' 单步复现测试：只跑 "32" 这一个技能动作(技能3, 目标2)，每一步之间拉长延迟并打印真实点击坐标
' 用法：手动把游戏停在"回合待机、攻击键可见"的画面，再运行本脚本

Log.Open

Import "zm.luae"
zm.Init

' 和 battle_runner.q 保持一致的坐标定义
Dim BATTLE_HERO_SKILL_CHECK_TAR = Array(1200, 700, 1350, 750, "Attachment:ATTACK_BTN.png")
Dim BATTLE_HERO_SKILL_COORDS = Array(_
	Array(84, 650),_
	Array(183, 650),_
	Array(282, 650),_
	Array(441, 650),_
	Array(540, 650),_
	Array(639, 650),_
	Array(799, 650),_
	Array(897, 650),_
	Array(996, 650)_
 )
Dim BATTLE_SKILL_GRANT_CHECK_TAR = Array(1205, 142, 1267, 198, "Attachment:BATTLE_SKILL_GRANT_CHECK.png")
Dim BATTLE_SKILL_GRANT_HREO_COORDS = Array(_
	Array(360, 500),_
	Array(717, 500),_
	Array(1074, 500)_
 )
' 仅作参照打印，方便和你观察到的"类似t3"位置比对
Dim BATTLE_TARGET_COORDS = Array(_
	Array(159, 33),_
	Array(424, 33),_
	Array(689, 33)_
 )

' 和 battle_runner.q 原版一致的延迟（不再人为拉长）
Dim BATTLE_SKILL_SPEEDUP_AWAIT_MS = 50
Dim BATTLE_SKILL_NORMAL_AWAIT_MS = 500

Function CheckImg2(Target)
	Dim intX, intY
	FindPic Target[1], Target[2], Target[3], Target[4], Target[5], "000000", 0, 0.9, intX, intY
	If intX > -1 And intY > -1 Then
		CheckImg2 = Array(intX, intY)
	End If
End Function

Function ContinuousCheckImg(Target)
	Dim GetImgCoord
	Do While true
		GetImgCoord = CheckImg2(Target)
		If GetImgCoord <> null Then
			ContinuousCheckImg = Array(GetImgCoord[1], GetImgCoord[2])
			Exit Do
		End If
		Delay 500
	Loop
	TracePrint "found:", Target[5], GetImgCoord[1], GetImgCoord[2]
End Function

TracePrint "=== TEST START ===", DateTime.Format()
TracePrint "REFERENCE t1/t2/t3 COORDS:", BATTLE_TARGET_COORDS[1][1], BATTLE_TARGET_COORDS[1][2], "|", BATTLE_TARGET_COORDS[2][1], BATTLE_TARGET_COORDS[2][2], "|", BATTLE_TARGET_COORDS[3][1], BATTLE_TARGET_COORDS[3][2]

TracePrint "STEP 0: wait ATTACK_BTN ready"
ContinuousCheckImg(BATTLE_HERO_SKILL_CHECK_TAR)

TracePrint "STEP 1: tap skill button 3 ->", BATTLE_HERO_SKILL_COORDS[3][1], BATTLE_HERO_SKILL_COORDS[3][2]
tap BATTLE_HERO_SKILL_COORDS[3][1], BATTLE_HERO_SKILL_COORDS[3][2]

TracePrint "STEP 2: wait BATTLE_SKILL_GRANT_CHECK overlay"
ContinuousCheckImg(BATTLE_SKILL_GRANT_CHECK_TAR)

TracePrint "STEP 3: tap grant target 2 ->", BATTLE_SKILL_GRANT_HREO_COORDS[2][1], BATTLE_SKILL_GRANT_HREO_COORDS[2][2]
tap BATTLE_SKILL_GRANT_HREO_COORDS[2][1], BATTLE_SKILL_GRANT_HREO_COORDS[2][2]

TracePrint "STEP 4: SKIPPED (no speedup blank tap this run)"

TracePrint "=== TEST END ==="
Log.Close
