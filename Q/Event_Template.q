' 1. 引入核心逻辑库
' 请确保按键精灵能找到该文件，如果不识别空格可将库名去除空格
Import "Caber_Core.q"

' 2. 定义当前活动的专属配置
Dim RunCount = 1            ' 刷本次数
Dim UseApple = 0            ' 0:不吃苹果, 1:吃苹果
Dim ActivityReward = 1      ' 是否有活动奖励结算
Dim DebugMode = 1           ' 0:真实点击, 1:Debug纯输出日志

' 3. 当前队伍（如蓝卡队）的出牌序列
Dim EventBattleSequence = Array(_
	"s23, 33, 53, 63, 70, 90, 83 | m30 | a8, 4, 5",_
	"s10 | a8, 4, 5",_
	"s40 | m13 | a8, 4, 5"_
)

' ==========================================
' 启动！
' ==========================================
Call StartAutoBattle(RunCount, UseApple, ActivityReward, EventBattleSequence, DebugMode)