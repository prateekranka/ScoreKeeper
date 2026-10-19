from io import BytesIO
from pathlib import Path
import argparse
import base64
import json
import random

from PIL import Image
from jev import write_private_json


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Freeze a labelled regression panel before making any Jev requests')
    parser.add_argument('--source', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True, mode=0o700)
    if (args.output / 'manifest.json').exists():
        raise SystemExit('The evaluation panel already exists and will not be replaced')
    source = json.loads((args.source / 'mnist-test.json').read_text())
    wrong = json.loads((args.source / 'benchmark-shared-final.json').read_text())['wrong']
    chosen = {row['index'] for row in wrong}
    rng = random.Random(20261018)
    chosen.update(rng.sample([index for index in range(len(source)) if index not in chosen], 96))
    rows = []
    for fixture in json.loads((args.source / 'user-fixtures.json').read_text()):
        rows.append({'id': f'user-{len(rows)}', 'file': fixture['file'], 'expected': fixture['expected'], 'split': 'regression', 'independent': False, 'writer': 'user', 'userSample': True})
    for index in sorted(chosen):
        image = args.output / f'mnist-{index}.png'
        image.write_bytes(base64.b64decode(source[index]['png']))
        rows.append({'id': f'mnist-{index}', 'file': image.name, 'expected': source[index]['expected'], 'split': 'regression', 'independent': False, 'writer': 'mnist'})
    for index in range(32):
        left, right = rng.sample(source, 2)
        canvas = Image.new('RGB', (600, 400), 'white')
        for column, item in enumerate((left, right)):
            with Image.open(BytesIO(base64.b64decode(item['png']))) as digit:
                canvas.paste(digit.convert('RGB'), (20 + column * 280, 60))
        image = args.output / f'pair-{index}.png'
        canvas.save(image, format='PNG')
        rows.append({'id': f'pair-{index}', 'file': image.name, 'expected': left['expected'] * 10 + right['expected'], 'split': 'regression', 'independent': False, 'writer': 'mnist-composite'})
    for fixture in json.loads((args.source / 'control-fixtures.json').read_text()):
        rows.append({'id': f"control-{fixture['name']}", 'file': fixture['file'], 'expected': None, 'split': 'regression', 'independent': False, 'writer': 'control'})
    write_private_json(args.output / 'manifest.json', rows)
    write_private_json(args.output / 'provenance.json', {'source': str(args.source), 'seed': 20261018, 'samples': len(rows), 'independentHoldout': False, 'note': 'Existing user images, known MNIST regressions, a fixed random MNIST sample and synthetic pairs are regression evidence only and cannot satisfy the independent-writer activation gate'})
    print(json.dumps({'samples': len(rows), 'manifest': str(args.output / 'manifest.json'), 'independentHoldout': False}))
