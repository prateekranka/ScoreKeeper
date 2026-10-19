from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from threading import BoundedSemaphore
from urllib.parse import urlparse, parse_qs
from datetime import datetime, timezone
import argparse
import json
import os
import secrets
import sqlite3
from recognise import DigitRecognizer, MODEL_SHA256, APPLE_MODEL_SHA256, VERSION, SOURCE_SHA256
from jev import JevDecisions, JevError
from handwriting import HandwritingStore, CollectionError


ROOT = Path(__file__).resolve().parent.parent
RECOGNISER = DigitRecognizer()
READERS = BoundedSemaphore(1)
PUBLIC_ORIGIN = os.environ.get('PIPCOUNT_PUBLIC_ORIGIN', '').rstrip('/')
PUBLIC_URL = urlparse(PUBLIC_ORIGIN)
if PUBLIC_ORIGIN and (PUBLIC_URL.scheme not in {'http', 'https'} or not PUBLIC_URL.hostname or PUBLIC_URL.username or PUBLIC_URL.password or PUBLIC_URL.path or PUBLIC_URL.query or PUBLIC_URL.fragment):
    raise ValueError('PIPCOUNT_PUBLIC_ORIGIN must be one HTTP or HTTPS origin')
ALLOWED_HOSTS = {'127.0.0.1', 'localhost'} | ({PUBLIC_URL.hostname} if PUBLIC_ORIGIN else set())


class PreviewHandler(SimpleHTTPRequestHandler):
    recogniser = RECOGNISER
    jev = JevDecisions()
    csrf_token = secrets.token_urlsafe(32)
    handwriting = HandwritingStore()

    def setup(self):
        super().setup()
        self.connection.settimeout(15)

    def end_headers(self):
        if self.path.startswith('/api/') or self.path.split('?')[0] in {'/', '/setup/jev', '/handwriting', '/handwriting/'}:
            self.send_header('Cache-Control', 'no-store')
        self.send_header('X-Content-Type-Options', 'nosniff')
        self.send_header('Referrer-Policy', 'no-referrer')
        self.send_header('Content-Security-Policy', "frame-ancestors 'none'")
        super().end_headers()

    def reply(self, code, value):
        body = json.dumps(value).encode()
        self.send_response(code)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Length', str(len(body)))
        self.end_headers()
        try:
            self.wfile.write(body)
        except (BrokenPipeError, ConnectionResetError):
            pass

    def do_GET(self):
        path = urlparse(self.path).path
        if path.startswith('/api/handwriting/'):
            if not self.known_host():
                self.reply(403, {'status': 'error'})
                return
            try:
                if path == '/api/handwriting/session':
                    writer = parse_qs(urlparse(self.path).query).get('writer', [''])[0]
                    self.reply(200, {**self.handwriting.session(writer), 'csrfToken': self.csrf_token})
                elif path == '/api/handwriting/export':
                    output, size = self.handwriting.export()
                    with output:
                        self.send_response(200)
                        self.send_header('Content-Type', 'application/zip')
                        name = datetime.now(timezone.utc).strftime('pipcount-handwriting-%Y%m%dT%H%M%SZ.zip')
                        self.send_header('Content-Disposition', f'attachment; filename="{name}"')
                        self.send_header('Content-Length', str(size))
                        self.end_headers()
                        while chunk := output.read(65536):
                            self.wfile.write(chunk)
                else:
                    self.reply(404, {'status': 'error'})
            except CollectionError as problem:
                self.reply(problem.status, {'status': 'error', 'reason': problem.code})
            except (BrokenPipeError, ConnectionResetError):
                pass
            except (OSError, ValueError, sqlite3.Error):
                self.reply(503, {'status': 'error', 'reason': 'storage_unavailable'})
        elif path == '/api/jev/status':
            if not self.known_host():
                self.reply(403, {'status': 'error'})
                return
            self.reply(200, {**self.jev.status(), 'csrfToken': self.csrf_token})
        elif path == '/api/recogniser':
            self.reply(200, {'recogniser': VERSION, 'implementationSHA256': SOURCE_SHA256, 'modelSHA256': MODEL_SHA256, 'appleModelSHA256': APPLE_MODEL_SHA256})
        else:
            if path in {'/setup/jev', '/handwriting', '/handwriting/'}:
                self.path = '/index.html'
            super().do_GET()

    def known_host(self):
        return urlparse('http://' + self.headers.get('Host', '')).hostname in ALLOWED_HOSTS

    def same_origin(self):
        origin = self.headers.get('Origin')
        return bool(origin and ((PUBLIC_ORIGIN and origin == PUBLIC_ORIGIN) or (urlparse(origin).scheme in {'http', 'https'} and urlparse(origin).netloc == self.headers.get('Host'))))

    def connect_jev(self):
        if not self.known_host() or not self.same_origin() or not secrets.compare_digest(self.headers.get('X-Pipcount-CSRF', '').encode(), self.csrf_token.encode()):
            self.reply(403, {'status': 'error', 'reason': 'forbidden'})
            return
        try:
            length = int(self.headers.get('Content-Length', '0'))
        except ValueError:
            length = 0
        if not 0 < length <= 2048 or self.headers.get('Content-Type') != 'application/json':
            self.reply(400, {'status': 'error', 'reason': 'invalid_key'})
            return
        try:
            payload = json.loads(self.rfile.read(length))
            result = self.jev.connect(payload.get('apiKey') if isinstance(payload, dict) else None)
            self.reply(200, result)
        except JevError as problem:
            self.reply(400 if problem.code in {'invalid_key', 'authentication'} else 503, {'status': 'error', 'reason': problem.code})
        except (ValueError, OSError):
            self.reply(503, {'status': 'error', 'reason': 'unavailable'})

    def do_POST(self):
        endpoint = urlparse(self.path).path
        if endpoint in {'/api/handwriting/samples', '/api/handwriting/undo'}:
            if not self.known_host() or not self.same_origin() or not secrets.compare_digest(self.headers.get('X-Pipcount-CSRF', '').encode(), self.csrf_token.encode()):
                self.reply(403, {'status': 'error', 'reason': 'forbidden'})
                return
            try:
                length = int(self.headers.get('Content-Length', '0'))
                if not 0 < length <= 1_048_576 or self.headers.get('Content-Type') != 'application/json':
                    raise CollectionError('invalid_drawing')
                payload = json.loads(self.rfile.read(length))
                result = self.handwriting.save(payload) if endpoint.endswith('/samples') else self.handwriting.undo(payload)
                self.reply(200, result)
            except CollectionError as problem:
                self.reply(problem.status, {'status': 'error', 'reason': problem.code})
            except (ValueError, UnicodeDecodeError):
                self.reply(400, {'status': 'error', 'reason': 'invalid_drawing'})
            except (OSError, sqlite3.Error):
                self.reply(503, {'status': 'error', 'reason': 'storage_unavailable'})
            return
        if urlparse(self.path).path == '/api/jev/connect':
            self.connect_jev()
            return
        if urlparse(self.path).path != '/api/recognise':
            self.reply(404, {'status': 'error'})
            return
        origin = self.headers.get('Origin')
        if not self.known_host() or (origin and not self.same_origin()):
            self.reply(403, {'status': 'error'})
            return
        try:
            length = int(self.headers.get('Content-Length', '0'))
        except ValueError:
            length = 0
        if not 0 < length <= 1_048_576 or self.headers.get('Content-Type') != 'image/png':
            self.reply(400, {'status': 'unreadable'})
            return
        payload = self.rfile.read(length)
        if not payload.startswith(b'\x89PNG\r\n\x1a\n'):
            self.reply(400, {'status': 'unreadable'})
            return
        if not READERS.acquire(timeout=5):
            self.reply(503, {'status': 'error'})
            return
        try:
            result = self.jev.recognise(payload, self.recogniser.recognise(payload))
            self.reply(200, {**result, 'recogniser': VERSION})
        except (OSError, RuntimeError, ValueError):
            self.reply(503, {'status': 'error'})
        finally:
            READERS.release()


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--port', type=int, default=4180)
    args = parser.parse_args()
    handler = partial(PreviewHandler, directory=str(ROOT / 'dist'))
    server = ThreadingHTTPServer(('127.0.0.1', args.port), handler)
    print(f'PipCount preview is listening on 127.0.0.1:{args.port}', flush=True)
    server.serve_forever()
