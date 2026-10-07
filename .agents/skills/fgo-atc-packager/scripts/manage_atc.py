#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
FGO_Q 按键精灵 .atc 附件包打包与管理工具 (ATC Asset Manager)
- 用于按键精灵移动端 (.atc) 附件包的解包、打包、单图注入与多端部署同步。
"""

import os
import sys
import argparse
import zipfile
import shutil
import glob
import subprocess

REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
EDITOR_DIR = os.path.join(REPO_ROOT, "editor_v5")
ATTACHED_IMAGES_DIR = os.path.join(REPO_ROOT, "images", "attached images")

# PC 按键精灵手机助手脚本存储目录
PC_ASSISTANT_DIRS = [
    r"D:\ProgramData\按键精灵\按键精灵手机助手\Script",
    r"E:\back 970pro\ProgramData\按键精灵\按键精灵手机助手\Script",
]

# V5 脚本 UUID 与命名标识
V5_RUNNER_NAME = "fgo_battle_v5_runner(d7a5b3c2-8e1f-4c92-a1b3-f5c7e8d9a0b1)"
SIMULATOR_SCRIPT_DIR = "/sdcard/MobileAnJian/Script"


def find_adb():
    """在当前仓库或系统 PATH 中探测可用的 adb.exe"""
    candidates = [
        r"E:\leidian\LDPlayer9\adb.exe",
        r"D:\leidian\LDPlayer9\adb.exe",
        r"C:\leidian\LDPlayer9\adb.exe",
        r"D:\Program Files\Netease\MuMu\nx_main\adb.exe",
        r"D:\Program Files\Netease\MuMu\nx_device\15.0\shell\adb.exe",
        r"D:\ProgramData\按键精灵\按键精灵手机助手\android\adb.exe",
        os.path.join(REPO_ROOT, "bin", "adb.exe"),
        os.path.join(REPO_ROOT, "platform-tools", "adb.exe"),
    ]
    for c in candidates:
        if os.path.isfile(c):
            return c
    adb_which = shutil.which("adb")
    return adb_which or "adb"


def list_atc(atc_path):
    """查看 .atc 内部文件列表"""
    if not os.path.isfile(atc_path):
        print(f"[Error] ATC 文件不存在: {atc_path}")
        return
    with zipfile.ZipFile(atc_path, "r") as z:
        items = z.namelist()
        print(f"=== ATC 包内资源清单 ({len(items)} 个文件): {atc_path} ===")
        for name in sorted(items):
            info = z.getinfo(name)
            print(f"  - {name} ({info.file_size} bytes)")


def extract_atc(atc_path, output_dir):
    """解压 .atc 附件包中的所有图片"""
    if not os.path.isfile(atc_path):
        print(f"[Error] ATC 文件不存在: {atc_path}")
        return
    os.makedirs(output_dir, exist_ok=True)
    with zipfile.ZipFile(atc_path, "r") as z:
        z.extractall(output_dir)
    print(f"[OK] 已成功解压至: {output_dir}")


def build_atc(source_dir, output_atc):
    """
    将图片文件夹全量打包为按键精灵手机版 .atc 文件
    规范：所有附件图片必须位于 Attachment/ 根目录下
    """
    if not os.path.isdir(source_dir):
        print(f"[Error] 源图片目录不存在: {source_dir}")
        return
    os.makedirs(os.path.dirname(os.path.abspath(output_atc)), exist_ok=True)

    count = 0
    with zipfile.ZipFile(output_atc, "w", compression=zipfile.ZIP_DEFLATED) as z:
        for fname in sorted(os.listdir(source_dir)):
            if fname.lower().endswith((".png", ".bmp", ".jpg", ".jpeg")):
                fpath = os.path.join(source_dir, fname)
                arcname = f"Attachment/{fname}"
                z.write(fpath, arcname=arcname)
                count += 1
    print(f"[OK] 已打包 {count} 个图片资源到: {output_atc}")


def add_to_atc(atc_path, img_path, target_fname=None):
    """
    向已有的 .atc 追加或覆盖单张图片
    """
    if not os.path.isfile(atc_path):
        print(f"[Error] 目标 ATC 不存在: {atc_path}")
        return
    if not os.path.isfile(img_path):
        print(f"[Error] 输入图片不存在: {img_path}")
        return

    fname = target_fname or os.path.basename(img_path)
    arcname = f"Attachment/{fname}"

    # ZIP 不支持直接原位覆盖文件，先读出所有条目并覆写重构
    temp_atc = atc_path + ".tmp"
    with zipfile.ZipFile(atc_path, "r") as z_in, zipfile.ZipFile(temp_atc, "w", compression=zipfile.ZIP_DEFLATED) as z_out:
        for item in z_in.infolist():
            if item.filename != arcname:
                z_out.writestr(item, z_in.read(item.filename))
        z_out.write(img_path, arcname=arcname)

    shutil.move(temp_atc, atc_path)
    print(f"[OK] 已成功注入 {arcname} 至: {atc_path}")


def sync_atc(atc_path, device=None):
    """
    将 .atc 同步部署到 PC 按键手机助手目录和模拟器
    """
    if not os.path.isfile(atc_path):
        print(f"[Error] ATC 文件不存在: {atc_path}")
        return

    # 1. 部署至 PC 助手
    for pc_dir in PC_ASSISTANT_DIRS:
        if os.path.isdir(pc_dir):
            target = os.path.join(pc_dir, f"{V5_RUNNER_NAME}.atc")
            shutil.copy2(atc_path, target)
            print(f"[Deploy] 已同步至 PC 助手: {target}")

    # 2. 部署至模拟器
    adb = find_adb()
    cmd = [adb]
    if not device:
        try:
            sys.path.insert(0, os.path.join(REPO_ROOT, "editor_v5"))
            import adb_sync
            device = adb_sync.get_selected_device(adb)
        except Exception:
            pass
    if device:
        cmd.extend(["-s", device])
    cmd.extend(["push", atc_path, f"{SIMULATOR_SCRIPT_DIR}/{V5_RUNNER_NAME}.atc"])
    try:
        res = subprocess.run(cmd, capture_output=True, text=True, timeout=10)
        if res.returncode == 0:
            print(f"[Deploy] 已成功推送到模拟器: {SIMULATOR_SCRIPT_DIR}/{V5_RUNNER_NAME}.atc")
        else:
            print(f"[Deploy Warning] 推送模拟器失败: {res.stderr.strip()}")
    except Exception as e:
        print(f"[Deploy Error] 执行 ADB 推送异常: {e}")


def main():
    parser = argparse.ArgumentParser(description="按键精灵 .atc 附件包打包与管理工具")
    subparsers = parser.add_subparsers(dest="command", required=True)

    # list
    p_list = subparsers.add_parser("list", help="列出 .atc 内的图片列表")
    p_list.add_argument("atc", help="ATC 文件路径")

    # extract
    p_ext = subparsers.add_parser("extract", help="解压 .atc 到指定目录")
    p_ext.add_argument("atc", help="ATC 文件路径")
    p_ext.add_argument("output", help="输出目录")

    # build
    p_build = subparsers.add_parser("build", help="从图片目录构建全新的 .atc 文件")
    p_build.add_argument("--source", default=ATTACHED_IMAGES_DIR, help="源图片目录 (默认: images/attached images/)")
    p_build.add_argument("--output", required=True, help="目标 .atc 输出路径")

    # add
    p_add = subparsers.add_parser("add", help="向已有 .atc 追加或更新单张图片")
    p_add.add_argument("atc", help="目标 .atc 文件路径")
    p_add.add_argument("image", help="待注入的图片路径")
    p_add.add_argument("--name", help="在包内的文件名 (可选，默认使用图片原本文件名)")

    # sync
    p_sync = subparsers.add_parser("sync", help="将 .atc 文件同步到 PC 助手与安卓模拟器")
    p_sync.add_argument("atc", help="ATC 文件路径")
    p_sync.add_argument("--device", help="ADB 设备标识 (可选)")

    args = parser.parse_args()

    if args.command == "list":
        list_atc(args.atc)
    elif args.command == "extract":
        extract_atc(args.atc, args.output)
    elif args.command == "build":
        build_atc(args.source, args.output)
    elif args.command == "add":
        add_to_atc(args.atc, args.image, args.name)
    elif args.command == "sync":
        sync_atc(args.atc, args.device)


if __name__ == "__main__":
    main()
