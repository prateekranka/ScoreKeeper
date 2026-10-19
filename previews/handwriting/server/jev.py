from collections import OrderedDict
from io import BytesIO
from pathlib import Path
from threading import RLock
import hashlib
import json
import logging
import math
import os
import tempfile

from PIL import Image as PILImage, ImageOps
from keyring.backends.macOS import Keyring
from typesafe_sdk import Choice, Image, Noul, RetryPolicy, TypeSafeClient, TypeSafeAuthenticationError, TypeSafeError
from recognise import MODEL_SHA256, APPLE_MODEL_SHA256, VERSION


ROOT = Path(__file__).resolve().parent.parent
RUNTIME = ROOT / '.runtime' / 'jev'
KEYCHAIN_ACCOUNT = os.environ.get('PIPCOUNT_JEV_ACCOUNT', hashlib.sha256(str(ROOT).encode()).hexdigest()[:24])
MODEL = 'jev-1.14.0'
MIN_CONFIDENCE = 0.90
MIN_PROBABILITY = 0.99
READ_INSTRUCTIONS = 'Read the complete handwritten round score in `drawing` as an integer from 0 to 99. Choose unreadable for blank input, an unsupported sign, more than two digits, stray marks that change the reading, or genuinely ambiguous handwriting. Use only the drawing. Do not infer a score from a player, total, expected answer or another recogniser.'
CRITERIA = {**{str(value): f'The complete handwritten score is {value}' for value in range(100)}, 'unreadable': 'The image does not unambiguously show one whole score from 0 to 99'}
PROMPT_SHA256 = hashlib.sha256(json.dumps({'instructions': READ_INSTRUCTIONS, 'criteria': CRITERIA}, sort_keys=True).encode()).hexdigest()
logging.getLogger('typesafe_sdk').setLevel(logging.CRITICAL)


class JevError(Exception):
    def __init__(self, code, diagnostic=None):
        self.code = code
        self.diagnostic = diagnostic
        super().__init__(code)


def valid_probability_mass(probabilities):
    values = list(probabilities.values())
    if not values or any(not math.isfinite(value) or not 0 <= value <= 1 for value in values):
        return False
    if math.isclose(math.fsum(values), 1, abs_tol=0.001):
        return True
    if not all(math.isclose(value * 100, round(value * 100), abs_tol=0.000001) for value in values):
        return False
    return math.fsum(max(0, value - 0.005) for value in values) <= 1.000000001 and math.fsum(min(1, value + 0.005) for value in values) >= 0.999999999


def write_private_json(path, value):
    path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    handle, temporary = tempfile.mkstemp(dir=path.parent)
    try:
        with os.fdopen(handle, 'w') as output:
            json.dump(value, output, allow_nan=False)
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


class KeychainCredentials:
    def __init__(self, runtime=RUNTIME):
        self.marker = runtime / 'configured.json'
        self.cached = None
        self.backend = Keyring()

    def get(self):
        if self.cached is not None:
            return self.cached
        if not self.marker.exists():
            return None
        try:
            self.cached = self.backend.get_password('PipCount TypeSafe Preview', KEYCHAIN_ACCOUNT)
            return self.cached
        except Exception:
            raise JevError('keychain') from None

    def set(self, key):
        try:
            self.backend.set_password('PipCount TypeSafe Preview', KEYCHAIN_ACCOUNT, key)
        except Exception:
            raise JevError('keychain') from None
        self.cached = key
        write_private_json(self.marker, {'configured': True})


def default_client(key):
    return TypeSafeClient(api_key=key, model=MODEL, base_url='https://api.typesafe.ai', retry=RetryPolicy(max_retries=0), timeout=12, compression=False)


class JevDecisions:
    def __init__(self, credentials=None, client_factory=default_client, runtime=RUNTIME):
        self.credentials = credentials if credentials is not None else KeychainCredentials(runtime)
        self.client_factory = client_factory
        self.runtime = runtime
        self.lock = RLock()
        self.cache = OrderedDict()

    def key(self):
        with self.lock:
            return self.credentials.get()

    def fingerprint(self):
        key = self.key()
        return hashlib.sha256(key.encode()).hexdigest() if key else None

    def policy_identity(self):
        return {'model': MODEL, 'promptSHA256': PROMPT_SHA256, 'credentialFingerprint': self.fingerprint(), 'minimumConfidence': MIN_CONFIDENCE, 'minimumProbability': MIN_PROBABILITY, 'verifierSHA256': hashlib.sha256(Path(__file__).read_bytes()).hexdigest(), 'localVersion': VERSION, 'localSHA256': hashlib.sha256((ROOT / 'server' / 'recognise.py').read_bytes()).hexdigest(), 'localModelSHA256': MODEL_SHA256, 'appleModelSHA256': APPLE_MODEL_SHA256}

    def verified(self):
        try:
            policy = json.loads((self.runtime / 'policy.json').read_text())
            report_data = (self.runtime / 'evaluation.json').read_bytes()
            report = json.loads(report_data)
            return bool(self.key()) and policy['identity'] == self.policy_identity() and policy['reportSHA256'] == hashlib.sha256(report_data).hexdigest() and report['eligible'] is True and report['identity'] == policy['identity']
        except (OSError, ValueError, KeyError, JevError):
            return False

    def status(self):
        try:
            configured = bool(self.key())
            error = None
        except JevError as problem:
            configured, error = False, problem.code
        recommendation = None
        try:
            review = json.loads((self.runtime / 'engineering.json').read_text())
            answer = review['answers']['next_step']
            if answer['choice'] in {'evaluate_veto', 'evaluate_primary', 'collect_writers', 'retain_local'}:
                recommendation = {'choice': answer['choice'], 'confidence': answer['confidence']}
        except (OSError, ValueError, KeyError):
            pass
        evaluation = None
        if configured:
            try:
                report = json.loads((self.runtime / 'evaluation.json').read_text())
                identity = report['identity']
                if identity['credentialFingerprint'] == self.fingerprint() and identity['model'] == MODEL and identity['promptSHA256'] == PROMPT_SHA256:
                    users = [row for row in report['rows'] if row['userSample']]
                    evaluation = {'samples': report['jev']['samples'], 'valid': report['jev']['valid'], 'accepted': report['jev']['accepted'], 'wrongAccepted': report['jev']['wrongAccepted'], 'eligible': report['eligible'], 'p95Seconds': report['p95Seconds'], 'userSamples': len(users), 'userCandidatesCorrect': sum(row['jev'].get('candidate') == row['expected'] for row in users), 'userAcceptedCorrect': sum(row['jev'].get('status') == 'ready' and row['jev'].get('value') == row['expected'] for row in users)}
            except (OSError, ValueError, KeyError, JevError):
                pass
        return {'configured': configured, 'model': MODEL, 'mode': 'verify' if configured and self.verified() else ('awaiting_evaluation' if configured else 'local'), 'engineering': recommendation, 'evaluation': evaluation, 'error': error}

    def engineering_review(self, key=None, evaluation=None):
        key = key or self.key()
        if not key:
            raise JevError('not_configured')
        state = {
            'goal': 'Reduce wrong accepted handwritten scores in the PipCount web preview',
            'baseline_regression_evidence': {'samples': 10000, 'accepted': 9123, 'wrong_accepted': 16, 'rejected': 877, 'user_samples_correct': 8},
            'current_pipeline': 'Two local digit CNNs with segmentation checks, original-ink agreement, inline reading, explicit one-tap save and Undo',
            'constraints': ['Keep a single writing dialog and the current save flow', 'Do not claim error-free recognition from a finite benchmark', 'Use code for arithmetic, ranges, persistence and Undo', 'Keep API credentials on the Mac', 'Jev image input is experimental', 'Do not enable Jev unless measured validation passes'],
        }
        if evaluation is not None:
            state['measured_jev_evaluation'] = {name: evaluation[name] for name in ('local', 'jev', 'combined', 'holdout', 'p95Seconds', 'eligible', 'checks')}
            labelled = [row for row in evaluation['rows'] if row['expected'] is not None]
            writers = {row['writer'] for row in labelled if row.get('writer', 'unknown') != 'unknown'}
            state['measured_jev_evaluation']['set_description'] = f"A regression panel of {len(evaluation['rows'])} drawings, with {len(labelled)} labelled scores, {len(evaluation['rows']) - len(labelled)} invalid controls, {len(writers)} anonymous writer IDs and {evaluation['holdout']['samples']} qualifying independent holdout examples, where anonymous writer IDs do not establish distinct people"
            valid = [row for row in evaluation['rows'] if row['expected'] is not None]
            users = [row for row in evaluation['rows'] if row['userSample']]
            state['measured_jev_evaluation']['unfiltered_candidates'] = {'valid': len(valid), 'correct': sum(row['jev'].get('candidate') == row['expected'] for row in valid), 'wrong': sum(row['jev'].get('candidate') is not None and row['jev'].get('candidate') != row['expected'] for row in valid)}
            state['measured_jev_evaluation']['user_examples'] = {'samples': len(users), 'local_correct': sum(row['local'].get('value') == row['expected'] for row in users), 'jev_candidates_correct': sum(row['jev'].get('candidate') == row['expected'] for row in users), 'jev_accepted_correct': sum(row['jev'].get('status') == 'ready' and row['jev'].get('value') == row['expected'] for row in users)}
        questions = {
            'next_step': Choice(instructions='Which engineering step should be tried next, given this evidence and these constraints?', criteria={
                'evaluate_veto': 'Measure Jev as an independent image reader and veto local readings that disagree or are uncertain before considering activation',
                'evaluate_primary': 'Measure Jev as the primary image reader, including recovery of local rejections, before considering activation',
                'collect_writers': 'First collect a separate set of real finger handwriting from several writers',
                'retain_local': 'Keep the existing pipeline while gathering more evidence',
            }),
            'supports_zero_error_claim': Noul(instructions='Does the available evidence justify claiming that future handwriting recognition will be error free?'),
            'requires_measured_validation': Noul(instructions='Does enabling Jev for score acceptance require measuring wrong accepted scores, valid-score coverage and latency on withheld examples?'),
        }
        try:
            with self.client_factory(key) as client:
                result = client.system_one(state=state, questions=questions)
            value = result.model_dump(mode='json')
            if value['model'] != MODEL:
                raise JevError('model_changed')
            if set(value['answers']) != set(questions) or 'next_step' not in result.choices or set(result.nouls) != {'supports_zero_error_claim', 'requires_measured_validation'}:
                raise JevError('invalid_response')
            answer = result.choices['next_step']
            if answer.choice not in questions['next_step'].criteria or not math.isfinite(answer.confidence) or not 0 <= answer.confidence <= 1 or any(not math.isfinite(answer.noul) or not 0 <= answer.noul <= 1 for answer in result.nouls.values()):
                raise JevError('invalid_response')
            return value
        except TypeSafeAuthenticationError:
            raise JevError('authentication') from None
        except TypeSafeError:
            raise JevError('unavailable') from None
        except (ValueError, KeyError):
            raise JevError('invalid_response') from None

    def connect(self, key):
        if not isinstance(key, str):
            raise JevError('invalid_key')
        key = key.strip()
        if not 8 <= len(key) <= 512 or not key.isascii() or any(character.isspace() or ord(character) < 33 for character in key):
            raise JevError('invalid_key')
        with self.lock:
            review = self.engineering_review(key)
            self.credentials.set(key)
            write_private_json(self.runtime / 'engineering.json', review)
            (self.runtime / 'policy.json').unlink(missing_ok=True)
            self.cache.clear()
        return self.status()

    def read_score(self, payload):
        key = self.key()
        if not key:
            raise JevError('not_configured')
        cache_key = (hashlib.sha256(key.encode()).hexdigest(), hashlib.sha256(payload).hexdigest())
        with self.lock:
            if cache_key in self.cache:
                return self.cache[cache_key]
        try:
            with PILImage.open(BytesIO(payload)) as source:
                if source.format != 'PNG' or max(source.size) > 2048:
                    raise JevError('invalid_image')
                drawing = ImageOps.exif_transpose(source).convert('RGB')
                drawing.thumbnail((1000, 1000), PILImage.Resampling.LANCZOS)
                if min(drawing.size) < 280:
                    drawing = ImageOps.expand(drawing, border=(max(0, (280-drawing.width+1)//2), max(0, (280-drawing.height+1)//2)), fill='white')
                encoded = BytesIO()
                drawing.save(encoded, format='PNG')
            with self.client_factory(key) as client:
                response = client.system_one(state={'drawing': Image(encoded.getvalue())}, questions={'score': Choice(instructions=READ_INSTRUCTIONS, criteria=CRITERIA)}, extra_headers={'TypeSafe-Danger-Zone-Images': 'true'})
            if 'score' not in response.choices:
                raise JevError('invalid_response', {'model': response.model, 'questionCount': len(response.answers), 'scoreAnswerPresent': False})
            answer = response.choices['score']
            probabilities = dict(answer.probabilities)
            choice, confidence = answer.choice, float(answer.confidence)
            if response.model != MODEL or set(probabilities) != set(CRITERIA) or choice not in CRITERIA or not math.isfinite(confidence) or not 0 <= confidence <= 1 or not valid_probability_mass(probabilities) or probabilities[choice] < max(probabilities.values()):
                raise JevError('invalid_response', {'model': response.model, 'choice': choice if choice in CRITERIA else 'unknown', 'confidence': confidence if math.isfinite(confidence) else None, 'probabilityCount': len(probabilities), 'probabilitySum': sum(probabilities.values()) if all(math.isfinite(value) for value in probabilities.values()) else None, 'keysMatch': set(probabilities) == set(CRITERIA), 'selectedIsMaximum': probabilities.get(choice) == max(probabilities.values(), default=None)})
            ready = choice != 'unreadable' and confidence >= MIN_CONFIDENCE and probabilities[choice] >= MIN_PROBABILITY
            result = {'status': 'ready' if ready else 'unreadable', 'value': int(choice) if ready else None, 'candidate': int(choice) if choice != 'unreadable' else None, 'confidence': confidence, 'probability': probabilities[choice], 'model': response.model, 'usage': response.usage.model_dump(mode='json')}
        except TypeSafeAuthenticationError:
            raise JevError('authentication') from None
        except TypeSafeError:
            raise JevError('unavailable') from None
        except (OSError, ValueError, KeyError, PILImage.DecompressionBombError) as problem:
            raise JevError('invalid_response', {'exceptionType': type(problem).__name__}) from None
        with self.lock:
            self.cache[cache_key] = result
            while len(self.cache) > 128:
                self.cache.popitem(last=False)
        return result

    def recognise(self, payload, local):
        if not self.verified() or local.get('status') != 'ready':
            return local
        try:
            decision = self.read_score(payload)
        except JevError:
            return {'status': 'error', 'reason': 'jev_unavailable'}
        if decision['status'] == 'ready' and decision['value'] == local.get('value'):
            return {**local, 'decisionProvider': 'jev', 'decisionModel': MODEL}
        return {'status': 'unreadable', 'reason': 'jev_disagreement'}
