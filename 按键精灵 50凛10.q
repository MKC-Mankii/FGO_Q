'SetScreenScale 576, 1024, 0
'凛初始 50np
'双C呆
'御主 10np礼装，技能位3

Log.Open
Dim NEED_REVERSE = true
Dim PREPARE_FRIEND_CABER_COORD = Array(120, 200)
Dim PREPARE_FRIEND_CABER_RGB_STAGE_1 = "8A4048"	' 138,64,72
Dim PREPARE_FRIEND_CABER_RGB_STAGE_2 = "814949" ' 129,73,73
Dim PREPARE_FRIEND_CABER_RGB_STAGE_3 = "FFF9E9" ' 255,249,233
Dim PREPARE_FRIEND_CABER_RGB = "8A4048|814949|FFF9E9"
Dim START_COORD = Array(900, 536)
Dim START_RGB = "0E0E1D" ' 14,14,29
Dim BATTLE_CABER_1_SKILL_1_COORD = Array(61, 460)
Dim BATTLE_CABER_1_SKILL_1_RGB = "5B5B5B" ' 91,91,91
Dim BATTLE_CABER_1_SKILL_2_COORD = Array(130, 465)
Dim BATTLE_CABER_1_SKILL_2_RGB = "C4D5E1" ' 196,213,225
Dim BATTLE_CABER_1_SKILL_3_COORD = Array(204, 463)
Dim BATTLE_CABER_1_SKILL_3_RGB = "7DEFFF" ' 125,239,255

Dim BATTLE_CABER_2_SKILL_1_COORD = Array(315, 460)
Dim BATTLE_CABER_2_SKILL_1_RGB = "5B5B5B" ' 91,91,91
Dim BATTLE_CABER_2_SKILL_2_COORD = Array(384, 465)
Dim BATTLE_CABER_2_SKILL_2_RGB = "C4D5E1" ' 196,213,225
Dim BATTLE_CABER_2_SKILL_3_COORD = Array(458, 463)
Dim BATTLE_CABER_2_SKILL_3_RGB = "7DEFFF" ' 125,239,255

Dim BATTLE_LIN_SKILL_1_COORD = Array(569, 460)
Dim BATTLE_LIN_SKILL_1_RGB = "5B5B5B" ' 91,91,91
Dim BATTLE_LIN_SKILL_2_COORD = Array(638, 462)
Dim BATTLE_LIN_SKILL_2_RGB = "F2E148" ' 242,225,72
Dim BATTLE_LIN_SKILL_3_COORD = Array(709, 465)
Dim BATTLE_LIN_SKILL_3_RGB = "A1B1D0" ' 161,177,208

Dim ATTACK_COORD = Array(905,485)
Dim ATTACK_RGB = "00B3E5" ' 0,179,229
Dim MASTER_SKILL_SHOW_COORD = Array(955,250)
Dim MASTER_SKILL_SHOW_RGB = "0E2F69" ' 14,47,105

Dim MASTER_SKILL_1_DISPLAY_COORD = Array(725,222)
Dim MASTER_SKILL_1_DISPLAY_RGB_1 = "FEFEFE" ' 254,254,254
Dim MASTER_SKILL_1_DISPLAY_RGB_2 = "FFFFFF" ' 255,255,255
Dim MASTER_SKILL_1_COORD = Array(725,250)
Dim MASTER_SKILL_2_COORD = Array(800,250)
Dim MASTER_SKILL_3_COORD = Array(870,250)
Dim MASTER_SKILL_AWAIT_MS = 200

Dim 屏幕横坐标X,屏幕纵坐标Y
屏幕横坐标X=GetScreenX()
屏幕纵坐标Y=GetScreenY()
TracePrint 屏幕横坐标X,屏幕纵坐标Y

' SetScreenScale 576, 1024, 0

Function RGBToBGR(RGBs)
	RGBArr = Split(RGBs, "|")
	Dim BGRArr = Array()
	For Each RGB_SINGLE In RGBArr
		RGB_SINGLE = Mid(RGB_SINGLE, 5, 2) & Mid(RGB_SINGLE, 3, 2) & Mid(RGB_SINGLE, 1, 2)
		BGRArr[UBound(BGRArr)+2] = RGB_SINGLE
	Next
	RGBToBGR = Join(BGRArr, "|")
End Function

Function CheckAndTapRGBS(Point, RGBArr)
	Dim PointX = Point[1]
	Dim PointY = Point[2]
	' Dim Count = 0
	Dim IntX,IntY
	Dim RGBs
	If NEED_REVERSE Then
		Dim Reverse_RGBArr = Array()
		For Each RGB_SINGLE In RGBArr
			RGB_SINGLE = Mid(RGB_SINGLE, 5, 2) & Mid(RGB_SINGLE, 3, 2) & Mid(RGB_SINGLE, 1, 2)
			Reverse_RGBArr[UBound(Reverse_RGBArr)+2] = RGB_SINGLE
		Next
		RGBs = Join(Reverse_RGBArr, "|")
	Else
		RGBs = Join(RGBArr, "|")
	End If
	TracePrint PointX, PointY, RGBs
	' Dim rColor
	' rColor = GetPixelColor(120, 200)
	' rColor = GetPixelColor(120, 201)
	' TracePrint "这个点的颜色为："&rColor
	Do While true
		FindMultiColor PointX-1, PointY-1, PointX+1, PointY+1,RGBs,"",1,1,intX,intY
		If intX > 0 Then
			' ShowMessage ( Count & ":" & CStr(IntX) & " a " & CStr(IntY)) ' todo
			Exit Do
		End If
		Delay 500
		' Count = Count+1
	Loop
	TracePrint "find out:", IntX, IntY
	tap 120, 200
End Function

TracePrint "Choose Friend"
CheckAndTapRGBS(PREPARE_FRIEND_CABER_COORD, Array(PREPARE_FRIEND_CABER_RGB_STAGE_1,PREPARE_FRIEND_CABER_RGB_STAGE_2,PREPARE_FRIEND_CABER_RGB_STAGE_3))

TracePrint "Prepare to Start"
' CheckAndTap()

Log.Close
