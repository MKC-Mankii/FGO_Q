import os
import sys
import subprocess
import shutil
import time
import glob

# 预设候选 ADB 路径
CANDIDATE_ADB_PATHS = [
    r"D:\Program Files\Netease\MuMu\nx_main\adb.exe",
    r"D:\Program Files\Netease\MuMu\nx_device\15.0\shell\adb.exe",
    r"D:\ProgramData\按键精灵\手机助手\android\adb.exe",
    r"E:\back 970pro\Program Files\Netease\MuMuPlayer-12.0\nx_main\adb.exe",
    r"E:\leidian\LDPlayer9\adb.exe",
]

# PC 端按键精灵助手脚本目录候选
PC_ASSISTANT_SCRIPT_DIRS = [
    r"D:\ProgramData\按键精灵\按键精灵手机助手\Script",
    r"E:\back 970pro\ProgramData\按键精灵\按键精灵手机助手\Script",
]

# Windows 无控制台进程标志
CREATE_NO_WINDOW = 0x08000000 if sys.platform == "win32" else 0

_cached_adb_path = None


def find_adb():
    """查找系统中可用的 adb.exe 路径，优先使用缓存与 MuMu / 按键自带 adb"""
    global _cached_adb_path
    if _cached_adb_path and os.path.isfile(_cached_adb_path):
        return _cached_adb_path

    # 1. 扫描候选路径
    for path in CANDIDATE_ADB_PATHS:
        if os.path.isfile(path):
            try:
                res = subprocess.run(
                    [path, "version"],
                    stdin=subprocess.DEVNULL,
                    stdout=subprocess.PIPE,
                    stderr=subprocess.PIPE,
                    creationflags=CREATE_NO_WINDOW,
                    timeout=3
                )
                if res.returncode == 0:
                    _cached_adb_path = path
                    return path
            except Exception:
                continue

    # 2. 检查系统 PATH
    which_adb = shutil.which("adb")
    if which_adb and os.path.isfile(which_adb):
        try:
            res = subprocess.run(
                [which_adb, "version"],
                stdin=subprocess.DEVNULL,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                creationflags=CREATE_NO_WINDOW,
                timeout=3
            )
            if res.returncode == 0:
                _cached_adb_path = which_adb
                return which_adb
        except Exception:
            pass

    return None


def get_connected_devices(adb_path=None):
    """获取所有已连接且处于正常 device 状态的安卓设备列表"""
    adb = adb_path or find_adb()
    if not adb:
        return []

    try:
        res = subprocess.run(
            [adb, "devices"],
            stdin=subprocess.DEVNULL,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            creationflags=CREATE_NO_WINDOW,
            timeout=3
        )
        if res.returncode != 0:
            return []
        
        output = res.stdout.decode("utf-8", errors="ignore")
        devices = []
        for line in output.splitlines():
            line = line.strip()
            if not line or line.startswith("List of devices"):
                continue
            parts = line.split()
            if len(parts) >= 2 and parts[1] == "device":
                devices.append(parts[0])
        return devices
    except Exception:
        return []


def get_adb_status():
    """获取当前 ADB 及模拟器连接概况（供前端状态接口调用）"""
    adb = find_adb()
    if not adb:
        return {
            "available": False,
            "connected": False,
            "message": "未找到 adb.exe 命令行工具"
        }

    devices = get_connected_devices(adb)
    if not devices:
        return {
            "available": True,
            "connected": False,
            "adb_path": adb,
            "message": "未检测到在线的安卓模拟器 (设备列表为空)"
        }

    # 优先选取 emulator-5554，否则选取第一个
    target_dev = "emulator-5554" if "emulator-5554" in devices else devices[0]
    return {
        "available": True,
        "connected": True,
        "adb_path": adb,
        "device": target_dev,
        "all_devices": devices,
        "message": f"已连接模拟器: {target_dev}"
    }


def find_simulator_v4_config_files(adb, device):
    """扫描模拟器内部需要同步的目标文件：
       1. 模拟器历史工程配置 /sdcard/MobileAnJian/Script/fgo_battle_v4_config(...).mq（覆写防脏读）
       2. 规范化总线通信目录 /sdcard/FGO_Q/battle_v4_config.mq（V4 标准首选）
       注：已移除冗余备份 /sdcard/MobileAnJian/Script/battle_v4_config.mq
    """
    targets = []
    try:
        res = subprocess.run(
            [adb, "-s", device, "shell", "ls", "/sdcard/MobileAnJian/Script/"],
            stdin=subprocess.DEVNULL,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            creationflags=CREATE_NO_WINDOW,
            timeout=3
        )
        if res.returncode == 0:
            lines = res.stdout.decode("utf-8", errors="ignore").splitlines()
            for line in lines:
                name = line.strip()
                if "battle_v4_config" in name.lower() and name.endswith(".mq"):
                    if name.lower() != "battle_v4_config.mq":
                        targets.append(f"/sdcard/MobileAnJian/Script/{name}")
    except Exception as e:
        print(f"[ADB] Error listing simulator script dir: {e}", file=sys.stderr)

    # 规范化总线通信目录（V4 首选）
    fgo_q_mq = "/sdcard/FGO_Q/battle_v4_config.mq"
    if fgo_q_mq not in targets:
        targets.append(fgo_q_mq)

    return targets


def sync_to_pc_assistant(config_text_gbk):
    """同步写入本地按键精灵手机助手的 Script 目录"""
    synced_paths = []
    for base_dir in PC_ASSISTANT_SCRIPT_DIRS:
        if not os.path.isdir(base_dir):
            continue
        try:
            pattern = os.path.join(base_dir, "*battle_v4_config*.mq")
            matches = glob.glob(pattern)
            for mq_file in matches:
                with open(mq_file, "wb") as f:
                    f.write(config_text_gbk)
                synced_paths.append(mq_file)
        except Exception as e:
            print(f"[ADB] Failed to sync PC assistant at {base_dir}: {e}", file=sys.stderr)
    return synced_paths


def push_config_to_simulator(config_text, device=None):
    """
    将配置文本以标准 GBK + CRLF 格式直接下发至模拟器与 PC 助手
    返回同步结果字典
    注意：PC 助手目录同步属于本地磁盘写入，不依赖模拟器是否在线
    """
    t0 = time.time()

    # 1. 转换换行符为 CRLF 并编码为 GBK
    normalized_text = config_text.replace("\r\n", "\n").replace("\r", "\n").replace("\n", "\r\n")
    gbk_bytes = normalized_text.encode("gbk", errors="replace")

    # 2. 优先同步 PC 手机助手目录 (纯本地写入，完全不依赖模拟器状态)
    pc_synced = sync_to_pc_assistant(gbk_bytes)

    # 3. 检查 ADB 与模拟器在线状态
    adb = find_adb()
    if not adb:
        return {
            "success": False,
            "connected": False,
            "pc_synced_files": pc_synced,
            "message": "未找到 adb.exe，已保存本地工程与 PC 助手目录"
        }

    devices = get_connected_devices(adb)
    if not devices:
        return {
            "success": False,
            "connected": False,
            "adb_path": adb,
            "pc_synced_files": pc_synced,
            "message": "未检测到在线安卓模拟器，已保存本地工程与 PC 助手目录"
        }

    target_dev = device or ("emulator-5554" if "emulator-5554" in devices else devices[0])

    # 4. 准备临时推送文件
    temp_dir = os.path.join(os.path.dirname(__file__), ".tmp")
    os.makedirs(temp_dir, exist_ok=True)
    temp_file = os.path.join(temp_dir, "battle_v4_config_push.mq")
    with open(temp_file, "wb") as f:
        f.write(gbk_bytes)

    # 3. 确保模拟器目录 /sdcard/FGO_Q 存在
    try:
        subprocess.run(
            [adb, "-s", target_dev, "shell", "mkdir", "-p", "/sdcard/FGO_Q", "/sdcard/MobileAnJian/Script"],
            stdin=subprocess.DEVNULL,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            creationflags=CREATE_NO_WINDOW,
            timeout=2
        )
    except Exception:
        pass

    # 4. 扫描目标路径并批量推送到模拟器
    target_files = find_simulator_v4_config_files(adb, target_dev)
    pushed_files = []

    for remote_path in target_files:
        try:
            res = subprocess.run(
                [adb, "-s", target_dev, "push", temp_file, remote_path],
                stdin=subprocess.DEVNULL,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                creationflags=CREATE_NO_WINDOW,
                timeout=4
            )
            if res.returncode == 0:
                pushed_files.append(remote_path)
            else:
                err_msg = res.stderr.decode("utf-8", errors="ignore").strip()
                print(f"[ADB] Failed to push to {remote_path}: {err_msg}", file=sys.stderr)
        except Exception as e:
            print(f"[ADB] Exception pushing to {remote_path}: {e}", file=sys.stderr)

    # 清理临时文件
    try:
        os.remove(temp_file)
    except Exception:
        pass

    elapsed_ms = int((time.time() - t0) * 1000)

    if pushed_files:
        msg = f"已直推至模拟器 ({target_dev}) [{len(pushed_files)} 处, {elapsed_ms}ms]"
        if pc_synced:
            msg += "，并同步手机助手"
        return {
            "success": True,
            "connected": True,
            "device": target_dev,
            "pushed_files": pushed_files,
            "pc_synced_files": pc_synced,
            "elapsed_ms": elapsed_ms,
            "message": msg
        }
    else:
        return {
            "success": False,
            "connected": True,
            "device": target_dev,
            "message": f"推送到模拟器失败 (未成功写入任何路径)"
        }
