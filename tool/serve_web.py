"""Serve app/build/web like a production SPA host: real files as-is, every
other path rewritten to index.html, so deep links like /inspections/INS-1042
survive a browser refresh.

Usage: python tool/serve_web.py [port]   (default 5173)
"""
import http.server
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent / 'app' / 'build' / 'web'


class SpaHandler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(ROOT), **kwargs)

    def send_head(self):
        path = self.path.split('?', 1)[0].split('#', 1)[0]
        if not (ROOT / path.lstrip('/')).is_file():
            self.path = '/index.html'
        return super().send_head()


if __name__ == '__main__':
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 5173
    print(f'Serving {ROOT} on http://localhost:{port}')
    http.server.ThreadingHTTPServer(('127.0.0.1', port), SpaHandler).serve_forever()
