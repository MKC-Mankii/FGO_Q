# -*- coding: utf-8 -*-
"""
V5 动态资产与底层读图可行性端到端验证脚本
"""
import os
import sys
import cv2

sys.path.insert(0, os.path.dirname(__file__))
from calibration import CalibrationEngine
import adb_sync

def main():
    print("=== [V5 验证 1] ADB 探测与模拟器屏幕抓取 ===")
    adb = adb_sync.find_adb()
    print("ADB 路径:", adb)
    status = adb_sync.get_adb_status()
    print("模拟器状态:", status)
    
    cal = CalibrationEngine(os.path.dirname(__file__))
    img = cal.capture_screen_cv2(adb_sync)
    h, w = img.shape[:2]
    print(f"成功截取当前屏幕: {w}x{h}")
    
    print("\n=== [V5 验证 2] 视口检测与锚点映射算法 ===")
    vp = cal.detect_viewport(img)
    print("视口信息:", vp)
    # 测试基准坐标 (1440x810 下的 Attack 按钮: 1275, 725, 锚点: bottom_right)
    tx, ty = cal.transform_coordinate(1275, 725, "bottom_right", vp)
    print(f"Attack 按钮基准 (1275, 725) -> 当前屏幕自适应坐标: ({tx}, {ty})")
    
    print("\n=== [V5 验证 3] 局部特征裁切与本地保存 ===")
    # 截取中央一小块区域做测试模板 (200x200)
    cx, cy = w // 2, h // 2
    crop_rect = [cx - 50, cy - 50, cx + 50, cy + 50]
    saved_path, size = cal.crop_and_save(img, crop_rect, "v5_dynamic_test.png")
    print(f"测试特征图已裁切并保存至: {saved_path} (尺寸: {size})")
    
    print("\n=== [V5 验证 4] 本地 OpenCV 工业级模板匹配验证 ===")
    match_res = cal.test_match(img, saved_path, [cx - 100, cy - 100, cx + 100, cy + 100])
    print("匹配结果:", match_res)
    assert match_res["matched"] is True, "模板匹配测试失败"
    print(">> 本地模板匹配置信度高达:", match_res["confidence_text"])
    
    print("\n=== [V5 验证 5] ADB 直推模拟器动态图片池 (/sdcard/FGO_Q/images/) ===")
    dev = status["device"]
    # 确保远端目录存在
    adb_sync.run_adb([adb, "-s", dev, "shell", "mkdir", "-p", "/sdcard/FGO_Q/images"])
    # 推送测试图
    push_res = adb_sync.run_adb([adb, "-s", dev, "push", saved_path, "/sdcard/FGO_Q/images/v5_dynamic_test.png"])
    print("ADB Push 输出:", push_res.stdout.decode("utf-8", errors="ignore").strip())
    
    # 验证远端文件
    ls_res = adb_sync.run_adb([adb, "-s", dev, "shell", "ls", "-l", "/sdcard/FGO_Q/images/v5_dynamic_test.png"])
    ls_output = ls_res.stdout.decode("utf-8", errors="ignore").strip()
    print("远端文件确认:", ls_output)
    assert "v5_dynamic_test.png" in ls_output, "远端文件不存在"
    
    print("\n=======================================================")
    print(">>> 【全链路验证通过】V5 动态图源与底层读图路径完全可行！<<<")
    print("=======================================================")

if __name__ == "__main__":
    main()
