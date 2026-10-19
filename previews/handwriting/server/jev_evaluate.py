from pathlib import Path
import argparse
import hashlib
import json
import math
import time

from jev import JevDecisions, JevError, RUNTIME, write_private_json
from recognise import DigitRecognizer


MAX_REQUESTS = 220
MIN_HOLDOUT = 100
MIN_WRITERS = 3
MIN_COVERAGE = 0.85
MAX_P95_SECONDS = 5


def load_manifest(path):
    rows = json.loads(path.read_text())
    if not isinstance(rows, list) or not 1 <= len(rows) <= MAX_REQUESTS:
        raise ValueError('The manifest must contain between 1 and 220 drawings')
    samples, hashes = [], set()
    for row in rows:
        image = (path.parent / row['file']).resolve()
        expected = row['expected']
        if expected is not None and (type(expected) is not int or not 0 <= expected <= 99):
            raise ValueError('Expected scores must be integers from 0 to 99 or null for unreadable input')
        payload = image.read_bytes()
        if not payload.startswith(b'\x89PNG\r\n\x1a\n') or len(payload) > 1_048_576:
            raise ValueError('Every drawing must be a PNG of at most one MiB')
        digest = hashlib.sha256(payload).hexdigest()
        if digest in hashes:
            raise ValueError('Duplicate drawings cannot count as independent evaluation examples')
        hashes.add(digest)
        samples.append({'id': str(row['id']), 'payload': payload, 'expected': expected, 'sha256': digest, 'split': row.get('split', 'regression'), 'independent': row.get('independent') is True, 'writer': str(row.get('writer', 'unknown')), 'userSample': row.get('userSample') is True})
    return samples


def metrics(rows, field):
    valid = [row for row in rows if row['expected'] is not None]
    accepted = [row for row in rows if row[field].get('status') == 'ready']
    correct = [row for row in accepted if row[field].get('value') == row['expected']]
    return {'samples': len(rows), 'valid': len(valid), 'accepted': len(accepted), 'wrongAccepted': len(accepted) - len(correct), 'coverage': len(correct) / len(valid) if valid else 0}


def evaluate(samples, decisions, recogniser, activate=False, output=None):
    if not decisions.key():
        raise JevError('not_configured')
    output = output or decisions.runtime
    identity = decisions.policy_identity()
    rows = []
    for index, sample in enumerate(samples):
        local = recogniser.recognise(sample['payload'])
        start = time.monotonic()
        try:
            remote = decisions.read_score(sample['payload'])
        except JevError as problem:
            remote = {'status': 'error', 'reason': problem.code, 'diagnostic': problem.diagnostic}
        elapsed = time.monotonic() - start
        combined = local if local.get('status') == 'ready' and remote.get('status') == 'ready' and local.get('value') == remote.get('value') else {'status': 'unreadable'}
        rows.append({**{key: value for key, value in sample.items() if key != 'payload'}, 'local': local, 'jev': remote, 'combined': combined, 'seconds': elapsed})
        write_private_json(output / 'evaluation-progress.json', {'completed': index + 1, 'total': len(samples), 'rows': rows})
        print(json.dumps({'completed': index + 1, 'total': len(samples)}), flush=True)
    if decisions.policy_identity() != identity:
        raise JevError('credential_changed')
    holdout = [row for row in rows if row['split'] == 'holdout' and row['independent'] and row['writer'] != 'unknown' and row['expected'] is not None]
    users = [row for row in rows if row['userSample']]
    controls = [row for row in rows if row['expected'] is None]
    durations = sorted(row['seconds'] for row in rows)
    p95 = durations[max(0, math.ceil(len(durations) * .95) - 1)]
    combined_metrics = metrics(rows, 'combined')
    checks = {
        'noWrongAccepted': combined_metrics['wrongAccepted'] == 0,
        'coverage': combined_metrics['coverage'] >= MIN_COVERAGE,
        'independentHoldoutCount': len(holdout) >= MIN_HOLDOUT,
        'independentWriterCount': len({row['writer'] for row in holdout}) >= MIN_WRITERS,
        'holdoutCoverage': metrics(holdout, 'combined')['coverage'] >= MIN_COVERAGE,
        'allUserSamplesCorrect': len(users) >= 8 and all(row['combined'].get('status') == 'ready' and row['combined'].get('value') == row['expected'] for row in users),
        'controlsRejected': len(controls) >= 5 and all(row['jev'].get('status') != 'ready' for row in controls),
        'noProviderErrors': all(row['jev'].get('status') != 'error' for row in rows),
        'p95Latency': p95 <= MAX_P95_SECONDS,
    }
    report = {'identity': identity, 'eligible': all(checks.values()), 'checks': checks, 'local': metrics(rows, 'local'), 'jev': metrics(rows, 'jev'), 'combined': combined_metrics, 'holdout': metrics(holdout, 'combined'), 'p95Seconds': p95, 'limits': {'minimumHoldout': MIN_HOLDOUT, 'minimumWriters': MIN_WRITERS, 'minimumCoverage': MIN_COVERAGE, 'maximumP95Seconds': MAX_P95_SECONDS}, 'proofLimit': 'A finite evaluation cannot guarantee error-free recognition and experimental image support can change', 'rows': rows}
    write_private_json(output / 'evaluation.json', report)
    if activate:
        if not report['eligible']:
            (decisions.runtime / 'policy.json').unlink(missing_ok=True)
        else:
            write_private_json(decisions.runtime / 'evaluation.json', report)
            data = (decisions.runtime / 'evaluation.json').read_bytes()
            write_private_json(decisions.runtime / 'policy.json', {'identity': identity, 'reportSHA256': hashlib.sha256(data).hexdigest()})
    return report


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Measure Jev separately from local recognition before enabling its veto')
    parser.add_argument('--manifest', type=Path, default=RUNTIME / 'manifest.json')
    parser.add_argument('--output', type=Path, default=RUNTIME)
    parser.add_argument('--engineering', action='store_true')
    parser.add_argument('--review-report', type=Path)
    parser.add_argument('--activate', action='store_true')
    args = parser.parse_args()
    try:
        decisions = JevDecisions()
        if not decisions.key():
            raise JevError('not_configured')
        if args.review_report:
            evaluation = json.loads(args.review_report.read_text())
            review = decisions.engineering_review(evaluation=evaluation)
            write_private_json(RUNTIME / 'engineering.json', review)
            write_private_json(RUNTIME / 'evaluation.json', evaluation)
            write_private_json(args.output / 'engineering.json', review)
            print(json.dumps({'model': review['model'], 'answers': review['answers'], 'usage': review['usage']}))
            raise SystemExit(0)
        if args.engineering:
            write_private_json(RUNTIME / 'engineering.json', decisions.engineering_review())
        report = evaluate(load_manifest(args.manifest), decisions, DigitRecognizer(), args.activate, args.output)
        print(json.dumps({'eligible': report['eligible'], 'checks': report['checks'], 'mode': decisions.status()['mode']}))
    except JevError as problem:
        print(json.dumps({'status': 'error', 'reason': problem.code}))
        raise SystemExit(2)
    except (OSError, ValueError, KeyError) as problem:
        print(json.dumps({'status': 'error', 'reason': 'invalid_manifest', 'detail': str(problem)}))
        raise SystemExit(2)
