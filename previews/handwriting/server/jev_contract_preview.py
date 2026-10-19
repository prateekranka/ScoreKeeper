from email.parser import BytesParser
from email.policy import default
from functools import partial
from http.server import ThreadingHTTPServer
from io import BytesIO
from pathlib import Path
from urllib.parse import urlparse
import argparse
import hashlib
import json
import tempfile

import httpx2
from PIL import Image
from typesafe_sdk import TypeSafeClient, RetryPolicy

from jev import JevDecisions, JevError, MODEL, write_private_json
from jev_evaluate import evaluate
from preview import PreviewHandler, ROOT


class MemoryCredentials:
    def __init__(self):
        self.value = None
        self.unavailable = False

    def get(self):
        return self.value

    def set(self, value):
        if self.unavailable:
            raise JevError('keychain')
        self.value = value


class ContractService:
    def __init__(self, runtime):
        self.case = 'agree'
        self.calls = []
        self.credentials = MemoryCredentials()
        self.decisions = JevDecisions(self.credentials, self.client, runtime)

    def client(self, key):
        return TypeSafeClient(api_key=key, model=MODEL, base_url='https://api.typesafe.ai', transport=httpx2.MockTransport(self.respond), retry=RetryPolicy(max_retries=0), timeout=12, compression=False)

    def respond(self, request):
        assert request.method == 'POST' and str(request.url) == 'https://api.typesafe.ai/v1/systemone'
        assert request.headers.get('Authorization', '').startswith('Bearer ')
        raw = request.read()
        content_type = request.headers['Content-Type']
        image = None
        if content_type.startswith('multipart/'):
            message = BytesParser(policy=default).parsebytes(f'Content-Type: {content_type}\r\nMIME-Version: 1.0\r\n\r\n'.encode() + raw)
            parts = list(message.iter_parts())
            body = json.loads(parts[0].get_payload(decode=True))
            image = parts[1].get_payload(decode=True)
            assert len(parts) == 2 and parts[1].get_content_type() == 'image/png'
            assert request.headers.get('TypeSafe-Danger-Zone-Images') == 'true'
            assert set(body['state']) == {'drawing'} and len(body['assets']) == 1
            with Image.open(BytesIO(image)) as drawing:
                assert 280 <= min(drawing.size) <= max(drawing.size) <= 1568
        else:
            body = json.loads(raw)
        assert body['model'] == MODEL
        self.calls.append({'kind': 'drawing' if image else 'engineering', 'stateKeys': list(body['state']), 'questionKeys': list(body['questions']), 'imageHeader': request.headers.get('TypeSafe-Danger-Zone-Images'), 'imageSHA256': hashlib.sha256(image).hexdigest() if image else None})
        if self.case == 'timeout':
            raise httpx2.ReadTimeout('Simulated upstream timeout', request=request)
        if self.case == 'unauthorized':
            return httpx2.Response(401, json={'error': 'Invalid API key'}, request=request)
        answers = {}
        for name, question in body['questions'].items():
            if name == 'score':
                choice = '7' if self.case == 'disagree' else 'unreadable' if self.case == 'unreadable' else '4'
                probability = .98 if self.case == 'lowconfidence' else .999
                probabilities = {label: (probability if label == choice else (1 - probability) / (len(question['criteria']) - 1)) for label in question['criteria']}
                if self.case == 'badprobabilities':
                    probabilities[choice] = 9
                if self.case in {'rounded', 'badmass', 'excessmass', 'notrounded'}:
                    probabilities = {label: 0 for label in question['criteria']}
                    probabilities[choice] = {'rounded': .99, 'badmass': .05, 'excessmass': .99, 'notrounded': .991234}[self.case]
                    if self.case == 'excessmass':
                        probabilities['5'] = .99
                answers[name] = {'type': 'choice', 'choice': choice, 'confidence': .99, 'probabilities': probabilities}
            elif name == 'next_step':
                answers[name] = {'type': 'choice', 'choice': 'evaluate_veto', 'confidence': .95, 'probabilities': {label: .97 if label == 'evaluate_veto' else .01 for label in question['criteria']}}
            else:
                answers[name] = {'type': 'noul', 'noul': .01 if name == 'supports_zero_error_claim' else .99}
        return httpx2.Response(200, json={'model': 'different-model' if self.case == 'badmodel' else MODEL, 'usage': {'input_tokens': 100, 'output_tokens': 10}, 'answers': answers}, request=request)

    def reset(self, options):
        self.case = options.get('case', 'agree')
        self.calls.clear()
        self.credentials.value = 'e2e-dummy-key-not-a-credential' if options.get('configured') else None
        self.credentials.unavailable = self.case == 'keychain'
        self.decisions.cache.clear()
        for name in ('engineering.json', 'policy.json', 'evaluation.json'):
            (self.decisions.runtime / name).unlink(missing_ok=True)
        if options.get('active'):
            report = {'eligible': True, 'identity': self.decisions.policy_identity(), 'fixture': 'SDK contract test only, not an accuracy evaluation'}
            write_private_json(self.decisions.runtime / 'evaluation.json', report)
            data = (self.decisions.runtime / 'evaluation.json').read_bytes()
            write_private_json(self.decisions.runtime / 'policy.json', {'identity': self.decisions.policy_identity(), 'reportSHA256': hashlib.sha256(data).hexdigest()})
        return self.state()

    def state(self):
        return {'status': self.decisions.status(), 'calls': self.calls}


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--port', type=int, required=True)
    parser.add_argument('--runtime', type=Path, required=True)
    parser.add_argument('--fixtures', type=Path, required=True)
    args = parser.parse_args()
    service = ContractService(args.runtime)

    class ContractHandler(PreviewHandler):
        jev = service.decisions

        def do_GET(self):
            if urlparse(self.path).path == '/api/test/jev':
                self.reply(200, service.state())
            else:
                super().do_GET()

        def do_POST(self):
            endpoint = urlparse(self.path).path
            if endpoint == '/api/test/jev':
                size = int(self.headers.get('Content-Length', '0'))
                self.reply(200, service.reset(json.loads(self.rfile.read(size))))
            elif endpoint == '/api/test/evaluate':
                fixture = next(row for row in json.loads(args.fixtures.read_text()) if row['expected'] == 4)
                payload = Path(fixture['file']).read_bytes()
                sample = {'id': 'e2e-digit', 'payload': payload, 'expected': 4, 'sha256': hashlib.sha256(payload).hexdigest(), 'split': 'holdout', 'independent': True, 'writer': 'fixture', 'userSample': True}
                with tempfile.TemporaryDirectory(dir=args.runtime) as directory:
                    report = evaluate([sample], self.jev, self.recogniser, True, Path(directory))
                self.reply(200, {'eligible': report['eligible'], 'checks': report['checks'], 'combined': report['combined'], 'mode': self.jev.status()['mode']})
            else:
                super().do_POST()

    server = ThreadingHTTPServer(('127.0.0.1', args.port), partial(ContractHandler, directory=str(ROOT / 'dist')))
    print(f'PipCount simulated TypeSafe contract server is listening on {args.port}', flush=True)
    server.serve_forever()
