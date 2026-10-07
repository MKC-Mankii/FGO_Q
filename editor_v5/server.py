import http.server
import json
import os
import sys
import time
import shutil
import glob
import logging
from logging.handlers import RotatingFileHandler

# 兼容 pythonw.exe 无控制台运行（防止 NoneType.write 崩溃）及 Windows 控制台 UTF-8 支持
if sys.stdout is None:
    sys.stdout = open(os.devnull, 'w', encoding='utf-8')
elif hasattr(sys.stdout, 'reconfigure'):
    try:
        sys.stdout.reconfigure(encoding='utf-8', errors='replace')
    except Exception:
        pass

if sys.stderr is None:
    sys.stderr = open(os.devnull, 'w', encoding='utf-8')
elif hasattr(sys.stderr, 'reconfigure'):
    try:
        sys.stderr.reconfigure(encoding='utf-8', errors='replace')
    except Exception:
        pass

PORT = 8099

# 默认隔离 ADB 端口（避免与 MuMu/MFA 等占用 5037 默认端口的其他项目发生 kill-server 冲突）
DEFAULT_ADB_PORT = os.environ.get("ANDROID_ADB_SERVER_PORT", "5038")
if "ANDROID_ADB_SERVER_PORT" not in os.environ:
    os.environ["ANDROID_ADB_SERVER_PORT"] = DEFAULT_ADB_PORT
if "ADB_SERVER_SOCKET" not in os.environ:
    os.environ["ADB_SERVER_SOCKET"] = f"tcp:localhost:{DEFAULT_ADB_PORT}"

ROOT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
EDITOR_DIR = os.path.abspath(os.path.dirname(__file__))
LOG_DIR = os.path.join(EDITOR_DIR, "logs")
os.makedirs(LOG_DIR, exist_ok=True)
LOG_FILE = os.path.join(LOG_DIR, "editor.log")

# 配置 Editor 本地滚动日志系统
logger = logging.getLogger("editor")
logger.setLevel(logging.INFO)

if not logger.handlers:
    # 轮转日志：每个文件上限 5MB，最多保留 5 份历史文件，全局 UTF-8
    file_handler = RotatingFileHandler(
        LOG_FILE, maxBytes=5 * 1024 * 1024, backupCount=5, encoding="utf-8"
    )
    file_formatter = logging.Formatter(
        "[%(asctime)s] [%(levelname)s] %(message)s", datefmt="%Y-%m-%d %H:%M:%S"
    )
    file_handler.setFormatter(file_formatter)
    logger.addHandler(file_handler)

    if sys.stdout is not None:
        try:
            console_handler = logging.StreamHandler(sys.stdout)
            console_handler.setFormatter(file_formatter)
            logger.addHandler(console_handler)
        except Exception:
            pass

if EDITOR_DIR not in sys.path:
    sys.path.insert(0, EDITOR_DIR)

try:
    import adb_sync
except Exception as e:
    adb_sync = None
    logger.warning(f"Failed to import adb_sync module: {e}")

_adb_sync_mtime = 0

def check_and_reload_adb_sync():
    global adb_sync, _adb_sync_mtime
    sync_file = os.path.join(EDITOR_DIR, "adb_sync.py")
    if os.path.isfile(sync_file):
        try:
            mtime = os.path.getmtime(sync_file)
            if mtime > _adb_sync_mtime:
                import importlib
                if adb_sync is not None:
                    adb_sync = importlib.reload(adb_sync)
                else:
                    import adb_sync
                _adb_sync_mtime = mtime
        except Exception as e:
            logger.warning(f"Failed to reload adb_sync: {e}")


try:
    import calibration
    cal_engine = calibration.CalibrationEngine(EDITOR_DIR)
except Exception as e:
    cal_engine = None
    logger.warning(f"Failed to import calibration module: {e}")

CONFIG_PATH_V5 = os.path.join(ROOT_DIR, "Q", "battle_v5_config.q")
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
        logger.info(f"[Backup] 历史快照已创建: {backup_name}")

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
        logger.warning(f"[Backup] 备份配置失败: {e}")
        return None


def ensure_targets_in_config(text, current_config_path=CONFIG_PATH_V5):
    """确保待保存或下发的配置文本包含屏幕标定与视觉目标配置块，避免被意外覆盖剥离"""
    if not text or "TARGETS & COORDINATES CONFIG" in text or not os.path.isfile(current_config_path):
        return text
    try:
        with open(current_config_path, "r", encoding="utf-8") as f:
            old_text = f.read()
        m_pos = old_text.find("TARGETS & COORDINATES CONFIG")
        if m_pos != -1:
            c_pos = old_text.rfind("'", 0, m_pos)
            prev_text = old_text[:c_pos].rstrip()
            last_line_start = prev_text.rfind('\n')
            last_line = (prev_text[last_line_start + 1:] if last_line_start != -1 else prev_text).strip()
            if last_line.startswith("'") and ("===" in last_line or "---" in last_line):
                c_pos = last_line_start + 1 if last_line_start != -1 else 0
            return text.rstrip() + "\n\n" + old_text[c_pos if c_pos != -1 else m_pos:].strip() + "\n"
    except Exception as e:
        logger.warning(f"Failed to preserve targets config section: {e}")
    if "ENHANCE_SKILL_HERO_UNSELECTED_TAR" not in text:
        tar_line = 'Dim ENHANCE_SKILL_HERO_UNSELECTED_TAR = Array(140, 560, 300, 630, "Attachment:ENHANCE_SKILL_HERO_UNSELECTED.png")'
        if "Dim TAP_ENHANCE_SKILL_3 = Array(1172, 286)" in text:
            text = text.replace("Dim TAP_ENHANCE_SKILL_3 = Array(1172, 286)", "Dim TAP_ENHANCE_SKILL_3 = Array(1172, 286)\n" + tar_line)
        elif "TAP_ENHANCE_SKILL_3" in text:
            import re
            text = re.sub(r'(Dim\s+TAP_ENHANCE_SKILL_3\s*=[^\r\n]*)', r'\1\n' + tar_line, text)
        else:
            text = text.rstrip() + "\n" + tar_line + "\n"
    return text


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
        # 过滤轮询心跳请求，避免日志被每秒的状态探测刷屏
        path = getattr(self, 'path', '')
        if '/api/runner/status' in path or '/api/adb/status' in path:
            return
        logger.info(f"{self.address_string()} - {format % args}")

    def end_headers(self):
        self.send_header('Cache-Control', 'no-cache, no-store, must-revalidate')
        self.send_header('Pragma', 'no-cache')
        self.send_header('Expires', '0')
        super().end_headers()

    def do_GET(self):
        check_and_reload_adb_sync()

        if self.path.startswith('/api/config'):
            target_path = CONFIG_PATH_V5

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
        elif self.path.startswith('/api/sync/images'):
            target_dev = None
            if 'device=' in self.path:
                target_dev = self.path.split('device=')[1].split('&')[0]
            if adb_sync:
                res = adb_sync.sync_images_to_simulator(device=target_dev)
            else:
                res = {"success": False, "connected": False, "message": "adb_sync 模块未就绪"}
            self.send_response(200)
            self.send_header('Content-Type', 'application/json; charset=utf-8')
            self.send_header('Cache-Control', 'no-cache')
            self.end_headers()
            self.wfile.write(json.dumps(res, ensure_ascii=False).encode('utf-8'))
            return
        elif self.path.startswith('/api/adb/status'):
            force = ("refresh=1" in self.path or "force=1" in self.path)
            if adb_sync:
                try:
                    status = adb_sync.get_adb_status(force_refresh=force)
                except Exception as e:
                    status = {"available": False, "connected": False, "message": str(e)}
            else:
                status = {"available": False, "connected": False, "message": "adb_sync 模块未加载"}
            self.send_response(200)
            self.send_header('Content-Type', 'application/json; charset=utf-8')
            self.send_header('Cache-Control', 'no-cache')
            self.end_headers()
            self.wfile.write(json.dumps(status, ensure_ascii=False).encode('utf-8'))
            return
        elif self.path.startswith('/api/runner/status'):
            if adb_sync:
                try:
                    status = adb_sync.get_runner_status()
                    if hasattr(adb_sync, 'get_ready_env_progress'):
                        status['ready_progress'] = adb_sync.get_ready_env_progress()
                except Exception as e:
                    status = {"available": False, "connected": False, "alive": False, "state": "OFFLINE", "message": str(e)}
            else:
                status = {"available": False, "connected": False, "alive": False, "state": "OFFLINE", "message": "adb_sync 模块未加载"}
            self.send_response(200)
            self.send_header('Content-Type', 'application/json; charset=utf-8')
            self.send_header('Cache-Control', 'no-cache')
            self.end_headers()
            self.wfile.write(json.dumps(status, ensure_ascii=False).encode('utf-8'))
            return
        elif self.path.startswith('/api/runner/launch'):
            if adb_sync:
                try:
                    force_re = ("restart=1" in self.path or "force=1" in self.path)
                    res = adb_sync.launch_runner(wait_ready=True, force_restart=force_re)
                except Exception as e:
                    res = {"success": False, "connected": False, "message": str(e)}
            else:
                res = {"success": False, "connected": False, "message": "adb_sync 模块未加载"}
            self.send_response(200)
            self.send_header('Content-Type', 'application/json; charset=utf-8')
            self.send_header('Cache-Control', 'no-cache')
            self.end_headers()
            self.wfile.write(json.dumps(res, ensure_ascii=False).encode('utf-8'))
            return
        elif self.path.startswith('/api/fgo/navigate_home'):
            if adb_sync:
                try:
                    target_dev = adb_sync.get_selected_device() if hasattr(adb_sync, 'get_selected_device') else None
                    res = adb_sync.navigate_fgo_to_home(device=target_dev, max_wait_sec=115)
                except Exception as e:
                    res = {"success": False, "connected": False, "message": str(e)}
            else:
                res = {"success": False, "connected": False, "message": "adb_sync 模块未加载"}
            self.send_response(200)
            self.send_header('Content-Type', 'application/json; charset=utf-8')
            self.send_header('Cache-Control', 'no-cache')
            self.end_headers()
            self.wfile.write(json.dumps(res, ensure_ascii=False).encode('utf-8'))
            return
        elif self.path.startswith('/api/runner/ready_status'):
            progress = adb_sync.get_ready_env_progress() if (adb_sync and hasattr(adb_sync, 'get_ready_env_progress')) else {}
            self.send_response(200)
            self.send_header('Content-Type', 'application/json; charset=utf-8')
            self.send_header('Cache-Control', 'no-cache')
            self.end_headers()
            self.wfile.write(json.dumps(progress, ensure_ascii=False).encode('utf-8'))
            return
        elif self.path.startswith('/api/runner/ready_env'):
            if adb_sync:
                try:
                    target_dev = adb_sync.get_selected_device() if hasattr(adb_sync, 'get_selected_device') else None
                    force_re = ("restart=1" in self.path or "force=1" in self.path)
                    logger.info(f"[API] 收到 GET /api/runner/ready_env (device={target_dev}, restart={force_re})")
                    res = adb_sync.ready_environment(device=target_dev, force_restart=force_re)
                    logger.info(f"[API] GET ready_env 执行完成: {res.get('message')}")
                except Exception as e:
                    logger.error(f"[API] GET ready_env 异常: {e}")
                    res = {"success": False, "connected": False, "message": str(e)}
            else:
                res = {"success": False, "connected": False, "message": "adb_sync 模块未加载"}
            self.send_response(200)
            self.send_header('Content-Type', 'application/json; charset=utf-8')
            self.send_header('Cache-Control', 'no-cache')
            self.end_headers()
            self.wfile.write(json.dumps(res, ensure_ascii=False).encode('utf-8'))
            return
        elif self.path.startswith('/api/calibrate/targets'):
            if cal_engine:
                try:
                    res = cal_engine.get_targets_manifest()
                except Exception as e:
                    res = {"targets": [], "error": str(e)}
            else:
                res = {"targets": [], "error": "Calibration engine not loaded"}
            self.send_response(200)
            self.send_header('Content-Type', 'application/json; charset=utf-8')
            self.send_header('Cache-Control', 'no-cache')
            self.end_headers()
            self.wfile.write(json.dumps(res, ensure_ascii=False).encode('utf-8'))
            return
        elif self.path.startswith('/api/calibrate/screen'):
            dev = None
            if '?' in self.path:
                from urllib.parse import parse_qs, urlparse
                qs = parse_qs(urlparse(self.path).query)
                dev = qs.get('device', [None])[0]

            if cal_engine and adb_sync:
                try:
                    target_dev = dev or (adb_sync.get_selected_device() if hasattr(adb_sync, 'get_selected_device') else None)
                    raw_bytes = cal_engine.capture_screen_raw(adb_sync, device=target_dev)
                    img = cal_engine.capture_screen_cv2(adb_sync, device=target_dev)
                    vp = cal_engine.detect_viewport(img)
                    import base64
                    b64_data = base64.b64encode(raw_bytes).decode('ascii')
                    res = {
                        "success": True,
                        "device": target_dev,
                        "width": img.shape[1],
                        "height": img.shape[0],
                        "viewport": vp,
                        "image_base64": f"data:image/png;base64,{b64_data}"
                    }
                except Exception as e:
                    logger.warning(f"Screen capture failed: {e}")
                    res = {"success": False, "error": str(e)}
            else:
                res = {"success": False, "error": "adb_sync or cal_engine not available"}
            self.send_response(200)
            self.send_header('Content-Type', 'application/json; charset=utf-8')
            self.send_header('Cache-Control', 'no-cache')
            self.end_headers()
            self.wfile.write(json.dumps(res, ensure_ascii=False).encode('utf-8'))
            return
        elif self.path.startswith('/api/calibrate/image/'):
            fname = self.path[len('/api/calibrate/image/'):].split('?')[0]
            fpath = cal_engine.resolve_image_path(fname) if cal_engine else os.path.join(EDITOR_DIR, "images", fname)
            if fpath and os.path.isfile(fpath):
                with open(fpath, 'rb') as f:
                    data = f.read()
                self.send_response(200)
                self.send_header('Content-Type', 'image/png')
                self.send_header('Cache-Control', 'no-cache')
                self.end_headers()
                self.wfile.write(data)
                return
            else:
                self.send_response(404)
                self.end_headers()
                return
        elif self.path.startswith('/api/extra/detect_scene'):
            target_dev = None
            if 'device=' in self.path:
                target_dev = self.path.split('device=')[1].split('&')[0]
            if not target_dev and adb_sync:
                target_dev = adb_sync.get_selected_device() if hasattr(adb_sync, 'get_selected_device') else None
            
            res = {"success": False, "scene": "unknown", "name": "未连接模拟器", "message": "模拟器未连接"}
            if cal_engine and adb_sync:
                try:
                    screen_mat = cal_engine.capture_screen_cv2(adb_sync, device=target_dev)
                    if screen_mat is None:
                        res = {"success": False, "scene": "unknown", "name": "截屏失败", "message": "无法截取模拟器屏幕，请确认模拟器已开启并在运行"}
                    else:
                        scene_candidates = [
                            ("hero", "从者强化", "ENHANCE_HERO.png", [880, 5, 1300, 70]),
                            ("equip", "礼装强化", "ENHANCE_EQUIP.png", [880, 5, 1300, 70]),
                            ("skill", "技能强化", "ENHANCE_SKILL.png", [880, 5, 1300, 70]),
                            ("friend_pool", "友情点召唤", "POOLFRIEND_CONTINUE.png", [720, 720, 990, 800]),
                            ("roll_100", "无限池抽卡", "ROLL100.png", [330, 370, 620, 610]),
                            ("roll_10", "无限池抽卡", "ROLL10.png", [330, 370, 620, 610]),
                            ("battle", "战斗中", "ATTACK_BTN.png", [1200, 700, 1350, 750])
                        ]
                        matched_scene = None
                        for sc_id, sc_name, img_name, area in scene_candidates:
                            tpl_path = cal_engine.resolve_image_path(img_name)
                            if tpl_path and os.path.exists(tpl_path):
                                m_res = cal_engine.test_match(screen_mat, tpl_path, search_area=area)
                                if m_res and (m_res.get("matched") or m_res.get("similarity", 0) >= 0.8):
                                    matched_scene = (sc_id, sc_name, m_res)
                                    break
                        if matched_scene:
                            sim_val = round(float(matched_scene[2].get("similarity", 0.95)) * 100, 1)
                            res = {
                                "success": True,
                                "scene": matched_scene[0],
                                "name": matched_scene[1],
                                "confidence": matched_scene[2].get("similarity", 0),
                                "message": f"成功识别当前界面：【{matched_scene[1]}】 (匹配度: {sim_val}%)"
                            }
                        else:
                            res = {
                                "success": True,
                                "scene": "unknown",
                                "name": "未识别场景",
                                "message": "当前屏幕未识别到已知的强化或抽卡界面，请在 FGO 内先进入对应界面"
                            }
                except Exception as e:
                    logger.warning(f"[SceneDetector] 探测界面异常: {e}")
                    res = {"success": False, "scene": "error", "name": "探测异常", "message": f"探测异常: {str(e)}"}
            elif not adb_sync:
                res = {"success": False, "scene": "unknown", "name": "未连接", "message": "ADB 同步模块未就绪"}
            elif not cal_engine:
                res = {"success": False, "scene": "unknown", "name": "引擎未载入", "message": "标定引擎未载入"}
            self.send_response(200)
            self.send_header('Content-Type', 'application/json; charset=utf-8')
            self.send_header('Cache-Control', 'no-cache')
            self.end_headers()
            self.wfile.write(json.dumps(res, ensure_ascii=False).encode('utf-8'))
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
        check_and_reload_adb_sync()
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
        elif self.path.startswith('/api/adb/device'):
            length = int(self.headers.get('Content-Length', 0))
            body = self.rfile.read(length).decode('utf-8') if length > 0 else "{}"
            req = {}
            if body:
                try:
                    req = json.loads(body)
                except Exception:
                    pass
            dev = req.get('device')
            if not dev and '?' in self.path:
                from urllib.parse import parse_qs, urlparse
                qs = parse_qs(urlparse(self.path).query)
                dev = qs.get('device', [None])[0]

            res = {"success": False}
            if adb_sync and dev:
                try:
                    adb_sync.set_selected_device(dev)
                    status = adb_sync.get_adb_status()
                    res = {"success": True, "device": dev, "status": status}
                except Exception as e:
                    res = {"success": False, "error": str(e)}
            else:
                res = {"success": False, "error": "未提供有效设备标识或 adb_sync 模块不可用"}

            self.send_response(200)
            self.send_header('Content-Type', 'application/json; charset=utf-8')
            self.send_header('Cache-Control', 'no-cache')
            self.end_headers()
            self.wfile.write(json.dumps(res, ensure_ascii=False).encode('utf-8'))
            return
        elif self.path.startswith('/api/calibrate/save_target'):
            length = int(self.headers.get('Content-Length', 0))
            body = self.rfile.read(length).decode('utf-8') if length > 0 else "{}"
            req = json.loads(body)
            target_key = req.get('target_key')
            rect = req.get('rect') # [x1, y1, x2, y2]
            tap_coord = req.get('tap_coord') # [x, y] or None
            anchor = req.get('anchor', 'center')
            search_area = req.get('search_area') # 可选运行时匹配范围
            req_dev = req.get('device')
            target_file = req.get('file')
            target_name = req.get('name')
            category = req.get('category')
            image_base64 = req.get('image_base64')
            target_dev = req_dev or (adb_sync.get_selected_device() if hasattr(adb_sync, 'get_selected_device') else None)
            
            res = {"success": False}
            if cal_engine and target_key:
                try:
                    # 确定特征图文件名
                    fname = target_file
                    if not fname:
                        manifest = cal_engine.get_targets_manifest()
                        for t in manifest.get('targets', []):
                            if t.get('key') == target_key and t.get('file'):
                                fname = t.get('file')
                                break
                    if not fname:
                        fname = f"{target_key}.png"
                    if not fname.lower().endswith(".png"):
                        fname += ".png"

                    if rect and len(rect) == 4:
                        img = None
                        if image_base64:
                            try:
                                import base64
                                import numpy as np
                                import cv2
                                b64_clean = image_base64.split(',', 1)[1] if ',' in image_base64 else image_base64
                                raw_bytes = base64.b64decode(b64_clean)
                                nparr = np.frombuffer(raw_bytes, np.uint8)
                                img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
                            except Exception as decode_err:
                                logger.warning(f"Failed to decode client image_base64: {decode_err}")

                        if img is None and adb_sync:
                            img = cal_engine.capture_screen_cv2(adb_sync, device=target_dev)

                        if img is None:
                            raise ValueError("无法获取有效的屏幕画面进行裁剪")

                        saved_path, size, repo_path = cal_engine.crop_and_save(img, rect, fname)
                        # 更新 profile (双套坐标: crop_area 与 search_area)
                        cal_engine.save_target_definition(
                            target_key, rect, tap_coord, anchor,
                            search_area=search_area, target_file=fname, target_name=target_name, category=category
                        )
                        updated_cfg = cal_engine.sync_target_to_config_file(target_key, CONFIG_PATH_V5)
                        
                        # 直推模拟器 /sdcard/FGO_Q/images/ 与 /sdcard/FGO_Q/battle_v5_config.mq
                        adb = adb_sync.find_adb() if adb_sync else None
                        dev = target_dev or (adb_sync.get_adb_status().get('device') if adb_sync else None)
                        pushed = False
                        if adb and dev and os.path.isfile(saved_path):
                            adb_sync.run_adb([adb, '-s', dev, 'shell', 'mkdir', '-p', '/sdcard/FGO_Q/images'])
                            push_r = adb_sync.run_adb([adb, '-s', dev, 'push', saved_path, f'/sdcard/FGO_Q/images/{fname}'])
                            pushed = (push_r.returncode == 0)
                            logger.info(f"Pushed calibrated target to emulator ({dev}): {fname}, success={pushed}")
                            if updated_cfg:
                                adb_sync.push_config_to_simulator(updated_cfg, device=dev)
                        
                        res = {
                            "success": True,
                            "target_key": target_key,
                            "file": fname,
                            "size": size,
                            "device": dev,
                            "repo_saved": bool(repo_path and os.path.isfile(repo_path)),
                            "pushed_to_emulator": pushed,
                            "config_synced": bool(updated_cfg),
                            "image_url": f"/api/calibrate/image/{fname}?t={int(time.time()*1000)}"
                        }
                    else:
                        # 纯点击锚点或仅更新属性/搜索范围
                        cal_engine.save_target_definition(
                            target_key, None, tap_coord, anchor,
                            search_area=search_area, target_file=fname, target_name=target_name, category=category
                        )
                        updated_cfg = cal_engine.sync_target_to_config_file(target_key, CONFIG_PATH_V5)
                        dev = target_dev or (adb_sync.get_adb_status().get('device') if adb_sync else None)
                        if adb_sync and dev and updated_cfg:
                            adb_sync.push_config_to_simulator(updated_cfg, device=dev)
                        res = {
                            "success": True,
                            "target_key": target_key,
                            "config_synced": bool(updated_cfg),
                            "is_tap_only": True
                        }
                except Exception as e:
                    logger.error(f"Save target failed: {e}")
                    res = {"success": False, "error": str(e)}
            else:
                res = {"success": False, "error": "Invalid params or engine not ready"}
                
            self.send_response(200)
            self.send_header('Content-Type', 'application/json; charset=utf-8')
            self.send_header('Cache-Control', 'no-cache')
            self.end_headers()
            self.wfile.write(json.dumps(res, ensure_ascii=False).encode('utf-8'))
            return
        elif self.path.startswith('/api/calibrate/test_match'):
            length = int(self.headers.get('Content-Length', 0))
            body = self.rfile.read(length).decode('utf-8') if length > 0 else "{}"
            req = json.loads(body)
            target_key = req.get('target_key')
            search_area = req.get('search_area')
            req_dev = req.get('device')
            target_file = req.get('file')
            image_base64 = req.get('image_base64')
            target_dev = req_dev or (adb_sync.get_selected_device() if hasattr(adb_sync, 'get_selected_device') else None)
            
            res = {"success": False}
            if cal_engine and target_key:
                try:
                    img = None
                    if image_base64:
                        try:
                            import base64
                            import numpy as np
                            import cv2
                            b64_clean = image_base64.split(',', 1)[1] if ',' in image_base64 else image_base64
                            raw_bytes = base64.b64decode(b64_clean)
                            nparr = np.frombuffer(raw_bytes, np.uint8)
                            img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
                        except Exception as decode_err:
                            logger.warning(f"Failed to decode client image_base64 in test_match: {decode_err}")

                    if img is None and adb_sync:
                        img = cal_engine.capture_screen_cv2(adb_sync, device=target_dev)

                    if img is None:
                        raise ValueError("无法获取模拟器屏幕画面进行识别")

                    fname = target_file
                    if not fname:
                        manifest = cal_engine.get_targets_manifest()
                        for t in manifest.get('targets', []):
                            if t.get('key') == target_key and t.get('file'):
                                fname = t.get('file')
                                break
                    if not fname:
                        fname = f"{target_key}.png"

                    tpl_path = cal_engine.resolve_image_path(fname)
                    if tpl_path and os.path.isfile(tpl_path):
                        match_info = cal_engine.test_match(img, tpl_path, search_area)
                        res = {"success": True, "device": target_dev, "match": match_info}
                    else:
                        res = {"success": False, "error": f"本地尚无特征图: {fname}"}
                except Exception as e:
                    res = {"success": False, "error": str(e)}
            else:
                res = {"success": False, "error": "Invalid params"}
                
            self.send_response(200)
            self.send_header('Content-Type', 'application/json; charset=utf-8')
            self.send_header('Cache-Control', 'no-cache')
            self.end_headers()
            self.wfile.write(json.dumps(res, ensure_ascii=False).encode('utf-8'))
            return
        elif self.path.startswith('/api/sync/images'):
            length = int(self.headers.get('Content-Length', 0))
            target_dev = None
            if length > 0:
                try:
                    req_data = json.loads(self.rfile.read(length).decode('utf-8'))
                    target_dev = req_data.get('device')
                except Exception:
                    pass
            if adb_sync:
                res = adb_sync.sync_images_to_simulator(device=target_dev)
            else:
                res = {"success": False, "connected": False, "message": "adb_sync 模块未就绪"}
            self.send_response(200)
            self.send_header('Content-Type', 'application/json; charset=utf-8')
            self.send_header('Cache-Control', 'no-cache')
            self.end_headers()
            self.wfile.write(json.dumps(res, ensure_ascii=False).encode('utf-8'))
            return
        elif self.path.startswith('/api/sync'):
            length = int(self.headers.get('Content-Length', 0))
            body = self.rfile.read(length).decode('utf-8') if length > 0 else ""
            text = ""
            target_dev = None
            if body:
                try:
                    req_data = json.loads(body)
                    text = req_data.get('text', '')
                    target_dev = req_data.get('device')
                except Exception:
                    pass

            # 若传入了最新配置文本，同时落盘保存本地代码仓库 Q/battle_v5_config.q（带历史快照）
            if text:
                try:
                    text = ensure_targets_in_config(text, CONFIG_PATH_V5)
                    backup_config(CONFIG_PATH_V5)
                    os.makedirs(os.path.dirname(CONFIG_PATH_V5), exist_ok=True)
                    with open(CONFIG_PATH_V5, 'w', encoding='utf-8') as f:
                        f.write(text)
                except Exception as e:
                    print(f"[Warning] Failed to save repo config in /api/sync: {e}", file=sys.stderr)
            elif not text and os.path.exists(CONFIG_PATH_V5):
                with open(CONFIG_PATH_V5, 'r', encoding='utf-8') as f:
                    text = f.read()

            try:
                if adb_sync:
                    target_dev = target_dev or (adb_sync.get_selected_device() if hasattr(adb_sync, 'get_selected_device') else None)
                    res = adb_sync.push_config_to_simulator(text, device=target_dev)
                else:
                    res = {"success": False, "connected": False, "message": "adb_sync 模块未加载"}
            except Exception as e:
                res = {"success": False, "connected": False, "message": str(e)}

            logger.info(f"[Sync] 手动同步配置至模拟器结果: {res.get('message', '')} (success={res.get('success')})")

            self.send_response(200)
            self.send_header('Content-Type', 'application/json; charset=utf-8')
            self.send_header('Cache-Control', 'no-cache')
            self.end_headers()
            self.wfile.write(json.dumps(res).encode('utf-8'))
            return
        elif self.path.startswith('/api/fgo/navigate_home'):
            length = int(self.headers.get('Content-Length', 0))
            body = self.rfile.read(length).decode('utf-8') if length > 0 else ""
            target_dev = None
            if body:
                try:
                    req_data = json.loads(body)
                    target_dev = req_data.get('device')
                except Exception:
                    pass

            if adb_sync:
                try:
                    target_dev = target_dev or (adb_sync.get_selected_device() if hasattr(adb_sync, 'get_selected_device') else None)
                    res = adb_sync.navigate_fgo_to_home(device=target_dev, max_wait_sec=50)
                except Exception as e:
                    res = {"success": False, "connected": False, "message": str(e)}
            else:
                res = {"success": False, "connected": False, "message": "adb_sync 模块未加载"}

            self.send_response(200)
            self.send_header('Content-Type', 'application/json; charset=utf-8')
            self.send_header('Cache-Control', 'no-cache')
            self.end_headers()
            self.wfile.write(json.dumps(res, ensure_ascii=False).encode('utf-8'))
            return
        elif self.path.startswith('/api/runner/ready_env'):
            length = int(self.headers.get('Content-Length', 0))
            body = self.rfile.read(length).decode('utf-8') if length > 0 else ""
            target_dev = None
            force_re = ("restart=1" in self.path or "force=1" in self.path)
            if body:
                try:
                    req_data = json.loads(body)
                    target_dev = req_data.get('device')
                    if req_data.get("restart") or req_data.get("force_restart"):
                        force_re = True
                except Exception:
                    pass

            logger.info(f"[API] 收到 POST /api/runner/ready_env (device={target_dev}, restart={force_re})")
            if adb_sync:
                try:
                    target_dev = target_dev or (adb_sync.get_selected_device() if hasattr(adb_sync, 'get_selected_device') else None)
                    res = adb_sync.ready_environment(device=target_dev, force_restart=force_re)
                    logger.info(f"[API] POST ready_env 执行完成: {res.get('message')}")
                except Exception as e:
                    logger.error(f"[API] POST ready_env 异常: {e}")
                    res = {"success": False, "connected": False, "message": str(e)}
            else:
                res = {"success": False, "connected": False, "message": "adb_sync 模块未加载"}

            self.send_response(200)
            self.send_header('Content-Type', 'application/json; charset=utf-8')
            self.send_header('Cache-Control', 'no-cache')
            self.end_headers()
            self.wfile.write(json.dumps(res, ensure_ascii=False).encode('utf-8'))
            return
        elif self.path.startswith('/api/runner/launch'):
            length = int(self.headers.get('Content-Length', 0))
            body = self.rfile.read(length).decode('utf-8') if length > 0 else ""
            target_dev = None
            if body:
                try:
                    req_data = json.loads(body)
                    target_dev = req_data.get('device')
                except Exception:
                    pass

            if adb_sync:
                try:
                    target_dev = target_dev or (adb_sync.get_selected_device() if hasattr(adb_sync, 'get_selected_device') else None)
                    force_re = bool(req_data.get("restart") or req_data.get("force_restart") or ("restart=1" in self.path))
                    res = adb_sync.launch_runner(device=target_dev, wait_ready=True, force_restart=force_re)
                except Exception as e:
                    res = {"success": False, "connected": False, "message": str(e)}
            else:
                res = {"success": False, "connected": False, "message": "adb_sync 模块未加载"}

            self.send_response(200)
            self.send_header('Content-Type', 'application/json; charset=utf-8')
            self.send_header('Cache-Control', 'no-cache')
            self.end_headers()
            self.wfile.write(json.dumps(res, ensure_ascii=False).encode('utf-8'))
            return
        elif self.path in ('/api/run', '/api/run/') or self.path.startswith('/api/run?'):
            length = int(self.headers.get('Content-Length', 0))
            body = self.rfile.read(length).decode('utf-8') if length > 0 else ""
            text = ""
            target_dev = None
            mode = 'BATTLE'
            if body:
                try:
                    req_data = json.loads(body)
                    text = req_data.get('text', '')
                    target_dev = req_data.get('device')
                    mode = req_data.get('mode', 'BATTLE')
                except Exception:
                    pass

            sync_res = None
            if text:
                try:
                    text = ensure_targets_in_config(text, CONFIG_PATH_V5)
                    need_write = True
                    if os.path.isfile(CONFIG_PATH_V5):
                        try:
                            with open(CONFIG_PATH_V5, 'r', encoding='utf-8') as f:
                                if f.read() == text:
                                    need_write = False
                        except Exception:
                            pass
                    if need_write:
                        backup_config(CONFIG_PATH_V5)
                        os.makedirs(os.path.dirname(CONFIG_PATH_V5), exist_ok=True)
                        with open(CONFIG_PATH_V5, 'w', encoding='utf-8') as f:
                            f.write(text)
                    if adb_sync:
                        target_dev = target_dev or (adb_sync.get_selected_device() if hasattr(adb_sync, 'get_selected_device') else None)
                        sync_res = adb_sync.push_config_to_simulator(text, device=target_dev)
                except Exception as e:
                    logger.warning(f"[Run] 运行前保存/直推配置异常: {e}")

            if adb_sync:
                target_dev = target_dev or (adb_sync.get_selected_device() if hasattr(adb_sync, 'get_selected_device') else None)
                # 检查 Runner 是否在线（不整合拉起脚本，独立分开控制）
                st = adb_sync.get_runner_status(device=target_dev)
                if not st.get("alive") or st.get("state") == "OFFLINE":
                    run_res = {"success": False, "message": "按键脚本未在运行，请先点击「拉起脚本」或在模拟器启动脚本"}
                else:
                    cmd = "START_EXTRA" if str(mode).upper() == "EXTRA" else "START_BATTLE"
                    run_res = adb_sync.send_runner_command(cmd, device=target_dev)
            else:
                run_res = {"success": False, "connected": False, "message": "adb_sync 模块未加载"}

            if sync_res:
                run_res["sync"] = sync_res

            logger.info(f"[Run] 触发运行任务(mode={mode}): 指令下发={run_res.get('success')} | 消息: {run_res.get('message', '')}")

            self.send_response(200)
            self.send_header('Content-Type', 'application/json; charset=utf-8')
            self.send_header('Cache-Control', 'no-cache')
            self.end_headers()
            self.wfile.write(json.dumps(run_res).encode('utf-8'))
            return
        elif self.path.startswith('/api/stop'):
            if adb_sync:
                target_dev = (adb_sync.get_selected_device() if hasattr(adb_sync, 'get_selected_device') else None)
                stop_res = adb_sync.send_runner_command("STOP", device=target_dev)
            else:
                stop_res = {"success": False, "connected": False, "message": "adb_sync 模块未加载"}

            logger.info(f"[Stop] 触发停止战斗: 指令下发={stop_res.get('success')} | 消息: {stop_res.get('message', '')}")

            self.send_response(200)
            self.send_header('Content-Type', 'application/json; charset=utf-8')
            self.send_header('Cache-Control', 'no-cache')
            self.end_headers()
            self.wfile.write(json.dumps(stop_res).encode('utf-8'))
            return
        elif self.path.startswith('/api/save'):
            length = int(self.headers.get('Content-Length', 0))
            body = self.rfile.read(length).decode('utf-8')
            try:
                data = json.loads(body)
                text = data.get('text', '')
                target_dev = data.get('device') or (adb_sync.get_selected_device() if hasattr(adb_sync, 'get_selected_device') else None)

                # 优先保存到 V5 配置
                target_path = CONFIG_PATH_V5
                text = ensure_targets_in_config(text, target_path)

                # 备份历史文件
                backup_path = backup_config(target_path)

                os.makedirs(os.path.dirname(target_path), exist_ok=True)
                with open(target_path, 'w', encoding='utf-8') as f:
                    f.write(text)

                # 阶段一：自动下发至模拟器与手机助手
                adb_res = None
                try:
                    if adb_sync:
                        adb_res = adb_sync.push_config_to_simulator(text, device=target_dev)
                    else:
                        adb_res = {"success": False, "connected": False, "message": "adb_sync 模块未加载"}
                except Exception as e:
                    adb_res = {
                        "success": False,
                        "connected": False,
                        "message": f"直推模拟器异常: {str(e)}"
                    }

                logger.info(f"[Save] 配置已保存落盘: {target_path} | ADB结果: {adb_res.get('message', '')}")

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
                logger.error(f"[Save] 保存配置异常: {e}", exc_info=True)
                self.send_response(500)
                self.send_header('Content-Type', 'application/json; charset=utf-8')
                self.end_headers()
                self.wfile.write(json.dumps({'success': False, 'message': str(e)}).encode('utf-8'))
        else:
            self.send_response(404)
            self.end_headers()


class ThreadingHTTPServerWithReuse(http.server.ThreadingHTTPServer):
    allow_reuse_address = True
    daemon_threads = True


def create_server(host='127.0.0.1', port=PORT):
    return ThreadingHTTPServerWithReuse((host, port), ConfigEditorHandler)

def start_server_thread(host='127.0.0.1', port=PORT):
    server = create_server(host, port)
    import threading
    t = threading.Thread(target=server.serve_forever, daemon=True)
    t.start()
    return server

if __name__ == '__main__':
    server = create_server('0.0.0.0', PORT)
    logger.info(f"=== FGO Q Editor Server running on port {PORT} ===")
    logger.info(f"Local log file: {LOG_FILE}")
    print(f"FGO Q Editor Server running on port {PORT}...", flush=True)
    server.serve_forever()
