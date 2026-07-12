
' config.q
' 配置源文件：只保存配置，不保存战斗逻辑
' 按键精灵编译后会把它下发成 .mq，逻辑主脚本读取这个 mq 文件内容

' 预设标记（目前仅用于日志）
Dim PRESET = "campaign"

' 旧字段：全局好友关键字（兼容兜底）
' 优先使用下面按关卡配置的 FRIEND_Gx_y
Dim FRIEND = "aobao"

' USER CONFIG
Dim ACTIVITY_REWARD = 1

' BATTLE CONFIG
' DSL 大组在 battle_runner.q 里手动改（CFG_ACTION_GROUP_INDEX）

' 选择组内第几套 DSL（从 1 开始，runner 会读取这个值）
Dim ACTION_ROUND_INDEX = 1

' 直接覆盖 Activity DSL（可空）。如果为空，则按 ACTION_ROUND_INDEX 使用下面的 ACTIVITY_DSL_1/2/3
Dim ACTIVITY_DSL = ""

' 兼容旧字段（仅保留 campaign 三套）
' 未配置新大组字段时，runner 仍会按 ACTIVITY_DSL_1/2/3 取值
Dim ACTIVITY_DSL_1 = "s70, 90 | m30034 | s70, 40, 50, 62| a6, 4, 5;s10 | a7, 4, 5;m10 | s20, 30, 82, 92 | a6, 7, 5"
Dim ACTIVITY_DSL_2 = "aB, B"
Dim ACTIVITY_DSL_3 = "s20, 30, 40, 52, 70, 83 | a7, 8, 5;s10 | a6, 4, 5;s92, 50 | m22 | a7, 4, 5"

' -----------------------------
' 大组 1: campaign
Dim FRIEND_G1_1 = "aobao"
Dim ACTIVITY_DSL_G1_1 = "s70, 90 | m30034 | s70, 40, 50, 62| a6, 4, 5;s10 | a7, 4, 5;m10 | s20, 30, 82, 92 | a6, 7, 5"
Dim FRIEND_G1_2 = "aobao"
Dim ACTIVITY_DSL_G1_2 = "aB, B"
Dim FRIEND_G1_3 = "aobao"
Dim ACTIVITY_DSL_G1_3 = "s20, 30, 40, 52, 70, 83 | a7, 8, 5;s10 | a6, 4, 5;s92, 50 | m22 | a7, 4, 5"

' 大组 2: caber（来自 Caber Common 的 ArtActionRounds_DSL）
Dim FRIEND_G2_1 = "cdai"
Dim ACTIVITY_DSL_G2_1 = "s23, 33, 53, 63, 70, 90, 83 | m30 | a8, 4, 5;s10 | a8, 4, 5;s40 | m13 | a8, 4, 5"
Dim FRIEND_G2_2 = "cdai"
Dim ACTIVITY_DSL_G2_2 = "s10, 20, 53, 63, 70, 90, 83 | m30 | a8, 4, 5;s40 | a8, 4, 5;s33 | m10 | a8, 4, 5"
Dim FRIEND_G2_3 = "cdai"
Dim ACTIVITY_DSL_G2_3 = "s10, 20, 53, 63, 80, 90 | a8, 4, 5;s40 | a8, 4, 5;s33 | m10, 30 | a8, 4, 5"

' 大组 3: order_saber
Dim FRIEND_G3_1 = "sparrow"
Dim ACTIVITY_DSL_G3_1 = "s40, 53, 60 | m30024, 10 | s40, 10, 20, 30, 70, 80, 90 | a8, 6, B"
Dim FRIEND_G3_2 = "sparrow"
Dim ACTIVITY_DSL_G3_2 = "s10, 40, 52, 60, 70, 83, 90 | m22 | a7, 8, A"
Dim FRIEND_G3_3 = "sparrow"
Dim ACTIVITY_DSL_G3_3 = "s10, 20, 53, 63, 80, 90 | a8, 4, 5;s40 | a8, 4, 5;s33 | m10, 30 | a8, 4, 5"

' 大组 4: ordeal（1-4 为 ActvityActionRounds，5-7 为 ArtActionRounds）
Dim FRIEND_G4_1 = "shahushan"
Dim ACTIVITY_DSL_G4_1 = "s10, 20, 40, 50, 62, 70, 92 | m22 | a7, 4, 5"
Dim FRIEND_G4_2 = "shahushan"
Dim ACTIVITY_DSL_G4_2 = "s92, 40, 50, 60, 30 | a7, B, B;s72 | m32 | s50 | aB, 7, B;s82, 60 | a7, B, B"
Dim FRIEND_G4_3 = "shahushan"
Dim ACTIVITY_DSL_G4_3 = "s10, 20, 30, 41, 51, 61, 71, 91 | m31 | aB, 6, B;s10, 20, 30 | a6, B, B"
Dim FRIEND_G4_4 = "shahushan"
Dim ACTIVITY_DSL_G4_4 = "s10, 20, 30, 51, 61, 71, 80, 91 | m31 | aB, 6, B;s41, 10, 20, 30 | a6, B, B"
Dim FRIEND_G4_5 = "shahushan"
Dim ACTIVITY_DSL_G4_5 = "s23, 33, 53, 63, 70, 90 | m33 | a8, 4, 5;s10 | a8, 4, 5;s40, 80 | m13 | a8, 4, 5"
Dim FRIEND_G4_6 = "shahushan"
Dim ACTIVITY_DSL_G4_6 = "s23, 33, 53, 63, 70, 90, 83 | a8, 4, 5;s10 | a8, 4, 5;s40 | m13 | a8, 4, 5"
Dim FRIEND_G4_7 = "shahushan"
Dim ACTIVITY_DSL_G4_7 = "s23, 33, 40, 50, 80 | a8, 4, 5;s10 | a8, 4, 5;s63 | m10 | a8, 4, 5"

' 预设说明：
' campaign = 常规战斗配置
' ordeal   = 险境战斗配置
' saber    = 剑阶战斗配置
' custom   = 手工逐项修改上面字段
