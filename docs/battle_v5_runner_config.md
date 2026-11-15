# Runner 与配置文件权威指南 (v5 版本架构规范)

本文档是 FGO_Q 自动化系统 **v5 架构（全视觉解耦、全链路闭环与标定工坊）** 的官方权威指南。全面涵盖 [Q/battle_v5_runner.q](file:///f:/2nd%20Accra/Git/Github/FGO_Q/Q/battle_v5_runner.q)（执行引擎主脚本）、[Q/battle_v5_config.q](file:///f:/2nd%20Accra/Git/Github/FGO_Q/Q/battle_v5_config.q)（战斗策略、助战模板与视觉标定配置库）、[editor_v5/](file:///f:/2nd%20Accra/Git/Github/FGO_Q/editor_v5)（四维可视化编排工作台）、以及 [.atc 附件包与资源部署体系](file:///f:/2nd%20Accra/Git/Github/FGO_Q/.agents/skills/fgo-atc-packager/SKILL.md) 的系统设计、通信协议、坐标规范与闭环控制机制。

前端视觉与交互设计规范请参阅 [🎨 Editor V5 视觉与交互设计规范 (Mooncell Design System)](file:///f:/2nd%20Accra/Git/Github/FGO_Q/docs/editor_ui_design_spec.md)。

---

## 1. 架构演进哲学：从 V4 到 V5 的四维彻底解耦

### 1.1 V4 的遗留瓶颈
在 **V4 架构** 中，初步实现了“出招 DSL 与执行引擎解耦”。但在日常深度使用、多分辨率适配与维护中暴露出明显的瓶颈：
1. **坐标与搜图范围硬编码**：找图范围 `[x1, y1, x2, y2]` 和点击坐标 `[x, y]` 硬编码在 Runner 脚本内部，调整任何坐标都需要反编译或重新打包按键精灵脚本。
2. **静态附件包依赖**：图片匹配过度依赖 PC 按键精灵助手打包的内置 Attachment 资源包，游戏图标若有微调需繁琐重新打包并部署。
3. **助战从者模板耦合**：新增助战或特定阵营从者（如善阵营杀狐、狂呆）需直接修改 Runner 内的多重 `If-Else` 判断分支。
4. **单核战斗思维**：整备（从者强化、灵基再临、技能强化、友情池、无限池）缺乏自动化闭环，必须依靠人工反复在各个界面之间切换。

### 1.2 V5 的四维核心解耦原则
**“策略归 Config，坐标归 Config，助战归 Profile，资源热覆盖，Runner 纯逻辑。”**

- **纯逻辑执行引擎 (Runner)**：不包含任何业务私有硬编码假定。启动时动态拉取最新配置，成为纯粹的状态机与驱动器。
- **全目标配置库 (Config)**：统一管理战斗 DSL、助战模板列表、视觉识别区域与点击坐标点。
- **动态名录档案 (Profile)**：助战名录由 [editor_v5/profiles/friends.json](file:///f:/2nd%20Accra/Git/Github/FGO_Q/editor_v5/profiles/friends.json) 驱动，标定档案由 [editor_v5/profiles/default_1440x810.json](file:///f:/2nd%20Accra/Git/Github/FGO_Q/editor_v5/profiles/default_1440x810.json) 维护，与代码解耦。
- **双轨资源覆盖机制 (Assets)**：模拟器优先命中 `/sdcard/FGO_Q/images/` 动态热更新图库，离线由按键精灵内置 `.atc` 附件包保底。
- **双核分体运行控制 (Twin Run)**：支持 `START_BATTLE`（战术战斗）与 `START_EXTRA`（后勤整备）双核驱动，各自具备独立的调度引擎与安全保护。

---

## 2. 现代协同架构全景图

```mermaid
flowchart TD
    subgraph PC端 Editor V5 可视化工作台
        W1["⚔️ 战术编排 (DSL Editor)"]
        W2["🛠️ 后勤整备 (Extra Workbench)"]
        W3["📐 屏幕标定 (Calibration Studio)"]
        W4["👥 管理助战 (Friends Manager)"]
        Server["Python 后端 (server.py & adb_sync.py)"]
    end

    subgraph 配置文件与版本库
        CfgFile["Q/battle_v5_config.q (权威配置源)"]
        ProfCalib["profiles/default_1440x810.json (标定档案)"]
        ProfFriend["profiles/friends.json (助战名录)"]
        ImgRepo["images/ & editor_v5/images/ (图片资产)"]
        Backups[".config_backups/*.bak.q (自动快照)"]
    end

    subgraph 模拟器 /sdcard/FGO_Q 运行时
        SimMQ["/sdcard/FGO_Q/battle_v5_config.mq (运行时配置)"]
        SimImg["/sdcard/FGO_Q/images/ (热更新图片库)"]
        SimRunner["按键精灵 Runner 进程 (battle_v5_runner)"]
    end

    W1 -- "编辑出招/换人策略" --> Server
    W2 -- "设置强化/抽卡参数" --> Server
    W3 -- "框选匹配图/点击坐标" --> Server
    W4 -- "增删改助战/绑定特征图" --> Server

    Server -- "更新配置与 ATT 模板" --> CfgFile
    Server -- "保存标定数据" --> ProfCalib
    Server -- "持久化助战名录" --> ProfFriend
    Server -- "写入带时间戳快照" --> Backups
    Server -- "ADB push 直推" --> SimMQ
    Server -- "ADB push 热更新图" --> SimImg

    Server -- "下发 START_BATTLE / START_EXTRA" --> SimRunner
    SimRunner -- "ReloadConfig() 动态拉取" --> SimMQ
    SimRunner -- "ResolveTargetImg() 优先检查" --> SimImg
    SimRunner -- "未热更新图片时保底" --> SimMQ
```

---

## 3. 目标与坐标配置项规范 (`battle_v5_config.q`)

基准设计分辨率为 **1440 × 810**（16:9 横屏）。全部配置在 [Q/battle_v5_config.q](file:///f:/2nd%20Accra/Git/Github/FGO_Q/Q/battle_v5_config.q) 中以按键精灵标准语法声明：

### 3.1 运行模式与全局参数
| 变量名 | 默认值 | 作用说明 |
| :--- | :--- | :--- |
| `SCREEN_BASE_W` | `1440` | 基准设计宽度 |
| `SCREEN_BASE_H` | `810` | 基准设计高度 |
| `RUN_MODE` | `0` | 当前运行主模式：`0` = 战术战斗 (Battle)，`1` = 后勤整备 (Extra) |
| `ACTION_GROUP_INDEX` | `2` | 当前生效大组：`0`=test, `1`=campaign, `2`=caber, `3`=grand, `4`=ordeal |
| `BATTLE_COUNT` | `30` | 连续战斗次数上限 |
| `APPLE_ENABLE` | `0` | 是否吃苹果补充体力 (`0`=关/不吃, `1`=银苹果, `2`=金苹果) |
| `MANUAL_CHOOSE_FRIEND` | `0` | 是否人工选择助战 (`0`=自动找图, `1`=人工选择) |
| `DEBUG_SCREENSHOT_ENABLE` | `0` | 是否开启调试排查全屏截图 (`0`=关, `1`=开) |
| `DEBUG_FRIEND_ONLY` | `0` | 助战调试模式：仅执行助战选择与翻页测试，选定后不进入战斗直接结束 (`0`=关, `1`=开；若开启人工选助战则不生效) |

### 3.2 助战模板声明与准备进战
所有助战从者模板在 `battle_v5_config.q` 中通过 `ATT_<Key>` 统一声明（支持以 `|` 组合多个立绘特征图），由 [editor_v5/profiles/friends.json](file:///f:/2nd%20Accra/Git/Github/FGO_Q/editor_v5/profiles/friends.json) 自动同步：

```vbscript
' ==================== 助战特征匹配图模板 (FRIEND TEMPLATES) ====================
Dim ATT_Aobao = "Attachment:friendAobao1.png|Attachment:friendAobao2.png|Attachment:friendAobao3.png|Attachment:friendAobao5.png"
Dim ATT_Aobaoshan = "Attachment:friendAobao3Shan.png"
Dim ATT_Cdai = "Attachment:friendCDai.png|Attachment:friendCDai2.png|Attachment:friendCDai3.png"
Dim ATT_Daoman = "Attachment:friendDaoMan3.png"
Dim ATT_Cba = "Attachment:friendCba.png"
Dim ATT_Rba = "Attachment:friendRba1.png|Attachment:friendRba2.png|Attachment:friendRba3.png|Attachment:friendRba4.png"
Dim ATT_Rbashan = "Attachment:friendRba3Shan.png"
Dim ATT_Shahu = "Attachment:friendShaHu1.png|Attachment:friendShaHu2.png|Attachment:friendShaHu3.png"
Dim ATT_Shahushan = "Attachment:friendShaHuShan1.png|Attachment:friendShaHuShan2.png|Attachment:friendShaHuShan3.png"
Dim ATT_Princess = "Attachment:friendPrincess.png|Attachment:friendPrincess2.png|Attachment:friendPrincess3.png"
Dim ATT_Princess120 = "Attachment:friendPrincess120.png|Attachment:friendPrincess1202.png|Attachment:friendPrincess1203.png"
Dim ATT_Taigong = "Attachment:friendtaigong.png"
Dim ATT_Sparrow = "Attachment:friendSparrow.png"
Dim ATT_Mary = "Attachment:friendMary1.png|Attachment:friendMary2.png"
Dim ATT_Keli = "Attachment:friendKeli1.png|Attachment:friendKeli2.png|Attachment:friendKeli3.png"
```

| 变量名 | 默认值 / 格式 | 含义 |
| :--- | :--- | :--- |
| `PREPARE_FRIEND_AREA` | `Array(40, 180, 920, 800)` | 助战职阶列表滚动检索识别区域 |
| `PREPARE_FRIEND_EQUIP_TAR` | `Array(40, 180, 920, 800, "Attachment:friend_equip_goodness.png")` | 助战概念礼装检索目标 |
| `PREPARE_FRIEND_SCROLLBAR_X` | `1412` | 助战右侧垂直滚动条轨道中心 X 坐标 |
| `PREPARE_FRIEND_SCROLLBAR_BASE_Y` | `228` | 未翻页时滑块初始中心 Y 坐标 |
| `PREPARE_FRIEND_SCROLLBAR_STEP_Y` | `61` | 翻一页（2个完整卡片位移 450px）滑块拖拽步进 Y 距离 |
| `PREPARE_FRIEND_PAGE_SWIPE_DELAY` | `1000` | 翻页拖拽后等待列表稳定延时 (ms) |
| `PAGE_TURNS_Gx_y` | `0` | 方案独立属性：当前页面未找到指定助战时向下翻页查找的最大次数（默认 0，每次正好翻动 2 个完整助战卡片） |
| `START_TAR` | `Array(1200, 700, 1420, 800, "Attachment:START_BTN.png")` | 编队确认页“开始战斗”按钮 |
| `START_TAPED_DELAY` | `8000` | 点击开始按钮后的等待加载延迟 (ms) |

### 3.3 战斗操作坐标（从者技能、指向、换人、御主）
| 变量名 | 默认值 | 对应按键 / 作用 |
| :--- | :--- | :--- |
| `BATTLE_HERO_SKILL_CHECK_TAR` | `Array(1200, 700, 1350, 750, "Attachment:ATTACK_BTN.png")` | 主攻击键识别（判定行动就绪） |
| `TAP_HERO_SKILL_1_1` ~ `1_3` | `[84, 650]`, `[183, 650]`, `[282, 650]` | 1 号位从者第 1、2、3 技能 |
| `TAP_HERO_SKILL_2_1` ~ `2_3` | `[441, 650]`, `[540, 650]`, `[639, 650]` | 2 号位从者第 1、2、3 技能 |
| `TAP_HERO_SKILL_3_1` ~ `3_3` | `[799, 650]`, `[897, 650]`, `[996, 650]` | 3 号位从者第 1、2、3 技能 |
| `BATTLE_SKILL_GRANT_CHECK_TAR` | `Array(1205, 142, 1267, 198, "Attachment:BATTLE_SKILL_GRANT_CHECK.png")` | 技能指向选择界面弹窗识别 |
| `TAP_SKILL_GRANT_HERO_1` ~ `3` | `[360, 500]`, `[717, 500]`, `[1074, 500]` | 指向充能选择 1、2、3 号从者 |
| `BATTLE_SKILL_CHANGE_CHECK_TAR` | `Array(723, 685, 777, 719, ...)` | 换人界面弹窗确认按钮检测 |
| `BATTLE_SKILL_CHANGE_SELECTEED_CHECK_TAR` | `Array(723, 685, 777, 719, ...)` | 换人从者选中后确认键高亮检测 |
| `TAP_SKILL_CHANGE_FRONT_1` ~ `3` | `[150, 390]`, `[375, 390]`, `[600, 390]` | 换人前排 1、2、3 号位从者 |
| `TAP_SKILL_CHANGE_BACK_1` ~ `3` | `[825, 390]`, `[1050, 390]`, `[1275, 390]` | 换人后排 1、2、3 号位从者 |
| `BATTLE_MASTER_SKILL_OPEN_TAR` | `Array(1280, 300, 1410, 420, ...)` | 御主技能展开图标识别 |
| `TAP_MASTER_SKILL_OPEN` | `Array(1317, 325)` | 御主技能抽屉展开点击点 |
| `TAP_MASTER_SKILL_1` ~ `3` | `[1020, 350]`, `[1120, 350]`, `[1220, 350]` | 御主第 1、2、3 技能点击点 |
| `BATTLE_SKILL_SPEEDUP_COORD` | `Array(1100, 770)` | 技能释放后的画面加速防卡点击点 |
| `BATTLE_SKILL_SPECIAL_SKILL_A_TAR` | `Array(180, 240, 345, 410, ...)` | 特殊技能弹窗检测（如静希草十郎） |
| `TAP_SKILL_SPECIAL_SKILL_A_ACT_3` | `Array(1060, 480)` | 特殊技能第 3 动作选项点击坐标 |

### 3.4 敌方选怪、卡牌选出与卡牌确认
| 变量名 | 默认值 | 作用说明 |
| :--- | :--- | :--- |
| `TAP_TARGET_ENEMY_1` ~ `6` | `[159, 33]`, `[424, 33]`, `[689, 33]` 等 | 敌方 6 个目标位置点击点 (前排 1~3、后排 4~6) |
| `BATTLE_ATTACK_BACK_TAR` | `Array(1300, 750, 1390, 785, ...)` | 选卡界面中的返回键识别 |
| `TAP_CARD_NORMAL_1` ~ `5` | `[118, 581]` 至 `[1278, 581]` | 指令卡 1~5 号位点击点 |
| `TAP_CARD_NP_1` ~ `3` | `[412, 322]`, `[699, 322]`, `[986, 322]` | 宝具卡 1~3 号位点击点 |
| `BATTLE_ATTACK_CARD_BUSTER_TAR` | `Array(55, 460, 1390, 690, ...)` | Buster 红卡区域识别范围 |
| `BATTLE_ATTACK_CARD_ARTS_TAR` | `Array(55, 460, 1390, 690, ...)` | Arts 蓝卡区域识别范围 |
| `BATTLE_ATTACK_CARD_QUICK_TAR` | `Array(55, 460, 1390, 690, ...)` | Quick 绿卡区域识别范围 |
| `BATTLE_ATTACK_CARD_6_FIRST_TAPED_TAR` ~ `8` | 见配置 | 宝具 1~3 选出后高亮判定（红/蓝/绿三色多候选） |
| `BATTLE_ATTACK_CARD_3_FIRST_TAPED_TAR` | 见配置 | 普卡首位选出后的高亮识别区域 |
| `BATTLE_HERO_NP_FACE_1_TAR` ~ `3` | `Array(443, 181, 483, 201, ...)` 等 | 从者 1~3 号位宝具卡面部立绘采样切片区域 (40x20，支持屏幕标定可视化微调) |
| `BATTLE_HERO_CARD_AREA_1_TAR` ~ `5` | `Array(33, 480, 203, 580, ...)` 等 | 手牌 1~5 号位从者面部立绘匹配范围 (严格避开顶部饰条与暴击率数字，支持屏幕标定微调) |
| `BATTLE_CRIT_100_AREA_1_TAR` ~ `5` | `Array(63, 350, 83, 445, ...)` 等 | 手牌 1~5 号位 100% 暴击标志百位'1'搜寻区域 (支持屏幕标定微调) |
| `BATTLE_ATTACK_CARD_100_TAR` | `Array(55, 350, 1390, 445, ...)` | 100% 满暴击率识别特征多模板 (`BATTLE_ATTACK_CARD_100.png` \| `_2.png`) |
| `BATTLE_CARD_COLORS` | `Array("", "", "", "", "", "")` | 当前回合 1~5 号手牌检测到的色卡颜色缓存 (`B`/`A`/`Q`) |
| `BATTLE_CARD_IS_CRIT_100` | `Array(0, 0, 0, 0, 0, 0)` | 当前回合 1~5 号手牌 100% 满暴标记状态缓存 (`0`/`1`) |
| `BATTLE_ATTACK_CARD_PRIORITY_TARS` | `Array(null, null, null, null)` | 从者 1~3 号位专属头像特征（动态从宝具卡采样或用户自定义） |
| `BATTLE_HERO_SAMPLED` | `Array(0, 0, 0, 0)` | 整场战斗从者 1~3 号位头像动态采样完成状态 (`0`/`1`) |

> **出牌与从者头像识别机制详见**：[本文档第 6 章：出牌偏好定制、长链优先级与动态宝具识别机制](#6-出牌偏好定制长链优先级与动态宝具识别机制)（包含长链优先级 DSL、100% 满暴决策及基于宝具卡动态零资产头像采样全套技术规范）。

### 3.5 结算、吃苹果与连续再战
| 变量名 | 默认值 | 作用说明 |
| :--- | :--- | :--- |
| `AWARD_TIE_TAR` | `Array(90, 190, 330, 225, ...)` | 战后羁绊/结果标识检测 |
| `AWARD_TIE_UP_TAR` | `Array(696, 101, 828, 245, ...)` | 从者羁绊等级提升升级弹窗检测 |
| `TAP_AWARD_SKIP` | `Array(166, 60)` | 战后连续点击跳过动画空白坐标 |
| `AWARD_TREASURE_NEXT_TAR` | `Array(1178, 696, 1282, 740, ...)` | 战利品掉落“下一步”按钮 |
| `AWARD_ACTIVITY_NEXT_TAR` | `Array(1178, 696, 1282, 740, ...)` | 活动点数结算“下一步”按钮 |
| `ADD_FRIEND_TAR` | `Array(325, 670, 415, 715, ...)` | 好友申请弹窗“拒绝/关闭”按钮 |
| `AGAIN_ALERT_AGAIN_TAR` | `Array(795, 620, 1030, 700, ...)` | 连续出击“连续出击”按钮 |
| `AGAIN_ALERT_CLOSE_TAR` | `Array(370, 620, 620, 700, ...)` | 连续出击“关闭”按钮 |
| `AGAIN_ORDEAL_NO_TICKET_TAR` | `Array(600, 600, 850, 670, ...)` | 白纸化地球茶壶/体力耗尽提示 |
| `AGAIN_BATTLE_OUT_MENU_TAR` | `Array(1301, 689, 1360, 715, ...)` | 关卡选择退出菜单标识 |
| `APPLE_DISPLAY_TAR` | `Array(634, 37, 743, 83, ...)` | 体力耗尽恢复确认弹窗 |
| `APPLE_CONFIRM_TAR` | `Array(800, 580, 1050, 720, ...)` | 吃苹果使用确认“决定”按钮（兼容金/银苹果不同高度弹窗） |
| `TAP_APPLE_GOLDEN` | `Array(420, 360)` | 金苹果选项点击点 |
| `TAP_APPLE_SILVER` | `Array(420, 520)` | 银苹果选项点击点 |
| `TAP_APPLE_CLOSE` | `Array(720, 695)` | 吃苹果弹窗取消关闭按钮 |

### 3.6 后勤整备 (Extra) 参数与全目标配置
| 变量名 | 默认值 / 格式 | 作用说明 |
| :--- | :--- | :--- |
| `EXTRA_ACTION_COUNT` | `30` | Extra 动作执行上限次数 (1~999，如强化 30 次/抽卡 100 次) |
| `EXTRA_SKILL_MAX_LEVEL` | `10` | 技能强化目标上限等级 (1~10，若小于 10 则防止升 10 消耗结晶) |
| `EXTRA_SKILL_AUTO_THREE` | `1` | 技能强化是否自动轮询 1、2、3 全部技能 (`0`=关, `1`=开) |
| `EXTRA_HERO_AUTO_ASCEND` | `1` | 从者强化是否在满级时自动执行灵基再临 (`0`=关, `1`=开) |
| `EXTRA_HERO_AUTO_GRAIL` | `1` | 从者强化是否自动执行圣杯转临 (`0`=关闭, `1`=100上限/防超100, `2`=无上限/持续转临) |
| `EXTRA_DRY_RUN` | `1` | 防点安全锁/仿真测试模式 (`1`=开启防点保护/只识别不点击, `0`=正常真实点击) |
| `ENHANCE_HERO_LV100_TAR` | `Array(470, 505, 580, 565, ...)` | 强化主界面强化结果当前等级粗体 100 识别切片 (第一道防守) |
| `ENHANCE_GRAIL_HERO_LV100_TAR` | `Array(470, 230, 580, 290, ...)` | 圣杯转临界面转临结果目标等级粗体 100 识别切片 (第二道防守) |
| `ENHANCE_HERO_TAR` | `Array(880, 5, 1300, 70, ...)` | 从者强化主界面标识 |
| `ENHANCE_HERO_RECOMMAND_TAR` | `Array(1240, 150, 1370, 208, ...)` | 自动选择推荐狗粮按钮 |
| `ENHANCE_HERO_RECOMMAND_CONFIRM_TAR`| `Array(880, 680, 1006, 745, ...)` | 自动推荐狗粮弹窗“决定/确认”按钮 |
| `ENHANCE_HERO_ENHANCE_TAR` | `Array(1340, 716, 1438, 798, ...)` | 从者/再临执行强化主按钮 |
| `ENHANCE_HERO_ENHANCE_CONFIRM_TAR` | `Array(877, 632, 1006, 698, ...)` | 从者强化弹窗确认按钮 |
| `ENHANCE_HERO_TEMP_CONFIRM_TAR` | `Array(877, 590, 1006, 660, ...)` | 限时加入（临时）从者强化/再临/转临提示弹窗“决定”按钮 |
| `TAP_ENHANCE_HERO_TEMP_CONFIRM` | `Array(943, 633)` | 临时从者提示弹窗“决定”点击点 |
| `ENHANCE_HERO_REFUND_CLOSE_TAR` | `Array(550, 580, 890, 680, ...)` | 溢出经验/素材返还弹窗“关闭”按钮 |
| `TAP_ENHANCE_HERO_REFUND_CLOSE` | `Array(686, 614)` | 经验/素材返还弹窗点击点 |
| `ENHANCE_HERO_TO_ASCEND_TAR` | `Array(1050, 580, 1320, 680, ...)` | 满级时“前往灵基再临”跳转按钮识别 |
| `TAP_ENHANCE_HERO_TO_ASCEND` | `Array(1185, 628)` | 点击前往灵基再临跳转点 |
| `ENHANCE_HERO_TO_GRAIL_TAR` | `Array(1050, 580, 1320, 680, ...)` | 满级时“前往圣杯转临”跳转按钮识别 |
| `TAP_ENHANCE_HERO_TO_GRAIL` | `Array(1185, 628)` | 点击前往圣杯转临跳转点 |
| `ENHANCE_ASCEND_TAR` | `Array(880, 5, 1300, 70, ...)` | 灵基再临主界面标识 |
| `ENHANCE_ASCEND_BTN_TAR` | `Array(1340, 716, 1438, 798, ...)` | 灵基再临执行按钮 |
| `ENHANCE_ASCEND_CONFIRM_TAR` | `Array(877, 632, 1006, 698, ...)` | 灵基再临弹窗确认按钮 |
| `ENHANCE_ASCEND_TO_HERO_TAR` | `Array(1000, 270, 1360, 370, ...)` | 再临完成后“前往强化从者”快捷返回按钮 |
| `TAP_ENHANCE_ASCEND_TO_HERO` | `Array(1180, 321)` | 点击“前往强化从者”快捷跳转点 |
| `ENHANCE_ASCEND_BACK_TAR` | `Array(40, 10, 120, 65, ...)` | 灵基再临左上角返回按钮 |
| `TAP_ENHANCE_ASCEND_BACK` | `Array(60, 40)` | 左上角返回点击点 |
| `ENHANCE_GRAIL_TAR` | `Array(1050, 5, 1420, 70, ...)` | 圣杯转临主界面标识 |
| `ENHANCE_GRAIL_CONFIRM_TAR` | `Array(877, 632, 1006, 698, ...)` | 圣杯转临弹窗确认按钮 |
| `TAP_ENHANCE_GRAIL_CONFIRM` | `Array(943, 662)` | 圣杯转临弹窗确认点击点 |
| `TAP_ENHANCE_BLIND_SKIP` | `Array(940, 660)` | 强化/再临结算超长立绘与语音盲点快进点击点 |
| `ENHANCE_SKILL_TAR` | `Array(880, 5, 1300, 70, ...)` | 技能强化主界面标识 |
| `ENHANCE_SKILL_ENHANCE_TAR` | `Array(1185, 725, 1230, 785, ...)` | 技能强化主按钮 |
| `ENHANCE_SKILL_ENHANCE_CONFIRM_TAR`| `Array(820, 640, 890, 690, ...)` | 技能强化弹窗确认按钮 |
| `ENHANCE_SKILL_ENHANCE_L10_TAR` | `Array(450, 490, 610, 630, ...)` | 技能升 10 级专用标识 (传承结晶提示) |
| `ENHANCE_SKILL_MAX_L10_TAR` | `Array(1150, 720, 1410, 800, ...)` | 技能已达 Lv10 上限标识 |
| `ENHANCE_SKILL_CLICK_COORD` | `Array(1100, 765)` | 技能升级动画快速点击跳过点 |
| `TAP_ENHANCE_SKILL_1` ~ `3` | `[532, 286]`, `[852, 286]`, `[1172, 286]` | 技能强化界面 1、2、3 号技能切换点击点 |
| `ENHANCE_SKILL_HERO_UNSELECTED_TAR`| `Array(140, 560, 300, 630, ...)` | 从者未选择或技能满级自动取消选中标识 |
| `ENHANCE_EQUIP_TAR` | `Array(880, 5, 1300, 70, ...)` | 概念礼装强化主界面标识 |
| `ENHANCE_EQUIP_ENHANCE_TAR` | `Array(1340, 716, 1438, 798, ...)` | 礼装强化主按钮（可点击态，右侧白底-青框边缘） |
| `ENHANCE_EQUIP_ENHANCE_GRAY_TAR` | `Array(1340, 716, 1438, 798, ...)` | 礼装强化主按钮（置灰不可点击态，右侧灰底-青框边缘） |
| `ENHANCE_EQUIP_ENHANCE_CONFIRM_TAR`| `Array(877, 632, 1006, 698, ...)` | 礼装强化弹窗确认按钮 |
| `POOLFRIEND_CONTINUE_TAR` | `Array(720, 720, 990, 800, ...)` | 友情点召唤继续抽卡按钮 |
| `POOLFRIEND_GO_TAR` | `Array(830, 600, 1080, 670, ...)` | 友情池前往召唤确认按钮 |
| `INFINITE_ROLL_TAR` | `Array(330, 370, 620, 610, ...)` | 无限池抽奖按钮 (ROLL100 / ROLL10) |
| `INFINITE_ROLL_FAST_COORD` | `Array(300, 400)` | 无限池极速连点空白点 |

---

## 4. 后勤整备 (Extra) 自动化闭环引擎规范

在 [Q/battle_v5_runner.q](file:///f:/2nd%20Accra/Git/Github/FGO_Q/Q/battle_v5_runner.q) 中，Extra 模式已进化为包含自检、跳转、动画跳过与返回自循环的完整闭环。

```mermaid
stateDiagram-v2
    [*] --> DetectScene: 启动 Extra
    DetectScene --> HeroEnhance: 识别到从者强化
    DetectScene --> SkillEnhance: 识别到技能强化
    DetectScene --> EquipEnhance: 识别到礼装强化
    DetectScene --> FriendPool: 识别到友情池
    DetectScene --> InfiniteRoll: 识别到无限池

    state HeroEnhance {
        [*] --> CheckRefund: 进场防滞留
        CheckRefund --> FeedCards: 关闭返还弹窗
        FeedCards --> ExecuteEnhance: 推荐狗粮并确认
        ExecuteEnhance --> SkipAnim: 点击强化并确认
        SkipAnim --> CheckRefund: 强化中素材返还关闭
        SkipAnim --> LevelCapReached: 出现前往再临/转临
        LevelCapReached --> DoAscend: EXTRA_HERO_AUTO_ASCEND=1
        LevelCapReached --> DoGrail: EXTRA_HERO_AUTO_GRAIL=1
        LevelCapReached --> [*]: 达到阶段上限且未开转临
        
        state DoAscend {
            [*] --> ClickAscendBtn: 确认进入再临界面
            ClickAscendBtn --> FastForward60s: 确认再临消耗
            FastForward60s --> ClickBackToHero: 盲点快进超长台词
            ClickBackToHero --> [*]: 点击「前往强化从者」
        }
        DoAscend --> FeedCards: 无缝返回从者强化
    }

    state SkillEnhance {
        [*] --> CheckSkillUnselected: 检查从者选中状态
        CheckSkillUnselected --> CycleSkills: 技能 1 -> 2 -> 3 循环
        CycleSkills --> LoreProtection: 检查 Lv9 传承结晶保护
        LoreProtection --> Max10Check: 检查 Lv10 上限
        Max10Check --> CycleSkills: 未达上限继续升级
        CycleSkills --> [*]: 三技能均达到目标
    }
```

### 4.1 从者强化与灵基再临自闭环 (`DoEnhance` & `DoHeroAscendFlow`)
1. **防滞留检测**：进入每轮强化前，首先识别 `ENHANCE_HERO_REFUND_CLOSE_TAR`，即时关闭由于大成功导致经验溢出弹出的素材返还弹窗。
2. **自动喂狗粮**：点击 `ENHANCE_HERO_RECOMMAND_TAR` 触发系统推荐狗粮，并在弹出确认窗口后点击 `ENHANCE_HERO_RECOMMAND_CONFIRM_TAR`。
3. **强化执行与临时从者提示自适应**：
   - 点击 `ENHANCE_HERO_ENHANCE_TAR` 触发强化；
   - 若遇到限时加入（临时）从者的提示弹窗（出现于点击强化后、最终确认前，内容警告道具不退还并询问是否确认），引擎自动识别其上浮的「决定」按钮（`ENHANCE_HERO_TEMP_CONFIRM_TAR`）并点击放行；
   - 随后继续等待并点击常规确认弹窗的「决定」按钮（`ENHANCE_HERO_ENHANCE_CONFIRM_TAR`）；
   - 调用 `SkipHeroEnhanceAnim()` 持续以 `TAP_ENHANCE_BLIND_SKIP` 快进动画。
4. **无缝灵基再临**：
   - 强化达到当前等级上限时，游戏右下角浮现“前往灵基再临”（`ENHANCE_HERO_TO_ASCEND_TAR`）。
   - 若 `EXTRA_HERO_AUTO_ASCEND = 1`，Runner 自动点击跳转，进入灵基再临界面。
   - 点击灵基再临主按钮后，同样内置临时从者提示弹窗自适应放行逻辑，随后确认进入再临。
   - 启动最长 **60 秒的安全盲点快进**，跳过从者的长篇晋级台词与立绘演出。
   - 检测到界面右上角的「前往强化从者」按钮（`ENHANCE_ASCEND_TO_HERO_TAR`）时，立即点击返回从者强化界面，**形成无缝自循环**，继续喂食下一阶段狗粮！
5. **圣杯转临守护与防超 100 级双重防守 (`DoHeroGrailFlow`)**：
   - **三态配置设计**：`EXTRA_HERO_AUTO_GRAIL` 支持 3 种模式（`0`=关闭, `1`=100上限/防超100, `2`=无上限/持续转临）。
   - **第一道防守（强化主界面拦截）**：当从者满级浮现“前往圣杯转临”（`ENHANCE_HERO_TO_GRAIL_TAR`）时，若勾选了 `100上限`，引擎立即在左侧强化结果区域复核等级数字切片 `ENHANCE_HERO_LV100_TAR`。若已达 100 级，**彻底阻断对跳转按钮的点击**，宣布达成百级育成并安全停机，根本不跳转进入转临界面。
   - **第二道防守（转临主界面二次复核拦截）**：针对 90~98 级跨阶段转临或人工停留在转临界面启动的断点场景，在转临界面执行前再次复核转临结果区域粗体 `100` 切片 `ENHANCE_GRAIL_HERO_LV100_TAR`。若已达 100 级且设置了 100 上限，**彻底阻断右下角「强化」按钮点击**，绝不误喂圣杯突破 100 级。
   - **断点自愈接管**：引擎通过 `DetectExtraMethodIndex` 自动识别转临界面标识 `ENHANCE_GRAIL_TAR`，即使直接在转临界面启动脚本，亦能无缝接管并触发第二道防守安全停机。
   - **全流程仿真防点安全锁 (`EXTRA_DRY_RUN`)**：若在 Editor 调试选项中开启 `🔒 防点安全锁`（`EXTRA_DRY_RUN = 1`），强化点击、灵基再临点击、圣杯转临点击及所有二次确认弹窗点击均会在下发前被物理短路拦截，仅打印匹配日志与状态更新，实现 100% 零消耗安全测试。

### 4.2 技能三技能轮询与结晶防护 (`DoSkillEnhance`)
1. **三技能自动轮询**：若 `EXTRA_SKILL_AUTO_THREE = 1`，引擎从技能 1 开始强化，升至目标或材料不足后，自动依次切换至技能 2（`TAP_ENHANCE_SKILL_2`）和技能 3（`TAP_ENHANCE_SKILL_3`）。
2. **传承结晶安全锁**：若 `EXTRA_SKILL_MAX_LEVEL < 10`（默认预设为 9），当检测到技能进入升 10 级弹窗并出现传承结晶图标（`ENHANCE_SKILL_ENHANCE_L10_TAR`）时，系统立即中断当前技能升级，防止意外消耗珍贵结晶。
3. **满级自动完结**：当技能达到 10 级（`ENHANCE_SKILL_MAX_L10_TAR`）或所有技能升满导致从者自动取消选中（`ENHANCE_SKILL_HERO_UNSELECTED_TAR`）时，引擎安全退出。

### 4.3 概念礼装强化与自动停机闭环 (`DoEquipEnhance`)
1. **入口容错与防呆停机**：
   - 进入 `DoEquipEnhance` 时先检测是否存在残留的经验溢出素材返还弹窗（`ENHANCE_HERO_REFUND_CLOSE_TAR`）；若存在则先点击「关闭」（`+35, +18`）并直接转入动画跳过/返回主界面等待循环。
   - 否则在短重试窗口（最多 6 次 × 300ms）内同步检测 `ENHANCE_EQUIP_ENHANCE_GRAY_TAR` 与 `ENHANCE_EQUIP_ENHANCE_TAR`：一旦检测到「强化」按钮已置灰（素材不足、未选素材或礼装已满级），或超时未检测到可点击按钮，立即设置 `HasTicket = false` 与 `ABORT_REASON` 并安全停机，避免无限空等。
   - 支持 `EXTRA_DRY_RUN = 1` 仿真防点安全锁拦截。
2. **强化执行与动画跳过**：
   - 点击可点击态「强化」按钮并确认 `ENHANCE_EQUIP_ENHANCE_CONFIRM_TAR`。
   - 在动画跳过循环中持续优先检测 `ENHANCE_HERO_REFUND_CLOSE_TAR`（大成功/极大成功满级返还弹窗）；若弹出则点击「关闭」并标记 `refundSeen = true`，继续跳过后续「请点击游戏界面」结算画面。
3. **满级/耗尽即时停机**：
   - 动画结束后若检测到 `ENHANCE_EQUIP_ENHANCE_GRAY_TAR`（按钮已变灰），或已关闭返还弹窗且返回主界面（`ENHANCE_EQUIP_TAR` 可见但 `ENHANCE_EQUIP_ENHANCE_TAR` 不可见），立即设置 `HasTicket = false` 并正常退出任务。

---

## 5. 助战管理体系与动态模板寻址规范

在 V5 架构中，助战体系完全解耦为独立的名录档案与动态寻址管线：

### 5.1 助战名录档案 (`editor_v5/profiles/friends.json`)
助战从者信息由 [profiles/friends.json](file:///f:/2nd%20Accra/Git/Github/FGO_Q/editor_v5/profiles/friends.json) 集中持久化：
```json
{
  "version": "1.0",
  "friends": [
    {
      "key": "shahu",
      "name": "杀狐",
      "shortLabel": "杀狐",
      "builtin": true,
      "images": [
        "friendShaHu1.png",
        "friendShaHu2.png",
        "friendShaHu3.png"
      ],
      "description": "红卡核心拐"
    },
    {
      "key": "shahushan",
      "name": "杀狐+善",
      "shortLabel": "杀狐+善",
      "builtin": true,
      "images": [
        "friendShaHuShan1.png",
        "friendShaHuShan2.png",
        "friendShaHuShan3.png"
      ],
      "description": "善阵营杀狐"
    }
  ]
}
```

### 5.2 动态模板同步与 Runner 零侵入解析
1. **Config 自动生成声明**：Editor V5 后端保存配置时，自动遍历 `friends.json`，在 `battle_v5_config.q` 头部生成对应的 `Dim ATT_<FriendKey> = "Attachment:img1.png|..."` 语句。
2. **Runner 动态反射检索**：
   在 [Q/battle_v5_runner.q](file:///f:/2nd%20Accra/Git/Github/FGO_Q/Q/battle_v5_runner.q) 的 `ReloadConfig()` 中：
   ```vbscript
   Dim customAtt = Trim(CStr(CfgGet("att_" & selectedFriendKey, "")))
   If Len(customAtt) > 0 And customAtt <> "Attachment:" Then
       PREPARE_FRIEND_TAR = Array(PREPARE_FRIEND_AREA[1], PREPARE_FRIEND_AREA[2], PREPARE_FRIEND_AREA[3], PREPARE_FRIEND_AREA[4], customAtt)
       HAS_FRIEND_CONFIG = true
   ...
   ```
   **优势**：在 Editor V5 的「管理助战」面板中新增任意从者并完成标定截图后，**无需修改 `battle_v5_runner.q` 的任何一行代码**，即可在战术编排中直接选择并生效！

---

## 6. 出牌偏好定制、长链优先级与动态宝具识别机制

> **关联机制库**：[docs/fgo_game_mechanics.md](file:///f:/2nd%20Accra/Git/Github/FGO_Q/docs/fgo_game_mechanics.md)（FGO 游戏底层机制与视觉渲染特性知识库）

### 6.1 功能目标与技术定位

在实际周回与高难关卡中，选卡出牌逻辑具备高度复杂性（如单核主 C 集火、副 C 垫刀、特定从者色卡暴击、严格防翻车刹车等）。  
本系统由**「自由长链优先级序列」**、**「100% 满暴击决策」**与**「动态宝具卡从者头像零维护识别」**三大核心支柱组成：

1. **自由长链优先级序列**：
   - 用户可构建任意深度的优先级链路（如：`H1A!>H1!>H3!>*`）。
   - 执行端按自左至右的顺序链式扫描判定，首次命中可用手牌即出牌。
2. **100% 暴击决策 (Crit 100%)**：
   - **满暴优先择优 (Auto Tie-Breaker)**：当同一条件命中多张手牌时，自动优先挑选带有 100% 满暴标记的卡。
   - **必爆硬性过滤 (Must Crit, 后缀 `!`)**：显式要求必须 100% 暴击，若非满暴则视为不命中并顺延至下一条件。
3. **动态宝具卡从者头像识别 (Zero-Asset Dynamic NP Avatar Sampling)**：
   - **拒绝维护全量静态头像库**：游戏内从者数量极其庞大，且每位从者存在 1~4 阶段不同再临立绘，预先切片维护静态图像库成本过高且极易失效。
   - **零切图自适应采样**：直接利用攻击选卡阶段升起的宝具卡（宝具 1/2/3 对应从者 1/2/3），在脚本运行期间动态调用 `SnapShot` 截取面部立绘，并缓存至设备临时目录。
   - **整场战斗持久复用**：从者宝具只要在战斗中（如 W1 或 W2）升起过一次并完成采样，其头像缓存将在整场战斗跨回合、跨面持续生效，即使随后从者放完宝具 NP 归零，后续回合也能稳定识别其普攻手卡。
4. **安全刹车停机**：
   - 若用户配置的严格优先级序列全部未命中场上手牌且未显式指定 `*` 兜底，脚本立即触发 `AbortBattle` 安全停止，防止盲出废牌导致高难翻车。

---

### 6.2 界面布局与线框原型 (UI Layout)

#### 从「从1」卡牌触发偏好定制弹窗

```text
┌────────────────────────────────────────────────────────┐
│  [从1] 顺位 ① 偏好定制                           [✕]  │
├────────────────────────────────────────────────────────┤
│  ┌──────────────────────────────────────────────────┐  │
│  │ [ 1 从1·红★ ✕ ] ──► [ 2 从1·无 ✕ ] ──► [ 3 从3·无 ✕ ]│  │
│  └──────────────────────────────────────────────────┘  │
│  [清空]                 [☐ 必爆]           H1B!>H1>H3 │
├────────────────────────────────────────────────────────┤
│  当前[从1]: [无]  [●红]  [蓝]  [绿]                    │
├────────────────────────────────────────────────────────┤
│  从1:       [无]   [红]  [蓝]  [绿]                     │
│  从2:       [无]   [红]  [蓝]  [绿]                     │
│  从3:       [无]   [红]  [蓝]  [绿]                     │
│  色卡:      [红]   [蓝]  [绿]                           │
│  兜底:      [任意 (*)]                                │
└────────────────────────────────────────────────────────┘
```

> **设计规范要点**：
> * **单一「必爆」开关**：界面仅保留一个 `[☐ 必爆]` 复选框（置于控制条中），去除冗余开关。
> * **首行聚焦当前卡**：`当前[从1]:` 为**单选模式 (Radio)**，直接联动上方流水线的**第 1 项**。
> * **流水线芯片星标联动**：带必爆要求的节点显示金黄色 `★`（如 `[ 1 从1·红★ ✕ ]`），点击芯片可快速切换必爆状态。
> * **下半区高密度排版**：严格按照 Mooncell 高密度配色与网格规范，去除多余引导文本，紧凑排列追加按钮。

---

### 6.3 点击与交互行为规则

1. **`[☐ 必爆]` 状态修饰器行为**：
   - 作为当前操作的修饰器：
     - 若 `[☑ 必爆]` **勾选**：
       - 点选 `当前[从1]` 色卡 $\to$ 第 1 项设置为带必爆（带 `★`，DSL 后缀 `!`）；
       - 点击下方追加按钮 $\to$ 追加带必爆的规则（带 `★`，DSL 后缀 `!`）；
     - 若 `[☐ 必爆]` **未勾选**：
       - 点选或追加的规则均为普通规则（无 `!` 后缀）。
   - **状态双向联动**：当点击/切换上方流水线节点时，`[☐ 必爆]` 开关与该节点是否必爆保持同步。

2. **首行 `当前[从1]:`（单选锚定 · 绑定第 1 项）**：
   - **Radio 机制**：`[无]`、`[红]`、`[蓝]`、`[绿]` 始终有且仅有一个选中；
   - 点选即直接修改第 1 项，**完全不破坏后续已配置的第 2、3 等顺位**。

3. **后续行（规则追加区 · 决定第 2 项及之后顺位）**：
   - 点击任意按钮向序列末尾追加对应规则：
     - `从1:` 的 `[红]` $\to$ 追加从1红卡（结合必爆状态生成 `[从1·红★]` 或 `[从1·红]`）；
     - `从1:` 的 `[无]` $\to$ 追加从1任意卡；
     - `色卡:` 的 `[红]` $\to$ 追加场上任意红卡；
     - `兜底:` 的 `[任意 (*)]` $\to$ 追加任意手牌兜底（`*` 不支持必爆修饰）。

4. **顶部已选序列流水线**：
   - **删除节点**：点击节点右侧 `[✕]` 单独移除该节点。
   - **快捷切换必爆**：点击节点上的 `★` 或双击节点，可直接切换该节点的必爆属性。
   - **清空流水线**：点击 `[清空]` 一键重置为初始单选状态。
   - **DSL 实时展示**：右侧实时呈现纯净的 DSL 表达式。

---

### 6.4 DSL 语法规范与原子对照表

#### 6.4.1 语法格式
使用 `>` 连接任意数量的原子条件，使用 `!` 后缀声明必爆：
$$\text{条件1} > \text{条件2} > \text{条件3} > \dots > \text{兜底项}$$

#### 6.4.2 原子条件对照表
| 原子标记 | 含义 | 必爆标记 | 底层匹配依据 | 说明 |
| :--- | :--- | :---: | :--- | :--- |
| `H1B` / `H1A` / `H1Q` | 从1指定色卡 | 否 | 动态采样头像 + 色卡找图 | 优先出从1该色卡；多张同色卡自动择优 100% 满暴卡 |
| `H1B!` / `H1A!` / `H1Q!` | 从1指定色卡 (必爆) | **是** | 动态采样头像 + 色卡 + 满暴100% | **必须 100% 暴击**；若非 100% 则顺延下一项 |
| `H1` / `H2` / `H3` | 从者任意卡 | 否 | 动态采样头像 | 匹配指定从者任意手牌，同从者下手牌优先满暴卡 |
| `H1!` / `H2!` / `H3!` | 从者任意卡 (必爆) | **是** | 动态采样头像 + 满暴100% | **必须为该从者的 100% 暴击卡**，否则顺延 |
| `B` / `A` / `Q` | 场上任意该色卡 | 否 | 色卡找图 | 任意从者该色卡，自动优先满暴卡 |
| `B!` / `A!` / `Q!` | 场上任意该色卡 (必爆) | **是** | 色卡找图 + 满暴100% | 场上必须有 100% 暴击的该色卡才出，否则顺延 |
| `*` | 场上任意手牌 | 否 | 任意可用手卡 | 兜底项；前置条件均未命中时出任意牌，防止脚本停机 |

---

### 6.5 动态宝具卡从者头像识别架构 (Dynamic NP Avatar Sampling)

```mermaid
flowchart TD
    Start["进入指令卡界面 (DoAttackActions)"] --> Delay["延时等待宝具卡升起动画稳定"]
    Delay --> Loop["遍历检测从者 1, 2, 3"]
    Loop --> CheckSampled{"该从者已采样？<br>(BATTLE_HERO_SAMPLED[h]==1)"}
    CheckSampled -- 是 --> NextHero["检查下一个从者"]
    CheckSampled -- 否 --> ActiveCheck{"宝具卡是否亮起？<br>IsNPCardActive(h)"}
    ActiveCheck -- 否(NP<100%未升起) --> NextHero
    ActiveCheck -- 是(NP>=100%升起) --> SnapShot["SnapShot 裁切纯净双眼面部特征 (40x20)<br>保存至 /sdcard/FGO_Q/images/tmp_hero_h.png"]
    SnapShot --> Mount["挂载到匹配数组:<br>BATTLE_ATTACK_CARD_PRIORITY_TARS[h]<br>BATTLE_HERO_SAMPLED[h] = 1"]
    Mount --> NextHero
    NextHero --> DetectCards["扫描当前 5 张手牌色卡与 100% 暴击率 (DetectBattleCards)"]
    DetectCards --> SelectCards["执行出卡长链匹配 (SelectAttackCard)"]
```

#### 6.5.1 宝具卡与手牌立绘一致性原理
* FGO 客户端在渲染攻击手牌与上方宝具卡时，使用的是完全相同的角色半身立绘资源。
* 宝具卡（6、7、8 号位）与手牌（1~5 号位）中的面部头像在**缩放比例、朝向角度、五官比例上完全一致**。
* 因此，直接从亮起的宝具卡裁切的面部图像，可直接作为手牌立绘的高精度匹配模板。

#### 6.5.2 宝具卡激活判定算法 (`IsNPCardActive`)
* **核心难点**：当从者 NP < 100% 时，宝具卡**完全不存在**，原位置显示的是战斗场景背景（如火焰燃烧、暗色石柱、天空、水流等）；当 NP ≥ 100% 时，宝具卡才从屏幕上方升起并带有边框与立绘。
* **算法实现**：
  - 针对从者 $h \in \{1, 2, 3\}$，对应宝具卡横坐标中心 $cx \in \{412, 699, 986\}$；
  - 在卡面立绘核心区横向 $cx-15, cx, cx+15$，纵向 $y \in \{155, 170, 185\}$ 均匀采样 9 个像素点；
  - 提取色彩分量并判断有效色彩/高光阈值：
    $$\text{isHit} = (B > 40) \land ((G > 40) \lor (B > 70))$$
  - **抗干扰特性**：背景火焰由于纯红/纯橙，其 $B$ 通道极低（实测 $B < 25$）；暗色背景各通道均极低；而升起的宝具卡面由于人物肤色、发色或边框高光，$B$ 与 $G$ 通道显著偏高。
  - **实测验证**：在全量历史战斗截图（跨越不同地图、燃烧背景、不同从者）中，未激活宝具卡命中点数 $\le 2$（通常为 0~1），激活宝具卡命中点数 $\ge 5$（通常为 8~9）。以 $\ge 3$ 为阈值，达到 **100% 正确率**。

#### 6.5.3 动态截屏与路径挂载 (`SampleServantAvatarsFromNPCards`)
* 当判定 `IsNPCardActive(h) == true` 且该从者尚未采样时：
  ```vbscript
  ' 宝具卡立绘面部双眼纯净区：以卡面面部为中心，尺寸 40x20（避开顶部Buff与底部宝具名大字，抗手牌垂直正弦呼吸浮动）
  SnapShot savePath, cx - 20, 180, cx + 20, 200
  ```
* 截取图片立即保存至 Android 存储 `/sdcard/FGO_Q/images/tmp_hero_h.png`；
* 将保存路径挂载到 `BATTLE_ATTACK_CARD_PRIORITY_TARS[h]`，并置 `BATTLE_HERO_SAMPLED[h] = 1`。

#### 6.5.4 战斗生命周期持久化与重置
* **跨回合持久性**：从者宝具只要在某一面（如 Wave 1）满充并被采样一次，生成的头像文件在整场战斗中始终保留。即使后续回合该从者释放了宝具导致 NP 回落至 0%，脚本依然可以使用已缓存的头像稳定匹配其手牌。
* **战斗开始重置**：在每场战斗开始时的 `DoBattle` 阶段，自动将 `BATTLE_HERO_SAMPLED` 重置为 `Array(0, 0, 0, 0)`，并清空临时 `tmp_hero_` 路径，确保换队或连续再战时能自动为新阵容采样。

#### 6.5.5 手牌立绘模板匹配工程规范 (`IsHeroCard`)
* **对应游戏机制**：对应 [docs/fgo_game_mechanics.md](file:///f:/2nd%20Accra/Git/Github/FGO_Q/docs/fgo_game_mechanics.md) 中关于“手牌正弦呼吸浮动”、“上下文字/Buff遮挡”以及“宝具表面流光粒子蒙层”规律。
* **工程解法**：
  - **40×20 紧凑面部采样**：
    - 废除 60×60 大方框，采用 40×20 横向条状切片，聚焦于双眼与鼻梁面部纯净区；
    - **避障与抗浮动能力**：水平居中避开右侧助战标牌（保留 $\ge 40\text{px}$ 间距）；垂直避开顶部 Buff 堆叠与底部宝具名大字；高度收窄至 20 像素使得手牌上下正弦浮动时特征完全保持在面部皮肤中，相似度绝不跳变。
  - **检测窗口垂直放宽**：以手牌中心横坐标 $cx$ 设定检测范围：
    $$\text{heroArea} = [cx - 85, 380, cx + 85, 560]$$
    垂直跨度达 180 像素，充分覆盖手牌呼吸浮动的位移裕量。
  - **动态蒙层容差与相似度校准**：
    - 宝具卡激活时表面覆盖全局动态流光 Shader（整卡全域提亮），与手牌原始立绘存在约 $25 \sim 40$ 灰度/色彩阶差异；
    - 底层调用匹配时配合偏色容差放宽至 `"282828"`（单通道 40 阶容差，精准吸收宝具全局 Shader 提亮），相似度阈值设为 `0.50`；
    - **实测工程数据**：
      - 目标从者手牌最佳匹配度：**0.6400 ~ 0.8875**（稳定判定命中）；
      - 非目标从者手牌最佳匹配度：**0.5587 ~ 0.5645**；
      - 区分度安全隔离裕度仍保持在 **0.08 以上**，既杜绝漏选又彻底杜绝误选他从者。

#### 6.5.6 彻底解耦助战标记
* 彻底移除了 `BATTLE_ATTACK_CARD_SUPPORT.png` 依赖。
* 助战从者可能位于 1、2、3 号任意槽位，系统完全通过宝具卡 6/7/8 与从者 1/2/3 对应，无需检测助战标，彻底避免了因 buff 图标遮挡助战标记导致的误判。

---

### 6.6 100% 满暴击率识别算法优化

#### 6.6.1 传统识别痛点
传统全图模板找图由于暴击星百分比数字直接浮动在不同颜色的指令卡（红、蓝、绿）上方，容易受卡面底色、从者立绘线条以及亚像素抗锯齿平滑影响，导致 100% 满暴数字匹配相似度波动。

#### 6.6.2 优化方案
* **数字 `1` 专属切片模板**：提取 100% 中百位数 `'1'` 的核心内切特征 `BATTLE_ATTACK_CARD_100.png`。
* **百位数窄带垂直扫描区**：
  $$\text{critAreaNarrow} = [cx - 55, 350, cx - 33, 445]$$
  横向精准锁定百位数 `'1'` 出现的固定偏移区间（$cx-55 \sim cx-33$），纵向覆盖正常浮动与已选浮动范围（$y: 350 \sim 445$）。
* **匹配相似度**：相似度阈值设为 `0.75`，兼容新旧模板双层兜底。实测红卡、绿卡、蓝卡上的 100% 暴击率均能在 91.2% ~ 94.0% 相似度下稳定命中，且对 0%~90% 暴击率保持 0 误判。

---

### 6.7 底层执行与匹配决策流程 (Runner Runtime)

```mermaid
flowchart TD
    Start["选卡指令执行 (SelectAttackCard)"] --> ScanCards["读取缓存的手牌色卡 Colors[1..5]<br>与满暴标记 Is100Crit[1..5]"]
    ScanCards --> ParseTokens["解析 DSL 优先级长链 (Split by '>')"]
    ParseTokens --> LoopTokens["遍历下一个原子条件 Atom"]
    LoopTokens --> CheckCritFlag{"Atom 包含 '!'<br>(必爆过滤)？"}
    
    CheckCritFlag -- 是 --> FilterMustCrit["仅在 [符合从者/色卡 且 Is100Crit==1] 的候选卡中筛选"]
    CheckCritFlag -- 否 --> FilterNormal["在 [符合从者/色卡] 的所有可用候选卡中筛选"]
    
    FilterMustCrit --> HasCandidates{"存在命中候选卡？"}
    FilterNormal --> HasCandidates
    
    HasCandidates -- 否 --> HasMoreTokens{"序列中还有后续 Atom？"}
    HasMoreTokens -- 是 --> LoopTokens
    HasMoreTokens -- 否 --> Abort["触发 AbortBattle<br>安全停机并提示未命中原因"]
    
    HasCandidates -- 是 --> Has100InCandidates{"候选卡中有满暴卡？<br>(Is100Crit==1)"}
    Has100InCandidates -- 是 --> PickCritCard["优先锁定该 100% 满暴卡"]
    Has100InCandidates -- 否 --> PickNormalCard["锁定首张符合条件的候选卡"]
    
    PickCritCard --> TapCard["点击该卡出牌<br>标记 BATTLE_CARD_CHOSEN = 1"]
    PickNormalCard --> TapCard
    TapCard --> Finish["本动出牌完成退出"]
```

---

### 6.8 实战使用与 DSL 编写指南

#### 6.8.1 核心注意点：从者 NP < 100% 时的识别特性
* **前置依赖**：从者头像的动态采样**必须依赖该从者宝具卡曾经升起过**（即该从者在当前战斗的某回合中 NP 曾达到 $\ge 100\%$）。
* **特殊情况处理**：
  - 如果某回合某从者充能未满（例如因意外仅充到 90% NP），其宝具卡尚未升起，则该从者头像尚未被采样；
  - 此时若 DSL 书写为强求该从者的规则（如 `H1A!>H1!`），由于头像未就绪无法识别该从者手牌，会导致此规则无法命中；
  - 若整个长链均未命中且未写兜底，脚本将**触发安全停机**。

#### 6.8.2 实战 DSL 编写范式

出牌 DSL 的书写模式直接反映关卡的战术严格度：

* **模式 A：严格核心出牌（宁停机不盲出 · 严禁配置兜底）**：
  ```dsl
  aH1A!>H1!>H3!, 6, 8
  ```
  *适用场景：高难关卡、特定打手回收 NP 连发、暴击斩杀关键回合。*  
  *机制行为：关卡对出牌有严苛的策略要求，打错卡极易导致 NP 断档或伤害不足翻车。若手牌未命中条件，**必须触发安全停机保护**，保留当前现场由人工接管，严禁随意出牌。*

* **模式 B：容错型周回出牌（允许宽泛兜底推进）**：
  ```dsl
  H1A!>H1!>H3!>*
  ```
  *适用场景：伤害溢出充裕的日常素材/QP 副本。*  
  *机制行为：优先追求主 C 暴击最大化伤害；若未发出目标卡，也允许通过 `*` 任意出牌平推过本。*

---

## 7. 动静态双轨资产与 .atc 附件包规范

按键精灵在安卓端运行时依赖图片资源，系统采用动静态双轨保障：

```mermaid
flowchart LR
    Target["找图请求: ResolveTargetImg(imgName)"]
    SD["/sdcard/FGO_Q/images/<imgName> (热更新轨)"]
    ATC["Attachment:<imgName> (离线保底轨)"]

    Target --> CheckSD{SD 卡存在该图?}
    CheckSD -- 是 --> UseSD["使用热更新图片 (即刻生效)"]
    CheckSD -- 否 --> UseATC["使用内置 .atc 解压图片"]
```

### 7.1 双轨分工
1. **第一优先级（动态热更新轨 · 免打包）**：
   - 路径：`/sdcard/FGO_Q/images/<fileName>.png`
   - **特点**：在 Editor V5 标定工坊中截图标定、重新裁剪、或新增助战后，点击保存即可通过 ADB 推送至该目录。**脚本无需重编译，不需要重新打包按键精灵工程**。
2. **第二优先级（离线保底轨 · ATC 封装）**：
   - 路径：`Attachment:<fileName>.png`（从按键精灵打包的 `.atc` 中解压提取）
   - **特点**：用于离线发布、换机迁移或首次部署环境的兜底保证。

### 7.2 自动化打包与同步工具 (`manage_atc.py`)
系统提供了自动化命令行工具 [.agents/skills/fgo-atc-packager/scripts/manage_atc.py](file:///f:/2nd%20Accra/Git/Github/FGO_Q/.agents/skills/fgo-atc-packager/scripts/manage_atc.py)，配合专用打包技能实现全自动附件包管理：
- **查看附件包内容**：`python manage_atc.py info <atc_file>`
- **一键打包全量素材**：`python manage_atc.py pack --images-dir images/ --output runner_v5.atc`
- **自动同步到模拟器与 PC 手机助手**：`python manage_atc.py sync-all`

### 7.3 图色识别与抗干扰小图裁切方法论 (Micro-Crop & Anti-Interference Sampling Method)

在 FGO 等包含复杂粒子动效、流光 Shader、半透明蒙层及呼吸动效的 2D/2.5D 客户端中，传统的“大范围截图 + 全屏粗糙匹配”极其脆弱。系统在工程实践中提炼出一套标准化的**抗干扰小图裁切（微切片）方法论**：

#### 7.3.1 核心设计三原则

1. **最小充分特征原则 (Minimum Sufficient Feature Principle)**：
   - 严禁截取包含大面积天空渐变、流光粒子、外框装饰或周围不相关控件的大图；
   - 精确定位并仅提取区分场景的**唯一本质差异特征**。例如：
     - 区分「追加技能强化」与「普通技能强化」时，两者大标题右半部完全一致，唯一差异在于左侧是否有「追加」两字。因此**仅截取「追加」两个字的主体**（约 $118 \times 53$ 像素），绝不连带截取整行标题或周围背景；
     - 灵基再临/圣杯转临完成界面的返回按钮，外圈带有强烈发光渐变与脉冲辉光，因此**微切片精简为核心文字「强化」两字**（尺寸仅 $56 \times 30$ 像素），实测匹准度从动荡的 0.72 提升至稳固的 1.00。
2. **像素级紧凑包裹 (Tight Pixel Bounding)**：
   - 裁切矩形必须基于前景色字符或图标核心笔画的最小外接矩形紧密贴合（上下左右冗余留白控制在 $\le 1 \sim 2\text{px}$）；
   - 彻底剥离可能受到客户端抗锯齿、光晕扩散或 Shader 扰动的背景像素，确保模板图像内部 90% 以上由高辨识度的稳定图元构成。
3. **物理几何专属窗口聚焦 (Focused Search Window)**：
   - 小图模板必须配合**精准收敛的搜索区域（Target Area）**，绝不使用全屏暴力扫描；
   - 搜索窗口范围一般限制在预期物理呈现坐标的上下左右扩展 $20 \sim 50\text{px}$ 以内；
   - 窗口收敛不仅大幅提升按键精灵 `FindPic` 的执行性能（数毫秒级瞬间命中），更从几何拓扑层面杜绝了屏幕其他区域相同色彩/字形引发的假阳性误判。

#### 7.3.2 典型微切片工程对照表

| 识别场景 | 传统粗暴截图缺陷 | 微切片裁切策略 (Micro-Crop) | 物理搜索专属窗口 | 匹准度提升 |
| :--- | :--- | :--- | :--- | :--- |
| **追加技能强化判定** | 截取整串标题或大面积浅蓝渐变，极易受背景光斑干扰 | 仅紧凑裁切「追加」二字主体 (`ENHANCE_SKILL_APPEND.png`, $118 \times 53$) | $x: 1000 \sim 1250,\ y: 5 \sim 75$ | $0.74 \to \mathbf{1.00}$ (零误判) |
| **转临/再临返回主界面** | 截取完整外框，因外环呼吸光晕导致匹配度在 0.7 临界震荡 | 仅紧凑裁切按钮中心「强化」二字 (`ENHANCE_ASCEND_TO_HERO.png`, $56 \times 30$) | $x: 880 \sim 1400,\ y: 5 \sim 70$ | $0.72 \to \mathbf{1.00}$ (无抖动) |
| **手牌 100% 满暴判定** | 窗口过宽包含十位数，非 100% 卡片（如 40%、60%）竖笔误判为 '1' | 严格限定百位数专属区，配合直笔微模板 (`BATTLE_ATTACK_CARD_100_2.png`, $17 \times 4$) | $cx - 55 \sim cx - 35$ (宽度仅 20px) | 彻底消除假阳性 |

#### 7.3.3 开发与调优执行规范

未来任何新增或调优图色模板的任务，均须遵循如下工作流：
1. **真机全屏采样**：通过 ADB 获取基准分辨率（1440×810）原始真机 PNG 画面；
2. **提取差异原子**：在图片编辑或脚本中定位目标与对照场景的差异原子，剔除共性部分；
3. **紧凑微切片**：计算文字/图标边界最小外接矩形导出模板切片；
4. **单点全图校验**：在真实场景截图中测试全图匹配度分布，确认目标点相似度 $\ge 0.88$，且非目标区域最高相似度严格压制在 $\le 0.55$，形成明确判别断层；
5. **双轨同步部署**：同步更新 `editor_v5/images/`、`images/attached images/`、`.atc` 附件包并推送到模拟器。

---

## 8. Runner 动态解析与运行时防护机制

### 8.1 字符串转原生数组 (`ParseTarget` / `ParseCoord`)
在 `battle_v5_runner.q` 中，从外部 `.mq` 读取字符串后：
- `ParseTarget(cfgStr, defaultTar)`：支持解析形如 `Array(1200, 700, 1420, 800, "Attachment:START_BTN.png")` 的字符串，自动切分为 `[x1, y1, x2, y2, imgPath]` 5 个元素的原生数组。
- `ParseCoord(cfgStr, defaultCoord)`：支持解析形如 `Array(84, 650)` 的字符串为 `[x, y]` 原生坐标数组。
- **容错保底**：若外部配置缺省、解析错误或缺失，自动回退到默认常量，保证按键精灵脚本在任何异常配置下均不崩溃。

### 8.2 场景智能自愈与环境就绪 (`ready_env`)
- 在下发执行前，Editor V5 会探测模拟器环境：
  - 自动检查按键精灵后台进程是否存活。
  - 支持 `/api/runner/ready_env` 自动拉起按键精灵与 Runner。
  - 支持 `/api/fgo/navigate_home` 自动点击跳过公告弹窗、回归游戏主界面。

---

## 9. Editor V5 工作流与双核运行控制

### 9.1 启动服务
- 运行 `python editor_v5/launcher.py` 或 `python editor_v5/server.py`。
- 服务默认在 `http://127.0.0.1:8099` 启动。内置单实例端口占用检测，若 8099 端口已被占用，自动唤醒前台窗口。

### 9.2 四大顶级工作台 (Quad-View Workbenches)
1. **⚔️ 战术编排 (DSL Editor)**：
   - 树状展示关卡大组与多套出招方案。
   - 支持可视化点击添加从者技能、指向充能、战斗服换人、选敌与出牌。
   - 助战选择下拉框直连助战名录，实时响应新增从者。
2. **🛠️ 后勤整备 (Extra Workbench)**：
   - 汇集从者强化、灵基再临、圣杯转临、技能强化、礼装强化、友情点与无限池控制。
   - 搭载 `/api/extra/detect_scene` **场景智能探测器**：一键截屏比对当前 FGO 所处界面并向用户反馈匹配状态。
   - 提供 10 / 30 / 100 / 999 常用动作次数快速选择筹码，默认锁定技能 9 级结晶防误触。
3. **📐 屏幕标定 (Calibration Studio)**：
   - 实时截取模拟器画面，支持在画布上拖拽框选视觉目标或直接点击拾取中心坐标。
   - 内置 OpenCV 模板匹配测试（`/api/calibrate/test_match`），即时评估搜图置信度。
   - 保存时一键更新 `profiles/default_1440x810.json`、改写 `battle_v5_config.q`、并自动推送到模拟器 `/sdcard/FGO_Q/images/`。
4. **👥 管理助战 (Friends Manager)**：
   - 展示全局助战名录卡片，实时校验每张特征图在磁盘上的物理存在状态。
   - 支持新增自定义助战，自动分配规范特征图名称（如 `friendTiamat1.png`）。
   - 提供直通标定工坊的无缝引导，新增助战一键前往框选并生成特征图。

### 9.3 双核分体运行按钮 (Twin Run Group) 与状态互斥
- 待命状态呈现双拼按钮：`[ ⚔️ 运行战斗 | 🛠️ 运行整备 ]`。
- 启动任意任务后，按钮合并为动态呼吸脉冲的 `[ ⏹ 停止任务 ]`。
- **任务严格互斥**：战斗运行中，整备面板显示黄色防误触警告横幅并禁用触发；反之亦然，且均提供内嵌的紧急停止按钮。

### 9.4 配置持久化与历史快照保护机制
- **标定段完整性保护 (`ensure_targets_in_config`)**：Web 端提交纯战斗 DSL 时，后端自动校验并强制保留底部的视觉目标与标定块，杜绝因保存配置导致标定丢失。
- **自动化快照回退**：每次调用 `/api/save` 或 `/api/sync` 修改配置时，后端在 `.config_backups/` 目录下自动生成带精确时间戳的快照文件（如 `battle_v5_config.20261009_154500.bak.q`），保留最近 10 次历史记录，确保配置随时可溯源回滚。
