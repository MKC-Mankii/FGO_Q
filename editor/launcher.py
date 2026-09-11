import os
import sys
import time
import socket
import webbrowser
import subprocess

PORT = 8099
ROOT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
SERVER_SCRIPT = os.path.join(ROOT_DIR, "editor", "server.py")

def is_port_open(port):
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.settimeout(0.4)
        return s.connect_ex(("127.0.0.1", port)) == 0

def launch():
    if not is_port_open(PORT):
        # 查找 pythonw 或当前解释器
        python_exe = sys.executable
        if python_exe.lower().endswith("python.exe"):
            pythonw_candidate = python_exe[:-10] + "pythonw.exe"
            if os.path.exists(pythonw_candidate):
                python_exe = pythonw_candidate

        # 静默在后台拉起 server.py
        subprocess.Popen(
            [python_exe, SERVER_SCRIPT],
            cwd=ROOT_DIR,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            stdin=subprocess.DEVNULL,
            creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0x08000000)
        )
        # 等待服务就绪
        for _ in range(15):
            time.sleep(0.15)
            if is_port_open(PORT):
                break

    # 自动使用系统默认浏览器打开编辑器
    url = f"http://127.0.0.1:{PORT}"
    try:
        os.startfile(url)
    except Exception:
        subprocess.Popen(f'explorer "{url}"', shell=True)

if __name__ == "__main__":
    launch()
