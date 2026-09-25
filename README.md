# FGO_Q 自动化战斗配置与执行体系

FGO 自动化战斗与策略编排系统。通过将**战斗底层引擎（Runner）**与**关卡出牌策略（Config）**彻底解耦，提供**轻量化可视化配置编辑器**，实现各关卡技能释放、御主礼装、从者换人、色卡偏好及队伍助战的直观配置与一键生效。

---

## 📌 版本导航 (V3 vs V4)

本项目目前采用 **V3 稳定版本** 与 **V4 进化版本** 双轨并行：

| 模块 / 资源 | V3 稳定版本 (Stable) | V4 进化版本 (Current Dev) |
| :--- | :--- | :--- |
| **战斗执行引擎** | [Q/battle_v3_runner.q](file:///F:/2nd%20Accra/Git/Github/FGO_Q/Q/battle_v3_runner.q) | [Q/battle_v4_runner.q](file:///F:/2nd%20Accra/Git/Github/FGO_Q/Q/battle_v4_runner.q) |
| **策略配置文件** | [Q/battle_v3_config.q](file:///F:/2nd%20Accra/Git/Github/FGO_Q/Q/battle_v3_config.q) | [Q/battle_v4_config.q](file:///F:/2nd%20Accra/Git/Github/FGO_Q/Q/battle_v4_config.q) |
| **可视化编辑器** | [editor_v3/](file:///F:/2nd%20Accra/Git/Github/FGO_Q/editor_v3) (服务端口 `8099`) | [editor_v4/](file:///F:/2nd%20Accra/Git/Github/FGO_Q/editor_v4) (服务端口 `8098`) |
| **桌面启动快捷方式** | [FGO_Config_Editor_V3.lnk](file:///F:/2nd%20Accra/Git/Github/FGO_Q/FGO_Config_Editor_V3.lnk) | [FGO_Config_Editor_V4.lnk](file:///F:/2nd%20Accra/Git/Github/FGO_Q/FGO_Config_Editor_V4.lnk) |
| **架构与配置文档** | [docs/battle_v3_runner_config.md](file:///F:/2nd%20Accra/Git/Github/FGO_Q/docs/battle_v3_runner_config.md) | [docs/battle_v4_runner_config.md](file:///F:/2nd%20Accra/Git/Github/FGO_Q/docs/battle_v4_runner_config.md) |

---

## 🚀 核心架构与演进

### V3 版本特性
- **纯粹数据分离**：将出牌与技能 DSL 提取至 `battle_v3_config.q`；
- **五大战区划分**：测试（test）、活动（campaign）、术呆常用（caber）、戴冠战（grand）、白纸化（ordeal）；
- **可视化时序看板**：多回合技能、御主礼装与出牌拖拽排布，自动轮转快照备份。

### V4 版本关键突破
1. **参数彻底下放**：将以往写死在 Runner 中的 5 项参数（大组选择、连战次数、吃苹果、人工助战、强制色卡）全部移至 Config，支持在 Web/桌面端实时调节保存；
2. **编辑器布局优化**：精简移除顶部横向战场 Tabs，收敛为顶栏单一下拉框统一驱动；顶栏直显运行配置，工作区视野更大；
3. **免复制直推与离线自愈 (阶段一已完成 ✅)**：编辑器保存时自动将配置写入代码仓库源文件、同步 Windows 本地 PC 手机助手目录，并通过 ADB 毫秒级直推模拟器通信总线（`/sdcard/FGO_Q/battle_v4_config.mq`）与覆盖历史工程。内置 10 秒轻量心跳监测，模拟器连接后自动静默补推最新配置，彻底告别频繁复制粘贴；
4. **直控运行路线 (阶段二规划中 🚀)**：设计基于 `/sdcard/FGO_Q/` 指令总线与状态文件回传，未来实现在编辑器上一键「▶ 运行战斗」与「⏹ 停止战斗」，实现完整闭环。

---

## 📚 项目完整文档索引

所有详细技术文档均归档在 [docs/](file:///F:/2nd%20Accra/Git/Github/FGO_Q/docs) 目录中：

- **V4 规范**：[docs/battle_v4_runner_config.md](file:///F:/2nd%20Accra/Git/Github/FGO_Q/docs/battle_v4_runner_config.md) — V4 架构说明、5 项运行配置、DSL 语法规范与使用指南。
- **工具与协同架构**：[docs/tools_and_runtime_architecture.md](file:///F:/2nd%20Accra/Git/Github/FGO_Q/docs/tools_and_runtime_architecture.md) — PC 手机助手、安卓模拟器、移动端按键精灵的底层机制、打包交互与通信总线说明。
- **V4 演进方案**：[docs/fgo_v4_execution_proposals.md](file:///F:/2nd%20Accra/Git/Github/FGO_Q/docs/fgo_v4_execution_proposals.md) — 页面直控运行方案思考、ADB 探测分析与分阶段实施路径。
- **V3 规范**：[docs/battle_v3_runner_config.md](file:///F:/2nd%20Accra/Git/Github/FGO_Q/docs/battle_v3_runner_config.md) — V3 架构规范与原版操作指引。
- **历史归档**：[docs/battle_v2_runner_config.md](file:///F:/2nd%20Accra/Git/Github/FGO_Q/docs/battle_v2_runner_config.md) — V2 历史版本留存文档。
