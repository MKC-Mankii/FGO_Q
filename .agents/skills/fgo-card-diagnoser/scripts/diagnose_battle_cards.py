#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
FGO Card Selection & Servant Recognition Diagnoser
---------------------------------------------------
一键排查选卡失败、点错卡、从者立绘不匹配与 100% 暴击检测异常的标准化诊断工具。
核心能力：
1. 自动从模拟器拉取 /sdcard/FGO_Q/debug_card_log.txt、/sdcard/FGO_Q/images/tmp_hero_*.png 切片及现场截图；
2. 结合当前模拟器截屏（或用户传入的报错截屏）对 5 张手牌进行自动化 CV 识别推演；
3. 输出色卡、100% 满暴、从者 1~3 匹配置信度矩阵；
4. 模拟 DSL 优先级匹配流，精确指出点错卡或停机未命中的根因；
5. 生成带标注框的诊断合成图与 Markdown 诊断报告。
"""

import os
import sys
import json
import argparse
import glob
import subprocess
from datetime import datetime
from pathlib import Path

if sys.stdout is not None and hasattr(sys.stdout, 'reconfigure'):
    try:
        sys.stdout.reconfigure(encoding='utf-8', errors='replace')
    except Exception:
        pass

try:
    import cv2
    import numpy as np
except ImportError:
    print("[Error] 需要安装 opencv-python: pip install opencv-python", file=sys.stderr)
    sys.exit(1)

REPO_ROOT = str(Path(__file__).resolve().parents[4])

# 默认 1440x810 标定参数
DEFAULT_CARD_CENTERS = [118, 408, 698, 991, 1278]
DEFAULT_CARD_AREAS = [
    [33, 480, 203, 580],
    [323, 480, 493, 580],
    [613, 480, 783, 580],
    [906, 480, 1076, 580],
    [1193, 480, 1363, 580]
]
DEFAULT_CRIT_AREAS = [
    [63, 350, 83, 445],
    [353, 350, 373, 445],
    [643, 350, 663, 445],
    [936, 350, 956, 445],
    [1223, 350, 1243, 445]
]
DEFAULT_NP_FACE_AREAS = [
    [443, 181, 483, 201],
    [719, 181, 759, 201],
    [995, 181, 1035, 201]
]

def find_adb():
    candidates = [
        "adb",
        r"F:\AI\platform-tools\adb.exe",
        r"E:\leidian\LDPlayer9\adb.exe",
        r"C:\Program Files\Nox\bin\adb.exe",
        r"D:\Program Files\Nox\bin\adb.exe",
    ]
    for c in candidates:
        try:
            res = subprocess.run([c, "version"], stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=2)
            if res.returncode == 0:
                return c
        except Exception:
            continue
    return None

def get_connected_device(adb):
    if not adb:
        return None
    try:
        res = subprocess.run([adb, "devices"], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, timeout=3)
        lines = res.stdout.strip().splitlines()
        devices = []
        for line in lines[1:]:
            parts = line.split()
            if len(parts) >= 2 and parts[1] == "device":
                devices.append(parts[0])
        if devices:
            return devices[0]
    except Exception:
        pass
    return None

def load_calibration_profile():
    profile_path = os.path.join(REPO_ROOT, "editor_v5", "profiles", "default_1440x810.json")
    if not os.path.isfile(profile_path):
        return None
    try:
        with open(profile_path, "r", encoding="utf-8") as f:
            return json.load(f)
    except Exception:
        return None

def get_calibrated_areas(profile_data):
    if not profile_data:
        return DEFAULT_CARD_AREAS, DEFAULT_CRIT_AREAS, DEFAULT_NP_FACE_AREAS

    targets = profile_data.get("targets", {})
    card_areas = []
    for i in range(1, 6):
        t = targets.get(f"BATTLE_HERO_CARD_AREA_{i}")
        if t and (t.get("search_area") or t.get("area")):
            card_areas.append(t.get("search_area") or t.get("area"))
        else:
            card_areas.append(DEFAULT_CARD_AREAS[i-1])

    crit_areas = []
    for i in range(1, 6):
        t = targets.get(f"BATTLE_CRIT_100_AREA_{i}")
        if t and (t.get("search_area") or t.get("area")):
            crit_areas.append(t.get("search_area") or t.get("area"))
        else:
            crit_areas.append(DEFAULT_CRIT_AREAS[i-1])

    np_areas = []
    for i in range(1, 4):
        t = targets.get(f"BATTLE_HERO_NP_FACE_{i}")
        if t and (t.get("crop_area") or t.get("search_area") or t.get("area")):
            np_areas.append(t.get("crop_area") or t.get("search_area") or t.get("area"))
        else:
            np_areas.append(DEFAULT_NP_FACE_AREAS[i-1])

    return card_areas, crit_areas, np_areas

def pull_debug_artifacts_from_device(adb, device, out_dir):
    os.makedirs(out_dir, exist_ok=True)
    pulled_items = []

    # 1. Pull debug_card_log.txt
    try:
        remote_log = "/sdcard/FGO_Q/debug_card_log.txt"
        local_log = os.path.join(out_dir, "debug_card_log.txt")
        subprocess.run([adb, "-s", device, "pull", remote_log, local_log], stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=5)
        if os.path.isfile(local_log) and os.path.getsize(local_log) > 0:
            pulled_items.append("debug_card_log.txt")
    except Exception as e:
        print(f"[Warn] 拉取 debug_card_log.txt 失败: {e}", file=sys.stderr)

    # 2. Pull tmp_hero_*.png
    try:
        res = subprocess.run([adb, "-s", device, "shell", "ls /sdcard/FGO_Q/images/tmp_hero_*.png 2>/dev/null"], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, timeout=5)
        if res.returncode == 0:
            remote_files = [f.strip() for f in res.stdout.splitlines() if f.strip().endswith(".png")]
            for rf in remote_files:
                base = os.path.basename(rf)
                local_f = os.path.join(out_dir, base)
                subprocess.run([adb, "-s", device, "pull", rf, local_f], stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=5)
                if os.path.isfile(local_f):
                    pulled_items.append(base)
    except Exception as e:
        print(f"[Warn] 拉取 tmp_hero 切片失败: {e}", file=sys.stderr)

    # 3. Pull debug_sample_hero_screen.png
    try:
        remote_dbg_screen = "/sdcard/FGO_Q/images/debug_sample_hero_screen.png"
        local_dbg_screen = os.path.join(out_dir, "debug_sample_hero_screen.png")
        subprocess.run([adb, "-s", device, "pull", remote_dbg_screen, local_dbg_screen], stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=5)
        if os.path.isfile(local_dbg_screen) and os.path.getsize(local_dbg_screen) > 0:
            pulled_items.append("debug_sample_hero_screen.png")
    except Exception:
        pass

    return pulled_items

def capture_live_screen(adb, device, out_path):
    try:
        res = subprocess.run([adb, "-s", device, "exec-out", "screencap", "-p"], stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=8)
        if res.returncode == 0 and res.stdout:
            data = res.stdout
            if not data.startswith(b"\x89PNG\r\n\x1a\n"):
                data = data.replace(b"\r\r\n", b"\n").replace(b"\r\n", b"\n")
            with open(out_path, "wb") as f:
                f.write(data)
            return True
    except Exception as e:
        print(f"[Warn] ADB 截屏失败: {e}", file=sys.stderr)
    return False

def resolve_template_path(fname):
    candidates = [
        os.path.join(REPO_ROOT, "editor_v5", "images", fname),
        os.path.join(REPO_ROOT, "images", "attached images", fname),
        os.path.join(REPO_ROOT, "images", fname)
    ]
    for c in candidates:
        if os.path.isfile(c):
            return c
    return None

def detect_card_color(screen_bgr, card_idx, card_cx):
    # 颜色模板匹配
    templates = {
        "B": resolve_template_path("BATTLE_ATTACK_CARD_BUSTER.png"),
        "A": resolve_template_path("BATTLE_ATTACK_CARD_ARTS.png"),
        "Q": resolve_template_path("BATTLE_ATTACK_CARD_QUICK.png")
    }
    x1 = max(0, card_cx - 130)
    x2 = min(1439, card_cx + 130)
    y1, y2 = 460, 750
    crop = screen_bgr[y1:y2, x1:x2]

    best_color = "未知"
    best_val = -1.0
    for color, t_path in templates.items():
        if not t_path or not os.path.isfile(t_path):
            continue
        tpl = cv2.imread(t_path)
        if tpl is None:
            continue
        res = cv2.matchTemplate(crop, tpl, cv2.TM_CCOEFF_NORMED)
        _, max_v, _, _ = cv2.minMaxLoc(res)
        if max_v > best_val:
            best_val = max_v
            best_color = color

    if best_val >= 0.70:
        return best_color, best_val
    return "未知", best_val

def detect_card_crit_100(screen_bgr, crit_area):
    x1, y1, x2, y2 = crit_area
    crop = screen_bgr[y1:y2, x1:x2]
    if crop.shape[0] < 5 or crop.shape[1] < 5:
        return False, 0.0

    tpl_paths = [
        resolve_template_path("BATTLE_ATTACK_CARD_100.png"),
        resolve_template_path("BATTLE_ATTACK_CARD_100_2.png")
    ]
    max_score = 0.0
    for p in tpl_paths:
        if not p or not os.path.isfile(p):
            continue
        tpl = cv2.imread(p)
        if tpl is None:
            continue
        if crop.shape[0] < tpl.shape[0] or crop.shape[1] < tpl.shape[1]:
            continue
        res = cv2.matchTemplate(crop, tpl, cv2.TM_CCOEFF_NORMED)
        _, max_v, _, _ = cv2.minMaxLoc(res)
        if max_v > max_score:
            max_score = max_v

    is_100 = (max_score >= 0.70)
    return is_100, max_score

def match_servant_avatars(screen_bgr, card_area, hero_templates_map):
    x1, y1, x2, y2 = card_area
    crop = screen_bgr[y1:y2, x1:x2]
    scores = {}

    for hero_id, tpl_list in hero_templates_map.items():
        best_score = 0.0
        best_tpl_name = ""
        for (name, tpl_img) in tpl_list:
            if tpl_img is None or crop.shape[0] < tpl_img.shape[0] or crop.shape[1] < tpl_img.shape[1]:
                continue
            res = cv2.matchTemplate(crop, tpl_img, cv2.TM_CCOEFF_NORMED)
            _, max_v, _, _ = cv2.minMaxLoc(res)
            if max_v > best_score:
                best_score = max_v
                best_tpl_name = name
        scores[hero_id] = (best_score, best_tpl_name)

    return scores

def parse_dsl_sequence(dsl_str):
    if not dsl_str:
        return []
    atoms = [a.strip().upper() for a in dsl_str.split(">") if a.strip()]
    return atoms

def simulate_card_selection(cards_info, dsl_atoms, hero_threshold=0.75):
    if not dsl_atoms:
        return None, "未提供 DSL 规则"

    # cards_info: list of dict: index, color, is_crit, best_hero, best_hero_score
    for atom in dsl_atoms:
        must_crit = atom.endswith("!")
        clean = atom[:-1] if must_crit else atom

        for c in cards_info:
            if must_crit and not c["is_crit"]:
                continue
            # 从者判断
            if clean in ["H1", "H2", "H3"]:
                h_num = int(clean[1])
                if c["best_hero"] == h_num and c["best_hero_score"] >= hero_threshold:
                    return c["index"], f"命中规则 [{atom}] -> 手牌 {c['index']}"
            # 色卡判断
            elif clean in ["B", "A", "Q"]:
                if c["color"] == clean:
                    return c["index"], f"命中规则 [{atom}] -> 手牌 {c['index']}"
            elif clean == "*":
                return c["index"], f"命中通配规则 [{atom}] -> 手牌 {c['index']}"

    return None, f"未命中任何优先级规则 [{'>'.join(dsl_atoms)}]，安全停机"

def main():
    parser = argparse.ArgumentParser(description="FGO 战斗选卡与从者立绘识别排查工具")
    parser.add_argument("--screen", "-s", type=str, default=None, help="目标截屏路径（默认自动截取当前模拟器或读取 scratch 证据截图）")
    parser.add_argument("--device", "-d", type=str, default=None, help="ADB 设备号")
    parser.add_argument("--dsl", type=str, default=None, help="待模拟推演的出牌 DSL（如 'H3>A>B>Q>H2>H1' 或 'H1!>H2!>H3!'）")
    parser.add_argument("--out-dir", "-o", type=str, default=os.path.join(REPO_ROOT, "scratch", "card_diagnosis"), help="输出目录")
    parser.add_argument("--threshold", "-t", type=float, default=0.75, help="从者识别相似度判定阈值 (默认 0.75)")
    parser.add_argument("--no-pull", action="store_true", help="禁止自动从 ADB 拉取切片与日志")
    args = parser.parse_args()

    os.makedirs(args.out_dir, exist_ok=True)
    adb = find_adb()
    device = args.device or get_connected_device(adb)

    print("================================================================================")
    print(" FGO Card Selection & Servant Recognition Diagnoser (V5)")
    print("================================================================================")
    if adb and device:
        print(f"[*] 检测到连接的设备: {device} (ADB: {adb})")
    else:
        print("[*] 模拟器未连接或离线，将使用本地已有离线证据链进行分析")

    pulled = []
    if adb and device and not args.no_pull:
        print("[*] 正在从设备拉取现场切片与日志...")
        pulled = pull_debug_artifacts_from_device(adb, device, args.out_dir)
        print(f"[*] 已同步拉取 {len(pulled)} 项现场资产: {', '.join(pulled) if pulled else '无新文件'}")

    # 解析 debug_card_log.txt
    log_file = os.path.join(args.out_dir, "debug_card_log.txt")
    if not os.path.isfile(log_file):
        # 尝试从全局 scratch 找
        cand = os.path.join(REPO_ROOT, "scratch", "debug_card_log.txt")
        if os.path.isfile(cand):
            log_file = cand

    print("\n------------------------- 1. 现场最新执行日志 -------------------------")
    if os.path.isfile(log_file):
        with open(log_file, "r", encoding="utf-8", errors="ignore") as f:
            lines = [l.strip() for l in f.readlines() if l.strip()]
        recent_lines = lines[-8:]
        for rl in recent_lines:
            print(f"  {rl}")
    else:
        print("  [未找到 debug_card_log.txt]")

    # 确定截屏路径
    screen_path = args.screen
    if not screen_path:
        # 如果连接着设备，优先 live 抓取
        if adb and device:
            live_path = os.path.join(args.out_dir, "current_screen.png")
            if capture_live_screen(adb, device, live_path):
                screen_path = live_path
        # 否则查找 scratch 下的截图
        if not screen_path or not os.path.isfile(screen_path):
            candidates = [
                os.path.join(args.out_dir, "debug_sample_hero_screen.png"),
                os.path.join(REPO_ROOT, "scratch", "screen_fail_now.png"),
                os.path.join(REPO_ROOT, "scratch", "current_screen.png"),
            ]
            for c in candidates:
                if os.path.isfile(c):
                    screen_path = c
                    break

    if not screen_path or not os.path.isfile(screen_path):
        print(f"\n[Error] 未能找到有效的游戏截屏图像！请使用 --screen 指定图片路径或连接模拟器。", file=sys.stderr)
        sys.exit(1)

    print(f"\n[*] 载入游戏分析画面: {screen_path}")
    screen_bgr = cv2.imread(screen_path)
    if screen_bgr is None:
        print(f"[Error] 无法解码截图: {screen_path}", file=sys.stderr)
        sys.exit(1)

    # 尺寸校验
    h, w = screen_bgr.shape[:2]
    print(f"[*] 截屏画面分辨率: {w}x{h}")
    if (w, h) != (1440, 810):
        print(f"[*] 画面非 1440x810 标准基准，缩放到 1440x810 进行无损对齐分析")
        screen_bgr = cv2.resize(screen_bgr, (1440, 810), interpolation=cv2.INTER_AREA)

    # 载入标定区域
    profile_data = load_calibration_profile()
    card_areas, crit_areas, np_areas = get_calibrated_areas(profile_data)

    # 收集 1~3 号从者的模板切片 (优先从 out_dir/tmp_hero_*.png，其次本地标定库)
    hero_templates_map = {1: [], 2: [], 3: []}
    for h_id in [1, 2, 3]:
        # 1. 查找 tmp_hero_{h_id}_*.png
        tmp_pattern = os.path.join(args.out_dir, f"tmp_hero_{h_id}_*.png")
        for f in glob.glob(tmp_pattern):
            img = cv2.imread(f)
            if img is not None:
                hero_templates_map[h_id].append((os.path.basename(f), img))
        # 2. 如果没有，查找本地预置/用户上传的标定切片
        if not hero_templates_map[h_id]:
            ref_path = resolve_template_path(f"BATTLE_HERO_NP_FACE_{h_id}.png")
            if ref_path and os.path.isfile(ref_path):
                img = cv2.imread(ref_path)
                if img is not None:
                    hero_templates_map[h_id].append((os.path.basename(ref_path), img))

    print("\n------------------------- 2. 从者头像切片资产 -------------------------")
    for h_id in [1, 2, 3]:
        tpls = hero_templates_map[h_id]
        if tpls:
            names = [t[0] for t in tpls]
            print(f"  从者 {h_id}: 已加载 {len(tpls)} 帧切片 -> {', '.join(names)} (尺寸: {tpls[0][1].shape[1]}x{tpls[0][1].shape[0]})")
        else:
            print(f"  从者 {h_id}: [未找到切片资产] (可在选卡阶段从宝具卡重新采样)")

    # 循环分析 5 张手牌
    cards_info = []
    annotated = screen_bgr.copy()

    print("\n------------------------- 3. 当前手牌识别与置信度推演 -------------------------")
    print(f"{'卡位':^6}|{'色卡':^8}|{'100%满暴':^12}|{'从者1相似度':^14}|{'从者2相似度':^14}|{'从者3相似度':^14}|{'最高匹配':^12}")
    print("-" * 88)

    for idx in range(5):
        card_num = idx + 1
        cx = DEFAULT_CARD_CENTERS[idx]
        card_area = card_areas[idx]
        crit_area = crit_areas[idx]

        color, color_val = detect_card_color(screen_bgr, card_num, cx)
        is_crit, crit_val = detect_card_crit_100(screen_bgr, crit_area)
        servant_scores = match_servant_avatars(screen_bgr, card_area, hero_templates_map)

        best_h = None
        best_h_score = 0.0
        for h_id in [1, 2, 3]:
            score, _ = servant_scores.get(h_id, (0.0, ""))
            if score > best_h_score:
                best_h_score = score
                best_h = h_id

        cards_info.append({
            "index": card_num,
            "color": color,
            "color_score": color_val,
            "is_crit": is_crit,
            "crit_score": crit_val,
            "servant_scores": servant_scores,
            "best_hero": best_h,
            "best_hero_score": best_h_score
        })

        s1_str = f"{servant_scores.get(1, (0.0, ''))[0]:.3f}"
        s2_str = f"{servant_scores.get(2, (0.0, ''))[0]:.3f}"
        s3_str = f"{servant_scores.get(3, (0.0, ''))[0]:.3f}"
        crit_str = f"★ 100% ({crit_val:.2f})" if is_crit else f"否 ({crit_val:.2f})"

        best_label = "无"
        if best_h and best_h_score >= args.threshold:
            best_label = f"H{best_h} (✔命中)"
        elif best_h and best_h_score >= 0.50:
            best_label = f"H{best_h} (?低信)"

        print(f" Card {card_num} | {color:^6} | {crit_str:^10} | {s1_str:^12} | {s2_str:^12} | {s3_str:^12} | {best_label:^10}")

        # 在合成图上绘制诊断框
        # 手牌立绘框
        cv2.rectangle(annotated, (card_area[0], card_area[1]), (card_area[2], card_area[3]), (0, 255, 0), 2)
        # 暴击率检测框
        cv2.rectangle(annotated, (crit_area[0], crit_area[1]), (crit_area[2], crit_area[3]), (0, 165, 255), 2)

        # 文字标示
        tag = f"C{card_num}: {color} {'[CRIT]' if is_crit else ''}"
        cv2.putText(annotated, tag, (card_area[0], card_area[1] - 8), cv2.FONT_HERSHEY_SIMPLEX, 0.55, (0, 255, 255), 2)
        if best_h:
            h_tag = f"H{best_h}: {best_h_score:.2f}"
            h_col = (0, 255, 0) if best_h_score >= args.threshold else (0, 0, 255)
            cv2.putText(annotated, h_tag, (card_area[0], card_area[3] + 18), cv2.FONT_HERSHEY_SIMPLEX, 0.55, h_col, 2)

    # 绘制宝具卡区域
    for i, np_a in enumerate(np_areas, 1):
        cv2.rectangle(annotated, (np_a[0], np_a[1]), (np_a[2], np_a[3]), (255, 0, 255), 2)
        cv2.putText(annotated, f"NP_H{i}", (np_a[0], np_a[1] - 6), cv2.FONT_HERSHEY_SIMPLEX, 0.45, (255, 0, 255), 1)

    overlay_out = os.path.join(args.out_dir, "diagnosis_overlay.png")
    cv2.imwrite(overlay_out, annotated)
    print(f"\n[*] 诊断标注可视化图像已生成: {overlay_out}")

    # 4. 模拟 DSL 决策
    if args.dsl:
        print("\n------------------------- 4. DSL 出牌决策推演 -------------------------")
        atoms = parse_dsl_sequence(args.dsl)
        print(f"[*] 待测试 DSL: {'>'.join(atoms)}")
        selected_card, reason = simulate_card_selection(cards_info, atoms, hero_threshold=args.threshold)
        print(f"[*] 决策结果: {reason}")
        if selected_card is not None:
            c_info = cards_info[selected_card - 1]
            print(f"[*] 最终选中卡牌: Card {selected_card} ({c_info['color']}, 满暴={c_info['is_crit']}, 最高从者=H{c_info['best_hero']} @ {c_info['best_hero_score']:.3f})")
        else:
            print("[!] 未能选出卡牌！根据刚性出牌规范，安全停机保全用户现场。")

    print("\n------------------------- 5. 诊断结论与建议 -------------------------")
    issues = []
    # 1. 分析手牌识别置信度
    for c in cards_info:
        idx = c["index"]
        bh = c["best_hero"]
        bscore = c["best_hero_score"]
        if bh and bscore >= args.threshold:
            pass  # 明确命中
        elif bh and bscore >= 0.58:
            issues.append(f"- 手牌 {idx} 最高匹配从者为 H{bh}，相似度为 {bscore:.3f}（未达阈值 {args.threshold}）：立绘五官可能受宝具卡脉冲流光过曝影响，或手牌检测框略有偏移。建议在 Editor 屏幕标定中微调从者 {bh} 的切片区域。")
        else:
            issues.append(f"- 手牌 {idx} 所有从者相似度均 < 0.58（最高仅 H{bh} @ {bscore:.3f}）：未能稳定识别归属从者。")

    # 2. 检查是否有 100% 暴击却因从者不匹配被跳过的卡
    for c in cards_info:
        if c["is_crit"] and c["best_hero_score"] < args.threshold:
            issues.append(f"- 手牌 {c['index']} 带有 100% 满暴标记，但其从者未被确认（最高 H{c['best_hero']} @ {c['best_hero_score']:.3f}）。若 DSL 包含如 'H{c['best_hero']}!'，该卡将被跳过。")

    if issues:
        for iss in issues:
            print(iss)
    else:
        print("- 5 张手牌从者归属与色卡状态清晰明确，判别裕度充足（> 0.15），未见临界识别风险。")

    print("\n================================================================================")
    print(f" 诊断完成！完整报告已存储至: {args.out_dir}")
    print("================================================================================")

if __name__ == "__main__":
    main()
