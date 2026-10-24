"""Serve app/build/web like a production SPA host: real files as-is, every
other path rewritten to index.html, so deep links like /inspections/INS-1042
survive a browser refresh.

Usage: python tool/serve_web.py [port] [build dir] [--isolate]
  port       default 5173
  build dir  relative to app/, default build/web (e.g. build/web-wasm)
  --isolate  send COOP/COEP headers so the page is cross-origin isolated and
             the WebAssembly renderer (skwasm) can use worker threads
"""
import http.server
import pathlib
import sys

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
        if not (ROOT / path.lstrip('/')).is_file():
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
    port = int(ARGS[0]) if ARGS else 5173
    print(f'Serving {ROOT} on http://localhost:{port}' + (' (cross-origin isolated)' if ISOLATE else ''))
    http.server.ThreadingHTTPServer(('127.0.0.1', port), SpaHandler).serve_forever()
