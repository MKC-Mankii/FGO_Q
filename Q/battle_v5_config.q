' battle_v5_config.q
' 配置源文件：只保存配置，不保存战斗逻辑
' 按键精灵编译后会把它下发成 .mq，逻辑主脚本读取这个 mq 文件内容
' 【重要提示】本文件仅为 V5 配置文件，请勿在按键精灵中直接独立运行！
' 若误启动本文件，将弹出提示并退出。请启动【fgo_battle_v5_runner】主脚本！
ShowMessage "【提示】这是配置文件！请启动【fgo_battle_v5_runner】", 3000

' 好友关键字填写在下面按关卡配置的 FRIEND_Gx_y 中；不区分大小写。
' 支持：aobao, aobaoshan, cdai, daoman, cba, rba, rbashan,
'       shahu, shahushan, princess, princess120, taigong, sparrow, mary, keli
' 优先级：FRIEND_Gx_y > FRIEND_Gx > friend（全局字段，目前未在此文件配置）。

' ==================== 全局运行配置 (RUNNER CONFIG) ====================
Dim RUN_MODE = 1  ' 当前运行主模式: 0=战术战斗(Battle), 1=Extra辅助(Extra)
Dim ACTION_GROUP_INDEX = 1  ' 当前生效大组: 0=test, 1=campaign, 2=caber, 3=grand, 4=ordeal
Dim BATTLE_COUNT = 30  ' 连续战斗次数
Dim APPLE_ENABLE = 0  ' 是否吃苹果补充体力 (0=关, 1=开)
Dim MANUAL_CHOOSE_FRIEND = 0  ' 是否人工选助战 (0=自动找图, 1=人工选择)
Dim FORCE_COLOR_CARD = 0  ' 是否强制选择对应色卡 (0=关, 1=开)

' --- Extra 辅助运行配置 ---
Dim EXTRA_ACTION_COUNT = 30  ' Extra 连续执行次数上限
Dim EXTRA_SKILL_MAX_LEVEL = 9  ' 技能强化目标等级 (1~10)
Dim EXTRA_SKILL_AUTO_THREE = 1  ' 技能强化是否强化全部技能 (0=关, 1=开)
Dim EXTRA_HERO_AUTO_ASCEND = 1  ' 从者强化是否自动灵基再临 (0=关, 1=开)
Dim EXTRA_HERO_AUTO_GRAIL = 0  ' 强化是否自动圣杯转临 (0=关, 1=开，默认关避免消耗珍贵圣杯)
Dim EXTRA_HERO_AUTO_GRAIL = 0  ' 从者强化是否自动圣杯转临 (0=关, 1=开)

' ==================== 兼容与兜底字段 ====================
Dim CFG_ACTION_GROUP_INDEX = 1
Dim MANUAL_BATTLE_COUNT = 30
Dim MANUAL_APPLE_ENABLE = 0
Dim MANUAL_FORCE_COLOR_CARD = 0
Dim EXTRA_ENABLE = 1
Dim ACTIVITY_REWARD = 0

' -----------------------------
' 大组 0: test（测试战场）
Dim ACTIVITY_REWARD_G0 = 0
Dim ACTION_ROUND_INDEX_G0 = 1
Dim FRIEND_G0 = "aobao"
' 方案 1: 普攻
Dim ACTIVITY_REWARD_G0_1 = 0
Dim FRIEND_G0_1 = "cdai"
Dim DSL_G0_1 = "s40, 70 | a3, 4, 5;a3, 4, 5"
' 方案 2: cdai
Dim ACTIVITY_REWARD_G0_2 = 0
Dim FRIEND_G0_2 = "cdai"
Dim DSL_G0_2 = "m22 | t1 | a7, B, B"
' 方案 3: rba
Dim ACTIVITY_REWARD_G0_3 = 0
Dim FRIEND_G0_3 = "rba"
Dim DSL_G0_3 = "aB, B, B"
' 方案 4: target测试
Dim ACTIVITY_REWARD_G0_4 = 0
Dim FRIEND_G0_4 = "aobao"
Dim DSL_G0_4 = "s10 | a6, B, B;s20 | a6, B, B;s30 | a6, B, B"
' 方案 5: aobao
Dim ACTIVITY_REWARD_G0_5 = 0
Dim FRIEND_G0_5 = "aobao"
Dim DSL_G0_5 = "t1 | t2 | t3 | t4 | t5 | t6 | t1 | t2 | t3 | t4 | t5 | t6 | a7, 4, 5"

' -----------------------------
' 大组 1: campaign（活动关卡）
Dim ACTIVITY_REWARD_G1 = 0
Dim ACTION_ROUND_INDEX_G1 = 1
' 方案 1: 90+
Dim ACTIVITY_REWARD_G1_1 = 0
Dim FRIEND_G1_1 = "shahu"
Dim DSL_G1_1 = "s92, 10, 50 | a7, 4, 5;s20, 32, 40, 72, 82, 60 | aB, Q, A;m32 | s40, 50 | a7, B, B"
' 方案 2: shahu
Dim ACTIVITY_REWARD_G1_2 = 0
Dim FRIEND_G1_2 = "shahu"
Dim DSL_G1_2 = "s82, 92, 50 | a7, 4, 5;s40, 72, 12, 30, 60 | m32 | s50 | a7, B, A;s20, 40 | a7, B, B"

' -----------------------------
' 大组 2: caber（术呆通用）
Dim ACTIVITY_REWARD_G2 = 0
Dim ACTION_ROUND_INDEX_G2 = 1
Dim FRIEND_G2 = "cdai"
' 方案 1: 水伊吹
Dim ACTIVITY_REWARD_G2_1 = 0
Dim FRIEND_G2_1 = "cdai"
Dim DSL_G2_1 = "s10, 20, 53, 63, 70, 90, 83 | m30 | a8, 4, 5;s40 | a8, 4, 5;s33 | m10 | a8, 4, 5"
' 方案 2: 兰丸50
Dim ACTIVITY_REWARD_G2_2 = 0
Dim FRIEND_G2_2 = "cdai"
Dim DSL_G2_2 = "s10, 20, 53, 63, 90 | a8, 4, 5;s40 | a8, 4, 5;s33, 80 | m10, 30 | a8, 4, 5"
' 方案 3: 壹与60
Dim ACTIVITY_REWARD_G2_3 = 0
Dim FRIEND_G2_3 = "cdai"
Dim DSL_G2_3 = "s10, 20, 53, 63, 70, 90 | m10 | a8, 4, 5;s40 | a8, 4, 5;m30 | s33, 80 | a8, 4, 5"

' -----------------------------
' 大组 3: grand（戴冠战关卡）
Dim ACTIVITY_REWARD_G3 = 0
Dim ACTION_ROUND_INDEX_G3 = 4
' 方案 1: 剑
Dim ACTIVITY_REWARD_G3_1 = 0
Dim FRIEND_G3_1 = "sparrow"
Dim DSL_G3_1 = "s40, 53, 60 | m30024, 10 | s40, 10, 20, 30, 70, 80, 90 | a8, 6, B"
' 方案 2: 枪
Dim ACTIVITY_REWARD_G3_2 = 0
Dim FRIEND_G3_2 = "Cba"
Dim DSL_G3_2 = "s10, 30 | m30014, 10 | s10, 20, 40, 50, 60, 70, 83, 90 | a7, 8, A"
' 方案 3: 骑
Dim ACTIVITY_REWARD_G3_3 = 0
Dim FRIEND_G3_3 = "keli"
Dim DSL_G3_3 = "s90, 70 | m30034, 10 | s80, 70, 60, 50, 40, 32, 22, 10 | a6, 7, Q"
' 方案 4: 骑2
Dim ACTIVITY_REWARD_G3_4 = 0
Dim FRIEND_G3_4 = "keli"
Dim DSL_G3_4 = "s80, 70, 60, 50, 40, 22, 10 | m12 | a6, 7, Q"
' 方案 5: 狂
Dim ACTIVITY_REWARD_G3_5 = 0
Dim FRIEND_G3_5 = "Bdai"
Dim DSL_G3_5 = "s10, 40, 52, 60, 70, 83, 90 | m22 | a7, 8, A"
' 方案 6: EX1
Dim ACTIVITY_REWARD_G3_6 = 0
Dim FRIEND_G3_6 = "princess"
Dim DSL_G3_6 = "s12, 20, 32, 40, 50, 60, 70, 80 | m30014, 10 | s30 | a8, 7, B"
' 方案 7: EX2
Dim ACTIVITY_REWARD_G3_7 = 0
Dim FRIEND_G3_7 = "aobao"
Dim DSL_G3_7 = "s70, 82, 92, 60, 50, 40, 20 | m22 | a7, B, B"

' -----------------------------
' 大组 4: ordeal（白纸化地球 Ordeal Call）
Dim ACTIVITY_REWARD_G4 = 0
Dim ACTION_ROUND_INDEX_G4 = 1
Dim FRIEND_G4 = "shahushan"
' 方案 1: 矿场学姐RBA
Dim ACTIVITY_REWARD_G4_1 = 0
Dim FRIEND_G4_1 = "shahushan"
Dim DSL_G4_1 = "s10, 20, 30, 51, 61, 71, 80, 91 | m31 | aB, 6, B;s41, 10, 20, 30 | a6, B, B"
' 方案 2: shahushan
Dim ACTIVITY_REWARD_G4_2 = 0
Dim FRIEND_G4_2 = "shahushan"
Dim DSL_G4_2 = "s92, 40, 50, 60, 30 | a7, B, B;s72 | m32 | s50 | aB, 7, B;s82, 60 | a7, B, B"
' 方案 3: shahushan
Dim ACTIVITY_REWARD_G4_3 = 0
Dim FRIEND_G4_3 = "shahushan"
Dim DSL_G4_3 = "s10, 20, 30, 41, 51, 61, 71, 91 | m31 | aB, 6, B;s10, 20, 30 | a6, B, B"
' 方案 4: shahushan
Dim ACTIVITY_REWARD_G4_4 = 0
Dim FRIEND_G4_4 = "shahushan"
Dim DSL_G4_4 = "s10, 20, 40, 50, 62, 70, 92 | m22 | a7, 4, 5"

' 预设说明：
' test     = 测试配置
' campaign = 活动关卡配置
' caber    = 术呆常用配置
' grand    = 戴冠战关卡配置
' ordeal   = 白纸化地球 Ordeal Call 配置
' custom   = 手工逐项修改上面字段

' ==============================================================================
' 🎯 屏幕标定与视觉目标配置 (TARGETS & COORDINATES CONFIG)
' 基础分辨率基准: 1440x810
' 由 Editor V5 标定工坊管理维护，亦可在此直接手工修改
' 修改后 runner 将在每次启动时自动重载最新坐标并优先读取 /sdcard/FGO_Q/images/ 中更新的图片
' ==============================================================================

' --- 基础参数 ---
Dim SCREEN_BASE_W = 1440
Dim SCREEN_BASE_H = 810

' --- 助战准备 (PREPARE FRIEND) ---
Dim PREPARE_FRIEND_AREA = Array(40, 180, 920, 800)
Dim ATT_EQUIP_Goodness = "Attachment:friend_equip_goodness.png"
Dim PREPARE_FRIEND_EQUIP_TAR = Array(40, 180, 920, 800, "Attachment:friend_equip_goodness.png")

' --- 战斗开始 (START) ---
Dim START_TAR = Array(1200, 700, 1420, 800, "Attachment:START_BTN.png")
Dim START_TAPED_DELAY = 8000

' --- 战斗: 从者技能 (HERO SKILLS) ---
Dim BATTLE_HERO_SKILL_CHECK_TAR = Array(1200, 700, 1350, 750, "Attachment:ATTACK_BTN.png")
Dim TAP_HERO_SKILL_1_1 = Array(84, 650)
Dim TAP_HERO_SKILL_1_2 = Array(183, 650)
Dim TAP_HERO_SKILL_1_3 = Array(282, 650)
Dim TAP_HERO_SKILL_2_1 = Array(441, 650)
Dim TAP_HERO_SKILL_2_2 = Array(540, 650)
Dim TAP_HERO_SKILL_2_3 = Array(639, 650)
Dim TAP_HERO_SKILL_3_1 = Array(799, 650)
Dim TAP_HERO_SKILL_3_2 = Array(897, 650)
Dim TAP_HERO_SKILL_3_3 = Array(996, 650)

' --- 战斗: 技能指向/充能目标 (SKILL GRANT HERO) ---
Dim BATTLE_SKILL_GRANT_CHECK_TAR = Array(1205, 142, 1267, 198, "Attachment:BATTLE_SKILL_GRANT_CHECK.png")
Dim TAP_SKILL_GRANT_HERO_1 = Array(360, 500)
Dim TAP_SKILL_GRANT_HERO_2 = Array(717, 500)
Dim TAP_SKILL_GRANT_HERO_3 = Array(1074, 500)

' --- 战斗: 换人 (SKILL CHANGE HERO) ---
Dim BATTLE_SKILL_CHANGE_CHECK_TAR = Array(723, 685, 777, 719, "Attachment:BATTLE_SKILL_CHANGE_CHECK.png")
Dim BATTLE_SKILL_CHANGE_SELECTEED_CHECK_TAR = Array(723, 685, 777, 719, "Attachment:BATTLE_SKILL_CHANGE_SELECTEED_CHECK.png")
Dim BATTLE_SKILL_CHANGE_SELECTED_AWAIT_MS = 200
Dim TAP_SKILL_CHANGE_FRONT_1 = Array(150, 390)
Dim TAP_SKILL_CHANGE_FRONT_2 = Array(375, 390)
Dim TAP_SKILL_CHANGE_FRONT_3 = Array(600, 390)
Dim TAP_SKILL_CHANGE_BACK_1 = Array(825, 390)
Dim TAP_SKILL_CHANGE_BACK_2 = Array(1050, 390)
Dim TAP_SKILL_CHANGE_BACK_3 = Array(1275, 390)

' --- 战斗: 特殊技能 (SPECIAL SKILL: CaoShiLang) ---
Dim BATTLE_SKILL_SPECIAL_SKILL_A_TAR = Array(180, 240, 345, 410, "Attachment:BATTLE_SKILL_SPECIAL_SKILL_A.png")
Dim TAP_SKILL_SPECIAL_SKILL_A_ACT_3 = Array(1060, 480)

' --- 战斗: 御主技能 (MASTER SKILLS) ---
Dim BATTLE_MASTER_SKILL_OPEN_TAR = Array(1280, 300, 1410, 420, "Attachment:BATTLE_MASTER_SKILL_OPEN.png")
Dim BATTLE_MASTER_SKILL_DISPLAY_TAR = Array(980, 310, 1059, 316, "Attachment:BATTLE_MASTER_SKILL_DISPLAY.png")
Dim TAP_MASTER_SKILL_OPEN = Array(1317, 325)
Dim TAP_MASTER_SKILL_1 = Array(1020, 350)
Dim TAP_MASTER_SKILL_2 = Array(1120, 350)
Dim TAP_MASTER_SKILL_3 = Array(1220, 350)
Dim BATTLE_MASTER_SKILL_AWAIT_MS = 300

' --- 战斗: 技能动画与加速 ---
Dim BATTLE_SKILL_SPEEDUP_COORD = Array(1100, 770)
Dim BATTLE_SKILL_SPEEDUP_AWAIT_MS = 50
Dim BATTLE_SKILL_NORMAL_AWAIT_MS = 500

' --- 战斗: 敌方目标选择 (SELECT ENEMY TARGET) ---
Dim TAP_TARGET_ENEMY_1 = Array(159, 33)
Dim TAP_TARGET_ENEMY_2 = Array(424, 33)
Dim TAP_TARGET_ENEMY_3 = Array(689, 33)
Dim TAP_TARGET_ENEMY_4 = Array(130, 150)
Dim TAP_TARGET_ENEMY_5 = Array(355, 150)
Dim TAP_TARGET_ENEMY_6 = Array(580, 150)

' --- 战斗: 选卡与出牌 (ATTACK & CARDS) ---
Dim BATTLE_ATTACK_BACK_TAR = Array(1300, 750, 1390, 785, "Attachment:BATTLE_ATTACK_BACK.png")
Dim BATTLE_ATTACK_CARD_BUSTER_TAR = Array(55, 460, 1390, 690, "Attachment:BATTLE_ATTACK_CARD_BUSTER.png")
Dim BATTLE_ATTACK_CARD_ARTS_TAR = Array(55, 460, 1390, 690, "Attachment:BATTLE_ATTACK_CARD_ARTS.png")
Dim BATTLE_ATTACK_CARD_QUICK_TAR = Array(55, 460, 1390, 690, "Attachment:BATTLE_ATTACK_CARD_QUICK.png")

Dim TAP_CARD_NORMAL_1 = Array(118, 581)
Dim TAP_CARD_NORMAL_2 = Array(408, 581)
Dim TAP_CARD_NORMAL_3 = Array(698, 581)
Dim TAP_CARD_NORMAL_4 = Array(991, 581)
Dim TAP_CARD_NORMAL_5 = Array(1278, 581)
Dim TAP_CARD_NP_1 = Array(412, 322)
Dim TAP_CARD_NP_2 = Array(699, 322)
Dim TAP_CARD_NP_3 = Array(986, 322)

Dim BATTLE_ATTACK_CARD_3_FIRST_TAPED_TAR = Array(650, 550, 780, 600, "Attachment:BATTLE_ATTACK_CARD_3_FIRST_TAPED.png")
Dim BATTLE_ATTACK_CARD_4_SECOND_TAPED_TAR = Array(950, 560, 1071, 600, "Attachment:BATTLE_ATTACK_CARD_4_SECOND_TAPED.png")
Dim BATTLE_ATTACK_CARD_6_FIRST_TAPED_TAR = Array(400, 210, 550, 352, "Attachment:ULT_Taped_Red1.png|Attachment:ULT_Taped_Blue1.png|Attachment:ULT_Taped_Green1.png")
Dim BATTLE_ATTACK_CARD_7_FIRST_TAPED_TAR = Array(680, 210, 790, 352, "Attachment:ULT_Taped_Red2.png|Attachment:ULT_Taped_Blue2.png|Attachment:ULT_Taped_Green2.png")
Dim BATTLE_ATTACK_CARD_8_FIRST_TAPED_TAR = Array(930, 210, 1048, 259, "Attachment:ULT_Taped_Red3.png|Attachment:ULT_Taped_Blue3.png|Attachment:ULT_Taped_Green3.png")
Dim BATTLE_ATTACK_CARD_6_SECOND_TAPED_TAR = Array(400, 213, 520, 355, "Attachment:BATTLE_ATTACK_CARD_6_SECOND_TAPED.png")
Dim BATTLE_ATTACK_CARD_7_SECOND_TAPED_TAR = Array(700, 227, 727, 238, "Attachment:BATTLE_ATTACK_CARD_7_SECOND_TAPED.png|Attachment:BATTLE_ATTACK_CARD_7_SECOND_TAPED2.png")
Dim BATTLE_ATTACK_CARD_8_SECOND_TAPED_TAR = Array(960, 227, 987, 238, "Attachment:BATTLE_ATTACK_CARD_8_SECOND_TAPED.png")

Dim BATTLE_ULTIMATE_DISPLAY_AWAIT_MS = 1000
Dim BATTLE_CARD_TAPED_AWAIT_MS = 300
Dim BATTLE_ROUND_CHANGE_AWAIT_MS = 6000
Dim BATTLE_NORMAL_ATTACK_PLAY_AWAIT_MS = 11000
Dim BATTLE_ULTIMATE_PLAY_1_AWAIT_MS = 16000
Dim BATTLE_ULTIMATE_PLAY_2_AWAIT_MS = 19000
Dim BATTLE_LAST_ROUND_END_AWAIT_MS = 3000
Dim BATTLE_ULTIMATE_PLAY_LAST_AWAIT_MS = 21000

' --- 结算奖励 (AWARD & REWARD) ---
Dim AWARD_TIE_TAR = Array(90, 190, 330, 225, "Attachment:AWARD_TIE.png")
Dim AWARD_TIE_UP_TAR = Array(696, 101, 828, 245, "Attachment:AWARD_TIE_UP.png")
Dim TAP_AWARD_SKIP = Array(166, 60)
Dim AWARD_TREASURE_NEXT_TAR = Array(1178, 696, 1282, 740, "Attachment:AWARD_TREASURE_NEXT.png")
Dim AWARD_ACTIVITY_NEXT_TAR = Array(1178, 696, 1282, 740, "Attachment:AWARD_TREASURE_NEXT.png")
Dim AWARD_NORMAL_TAP_AWAIT_MS = 300
Dim BEFORE_ACTIVITY_AWAIT_MS = 500

' --- 好友申请与再战 (ADD FRIEND & AGAIN) ---
Dim ADD_FRIEND_TAR = Array(325, 670, 415, 715, "Attachment:ADD_FRIEND_CLOSE.png")
Dim ADD_FRIEND_CHECK_AWAIT_MS = 500
Dim AGAIN_ALERT_AGAIN_TAR = Array(795, 620, 1030, 700, "Attachment:AGAIN_ALERT_AGAIN.png")
Dim AGAIN_ALERT_CLOSE_TAR = Array(370, 620, 620, 700, "Attachment:AGAIN_ALERT_CLOSE.png")
Dim AGAIN_ORDEAL_NO_TICKET_TAR = Array(600, 600, 850, 670, "Attachment:AGAIN_ORDEAL_NO_TICKET.png")
Dim AGAIN_BATTLE_OUT_MENU_TAR = Array(1301, 689, 1360, 715, "Attachment:AGAIN_BATTLE_OUT_MENU.png")

' --- 补充体力 / 吃苹果 (APPLE) ---
Dim APPLE_DISPLAY_TAR = Array(634, 37, 743, 83, "Attachment:APPLE_DISPLAY.png")
Dim APPLE_CONFIRM_TAR = Array(895, 608, 992, 660, "Attachment:APPLE_CONFIRM.png")
Dim TAP_APPLE_GOLDEN = Array(420, 360)
Dim TAP_APPLE_SILVER = Array(420, 520)
Dim TAP_APPLE_CLOSE = Array(720, 695)
Dim APPLE_CHECK_AWAIT_MS = 500

' --- Extra: 辅助功能目标 (EXTRA TARGETS) ---
Dim INFINITE_ROLL_TAR = Array(330, 370, 620, 610, "Attachment:ROLL100.png|Attachment:ROLL100-1.png|Attachment:ROLL10.png|Attachment:ROLL10-1.png")
Dim INFINITE_ROLL_FAST_COORD = Array(300, 400)

Dim ENHANCE_HERO_TAR = Array(880, 5, 1300, 70, "Attachment:ENHANCE_HERO.png")
Dim ENHANCE_HERO_RECOMMAND_TAR = Array(1240, 150, 1370, 208, "Attachment:ENHANCE_HERO_RECOMMAND.png")
Dim ENHANCE_HERO_RECOMMAND_CONFIRM_TAR = Array(880, 680, 1006, 745, "Attachment:ENHANCE_HERO_RECOMMAND_CONFIRM.png")
Dim ENHANCE_HERO_ENHANCE_TAR = Array(1340, 716, 1438, 798, "Attachment:ENHANCE_HERO_ENHANCE.png")
Dim ENHANCE_HERO_ENHANCE_CONFIRM_TAR = Array(877, 632, 1006, 698, "Attachment:ENHANCE_HERO_ENHANCE_CONFIRM.png")
Dim ENHANCE_HERO_REFUND_CLOSE_TAR = Array(550, 580, 890, 680, "Attachment:ENHANCE_HERO_REFUND_CLOSE.png")
Dim TAP_ENHANCE_HERO_REFUND_CLOSE = Array(686, 614)
Dim ENHANCE_HERO_TO_ASCEND_TAR = Array(1050, 580, 1320, 680, "Attachment:ENHANCE_HERO_TO_ASCEND.png")
Dim ENHANCE_HERO_TO_GRAIL_TAR = Array(1050, 580, 1320, 680, "Attachment:ENHANCE_HERO_TO_GRAIL.png")
Dim ENHANCE_ASCEND_TAR = Array(880, 5, 1300, 70, "Attachment:ENHANCE_ASCEND.png")
Dim ENHANCE_GRAIL_TAR = Array(1050, 5, 1420, 70, "Attachment:ENHANCE_GRAIL.png")
Dim ENHANCE_GRAIL_CONFIRM_TAR = Array(877, 632, 1006, 698, "Attachment:ENHANCE_HERO_ENHANCE_CONFIRM.png")
Dim TAP_ENHANCE_GRAIL_CONFIRM = Array(943, 662)
Dim ENHANCE_ASCEND_BTN_TAR = Array(1340, 716, 1438, 798, "Attachment:ENHANCE_ASCEND_BTN.png|Attachment:ENHANCE_HERO_ENHANCE.png")
Dim ENHANCE_ASCEND_CONFIRM_TAR = Array(877, 632, 1006, 698, "Attachment:ENHANCE_HERO_ENHANCE_CONFIRM.png")
Dim ENHANCE_ASCEND_TO_HERO_TAR = Array(1000, 270, 1360, 370, "Attachment:ENHANCE_ASCEND_TO_HERO.png")
Dim ENHANCE_ASCEND_BACK_TAR = Array(40, 10, 120, 65, "Attachment:ENHANCE_ASCEND_BACK.png")

Dim TAP_ENHANCE_HERO_TO_ASCEND = Array(1185, 628)
Dim TAP_ENHANCE_HERO_TO_GRAIL = Array(1185, 628)
Dim TAP_ENHANCE_ASCEND_BTN = Array(1391, 739)
Dim TAP_ENHANCE_ASCEND_CONFIRM = Array(943, 662)
Dim TAP_ENHANCE_ASCEND_TO_HERO = Array(1180, 321)
Dim TAP_ENHANCE_ASCEND_BACK = Array(60, 40)
Dim TAP_ENHANCE_BLIND_SKIP = Array(940, 660)

Dim POOLFRIEND_CONTINUE_TAR = Array(720, 720, 990, 800, "Attachment:POOLFRIEND_CONTINUE.png")
Dim POOLFRIEND_GO_TAR = Array(830, 600, 1080, 670, "Attachment:POOLFRIEND_GO.png")

Dim ENHANCE_EQUIP_TAR = Array(880, 5, 1300, 70, "Attachment:ENHANCE_EQUIP.png")
Dim ENHANCE_EQUIP_ENHANCE_TAR = Array(1340, 716, 1438, 798, "Attachment:ENHANCE_EQUIP_ENHANCE.png")
Dim ENHANCE_EQUIP_ENHANCE_CONFIRM_TAR = Array(877, 632, 1006, 698, "Attachment:ENHANCE_EQUIP_ENHANCE_CONFIRM.png")

Dim ENHANCE_SKILL_TAR = Array(880, 5, 1300, 70, "Attachment:ENHANCE_SKILL.png")
Dim ENHANCE_SKILL_ENHANCE_TAR = Array(1185, 725, 1230, 785, "Attachment:ENHANCE_SKILL_ENHANCE.png")
Dim ENHANCE_SKILL_ENHANCE_CONFIRM_TAR = Array(820, 640, 890, 690, "Attachment:ENHANCE_SKILL_ENHANCE_CONFIRM.png")
Dim ENHANCE_SKILL_ENHANCE_L10_TAR = Array(450, 490, 610, 630, "Attachment:ENHANCE_SKILL_ENHANCE_L10.png")
Dim ENHANCE_SKILL_CLICK_COORD = Array(1100, 765)
Dim ENHANCE_SKILL_MAX_L10_TAR = Array(1150, 720, 1410, 800, "Attachment:ENHANCE_SKILL_MAX_L10.png")
Dim TAP_ENHANCE_SKILL_1 = Array(532, 286)
Dim TAP_ENHANCE_SKILL_2 = Array(852, 286)
Dim TAP_ENHANCE_SKILL_3 = Array(1172, 286)
Dim ENHANCE_SKILL_HERO_UNSELECTED_TAR = Array(140, 560, 300, 630, "Attachment:ENHANCE_SKILL_HERO_UNSELECTED.png")
