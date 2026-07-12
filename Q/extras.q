' battle_runner_extras.q
' 从 battle_runner.q 拆分出的额外功能方法
'
' 依赖：
' - battle_runner.q 中已定义的通用方法：CheckAndTapImg2 / CheckNoImgAndTap2 / CheckImg2 / ContinuousCheckImg / TouchMoveWithDownTime
' - 全局变量：HasTicket

Log.Open

' ==================== QUICK EDIT (MANUAL) ====================
' 1=DoRoll, 2=DoFriendPool, 3=DoEnhance, 4=DoEquipEnhance, 5=DoSkillEnhance
Dim EXTRA_METHOD_INDEX = 1
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

Function DoSelectedExtraAction()
	If EXTRA_METHOD_INDEX = 1 Then
		DoRoll()
	ElseIf EXTRA_METHOD_INDEX = 2 Then
		DoFriendPool()
	ElseIf EXTRA_METHOD_INDEX = 3 Then
		DoEnhance()
	ElseIf EXTRA_METHOD_INDEX = 4 Then
		DoEquipEnhance()
	ElseIf EXTRA_METHOD_INDEX = 5 Then
		DoSkillEnhance(EXTRA_SKILL_MAX_LEVEL)
	Else
		TracePrint "INVALID EXTRA_METHOD_INDEX:", EXTRA_METHOD_INDEX
		HasTicket = false
	End If
End Function

' OTHERS
Dim INFINITE_ROLL_TAR = Array(330, 370, 620, 610, "Attachment:ROLL100.png|Attachment:ROLL100-1.png|Attachment:ROLL10.png|Attachment:ROLL10-1.png") ' ROLL10 ROLL100
Dim INFINITE_ROLL_FAST_COORD = Array(300, 400)

Dim ENHANCE_RECOMMAND_TAR = Array(1240, 150, 1370, 208, "Attachment:ENHANCE_RECOMMAND.png")
Dim ENHANCE_RECOMMAND_CONFIRM_TAR = Array(880, 680, 1006, 745, "Attachment:ENHANCE_RECOMMAND_CONFIRM.png")
Dim ENHANCE_ENHANCE_TAR = Array(1340, 716, 1438, 798, "Attachment:ENHANCE_ENHANCE.png")
Dim ENHANCE_ENHANCE_CONFIRM_TAR = Array(877, 632, 1006, 698, "Attachment:ENHANCE_ENHANCE_CONFIRM.png")

Dim POOLFRIEND_CONTINUE_TAR = Array(720, 720, 990, 800, "Attachment:POOLFRIEND_CONTINUE.png")
Dim POOLFRIEND_GO_TAR = Array(830, 600, 1080, 670, "Attachment:POOLFRIEND_GO.png")

Dim EQUIP_ENHANCE_START_TAR = Array(446, 216, 532, 315, "Attachment:EQUIP_ENHANCE_START.png")
Dim EQUIP_ENHANCE_SELECT_READY_TAR = Array(1205, 204, 1226, 267, "Attachment:EQUIP_ENHANCE_SELECT_READY.png")
Dim EQUIP_ENHANCE_SELECT_COORD = Array(150, 390, 1050, 710)
Dim EQUIP_ENHANCE_SELECT_CONFIRM_TAR = Array(1200, 725, 1260, 790, "Attachment:EQUIP_ENHANCE_SELECT_CONFIRM.png")
Dim EQUIP_ENHANCE_SELECT_STOP_TAR = Array(80, 530, 1116, 809, "Attachment:EQUIP_ENHANCE_SELECT_STOP.png|Attachment:EQUIP_ENHANCE_SELECT_STOP2.png")

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

Function DoFriendPool()
	CheckAndTapImg2(POOLFRIEND_CONTINUE_TAR, null)
	Delay 500
	CheckAndTapImg2(POOLFRIEND_GO_TAR, null)
	Delay 800
	CheckNoImgAndTap2(POOLFRIEND_CONTINUE_TAR, POOLFRIEND_CONTINUE_TAR)
End Function

Function DoEquipEnhance()
	CheckAndTapImg2(EQUIP_ENHANCE_START_TAR, null)
	Delay 500
	ContinuousCheckImg(EQUIP_ENHANCE_SELECT_READY_TAR)

	Dim CheckEnhanceSelectStop = CheckImg2(EQUIP_ENHANCE_SELECT_STOP_TAR)
	If CheckEnhanceSelectStop <> null Then
		HasTicket = false
		Traceprint "EQUIP_ENHANCE_SELECT_STOP"
		Exit Function
	End If

	TouchMoveWithDownTime(EQUIP_ENHANCE_SELECT_COORD, 1200)
	Delay 500
	CheckAndTapImg2(EQUIP_ENHANCE_SELECT_CONFIRM_TAR, null)

	CheckAndTapImg2(ENHANCE_ENHANCE_TAR, null)
	Delay 500
	CheckAndTapImg2(ENHANCE_ENHANCE_CONFIRM_TAR, null)
	Delay 500
	CheckNoImgAndTap2(EQUIP_ENHANCE_START_TAR, ENHANCE_ENHANCE_CONFIRM_TAR)
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
Traceprint "EXTRAS START FROM", DateTime.Format(), "METHOD=", EXTRA_METHOD_INDEX

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
