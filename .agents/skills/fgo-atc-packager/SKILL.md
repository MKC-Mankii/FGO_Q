---
name: fgo-atc-packager
description: >-
  Manage, inspect, extract, pack, and synchronize MobileAnJian (按键精灵手机版/手机助手) .atc attachment packages
  for FGO_Q. Use when packaging script image attachments into .atc, updating fallback image assets,
  understanding MobileAnJian script resource structure, or deploying script packages to PC and emulator paths.
---

# FGO_Q 按键精灵 .atc 附件包打包与资产管理技能 (ATC Packager)

按键精灵手机版（以及 PC 端「按键精灵手机助手」）在分发与运行脚本时，采用专用的 `.atc` (Attachment) 文件封装脚本所依赖的所有图像特征与附属文件。

本技能提供了 `.atc` 附件包的完整技术标准、动静态双轨资产机制、以及自动化管理脚本工具。

---

## 1. 按键精灵手机版脚本结构规范

在 PC 助手目录（如 `D:\ProgramData\按键精灵\按键精灵手机助手\Script\`）与模拟器脚本目录（`/sdcard/MobileAnJian/Script/`）下，每个脚本均由 4 个同名文件组成：

文件后缀 | 文件说明 | 核心规范与注意点
:--- | :--- | :---
`.mq` | 按键精灵源码 | GBK 编码存储。包含执行逻辑、函数与找图坐标。
`.prop` | 脚本元数据属性 | JSON 格式，定义脚本 `id` (UUID)、`Name` (显示名称)、`repeat`、`duration` 等。
`.uis` | UI 交互界面配置 | 定义脚本启动时的浮窗参数设置界面。
`.atc` | 附件包 (Attachment) | **标准 ZIP 压缩包**，内部必须以 `Attachment/` 作为根目录，存放全部图片资源。

> [!IMPORTANT]
> **UUID 强绑定规则**：`.atc` 文件的命名必须与 `.mq` 和 `.prop` 中的 UUID 完全一致。
> 例如：`fgo_battle_v5_runner(d7a5b3c2-8e1f-4c92-a1b3-f5c7e8d9a0b1).atc`。

---

## 2. FGO_Q 动静态双轨图库匹配架构

在 `Q/battle_v5_runner.q` 的底层实现中，找图函数（`CheckImg2` / `CheckPriorityImg`）均通过 `ResolveTargetImg()` 执行路径重定向：

```vbscript
Function ResolveTargetImg(rawAttachedImg)
    ...
    pickedPath = "Attachment:" & fileName
    sdPath = "/sdcard/FGO_Q/images/" & fileName
    If Dir.Exist(sdPath) = 1 Then
        pickedPath = sdPath    ' 优先命中动态热推图库！
    Else
        sdPath = "/storage/emulated/0/FGO_Q/images/" & fileName
        If Dir.Exist(sdPath) = 1 Then
            pickedPath = sdPath
        End If
    End If
    ...
```

### 双轨机制分工：

1. **第一优先级（动态热更轨 · 免打包）**：
   - 路径：`/sdcard/FGO_Q/images/<fileName>.png`
   - **特点**：日常在 Editor V5 中标定、重新裁切、添加助战好友（如 `friendShaHu2Shan.png`）时，**仅需 ADB 推送到此目录即可立即生效**，脚本无需重编译，也不需要重新打包 `.atc`。
2. **第二优先级（离线保底轨 · ATC 封装）**：
   - 路径：`Attachment:<fileName>.png`（从关联的 `.atc` 解压提取）
   - **特点**：用于将整个脚本打包为完全独立的安装包离线分发。在 `/sdcard/FGO_Q/images/` 缺失或全新安装的模拟器上提供静态保底能力。

---

## 3. CLI 工具使用指南 (`scripts/manage_atc.py`)

仓库已内置标准化管理脚本：[manage_atc.py](./scripts/manage_atc.py)。

### 1) 查看 .atc 内的文件清单
```bash
python .agents/skills/fgo-atc-packager/scripts/manage_atc.py list <atc_path>
# 示例：
python .agents/skills/fgo-atc-packager/scripts/manage_atc.py list scratch/runner_v5.atc
```

### 2) 解压 .atc 到指定目录
```bash
python .agents/skills/fgo-atc-packager/scripts/manage_atc.py extract <atc_path> <output_dir>
# 示例：
python .agents/skills/fgo-atc-packager/scripts/manage_atc.py extract scratch/runner_v5.atc extracted_images/
```

### 3) 全量打包图片目录为全新 .atc
```bash
python .agents/skills/fgo-atc-packager/scripts/manage_atc.py build --source "images/attached images/" --output "scratch/fgo_battle_v5_runner.atc"
```

### 4) 向现有 .atc 中追加或覆盖单张图片
```bash
python .agents/skills/fgo-atc-packager/scripts/manage_atc.py add <atc_path> <image_path> [--name <optional_name>]
# 示例：将新助战头像直接打入已有包
python .agents/skills/fgo-atc-packager/scripts/manage_atc.py add scratch/runner_v5.atc "images/attached images/friendShaHu2Shan.png"
```

### 5) 一键双端同步部署（PC 手机助手 + 模拟器）
```bash
python .agents/skills/fgo-atc-packager/scripts/manage_atc.py sync scratch/runner_v5.atc
```

---

## 4. Python 代码集成参考

如需在自定义自动化流程中操作 `.atc`，可直接参考如下纯原生标准库实现：

```python
import zipfile
import os
import shutil

def pack_images_to_atc(img_folder: str, atc_target_path: str):
    """构建标准按键精灵 .atc 附件包"""
    with zipfile.ZipFile(atc_target_path, 'w', compression=zipfile.ZIP_DEFLATED) as z:
        for fname in sorted(os.listdir(img_folder)):
            if fname.lower().endswith(('.png', '.bmp', '.jpg')):
                full_path = os.path.join(img_folder, fname)
                # 关键：必须注入 Attachment/ 前缀
                z.write(full_path, arcname=f"Attachment/{fname}")

def update_single_image_in_atc(atc_path: str, new_img_path: str, arc_name: str = None):
    """安全覆盖/追加已有 .atc 中的单张图片"""
    fname = arc_name or os.path.basename(new_img_path)
    target_arc = f"Attachment/{fname}"
    temp_atc = atc_path + ".tmp"
    with zipfile.ZipFile(atc_path, 'r') as z_in, zipfile.ZipFile(temp_atc, 'w', compression=zipfile.ZIP_DEFLATED) as z_out:
        for item in z_in.infolist():
            if item.filename != target_arc:
                z_out.writestr(item, z_in.read(item.filename))
        z_out.write(new_img_path, arcname=target_arc)
    shutil.move(temp_atc, atc_path)
```
