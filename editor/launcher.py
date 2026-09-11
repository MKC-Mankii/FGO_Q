import os
import sys
import time
import socket
import subprocess
import ctypes
import threading

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
EDITOR_DIR = os.path.join(ROOT_DIR, "editor")
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

def is_port_open(port):
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.settimeout(0.4)
        return s.connect_ex(("127.0.0.1", port)) == 0

def ensure_server_running():
    """确保配置服务已在后台运行"""
    if not is_port_open(PORT):
        try:
            import server
            server.start_server_thread('127.0.0.1', PORT)
        except Exception as e:
            # 如果模块导入失败，降级为子进程静默拉起
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

        # 等待服务就绪
        for _ in range(20):
            time.sleep(0.1)
            if is_port_open(PORT):
                break

def launch_native_webview(debug=False):
    """使用 pywebview 启动原生独立桌面窗口"""
    import webview
    global CURRENT_WINDOW
    
    # 黄金推荐尺寸：1600px 宽度（完美承载 1440px 容器及边距留白）× 1020px 高度（控制台全域免滚动完整展示）
    api = NativeApi()
    window = webview.create_window(
        title="FGO 战斗配置编辑器 (V3)",
        url=APP_URL,
        width=1600,
        height=1020,
        min_size=(1100, 680),
        text_select=True,
        zoomable=True,
        js_api=api
    )
    CURRENT_WINDOW = window

    # 延迟 300ms 二次调用原生 resize，覆盖可能被 Windows 或 WebView2 内部记忆还原的旧尺寸
    def delayed_enforce_size():
        time.sleep(0.35)
        try:
            window.resize(1600, 1020)
        except Exception:
            pass

    threading.Thread(target=delayed_enforce_size, daemon=True).start()
    # 启动 GUI 事件循环（默认不自动弹 F12 调试窗口，仅在指定 --debug 时开启）
    webview.start(private_mode=False, debug=debug)

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
