import http.server
import json
import os
import sys

PORT = 8099
ROOT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
EDITOR_DIR = os.path.abspath(os.path.dirname(__file__))

CONFIG_PATH_V3 = os.path.join(ROOT_DIR, "Q", "battle_v3_config.q")
CONFIG_PATH_V2 = os.path.join(ROOT_DIR, "Q", "battle_v2_config.q")
CONFIG_PATH_V1 = os.path.join(ROOT_DIR, "Q", "battle_config.q")

class ConfigEditorHandler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=EDITOR_DIR, **kwargs)

    def do_GET(self):
        if self.path.startswith('/api/config'):
            if os.path.exists(CONFIG_PATH_V3):
                target_path = CONFIG_PATH_V3
            elif os.path.exists(CONFIG_PATH_V2):
                target_path = CONFIG_PATH_V2
            else:
                target_path = CONFIG_PATH_V1

            if os.path.exists(target_path):
                with open(target_path, 'r', encoding='utf-8') as f:
                    content = f.read()
                self.send_response(200)
                self.send_header('Content-Type', 'application/json; charset=utf-8')
                self.send_header('Cache-Control', 'no-cache')
                self.end_headers()
                self.wfile.write(json.dumps({'text': content, 'path': target_path}).encode('utf-8'))
            else:
                self.send_response(404)
                self.end_headers()
        elif self.path in ('/', '/index.html'):
            self.path = '/battle_config_editor.html'
            return super().do_GET()
        else:
            return super().do_GET()

    def do_POST(self):
        if self.path.startswith('/api/save'):
            length = int(self.headers.get('Content-Length', 0))
            body = self.rfile.read(length).decode('utf-8')
            data = json.loads(body)
            text = data.get('text', '')
            
            with open(CONFIG_PATH_V3, 'w', encoding='utf-8') as f:
                f.write(text)
                
            self.send_response(200)
            self.send_header('Content-Type', 'application/json; charset=utf-8')
            self.end_headers()
            self.wfile.write(json.dumps({'success': True, 'path': CONFIG_PATH_V3}).encode('utf-8'))
        else:
            self.send_response(404)
            self.end_headers()

if __name__ == '__main__':
    server = http.server.ThreadingHTTPServer(('0.0.0.0', PORT), ConfigEditorHandler)
    print(f"FGO Q Editor Server running on port {PORT}...", flush=True)
    server.serve_forever()
