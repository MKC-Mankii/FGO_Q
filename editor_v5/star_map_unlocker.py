import os
import sys
import time
import json
import logging
import threading
import subprocess
import cv2
import numpy as np

# 统一日志
logger = logging.getLogger("editor")

# 引入项目环境路径
CURRENT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.dirname(CURRENT_DIR)
if PROJECT_ROOT not in sys.path:
    sys.path.insert(0, PROJECT_ROOT)
if CURRENT_DIR not in sys.path:
    sys.path.insert(0, CURRENT_DIR)

# Windows 无控制台进程标志 (彻底杜绝黑框弹窗闪烁)
CREATE_NO_WINDOW = 0x08000000 if sys.platform == "win32" else 0

EDITOR_IMAGES_DIR = os.path.join(PROJECT_ROOT, "images", "editor")

# 模板图片路径
TPL_SPARKLE_PATH = os.path.join(EDITOR_IMAGES_DIR, "STAR_MAP_SPARKLE.png")
TPL_EXECUTE_PATH = os.path.join(EDITOR_IMAGES_DIR, "STAR_MAP_EXECUTE.png")
TPL_NOTICE_CLOSE_PATH = os.path.join(EDITOR_IMAGES_DIR, "STAR_MAP_NOTICE_CLOSE.png")

# 尝试从 adb_sync 导入基础工具
try:
    from editor_v5.adb_sync import find_adb, get_selected_device, run_adb
except ImportError:
    try:
        from adb_sync import find_adb, get_selected_device, run_adb
    except ImportError:
        def find_adb():
            candidates = [
                r"E:\leidian\LDPlayer9\adb.exe",
                r"D:\leidian\LDPlayer9\adb.exe",
                r"C:\leidian\LDPlayer9\adb.exe",
                r"D:\Program Files\Netease\MuMu\nx_main\adb.exe",
            ]
            for c in candidates:
                if os.path.isfile(c):
                    return c
            return "adb"
            
        def get_selected_device(adb_path=None):
            return "emulator-5554"
            
        def run_adb(args, timeout=5, capture_output=True):
            stdout = subprocess.PIPE if capture_output else subprocess.DEVNULL
            stderr = subprocess.PIPE if capture_output else subprocess.DEVNULL
            return subprocess.run(
                args,
                stdin=subprocess.DEVNULL,
                stdout=stdout,
                stderr=stderr,
                creationflags=CREATE_NO_WINDOW,
                timeout=timeout
            )

# 全局运行状态与控制锁
_star_map_lock = threading.Lock()
_star_map_thread = None
_cancel_requested = False

_star_map_progress = {
    "running": False,
    "status": "IDLE",           # IDLE, RUNNING, FINISHED, CANCELLED, ERROR
    "message": "待命中",
    "liberated_count": 0,
    "current_action": "",
    "device": "",
    "updated_at": 0
}


def get_star_map_progress():
    with _star_map_lock:
        return dict(_star_map_progress)


def _set_progress(status, message, action="", liberated_inc=0):
    global _star_map_progress
    with _star_map_lock:
        _star_map_progress["status"] = status
        _star_map_progress["running"] = (status == "RUNNING")
        _star_map_progress["message"] = message
        if action:
            _star_map_progress["current_action"] = action
        if liberated_inc > 0:
            _star_map_progress["liberated_count"] += liberated_inc
        _star_map_progress["updated_at"] = time.time()
        logger.info(f"[星图解放] [{status}] {message} ({action})")


def request_stop_star_map():
    global _cancel_requested
    with _star_map_lock:
        _cancel_requested = True
        if _star_map_progress["running"]:
            _star_map_progress["message"] = "正在请求停止..."
            _star_map_progress["updated_at"] = time.time()
    logger.info("[星图解放] 收到停止请求")
    return {"success": True, "message": "已发送停止请求"}


def is_cancel_requested():
    global _cancel_requested
    return bool(_cancel_requested)


class StarMapAutomation:
    def __init__(self, adb_path=None, device=None, auto_swipe=True):
        self.adb = adb_path or find_adb()
        self.device = device or get_selected_device(self.adb) or "emulator-5554"
        self.auto_swipe = auto_swipe
        self.cwd = os.path.dirname(self.adb) if (self.adb and os.path.isabs(self.adb)) else None
        
        # 预载模板
        self.tpl_sparkle = cv2.imread(TPL_SPARKLE_PATH)
        self.tpl_execute = cv2.imread(TPL_EXECUTE_PATH, 0)
        self.tpl_notice_close = cv2.imread(TPL_NOTICE_CLOSE_PATH, 0)
        
        if self.tpl_sparkle is None:
            raise FileNotFoundError(f"Star sparkle template not found: {TPL_SPARKLE_PATH}")

    def screencap(self):
        """高速内存截屏 (静默无黑框窗口)"""
        cmd = [self.adb, "-s", self.device, "exec-out", "screencap", "-p"]
        proc = subprocess.run(
            cmd,
            cwd=self.cwd,
            stdin=subprocess.DEVNULL,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            creationflags=CREATE_NO_WINDOW
        )
        if proc.returncode != 0:
            raise RuntimeError(f"ADB screencap failed: {proc.stderr.decode('utf-8', errors='replace')}")
        arr = np.frombuffer(proc.stdout, dtype=np.uint8)
        img = cv2.imdecode(arr, cv2.IMREAD_COLOR)
        return img

    def tap(self, x, y):
        """ADB 点击指定坐标 (静默无黑框窗口)"""
        cmd = [self.adb, "-s", self.device, "shell", "input", "tap", str(int(x)), str(int(y))]
        subprocess.run(
            cmd,
            cwd=self.cwd,
            stdin=subprocess.DEVNULL,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            creationflags=CREATE_NO_WINDOW
        )

    def swipe(self, sx, sy, ex, ey, duration_ms=450):
        """ADB 平移拖拽手势 (静默无黑框窗口)"""
        cmd = [
            self.adb, "-s", self.device, "shell", "input", "swipe",
            str(int(sx)), str(int(sy)), str(int(ex)), str(int(ey)), str(int(duration_ms))
        ]
        subprocess.run(
            cmd,
            cwd=self.cwd,
            stdin=subprocess.DEVNULL,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            creationflags=CREATE_NO_WINDOW
        )

    def check_liberation_modal(self, img):
        """检查是否有「星座解放」/「旅程锁解放」弹窗 (匹配执行按钮)"""
        if self.tpl_execute is None:
            return False, None, None
        gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
        # 执行按钮区域: y: 650-780, x: 800-1100
        crop = gray[650:780, 800:1100]
        res = cv2.matchTemplate(crop, self.tpl_execute, cv2.TM_CCOEFF_NORMED)
        min_v, max_v, min_l, max_l = cv2.minMaxLoc(res)
        if max_v >= 0.80:
            btn_x = 800 + max_l[0] + self.tpl_execute.shape[1] // 2
            btn_y = 650 + max_l[1] + self.tpl_execute.shape[0] // 2
            return True, btn_x, btn_y
        return False, None, None

    def check_notice_modal(self, img):
        """检查是否有里程碑/任务达成提示弹窗 (匹配中央关闭按钮)"""
        if self.tpl_notice_close is None:
            return False, None, None
        gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
        # 关闭按钮区域: y: 580-720, x: 550-890
        crop = gray[580:720, 550:890]
        res = cv2.matchTemplate(crop, self.tpl_notice_close, cv2.TM_CCOEFF_NORMED)
        min_v, max_v, min_l, max_l = cv2.minMaxLoc(res)
        if max_v >= 0.80:
            btn_x = 550 + max_l[0] + self.tpl_notice_close.shape[1] // 2
            btn_y = 580 + max_l[1] + self.tpl_notice_close.shape[0] // 2
            return True, btn_x, btn_y
        return False, None, None

    def check_details_modal(self, img):
        """检查是否误触已解锁星座打开了「星座详情」展示窗"""
        # 星座详情窗是一个大黑框 (x: 150-1290, y: 275-675)
        # 内部有「星座详情」白色文字，可通过区域特征或右上角菱形 X 识别
        gray = cv2.cvtColor(img[280:360, 600:840], cv2.COLOR_BGR2GRAY)
        white_text = np.sum(gray > 220)
        # 检查中心区域黑色背景比例
        black_bg = np.sum((img[350:600, 400:1000, 0] < 25) & 
                          (img[350:600, 400:1000, 1] < 25) & 
                          (img[350:600, 400:1000, 2] < 25))
        if black_bg > 50000 and white_text > 100:
            return True
        return False

    def dismiss_overlays_if_present(self, img=None):
        """自动关闭干扰弹窗（通知提示或已解锁星座详情）"""
        if img is None:
            img = self.screencap()
            
        # 1. 里程碑/任务达成弹窗
        has_notice, close_x, close_y = self.check_notice_modal(img)
        if has_notice:
            logger.info(f"[星图解放] 检测到任务通知提示弹窗，点击关闭 ({close_x}, {close_y})...")
            self.tap(close_x, close_y)
            time.sleep(1.2)
            return True
            
        # 2. 星座详情展示窗 (点击外围空白处关闭)
        if self.check_details_modal(img):
            logger.info("[星图解放] 检测到星座详情展示窗，点击空白处自动关闭...")
            self.tap(720, 150)
            time.sleep(1.2)
            return True
            
        return False

    def detect_stars(self, img, blacklist=None, threshold=0.48):
        """
        高精度检测当前屏幕上所有可解放节点（星座分值与旅程锁）的黄色闪烁星光。
        结合模板匹配、HSV 黄色微元过滤与蓝光光晕阈值，杜绝误触与漏检。
        """
        if blacklist is None:
            blacklist = []
            
        res = cv2.matchTemplate(img, self.tpl_sparkle, cv2.TM_CCOEFF_NORMED)
        
        # 精准排除固定 UI：
        # 左上角返回/关闭按钮: x: 0-180, y: 0-90
        res[:90, :180] = 0
        # 右上角资源条与职阶名: x: 740-1440, y: 0-90
        res[:90, 740:] = 0
        # 左下角「效果一览/帮助」按钮: x: 0-200, y > 720
        res[720:, :200] = 0
        # 右下角「菜单」按钮: x > 1220, y > 710
        res[710:, 1220:] = 0
        # 右上方「使用回归沙漏」按钮: x: 1150-1400, y: 100-160
        res[100:160, 1150:1400] = 0
        
        h, w = self.tpl_sparkle.shape[:2]
        locs = np.where(res >= threshold)
        peaks = []
        for pt in zip(*locs[::-1]):
            val = res[pt[1], pt[0]]
            cx = pt[0] + w // 2
            cy = pt[1] + h // 2
            
            # 黑名单过滤 (防止反复点击失败坐标)
            if any(abs(cx - bx) < 30 and abs(cy - by) < 30 for bx, by in blacklist):
                continue
                
            # 去重邻近峰值
            if not any(abs(cx - p[0]) < 25 and abs(cy - p[1]) < 25 for p in peaks):
                # 1. 核心黄色微元核验 (杜绝深色宇宙背景噪点)
                patch_15 = img[max(0, cy-15):min(img.shape[0], cy+15), max(0, cx-15):min(img.shape[1], cx+15)]
                hsv_patch = cv2.cvtColor(patch_15, cv2.COLOR_BGR2HSV)
                yellow_px = np.sum(cv2.inRange(hsv_patch, (18, 60, 180), (38, 255, 255)) > 0)
                
                # 2. 蓝光光晕阈值核验 (旅程锁背后有冰蓝星光约 150-180，已解放节点环绕高强光晕 >400)
                patch_35 = img[max(0, cy-35):min(img.shape[0], cy+35), max(0, cx-35):min(img.shape[1], cx+35)]
                cyan_glow = np.sum((patch_35[:, :, 0] > 180) & (patch_35[:, :, 1] > 150) & (patch_35[:, :, 2] < 150))
                
                if yellow_px >= 18 and cyan_glow < 300:
                    peaks.append((cx, cy, val, yellow_px, cyan_glow))
                    
        # 按匹配度从高到低排序
        peaks.sort(key=lambda item: item[2], reverse=True)
        return [(p[0], p[1], p[2]) for p in peaks]

    def liberate_single_node(self, star_x, star_y, img=None):
        """点击并解放单个节点（兼顾普通星座分值与旅程锁）"""
        if img is None:
            img = self.screencap()
            
        # 节点/锁中心位于星光左下方约 18~22 像素
        node_x = max(15, star_x - 20)
        node_y = min(img.shape[0] - 15, star_y + 20)
        
        logger.info(f"[星图解放] 点击节点/锁 ({node_x}, {node_y}) [星光: ({star_x}, {star_y})]...")
        self.tap(node_x, node_y)
        time.sleep(1.3)
        
        # 检查是否弹出解放确认窗
        img_after = self.screencap()
        modal_open, exec_x, exec_y = self.check_liberation_modal(img_after)
        
        if not modal_open:
            # 重试直接点击星光坐标
            logger.info(f"[星图解放] 弹窗未出现，重试直接点击星光 ({star_x}, {star_y})...")
            self.tap(star_x, star_y)
            time.sleep(1.3)
            img_after = self.screencap()
            modal_open, exec_x, exec_y = self.check_liberation_modal(img_after)
            
        if modal_open:
            logger.info(f"[星图解放] 弹窗已展开，点击执行按钮 ({exec_x}, {exec_y})...")
            self.tap(exec_x, exec_y)
            time.sleep(2.8)
            
            # 解放完成后检查是否有任务达成提示窗
            self.dismiss_overlays_if_present()
            return True
            
        # 若弹出的不是解放窗而是星座详情，关闭它
        self.dismiss_overlays_if_present(img_after)
        return False

    def execute_all(self, max_nodes=150):
        """执行完整星图解放流程（含全图智能巡航平移与防死循环保护）"""
        _set_progress("RUNNING", "启动星图自动化解放引擎...", "准备截屏")
        liberated_count = 0
        blacklist = []
        
        # 4 方位全图巡航拖拽平移手势序列 (覆盖东、南、西、北各主干支线)
        SWIPE_EXPLORATION_STEPS = [
            ("向右平移探索 (探索右方分支)", 1100, 450, 400, 450),
            ("继续向右平移探索", 1100, 450, 400, 450),
            ("向上平移探索 (探索上方分支)", 720, 220, 720, 650),
            ("继续向上平移探索", 720, 220, 720, 650),
            ("向左平移探索 (探索左方分支)", 400, 450, 1100, 450),
            ("继续向左平移探索", 400, 450, 1100, 450),
            ("向下平移探索 (探索下方分支)", 720, 650, 720, 220),
            ("继续向下平移探索", 720, 650, 720, 220),
            ("回正星图中心", 400, 450, 750, 450),
        ]
        
        swipe_step_index = 0
        consecutive_swipes = 0
        max_total_swipes = len(SWIPE_EXPLORATION_STEPS)

        while liberated_count < max_nodes:
            if is_cancel_requested():
                _set_progress("CANCELLED", "星图解放已被用户取消", "停止运行")
                return {"success": False, "cancelled": True, "liberated_count": liberated_count}
                
            img = self.screencap()
            
            # 1. 优先关闭任何干扰遮罩弹窗
            if self.dismiss_overlays_if_present(img):
                continue
                
            # 2. 若已有解放确认弹窗则直接点击执行
            modal_open, exec_x, exec_y = self.check_liberation_modal(img)
            if modal_open:
                _set_progress("RUNNING", f"点击解放弹窗执行确认 ({exec_x}, {exec_y})", "点击执行")
                self.tap(exec_x, exec_y)
                time.sleep(2.8)
                liberated_count += 1
                _set_progress("RUNNING", f"成功解放第 {liberated_count} 个星图节点", "解放完成", liberated_inc=1)
                self.dismiss_overlays_if_present()
                blacklist.clear()
                consecutive_swipes = 0
                continue
                
            # 3. 扫描当前屏幕上的黄色闪烁星光
            stars = self.detect_stars(img, blacklist=blacklist)
            
            if stars:
                # 发现可用节点，重置平移计数器
                consecutive_swipes = 0
                star_x, star_y, score = stars[0]
                _set_progress(
                    "RUNNING",
                    f"发现 {len(stars)} 个可解放节点，正在点击 ({star_x}, {star_y})...",
                    f"点击节点 (相似度 {score:.2f})"
                )
                
                success = self.liberate_single_node(star_x, star_y, img)
                if success:
                    liberated_count += 1
                    _set_progress(
                        "RUNNING",
                        f"已成功解放第 {liberated_count} 个星座/旅程锁！",
                        "解放成功",
                        liberated_inc=1
                    )
                    # 游戏会自动将镜头对准刚解锁的节点，清空黑名单以便探测新分支
                    blacklist.clear()
                else:
                    logger.warning(f"[星图解放] 无法打开节点 ({star_x}, {star_y}) 的弹窗，加入临时黑名单")
                    blacklist.append((star_x, star_y))
                    
                continue

            # 4. 当前视野无新节点 -> 自动平移巡航探索其他象限
            if self.auto_swipe and consecutive_swipes < max_total_swipes:
                swipe_info = SWIPE_EXPLORATION_STEPS[swipe_step_index % len(SWIPE_EXPLORATION_STEPS)]
                swipe_name, sx, sy, ex, ey = swipe_info
                
                _set_progress(
                    "RUNNING",
                    f"当前画面无新节点，正在平移星图 ({consecutive_swipes+1}/{max_total_swipes}): {swipe_name}",
                    "全图巡航搜索"
                )
                
                self.swipe(sx, sy, ex, ey, duration_ms=450)
                time.sleep(1.2)
                
                swipe_step_index += 1
                consecutive_swipes += 1
                blacklist.clear()
                continue
                
            # 完整巡航所有方位后均未发现可解放目标，流程正常收尾
            break

        _set_progress("FINISHED", f"星图扫描解放完毕！共成功解放 {liberated_count} 个分值星座/旅程锁。", "全部完成")
        return {"success": True, "liberated_count": liberated_count}


def start_star_map_unlock(device=None, auto_swipe=True):
    """异步后台启动星图自动解放任务"""
    global _star_map_thread, _cancel_requested
    with _star_map_lock:
        if _star_map_progress["running"]:
            return {"success": False, "message": "星图解放任务已在运行中"}
        _cancel_requested = False
        _star_map_progress["running"] = True
        _star_map_progress["status"] = "RUNNING"
        _star_map_progress["message"] = "任务已启动，正在连接模拟器..."
        _star_map_progress["liberated_count"] = 0
        _star_map_progress["device"] = device or ""
        _star_map_progress["updated_at"] = time.time()

    def _worker():
        try:
            automation = StarMapAutomation(device=device, auto_swipe=auto_swipe)
            automation.execute_all()
        except Exception as e:
            logger.error(f"[星图解放] 运行异常: {e}", exc_info=True)
            _set_progress("ERROR", f"执行异常: {e}", "异常终止")

    _star_map_thread = threading.Thread(target=_worker, daemon=True)
    _star_map_thread.start()
    return {"success": True, "message": "星图自动解放任务已成功启动"}


if __name__ == "__main__":
    print("=== FGO 职阶星图自动化解放脚本 (Editor 原生极速引擎) ===")
    automation = StarMapAutomation(auto_swipe=True)
    res = automation.execute_all()
    print("运行结果:", res)
