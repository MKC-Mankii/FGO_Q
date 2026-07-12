
' config.q
' 配置源文件：只保存配置，不保存战斗逻辑
' 按键精灵编译后会把它下发成 .mq，逻辑主脚本读取这个 mq 文件内容

' 预设标记（目前仅用于日志）
Dim PRESET = "campaign"

' 好友关键字：casgil / aobao / cdai / daoman / rba / shahu / princess / princess120 / taigong
Dim FRIEND = "casgil"

' 总战斗次数
Dim BATTLE_COUNT = 3

' USER CONFIG
' debug: 1=true, 0=false
Dim DEBUGE_MODULE_BATTLE = 0
Dim APPLE_ENABLE = 0
Dim ACTIVITY_REWARD = 1

' BATTLE CONFIG
' 选择使用哪一套 Activity DSL：1/2/3
Dim ACTION_ROUND_INDEX = 1

' 直接覆盖 Activity DSL（可空）。如果为空，则按 ACTION_ROUND_INDEX 使用下面的 ACTIVITY_DSL_1/2/3
Dim ACTIVITY_DSL = ""

' 多套 Activity DSL（保留多套方便切换）
' ACTION_ROUND_INDEX=1 -> ACTIVITY_DSL_1
' ACTION_ROUND_INDEX=2 -> ACTIVITY_DSL_2
' ACTION_ROUND_INDEX=3 -> ACTIVITY_DSL_3
Dim ACTIVITY_DSL_1 = "s70, 90 | m30034 | s70, 40, 50, 62| a6, 4, 5;s10 | a7, 4, 5;m10 | s20, 30, 82, 92 | a6, 7, 5"
Dim ACTIVITY_DSL_2 = "aB, B"
Dim ACTIVITY_DSL_3 = "s20, 30, 40, 52, 70, 83 | a7, 8, 5;s10 | a6, 4, 5;s92, 50 | m22 | a7, 4, 5"

' 预设说明：
' campaign = 常规战斗配置
' ordeal   = 险境战斗配置
' saber    = 剑阶战斗配置
' custom   = 手工逐项修改上面字段
