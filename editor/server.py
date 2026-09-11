import http.server
import json
import os
import sys
import time
import shutil
import glob

PORT = 8099
ROOT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
EDITOR_DIR = os.path.abspath(os.path.dirname(__file__))

CONFIG_PATH_V3 = os.path.join(ROOT_DIR, "Q", "battle_v3_config.q")
CONFIG_PATH_V2 = os.path.join(ROOT_DIR, "Q", "battle_v2_config.q")
CONFIG_PATH_V1 = os.path.join(ROOT_DIR, "Q", "battle_config.q")
BACKUP_DIR = os.path.join(ROOT_DIR, "Q", ".backup")
MAX_BACKUPS = 10


def backup_config(target_path):
    """保存前自动备份源配置文件，最多保留 MAX_BACKUPS 份历史快照"""
    if not os.path.exists(target_path):
        return None
    try:
        os.makedirs(BACKUP_DIR, exist_ok=True)
        timestamp = time.strftime("%Y%m%d_%H%M%S")
        base_name = os.path.basename(target_path)
        backup_name = f"{base_name}.{timestamp}.bak.q"
        backup_path = os.path.join(BACKUP_DIR, backup_name)
        shutil.copy2(target_path, backup_path)

        # 轮转清理：保留最新 MAX_BACKUPS 份
        existing_backups = sorted(
            glob.glob(os.path.join(BACKUP_DIR, f"{base_name}.*.bak.q")),
            key=os.path.getmtime
        )
        while len(existing_backups) > MAX_BACKUPS:
            oldest = existing_backups.pop(0)
            try:
                os.remove(oldest)
            except OSError:
                pass
        return backup_path
    except Exception as e:
        print(f"[Warning] Failed to backup config: {e}", file=sys.stderr)
        return None


class ConfigEditorHandler(http.server.SimpleHTTPRequestHandler):
    extensions_map = {
        **http.server.SimpleHTTPRequestHandler.extensions_map,
        '.js': 'application/javascript; charset=utf-8',
        '.mjs': 'application/javascript; charset=utf-8',
        '.css': 'text/css; charset=utf-8',
        '.json': 'application/json; charset=utf-8',
        '.html': 'text/html; charset=utf-8',
    }

    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=EDITOR_DIR, **kwargs)

    def end_headers(self):
        self.send_header('Cache-Control', 'no-cache, no-store, must-revalidate')
        self.send_header('Pragma', 'no-cache')
        self.send_header('Expires', '0')
        super().end_headers()

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
        elif self.path.startswith('/api/shutdown'):
            self.send_response(200)
            self.send_header('Content-Type', 'text/html; charset=utf-8')
            self.send_header('Cache-Control', 'no-cache')
            self.end_headers()
            self.wfile.write("<h2 style='font-family:sans-serif; text-align:center; margin-top:50px;'>🛑 FGO 配置编辑器服务已停止</h2><p style='text-align:center; color:#666;'>后台进程已退出，8099 端口已释放。您可以安全关闭此窗口。</p>".encode('utf-8'))
            import threading
            def _stop():
                time.sleep(0.3)
                print("[Server] GET /api/shutdown received. Exiting...", flush=True)
                os._exit(0)
            threading.Thread(target=_stop, daemon=True).start()
            return
        elif self.path in ('/favicon.ico', '/icons/fgo_editor.ico'):
            icon_path = os.path.join(EDITOR_DIR, "icons", "fgo_editor.ico")
            if os.path.exists(icon_path):
                with open(icon_path, 'rb') as f:
                    content = f.read()
                self.send_response(200)
                self.send_header('Content-Type', 'image/x-icon')
                self.send_header('Cache-Control', 'public, max-age=86400')
                self.end_headers()
                self.wfile.write(content)
                return
            else:
                self.send_response(404)
                self.end_headers()
        elif self.path in ('/', '/index.html'):
            self.path = '/battle_config_editor.html'
            return super().do_GET()
        else:
            return super().do_GET()

    def do_POST(self):
        if self.path.startswith('/api/shutdown'):
            self.send_response(200)
            self.send_header('Content-Type', 'application/json; charset=utf-8')
            self.send_header('Cache-Control', 'no-cache')
            self.end_headers()
            self.wfile.write(json.dumps({'success': True, 'message': 'Server stopped'}).encode('utf-8'))
            import threading
            def _stop():
                time.sleep(0.3)
                print("[Server] POST /api/shutdown received. Exiting...", flush=True)
                os._exit(0)
            threading.Thread(target=_stop, daemon=True).start()
            return
        elif self.path.startswith('/api/save'):
            length = int(self.headers.get('Content-Length', 0))
            body = self.rfile.read(length).decode('utf-8')
            try:
                data = json.loads(body)
                text = data.get('text', '')

                # 备份历史文件
                backup_path = backup_config(CONFIG_PATH_V3)

                os.makedirs(os.path.dirname(CONFIG_PATH_V3), exist_ok=True)
                with open(CONFIG_PATH_V3, 'w', encoding='utf-8') as f:
                    f.write(text)

                self.send_response(200)
                self.send_header('Content-Type', 'application/json; charset=utf-8')
                self.end_headers()
                self.wfile.write(json.dumps({
                    'success': True,
                    'path': CONFIG_PATH_V3,
                    'backup': backup_path
                }).encode('utf-8'))
            except Exception as e:
                self.send_response(500)
                self.send_header('Content-Type', 'application/json; charset=utf-8')
                self.end_headers()
                self.wfile.write(json.dumps({'success': False, 'message': str(e)}).encode('utf-8'))
        else:
            self.send_response(404)
            self.end_headers()


if __name__ == '__main__':
    server = http.server.ThreadingHTTPServer(('0.0.0.0', PORT), ConfigEditorHandler)
    print(f"FGO Q Editor Server running on port {PORT}...", flush=True)
    server.serve_forever()
