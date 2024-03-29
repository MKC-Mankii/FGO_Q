' SetScreenScale 576, 1024, 0
' v4
' 极 狗粮本
' 期望往“可配置技能顺序”方向调整

Log.Open

' USER CONFIG
Dim RoundCount = 3 ' configurable
Dim BATTLE_COUNT = 1


' BASIC CONFIG
' CONST
Dim NEED_REVERSE = true
Dim COLOR_SIM = 0.9

' PREPARE
Dim PREPARE_FRIEND_CABER_COORD = Array(120, 200)
Dim PREPARE_FRIEND_CABER_RGB = "8A4048|814949|FFF9E9"	' 138,64,72 129,73,73 255,249,233

' START
Dim START_COORD = Array(900, 536)
Dim START_RGB = "0E0E1D" ' 14,14,29
Dim START_TAPED_DELAY = 12000

' BATTLE: SKILL
' Hero skill
Dim BATTLE_HERO_SKILL_1_COORD = Array(61, 460)
Dim BATTLE_HERO_SKILL_2_COORD = Array(130, 465)
Dim BATTLE_HERO_SKILL_3_COORD = Array(204, 463)
Dim BATTLE_HERO_SKILL_4_COORD = Array(315, 460)
Dim BATTLE_HERO_SKILL_5_COORD = Array(384, 465)
Dim BATTLE_HERO_SKILL_6_COORD = Array(458, 463)
Dim BATTLE_HERO_SKILL_7_COORD = Array(569, 460)
Dim BATTLE_HERO_SKILL_8_COORD = Array(638, 462)
Dim BATTLE_HERO_SKILL_9_COORD = Array(709, 465)
' Hero Skill display check: attack button
Dim BATTLE_HERO_SKILL_CHECK_COORD = Array(905, 485)
Dim BATTLE_HERO_SKILL_CHECK_RGB = "00B3E5" ' 0,179,229
' Skill Grant
Dim BATTLE_SKILL_GRANT_HREO_1_COORD = Array(260, 330)
Dim BATTLE_SKILL_GRANT_HREO_2_COORD = Array(510, 330)
Dim BATTLE_SKILL_GRANT_HREO_3_COORD = Array(760, 330)
' Skill Grant display check: close button
Dim BATTLE_SKILL_GRANT_CHECK_COORD = Array(878, 120)
Dim BATTLE_SKILL_GRANT_CHECK_RGB = "2B336C|29316A" ' 43,51,108 || 41,49,106
' Skill Change
Dim BATTLE_SKILL_CHANGE_HERO_1_COORD = Array(110, 270)
Dim BATTLE_SKILL_CHANGE_HERO_2_COORD = Array(270, 270)
Dim BATTLE_SKILL_CHANGE_HERO_3_COORD = Array(430, 270)
Dim BATTLE_SKILL_CHANGE_HERO_4_COORD = Array(590, 270)
Dim BATTLE_SKILL_CHANGE_HERO_5_COORD = Array(750, 270)
Dim BATTLE_SKILL_CHANGE_HERO_6_COORD = Array(910, 270)
' Skill Change: display check: change button
Dim BATTLE_SKILL_CHANGE_CHECK_COORD = Array(512, 498)
Dim BATTLE_SKILL_CHANGE_CHECK_RGB = "38466B" ' 56,70,107
' Skill Change: selected check: change button
Dim BATTLE_SKILL_CHANGE_SELECTEED_CHECK_COORD = Array(512, 498)
Dim BATTLE_SKILL_CHANGE_SELECTEED__CHECK_RGB = "67759A" ' 103,117,154

' Master skill
Dim BATTLE_MASTER_SKILL_OPEN_COORD = Array(955, 250)
Dim BATTLE_MASTER_SKILL_OPEN_RGB = "0E2F69" ' 14,47,105
Dim BATTLE_MASTER_SKILL_AWAIT_MS = 200
Dim BATTLE_MASTER_SKILL_1_COORD = Array(725, 250)
Dim BATTLE_MASTER_SKILL_2_COORD = Array(800, 250)
Dim BATTLE_MASTER_SKILL_3_COORD = Array(870, 250)
' Master skill display check: skill 1 top
Dim BATTLE_MASTER_SKILL_DISPLAY_COORD = Array(725, 222) ' Display Reference by skill 1 top
Dim BATTLE_MASTER_SKILL_DISPLAY_RGB = "FEFEFE|FFFFFF" ' 254,254,254

Dim BATTLE_SKILL_NORMAL_AWAIT_MS = 500

' BATTLE: ATTACK
Dim BATTLE_ATTACK_COORD = Array(905, 485)
Dim BATTLE_ATTACK_RGB = "00B3DC" ' 0,179,220 previous:0,179,229
Dim BATTLE_ULTIMATE_DISPLAY_AWAIT_MS = 2000
Dim BATTLE_ATTACK_BACK_COORD = Array(958, 544) 
Dim BATTLE_ATTACK_BACK_RGB = "87A9DC" ' 135,169,220
Dim BATTLE_ATTACK_ULTIMATE_1_COORD = Array(328, 165)
Dim BATTLE_ATTACK_ULTIMATE_1_FIRST_TAPED_COORD = Array(513, 165)
Dim BATTLE_ATTACK_ULTIMATE_1_FIRST_TAPED_RGB = "FDF5C2" ' 253,245,194 ' Maybe different with other hero
Dim BATTLE_ATTACK_ULTIMATE_2_COORD = Array(513, 165)
Dim BATTLE_ATTACK_ULTIMATE_2_FIRST_TAPED_COORD = Array(513, 165)
Dim BATTLE_ATTACK_ULTIMATE_2_FIRST_TAPED_RGB = "FDF5C2" ' 253,245,194 ' Maybe different with other hero
Dim BATTLE_ATTACK_ULTIMATE_3_COORD = Array(698, 165)
Dim BATTLE_ATTACK_ULTIMATE_3_FIRST_TAPED_COORD = Array(698, 165)
Dim BATTLE_ATTACK_ULTIMATE_3_FIRST_TAPED_RGB = "FCF4C2" ' 252,244,194 ' Maybe different with other hero
Dim BATTLE_ATTACK_CARD_4_COORD = Array(717, 404)
Dim BATTLE_ATTACK_CARD_4_SECOND_TAPED_COORD = Array(717, 404)
Dim BATTLE_ATTACK_CARD_4_SECOND_TAPED_RGB = "FFFFFE" ' 255,255,254
Dim BATTLE_ATTACK_CARD_5_COORD = Array(922, 404)
Dim BATTLE_CARD_TAPED_AWAIT_MS = 500
Dim ROUND_CHANGE_AWAIT_MS = 6000
Dim BATTLE_ULTIMATE_PLAY_1_AWAIT_MS = 12000 + ROUND_CHANGE_AWAIT_MS
Dim BATTLE_ULTIMATE_PLAY_2_AWAIT_MS = 18000 + ROUND_CHANGE_AWAIT_MS
Dim BATTLE_ULTIMATE_PLAY_LAST_AWAIT_MS = 18000

' AWARD
Dim AWARD_TIE_COORD = Array(74, 149)
Dim AWARD_TIE_RGB = "DCAB2A|DBAB2A" ' 219,171,42
Dim AWARD_TIE_TAP_COORD = Array(324, 149)
Dim AWARD_NORMAL_TAP_AWAIT_MS = 300
Dim AWARD_MASTER_EXP_COORD = Array(529, 163)
Dim AWARD_MASTER_EXP_RGB = "EEBC20" ' 238,188,32
Dim AWARD_MASTER_EXP_TAP_COORD = Array(779, 163)
Dim AWARD_TREASURE_COORD = Array(864, 510)
Dim AWARD_TREASURE_RGB = "435073" ' 67,80,115

' AGAIN
Dim AGAIN_ALERT_CLOSE_COORD = Array(352, 451)
Dim AGAIN_ALERT_CLOSE_RGB = "767676" ' 118,118,118
Dim AGAIN_ALERT_CLOSE_AGAGIN = Array(669, 451)

' APPLE
Dim APPLE_CHECK_AWAIT_MS = 500
Dim APPLE_GLODEN_COORD = Array(300, 250)
Dim APPLE_GLODEN_RGB = "FAE950" ' 250,233,80
Dim APPLE_SILVER_COORD = Array(300, 368)
Dim APPLE_SILVER_RGB = "E7FEFE" ' 231,254,254
Dim APPLE_EAT_CONFIRM_COORD = Array(670, 450)
Dim APPLE_EAT_CONFIRM_RGB = "C0C0C0" ' 192,192,192
Dim APPLE_CLOSE_COORD = Array(509, 495)
Dim APPLE_CLOSE_RGB = "72809B" ' 114,128,155

' VARIATE
Dim IsFirstBattle = true

' Dim 屏幕横坐标X,屏幕纵坐标Y
' 屏幕横坐标X=GetScreenX()
' 屏幕纵坐标Y=GetScreenY()
' TracePrint 屏幕横坐标X,屏幕纵坐标Y
' SetScreenScale 576, 1024, 0

Function ReverseColor(RGBs) 'RGBs or BGRs
	Dim RGBArr = Split(RGBs, "|")
	Dim BGRArr = Array()
	For Each RGB_SINGLE In RGBArr
		RGB_SINGLE = Mid(RGB_SINGLE, 5, 2) & Mid(RGB_SINGLE, 3, 2) & Mid(RGB_SINGLE, 1, 2)
		BGRArr[UBound(BGRArr)+2] = RGB_SINGLE
	Next
	ReverseColor = Join(BGRArr, "|")
End Function
Function RGBToBGR(RGBs)
	RGBToBGR = ReverseColor(RGBs)
End Function
Function BGRToRGB(BGRs)
	BGRToRGB = ReverseColor(BGRs) 
End Function

Function ContinuousCheckPointBGR(PointX, PointY, BGRs)
	TracePrint "check: ", BGRs, PointX, PointY
	Dim IntX,IntY
	' Dim Count = 0
	Do While true
		FindMultiColor PointX-1, PointY-1, PointX+1, PointY+1,BGRs,"", 1, COLOR_SIM, intX, intY
		If intX > 0 Then
			' ShowMessage ( Count & ":" & CStr(IntX) & " a " & CStr(IntY))
			Exit Do
		Else
			Dim rColor
			rColor = GetPixelColor(PointX, PointY)
			TracePrint "actual: " & BGRToRGB(rColor)
		End If
		Delay 500
		' Count = Count+1
	Loop
	TracePrint "find out:", IntX, IntY
End Function

Function CheckPointBGR(PointX, PointY, BGRs)
	TracePrint "check: ", BGRs, PointX, PointY


	Dim IntX,IntY
	' Dim Count = 0
	
	FindMultiColor PointX-1, PointY-1, PointX+1, PointY+1,BGRs,"", 1, COLOR_SIM, intX,intY
	If intX > 0 Then
		' ShowMessage ( Count & ":" & CStr(IntX) & " a " & CStr(IntY))
		TracePrint "find out:", IntX, IntY
		CheckPointBGR = true
	Else
		Dim rColor
		rColor = GetPixelColor(PointX, PointY)
		TracePrint "actual: " & BGRToRGB(rColor)
		CheckPointBGR = false
	End If
	
	
End Function

Function CheckAndTapRGB(Point, RGBs, TapPoint)
	Dim CheckPointX = Point[1]
	Dim CheckPointY = Point[2]
	Dim TapPointX
	Dim TapPointY
	If TapPoint Then
		TapPointX = TapPoint[1]
		TapPointY = TapPoint[2]
	Else
		TapPointX = Point[1]
		TapPointY = Point[2]
	End If

	Dim BGRs = RGBToBGR(RGBs)
	
	ContinuousCheckPointBGR(CheckPointX, CheckPointY, BGRs)

	tap TapPointX, TapPointY
End Function

Function CheckNoPointAndTapRGB(Point, RGBs, TapPoint)
	Dim CheckPointX = Point[1]
	Dim CheckPointY = Point[2]
	Dim TapPointX
	Dim TapPointY
	If TapPoint Then
		TapPointX = TapPoint[1]
		TapPointY = TapPoint[2]
	Else
		TapPointX = Point[1]
		TapPointY = Point[2]
	End If

	Dim BGRs = RGBToBGR(RGBs)
	
	Dim CheckPointBGRSuccess = CheckPointBGR(CheckPointX, CheckPointY, BGRs)

	TracePrint "find out success:", CheckPointBGRSuccess
	If not CheckPointBGRSuccess Then
		TracePrint "click"
		tap TapPointX, TapPointY
	End If
	
End Function

Function CheckPoint(Point, RGBs)
	Dim CheckPointX = Point[1]
	Dim CheckPointY = Point[2]
	Dim TapPointX
	Dim TapPointY

	Dim BGRs = RGBToBGR(RGBs)
	
	CheckPoint = CheckPointBGR(CheckPointX, CheckPointY, BGRs)

End Function


Function CheckTapUtilDisappear(Point, RGBs, TapPoint)
	Dim CheckPointX = Point[1]
	Dim CheckPointY = Point[2]
	Dim TapPointX
	Dim TapPointY
	Dim ClickedCount = 0
	If TapPoint Then
		TapPointX = TapPoint[1]
		TapPointY = TapPoint[2]
	Else
		TapPointX = Point[1]
		TapPointY = Point[2]
	End If

	Dim BGRs = RGBToBGR(RGBs)
	
	Do While true
	
		Dim CheckPointBGRSuccess = CheckPointBGR(CheckPointX, CheckPointY, BGRs)
		TracePrint "find out success:", CheckPointBGRSuccess
		If CheckPointBGRSuccess Then
			tap TapPointX, TapPointY
			ClickedCount = ClickedCount + 1
			Delay 200
		Else
			If ClickedCount > 0 Then
				Exit Do
			Else
				Delay 300
			End If
		End If
	Loop
	
End Function


Function DoBattle()
	' TracePrint "Choose Friend"
	' CheckAndTapRGB(PREPARE_FRIEND_CABER_COORD, PREPARE_FRIEND_CABER_RGB, null)

	If IsFirstBattle Then
		TracePrint "Start"
		CheckAndTapRGB(START_COORD, START_RGB, null)
		IsFirstBattle = false
	End If

	TracePrint "Delay to battle"
	Delay START_TAPED_DELAY

	' Round 1

	TracePrint "Round 1"
	TracePrint "skill 2"
	CheckAndTapRGB(BATTLE_HERO_SKILL_CHECK_COORD, BATTLE_HERO_SKILL_CHECK_RGB, BATTLE_HERO_SKILL_2_COORD)
	Delay BATTLE_SKILL_NORMAL_AWAIT_MS
	TracePrint "skill 3"
	CheckAndTapRGB(BATTLE_HERO_SKILL_CHECK_COORD, BATTLE_HERO_SKILL_CHECK_RGB, BATTLE_HERO_SKILL_3_COORD)
	Delay BATTLE_SKILL_NORMAL_AWAIT_MS


	TracePrint "attack"
	CheckAndTapRGB(BATTLE_ATTACK_COORD, BATTLE_ATTACK_RGB, null)
	Delay BATTLE_ULTIMATE_DISPLAY_AWAIT_MS
	CheckAndTapRGB(BATTLE_ATTACK_BACK_COORD, BATTLE_ATTACK_BACK_RGB, BATTLE_ATTACK_ULTIMATE_1_COORD)
	Delay BATTLE_CARD_TAPED_AWAIT_MS
	CheckAndTapRGB(BATTLE_ATTACK_ULTIMATE_1_FIRST_TAPED_COORD, BATTLE_ATTACK_ULTIMATE_1_FIRST_TAPED_RGB, BATTLE_ATTACK_CARD_4_COORD)
	Delay BATTLE_CARD_TAPED_AWAIT_MS
	CheckAndTapRGB(BATTLE_ATTACK_CARD_4_SECOND_TAPED_COORD, BATTLE_ATTACK_CARD_4_SECOND_TAPED_RGB, BATTLE_ATTACK_CARD_5_COORD)

	Delay BATTLE_ULTIMATE_PLAY_1_AWAIT_MS


	' Round 2

	TracePrint "Round 2"
	TracePrint "attack"
	CheckAndTapRGB(BATTLE_ATTACK_COORD, BATTLE_ATTACK_RGB, null)
	Delay BATTLE_ULTIMATE_DISPLAY_AWAIT_MS
	CheckAndTapRGB(BATTLE_ATTACK_BACK_COORD, BATTLE_ATTACK_BACK_RGB, BATTLE_ATTACK_ULTIMATE_2_COORD)
	Delay BATTLE_CARD_TAPED_AWAIT_MS
	CheckAndTapRGB(BATTLE_ATTACK_ULTIMATE_2_FIRST_TAPED_COORD, BATTLE_ATTACK_ULTIMATE_2_FIRST_TAPED_RGB, BATTLE_ATTACK_CARD_4_COORD)
	Delay BATTLE_CARD_TAPED_AWAIT_MS
	CheckAndTapRGB(BATTLE_ATTACK_CARD_4_SECOND_TAPED_COORD, BATTLE_ATTACK_CARD_4_SECOND_TAPED_RGB, BATTLE_ATTACK_CARD_5_COORD)

	Delay BATTLE_ULTIMATE_PLAY_2_AWAIT_MS


	' Round 3

	TracePrint "Round 3"
	TracePrint "skill 8"
	CheckAndTapRGB(BATTLE_HERO_SKILL_CHECK_COORD, BATTLE_HERO_SKILL_CHECK_RGB, BATTLE_HERO_SKILL_8_COORD)
	Delay BATTLE_SKILL_NORMAL_AWAIT_MS
	TracePrint "skill 9"
	CheckAndTapRGB(BATTLE_HERO_SKILL_CHECK_COORD, BATTLE_HERO_SKILL_CHECK_RGB, BATTLE_HERO_SKILL_9_COORD)
	Delay BATTLE_SKILL_NORMAL_AWAIT_MS

	TracePrint "skill master 1"
	CheckAndTapRGB(BATTLE_MASTER_SKILL_OPEN_COORD, BATTLE_MASTER_SKILL_OPEN_RGB, null)
	Delay BATTLE_MASTER_SKILL_AWAIT_MS
	CheckAndTapRGB(BATTLE_MASTER_SKILL_DISPLAY_COORD, BATTLE_MASTER_SKILL_DISPLAY_RGB, BATTLE_MASTER_SKILL_1_COORD)
	CheckAndTapRGB(BATTLE_SKILL_GRANT_CHECK_COORD, BATTLE_SKILL_GRANT_CHECK_RGB, BATTLE_SKILL_GRANT_HREO_3_COORD)
	Delay BATTLE_SKILL_NORMAL_AWAIT_MS

	TracePrint "attack"
	CheckAndTapRGB(BATTLE_ATTACK_COORD, BATTLE_ATTACK_RGB, null)
	Delay BATTLE_ULTIMATE_DISPLAY_AWAIT_MS
	CheckAndTapRGB(BATTLE_ATTACK_BACK_COORD, BATTLE_ATTACK_BACK_RGB, BATTLE_ATTACK_ULTIMATE_3_COORD)
	Delay BATTLE_CARD_TAPED_AWAIT_MS
	CheckAndTapRGB(BATTLE_ATTACK_ULTIMATE_3_FIRST_TAPED_COORD, BATTLE_ATTACK_ULTIMATE_3_FIRST_TAPED_RGB, BATTLE_ATTACK_CARD_4_COORD)
	Delay BATTLE_CARD_TAPED_AWAIT_MS
	CheckAndTapRGB(BATTLE_ATTACK_CARD_4_SECOND_TAPED_COORD, BATTLE_ATTACK_CARD_4_SECOND_TAPED_RGB, BATTLE_ATTACK_CARD_5_COORD)

	Delay BATTLE_ULTIMATE_PLAY_LAST_AWAIT_MS


	' Award

	TracePrint "award tie"
	CheckTapUtilDisappear(AWARD_TIE_COORD, AWARD_TIE_RGB, AWARD_TIE_TAP_COORD)

	TracePrint "award master exp"
	CheckTapUtilDisappear(AWARD_MASTER_EXP_COORD, AWARD_MASTER_EXP_RGB, AWARD_MASTER_EXP_TAP_COORD)

	TracePrint "award treasure"
	CheckAndTapRGB(AWARD_TREASURE_COORD, AWARD_TREASURE_RGB, null)

	' Again?
	' TracePrint "again: close"
	' CheckAndTapRGB(AGAIN_ALERT_CLOSE_COORD, AGAIN_ALERT_CLOSE_RGB, null)
	TracePrint "again: yes"
	CheckAndTapRGB(AGAIN_ALERT_CLOSE_COORD, AGAIN_ALERT_CLOSE_RGB, AGAIN_ALERT_CLOSE_AGAGIN)

	Delay APPLE_CHECK_AWAIT_MS
	Dim CheckSuccess = CheckPoint(APPLE_SILVER_COORD, APPLE_SILVER_RGB)
	If CheckSuccess Then
		If BATTLE_COUNT > 1  Then
			CheckAndTapRGB(APPLE_SILVER_COORD, APPLE_SILVER_RGB, null)
			CheckAndTapRGB(APPLE_EAT_CONFIRM_COORD, APPLE_EAT_CONFIRM_RGB, null)
		Else
			CheckAndTapRGB(APPLE_CLOSE_COORD, APPLE_CLOSE_RGB, null)
		End If
	End If

End Function

Do While true
	DoBattle()
	BATTLE_COUNT = BATTLE_COUNT - 1

	TracePrint "remaining BATTLE_COUNT = ", BATTLE_COUNT
	If BATTLE_COUNT < 1 Then
		TracePrint "END"
		Exit Do
	End If
Loop

Log.Close