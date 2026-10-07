# FGO_Q Editor V5 视觉与交互设计规范 (Mooncell Design System)

> **版本**：v1.0 (2026-10-06)  
> **设计源**：[Mooncell - 玩家共同构筑的 FGO 中文 Wiki (fgo.wiki)](https://fgo.wiki/w/%E9%A6%96%E9%A1%B5)  
> **适用范围**：`editor_v5/` 及其未来新增功能页面、浮层与组件

---

## 📖 设计哲学与背景

`editor_v5`（Battle Config Editor）的原始设计深度参考了 **Mooncell (fgo.wiki)** 首页及其从者、关卡子页面的经典视觉风格：
1. **高信息密度与工整对齐**：承袭 Wiki 的表格与卡片信息排版基因，紧凑、清晰、无多余留白；
2. **纯净通透的高对比度白昼基底**：主底色为纯净淡蓝灰（`#f4f7fb`），面板与卡片为纯白（`#ffffff`），彻底消除低对比度发灰感；
3. **三级色阶与 FGO 职阶/色卡语义**：严格遵循 Mooncell 官方正统的 `light-`（底色）、`base-`（边框）、`dark-`（文字/激活）三级色彩阶梯，避免大面积刺眼纯色块；
4. **全局统一，严禁割裂**：所有视图（战术编排、后勤整备、屏幕标定等）无论功能性质如何，**严禁自行引入深黑/暗夜模式**，必须在统一的视觉语言下演进。

---

## 🌐 参考 Wiki 网站信息与对标子页面 (Reference Sources)

### 1. 参考站点基本信息
* **网站名称**：Mooncell - 玩家共同构筑的 FGO 中文 Wiki
* **主站首页**：[https://fgo.wiki/w/首页](https://fgo.wiki/w/%E9%A6%96%E9%A1%B5)
* **站点性质**：非营利性质的高信息密度 FGO 中文资料 Wiki 平台
* **官方全局样式源**：[`site.styles` (Vector 皮肤自定义样式表)](https://fgo.wiki/load.php?lang=zh-cn&modules=site.styles&only=styles&skin=vector)
  * 本系统的 `--lightblue`, `--darkblue`, `--lightyellow`, `--green`, `--purple` 等核心色阶变量均直接提取并对齐自该官方样式表。

---

### 2. 核心对标子页面与 Editor 组件映射

| Mooncell 对标子页面 | 页面典型 URL | 对标参考的 UI 特征 | 落地到 Editor V5 的对应模块 |
| :--- | :--- | :--- | :--- |
| **Wiki 首页** | [fgo.wiki/w/首页](https://fgo.wiki/w/%E9%A6%96%E9%A1%B5) | • 浅蓝灰底色（`#f4f7fb`）<br>• 通报横幅（Notice Banner）<br>• 品牌标头与高对比度文字体系 | • 全局基底背景 `--bg-base`<br>• 顶栏品牌区与版本号徽章<br>• 互斥运行警示条（Lock Banner） |
| **英灵图鉴 / 从者详情页** | [从者详情 (如：阿尔托莉雅)](https://fgo.wiki/w/%E9%98%BF%E5%B0%94%E6%89%98%E8%8E%89%E9%9B%85%C2%B7%E6%BD%98%E5%BE%B7%E6%8B%89%E8%B4%A1) | • **Tabber Neue 选项卡**（平铺胶囊分段器）<br>• **技能/宝具卡片**（红/蓝/绿职阶三级色阶）<br>• **灵基再临阶段立绘查看器**（浅灰点阵底与柔和投影）<br>• **Wikitable 表头**（浅灰蓝底 + 左侧深蓝标条） | • **顶栏主视图切换 Tab**（编排/整备/标定）<br>• **战术编排控制台**（从者/御主技能卡片组）<br>• **屏幕标定 Canvas 视口**（专业浅色点阵工作台）<br>• **卡片标题与弹窗 Header Strip** |
| **关卡与活动周回页** | [主线/周回关卡副本汇总](https://fgo.wiki/w/%E5%85%B3%E5%8D%A1%E4%B8%80%E8%A7%88) | • 多回合敌方配置与行动时序排版<br>• 关卡掉落物与活动点数奖励徽章<br>• 紧凑型筛选工具栏（Filterable bar） | • **战斗动作时序看板**（Round/Waves Board）<br>• **方案元数据与点数奖励开关**<br>• **全局运行参数栏**（`runner-settings-bar`） |
| **育成强化与道具素材页** | [技能与灵基再临强化素材](https://fgo.wiki/w/%E7%B4%A0%E6%9D%90%E4%B8%80%E8%A7%88) | • 从者/礼装/技能强化计算与推荐布局<br>• 技能等级上限分段胶囊（Lv9 / Lv10）<br>• 无限池奖池卡片矩阵 | • **后勤整备 5 大功能展示卡片**（无限池/从者/礼装/技能/友情抽卡）<br>• **技能强化等级药丸**（Segmented Pills）<br>• **实时场景探测器横幅**（Detector Card） |

---

## 🎨 官方色彩系统 (Design Tokens)

所有色彩已完整沉淀在 `editor_v5/css/base.css` 的 `:root` 变量表中。日常开发与后续功能迭代**严禁硬编码 hex 颜色**，必须直接使用语义化变量：

### 1. 基础系统色
| Token 变量 | 色值 | 用途说明 |
| :--- | :--- | :--- |
| `--bg-base` | `#f4f7fb` | 页面主背景（淡蓝灰） |
| `--bg-panel` | `#ffffff` | 面板与容器底色（纯白） |
| `--bg-card` | `#ffffff` | 卡片底色 |
| `--bg-card-hover`| `#f0f6ff` | 卡片与列表项悬浮微底色 |
| `--line` | `#cbd5e1` | Wiki 主实线细边框（清爽利落） |
| `--line-light` | `#e2e8f0` | 次级细分隔线与表单描边 |
| `--text-main` | `#1f2937` | 高对比度深墨黑正文与标题 |
| `--text-muted` | `#4b5563` | 次要文本与标签说明 |
| `--text-subtle` | `#6b7280` | 辅助性弱文本与元数据 |

---

### 2. Mooncell 三级色阶体系 (来自 `site.styles`)

Mooncell 的状态胶囊与组件采用经典的 **“浅色底 + 亮色边框 + 深色高对比文字”**：

```text
浅色态 (Light Background) ───► 边框态 (Border / Glow) ───► 激活/深色文字态 (Active / High Contrast Text)
```

| 职阶/功能语义 | 浅底色 (Light) | 边框色 (Base) | 深色文字/激活色 (Dark) | 典型应用场景 |
| :--- | :--- | :--- | :--- | :--- |
| **Arts 湖蓝** *(核心主色)* | `--lightblue` (`#EBF7FE`) | `--blue` (`#85C1F7`) | `--darkblue` / `--accent` (`#4487DF`) | 顶栏主操作、运行战斗、从者技能、标定匹配范围、链接 |
| **Gold 暖金** *(御主/高阶)* | `--lightyellow` (`#FEF9DE`) | `--yellow` (`#F9E179`) | `--darkyellow` / `--gold` (`#F1BD4C` / `#d9931e`) | 御主礼装、换人、默认方案星标、运行参数、就绪环境 |
| **Quick 翠绿** *(育成/就绪)* | `--lightgreen` (`#F9FFEA`) | `--green` (`#B9E66B`) | `--darkgreen` / `--quick` (`#84B63C` / `#4ea824`) | 运行整备、从者强化、标定截图选区、成功状态提示 |
| **Buster 猩红** *(警告/停止)* | `--lightred` (`#FDF5F5`) | `--red` (`#F3ACAA`) | `--darkred` / `--buster` (`#E7615C`) | 停止任务、退出服务倒计时、点击锚点标注、删除动作 |
| **灵基紫** *(目标锁定)* | `--lightpurple` (`#F7F1FC`) | `--purple` (`#C794F6`) | `--darkpurple` (`#A443DF`) | 锁定目标 1~6、Extra 特殊技能 |
| **暖橙** *(消耗/抽卡)* | `--lightorange` (`#FFF7ED`) | `--orange` (`#F4C89C`) | `--darkorange` (`#E7815C`) | 友情点抽卡、未保存 Dirty 动态呼吸提醒 |

---

## 📐 基础组件与排版规范

### 1. 结构与圆角规范
- **小徽章 / Pill 标签 / 分段按钮**：圆角固定为 `4px ~ 6px`；
- **常规操作按钮 / 搜索输入框**：圆角固定为 `6px`；
- **卡片 / 模块面板 / 弹窗**：圆角固定为 `8px ~ 10px`，杜绝生硬直角与过度夸张的大圆角；
- **阴影规范**：
  - 常规卡片：`box-shadow: 0 1px 3px rgba(0, 0, 0, 0.05), 0 1px 2px rgba(0, 0, 0, 0.03);`
  - 悬浮/浮层：`box-shadow: 0 4px 16px rgba(15, 23, 42, 0.12);`

### 2. 标题与栏目装饰 (Mooncell Header Strip)
Wiki 特色的栏目头均带有纯色左饰条：
```css
.card-title {
    font-size: 13.5px;
    font-weight: 700;
    color: var(--text-main);
    border-left: 3.5px solid var(--darkblue);
    padding-left: 8px;
}
```

### 3. 分段控制器 (Tabber Neue)
视图切换与分类切换采用 Mooncell 官方分段控制器：
- 外壳：`background: #e2e8f0; border: 1px solid var(--line); border-radius: 7px; padding: 2.5px;`
- 未激活项：透明底，`color: var(--text-muted);`
- 激活项：`background: #ffffff; color: var(--darkblue); font-weight: 700; box-shadow: 0 1px 3px rgba(0, 0, 0, 0.08);`

---

## 🖥️ 核心视图与模块设计规范

### 1. 顶部栏 (Masthead) & 运行中枢
* **Tab 导航**：使用 Tabber 分段胶囊规范，切换视图时不产生突兀闪烁；
* **双核运行按钮 (`twin-run-group`)**：
  * 外框采用纯白卡片胶囊，高度统一定为 `30px`；
  * **运行战斗**：采用 Arts 湖蓝渐变（`#4487df` ➜ `#2b75dc`）；
  * **运行整备**：采用 Quick 育成翠绿渐变（`#4ea824` ➜ `#38a169`）；
  * **停止任务**：合体替换为 Buster 猩红警戒渐变（`#e7615c` ➜ `#c53030`），带柔和呼吸脉冲。
* **运行参数栏 (`runner-settings-bar`)**：白底卡片 + 左侧 4px 湖蓝标条，内部复选框在勾选激活时呈现浅蓝微底与深蓝边框。

---

### 2. 战术编排视图 (Tactical Config View)
* **左侧方案列表**：紧凑列表项，激活项采用 `--lightblue` 背景与 `--darkblue` 文字；
* **动作时序看板**：Round/Wave 卡片具有工整的灰色外框，回合内部动作胶囊根据动作类型（从者技能、御主换人、锁定目标、出牌）严格对应三级色阶；
* **动作输入控制台**：
  * 锁定目标：默认白底细边，选中高亮为灵基紫（`#a443df`）；
  * 从者技能：默认白底，选中高亮为 Arts 湖蓝（`#4487df`）；
  * 御主技能：默认白底，选中高亮为 Gold 醇金（`#d9931e`）。

---

### 3. 后勤整备视图 (Logistics & Enhancement View)
* **实时场景探测器 (`extra-detector-card`)**：采用 Mooncell 经典的“信息通报横幅（Notice Banner）”样式，白底带有 4px 湖蓝左饰条与三级色阶探测胶囊；
* **5 大功能卡片矩阵 (`extra-cards-grid`)**：
  * 纯白底卡片，卡片头部配备专属职阶/功能图标与标题；
  * 底部标签为统一的浅灰/三级色阶 Pill；
  * 技能强化设置面板与等级药丸按钮（Lv9 / Lv10）全量采用浅色规范。

---

### 4. 屏幕标定工作台 (Calibration Studio)
* **主容器与侧栏**：彻底摒弃暗黑模式，背景使用 `--bg-base: #f4f7fb`，左侧资产清单与右侧属性检查器全量使用纯白卡片；
* **点阵工作台视口 (`cal-canvas-wrapper`)**：
  * 背景采用专业浅色网格点阵（`#f1f5f9` + `radial-gradient` 点阵），明亮通透；
  * Canvas 画布居中悬浮，外围配上精致阴影（`0 4px 18px rgba(0,0,0,0.15)`）与细线边框，让模拟器画面以精美卡面质感呈现；
  * 空状态提示卡片为半透明白底加微模糊毛玻璃质感；
* **图层与属性检查器**：截图选区（绿）、匹配范围（蓝）与点击锚点（红）使用对应的三级色阶，严禁在白底卡片内使用浅色/白色内联文字。

---

### 5. 浮层、弹窗与终端 (Overlays & Terminals)
* **Modals 弹窗**：白底卡片外壳，圆角 `8px`，标题带 3.5px 湖蓝标条；
* **右下角监控浮层 (`runner-monitor-panel`)**：浅色外壳 + 柔和灰黑终端日志框，融入整体页面；
* **全局 Toast**：深墨色半透明胶囊，平滑上升淡入。

---

## 🚫 后续开发避坑守则 (Anti-Patterns)

为保持系统长期的视觉纯洁度与高品质质感，后续新增功能请严格遵守以下红线：

1. ❌ **严禁自行开发 Dark Mode / 霓虹深黑卡片**：任何新视图与弹窗必须保持白昼 Wiki 风格；
2. ❌ **严禁在白底卡片上写死浅色文字**：例如 `color: #ffffff` 或浅灰，会导致文字隐形；
3. ❌ **严禁随意使用非标准 hex 颜色**：除极少数需要渐变的特殊按钮外，一律使用 `var(--darkblue)`、`var(--gold)` 等语义化变量；
4. ❌ **严禁破坏 6px~8px 的克制圆角规范**：避免使用过大（如 `24px`）或生硬直角（`0px`）；
5. ❌ **修改 HTML 必须同步两份文件**：`editor_v5/index.html` 与 `editor_v5/battle_config_editor.html` 必须保持严格一致，且引用 CSS 时务必带上最新的版本戳（如 `?v=20261006_mooncell`）。
