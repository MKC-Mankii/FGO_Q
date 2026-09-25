import os
import subprocess

def stop_server():
    try:
        output = subprocess.check_output("netstat -ano", shell=True).decode("gbk", errors="ignore")
        pids = set()
        for line in output.splitlines():
            if ":8099" in line and "LISTENING" in line:
                parts = line.strip().split()
                if parts:
                    pids.add(parts[-1])
        if pids:
            for pid in pids:
                subprocess.run(f"taskkill /f /pid {pid}", shell=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            print("配置编辑器服务已成功停止。")
        else:
            print("8099 端口未检测到正在运行的服务。")
    except Exception as e:
        print("停止服务出错:", e)

if __name__ == "__main__":
    stop_server()
