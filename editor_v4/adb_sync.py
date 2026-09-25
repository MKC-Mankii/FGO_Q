import os
import sys
import subprocess
import shutil
import time
import glob
import re

# 预设候选 ADB 路径
CANDIDATE_ADB_PATHS = [
    r"D:\Program Files\Netease\MuMu\nx_main\adb.exe",
    r"D:\Program Files\Netease\MuMu\nx_device\15.0\shell\adb.exe",
    r"D:\ProgramData\按键精灵\按键精灵手机助手\android\adb.exe",
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


def run_adb(args, timeout=5, capture_output=True):
    """统一执行 ADB 命令，自动设置 cwd 保证 DLL 加载与无窗口静默执行"""
    adb = args[0]
    cwd = os.path.dirname(adb) if (adb and os.path.isabs(adb)) else None
    stdout = subprocess.PIPE if capture_output else subprocess.DEVNULL
    stderr = subprocess.PIPE if capture_output else subprocess.DEVNULL
    return subprocess.run(
        args,
        cwd=cwd,
        stdin=subprocess.DEVNULL,
        stdout=stdout,
        stderr=stderr,
        creationflags=CREATE_NO_WINDOW,
        timeout=timeout
    )


def find_adb():
    """查找系统中可用的 adb.exe 路径，优先使用缓存与 MuMu / 按键自带 adb"""
    global _cached_adb_path
    if _cached_adb_path and os.path.isfile(_cached_adb_path):
        return _cached_adb_path

    # 1. 扫描候选路径
    for path in CANDIDATE_ADB_PATHS:
        if os.path.isfile(path):
            try:
                res = run_adb([path, "version"], timeout=3)
                if res.returncode == 0:
                    _cached_adb_path = path
                    return path
            except Exception:
                continue

    # 2. 检查系统 PATH
    which_adb = shutil.which("adb")
    if which_adb and os.path.isfile(which_adb):
        try:
            res = run_adb([which_adb, "version"], timeout=3)
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
        res = run_adb([adb, "devices"], timeout=3)
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
        res = run_adb(
            [adb, "-s", device, "shell", "ls", "/sdcard/MobileAnJian/Script/"],
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
        run_adb(
            [adb, "-s", target_dev, "shell", "mkdir", "-p", "/sdcard/FGO_Q", "/sdcard/MobileAnJian/Script"],
            timeout=2,
            capture_output=False
        )
    except Exception:
        pass

    # 4. 扫描目标路径并批量推送到模拟器
    target_files = find_simulator_v4_config_files(adb, target_dev)
    pushed_files = []

    for remote_path in target_files:
        try:
            res = run_adb(
                [adb, "-s", target_dev, "push", temp_file, remote_path],
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


def send_runner_command(cmd, device=None):
    """向模拟器下发控制指令 (START / STOP / CLEAR)"""
    t0 = time.time()
    adb = find_adb()
    if not adb:
        return {"success": False, "connected": False, "message": "未找到 adb.exe"}

    devices = get_connected_devices(adb)
    if not devices:
        return {"success": False, "connected": False, "message": "未检测到在线安卓模拟器"}

    target_dev = device or ("emulator-5554" if "emulator-5554" in devices else devices[0])

    cmd_clean = (cmd or "").strip()
    try:
        shell_cmd = f"echo '{cmd_clean}' > /sdcard/FGO_Q/cmd.txt" if cmd_clean else "echo -n '' > /sdcard/FGO_Q/cmd.txt"
        res = run_adb(
            [adb, "-s", target_dev, "shell", shell_cmd],
            timeout=3
        )

        elapsed_ms = int((time.time() - t0) * 1000)
        if res.returncode == 0:
            return {
                "success": True,
                "connected": True,
                "command": cmd_clean,
                "device": target_dev,
                "elapsed_ms": elapsed_ms,
                "message": f"指令 [{cmd_clean}] 已下发 ({elapsed_ms}ms)"
            }
        else:
            return {
                "success": False,
                "connected": True,
                "message": f"写入指令失败: {res.stderr.decode('utf-8', errors='ignore').strip()}"
            }
    except Exception as e:
        return {"success": False, "connected": False, "message": f"下发指令异常: {str(e)}"}


def get_runner_status(device=None):
    """
    读取并解析模拟器 /sdcard/FGO_Q/status.txt 与最新运行日志，判断脚本运行状态与真实心跳
    """
    t0 = time.time()
    adb = find_adb()
    if not adb:
        return {"available": False, "connected": False, "alive": False, "state": "OFFLINE", "message": "未找到 adb.exe", "logs": []}

    devices = get_connected_devices(adb)
    if not devices:
        return {"available": True, "connected": False, "alive": False, "state": "OFFLINE", "message": "模拟器未连接", "logs": []}

    target_dev = device or ("emulator-5554" if "emulator-5554" in devices else devices[0])

    try:
        # 一次性获取当前时间戳、status.txt 修改时间、status 内容、以及最新日志最后 12 行
        shell_cmd = (
            "date +%s; "
            "stat -c %Y /sdcard/FGO_Q/status.txt 2>/dev/null || echo 0; "
            "echo ---STATUS---; "
            "cat /sdcard/FGO_Q/status.txt 2>/dev/null; "
            "echo ---LOGS---; "
            "ls -t /sdcard/com.cyjh.mobileanjian/log/*.log 2>/dev/null | head -n 1 | xargs tail -n 12 2>/dev/null"
        )
        res = run_adb(
            [adb, "-s", target_dev, "shell", shell_cmd],
            timeout=4
        )
        if res.returncode != 0:
            return {"available": True, "connected": True, "alive": False, "state": "OFFLINE", "message": "状态探测失败", "logs": []}

        # Android 系统内部（包括按键精灵日志文件与 status.txt）统一使用 UTF-8 编码
        try:
            raw_output = res.stdout.decode("utf-8")
        except UnicodeDecodeError:
            try:
                raw_output = res.stdout.decode("gbk")
            except UnicodeDecodeError:
                raw_output = res.stdout.decode("utf-8", errors="ignore")

        parts = raw_output.split("---STATUS---")
        header_part = parts[0].strip() if len(parts) > 0 else ""
        rest_part = parts[1] if len(parts) > 1 else ""

        body_parts = rest_part.split("---LOGS---")
        content = body_parts[0].strip() if len(body_parts) > 0 else ""
        raw_logs = body_parts[1].strip() if len(body_parts) > 1 else ""

        # 解析时间戳
        header_lines = [l.strip() for l in header_part.splitlines() if l.strip()]
        now_ts = int(header_lines[0]) if len(header_lines) > 0 and header_lines[0].isdigit() else int(time.time())
        mtime_ts = int(header_lines[1]) if len(header_lines) > 1 and header_lines[1].isdigit() else 0

        # 解析日志行
        log_lines = []
        for l in raw_logs.splitlines():
            l = l.strip()
            if l:
                # 规范化空格与制表符
                l_clean = " ".join(l.split())
                # 规整按键精灵默认的下划线行号标签：脚本第_802行 -> 脚本第802行
                l_clean = re.sub(r'脚本第_(\d+)行', r'脚本第\1行', l_clean)
                log_lines.append(l_clean)

        if not content:
            return {
                "available": True,
                "connected": True,
                "alive": False,
                "state": "OFFLINE",
                "device": target_dev,
                "message": "脚本尚未启动 (无状态文件)",
                "logs": log_lines
            }

        # 解析 status.txt 键值对
        fields = {}
        for line in content.splitlines():
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            if "=" in line:
                k, v = line.split("=", 1)
                fields[k.strip().lower()] = v.strip()

        raw_state = fields.get("state", "IDLE").upper()
        round_val = int(fields.get("round", 0)) if fields.get("round", "0").isdigit() else 0
        total_rounds = int(fields.get("total_rounds", 0)) if fields.get("total_rounds", "0").isdigit() else 0
        sub_round = int(fields.get("sub_round", 0)) if fields.get("sub_round", "0").isdigit() else 0
        action = fields.get("action", "")
        time_text = fields.get("time", "")
        msg = fields.get("msg", "")

        # 真实心跳与活性判定
        time_diff = max(0, now_ts - mtime_ts) if mtime_ts > 0 else 9999
        # 待命状态每 3 秒刷新心跳，超时门限 12 秒；战斗中找图/宝具可能有长等待，超时门限 40 秒
        timeout_threshold = 40 if raw_state == "RUNNING" else 12

        if time_diff > timeout_threshold:
            alive = False
            state = "OFFLINE"
            status_msg = f"脚本已停止或退出 (最后活跃于 {time_diff} 秒前)"
        else:
            alive = True
            state = raw_state
            status_msg = msg or f"当前状态: {state}"

        return {
            "available": True,
            "connected": True,
            "alive": alive,
            "device": target_dev,
            "state": state,
            "round": round_val,
            "total_rounds": total_rounds,
            "sub_round": sub_round,
            "action": action,
            "time": time_text,
            "heartbeat_age_s": time_diff,
            "message": status_msg,
            "logs": log_lines,
            "elapsed_ms": int((time.time() - t0) * 1000)
        }
    except Exception as e:
        return {
            "available": True,
            "connected": True,
            "alive": False,
            "state": "OFFLINE",
            "message": f"读取状态异常: {str(e)}",
            "logs": []
        }




