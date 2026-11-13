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

# 单例互斥锁句柄引用（防止被 Python GC 释放）
_SINGLE_INSTANCE_MUTEX = None

class RECT(ctypes.Structure):
    _fields_ = [
        ('left', ctypes.c_long),
        ('top', ctypes.c_long),
        ('right', ctypes.c_long),
        ('bottom', ctypes.c_long)
    ]

class POINT(ctypes.Structure):
    _fields_ = [
        ('x', ctypes.c_long),
        ('y', ctypes.c_long)
    ]

def ensure_window_within_active_monitors(hwnd):
    """
    多屏越界自愈机制：
    检测指定窗口是否落在当前任意一个活动的物理/虚拟监视器可视范围内。
    当用户拔掉副屏或关闭副显示器电源时，Windows 常将窗口遗留在已断开的旧坐标区间。
    若检测到完全脱离活动显示器或标题栏不可触达，自动将窗口安全拉回主显示器工作区并居中。
    """
    try:
        user32 = ctypes.windll.user32
        if not user32.IsWindow(hwnd):
            return False

        rect = RECT()
        if not user32.GetWindowRect(hwnd, ctypes.byref(rect)):
            return False

        # 0 = MONITOR_DEFAULTTONULL (若不与任何活动监视器相交则返回 0)
        h_monitor_rect = user32.MonitorFromRect(ctypes.byref(rect), 0)
        # 探测窗口标题栏抓取区 (顶部向下 20px, 左侧向右 50px) 是否在有效屏幕内
        title_pt = POINT(rect.left + 50, rect.top + 20)
        h_monitor_title = user32.MonitorFromPoint(title_pt, 0)

        # 窗口完全脱离所有活动显示器，或者标题栏位于虚无空间无法被用户鼠标拖动
        if h_monitor_rect == 0 or h_monitor_title == 0:
            # 若窗口此前在副屏上处于最大化状态，先恢复为常规状态再平移
            if user32.IsZoomed(hwnd):
                user32.ShowWindow(hwnd, 9)  # SW_RESTORE

            SPI_GETWORKAREA = 0x0030
            work_area = RECT()
            user32.SystemParametersInfoW(SPI_GETWORKAREA, 0, ctypes.byref(work_area), 0)

            work_w = max(800, work_area.right - work_area.left)
            work_h = max(600, work_area.bottom - work_area.top)

            win_w = rect.right - rect.left
            win_h = rect.bottom - rect.top

            # 防止窗口尺寸异常或超出当前主显示器工作区
            if win_w <= 0 or win_w > work_w:
                win_w = min(1600, work_w)
            if win_h <= 0 or win_h > work_h:
                win_h = min(1020, work_h)

            new_x = work_area.left + max(0, (work_w - win_w) // 2)
            new_y = work_area.top + max(0, (work_h - win_h) // 2)

            SWP_NOZORDER = 0x0004
            SWP_SHOWWINDOW = 0x0040
            user32.SetWindowPos(hwnd, 0, new_x, new_y, win_w, win_h, SWP_NOZORDER | SWP_SHOWWINDOW)
            print(f"[Launcher] 检测到 Editor 窗口脱离活动显示器，已自动拉回主屏幕: pos=({new_x}, {new_y}), size=({win_w}x{win_h})", flush=True)
            return True
    except Exception as e:
        print(f"[Launcher] 窗口多屏边界自愈检查失败: {e}", file=sys.stderr)
    return False

def find_editor_windows(target_pid=None):
    """
    智能查找 Editor 窗口句柄列表：
    1. 优先通过当前进程 PID 精准定位原生窗口；
    2. 支持中英文标题模糊匹配 (兼容 HTML <title>FGO Q Battle Config Editor [V5]</title> 导致的原生标题变更)
    """
    hwnds = []
    user32 = ctypes.windll.user32
    def callback(hwnd, extra):
        if not user32.IsWindow(hwnd) or not user32.IsWindowVisible(hwnd):
            return True
        if target_pid:
            pid = ctypes.c_ulong()
            user32.GetWindowThreadProcessId(hwnd, ctypes.byref(pid))
            if pid.value == target_pid:
                rect = RECT()
                user32.GetWindowRect(hwnd, ctypes.byref(rect))
                # 过滤可能伴生出的辅助微型无边框消息窗口
                if (rect.right - rect.left) > 200 and (rect.bottom - rect.top) > 200:
                    hwnds.append(hwnd)
                return True

        length = user32.GetWindowTextLengthW(hwnd)
        if length > 0:
            buff = ctypes.create_unicode_buffer(length + 1)
            user32.GetWindowTextW(hwnd, buff, length + 1)
            title = buff.value
            if "FGO" in title and ("配置" in title or "Editor" in title or "Battle" in title):
                hwnds.append(hwnd)
        return True

    WNDENUMPROC = ctypes.WINFUNCTYPE(ctypes.c_bool, ctypes.c_int, ctypes.c_int)
    user32.EnumWindows(WNDENUMPROC(callback), 0)
    return hwnds

def activate_existing_window(window_title="FGO 战斗配置编辑器 (V5)"):
    """激活并前置已存在的同名窗口，并确保窗口处于有效显示器可见范围内"""
    try:
        user32 = ctypes.windll.user32
        hwnds = find_editor_windows()
        if hwnds:
            for hwnd in hwnds:
                # 9 = SW_RESTORE (恢复最小化的窗口)
                user32.ShowWindow(hwnd, 9)
                # 检查多屏越界自愈，若处于已断开的副屏坐标空间，自动拉回主屏幕可见区域
                ensure_window_within_active_monitors(hwnd)
                user32.SetForegroundWindow(hwnd)
            return True
    except Exception:
        pass
    return False

def acquire_single_instance(mutex_name=r"Local\FGO_Q_Editor_SingleInstance_Mutex"):
    """尝试获取本地用户单例互斥锁，已存在则返回 False"""
    global _SINGLE_INSTANCE_MUTEX
    try:
        kernel32 = ctypes.windll.kernel32
        mutex = kernel32.CreateMutexW(None, False, mutex_name)
        last_error = kernel32.GetLastError()
        ERROR_ALREADY_EXISTS = 183
        if last_error == ERROR_ALREADY_EXISTS:
            if mutex:
                kernel32.CloseHandle(mutex)
            return False
        _SINGLE_INSTANCE_MUTEX = mutex
        return True
    except Exception:
        return True

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

def is_server_healthy(port, timeout=2.5):
    """验证目标端口上的配置服务是否已正常响应 HTTP 请求"""
    try:
        req = urllib.request.Request(f"http://127.0.0.1:{port}/api/config")
        with urllib.request.urlopen(req, timeout=timeout) as resp:
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

def start_server_watchdog():
    """后台守护线程：实时监控后端 8099 服务健康状态，若因旧实例关闭或异常导致服务中断，自动无缝复活拉起"""
    def _watchdog_loop():
        time.sleep(2.0)
        consecutive_fails = 0
        while True:
            try:
                if not is_server_healthy(PORT, timeout=2.5):
                    consecutive_fails += 1
                    # 连续失败 3 次 (约 10 秒) 才判定为假死并复活拉起，避免模块热重载或高负载瞬间被误杀
                    if consecutive_fails >= 3:
                        ensure_server_running()
                        consecutive_fails = 0
                else:
                    consecutive_fails = 0
            except Exception:
                pass
            time.sleep(3.0)

    t = threading.Thread(target=_watchdog_loop, daemon=True)
    t.start()

def start_monitor_bounds_watchdog(interval=2.5):
    """后台守护线程：实时检测窗口是否因显示器热拔插/关闭而漂移到屏幕外，若脱离活动显示器则自动平移拉回主屏"""
    current_pid = os.getpid()
    def _watchdog_loop():
        time.sleep(3.0)
        user32 = ctypes.windll.user32
        while True:
            try:
                # 优先匹配当前进程的主窗口，若为降级模式则兜底全局扫描匹配
                hwnds = find_editor_windows(target_pid=current_pid)
                if not hwnds:
                    hwnds = find_editor_windows()
                for hwnd in hwnds:
                    if user32.IsWindowVisible(hwnd) and not user32.IsIconic(hwnd):
                        ensure_window_within_active_monitors(hwnd)
            except Exception:
                pass
            time.sleep(interval)

    t = threading.Thread(target=_watchdog_loop, daemon=True)
    t.start()

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

    # 注册窗口显示后安全调整尺寸与屏幕安全边界校验的事件
    def on_shown():
        try:
            window.resize(1600, 1020)
        except Exception:
            pass
        try:
            for hwnd in find_editor_windows(target_pid=os.getpid()):
                ensure_window_within_active_monitors(hwnd)
        except Exception:
            pass

    window.events.shown += on_shown
    # 启动后台服务自愈守护，确保多窗口关闭或服务中断时秒级复活
    start_server_watchdog()
    # 启动多显示器边界自愈守护，显示器断开/关闭时自动拉回主屏幕
    start_monitor_bounds_watchdog()
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
    start_server_watchdog()
    start_monitor_bounds_watchdog()
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
        if not is_server_healthy(PORT):
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
                if is_server_healthy(PORT):
                    break
        try:
            os.startfile(APP_URL)
        except Exception:
            subprocess.Popen(f'explorer "{APP_URL}"', shell=True)
        return

    # 单例模式防重复启动检测：若已存在 Editor 窗口，激活并前置旧窗口，安全退出避免双实例端口与数据冲突
    if not acquire_single_instance():
        print("[Launcher] 检测到 Editor 实例已在运行中，正在激活已有窗口...", flush=True)
        activate_existing_window("FGO 战斗配置编辑器 (V5)")
        sys.exit(0)

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
