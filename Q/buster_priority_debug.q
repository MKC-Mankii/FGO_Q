' SetScreenScale 810, 1440, 0

Log.Open

Dim WAIT_ATTACK_SCREEN = 0
Dim TAP_RESULT_CARD = 0
Dim BATTLE_ULTIMATE_DISPLAY_AWAIT_MS = 1000
Dim BUSTER_SIM = 0.9
Dim PRIORITY_SIM = 0.9
Dim HERO_MOTION_Y_TOP_PAD = 20
Dim HERO_MOTION_Y_BOTTOM_PAD = 40
Dim BUSTER_MOTION_Y_TOP_PAD = 10
Dim BUSTER_MOTION_Y_BOTTOM_PAD = 20
Dim PRIORITY_RETRY_COUNT = 6
Dim PRIORITY_RETRY_DELAY_MS = 80

Dim BATTLE_HERO_SKILL_CHECK_TAR = Array(1200, 700, 1350, 750, "Attachment:ATTACK_BTN.png")

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

Dim BATTLE_ATTACK_CARD_BUSTER_TAR = Array(55, 460, 1390, 690, "Attachment:BATTLE_ATTACK_CARD_BUSTER.png")
Dim BATTLE_ATTACK_CARD_PRIORITY_TARS = Array()
BATTLE_ATTACK_CARD_PRIORITY_TARS[1] = "Attachment:BATTLE_ATTACK_Hero_Card_okita_face.png"
BATTLE_ATTACK_CARD_PRIORITY_TARS[2] = "Attachment:BATTLE_ATTACK_Hero_Card_beni.png"
Dim BATTLE_ATTACK_CARD_PRIORITY_COUNT = 2

Dim DEBUG_HERO_CANDIDATE_TARS = Array()
DEBUG_HERO_CANDIDATE_TARS[1] = "Attachment:BATTLE_ATTACK_Hero_Card_okita.png"
DEBUG_HERO_CANDIDATE_TARS[2] = "Attachment:BATTLE_ATTACK_Hero_Card_okita_face.png"
Dim DEBUG_HERO_CANDIDATE_COUNT = 2

Function CheckImgWithSim(Target, Sim)
	Dim Area = Target
	Dim AttachedImg = Target[5]
	Dim intX, intY
	FindPic Area[1], Area[2], Area[3], Area[4], AttachedImg, "000000", 0, Sim, intX, intY
	If intX > -1 And intY > -1 Then
		CheckImgWithSim = Array(intX, intY)
	End If
End Function

Function CheckImg2(Target)
	CheckImg2 = CheckImgWithSim(Target, BUSTER_SIM)
End Function

Function CheckPriorityImg(Target)
	CheckPriorityImg = CheckImgWithSim(Target, PRIORITY_SIM)
End Function

Function CheckImgWithRetry(Target, Sim, RetryCount, RetryDelayMs)
	Dim i
	Dim GetImgCoord
	For i = 1 To RetryCount
		GetImgCoord = CheckImgWithSim(Target, Sim)
		If GetImgCoord <> null Then
			CheckImgWithRetry = Array(GetImgCoord[1], GetImgCoord[2])
			Exit Function
		End If
		If i < RetryCount Then
			Delay RetryDelayMs
		End If
	Next
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
	TracePrint "found:", GetImgCoord[1], GetImgCoord[2]
End Function

Function CheckAndTapImg2(Target, TapPoint)
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

Function PrintFindResult(Label, Target, Sim)
	Dim GetImgCoord = CheckImgWithSim(Target, Sim)
	If GetImgCoord <> null Then
		TracePrint Label, "sim", Sim, "HIT", GetImgCoord[1], GetImgCoord[2], "area", Target[1], Target[2], Target[3], Target[4], "img", Target[5]
	Else
		TracePrint Label, "sim", Sim, "MISS", "area", Target[1], Target[2], Target[3], Target[4], "img", Target[5]
	End If
End Function

Function DebugSingleTarget(Label, Target)
	PrintFindResult Label, Target, 0.95
	PrintFindResult Label, Target, 0.93
	PrintFindResult Label, Target, 0.9
	PrintFindResult Label, Target, 0.88
	PrintFindResult Label, Target, 0.85
	PrintFindResult Label, Target, 0.83
	PrintFindResult Label, Target, 0.80
	PrintFindResult Label, Target, 0.78
	PrintFindResult Label, Target, 0.75
End Function

Function BuildBusterArea(CardIdx, TopPad, BottomPad)
	Dim cx = BATTLE_ATTACK_CARD_COORDS[CardIdx][1]
	BuildBusterArea = Array(cx - 130, 460 - TopPad, cx + 130, 750 + BottomPad, "Attachment:BATTLE_ATTACK_CARD_BUSTER.png")
End Function

Function BuildHeroArea(CardIdx, HeroImg, TopPad, BottomPad)
	Dim cx = BATTLE_ATTACK_CARD_COORDS[CardIdx][1]
	BuildHeroArea = Array(cx - 100, 350 - TopPad, cx + 100, 550 + BottomPad, HeroImg)
End Function

Function CheckPriorityImgMotion(Target)
	CheckPriorityImgMotion = CheckPriorityImg(Target)
End Function

Function DebugRetryTarget(Label, Target, Sim, RetryCount, RetryDelayMs)
	Dim i
	Dim GetImgCoord
	For i = 1 To RetryCount
		GetImgCoord = CheckImgWithSim(Target, Sim)
		If GetImgCoord <> null Then
			TracePrint Label, "attempt", i, "sim", Sim, "HIT", GetImgCoord[1], GetImgCoord[2], "area", Target[1], Target[2], Target[3], Target[4], "img", Target[5]
			DebugRetryTarget = Array(GetImgCoord[1], GetImgCoord[2])
			Exit Function
		Else
			TracePrint Label, "attempt", i, "sim", Sim, "MISS", "area", Target[1], Target[2], Target[3], Target[4], "img", Target[5]
		End If
		If i < RetryCount Then
			Delay RetryDelayMs
		End If
	Next
End Function

Function DebugHeroCandidateAcrossCards(Label, HeroImg)
	Dim i
	TracePrint "==== HERO CANDIDATE", Label, HeroImg, "===="
	For i = 1 To 5
		Dim heroStd = BuildHeroArea(i, HeroImg, 0, 0)
		Dim heroMotion = BuildHeroArea(i, HeroImg, HERO_MOTION_Y_TOP_PAD, HERO_MOTION_Y_BOTTOM_PAD)
		TracePrint "-- CARD", i, "STANDARD WINDOW --"
		DebugSingleTarget Label & " CARD " & i & " STD", heroStd
		TracePrint "-- CARD", i, "MOTION WINDOW --"
		DebugSingleTarget Label & " CARD " & i & " MOTION", heroMotion
	Next
End Function

Function JoinCardIndexes(CardIndexes, CardCount)
	Dim Msg = ""
	If CardCount = 0 Then
		JoinCardIndexes = "(none)"
		Exit Function
	End If
	Dim i
	For i = 1 To CardCount
		If i > 1 Then
			Msg = Msg & ","
		End If
		Msg = Msg & CStr(CardIndexes[i])
	Next
	JoinCardIndexes = Msg
End Function

Function DebugSelectPriorityBusterCard()
	TracePrint "================ DEBUG SELECT PRIORITY BUSTER CARD ================"
	TracePrint "BUSTER_SIM =", BUSTER_SIM, "PRIORITY_SIM =", PRIORITY_SIM, "PRIORITY_COUNT =", BATTLE_ATTACK_CARD_PRIORITY_COUNT
	TracePrint "BUSTER_MOTION_PAD =", BUSTER_MOTION_Y_TOP_PAD, BUSTER_MOTION_Y_BOTTOM_PAD, "HERO_MOTION_PAD =", HERO_MOTION_Y_TOP_PAD, HERO_MOTION_Y_BOTTOM_PAD
	TracePrint "PRIORITY_RETRY =", PRIORITY_RETRY_COUNT, "times", PRIORITY_RETRY_DELAY_MS, "ms"
	TracePrint "Priority 1 =", BATTLE_ATTACK_CARD_PRIORITY_TARS[1]
	TracePrint "Priority 2 =", BATTLE_ATTACK_CARD_PRIORITY_TARS[2]

	Dim BusterCards = Array()
	Dim BusterCount = 0
	Dim i
	For i = 1 To 5
		Dim cx = BATTLE_ATTACK_CARD_COORDS[i][1]
		Dim busterArea = BuildBusterArea(i, 0, 0)
		Dim busterMotionArea = BuildBusterArea(i, BUSTER_MOTION_Y_TOP_PAD, BUSTER_MOTION_Y_BOTTOM_PAD)
		TracePrint "---- CARD", i, "BUSTER CHECK ----"
		TracePrint "STANDARD WINDOW"
		DebugSingleTarget "BUSTER CARD " & i & " STD", busterArea
		TracePrint "MOTION WINDOW"
		DebugSingleTarget "BUSTER CARD " & i & " MOTION", busterMotionArea

		Dim getBuster = CheckImg2(busterArea)
		If getBuster <> null Then
			BusterCount = BusterCount + 1
			BusterCards[BusterCount] = i
			TracePrint "BUSTER DEFAULT HIT card", i, "coord", getBuster[1], getBuster[2]
		Else
			TracePrint "BUSTER DEFAULT MISS card", i
		End If
	Next

	TracePrint "BUSTER CARD LIST =", JoinCardIndexes(BusterCards, BusterCount)

	Dim d
	For d = 1 To DEBUG_HERO_CANDIDATE_COUNT
		If DEBUG_HERO_CANDIDATE_TARS[d] <> null Then
			DebugHeroCandidateAcrossCards "CANDIDATE " & d, DEBUG_HERO_CANDIDATE_TARS[d]
		End If
	Next

	Dim p
	For p = 1 To BATTLE_ATTACK_CARD_PRIORITY_COUNT
		If BATTLE_ATTACK_CARD_PRIORITY_TARS[p] <> null Then
			TracePrint "---- PRIORITY TEMPLATE", p, BATTLE_ATTACK_CARD_PRIORITY_TARS[p], "CHECK ALL 5 CARDS ----"
			For i = 1 To 5
				cx = BATTLE_ATTACK_CARD_COORDS[i][1]
				Dim heroAreaAll = BuildHeroArea(i, BATTLE_ATTACK_CARD_PRIORITY_TARS[p], 0, 0)
				Dim heroAreaAllMotion = BuildHeroArea(i, BATTLE_ATTACK_CARD_PRIORITY_TARS[p], HERO_MOTION_Y_TOP_PAD, HERO_MOTION_Y_BOTTOM_PAD)
				TracePrint "CARD", i, "STANDARD WINDOW"
				DebugSingleTarget "PRIORITY " & p & " CARD " & i & " STD", heroAreaAll
				TracePrint "CARD", i, "MOTION WINDOW"
				DebugSingleTarget "PRIORITY " & p & " CARD " & i & " MOTION", heroAreaAllMotion
			Next
		End If
	Next

	If BusterCount = 0 Then
		TracePrint "RESULT: No Buster Card found, original logic would fallback to global Buster target"
		Exit Function
	End If

	For p = 1 To BATTLE_ATTACK_CARD_PRIORITY_COUNT
		If BATTLE_ATTACK_CARD_PRIORITY_TARS[p] <> null Then
			TracePrint "---- ORIGINAL PRIORITY LOOP", p, BATTLE_ATTACK_CARD_PRIORITY_TARS[p], "----"
			Dim b
			For b = 1 To BusterCount
				Dim cIdx = BusterCards[b]
				cx = BATTLE_ATTACK_CARD_COORDS[cIdx][1]
				Dim heroArea = BuildHeroArea(cIdx, BATTLE_ATTACK_CARD_PRIORITY_TARS[p], 0, 0)
				Dim getHero = CheckImg2(heroArea)
				If getHero <> null Then
					TracePrint "RESULT: Found Priority Buster Card", "priority", p, "card", cIdx, "coord", getHero[1], getHero[2]
					If TAP_RESULT_CARD <> 0 Then
						tap BATTLE_ATTACK_CARD_COORDS[cIdx][1], BATTLE_ATTACK_CARD_COORDS[cIdx][2]
						TracePrint "ACTION: tapped card", cIdx
					Else
						TracePrint "ACTION: TAP_RESULT_CARD = 0, not tapping"
					End If
					Exit Function
				Else
					TracePrint "ORIGINAL LOOP MISS", "priority", p, "card", cIdx, "area", heroArea[1], heroArea[2], heroArea[3], heroArea[4]
				End If
			Next
		End If
	Next

	Dim firstBusterIdx = BusterCards[1]
	TracePrint "RESULT: No priority matched, original logic would tap first Buster Card", firstBusterIdx
	If TAP_RESULT_CARD <> 0 Then
		tap BATTLE_ATTACK_CARD_COORDS[firstBusterIdx][1], BATTLE_ATTACK_CARD_COORDS[firstBusterIdx][2]
		TracePrint "ACTION: tapped fallback card", firstBusterIdx
	Else
		TracePrint "ACTION: TAP_RESULT_CARD = 0, not tapping fallback card"
	End If

	TracePrint "---- PROPOSED PRIORITY LOOP (explicit count + priority sim) ----"
	For p = 1 To BATTLE_ATTACK_CARD_PRIORITY_COUNT
		If BATTLE_ATTACK_CARD_PRIORITY_TARS[p] <> null Then
			TracePrint "---- PROPOSED PRIORITY", p, BATTLE_ATTACK_CARD_PRIORITY_TARS[p], "sim", PRIORITY_SIM, "motion window + retry ----"
			For b = 1 To BusterCount
				cIdx = BusterCards[b]
				cx = BATTLE_ATTACK_CARD_COORDS[cIdx][1]
				heroArea = BuildHeroArea(cIdx, BATTLE_ATTACK_CARD_PRIORITY_TARS[p], HERO_MOTION_Y_TOP_PAD, HERO_MOTION_Y_BOTTOM_PAD)
				Dim getHeroProposed = DebugRetryTarget("PROPOSED RETRY priority " & p & " card " & cIdx, heroArea, PRIORITY_SIM, PRIORITY_RETRY_COUNT, PRIORITY_RETRY_DELAY_MS)
				If getHeroProposed <> null Then
					TracePrint "PROPOSED RESULT: Found Priority Buster Card", "priority", p, "card", cIdx, "coord", getHeroProposed[1], getHeroProposed[2]
					If TAP_RESULT_CARD <> 0 Then
						tap BATTLE_ATTACK_CARD_COORDS[cIdx][1], BATTLE_ATTACK_CARD_COORDS[cIdx][2]
						TracePrint "ACTION: tapped proposed card", cIdx
					Else
						TracePrint "ACTION: TAP_RESULT_CARD = 0, not tapping proposed card"
					End If
					Exit Function
				Else
					TracePrint "PROPOSED LOOP MISS", "priority", p, "card", cIdx, "area", heroArea[1], heroArea[2], heroArea[3], heroArea[4]
				End If
			Next
		End If
	Next

	TracePrint "PROPOSED RESULT: No priority matched, would still fallback to first Buster Card", firstBusterIdx
End Function

TracePrint "DEBUG SCRIPT START", DateTime.Format()
TracePrint "WAIT_ATTACK_SCREEN =", WAIT_ATTACK_SCREEN, "TAP_RESULT_CARD =", TAP_RESULT_CARD, "BUSTER_SIM =", BUSTER_SIM, "PRIORITY_SIM =", PRIORITY_SIM

If WAIT_ATTACK_SCREEN <> 0 Then
	TracePrint "Waiting ATTACK button and entering card screen"
	CheckAndTapImg2(BATTLE_HERO_SKILL_CHECK_TAR, null)
	Delay BATTLE_ULTIMATE_DISPLAY_AWAIT_MS
End If

DebugSelectPriorityBusterCard()

TracePrint "DEBUG SCRIPT END", DateTime.Format()
Log.Close
