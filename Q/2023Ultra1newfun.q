' SetScreenScale 576, 1024, 0
' v4

Log.Open

' USER CONFIG
Dim RoundCount = 3 ' configurable
Dim BATTLE_COUNT = 20


' BASIC CONFIG
' CONST
Dim NEED_REVERSE = true
Dim COLOR_SIM = 0.95

' PREPARE
Dim PREPARE_FRIEND_TAR = Array(40, 180, 920, 800, "Attachment:friendShaHu2.png")
' "Attachment:friendtaigong.png"
' "Attachment:friendCDai.png"
' "Attachment:friendAobao.png"


' START
Dim START_TAR = Array(1200, 700, 1420, 800, "Attachment:START_BTN.png")
Dim START_TAPED_DELAY = 8000

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

Dim BATTLE_HERO_SKILL_CHECK_TAR = Array(1200, 700, 1350, 750, "Attachment:ATTACK_BTN.png")

' Skill Grant
Dim BATTLE_SKILL_GRANT_HREO_1_COORD = Array(360, 500)
Dim BATTLE_SKILL_GRANT_HREO_2_COORD = Array(717, 500)
Dim BATTLE_SKILL_GRANT_HREO_3_COORD = Array(1074, 500)
' Skill Grant display check: close button
Dim BATTLE_SKILL_GRANT_CHECK_TAR = Array(1205, 142, 1267, 198, "Attachment:BATTLE_SKILL_GRANT_CHECK.png")



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
Dim BATTLE_MASTER_SKILL_OPEN_ATT = "Attachment:BATTLE_MASTER_SKILL_OPEN2.png"
Dim BATTLE_MASTER_SKILL_AWAIT_MS = 200
Dim BATTLE_MASTER_SKILL_1_COORD = Array(1020, 350)
Dim BATTLE_MASTER_SKILL_2_COORD = Array(1120, 350)
Dim BATTLE_MASTER_SKILL_3_COORD = Array(1220, 350)
' Master skill display check: skill 1 top
Dim BATTLE_MASTER_SKILL_DISPLAY_TAR = Array(980, 310, 1059, 316, "Attachment:BATTLE_MASTER_SKILL_DISPLAY.png") 
' Display Reference by skill 1 top


Dim BATTLE_SKILL_SPEEDUP_AWAIT_MS = 50
Dim BATTLE_SKILL_NORMAL_AWAIT_MS = 500

' BATTLE: ATTACK





Dim BATTLE_ULTIMATE_DISPLAY_AWAIT_MS = 1000

Dim BATTLE_ATTACK_BACK_TAR = Array(1300, 750, 1390, 785, "Attachment:BATTLE_ATTACK_BACK2.png") 

Dim BATTLE_ATTACK_ULTIMATE_1_COORD = Array(412, 322)
Dim BATTLE_ATTACK_ULTIMATE_1_FIRST_TAPED_TAR = Array(400, 315, 550, 352, "Attachment:ULT_Taped_Red1.png")   ' first text line
Dim BATTLE_ATTACK_ULTIMATE_2_COORD = Array(699, 322)
Dim BATTLE_ATTACK_ULTIMATE_2_FIRST_TAPED_TAR = Array(680, 315, 790, 352, "Attachment:ULT_Taped_Blue2.png")
Dim BATTLE_ATTACK_ULTIMATE_3_COORD = Array(986, 322)
Dim BATTLE_ATTACK_ULTIMATE_3_FIRST_TAPED_TAR = Array(986, 315, 1042, 352, "Attachment:ULT_Taped_Red3.png")
'	"Attachment:ULT_Taped_Green3.png"

Dim BATTLE_ATTACK_CARD_3_COORD = Array(698, 581)
Dim BATTLE_ATTACK_CARD_3_FIRST_TAPED_TAR = Array(698, 581, 722, 588, "Attachment:BATTLE_ATTACK_CARD_3_FIRST_TAPED.png")
Dim BATTLE_ATTACK_CARD_4_COORD = Array(991, 581)
Dim BATTLE_ATTACK_CARD_4_SECOND_TAPED_TAR = Array(991, 581, 1016, 588, "Attachment:BATTLE_ATTACK_CARD_4_SECOND_TAPED.png")
Dim BATTLE_ATTACK_CARD_5_COORD = Array(1278, 581)




Dim BATTLE_CARD_TAPED_AWAIT_MS = 300
Dim BATTLE_ROUND_CHANGE_AWAIT_MS = 6000
Dim BATTLE_NORMAL_ATTACK_PLAY_AWAIT_MS = 5000 + BATTLE_ROUND_CHANGE_AWAIT_MS
Dim BATTLE_ULTIMATE_PLAY_1_AWAIT_MS = 10000 + BATTLE_ROUND_CHANGE_AWAIT_MS
Dim BATTLE_ULTIMATE_PLAY_2_AWAIT_MS = 13000 + BATTLE_ROUND_CHANGE_AWAIT_MS
Dim BATTLE_LAST_ROUND_END_AWAIT_MS = 3000
Dim BATTLE_ULTIMATE_PLAY_LAST_AWAIT_MS = 18000 + BATTLE_LAST_ROUND_END_AWAIT_MS

' AWARD
Dim AWARD_TIE_TAR = Array(180, 120, 250, 260, "Attachment:AWARD_TIE.png") ' normal:TIE, special:TIE2
Dim AWARD_TAP_COORD = Array(166, 60)
Dim AWARD_TREASURE_NEXT_TAR = Array(1178, 696, 1282, 740, "Attachment:AWARD_TREASURE_NEXT.png")
Dim AWARD_NORMAL_TAP_AWAIT_MS = 300

' Activity AWARD
Dim AWARD_ACTIVITY_NEXT_TAR = Array(1178, 696, 1282, 740, "Attachment:AWARD_TREASURE_NEXT.png")

' ADD FRIEND
Dim ADD_FRIEND_CHECK_AWAIT_MS = 500
Dim ADD_FRIEND_TAR = Array(325, 670, 415, 715, "Attachment:ADD_FRIEND_CLOSE.png")

' AGAIN
Dim AGAIN_ALERT_AGAIN_AREA = Array(860, 614, 946, 658)
Dim AGAIN_ALERT_AGAIN_ATT = "Attachment:AGAIN_ALERT_AGAIN.png"

' APPLE
Dim APPLE_CHECK_AWAIT_MS = 500
Dim APPLE_DISPLAY_AREA = Array(634, 37, 743, 83)
Dim APPLE_DISPLAY_ATT = "Attachment:APPLE_DISPLAY.png"
Dim APPLE_GLODEN_COORD = Array(420, 360)
Dim APPLE_SILVER_COORD = Array(420, 520)
Dim APPLE_CONFIRM_AREA = Array(895, 608, 992, 660)
Dim APPLE_CONFIRM_ATT = "Attachment:APPLE_CONFIRM.png"
Dim APPLE_CLOSE_COORD = Array(490, 630)


Dim INFINITE_ROLL_TAR = Array(330, 388, 570, 455, "Attachment:ROLL100.png") ' ROLL10 ROLL100



' VARIATE
Dim IsFirstBattle = true

' Dim 屏幕横坐标X,屏幕纵坐标Y
' 屏幕横坐标X=GetScreenX()
' 屏幕纵坐标Y=GetScreenY()
' TracePrint 屏幕横坐标X,屏幕纵坐标Y
' SetScreenScale 810, 1440, 0


Dim CurrentBattleCount = 0




Function BattlePrint(Msg)
	TracePrint "Battle", CurrentBattleCount, Msg
End Function

Function clickAndWaitSkillAction()
	Delay BATTLE_SKILL_SPEEDUP_AWAIT_MS
	tap 144, 512
	Delay BATTLE_SKILL_NORMAL_AWAIT_MS
End Function









// 取图法>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

Function CheckAndTapImg2(Target, TapPoint)
	CheckAndTapImg(Target, Target[5], TapPoint)
End Function

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
	Dim GetImgCoord
	Do While true
		GetImgCoord = CheckImg(Area, AttachedImg)
		If GetImgCoord <> null Then
			ContinuousCheckImg = Array(GetImgCoord[1], GetImgCoord[2])
			Exit Do
		End If
		Delay 500
	Loop
	TracePrint "found: ", GetImgCoord[1], GetImgCoord[2]
End Function

Function CheckNoImgAndTap2(Target, TapPoint)
	CheckNoImgAndTap(Target, Target[5], TapPoint)
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

Function CheckImg2(Target)
	CheckImg(Target, Target[5])
End Function
Function CheckImg(Area, AttachedImg)
	TracePrint "check: ", Area[1], Area[2], Area[3], Area[4], AttachedImg
	Dim intX, intY
	FindPic Area[1], Area[2], Area[3], Area[4], AttachedImg, "000000", 0, 0.9, intX, intY
	If intX > -1 And intY > -1 Then
		CheckImg = Array(intX, intY)
	End If
End Function

// do Battle >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
Function DoBattle()
	BattlePrint("Choose Friend")
	CheckAndTapImg2(PREPARE_FRIEND_TAR, null)

	If IsFirstBattle Then
		TracePrint "Start"
		CheckAndTapImg2(START_TAR, null)
		IsFirstBattle = false
	End If

	BattlePrint("Delay to battle")
	Delay START_TAPED_DELAY

	' Round 1

	BattlePrint("Round 1")
	TracePrint "skill 2"
	CheckAndTapImg2(BATTLE_HERO_SKILL_CHECK_TAR, BATTLE_HERO_SKILL_2_COORD)
	CheckAndTapImg2(BATTLE_SKILL_GRANT_CHECK_TAR, BATTLE_SKILL_GRANT_HREO_3_COORD)
	clickAndWaitSkillAction()
	TracePrint "skill 3"
	CheckAndTapImg2(BATTLE_HERO_SKILL_CHECK_TAR, BATTLE_HERO_SKILL_3_COORD)
	CheckAndTapImg2(BATTLE_SKILL_GRANT_CHECK_TAR, BATTLE_SKILL_GRANT_HREO_3_COORD)
	clickAndWaitSkillAction()
	TracePrint "skill 5"
	CheckAndTapImg2(BATTLE_HERO_SKILL_CHECK_TAR, BATTLE_HERO_SKILL_5_COORD)
	CheckAndTapImg2(BATTLE_SKILL_GRANT_CHECK_TAR, BATTLE_SKILL_GRANT_HREO_3_COORD)
	clickAndWaitSkillAction()
	TracePrint "skill 6"
	CheckAndTapImg2(BATTLE_HERO_SKILL_CHECK_TAR, BATTLE_HERO_SKILL_6_COORD)
	CheckAndTapImg2(BATTLE_SKILL_GRANT_CHECK_TAR, BATTLE_SKILL_GRANT_HREO_3_COORD)
	clickAndWaitSkillAction()
	TracePrint "skill 9"
	CheckAndTapImg2(BATTLE_HERO_SKILL_CHECK_TAR, BATTLE_HERO_SKILL_9_COORD)
	clickAndWaitSkillAction()


	TracePrint "attack"
	CheckAndTapImg2(BATTLE_HERO_SKILL_CHECK_TAR, null)
	Delay BATTLE_ULTIMATE_DISPLAY_AWAIT_MS
	CheckAndTapImg2(BATTLE_ATTACK_BACK_TAR, BATTLE_ATTACK_CARD_3_COORD)
	Delay BATTLE_CARD_TAPED_AWAIT_MS
	CheckAndTapImg2(BATTLE_ATTACK_CARD_3_FIRST_TAPED_TAR, BATTLE_ATTACK_CARD_4_COORD)
	Delay BATTLE_CARD_TAPED_AWAIT_MS
	CheckAndTapImg2(BATTLE_ATTACK_CARD_4_SECOND_TAPED_TAR, BATTLE_ATTACK_CARD_5_COORD)
	Delay BATTLE_NORMAL_ATTACK_PLAY_AWAIT_MS


	' Round 2

	BattlePrint("Round 2")
	TracePrint "skill 7"
	CheckAndTapImg2(BATTLE_HERO_SKILL_CHECK_TAR, BATTLE_HERO_SKILL_7_COORD)
	clickAndWaitSkillAction()

	TracePrint "attack"
	CheckAndTapImg2(BATTLE_HERO_SKILL_CHECK_TAR, null)
	Delay BATTLE_ULTIMATE_DISPLAY_AWAIT_MS
	CheckAndTapImg2(BATTLE_ATTACK_BACK_TAR, BATTLE_ATTACK_ULTIMATE_3_COORD)
	Delay BATTLE_CARD_TAPED_AWAIT_MS
	CheckAndTapImg2(BATTLE_ATTACK_ULTIMATE_3_FIRST_TAPED_TAR, BATTLE_ATTACK_CARD_4_COORD)
	Delay BATTLE_CARD_TAPED_AWAIT_MS
	CheckAndTapImg2(BATTLE_ATTACK_CARD_4_SECOND_TAPED_TAR, BATTLE_ATTACK_CARD_5_COORD)
	Delay BATTLE_ULTIMATE_PLAY_2_AWAIT_MS


	' Round 3

	BattlePrint("Round 3")
	TracePrint "skill 1"
	CheckAndTapImg2(BATTLE_HERO_SKILL_CHECK_TAR, BATTLE_HERO_SKILL_1_COORD)
	CheckAndTapImg2(BATTLE_SKILL_GRANT_CHECK_TAR, BATTLE_SKILL_GRANT_HREO_3_COORD)
	clickAndWaitSkillAction()
	TracePrint "skill 4"
	CheckAndTapImg2(BATTLE_HERO_SKILL_CHECK_TAR, BATTLE_HERO_SKILL_4_COORD)
	CheckAndTapImg2(BATTLE_SKILL_GRANT_CHECK_TAR, BATTLE_SKILL_GRANT_HREO_3_COORD)
	clickAndWaitSkillAction()
'	TracePrint "skill master 3"
'	CheckAndTapImg(BATTLE_MASTER_SKILL_OPEN_AREA, BATTLE_MASTER_SKILL_OPEN_ATT, null)
'	Delay BATTLE_MASTER_SKILL_AWAIT_MS
'	CheckAndTapImg2(BATTLE_MASTER_SKILL_DISPLAY_TAR, BATTLE_MASTER_SKILL_3_COORD)
'	CheckAndTapImg2(BATTLE_SKILL_GRANT_CHECK_TAR, BATTLE_SKILL_GRANT_HREO_3_COORD)
'	clickAndWaitSkillAction()



	TracePrint "attack"
	CheckAndTapImg2(BATTLE_HERO_SKILL_CHECK_TAR, null)
	Delay BATTLE_ULTIMATE_DISPLAY_AWAIT_MS
	CheckAndTapImg2(BATTLE_ATTACK_BACK_TAR, BATTLE_ATTACK_ULTIMATE_3_COORD)
	Delay BATTLE_CARD_TAPED_AWAIT_MS
	CheckAndTapImg2(BATTLE_ATTACK_ULTIMATE_3_FIRST_TAPED_TAR, BATTLE_ATTACK_CARD_4_COORD)
	Delay BATTLE_CARD_TAPED_AWAIT_MS
	CheckAndTapImg2(BATTLE_ATTACK_CARD_4_SECOND_TAPED_TAR, BATTLE_ATTACK_CARD_5_COORD)

	Delay BATTLE_ULTIMATE_PLAY_LAST_AWAIT_MS


	' Award

	BattlePrint("award tie")
	CheckAndTapImg2(AWARD_TIE_TAR, AWARD_TAP_COORD)
	Delay AWARD_NORMAL_TAP_AWAIT_MS
	TracePrint "award before treasure"
	CheckNoImgAndTap2(AWARD_TREASURE_NEXT_TAR, AWARD_TAP_COORD)
	Delay AWARD_NORMAL_TAP_AWAIT_MS
	TracePrint "award treasure"
	CheckAndTapImg2(AWARD_TREASURE_NEXT_TAR, null)
	
	' Activity Award

	'TracePrint "activity award"
	'Delay AWARD_NORMAL_TAP_AWAIT_MS
	'CheckAndTapImg2(AWARD_ACTIVITY_NEXT_TAR, null)


	' Add Friend?
	Delay ADD_FRIEND_CHECK_AWAIT_MS
	Dim CheckAddFriendSuccess = CheckImg2(ADD_FRIEND_TAR)
	If CheckAddFriendSuccess <> null Then
		CheckAndTapImg2(ADD_FRIEND_TAR, null)
	End If

	' Again?
	BattlePrint("again?")
	TracePrint "again: yes"
	CheckAndTapImg(AGAIN_ALERT_AGAIN_AREA, AGAIN_ALERT_AGAIN_ATT, null)


	' Apple

	Delay APPLE_CHECK_AWAIT_MS
	Dim CheckAppleAlertSuccess = CheckImg(APPLE_DISPLAY_AREA, APPLE_DISPLAY_ATT)
	If CheckAppleAlertSuccess <> null Then
		If CurrentBattleCount < BATTLE_COUNT  Then
			CheckAndTapImg(APPLE_DISPLAY_AREA, APPLE_DISPLAY_ATT, APPLE_GLODEN_COORD)
			CheckAndTapImg(APPLE_CONFIRM_AREA, APPLE_CONFIRM_ATT, null)
		Else
			CheckAndTapImg(APPLE_CONFIRM_AREA, APPLE_CONFIRM_ATT, APPLE_CLOSE_COORD)
		End If
	End If

End Function

Function DoRoll()
	CheckAndTapImg2(INFINITE_ROLL_TAR, null)
	Delay 500
	CheckNoImgAndTap2(INFINITE_ROLL_TAR, INFINITE_ROLL_TAR)
End Function


Do While true
	CurrentBattleCount = CurrentBattleCount + 1
	DoBattle()
	'DoRoll()

	TracePrint "BattleCount Current =", CurrentBattleCount, "Max = ", BATTLE_COUNT
	If CurrentBattleCount >= BATTLE_COUNT Then
		TracePrint "END"
		Exit Do
	End If
Loop

Log.Close