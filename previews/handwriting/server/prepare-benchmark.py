from io import BytesIO
from pathlib import Path
import base64
import gzip
import json
import struct
import sys

from PIL import Image, ImageOps

root = Path(sys.argv[1])
images = gzip.decompress((root / 't10k-images-idx3-ubyte.gz').read_bytes())
labels = gzip.decompress((root / 't10k-labels-idx1-ubyte.gz').read_bytes())
assert struct.unpack('>IIII', images[:16]) == (2051, 10000, 28, 28)
assert struct.unpack('>II', labels[:8]) == (2049, 10000)
rows = []
for index, label in enumerate(labels[8:]):
    image = ImageOps.invert(Image.frombytes('L', (28, 28), images[16 + index * 784:16 + (index + 1) * 784]))
    image = image.resize((280, 280), Image.Resampling.LANCZOS)
    output = BytesIO()
    image.save(output, format='PNG')
    rows.append({'index':index, 'expected':label, 'png':base64.b64encode(output.getvalue()).decode()})
(root / 'mnist-test.json').write_text(json.dumps(rows))
