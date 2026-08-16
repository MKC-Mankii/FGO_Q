' Friend detection diagnostics for shahushan
' Purpose:
' 1) Verify each shahushan attachment can be found in friend area
' 2) Verify combined pipe-target matching behavior
' 3) Compare similarity and search-area variants

Log.Open

Dim FRIEND_AREA = Array(40, 180, 920, 800)
Dim ATT_SHAHU_SHAN_1 = "Attachment:friendShaHu1Shan.png"
Dim ATT_SHAHU_SHAN_2 = "Attachment:friendShaHu2Shan.png"
Dim ATT_SHAHU_SHAN_3 = "Attachment:friendShaHu3Shan.png"
Dim ATT_SHAHU_SHAN_PIPE = ATT_SHAHU_SHAN_1 & "|" & ATT_SHAHU_SHAN_2 & "|" & ATT_SHAHU_SHAN_3

Sub DLog(title, msg)
	TracePrint "[SHAHUSHAN-TEST]", title, msg
End Sub

Function BuildTarget(area, img)
	BuildTarget = Array(area[1], area[2], area[3], area[4], img)
End Function

Function CheckImg2WithSim(Target, Similarity)
	Dim Area = Target
	Dim AttachedImg = Target[5]
	Dim intX, intY
	FindPic Area[1], Area[2], Area[3], Area[4], AttachedImg, "000000", 0, Similarity, intX, intY
	If intX > -1 And intY > -1 Then
		CheckImg2WithSim = Array(intX, intY)
	End If
End Function

Sub ProbeTarget(Target, label)
	Dim sims = Array(0.95, 0.92, 0.9, 0.88, 0.85, 0.82, 0.8)
	Dim i
	DLog "TARGET", label & " img=" & CStr(Target[5])
	DLog "AREA", CStr(Target[1]) & "," & CStr(Target[2]) & "," & CStr(Target[3]) & "," & CStr(Target[4])
	For i = 1 To UBound(sims) + 1
		Dim simVal = sims[i]
		Dim p = CheckImg2WithSim(Target, simVal)
		If p <> null Then
			DLog "HIT", "sim=" & CStr(simVal) & " x=" & CStr(p[1]) & " y=" & CStr(p[2])
		Else
			DLog "MISS", "sim=" & CStr(simVal)
		End If
	Next
End Sub

Function ContinuousCheckImgTagsDebug(Targets, MaxRounds, Similarity)
	Dim GetImgCoord
	Dim TargetIndex
	Dim RoundIndex = 0
	Dim TargetCount = UBound(Targets) + 1

	DLog "TAGS", "target_count=" & CStr(TargetCount) & " max_rounds=" & CStr(MaxRounds) & " sim=" & CStr(Similarity)

	Do While true
		RoundIndex = RoundIndex + 1
		DLog "ROUND", CStr(RoundIndex)

		For TargetIndex = 1 To TargetCount
			Dim tar = Targets[TargetIndex]
			DLog "PROBE", "idx=" & CStr(TargetIndex) & " img=" & CStr(tar[5])
			GetImgCoord = CheckImg2WithSim(tar, Similarity)
			If GetImgCoord <> null Then
				DLog "FOUND", "idx=" & CStr(TargetIndex) & " x=" & CStr(GetImgCoord[1]) & " y=" & CStr(GetImgCoord[2])
				ContinuousCheckImgTagsDebug = TargetIndex
				Exit Function
			End If
		Next

		If RoundIndex >= MaxRounds Then
			DLog "TIMEOUT", "no target matched"
			ContinuousCheckImgTagsDebug = 0
			Exit Function
		End If

		Delay 300
	Loop
End Function

Sub RunShahuShanDiagnostics()
	DLog "BEGIN", "ShahuShan friend search diagnostics"

	Dim baseArea = FRIEND_AREA
	Dim extArea = Array(baseArea[1] - 80, baseArea[2] - 80, baseArea[3] + 80, baseArea[4] + 80)

	Dim tar1 = BuildTarget(baseArea, ATT_SHAHU_SHAN_1)
	Dim tar2 = BuildTarget(baseArea, ATT_SHAHU_SHAN_2)
	Dim tar3 = BuildTarget(baseArea, ATT_SHAHU_SHAN_3)
	Dim tarPipe = BuildTarget(baseArea, ATT_SHAHU_SHAN_PIPE)

	Dim tar1Ext = BuildTarget(extArea, ATT_SHAHU_SHAN_1)
	Dim tar2Ext = BuildTarget(extArea, ATT_SHAHU_SHAN_2)
	Dim tar3Ext = BuildTarget(extArea, ATT_SHAHU_SHAN_3)
	Dim tarPipeExt = BuildTarget(extArea, ATT_SHAHU_SHAN_PIPE)

	' A) Single-image probes in original area
	DLog "STEP", "A) single-image probe in base area"
	ProbeTarget tar1, "shahu1_base"
	ProbeTarget tar2, "shahu2_base"
	ProbeTarget tar3, "shahu3_base"

	' B) Combined pipe-image probe in original area
	DLog "STEP", "B) combined-pipe probe in base area"
	ProbeTarget tarPipe, "shahu_pipe_base"

	' C) Single-image probes in expanded area
	DLog "STEP", "C) single-image probe in expanded area"
	ProbeTarget tar1Ext, "shahu1_ext"
	ProbeTarget tar2Ext, "shahu2_ext"
	ProbeTarget tar3Ext, "shahu3_ext"

	' D) Combined pipe-image probe in expanded area
	DLog "STEP", "D) combined-pipe probe in expanded area"
	ProbeTarget tarPipeExt, "shahu_pipe_ext"

	' E) Simulate ContinuousCheckImgTags scanning order (same as production logic)
	DLog "STEP", "E) tags scan in base area at sim=0.9"
	Dim tagTargetsBase = Array(tar1, tar2, tar3)
	Dim idxBase = ContinuousCheckImgTagsDebug(tagTargetsBase, 3, 0.9)
	DLog "RESULT", "tags_base_idx=" & CStr(idxBase)

	DLog "STEP", "F) tags scan in expanded area at sim=0.85"
	Dim tagTargetsExt = Array(tar1Ext, tar2Ext, tar3Ext)
	Dim idxExt = ContinuousCheckImgTagsDebug(tagTargetsExt, 3, 0.85)
	DLog "RESULT", "tags_ext_idx=" & CStr(idxExt)

	DLog "END", "Diagnostics finished"
End Sub

RunShahuShanDiagnostics()

Log.Close
