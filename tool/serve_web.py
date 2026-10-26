"""Serve app/build/web like a production SPA host: real files as-is, app
routes (paths without a file extension) rewritten to index.html, so deep links
like /inspections/INS-1042 survive a browser refresh. A missing asset
(main.dart.js, sqlite3.wasm, …) is a 404, not index.html served as that file.

Usage: python tool/serve_web.py [port] [build dir] [--isolate]
  port       default 5173
  build dir  relative to app/, default build/web (e.g. build/web-wasm)
  --isolate  send COOP/COEP headers so the page is cross-origin isolated and
             the WebAssembly renderer (skwasm) can use worker threads

Listens on 127.0.0.1 only.
"""
import http.server
import pathlib
import sys
import urllib.parse

ARGS = [a for a in sys.argv[1:] if not a.startswith('--')]
ISOLATE = '--isolate' in sys.argv
ROOT = pathlib.Path(__file__).resolve().parent.parent / 'app' / (ARGS[1] if len(ARGS) > 1 else 'build/web')


class SpaHandler(http.server.SimpleHTTPRequestHandler):
    # The Windows registry often lacks these; browsers refuse modules and
    # streaming wasm compilation served as text/plain.
    extensions_map = {
        **http.server.SimpleHTTPRequestHandler.extensions_map,
        '.mjs': 'text/javascript',
        '.js': 'text/javascript',
        '.wasm': 'application/wasm',
        '.json': 'application/json',
    }

    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(ROOT), **kwargs)

    def send_head(self):
        path = self.path.split('?', 1)[0].split('#', 1)[0]
        # translate_path decodes %-escapes and keeps the result inside ROOT
        # (it drops '..', drive letters and other non-name segments), so the
        # check never looks at files outside the build.
        if not pathlib.Path(self.translate_path(path)).is_file():
            name = urllib.parse.unquote(path).rstrip('/').rsplit('/', 1)[-1]
            if '.' in name:
                self.send_error(404, 'File not found')
                return None
            self.path = '/index.html'
        return super().send_head()

    def end_headers(self):
        # Always revalidate: a fresh build must never mix with cached files.
        self.send_header('Cache-Control', 'no-cache')
        if ISOLATE:
            self.send_header('Cross-Origin-Opener-Policy', 'same-origin')
            # credentialless (not require-corp) keeps cross-origin map tiles loading.
            self.send_header('Cross-Origin-Embedder-Policy', 'credentialless')
        super().end_headers()


if __name__ == '__main__':
    if not (ROOT / 'index.html').is_file():
        sys.exit(f'No web build in {ROOT}: run `fvm flutter build web` in app/ first.')
    port = int(ARGS[0]) if ARGS else 5173
    print(f'Serving {ROOT} on http://localhost:{port}' + (' (cross-origin isolated)' if ISOLATE else ''))
    http.server.ThreadingHTTPServer(('127.0.0.1', port), SpaHandler).serve_forever()
