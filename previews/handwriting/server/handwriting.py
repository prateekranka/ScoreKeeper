from contextlib import contextmanager
from datetime import datetime, timezone
from io import BytesIO
from pathlib import Path
from threading import RLock
import hashlib
import json
import math
import os
import random
import sqlite3
import tempfile
import uuid
import zipfile

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parent.parent
PAIRS = [10, 11, 12, 17, 18, 19, 20, 24, 25, 30, 37, 40, 41, 50, 60, 69, 70, 72, 90, 99]


class CollectionError(Exception):
    def __init__(self, code, status=400):
        self.code = code
        self.status = status
        super().__init__(code)


def identifier(value):
    try:
        if not isinstance(value, str) or str(uuid.UUID(value)) != value:
            raise ValueError()
        return value
    except (ValueError, AttributeError):
        raise CollectionError('invalid_identifier') from None


def expected_score(writer, index):
    cycle, position = divmod(index, 40)
    remaining = list(range(10)) + PAIRS
    random.Random(int(hashlib.sha256(f'{writer}:{cycle}'.encode()).hexdigest(), 16)).shuffle(remaining)
    return (list(range(10)) + remaining)[position]


def clean_strokes(value):
    if not isinstance(value, list) or not 1 <= len(value) <= 100:
        raise CollectionError('write_first')
    result, count = [], 0
    for stroke in value:
        if not isinstance(stroke, list) or not 1 <= len(stroke) <= 1500:
            raise CollectionError('invalid_drawing')
        clean = []
        for point in stroke:
            if not isinstance(point, dict):
                raise CollectionError('invalid_drawing')
            item = {}
            for key, maximum in (('x', 1000), ('y', 1000), ('t', 1e15), ('pressure', 1)):
                number = point.get(key)
                if key in ('t', 'pressure') and number is None:
                    continue
                if type(number) not in (int, float) or not math.isfinite(number) or not 0 <= number <= maximum:
                    raise CollectionError('invalid_drawing')
                item[key] = number
            clean.append(item)
        count += len(clean)
        if count > 10000:
            raise CollectionError('invalid_drawing')
        result.append(clean)
    points = [point for stroke in result for point in stroke]
    if len(points) < 2 or max(max(point[axis] for point in points) - min(point[axis] for point in points) for axis in ('x', 'y')) < 5:
        raise CollectionError('write_first')
    return result


def render_drawing(strokes):
    points = [point for stroke in strokes for point in stroke]
    left, top = (min(point[axis] for point in points) for axis in ('x', 'y'))
    width = max(20, max(point['x'] for point in points) - left)
    height = max(20, max(point['y'] for point in points) - top)
    scale = 640 / max(width + 160, height + 160)
    image = Image.new('RGB', (math.ceil((width + 160) * scale), math.ceil((height + 160) * scale)), 'white')
    draw = ImageDraw.Draw(image)
    radius = 6 * scale
    for stroke in strokes:
        coordinates = [((point['x'] - left + 80) * scale, (point['y'] - top + 80) * scale) for point in stroke]
        if len(coordinates) > 1:
            draw.line(coordinates, fill='#191a1c', width=max(1, round(radius * 2)), joint='curve')
        for x, y in coordinates:
            draw.ellipse((x - radius, y - radius, x + radius, y + radius), fill='#191a1c')
    output = BytesIO()
    image.save(output, format='PNG')
    return output.getvalue()


class HandwritingStore:
    def __init__(self, directory=None):
        self.directory = Path(directory or os.environ.get('PIPCOUNT_HANDWRITING_DIR') or ROOT / '.runtime' / 'handwriting')
        self.directory.mkdir(parents=True, exist_ok=True, mode=0o700)
        self.file = self.directory / 'samples.sqlite3'
        self.lock = RLock()
        with self.database() as db:
            db.execute('PRAGMA journal_mode=WAL')
            db.executescript('''CREATE TABLE IF NOT EXISTS writers (id TEXT PRIMARY KEY, next_index INTEGER NOT NULL);
CREATE TABLE IF NOT EXISTS samples (id TEXT PRIMARY KEY, writer_id TEXT NOT NULL, prompt_index INTEGER NOT NULL, expected INTEGER NOT NULL, strokes TEXT NOT NULL, ink_sha256 TEXT NOT NULL, png BLOB NOT NULL, metadata TEXT NOT NULL, created TEXT NOT NULL, discarded INTEGER NOT NULL DEFAULT 0);
CREATE UNIQUE INDEX IF NOT EXISTS active_prompt ON samples(writer_id, prompt_index) WHERE discarded=0;''')
        self.file.chmod(0o600)

    @contextmanager
    def database(self):
        db = sqlite3.connect(self.file, timeout=10)
        db.row_factory = sqlite3.Row
        try:
            with db:
                yield db
        finally:
            db.close()

    def session(self, writer, db=None):
        writer = identifier(writer)
        if db is None:
            with self.database() as connection:
                connection.execute('BEGIN')
                return self.session(writer, connection)
        row = db.execute('SELECT next_index FROM writers WHERE id=?', (writer,)).fetchone()
        index = row['next_index'] if row else 0
        count = db.execute('SELECT COUNT(*) AS samples, COUNT(DISTINCT writer_id) AS writers FROM samples WHERE discarded=0').fetchone()
        writer_count = db.execute('SELECT COUNT(*) FROM samples WHERE writer_id=? AND discarded=0', (writer,)).fetchone()[0]
        last = db.execute('SELECT id, expected FROM samples WHERE writer_id=? AND discarded=0 ORDER BY prompt_index DESC LIMIT 1', (writer,)).fetchone()
        return {'writerId': writer, 'promptIndex': index, 'expected': expected_score(writer, index), 'writerSaved': writer_count, 'totalSaved': count['samples'], 'writerCount': count['writers'], 'writerTarget': 40, 'lastSample': dict(last) if last else None}

    def save(self, data):
        if not isinstance(data, dict):
            raise CollectionError('invalid_drawing')
        sample_id, writer = identifier(data.get('id')), identifier(data.get('writerId'))
        index, expected = data.get('promptIndex'), data.get('expected')
        if type(index) is not int or not 0 <= index < 10000 or type(expected) is not int or expected != expected_score(writer, index):
            raise CollectionError('wrong_prompt', 409)
        strokes = clean_strokes(data.get('strokes'))
        encoded = json.dumps(strokes, sort_keys=True, separators=(',', ':'), allow_nan=False)
        digest = hashlib.sha256(encoded.encode()).hexdigest()
        metadata = {}
        source = data.get('metadata', {})
        if not isinstance(source, dict):
            raise CollectionError('invalid_drawing')
        for key, maximum in (('width', 10000), ('height', 10000), ('pixelRatio', 8)):
            number = source.get(key)
            if number is not None:
                if type(number) not in (int, float) or not math.isfinite(number) or not 0 < number <= maximum:
                    raise CollectionError('invalid_drawing')
                metadata[key] = number
        pointers = source.get('pointerTypes', [])
        if not isinstance(pointers, list) or len(pointers) > 3 or any(value not in {'touch', 'pen', 'mouse'} for value in pointers):
            raise CollectionError('invalid_drawing')
        metadata['pointerTypes'] = sorted(set(pointers))
        png = render_drawing(strokes)
        with self.lock, self.database() as db:
            db.execute('BEGIN IMMEDIATE')
            existing = db.execute('SELECT * FROM samples WHERE id=?', (sample_id,)).fetchone()
            if existing:
                if existing['discarded'] or existing['writer_id'] != writer or existing['prompt_index'] != index or existing['ink_sha256'] != digest:
                    raise CollectionError('sample_conflict', 409)
                return {'savedExpected': expected, 'created': False, 'session': self.session(writer, db)}
            current = self.session(writer, db)
            if current['promptIndex'] != index:
                raise CollectionError('stale_prompt', 409)
            if current['totalSaved'] >= 5000:
                raise CollectionError('collection_full', 429)
            db.execute('INSERT OR IGNORE INTO writers(id,next_index) VALUES (?,0)', (writer,))
            db.execute('INSERT INTO samples(id,writer_id,prompt_index,expected,strokes,ink_sha256,png,metadata,created) VALUES (?,?,?,?,?,?,?,?,?)', (sample_id, writer, index, expected, encoded, digest, png, json.dumps(metadata), datetime.now(timezone.utc).isoformat()))
            db.execute('UPDATE writers SET next_index=? WHERE id=?', (index + 1, writer))
            return {'savedExpected': expected, 'created': True, 'session': self.session(writer, db)}

    def undo(self, data):
        if not isinstance(data, dict):
            raise CollectionError('invalid_identifier')
        writer, sample_id = identifier(data.get('writerId')), identifier(data.get('id'))
        with self.lock, self.database() as db:
            db.execute('BEGIN IMMEDIATE')
            row = db.execute('SELECT * FROM samples WHERE writer_id=? AND id=?', (writer, sample_id)).fetchone()
            current = self.session(writer, db)
            if row and row['discarded'] and current['promptIndex'] == row['prompt_index']:
                return {'strokes': json.loads(row['strokes']), 'metadata': json.loads(row['metadata']), 'session': current}
            if not row or row['discarded'] or not current['lastSample'] or current['lastSample']['id'] != sample_id or current['promptIndex'] != row['prompt_index'] + 1:
                raise CollectionError('stale_prompt', 409)
            db.execute('UPDATE samples SET discarded=1 WHERE id=?', (sample_id,))
            db.execute('UPDATE writers SET next_index=? WHERE id=?', (row['prompt_index'], writer))
            return {'strokes': json.loads(row['strokes']), 'metadata': json.loads(row['metadata']), 'session': self.session(writer, db)}

    def export(self):
        output = tempfile.SpooledTemporaryFile(max_size=1_048_576)
        try:
            manifest = []
            with self.database() as db, zipfile.ZipFile(output, 'w', compression=zipfile.ZIP_DEFLATED) as archive:
                for row in db.execute('SELECT * FROM samples WHERE discarded=0 ORDER BY writer_id,prompt_index'):
                    image_file = f"images/{row['id']}.png"
                    stroke_file = f"strokes/{row['id']}.json"
                    archive.writestr(image_file, row['png'])
                    archive.writestr(stroke_file, json.dumps({'strokes': json.loads(row['strokes']), 'metadata': json.loads(row['metadata'])}))
                    manifest.append({'id': row['id'], 'file': image_file, 'expected': row['expected'], 'split': 'unreviewed', 'independent': False, 'reservedFor': 'holdout', 'writer': row['writer_id'], 'userSample': False, 'rawStrokes': stroke_file, 'created': row['created'], 'imageSHA256': hashlib.sha256(row['png']).hexdigest(), 'labelProvenance': 'Prompted score confirmed by the contributor, not a model prediction'})
                archive.writestr('manifest.json', json.dumps(manifest, indent=2))
                archive.writestr('provenance.json', json.dumps({'created': datetime.now(timezone.utc).isoformat(), 'samples': len(manifest), 'writers': len({row['writer'] for row in manifest}), 'modelCallsDuringCollection': 0, 'writerIdentity': 'Anonymous identifiers selected by contributors, not verified personal identities', 'validation': 'This is a frozen collection snapshot and labels still need review before evaluation'}, indent=2))
            output.seek(0, 2)
            size = output.tell()
            output.seek(0)
            return output, size
        except Exception:
            output.close()
            raise
