' SetScreenScale 810, 1440, 0
' v5

Log.Open

' USER CONFIG
Dim BATTLE_COUNT = 1
Dim AllActionRound = Array(_
	Array(_
		Array("skill",  1,0, 3,0, 2,1, 4,0, 5,0, 8,1, 9,1),_
		Array("master", 3,1),_
		Array("attack", 6,4,5)_
	),_
	Array(_
		Array("skill",  7,0),_
		Array("attack", 6,4,5)_
	),_
	Array(_
		Array("skill",  6,1),_
		Array("attack", 6,4,5)_
	)_
 )
' SKILL:Change undefined

' BASIC CONFIG
' CONST
Dim NEED_REVERSE = true
Dim COLOR_SIM = 0.95

' PREPARE
Dim ATT_Taigong = "Attachment:friendtaigong.png"
Dim ATT_CDai = "Attachment:friendCDai.png|Attachment:friendCDai2.png|Attachment:friendCDai3.png"
Dim ATT_Aobao = "Attachment:friendAobao.png"
Dim ATT_Shahu = "Attachment:friendShaHu2.png"
Dim PREPARE_FRIEND_TAR = Array(40, 180, 920, 800, ATT_CDai)


' START
Dim START_TAR = Array(1200, 700, 1420, 800, "Attachment:START_BTN.png")
Dim START_TAPED_DELAY = 8000

' BATTLE: SKILL
' Hero skill
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
' Hero Skill display check: attack button
Dim BATTLE_HERO_SKILL_CHECK_TAR = Array(1200, 700, 1350, 750, "Attachment:ATTACK_BTN.png")

' Skill Grant
Dim BATTLE_SKILL_GRANT_HREO_COORDS = Array(_
	Array(360, 500),_
	Array(717, 500),_
	Array(1074, 500)_
 )
' Skill Grant display check: close button
Dim BATTLE_SKILL_GRANT_CHECK_TAR = Array(1205, 142, 1267, 198, "Attachment:BATTLE_SKILL_GRANT_CHECK.png")


' Skill Change
Dim BATTLE_SKILL_CHANGE_HERO_COORDS = Array(_
	Array(150, 390),_
	Array(375, 390),_
	Array(600, 390),_
	Array(825, 390),_
	Array(1050, 390),_
	Array(1275, 390)_
 )
' Skill Change: display check: change button
Dim BATTLE_SKILL_CHANGE_CHECK_TAR = Array(723, 685, 777, 719, "Attachment:BATTLE_SKILL_CHANGE_CHECK.png")
' Skill Change: selected check: change button
Dim BATTLE_SKILL_CHANGE_SELECTEED_CHECK_TAR = Array(723, 685, 777, 719, "Attachment:BATTLE_SKILL_CHANGE_SELECTEED_CHECK.png")
Dim BATTLE_SKILL_CHANGE_SELECTED_AWAIT_MS = 200

' Master skill
Dim BATTLE_MASTER_SKILL_OPEN_TAR = Array(1317, 325, 1370, 376, "Attachment:BATTLE_MASTER_SKILL_OPEN3.png")
Dim BATTLE_MASTER_SKILL_AWAIT_MS = 200
Dim BATTLE_MASTER_SKILL_COORDS = Array(_
	Array(1020, 350),_
	Array(1120, 350),_
	Array(1220, 350)_
 )
' Master skill display check: skill 1 top
Dim BATTLE_MASTER_SKILL_DISPLAY_TAR = Array(980, 310, 1059, 316, "Attachment:BATTLE_MASTER_SKILL_DISPLAY.png") 
' Display Reference by skill 1 top


Dim BATTLE_SKILL_SPEEDUP_AWAIT_MS = 50
Dim BATTLE_SKILL_NORMAL_AWAIT_MS = 500

' BATTLE: ATTACK





Dim BATTLE_ULTIMATE_DISPLAY_AWAIT_MS = 1000

Dim BATTLE_ATTACK_BACK_TAR = Array(1300, 750, 1390, 785, "Attachment:BATTLE_ATTACK_BACK2.png") 

Dim BATTLE_ATTACK_CARD_COORDS = Array(_
	Array(118, 581),_
	Array(408, 581),_
	Array(698, 581),_
	Array(991, 581),_
	Array(1278, 581),_
	Array(412, 322),_
	Array(699, 322),_
	Array(986, 322)_
 )
Dim BATTLE_ATTACK_CARD_FIRST_TAPED_TARS = Array(_
	Array(),_
	Array(),_
	Array(698, 581, 722, 588, "Attachment:BATTLE_ATTACK_CARD_3_FIRST_TAPED.png"),_
	Array(),_
	Array(),_
	Array(400, 315, 550, 352, "Attachment:ULT_Taped_Red1.png|Attachment:ULT_Taped_Blue1.png"),_
	Array(680, 315, 790, 352, "Attachment:ULT_Taped_Red2.png|Attachment:ULT_Taped_Blue2.png"),_
	Array(940, 314, 1042, 352, "Attachment:ULT_Taped_Red3.png|Attachment:ULT_Taped_Blue3.png|Attachment:ULT_Taped_Green3.png")_
 )
Dim BATTLE_ATTACK_CARD_SECON_TAPED_TARS = Array(_
	Array(),_
	Array(),_
	Array(),_
	Array(991, 581, 1016, 588, "Attachment:BATTLE_ATTACK_CARD_4_SECOND_TAPED.png"),_
	Array(),_
	Array(),_
	Array(),_
	Array()_
 )


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
Dim AGAIN_ALERT_AGAIN_TAR = Array(860, 614, 946, 658, "Attachment:AGAIN_ALERT_AGAIN.png")
Dim AGAIN_ALERT_CLOSE_TAR = Array(450, 612, 545, 658, "Attachment:AGAIN_ALERT_CLOSE.png")

' APPLE
Dim APPLE_CHECK_AWAIT_MS = 500
Dim APPLE_DISPLAY_TAR = Array(634, 37, 743, 83, "Attachment:APPLE_DISPLAY.png")
Dim APPLE_GLODEN_COORD = Array(420, 360)
Dim APPLE_SILVER_COORD = Array(420, 520)
Dim APPLE_CONFIRM_TAR = Array(895, 608, 992, 660, "Attachment:APPLE_CONFIRM.png")
Dim APPLE_CLOSE_COORD = Array(490, 630)


' OTHERS
Dim INFINITE_ROLL_TAR = Array(330, 388, 570, 455, "Attachment:ROLL100.png") ' ROLL10 ROLL100

Dim ENHANCE_RECOMMAND_TAR = Array(1240, 150, 1370, 208, "Attachment:ENHANCE_RECOMMAND.png")
Dim ENHANCE_RECOMMAND_CONFIRM_TAR = Array(880, 680, 1006, 745, "Attachment:ENHANCE_RECOMMAND_CONFIRM.png")
Dim ENHANCE_ENHANCE_TAR = Array(1340, 716, 1438, 798, "Attachment:ENHANCE_ENHANCE.png")
Dim ENHANCE_ENHANCE_CONFIRM_TAR = Array(877, 632, 1006, 698, "Attachment:ENHANCE_ENHANCE_CONFIRM.png")


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
	TracePrint "CheckAndTapImg2", Target[1], Target[2], Target[5]
	Dim Point = ContinuousCheckImg(Target)
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
	TracePrint "found: ", GetImgCoord[1], GetImgCoord[2]
End Function

Function ContinuousCheckImgMiss(Target)
	Dim GetImgCoord
	Do While true
		GetImgCoord = CheckImg2(Target)
		If GetImgCoord = null Then
			ContinuousCheckImgMiss = null
			Exit Do
		End If
		Delay 500
	Loop
	TracePrint "missed: ", Target[1], Target[2]
End Function

Function CheckNoImgAndTap2(Target, TapPoint)
	Dim AttachedImg = Target[5]
	Do While true
		Dim GetImgCoord = CheckImg2(Target)
		If GetImgCoord = null Then
			TracePrint "cannot find ", AttachedImg, "then tap", TapPoint[1], TapPoint[2]
			tap TapPoint[1], TapPoint[2]
		Else
			Exit Do
		End If
		Delay 300
	Loop
End Function

Function CheckImg2(Target)
	Dim Area = Target
	Dim AttachedImg = Target[5]
	'TracePrint "check: ", Area[1], Area[2], Area[3], Area[4], AttachedImg
	Dim intX, intY
	FindPic Area[1], Area[2], Area[3], Area[4], AttachedImg, "000000", 0, 0.9, intX, intY
	If intX > -1 And intY > -1 Then
		CheckImg2 = Array(intX, intY)
	End If
End Function

Function CheckNoImgAndTapOnce(Target, TapPoint)
	Dim AttachedImg = Target[5]
	Dim GetImgCoord = CheckImg2(Target)
	If GetImgCoord = null Then
		TracePrint "CheckNoImgAndTapOnce ", AttachedImg, TapPoint[1], TapPoint[2]
		tap TapPoint[1], TapPoint[2]
	Else
	End If
End Function

Function CheckMissImgAndTap(Target, TapPoint)
	TracePrint "CheckMissImgAndTap", Target[1], Target[2], Target[5]
	Dim AttachedImg = Target[5]
	Dim TapPointX
	Dim TapPointY
	If TapPoint Then
		TapPointX = TapPoint[1]
		TapPointY = TapPoint[2]
	Else
		TapPointX = Target[1]
		TapPointY = Target[2]
	End If
	ContinuousCheckImgMiss(Target)
	tap TapPointX, TapPointY
End Function

// do Battle >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
Function ChooseFriend()
	BattlePrint("Choose Friend")
	CheckAndTapImg2(PREPARE_FRIEND_TAR, null)
End Function
Function CheckFirstBattle2Start()
	If IsFirstBattle Then
		TracePrint "First Battle Start"
		CheckAndTapImg2(START_TAR, null)
		IsFirstBattle = false
	End If
End Function

Function DoSkillActions(ActionsGroup)
	TracePrint "skill"
	Dim ActionsCount = (UBound(ActionsGroup))/2
	For ActionIndex = 1 To ActionsCount
		Dim SkillIndex = ActionsGroup[ActionIndex*2]
		TracePrint "skill", SkillIndex
		Dim SkillTargetIndex = ActionsGroup[ActionIndex*2 + 1]
		CheckAndTapImg2(BATTLE_HERO_SKILL_CHECK_TAR, BATTLE_HERO_SKILL_COORDS[SkillIndex])
		If SkillTargetIndex > 0 Then
			CheckAndTapImg2(BATTLE_SKILL_GRANT_CHECK_TAR, BATTLE_SKILL_GRANT_HREO_COORDS[SkillTargetIndex])
		End If
		clickAndWaitSkillAction()
	Next
End Function

Function DoMasterActions(ActionsGroup)
	Dim ActionsCount = (UBound(ActionsGroup))/2
	For ActionIndex = 1 To ActionsCount
		Dim SkillIndex = ActionsGroup[ActionIndex*2]
		TracePrint "master", SkillIndex
		Dim SkillTargetIndex = ActionsGroup[ActionIndex*2 + 1]
		Dim SkillChangeTargetIndex1
		Dim SkillChangeTargetIndex2
		If SkillTargetIndex > 100 Then
			SkillChangeTargetIndex1 = Fix(SkillTargetIndex/100)
			SkillChangeTargetIndex2 = SkillTargetIndex - SkillChangeTargetIndex1*100
		End If
		
		CheckAndTapImg2(BATTLE_MASTER_SKILL_OPEN_TAR, null)
		Delay BATTLE_MASTER_SKILL_AWAIT_MS
		CheckAndTapImg2(BATTLE_MASTER_SKILL_DISPLAY_TAR, BATTLE_MASTER_SKILL_COORDS[SkillIndex])
		If SkillTargetIndex > 100 Then
			CheckAndTapImg2(BATTLE_SKILL_CHANGE_CHECK_TAR, BATTLE_SKILL_CHANGE_HERO_COORDS[SkillChangeTargetIndex1])
			Delay BATTLE_SKILL_CHANGE_SELECTED_AWAIT_MS
			CheckAndTapImg2(BATTLE_SKILL_CHANGE_CHECK_TAR, BATTLE_SKILL_CHANGE_HERO_COORDS[SkillChangeTargetIndex2])
			CheckAndTapImg2(BATTLE_SKILL_CHANGE_SELECTEED_CHECK_TAR, null)
		ElseIf SkillTargetIndex > 0 Then
			CheckAndTapImg2(BATTLE_SKILL_GRANT_CHECK_TAR, BATTLE_SKILL_GRANT_HREO_COORDS[SkillTargetIndex])
		End If
		clickAndWaitSkillAction()
	Next
End Function

Function DoAttackActions(ActionsGroup)
	TracePrint "attack"
	CheckAndTapImg2(BATTLE_HERO_SKILL_CHECK_TAR, null)
	Delay BATTLE_ULTIMATE_DISPLAY_AWAIT_MS
	
	Dim FirstCardIndex = ActionsGroup[2]
	CheckAndTapImg2(BATTLE_ATTACK_BACK_TAR, BATTLE_ATTACK_CARD_COORDS[FirstCardIndex])
	Delay BATTLE_CARD_TAPED_AWAIT_MS

	Dim SecondCardIndex = ActionsGroup[3]
	CheckAndTapImg2(BATTLE_ATTACK_CARD_FIRST_TAPED_TARS[FirstCardIndex], BATTLE_ATTACK_CARD_COORDS[SecondCardIndex])
	Delay BATTLE_CARD_TAPED_AWAIT_MS

	Dim ThirdCardIndex = ActionsGroup[4]
	CheckAndTapImg2(BATTLE_ATTACK_CARD_SECON_TAPED_TARS[SecondCardIndex], BATTLE_ATTACK_CARD_COORDS[ThirdCardIndex])
	Delay BATTLE_NORMAL_ATTACK_PLAY_AWAIT_MS
End Function

Function DoGroupActions(ActionsGroup)
	If ActionsGroup[1] = "skill" Then
		DoSkillActions(ActionsGroup)
	ElseIf ActionsGroup[1] = "master" Then
		DoMasterActions(ActionsGroup)
	ElseIf ActionsGroup[1] = "attack" Then
		DoAttackActions(ActionsGroup)
	End If
End Function

Function DoBattle()
	
	ChooseFriend()
	CheckFirstBattle2Start()

	BattlePrint("Delay to battle")
	Delay START_TAPED_DELAY

	Dim RoundCount = UBound(AllActionRound)+1
	For RoundIndex = 1 To RoundCount
		BattlePrint("Round " & RoundIndex)
		Dim ActionsRound = AllActionRound[RoundIndex]
		' ActionsGroup
		Dim ActionsGroupCount = UBound(ActionsRound)+1
		For ActionsGroupIndex = 1 To ActionsGroupCount
			Dim ActionsGroup = ActionsRound[ActionsGroupIndex]
			DoGroupActions(ActionsGroup)
		Next
	Next


	' Award
	BattlePrint("award tie")
	CheckAndTapImg2(AWARD_TIE_TAR, AWARD_TAP_COORD)
	Delay AWARD_NORMAL_TAP_AWAIT_MS
	TracePrint "award before treasure"
	CheckNoImgAndTap2(AWARD_TREASURE_NEXT_TAR, AWARD_TAP_COORD)
	Delay AWARD_NORMAL_TAP_AWAIT_MS
	TracePrint "award treasure"
	CheckAndTapImg2(AWARD_TREASURE_NEXT_TAR, null)

	' Normal Activity Award (Next)
	' TracePrint "activity award"
	' Delay AWARD_NORMAL_TAP_AWAIT_MS
	' CheckAndTapImg2(AWARD_TREASURE_NEXT_TAR, null)
	
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


End Function

Function DoRoll()
	CheckAndTapImg2(INFINITE_ROLL_TAR, null)
	Delay 500
	CheckNoImgAndTap2(INFINITE_ROLL_TAR, INFINITE_ROLL_TAR)
End Function

Function DoEnhance()
	CheckAndTapImg2(ENHANCE_RECOMMAND_TAR, null)
	Delay 500
	CheckAndTapImg2(ENHANCE_RECOMMAND_CONFIRM_TAR, null)
	Delay 500
	CheckAndTapImg2(ENHANCE_ENHANCE_TAR, null)
	Delay 500
	CheckAndTapImg2(ENHANCE_ENHANCE_CONFIRM_TAR, null)
	Delay 500
	CheckNoImgAndTap2(ENHANCE_RECOMMAND_TAR, ENHANCE_ENHANCE_CONFIRM_TAR)
	Delay 500
End Function

// START
Traceprint "START FROM", DateTime.Format()

Do While true
	CurrentBattleCount = CurrentBattleCount + 1
	DoBattle()
	'DoRoll()
	'DoEnhance()

	TracePrint "BattleCount Current =", CurrentBattleCount, "Max = ", BATTLE_COUNT
	If CurrentBattleCount >= BATTLE_COUNT Then
		TracePrint "END"
		Exit Do
	End If
Loop

Log.Close