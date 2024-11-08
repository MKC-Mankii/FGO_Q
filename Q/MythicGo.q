' SetScreenScale 810, 1440, 0
' SetScreenScale 720, 1280, 0
' v5

Log.Open

' USER CONFIG
Dim BATTLE_COUNT = 50

' BASIC CONFIG
' CONST
Dim NEED_REVERSE = true
Dim COLOR_SIM = 0.9


' Mythic heros


Dim GET_GIFT_TAR = Array(213, 945, 245, 990, "Attachment:GET_GIFT.png")
Dim GET_GIFT_GOT_COORD = Array(120, 120)
Dim GET_GIFT_OPENED_TAR = Array(665, 96, 700, 130, "Attachment:GET_GIFT_CLOSE.png|Attachment:GET_GIFT_GOT_CLOSE.png")
Dim GET_GIFT_CLOSE_TAR = Array(665, 96, 700, 130, "Attachment:GET_GIFT_CLOSE.png")
Dim GET_GIFT_GOT_CLOSE_TAR = Array(665, 96, 700, 130, "Attachment:GET_GIFT_GOT_CLOSE.png")
Dim GET_GIFT_GOT_ITEM_TAR = Array(328, 610, 380, 670, "Attachment:GET_GIFT_GOT_VOUCHER.png|Attachment:GET_GIFT_GOT_DIAMOND.png")

Dim LIKE_GIFT_TAR = Array(420, 445, 480, 630, "Attachment:LIKE_GIFT.png")
Dim LIKE_GIFT_TAR_H_OFFSET = 42
Dim LIKE_GIFT_BOTTOM_H_OFFSET = 148
Dim LIKE_GIFT_DETAIL_TAR = Array(355, 185, 440, 235, "Attachment:LIKE_GIFT_DETAIL.png")
Dim LIKE_GIFT_DETAIL_LIKE_COORD = Array(600, 355)
Dim LIKE_LIKED_TAR = Array(575, 325, 625, 375, "Attachment:LIKE_LIKED.png")
Dim LIKE_CLOSE_COORD = Array(682, 115)

Dim RAINBOW_START_TAR = Array(270, 1190, 430, 1250, "Attachment:RAINBOW_START.png")
Dim RAINBOW_AGAIN_TAR = Array(280, 990, 450, 1050, "Attachment:RAINBOW_AGAIN.png")




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



Function Tap2(TapPointX, TapPointY)
	TouchDown TapPointX, TapPointY
	Delay 100
	TouchUp
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
	Tap2 TapPointX, TapPointY
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
			Tap2 TapPoint[1], TapPoint[2]
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
	TracePrint "CheckNoImgAndTapOnce ", AttachedImg, TapPoint[1], TapPoint[2]
	Dim GetImgCoord = CheckImg2(Target)
	If GetImgCoord = null Then
		TracePrint "no img"
		Tap2 TapPoint[1], TapPoint[2]
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
	Tap2 TapPointX, TapPointY
End Function


Function CheckTapImgAndReturnCoord(Target)
	TracePrint "CheckTapImgAndReturnCoord", Target[1], Target[2], Target[5]
	Dim Point = ContinuousCheckImg(Target)
	Tap2 Point[1], Point[2]
	CheckTapImgAndReturnCoord = Point
End Function

// do Battle >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>


Function GetGift()
	CheckMissImgAndTap(GET_GIFT_TAR, null)
	Delay 1500
	TracePrint "Checking Gift panel opened"
	ContinuousCheckImg(GET_GIFT_OPENED_TAR)

	TracePrint "Checking Gift got"
	Dim GetImgCoord = CheckImg2(GET_GIFT_GOT_CLOSE_TAR)
	'SnapShot "/storage/emulated/0/$MuMu共享文件夹/test" & DateTime.Format("%Y%m%d%H%M%S") &".png"
	SnapShot "/sdcard/$MuMu12Shared/test" & DateTime.Format("%Y%m%d%H%M%S") &".png"
	If GetImgCoord <> null Then
		TracePrint "Got, wait for gift displayed"
		ContinuousCheckImg(GET_GIFT_GOT_ITEM_TAR)
		BattleSuccessCount = BattleSuccessCount + 1
	Else
		TracePrint "Not got"
	End If
	BattleTraceMsg = "Got Gift:" & BattleSuccessCount

	TracePrint "Tap,if got"
	CheckNoImgAndTapOnce(GET_GIFT_CLOSE_TAR, GET_GIFT_GOT_COORD)
	Delay 500
	TracePrint "Close panel"
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
		temp_LIKE_GIFT_TAR[2] = TapedPoint[2] + LIKE_GIFT_TAR_H_OFFSET
		temp_LIKE_GIFT_TAR[4] = temp_LIKE_GIFT_TAR[4] + LIKE_GIFT_BOTTOM_H_OFFSET
		Delay 500
	Next

	TouchDown 480, 1025, 1//按住屏幕上的a坐标不放,并设置此触点ID=1
	TouchMove 480, 425, 1, 1000//将ID=1的触点花x毫秒移动至b坐标
	Delay 500
	TouchUp 1//松开弹起ID=1的触点

End Function

Function DoRainbow()
	CheckAndTapImg2(RAINBOW_START_TAR, RAINBOW_START_TAR)
	Delay 8000
	CheckAndTapImg2(RAINBOW_AGAIN_TAR, RAINBOW_AGAIN_TAR)
	Delay 2000

End Function

Traceprint "START FROM", DateTime.Format()

Do While true
	CurrentBattleCount = CurrentBattleCount + 1
	'DoRoll()
	'DoEnhance
	'GetGift()
	'DoLike
	DoRainbow()

	TracePrint BattleTraceMsg, "Battle Count=" & CurrentBattleCount, "Max=" & BATTLE_COUNT, ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
	If CurrentBattleCount >= BATTLE_COUNT Then
		TracePrint "END"
		Exit Do
	End If
Loop

Log.Close