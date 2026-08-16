' battle_runner_extras.q
' 从 battle_runner.q 拆分出的额外功能方法
'
' 依赖：
' - battle_runner.q 中已定义的通用方法：CheckAndTapImg2 / CheckNoImgAndTap2 / CheckImg2 / ContinuousCheckImg / TouchMoveWithDownTime
' - 全局变量：HasTicket

Log.Open

' ==================== QUICK EDIT (MANUAL) ====================
' 自动识别场景，不再手动设置 EXTRA_METHOD_INDEX
Dim EXTRA_ACTION_COUNT = 30
Dim EXTRA_SKILL_MAX_LEVEL = 9
' ============================================================

Dim CurrentBattleCount = 0
Dim HasTicket = true

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
	Dim intX, intY
	FindPic Area[1], Area[2], Area[3], Area[4], AttachedImg, "000000", 0, 0.9, intX, intY
	If intX > -1 And intY > -1 Then
		CheckImg2 = Array(intX, intY)
	End If
End Function

// 拖拽>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
Function TouchMoveWithDownTime(Target,DownTime)
	TouchDown Target[1], Target[2], 1 //按住屏幕上的a坐标不放,并设置此触点ID=1
	If IsNull(DownTime) Then
		DownTime = 500
	End If
	Delay DownTime
	TouchMove Target[3], Target[4], 1, 500 //将ID=1的触点花x毫秒移动至b坐标
	Delay 500
	TouchUp 1//松开弹起ID=1的触点
End Function

Function DetectExtraMethodIndex()
	Dim ScenePoint

	' 1=DoEnhance
	ScenePoint = CheckImg2(ENHANCE_HERO_TAR)
	If ScenePoint <> null Then
		DetectExtraMethodIndex = 1
		Exit Function
	End If

	' 2=DoEquipEnhance
	ScenePoint = CheckImg2(ENHANCE_EQUIP_TAR)
	If ScenePoint <> null Then
		DetectExtraMethodIndex = 2
		Exit Function
	End If

	' 3=DoSkillEnhance
	ScenePoint = CheckImg2(ENHANCE_SKILL_TAR)
	If ScenePoint <> null Then
		DetectExtraMethodIndex = 3
		Exit Function
	End If
	ScenePoint = CheckImg2(ENHANCE_SKILL_ENHANCE_TAR)
	If ScenePoint <> null Then
		DetectExtraMethodIndex = 3
		Exit Function
	End If

	' 4=DoFriendPool
	ScenePoint = CheckImg2(POOLFRIEND_CONTINUE_TAR)
	If ScenePoint <> null Then
		DetectExtraMethodIndex = 4
		Exit Function
	End If

	' 5=DoRoll
	ScenePoint = CheckImg2(INFINITE_ROLL_TAR)
	If ScenePoint <> null Then
		DetectExtraMethodIndex = 5
		Exit Function
	End If

	DetectExtraMethodIndex = 0
End Function

Function GetExtraMethodActionName(DetectedMethodIndex)
	If DetectedMethodIndex = 1 Then
		GetExtraMethodActionName = "DoEnhance"
	ElseIf DetectedMethodIndex = 2 Then
		GetExtraMethodActionName = "DoEquipEnhance"
	ElseIf DetectedMethodIndex = 3 Then
		GetExtraMethodActionName = "DoSkillEnhance"
	ElseIf DetectedMethodIndex = 4 Then
		GetExtraMethodActionName = "DoFriendPool"
	ElseIf DetectedMethodIndex = 5 Then
		GetExtraMethodActionName = "DoRoll"
	Else
		GetExtraMethodActionName = "UNKNOWN"
	End If
End Function

Function DoSelectedExtraAction()
	Dim DetectedMethodIndex = DetectExtraMethodIndex()
	If DetectedMethodIndex = 0 Then
		TracePrint "AUTO DETECT FAILED: NO MATCHED SCENE"
		HasTicket = false
		Exit Function
	End If

	TracePrint "AUTO DETECT EXTRA_METHOD_INDEX:", DetectedMethodIndex, "ACTION=", GetExtraMethodActionName(DetectedMethodIndex)

	If DetectedMethodIndex = 1 Then
		DoEnhance()
	ElseIf DetectedMethodIndex = 2 Then
		DoEquipEnhance()
	ElseIf DetectedMethodIndex = 3 Then
		DoSkillEnhance(EXTRA_SKILL_MAX_LEVEL)
	ElseIf DetectedMethodIndex = 4 Then
		DoFriendPool()
	ElseIf DetectedMethodIndex = 5 Then
		DoRoll()
	Else
		TracePrint "INVALID AUTO DETECT INDEX:", DetectedMethodIndex
		HasTicket = false
	End If
End Function

' OTHERS
Dim INFINITE_ROLL_TAR = Array(330, 370, 620, 610, "Attachment:ROLL100.png|Attachment:ROLL100-1.png|Attachment:ROLL10.png|Attachment:ROLL10-1.png") ' ROLL10 ROLL100
Dim INFINITE_ROLL_FAST_COORD = Array(300, 400)

Dim ENHANCE_HERO_TAR = Array(880, 5, 1300, 70, "Attachment:ENHANCE_HERO.png")
Dim ENHANCE_HERO_RECOMMAND_TAR = Array(1240, 150, 1370, 208, "Attachment:ENHANCE_HERO_RECOMMAND.png")
Dim ENHANCE_HERO_RECOMMAND_CONFIRM_TAR = Array(880, 680, 1006, 745, "Attachment:ENHANCE_HERO_RECOMMAND_CONFIRM.png")
Dim ENHANCE_HERO_ENHANCE_TAR = Array(1340, 716, 1438, 798, "Attachment:ENHANCE_HERO_ENHANCE.png")
Dim ENHANCE_HERO_ENHANCE_CONFIRM_TAR = Array(877, 632, 1006, 698, "Attachment:ENHANCE_HERO_ENHANCE_CONFIRM.png")

Dim POOLFRIEND_CONTINUE_TAR = Array(720, 720, 990, 800, "Attachment:POOLFRIEND_CONTINUE.png")
Dim POOLFRIEND_GO_TAR = Array(830, 600, 1080, 670, "Attachment:POOLFRIEND_GO.png")

Dim ENHANCE_EQUIP_TAR = Array(880, 5, 1300, 70, "Attachment:ENHANCE_EQUIP.png")
Dim ENHANCE_EQUIP_START_TAR = Array(446, 216, 532, 315, "Attachment:ENHANCE_EQUIP_START.png")
Dim ENHANCE_EQUIP_SELECT_READY_TAR = Array(1205, 204, 1226, 267, "Attachment:ENHANCE_EQUIP_SELECT_READY.png")
Dim ENHANCE_EQUIP_SELECT_COORD = Array(150, 390, 1050, 710)
Dim ENHANCE_EQUIP_SELECT_CONFIRM_TAR = Array(1200, 725, 1260, 790, "Attachment:ENHANCE_EQUIP_SELECT_CONFIRM.png")
Dim ENHANCE_EQUIP_SELECT_STOP_TAR = Array(80, 530, 1116, 809, "Attachment:ENHANCE_EQUIP_SELECT_STOP.png|Attachment:ENHANCE_EQUIP_SELECT_STOP2.png")
Dim ENHANCE_EQUIP_ENHANCE_TAR = Array(1340, 716, 1438, 798, "Attachment:ENHANCE_EQUIP_ENHANCE.png")
Dim ENHANCE_EQUIP_ENHANCE_CONFIRM_TAR = Array(877, 632, 1006, 698, "Attachment:ENHANCE_EQUIP_ENHANCE_CONFIRM.png")

Dim ENHANCE_SKILL_TAR = Array(880, 5, 1300, 70, "Attachment:ENHANCE_SKILL.png")
Dim ENHANCE_SKILL_ENHANCE_TAR = Array(1185, 725, 1230, 785, "Attachment:ENHANCE_SKILL_ENHANCE.png")
Dim ENHANCE_SKILL_ENHANCE_CONFIRM_TAR = Array(820, 640, 890, 690, "Attachment:ENHANCE_SKILL_ENHANCE_CONFIRM.png")
Dim ENHANCE_SKILL_ENHANCE_L10_TAR = Array(450, 490, 610, 630, "Attachment:ENHANCE_SKILL_ENHANCE_L10.png")
Dim ENHANCE_SKILL_CLICK_COORD = Array(1100, 765)

Function DoRoll()
	CheckAndTapImg2(INFINITE_ROLL_TAR, null)
	Delay 500
	CheckNoImgAndTap2(INFINITE_ROLL_TAR, INFINITE_ROLL_FAST_COORD)
End Function

Function DoEnhance()
	CheckAndTapImg2(ENHANCE_HERO_ENHANCE_TAR, null)
	Delay 500
	CheckAndTapImg2(ENHANCE_HERO_ENHANCE_CONFIRM_TAR, null)
	Delay 500
	CheckNoImgAndTap2(ENHANCE_HERO_RECOMMAND_TAR, ENHANCE_HERO_ENHANCE_CONFIRM_TAR)
	Delay 500
End Function

Function DoFriendPool()
	CheckAndTapImg2(POOLFRIEND_CONTINUE_TAR, null)
	Delay 500
	CheckAndTapImg2(POOLFRIEND_GO_TAR, null)
	Delay 800
	CheckNoImgAndTap2(POOLFRIEND_CONTINUE_TAR, POOLFRIEND_CONTINUE_TAR)
End Function

Function DoEquipEnhance()
	'CheckAndTapImg2(ENHANCE_EQUIP_START_TAR, null)
	'Delay 500
	'ContinuousCheckImg(ENHANCE_EQUIP_SELECT_READY_TAR)

	'Dim CheckEnhanceSelectStop = CheckImg2(ENHANCE_EQUIP_SELECT_STOP_TAR)
	'If CheckEnhanceSelectStop <> null Then
	'	HasTicket = false
	'	Traceprint "ENHANCE_EQUIP_SELECT_STOP"
	'	Exit Function
	'End If

	'TouchMoveWithDownTime(ENHANCE_EQUIP_SELECT_COORD, 1200)
	'Delay 500
	'CheckAndTapImg2(ENHANCE_EQUIP_SELECT_CONFIRM_TAR, null)

	CheckAndTapImg2(ENHANCE_EQUIP_ENHANCE_TAR, null)
	Delay 500
	CheckAndTapImg2(ENHANCE_EQUIP_ENHANCE_CONFIRM_TAR, null)
	Delay 500
	CheckNoImgAndTap2(ENHANCE_EQUIP_ENHANCE_TAR, ENHANCE_EQUIP_ENHANCE_CONFIRM_TAR)
End Function

Function DoSkillEnhance(MaxLevel)
	ContinuousCheckImg(ENHANCE_SKILL_ENHANCE_TAR)
	If MaxLevel <> 10 Then
		Dim CheckSkillEnhance10TarSuccess = CheckImg2(ENHANCE_SKILL_ENHANCE_L10_TAR)
		If CheckSkillEnhance10TarSuccess <> null Then
			HasTicket = false
			Traceprint "ENHANCE_SKILL_10_STOP"
			Exit Function
		End If
	End If
	CheckAndTapImg2(ENHANCE_SKILL_ENHANCE_TAR, null)
	CheckAndTapImg2(ENHANCE_SKILL_ENHANCE_CONFIRM_TAR, null)
	Delay 700
	CheckNoImgAndTap2(ENHANCE_SKILL_ENHANCE_TAR, ENHANCE_SKILL_CLICK_COORD)
End Function


' START
Traceprint "EXTRAS START FROM", DateTime.Format(), "METHOD=AUTO_DETECT"

If EXTRA_ACTION_COUNT <= 0 Then
	TracePrint "EXTRA_ACTION_COUNT INVALID, STOP"
	Log.Close
	EndScript
End If

Do While true
	CurrentBattleCount = CurrentBattleCount + 1
	DoSelectedExtraAction()

	TracePrint "ExtraAction Current =", CurrentBattleCount, "Max = ", EXTRA_ACTION_COUNT, "HasTicket = ", HasTicket
	If CurrentBattleCount >= EXTRA_ACTION_COUNT Or HasTicket = false Then
		TracePrint "EXTRAS END"
		Exit Do
	End If
Loop

Log.Close
