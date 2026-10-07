# FGO_Q 自动化战斗编排与执行体系

FGO_Q 是专为《Fate/Grand Order》(FGO) 设计的高效、高容错自动化战斗编排与执行系统。通过将**通用战斗执行引擎（Runner）**与**关卡出牌策略（Config）**彻底解耦，搭配**现代化独立可视化配置编辑器（Config Editor）**，实现从战术时序编排、ADB 毫秒级直推到桌面端一键直控启停的全链路闭环。

---

## 🌟 核心特性

- **策略与引擎彻底解耦**：战斗逻辑、图色识别与状态守卫封装于稳定引擎中；队伍技能、御主礼装与出牌策略以纯文本 DSL 独立承载，日常调优无需修改或重编引擎代码。
- **现代化可视化编排**：提供基于 WebView2 引擎的独立桌面配置编辑器（兼支持现代浏览器 Web 端访问），支持拖拽编排多回合技能、御主换人、目标选择、宝具与色卡偏好。
- **ADB 免复制直推与自愈**：一键保存（`Ctrl + S`）自动在 200ms 内直推至模拟器指定总线路径；内置轻量心跳监测，离线期间修改配置在模拟器就绪后自动补推。
- **页面一键直控与自愈闭环**：在编辑器页面直接「▶ 运行战斗」与「⏹ 停止战斗」，支持离线拦截引导、按钮状态自愈还原以及右下角无遮罩实时日志终端。
- **动态内存热重载 (Zero Restart)**：脚本启动时动态读取最新策略配置，日常修改方案或运行参数完全无需在模拟器中反复重启按键脚本。
- **工业级容错与版本保护**：内置结算图色抗噪点容错、单动作安全退出守卫、本地日志轮转以及自动保留最近 10 份历史快照。

---

## 📁 仓库目录导航

```text
FGO_Q/
├── Q/                      # 核心生产脚本
│   ├── battle_v5_runner.q  # 战斗执行主脚本 (V5 全解耦按键精灵执行引擎)
│   ├── battle_v5_config.q  # 战术策略与视觉标定配置库 (DSL 方案与全动态坐标)
│   └── .backup/            # 配置文件自动备份快照目录
├── editor_v5/              # V5 可视化配置编辑器与标定工坊 (Calibration Studio)
│   ├── launcher.py         # 桌面原生独立窗口启动器 (WebView2 引擎)
│   ├── server.py           # 本地 Python 后端服务 (端口 8099)
│   ├── calibration.py      # 实时截图标定、坐标换算与模板测试服务
│   ├── adb_sync.py         # ADB 自动探测、双通道直推同步与总线交互模块
│   └── index.html          # 编辑器前端主界面 (时序看板 + 标定工坊)
├── docs/                   # 详细架构设计与权威指南
│   ├── editor_ui_design_spec.md        # V5 前端视觉与交互设计规范 (Mooncell 规范)
│   ├── battle_v5_runner_config.md      # V5 架构权威指南与全解耦标定体系
│   ├── fgo_v5_execution_proposals.md   # V5 架构演进全量技术提案
│   └── tools_and_runtime_architecture.md # 底层工具体系与运行机制解析
├── archive/                # 历史版本与过往脚本资源归档
│   ├── Q/                  # V2/V3/V4 及历史关卡脚本归档 (60+ 份历史脚本)
│   ├── doc/                # V2/V3/V4 历史版本说明文档
│   ├── editor_v3/          # V3 独立配置编辑器归档
│   └── editor_v4/          # V4 独立配置编辑器归档
└── FGO_Config_Editor_V5.lnk # 桌面一键启动快捷方式
```

---

## 🚀 快速上手

### 1. 启动可视化配置编辑器
- **桌面窗口启动**：双击根目录下的 [FGO_Config_Editor_V5.lnk](file:///F:/2nd%20Accra/Git/Github/FGO_Q/FGO_Config_Editor_V5.lnk)（或在终端运行 `python editor_v5/launcher.py`），直接以独立原生窗口运行；
- **浏览器访问**：双击 `editor_v5/start_editor.bat` 启动后台服务，浏览器打开 `http://127.0.0.1:8099`。

### 2. 编排策略并保存
- 在顶栏调整连战次数、吃苹果、选择战场方案等全局参数；
- 在时序看板中拖拽排布技能与指令卡，按下 **`Ctrl + S`** 即可毫秒级直推模拟器生效。

### 3. 运行与监控
- **挂机运行**：在安卓模拟器中启动按键精灵 `battle_v5_runner`（启动后进入常驻待命）；
- **页面直控**：在配置编辑器顶栏点击「▶ 运行战斗」即可开始；点击顶栏状态胶囊可展开右下角实时日志终端查看进度。

---

## 📚 详细文档指引

想要深入了解系统设计细节、通信总线或排查故障，请参阅：

- [🎨 V5 前端视觉与交互设计规范 (Mooncell Design System)](file:///f:/2nd%20Accra/Git/Github/FGO_Q/docs/editor_ui_design_spec.md)：深入拆解 Mooncell (fgo.wiki) 官方设计基因、Design Tokens 色彩系统、各主视图与组件设计规范以及后续开发避坑红线。
- [🚀 V5 权威指南与全解耦标定体系](file:///f:/2nd%20Accra/Git/Github/FGO_Q/docs/battle_v5_runner_config.md)：涵盖 V5 视觉目标与点击坐标全解耦、标定工坊（Calibration Studio）使用说明、图片外部热替换、模拟器直推同步与完整键位表。
- [📖 V5 架构演进全量技术提案](file:///f:/2nd%20Accra/Git/Github/FGO_Q/docs/fgo_v5_execution_proposals.md)：包含坐标解耦、视口黑边探测算法与双通道同步流水线的技术推演与实现全貌。
- [🛠️ 运行工具体系与底层架构说明](file:///F:/2nd%20Accra/Git/Github/FGO_Q/docs/tools_and_runtime_architecture.md)：深入解析 PC 助手、ADB 桥接、安卓模拟器与移动端按键精灵的底层机制与避坑规范。
- [📦 V4 权威指南与 DSL 语法规范 (历史归档)](file:///F:/2nd%20Accra/Git/Github/FGO_Q/archive/doc/battle_v4_runner_config.md)：涵盖解耦哲学、多端直推、双向总线协议、内存热重载、DSL 完整语法及常见问题排查。
- [📦 历史归档资产](file:///F:/2nd%20Accra/Git/Github/FGO_Q/archive)：查阅过往 V2/V3/V4 文档、早期编辑器与往期活动关卡脚本留存。

