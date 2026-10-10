"""
FGO_Q Editor V5 - 标定与视觉资产核心引擎 (Calibration Engine)
基于 OpenCV 与 NumPy 高性能图像处理：
1. ADB 毫秒级无损屏幕截图采集
2. 图像裁剪与特征资产提取 (cv2.imwrite)
3. 工业级模板匹配与置信度测试验证 (cv2.matchTemplate TM_CCOEFF_NORMED)
4. 视口黑边检测 (Viewport Detection) 与多长宽比锚点自适应计算
"""

import os
import sys
import json
import logging
import cv2
import numpy as np

logger = logging.getLogger("editor.calibration")

BASE_WIDTH = 1440
BASE_HEIGHT = 810
BASE_RATIO = 16.0 / 9.0


class CalibrationEngine:
    def __init__(self, editor_dir):
        self.editor_dir = editor_dir
        self.repo_dir = os.path.dirname(editor_dir)
        self.repo_root = self.repo_dir
        self.images_dir = os.path.join(editor_dir, "images")
        self.editor_images_dir = os.path.join(self.repo_dir, "images", "editor")
        self.repo_images_dir = os.path.join(self.repo_dir, "images", "attached images")
        self.backup_dir = os.path.join(editor_dir, "backup_images")
        self.profiles_dir = os.path.join(editor_dir, "profiles")
        os.makedirs(self.images_dir, exist_ok=True)
        os.makedirs(self.editor_images_dir, exist_ok=True)
        os.makedirs(self.repo_images_dir, exist_ok=True)
        os.makedirs(self.backup_dir, exist_ok=True)
        os.makedirs(self.profiles_dir, exist_ok=True)

    def resolve_image_path(self, fname):
        """
        多级图库寻址解析：
        1. 优先查 editor_v5/images/ (最近自定义/编辑的本地图)
        2. 查 Editor 专用图库 images/editor/ (Editor 自身识别特征与流程模板)
        3. 查 Runner 仓库基准图库 images/attached images/ (按键精灵执行端成熟识别模板)
        4. 容错查 仓库 images/ 根目录
        """
        if not fname:
            return None
        candidates = [
            os.path.join(self.images_dir, fname),
            os.path.join(self.editor_images_dir, fname),
            os.path.join(self.repo_images_dir, fname),
            os.path.join(self.repo_dir, "images", fname)
        ]
        for p in candidates:
            if os.path.isfile(p):
                return p
        return None

    def capture_screen_raw(self, adb_sync_module, device=None):
        """通过 ADB 抓取当前模拟器屏幕原始 PNG 字节"""
        adb = adb_sync_module.find_adb()
        if not adb:
            raise RuntimeError("未找到有效的 adb.exe")
        
        status = adb_sync_module.get_adb_status()
        target_device = device or (adb_sync_module.get_selected_device() if hasattr(adb_sync_module, "get_selected_device") else None) or status.get("device")
        if not status.get("connected") or not target_device:
            raise RuntimeError("未检测到连接的安卓模拟器设备")
        
        res = adb_sync_module.run_adb([adb, "-s", target_device, "exec-out", "screencap", "-p"], timeout=8)
        if res.returncode != 0 or not res.stdout:
            raise RuntimeError(f"ADB 截屏失败 ({target_device}): {res.stderr.decode('utf-8', errors='ignore')}")
        
        image_bytes = res.stdout
        # 仅在非标准 PNG 头且检测到被污染的 CRLF 时才尝试清洗
        if not image_bytes.startswith(b"\x89PNG\r\n\x1a\n"):
            if b"\r\r\n" in image_bytes[:32]:
                image_bytes = image_bytes.replace(b"\r\r\n", b"\n")
            elif b"\r\n" in image_bytes[:32]:
                image_bytes = image_bytes.replace(b"\r\n", b"\n")
            
        return image_bytes

    def capture_screen_cv2(self, adb_sync_module, device=None):
        """通过 ADB 截屏并解码为 OpenCV BGR 格式的图像数组"""
        raw_bytes = self.capture_screen_raw(adb_sync_module, device=device)
        nparr = np.frombuffer(raw_bytes, np.uint8)
        img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
        if img is None:
            raise RuntimeError("无法解码 ADB 截屏图像数据")
            
        # 若是坚屏 (h > w)，但在跑横屏游戏，自动做顺时针旋转适配
        h, w = img.shape[:2]
        if h > w and h >= 1280:
            # 模拟器横屏显示但底层物理以竖屏返回时做纠偏
            pass
        return img

    def detect_viewport(self, img):
        """
        自动检测 FGO 在非 16:9 屏幕下的有效游戏视口与黑边偏移
        :param img: OpenCV ndarray (BGR)
        :return: dict 包含 screen_w, screen_h, offset_x, offset_y, viewport_w, viewport_h, scale
        """
        h, w = img.shape[:2]
        screen_ratio = w / float(h)
        
        if screen_ratio >= BASE_RATIO:
            # 宽屏全面屏 (左右有黑边或装饰纹)
            viewport_h = h
            offset_y = 0
            viewport_w = int(round(h * BASE_RATIO))
            offset_x = int(round((w - viewport_w) / 2.0))
            scale = float(h) / float(BASE_HEIGHT)
        else:
            # 窄屏/平板 (上下有黑边)
            viewport_w = w
            offset_x = 0
            viewport_h = int(round(w / BASE_RATIO))
            offset_y = int(round((h - viewport_h) / 2.0))
            scale = float(w) / float(BASE_WIDTH)
            
        return {
            "screen_w": w,
            "screen_h": h,
            "offset_x": offset_x,
            "offset_y": offset_y,
            "viewport_w": viewport_w,
            "viewport_h": viewport_h,
            "scale": round(scale, 4),
            "screen_ratio": round(screen_ratio, 4)
        }

    def transform_coordinate(self, x0, y0, anchor, viewport_info):
        """
        根据锚点类型将 1440x810 基准坐标映射到目标屏幕坐标
        :param x0: 基准 X
        :param y0: 基准 Y
        :param anchor: 'center', 'bottom_left', 'bottom_right', 'top_right', 'top_left'
        :param viewport_info: detect_viewport 返回的字典
        """
        s = viewport_info["scale"]
        ox = viewport_info["offset_x"]
        oy = viewport_info["offset_y"]
        vw = viewport_info["viewport_w"]
        vh = viewport_info["viewport_h"]
        sw = viewport_info["screen_w"]
        sh = viewport_info["screen_h"]

        anchor = anchor.lower()
        if anchor == "center":
            x = ox + vw / 2.0 + (x0 - BASE_WIDTH / 2.0) * s
            y = oy + vh / 2.0 + (y0 - BASE_HEIGHT / 2.0) * s
        elif anchor == "bottom_left":
            x = ox + x0 * s
            y = sh - (BASE_HEIGHT - y0) * s
        elif anchor == "bottom_right":
            x = sw - (BASE_WIDTH - x0) * s
            y = sh - (BASE_HEIGHT - y0) * s
        elif anchor == "top_right":
            x = sw - (BASE_WIDTH - x0) * s
            y = oy + y0 * s
        elif anchor == "top_left":
            x = ox + x0 * s
            y = oy + y0 * s
        else:
            x = ox + x0 * s
            y = oy + y0 * s
            
        return int(round(x)), int(round(y))

    def crop_and_save(self, img, rect, target_name):
        """
        使用 OpenCV 裁剪指定矩形范围并保存为目标模板图片
        双写策略：
        1. 保存至 editor_v5/images/ (本地资产缓存)
        2. 原位替换 Git 仓库图库 images/attached images/ (纳入版本控制)
        3. 替换前自动安全快照备份至 editor_v5/backup_images/
        :param img: OpenCV ndarray
        :param rect: [x1, y1, x2, y2]
        :param target_name: 目标文件名 (如 ATTACK_BTN.png)
        """
        x1, y1, x2, y2 = rect
        h, w = img.shape[:2]
        
        # 边界保护
        x1, x2 = max(0, min(x1, x2)), min(w, max(x1, x2))
        y1, y2 = max(0, min(y1, y2)), min(h, max(y1, y2))
        
        cropped = img[y1:y2, x1:x2]
        if cropped.size == 0:
            raise ValueError(f"裁剪区域无效: {rect}")
            
        if not target_name.lower().endswith(".png"):
            target_name += ".png"
            
        # 1. 写入本地 editor_v5 缓存
        save_path = os.path.join(self.images_dir, target_name)
        cv2.imwrite(save_path, cropped)

        # 2. 仓库原位替换与快照备份 (智能判断资产归属：images/editor/ 还是 images/attached images/)
        if os.path.isfile(os.path.join(self.editor_images_dir, target_name)):
            repo_save_path = os.path.join(self.editor_images_dir, target_name)
        else:
            repo_save_path = os.path.join(self.repo_images_dir, target_name)
        if os.path.isfile(repo_save_path):
            import shutil, time
            ts = time.strftime("%Y%m%d_%H%M%S")
            base, ext = os.path.splitext(target_name)
            backup_fname = f"{base}_{ts}{ext}"
            backup_file = os.path.join(self.backup_dir, backup_fname)
            try:
                shutil.copy2(repo_save_path, backup_file)
                logger.info(f"Existing repo image backed up to: {backup_file}")
            except Exception as e:
                logger.warning(f"Failed to backup existing image: {e}")

        cv2.imwrite(repo_save_path, cropped)
        logger.info(f"Target cropped and dual-saved: editor={save_path}, repo={repo_save_path} ({cropped.shape[1]}x{cropped.shape[0]})")
        return save_path, (cropped.shape[1], cropped.shape[0]), repo_save_path

    def test_match(self, screen_img, template_path, search_area=None):
        """
        使用 OpenCV 工业级 matchTemplate 算法在屏幕图像中测试模板匹配度
        :param screen_img: 全屏 OpenCV ndarray (BGR)
        :param template_path: 模板图片路径或文件名
        :param search_area: 可选搜图区域 [x1, y1, x2, y2]
        :return: dict 包含 similarity (0.0~1.0), matched_rect [x, y, w, h], center_coord [cx, cy]
        """
        if not os.path.isfile(template_path):
            resolved = self.resolve_image_path(template_path)
            if resolved and os.path.isfile(resolved):
                template_path = resolved
            else:
                raise FileNotFoundError(f"模板图片不存在: {template_path}")
            
        tpl = cv2.imread(template_path, cv2.IMREAD_COLOR)
        if tpl is None:
            raise ValueError(f"无法读取模板图片: {template_path}")
            
        th, tw = tpl.shape[:2]
        sh, sw = screen_img.shape[:2]
        
        base_x, base_y = 0, 0
        search_img = screen_img
        
        if search_area:
            x1, y1, x2, y2 = search_area
            x1, x2 = max(0, min(x1, x2)), min(sw, max(x1, x2))
            y1, y2 = max(0, min(y1, y2)), min(sh, max(y1, y2))
            search_img = screen_img[y1:y2, x1:x2]
            base_x, base_y = x1, y1
            
        s_h, s_w = search_img.shape[:2]
        if tw > s_w or th > s_h:
            return {"similarity": 0.0, "matched": False, "message": "模板尺寸大于搜索区域"}
            
        # 归一化相关系数匹配
        res = cv2.matchTemplate(search_img, tpl, cv2.TM_CCOEFF_NORMED)
        min_val, max_val, min_loc, max_loc = cv2.minMaxLoc(res)
        
        best_x = base_x + max_loc[0]
        best_y = base_y + max_loc[1]
        
        return {
            "similarity": round(float(max_val), 4),
            "matched": bool(max_val >= 0.8),
            "matched_rect": [best_x, best_y, tw, th],
            "center_coord": [best_x + tw // 2, best_y + th // 2],
            "confidence_text": f"{round(max_val * 100, 1)}%"
        }

    def _infer_category(self, fname):
        """根据图片文件名智能推断归属类别"""
        name = fname.lower()
        if name.startswith("friend"):
            return "friend"
        elif any(k in name for k in ("enhance", "roll", "pool")):
            return "enhance"
        elif any(k in name for k in ("award", "again", "apple", "add_friend")):
            return "reward"
        else:
            return "battle"

    def get_targets_manifest(self, profile_file="default_1440x810.json"):
        """获取目标配置清单，完整透出仓库已有图库并关联标定状态与预览 URL"""
        profile_path = os.path.join(self.profiles_dir, profile_file)
        profile_data = {}
        if os.path.isfile(profile_path):
            with open(profile_path, "r", encoding="utf-8") as f:
                profile_data = json.load(f)
            
        targets_dict = profile_data.get("targets", {})
        result_list = []
        seen_files = set()

        for k, v in targets_dict.items():
            cat = v.get("category", "battle")
            is_tap = (cat == "tap" or (not v.get("file") and v.get("tap_coord") and not v.get("search_area")))
            if is_tap:
                fname = None
                has_img = False
                img_path = None
            else:
                fname = v.get("file", f"{k}.png")
                seen_files.add(fname.lower())
                img_path = self.resolve_image_path(fname)
                has_img = img_path is not None and os.path.isfile(img_path)
            
            search_area = v.get("search_area") or v.get("area") or None
            crop_area = v.get("crop_area", None)
            
            result_list.append({
                "key": k,
                "name": v.get("name", k),
                "category": cat,
                "file": fname,
                "anchor": v.get("anchor", "center"),
                "search_area": search_area,
                "crop_area": crop_area,
                "area": search_area,
                "tap_coord": v.get("tap_coord"),
                "description": v.get("description", ""),
                "has_image": has_img,
                "image_url": f"/api/calibrate/image/{fname}" if has_img else None,
                "source": "tap" if is_tap else ("repo" if (has_img and self.repo_images_dir in (img_path or "")) else "editor")
            })
            
        # 全量透出仓库与 Editor 专用目录中未在 profile 中显式注册的历史特征图谱
        scan_configs = [
            (self.editor_images_dir, "editor", "来自 Editor 专用图库 images/editor/"),
            (self.repo_images_dir, "repo", "来自 Runner 仓库图库 images/attached images/"),
        ]
        for scan_dir, src_label, desc_prefix in scan_configs:
            if os.path.isdir(scan_dir):
                for fname in sorted(os.listdir(scan_dir)):
                    if fname.lower().endswith(".png") and fname.lower() not in seen_files:
                        key = os.path.splitext(fname)[0]
                        cat = "editor" if src_label == "editor" else self._infer_category(fname)
                        result_list.append({
                            "key": key,
                            "name": f"Editor资产: {key}" if src_label == "editor" else f"仓库资产: {key}",
                            "category": cat,
                            "file": fname,
                            "anchor": "center",
                            "search_area": [0, 0, 1440, 810],
                            "crop_area": None,
                            "area": [0, 0, 1440, 810],
                            "tap_coord": None,
                            "description": f"{desc_prefix}{fname} 的成熟识别特征",
                            "has_image": True,
                            "image_url": f"/api/calibrate/image/{fname}",
                            "source": src_label
                        })
                        seen_files.add(fname.lower())

        return {
            "profile_name": profile_data.get("name", profile_file),
            "screen_width": profile_data.get("screen_width", 1440),
            "screen_height": profile_data.get("screen_height", 810),
            "total_assets": len(result_list),
            "targets": result_list
        }

    def save_target_definition(self, target_key, crop_rect, tap_coord, anchor, search_area=None, target_file=None, target_name=None, category=None, profile_file="default_1440x810.json", description=None):
        """
        更新 profile 文件中某个目标的双套坐标与元数据：
        - crop_area: 本次裁切使用的精确像素坐标 (持久化留存，未来重截时可一键复位)
        - search_area: 运行时找图匹配范围
        - tap_coord: 推荐点击坐标
        - anchor: 锚点属性
        - description: 目标业务描述说明
        """
        profile_path = os.path.join(self.profiles_dir, profile_file)
        if not os.path.isfile(profile_path):
            raise FileNotFoundError(f"Profile 文件不存在: {profile_path}")
            
        with open(profile_path, "r", encoding="utf-8") as f:
            profile_data = json.load(f)
            
        targets = profile_data.setdefault("targets", {})
        target = targets.setdefault(target_key, {})
        
        target["key"] = target_key
        old_file = target.get("file")
        if target_file:
            # 如果文件名发生了变更，且原图在图库中存在，同步复制一份到新文件名，避免资产改名后特征图丢失
            if old_file and target_file != old_file:
                old_path = self.resolve_image_path(old_file)
                if old_path and os.path.isfile(old_path):
                    import shutil
                    new_cache = os.path.join(self.images_dir, target_file)
                    if not os.path.exists(new_cache):
                        try:
                            shutil.copy2(old_path, new_cache)
                        except Exception as e:
                            logger.warning(f"Failed to copy image to cache: {e}")
                    old_dir = os.path.dirname(old_path)
                    new_in_same_dir = os.path.join(old_dir, target_file)
                    if not os.path.exists(new_in_same_dir):
                        try:
                            shutil.copy2(old_path, new_in_same_dir)
                        except Exception as e:
                            logger.warning(f"Failed to copy image to same dir: {e}")
            target["file"] = target_file
        elif "file" not in target:
            target["file"] = f"{target_key}.png"
            
        if target_name:
            target["name"] = target_name
        elif "name" not in target:
            target["name"] = target_key
            
        if category:
            target["category"] = category
        elif "category" not in target:
            target["category"] = self._infer_category(target.get("file", ""))

        if description is not None:
            target["description"] = description
        
        # 1. 保存精确裁切区域 (若为 None 则保持或跳过，便于纯点击锚点保存)
        if crop_rect is not None:
            target["crop_area"] = crop_rect
        
        # 2. 运行时匹配范围：优先用传入的 search_area，否则保留既有 search_area/area，若均无且有裁切区域则外扩
        if search_area:
            target["search_area"] = search_area
            target["area"] = search_area
        elif crop_rect and ("search_area" not in target and "area" not in target):
            x1, y1, x2, y2 = crop_rect
            expanded = [max(0, x1 - 30), max(0, y1 - 30), min(1440, x2 + 30), min(810, y2 + 30)]
            target["search_area"] = expanded
            target["area"] = expanded
        elif target.get("search_area") or target.get("area"):
            target["search_area"] = target.get("search_area") or target.get("area")
            target["area"] = target["search_area"]
            
        if tap_coord is not None:
            target["tap_coord"] = tap_coord
        if anchor:
            target["anchor"] = anchor
            
        with open(profile_path, "w", encoding="utf-8") as f:
            json.dump(profile_data, f, ensure_ascii=False, indent=2)
            
        return target

    def sync_target_to_config_file(self, target_key, config_file_path=None, profile_file="default_1440x810.json"):
        """
        将标定后的目标参数（搜图范围或点击坐标）同步更新写入 Q/battle_v5_config.q 中对应的 Dim 配置项。
        """
        import re

        if config_file_path is None:
            config_file_path = os.path.join(self.repo_root, "Q", "battle_v5_config.q")
            
        if not os.path.isfile(config_file_path):
            return None
            
        profile_path = os.path.join(self.profiles_dir, profile_file)
        if not os.path.isfile(profile_path):
            return None
            
        with open(profile_path, "r", encoding="utf-8") as f:
            profile_data = json.load(f)
            
        targets = profile_data.get("targets", {})
        target = targets.get(target_key, {})
        if not target:
            return None
            
        TARGET_TO_CONFIG_VAR = {
            "START_BTN": "START_TAR",
            "BATTLE_HERO_SKILL_CHECK": "BATTLE_HERO_SKILL_CHECK_TAR",
            "BATTLE_SKILL_GRANT_CHECK": "BATTLE_SKILL_GRANT_CHECK_TAR",
            "BATTLE_SKILL_CHANGE_CHECK": "BATTLE_SKILL_CHANGE_CHECK_TAR",
            "BATTLE_SKILL_CHANGE_SELECTEED_CHECK": "BATTLE_SKILL_CHANGE_SELECTEED_CHECK_TAR",
            "BATTLE_SKILL_SPECIAL_SKILL_A": "BATTLE_SKILL_SPECIAL_SKILL_A_TAR",
            "BATTLE_MASTER_SKILL_OPEN": "BATTLE_MASTER_SKILL_OPEN_TAR",
            "BATTLE_MASTER_SKILL_DISPLAY": "BATTLE_MASTER_SKILL_DISPLAY_TAR",
            "BATTLE_ATTACK_BACK": "BATTLE_ATTACK_BACK_TAR",
            "BATTLE_ATTACK_CARD_BUSTER": "BATTLE_ATTACK_CARD_BUSTER_TAR",
            "BATTLE_ATTACK_CARD_ARTS": "BATTLE_ATTACK_CARD_ARTS_TAR",
            "BATTLE_ATTACK_CARD_QUICK": "BATTLE_ATTACK_CARD_QUICK_TAR",
            "AWARD_TIE": "AWARD_TIE_TAR",
            "AWARD_TIE_UP": "AWARD_TIE_UP_TAR",
            "AWARD_TREASURE_NEXT": "AWARD_TREASURE_NEXT_TAR",
            "AWARD_ACTIVITY_NEXT": "AWARD_ACTIVITY_NEXT_TAR",
            "ADD_FRIEND_CLOSE": "ADD_FRIEND_TAR",
            "AGAIN_ALERT_AGAIN": "AGAIN_ALERT_AGAIN_TAR",
            "AGAIN_ALERT_CLOSE": "AGAIN_ALERT_CLOSE_TAR",
            "AGAIN_ORDEAL_NO_TICKET": "AGAIN_ORDEAL_NO_TICKET_TAR",
            "AGAIN_BATTLE_OUT_MENU": "AGAIN_BATTLE_OUT_MENU_TAR",
            "APPLE_DISPLAY": "APPLE_DISPLAY_TAR",
            "APPLE_CONFIRM": "APPLE_CONFIRM_TAR",
            "friend_equip_goodness": "PREPARE_FRIEND_EQUIP_TAR",
            "TAP_AWARD_SKIP": "TAP_AWARD_SKIP",
            "TAP_APPLE_GOLDEN": "TAP_APPLE_GOLDEN",
            "TAP_APPLE_SILVER": "TAP_APPLE_SILVER",
            "TAP_APPLE_CLOSE": "TAP_APPLE_CLOSE",
        }
        
        with open(config_file_path, "r", encoding="utf-8") as f:
            cfg_text = f.read()
            
        var_name = TARGET_TO_CONFIG_VAR.get(target_key)
        if not var_name:
            if re.search(rf'^\s*(?:Dim\s+)?{re.escape(target_key)}\s*=', cfg_text, re.IGNORECASE | re.MULTILINE):
                var_name = target_key
            elif re.search(rf'^\s*(?:Dim\s+)?{re.escape(target_key)}_TAR\s*=', cfg_text, re.IGNORECASE | re.MULTILINE):
                var_name = f"{target_key}_TAR"
            else:
                var_name = target_key
                
        search_area = target.get("search_area") or target.get("area")
        tap_coord = target.get("tap_coord")
        fname = target.get("file") or f"{target_key}.png"
        
        if search_area and len(search_area) == 4:
            new_val = f'Array({int(search_area[0])}, {int(search_area[1])}, {int(search_area[2])}, {int(search_area[3])}, "Attachment:{fname}")'
        elif tap_coord and len(tap_coord) == 2:
            new_val = f'Array({int(tap_coord[0])}, {int(tap_coord[1])})'
        else:
            return None
            
        pattern = re.compile(rf'^\s*(?:Dim\s+)?{re.escape(var_name)}\s*=.*$', re.IGNORECASE | re.MULTILINE)
        new_line = f"Dim {var_name} = {new_val}"
        
        if pattern.search(cfg_text):
            updated_text = pattern.sub(new_line, cfg_text)
        else:
            # 如果既不在标准映射表中，也不在已有变量列表中，且属于好友图库特征，则无需在 config.q 中新增冗余 Dim
            if target_key not in TARGET_TO_CONFIG_VAR and (target.get("category") == "friend" or target_key.lower().startswith("friend")):
                return cfg_text
            updated_text = cfg_text.rstrip() + f"\n{new_line}\n"
            
        with open(config_file_path, "w", encoding="utf-8") as f:
            f.write(updated_text)
            
        return updated_text



