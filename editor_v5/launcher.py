import os
import sys
import time
import socket
import subprocess
import ctypes
import threading
import shutil
import urllib.request

# 默认隔离 ADB 端口（避免与 MuMu/MFA 等占用 5037 默认端口的其他项目发生 kill-server 冲突）
DEFAULT_ADB_PORT = os.environ.get("ANDROID_ADB_SERVER_PORT", "5038")
if "ANDROID_ADB_SERVER_PORT" not in os.environ:
    os.environ["ANDROID_ADB_SERVER_PORT"] = DEFAULT_ADB_PORT
if "ADB_SERVER_SOCKET" not in os.environ:
    os.environ["ADB_SERVER_SOCKET"] = f"tcp:localhost:{DEFAULT_ADB_PORT}"

# 1. 开启 Windows Per-Monitor DPI-Aware (V2)
# 这一步极其关键：默认情况下 Python 是 DPI-Unaware 的，在 2K/3K/4K 高分屏下
# Windows 会强制使用虚拟化拉伸并锁定小分辨率，导致设定的 1500+ 宽高被系统压回旧尺寸。
try:
    ctypes.windll.shcore.SetProcessDpiAwareness(2)
except Exception:
    try:
        ctypes.windll.user32.SetProcessDPIAware()
    except Exception:
        pass

PORT = 8099
ROOT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
EDITOR_DIR = os.path.join(ROOT_DIR, "editor_v5")
ICO_PATH = os.path.join(EDITOR_DIR, "icons", "fgo_editor.ico")
APP_URL = f"http://127.0.0.1:{PORT}"

# 全局原生窗口引用
CURRENT_WINDOW = None

class NativeApi:
    def resizeWindow(self, w=1600, h=1020):
        global CURRENT_WINDOW
        if CURRENT_WINDOW:
            try:
                CURRENT_WINDOW.resize(int(w), int(h))
                return True
            except Exception:
                return False
        return False

# 添加 editor 目录到 sys.path 以便直接引用 server 模块
if EDITOR_DIR not in sys.path:
    sys.path.insert(0, EDITOR_DIR)

def is_server_healthy(port):
    """验证目标端口上的配置服务是否已正常响应 HTTP 请求"""
    try:
        req = urllib.request.Request(f"http://127.0.0.1:{port}/api/config")
        with urllib.request.urlopen(req, timeout=0.8) as resp:
            return resp.status == 200
    except Exception:
        return False

def kill_process_on_port(port):
    """清理占用指定端口的死进程或僵尸服务"""
    try:
        output = subprocess.check_output("netstat -ano", shell=True).decode("gbk", errors="ignore")
        pids = set()
        current_pid = str(os.getpid())
        for line in output.splitlines():
            if f":{port}" in line and "LISTENING" in line:
                parts = line.strip().split()
                if parts and parts[-1] != current_pid:
                    pids.add(parts[-1])
        for pid in pids:
            subprocess.run(f"taskkill /f /pid {pid}", shell=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        if pids:
            time.sleep(0.3)
    except Exception:
        pass

def cleanup_webview_profile():
    """安全清理旧版本可能残留导致 WebView2 启动死锁或白屏的临时缓存"""
    dirs_to_clean = [
        os.path.join(EDITOR_DIR, ".webview_profile"),
        os.path.expandvars(r"%APPDATA%\pywebview\EBWebView")
    ]
    for d in dirs_to_clean:
        if os.path.exists(d):
            try:
                shutil.rmtree(d, ignore_errors=True)
            except Exception:
                pass

def ensure_server_running():
    """确保配置服务已在后台运行并健康响应"""
    if is_server_healthy(PORT):
        return

    # 若端口被占用但服务不响应健康检测，强制回收端口以防白屏与假死
    kill_process_on_port(PORT)

    try:
        import server
        server.start_server_thread('127.0.0.1', PORT)
    except Exception:
        # 如果模块导入失败，降级为子进程拉起
        python_exe = sys.executable
        if python_exe.lower().endswith("python.exe"):
            cand = python_exe[:-10] + "pythonw.exe"
            if os.path.exists(cand):
                python_exe = cand
        server_script = os.path.join(EDITOR_DIR, "server.py")
        subprocess.Popen(
            [python_exe, server_script],
            cwd=ROOT_DIR,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            stdin=subprocess.DEVNULL,
            creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0x08000000)
        )

    # 等待服务健康就绪（最多 5 秒）
    for _ in range(50):
        time.sleep(0.1)
        if is_server_healthy(PORT):
            break

def launch_native_webview(debug=False):
    """使用 pywebview 启动原生独立桌面窗口"""
    import webview
    global CURRENT_WINDOW

    cleanup_webview_profile()
    
    # 推荐尺寸：1600px 宽度（完美承载 1440px 容器及边距留白）× 1020px 高度（控制台全域免滚动完整展示）
    api = NativeApi()
    window = webview.create_window(
        title="FGO 战斗配置编辑器 (V5)",
        url=APP_URL,
        width=1600,
        height=1020,
        min_size=(1100, 680),
        text_select=True,
        zoomable=True,
        js_api=api
    )
    CURRENT_WINDOW = window

    # 注册窗口显示后安全调整尺寸的事件（避免后台子线程直接操作未初始化原生句柄导致崩溃/白屏）
    def on_shown():
        try:
            window.resize(1600, 1020)
        except Exception:
            pass

    window.events.shown += on_shown
    # 启动 GUI 事件循环，强制使用独立隔离环境 (private_mode=True)，彻底杜绝 EBWebView 目录锁冲突导致的 0x800700AA 白屏
    webview.start(private_mode=True, debug=debug)

def find_chromium_browser():
    """查找系统中存在的 Edge 或 Chrome 可执行文件路径"""
    candidates = [
        # Microsoft Edge (Win10/Win11 自带)
        os.path.expandvars(r"%ProgramFiles(x86)%\Microsoft\Edge\Application\msedge.exe"),
        os.path.expandvars(r"%ProgramFiles%\Microsoft\Edge\Application\msedge.exe"),
        os.path.expandvars(r"%LocalAppData%\Microsoft\Edge\Application\msedge.exe"),
        # Google Chrome
        os.path.expandvars(r"%ProgramFiles%\Google\Chrome\Application\chrome.exe"),
        os.path.expandvars(r"%ProgramFiles(x86)%\Google\Chrome\Application\chrome.exe"),
        os.path.expandvars(r"%LocalAppData%\Google\Chrome\Application\chrome.exe"),
    ]
    for p in candidates:
        if os.path.isfile(p):
            return p
    return None

def launch_app_mode():
    """降级方案：使用 Edge / Chrome 的 --app 独立窗口模式运行"""
    browser_exe = find_chromium_browser()
    if browser_exe:
        user_data_dir = os.path.join(EDITOR_DIR, ".app_profile")
        cmd = [
            browser_exe,
            f"--app={APP_URL}",
            f"--user-data-dir={user_data_dir}",
            "--window-size=1500,930"
        ]
        proc = subprocess.Popen(cmd)
        proc.wait()  # 等待应用窗口关闭
    else:
        # 最后的保底：系统默认方式打开
        try:
            os.startfile(APP_URL)
        except Exception:
            subprocess.Popen(f'explorer "{APP_URL}"', shell=True)

def main():
    # 如果指定了 --browser 参数，则以后台服务+默认浏览器标签页模式启动
    if "--browser" in sys.argv:
        # 确保后台 server.py 作为独立持久进程拉起
        if not is_port_open(PORT):
            python_exe = sys.executable
            if python_exe.lower().endswith("python.exe"):
                cand = python_exe[:-10] + "pythonw.exe"
                if os.path.exists(cand):
                    python_exe = cand
            server_script = os.path.join(EDITOR_DIR, "server.py")
            subprocess.Popen(
                [python_exe, server_script],
                cwd=ROOT_DIR,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                stdin=subprocess.DEVNULL,
                creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0x08000000)
            )
            for _ in range(20):
                time.sleep(0.1)
                if is_port_open(PORT):
                    break
        try:
            os.startfile(APP_URL)
        except Exception:
            subprocess.Popen(f'explorer "{APP_URL}"', shell=True)
        return

    ensure_server_running()
    
    try:
        # 首选方案 B：原生桌面窗口 (默认不弹控制台；支持 F5/Ctrl+R 刷新)
        debug_flag = "--debug" in sys.argv
        launch_native_webview(debug=debug_flag)
    except Exception as e:
        print(f"[Launcher] pywebview failed ({e}), falling back to app-mode...", file=sys.stderr)
        # 降级方案 A：Edge/Chrome 独立 App 模式
        launch_app_mode()
    finally:
        # 当桌面窗口关闭后，干净退出进程
        os._exit(0)

if __name__ == "__main__":
    main()
