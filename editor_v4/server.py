import http.server
import json
import os
import sys
import time
import shutil
import glob

# 兼容 pythonw.exe 无控制台运行（防止 NoneType.write 崩溃）
if sys.stdout is None:
    sys.stdout = open(os.devnull, 'w')
if sys.stderr is None:
    sys.stderr = open(os.devnull, 'w')

PORT = 8098
ROOT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
EDITOR_DIR = os.path.abspath(os.path.dirname(__file__))

if EDITOR_DIR not in sys.path:
    sys.path.insert(0, EDITOR_DIR)

try:
    import adb_sync
except Exception:
    adb_sync = None

CONFIG_PATH_V4 = os.path.join(ROOT_DIR, "Q", "battle_v4_config.q")
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

    def log_message(self, format, *args):
        try:
            if sys.stderr:
                sys.stderr.write("%s - - [%s] %s\n" % (self.address_string(), self.log_date_time_string(), format % args))
        except Exception:
            pass

    def end_headers(self):
        self.send_header('Cache-Control', 'no-cache, no-store, must-revalidate')
        self.send_header('Pragma', 'no-cache')
        self.send_header('Expires', '0')
        super().end_headers()

    def do_GET(self):
        if self.path.startswith('/api/config'):
            target_path = CONFIG_PATH_V4

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
        elif self.path.startswith('/api/adb/status'):
            if adb_sync:
                try:
                    status = adb_sync.get_adb_status()
                except Exception as e:
                    status = {"available": False, "connected": False, "message": str(e)}
            else:
                status = {"available": False, "connected": False, "message": "adb_sync 模块未加载"}
            self.send_response(200)
            self.send_header('Content-Type', 'application/json; charset=utf-8')
            self.send_header('Cache-Control', 'no-cache')
            self.end_headers()
            self.wfile.write(json.dumps(status).encode('utf-8'))
            return
        elif self.path.startswith('/api/open-browser'):
            import webbrowser
            webbrowser.open(f"http://127.0.0.1:{PORT}")
            self.send_response(200)
            self.send_header('Content-Type', 'application/json; charset=utf-8')
            self.send_header('Cache-Control', 'no-cache')
            self.end_headers()
            self.wfile.write(json.dumps({'success': True}).encode('utf-8'))
            return
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
        elif self.path.startswith('/api/sync'):
            length = int(self.headers.get('Content-Length', 0))
            body = self.rfile.read(length).decode('utf-8') if length > 0 else ""
            text = ""
            if body:
                try:
                    text = json.loads(body).get('text', '')
                except Exception:
                    pass

            # 若传入了最新配置文本，同时落盘保存本地代码仓库 Q/battle_v4_config.q（带历史快照）
            if text:
                try:
                    backup_config(CONFIG_PATH_V4)
                    os.makedirs(os.path.dirname(CONFIG_PATH_V4), exist_ok=True)
                    with open(CONFIG_PATH_V4, 'w', encoding='utf-8') as f:
                        f.write(text)
                except Exception as e:
                    print(f"[Warning] Failed to save repo config in /api/sync: {e}", file=sys.stderr)
            elif not text and os.path.exists(CONFIG_PATH_V4):
                with open(CONFIG_PATH_V4, 'r', encoding='utf-8') as f:
                    text = f.read()

            try:
                import adb_sync
                res = adb_sync.push_config_to_simulator(text)
            except Exception as e:
                res = {"success": False, "connected": False, "message": str(e)}

            self.send_response(200)
            self.send_header('Content-Type', 'application/json; charset=utf-8')
            self.send_header('Cache-Control', 'no-cache')
            self.end_headers()
            self.wfile.write(json.dumps(res).encode('utf-8'))
            return
        elif self.path.startswith('/api/save'):
            length = int(self.headers.get('Content-Length', 0))
            body = self.rfile.read(length).decode('utf-8')
            try:
                data = json.loads(body)
                text = data.get('text', '')

                # 优先保存到 V4 配置
                target_path = CONFIG_PATH_V4

                # 备份历史文件
                backup_path = backup_config(target_path)

                os.makedirs(os.path.dirname(target_path), exist_ok=True)
                with open(target_path, 'w', encoding='utf-8') as f:
                    f.write(text)

                # 阶段一：自动下发至模拟器与手机助手
                adb_res = None
                try:
                    import adb_sync
                    adb_res = adb_sync.push_config_to_simulator(text)
                except Exception as e:
                    adb_res = {
                        "success": False,
                        "connected": False,
                        "message": f"直推模拟器异常: {str(e)}"
                    }

                self.send_response(200)
                self.send_header('Content-Type', 'application/json; charset=utf-8')
                self.end_headers()
                self.wfile.write(json.dumps({
                    'success': True,
                    'path': target_path,
                    'backup': backup_path,
                    'adb': adb_res
                }).encode('utf-8'))
            except Exception as e:
                self.send_response(500)
                self.send_header('Content-Type', 'application/json; charset=utf-8')
                self.end_headers()
                self.wfile.write(json.dumps({'success': False, 'message': str(e)}).encode('utf-8'))
        else:
            self.send_response(404)
            self.end_headers()


def create_server(host='127.0.0.1', port=PORT):
    return http.server.ThreadingHTTPServer((host, port), ConfigEditorHandler)

def start_server_thread(host='127.0.0.1', port=PORT):
    server = create_server(host, port)
    import threading
    t = threading.Thread(target=server.serve_forever, daemon=True)
    t.start()
    return server

if __name__ == '__main__':
    server = create_server('0.0.0.0', PORT)
    print(f"FGO Q Editor Server running on port {PORT}...", flush=True)
    server.serve_forever()
