import os
import sys
import subprocess
import shutil
import time
import glob
import re
import json
import socket
import logging

if sys.stdout is not None and hasattr(sys.stdout, 'reconfigure'):
    try:
        sys.stdout.reconfigure(encoding='utf-8', errors='replace')
    except Exception:
        pass
if sys.stderr is not None and hasattr(sys.stderr, 'reconfigure'):
    try:
        sys.stderr.reconfigure(encoding='utf-8', errors='replace')
    except Exception:
        pass

logger = logging.getLogger("editor")

# 默认隔离 ADB 端口（避免与 MuMu/MFA 等占用 5037 默认端口的其他项目发生 kill-server 冲突）
DEFAULT_ADB_PORT = 5038
ADB_PORT = int(os.environ.get("ANDROID_ADB_SERVER_PORT", DEFAULT_ADB_PORT))
if "ANDROID_ADB_SERVER_PORT" not in os.environ:
    os.environ["ANDROID_ADB_SERVER_PORT"] = str(ADB_PORT)
if "ADB_SERVER_SOCKET" not in os.environ:
    os.environ["ADB_SERVER_SOCKET"] = f"tcp:localhost:{ADB_PORT}"

# 预设候选 ADB 路径 (优先雷电模拟器)
CANDIDATE_ADB_PATHS = [
    r"E:\leidian\LDPlayer9\adb.exe",
    r"D:\leidian\LDPlayer9\adb.exe",
    r"C:\leidian\LDPlayer9\adb.exe",
    r"D:\Program Files\Netease\MuMu\nx_main\adb.exe",
    r"D:\Program Files\Netease\MuMu\nx_device\15.0\shell\adb.exe",
    r"D:\ProgramData\按键精灵\按键精灵手机助手\android\adb.exe",
    r"E:\back 970pro\Program Files\Netease\MuMuPlayer-12.0\nx_main\adb.exe",
]

# PC 端按键精灵助手脚本目录候选
PC_ASSISTANT_SCRIPT_DIRS = [
    r"D:\ProgramData\按键精灵\按键精灵手机助手\Script",
    r"E:\back 970pro\ProgramData\按键精灵\按键精灵手机助手\Script",
]

# Windows 无控制台进程标志
CREATE_NO_WINDOW = 0x08000000 if sys.platform == "win32" else 0

_cached_adb_path = None

# 资产图库解耦规范：
# 1. EDITOR_IMAGES_DIR: 专属于 Editor 自身自动化流程（启动判定、推进登录、公告关闭、战斗状态识别等）
# 2. RUNNER_IMAGES_DIR: 专属于 Runner 脚本（打包 .atc 附件与推送至 /sdcard/FGO_Q/images/）
EDITOR_IMAGES_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "images", "editor"))
RUNNER_IMAGES_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "images", "attached images"))


def load_template_image(fname, preferred="editor"):
    """
    统一模板加载器（严格遵循 Editor / Runner 资产解耦规范）：
    - preferred='editor': 优先从 images/editor/ 加载，若无则从 images/attached images/ 或 editor_v5/images 兜底
    - preferred='runner': 优先从 images/attached images/ 加载，若无则从 images/editor/ 兜底
    """
    if not fname:
        return None
    try:
        import cv2
    except ImportError:
        return None

    dirs = (
        [EDITOR_IMAGES_DIR, RUNNER_IMAGES_DIR, os.path.join(os.path.dirname(__file__), "images")]
        if preferred == "editor"
        else [RUNNER_IMAGES_DIR, EDITOR_IMAGES_DIR, os.path.join(os.path.dirname(__file__), "images")]
    )
    for d in dirs:
        p = os.path.join(d, fname)
        if os.path.isfile(p):
            return cv2.imread(p)
    return None


# 就绪环境实时进度状态跟踪（供前端按钮高频拉取并展示当前子步骤）
_ready_env_progress = {
    "active": False,
    "icon": "⚡",
    "status": "就绪环境",
    "detail": "",
    "updated_at": 0
}

_is_environment_ready = False


def is_environment_ready():
    global _is_environment_ready
    return bool(_is_environment_ready)


def set_environment_ready(val: bool):
    global _is_environment_ready
    _is_environment_ready = bool(val)


def get_ready_env_progress():
    global _ready_env_progress, _is_environment_ready
    res = dict(_ready_env_progress)
    res["environment_ready"] = _is_environment_ready
    return res


def set_ready_env_progress(icon, status, detail=""):
    global _ready_env_progress
    _ready_env_progress["active"] = True
    _ready_env_progress["icon"] = icon
    _ready_env_progress["status"] = status
    _ready_env_progress["detail"] = detail
    _ready_env_progress["updated_at"] = time.time()
    logger.info(f"[就绪进度] {icon} {status} ({detail})")


def finish_ready_env_progress(success=True, message="已完全就绪"):
    global _ready_env_progress, _is_environment_ready
    _is_environment_ready = bool(success)
    _ready_env_progress["active"] = False
    _ready_env_progress["icon"] = "✅" if success else "❌"
    _ready_env_progress["status"] = "已就绪" if success else "就绪未完"
    _ready_env_progress["detail"] = message
    _ready_env_progress["updated_at"] = time.time()



def run_adb(args, timeout=5, capture_output=True):
    """统一执行 ADB 命令，自动设置 cwd 保证 DLL 加载、注入隔离端口并无窗口静默执行"""
    adb = args[0]
    cwd = os.path.dirname(adb) if (adb and os.path.isabs(adb)) else None
    stdout = subprocess.PIPE if capture_output else subprocess.DEVNULL
    stderr = subprocess.PIPE if capture_output else subprocess.DEVNULL
    env = os.environ.copy()
    env["ANDROID_ADB_SERVER_PORT"] = str(ADB_PORT)
    env["ADB_SERVER_SOCKET"] = f"tcp:localhost:{ADB_PORT}"
    return subprocess.run(
        args,
        cwd=cwd,
        stdin=subprocess.DEVNULL,
        stdout=stdout,
        stderr=stderr,
        env=env,
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


# 常见安卓模拟器监听端口 (MuMu 12, 雷电, MuMu经典, 夜神, 逍遥等)
COMMON_SIMULATOR_PORTS = [
    (16384, "MuMu 12"),
    (5555, "标准/雷电"),
    (7555, "MuMu 经典"),
    (16416, "MuMu 12-2"),
    (5557, "雷电-2"),
    (62001, "夜神模拟器"),
    (21503, "逍遥模拟器"),
]

DEVICE_STATE_FILE = os.path.join(os.path.dirname(__file__), ".selected_device.json")
_selected_device = None
_device_info_cache = {}
_device_vm_id_cache = {}
_listening_ports_cache = {}
_listening_ports_cache_ts = 0


def _get_process_image_path(pid: int) -> str:
    """Windows 获取进程完整路径 (QueryFullProcessImageNameW, 单进程耗时 <0.1ms)"""
    if sys.platform != "win32" or pid <= 4:
        return ""
    try:
        import ctypes
        import ctypes.wintypes
        kernel32 = ctypes.windll.kernel32
        PROCESS_QUERY_LIMITED_INFORMATION = 0x1000
        h = kernel32.OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, False, pid)
        if not h:
            return ""
        buf = ctypes.create_unicode_buffer(1024)
        size = ctypes.wintypes.DWORD(1024)
        path = ""
        if kernel32.QueryFullProcessImageNameW(h, 0, buf, ctypes.byref(size)):
            path = buf.value
        kernel32.CloseHandle(h)
        return path
    except Exception:
        return ""


def get_listening_ports_process_map(force=False):
    """获取 Windows 本地监听端口与进程的映射关系 (毫秒级高效解析)"""
    global _listening_ports_cache, _listening_ports_cache_ts
    now = time.time()
    if not force and (now - _listening_ports_cache_ts < 2.0) and _listening_ports_cache:
        return _listening_ports_cache

    if sys.platform != "win32":
        return {"by_endpoint": {}, "by_port": {}, "by_pid": {}}

    res_data = {"by_endpoint": {}, "by_port": {}, "by_pid": {}}
    try:
        res = subprocess.run(
            ['netstat', '-ano', '-p', 'tcp'],
            capture_output=True,
            text=True,
            timeout=2,
            creationflags=CREATE_NO_WINDOW
        )
        if res.returncode == 0:
            listeners = []
            pids = set()
            for line in res.stdout.splitlines():
                parts = line.strip().split()
                if len(parts) >= 5 and parts[0].upper() == 'TCP':
                    local_addr = parts[1]
                    state = parts[3].upper()
                    pid_str = parts[4]
                    if state == 'LISTENING' and ':' in local_addr:
                        try:
                            ip, port_str = local_addr.rsplit(':', 1)
                            port = int(port_str)
                            pid = int(pid_str)
                            if pid > 4:
                                listeners.append((ip, port, pid))
                                pids.add(pid)
                        except ValueError:
                            pass

            resolved_paths = {}
            for pid in pids:
                path = _get_process_image_path(pid)
                exe = os.path.basename(path).lower() if path else ""
                resolved_paths[pid] = (path, exe)

            for ip, port, pid in listeners:
                path, exe = resolved_paths.get(pid, ("", ""))
                entry = {"ip": ip, "port": port, "pid": pid, "path": path, "exe": exe}
                res_data["by_endpoint"][f"{ip}:{port}"] = entry
                if port not in res_data["by_port"]:
                    res_data["by_port"][port] = []
                res_data["by_port"][port].append(entry)
                if pid not in res_data["by_pid"]:
                    res_data["by_pid"][pid] = []
                res_data["by_pid"][pid].append(entry)
                if port not in res_data:
                    res_data[port] = entry
                elif any(k in exe for k in ("mumu", "dnplayer", "ld", "nox", "memu")):
                    res_data[port] = entry
    except Exception as e:
        logger.debug(f"[ADB] get_listening_ports_process_map error: {e}")

    _listening_ports_cache = res_data
    _listening_ports_cache_ts = now
    return res_data


def _pick_canonical_port_for_exe(ports, exe):
    """根据进程可执行文件名称与端口列表，挑选该模拟器的最优先主端口"""
    if not ports:
        return None
    exe = (exe or "").lower()
    # MuMu 12 / MuMu Nx: 首选 16384 + 32*k, 次选 7555, 最后 5555
    if any(k in exe for k in ("mumu", "nemu")):
        for p in ports:
            if 16384 <= p <= 16500:
                return p
        if 7555 in ports:
            return 7555
        return ports[0]
    # 雷电模拟器 (dnplayer / ldbox): 首选 5555, 5557
    if any(k in exe for k in ("dnplayer", "ld9box", "ldbox", "leidian")):
        if 5555 in ports:
            return 5555
        if 5557 in ports:
            return 5557
        return ports[0]
    # 夜神模拟器: 首选 62001
    if "nox" in exe:
        if 62001 in ports:
            return 62001
        return ports[0]
    # 逍遥模拟器: 首选 21503
    if any(k in exe for k in ("memu", "microvirt")):
        if 21503 in ports:
            return 21503
        return ports[0]
    # 默认：优先选特定模拟器常见端口，否则选首个
    for pref in (16384, 5555, 7555, 62001, 21503):
        if pref in ports:
            return pref
    return ports[0]


def get_device_vm_identifier(adb, dev: str) -> str:
    """获取 Android 虚拟机的唯一实例标识符，防止同一虚拟机的多端口别名重复识别。
    1. 优先使用 /proc/sys/kernel/random/boot_id (Linux 内核单次启动唯一 UUID)
    2. 备用 sys.vdid / persist.adb.wifi.guid
    3. 备用 ro.serialno / ro.boot.serialno
    """
    global _device_vm_id_cache
    if dev in _device_vm_id_cache:
        cached_id, cached_ts = _device_vm_id_cache[dev]
        if time.time() - cached_ts < 30.0:
            return cached_id

    vm_id = ""
    # 1. 内核 boot_id (每次 Linux 启动生成唯一 36 位 UUID)
    try:
        res = run_adb([adb, "-s", dev, "shell", "cat", "/proc/sys/kernel/random/boot_id"], timeout=1.5)
        if res.returncode == 0:
            val = res.stdout.decode("utf-8", errors="ignore").strip()
            if val and len(val) >= 16:
                vm_id = f"boot:{val}"
    except Exception:
        pass

    # 2. 备用 sys.vdid
    if not vm_id:
        try:
            res = run_adb([adb, "-s", dev, "shell", "getprop", "sys.vdid"], timeout=1.2)
            if res.returncode == 0:
                val = res.stdout.decode("utf-8", errors="ignore").strip()
                if val:
                    vm_id = f"vdid:{val}"
        except Exception:
            pass

    # 3. 备用 persist.adb.wifi.guid
    if not vm_id:
        try:
            res = run_adb([adb, "-s", dev, "shell", "getprop", "persist.adb.wifi.guid"], timeout=1.2)
            if res.returncode == 0:
                val = res.stdout.decode("utf-8", errors="ignore").strip()
                if val:
                    vm_id = f"guid:{val}"
        except Exception:
            pass

    # 4. 备用 ro.serialno
    if not vm_id:
        try:
            res = run_adb([adb, "-s", dev, "shell", "getprop", "ro.serialno"], timeout=1.2)
            if res.returncode == 0:
                val = res.stdout.decode("utf-8", errors="ignore").strip()
                if val:
                    vm_id = f"sn:{val}"
        except Exception:
            pass

    if vm_id:
        _device_vm_id_cache[dev] = (vm_id, time.time())
    return vm_id


def probe_and_connect_simulators(adb, existing_devices=None):
    """快速探测本地模拟器监听端口并自动发起 adb connect。
    具备多端口同源归并与多模拟器并行寻址能力：
    1. 进程归并：若某模拟器（如 MuMu 12）同时监听 16384、5555、7555，仅对其主端口 (16384) 发起连接。
    2. 多模拟器端口重叠智能分流：若 MuMu 占用了 127.0.0.1:5555，而雷电模拟器监听在 0.0.0.0:5555，
       自动分流连接 127.0.0.2:5555，确保两者同时在线互不踩踏。
    """
    existing = set(existing_devices or [])
    
    # 提取已通过本地标准管道连接的 emulator-xxxx 占用的端口 (adb port = console_port + 1)
    active_emulator_ports = set()
    for dev in existing:
        if dev.startswith("emulator-"):
            try:
                cport = int(dev.split("-")[1])
                active_emulator_ports.add(cport + 1)
            except Exception:
                pass

    port_map = get_listening_ports_process_map()
    by_pid = port_map.get("by_pid", {})
    by_port = port_map.get("by_port", {})

    # 获取已在线设备对应的 PID
    already_connected_pids = set()
    for dev in existing:
        port = None
        if ":" in dev:
            try:
                port = int(dev.split(":")[1])
            except ValueError:
                pass
        elif dev.startswith("emulator-"):
            try:
                cport = int(dev.split("-")[1])
                port = cport + 1
            except ValueError:
                pass
        if port and port in by_port:
            for l_info in by_port[port]:
                if dev.startswith("127.0.0.1:") and l_info["ip"] in ("127.0.0.1", "0.0.0.0"):
                    if port in (16384, 16416, 7555, 62001, 21503) or len(by_port[port]) == 1:
                        already_connected_pids.add(l_info["pid"])
                    elif l_info["ip"] == "127.0.0.1":
                        already_connected_pids.add(l_info["pid"])
                elif dev.startswith("127.0.0.2:") and l_info["ip"] == "0.0.0.0":
                    already_connected_pids.add(l_info["pid"])

    # 扫描未连接的模拟器进程并选择目标连接端点
    endpoints_to_connect = set()
    for pid, listeners in by_pid.items():
        exes = [l["exe"] for l in listeners if l.get("exe")]
        exe = exes[0] if exes else ""
        is_emu = any(k in exe for k in ("mumu", "nemu", "dnplayer", "ld", "nox", "memu", "microvirt", "bluestacks"))
        ports = [l["port"] for l in listeners]
        if not is_emu and not any(p in (16384, 5555, 7555, 62001, 21503) for p in ports):
            continue

        if pid in already_connected_pids:
            continue

        target_ep = None
        if any(k in exe for k in ("mumu", "nemu")):
            for p in ports:
                if 16384 <= p <= 16500:
                    target_ep = f"127.0.0.1:{p}"
                    break
            if not target_ep and 7555 in ports:
                target_ep = "127.0.0.1:7555"
        elif any(k in exe for k in ("dnplayer", "ld9box", "ldbox", "leidian")):
            # 必须从当前进程实际监听端口中匹配雷电 ADB 端口 (5555, 5557, 5559...)，严禁开机未就绪时提前盲连导致 VirtualBox NAT 重定向端口撞车失败
            ld_port = None
            for p in ports:
                if p in (5555, 5557, 5559, 5561, 5563, 5565):
                    ld_port = p
                    break
            if not ld_port:
                continue

            # 检测雷电模拟器端口是否被 MuMu 抢占 127.0.0.1
            mumu_on_port = False
            for other_l in by_port.get(ld_port, []):
                if other_l["pid"] != pid and any(k in other_l.get("exe", "") for k in ("mumu", "nemu")):
                    mumu_on_port = True
                    break

            if mumu_on_port:
                # 127.0.0.1 该端口已被 MuMu 占领，ADB 自动扫描生成的 emulator-xxxx 实为 MuMu！
                # 雷电必须通过 127.0.0.2 寻址 0.0.0.0，切勿因已存在 emulator-xxxx 而误跳过
                target_ep = f"127.0.0.2:{ld_port}"
            else:
                has_native_emu = any(d.startswith("emulator-") for d in existing)
                if has_native_emu:
                    continue
                target_ep = f"127.0.0.1:{ld_port}"
        elif "nox" in exe:
            if 62001 in ports:
                target_ep = "127.0.0.1:62001"
        elif any(k in exe for k in ("memu", "microvirt")):
            if 21503 in ports:
                target_ep = "127.0.0.1:21503"
        elif any(k in exe for k in ("bluestacks", "hd-player")):
            for p in ports:
                if p in (5555, 5557, 5559):
                    target_ep = f"127.0.0.1:{p}"
                    break
        else:
            for p in ports:
                if p in (5555, 7555, 62001, 21503, 16384):
                    target_ep = f"127.0.0.1:{p}"
                    break

        if target_ep and target_ep not in existing:
            endpoints_to_connect.add(target_ep)
            already_connected_pids.add(pid)

    # 兜底：对未绑定到 PID 的候选端口发起快速探测
    for port, _ in COMMON_SIMULATOR_PORTS:
        if port in active_emulator_ports:
            continue
        ep = f"127.0.0.1:{port}"
        if ep not in existing and ep not in endpoints_to_connect:
            try:
                with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
                    s.settimeout(0.03)
                    if s.connect_ex(("127.0.0.1", port)) == 0:
                        endpoints_to_connect.add(ep)
            except Exception:
                pass

    # 统一发起连接
    for ep in endpoints_to_connect:
        try:
            run_adb([adb, "connect", ep], timeout=2)
        except Exception:
            pass


def deduplicate_devices(adb, devices):
    """
    智能多维去重与冗余连接清理：
    1. 进程归组：对 127.0.0.1:port，若多个端口归属于同一 Windows 进程 PID，断开冗余端口连接，只保留主端口。
    2. 内核 boot_id / 实例 GUID 归组：同一 Android VM 若通过多个网络端点或本地管道接入，断开冗余端点。
    3. 别名互斥：emulator-N 与 127.0.0.1:(N+1) 互斥。
    """
    if not devices or len(devices) <= 1:
        return list(devices or [])

    port_map = get_listening_ports_process_map()

    # 1. 查找所有 emulator-xxxx 占用的 adb 端口
    emulator_ports = {}
    for dev in devices:
        if dev.startswith("emulator-"):
            try:
                cport = int(dev.split("-")[1])
                emulator_ports[cport + 1] = dev
            except Exception:
                pass

    # 2. 如果存在 emulator-N 与 127.0.0.1:(N+1)，断开 127.0.0.1:(N+1)
    stage1 = []
    for dev in devices:
        is_dup = False
        for port, emu_dev in emulator_ports.items():
            if dev in (f"127.0.0.1:{port}", f"localhost:{port}"):
                try:
                    run_adb([adb, "disconnect", dev], timeout=1)
                except Exception:
                    pass
                is_dup = True
                break
        if not is_dup:
            stage1.append(dev)

    if len(stage1) <= 1:
        return stage1

    # 3. 按 Windows 进程 PID 归组去重 (仅针对 127.0.0.1 / localhost 端口)
    pid_groups = {}
    non_pid_devs = []
    for dev in stage1:
        port = None
        if dev.startswith("127.0.0.1:") or dev.startswith("localhost:"):
            try:
                port = int(dev.split(":")[1])
            except ValueError:
                pass
        p_info = port_map.get(port) if port else None
        if p_info and p_info.get("pid"):
            pid = p_info["pid"]
            if pid not in pid_groups:
                pid_groups[pid] = []
            pid_groups[pid].append((dev, port, p_info.get("exe", "")))
        else:
            non_pid_devs.append(dev)

    stage2 = []
    for pid, group in pid_groups.items():
        if len(group) == 1:
            stage2.append(group[0][0])
        else:
            ports = [p for _, p, _ in group]
            exe = group[0][2]
            canonical_port = _pick_canonical_port_for_exe(ports, exe)
            canonical_dev = None
            for dev, port, _ in group:
                if port == canonical_port and not canonical_dev:
                    canonical_dev = dev
                else:
                    try:
                        run_adb([adb, "disconnect", dev], timeout=1)
                    except Exception:
                        pass
            if canonical_dev:
                stage2.append(canonical_dev)
            else:
                stage2.append(group[0][0])

    stage2.extend(non_pid_devs)
    if len(stage2) <= 1:
        return stage2

    # 4. 基于 Android 虚拟机实例唯一 ID (boot_id / vdid / serial) 二次去重
    # 关键：优先保留 emulator-xxxx 原生设备，将网络别名排在后面以便断开
    stage2.sort(key=lambda d: 0 if d.startswith("emulator-") else 1)
    seen_vms = {}
    result = []
    for dev in stage2:
        vm_id = get_device_vm_identifier(adb, dev)
        if vm_id:
            if vm_id in seen_vms:
                try:
                    if ":" in dev:
                        run_adb([adb, "disconnect", dev], timeout=1)
                except Exception:
                    pass
                continue
            seen_vms[vm_id] = dev
        result.append(dev)

    return result


_last_connected_devices = []
_last_devices_poll_ts = 0


def get_connected_devices(adb_path=None, force_refresh=False):
    """获取所有已连接且处于正常 device 状态的安卓设备列表 (支持自动探测 MuMu/雷电等全系模拟器并智能去重)"""
    global _last_connected_devices, _last_devices_poll_ts
    now = time.time()
    if not force_refresh and (now - _last_devices_poll_ts < 2.5):
        return _last_connected_devices

    adb = adb_path or find_adb()
    if not adb:
        return []

    # 1. 先读取当前 ADB 服务已知设备
    raw_devices = []
    try:
        res = run_adb([adb, "devices"], timeout=2)
        if res.returncode == 0:
            for line in res.stdout.decode("utf-8", errors="ignore").splitlines():
                parts = line.strip().split()
                if len(parts) >= 2:
                    if parts[1] == "device":
                        raw_devices.append(parts[0])
                    elif parts[1] == "offline":
                        try:
                            run_adb([adb, "disconnect", parts[0]], timeout=1)
                        except Exception:
                            pass
    except Exception:
        pass

    # 2. 仅对尚未连接的模拟器端口进行快速探针直连（避免给已在线的模拟器创建影子重复连接）
    try:
        probe_and_connect_simulators(adb, existing_devices=raw_devices)
    except Exception:
        pass

    # 3. 再次读取全量设备
    devices = []
    try:
        res = run_adb([adb, "devices"], timeout=3)
        if res.returncode == 0:
            for line in res.stdout.decode("utf-8", errors="ignore").splitlines():
                line = line.strip()
                if not line or line.startswith("List of devices"):
                    continue
                parts = line.split()
                if len(parts) >= 2 and parts[1] == "device":
                    devices.append(parts[0])
    except Exception:
        pass

    # 4. 智能过滤与去重
    deduped = deduplicate_devices(adb, devices)
    _last_connected_devices = deduped
    _last_devices_poll_ts = now
    return deduped


def get_device_friendly_info(adb, dev):
    """解析设备友好的模拟器型号与中文标签，综合本地进程、安卓系统特征与端口特征精准研判"""
    if dev in _device_info_cache:
        cached_info, cached_ts = _device_info_cache[dev]
        if time.time() - cached_ts < 15.0:
            return cached_info

    sim_name = None
    port_map = get_listening_ports_process_map()
    by_endpoint = port_map.get("by_endpoint", {})
    by_port = port_map.get("by_port", {})

    port = None
    ip = "127.0.0.1"
    if ":" in dev:
        try:
            ip, port_str = dev.split(":")
            port = int(port_str)
        except ValueError:
            pass
    elif dev.startswith("emulator-"):
        try:
            cport = int(dev.split("-")[1])
            port = cport + 1
        except ValueError:
            pass

    # 1. 尝试从本地 Windows 监听进程判定 (最精准)
    matched_entry = by_endpoint.get(f"{ip}:{port}")
    if not matched_entry and port and port in by_port:
        if ip == "127.0.0.2":
            for ent in by_port[port]:
                if ent["ip"] == "0.0.0.0":
                    matched_entry = ent
                    break
        if not matched_entry:
            matched_entry = by_port[port][0]

    if matched_entry and matched_entry.get("exe"):
        exe = matched_entry["exe"].lower()
        if any(k in exe for k in ("mumunx", "mumu12")):
            sim_name = "MuMu 12"
        elif any(k in exe for k in ("mumu", "nemu")):
            if port and 16384 <= port <= 16500:
                sim_name = "MuMu 12"
            else:
                sim_name = "MuMu 模拟器"
        elif any(k in exe for k in ("dnplayer", "ld9box", "ldbox", "leidian")):
            sim_name = "雷电模拟器"
        elif "nox" in exe:
            sim_name = "夜神模拟器"
        elif any(k in exe for k in ("memu", "microvirt")):
            sim_name = "逍遥模拟器"
        elif any(k in exe for k in ("bluestacks", "hd-player")):
            sim_name = "BlueStacks"

    # 2. 如果未能从进程识别，尝试从 Android 系统属性及特征识别
    if not sim_name:
        try:
            res = run_adb([adb, "-s", dev, "shell", "getprop", "init.svc.ldinit"], timeout=1.0)
            if res.returncode == 0 and res.stdout.strip() == b"running":
                sim_name = "雷电模拟器"
        except Exception:
            pass

    if not sim_name:
        try:
            res = run_adb([adb, "-s", dev, "shell", "getprop", "ro.leidian.version"], timeout=1.0)
            if res.returncode == 0 and res.stdout.strip():
                sim_name = "雷电模拟器"
        except Exception:
            pass

    if not sim_name:
        try:
            res = run_adb([adb, "-s", dev, "shell", "pm", "path", "com.android.ld.storeenter"], timeout=1.0)
            if res.returncode == 0 and b"package:" in res.stdout:
                sim_name = "雷电模拟器"
        except Exception:
            pass

    if not sim_name:
        try:
            res = run_adb([adb, "-s", dev, "shell", "pm", "path", "com.mumu.store"], timeout=1.0)
            if res.returncode == 0 and b"package:" in res.stdout:
                sim_name = "MuMu 12"
        except Exception:
            pass

    # 3. 兜底回退按端口/名称启发式判断
    if not sim_name:
        if port and (16384 <= port <= 16500):
            sim_name = "MuMu 12"
        elif port == 7555:
            sim_name = "MuMu 经典"
        elif port == 62001:
            sim_name = "夜神模拟器"
        elif port == 21503:
            sim_name = "逍遥模拟器"
        elif dev.startswith("emulator-"):
            sim_name = "安卓模拟器"
        else:
            sim_name = "安卓设备"

    model = ""
    try:
        res = run_adb([adb, "-s", dev, "shell", "getprop", "ro.product.model"], timeout=1.5)
        if res.returncode == 0:
            model = res.stdout.decode("utf-8", errors="ignore").strip()
    except Exception:
        pass

    if model:
        label = f"{sim_name} · {model} ({dev})"
    else:
        label = f"{sim_name} ({dev})"

    info = {
        "id": dev,
        "type": sim_name,
        "model": model,
        "label": label
    }
    _device_info_cache[dev] = (info, time.time())
    return info


def load_saved_device():
    """从磁盘加载用户保存的首选模拟器"""
    if os.path.isfile(DEVICE_STATE_FILE):
        try:
            with open(DEVICE_STATE_FILE, "r", encoding="utf-8") as f:
                data = json.load(f)
                return data.get("selected_device")
        except Exception:
            pass
    return None


def set_selected_device(dev):
    """设置并持久化当前选中的模拟器设备"""
    global _selected_device
    _selected_device = dev
    try:
        with open(DEVICE_STATE_FILE, "w", encoding="utf-8") as f:
            json.dump({"selected_device": dev}, f, ensure_ascii=False)
    except Exception as e:
        print(f"[ADB] Failed to save selected device: {e}", file=sys.stderr)
    return _selected_device


def get_selected_device(adb_path=None):
    """获取当前已选中的有效在线设备（若未选或失效则按策略智能选出最优默认并记忆）"""
    global _selected_device
    devices = get_connected_devices(adb_path)
    if not devices:
        return None

    # 1. 优先使用当前内存中已选且依然在线的设备
    if _selected_device and _selected_device in devices:
        if _selected_device == "emulator-5554" and "127.0.0.2:5555" in devices:
            set_selected_device("127.0.0.2:5555")
            return "127.0.0.2:5555"
        return _selected_device

    # 2. 从本地持久化配置文件恢复
    saved = load_saved_device()
    if saved:
        # 若保存的配置是 5555/emulator 族系，且当前存在明确的 127.0.0.2:5555 (雷电模拟器)，优先选用雷电
        if saved in ("127.0.0.1:5555", "127.0.0.2:5555", "emulator-5554") and "127.0.0.2:5555" in devices:
            set_selected_device("127.0.0.2:5555")
            return "127.0.0.2:5555"

        if saved in devices:
            _selected_device = saved
            return _selected_device
        # 兼容端口映射别名 (127.0.0.1:5555 <-> emulator-5554 <-> 127.0.0.2:5555)
        if saved in ("127.0.0.1:5555", "127.0.0.2:5555", "emulator-5554"):
            for dev in devices:
                if any(x in dev for x in ("5555", "emulator-5554")):
                    set_selected_device(dev)
                    return dev
        if saved in ("127.0.0.1:5555", "127.0.0.1:7555"):
            for dev in devices:
                if "16384" in dev or "16416" in dev:
                    set_selected_device(dev)
                    return dev

    # 3. 若无匹配，优先选择雷电模拟器（若有 127.0.0.2:5555），否则选择首个在线可用设备并记忆
    default_dev = "127.0.0.2:5555" if "127.0.0.2:5555" in devices else devices[0]
    set_selected_device(default_dev)
    return default_dev


def get_adb_status(force_refresh=False):
    """获取当前 ADB 及全部模拟器连接列表与当前选中项"""
    adb = find_adb()
    if not adb:
        return {
            "available": False,
            "connected": False,
            "device": None,
            "device_label": "未找到 adb.exe",
            "devices_info": [],
            "all_devices": [],
            "message": "未找到 adb.exe 命令行工具"
        }

    devices = get_connected_devices(adb, force_refresh=force_refresh)
    if not devices:
        return {
            "available": True,
            "connected": False,
            "adb_path": adb,
            "adb_port": ADB_PORT,
            "device": None,
            "device_label": "模拟器离线",
            "devices_info": [],
            "all_devices": [],
            "message": f"未检测到在线的安卓模拟器 (ADB端口: {ADB_PORT})"
        }

    target_dev = get_selected_device(adb)
    devices_info = []
    for d in devices:
        info = get_device_friendly_info(adb, d)
        devices_info.append({
            "id": d,
            "label": info["label"],
            "type": info["type"],
            "model": info["model"],
            "selected": (d == target_dev)
        })

    active_info = get_device_friendly_info(adb, target_dev) if target_dev else None
    display_label = active_info["label"] if active_info else target_dev

    return {
        "available": True,
        "connected": True,
        "adb_path": adb,
        "adb_port": ADB_PORT,
        "device": target_dev,
        "device_label": display_label,
        "all_devices": devices,
        "devices_info": devices_info,
        "message": f"已连接模拟器: {display_label} (ADB端口: {ADB_PORT})"
    }


def find_simulator_v4_config_files(adb, device):
    """扫描模拟器内部需要同步的目标文件：
       1. 模拟器历史工程配置 /sdcard/MobileAnJian/Script/fgo_battle_v5_config(...).mq（覆写防脏读）
       2. 规范化总线通信目录 /sdcard/FGO_Q/battle_v5_config.mq（V4 标准首选）
       注：已移除冗余备份 /sdcard/MobileAnJian/Script/battle_v5_config.mq
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
                if "battle_v5_config" in name.lower() and name.endswith(".mq"):
                    if name.lower() != "battle_v5_config.mq":
                        targets.append(f"/sdcard/MobileAnJian/Script/{name}")
    except Exception as e:
        print(f"[ADB] Error listing simulator script dir: {e}", file=sys.stderr)

    # 规范化总线通信目录（V4 首选）
    fgo_q_mq = "/sdcard/FGO_Q/battle_v5_config.mq"
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
            pattern = os.path.join(base_dir, "*battle_v5_config*.mq")
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

    target_dev = device or get_selected_device(adb) or devices[0]

    # 4. 准备临时推送文件
    temp_dir = os.path.join(os.path.dirname(__file__), ".tmp")
    os.makedirs(temp_dir, exist_ok=True)
    temp_file = os.path.join(temp_dir, "battle_v5_config_push.mq")
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

    target_dev = device or get_selected_device(adb) or devices[0]

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


def sync_images_to_simulator(adb=None, device=None):
    """
    将仓库中完整的图片资源目录 (images/attached images/) 全量推送到模拟器 (/sdcard/FGO_Q/images/)，
    确保模拟器热更图片库完整且与仓库最新一致，完全实现免 .atc 运行。
    """
    adb = adb or find_adb()
    if not adb:
        return {"success": False, "connected": False, "message": "未找到 adb.exe"}
    target_dev = device or get_selected_device(adb)
    if not target_dev:
        return {"success": False, "connected": False, "message": "未找到已连接设备"}

    repo_images_dir = RUNNER_IMAGES_DIR
    if not os.path.isdir(repo_images_dir):
        return {"success": False, "connected": True, "message": f"仓库图片目录不存在: {repo_images_dir}"}

    run_adb([adb, "-s", target_dev, "shell", "mkdir", "-p", "/sdcard/FGO_Q/images"])
    res = run_adb([adb, "-s", target_dev, "push", f"{repo_images_dir}/.", "/sdcard/FGO_Q/images/"], timeout=15)
    if res.returncode == 0:
        return {"success": True, "connected": True, "message": "全量图片库已同步至模拟器 /sdcard/FGO_Q/images/"}
    else:
        err = res.stderr.decode("utf-8", errors="ignore").strip()
        return {"success": False, "connected": True, "message": f"图片同步失败: {err}"}


V5_RUNNER_UUID = "d7a5b3c2-8e1f-4c92-a1b3-f5c7e8d9a0b1"
V5_RUNNER_NAME = "fgo_battle_v5_runner"


def ensure_v5_runner_deployed(adb=None, device=None):
    """
    检查并部署 V5 战斗 Runner 脚本 (fgo_battle_v5_runner) 至 PC 助手与模拟器
    确保脚本在按键精灵「未分类」中真实存在且配置合法。
    """
    adb = adb or find_adb()
    if not adb:
        return False
    target_dev = device or get_selected_device(adb)
    if not target_dev:
        return False

    sync_images_to_simulator(adb, target_dev)

    base_name = f"{V5_RUNNER_NAME}({V5_RUNNER_UUID})"
    repo_v5_runner = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "Q", "battle_v5_runner.q"))
    if not os.path.exists(repo_v5_runner):
        return False

    with open(repo_v5_runner, "rb") as f:
        mq_bytes = f.read()

    pc_atc_path = None
    for pc_dir in PC_ASSISTANT_SCRIPT_DIRS:
        if os.path.isdir(pc_dir):
            pc_mq = os.path.join(pc_dir, f"{base_name}.mq")
            pc_prop = os.path.join(pc_dir, f"{base_name}.prop")
            pc_uis = os.path.join(pc_dir, f"{base_name}.uis")
            pc_atc = os.path.join(pc_dir, f"{base_name}.atc")
            try:
                with open(pc_mq, "wb") as f:
                    f.write(mq_bytes)
                prop_data = {
                    "id": V5_RUNNER_UUID,
                    "Name": V5_RUNNER_NAME,
                    "repeat": 1,
                    "duration": 10,
                    "setStatue": "RUN_NUM",
                    "scriptType": "ONOE",
                    "isFirst": False
                }
                with open(pc_prop, "w", encoding="utf-8") as f:
                    json.dump(prop_data, f, separators=(",", ":"))

                if not os.path.exists(pc_uis):
                    v4_uis = os.path.join(pc_dir, "fgo_battle_v4_runner(3bfd2e42-6e25-4641-b06a-bd419c99d198).uis")
                    if os.path.exists(v4_uis):
                        shutil.copy2(v4_uis, pc_uis)
                    else:
                        with open(pc_uis, "wb") as f:
                            f.write(b"Function \xba\xaf\xca\xfd\xc3\xfb1()\n\nEnd Function\n")
                if not os.path.exists(pc_atc):
                    v4_atc = os.path.join(pc_dir, "fgo_battle_v4_runner(3bfd2e42-6e25-4641-b06a-bd419c99d198).atc")
                    if os.path.exists(v4_atc):
                        shutil.copy2(v4_atc, pc_atc)

                if os.path.exists(pc_atc):
                    pc_atc_path = pc_atc
            except Exception as e:
                print(f"[Deploy] PC script deploy warning: {e}", file=sys.stderr)

    # 检查模拟器内部是否存在 fgo_battle_v5_runner 且大小一致 (若仓库代码更新则自动同步)
    chk = run_adb([adb, "-s", target_dev, "shell", f"ls -l /sdcard/MobileAnJian/Script/*{V5_RUNNER_NAME}*.mq 2>/dev/null"])
    needs_sim_push = (chk.returncode != 0 or str(len(mq_bytes)) not in chk.stdout.decode("utf-8", errors="ignore"))

    if needs_sim_push:
        import tempfile
        tmp_dir = tempfile.gettempdir()
        tmp_mq = os.path.join(tmp_dir, f"{base_name}.mq")
        tmp_prop = os.path.join(tmp_dir, f"{base_name}.prop")
        tmp_uis = os.path.join(tmp_dir, f"{base_name}.uis")

        with open(tmp_mq, "wb") as f:
            f.write(mq_bytes)
        with open(tmp_prop, "w", encoding="utf-8") as f:
            json.dump({
                "id": V5_RUNNER_UUID,
                "Name": V5_RUNNER_NAME,
                "repeat": 1,
                "duration": 10,
                "setStatue": "RUN_NUM",
                "scriptType": "ONOE",
                "isFirst": False
            }, f, separators=(",", ":"))
        with open(tmp_uis, "wb") as f:
            f.write(b"Function \xba\xaf\xca\xfd\xc3\xfb1()\n\nEnd Function\n")

        run_adb([adb, "-s", target_dev, "push", tmp_mq, f"/sdcard/MobileAnJian/Script/{base_name}.mq"])
        run_adb([adb, "-s", target_dev, "push", tmp_prop, f"/sdcard/MobileAnJian/Script/{base_name}.prop"])
        run_adb([adb, "-s", target_dev, "push", tmp_uis, f"/sdcard/MobileAnJian/Script/{base_name}.uis"])
        if pc_atc_path and os.path.exists(pc_atc_path):
            run_adb([adb, "-s", target_dev, "push", pc_atc_path, f"/sdcard/MobileAnJian/Script/{base_name}.atc"])

        run_adb([adb, "-s", target_dev, "push", tmp_mq, "/sdcard/FGO_Q/battle_v5_runner.mq"])

        for p in [tmp_mq, tmp_prop, tmp_uis]:
            try:
                os.remove(p)
            except Exception:
                pass

    return True


def check_fgo_startup_screen(img=None, device=None):
    """
    毫秒级检测 FGO 当前是否处于启动阶段画面（闪屏、连接加载、小知识Tips、标题登录画面）。
    核心准则（逻辑取反）：
    游戏启动特征有限且固定（闪屏底色、白底连接中、标题登录画面、TOUCH SCREEN）。
    如果返回 is_startup=False，说明游戏已处于正常运行中（主页、战斗、编成、强化、商店等任意游戏内画面），
    无需且严禁执行推进主页流程，零触碰保留现场，即刻判定就绪。

    返回结构:
    {
        "is_startup": bool,     # True 表示处于启动阶段；False 表示已在正常运行中
        "stage": str,          # "splash" | "title" | "running" | "none"
        "reason": str,         # 判定依据描述
        "confidence": float    # 关键特征最高匹配置信度
    }
    """
    try:
        import cv2
        import numpy as np
    except ImportError:
        return {"is_startup": False, "stage": "none", "reason": "未安装 opencv-python", "confidence": 0.0}

    if isinstance(img, str):
        device = img
        img = None

    adb = find_adb()
    target_dev = device or (get_selected_device(adb) if adb else None)

    if img is None:
        if not adb or not target_dev:
            return {"is_startup": False, "stage": "none", "reason": "未找到设备", "confidence": 0.0}
        chk = run_adb([adb, "-s", target_dev, "shell", "dumpsys window | grep mCurrentFocus"], timeout=2)
        focus_str = chk.stdout.decode("utf-8", errors="ignore")
        if "com.bilibili.fatego" not in focus_str:
            return {"is_startup": True, "stage": "not_foreground", "reason": "FGO 不在前台", "confidence": 0.0}
        res = run_adb([adb, "-s", target_dev, "exec-out", "screencap", "-p"], timeout=3)
        if res.returncode != 0 or not res.stdout:
            return {"is_startup": True, "stage": "none", "reason": "截屏失败", "confidence": 0.0}
        try:
            img_raw = cv2.imdecode(np.frombuffer(res.stdout, np.uint8), cv2.IMREAD_COLOR)
            if img_raw is None:
                return {"is_startup": True, "stage": "none", "reason": "解码截屏失败", "confidence": 0.0}
            orig_h, orig_w = img_raw.shape[:2]
            img = cv2.resize(img_raw, (1440, 810)) if (orig_w, orig_h) != (1440, 810) else img_raw
        except Exception as e:
            return {"is_startup": True, "stage": "none", "reason": f"截屏异常: {e}", "confidence": 0.0}

    def load_tpl_local(fname):
        return load_template_image(fname, preferred="editor")

    # 1. 闪屏 / 加载黑白屏 / 白底奔跑芙芙连接中
    mean_val = float(img.mean())
    std_val = float(img.std())
    if mean_val < 15 or mean_val > 240 or (mean_val > 200 and std_val < 15.0):
        return {
            "is_startup": True,
            "stage": "splash",
            "reason": f"闪屏/连接加载 (均值={mean_val:.1f}, 方差={std_val:.1f})",
            "confidence": 1.0
        }

    # 2. 标题画面特异性元素识别
    # A. TOUCH SCREEN / 点击屏幕: y=500..750, x=400..1040
    tpl_touch = load_tpl_local("FGO_TOUCH_SCREEN.png")
    if tpl_touch is not None:
        roi_touch = img[500:750, 400:1040]
        s_touch = float(cv2.matchTemplate(roi_touch, tpl_touch, cv2.TM_CCOEFF_NORMED).max())
        if s_touch >= 0.72:
            return {"is_startup": True, "stage": "title", "reason": f"标题画面 TOUCH SCREEN (匹配度: {s_touch:.3f})", "confidence": s_touch}

    # B. 区服选择 / 服务器选择 (右下角): y=580..720, x=1150..1440
    tpl_tserver = load_tpl_local("FGO_TITLE_SERVER.png")
    if tpl_tserver is not None:
        roi_ts = img[580:720, 1150:1440]
        s_ts = float(cv2.matchTemplate(roi_ts, tpl_tserver, cv2.TM_CCOEFF_NORMED).max())
        if s_ts >= 0.78:
            return {"is_startup": True, "stage": "title", "reason": f"标题画面 区服选择 (匹配度: {s_ts:.3f})", "confidence": s_ts}

    tpl_sselect = load_tpl_local("FGO_SERVER_SELECT.png")
    if tpl_sselect is not None:
        roi_ss = img[580:720, 1150:1440]
        s_ss = float(cv2.matchTemplate(roi_ss, tpl_sselect, cv2.TM_CCOEFF_NORMED).max())
        if s_ss >= 0.78:
            return {"is_startup": True, "stage": "title", "reason": f"标题画面 选择服务器 (匹配度: {s_ss:.3f})", "confidence": s_ss}

    # C. 清除缓存 (左下角): y=580..720, x=20..300
    tpl_tcache = load_tpl_local("FGO_TITLE_CACHE.png")
    if tpl_tcache is not None:
        roi_tc = img[580:720, 20:300]
        s_tc = float(cv2.matchTemplate(roi_tc, tpl_tcache, cv2.TM_CCOEFF_NORMED).max())
        if s_tc >= 0.78:
            return {"is_startup": True, "stage": "title", "reason": f"标题画面 清除缓存 (匹配度: {s_tc:.3f})", "confidence": s_tc}

    # D. 点击推进提示 (小知识Tips底部): y=680..790, x=500..950
    tpl_tgame = load_tpl_local("FGO_TAP_GAME.png")
    if tpl_tgame is not None:
        roi_tg = img[680:790, 500:950]
        s_tg = float(cv2.matchTemplate(roi_tg, tpl_tgame, cv2.TM_CCOEFF_NORMED).max())
        if s_tg >= 0.78:
            return {"is_startup": True, "stage": "tips", "reason": f"启动加载提示「请点击游戏界面」 (匹配度: {s_tg:.3f})", "confidence": s_tg}

    # 3. 只有明确识别到游戏主页菜单 (HOME_MENU) 或战斗特征时，才判定为正常运行中
    tpl_home = load_tpl_local("FGO_HOME_MENU.png")
    if tpl_home is not None:
        roi_hm = img[680:790, 1240:1440]
        s_hm = float(cv2.matchTemplate(roi_hm, tpl_home, cv2.TM_CCOEFF_NORMED).max())
        if s_hm >= 0.82:
            return {"is_startup": False, "stage": "home", "reason": f"已处于游戏主页 (菜单匹配度: {s_hm:.3f})", "confidence": s_hm}

    b_info = check_fgo_in_battle(img=img, device=target_dev)
    if b_info.get("in_battle") or b_info.get("in_team"):
        return {"is_startup": False, "stage": "battle", "reason": f"已处于战斗/编成画面 ({b_info.get('scene')})", "confidence": b_info.get("confidence", 1.0)}

    # 4. 既非明确的在玩状态，也未匹配上述固定标识 -> 属于启动过渡/加载中画面
    return {
        "is_startup": True,
        "stage": "transition_loading",
        "reason": "启动过渡/加载中画面",
        "confidence": 0.5
    }


def check_fgo_in_battle(img=None, device=None):
    """
    毫秒级快速检测当前模拟器中 FGO 是否处于战斗画面（或队伍出击编成界面）。
    标准（在归一化 1440x810 标定下）：
    1. 右上角「战斗菜单」(BATTLE_MENU) 匹配度 >= 0.85
    2. 或右下角「攻击」(ATTACK_BTN) 匹配度 >= 0.85
    3. 或选卡阶段右下角「Back」(BATTLE_ATTACK_BACK) 匹配度 >= 0.90
    4. 或右侧「御主技能」(BATTLE_MASTER_SKILL_OPEN) 匹配度 >= 0.88
    5. 或队伍出击确认「开始任务」(START_BTN) 匹配度 >= 0.88 且不在主页
    返回字典: {"in_battle": bool, "in_team": bool, "scene": str, "confidence": float}
    """
    try:
        import cv2
        import numpy as np
    except ImportError:
        return {"in_battle": False, "in_team": False, "scene": "none", "confidence": 0.0}

    if isinstance(img, str):
        device = img
        img = None

    adb = find_adb()
    target_dev = device or (get_selected_device(adb) if adb else None)

    if img is None:
        if not adb or not target_dev:
            return {"in_battle": False, "in_team": False, "scene": "none", "confidence": 0.0}
        chk = run_adb([adb, "-s", target_dev, "shell", "dumpsys window | grep mCurrentFocus"], timeout=2)
        focus_str = chk.stdout.decode("utf-8", errors="ignore")
        if "com.bilibili.fatego" not in focus_str:
            return {"in_battle": False, "in_team": False, "scene": "none", "confidence": 0.0}
        res = run_adb([adb, "-s", target_dev, "exec-out", "screencap", "-p"], timeout=3)
        if res.returncode != 0 or not res.stdout:
            return {"in_battle": False, "in_team": False, "scene": "none", "confidence": 0.0}
        try:
            img_raw = cv2.imdecode(np.frombuffer(res.stdout, np.uint8), cv2.IMREAD_COLOR)
            if img_raw is None:
                return {"in_battle": False, "in_team": False, "scene": "none", "confidence": 0.0}
            orig_h, orig_w = img_raw.shape[:2]
            img = cv2.resize(img_raw, (1440, 810)) if (orig_w, orig_h) != (1440, 810) else img_raw
        except Exception:
            return {"in_battle": False, "in_team": False, "scene": "none", "confidence": 0.0}

    def load_tpl_local(fname):
        return load_template_image(fname, preferred="editor")

    # 1. 战斗菜单 (BATTLE_MENU) - 最稳定的战斗常驻标识
    tpl_bmenu = load_tpl_local("BATTLE_MENU.png")
    if tpl_bmenu is not None:
        roi_bmenu = img[200:300, 1300:1380]
        s_bmenu = float(cv2.matchTemplate(roi_bmenu, tpl_bmenu, cv2.TM_CCOEFF_NORMED).max())
        if s_bmenu >= 0.85:
            return {"in_battle": True, "in_team": False, "scene": "battle_menu", "confidence": s_bmenu}

    # 2. 攻击按钮 (ATTACK_BTN)
    tpl_atk = load_tpl_local("ATTACK_BTN.png")
    if tpl_atk is not None:
        roi_atk = img[650:780, 1180:1380]
        s_atk = float(cv2.matchTemplate(roi_atk, tpl_atk, cv2.TM_CCOEFF_NORMED).max())
        if s_atk >= 0.85:
            return {"in_battle": True, "in_team": False, "scene": "battle_attack", "confidence": s_atk}

    # 3. 选卡返回按钮 (BATTLE_ATTACK_BACK)
    tpl_back = load_tpl_local("BATTLE_ATTACK_BACK.png")
    if tpl_back is not None:
        roi_back = img[720:800, 1280:1420]
        s_back = float(cv2.matchTemplate(roi_back, tpl_back, cv2.TM_CCOEFF_NORMED).max())
        if s_back >= 0.90:
            return {"in_battle": True, "in_team": False, "scene": "battle_cards", "confidence": s_back}

    # 4. 右侧御主技能 (BATTLE_MASTER_SKILL_OPEN)
    tpl_ms = load_tpl_local("BATTLE_MASTER_SKILL_OPEN.png")
    if tpl_ms is not None:
        roi_ms = img[280:480, 1260:1380]
        s_ms = float(cv2.matchTemplate(roi_ms, tpl_ms, cv2.TM_CCOEFF_NORMED).max())
        if s_ms >= 0.88:
            return {"in_battle": True, "in_team": False, "scene": "battle_master_skill", "confidence": s_ms}

    # 5. 队伍出击确认 (START_BTN) 且不在主页
    tpl_start = load_tpl_local("START_BTN.png")
    tpl_home = load_tpl_local("FGO_HOME_MENU.png")
    s_home = float(cv2.matchTemplate(img[680:790, 1240:1440], tpl_home, cv2.TM_CCOEFF_NORMED).max()) if tpl_home is not None else 0.0
    if tpl_start is not None and s_home < 0.75:
        roi_start = img[650:800, 1180:1440]
        s_start = float(cv2.matchTemplate(roi_start, tpl_start, cv2.TM_CCOEFF_NORMED).max())
        if s_start >= 0.88:
            return {"in_battle": False, "in_team": True, "scene": "team_start", "confidence": s_start}

    return {"in_battle": False, "in_team": False, "scene": "none", "confidence": 0.0}


def navigate_fgo_to_home(device=None, max_wait_sec=115, progress_cb=None):
    """
    全自动智能引导 FGO 从冷启动/热唤醒/标题画面/各类活动公告及签到弹窗中，
    自动识别关键按钮并精准点击，直至成功进入游戏主页（检测到「菜单」按钮）。

    阶段策略：
    1. 确保 FGO 处于前台（若非前台则通过 monkey 自动调起）
    2. 加载阶段黑白屏与「加载中..」动画智能等待
    3. 加载提示「请点击游戏界面」自动识别并点击推进
    4. 标题画面「区服选择 / 清除缓存 / TOUCH SCREEN」自动识别并点击进入游戏登录
    5. 全屏游戏公告右上角黑白 [X]、模态弹窗银边 [X] 自动关闭
    6. 友情点数、签到、日常奖励弹窗底部白色「关闭」胶囊按钮精准识别点击
    7. 终端/主页金色「菜单」按钮检测确认已完全进入主界面并安全返回
    8. 兼容多种分辨率（自动以 1440x810 标定基准归一化匹配，并映射回真实屏幕物理坐标）
    """
    t0 = time.time()
    adb = find_adb()
    if not adb:
        return {"success": False, "connected": False, "message": "未找到 adb.exe"}

    target_dev = device or get_selected_device(adb)
    if not target_dev:
        return {"success": False, "connected": False, "message": "未检测到已连接的模拟器"}

    try:
        import cv2
        import numpy as np
    except ImportError:
        return {"success": False, "connected": True, "message": "未安装 opencv-python 或 numpy 图像库"}

    # 载入标定模板（从 images/editor/ 专属图库加载）
    def load_tpl(fname):
        return load_template_image(fname, preferred="editor")

    tpl_menu = load_tpl("FGO_HOME_MENU.png")
    tpl_close_modal = load_tpl("FGO_MODAL_CLOSE.png")
    tpl_calendar_title = load_tpl("FGO_CALENDAR_TITLE.png")
    tpl_modal_cancel = load_tpl("FGO_MODAL_CANCEL.png")
    tpl_notice_x = load_tpl("FGO_NOTICE_X.png")
    tpl_dialog_x = load_tpl("FGO_DIALOG_X.png")
    tpl_close_x = load_tpl("FGO_CLOSE_X.png")
    tpl_guide_tab = load_tpl("FGO_GUIDE_TAB.png")
    tpl_guide_tips = load_tpl("FGO_GUIDE_MONTH_TIPS.png")
    tpl_title_server = load_tpl("FGO_TITLE_SERVER.png")
    tpl_server_select = load_tpl("FGO_SERVER_SELECT.png")
    tpl_title_cache = load_tpl("FGO_TITLE_CACHE.png")
    tpl_touch_screen = load_tpl("FGO_TOUCH_SCREEN.png")
    tpl_tap_game = load_tpl("FGO_TAP_GAME.png")
    tpl_battle_detail_x = load_tpl("BATTLE_DETAIL_CLOSE_X.png")

    if tpl_menu is None:
        logger.warning("[FGO导航] 缺失核心特征图 FGO_HOME_MENU.png")
        return {"success": False, "connected": True, "message": "缺失核心特征图 FGO_HOME_MENU.png"}

    idle_count = 0
    idle_fallback_taps = 0
    title_tapped_count = 0
    popups_closed_since_title = 0
    last_title_tap_time = 0.0
    home_menu_first_seen_time = None
    consecutive_home_menu_count = 0
    logger.info(f"[FGO导航] 开始推进 FGO 状态至游戏主页 (最大等待 {max_wait_sec}s)...")

    while time.time() - t0 < max_wait_sec:
        # 1. 检查 FGO 是否在前台
        chk = run_adb([adb, "-s", target_dev, "shell", "dumpsys window | grep mCurrentFocus"])
        focus_str = chk.stdout.decode("utf-8", errors="ignore")
        if "com.bilibili.fatego" not in focus_str:
            set_ready_env_progress("📱", "唤醒游戏", "FGO 处于后台，重新唤起至前台")
            logger.info("[FGO导航] FGO 处于后台，重新唤起至前台...")
            run_adb([adb, "-s", target_dev, "shell", "monkey -p com.bilibili.fatego -c android.intent.category.LAUNCHER 1"])
            time.sleep(2.0)
            continue

        # 2. 抓取屏幕截图
        res = run_adb([adb, "-s", target_dev, "exec-out", "screencap", "-p"], timeout=5)
        if res.returncode != 0 or not res.stdout:
            time.sleep(1.0)
            continue

        try:
            img_raw = cv2.imdecode(np.frombuffer(res.stdout, np.uint8), cv2.IMREAD_COLOR)
        except Exception:
            time.sleep(1.0)
            continue

        if img_raw is None:
            time.sleep(1.0)
            continue

        orig_h, orig_w = img_raw.shape[:2]
        if (orig_w, orig_h) != (1440, 810):
            img = cv2.resize(img_raw, (1440, 810))
        else:
            img = img_raw

        def tap_screen(nx, ny):
            rx = int(nx * orig_w / 1440.0)
            ry = int(ny * orig_h / 810.0)
            run_adb([adb, "-s", target_dev, "shell", "input", "tap", str(rx), str(ry)])

        # 2.5 战斗画面保留判定：若当前已在战斗或队伍编成界面，保留现场即刻就绪
        b_info = check_fgo_in_battle(img=img, device=target_dev)
        if b_info.get("in_battle") or b_info.get("in_team"):
            elapsed = int(time.time() - t0)
            set_ready_env_progress("⚔️", "战斗就绪", "已处于战斗/队伍中")
            logger.info(f"[FGO导航] 检测到游戏当前已处于战斗/队伍中（{b_info.get('scene')}），零触碰保留现场即刻就绪！(耗时 {elapsed}s)")
            return {
                "success": True,
                "reached_home": False,
                "in_battle": True,
                "already_running": True,
                "device": target_dev,
                "elapsed_s": elapsed,
                "message": f"游戏当前已处于战斗/队伍画面（{b_info.get('scene')}），已成功就绪！(耗时 {elapsed}s)"
            }

        # 检查是否有从者详情等全屏模态弹窗遮挡（如长按/点击从者唤起的宝具/数值详细弹窗）
        if tpl_battle_detail_x is not None:
            roi_bx = img[40:120, 1180:1280]
            if cv2.matchTemplate(roi_bx, tpl_battle_detail_x, cv2.TM_CCOEFF_NORMED).max() >= 0.78:
                logger.info("[FGO导航] 检测到战斗/从者详情弹窗遮挡，点击右上角叉号关闭: (1226, 73)")
                tap_screen(1226, 73)
                time.sleep(1.0)
                continue

        # 3. 游玩指引弹窗处理 (左侧「游玩指引」Tab 或 左下角「本月不再提示」)
        is_guide_window = False
        if tpl_guide_tab is not None:
            roi_gtab = img[150:350, 0:200]
            if cv2.matchTemplate(roi_gtab, tpl_guide_tab, cv2.TM_CCOEFF_NORMED).max() >= 0.80:
                is_guide_window = True
        if not is_guide_window and tpl_guide_tips is not None:
            roi_gtips = img[720:785, 40:200]
            if cv2.matchTemplate(roi_gtips, tpl_guide_tips, cv2.TM_CCOEFF_NORMED).max() >= 0.80:
                is_guide_window = True

        if is_guide_window:
            set_ready_env_progress("📋", "游玩指引", "识别到游玩指引，处理本月不再提示")
            logger.info("[FGO导航] 识别到「游玩指引」弹窗！")

            # 检测是否已勾选「本月不再提示」
            inner_cb = img[743:763, 27:48]
            check_pixels = int(np.sum((inner_cb[:, :, 1] > 80) & (inner_cb[:, :, 2] > 80)))
            is_checked = (check_pixels > 25)

            if not is_checked:
                set_ready_env_progress("☑️", "游玩指引", "勾选左下角「本月不再提示」")
                logger.info(f"[FGO导航] 「本月不再提示」未勾选 (check_pixels={check_pixels})，点击勾选: (50, 752)")
                tap_screen(50, 752)
                time.sleep(0.6)
            else:
                logger.info(f"[FGO导航] 「本月不再提示」已处于勾选状态 (check_pixels={check_pixels})，无需重复点击")

            # 点击右上角关闭 [X]
            guide_x_cx, guide_x_cy = 1395, 42
            roi_gx = img[0:100, 1340:1440]
            for tx in [tpl_dialog_x, tpl_notice_x, tpl_close_x]:
                if tx is not None:
                    rgx = cv2.matchTemplate(roi_gx, tx, cv2.TM_CCOEFF_NORMED)
                    _, sgx, _, lgx = cv2.minMaxLoc(rgx)
                    if sgx >= 0.75:
                        guide_x_cx = 1340 + lgx[0] + tx.shape[1] // 2
                        guide_x_cy = 0 + lgx[1] + tx.shape[0] // 2
                        break

            set_ready_env_progress("❌", "游玩指引", f"点击右上角关闭: ({guide_x_cx}, {guide_x_cy})")
            logger.info(f"[FGO导航] 点击「游玩指引」右上角关闭 [X]: ({guide_x_cx}, {guide_x_cy})")
            tap_screen(guide_x_cx, guide_x_cy)
            idle_count = 0
            popups_closed_since_title += 1
            home_menu_first_seen_time = None
            consecutive_home_menu_count = 0
            time.sleep(1.5)
            continue

        # 4. 模态弹窗「关闭」胶囊按钮 (如友情点数/连续签到/说明，全面搜索底部区域)
        if tpl_close_modal is not None:
            roi_modal = img[520:760, 80:1360]
            res_m = cv2.matchTemplate(roi_modal, tpl_close_modal, cv2.TM_CCOEFF_NORMED)
            _, max_m, _, loc_m = cv2.minMaxLoc(res_m)
            if max_m >= 0.80:
                cx = 80 + loc_m[0] + tpl_close_modal.shape[1] // 2
                cy = 520 + loc_m[1] + tpl_close_modal.shape[0] // 2
                set_ready_env_progress("📋", "关闭弹窗", f"点击弹窗关闭按钮: ({cx}, {cy})")
                logger.info(f"[FGO导航] 识别到模态弹窗「关闭」按钮 (匹配度 {max_m:.3f})，点击: ({cx}, {cy})")
                tap_screen(cx, cy)
                idle_count = 0
                popups_closed_since_title += 1
                home_menu_first_seen_time = None
                consecutive_home_menu_count = 0
                time.sleep(1.5)
                continue

        # 4.5. 日历提醒订阅弹窗处理 (出现时点击「取消」胶囊按钮)
        is_calendar_popup = False
        cal_cx, cal_cy = 467, 628

        if tpl_calendar_title is not None:
            roi_cal = img[100:300, 400:1040]
            res_cal = cv2.matchTemplate(roi_cal, tpl_calendar_title, cv2.TM_CCOEFF_NORMED)
            _, max_cal, _, _ = cv2.minMaxLoc(res_cal)
            if max_cal >= 0.75:
                is_calendar_popup = True

        if not is_calendar_popup and tpl_modal_cancel is not None:
            # 即使未直接匹配到标题，若底部存在「取消」胶囊按钮且处于弹窗层
            roi_c = img[520:760, 80:1360]
            res_c = cv2.matchTemplate(roi_c, tpl_modal_cancel, cv2.TM_CCOEFF_NORMED)
            _, max_c, _, loc_c = cv2.minMaxLoc(res_c)
            if max_c >= 0.82:
                is_calendar_popup = True
                cal_cx = 80 + loc_c[0] + tpl_modal_cancel.shape[1] // 2
                cal_cy = 520 + loc_c[1] + tpl_modal_cancel.shape[0] // 2
        elif is_calendar_popup and tpl_modal_cancel is not None:
            roi_c = img[520:760, 80:1360]
            res_c = cv2.matchTemplate(roi_c, tpl_modal_cancel, cv2.TM_CCOEFF_NORMED)
            _, max_c, _, loc_c = cv2.minMaxLoc(res_c)
            if max_c >= 0.75:
                cal_cx = 80 + loc_c[0] + tpl_modal_cancel.shape[1] // 2
                cal_cy = 520 + loc_c[1] + tpl_modal_cancel.shape[0] // 2

        if is_calendar_popup:
            set_ready_env_progress("📅", "日历提醒", f"识别到日历提醒弹窗，点击取消: ({cal_cx}, {cal_cy})")
            logger.info(f"[FGO导航] 识别到日历提醒/系统弹窗，点击取消按钮: ({cal_cx}, {cal_cy})")
            tap_screen(cal_cx, cal_cy)
            idle_count = 0
            popups_closed_since_title += 1
            home_menu_first_seen_time = None
            consecutive_home_menu_count = 0
            time.sleep(1.5)
            continue

        # 5. 右上角关闭叉号 [X] (全屏公告、活动说明或模态通知，全面覆盖右上区域)
        max_x_score = 0.0
        best_x_loc = None
        best_x_tpl = None
        roi_x = img[0:220, 1050:1440]
        for tx in [tpl_notice_x, tpl_dialog_x, tpl_close_x]:
            if tx is not None:
                r = cv2.matchTemplate(roi_x, tx, cv2.TM_CCOEFF_NORMED)
                _, s, _, l = cv2.minMaxLoc(r)
                if s > max_x_score:
                    max_x_score, best_x_loc, best_x_tpl = s, l, tx

        if max_x_score >= 0.72 and best_x_loc is not None and best_x_tpl is not None:
            cx = 1050 + best_x_loc[0] + best_x_tpl.shape[1] // 2
            cy = 0 + best_x_loc[1] + best_x_tpl.shape[0] // 2
            set_ready_env_progress("❌", "关闭公告", f"点击右上角关闭叉号: ({cx}, {cy})")
            logger.info(f"[FGO导航] 识别到公告/弹窗右上角关闭叉号 [X] (匹配度 {max_x_score:.3f})，点击关闭: ({cx}, {cy})")
            tap_screen(cx, cy)
            idle_count = 0
            popups_closed_since_title += 1
            home_menu_first_seen_time = None
            consecutive_home_menu_count = 0
            time.sleep(1.5)
            continue

        # 6. 「请点击游戏界面」启动加载提示（出现在标题画面之前）
        if tpl_tap_game is not None:
            roi_tg = img[680:790, 500:950]
            res_tg = cv2.matchTemplate(roi_tg, tpl_tap_game, cv2.TM_CCOEFF_NORMED)
            _, max_tg, _, _ = cv2.minMaxLoc(res_tg)
            if max_tg >= 0.78:
                set_ready_env_progress("👆", "点击推进", "识别到游戏提示，点击推进")
                logger.info(f"[FGO导航] 识别到「请点击游戏界面」提示 (匹配度 {max_tg:.3f})，点击推进")
                tap_screen(720, 500)
                idle_count = 0
                time.sleep(2.0)
                continue

        # 7. 标题画面判定 (TOUCH SCREEN / 区服选择 / 选择服务器 / 清除缓存)
        is_title = False
        title_tap_x, title_tap_y = 720, 640

        if tpl_touch_screen is not None:
            roi_touch = img[500:750, 400:1040]
            res_touch = cv2.matchTemplate(roi_touch, tpl_touch_screen, cv2.TM_CCOEFF_NORMED)
            _, max_touch, _, loc_touch = cv2.minMaxLoc(res_touch)
            if max_touch >= 0.72:
                is_title = True
                title_tap_x = 400 + loc_touch[0] + tpl_touch_screen.shape[1] // 2
                title_tap_y = 500 + loc_touch[1] + tpl_touch_screen.shape[0] // 2

        if not is_title and tpl_title_server is not None:
            roi_ts = img[580:720, 1150:1440]
            res_ts = cv2.matchTemplate(roi_ts, tpl_title_server, cv2.TM_CCOEFF_NORMED)
            _, max_ts, _, _ = cv2.minMaxLoc(res_ts)
            if max_ts >= 0.78:
                is_title = True

        if not is_title and tpl_server_select is not None:
            roi_ss = img[580:720, 1150:1440]
            res_ss = cv2.matchTemplate(roi_ss, tpl_server_select, cv2.TM_CCOEFF_NORMED)
            _, max_ss, _, _ = cv2.minMaxLoc(res_ss)
            if max_ss >= 0.78:
                is_title = True

        if not is_title and tpl_title_cache is not None:
            roi_tc = img[580:720, 20:300]
            res_tc = cv2.matchTemplate(roi_tc, tpl_title_cache, cv2.TM_CCOEFF_NORMED)
            _, max_tc, _, _ = cv2.minMaxLoc(res_tc)
            if max_tc >= 0.78:
                is_title = True

        if is_title:
            title_tapped_count += 1
            popups_closed_since_title = 0
            home_menu_first_seen_time = None
            consecutive_home_menu_count = 0
            last_title_tap_time = time.time()
            set_ready_env_progress("🔑", "登录标题", "识别到标题画面，点击进入游戏")
            logger.info(f"[FGO导航] 识别到登录标题画面 (第 {title_tapped_count} 次)，点击进入: ({title_tap_x}, {title_tap_y})")
            tap_screen(title_tap_x, title_tap_y)
            idle_count = 0
            time.sleep(2.5) # 给网络连接与数据读取留出缓冲时间
            continue

        # 8. 核心判定：终端/主页金色「菜单」按钮 (HOME_MENU)
        roi_menu = img[680:790, 1240:1440]
        res_menu = cv2.matchTemplate(roi_menu, tpl_menu, cv2.TM_CCOEFF_NORMED)
        _, max_menu, _, _ = cv2.minMaxLoc(res_menu)
        if max_menu >= 0.82:
            # 必须严密核查：是否存在仍未关闭的公告 [X]、游玩指引或模态弹窗遮挡
            has_blocking_popup = False
            if tpl_close_modal is not None:
                if cv2.matchTemplate(img[520:760, 80:1360], tpl_close_modal, cv2.TM_CCOEFF_NORMED).max() >= 0.80:
                    has_blocking_popup = True

            if not has_blocking_popup:
                if tpl_calendar_title is not None and cv2.matchTemplate(img[100:300, 400:1040], tpl_calendar_title, cv2.TM_CCOEFF_NORMED).max() >= 0.75:
                    has_blocking_popup = True
                elif tpl_modal_cancel is not None and cv2.matchTemplate(img[520:760, 80:1360], tpl_modal_cancel, cv2.TM_CCOEFF_NORMED).max() >= 0.80:
                    has_blocking_popup = True

            if not has_blocking_popup:
                roi_x_chk = img[0:220, 1050:1440]
                for tx in [tpl_notice_x, tpl_dialog_x, tpl_close_x]:
                    if tx is not None and cv2.matchTemplate(roi_x_chk, tx, cv2.TM_CCOEFF_NORMED).max() >= 0.72:
                        has_blocking_popup = True
                        break

            if not has_blocking_popup:
                if tpl_guide_tab is not None and cv2.matchTemplate(img[150:350, 0:200], tpl_guide_tab, cv2.TM_CCOEFF_NORMED).max() >= 0.80:
                    has_blocking_popup = True
                elif tpl_guide_tips is not None and cv2.matchTemplate(img[720:785, 40:200], tpl_guide_tips, cv2.TM_CCOEFF_NORMED).max() >= 0.80:
                    has_blocking_popup = True

            if has_blocking_popup:
                set_ready_env_progress("🔍", "核验主页", "检测到底层菜单，但仍有弹窗遮挡")
                logger.info(f"[FGO导航] 检测到底层主页菜单 (匹配度 {max_menu:.3f})，但仍有公告/弹窗遮挡，继续优先关闭弹窗...")
                home_menu_first_seen_time = None
                consecutive_home_menu_count = 0
                time.sleep(1.0)
                continue

            # 关键保障：若从标题登录且尚未关闭过任何登录公告/弹窗
            # FGO 登录进入主界面后通常需要 2~5 秒才会异步拉取并弹出全屏公告与游玩指引！
            if title_tapped_count > 0 and popups_closed_since_title == 0:
                if home_menu_first_seen_time is None:
                    home_menu_first_seen_time = time.time()
                elapsed_waiting_notice = time.time() - home_menu_first_seen_time
                if elapsed_waiting_notice < 4.0:
                    set_ready_env_progress("⏳", "正在登录", f"已进入主界面，等待登录公告加载 ({int(elapsed_waiting_notice)}s)...")
                    logger.info(f"[FGO导航] 登录后首次检测到主界面菜单，持续监测公告弹出 ({elapsed_waiting_notice:.1f}s/4.0s)...")
                    time.sleep(1.0)
                    continue
                else:
                    logger.info("[FGO导航] 登录后持续 4 秒未检测到登录公告弹出，确认无弹窗阻挡")

            # 二次稳态确认：确保连续 2 轮无弹窗阻挡且稳定处于主界面
            consecutive_home_menu_count += 1
            if consecutive_home_menu_count < 2:
                time.sleep(1.0)
                continue

            elapsed = int(time.time() - t0)
            set_ready_env_progress("✅", "主页就绪", "成功就绪于游戏主页")
            logger.info(f"[FGO导航] 成功确认完全就绪于游戏主页（已处理弹窗数: {popups_closed_since_title}，无弹窗阻挡，耗时 {elapsed}s）")
            return {
                "success": True,
                "reached_home": True,
                "device": target_dev,
                "elapsed_s": elapsed,
                "message": f"已成功推进并就绪于 FGO 游戏主页！(耗时 {elapsed}s)"
            }

        # 9. 标题点击后的加载与等待公告阶段状态追踪
        time_since_title = (time.time() - last_title_tap_time) if last_title_tap_time > 0 else 999
        if title_tapped_count > 0 and time_since_title < 45:
            set_ready_env_progress("⏳", "正在登录", f"已点击标题，正在载入公告与数据 ({int(time_since_title)}s)...")

        # 10. 纯黑屏/纯白屏加载保护
        mean_b = img.mean()
        if mean_b < 15 or mean_b > 240:
            set_ready_env_progress("⏳", "正在加载", "等待游戏画面加载...")
            time.sleep(1.0)
            continue

        # 11. 兜底与加载状态追踪
        if title_tapped_count > 0 and time_since_title < 15:
            time.sleep(1.2)
            continue

        if title_tapped_count > 0:
            idle_count += 1
            if idle_count >= 2 and idle_fallback_taps < 5:
                idle_fallback_taps += 1
                logger.info(f"[FGO导航] 登录后连续未识别特定标识，尝试兜底轻触跳过过渡画面 (第 {idle_fallback_taps}/5 次)")
                tap_screen(720, 750)
                idle_count = 0
                time.sleep(1.2)
            else:
                time.sleep(1.0)
        else:
            set_ready_env_progress("⏳", "正在加载", "等待游戏启动与画面呈现...")
            time.sleep(1.0)

    elapsed = int(time.time() - t0)
    logger.warning(f"[FGO导航] 等待进入游戏主页超时 ({elapsed}s)")
    return {
        "success": False,
        "reached_home": False,
        "device": target_dev,
        "elapsed_s": elapsed,
        "message": f"等待进入游戏主页超时 ({elapsed}s)，请检查模拟器 FGO 状态"
    }


def check_fgo_at_home(device=None):
    """
    毫秒级快速检测当前模拟器中 FGO 是否在前台且已处于游戏主页/终端界面。
    标准：
    1. 前台聚焦 Activity 属于 com.bilibili.fatego
    2. 右下角金色「菜单」按钮 (HOME_MENU) 匹配度 >= 0.85
    3. 无阻断性模态弹窗（无关闭胶囊按钮、无右上角关闭叉号）
    """
    adb = find_adb()
    if not adb:
        return False
    target_dev = device or get_selected_device(adb)
    if not target_dev:
        return False

    chk = run_adb([adb, "-s", target_dev, "shell", "dumpsys window | grep mCurrentFocus"], timeout=2)
    focus_str = chk.stdout.decode("utf-8", errors="ignore")
    if "com.bilibili.fatego" not in focus_str:
        return False

    try:
        import cv2
        import numpy as np
    except ImportError:
        return False

    res = run_adb([adb, "-s", target_dev, "exec-out", "screencap", "-p"], timeout=3)
    if res.returncode != 0 or not res.stdout:
        return False

    try:
        img_raw = cv2.imdecode(np.frombuffer(res.stdout, np.uint8), cv2.IMREAD_COLOR)
    except Exception:
        return False

    if img_raw is None:
        return False

    orig_h, orig_w = img_raw.shape[:2]
    img = cv2.resize(img_raw, (1440, 810)) if (orig_w, orig_h) != (1440, 810) else img_raw

    # 载入模板 (优先从 images/editor/ 载入)
    def load_tpl(fname):
        return load_template_image(fname, preferred="editor")

    tpl_menu = load_tpl("FGO_HOME_MENU.png")
    if tpl_menu is None:
        return False

    roi_menu = img[680:790, 1240:1440]
    res_menu = cv2.matchTemplate(roi_menu, tpl_menu, cv2.TM_CCOEFF_NORMED)
    if res_menu.max() < 0.82:
        return False

    # 检查是否有阻断性弹窗「关闭」按钮
    tpl_modal = load_tpl("FGO_MODAL_CLOSE.png")
    if tpl_modal is not None:
        res_m = cv2.matchTemplate(img[520:760, 80:1360], tpl_modal, cv2.TM_CCOEFF_NORMED)
        if res_m.max() >= 0.80:
            return False

    # 检查是否有阻断性日历提醒弹窗 / 取消按钮
    tpl_cal_title = load_tpl("FGO_CALENDAR_TITLE.png")
    if tpl_cal_title is not None:
        if cv2.matchTemplate(img[100:300, 400:1040], tpl_cal_title, cv2.TM_CCOEFF_NORMED).max() >= 0.75:
            return False

    tpl_cancel = load_tpl("FGO_MODAL_CANCEL.png")
    if tpl_cancel is not None:
        if cv2.matchTemplate(img[520:760, 80:1360], tpl_cancel, cv2.TM_CCOEFF_NORMED).max() >= 0.80:
            return False

    # 检查是否有阻断性右上角叉号
    tpl_nx = load_tpl("FGO_NOTICE_X.png")
    tpl_dx = load_tpl("FGO_DIALOG_X.png")
    tpl_cx = load_tpl("FGO_CLOSE_X.png")
    roi_x = img[0:220, 1050:1440]
    for tx in [tpl_nx, tpl_dx, tpl_cx]:
        if tx is not None and cv2.matchTemplate(roi_x, tx, cv2.TM_CCOEFF_NORMED).max() >= 0.72:
            return False

    # 检查是否有游玩指引弹窗阻断
    tpl_gtab = load_tpl("FGO_GUIDE_TAB.png")
    if tpl_gtab is not None and cv2.matchTemplate(img[150:350, 0:200], tpl_gtab, cv2.TM_CCOEFF_NORMED).max() >= 0.80:
        return False
    tpl_gtips = load_tpl("FGO_GUIDE_MONTH_TIPS.png")
    if tpl_gtips is not None and cv2.matchTemplate(img[720:785, 40:200], tpl_gtips, cv2.TM_CCOEFF_NORMED).max() >= 0.80:
        return False

    return True


def launch_runner(device=None, wait_ready=True, target_script="fgo_battle_v5_runner", force_restart=False):
    """
    通过 ADB 全自动模拟按键精灵动态加载、
    在脚本列表中动态定位指定 Runner 脚本 (默认 fgo_battle_v5_runner)、
    并精准点击启动，直至就绪状态。
    """
    t0 = time.time()
    adb = find_adb()
    if not adb:
        return {"success": False, "connected": False, "message": "未找到 adb.exe"}

    devices = get_connected_devices(adb)
    if not devices:
        return {"success": False, "connected": False, "message": "未检测到在线安卓模拟器"}

    target_dev = device or get_selected_device(adb) or devices[0]

    # 1. 检查 Runner 是否已经在运行
    if not force_restart:
        status = get_runner_status(device=target_dev)
        if status.get("alive") and status.get("state") in ["IDLE", "RUNNING"]:
            return {
                "success": True,
                "connected": True,
                "device": target_dev,
                "already_running": True,
                "state": status.get("state"),
                "message": f"脚本已在运行 ({status.get('state')})，无需重复拉起"
            }
    else:
        run_adb([adb, "-s", target_dev, "shell", "am", "force-stop", "com.cyjh.mobileanjian"])
        time.sleep(1.0)

    # 2. 确保目标脚本文件已正确部署至模拟器
    ensure_v5_runner_deployed(adb, target_dev)

    # 检查当前是否已经停留在脚本列表页 (UserAppScriptActivity)，若是则可直接跳过冷启动导航
    already_at_script_list = False
    if not force_restart:
        chk_init = run_adb([adb, "-s", target_dev, "shell", "dumpsys window | grep mCurrentFocus"])
        if "UserAppScriptActivity" in chk_init.stdout.decode("utf-8", errors="ignore"):
            already_at_script_list = True
            logger.info("[Runner拉起] 当前模拟器已处于脚本列表页 (UserAppScriptActivity)，直接定位目标脚本")

    if not already_at_script_list:
        # 3. 唤醒按键精灵应用并动态等待 MainActivity（使用 -S 强制重置残留页面与弹窗状态）
        set_ready_env_progress("🚀", "唤醒按键", "唤醒按键精灵应用")
        run_adb([adb, "-s", target_dev, "shell", "am", "start", "-S", "-n", "com.cyjh.mobileanjian/.vip.activity.GuiActivity"])

        # 动态轮询等待 MainActivity（避开开屏广告）
        for _ in range(16):
            time.sleep(1)
            chk = run_adb([adb, "-s", target_dev, "shell", "dumpsys window | grep mCurrentFocus"])
            focus_str = chk.stdout.decode("utf-8", errors="ignore")
            if "com.cyjh.mobileanjian" in focus_str and "MainActivity" in focus_str:
                break

        time.sleep(1.5)

        # 4. 点击【编写】标签页 (701, 1109)
        set_ready_env_progress("📝", "编写界面", "进入脚本编写分类")
        run_adb([adb, "-s", target_dev, "shell", "input", "tap", "701", "1109"])
        for _ in range(10):
            time.sleep(0.5)
            chk = run_adb([adb, "-s", target_dev, "shell", "dumpsys window | grep mCurrentFocus"])
            if "UserActivity" in chk.stdout.decode("utf-8", errors="ignore"):
                break

        time.sleep(1.0)

        # 5. 点击【未分类】分类 (400, 767)
        set_ready_env_progress("📁", "查找脚本", "定位目标 Runner 脚本")
        run_adb([adb, "-s", target_dev, "shell", "input", "tap", "400", "767"])
        time.sleep(1.5)

    # 6. 动态解析 UI 树，精准查找指定目标脚本 (target_script) 及其左侧蓝色播放按钮坐标（绝不盲点任何随机坐标！）
    set_ready_env_progress("📁", "查找脚本", f"定位脚本 [{target_script}]")
    def is_anjian_foreground():
        chk = run_adb([adb, "-s", target_dev, "shell", "dumpsys window | grep mCurrentFocus"])
        return "com.cyjh.mobileanjian" in chk.stdout.decode("utf-8", errors="ignore")

    if not is_anjian_foreground():
        return {"success": False, "connected": True, "message": "按键精灵未在前台，已安全终止，防止误触"}

    target_cx = None
    target_cy = None
    play_cx = None
    play_cy = None
    for attempt in range(2):
        run_adb([adb, "-s", target_dev, "shell", "uiautomator", "dump", "/data/local/tmp/uidump.xml"], timeout=6)
        xml_res = run_adb([adb, "-s", target_dev, "shell", "cat", "/data/local/tmp/uidump.xml"], timeout=4)
        xml_str = xml_res.stdout.decode("utf-8", errors="ignore")

        if xml_str and "<hierarchy" in xml_str:
            import xml.etree.ElementTree as ET
            try:
                root = ET.fromstring(xml_str)
                parent_map = {c: p for p in root.iter() for c in p}
                for node in root.iter():
                    text = node.attrib.get("text", "")
                    if text == target_script or (not target_cx and text in ("fgo_battle_v5_runner", "battle_v5_runner")):
                        bounds = node.attrib.get("bounds", "")
                        m = re.match(r'\[(\d+),(\d+)\]\[(\d+),(\d+)\]', bounds)
                        if m:
                            target_cx = (int(m.group(1)) + int(m.group(3))) // 2
                            target_cy = (int(m.group(2)) + int(m.group(4))) // 2

                            # 向上遍历追溯至列表条目容器 (子级包含同一行的播放按钮与脚本名)
                            row = node
                            while row in parent_map and "fmas_lv" not in parent_map[row].attrib.get("resource-id", ""):
                                row = parent_map[row]

                            icon_node = None
                            for c in row.iter():
                                if "ibmg_title_icon" in c.attrib.get("resource-id", ""):
                                    icon_node = c
                                    break

                            if icon_node is not None:
                                im = re.match(r'\[(\d+),(\d+)\]\[(\d+),(\d+)\]', icon_node.attrib.get("bounds", ""))
                                if im:
                                    play_cx = (int(im.group(1)) + int(im.group(3))) // 2
                                    play_cy = (int(im.group(2)) + int(im.group(4))) // 2

                            # 几何兜底：左侧蓝色播放按钮居左 (X≈65, Y≈行中心)
                            if not play_cx or not play_cy:
                                play_cx = 65
                                play_cy = target_cy

                            if text == target_script:
                                break
            except Exception as e:
                logger.warning(f"[Runner拉起] 解析 UI 树异常: {e}")

        if target_cx and target_cy:
            break
        # 若第一页未找到，向上滑动列表重试
        if is_anjian_foreground():
            run_adb([adb, "-s", target_dev, "shell", "input", "swipe", "400", "900", "400", "300"])
            time.sleep(1.5)

    # 严禁盲点：如果未找到脚本，立即安全退出，绝不点击未知屏幕位置
    if not target_cx or not target_cy:
        return {
            "success": False,
            "connected": True,
            "device": target_dev,
            "message": f"未在按键精灵列表中找到脚本 [{target_script}]，已安全退出（未触发任何盲点）"
        }

    # 确认仍在前台后再点击
    if not is_anjian_foreground():
        return {"success": False, "connected": True, "message": "按键精灵偏离前台，已安全取消点击"}

    # 优先直接点击脚本左侧蓝色播放按钮 (直接弹出启动配置悬浮窗，无需进入详情页再点加载，节省1步并提速)
    click_x = play_cx if play_cx else target_cx
    click_y = play_cy if play_cy else target_cy
    action_desc = "蓝色播放按钮" if play_cx else "脚本条目"
    logger.info(f"[Runner拉起] 点击目标脚本 [{target_script}] {action_desc}: ({click_x}, {click_y})")
    set_ready_env_progress("▶", "启动脚本", f"点击播放按钮 ({click_x}, {click_y})")
    run_adb([adb, "-s", target_dev, "shell", "input", "tap", str(click_x), str(click_y)])
    time.sleep(1.2)

    # 7. 容错分支：若异常进入了脚本详情页 (MyScriptDetailInfoActivity)，点击【加载】(405, 1376)
    chk = run_adb([adb, "-s", target_dev, "shell", "dumpsys window | grep mCurrentFocus"])
    focus_str = chk.stdout.decode("utf-8", errors="ignore")
    if "MyScriptDetailInfoActivity" in focus_str:
        set_ready_env_progress("⚙️", "加载脚本", "加载配置与执行引擎")
        run_adb([adb, "-s", target_dev, "shell", "input", "tap", "405", "1376"])
        time.sleep(1.5)

    # 8. 在悬浮配置窗核验后点击【启动】(759, 691)
    if is_anjian_foreground():
        set_ready_env_progress("▶", "启动待命", "悬浮窗启动后台待命")
        run_adb([adb, "-s", target_dev, "shell", "input", "tap", "759", "691"])
        time.sleep(1.5)

    # 9. 启动成功后，切回 FGO 游戏前台并智能点击推进至游戏主页
    set_ready_env_progress("📱", "唤醒游戏", "切回 FGO 前台")
    logger.info(f"[Runner拉起] 脚本已加载启动，切回 FGO 前台并推进至游戏主页...")
    run_adb([adb, "-s", target_dev, "shell", "monkey -p com.bilibili.fatego -c android.intent.category.LAUNCHER 1"])

    # 自动识别标题画面、公告 [X]、签到弹窗「关闭」，直至进入主界面 (给予 115 秒充足容限)
    nav_res = navigate_fgo_to_home(device=target_dev, max_wait_sec=115)

    # 10. 验证是否成功进入 IDLE 待命
    runner_state = "UNKNOWN"
    if wait_ready:
        for _ in range(8):
            time.sleep(1)
            st = get_runner_status(device=target_dev)
            if st.get("alive") and st.get("state") in ["IDLE", "RUNNING"]:
                runner_state = st.get("state")
                break

    elapsed = int(time.time() - t0)
    reached_home = nav_res.get("reached_home", False)
    in_battle = nav_res.get("in_battle", False)
    if in_battle:
        home_desc = "已就绪于战斗画面"
    elif reached_home:
        home_desc = "已就绪于游戏主页"
    else:
        home_desc = "游戏唤醒中(未完全进入主页)"
    is_success = bool(runner_state in ["IDLE", "RUNNING"] and (reached_home or in_battle))
    logger.info(f"[Runner拉起] 完成: success={is_success}, state={runner_state}, reached_home={reached_home}, in_battle={in_battle} (耗时 {elapsed}s)")
    return {
        "success": is_success,
        "connected": True,
        "device": target_dev,
        "state": runner_state,
        "script": target_script,
        "fgo_navigation": nav_res,
        "elapsed_s": elapsed,
        "message": f"按键精灵 {target_script} ({runner_state})，{home_desc}！(总耗时 {elapsed}s)"
    }


def ready_environment(device=None, force_restart=False):
    """
    智能一键就绪环境：
    合并「拉起脚本」与「进入主页」为一个原子操作，按需执行：
    1. 哪个没完成就操作哪个：
       - 若脚本未拉起：优先执行拉起脚本（拉起完成后会自动将 FGO 唤起至前台并推进至游戏主页）
       - 若 FGO 未在主页：执行自动点击推进至主页（点击标题、关闭公告与弹窗）
    2. 若都没完成：先拉起脚本，再自动推进 FGO 进入游戏主页（严禁先启游戏再起脚本，避免游戏被前台打断导致二次重启）
    3. 若两者均已就绪：即时返回成功状态，提示可随时运行战斗
    """
    t0 = time.time()
    adb = find_adb()
    if not adb:
        finish_ready_env_progress(False, "未找到 adb.exe")
        return {"success": False, "connected": False, "message": "未找到 adb.exe"}

    target_dev = device or get_selected_device(adb)
    if not target_dev:
        finish_ready_env_progress(False, "未检测到在线安卓模拟器")
        return {"success": False, "connected": False, "message": "未检测到在线安卓模拟器"}

    set_ready_env_progress("🔍", "检查状态", "检查按键与游戏环境")
    logger.info(f"[就绪环境] 收到就绪环境检查请求 (device={target_dev}, force_restart={force_restart})")

    # 1. 检查 Runner 脚本状态
    st = get_runner_status(device=target_dev)
    runner_alive = bool(st.get("alive") and st.get("state") in ["IDLE", "RUNNING"])

    # 2. 场景：按键脚本未拉起（或明确要求强制重启）
    # 【核心避坑设计】：
    # 严禁在脚本尚未拉起前提前唤醒/启动 FGO！
    # 如果此时启动 FGO，紧接着拉起按键精灵会强行夺取前台焦点打断 FGO 的冷启动初始化，
    # 导致脚本拉起完成后 FGO 又被迫重新冷启动，造成游戏重复启动两次。
    # 必须严格遵循：先拉起按键脚本 -> 脚本待命后再唤起 FGO -> 推进至游戏主页。
    if force_restart or not runner_alive:
        set_ready_env_progress("🚀", "拉起脚本", "准备启动按键精灵与脚本")
        logger.info(f"[就绪环境] 脚本未处于待命状态 (alive={runner_alive}, force_restart={force_restart})，优先拉起脚本...")
        launch_res = launch_runner(device=target_dev, wait_ready=True, force_restart=force_restart)
        elapsed = int(time.time() - t0)

        fgo_nav = launch_res.get("fgo_navigation", {})
        reached = fgo_nav.get("reached_home", False) or fgo_nav.get("in_battle", False)
        runner_ok = launch_res.get("state") in ["IDLE", "RUNNING"]

        # launch_runner 内部已在脚本启动后切回 FGO 并调用 navigate_fgo_to_home 推进至主页
        if runner_ok and reached:
            finish_ready_env_progress(True, "按键脚本与游戏环境均已就绪")
            logger.info(f"[就绪环境] 按键脚本与 FGO 均已完全就绪 (总耗时 {elapsed}s)")
            launch_res["environment_ready"] = True
            launch_res["elapsed_s"] = elapsed
            return launch_res

        # 如果 Runner 已就绪，但 launch_runner 未尝试推进 FGO（例如命中缓存未做 navigation）
        if runner_ok and "reached_home" not in fgo_nav:
            set_ready_env_progress("📱", "推进主页", "智能推进 FGO 进入游戏主页...")
            logger.info("[就绪环境] Runner 已待命，补充推进 FGO 进入游戏主页...")
            nav_res = navigate_fgo_to_home(device=target_dev, max_wait_sec=115)
            elapsed = int(time.time() - t0)
            reached = nav_res.get("reached_home", False) or nav_res.get("in_battle", False)
            if reached:
                finish_ready_env_progress(True, "按键脚本与游戏环境均已就绪")
                logger.info(f"[就绪环境] 补充推进完成，成功就绪 (总耗时 {elapsed}s)")
                return {
                    "success": True,
                    "connected": True,
                    "device": target_dev,
                    "environment_ready": True,
                    "runner_state": launch_res.get("state"),
                    "fgo_navigation": nav_res,
                    "elapsed_s": elapsed,
                    "message": f"按键脚本 ({launch_res.get('state')}) 与 FGO 游戏均已完全就绪 (总耗时 {elapsed}s)！"
                }
            else:
                finish_ready_env_progress(False, "推进 FGO 进入游戏未完成")
                logger.warning(f"[就绪环境] 补充推进未能完全就绪: {nav_res.get('message')}")
                return {
                    "success": False,
                    "connected": True,
                    "device": target_dev,
                    "environment_ready": False,
                    "runner_state": launch_res.get("state"),
                    "fgo_navigation": nav_res,
                    "elapsed_s": elapsed,
                    "message": f"按键脚本已待命，但 FGO 未能完全就绪: {nav_res.get('message')}"
                }

        # 若未成功完成
        if launch_res.get("success"):
            finish_ready_env_progress(True, "按键脚本与游戏环境均已就绪")
        else:
            finish_ready_env_progress(False, launch_res.get("message", "就绪未完成"))
        launch_res["environment_ready"] = is_environment_ready()
        launch_res["elapsed_s"] = elapsed
        return launch_res

    # 3. 场景：按键脚本已经在后台正常待命 (runner_alive=True 且无需 force_restart)
    # 此时无需打开按键精灵，只需检查并就绪 FGO
    chk = run_adb([adb, "-s", target_dev, "shell", "dumpsys window | grep mCurrentFocus"], timeout=2)
    focus_str = chk.stdout.decode("utf-8", errors="ignore")
    fgo_in_focus = "com.bilibili.fatego" in focus_str

    if fgo_in_focus:
        # FGO 已在前台，快速检查是否已经在主页或战斗中
        at_home = check_fgo_at_home(device=target_dev)
        battle_info = check_fgo_in_battle(device=target_dev)
        in_battle = bool(battle_info.get("in_battle") or battle_info.get("in_team"))

        if at_home or in_battle:
            finish_ready_env_progress(True, "按键脚本与游戏环境均已就绪")
            ready_desc = "游戏主页" if at_home else "战斗/队伍中"
            elapsed = int(time.time() - t0)
            logger.info(f"[就绪环境] 按键脚本 ({st.get('state')}) 与游戏运行状态均已就绪（已处于{ready_desc}），零触碰秒级返回")
            return {
                "success": True,
                "connected": True,
                "device": target_dev,
                "already_ready": True,
                "environment_ready": True,
                "runner_state": st.get("state"),
                "at_home": at_home,
                "in_battle": in_battle,
                "elapsed_s": elapsed,
                "message": f"按键脚本 ({st.get('state')}) 与游戏均已正常运行（{ready_desc}），环境已完全就绪！"
            }

    # FGO 不在前台，或者虽在前台但尚未处于主页/战斗画面 -> 唤醒并推进进入主页
    if not fgo_in_focus:
        set_ready_env_progress("📱", "唤醒游戏", "唤起 FGO 至前台")
        logger.info("[就绪环境] 脚本已待命，FGO 处于后台或未启动，唤起至前台...")
        run_adb([adb, "-s", target_dev, "shell", "monkey -p com.bilibili.fatego -c android.intent.category.LAUNCHER 1"])
        time.sleep(1.2)

    set_ready_env_progress("📱", "推进主页", "智能推进 FGO 进入游戏主页...")
    logger.info(f"[就绪环境] 脚本已待命 ({st.get('state')})，推进 FGO 进入游戏主页...")
    nav_res = navigate_fgo_to_home(device=target_dev, max_wait_sec=115)
    elapsed = int(time.time() - t0)
    reached = nav_res.get("reached_home", False) or nav_res.get("in_battle", False)

    if reached:
        finish_ready_env_progress(True, "按键脚本与游戏环境均已就绪")
        logger.info(f"[就绪环境] 推进完成，FGO 环境已就绪 (耗时 {elapsed}s)")
        return {
            "success": True,
            "connected": True,
            "device": target_dev,
            "environment_ready": True,
            "runner_state": st.get("state"),
            "fgo_navigation": nav_res,
            "elapsed_s": elapsed,
            "message": f"按键脚本已在待命，FGO 环境已完全就绪！(耗时 {elapsed}s)"
        }
    else:
        finish_ready_env_progress(False, "推进 FGO 进入游戏未完成")
        logger.warning(f"[就绪环境] 推进 FGO 进入游戏未完成: {nav_res.get('message')}")
        return {
            "success": False,
            "connected": True,
            "device": target_dev,
            "environment_ready": False,
            "runner_state": st.get("state"),
            "fgo_navigation": nav_res,
            "elapsed_s": elapsed,
            "message": f"按键脚本已待命，但推进 FGO 进入游戏未完成: {nav_res.get('message')}"
        }



def format_duration(seconds):
    """将秒数格式化为人类友好的时间跨度（自动进位为秒/分/小时/天）"""
    s = max(0, int(seconds or 0))
    if s < 60:
        return f"{s}秒"
    days = s // 86400
    hours = (s % 86400) // 3600
    minutes = (s % 3600) // 60
    secs = s % 60

    res = ""
    if days > 0:
        res += f"{days}天"
    if hours > 0:
        res += f"{hours}小时"
    if minutes > 0 or (hours > 0 and secs > 0):
        res += f"{minutes}分"
    if secs > 0 or (not days and not hours):
        res += f"{secs}秒"
    return res


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

    target_dev = device or get_selected_device(adb) or devices[0]

    try:
        # 一次性获取当前时间戳、status.txt 修改时间、status 内容、以及最新日志最后 12 行
        # 一次性获取当前时间戳、status.txt 修改时间、按键进程、status 内容、以及最新日志最后 12 行
        shell_cmd = (
            "date +%s; "
            "stat -c %Y /sdcard/FGO_Q/status.txt 2>/dev/null || echo 0; "
            "pidof com.cyjh.mobileanjian 2>/dev/null || echo 0; "
            "echo ---STATUS---; "
            "cat /sdcard/FGO_Q/status.txt 2>/dev/null; "
            "echo ''; "
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

        # 解析时间戳与按键精灵进程活跃度
        header_lines = [l.strip() for l in header_part.splitlines() if l.strip()]
        now_ts = int(header_lines[0]) if len(header_lines) > 0 and header_lines[0].isdigit() else int(time.time())
        mtime_ts = int(header_lines[1]) if len(header_lines) > 1 and header_lines[1].isdigit() else 0
        anjian_pid = header_lines[2] if len(header_lines) > 2 else "0"
        anjian_alive = (anjian_pid != "0" and len(anjian_pid) > 0)

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

        mode_val = fields.get("mode", "").upper()
        raw_state = fields.get("state", "IDLE").upper()
        round_val = int(fields.get("round", 0)) if fields.get("round", "0").isdigit() else 0
        total_rounds = int(fields.get("total_rounds", 0)) if fields.get("total_rounds", "0").isdigit() else 0
        sub_round = int(fields.get("sub_round", 0)) if fields.get("sub_round", "0").isdigit() else 0
        action = fields.get("action", "")
        time_text = fields.get("time", "")
        msg = fields.get("msg", "")

        # 真实心跳与活性判定
        time_diff = max(0, now_ts - mtime_ts) if mtime_ts > 0 else 9999
        # 待命状态心跳已提升至 1 秒一次，超时门限设为 3 秒（3 倍容差，杜绝偶发延迟且 3 秒极速响应离线）；战斗中找图/宝具可能有长等待，超时门限 40 秒
        timeout_threshold = 40 if raw_state == "RUNNING" else 3

        if not anjian_alive or time_diff > timeout_threshold:
            alive = False
            state = "OFFLINE"
            set_environment_ready(False)
            if not anjian_alive:
                status_msg = "按键精灵未运行或已退出"
            else:
                formatted_diff = format_duration(time_diff)
                status_msg = f"脚本已停止或退出 (已离线 {formatted_diff})"
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
            "mode": mode_val,
            "environment_ready": is_environment_ready(),
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
        set_environment_ready(False)
        return {
            "available": True,
            "connected": True,
            "alive": False,
            "state": "OFFLINE",
            "environment_ready": False,
            "message": f"读取状态异常: {str(e)}",
            "logs": []
        }





