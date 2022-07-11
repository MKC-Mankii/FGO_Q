' SetScreenScale 576, 1024, 0
' 无限池

Log.Open

' USER CONFIG
Dim RoundCount = 3 ' configurable
Dim BATTLE_COUNT = 20


' BASIC CONFIG
' CONST
Dim NEED_REVERSE = true

' PREPARE
Dim START_EXCHANGE_COORD = Array(347, 371)
Dim START_EXCHANGE_RGB = "3CB2D4"	' 60,178,212
Dim START_EXCHANGE_AGAIN_COORD = Array(321, 322)
Dim START_EXCHANGE_AGAIN_RGB = "34A0C8"	' 52,160,200
Dim EXCHANGE_TAP_AWAIT = 500
Dim EXCHANGE_TAP_AMI_AWAIT = 200
Dim CHECK_EMPTY_COORD = Array(236, 371)
Dim CHECK_EMPTY_RGB = "1F5A6B"	' 31,90,107
Dim RESET_COORD = Array(910, 195)
Dim RESET_DO_COORD = Array(673, 451)
Dim RESET_DO_RGB = "9F9F9F"	' 159,159,159
Dim RESET_DONE_COORD = Array(510, 449)
Dim RESET_DONE_RGB = "B9B9B9"	' 185,185,185



' VARIATE
Dim IsFirstBattle = true

' Dim 屏幕横坐标X,屏幕纵坐标Y
' 屏幕横坐标X=GetScreenX()
' 屏幕纵坐标Y=GetScreenY()
' TracePrint 屏幕横坐标X,屏幕纵坐标Y
' SetScreenScale 576, 1024, 0

Function RGBToBGR(RGBs)
	Dim RGBArr = Split(RGBs, "|")
	Dim BGRArr = Array()
	For Each RGB_SINGLE In RGBArr
		RGB_SINGLE = Mid(RGB_SINGLE, 5, 2) & Mid(RGB_SINGLE, 3, 2) & Mid(RGB_SINGLE, 1, 2)
		BGRArr[UBound(BGRArr)+2] = RGB_SINGLE
	Next
	RGBToBGR = Join(BGRArr, "|")
End Function

Function ContinuousCheckPointBGR(PointX, PointY, BGRs)
	TracePrint "check:", PointX, PointY, BGRs
	' Dim rColor
	' rColor = GetPixelColor(120, 200)
	' rColor = GetPixelColor(120, 201)
	' TracePrint "这个点的颜色为: "&rColor
	Dim IntX,IntY
	' Dim Count = 0
	Do While true
		FindMultiColor PointX-1, PointY-1, PointX+1, PointY+1,BGRs,"",1,1,intX,intY
		If intX > 0 Then
			' ShowMessage ( Count & ":" & CStr(IntX) & " a " & CStr(IntY))
			Exit Do
		End If
		Delay 500
		' Count = Count+1
	Loop
	TracePrint "find out:", IntX, IntY
End Function

Function CheckPointBGR(PointX, PointY, BGRs)
	TracePrint "check:", PointX, PointY, BGRs

	Dim rColor
	rColor = GetPixelColor(PointX, PointY)
	TracePrint "这个点的颜色为: "&rColor
	
	Dim IntX,IntY
	' Dim Count = 0
	
	FindMultiColor PointX-1, PointY-1, PointX+1, PointY+1,BGRs,"",1,1,intX,intY
	If intX > 0 Then
		' ShowMessage ( Count & ":" & CStr(IntX) & " a " & CStr(IntY))
		TracePrint "find out:", IntX, IntY
		CheckPointBGR = true
	Else
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
	CheckAndTapRGB(START_EXCHANGE_COORD, START_EXCHANGE_RGB, null)
	ShowMessage "exchange:1"
	Delay EXCHANGE_TAP_AWAIT

	CheckNoPointAndTapRGB(START_EXCHANGE_COORD, START_EXCHANGE_RGB, null)
	Delay EXCHANGE_TAP_AWAIT
	CheckNoPointAndTapRGB(START_EXCHANGE_COORD, START_EXCHANGE_RGB, null)
	Delay EXCHANGE_TAP_AMI_AWAIT
	CheckNoPointAndTapRGB(START_EXCHANGE_COORD, START_EXCHANGE_RGB, null)
	Delay EXCHANGE_TAP_AMI_AWAIT
	CheckNoPointAndTapRGB(START_EXCHANGE_COORD, START_EXCHANGE_RGB, null)
	Delay EXCHANGE_TAP_AMI_AWAIT
	
	For i = 2 To 30
		CheckAndTapRGB(START_EXCHANGE_AGAIN_COORD, START_EXCHANGE_AGAIN_RGB, null)
		ShowMessage "exchange:" & i
		Delay EXCHANGE_TAP_AWAIT
		CheckNoPointAndTapRGB(START_EXCHANGE_AGAIN_COORD, START_EXCHANGE_AGAIN_RGB, null)
		Delay EXCHANGE_TAP_AMI_AWAIT
		CheckNoPointAndTapRGB(START_EXCHANGE_AGAIN_COORD, START_EXCHANGE_AGAIN_RGB, null)
		Delay EXCHANGE_TAP_AMI_AWAIT
		CheckNoPointAndTapRGB(START_EXCHANGE_AGAIN_COORD, START_EXCHANGE_AGAIN_RGB, null)
		Delay EXCHANGE_TAP_AMI_AWAIT
	Next
	CheckNoPointAndTapRGB(START_EXCHANGE_AGAIN_COORD, START_EXCHANGE_AGAIN_RGB, null)
	Delay EXCHANGE_TAP_AMI_AWAIT

	CheckAndTapRGB(CHECK_EMPTY_COORD, CHECK_EMPTY_RGB, RESET_COORD)
	CheckAndTapRGB(RESET_DO_COORD, RESET_DO_RGB, null)
	CheckAndTapRGB(RESET_DONE_COORD, RESET_DONE_RGB, null)

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