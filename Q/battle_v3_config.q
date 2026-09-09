' battle_v3_config.q
' 配置源文件：只保存配置，不保存战斗逻辑
' 按键精灵编译后会把它下发成 .mq，逻辑主脚本读取这个 mq 文件内容

' 预设标记（目前仅用于日志）
Dim PRESET = "campaign"

' 好友关键字填写在下面按关卡配置的 FRIEND_Gx_y 中；不区分大小写。
' 支持：aobao, aobaoshan, cdai, daoman, cba, rba, rbashan,
'       shahu, shahushan, princess, princess120, taigong, sparrow, mary, keli
' 优先级：FRIEND_Gx_y > FRIEND_Gx > friend（全局字段，目前未在此文件配置）。

' USER CONFIG
Dim ACTIVITY_REWARD = 1

' BATTLE CONFIG
' DSL 大组在 battle_v3_runner.q 里手动改（CFG_ACTION_GROUP_INDEX）
' 0=test, 1=campaign, 2=caber, 3=grand, 4=ordeal

' -----------------------------
' 大组 0: test（测试大组）
Dim ACTION_ROUND_INDEX_G0 = 1
Dim FRIEND_G0 = "aobao"
Dim FRIEND_G0_1 = "aobao"
Dim DSL_G0_1 = "m22 | t1 | a7, B, B"
Dim FRIEND_G0_2 = "aobao"
Dim DSL_G0_2 = "aB, B, B"
Dim FRIEND_G0_3 = "aobao"
Dim DSL_G0_3 = "s20, 30, 40, 52, 70, 83 | a7, 8, 5;s10 | a6, 4, 5;s92, 50 | m22 | a7, 4, 5"

' -----------------------------
' 大组 1: campaign（活动关卡）
Dim ACTION_ROUND_INDEX_G1 = 2
Dim FRIEND_G1_1 = "mary"
Dim DSL_G1_1 = "s50 | a7, 4, 5;s40 | m32 | s32, 50, 60 | t1 | aB, Q, A;s70, 92, 40 | a7, B, B"
Dim FRIEND_G1_2 = "rba"
Dim DSL_G1_2 = "s72, 80, 91, 10, 20, 30, 40, 50, 60 | m22 | a6, 7, 5"
Dim FRIEND_G1_3 = "aobao"
Dim DSL_G1_3 = "s20, 30, 40, 52, 70, 83 | a7, 8, 5;s10 | a6, 4, 5;s92, 50 | m22 | a7, 4, 5"

' -----------------------------
' 大组 2: caber（来自 Caber Common 的 ArtActionRounds_DSL）
Dim ACTION_ROUND_INDEX_G2 = 2
Dim FRIEND_G2 = "cdai"
Dim FRIEND_G2_1 = "cdai"
Dim DSL_G2_1 = "s23, 33, 53, 63, 70, 90, 83 | m30 | a8, 4, 5;s10 | a8, 4, 5;s40 | m13 | a8, 4, 5"
Dim FRIEND_G2_2 = "cdai"
Dim DSL_G2_2 = "s10, 20, 53, 63, 70, 90, 83 | m30 | a8, 4, 5;s40 | a8, 4, 5;s33 | m10 | a8, 4, 5"
Dim FRIEND_G2_3 = "cdai"
Dim DSL_G2_3 = "s10, 20, 53, 63, 80, 90 | a8, 4, 5;s40 | a8, 4, 5;s33 | m10, 30 | a8, 4, 5"

' -----------------------------
' 大组 3: grand（戴冠战关卡）
Dim ACTION_ROUND_INDEX_G3 = 3
Dim FRIEND_G3_1 = "sparrow"
Dim DSL_G3_1 = "s40, 53, 60 | m30024, 10 | s40, 10, 20, 30, 70, 80, 90 | a8, 6, B"
Dim FRIEND_G3_2 = "Cba"
Dim DSL_G3_2 = "s10, 30 | m30014, 10 | s10, 20, 40, 50, 60, 70, 83, 90 | a7, 8, A"
Dim FRIEND_G3_3 = "keli"
Dim DSL_G3_3 = "s90, 80, 70, | m30034, 10 | s80, 70, 60, 50, 40, 31, 21, 10 | a6, 7, 5"
Dim FRIEND_G3_4 = "Bdai"
Dim DSL_G3_4 = "s10, 40, 52, 60, 70, 83, 90 | m22 | a7, 8, A"
Dim FRIEND_G3_5 = "princess"
Dim DSL_G3_5 = "s12, 20, 32, 40, 50, 60, 70, 80 | m30014, 10 | s30 | a8, 7, B"
Dim FRIEND_G3_6 = "aobao"
Dim DSL_G3_6 = "s70, 82, 92, 60, 50, 40, 20 | m22 | a7, B, B"

' -----------------------------
' 大组 4: ordeal（白纸化地球 Ordeal Call）
Dim ACTION_ROUND_INDEX_G4 = 1
Dim FRIEND_G4 = "shahushan"
Dim FRIEND_G4_1 = "shahushan"
Dim DSL_G4_1 = "s10, 20, 30, 51, 61, 71, 80, 91 | m31 | aB, 6, B;s41, 10, 20, 30 | a6, B, B"
Dim FRIEND_G4_2 = "shahushan"
Dim DSL_G4_2 = "s92, 40, 50, 60, 30 | a7, B, B;s72 | m32 | s50 | aB, 7, B;s82, 60 | a7, B, B"
Dim FRIEND_G4_3 = "shahushan"
Dim DSL_G4_3 = "s10, 20, 30, 41, 51, 61, 71, 91 | m31 | aB, 6, B;s10, 20, 30 | a6, B, B"
Dim FRIEND_G4_4 = "shahushan"
Dim DSL_G4_4 = "s10, 20, 40, 50, 62, 70, 92 | m22 | a7, 4, 5"

' 预设说明：
' test     = 测试配置
' campaign = 活动关卡配置
' caber    = 术呆常用配置
' grand    = 戴冠战关卡配置
' ordeal   = 白纸化地球 Ordeal Call 配置
' custom   = 手工逐项修改上面字段
