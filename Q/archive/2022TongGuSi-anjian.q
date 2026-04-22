' SetScreenScale 576, 1024, 0
' v4
' 极 狗粮本
' 期望往“可配置技能顺序”方向调整

Log.Open

' USER CONFIG
Dim RoundCount = 3 ' configurable
Dim BATTLE_COUNT = 20


' BASIC CONFIG
' CONST
Dim NEED_REVERSE = true
Dim COLOR_SIM = 0.95

' PREPARE
Dim PREPARE_FRIEND_CABER_AREA = Array(40, 180, 920, 800)
Dim PREPARE_FRIEND_TAIGONG5 = "Attachment:friendtaigong.png"

' START
Dim START_AREA = Array(1200, 700, 1420, 800)
Dim START_BTN_ATT = "Attachment:START_BTN.png"
Dim START_TAPED_DELAY = 12000

' BATTLE: SKILL
' Hero skill
Dim BATTLE_HERO_SKILL_1_COORD = Array(84, 650)
Dim BATTLE_HERO_SKILL_2_COORD = Array(183, 650) //+99
Dim BATTLE_HERO_SKILL_3_COORD = Array(282, 650)
Dim BATTLE_HERO_SKILL_4_COORD = Array(441, 650) //+357
Dim BATTLE_HERO_SKILL_5_COORD = Array(540, 650)
Dim BATTLE_HERO_SKILL_6_COORD = Array(639, 650)
Dim BATTLE_HERO_SKILL_7_COORD = Array(799, 650)
Dim BATTLE_HERO_SKILL_8_COORD = Array(897, 650)
Dim BATTLE_HERO_SKILL_9_COORD = Array(996, 650)
' Hero Skill display check: attack button

Dim BATTLE_HERO_SKILL_CHECK_AREA = Array(1200, 700, 1350, 750)
Dim BATTLE_HERO_SKILL_CHECK_ATT = "Attachment:ATTACK_BTN.png"

' Skill Grant
Dim BATTLE_SKILL_GRANT_HREO_1_COORD = Array(360, 500)
Dim BATTLE_SKILL_GRANT_HREO_2_COORD = Array(717, 500)
Dim BATTLE_SKILL_GRANT_HREO_3_COORD = Array(1074, 500)
' Skill Grant display check: close button
Dim BATTLE_SKILL_GRANT_CHECK_AREA = Array(1205, 142, 1267, 198)
Dim BATTLE_SKILL_GRANT_CHECK_ATT = "Attachment:BATTLE_SKILL_GRANT_CHECK.png"


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
Dim BATTLE_MASTER_SKILL_OPEN_AREA = Array(1317, 325, 1370, 376)
Dim BATTLE_MASTER_SKILL_OPEN_ATT = "Attachment:BATTLE_MASTER_SKILL_OPEN.png"
Dim BATTLE_MASTER_SKILL_AWAIT_MS = 200
Dim BATTLE_MASTER_SKILL_1_COORD = Array(1020, 350)
Dim BATTLE_MASTER_SKILL_2_COORD = Array(1120, 350)
Dim BATTLE_MASTER_SKILL_3_COORD = Array(1220, 350)
' Master skill display check: skill 1 top
Dim BATTLE_MASTER_SKILL_DISPLAY_AREA = Array(980, 310, 1059, 316) ' Display Reference by skill 1 top
Dim BATTLE_MASTER_SKILL_DISPLAY_ATT = "Attachment:BATTLE_MASTER_SKILL_DISPLAY.png"

Dim BATTLE_SKILL_SPEEDUP_AWAIT_MS = 50
Dim BATTLE_SKILL_NORMAL_AWAIT_MS = 500

' BATTLE: ATTACK





Dim BATTLE_ULTIMATE_DISPLAY_AWAIT_MS = 1000

Dim BATTLE_ATTACK_BACK_AREA = Array(1300, 750, 1390, 785) 
Dim BATTLE_ATTACK_BACK_ATT = "Attachment:BATTLE_ATTACK_BACK.png"
Dim BATTLE_ATTACK_ULTIMATE_3_COORD = Array(986, 322)
Dim BATTLE_ATTACK_ULTIMATE_3_FIRST_TAPED_AREA = Array(986, 322, 1042, 348)
Dim BATTLE_ATTACK_ULTIMATE_3_FIRST_TAPED_ATT = "Attachment:ULT_Taped_Green3.png"

Dim BATTLE_ATTACK_CARD_4_COORD = Array(991, 581)
Dim BATTLE_ATTACK_CARD_4_SECOND_TAPED_AREA = Array(991, 581, 1016, 588)
Dim BATTLE_ATTACK_CARD_4_SECOND_TAPED_ATT = "Attachment:BATTLE_ATTACK_CARD_4_SECOND_TAPED.png"
Dim BATTLE_ATTACK_CARD_5_COORD = Array(1278, 581)




Dim BATTLE_CARD_TAPED_AWAIT_MS = 300
Dim ROUND_CHANGE_AWAIT_MS = 6000
Dim BATTLE_ULTIMATE_PLAY_1_AWAIT_MS = 12000 + ROUND_CHANGE_AWAIT_MS
Dim BATTLE_ULTIMATE_PLAY_2_AWAIT_MS = 18000 + ROUND_CHANGE_AWAIT_MS
Dim BATTLE_ULTIMATE_PLAY_LAST_AWAIT_MS = 18000

' AWARD
Dim AWARD_TIE_AREA = Array(202, 206, 232, 230)
Dim AWARD_TIE_ATT = "Attachment:AWARD_TIE.png"
Dim AWARD_TAP_COORD = Array(166, 60)
Dim AWARD_TREASURE_NEXT_AREA = Array(1178, 696, 1282, 740)
Dim AWARD_TREASURE_NEXT_ATT = "Attachment:AWARD_TREASURE_NEXT.png"
Dim AWARD_NORMAL_TAP_AWAIT_MS = 300


' AGAIN
Dim AGAIN_ALERT_AGAIN_AREA = Array(860, 614, 946, 658)
Dim AGAIN_ALERT_AGAIN_ATT = "Attachment:AGAIN_ALERT_AGAIN.png"

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
' SetScreenScale 810, 1440, 0







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

Function clickAndWaitSkillAction()
	Delay BATTLE_SKILL_SPEEDUP_AWAIT_MS
	tap 144, 512
	Delay BATTLE_SKILL_NORMAL_AWAIT_MS
End Function









// 取图法>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

Function CheckAndTapImg(Area, AttachedImg, TapPoint)
	Dim Point = ContinuousCheckImg(Area, AttachedImg)
	Dim TapPointX
	Dim TapPointY
	If TapPoint Then
		TapPointX = TapPoint[1]
		TapPointY = TapPoint[2]
	Else
		TapPointX = Point[1]
		TapPointY = Point[2]
	End If
	tap TapPointX, TapPointY
End Function

Function ContinuousCheckImg(Area, AttachedImg)
	TracePrint "check: ", Area[1], Area[2], Area[3], Area[4], AttachedImg
	Dim intX, intY
	Do While true
		FindPic Area[1], Area[2], Area[3], Area[4], AttachedImg, "000000", 0, 0.9, intX, intY
		If intX > -1 And intY > -1 Then
			ContinuousCheckImg = Array(intX, intY)
			Exit Do
		End If
		Delay 500
	Loop
	TracePrint "found: ", IntX, IntY
End Function

Function CheckNoImgAndTap(Area, AttachedImg, TapPoint)
	Do While true
		Dim GetImgCoord = CheckImg(Area, AttachedImg)
		If GetImgCoord = null Then
			TracePrint "cannot find ", AttachedImg, "Then tap", TapPoint[1], TapPoint[2]
			tap TapPoint[1], TapPoint[2]
		Else
			Exit Do
		End If
		Delay 300
	Loop
End Function

Function CheckImg(Area, AttachedImg)
	Dim intX, intY
	FindPic Area[1], Area[2], Area[3], Area[4], AttachedImg, "000000", 0, 0.9, intX, intY
	If intX > -1 And intY > -1 Then
		CheckImg = Array(intX, intY)
	End If
End Function

// do Battle >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
Function DoBattle()
	TracePrint "Choose Friend"
	CheckAndTapImg(PREPARE_FRIEND_CABER_AREA, PREPARE_FRIEND_TAIGONG5, null)

	If IsFirstBattle Then
		TracePrint "Start"
		CheckAndTapImg(START_AREA, START_BTN_ATT, null)
		IsFirstBattle = false
	End If

	TracePrint "Delay to battle"
	Delay START_TAPED_DELAY

	' Round 1

	TracePrint "Round 1"
	TracePrint "skill 1"
	CheckAndTapImg(BATTLE_HERO_SKILL_CHECK_AREA, BATTLE_HERO_SKILL_CHECK_ATT, BATTLE_HERO_SKILL_1_COORD)
	CheckAndTapImg(BATTLE_SKILL_GRANT_CHECK_AREA, BATTLE_SKILL_GRANT_CHECK_ATT, BATTLE_SKILL_GRANT_HREO_3_COORD)
	clickAndWaitSkillAction()
	TracePrint "skill 2"
	CheckAndTapImg(BATTLE_HERO_SKILL_CHECK_AREA, BATTLE_HERO_SKILL_CHECK_ATT, BATTLE_HERO_SKILL_2_COORD)
	clickAndWaitSkillAction()

	TracePrint "skill 4"
	CheckAndTapImg(BATTLE_HERO_SKILL_CHECK_AREA, BATTLE_HERO_SKILL_CHECK_ATT, BATTLE_HERO_SKILL_4_COORD)
	clickAndWaitSkillAction()
	TracePrint "skill 5"
	CheckAndTapImg(BATTLE_HERO_SKILL_CHECK_AREA, BATTLE_HERO_SKILL_CHECK_ATT, BATTLE_HERO_SKILL_5_COORD)
	CheckAndTapImg(BATTLE_SKILL_GRANT_CHECK_AREA, BATTLE_SKILL_GRANT_CHECK_ATT, BATTLE_SKILL_GRANT_HREO_3_COORD)
	clickAndWaitSkillAction()
	TracePrint "skill 6"
	CheckAndTapImg(BATTLE_HERO_SKILL_CHECK_AREA, BATTLE_HERO_SKILL_CHECK_ATT, BATTLE_HERO_SKILL_6_COORD)
	CheckAndTapImg(BATTLE_SKILL_GRANT_CHECK_AREA, BATTLE_SKILL_GRANT_CHECK_ATT, BATTLE_SKILL_GRANT_HREO_3_COORD)
	clickAndWaitSkillAction()

	TracePrint "skill 7"
	CheckAndTapImg(BATTLE_HERO_SKILL_CHECK_AREA, BATTLE_HERO_SKILL_CHECK_ATT, BATTLE_HERO_SKILL_7_COORD)
	clickAndWaitSkillAction()
	TracePrint "skill 8"
	CheckAndTapImg(BATTLE_HERO_SKILL_CHECK_AREA, BATTLE_HERO_SKILL_CHECK_ATT, BATTLE_HERO_SKILL_8_COORD)
	clickAndWaitSkillAction()

	TracePrint "attack"
	CheckAndTapImg(BATTLE_HERO_SKILL_CHECK_AREA, BATTLE_HERO_SKILL_CHECK_ATT, null)
	Delay BATTLE_ULTIMATE_DISPLAY_AWAIT_MS
	CheckAndTapImg(BATTLE_ATTACK_BACK_AREA, BATTLE_ATTACK_BACK_ATT, BATTLE_ATTACK_ULTIMATE_3_COORD)
	Delay BATTLE_CARD_TAPED_AWAIT_MS
	CheckAndTapImg(BATTLE_ATTACK_ULTIMATE_3_FIRST_TAPED_AREA, BATTLE_ATTACK_ULTIMATE_3_FIRST_TAPED_ATT, BATTLE_ATTACK_CARD_4_COORD)
	Delay BATTLE_CARD_TAPED_AWAIT_MS
	CheckAndTapImg(BATTLE_ATTACK_CARD_4_SECOND_TAPED_AREA, BATTLE_ATTACK_CARD_4_SECOND_TAPED_ATT, BATTLE_ATTACK_CARD_5_COORD)
	Delay BATTLE_ULTIMATE_PLAY_2_AWAIT_MS


	' Round 2

	TracePrint "Round 2"
	TracePrint "skill 9"
	CheckAndTapImg(BATTLE_HERO_SKILL_CHECK_AREA, BATTLE_HERO_SKILL_CHECK_ATT, BATTLE_HERO_SKILL_9_COORD)
	clickAndWaitSkillAction()

	TracePrint "skill master 3"
	CheckAndTapImg(BATTLE_MASTER_SKILL_OPEN_AREA, BATTLE_MASTER_SKILL_OPEN_ATT, null)
	Delay BATTLE_MASTER_SKILL_AWAIT_MS
	CheckAndTapImg(BATTLE_MASTER_SKILL_DISPLAY_AREA, BATTLE_MASTER_SKILL_DISPLAY_ATT, BATTLE_MASTER_SKILL_3_COORD)
	CheckAndTapImg(BATTLE_SKILL_GRANT_CHECK_AREA, BATTLE_SKILL_GRANT_CHECK_ATT, BATTLE_SKILL_GRANT_HREO_3_COORD)
	Delay BATTLE_SKILL_NORMAL_AWAIT_MS

	TracePrint "attack"
	CheckAndTapImg(BATTLE_HERO_SKILL_CHECK_AREA, BATTLE_HERO_SKILL_CHECK_ATT, null)
	Delay BATTLE_ULTIMATE_DISPLAY_AWAIT_MS
	CheckAndTapImg(BATTLE_ATTACK_BACK_AREA, BATTLE_ATTACK_BACK_ATT, BATTLE_ATTACK_ULTIMATE_3_COORD)
	Delay BATTLE_CARD_TAPED_AWAIT_MS
	CheckAndTapImg(BATTLE_ATTACK_ULTIMATE_3_FIRST_TAPED_AREA, BATTLE_ATTACK_ULTIMATE_3_FIRST_TAPED_ATT, BATTLE_ATTACK_CARD_4_COORD)
	Delay BATTLE_CARD_TAPED_AWAIT_MS
	CheckAndTapImg(BATTLE_ATTACK_CARD_4_SECOND_TAPED_AREA, BATTLE_ATTACK_CARD_4_SECOND_TAPED_ATT, BATTLE_ATTACK_CARD_5_COORD)
	Delay BATTLE_ULTIMATE_PLAY_2_AWAIT_MS


	' Round 3

	TracePrint "Round 3"
	TracePrint "skill 3"
	CheckAndTapImg(BATTLE_HERO_SKILL_CHECK_AREA, BATTLE_HERO_SKILL_CHECK_ATT, BATTLE_HERO_SKILL_3_COORD)
	CheckAndTapImg(BATTLE_SKILL_GRANT_CHECK_AREA, BATTLE_SKILL_GRANT_CHECK_ATT, BATTLE_SKILL_GRANT_HREO_3_COORD)
	clickAndWaitSkillAction()


	TracePrint "attack"
	CheckAndTapImg(BATTLE_HERO_SKILL_CHECK_AREA, BATTLE_HERO_SKILL_CHECK_ATT, null)
	Delay BATTLE_ULTIMATE_DISPLAY_AWAIT_MS
	CheckAndTapImg(BATTLE_ATTACK_BACK_AREA, BATTLE_ATTACK_BACK_ATT, BATTLE_ATTACK_ULTIMATE_3_COORD)
	Delay BATTLE_CARD_TAPED_AWAIT_MS
	CheckAndTapImg(BATTLE_ATTACK_ULTIMATE_3_FIRST_TAPED_AREA, BATTLE_ATTACK_ULTIMATE_3_FIRST_TAPED_ATT, BATTLE_ATTACK_CARD_4_COORD)
	Delay BATTLE_CARD_TAPED_AWAIT_MS
	CheckAndTapImg(BATTLE_ATTACK_CARD_4_SECOND_TAPED_AREA, BATTLE_ATTACK_CARD_4_SECOND_TAPED_ATT, BATTLE_ATTACK_CARD_5_COORD)

	Delay BATTLE_ULTIMATE_PLAY_LAST_AWAIT_MS


	' Award

	TracePrint "award tie"
	CheckAndTapImg(AWARD_TIE_AREA, AWARD_TIE_ATT, AWARD_TAP_COORD)
	Delay AWARD_NORMAL_TAP_AWAIT_MS
	CheckNoImgAndTap(AWARD_TREASURE_NEXT_AREA, AWARD_TREASURE_NEXT_ATT, AWARD_TAP_COORD)
	Delay AWARD_NORMAL_TAP_AWAIT_MS
	CheckAndTapImg(AWARD_TREASURE_NEXT_AREA, AWARD_TREASURE_NEXT_ATT, null)


	' Again?
	' TracePrint "again: close"
	' CheckAndTapRGB(AGAIN_ALERT_CLOSE_COORD, AGAIN_ALERT_CLOSE_RGB, null)

	TracePrint "again: yes"
	CheckAndTapImg(AGAIN_ALERT_AGAIN_AREA, AGAIN_ALERT_AGAIN_ATT, null)

	Delay APPLE_CHECK_AWAIT_MS
	Dim CheckSuccess = CheckImg(APPLE_SILVER_COORD, APPLE_SILVER_RGB)
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