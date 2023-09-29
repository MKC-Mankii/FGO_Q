' SetScreenScale 810, 1440, 0
' v5

Log.Open

' USER CONFIG
Dim BATTLE_COUNT = 50

' BASIC CONFIG
' CONST
Dim NEED_REVERSE = true
Dim COLOR_SIM = 0.9


' OTHERS
Dim INFINITE_ROLL_TAR = Array(330, 388, 570, 455, "Attachment:ROLL100.png") ' ROLL10 ROLL100

Dim ENHANCE_RECOMMAND_TAR = Array(1240, 150, 1370, 208, "Attachment:ENHANCE_RECOMMAND.png")
Dim ENHANCE_RECOMMAND_CONFIRM_TAR = Array(880, 680, 1006, 745, "Attachment:ENHANCE_RECOMMAND_CONFIRM.png")
Dim ENHANCE_ENHANCE_TAR = Array(1340, 716, 1438, 798, "Attachment:ENHANCE_ENHANCE.png")
Dim ENHANCE_ENHANCE_CONFIRM_TAR = Array(877, 632, 1006, 698, "Attachment:ENHANCE_ENHANCE_CONFIRM.png")

' Mythic heros


Dim GET_GIFT_TAR = Array(1058, 620, 1120, 676, "Attachment:GET_GIFT.png")
'Dim GET_GIFT_GOT_TAR = Array(111, 22, 146, 57, "Attachment:GET_GIFT_GOT.png")
Dim GET_GIFT_GOT_COORD = Array(150, 150)
Dim GET_GIFT_CLOSE_TAR = Array(111, 22, 146, 57, "Attachment:GET_GIFT_CLOSE.png")
Dim GET_GIFT_OPENED_TAR = Array(111, 22, 146, 57, "Attachment:GET_GIFT_CLOSE.png|Attachment:GET_GIFT_GOT_CLOSE.png")


'Dim GET_GIFT_TAR = Array(128, 1048, 192, 1124, "Attachment:GET_GIFT.png")
'Dim GET_GIFT_CLOSE_TAR = Array(750, 111, 787, 146, "Attachment:GET_GIFT_CLOSE.png")

Dim LIKE_GIFT_TAR = Array(466, 200, 680, 360, "Attachment:LIKE_GIFT6.png")
Dim LIKE_GIFT_TAR_H_OFFSET = 30
Dim LIKE_GIFT_BOTTOM_H_OFFSET = 166
Dim LIKE_GIFT_DETAIL_TAR = Array(208, 321, 267, 406, "Attachment:LIKE_GIFT_DETAIL.png")
Dim LIKE_GIFT_DETAIL_LIKE_COORD = Array(400, 130)
Dim LIKE_LIKED_TAR = Array(371, 106, 416, 154, "Attachment:LIKE_LIKED.png")
Dim LIKE_CLOSE_COORD = Array(111, 22)





' VARIATE
Dim IsFirstBattle = true

' Dim 屏幕横坐标X,屏幕纵坐标Y
' 屏幕横坐标X=GetScreenX()
' 屏幕纵坐标Y=GetScreenY()
' TracePrint 屏幕横坐标X,屏幕纵坐标Y
' SetScreenScale 810, 1440, 0


Dim CurrentBattleCount = 0
Dim BattleTraceMsg
Dim BattleSuccessCount = 0




Function BattlePrint(Msg)
	TracePrint "Battle", CurrentBattleCount, Msg
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
		Delay 150
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
	TracePrint "CheckNoImgAndTapOnce ", AttachedImg, TapPoint[1], TapPoint[2]
	Dim AttachedImg = Target[5]
	Dim GetImgCoord = CheckImg2(Target)
	If GetImgCoord = null Then
		TracePrint "no img"
		tap TapPoint[1], TapPoint[2]
		CheckNoImgAndTapOnce = true
	Else
		CheckNoImgAndTapOnce = false
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


Function CheckTapImgAndReturnCoord(Target)
	TracePrint "CheckTapImgAndReturnCoord", Target[1], Target[2], Target[5]
	Dim Point = ContinuousCheckImg(Target)
	tap Point[1], Point[2]
	CheckTapImgAndReturnCoord = Point
End Function

// do Battle >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>


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

Function GetGift()
	CheckMissImgAndTap(GET_GIFT_TAR, null)
	Delay 1500
	TracePrint "Checking Gift panel opened"
	ContinuousCheckImg(GET_GIFT_OPENED_TAR)
	Dim GotGift = CheckNoImgAndTapOnce(GET_GIFT_CLOSE_TAR, GET_GIFT_GOT_COORD)
	If GotGift Then
		BattleSuccessCount = BattleSuccessCount + 1
	End If
	BattleTraceMsg = "Got Gift:" & BattleSuccessCount
	Delay 500
	CheckAndTapImg2(GET_GIFT_CLOSE_TAR, null)
	Delay 1000
End Function

Function DoLike()
	'CurrentBattleCount = BATTLE_COUNT
	'CheckAndTapImg2(GET_GIFT_TAR, null)
	'Delay 500

	Dim temp_LIKE_GIFT_TAR = Array(LIKE_GIFT_TAR[1], LIKE_GIFT_TAR[2], LIKE_GIFT_TAR[3], LIKE_GIFT_TAR[4], LIKE_GIFT_TAR[5])
	For 4
		Dim TapedPoint = CheckTapImgAndReturnCoord(temp_LIKE_GIFT_TAR)
		Delay 500
		CheckAndTapImg2(LIKE_GIFT_DETAIL_TAR, LIKE_GIFT_DETAIL_LIKE_COORD)
		Delay 500
		CheckAndTapImg2(LIKE_LIKED_TAR, LIKE_CLOSE_COORD)
		Delay 500
		temp_LIKE_GIFT_TAR[1] = TapedPoint[1] + LIKE_GIFT_TAR_H_OFFSET
		temp_LIKE_GIFT_TAR[3] = temp_LIKE_GIFT_TAR[3] + LIKE_GIFT_BOTTOM_H_OFFSET
		Delay 500
	Next

	TouchDown 1166, 600, 1//按住屏幕上的a坐标不放,并设置此触点ID=1
	TouchMove 493, 600, 1, 1000//将ID=1的触点花x毫秒移动至b坐标
	Delay 500
	TouchUp 1//松开弹起ID=1的触点

End Function

Traceprint "START FROM", DateTime.Format()

Do While true
	CurrentBattleCount = CurrentBattleCount + 1
	'DoRoll()
	'DoEnhance
	GetGift()
	'DoLike

	TracePrint BattleTraceMsg, "Battle Count=" & CurrentBattleCount, "Max=" & BATTLE_COUNT, ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
	If CurrentBattleCount >= BATTLE_COUNT Then
		TracePrint "END"
		Exit Do
	End If
Loop

Log.Close