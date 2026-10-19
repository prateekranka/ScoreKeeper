from pathlib import Path
import hashlib
import json
import shutil
import subprocess
import sys
import venv

root = Path(__file__).resolve().parent.parent
if sys.platform != 'darwin' or not shutil.which('xcrun'):
    raise SystemExit('Local recognition requires macOS and the Swift command-line tools')
models = json.loads((root / 'server/models/PROVENANCE.json').read_text())
for name, expected in [('mnist-12.onnx', models['sha256']), ('MNISTClassifier.mlmodel', models['independentModel']['sha256'])]:
    if hashlib.sha256((root / 'server/models' / name).read_bytes()).hexdigest() != expected:
        raise SystemExit('A bundled model does not match its reviewed checksum')
runtime = root / '.runtime'
environment = runtime / 'digits-env'
venv.EnvBuilder(with_pip=True).create(environment)
subprocess.run([str(environment / 'bin/python'), '-m', 'pip', 'install', '-r', str(root / 'server/requirements.lock')], check=True)
cache = runtime / 'module-cache'
cache.mkdir(parents=True, exist_ok=True)
subprocess.run(['xcrun', 'swiftc', '-O', '-module-cache-path', str(cache), str(root / 'server/apple-digits.swift'), '-o', str(runtime / 'apple-digits')], check=True)
print('Local Python environment and Core ML worker are ready')
