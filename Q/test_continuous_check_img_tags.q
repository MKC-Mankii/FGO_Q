' Unit test for ContinuousCheckImgTags
' Standalone script with mock CheckImg2 and detailed logs

Log.Open

Dim TEST_TOTAL = 0
Dim TEST_PASS = 0
Dim MOCK_HIT_NAME = ""
Dim USE_REAL_FINDPIC = 0
Dim REAL_FINDPIC_SIM = 0.9

' Keep the same target shape/name as battle_runner.q for realistic unit checks
Dim AGAIN_ALERT_AGAIN_TAR = Array(795, 620, 1030, 700, "Attachment:AGAIN_ALERT_AGAIN.png")
Dim AGAIN_ALERT_CLOSE_TAR = Array(370, 620, 620, 700, "Attachment:AGAIN_ALERT_CLOSE.png")
Dim AGAIN_ORDEAL_NO_TICKET_TAR = Array(600, 600, 850, 670, "Attachment:AGAIN_ORDEAL_NO_TICKET.png")
Dim AGAIN_BATTLE_OUT_MENU_TAR = Array(1301, 689, 1360, 715, "Attachment:AGAIN_BATTLE_OUT_MENU.png")

Sub TestLog(msg)
	TracePrint "[TEST]", msg
End Sub

Sub AssertEqual(testName, expectedVal, actualVal)
	TEST_TOTAL = TEST_TOTAL + 1
	If CStr(expectedVal) = CStr(actualVal) Then
		TEST_PASS = TEST_PASS + 1
		TracePrint "[PASS]", testName, "expected=", expectedVal, "actual=", actualVal
	Else
		TracePrint "[FAIL]", testName, "expected=", expectedVal, "actual=", actualVal
	End If
End Sub

Function BuildTarget(tagName)
	BuildTarget = Array(0, 0, 0, 0, tagName)
End Function

' CheckImg2 supports both mock mode and real FindPic mode
Function CheckImg2(Target)
	If USE_REAL_FINDPIC = 1 Then
		Dim Area = Target
		Dim AttachedImg = Target[5]
		Dim intX, intY
		FindPic Area[1], Area[2], Area[3], Area[4], AttachedImg, "000000", 0, REAL_FINDPIC_SIM, intX, intY
		If intX > -1 And intY > -1 Then
			CheckImg2 = Array(intX, intY)
		End If
		Exit Function
	End If

	Dim MockAttachedImg = CStr(Target[5])
	If Len(MOCK_HIT_NAME) > 0 And MockAttachedImg = MOCK_HIT_NAME Then
		CheckImg2 = Array(100, 200)
	End If
End Function

Function CheckImg2WithSim(Target, Similarity)
	Dim Area2 = Target
	Dim AttachedImg2 = Target[5]
	Dim intX2, intY2
	FindPic Area2[1], Area2[2], Area2[3], Area2[4], AttachedImg2, "000000", 0, Similarity, intX2, intY2
	If intX2 > -1 And intY2 > -1 Then
		CheckImg2WithSim = Array(intX2, intY2)
	End If
End Function

' Test-safe version: same 1-based scan logic + max rounds to avoid dead loops
Function ContinuousCheckImgTags_Test(Targets, MaxRounds)
	Dim GetImgCoord
	Dim TargetIndex
	Dim RoundIndex = 0
	Dim TargetCount = UBound(Targets) + 1

	TracePrint "[DEBUG] ContinuousCheckImgTags_Test target_count=", TargetCount, "max_rounds=", MaxRounds

	Do While true
		RoundIndex = RoundIndex + 1
		TracePrint "[DEBUG] round=", RoundIndex

		For TargetIndex = 1 To TargetCount
			If Not IsNull(Targets[TargetIndex]) Then
				TracePrint "[DEBUG] probe idx=", TargetIndex, "tag=", CStr(Targets[TargetIndex][5])
				GetImgCoord = CheckImg2(Targets[TargetIndex])
			Else
				TracePrint "[DEBUG] probe idx=", TargetIndex, "tag=<null>"
				GetImgCoord = null
			End If

			If GetImgCoord <> null Then
				TracePrint "[DEBUG] found idx=", TargetIndex, "x=", GetImgCoord[1], "y=", GetImgCoord[2]
				ContinuousCheckImgTags_Test = TargetIndex
				Exit Function
			End If
		Next

		If RoundIndex >= MaxRounds Then
			TracePrint "[DEBUG] timeout no target matched"
			ContinuousCheckImgTags_Test = 0
			Exit Function
		End If
	Loop
End Function

Sub RunRealImageDiagnostics(Targets)
	TracePrint "[REAL-DIAG] begin"
	Dim Sims = Array(0.95, 0.9, 0.85, 0.8)
	Dim TargetCount = UBound(Targets) + 1
	Dim i
	For i = 1 To TargetCount
		Dim tar = Targets[i]
		TracePrint "[REAL-DIAG] target", i, "img=", CStr(tar[5]), "area=", tar[1], tar[2], tar[3], tar[4]
		Dim j
		For j = 1 To UBound(Sims) + 1
			Dim simVal = Sims[j]
			Dim p = CheckImg2WithSim(tar, simVal)
			If p <> null Then
				TracePrint "[REAL-DIAG] hit", "idx=", i, "sim=", simVal, "x=", p[1], "y=", p[2]
			Else
				TracePrint "[REAL-DIAG] miss", "idx=", i, "sim=", simVal
			End If
		Next

		Dim expand = 80
		Dim extTar = Array(tar[1]-expand, tar[2]-expand, tar[3]+expand, tar[4]+expand, tar[5])
		Dim pExt = CheckImg2WithSim(extTar, 0.85)
		If pExt <> null Then
			TracePrint "[REAL-DIAG] hit expanded", "idx=", i, "x=", pExt[1], "y=", pExt[2], "expand=", expand
		Else
			TracePrint "[REAL-DIAG] miss expanded", "idx=", i, "expand=", expand
		End If
	Next
	TracePrint "[REAL-DIAG] end"
End Sub

Sub RunRealImageProbe()
	Dim Targets = Array(AGAIN_ALERT_AGAIN_TAR, AGAIN_ALERT_CLOSE_TAR, AGAIN_ORDEAL_NO_TICKET_TAR, AGAIN_BATTLE_OUT_MENU_TAR)
	USE_REAL_FINDPIC = 1
	TracePrint "[REAL] start real FindPic probe, sim=", REAL_FINDPIC_SIM
	Dim RealResult = ContinuousCheckImgTags_Test(Targets, 2)
	If RealResult > 0 Then
		TracePrint "[REAL] found idx=", RealResult, "img=", CStr(Targets[RealResult][5])
	Else
		TracePrint "[REAL] no target found in probe window"
		RunRealImageDiagnostics(Targets)
	End If
	USE_REAL_FINDPIC = 0
End Sub

Sub RunAllTests()
	Dim Targets = Array(AGAIN_ALERT_AGAIN_TAR, AGAIN_ALERT_CLOSE_TAR, AGAIN_ORDEAL_NO_TICKET_TAR, AGAIN_BATTLE_OUT_MENU_TAR)

	TestLog("Case 1: hit idx=1")
	MOCK_HIT_NAME = CStr(AGAIN_ALERT_AGAIN_TAR[5])
	AssertEqual "hit_idx_1", 1, ContinuousCheckImgTags_Test(Targets, 2)

	TestLog("Case 2: hit idx=3")
	MOCK_HIT_NAME = CStr(AGAIN_ORDEAL_NO_TICKET_TAR[5])
	AssertEqual "hit_idx_3", 3, ContinuousCheckImgTags_Test(Targets, 2)

	TestLog("Case 3: hit idx=4 (AGAIN_BATTLE_OUT_MENU_TAR)")
	MOCK_HIT_NAME = CStr(AGAIN_BATTLE_OUT_MENU_TAR[5])
	AssertEqual "hit_idx_4", 4, ContinuousCheckImgTags_Test(Targets, 2)

	TestLog("Case 4: no hit -> timeout 0")
	MOCK_HIT_NAME = ""
	AssertEqual "no_hit_timeout", 0, ContinuousCheckImgTags_Test(Targets, 2)

	TracePrint "[SUMMARY]", TEST_PASS, "/", TEST_TOTAL, "passed"
End Sub

RunAllTests()
RunRealImageProbe()

Log.Close
