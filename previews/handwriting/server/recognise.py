from io import BytesIO
from pathlib import Path
import hashlib
import json
import selectors
import subprocess
import sys

import numpy as np
import onnxruntime as ort
from PIL import Image, ImageFilter, ImageOps
from scipy import ndimage


MODEL = Path(__file__).parent / 'models' / 'mnist-12.onnx'
MODEL_SHA256 = hashlib.sha256(MODEL.read_bytes()).hexdigest()
if MODEL_SHA256 != '5c688690f8bacf667d4c2074af5ad0646ca328d7ab03eccf944a65b320171bdd':
    raise RuntimeError('Digit model checksum does not match the reviewed artifact')
VERSION = 'digits-6'
SOURCE_SHA256 = hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
APPLE_MODEL = MODEL.parent / 'MNISTClassifier.mlmodel'
APPLE_WORKER = MODEL.parent.parent.parent / '.runtime' / 'apple-digits'
APPLE_MODEL_SHA256 = hashlib.sha256(APPLE_MODEL.read_bytes()).hexdigest()
if APPLE_MODEL_SHA256 != '816d1a222d5272109166ffc819d7ce44aff923a673884e34d982aa74985ba587':
    raise RuntimeError('Apple digit model checksum does not match the reviewed artifact')


class DigitRecognizer:
    def __init__(self):
        options = ort.SessionOptions()
        options.intra_op_num_threads = 1
        options.inter_op_num_threads = 1
        self.session = ort.InferenceSession(str(MODEL), options, providers=['CPUExecutionProvider'])
        self.input = self.session.get_inputs()[0].name
        self.worker = None

    def apple_predictions(self, tensors):
        if self.worker is None or self.worker.poll() is not None:
            self.worker = subprocess.Popen([str(APPLE_WORKER), str(APPLE_MODEL)], stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True, bufsize=1)
        self.worker.stdin.write(json.dumps(tensors) + '\n')
        self.worker.stdin.flush()
        with selectors.DefaultSelector() as selector:
            selector.register(self.worker.stdout, selectors.EVENT_READ)
            if not selector.select(timeout=10):
                self.worker.kill()
                self.worker.wait()
                raise RuntimeError('Digit worker timed out')
        result = np.asarray(json.loads(self.worker.stdout.readline()), dtype=np.float32)
        if result.shape != (len(tensors), 10) or not np.isfinite(result).all() or not np.allclose(result.sum(axis=1), 1, atol=0.001):
            raise RuntimeError('Digit worker returned invalid probabilities')
        return result

    def classify(self, glyph):
        glyph = ImageOps.invert(glyph)
        glyph = glyph.crop(glyph.point(lambda value: 255 if value > 95 else 0).getbbox())
        scale = 80 / max(glyph.size)
        glyph = glyph.resize((max(1, round(glyph.width * scale)), max(1, round(glyph.height * scale))), Image.Resampling.LANCZOS)
        base = Image.new('L', (112, 112))
        base.paste(glyph, ((112 - glyph.width) // 2, (112 - glyph.height) // 2))
        ink = np.asarray(base) > 95
        edges = np.count_nonzero(ink[:, 1:] != ink[:, :-1]) + np.count_nonzero(ink[1:, :] != ink[:-1, :])
        width = 2 * np.count_nonzero(ink) / max(1, edges)
        variants = []
        tensors = []
        views = []
        for target in (6, 8, 10):
            difference = round((target - width) / 2) * 2
            kernel = min(15, abs(difference) + 1)
            views.append(base.filter(ImageFilter.MaxFilter(kernel) if difference > 0 else ImageFilter.MinFilter(kernel)) if difference else base)
        if width >= 4:
            views.append(base)
        for canvas in views:
            values = np.asarray(canvas.resize((28, 28), Image.Resampling.LANCZOS), dtype=np.float32) / 255
            y, x = np.indices(values.shape)
            mass = values.sum()
            if mass <= 0:
                raise ValueError('No ink after normalization')
            shift_x = round(13.5 - float((x * values).sum() / mass))
            shift_y = round(13.5 - float((y * values).sum() / mass))
            shifted = Image.fromarray((values * 255).astype(np.uint8)).transform((28, 28), Image.Transform.AFFINE, (1, 0, -shift_x, 0, 1, -shift_y))
            tensor = np.asarray(shifted, dtype=np.float32).reshape(1, 1, 28, 28) / 255
            tensors.append(tensor.reshape(-1).tolist())
            logits = self.session.run(None, {self.input: tensor})[0].reshape(10)
            probabilities = np.exp(logits - logits.max())
            probabilities /= probabilities.sum()
            variants.append(probabilities)
        apple = self.apple_predictions(tensors)
        model_averages = [np.mean(variants, axis=0), np.mean(apple, axis=0)]
        average = np.mean(model_averages, axis=0)
        order = np.argsort(average)[::-1]
        digit = int(order[0])
        confidence = min(float(probabilities[digit]) for probabilities in model_averages)
        margin = min(float(probabilities[digit] - max(np.delete(probabilities, digit))) for probabilities in model_averages)
        agreement = sum(int(np.argmax(probabilities)) == digit for probabilities in [*variants, *apple])
        return {'digit': digit, 'confidence': confidence, 'margin': margin, 'agreement': agreement, 'requiredAgreement': len(views) * 2}

    def recognise(self, payload):
        try:
            with Image.open(BytesIO(payload)) as source:
                if source.format != 'PNG' or max(source.size) > 2048 or getattr(source, 'n_frames', 1) != 1:
                    return {'status': 'unreadable'}
                visible = ImageOps.exif_transpose(source).convert('RGBA')
                image = Image.alpha_composite(Image.new('RGBA', visible.size, 'white'), visible).convert('L')
            mask = np.asarray(image) < 160
            y, x = np.nonzero(mask)
            if len(x) < 12:
                return {'status': 'unreadable'}
            left, top, right, bottom = int(x.min()), int(y.min()), int(x.max()) + 1, int(y.max()) + 1
            height = bottom - top
            if height < 12:
                return {'status': 'unreadable'}
            components, count = ndimage.label(mask, structure=np.ones((3, 3)))
            areas = np.bincount(components.ravel())[1:]
            if count > 1 and np.any(areas < max(4, int(areas.max() * 0.08))):
                return {'status': 'unreadable', 'reason': 'ambiguous-ink'}
            component_bounds = ndimage.find_objects(components)
            if any((region[1].stop - region[1].start) > 3 * (region[0].stop - region[0].start) and (region[0].stop - region[0].start) < height * 0.2 for region in component_bounds if region is not None):
                return {'status': 'unreadable', 'reason': 'detached-mark'}
            separated = []
            if count == 2:
                ordered = sorted(enumerate(component_bounds, 1), key=lambda item: (item[1][1].start + item[1][1].stop) / 2)
                first, second = ordered[0][1], ordered[1][1]
                overlap = min(first[0].stop, second[0].stop) - max(first[0].start, second[0].start)
                centres = (second[1].start + second[1].stop - first[1].start - first[1].stop) / 2
                if all(region[0].stop - region[0].start >= height * 0.55 for _, region in ordered) and overlap >= height * 0.4 and centres >= height * 0.2:
                    if min(areas) < max(areas) * 0.25:
                        return {'status': 'unreadable', 'reason': 'ambiguous-segmentation'}
                    values = np.asarray(image)
                    for label, region in ordered:
                        glyph = Image.fromarray(np.where(components[region] == label, values[region], 255).astype(np.uint8))
                        if glyph.width / glyph.height > 1.25:
                            return {'status': 'unreadable', 'reason': 'ambiguous-segmentation'}
                        separated.append(glyph)
            columns = mask[top:bottom, left:right].any(axis=0)
            runs = []
            for column in np.flatnonzero(columns):
                position = left + int(column)
                if runs and position == runs[-1][1]:
                    runs[-1][1] = position + 1
                else:
                    runs.append([position, position + 1])
            if not separated and not 1 <= len(runs) <= 2:
                return {'status': 'unreadable'}
            if not separated and len(runs) == 2:
                ink_areas = [int(mask[top:bottom, start:end].sum()) for start, end in runs]
                if min(ink_areas) < max(ink_areas) * 0.25:
                    return {'status': 'unreadable', 'reason': 'ambiguous-segmentation'}
            predictions = [self.classify(glyph) for glyph in separated]
            for start, end in ([] if separated else runs):
                rows = np.flatnonzero(mask[top:bottom, start:end].any(axis=1))
                glyph_top, glyph_bottom = top + int(rows.min()), top + int(rows.max()) + 1
                glyph_height = glyph_bottom - glyph_top
                if glyph_height < height * 0.55 or (end - start) / glyph_height > 1.25:
                    return {'status': 'unreadable'}
                if len(runs) == 2:
                    heights = [region[0].stop - region[0].start for region in component_bounds if region is not None and region[1].start >= start and region[1].stop <= end]
                    if not heights or max(heights) < glyph_height * 0.75:
                        return {'status': 'unreadable', 'reason': 'fragmented-digit'}
                predictions.append(self.classify(image.crop((start, glyph_top, end, glyph_bottom))))
            if any(p['confidence'] < 0.85 or p['margin'] < 0.70 or p['agreement'] < p['requiredAgreement'] for p in predictions):
                return {'status': 'unreadable', 'digits': predictions}
            value = int(''.join(str(p['digit']) for p in predictions))
            return {'status': 'ready', 'value': value, 'confidence': min(p['confidence'] for p in predictions), 'digits': predictions}
        except (ValueError, OSError, Image.DecompressionBombError):
            return {'status': 'unreadable'}


if __name__ == '__main__':
    payload = sys.stdin.buffer.read(1_048_577)
    result = DigitRecognizer().recognise(payload) if len(payload) <= 1_048_576 else {'status': 'unreadable'}
    print(json.dumps({**result, 'recogniser': VERSION}))
