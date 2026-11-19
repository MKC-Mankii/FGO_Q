' SetScreenScale 810, 1440, 0
' v5 DSL (v4 runner)

Log.Open

Import "zm.luae"
Import "DateTime.lua"
zm.Init

Dim CFG_ACTION_GROUP_INDEX = 0
Dim MANUAL_BATTLE_COUNT = 0
Dim MANUAL_APPLE_ENABLE = 0
Dim MANUAL_CHOOSE_FRIEND = 0
Dim MANUAL_DEBUG_SCREENSHOT_ENABLE = 0

' --- Extra 杈呭姪鍔熻兘涓庡叏灞杩愯屾ā寮 ---
Dim RUN_MODE = 0  ' 0=鎴樻湳鎴樻枟(Battle), 1=Extra杈呭姪(Extra)
Dim EXTRA_ENABLE = 0  ' 鍏煎规棫鐗堝紑鍏冲瓧娈
Dim EXTRA_ACTION_COUNT = 30  ' Extra 杩炵画鎵ц屾℃暟涓婇檺
Dim EXTRA_SKILL_MAX_LEVEL = 9  ' 鎶鑳藉己鍖栫洰鏍囦笂闄 (1~10)
Dim EXTRA_SKILL_AUTO_THREE = 1  ' 鎶鑳藉己鍖栨槸鍚﹂『搴忓己鍖3涓鎶鑳 (0=鍏, 1=寮)
Dim EXTRA_HERO_AUTO_ASCEND = 1  ' 浠庤呭己鍖栨槸鍚﹁嚜鍔ㄧ伒鍩哄啀涓 (0=鍏, 1=寮)
Dim EXTRA_HERO_AUTO_GRAIL = 1   ' 从者强化是否自动圣杯转临 (0=关, 1=100上限, 2=无上限)
Dim EXTRA_DRY_RUN = 1   ' Extra 仿真防点测试模式 (1=开启防点保护/只识别不点击, 0=正常真实点击)
Dim CURRENT_EXTRA_ACTION_NAME = ""  ' 褰撳墠姝ｅ湪鎵ц岀殑 Extra 鍔ㄤ綔绫诲瀷

Dim CFG_CONFIG_PATH = ""
Dim CFG_RAW = ""
Dim CFG_KEYS = Array()
Dim CFG_VALS = Array()
Dim CFG_ITEM_COUNT = 0
Dim CFG_PRESET = ""
Dim CFG_FRIEND = ""
Dim CFG_ACTION_INDEX = 0
Dim CFG_TEST_DSL = ""
Dim CFG_ACTIVITY_REWARD = 1

Dim BATTLE_COUNT = 0
Dim CHOOSE_FRIEND_MANUAL = 0
Dim APPLE_ENABLE = 0  ' 鏄鍚﹀悆鑻规灉琛ュ厖浣撳姏 (0=鍏/涓嶅悆, 1=閾惰嫻鏋, 2=閲戣嫻鏋)
Dim DEBUG_SCREENSHOT_ENABLE = 0
Dim DEBUG_FRIEND_ONLY = 0
Dim MANUAL_DEBUG_FRIEND_ONLY = 0
Dim ACTIVITY_REWARD = 1
Dim CAN_RUN = false

Dim HERO_CARD_OFFSET_COLOR = "202020"
Dim HERO_CARD_SIM = 0.75

Dim selectedDsl = ""
Dim selectedActivityDsl = ""
Dim selectedFriendKey = ""
Dim selectedPageTurns = 0

Dim CurrentBattleSequence = Array()
Dim AllActionRound = Array()
Dim PREPARE_FRIEND_TAR = Array()
Dim HAS_FRIEND_CONFIG = false

Dim USER_STOP_REQUESTED = false
Dim ABORT_REASON = ""
Dim CURRENT_SUB_ROUND_NUM = 0
Dim TOTAL_SUB_ROUND_NUM = 0
Dim STOP_CHECK_COUNTER = 0

Sub CfgSet(cfgKey, cfgVal)
	Dim i
	For i = 1 To CFG_ITEM_COUNT
		If CFG_KEYS(i) = cfgKey Then
			CFG_VALS(i) = cfgVal
			Exit Sub
		End If
	Next
	CFG_ITEM_COUNT = CFG_ITEM_COUNT + 1
	CFG_KEYS(CFG_ITEM_COUNT) = cfgKey
	CFG_VALS(CFG_ITEM_COUNT) = cfgVal
End Sub

Function CfgGet(cfgKey, defaultVal)
	Dim i
	For i = 1 To CFG_ITEM_COUNT
		If CFG_KEYS(i) = cfgKey Then
			CfgGet = CFG_VALS(i)
			Exit Function
		End If
	Next
	CfgGet = defaultVal
End Function

Function ParseTarget(cfgStr, defaultTar)
	If IsNull(cfgStr) Or Len(Trim(CStr(cfgStr))) = 0 Then
		ParseTarget = defaultTar
		Exit Function
	End If
	Dim s = Trim(CStr(cfgStr))
	s = Replace(s, "Array", "")
	s = Replace(s, "array", "")
	s = Replace(s, "(", "")
	s = Replace(s, ")", "")
	s = Trim(s)
	Dim parts = Split(s, ",")
	If UBound(parts) < 3 Then
		ParseTarget = defaultTar
		Exit Function
	End If
	Dim x1 = Int(Trim(parts(0)))
	Dim y1 = Int(Trim(parts(1)))
	Dim x2 = Int(Trim(parts(2)))
	Dim y2 = Int(Trim(parts(3)))
	Dim imgPart = ""
	If UBound(parts) >= 4 Then
		Dim pIdx
		For pIdx = 4 To UBound(parts)
			If Len(imgPart) > 0 Then
				imgPart = imgPart & "," & parts(pIdx)
			Else
				imgPart = parts(pIdx)
			End If
		Next
		imgPart = Trim(imgPart)
		If Left(imgPart, 1) = Chr(34) Then
			imgPart = Mid(imgPart, 2, Len(imgPart) - 1)
		End If
		If Right(imgPart, 1) = Chr(34) Then
			imgPart = Left(imgPart, Len(imgPart) - 1)
		End If
		imgPart = Trim(imgPart)
	End If
	ParseTarget = Array(x1, y1, x2, y2, imgPart)
End Function

Function ParseCoord(cfgStr, defaultCoord)
	If IsNull(cfgStr) Or Len(Trim(CStr(cfgStr))) = 0 Then
		ParseCoord = defaultCoord
		Exit Function
	End If
	Dim s = Trim(CStr(cfgStr))
	s = Replace(s, "Array", "")
	s = Replace(s, "array", "")
	s = Replace(s, "(", "")
	s = Replace(s, ")", "")
	s = Trim(s)
	Dim parts = Split(s, ",")
	If UBound(parts) < 1 Then
		ParseCoord = defaultCoord
		Exit Function
	End If
	Dim x = Int(Trim(parts(0)))
	Dim y = Int(Trim(parts(1)))
	ParseCoord = Array(x, y)
End Function

Function PickActionIndexByGroup(groupIndex)
	Dim groupIndexVal = Int(CfgGet("action_round_index_g" & groupIndex, "0"))
	If groupIndexVal > 0 Then
		PickActionIndexByGroup = groupIndexVal
	Else
		PickActionIndexByGroup = Int(CfgGet("action_round_index", "0"))
	End If
End Function

Function PickActivityRewardByGroupAndIndex(groupIndex, actionIndex)
	Dim val = CStr(CfgGet("activity_reward_g" & groupIndex & "_" & actionIndex, ""))
	If Len(val) > 0 Then
		PickActivityRewardByGroupAndIndex = Int(val)
	Else
		Dim gVal = CStr(CfgGet("activity_reward_g" & groupIndex, ""))
		If Len(gVal) > 0 Then
			PickActivityRewardByGroupAndIndex = Int(gVal)
		Else
			PickActivityRewardByGroupAndIndex = Int(CfgGet("activity_reward", "0"))
		End If
	End If
End Function

Function BuildRoundsFromFlatText(flatText)
	Dim outRounds = Array()
	Dim outIndex = 1
	Dim rawRounds = Split(CStr(flatText), ";")
	Dim oneRound
	For Each oneRound In rawRounds
		oneRound = Trim(CStr(oneRound))
		If Len(oneRound) > 0 Then
			outRounds(outIndex) = oneRound
			outIndex = outIndex + 1
		End If
	Next
	BuildRoundsFromFlatText = outRounds
End Function

Function PickFriendByGroup(groupIndex)
	PickFriendByGroup = CStr(CfgGet("friend_g" & groupIndex, ""))
End Function

Function PickFriendByGroupAndIndex(groupIndex, roundIndex)
	PickFriendByGroupAndIndex = CStr(CfgGet("friend_g" & groupIndex & "_" & roundIndex, ""))
End Function

Function PickPageTurnsByGroup(groupIndex)
	PickPageTurnsByGroup = CInt(CfgGet("page_turns_g" & groupIndex, 0))
End Function

Function PickPageTurnsByGroupAndIndex(groupIndex, roundIndex)
	PickPageTurnsByGroupAndIndex = CInt(CfgGet("page_turns_g" & groupIndex & "_" & roundIndex, CfgGet("page_turns_g" & groupIndex, 0)))
End Function

Function ParseBattleSequence(sequenceArray)
	Dim finalRounds = Array()
	Dim roundIndex = 1
	For Each roundStr In sequenceArray
		Dim groupStrs = Split(roundStr, "|")
		Dim roundGroups = Array()
		Dim groupIndex = 1
		For Each groupStr In groupStrs
			Dim acts = Split(Trim(groupStr), ",")
			Dim actGroup = Array()
			Dim actIndex = 1
			For Each act In acts
				act = Trim(act)
				If actIndex = 1 Then
					Dim prefix = LCase(Mid(act, 1, 1))
					If prefix = "s" Then
						actGroup[1] = "skill"
					ElseIf prefix = "a" Then
						actGroup[1] = "attack"
					ElseIf prefix = "m" Then
						actGroup[1] = "master"
					ElseIf prefix = "t" Then
						actGroup[1] = "target"
					End If
				End If
				
				Dim valStr = ""
				Dim firstChar = LCase(Mid(act, 1, 1))
				If actIndex = 1 And (firstChar = "s" Or firstChar = "a" Or firstChar = "m" Or firstChar = "t") Then
					valStr = Mid(act, 2, Len(act) - 1)
				Else
					valStr = act
				End If
				
				valStr = UCase(Trim(valStr))
				If actIndex = 1 And Len(valStr) = 0 Then
					' 绾鍓嶇紑鏍囪瘑濡 "a", "s", "m", "t"锛屾棤闇璁板綍鍙傛暟鍊硷紝涓嶆帹杩涘姩浣滅储寮
				Else
					If valStr = "B" Then
						actGroup[actIndex + 1] = "B"
					ElseIf valStr = "A" Then
						actGroup[actIndex + 1] = "A"
					ElseIf valStr = "Q" Then
						actGroup[actIndex + 1] = "Q"
					ElseIf IsNumeric(valStr) Then
						actGroup[actIndex + 1] = CInt(valStr)
					Else
						actGroup[actIndex + 1] = valStr
					End If
					actIndex = actIndex + 1
				End If
			Next
			roundGroups[groupIndex] = actGroup
			groupIndex = groupIndex + 1
		Next
		finalRounds[roundIndex] = roundGroups
		roundIndex = roundIndex + 1
	Next
	ParseBattleSequence = finalRounds
End Function

Function PickDslByGroupAndIndex(groupIndex, roundIndex)
	Dim dslVal = CStr(CfgGet("dsl_g" & groupIndex & "_" & roundIndex, ""))
	If Len(dslVal) = 0 Then
		dslVal = CStr(CfgGet("test_dsl_g" & groupIndex & "_" & roundIndex, ""))
	End If
	PickDslByGroupAndIndex = dslVal
End Function

' 鐘舵佸啓鍏ヤ笌蹇冭烦涓婃姤
Sub UpdateRunnerStatus(stateText, actionText)
	Dim statusPath = "/sdcard/FGO_Q/status.txt"
	Dim roundStr = ""
	Dim totalStr = ""
	Dim modeStr = "BATTLE"
	If RUN_MODE = 1 Then
		modeStr = "EXTRA"
	End If
	If stateText <> "IDLE" Or CurrentBattleCount > 0 Then
		roundStr = CStr(CurrentBattleCount)
		If RUN_MODE = 1 Then
			totalStr = CStr(EXTRA_ACTION_COUNT)
		Else
			totalStr = CStr(BATTLE_COUNT)
		End If
	End If
	Dim content = "state=" & stateText & Chr(10) & _
	              "mode=" & modeStr & Chr(10) & _
	              "round=" & roundStr & Chr(10) & _
	              "total_rounds=" & totalStr & Chr(10) & _
	              "sub_round=" & CURRENT_SUB_ROUND_NUM & Chr(10) & _
	              "total_sub_rounds=" & TOTAL_SUB_ROUND_NUM & Chr(10) & _
	              "action=" & actionText & Chr(10) & _
	              "time=" & DateTime.Format() & Chr(10) & _
	              "msg=" & actionText
	zm.FileWrite statusPath, content
End Sub

' 妫鏌ョ綉椤电鏄鍚︿笅鍙戜簡鍋滄㈡寚浠
' 娉锛歁ainStandbyLoop 鐩存帴璇诲彇 cmd.txt锛屾湰鍑芥暟浠呭湪鎴樻枟杩涜屼腑琚鍚勫惊鐜璋冪敤
Function CheckStopSignal()
	If USER_STOP_REQUESTED Then
		CheckStopSignal = true
		Exit Function
	End If
	' 闄嶄綆鏂囦欢杞璇锛氭瘡 4 娆¤皟鐢ㄦ墠鐪熷疄璇讳竴娆 cmd.txt锛堢害 2s 闂撮殧锛夛紝鍑忓皯 IO 璐熸媴
	STOP_CHECK_COUNTER = STOP_CHECK_COUNTER + 1
	If STOP_CHECK_COUNTER Mod 4 <> 0 Then
		CheckStopSignal = false
		Exit Function
	End If
	Dim cmdPath = "/sdcard/FGO_Q/cmd.txt"
	If Dir.Exist(cmdPath) = 1 Then
		Dim rawCmd = zm.FileRead(cmdPath)
		If Not IsNull(rawCmd) And Len(CStr(rawCmd)) > 0 Then
			Dim cmdText = UCase(Trim(CStr(rawCmd)))
			If cmdText = "STOP" Then
				TracePrint ">>> RECEIVED STOP COMMAND FROM WEB <<<"
				USER_STOP_REQUESTED = true
				ABORT_REASON = "鏀跺埌缃戦〉鍋滄㈡寚浠"
				zm.FileWrite cmdPath, ""
				UpdateRunnerStatus "STOPPING", "鏀跺埌缃戦〉鍋滄㈡寚浠"
				CheckStopSignal = true
				Exit Function
			End If
		End If
	End If
	CheckStopSignal = false
End Function

Sub AbortBattle(reasonText)
	TracePrint ">>> BATTLE ABORTED: " & reasonText & " <<<"
	ABORT_REASON = reasonText
	USER_STOP_REQUESTED = true
	BATTLE_ENDED_EARLY = true
	HasTicket = false
	UpdateRunnerStatus "IDLE", reasonText
End Sub

' BASIC CONFIG
' CONST
Dim NEED_REVERSE = true
Dim COLOR_SIM = 0.95

' PREPARE
Dim ATT_Aobao = "Attachment:friendAobao1.png|Attachment:friendAobao2.png|Attachment:friendAobao3.png|Attachment:friendAobao5.png"
Dim ATT_AobaoShan = "Attachment:friendAobao3Shan.png"
Dim ATT_CDai = "Attachment:friendCDai.png|Attachment:friendCDai2.png|Attachment:friendCDai3.png"
Dim ATT_DaoMan = "Attachment:friendDaoMan.png|Attachment:DaoMan.png|Attachment:friendDaoMan3.png"
Dim ATT_Cba = "Attachment:friendCba.png"
Dim ATT_RBA = "Attachment:friendRba1.png|Attachment:friendRba2.png|Attachment:friendRba3.png|Attachment:friendRba4.png"
Dim ATT_RBAShan = "Attachment:friendRba3Shan.png"
Dim ATT_Shahu = "Attachment:friendShaHu1.png|Attachment:friendShaHu2.png|Attachment:friendShaHu3.png"
Dim ATT_ShahuShan = "Attachment:friendShaHuShan1.png|Attachment:friendShaHuShan2.png|Attachment:friendShaHuShan3.png"
Dim ATT_MeilinC = "Attachment:friendMeilinC3.png"
Dim ATT_Taigong = "Attachment:friendtaigong.png"
Dim ATT_Princess = "Attachment:friendPrincess.png|Attachment:friendPrincess2.png|Attachment:friendPrincess3.png"
Dim ATT_Princess120 = "Attachment:friendPrincess120.png|Attachment:friendPrincess1202.png|Attachment:friendPrincess1203.png"
Dim ATT_QP = "Attachment:friendQP.png"
Dim ATT_Sparrow = "Attachment:friendSparrow.png"
Dim ATT_Mary = "Attachment:friendMary1.png|Attachment:friendMary2.png|Attachment:friendMary3.png"
Dim ATT_Keli = "Attachment:friendKeli1.png|Attachment:friendKeli2.png|Attachment:friendKeli3.png"
Dim ATT_Heshang = "Attachment:friendHeshang3.png"

' 闁板秶鐤嗛悜闁插秷娴囬崙鑺ユ殶閿涙碍鐦″▎鈩冩暪閸 START 閹稿洣鎶ら弮鍫曞櫢閺傛澘濮炴潪鑺ユ付閺備即鍘ょ純
Sub ApplyConfigTargets()
	' 0. Base screen size
	SCREEN_BASE_W = Int(CfgGet("screen_base_w", CStr(SCREEN_BASE_W)))
	SCREEN_BASE_H = Int(CfgGet("screen_base_h", CStr(SCREEN_BASE_H)))

	' 1. START
	START_TAR = ParseTarget(CfgGet("start_tar", CfgGet("start_btn", "")), START_TAR)
	START_TAPED_DELAY = Int(CfgGet("start_taped_delay", CStr(START_TAPED_DELAY)))

	' 2. BATTLE HERO SKILL
	BATTLE_HERO_SKILL_CHECK_TAR = ParseTarget(CfgGet("battle_hero_skill_check_tar", CfgGet("battle_hero_skill_check", "")), BATTLE_HERO_SKILL_CHECK_TAR)
	BATTLE_HERO_SKILL_COORDS = Array(_
		ParseCoord(CfgGet("tap_hero_skill_1_1", ""), BATTLE_HERO_SKILL_COORDS[1]),_
		ParseCoord(CfgGet("tap_hero_skill_1_2", ""), BATTLE_HERO_SKILL_COORDS[2]),_
		ParseCoord(CfgGet("tap_hero_skill_1_3", ""), BATTLE_HERO_SKILL_COORDS[3]),_
		ParseCoord(CfgGet("tap_hero_skill_2_1", ""), BATTLE_HERO_SKILL_COORDS[4]),_
		ParseCoord(CfgGet("tap_hero_skill_2_2", ""), BATTLE_HERO_SKILL_COORDS[5]),_
		ParseCoord(CfgGet("tap_hero_skill_2_3", ""), BATTLE_HERO_SKILL_COORDS[6]),_
		ParseCoord(CfgGet("tap_hero_skill_3_1", ""), BATTLE_HERO_SKILL_COORDS[7]),_
		ParseCoord(CfgGet("tap_hero_skill_3_2", ""), BATTLE_HERO_SKILL_COORDS[8]),_
		ParseCoord(CfgGet("tap_hero_skill_3_3", ""), BATTLE_HERO_SKILL_COORDS[9])_
	)

	' 3. SKILL GRANT
	BATTLE_SKILL_GRANT_CHECK_TAR = ParseTarget(CfgGet("battle_skill_grant_check_tar", CfgGet("battle_skill_grant_check", "")), BATTLE_SKILL_GRANT_CHECK_TAR)
	BATTLE_SKILL_GRANT_HREO_COORDS = Array(_
		ParseCoord(CfgGet("tap_skill_grant_hero_1", ""), BATTLE_SKILL_GRANT_HREO_COORDS[1]),_
		ParseCoord(CfgGet("tap_skill_grant_hero_2", ""), BATTLE_SKILL_GRANT_HREO_COORDS[2]),_
		ParseCoord(CfgGet("tap_skill_grant_hero_3", ""), BATTLE_SKILL_GRANT_HREO_COORDS[3])_
	)

	' 4. SKILL CHANGE
	BATTLE_SKILL_CHANGE_CHECK_TAR = ParseTarget(CfgGet("battle_skill_change_check_tar", CfgGet("battle_skill_change_check", "")), BATTLE_SKILL_CHANGE_CHECK_TAR)
	BATTLE_SKILL_CHANGE_SELECTEED_CHECK_TAR = ParseTarget(CfgGet("battle_skill_change_selecteed_check_tar", CfgGet("battle_skill_change_selecteed_check", "")), BATTLE_SKILL_CHANGE_SELECTEED_CHECK_TAR)
	BATTLE_SKILL_CHANGE_SELECTED_AWAIT_MS = Int(CfgGet("battle_skill_change_selected_await_ms", CStr(BATTLE_SKILL_CHANGE_SELECTED_AWAIT_MS)))
	BATTLE_SKILL_CHANGE_HERO_COORDS = Array(_
		ParseCoord(CfgGet("tap_skill_change_front_1", ""), BATTLE_SKILL_CHANGE_HERO_COORDS[1]),_
		ParseCoord(CfgGet("tap_skill_change_front_2", ""), BATTLE_SKILL_CHANGE_HERO_COORDS[2]),_
		ParseCoord(CfgGet("tap_skill_change_front_3", ""), BATTLE_SKILL_CHANGE_HERO_COORDS[3]),_
		ParseCoord(CfgGet("tap_skill_change_back_1", ""), BATTLE_SKILL_CHANGE_HERO_COORDS[4]),_
		ParseCoord(CfgGet("tap_skill_change_back_2", ""), BATTLE_SKILL_CHANGE_HERO_COORDS[5]),_
		ParseCoord(CfgGet("tap_skill_change_back_3", ""), BATTLE_SKILL_CHANGE_HERO_COORDS[6])_
	)

	' 5. SPECIAL SKILL A
	BATTLE_SKILL_SPECIAL_SKILL_A_TAR = ParseTarget(CfgGet("battle_skill_special_skill_a_tar", CfgGet("battle_skill_special_skill_a", "")), BATTLE_SKILL_SPECIAL_SKILL_A_TAR)
	BATTLE_SKILL_SPECIAL_SKILL_A_ACT_TARS(3) = ParseCoord(CfgGet("tap_skill_special_skill_a_act_3", ""), BATTLE_SKILL_SPECIAL_SKILL_A_ACT_TARS(3))

	' 6. MASTER SKILLS
	BATTLE_MASTER_SKILL_OPEN_TAR = ParseTarget(CfgGet("battle_master_skill_open_tar", CfgGet("battle_master_skill_open", "")), BATTLE_MASTER_SKILL_OPEN_TAR)
	BATTLE_MASTER_SKILL_DISPLAY_TAR = ParseTarget(CfgGet("battle_master_skill_display_tar", CfgGet("battle_master_skill_display", "")), BATTLE_MASTER_SKILL_DISPLAY_TAR)
	BATTLE_MASTER_SKILL_OPEN_COORDS = ParseCoord(CfgGet("tap_master_skill_open", CfgGet("battle_master_skill_open_coords", "")), BATTLE_MASTER_SKILL_OPEN_COORDS)
	BATTLE_MASTER_SKILL_COORDS = Array(_
		ParseCoord(CfgGet("tap_master_skill_1", ""), BATTLE_MASTER_SKILL_COORDS[1]),_
		ParseCoord(CfgGet("tap_master_skill_2", ""), BATTLE_MASTER_SKILL_COORDS[2]),_
		ParseCoord(CfgGet("tap_master_skill_3", ""), BATTLE_MASTER_SKILL_COORDS[3])_
	)
	BATTLE_MASTER_SKILL_AWAIT_MS = Int(CfgGet("battle_master_skill_await_ms", CStr(BATTLE_MASTER_SKILL_AWAIT_MS)))

	' 7. SKILL ANIMATION & SPEEDUP
	BATTLE_SKILL_SPEEDUP_COORD = ParseCoord(CfgGet("battle_skill_speedup_coord", ""), BATTLE_SKILL_SPEEDUP_COORD)
	BATTLE_SKILL_SPEEDUP_AWAIT_MS = Int(CfgGet("battle_skill_speedup_await_ms", CStr(BATTLE_SKILL_SPEEDUP_AWAIT_MS)))
	BATTLE_SKILL_NORMAL_AWAIT_MS = Int(CfgGet("battle_skill_normal_await_ms", CStr(BATTLE_SKILL_NORMAL_AWAIT_MS)))

	' 8. ENEMY TARGET
	BATTLE_TARGET_COORDS = Array(_
		ParseCoord(CfgGet("tap_target_enemy_1", ""), BATTLE_TARGET_COORDS[1]),_
		ParseCoord(CfgGet("tap_target_enemy_2", ""), BATTLE_TARGET_COORDS[2]),_
		ParseCoord(CfgGet("tap_target_enemy_3", ""), BATTLE_TARGET_COORDS[3]),_
		ParseCoord(CfgGet("tap_target_enemy_4", ""), BATTLE_TARGET_COORDS[4]),_
		ParseCoord(CfgGet("tap_target_enemy_5", ""), BATTLE_TARGET_COORDS[5]),_
		ParseCoord(CfgGet("tap_target_enemy_6", ""), BATTLE_TARGET_COORDS[6])_
	)

	' 9. ATTACK & CARDS
	BATTLE_ATTACK_BACK_TAR = ParseTarget(CfgGet("battle_attack_back_tar", CfgGet("battle_attack_back", "")), BATTLE_ATTACK_BACK_TAR)
	BATTLE_ATTACK_CARD_BUSTER_TAR = ParseTarget(CfgGet("battle_attack_card_buster_tar", CfgGet("battle_attack_card_buster", "")), BATTLE_ATTACK_CARD_BUSTER_TAR)
	BATTLE_ATTACK_CARD_ARTS_TAR = ParseTarget(CfgGet("battle_attack_card_arts_tar", CfgGet("battle_attack_card_arts", "")), BATTLE_ATTACK_CARD_ARTS_TAR)
	BATTLE_ATTACK_CARD_QUICK_TAR = ParseTarget(CfgGet("battle_attack_card_quick_tar", CfgGet("battle_attack_card_quick", "")), BATTLE_ATTACK_CARD_QUICK_TAR)

	' 9.1 HERO NP FACE SAMPLING TARS
	BATTLE_HERO_NP_FACE_1_TAR = ParseTarget(CfgGet("battle_hero_np_face_1_tar", CfgGet("battle_hero_np_face_1", "")), BATTLE_HERO_NP_FACE_1_TAR)
	BATTLE_HERO_NP_FACE_2_TAR = ParseTarget(CfgGet("battle_hero_np_face_2_tar", CfgGet("battle_hero_np_face_2", "")), BATTLE_HERO_NP_FACE_2_TAR)
	BATTLE_HERO_NP_FACE_3_TAR = ParseTarget(CfgGet("battle_hero_np_face_3_tar", CfgGet("battle_hero_np_face_3", "")), BATTLE_HERO_NP_FACE_3_TAR)

	' 9.2 HERO HAND CARD PORTRAIT SEARCH RECTS
	BATTLE_HERO_CARD_AREA_1_TAR = ParseTarget(CfgGet("battle_hero_card_area_1_tar", CfgGet("battle_hero_card_area_1", "")), BATTLE_HERO_CARD_AREA_1_TAR)
	BATTLE_HERO_CARD_AREA_2_TAR = ParseTarget(CfgGet("battle_hero_card_area_2_tar", CfgGet("battle_hero_card_area_2", "")), BATTLE_HERO_CARD_AREA_2_TAR)
	BATTLE_HERO_CARD_AREA_3_TAR = ParseTarget(CfgGet("battle_hero_card_area_3_tar", CfgGet("battle_hero_card_area_3", "")), BATTLE_HERO_CARD_AREA_3_TAR)
	BATTLE_HERO_CARD_AREA_4_TAR = ParseTarget(CfgGet("battle_hero_card_area_4_tar", CfgGet("battle_hero_card_area_4", "")), BATTLE_HERO_CARD_AREA_4_TAR)
	BATTLE_HERO_CARD_AREA_5_TAR = ParseTarget(CfgGet("battle_hero_card_area_5_tar", CfgGet("battle_hero_card_area_5", "")), BATTLE_HERO_CARD_AREA_5_TAR)

	' 9.3 CRIT 100% DETECTION TARS
	BATTLE_CRIT_100_AREA_1_TAR = ParseTarget(CfgGet("battle_crit_100_area_1_tar", CfgGet("battle_crit_100_area_1", "")), BATTLE_CRIT_100_AREA_1_TAR)
	BATTLE_CRIT_100_AREA_2_TAR = ParseTarget(CfgGet("battle_crit_100_area_2_tar", CfgGet("battle_crit_100_area_2", "")), BATTLE_CRIT_100_AREA_2_TAR)
	BATTLE_CRIT_100_AREA_3_TAR = ParseTarget(CfgGet("battle_crit_100_area_3_tar", CfgGet("battle_crit_100_area_3", "")), BATTLE_CRIT_100_AREA_3_TAR)
	BATTLE_CRIT_100_AREA_4_TAR = ParseTarget(CfgGet("battle_crit_100_area_4_tar", CfgGet("battle_crit_100_area_4", "")), BATTLE_CRIT_100_AREA_4_TAR)
	BATTLE_CRIT_100_AREA_5_TAR = ParseTarget(CfgGet("battle_crit_100_area_5_tar", CfgGet("battle_crit_100_area_5", "")), BATTLE_CRIT_100_AREA_5_TAR)
	BATTLE_ATTACK_CARD_100_TAR = ParseTarget(CfgGet("battle_attack_card_100_tar", CfgGet("battle_attack_card_100", "")), BATTLE_ATTACK_CARD_100_TAR)

	HERO_CARD_OFFSET_COLOR = CStr(CfgGet("hero_card_offset_color", "202020"))
	HERO_CARD_SIM = CDbl(CfgGet("hero_card_sim", "0.75"))

	Dim customHeroTar1 = CfgGet("battle_attack_hero_1_tar", CfgGet("hero_card_tar_1", ""))
	If Len(customHeroTar1) > 0 Then
		BATTLE_ATTACK_CARD_PRIORITY_TARS[1] = customHeroTar1
		If BATTLE_ATTACK_CARD_PRIORITY_COUNT < 1 Then BATTLE_ATTACK_CARD_PRIORITY_COUNT = 1
	End If
	Dim customHeroTar2 = CfgGet("battle_attack_hero_2_tar", CfgGet("hero_card_tar_2", ""))
	If Len(customHeroTar2) > 0 Then
		BATTLE_ATTACK_CARD_PRIORITY_TARS[2] = customHeroTar2
		If BATTLE_ATTACK_CARD_PRIORITY_COUNT < 2 Then BATTLE_ATTACK_CARD_PRIORITY_COUNT = 2
	End If
	Dim customHeroTar3 = CfgGet("battle_attack_hero_3_tar", CfgGet("hero_card_tar_3", ""))
	If Len(customHeroTar3) > 0 Then
		BATTLE_ATTACK_CARD_PRIORITY_TARS[3] = customHeroTar3
		If BATTLE_ATTACK_CARD_PRIORITY_COUNT < 3 Then BATTLE_ATTACK_CARD_PRIORITY_COUNT = 3
	End If

	BATTLE_ATTACK_CARD_COORDS = Array(_
		ParseCoord(CfgGet("tap_card_normal_1", ""), BATTLE_ATTACK_CARD_COORDS[1]),_
		ParseCoord(CfgGet("tap_card_normal_2", ""), BATTLE_ATTACK_CARD_COORDS[2]),_
		ParseCoord(CfgGet("tap_card_normal_3", ""), BATTLE_ATTACK_CARD_COORDS[3]),_
		ParseCoord(CfgGet("tap_card_normal_4", ""), BATTLE_ATTACK_CARD_COORDS[4]),_
		ParseCoord(CfgGet("tap_card_normal_5", ""), BATTLE_ATTACK_CARD_COORDS[5]),_
		ParseCoord(CfgGet("tap_card_np_1", ""), BATTLE_ATTACK_CARD_COORDS[6]),_
		ParseCoord(CfgGet("tap_card_np_2", ""), BATTLE_ATTACK_CARD_COORDS[7]),_
		ParseCoord(CfgGet("tap_card_np_3", ""), BATTLE_ATTACK_CARD_COORDS[8])_
	)

	BATTLE_ATTACK_CARD_FIRST_TAPED_TARS(3) = ParseTarget(CfgGet("battle_attack_card_3_first_taped_tar", CfgGet("battle_attack_card_3_first_taped", "")), BATTLE_ATTACK_CARD_FIRST_TAPED_TARS(3))
	BATTLE_ATTACK_CARD_FIRST_TAPED_TARS(6) = ParseTarget(CfgGet("battle_attack_card_6_first_taped_tar", ""), BATTLE_ATTACK_CARD_FIRST_TAPED_TARS(6))
	BATTLE_ATTACK_CARD_FIRST_TAPED_TARS(7) = ParseTarget(CfgGet("battle_attack_card_7_first_taped_tar", ""), BATTLE_ATTACK_CARD_FIRST_TAPED_TARS(7))
	BATTLE_ATTACK_CARD_FIRST_TAPED_TARS(8) = ParseTarget(CfgGet("battle_attack_card_8_first_taped_tar", ""), BATTLE_ATTACK_CARD_FIRST_TAPED_TARS(8))

	BATTLE_ATTACK_CARD_SECON_TAPED_TARS(4) = ParseTarget(CfgGet("battle_attack_card_4_second_taped_tar", CfgGet("battle_attack_card_4_second_taped", "")), BATTLE_ATTACK_CARD_SECON_TAPED_TARS(4))
	BATTLE_ATTACK_CARD_SECON_TAPED_TARS(6) = ParseTarget(CfgGet("battle_attack_card_6_second_taped_tar", CfgGet("battle_attack_card_6_second_taped", "")), BATTLE_ATTACK_CARD_SECON_TAPED_TARS(6))
	BATTLE_ATTACK_CARD_SECON_TAPED_TARS(7) = ParseTarget(CfgGet("battle_attack_card_7_second_taped_tar", CfgGet("battle_attack_card_7_second_taped", "")), BATTLE_ATTACK_CARD_SECON_TAPED_TARS(7))
	BATTLE_ATTACK_CARD_SECON_TAPED_TARS(8) = ParseTarget(CfgGet("battle_attack_card_8_second_taped_tar", CfgGet("battle_attack_card_8_second_taped", "")), BATTLE_ATTACK_CARD_SECON_TAPED_TARS(8))

	BATTLE_ULTIMATE_DISPLAY_AWAIT_MS = Int(CfgGet("battle_ultimate_display_await_ms", CStr(BATTLE_ULTIMATE_DISPLAY_AWAIT_MS)))
	BATTLE_CARD_TAPED_AWAIT_MS = Int(CfgGet("battle_card_taped_await_ms", CStr(BATTLE_CARD_TAPED_AWAIT_MS)))
	BATTLE_ROUND_CHANGE_AWAIT_MS = Int(CfgGet("battle_round_change_await_ms", CStr(BATTLE_ROUND_CHANGE_AWAIT_MS)))
	BATTLE_NORMAL_ATTACK_PLAY_AWAIT_MS = Int(CfgGet("battle_normal_attack_play_await_ms", CStr(BATTLE_NORMAL_ATTACK_PLAY_AWAIT_MS)))
	BATTLE_ULTIMATE_PLAY_1_AWAIT_MS = Int(CfgGet("battle_ultimate_play_1_await_ms", CStr(BATTLE_ULTIMATE_PLAY_1_AWAIT_MS)))
	BATTLE_ULTIMATE_PLAY_2_AWAIT_MS = Int(CfgGet("battle_ultimate_play_2_await_ms", CStr(BATTLE_ULTIMATE_PLAY_2_AWAIT_MS)))
	BATTLE_LAST_ROUND_END_AWAIT_MS = Int(CfgGet("battle_last_round_end_await_ms", CStr(BATTLE_LAST_ROUND_END_AWAIT_MS)))
	BATTLE_ULTIMATE_PLAY_LAST_AWAIT_MS = Int(CfgGet("battle_ultimate_play_last_await_ms", CStr(BATTLE_ULTIMATE_PLAY_LAST_AWAIT_MS)))

	' 10. AWARD & REWARD
	AWARD_TIE_TAR = ParseTarget(CfgGet("award_tie_tar", CfgGet("award_tie", "")), AWARD_TIE_TAR)
	AWARD_TIE_UP_TAR = ParseTarget(CfgGet("award_tie_up_tar", CfgGet("award_tie_up", "")), AWARD_TIE_UP_TAR)
	AWARD_TAP_COORD = ParseCoord(CfgGet("tap_award_skip", CfgGet("award_tap_coord", "")), AWARD_TAP_COORD)
	AWARD_TREASURE_NEXT_TAR = ParseTarget(CfgGet("award_treasure_next_tar", CfgGet("award_treasure_next", "")), AWARD_TREASURE_NEXT_TAR)
	AWARD_ACTIVITY_NEXT_TAR = ParseTarget(CfgGet("award_activity_next_tar", CfgGet("award_activity_next", "")), AWARD_ACTIVITY_NEXT_TAR)
	AWARD_NORMAL_TAP_AWAIT_MS = Int(CfgGet("award_normal_tap_await_ms", CStr(AWARD_NORMAL_TAP_AWAIT_MS)))
	BEFORE_ACTIVITY_AWAIT_MS = Int(CfgGet("before_activity_await_ms", CStr(BEFORE_ACTIVITY_AWAIT_MS)))

	' 11. ADD FRIEND & AGAIN
	ADD_FRIEND_TAR = ParseTarget(CfgGet("add_friend_tar", CfgGet("add_friend_close", "")), ADD_FRIEND_TAR)
	ADD_FRIEND_CHECK_AWAIT_MS = Int(CfgGet("add_friend_check_await_ms", CStr(ADD_FRIEND_CHECK_AWAIT_MS)))
	AGAIN_ALERT_AGAIN_TAR = ParseTarget(CfgGet("again_alert_again_tar", CfgGet("again_alert_again", "")), AGAIN_ALERT_AGAIN_TAR)
	AGAIN_ALERT_CLOSE_TAR = ParseTarget(CfgGet("again_alert_close_tar", CfgGet("again_alert_close", "")), AGAIN_ALERT_CLOSE_TAR)
	AGAIN_ORDEAL_NO_TICKET_TAR = ParseTarget(CfgGet("again_ordeal_no_ticket_tar", CfgGet("again_ordeal_no_ticket", "")), AGAIN_ORDEAL_NO_TICKET_TAR)
	AGAIN_BATTLE_OUT_MENU_TAR = ParseTarget(CfgGet("again_battle_out_menu_tar", CfgGet("again_battle_out_menu", "")), AGAIN_BATTLE_OUT_MENU_TAR)

	' 12. APPLE
	APPLE_DISPLAY_TAR = ParseTarget(CfgGet("apple_display_tar", CfgGet("apple_display", "")), APPLE_DISPLAY_TAR)
	APPLE_CONFIRM_TAR = ParseTarget(CfgGet("apple_confirm_tar", CfgGet("apple_confirm", "")), APPLE_CONFIRM_TAR)
	APPLE_CONFIRM_COORD = ParseCoord(CfgGet("tap_apple_confirm", CfgGet("apple_confirm_coord", "")), APPLE_CONFIRM_COORD)
	APPLE_GLODEN_COORD = ParseCoord(CfgGet("tap_apple_golden", CfgGet("apple_gloden_coord", "")), APPLE_GLODEN_COORD)
	APPLE_SILVER_COORD = ParseCoord(CfgGet("tap_apple_silver", CfgGet("apple_silver_coord", "")), APPLE_SILVER_COORD)
	APPLE_CLOSE_COORD = ParseCoord(CfgGet("tap_apple_close", CfgGet("apple_close_coord", "")), APPLE_CLOSE_COORD)
	APPLE_CHECK_AWAIT_MS = Int(CfgGet("apple_check_await_ms", CStr(APPLE_CHECK_AWAIT_MS)))

	' 13. FRIEND PREPARE
	PREPARE_FRIEND_EQUIP_TAR = ParseTarget(CfgGet("prepare_friend_equip_tar", CfgGet("friend_equip_goodness", "")), PREPARE_FRIEND_EQUIP_TAR)
	PREPARE_FRIEND_TITLE_TAR = ParseTarget(CfgGet("prepare_friend_title_tar", ""), PREPARE_FRIEND_TITLE_TAR)
	PREPARE_FRIEND_REFRESH_TAR = ParseTarget(CfgGet("prepare_friend_refresh_tar", ""), PREPARE_FRIEND_REFRESH_TAR)
	PREPARE_FRIEND_SCROLLBAR_X = CLng(CfgGet("prepare_friend_scrollbar_x", 1412))
	PREPARE_FRIEND_SCROLLBAR_BASE_Y = CLng(CfgGet("prepare_friend_scrollbar_base_y", 245))
	If PREPARE_FRIEND_SCROLLBAR_BASE_Y <= 180 Then
		PREPARE_FRIEND_SCROLLBAR_BASE_Y = 245
	End If
	PREPARE_FRIEND_SCROLLBAR_STEP_Y = CLng(CfgGet("prepare_friend_scrollbar_step_y", 45))
	PREPARE_FRIEND_PAGE_SWIPE_DELAY = CLng(CfgGet("prepare_friend_page_swipe_delay", 1000))
	Dim friendAreaVal = CfgGet("prepare_friend_area", "")
	If Len(friendAreaVal) > 0 Then
		Dim pFa = ParseTarget(friendAreaVal, Array(40, 180, 920, 800, "dummy.png"))
		PREPARE_FRIEND_AREA = Array(pFa[1], pFa[2], pFa[3], pFa[4])
	End If

	' 14. FRIEND TEMPLATES
	ATT_Aobao = CfgGet("att_aobao", ATT_Aobao)
	ATT_AobaoShan = CfgGet("att_aobaoshan", ATT_AobaoShan)
	ATT_CDai = CfgGet("att_cdai", ATT_CDai)
	ATT_DaoMan = CfgGet("att_daoman", ATT_DaoMan)
	ATT_Cba = CfgGet("att_cba", ATT_Cba)
	ATT_RBA = CfgGet("att_rba", ATT_RBA)
	ATT_RBAShan = CfgGet("att_rbashan", ATT_RBAShan)
	ATT_Shahu = CfgGet("att_shahu", ATT_Shahu)
	ATT_ShahuShan = CfgGet("att_shahushan", ATT_ShahuShan)
	ATT_MeilinC = CfgGet("att_meilinc", ATT_MeilinC)
	ATT_Taigong = CfgGet("att_taigong", ATT_Taigong)
	ATT_Princess = CfgGet("att_princess", ATT_Princess)
	ATT_Princess120 = CfgGet("att_princess120", ATT_Princess120)
	ATT_QP = CfgGet("att_qp", ATT_QP)
	ATT_Sparrow = CfgGet("att_sparrow", ATT_Sparrow)
	ATT_Mary = CfgGet("att_mary", ATT_Mary)
	ATT_Keli = CfgGet("att_keli", ATT_Keli)

	' 15. EXTRA TARGETS
	INFINITE_ROLL_TAR = ParseTarget(CfgGet("infinite_roll_tar", ""), INFINITE_ROLL_TAR)
	INFINITE_ROLL_FAST_COORD = ParseCoord(CfgGet("infinite_roll_fast_coord", ""), INFINITE_ROLL_FAST_COORD)
	ENHANCE_HERO_TAR = ParseTarget(CfgGet("enhance_hero_tar", ""), ENHANCE_HERO_TAR)
	ENHANCE_HERO_RECOMMAND_TAR = ParseTarget(CfgGet("enhance_hero_recommand_tar", ""), ENHANCE_HERO_RECOMMAND_TAR)
	ENHANCE_HERO_RECOMMAND_CONFIRM_TAR = ParseTarget(CfgGet("enhance_hero_recommand_confirm_tar", ""), ENHANCE_HERO_RECOMMAND_CONFIRM_TAR)
	ENHANCE_HERO_ENHANCE_TAR = ParseTarget(CfgGet("enhance_hero_enhance_tar", ""), ENHANCE_HERO_ENHANCE_TAR)
	ENHANCE_HERO_ENHANCE_CONFIRM_TAR = ParseTarget(CfgGet("enhance_hero_enhance_confirm_tar", ""), ENHANCE_HERO_ENHANCE_CONFIRM_TAR)
	ENHANCE_HERO_TEMP_CONFIRM_TAR = ParseTarget(CfgGet("enhance_hero_temp_confirm_tar", ""), ENHANCE_HERO_TEMP_CONFIRM_TAR)
	TAP_ENHANCE_HERO_TEMP_CONFIRM = ParseCoord(CfgGet("tap_enhance_hero_temp_confirm", ""), TAP_ENHANCE_HERO_TEMP_CONFIRM)
	If TAP_ENHANCE_HERO_TEMP_CONFIRM = null Then
		TAP_ENHANCE_HERO_TEMP_CONFIRM = Array(943, 633)
	End If
	ENHANCE_HERO_REFUND_CLOSE_TAR = ParseTarget(CfgGet("enhance_hero_refund_close_tar", ""), ENHANCE_HERO_REFUND_CLOSE_TAR)
	TAP_ENHANCE_HERO_REFUND_CLOSE = ParseCoord(CfgGet("tap_enhance_hero_refund_close", ""), TAP_ENHANCE_HERO_REFUND_CLOSE)
	ENHANCE_HERO_TO_ASCEND_TAR = ParseTarget(CfgGet("enhance_hero_to_ascend_tar", ""), ENHANCE_HERO_TO_ASCEND_TAR)
	ENHANCE_HERO_TO_GRAIL_TAR = ParseTarget(CfgGet("enhance_hero_to_grail_tar", ""), ENHANCE_HERO_TO_GRAIL_TAR)
	ENHANCE_HERO_LV100_TAR = ParseTarget(CfgGet("enhance_hero_lv100_tar", ""), ENHANCE_HERO_LV100_TAR)
	ENHANCE_GRAIL_HERO_LV100_TAR = ParseTarget(CfgGet("enhance_grail_hero_lv100_tar", ""), ENHANCE_GRAIL_HERO_LV100_TAR)
	ENHANCE_ASCEND_TAR = ParseTarget(CfgGet("enhance_ascend_tar", ""), ENHANCE_ASCEND_TAR)
	ENHANCE_GRAIL_TAR = ParseTarget(CfgGet("enhance_grail_tar", ""), ENHANCE_GRAIL_TAR)
	ENHANCE_GRAIL_CONFIRM_TAR = ParseTarget(CfgGet("enhance_grail_confirm_tar", ""), ENHANCE_GRAIL_CONFIRM_TAR)
	TAP_ENHANCE_GRAIL_CONFIRM = ParseCoord(CfgGet("tap_enhance_grail_confirm", ""), TAP_ENHANCE_GRAIL_CONFIRM)
	If InStr(1, ENHANCE_GRAIL_CONFIRM_TAR[5], "ENHANCE_GRAIL_CONFIRM.png") = 0 Then
		ENHANCE_GRAIL_CONFIRM_TAR[5] = "Attachment:ENHANCE_GRAIL_CONFIRM.png|" & ENHANCE_GRAIL_CONFIRM_TAR[5]
	End If
	If TAP_ENHANCE_GRAIL_CONFIRM = null Then
		TAP_ENHANCE_GRAIL_CONFIRM = Array(943, 662)
	End If
	ENHANCE_ASCEND_BTN_TAR = ParseTarget(CfgGet("enhance_ascend_btn_tar", ""), ENHANCE_ASCEND_BTN_TAR)
	ENHANCE_ASCEND_CONFIRM_TAR = ParseTarget(CfgGet("enhance_ascend_confirm_tar", ""), ENHANCE_ASCEND_CONFIRM_TAR)
	ENHANCE_ASCEND_TO_HERO_TAR = ParseTarget(CfgGet("enhance_ascend_to_hero_tar", ""), ENHANCE_ASCEND_TO_HERO_TAR)
	ENHANCE_ASCEND_BACK_TAR = ParseTarget(CfgGet("enhance_ascend_back_tar", ""), ENHANCE_ASCEND_BACK_TAR)
	TAP_ENHANCE_HERO_TO_ASCEND = ParseCoord(CfgGet("tap_enhance_hero_to_ascend", ""), TAP_ENHANCE_HERO_TO_ASCEND)
	TAP_ENHANCE_HERO_TO_GRAIL = ParseCoord(CfgGet("tap_enhance_hero_to_grail", ""), TAP_ENHANCE_HERO_TO_GRAIL)
	TAP_ENHANCE_ASCEND_BTN = ParseCoord(CfgGet("tap_enhance_ascend_btn", ""), TAP_ENHANCE_ASCEND_BTN)
	TAP_ENHANCE_ASCEND_CONFIRM = ParseCoord(CfgGet("tap_enhance_ascend_confirm", ""), TAP_ENHANCE_ASCEND_CONFIRM)
	TAP_ENHANCE_ASCEND_TO_HERO = ParseCoord(CfgGet("tap_enhance_ascend_to_hero", ""), TAP_ENHANCE_ASCEND_TO_HERO)
	TAP_ENHANCE_ASCEND_BACK = ParseCoord(CfgGet("tap_enhance_ascend_back", ""), TAP_ENHANCE_ASCEND_BACK)
	TAP_ENHANCE_BLIND_SKIP = ParseCoord(CfgGet("tap_enhance_blind_skip", ""), TAP_ENHANCE_BLIND_SKIP)
	If TAP_ENHANCE_BLIND_SKIP = null Or (TAP_ENHANCE_BLIND_SKIP[1] = 940 And TAP_ENHANCE_BLIND_SKIP[2] = 660) Or (TAP_ENHANCE_BLIND_SKIP[1] = 260 And TAP_ENHANCE_BLIND_SKIP[2] = 400) Then
		TAP_ENHANCE_BLIND_SKIP = Array(1060, 760)
	End If
	MODAL_CLOSE_TAR = ParseTarget(CfgGet("modal_close_tar", ""), MODAL_CLOSE_TAR)
	TAP_MODAL_CLOSE = ParseCoord(CfgGet("tap_modal_close", ""), TAP_MODAL_CLOSE)
	If TAP_MODAL_CLOSE = null Then
		TAP_MODAL_CLOSE = Array(663, 684)
	End If
	POOLFRIEND_CONTINUE_TAR = ParseTarget(CfgGet("poolfriend_continue_tar", ""), POOLFRIEND_CONTINUE_TAR)
	POOLFRIEND_GO_TAR = ParseTarget(CfgGet("poolfriend_go_tar", ""), POOLFRIEND_GO_TAR)
	POOLFRIEND_ICON_TAR = ParseTarget(CfgGet("poolfriend_icon_tar", ""), POOLFRIEND_ICON_TAR)
	POOLFRIEND_LIMIT_TAR = ParseTarget(CfgGet("poolfriend_limit_tar", ""), POOLFRIEND_LIMIT_TAR)
	POOLFRIEND_RIGHT_COORD = ParseCoord(CfgGet("poolfriend_right_coord", ""), POOLFRIEND_RIGHT_COORD)
	POOLFRIEND_MID_COORD = ParseCoord(CfgGet("poolfriend_mid_coord", ""), POOLFRIEND_MID_COORD)
	ENHANCE_EQUIP_TAR = ParseTarget(CfgGet("enhance_equip_tar", ""), ENHANCE_EQUIP_TAR)
	ENHANCE_EQUIP_ENHANCE_TAR = ParseTarget(CfgGet("enhance_equip_enhance_tar", ""), ENHANCE_EQUIP_ENHANCE_TAR)
	ENHANCE_EQUIP_ENHANCE_GRAY_TAR = ParseTarget(CfgGet("enhance_equip_enhance_gray_tar", ""), ENHANCE_EQUIP_ENHANCE_GRAY_TAR)
	ENHANCE_EQUIP_ENHANCE_CONFIRM_TAR = ParseTarget(CfgGet("enhance_equip_enhance_confirm_tar", ""), ENHANCE_EQUIP_ENHANCE_CONFIRM_TAR)
	ENHANCE_SKILL_TAR = ParseTarget(CfgGet("enhance_skill_tar", ""), ENHANCE_SKILL_TAR)
	ENHANCE_SKILL_ENHANCE_TAR = ParseTarget(CfgGet("enhance_skill_enhance_tar", ""), ENHANCE_SKILL_ENHANCE_TAR)
	If ENHANCE_SKILL_ENHANCE_TAR[3] < 1380 Then
		ENHANCE_SKILL_ENHANCE_TAR = Array(1340, 716, 1438, 798, "Attachment:ENHANCE_SKILL_ENHANCE.png")
	End If
	ENHANCE_SKILL_ENHANCE_CONFIRM_TAR = ParseTarget(CfgGet("enhance_skill_enhance_confirm_tar", ""), ENHANCE_SKILL_ENHANCE_CONFIRM_TAR)
	If ENHANCE_SKILL_ENHANCE_CONFIRM_TAR[2] > 630 Then
		ENHANCE_SKILL_ENHANCE_CONFIRM_TAR = Array(875, 590, 1020, 680, "Attachment:ENHANCE_SKILL_ENHANCE_CONFIRM.png")
	End If
	ENHANCE_SKILL_ENHANCE_L10_TAR = ParseTarget(CfgGet("enhance_skill_enhance_l10_tar", ""), ENHANCE_SKILL_ENHANCE_L10_TAR)
	ENHANCE_SKILL_CLICK_COORD = ParseCoord(CfgGet("enhance_skill_click_coord", ""), ENHANCE_SKILL_CLICK_COORD)
	ENHANCE_SKILL_MAX_L10_TAR = ParseTarget(CfgGet("enhance_skill_max_l10_tar", ""), ENHANCE_SKILL_MAX_L10_TAR)
	TAP_ENHANCE_SKILL_1 = ParseCoord(CfgGet("tap_enhance_skill_1", ""), TAP_ENHANCE_SKILL_1)
	TAP_ENHANCE_SKILL_2 = ParseCoord(CfgGet("tap_enhance_skill_2", ""), TAP_ENHANCE_SKILL_2)
	TAP_ENHANCE_SKILL_3 = ParseCoord(CfgGet("tap_enhance_skill_3", ""), TAP_ENHANCE_SKILL_3)
	ENHANCE_SKILL_HERO_UNSELECTED_TAR = ParseTarget(CfgGet("enhance_skill_hero_unselected_tar", ""), ENHANCE_SKILL_HERO_UNSELECTED_TAR)
	ENHANCE_SKILL_APPEND_TAR = ParseTarget(CfgGet("enhance_skill_append_tar", ""), ENHANCE_SKILL_APPEND_TAR)
End Sub

Sub ReloadConfig()
	CFG_CONFIG_PATH = ""
	CFG_RAW = ""
	CFG_KEYS = Array()
	CFG_VALS = Array()
	CFG_ITEM_COUNT = 0
	CFG_PRESET = ""
	CFG_FRIEND = ""
	CFG_ACTION_INDEX = 0
	CFG_TEST_DSL = ""
	CFG_ACTIVITY_REWARD = 1
	CAN_RUN = true
	HAS_FRIEND_CONFIG = false
	selectedDsl = ""
	selectedActivityDsl = ""
	selectedFriendKey = ""
	PREPARE_FRIEND_TAR = Array()
	CurrentBattleSequence = Array()
	AllActionRound = Array()

	' 娴兼ê鍘涘Λ閺 FGO_Q 閻╁瓨甯归惄瑜版洑鑵戦惃鍕娓堕弬浼村帳缂
	Dim directCfgPath = "/sdcard/FGO_Q/battle_v5_config.mq"
	If Dir.Exist(directCfgPath) <> 1 Then
		directCfgPath = "/storage/emulated/0/FGO_Q/battle_v5_config.mq"
	End If
	If Dir.Exist(directCfgPath) = 1 Then
		Dim directCfgRaw = zm.FileRead(directCfgPath)
		If Not IsNull(directCfgRaw) And Len(CStr(directCfgRaw)) > 0 Then
			Dim directCfgRawLower = LCase(CStr(directCfgRaw))
			If InStr(1, directCfgRawLower, "dim dsl_") > 0 Or InStr(1, directCfgRawLower, "dim action_group_index") > 0 Then
				CFG_CONFIG_PATH = directCfgPath
				CFG_RAW = CStr(directCfgRaw)
			End If
		End If
	End If

	If Len(CFG_CONFIG_PATH) = 0 Then
		Dim cfgCandidates = zm.DirScan("/sdcard/MobileAnJian/Script/", "*.mq", 1)
		If IsNull(cfgCandidates) Then
			cfgCandidates = zm.DirScan("/storage/emulated/0/MobileAnJian/Script/", "*.mq", 1)
		End If

		If cfgCandidates Then
			Dim cfgCandidatePath
			For Each cfgCandidatePath In cfgCandidates
				Dim cfgCandidatePathText = CStr(cfgCandidatePath)
				Dim cfgCandidatePathLower = LCase(cfgCandidatePathText)
				If InStr(1, cfgCandidatePathLower, "battle_v5_config") > 0 Or InStr(1, cfgCandidatePathLower, "battle_v3_config") > 0 Then
					Dim cfgCandidateRaw = zm.FileRead(cfgCandidatePathText)
					If Not IsNull(cfgCandidateRaw) And Len(CStr(cfgCandidateRaw)) > 0 Then
						Dim cfgCandidateRawLower = LCase(CStr(cfgCandidateRaw))
						If InStr(1, cfgCandidateRawLower, "dim dsl_") > 0 Or InStr(1, cfgCandidateRawLower, "dim test_dsl") > 0 Or InStr(1, cfgCandidateRawLower, "dim action_round_index_") > 0 Or InStr(1, cfgCandidateRawLower, "dim action_group_index") > 0 Then
							CFG_CONFIG_PATH = cfgCandidatePathText
							CFG_RAW = CStr(cfgCandidateRaw)
							If InStr(1, cfgCandidatePathLower, "battle_v5_config") > 0 Then
								Exit For
							End If
						End If
					End If
				End If
			Next
		End If
	End If

	If Len(CFG_CONFIG_PATH) > 0 Then
		TracePrint "CONFIG PATH FOUND:", CFG_CONFIG_PATH
	Else
		TracePrint "CONFIG PATH NOT FOUND"
		TracePrint "HINT:", "璇峰厛鍦ㄦ寜閿绮剧伒閲岀紪璇戝苟鍚屾 battle_v5_config.q"
		CAN_RUN = false
		Exit Sub
	End If

	If Not IsNull(CFG_RAW) And Len(CStr(CFG_RAW)) > 0 Then
		Dim cfgLines = Split(Replace(CStr(CFG_RAW), Chr(13), ""), Chr(10))
		Dim cfgLineIndex
		For cfgLineIndex = 0 To UBound(cfgLines)
			Dim cfgLineText = Trim(CStr(cfgLines(cfgLineIndex)))
			If Len(cfgLineText) > 0 Then
				If Left(cfgLineText, 1) <> "'" Then
					Dim eqPos = InStr(1, cfgLineText, "=")
					If eqPos > 0 Then
						Dim cfgKey = LCase(Trim(Left(cfgLineText, eqPos - 1)))
						If Left(cfgKey, 4) = "dim " Then
							cfgKey = Trim(Mid(cfgKey, 5, Len(cfgKey) - 4))
						End If
						Dim cfgVal = Trim(Mid(cfgLineText, eqPos + 1, Len(cfgLineText) - eqPos))
						If Left(cfgVal, 1) = Chr(34) Then
							Dim secondQuote = InStr(2, cfgVal, Chr(34))
							If secondQuote > 2 Then
								cfgVal = Mid(cfgVal, 2, secondQuote - 2)
							ElseIf secondQuote = 2 Then
								cfgVal = ""
							Else
								cfgVal = Mid(cfgVal, 2, Len(cfgVal) - 1)
							End If
						Else
							Dim commentPos = InStr(1, cfgVal, "'")
							If commentPos > 1 Then
								cfgVal = Trim(Left(cfgVal, commentPos - 1))
							ElseIf commentPos = 1 Then
								cfgVal = ""
							End If
						End If
						CfgSet cfgKey, cfgVal
					End If
				End If
			End If
		Next
	End If

	Dim callerRunMode = RUN_MODE
	RUN_MODE = CInt(CfgGet("run_mode", CfgGet("extra_enable", "0")))
	If callerRunMode = 1 Then
		RUN_MODE = 1
	End If
	EXTRA_ENABLE = RUN_MODE
	EXTRA_ACTION_COUNT = CInt(CfgGet("extra_action_count", "30"))
	EXTRA_SKILL_MAX_LEVEL = CInt(CfgGet("extra_skill_max_level", "9"))
	EXTRA_SKILL_AUTO_THREE = CInt(CfgGet("extra_skill_auto_three", "1"))
	EXTRA_HERO_AUTO_ASCEND = CInt(CfgGet("extra_hero_auto_ascend", "1"))
	EXTRA_HERO_AUTO_GRAIL = CInt(CfgGet("extra_hero_auto_grail", "0"))
	EXTRA_DRY_RUN = CInt(CfgGet("extra_dry_run", "1"))
	If RUN_MODE = 1 Then
		EXTRA_ENABLE = 1
		CAN_RUN = true
		ApplyConfigTargets()
		Exit Sub
	End If
	CFG_ACTION_GROUP_INDEX = CInt(CfgGet("action_group_index", CfgGet("cfg_action_group_index", "0")))
	MANUAL_BATTLE_COUNT = CInt(CfgGet("battle_count", CfgGet("manual_battle_count", "0")))
	MANUAL_APPLE_ENABLE = CInt(CfgGet("apple_enable", CfgGet("manual_apple_enable", "0")))
	MANUAL_CHOOSE_FRIEND = CInt(CfgGet("manual_choose_friend", CfgGet("choose_friend_manual", "0")))
	MANUAL_DEBUG_SCREENSHOT_ENABLE = CInt(CfgGet("debug_screenshot_enable", CfgGet("manual_debug_screenshot_enable", CfgGet("debug_enable", "0"))))

	CFG_FRIEND = CStr(CfgGet("friend", ""))
	CFG_ACTION_INDEX = PickActionIndexByGroup(CFG_ACTION_GROUP_INDEX)
	CFG_ACTIVITY_REWARD = PickActivityRewardByGroupAndIndex(CFG_ACTION_GROUP_INDEX, CFG_ACTION_INDEX)

	BATTLE_COUNT = CInt(MANUAL_BATTLE_COUNT)
	CHOOSE_FRIEND_MANUAL = CInt(MANUAL_CHOOSE_FRIEND)
	APPLE_ENABLE = CInt(MANUAL_APPLE_ENABLE)
	MANUAL_DEBUG_FRIEND_ONLY = CInt(CfgGet("debug_friend_only", CfgGet("manual_debug_friend_only", "0")))
	DEBUG_SCREENSHOT_ENABLE = CInt(MANUAL_DEBUG_SCREENSHOT_ENABLE)
	DEBUG_FRIEND_ONLY = CInt(MANUAL_DEBUG_FRIEND_ONLY)
	ACTIVITY_REWARD = CFG_ACTIVITY_REWARD

	HERO_CARD_OFFSET_COLOR = CStr(CfgGet("hero_card_offset_color", "202020"))
	HERO_CARD_SIM = CDbl(CfgGet("hero_card_sim", "0.75"))

	ApplyConfigTargets()

	TracePrint "CONFIG PARSED", "group=", CFG_ACTION_GROUP_INDEX, "index=", CFG_ACTION_INDEX, "battle_count=", BATTLE_COUNT, "friend=", CFG_FRIEND, "manual_choose_friend=", CHOOSE_FRIEND_MANUAL, "debug_screenshot=", DEBUG_SCREENSHOT_ENABLE, "debug_friend_only=", DEBUG_FRIEND_ONLY

	If CFG_ACTION_GROUP_INDEX < 0 Then
		TracePrint "CONFIG ACTION_ROUND_GROUP_INDEX INVALID, STOP"
		CAN_RUN = false
	End If

	If CFG_ACTION_INDEX <= 0 Then
		TracePrint "CONFIG ACTION_ROUND_INDEX INVALID, STOP"
		CAN_RUN = false
	End If

	If BATTLE_COUNT <= 0 Then
		TracePrint "MANUAL BATTLE_COUNT INVALID, STOP"
		CAN_RUN = false
	End If

	If CAN_RUN Then
		selectedActivityDsl = PickDslByGroupAndIndex(CFG_ACTION_GROUP_INDEX, CFG_ACTION_INDEX)
		If CFG_ACTION_GROUP_INDEX = 0 Then
			If Len(selectedActivityDsl) = 0 Then
				selectedActivityDsl = CFG_TEST_DSL
			End If
			If Len(selectedActivityDsl) = 0 Then
				selectedActivityDsl = CStr(CfgGet("test_dsl_" & CFG_ACTION_INDEX, ""))
			End If
		End If
	End If

	selectedDsl = selectedActivityDsl

	selectedFriendKey = LCase(Trim(CStr(PickFriendByGroupAndIndex(CFG_ACTION_GROUP_INDEX, CFG_ACTION_INDEX))))
	If Len(selectedFriendKey) = 0 Then
		selectedFriendKey = LCase(Trim(CStr(PickFriendByGroup(CFG_ACTION_GROUP_INDEX))))
	End If
	If Len(selectedFriendKey) = 0 Then
		selectedFriendKey = LCase(Trim(CStr(CFG_FRIEND)))
	End If
	selectedPageTurns = PickPageTurnsByGroupAndIndex(CFG_ACTION_GROUP_INDEX, CFG_ACTION_INDEX)

	If RUN_MODE = 0 Then
		If Len(selectedDsl) = 0 Then
			TracePrint "CONFIG DSL EMPTY, STOP"
			CAN_RUN = false
		End If
	Else
		' Extra 杈呭姪妯″紡鏃犻渶鎴樻湳 DSL
		CAN_RUN = true
	End If

	If CAN_RUN Then
		TracePrint "SELECTED DSL HEAD:", Left(CStr(selectedDsl), 120)
		CurrentBattleSequence = BuildRoundsFromFlatText(selectedDsl)
		AllActionRound = ParseBattleSequence(CurrentBattleSequence)
		TOTAL_SUB_ROUND_NUM = UBound(AllActionRound) + 1
	End If

	If Len(selectedFriendKey) > 0 Then
		Dim customAtt = Trim(CStr(CfgGet("att_" & selectedFriendKey, "")))
		If Len(customAtt) > 0 And customAtt <> "Attachment:" Then
			PREPARE_FRIEND_TAR = Array(PREPARE_FRIEND_AREA[1], PREPARE_FRIEND_AREA[2], PREPARE_FRIEND_AREA[3], PREPARE_FRIEND_AREA[4], customAtt)
			HAS_FRIEND_CONFIG = true
		ElseIf selectedFriendKey = "aobao" Then
			PREPARE_FRIEND_TAR = Array(PREPARE_FRIEND_AREA[1], PREPARE_FRIEND_AREA[2], PREPARE_FRIEND_AREA[3], PREPARE_FRIEND_AREA[4], ATT_Aobao)
			HAS_FRIEND_CONFIG = true
		ElseIf selectedFriendKey = "cdai" Then
			PREPARE_FRIEND_TAR = Array(PREPARE_FRIEND_AREA[1], PREPARE_FRIEND_AREA[2], PREPARE_FRIEND_AREA[3], PREPARE_FRIEND_AREA[4], ATT_CDai)
			HAS_FRIEND_CONFIG = true
		ElseIf selectedFriendKey = "daoman" Then
			PREPARE_FRIEND_TAR = Array(PREPARE_FRIEND_AREA[1], PREPARE_FRIEND_AREA[2], PREPARE_FRIEND_AREA[3], PREPARE_FRIEND_AREA[4], ATT_DaoMan)
			HAS_FRIEND_CONFIG = true
		ElseIf selectedFriendKey = "cba" Then
			PREPARE_FRIEND_TAR = Array(PREPARE_FRIEND_AREA[1], PREPARE_FRIEND_AREA[2], PREPARE_FRIEND_AREA[3], PREPARE_FRIEND_AREA[4], ATT_Cba)
			HAS_FRIEND_CONFIG = true
		ElseIf selectedFriendKey = "rba" Then
			PREPARE_FRIEND_TAR = Array(PREPARE_FRIEND_AREA[1], PREPARE_FRIEND_AREA[2], PREPARE_FRIEND_AREA[3], PREPARE_FRIEND_AREA[4], ATT_RBA)
			HAS_FRIEND_CONFIG = true
		ElseIf selectedFriendKey = "shahu" Then
			PREPARE_FRIEND_TAR = Array(PREPARE_FRIEND_AREA[1], PREPARE_FRIEND_AREA[2], PREPARE_FRIEND_AREA[3], PREPARE_FRIEND_AREA[4], ATT_Shahu)
			HAS_FRIEND_CONFIG = true
		ElseIf selectedFriendKey = "shahushan" Then
			PREPARE_FRIEND_TAR = Array(PREPARE_FRIEND_AREA[1], PREPARE_FRIEND_AREA[2], PREPARE_FRIEND_AREA[3], PREPARE_FRIEND_AREA[4], ATT_ShahuShan)
			HAS_FRIEND_CONFIG = true
		ElseIf selectedFriendKey = "aobaoshan" Then
			PREPARE_FRIEND_TAR = Array(PREPARE_FRIEND_AREA[1], PREPARE_FRIEND_AREA[2], PREPARE_FRIEND_AREA[3], PREPARE_FRIEND_AREA[4], ATT_AobaoShan)
			HAS_FRIEND_CONFIG = true
		ElseIf selectedFriendKey = "rbashan" Then
			PREPARE_FRIEND_TAR = Array(PREPARE_FRIEND_AREA[1], PREPARE_FRIEND_AREA[2], PREPARE_FRIEND_AREA[3], PREPARE_FRIEND_AREA[4], ATT_RBAShan)
			HAS_FRIEND_CONFIG = true
		ElseIf selectedFriendKey = "princess" Then
			PREPARE_FRIEND_TAR = Array(PREPARE_FRIEND_AREA[1], PREPARE_FRIEND_AREA[2], PREPARE_FRIEND_AREA[3], PREPARE_FRIEND_AREA[4], ATT_Princess)
			HAS_FRIEND_CONFIG = true
		ElseIf selectedFriendKey = "princess120" Then
			PREPARE_FRIEND_TAR = Array(PREPARE_FRIEND_AREA[1], PREPARE_FRIEND_AREA[2], PREPARE_FRIEND_AREA[3], PREPARE_FRIEND_AREA[4], ATT_Princess120)
			HAS_FRIEND_CONFIG = true
		ElseIf selectedFriendKey = "taigong" Then
			PREPARE_FRIEND_TAR = Array(PREPARE_FRIEND_AREA[1], PREPARE_FRIEND_AREA[2], PREPARE_FRIEND_AREA[3], PREPARE_FRIEND_AREA[4], ATT_Taigong)
			HAS_FRIEND_CONFIG = true
		ElseIf selectedFriendKey = "sparrow" Then
			PREPARE_FRIEND_TAR = Array(PREPARE_FRIEND_AREA[1], PREPARE_FRIEND_AREA[2], PREPARE_FRIEND_AREA[3], PREPARE_FRIEND_AREA[4], ATT_Sparrow)
			HAS_FRIEND_CONFIG = true
		ElseIf selectedFriendKey = "mary" Then
			PREPARE_FRIEND_TAR = Array(PREPARE_FRIEND_AREA[1], PREPARE_FRIEND_AREA[2], PREPARE_FRIEND_AREA[3], PREPARE_FRIEND_AREA[4], ATT_Mary)
			HAS_FRIEND_CONFIG = true
		ElseIf selectedFriendKey = "keli" Then
			PREPARE_FRIEND_TAR = Array(PREPARE_FRIEND_AREA[1], PREPARE_FRIEND_AREA[2], PREPARE_FRIEND_AREA[3], PREPARE_FRIEND_AREA[4], ATT_Keli)
			HAS_FRIEND_CONFIG = true
		ElseIf selectedFriendKey = "heshang" Then
			PREPARE_FRIEND_TAR = Array(PREPARE_FRIEND_AREA[1], PREPARE_FRIEND_AREA[2], PREPARE_FRIEND_AREA[3], PREPARE_FRIEND_AREA[4], ATT_Heshang)
			HAS_FRIEND_CONFIG = true
		End If
	End If

	If RUN_MODE = 0 Then
		If Not HAS_FRIEND_CONFIG And CHOOSE_FRIEND_MANUAL <= 0 Then
			' 若当前已处于战斗内（技能界面）或编队确认界面（且不在助战选择界面），允许免助战配置直接执行
			If CheckImg2(BATTLE_HERO_SKILL_CHECK_TAR) <> null Or (Not IsOnFriendSelectScreen() And CheckImg2(START_TAR) <> null) Then
				TracePrint "Already in battle or team screen (Attack/Start found), bypass empty friend check"
			Else
				TracePrint "FRIEND CONFIG INVALID OR EMPTY, STOP"
				CAN_RUN = false
			End If
		End If
	End If

	TracePrint "CONFIG APPLIED", "group=", CFG_ACTION_GROUP_INDEX, "index=", CFG_ACTION_INDEX, "friend=", selectedFriendKey, "battle_count=", BATTLE_COUNT, "activity_reward=", CFG_ACTIVITY_REWARD
End Sub

Dim SCREEN_BASE_W = 1440
Dim SCREEN_BASE_H = 810
Dim PREPARE_FRIEND_AREA = Array(40, 180, 920, 800)
Dim BATTLE_SKILL_SPEEDUP_COORD = Array(1100, 770)
Dim ATT_EQUIP_Goodness = "Attachment:friend_equip_goodness.png"

Dim PREPARE_FRIEND_EQUIP_TAR = Array(40, 180, 920, 800, ATT_EQUIP_Goodness)
Dim PREPARE_FRIEND_TITLE_TAR = Array(1150, 0, 1255, 80, "Attachment:PREPARE_FRIEND_TITLE.png")
Dim PREPARE_FRIEND_REFRESH_TAR = Array(980, 85, 1110, 175, "Attachment:PREPARE_FRIEND_REFRESH.png")
Dim PREPARE_FRIEND_SCROLLBAR_X = 1412
Dim PREPARE_FRIEND_SCROLLBAR_BASE_Y = 245
Dim PREPARE_FRIEND_SCROLLBAR_STEP_Y = 45
Dim PREPARE_FRIEND_PAGE_SWIPE_DELAY = 1000


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
' Skill SPECIAL skill Change(0): display check: change button
Dim BATTLE_SKILL_CHANGE_CHECK_TAR = Array(723, 685, 777, 719, "Attachment:BATTLE_SKILL_CHANGE_CHECK.png")
' Skill Change: selected check: change button
Dim BATTLE_SKILL_CHANGE_SELECTEED_CHECK_TAR = Array(723, 685, 777, 719, "Attachment:BATTLE_SKILL_CHANGE_SELECTEED_CHECK.png")
Dim BATTLE_SKILL_CHANGE_SELECTED_AWAIT_MS = 200

' Skill SPECIAL_SKILL_A(1): CaoShiLang
Dim BATTLE_SKILL_SPECIAL_SKILL_A_TAR = Array(180, 240, 345, 410, "Attachment:BATTLE_SKILL_SPECIAL_SKILL_A.png")
Dim BATTLE_SKILL_SPECIAL_SKILL_A_ACT_TARS = Array(_
	Array(),_
	Array(),_
	Array(1060, 480)_
 )


' Master skill
Dim BATTLE_MASTER_SKILL_OPEN_TAR = Array(1280, 300, 1410, 420, "Attachment:BATTLE_MASTER_SKILL_OPEN.png")
Dim BATTLE_MASTER_SKILL_OPEN_COORDS = Array(1317, 325)
Dim BATTLE_MASTER_SKILL_AWAIT_MS = 300
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

' BATTLE: TARGET (select enemy)
Dim BATTLE_TARGET_COORDS = Array(_
	Array(159, 33),_
	Array(424, 33),_
	Array(689, 33),_
	Array(130, 150),_
	Array(355, 150),_
	Array(580, 150)_
 )

' BATTLE: ATTACK





Dim BATTLE_ULTIMATE_DISPLAY_AWAIT_MS = 1000

Dim BATTLE_ATTACK_BACK_TAR = Array(1280, 740, 1410, 795, "Attachment:BATTLE_ATTACK_BACK.png") 

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
	Array(650, 550, 780, 600, "Attachment:BATTLE_ATTACK_CARD_3_FIRST_TAPED.png"),_
	Array(),_
	Array(),_
	Array(400, 210, 550, 352, "Attachment:ULT_Taped_Red1.png|Attachment:ULT_Taped_Blue1.png|Attachment:ULT_Taped_Green1.png"),_
	Array(680, 210, 790, 352, "Attachment:ULT_Taped_Red2.png|Attachment:ULT_Taped_Blue2.png|Attachment:ULT_Taped_Green2.png"),_
	Array(930, 210, 1048, 259, "Attachment:ULT_Taped_Red3.png|Attachment:ULT_Taped_Blue3.png|Attachment:ULT_Taped_Green3.png")_
 )
Dim BATTLE_ATTACK_CARD_SECON_TAPED_TARS = Array(_
	Array(),_
	Array(),_
	Array(),_
	Array(950, 560, 1071, 600, "Attachment:BATTLE_ATTACK_CARD_4_SECOND_TAPED.png"),_
	Array(),_
	Array(400, 213, 520, 355, "Attachment:BATTLE_ATTACK_CARD_6_SECOND_TAPED.png"),_
	Array(700, 227, 727, 238, "Attachment:BATTLE_ATTACK_CARD_7_SECOND_TAPED.png|Attachment:BATTLE_ATTACK_CARD_7_SECOND_TAPED2.png"),_
	Array(960, 227, 987, 238, "Attachment:BATTLE_ATTACK_CARD_8_SECOND_TAPED.png")_
 )
Dim BATTLE_ATTACK_CARD_BUSTER_TAR = Array(55, 575, 1390, 665, "Attachment:BATTLE_ATTACK_CARD_BUSTER.png")
Dim BATTLE_ATTACK_CARD_PRIORITY_TARS = Array()
BATTLE_ATTACK_CARD_PRIORITY_TARS[1] = null
BATTLE_ATTACK_CARD_PRIORITY_TARS[2] = null
BATTLE_ATTACK_CARD_PRIORITY_TARS[3] = null
Dim BATTLE_ATTACK_CARD_PRIORITY_COUNT = 0
Dim BATTLE_ATTACK_CARD_PRIORITY_SIM = 0.78
Dim BATTLE_HERO_SAMPLED = Array(0, 0, 0, 0)


Dim BATTLE_ATTACK_CARD_ARTS_TAR = Array(55, 575, 1390, 665, "Attachment:BATTLE_ATTACK_CARD_ARTS.png")
Dim BATTLE_ATTACK_CARD_ARTS_PRIORITY_TARS = Array()
Dim BATTLE_ATTACK_CARD_ARTS_PRIORITY_COUNT = 0
Dim BATTLE_ATTACK_CARD_ARTS_PRIORITY_SIM = 0.78

Dim BATTLE_ATTACK_CARD_QUICK_TAR = Array(55, 575, 1390, 665, "Attachment:BATTLE_ATTACK_CARD_QUICK.png")
Dim BATTLE_ATTACK_CARD_QUICK_PRIORITY_TARS = Array()
Dim BATTLE_ATTACK_CARD_QUICK_PRIORITY_COUNT = 0
Dim BATTLE_ATTACK_CARD_QUICK_PRIORITY_SIM = 0.78

' 瀹濆叿鍗′粠鑰呯珛缁橀噰鏍峰尯鍩 (NP CARD SERVANT FACE SAMPLING RECTS)
Dim BATTLE_HERO_NP_FACE_1_TAR = Array(443, 181, 483, 201, "Attachment:BATTLE_HERO_NP_FACE_1.png")
Dim BATTLE_HERO_NP_FACE_2_TAR = Array(719, 181, 759, 201, "Attachment:BATTLE_HERO_NP_FACE_2.png")
Dim BATTLE_HERO_NP_FACE_3_TAR = Array(995, 181, 1035, 201, "Attachment:BATTLE_HERO_NP_FACE_3.png")

' 鎵嬬墝浠庤呯珛缁樺尮閰嶅尯鍩 (COMMAND CARD SERVANT PORTRAIT SEARCH RECTS)
Dim BATTLE_HERO_CARD_AREA_1_TAR = Array(33, 480, 203, 580, "Attachment:BATTLE_HERO_CARD_AREA_1.png")
Dim BATTLE_HERO_CARD_AREA_2_TAR = Array(323, 480, 493, 580, "Attachment:BATTLE_HERO_CARD_AREA_2.png")
Dim BATTLE_HERO_CARD_AREA_3_TAR = Array(613, 480, 783, 580, "Attachment:BATTLE_HERO_CARD_AREA_3.png")
Dim BATTLE_HERO_CARD_AREA_4_TAR = Array(906, 480, 1076, 580, "Attachment:BATTLE_HERO_CARD_AREA_4.png")
Dim BATTLE_HERO_CARD_AREA_5_TAR = Array(1193, 480, 1363, 580, "Attachment:BATTLE_HERO_CARD_AREA_5.png")

' 100% 鏆村嚮妫娴嬪尯鍩熶笌妯℃澘 (CRIT 100% DETECTION RECTS & TEMPLATE)
Dim BATTLE_CRIT_100_AREA_1_TAR = Array(63, 350, 83, 445, "Attachment:BATTLE_ATTACK_CARD_100.png")
Dim BATTLE_CRIT_100_AREA_2_TAR = Array(353, 350, 373, 445, "Attachment:BATTLE_ATTACK_CARD_100.png")
Dim BATTLE_CRIT_100_AREA_3_TAR = Array(643, 350, 663, 445, "Attachment:BATTLE_ATTACK_CARD_100.png")
Dim BATTLE_CRIT_100_AREA_4_TAR = Array(936, 350, 956, 445, "Attachment:BATTLE_ATTACK_CARD_100.png")
Dim BATTLE_CRIT_100_AREA_5_TAR = Array(1223, 350, 1243, 445, "Attachment:BATTLE_ATTACK_CARD_100.png")
Dim BATTLE_ATTACK_CARD_100_TAR = Array(55, 350, 1390, 445, "Attachment:BATTLE_ATTACK_CARD_100.png|Attachment:BATTLE_ATTACK_CARD_100_2.png")

Dim BATTLE_CARD_COLORS = Array("", "", "", "", "", "")
Dim BATTLE_CARD_IS_CRIT_100 = Array(0, 0, 0, 0, 0, 0)
Dim BATTLE_CARD_CHOSEN = Array(0, 0, 0, 0, 0, 0)
Dim BATTLE_CARD_TAPED_AWAIT_MS = 300
Dim BATTLE_ROUND_CHANGE_AWAIT_MS = 6000
Dim BATTLE_NORMAL_ATTACK_PLAY_AWAIT_MS = 5000 + BATTLE_ROUND_CHANGE_AWAIT_MS
Dim BATTLE_ULTIMATE_PLAY_1_AWAIT_MS = 10000 + BATTLE_ROUND_CHANGE_AWAIT_MS
Dim BATTLE_ULTIMATE_PLAY_2_AWAIT_MS = 13000 + BATTLE_ROUND_CHANGE_AWAIT_MS
Dim BATTLE_LAST_ROUND_END_AWAIT_MS = 3000
Dim BATTLE_ULTIMATE_PLAY_LAST_AWAIT_MS = 18000 + BATTLE_LAST_ROUND_END_AWAIT_MS

' AWARD
Dim AWARD_TIE_TAR = Array(90, 190, 330, 225, "Attachment:AWARD_TIE.png") ' normal:TIE, special:TIE2
Dim AWARD_TIE_UP_TAR = Array(696, 101, 828, 245, "Attachment:AWARD_TIE_UP.png")
Dim AWARD_TAP_COORD = Array(166, 60)
Dim AWARD_TREASURE_NEXT_TAR = Array(1178, 696, 1282, 740, "Attachment:AWARD_TREASURE_NEXT.png")
Dim AWARD_NORMAL_TAP_AWAIT_MS = 300

' Activity AWARD
Dim BEFORE_ACTIVITY_AWAIT_MS = 500
Dim AWARD_ACTIVITY_NEXT_TAR = Array(1178, 696, 1282, 740, "Attachment:AWARD_TREASURE_NEXT.png")

' ADD FRIEND
Dim ADD_FRIEND_CHECK_AWAIT_MS = 500
Dim ADD_FRIEND_TAR = Array(325, 670, 415, 715, "Attachment:ADD_FRIEND_CLOSE.png")

' AGAIN
Dim AGAIN_ALERT_AGAIN_TAR = Array(795, 620, 1030, 700, "Attachment:AGAIN_ALERT_AGAIN.png")
Dim AGAIN_ALERT_CLOSE_TAR = Array(370, 620, 620, 700, "Attachment:AGAIN_ALERT_CLOSE.png")
Dim AGAIN_ORDEAL_NO_TICKET_TAR = Array(600, 600, 850, 670, "Attachment:AGAIN_ORDEAL_NO_TICKET.png")
Dim AGAIN_BATTLE_OUT_MENU_TAR = Array(1301, 689, 1360, 715, "Attachment:AGAIN_BATTLE_OUT_MENU.png")


' APPLE
Dim APPLE_CHECK_AWAIT_MS = 500
Dim APPLE_DISPLAY_TAR = Array(634, 37, 743, 83, "Attachment:APPLE_DISPLAY.png")
Dim APPLE_GLODEN_COORD = Array(420, 360)
Dim APPLE_SILVER_COORD = Array(420, 520)
Dim APPLE_CONFIRM_TAR = Array(800, 580, 1050, 720, "Attachment:APPLE_CONFIRM.png|Attachment:APPLE_CONFIRM_OLD.png")
Dim APPLE_CONFIRM_COORD = Array(944, 660)
Dim APPLE_CLOSE_COORD = Array(720, 695)

' ==================== EXTRA TARGETS ====================
Dim INFINITE_ROLL_TAR = Array(330, 370, 620, 610, "Attachment:ROLL100.png")
Dim INFINITE_ROLL_FAST_COORD = Array(300, 400)

Dim ENHANCE_HERO_TAR = Array(880, 5, 1300, 70, "Attachment:ENHANCE_HERO.png")
Dim ENHANCE_HERO_RECOMMAND_TAR = Array(1240, 150, 1370, 208, "Attachment:ENHANCE_HERO_RECOMMAND.png")
Dim ENHANCE_HERO_RECOMMAND_CONFIRM_TAR = Array(880, 680, 1006, 745, "Attachment:ENHANCE_HERO_RECOMMAND_CONFIRM.png")
Dim ENHANCE_HERO_ENHANCE_TAR = Array(1340, 716, 1438, 798, "Attachment:ENHANCE_HERO_ENHANCE.png")
Dim ENHANCE_HERO_ENHANCE_CONFIRM_TAR = Array(877, 632, 1006, 698, "Attachment:ENHANCE_HERO_ENHANCE_CONFIRM.png")
Dim ENHANCE_HERO_TEMP_CONFIRM_TAR = Array(877, 590, 1006, 660, "Attachment:ENHANCE_HERO_TEMP_CONFIRM.png|Attachment:ENHANCE_HERO_ENHANCE_CONFIRM.png")
Dim TAP_ENHANCE_HERO_TEMP_CONFIRM = Array(943, 633)
Dim ENHANCE_HERO_REFUND_CLOSE_TAR = Array(550, 580, 890, 680, "Attachment:ENHANCE_HERO_REFUND_CLOSE.png")
Dim TAP_ENHANCE_HERO_REFUND_CLOSE = Array(686, 614)
Dim ENHANCE_HERO_TO_ASCEND_TAR = Array(1050, 580, 1320, 680, "Attachment:ENHANCE_HERO_TO_ASCEND.png")
Dim ENHANCE_HERO_TO_GRAIL_TAR = Array(1050, 580, 1320, 680, "Attachment:ENHANCE_HERO_TO_GRAIL.png")
Dim ENHANCE_HERO_LV100_TAR = Array(470, 505, 580, 565, "Attachment:ENHANCE_HERO_LV100.png")
Dim ENHANCE_GRAIL_HERO_LV100_TAR = Array(470, 230, 580, 290, "Attachment:ENHANCE_GRAIL_HERO_LV100.png")
Dim ENHANCE_ASCEND_TAR = Array(880, 5, 1300, 70, "Attachment:ENHANCE_ASCEND.png")
Dim ENHANCE_GRAIL_TAR = Array(1050, 5, 1420, 70, "Attachment:ENHANCE_GRAIL.png")
Dim ENHANCE_GRAIL_CONFIRM_TAR = Array(877, 632, 1006, 698, "Attachment:ENHANCE_GRAIL_CONFIRM.png|Attachment:ENHANCE_HERO_ENHANCE_CONFIRM.png")
Dim TAP_ENHANCE_GRAIL_CONFIRM = Array(943, 662)
Dim ENHANCE_ASCEND_BTN_TAR = Array(1340, 716, 1438, 798, "Attachment:ENHANCE_ASCEND_BTN.png|Attachment:ENHANCE_HERO_ENHANCE.png")
Dim ENHANCE_ASCEND_CONFIRM_TAR = Array(877, 632, 1006, 698, "Attachment:ENHANCE_HERO_ENHANCE_CONFIRM.png")
Dim ENHANCE_ASCEND_TO_HERO_TAR = Array(1000, 270, 1360, 370, "Attachment:ENHANCE_ASCEND_TO_HERO.png")
Dim ENHANCE_ASCEND_BACK_TAR = Array(40, 10, 120, 65, "Attachment:ENHANCE_ASCEND_BACK.png")

Dim TAP_ENHANCE_HERO_TO_ASCEND = Array(1185, 628)
Dim TAP_ENHANCE_HERO_TO_GRAIL = Array(1185, 628)
Dim TAP_ENHANCE_ASCEND_BTN = Array(1391, 739)
Dim TAP_ENHANCE_ASCEND_CONFIRM = Array(943, 662)
Dim TAP_ENHANCE_ASCEND_TO_HERO = Array(1180, 321)
Dim TAP_ENHANCE_ASCEND_BACK = Array(60, 40)
Dim TAP_ENHANCE_BLIND_SKIP = Array(1060, 760)
Dim MODAL_CLOSE_TAR = Array(580, 620, 850, 720, "Attachment:AGAIN_ALERT_CLOSE.png")
Dim TAP_MODAL_CLOSE = Array(663, 684)

Dim POOLFRIEND_CONTINUE_TAR = Array(720, 720, 990, 800, "Attachment:POOLFRIEND_CONTINUE.png")
Dim POOLFRIEND_GO_TAR = Array(830, 600, 1080, 670, "Attachment:POOLFRIEND_GO.png")
Dim POOLFRIEND_ICON_TAR = Array(590, 625, 645, 675, "Attachment:POOLFRIEND_ICON.png")
Dim POOLFRIEND_LIMIT_TAR = Array(920, 495, 1180, 565, "Attachment:POOLFRIEND_LIMIT.png")
Dim POOLFRIEND_RIGHT_COORD = Array(963, 582)
Dim POOLFRIEND_MID_COORD = Array(719, 582)

Dim ENHANCE_EQUIP_TAR = Array(880, 5, 1300, 70, "Attachment:ENHANCE_EQUIP.png")
Dim ENHANCE_EQUIP_ENHANCE_TAR = Array(1340, 716, 1438, 798, "Attachment:ENHANCE_EQUIP_ENHANCE.png")
Dim ENHANCE_EQUIP_ENHANCE_GRAY_TAR = Array(1340, 716, 1438, 798, "Attachment:ENHANCE_EQUIP_ENHANCE_GRAY.png")
Dim ENHANCE_EQUIP_ENHANCE_CONFIRM_TAR = Array(877, 632, 1006, 698, "Attachment:ENHANCE_EQUIP_ENHANCE_CONFIRM.png")

Dim ENHANCE_SKILL_TAR = Array(880, 5, 1300, 70, "Attachment:ENHANCE_SKILL.png")
Dim ENHANCE_SKILL_ENHANCE_TAR = Array(1340, 716, 1438, 798, "Attachment:ENHANCE_SKILL_ENHANCE.png")
Dim ENHANCE_SKILL_ENHANCE_CONFIRM_TAR = Array(875, 590, 1020, 680, "Attachment:ENHANCE_SKILL_ENHANCE_CONFIRM.png")
Dim ENHANCE_SKILL_ENHANCE_L10_TAR = Array(450, 490, 610, 630, "Attachment:ENHANCE_SKILL_ENHANCE_L10.png")
Dim ENHANCE_SKILL_CLICK_COORD = Array(1100, 765)
Dim ENHANCE_SKILL_MAX_L10_TAR = Array(1150, 720, 1410, 800, "Attachment:ENHANCE_SKILL_MAX_L10.png")
Dim TAP_ENHANCE_SKILL_1 = Array(532, 286)
Dim TAP_ENHANCE_SKILL_2 = Array(852, 286)
Dim TAP_ENHANCE_SKILL_3 = Array(1172, 286)
Dim ENHANCE_SKILL_HERO_UNSELECTED_TAR = Array(140, 560, 300, 630, "Attachment:ENHANCE_SKILL_HERO_UNSELECTED.png")
Dim ENHANCE_SKILL_APPEND_TAR = Array(1000, 5, 1250, 75, "Attachment:ENHANCE_SKILL_APPEND.png")









' VARIATE

' Dim 鐏炲繐绠峰Ο閸ф劖鐖X,鐏炲繐绠风痪闈涙綏閺嶅槴
' 鐏炲繐绠峰Ο閸ф劖鐖X=GetScreenX()
' 鐏炲繐绠风痪闈涙綏閺嶅槴=GetScreenY()
' TracePrint 鐏炲繐绠峰Ο閸ф劖鐖X,鐏炲繐绠风痪闈涙綏閺嶅槴
' SetScreenScale 810, 1440, 0


Dim CurrentBattleCount = 0
Dim HasTicket = true   'true: ticket enought or no need ticket
Dim BATTLE_ENDED_EARLY = false
Dim BATTLE_ROUNDS_FINISHED = 0
Dim LAST_ACTION_WAS_ATTACK = false
Dim ROUND_READY_WAIT_GRACE_MS = 2000
Dim BATTLE_END_CONFIRM_COUNT = 3
Dim BATTLE_END_CONFIRM_INTERVAL_MS = 220
Dim AWARD_NEXT_MAX_RETRY = 120




Function BattlePrint(Msg)
	TracePrint "Battle", CurrentBattleCount, Msg
	UpdateRunnerStatus "RUNNING", Msg
	zm.FileWrite "/sdcard/FGO_Q/runner_log.txt", zm.FileRead("/sdcard/FGO_Q/runner_log.txt") & Chr(10) & DateTime.Format() & " " & Msg
End Function

' 间隔 500ms 两次确认是否已返回主界面/地图菜单，避免战斗中蓝色按钮闪光误判
Function IsOutMenuConfirmed()
	IsOutMenuConfirmed = false
	If CheckImg2(AGAIN_BATTLE_OUT_MENU_TAR) = null Then
		Exit Function
	End If
	Delay 500
	If USER_STOP_REQUESTED Or CheckStopSignal() Then
		Exit Function
	End If
	If CheckImg2(AGAIN_BATTLE_OUT_MENU_TAR) <> null Then
		IsOutMenuConfirmed = true
	End If
End Function

Function IsBattleEndDetected()
	Dim ConfirmIndex
	Dim LastTiePoint
	For ConfirmIndex = 1 To BATTLE_END_CONFIRM_COUNT
		' 閸欑憰浣规暰閸戝氭暛閸ョ偞娼甸敍灞芥皑閸掋倕鐣炬禒宥呮躬閹存ɑ鏋
		If CheckImg2(BATTLE_HERO_SKILL_CHECK_TAR) <> null Then
			IsBattleEndDetected = false
			Exit Function
		End If

		Dim TiePoint = CheckImg2(AWARD_TIE_TAR)
		If TiePoint = null Then
			IsBattleEndDetected = false
			Exit Function
		End If

		' 鐠囩拠鍡楀焼闁姘鐖堕崸鎰鐖ｆ导姘濮堥崝閿涘矁浣圭湴鏉╃偟鐢婚崨鎴掕厬娴ｅ秶鐤嗙粙鍐茬暰
		If ConfirmIndex > 1 Then
			If Abs(TiePoint[1] - LastTiePoint[1]) > 12 Or Abs(TiePoint[2] - LastTiePoint[2]) > 12 Then
				IsBattleEndDetected = false
				Exit Function
			End If
		End If

		LastTiePoint = TiePoint
		If ConfirmIndex < BATTLE_END_CONFIRM_COUNT Then
			Delay BATTLE_END_CONFIRM_INTERVAL_MS
		End If
	Next

	IsBattleEndDetected = true
End Function

Function WaitRoundReadyOrBattleEnd()
	Dim WaitedMs = 0
	Dim HeartbeatCounter = 0
	Do While true
		If USER_STOP_REQUESTED Or CheckStopSignal() Then
			WaitRoundReadyOrBattleEnd = false
			Exit Function
		End If

		' 鏅閫氬洖鍚堝氨缁鎬侊細Attack 鎸夐挳宸蹭寒璧
		If CheckImg2(BATTLE_HERO_SKILL_CHECK_TAR) <> null Then
			WaitRoundReadyOrBattleEnd = true
			Exit Function
		End If

		' 鎶鑳/鏀诲嚮/鍔ㄧ敾杩囨浮鏈熷厛缁欏介檺锛岄伩鍏嶆敾鍑婚敭鐭鏆傛秷澶辨椂璇鍒ょ粨鏉
		If LAST_ACTION_WAS_ATTACK And BATTLE_ROUNDS_FINISHED >= 1 And WaitedMs >= ROUND_READY_WAIT_GRACE_MS Then
			If IsBattleEndDetected() Then
				TracePrint "Battle ended while waiting next round (tie detected)"
				BATTLE_ENDED_EARLY = true
				WaitRoundReadyOrBattleEnd = false
				Exit Function
			End If
			If CheckImg2(AWARD_TREASURE_NEXT_TAR) <> null Then
				TracePrint "Battle ended while waiting next round (treasure next detected)"
				BATTLE_ENDED_EARLY = true
				WaitRoundReadyOrBattleEnd = false
				Exit Function
			End If
		End If

		HeartbeatCounter = HeartbeatCounter + 1
		' 蹇冭烦缁存寔锛氭瘡 3 绉掑埛鏂颁竴娆＄姸鎬侊紝闃叉㈢姸鎬佽璇鍒や负绂荤嚎/鏈鍚鍔
		If HeartbeatCounter Mod 10 = 0 Then
			UpdateRunnerStatus "RUNNING", "绛夊緟鍥炲悎灏辩华(" & Int(WaitedMs / 1000) & "s)..."
		End If

		' 寮傚父鍦烘櫙鎺㈡祴锛堝傚凡鎰忓栭鍥炲湴鍥撅級
		If WaitedMs >= 6000 And (HeartbeatCounter Mod 15 = 0) Then
			If IsOutMenuConfirmed() Then
				AbortBattle "妫娴嬪埌宸茶繑鍥炰富鐣岄潰/鍦板浘鑿滃崟锛岃嚜鍔ㄧ粨鏉熸垬鏂"
				WaitRoundReadyOrBattleEnd = false
				Exit Function
			End If
		End If

		' 瓒呮椂淇濇姢锛氭渶澶氱瓑寰 90 绉掞紙娑电洊缁濆ぇ閮ㄥ垎鏈闀垮疂鍏峰姩鐢+鏁屾柟琛屽姩锛
		If WaitedMs >= 90000 Then
			If IsBattleEndDetected() Or CheckImg2(AWARD_TREASURE_NEXT_TAR) <> null Then
				TracePrint "Battle end detected at timeout boundary"
				BATTLE_ENDED_EARLY = true
				WaitRoundReadyOrBattleEnd = false
				Exit Function
			Else
				AbortBattle "绛夊緟鍥炲悎灏辩华瓒呮椂(90s)锛屽凡鑷鍔ㄧ粨鏉熸垬鏂楅伩鍏嶅崱姝"
				WaitRoundReadyOrBattleEnd = false
				Exit Function
			End If
		End If

		Delay 300
		WaitedMs = WaitedMs + 300
	Loop
End Function

Function clickAndWaitSkillAction()
	Delay BATTLE_SKILL_SPEEDUP_AWAIT_MS
	tap BATTLE_SKILL_SPEEDUP_COORD[1], BATTLE_SKILL_SPEEDUP_COORD[2]
	Delay BATTLE_SKILL_NORMAL_AWAIT_MS
End Function









// 閸欐牕娴樺▔>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

Function CheckAndTapImg2(Target, TapPoint)
	TracePrint "CheckAndTapImg2", Target[1], Target[2], Target[5]
	Dim Point = ContinuousCheckImg(Target)
	If Point = null Then
		Exit Function
	End If
	Dim TapPointX
	Dim TapPointY
	If Not IsNull(TapPoint) Then
		TapPointX = TapPoint[1]
		TapPointY = TapPoint[2]
	Else
		TapPointX = Point[1]
		TapPointY = Point[2]
	End If
	tap TapPointX, TapPointY
End Function

Function ContinuousCheckImgTimeout(Target, MaxWaitCount)
	Dim GetImgCoord
	Dim waitCount = 0
	Do While true
		If USER_STOP_REQUESTED Or CheckStopSignal() Then
			ContinuousCheckImgTimeout = null
			Exit Function
		End If
		GetImgCoord = CheckImg2(Target)
		If GetImgCoord <> null Then
			ContinuousCheckImgTimeout = Array(GetImgCoord[1], GetImgCoord[2])
			Exit Do
		End If
		waitCount = waitCount + 1
		If waitCount Mod 6 = 0 Then
			UpdateRunnerStatus "RUNNING", "绛夊緟鍥剧墖(" & Int(waitCount / 2) & "s): " & Target[5]
		End If
		' 寮傚父鍦烘櫙鎺㈡祴锛堝�宸插湪涓荤晫闈�/鍦板浘锛屾垨浣撳姏寮圭獥鍑虹幇锛�
		If waitCount >= 8 And (waitCount Mod 4 = 0) Then
			If IsOutMenuConfirmed() Then
				AbortBattle "妫€娴嬪埌宸茶繑鍥炰富鐣岄潰/鍦板浘鑿滃崟锛岃嚜鍔ㄧ粨鏉熸垬鏂�"
				ContinuousCheckImgTimeout = null
				Exit Function
			End If
			If CheckImg2(APPLE_DISPLAY_TAR) <> null Then
				If APPLE_ENABLE <= 0 Then
					TracePrint "AP depleted and apple disabled, keeping dialog open for manual decision"
					AbortBattle "妫€娴嬪埌浣撳姏涓嶈冻涓旀湭寮€鍚�悆鑻规灉锛屼繚鐣欏脊绐楀苟缁堟�"
					ContinuousCheckImgTimeout = null
					Exit Function
				End If
			End If
		End If
		' 瓒呮椂淇濇姢
		If waitCount >= MaxWaitCount Then
			AbortBattle "鎵惧浘瓒呮椂(" & Int(MaxWaitCount / 2) & "s): " & Target[5] & "锛屽凡鑷�姩缁撴潫鎴樻枟閬垮厤鍗℃�"
			ContinuousCheckImgTimeout = null
			Exit Function
		End If
		Delay 500
	Loop
	TracePrint "found: ", GetImgCoord[1], GetImgCoord[2]
End Function
Function ContinuousCheckImg(Target)
	ContinuousCheckImg = ContinuousCheckImgTimeout(Target, 60)
End Function
Function WaitAwardTieScreen()
	WaitAwardTieScreen = false
	Dim waitCount = 0
	Dim maxWaitCount = 180
	TracePrint "WaitAwardTieScreen start, max wait 90s"
	
	Do While true
		If USER_STOP_REQUESTED Or CheckStopSignal() Then
			WaitAwardTieScreen = false
			Exit Function
		End If
		' 1. 浼樺厛妫€娴嬫槸鍚﹀凡鍑虹幇銆屼笌浠庤€呯殑缇佺粖銆�
		Dim tiePoint = CheckImg2(AWARD_TIE_TAR)
		If tiePoint <> null Then
			TracePrint "Found AWARD_TIE at", tiePoint[1], tiePoint[2], "tap award coord"
			tap AWARD_TAP_COORD[1], AWARD_TAP_COORD[2]
			WaitAwardTieScreen = true
			Exit Function
		End If
		' 2. 瀹归敊锛氭�娴嬫槸鍚﹀凡鐩存帴璺宠繃缇佺粖骞跺埌杈俱€屾垬鍒╁搧/涓嬩竴姝ャ€嶇晫闈�
		If CheckImg2(AWARD_TREASURE_NEXT_TAR) <> null Then
			TracePrint "AWARD_TREASURE_NEXT already visible, proceed to treasure"
			WaitAwardTieScreen = true
			Exit Function
		End If
		' 3. 瀹归敊锛氭�娴嬫槸鍚﹀凡鐩存帴鍑虹幇銆屽啀娆″嚭鍑�/鏈�嫢鏈夋垬鍒搞€嶅脊绐�
		If CheckImg2(AGAIN_ALERT_AGAIN_TAR) <> null Or CheckImg2(AGAIN_ORDEAL_NO_TICKET_TAR) <> null Then
			TracePrint "Again alert already visible, proceed to again"
			WaitAwardTieScreen = true
			Exit Function
		End If
		' 4. 寮傚父鍦烘櫙锛氬凡鎰忓�杩斿洖涓荤晫闈�/鍦板浘
		If waitCount >= 10 And (waitCount Mod 6 = 0) Then
			If IsOutMenuConfirmed() Then
				AbortBattle "妫€娴嬪埌宸茶繑鍥炰富鐣岄潰/鍦板浘鑿滃崟锛岃嚜鍔ㄧ粨鏉熸垬鏂�"
				WaitAwardTieScreen = false
				Exit Function
			End If
		End If
		waitCount = waitCount + 1
		If waitCount Mod 6 = 0 Then
			UpdateRunnerStatus "RUNNING", "绛夊緟缁撶畻鐣岄潰(" & Int(waitCount / 2) & "s)..."
		End If
		' 5. 鍔ㄧ敾鍔犻€燂細绛夊緟瓒呰繃 6 绉掑悗锛堝凡杩囨妧鑳芥敾鍑绘湡锛屾�澶勪簬鏁屼汉鍊掑湴/BATTLE FINISH/鑳滃埄濮垮娍锛夛紝
		' 姣忛殧 2 绉掕交瑙︿竴娆＄┖鐧藉尯鍩� (AWARD_TAP_COORD)锛屽姞閫熻烦杩囪儨鍒╁彴璇嶄笌缁撶畻榛戝睆杩囨浮
		If waitCount >= 12 And (waitCount Mod 4 = 0) Then
			tap AWARD_TAP_COORD[1], AWARD_TAP_COORD[2]
		End If
		' 6. 瓒呮椂淇濇姢 (90s)
		If waitCount >= maxWaitCount Then
			AbortBattle "绛夊緟缁撶畻鐣岄潰瓒呮椂(90s)锛屽凡鑷�姩缁撴潫鎴樻枟閬垮厤鍗℃�"
			WaitAwardTieScreen = false
			Exit Function
		End If
		Delay 500
	Loop
End Function

Function ContinuousCheckImgTags(Targets)
	Dim GetImgCoord
	Dim TargetIndex
	Dim TargetCount = UBound(Targets) + 1
	Dim waitCount = 0
	TracePrint "ContinuousCheckImgTags", TargetCount
	Do While true
		If USER_STOP_REQUESTED Or CheckStopSignal() Then
			ContinuousCheckImgTags = 0
			Exit Function
		End If
		For TargetIndex = 1 To TargetCount
			GetImgCoord = CheckImg2(Targets[TargetIndex])
			If GetImgCoord <> null Then
				ContinuousCheckImgTags = TargetIndex
				Exit Do
			End If
			Delay 100
		Next
		If GetImgCoord <> null Then
			Exit Do
		End If

		waitCount = waitCount + 1
		If waitCount Mod 5 = 0 Then
			UpdateRunnerStatus "RUNNING", "绛夊緟缁撶畻鍑哄嚮閫夐」(" & Int(waitCount * 0.7) & "s)..."
		End If

		' 瓒呮椂淇濇姢锛氭渶澶氱瓑寰呯害 45 绉 (60 娆)
		If waitCount >= 60 Then
			AbortBattle "缁撶畻鍑哄嚮閫夐」鍖归厤瓒呮椂(45s)锛屽凡鑷鍔ㄧ粨鏉熸垬鏂楅伩鍏嶅崱姝"
			ContinuousCheckImgTags = 0
			Exit Function
		End If

		Delay 300
	Loop
	TracePrint "found: ", TargetIndex, GetImgCoord[1], GetImgCoord[2]
End Function

Function ContinuousCheckImgMiss(Target)
	Dim GetImgCoord
	Dim missWaitCount = 0
	Do While true
		If USER_STOP_REQUESTED Or CheckStopSignal() Then
			ContinuousCheckImgMiss = null
			Exit Function
		End If
		GetImgCoord = CheckImg2(Target)
		If GetImgCoord = null Then
			ContinuousCheckImgMiss = null
			Exit Do
		End If
		missWaitCount = missWaitCount + 1
		If missWaitCount Mod 6 = 0 Then
			UpdateRunnerStatus "RUNNING", "绛夊緟鍥剧墖娑堝け: " & Target[5]
		End If
		If missWaitCount >= 40 Then
			TracePrint "ContinuousCheckImgMiss timeout (20s):", Target[5]
			ContinuousCheckImgMiss = null
			Exit Do
		End If
		Delay 500
	Loop
	TracePrint "missed: ", Target[1], Target[2]
End Function

Function CheckNoImgAndTap2(Target, TapPoint)
	Dim AttachedImg = Target[5]
	Dim RetryCount = 0
	Do While true
		If USER_STOP_REQUESTED Or CheckStopSignal() Then
			CheckNoImgAndTap2 = false
			Exit Do
		End If
		Dim GetImgCoord = CheckImg2(Target)
		If GetImgCoord = null Then
			TracePrint "cannot find ", AttachedImg, "then tap", TapPoint[1], TapPoint[2]
			tap TapPoint[1], TapPoint[2]
		Else
			CheckNoImgAndTap2 = true
			Exit Do
		End If
		Delay 300
		RetryCount = RetryCount + 1
		If RetryCount Mod 10 = 0 Then
			If RUN_MODE = 1 Then
				Dim extraActDesc = CURRENT_EXTRA_ACTION_NAME
				If Len(extraActDesc) = 0 Then extraActDesc = "鏁村"
				UpdateRunnerStatus "RUNNING", "Extra [" & extraActDesc & "] 绛夊緟鍔ㄧ敾(" & Int(RetryCount * 0.3) & "s)..."
			Else
				UpdateRunnerStatus "RUNNING", "缁撶畻绛夊緟涓嬩竴姝(" & Int(RetryCount * 0.3) & "s)..."
			End If
		End If
		If RetryCount >= AWARD_NEXT_MAX_RETRY Then
			TracePrint "wait target timeout:", AttachedImg
			CheckNoImgAndTap2 = false
			Exit Do
		End If
	Loop
End Function

Function ResolveTargetImg(rawAttachedImg)
	If IsNull(rawAttachedImg) Or Len(rawAttachedImg) = 0 Then
		ResolveTargetImg = ""
		Exit Function
	End If
	Dim imgList = Split(CStr(rawAttachedImg), "|")
	Dim resolvedStr = ""
	Dim oneImg, fileName, sdPath, pickedPath
	For Each oneImg In imgList
		oneImg = Trim(CStr(oneImg))
		fileName = oneImg
		If InStr(1, oneImg, "Attachment:") = 1 Then
			fileName = Mid(oneImg, 12, Len(oneImg) - 11)
		ElseIf InStr(1, oneImg, "/") > 0 Then
			Dim pathParts = Split(oneImg, "/")
			fileName = pathParts(UBound(pathParts))
		End If
		pickedPath = "Attachment:" & fileName
		If InStr(1, oneImg, "/") = 1 And Dir.Exist(oneImg) = 1 Then
			pickedPath = oneImg
		Else
			sdPath = "/sdcard/FGO_Q/images/" & fileName
			If Dir.Exist(sdPath) = 1 Then
				pickedPath = sdPath
			Else
				sdPath = "/storage/emulated/0/FGO_Q/images/" & fileName
				If Dir.Exist(sdPath) = 1 Then
					pickedPath = sdPath
				End If
			End If
		End If
		If Len(resolvedStr) = 0 Then
			resolvedStr = pickedPath
		Else
			resolvedStr = resolvedStr & "|" & pickedPath
		End If
	Next
	ResolveTargetImg = resolvedStr
End Function

Function CheckImg2(Target)
	Dim Area = Target
	Dim AttachedImg = ResolveTargetImg(Target[5])
	Dim intX, intY
	intX = -1 : intY = -1
	FindPic Area[1], Area[2], Area[3], Area[4], AttachedImg, "000000", 0, 0.9, intX, intY
	If intX > -1 And intY > -1 Then
		CheckImg2 = Array(intX, intY)
		Exit Function
	End If
	If InStr(1, AttachedImg, "|") > 0 Then
		Dim subImgs = Split(AttachedImg, "|")
		Dim oneSub
		For Each oneSub In subImgs
			oneSub = Trim(CStr(oneSub))
			If Len(oneSub) > 0 Then
				intX = -1 : intY = -1
				FindPic Area[1], Area[2], Area[3], Area[4], oneSub, "000000", 0, 0.9, intX, intY
				If intX > -1 And intY > -1 Then
					CheckImg2 = Array(intX, intY)
					Exit Function
				End If
			End If
		Next
	End If

	' 第二遍容差匹配（针对半透明光效、渐变背景与微色偏 UI）
	intX = -1 : intY = -1
	FindPic Area[1], Area[2], Area[3], Area[4], AttachedImg, "151515", 0, 0.8, intX, intY
	If intX > -1 And intY > -1 Then
		CheckImg2 = Array(intX, intY)
		Exit Function
	End If
	If InStr(1, AttachedImg, "|") > 0 Then
		Dim subImgs2 = Split(AttachedImg, "|")
		Dim oneSub2
		For Each oneSub2 In subImgs2
			oneSub2 = Trim(CStr(oneSub2))
			If Len(oneSub2) > 0 Then
				intX = -1 : intY = -1
				FindPic Area[1], Area[2], Area[3], Area[4], oneSub2, "151515", 0, 0.8, intX, intY
				If intX > -1 And intY > -1 Then
					CheckImg2 = Array(intX, intY)
					Exit Function
				End If
			End If
		Next
	End If
End Function

Function CheckPriorityImg(Target, Similarity)
	CheckPriorityImg = CheckPriorityImgEx(Target, Similarity, "000000")
End Function

Function CheckPriorityImgEx(Target, Similarity, OffsetColor)
	If IsNull(Similarity) Then
		Similarity = BATTLE_ATTACK_CARD_PRIORITY_SIM
	End If
	If IsNull(OffsetColor) Or Len(OffsetColor) = 0 Then
		OffsetColor = "000000"
	End If
	Dim Area = Target
	Dim AttachedImg = ResolveTargetImg(Target[5])
	Dim intX, intY
	intX = -1 : intY = -1
	FindPic Area[1], Area[2], Area[3], Area[4], AttachedImg, OffsetColor, 0, Similarity, intX, intY
	If intX > -1 And intY > -1 Then
		CheckPriorityImgEx = Array(intX, intY)
		Exit Function
	End If
	If InStr(1, AttachedImg, "|") > 0 Then
		Dim subImgs = Split(AttachedImg, "|")
		Dim oneSub
		For Each oneSub In subImgs
			oneSub = Trim(CStr(oneSub))
			If Len(oneSub) > 0 Then
				intX = -1 : intY = -1
				FindPic Area[1], Area[2], Area[3], Area[4], oneSub, OffsetColor, 0, Similarity, intX, intY
				If intX > -1 And intY > -1 Then
					CheckPriorityImgEx = Array(intX, intY)
					Exit Function
				End If
			End If
		Next
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

// 閹锋牗瀚>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
Function TouchMoveWithDownTime(Target,DownTime)
	TouchDown Target[1], Target[2], 1 //閹稿夌秶鐏炲繐绠锋稉濠勬畱a閸ф劖鐖ｆ稉宥嗘杹,楠炴儼鍓х枂濮濄倛袝閻愮紻=1
	If IsNull(DownTime) Then
    	DownTime = 500
	End If
	Delay DownTime
	TouchMove Target[3], Target[4], 1, 500 //鐏忓捄D=1閻ㄥ嫯袝閻愮呭Сx濮ｇ粔鎺斝╅崝銊ㄥ殾b閸ф劖鐖
	Delay 500
	TouchUp 1//閺夋儳绱戝纭呮崳ID=1閻ㄥ嫯袝閻
End Function

Function PageTurnByScrollbar(turnIndex)
	Dim startY = PREPARE_FRIEND_SCROLLBAR_BASE_Y + (turnIndex - 1) * PREPARE_FRIEND_SCROLLBAR_STEP_Y
	Dim endY = PREPARE_FRIEND_SCROLLBAR_BASE_Y + turnIndex * PREPARE_FRIEND_SCROLLBAR_STEP_Y
	BattlePrint("执行右侧滚动条翻页: 第 " & turnIndex & " 次，从 (" & PREPARE_FRIEND_SCROLLBAR_X & "," & startY & ") 平滑拖拽到 (" & PREPARE_FRIEND_SCROLLBAR_X & "," & endY & ")")
	TouchDown PREPARE_FRIEND_SCROLLBAR_X, startY, 1
	Delay 100

	' 按照游戏机制规范: 15步高频插值连续发送TouchMove，产生真正的ACTION_MOVE轨迹，100%激活Unity Scrollbar OnDrag
	Dim stepCount = 15
	Dim s
	For s = 1 To stepCount
		Dim curY = Int(startY + (endY - startY) * s / stepCount)
		TouchMove PREPARE_FRIEND_SCROLLBAR_X, curY, 1
		Delay 25
	Next

	Delay 150
	TouchUp 1
	Delay PREPARE_FRIEND_PAGE_SWIPE_DELAY
End Function

// do Battle >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
Function IsOnFriendSelectScreen()
	IsOnFriendSelectScreen = (CheckImg2(PREPARE_FRIEND_TITLE_TAR) <> null Or CheckImg2(PREPARE_FRIEND_REFRESH_TAR) <> null)
End Function

Function WaitFriendScreenReady()
	WaitFriendScreenReady = false
	Dim startTime = Time()
	Dim maxWaitSec = 30 ' 最长等待 30 秒真实时间（网络与动画加载）
	Dim HeartbeatCounter = 0

	Do While (Time() - startTime) < maxWaitSec
		If USER_STOP_REQUESTED Or CheckStopSignal() Then
			Exit Function
		End If

		' 1. 助战标题「助战选择」或「列表更新」出现
		If CheckImg2(PREPARE_FRIEND_TITLE_TAR) <> null Or CheckImg2(PREPARE_FRIEND_REFRESH_TAR) <> null Then
			WaitFriendScreenReady = true
			Delay 500 ' 额外预留 500ms 确保好友卡片与滑块渲染完毕且无惯性浮动
			Exit Function
		End If

		' 2. 目标助战头像本身已被检测到（快速直通）
		If CheckImg2(PREPARE_FRIEND_TAR) <> null Then
			WaitFriendScreenReady = true
			Exit Function
		End If

		' 3. 队伍开始确认界面或战斗中界面（意外直入）
		If CheckImg2(START_TAR) <> null Or CheckImg2(BATTLE_HERO_SKILL_CHECK_TAR) <> null Then
			WaitFriendScreenReady = true
			Exit Function
		End If

		HeartbeatCounter = HeartbeatCounter + 1
		If HeartbeatCounter Mod 6 = 0 Then
			UpdateRunnerStatus "RUNNING", "等待进入助战选择界面(" & (Time() - startTime) & "s)..."
		End If

		Delay 250
	Loop
End Function

Function ChooseFriend()
	BattlePrint("Choose Friend: key=" & selectedFriendKey & ", area=(" & PREPARE_FRIEND_TAR[1] & "," & PREPARE_FRIEND_TAR[2] & "," & PREPARE_FRIEND_TAR[3] & "," & PREPARE_FRIEND_TAR[4] & "), maxPageTurns=" & selectedPageTurns)

	' 1. 确保助战选择界面已完全加载完毕（防止连续出击过渡期或网络延迟导致的过早判定）
	If Not WaitFriendScreenReady() Then
		If Not USER_STOP_REQUESTED Then
			AbortBattle "等待进入助战选择界面超时(30s)，已自动停止保护现场"
		End If
		Exit Function
	End If
	Dim curPageTurn = 0
	Dim Point = null

	Do While true
		If USER_STOP_REQUESTED Or CheckStopSignal() Then
			Exit Function
		End If

		' 仅在首次翻页前(curPageTurn=0)启用重试机制：间隔500ms，最多尝试3次；翻页后仅检测1次
		Dim maxCheckRetry = 1
		If curPageTurn = 0 Then
			maxCheckRetry = 3
		End If
		Dim checkRetry = 0
		For checkRetry = 1 To maxCheckRetry
			Point = CheckImg2(PREPARE_FRIEND_TAR)
			If Point <> null Then
				Exit For
			End If
			If checkRetry < maxCheckRetry Then
				Delay 500
				If USER_STOP_REQUESTED Or CheckStopSignal() Then
					Exit Function
				End If
			End If
		Next

		If Point <> null Then
			BattlePrint("鎴愬姛鎵惧埌鍔╂垬濂藉弸(" & selectedFriendKey & ")锛屼綅浜 (" & Point[1] & "," & Point[2] & ")锛岀疮璁＄炕椤: " & curPageTurn & " 娆")
			Exit Do
		End If

		' 褰撳墠椤甸潰鏈鎵惧埌锛屼笖缈婚〉娆℃暟灏氭湭杈惧埌涓婇檺鏃讹紝鎵嶈Е鍙戠炕椤
		If curPageTurn < selectedPageTurns Then
			curPageTurn = curPageTurn + 1
			BattlePrint("褰撳墠椤垫湭鎵惧埌鍔╂垬(" & selectedFriendKey & ")锛岃Е鍙戠炕椤 (" & curPageTurn & "/" & selectedPageTurns & ")...")
			PageTurnByScrollbar(curPageTurn)
		Else
			' 缈婚〉娆℃暟鐢ㄥ敖浠嶆湭鎵惧埌
			Exit Do
		End If
	Loop

	If Point = null Or USER_STOP_REQUESTED Then
		If Not USER_STOP_REQUESTED Then
			AbortBattle "鏈鎵惧埌鍔╂垬濂藉弸(" & selectedFriendKey & ")锛屽凡缈婚〉 " & curPageTurn & " 娆★紝宸茶嚜鍔ㄧ粨鏉熸垬鏂楅伩鍏嶅崱姝"
		End If
		Exit Function
	End If

	Dim TapPointX = Point[1]
	Dim TapPointY = Point[2]
	// todo check friend equip
	Delay 100
	tap TapPointX, TapPointY
End Function

Function HandleEatApple()
	HandleEatApple = false
	If APPLE_ENABLE <= 0 Then
		TracePrint "AP depleted and apple disabled, keeping dialog open for manual decision"
		AbortBattle "妫娴嬪埌浣撳姏涓嶈冻涓旀湭寮鍚鍚冭嫻鏋滐紝淇濈暀寮圭獥绛夊緟浜哄伐澶勭悊"
		Exit Function
	End If

	Dim silverSecondConfirm
	Dim goldSecondConfirm

	If APPLE_ENABLE = 1 Then
		TracePrint "Eating silver apple..."
		UpdateRunnerStatus "RUNNING", "琛ュ厖浣撳姏(閾惰嫻鏋)涓..."
		' 1. 鐐瑰嚮閫夋嫨鐧介摱鏋滃疄
		If CheckImg2(APPLE_DISPLAY_TAR) <> null Then
			CheckAndTapImg2(APPLE_DISPLAY_TAR, APPLE_SILVER_COORD)
			Delay 800
		End If
		If USER_STOP_REQUESTED Or CheckStopSignal() Then Exit Function

		' 2. 閾惰嫻鏋滅 1 娆＄‘璁わ細浣跨敤鏁伴噺纭璁ゅ脊绐楋紙榛樿ゆ秷鑰1涓锛岀洿鎺ョ偣鍑诲喅瀹氾級
		TracePrint "Silver apple: confirming quantity (tap decide)..."
		CheckAndTapImg2(APPLE_CONFIRM_TAR, APPLE_CONFIRM_COORD)
		Delay 1000
		If USER_STOP_REQUESTED Or CheckStopSignal() Then Exit Function

		' 3. 閾惰嫻鏋滅 2 娆＄‘璁ゆ娴嬶細鑻ュ脊鍑烘渶缁堟秷鑰椾簩娆＄‘璁わ紝鍐嶆＄偣鍑诲喅瀹
		silverSecondConfirm = CheckImg2(APPLE_CONFIRM_TAR)
		If silverSecondConfirm <> null Then
			TracePrint "Silver apple: final usage confirm (tap decide)..."
			tap APPLE_CONFIRM_COORD[1], APPLE_CONFIRM_COORD[2]
			Delay 1000
		End If

		' 4. 绛夊緟浣撳姏鎭㈠嶅脊绐楀畬鍏ㄥ叧闂
		ContinuousCheckImgMiss(APPLE_DISPLAY_TAR)
		Delay 800
		HandleEatApple = true
	ElseIf APPLE_ENABLE >= 2 Then
		TracePrint "Eating golden apple..."
		UpdateRunnerStatus "RUNNING", "琛ュ厖浣撳姏(閲戣嫻鏋)涓..."
		' 1. 鐐瑰嚮閫夋嫨榛勯噾鏋滃疄
		If CheckImg2(APPLE_DISPLAY_TAR) <> null Then
			CheckAndTapImg2(APPLE_DISPLAY_TAR, APPLE_GLODEN_COORD)
			Delay 800
		End If
		If USER_STOP_REQUESTED Or CheckStopSignal() Then Exit Function

		' 2. 閲戣嫻鏋滅‘璁わ細鐩存帴鐐瑰嚮鍐冲畾
		TracePrint "Golden apple: confirming usage (tap decide)..."
		CheckAndTapImg2(APPLE_CONFIRM_TAR, APPLE_CONFIRM_COORD)
		Delay 1000
		If USER_STOP_REQUESTED Or CheckStopSignal() Then Exit Function

		' 3. 浜屾℃鏌ワ細闃茬矘杩/浜屾″脊绐
		goldSecondConfirm = CheckImg2(APPLE_CONFIRM_TAR)
		If goldSecondConfirm <> null Then
			tap APPLE_CONFIRM_COORD[1], APPLE_CONFIRM_COORD[2]
			Delay 1000
		End If

		' 4. 绛夊緟浣撳姏鎭㈠嶅脊绐楀畬鍏ㄥ叧闂
		ContinuousCheckImgMiss(APPLE_DISPLAY_TAR)
		Delay 800
		HandleEatApple = true
	End If
End Function

Function CheckBattleStart()
	CheckBattleStart = false
	TracePrint "Battle Start Check: wait START or ATTACK"
	Dim checkWaitCount = 0
	Do While true
		If USER_STOP_REQUESTED Or CheckStopSignal() Then
			CheckBattleStart = false
			Exit Function
		End If
		Dim AttackPoint = CheckImg2(BATTLE_HERO_SKILL_CHECK_TAR)
		Dim AttackBackPoint = CheckImg2(BATTLE_ATTACK_BACK_TAR)
		If AttackPoint <> null Or AttackBackPoint <> null Then
			TracePrint "Battle Start: ATTACK found (entered battle), start battle actions"
			CheckBattleStart = true
			Exit Function
		End If

		' 寮傚父涓庝綋鍔涘脊绐楁娴嬶紙浼樺厛妫娴嬩綋鍔涗笉瓒筹紝闃叉㈢偣鍑 START 鍚庡崱鍦ㄥ脊绐楋級
		If CheckImg2(APPLE_DISPLAY_TAR) <> null Then
			If Not HandleEatApple() Or USER_STOP_REQUESTED Or CheckStopSignal() Then
				CheckBattleStart = false
				Exit Function
			Else
				checkWaitCount = 0
				Delay 1000
			End If
		End If

		If checkWaitCount >= 10 And (checkWaitCount Mod 5 = 0) Then
			If IsOutMenuConfirmed() Then
				AbortBattle "妫娴嬪埌宸茶繑鍥炰富鐣岄潰/鍦板浘鑿滃崟锛屾棤娉曞紑濮嬫垬鏂楋紝宸茶嚜鍔ㄧ粨鏉熸垬鏂"
				CheckBattleStart = false
				Exit Function
			End If
		End If

		Dim StartPoint = null
		If Not IsOnFriendSelectScreen() Then
			StartPoint = CheckImg2(START_TAR)
		End If
		If StartPoint <> null Then
			If DEBUG_FRIEND_ONLY > 0 Then
				BattlePrint("【助战调试】已停在队伍确认界面（检测到开始任务按钮），根据配置停止进入战斗。")
				USER_STOP_REQUESTED = true
				ABORT_REASON = "【助战调试完成】已选定助战，已安全停机"
				CheckBattleStart = false
				Exit Function
			End If
			TracePrint "Battle Start: START found (team confirm screen), tap START"
			tap StartPoint[1], StartPoint[2]
			Delay 1200
		Else
			Delay 300
		End If

		checkWaitCount = checkWaitCount + 1
		If checkWaitCount Mod 8 = 0 Then
			UpdateRunnerStatus "RUNNING", "绛夊緟杩涘叆鎴樻枟(" & Int(checkWaitCount * 0.4) & "s)..."
		End If

		' 瓒呮椂淇濇姢锛氭渶澶氱害 60 绉 (150 娆)
		If checkWaitCount >= 150 Then
			AbortBattle "绛夊緟杩涘叆鎴樻枟瓒呮椂(60s)锛屽凡鑷鍔ㄧ粨鏉熸垬鏂楅伩鍏嶅崱姝"
			CheckBattleStart = false
			Exit Function
		End If
	Loop
End Function

Function CheckFirstBattle2Start()
	CheckFirstBattle2Start = CheckBattleStart()
End Function

Function DoSkillActions(ActionsGroup)
	LAST_ACTION_WAS_ATTACK = false
	Dim ActionIndex = 2
	Do While true
		If USER_STOP_REQUESTED Or CheckStopSignal() Then
			Exit Do
		End If
		If ActionIndex > 30 Then
			Exit Do
		End If
		Dim CurrentAction = ActionsGroup[ActionIndex]
		If IsNull(CurrentAction) Then
			Exit Do
		ElseIf Len(Trim(CStr(CurrentAction))) = 0 Then
			TracePrint "skill"
			TracePrint "skip empty skill action"
		Else
			TracePrint "skill"
			TracePrint "skill", CurrentAction
			Dim CurrentActionLength = Len(CStr(CurrentAction))
			Dim CurrentActionArr()
			For CurrentActionIndex = 1 To CurrentActionLength
				CurrentActionArr(CurrentActionIndex) = Int(Mid(CStr(CurrentAction), CurrentActionIndex, 1)) ' 鐎涙ê鍙嗛弫鎵绮嶉敍宀鍌ㄥ鏇氱矤0瀵婵
			Next
			Dim SkillIndex = CurrentActionArr(1)
			Dim SkillTargetIndex = CurrentActionArr(2)
			Dim SkillActionType = CurrentActionArr(3)
			If IsNull(SkillIndex) Or SkillIndex <= 0 Then
				TracePrint "invalid skill action, skip", CurrentAction
			Else
				If SkillTargetIndex > 0 Then
					' 1. 纭璁ゆ敾鍑绘寜閽鍦ㄥ満骞剁簿纭瑙﹀彂浠庤呮妧鑳
					CheckAndTapImg2(BATTLE_HERO_SKILL_CHECK_TAR, BATTLE_HERO_SKILL_COORDS[SkillIndex])
					If USER_STOP_REQUESTED Or CheckStopSignal() Then
						Exit Do
					End If
					' 2. 鐘舵侀┍鍔ㄧ函绛夊緟锛100ms 楂橀戞壘鍥撅紝缁濇棤鍥哄畾姝荤瓑寤惰繜锛屼弗绂佺洸鐐规墦鏂寮圭獥
					Dim heroTargetWait = 0
					Dim heroGrantDetected = false
					Do While heroTargetWait < 100
						If USER_STOP_REQUESTED Or CheckStopSignal() Then
							Exit Do
						End If
						If CheckImg2(BATTLE_SKILL_GRANT_CHECK_TAR) <> null Then
							heroGrantDetected = true
							Exit Do
						End If
						Delay 100
						heroTargetWait = heroTargetWait + 1
						' 闀垮懆鏈熼槻涓㈣Е鎺т繚鎶わ細鑻ョ瓑寰呰秴 1.5 绉掓棤鍙嶅簲鍒欒ˉ鐐逛竴娆℃妧鑳
						If heroTargetWait Mod 15 = 0 Then
							tap BATTLE_HERO_SKILL_COORDS[SkillIndex][1], BATTLE_HERO_SKILL_COORDS[SkillIndex][2]
						End If
					Loop
					If Not USER_STOP_REQUESTED And Not CheckStopSignal() And heroGrantDetected Then
						Delay 100
						tap BATTLE_SKILL_GRANT_HREO_COORDS[SkillTargetIndex][1], BATTLE_SKILL_GRANT_HREO_COORDS[SkillTargetIndex][2]
						Delay 300
						clickAndWaitSkillAction()
					ElseIf Not heroGrantDetected And Not USER_STOP_REQUESTED And Not CheckStopSignal() Then
						AbortBattle "绛夊緟鐩鏍囬夋嫨寮圭獥瓒呮椂(10s): " & BATTLE_SKILL_GRANT_CHECK_TAR[5]
					End If
				Else
					CheckAndTapImg2(BATTLE_HERO_SKILL_CHECK_TAR, BATTLE_HERO_SKILL_COORDS[SkillIndex])
					If SkillActionType = 1 Then		' Special Skill(1)
						CheckAndTapImg2(BATTLE_SKILL_SPECIAL_SKILL_A_TAR, BATTLE_SKILL_SPECIAL_SKILL_A_ACT_TARS[CurrentActionArr(4)])
					End If
					clickAndWaitSkillAction()
				End If
			End If
		End If
		ActionIndex = ActionIndex + 1
	Loop
End Function

Function DoMasterActions(ActionsGroup)
	LAST_ACTION_WAS_ATTACK = false
	Dim ActionIndex = 2
	Do While true
		If USER_STOP_REQUESTED Or CheckStopSignal() Then
			Exit Do
		End If
		If ActionIndex > 30 Then
			Exit Do
		End If
		Dim CurrentAction = ActionsGroup[ActionIndex]
		If IsNull(CurrentAction) Then
			Exit Do
		ElseIf Len(Trim(CStr(CurrentAction))) = 0 Then
			TracePrint "master"
			TracePrint "skip empty master action"
		Else
			TracePrint "master"
			CheckAndTapImg2(BATTLE_HERO_SKILL_CHECK_TAR, BATTLE_MASTER_SKILL_OPEN_COORDS)
			Delay BATTLE_MASTER_SKILL_AWAIT_MS

			TracePrint "master", CurrentAction
			Dim CurrentActionLength = Len(CStr(CurrentAction))
			Dim CurrentActionArr()
			For CurrentActionIndex = 1 To CurrentActionLength
				CurrentActionArr(CurrentActionIndex) = Int(Mid(CStr(CurrentAction), CurrentActionIndex, 1)) ' 鐎涙ê鍙嗛弫鎵绮嶉敍宀鍌ㄥ鏇氱矤0瀵婵
			Next
			Dim SkillIndex = CurrentActionArr(1)
			Dim SkillTargetIndex = CurrentActionArr(2)
			Dim SkillActionType = CurrentActionArr(3)
			If IsNull(SkillIndex) Or SkillIndex <= 0 Then
				TracePrint "invalid master action, skip", CurrentAction
			Else
				ContinuousCheckImg(BATTLE_MASTER_SKILL_DISPLAY_TAR)
				Delay 200
				If SkillActionType = 0 Then		' Special Skill(0):change (鎹浜)
					tap BATTLE_MASTER_SKILL_COORDS[SkillIndex][1], BATTLE_MASTER_SKILL_COORDS[SkillIndex][2]
					Delay 400
					Dim SkillChangeTargetIndex1 = CurrentActionArr(4)
					Dim SkillChangeTargetIndex2 = CurrentActionArr(5)
					CheckAndTapImg2(BATTLE_SKILL_CHANGE_CHECK_TAR, BATTLE_SKILL_CHANGE_HERO_COORDS[SkillChangeTargetIndex1])
					Delay BATTLE_SKILL_CHANGE_SELECTED_AWAIT_MS
					CheckAndTapImg2(BATTLE_SKILL_CHANGE_CHECK_TAR, BATTLE_SKILL_CHANGE_HERO_COORDS[SkillChangeTargetIndex2])
					CheckAndTapImg2(BATTLE_SKILL_CHANGE_SELECTEED_CHECK_TAR, null)
					' 鎹浜哄悗鍓嶆帓浠庤呮Ы浣嶅ご鍍忕紦瀛樺け鏁堬紝閲嶇疆瀵瑰簲妲戒綅鐨勯噰鏍锋爣璁颁互鏀鎸佸悗鎺掓柊浠庤呴噸鏂伴噰鏍
					If SkillChangeTargetIndex1 >= 1 And SkillChangeTargetIndex1 <= 3 Then
						BATTLE_HERO_SAMPLED[SkillChangeTargetIndex1] = 0
						BATTLE_ATTACK_CARD_PRIORITY_TARS[SkillChangeTargetIndex1] = null
					End If
				ElseIf SkillTargetIndex > 0 Then	' 鎸囧悜鎬ф妧鑳 (閫夋嫨浠庤呯洰鏍)
					' 1. 绮剧‘瑙﹀彂寰′富鎶鑳
					tap BATTLE_MASTER_SKILL_COORDS[SkillIndex][1], BATTLE_MASTER_SKILL_COORDS[SkillIndex][2]
					' 2. 鐘舵侀┍鍔ㄧ函绛夊緟锛100ms 楂橀戞壘鍥撅紝缁濇棤鍥哄畾姝荤瓑寤惰繜锛屼弗绂佸湪姝ゆ湡闂寸洸鐐规墦鏂寮圭獥
					Dim masterTargetWait = 0
					Dim masterGrantDetected = false
					Do While masterTargetWait < 100
						If USER_STOP_REQUESTED Or CheckStopSignal() Then
							Exit Do
						End If
						If CheckImg2(BATTLE_SKILL_GRANT_CHECK_TAR) <> null Then
							masterGrantDetected = true
							Exit Do
						End If
						Delay 100
						masterTargetWait = masterTargetWait + 1
						' 闀垮懆鏈熼槻涓㈣Е鎺т繚鎶わ細鑻ョ瓑寰呰秴 1.5 绉掓棤鍙嶅簲鍒欐俯鍜岃ˉ鐐逛竴娆
						If masterTargetWait Mod 15 = 0 Then
							tap BATTLE_MASTER_SKILL_COORDS[SkillIndex][1], BATTLE_MASTER_SKILL_COORDS[SkillIndex][2]
						End If
					Loop
					If Not USER_STOP_REQUESTED And Not CheckStopSignal() And masterGrantDetected Then
						Delay 100
						tap BATTLE_SKILL_GRANT_HREO_COORDS[SkillTargetIndex][1], BATTLE_SKILL_GRANT_HREO_COORDS[SkillTargetIndex][2]
						Delay 300
					ElseIf Not masterGrantDetected And Not USER_STOP_REQUESTED And Not CheckStopSignal() Then
						AbortBattle "绛夊緟鐩鏍囬夋嫨寮圭獥瓒呮椂(10s): " & BATTLE_SKILL_GRANT_CHECK_TAR[5]
					End If
				Else	' 鍏ㄤ綋/鏃犵洰鏍囨妧鑳
					tap BATTLE_MASTER_SKILL_COORDS[SkillIndex][1], BATTLE_MASTER_SKILL_COORDS[SkillIndex][2]
					Delay 200
				End If

				clickAndWaitSkillAction()
			End If
		End If

		ActionIndex = ActionIndex + 1
	Loop
End Function

Function SelectFallbackCard()
	Dim fallbackOrder = Array(5, 4, 3, 2, 1)
	Dim foIdx
	For foIdx = 1 To 5
		Dim ord = fallbackOrder[foIdx]
		If BATTLE_CARD_CHOSEN[ord] = 0 Then
			BATTLE_CARD_CHOSEN[ord] = 1
			TracePrint "Fallback tap card:", ord
			tap BATTLE_ATTACK_CARD_COORDS[ord][1], BATTLE_ATTACK_CARD_COORDS[ord][2]
			Exit Function
		End If
	Next
	TracePrint "Fallback all chosen, default tap card 5"
	tap BATTLE_ATTACK_CARD_COORDS[5][1], BATTLE_ATTACK_CARD_COORDS[5][2]
End Function

Function TryTapFirstColorCard(colorImg, colorName)
	TryTapFirstColorCard = false
	Dim i
	For i = 1 To 5
		If BATTLE_CARD_CHOSEN[i] = 0 Then
			Dim cx = BATTLE_ATTACK_CARD_COORDS[i][1]
			Dim cardArea = Array(cx - 130, 460, cx + 130, 750, colorImg)
			If CheckImg2(cardArea) <> null Then
				TracePrint "Fallback tap color", colorName, "at card", i
				BATTLE_CARD_CHOSEN[i] = 1
				tap BATTLE_ATTACK_CARD_COORDS[i][1], BATTLE_ATTACK_CARD_COORDS[i][2]
				TryTapFirstColorCard = true
				Exit Function
			End If
		End If
	Next
End Function

Function IsNPCardActive(heroNum)
	IsNPCardActive = false
	If heroNum < 1 Or heroNum > 3 Then Exit Function
	Dim npCenters = Array(444, 720, 996)
	Dim cx = npCenters[heroNum]

	' 瀹濆叿鍗″崌璧锋椂鍗＄墝椤堕儴涓庝袱渚у叿鏈夐珮浜鐧借壊鍗℃嗕笌鍔ㄦ佸厜鏁 (cx - 70 ~ cx + 70, y: 140 ~ 220)
	' 鏈鍗囪捣鐨勫疂鍏峰崱妲戒綅璇ュ尯鍩熺敱浜庤儗鏅鏆楄掑畬鍏ㄦ病鏈夐珮浜鐧藉厜锛堝疄娴嬬櫧鍍忕礌鏁颁负 0 vs 鍗囪捣鏃 2600+锛
	Dim intX, intY
	intX = -1 : intY = -1
	FindColor cx - 70, 140, cx + 70, 220, "FFFFFF", 0, 0.85, intX, intY
	If intX > -1 And intY > -1 Then
		IsNPCardActive = true
	End If
End Function

Sub SaveDebugScreen(sceneName)
	If DEBUG_SCREENSHOT_ENABLE <> 1 Then
		Exit Sub
	End If
	If Dir.Exist("/sdcard/FGO_Q/images") = 0 Then
		Dir.Create("/sdcard/FGO_Q/images")
	End If
	Dim sName = LCase(Trim(CStr(sceneName)))
	If Len(sName) = 0 Then sName = "general"
	Dim debugCapPath = "/sdcard/FGO_Q/images/debug_" & sName & "_screen.png"
	SnapShot debugCapPath, 0, 0, 1439, 809
	TracePrint "Saved debug screen for [" & sName & "] to:", debugCapPath
End Sub

Function SampleServantAvatarsFromNPCards()
	If Dir.Exist("/sdcard/FGO_Q/images") = 0 Then
		Dir.Create("/sdcard/FGO_Q/images")
	End If

	' 1. 妫鏌ユ槸鍚︽湁鏈閲囨牱鐨勪粠鑰呭凡鍗囪捣瀹濆叿鍗
	Dim heroesToSample = Array(0, 0, 0, 0)
	Dim needSampleCount = 0
	Dim h
	For h = 1 To 3
		If BATTLE_HERO_SAMPLED[h] = 0 Then
			If IsNPCardActive(h) Then
				heroesToSample[h] = 1
				needSampleCount = needSampleCount + 1
			End If
		End If
	Next

	If needSampleCount = 0 Then
		Exit Function
	End If

	' 銆愯皟璇曟埅灞忋戝綋寮鍚璋冭瘯寮鍏充笖闇閫氳繃瀹濆叿鍗℃彁鍙栦粠鑰呯壒寰佹椂锛屾埅鍙栧綋鍓嶉栧抚鐢婚潰渚涙帓鏌
	SaveDebugScreen "sample_hero"

	' 瀹濆叿鍗″湪灞忓箷 1440x810 涓嬬殑鏍囧噯鍙岀溂闈㈤儴閲囨牱鐭╁舰 (x1, y1, x2, y2)
	' 閲囩敤瀹藉ぇ浜庨珮鐨勬í鍚戦暱鏂瑰舰 (50x24 鍍忕礌)锛岀簿鍑嗚嗙洊鍙岀溂涓庨蓟姊佹í鍚戞牳蹇冪珛浣撶壒寰侊紝閬垮紑涓婃柟鍔ㄦ佺櫧鍏変笌涓嬫柟瀹濆叿鍚嶅ぇ瀛
	' 浠庤1(443): (418, 194, 468, 218)
	' 浠庤2(720): (695, 194, 745, 218)
	' 浠庤3(997): (972, 194, 1022, 218)
	Dim npFaceRects = Array(BATTLE_HERO_NP_FACE_1_TAR, BATTLE_HERO_NP_FACE_2_TAR, BATTLE_HERO_NP_FACE_3_TAR)

	' 2. 澶氭椂搴忛噰鏍凤細杩炵画鎴鍙 3 甯э紙闂撮殧 500ms锛屽巻鏃 1.0 绉掞級锛屽畬鏁磋嗙洊瀹濆叿鍗″姩鎬佹祦鍏夎剦鍐插懆鏈
	Dim frameIdx
	For frameIdx = 1 To 3
		For h = 1 To 3
			If heroesToSample[h] = 1 Then
				Dim rX1 = npFaceRects[h][1]
				Dim rY1 = npFaceRects[h][2]
				Dim rX2 = npFaceRects[h][3]
				Dim rY2 = npFaceRects[h][4]
				Dim frameSavePath = "/sdcard/FGO_Q/images/tmp_hero_" & h & "_" & frameIdx & ".png"
				If Dir.Exist(frameSavePath) = 1 Then
					Dir.Delete frameSavePath
				End If
				SnapShot frameSavePath, rX1, rY1, rX2, rY2
			End If
		Next
		If frameIdx < 3 Then
			Delay 500
		End If
	Next

	' 3. 楠岃瘉骞舵嫾鎺 3 甯у垏鐗囦负绠￠亾澶氭ā鏉 (OR 鍖归厤)锛屼换涓甯у懡涓鎵嬬墝鍗崇畻浠庤呰瘑鍒鎴愬姛
	For h = 1 To 3
		If heroesToSample[h] = 1 Then
			Dim multiTemplateStr = ""
			Dim validFrameCount = 0
			Dim f
			For f = 1 To 3
				Dim chkPath = "/sdcard/FGO_Q/images/tmp_hero_" & h & "_" & f & ".png"
				If Dir.Exist(chkPath) = 1 Then
					If Len(multiTemplateStr) = 0 Then
						multiTemplateStr = chkPath
					Else
						multiTemplateStr = multiTemplateStr & "|" & chkPath
					End If
					validFrameCount = validFrameCount + 1
				End If
			Next

			If validFrameCount > 0 Then
				BATTLE_ATTACK_CARD_PRIORITY_TARS[h] = multiTemplateStr
				If BATTLE_ATTACK_CARD_PRIORITY_COUNT < h Then
					BATTLE_ATTACK_CARD_PRIORITY_COUNT = h
				End If
				BATTLE_HERO_SAMPLED[h] = 1
				TracePrint "Successfully sampled", validFrameCount, "time-series avatar frames for Hero", h, "from NP Card", (h + 5), ":", multiTemplateStr
			Else
				TracePrint "Multi-frame SnapShot failed for Hero", h
			End If
		End If
	Next
End Function

Function IsHeroCard(cardIndex, heroNum)
	IsHeroCard = false
	If cardIndex < 1 Or cardIndex > 5 Then Exit Function
	If heroNum < 1 Or heroNum > 3 Then Exit Function

	Dim cx = BATTLE_ATTACK_CARD_COORDS[cardIndex][1]

	' 鑻ュ凡閲囨牱鎴栭厤缃浜嗕笓灞炰粠鑰呭ご鍍忕壒寰侊紝浠ュご鍍忔壘鍥句负鍑
	Dim customImg = BATTLE_ATTACK_CARD_PRIORITY_TARS[heroNum]
	If customImg <> null And Len(CStr(customImg)) > 0 Then
		' 鎵嬪崱绔嬬粯璇嗗埆鍖猴細浣跨敤鏍囧畾閰嶇疆鍖哄煙锛岄伩寮椤堕儴楗版潯涓庢毚鍑荤巼鏁板瓧
		Dim heroCardAreas = Array(BATTLE_HERO_CARD_AREA_1_TAR, BATTLE_HERO_CARD_AREA_2_TAR, BATTLE_HERO_CARD_AREA_3_TAR, BATTLE_HERO_CARD_AREA_4_TAR, BATTLE_HERO_CARD_AREA_5_TAR)
		Dim curArea = heroCardAreas[cardIndex]
		Dim heroArea = Array(curArea[1], curArea[2], curArea[3], curArea[4], customImg)
		Dim res = CheckPriorityImgEx(heroArea, HERO_CARD_SIM, HERO_CARD_OFFSET_COLOR)
		If res <> null Then
			TracePrint "IsHeroCard MATCH: Card", cardIndex, "Hero", heroNum, "at", res[1], res[2]
			IsHeroCard = true
			Exit Function
		Else
			TracePrint "IsHeroCard MISS: Card", cardIndex, "Hero", heroNum, "tol", HERO_CARD_OFFSET_COLOR, "sim", HERO_CARD_SIM
		End If
	End If
End Function


Function SelectColorWithHeroPriority(colorCode, heroOrder)
	Dim matchedCards = Array()
	Dim matchedCount = 0
	Dim colorTargetImg = ""
	If colorCode = "B" Then
		colorTargetImg = "Attachment:BATTLE_ATTACK_CARD_BUSTER.png"
	ElseIf colorCode = "A" Then
		colorTargetImg = "Attachment:BATTLE_ATTACK_CARD_ARTS.png"
	ElseIf colorCode = "Q" Then
		colorTargetImg = "Attachment:BATTLE_ATTACK_CARD_QUICK.png"
	End If

	Dim i
	For i = 1 To 5
		If BATTLE_CARD_CHOSEN[i] = 0 Then
			Dim cx = BATTLE_ATTACK_CARD_COORDS[i][1]
			Dim cardArea = Array(cx - 130, 460, cx + 130, 750, colorTargetImg)
			Dim getCard = CheckImg2(cardArea)
			If getCard <> null Then
				matchedCount = matchedCount + 1
				matchedCards[matchedCount] = i
			End If
		End If
	Next

	Dim orderLen = Len(heroOrder)

	If matchedCount = 0 Then
		TracePrint "No matching color card found for", colorCode
		' 娆′紭鍏堥檷绾э細鑻ユ寚瀹氫簡浠庤呭亸濂 (濡 B1)锛屽皾璇曞嚭璇ヤ粠鑰呯殑鍏朵粬鎵嬪崱
		If orderLen > 0 Then
			Dim fallbackHeroIdx
			For fallbackHeroIdx = 1 To orderLen
				Dim fHeroNum = CInt(Mid(heroOrder, fallbackHeroIdx, 1))
				If fHeroNum >= 1 And fHeroNum <= 3 Then
					Dim fi
					For fi = 1 To 5
						If BATTLE_CARD_CHOSEN[fi] = 0 Then
							If IsHeroCard(fi, fHeroNum) Then
								TracePrint "No", colorCode, "card on field, fallback to preferred Hero", fHeroNum, "at card", fi
								BATTLE_CARD_CHOSEN[fi] = 1
								tap BATTLE_ATTACK_CARD_COORDS[fi][1], BATTLE_ATTACK_CARD_COORDS[fi][2]
								Exit Function
							End If
						End If
					Next
				End If
			Next
		End If
		SelectFallbackCard()
		Exit Function
	End If

	' 1. 鏈楂樹紭鍏 + 娆′紭鍏堬細鍦ㄦ墍閫夎壊鍗′腑锛屼紭鍏堝绘壘绗﹀悎浠庤呬紭鍏堢骇鐨勫崱 (濡 B1 浼樺厛鎵句粠鑰 1 鐨 B 鍗)
	If orderLen > 0 Then
		Dim oIdx
		For oIdx = 1 To orderLen
			Dim hNum = CInt(Mid(heroOrder, oIdx, 1))
			If hNum >= 1 And hNum <= 3 Then
				Dim m
				For m = 1 To matchedCount
					Dim cIdx = matchedCards[m]
					If IsHeroCard(cIdx, hNum) Then
						TracePrint "Matched Color", colorCode, "Hero", hNum, "at card", cIdx
						BATTLE_CARD_CHOSEN[cIdx] = 1
						tap BATTLE_ATTACK_CARD_COORDS[cIdx][1], BATTLE_ATTACK_CARD_COORDS[cIdx][2]
						Exit Function
					End If
				Next
			End If
		Next
	End If

	' 2. 鏍稿績鍘熷垯锛氬嚭鐗岄夊畾(鑹插崱)涓烘渶楂樹紭鍏堬紒鑻ユ棤浠庤呭亸濂藉懡涓锛岄檷绾у嚭鍏朵粬浠庤呯殑璇ヨ壊鍗
	Dim firstMatchedIdx = matchedCards[1]
	TracePrint "No preferred hero matched for", colorCode, ", tap other hero's", colorCode, "card at", firstMatchedIdx
	BATTLE_CARD_CHOSEN[firstMatchedIdx] = 1
	tap BATTLE_ATTACK_CARD_COORDS[firstMatchedIdx][1], BATTLE_ATTACK_CARD_COORDS[firstMatchedIdx][2]
End Function

Function SelectHeroPriorityCard(heroNum, preferredColor)
	' 瑙勮寖鍖栧崟涓鑹插崱鍋忓ソ (濡 "B", "A", "Q")
	Dim cChar = ""
	If Len(preferredColor) > 0 Then
		cChar = UCase(Mid(preferredColor, 1, 1))
		If cChar <> "B" And cChar <> "A" And cChar <> "Q" Then
			cChar = ""
		End If
	End If

	Dim heroMatchedCards = Array()
	Dim heroCardCount = 0
	Dim i
	For i = 1 To 5
		If BATTLE_CARD_CHOSEN[i] = 0 Then
			If IsHeroCard(i, heroNum) Then
				heroCardCount = heroCardCount + 1
				heroMatchedCards[heroCardCount] = i
			End If
		End If
	Next

	If heroCardCount > 0 Then
		' 1. 鑻ユ寚瀹氫簡鑹插崱鍋忓ソ (B/A/Q)锛屼紭鍏堝湪璇ヤ粠鑰呮墜鐗屼腑鍖归厤璇ヨ壊鍗
		If Len(cChar) > 0 Then
			Dim cImg = ""
			If cChar = "B" Then
				cImg = "Attachment:BATTLE_ATTACK_CARD_BUSTER.png"
			ElseIf cChar = "A" Then
				cImg = "Attachment:BATTLE_ATTACK_CARD_ARTS.png"
			ElseIf cChar = "Q" Then
				cImg = "Attachment:BATTLE_ATTACK_CARD_QUICK.png"
			End If

			If Len(cImg) > 0 Then
				Dim hc
				For hc = 1 To heroCardCount
					Dim checkIdx = heroMatchedCards[hc]
					Dim cx = BATTLE_ATTACK_CARD_COORDS[checkIdx][1]
					Dim cardArea = Array(cx - 130, 460, cx + 130, 750, cImg)
					If CheckImg2(cardArea) <> null Then
						TracePrint "Found Hero", heroNum, "Card with preferred color", cChar, "at", checkIdx
						BATTLE_CARD_CHOSEN[checkIdx] = 1
						tap BATTLE_ATTACK_CARD_COORDS[checkIdx][1], BATTLE_ATTACK_CARD_COORDS[checkIdx][2]
						Exit Function
					End If
				Next
			End If
		End If

		' 2. 鏍稿績鍘熷垯锛氬嚭鐗岄夊畾(浠庤)涓烘渶楂樹紭鍏堬紒鑻ユ棤鍋忓ソ鑹插崱锛屼緷鐒朵紭鍏堝嚭璇ヤ粠鑰呯殑鍏朵粬浠绘剰鎵嬪崱
		Dim fallbackHeroCard = heroMatchedCards[1]
		TracePrint "Hero", heroNum, "has no preferred color", cChar, ", fallback to other card of Hero", heroNum, "at", fallbackHeroCard
		BATTLE_CARD_CHOSEN[fallbackHeroCard] = 1
		tap BATTLE_ATTACK_CARD_COORDS[fallbackHeroCard][1], BATTLE_ATTACK_CARD_COORDS[fallbackHeroCard][2]
		Exit Function
	End If

	' 3. 璇ヤ粠鑰呭畬鍏ㄦ湭鍙戠墝鎴栨湭璇嗗埆锛氶鍖栨寜鍋忓ソ鑹插崱瀵绘壘鍦轰笂鏅閫氳壊鍗★紝閬垮厤鍗℃
	If Len(cChar) > 0 Then
		If cChar = "B" Then
			If TryTapFirstColorCard("Attachment:BATTLE_ATTACK_CARD_BUSTER.png", "B") Then Exit Function
		ElseIf cChar = "A" Then
			If TryTapFirstColorCard("Attachment:BATTLE_ATTACK_CARD_ARTS.png", "A") Then Exit Function
		ElseIf cChar = "Q" Then
			If TryTapFirstColorCard("Attachment:BATTLE_ATTACK_CARD_QUICK.png", "Q") Then Exit Function
		End If
	End If

	' 4. 鏈缁堥檷绾э細54321 椤哄簭鎶藉彇绌洪棽鍗
	TracePrint "Hero", heroNum, "card not found, fallback to 54321"
	SelectFallbackCard()
End Function

Function DetectBattleCards()
	Dim i, retryRound, needRetry
	For i = 1 To 5
		BATTLE_CARD_COLORS[i] = ""
		BATTLE_CARD_IS_CRIT_100[i] = 0
	Next
	For retryRound = 1 To 3
		needRetry = False
		For i = 1 To 5
			If BATTLE_CARD_COLORS[i] = "" Then
				Dim cx = BATTLE_ATTACK_CARD_COORDS[i][1]
				Dim xCol1 = cx - 80 : If xCol1 < 0 Then xCol1 = 0
				Dim xCol2 = cx + 80 : If xCol2 > 1439 Then xCol2 = 1439
				Dim bArea = Array(xCol1, 570, xCol2, 670, "Attachment:BATTLE_ATTACK_CARD_BUSTER.png|Attachment:BATTLE_ATTACK_CARD_BUSTER_2.png")
				If CheckPriorityImgEx(bArea, 0.72, "282828") <> null Then
					BATTLE_CARD_COLORS[i] = "B"
				Else
					Dim aArea = Array(xCol1, 570, xCol2, 670, "Attachment:BATTLE_ATTACK_CARD_ARTS.png")
					If CheckPriorityImgEx(aArea, 0.72, "282828") <> null Then
						BATTLE_CARD_COLORS[i] = "A"
					Else
						Dim qArea = Array(xCol1, 570, xCol2, 670, "Attachment:BATTLE_ATTACK_CARD_QUICK.png")
						If CheckPriorityImgEx(qArea, 0.72, "282828") <> null Then
							BATTLE_CARD_COLORS[i] = "Q"
						Else
							needRetry = True
						End If
					End If
				End If
			End If
		Next
		If Not needRetry Then Exit For
		If retryRound < 3 Then Delay 250
	Next
	For i = 1 To 5
		If BATTLE_CARD_COLORS[i] = "" Then
			Dim fcx = BATTLE_ATTACK_CARD_COORDS[i][1]
			Dim fcX1 = fcx - 45 : If fcX1 < 0 Then fcX1 = 0
			Dim fcX2 = fcx + 45 : If fcX2 > 1439 Then fcX2 = 1439
			Dim fx, fy
			FindColor fcX1, 600, fcX2, 645, "0014EB-1E281E", 0, 0.9, fx, fy
			If fx > -1 And fy > -1 Then
				BATTLE_CARD_COLORS[i] = "B"
			Else
				FindColor fcX1, 600, fcX2, 645, "EB960A-1E3020", 0, 0.9, fx, fy
				If fx > -1 And fy > -1 Then
					BATTLE_CARD_COLORS[i] = "A"
				Else
					FindColor fcX1, 600, fcX2, 645, "00EB50-1E1E30", 0, 0.9, fx, fy
					If fx > -1 And fy > -1 Then BATTLE_CARD_COLORS[i] = "Q"
				End If
			End If
		End If
	Next
	For i = 1 To 5

		' 2. 100% 婊℃毚鍑荤巼璇嗗埆
		' 閲囩敤鍙屾ā鏉匡細鏍囧噯'1'(BATTLE_ATTACK_CARD_100.png)涓庣洿绗旀牳蹇(BATTLE_ATTACK_CARD_100_2.png)
		' 鎵鎻忓尯涓ユ牸闄愬畾鍦ㄧ櫨浣嶆暟涓撳睘鍑犱綍绐楀彛 cx - 55 ~ cx - 35 (瀹炴祴鐪熷疄 cx=[118,408,698,991,1278] 涓嬬櫨浣'1'鐗╃悊鍒嗗竷鍦 cx-51 ~ cx-37)
		' 鍋忚壊瀹瑰樊閲囩敤 "202020" 鍏煎圭孩/钃/缁垮悇鑹插崱搴曡壊鎶楅敮榻匡紝闃堝艰句负 0.72 (瀹炴祴婊℃毚鍗 0.88~1.00锛岄潪婊℃毚鍗 < 0.28)
		Dim crit100Areas = Array(BATTLE_CRIT_100_AREA_1_TAR, BATTLE_CRIT_100_AREA_2_TAR, BATTLE_CRIT_100_AREA_3_TAR, BATTLE_CRIT_100_AREA_4_TAR, BATTLE_CRIT_100_AREA_5_TAR)
		Dim cTar = crit100Areas[i]
		Dim critTpl = "Attachment:BATTLE_ATTACK_CARD_100.png|Attachment:BATTLE_ATTACK_CARD_100_2.png"
		If BATTLE_ATTACK_CARD_100_TAR <> null And Len(CStr(BATTLE_ATTACK_CARD_100_TAR[5])) > 0 Then
			critTpl = BATTLE_ATTACK_CARD_100_TAR[5]
		End If
		Dim critAreaNarrow = Array(cTar[1], cTar[2], cTar[3], cTar[4], critTpl)
		If CheckPriorityImgEx(critAreaNarrow, 0.72, "202020") <> null Then
			BATTLE_CARD_IS_CRIT_100[i] = 1
		End If

		TracePrint "Detected Card", i, "Color:", BATTLE_CARD_COLORS[i], "100%Crit:", BATTLE_CARD_IS_CRIT_100[i]
	Next

	Dim detectSummary = "Detected Hand: "
	Dim sIdx
	For sIdx = 1 To 5
		detectSummary = detectSummary & "C" & sIdx & "=[" & BATTLE_CARD_COLORS[sIdx] & ",crit=" & BATTLE_CARD_IS_CRIT_100[sIdx] & "] "
	Next
	TracePrint detectSummary
	zm.FileWrite "/sdcard/FGO_Q/debug_card_log.txt", DateTime.Format() & " " & detectSummary
End Function

Function MatchCardByAtom(atom)
	MatchCardByAtom = 0
	Dim cleanAtom = UCase(Trim(CStr(atom)))
	If Len(cleanAtom) = 0 Then Exit Function

	' 1. 瑙ｆ瀽 ! 蹇呯垎鏍囧織
	Dim mustCrit = false
	If Right(cleanAtom, 1) = "!" Then
		mustCrit = true
		cleanAtom = Left(cleanAtom, Len(cleanAtom) - 1)
	End If

	' 2. 瑙ｆ瀽瑙勫垯浠庤呬笌鑹插崱瑕佹眰
	Dim isWildcard = false
	Dim targetHero = 0
	Dim targetColor = ""

	If cleanAtom = "*" Then
		isWildcard = true
	ElseIf Left(cleanAtom, 1) = "H" Then
		If Len(cleanAtom) >= 2 Then
			targetHero = CInt(Mid(cleanAtom, 2, 1))
		End If
		If Len(cleanAtom) >= 3 Then
			targetColor = Mid(cleanAtom, 3, 1)
			If targetColor <> "B" And targetColor <> "A" And targetColor <> "Q" Then
				targetColor = ""
			End If
		End If
	ElseIf cleanAtom = "B" Or cleanAtom = "A" Or cleanAtom = "Q" Then
		targetColor = cleanAtom
	ElseIf Left(cleanAtom, 1) = "B" Or Left(cleanAtom, 1) = "A" Or Left(cleanAtom, 1) = "Q" Then
		' 鍏煎硅壊鍗+浠庤呮牸寮忥細B1/A1/Q1 鎴 B12/B123 绛夐『浣嶅亸濂
		targetColor = Left(cleanAtom, 1)
		Dim heroStr = Mid(cleanAtom, 2, Len(cleanAtom) - 1)
		If Len(heroStr) = 1 Then
			targetHero = CInt(heroStr)
		ElseIf Len(heroStr) > 1 Then
			' 鍏煎瑰氫粠鑰呴『浣嶅亸濂 (濡 B12 鎴 B123)锛屾寜椤轰綅閫愪釜閫掑綊灏濊瘯鍖归厤
			Dim hPos
			For hPos = 1 To Len(heroStr)
				Dim tryH = CInt(Mid(heroStr, hPos, 1))
				Dim subAtom = targetColor & tryH
				If mustCrit Then subAtom = subAtom & "!"
				Dim subMatch = MatchCardByAtom(subAtom)
				If subMatch >= 1 And subMatch <= 5 Then
					MatchCardByAtom = subMatch
					Exit Function
				End If
			Next
			Exit Function
		End If
	Else
		' 鏈鐭ュ師瀛愭潯浠
		Exit Function
	End If

	' 3. 鏀堕泦鎵鏈夌﹀悎鏉′欢鐨勬湭閫変腑鍊欓夋墜鐗
	Dim candidateCards = Array()
	Dim candidateCount = 0
	Dim i
	For i = 1 To 5
		If BATTLE_CARD_CHOSEN[i] = 0 Then
			Dim passCheck = true

			' 蹇呯垎纭鎬ц繃婊
			If mustCrit And BATTLE_CARD_IS_CRIT_100[i] <> 1 Then
				passCheck = false
			End If

			' 鑹插崱鍖归厤
			If passCheck And Len(targetColor) > 0 Then
				If BATTLE_CARD_COLORS[i] <> targetColor Then
					passCheck = false
				End If
			End If

			' 浠庤呭尮閰嶏紙澶嶇敤 3 甯ф椂搴忛噰鏍峰氭ā鏉 OR 璇嗗埆涓庡亸鑹插瑰樊锛
			If passCheck And targetHero >= 1 And targetHero <= 3 Then
				If Not IsHeroCard(i, targetHero) Then
					passCheck = false
				End If
			End If

			If passCheck Then
				candidateCount = candidateCount + 1
				candidateCards[candidateCount] = i
			End If
		End If
	Next

	If candidateCount = 0 Then
		Exit Function
	End If

	' 4. 鍚屾潯浠舵弧鏆翠紭鍏堟嫨浼 (Auto Tie-Breaker)
	Dim critCards = Array()
	Dim critCount = 0
	Dim c
	For c = 1 To candidateCount
		Dim cardIdx = candidateCards[c]
		If BATTLE_CARD_IS_CRIT_100[cardIdx] = 1 Then
			critCount = critCount + 1
			critCards[critCount] = cardIdx
		End If
	Next

	If critCount > 0 Then
		' 鑻ュ欓夊崱涓瀛樺湪婊℃毚鍗★紝浼樺厛鍦ㄦ弧鏆村崱涓鎸戦
		If isWildcard Then
			MatchCardByAtom = critCards[critCount]
		Else
			MatchCardByAtom = critCards[1]
		End If
	Else
		' 鏃犳弧鏆村崱鏃讹紙涓旀湭寮烘眰 mustCrit锛夛紝鍦ㄦ櫘閫氬欓夊崱涓鎸戦
		If isWildcard Then
			MatchCardByAtom = candidateCards[candidateCount]
		Else
			MatchCardByAtom = candidateCards[1]
		End If
	End If
End Function

Function SelectAttackCard(CardIndex)
	If IsNumeric(CardIndex) Then
		Dim cardNum = Int(CardIndex)
		If cardNum >= 1 And cardNum <= 5 Then
			BATTLE_CARD_CHOSEN[cardNum] = 1
		End If
		CheckAndTapImg2(BATTLE_ATTACK_BACK_TAR, BATTLE_ATTACK_CARD_COORDS[cardNum])
		Exit Function
	End If

	Dim exprStr = UCase(Trim(CStr(CardIndex)))
	If Len(exprStr) = 0 Then
		TracePrint "Empty card expression, fallback to 54321"
		SelectFallbackCard()
		Exit Function
	End If

	' 鑷鐢遍暱閾句紭鍏堢骇搴忓垪瑙ｆ瀽锛堜互 > 鍒嗛殧寰鐜灏濊瘯锛
	Dim globalMustCrit = false
	If Left(exprStr, 1) = "!" Then
		globalMustCrit = true
		exprStr = Mid(exprStr, 2, Len(exprStr) - 1)
	End If

	Dim tokens = Split(exprStr, ">")
	Dim t
	For Each t In tokens
		Dim atom = Trim(CStr(t))
		If Len(atom) > 0 Then
			If globalMustCrit And Right(atom, 1) <> "!" And atom <> "*" Then
				atom = atom & "!"
			End If
			Dim matchedCard = MatchCardByAtom(atom)
			If matchedCard >= 1 And matchedCard <= 5 Then
				Dim hitMsg = "Matched Priority Atom [" & atom & "] at Card " & matchedCard & " (Crit100=" & BATTLE_CARD_IS_CRIT_100[matchedCard] & ")"
				TracePrint hitMsg
				zm.FileWrite "/sdcard/FGO_Q/debug_card_log.txt", zm.FileRead("/sdcard/FGO_Q/debug_card_log.txt") & Chr(10) & DateTime.Format() & " " & hitMsg
				BATTLE_CARD_CHOSEN[matchedCard] = 1
				tap BATTLE_ATTACK_CARD_COORDS[matchedCard][1], BATTLE_ATTACK_CARD_COORDS[matchedCard][2]
				Exit Function
			End If
		End If
	Next

	' 搴忓垪鍏ㄩ儴閬嶅巻瀹屾瘯锛屽潎鏈鍛戒腑鍙鐢ㄦ墜鐗屼笖鏃犲厹搴
	Dim abortMsg = "閫夊崱鏈鍛戒腑浼樺厛绾ф潯浠 [" & exprStr & "] 涓旀棤鍏滃簳锛屽畨鍏ㄥ仠鏈"
	TracePrint "Card priority sequence [" & exprStr & "] NOT matched on any available card!"
	zm.FileWrite "/sdcard/FGO_Q/debug_card_log.txt", zm.FileRead("/sdcard/FGO_Q/debug_card_log.txt") & Chr(10) & DateTime.Format() & " ABORT: " & abortMsg
	AbortBattle abortMsg
End Function

Function NeedsHeroAvatarSampling(ActionsGroup)
	NeedsHeroAvatarSampling = false
	If IsNull(ActionsGroup) Then Exit Function
	Dim cIdx
	For cIdx = 2 To 4
		If cIdx <= UBound(ActionsGroup) Then
			Dim s = UCase(Trim(CStr(ActionsGroup[cIdx])))
			' 1. 鍖呭惈 H 浠庤呮爣璇嗭紙濡 H1, H2, H3, H1B, H2A! 绛夛級
			If InStr(1, s, "H") > 0 Then
				NeedsHeroAvatarSampling = true
				Exit Function
			End If
			' 2. 鍖呭惈 鑹插崱+浠庤 缁勫悎锛堝 B1, B2, B3, A1, A2, A3, Q1, Q2, Q3, B12 绛夛級
			If InStr(1, s, "B1") > 0 Or InStr(1, s, "B2") > 0 Or InStr(1, s, "B3") > 0 Or _
			   InStr(1, s, "A1") > 0 Or InStr(1, s, "A2") > 0 Or InStr(1, s, "A3") > 0 Or _
			   InStr(1, s, "Q1") > 0 Or InStr(1, s, "Q2") > 0 Or InStr(1, s, "Q3") > 0 Then
				NeedsHeroAvatarSampling = true
				Exit Function
			End If
		End If
	Next
End Function

Function DoAttackActions(ActionsGroup)
	TracePrint "attack"
	If USER_STOP_REQUESTED Or CheckStopSignal() Then
		Exit Function
	End If

	Dim resetIdx
	For resetIdx = 1 To 5
		BATTLE_CARD_CHOSEN[resetIdx] = 0
	Next

	' 鐐瑰嚮 Attack 鎸夐挳灞曞紑鎵嬬墝
	CheckAndTapImg2(BATTLE_HERO_SKILL_CHECK_TAR, null)
	Delay BATTLE_ULTIMATE_DISPLAY_AWAIT_MS

	' 浠呭綋鍑虹墝鎸囦护涓鍖呭惈浠庤呭崱鐗岄渶姹傦紙濡 H1/H2/H3锛夋椂鎵嶈繘琛屽疂鍏峰崱鐗瑰緛閲囨牱锛岄伩鍏嶆棤 H 鍗″姩浣滄椂鐨勯濆栨椂闂村紑閿
	If NeedsHeroAvatarSampling(ActionsGroup) Then
		' 鑻ュ皻鏈瀹屾垚鍏ㄩ儴鍓嶆帓浠庤呭ご鍍忛噰鏍凤紝杩藉姞 500ms 缂撳啿纭淇濅綆甯х巼涓嬪疂鍏峰崱瀹屽叏灞曞紑鍗囪捣
		If BATTLE_HERO_SAMPLED[1] = 0 Or BATTLE_HERO_SAMPLED[2] = 0 Or BATTLE_HERO_SAMPLED[3] = 0 Then
			Delay 500
		End If

		' 鍔ㄦ佷粠宸蹭寒璧风殑瀹濆叿鍗￠噰鏍蜂粠鑰呭ご鍍忥紙鑻ユゅ墠灏氭湭閲囨牱杩囷級
		SampleServantAvatarsFromNPCards()
	Else
		TracePrint "No H/Hero card tokens in attack action, skip NP avatar sampling"
	End If

	' 鎵鎻忓苟缂撳瓨褰撳墠 5 寮犳墜鐗岀殑鑹插崱绫诲瀷涓 100% 鏆村嚮鐜
	DetectBattleCards()
	
	Dim FirstCardIndex = ActionsGroup[2]
	SelectAttackCard(FirstCardIndex)
	Delay BATTLE_CARD_TAPED_AWAIT_MS
	If USER_STOP_REQUESTED Or CheckStopSignal() Then Exit Function

	Dim SecondCardIndex = ActionsGroup[3]
	If SecondCardIndex <> null And Len(CStr(SecondCardIndex)) > 0 Then
		SelectAttackCard(SecondCardIndex)
		Delay BATTLE_CARD_TAPED_AWAIT_MS
		If USER_STOP_REQUESTED Or CheckStopSignal() Then Exit Function
	Else
		TracePrint "Second card index omitted, fallback to 54321"
		SelectFallbackCard()
		Delay BATTLE_CARD_TAPED_AWAIT_MS
		If USER_STOP_REQUESTED Or CheckStopSignal() Then Exit Function
	End If

	Dim ThirdCardIndex = ActionsGroup[4]
	If ThirdCardIndex <> null And Len(CStr(ThirdCardIndex)) > 0 Then
		SelectAttackCard(ThirdCardIndex)
		Delay BATTLE_NORMAL_ATTACK_PLAY_AWAIT_MS
	Else
		TracePrint "Third card index omitted, fallback to 54321"
		SelectFallbackCard()
		Delay BATTLE_NORMAL_ATTACK_PLAY_AWAIT_MS
	End If

	LAST_ACTION_WAS_ATTACK = true
End Function


Function DoTargetActions(ActionsGroup)
	LAST_ACTION_WAS_ATTACK = false
	Dim TargetIndex = ActionsGroup[2]
	If IsNull(TargetIndex) Or Not IsNumeric(TargetIndex) Then
		TracePrint "invalid target action, skip"
		Exit Function
	End If
	TargetIndex = Int(TargetIndex)
	If TargetIndex < 1 Or TargetIndex > 6 Then
		TracePrint "invalid target index, skip", TargetIndex
		Exit Function
	End If
	TracePrint "target", TargetIndex
	CheckAndTapImg2(BATTLE_HERO_SKILL_CHECK_TAR, BATTLE_TARGET_COORDS[TargetIndex])
	Delay BATTLE_SKILL_NORMAL_AWAIT_MS
End Function

Function DoGroupActions(ActionsGroup)
	If BATTLE_ENDED_EARLY Then
		Exit Function
	End If

	If ActionsGroup[1] = "skill" Then
		DoSkillActions(ActionsGroup)
	ElseIf ActionsGroup[1] = "master" Then
		DoMasterActions(ActionsGroup)
	ElseIf ActionsGroup[1] = "attack" Then
		DoAttackActions(ActionsGroup)
	ElseIf ActionsGroup[1] = "target" Then
		DoTargetActions(ActionsGroup)
	End If
End Function

Function DoBattle()
	BATTLE_ENDED_EARLY = false
	BATTLE_ROUNDS_FINISHED = 0
	LAST_ACTION_WAS_ATTACK = false
	Dim rstH
	For rstH = 1 To 3
		BATTLE_HERO_SAMPLED[rstH] = 0
		If BATTLE_ATTACK_CARD_PRIORITY_TARS[rstH] <> null Then
			If InStr(1, CStr(BATTLE_ATTACK_CARD_PRIORITY_TARS[rstH]), "tmp_hero_") > 0 Then
				BATTLE_ATTACK_CARD_PRIORITY_TARS[rstH] = null
			End If
		End If
	Next
	
	Dim inBattleDirectly = false
	If CheckImg2(BATTLE_HERO_SKILL_CHECK_TAR) <> null Then
		TracePrint "Already in battle (Attack found), skip ChooseFriend and start actions directly"
		inBattleDirectly = true
	ElseIf Not IsOnFriendSelectScreen() And CheckImg2(START_TAR) <> null Then
		TracePrint "In team confirm screen (Start found), skip ChooseFriend"
		If DEBUG_FRIEND_ONLY > 0 Then
			BattlePrint("【助战调试】当前已处于队伍确认界面，根据配置停止进入战斗。")
			USER_STOP_REQUESTED = true
			ABORT_REASON = "【助战调试完成】已选定助战，已安全停机"
			Exit Function
		End If
	ElseIf CHOOSE_FRIEND_MANUAL <= 0 Then
		ChooseFriend()
		If DEBUG_FRIEND_ONLY > 0 Then
			BattlePrint("【助战调试】已成功完成助战选择与翻页测试！根据配置停止进入战斗。")
			USER_STOP_REQUESTED = true
			ABORT_REASON = "【助战调试完成】已选定助战，已安全停机"
			Exit Function
		End If
	Else
		TracePrint "Manual choose friend mode (CHOOSE_FRIEND_MANUAL>0), skip ChooseFriend"
		If DEBUG_FRIEND_ONLY > 0 Then
			BattlePrint("【助战调试】人工选助战模式下已跳过选择，根据配置停止进入战斗。")
			USER_STOP_REQUESTED = true
			ABORT_REASON = "【助战调试完成】人工选助战模式已安全停机"
			Exit Function
		End If
	End If
	If USER_STOP_REQUESTED Or CheckStopSignal() Then
		Exit Function
	End If
	If Not inBattleDirectly Then
		If Not CheckBattleStart() Or USER_STOP_REQUESTED Or CheckStopSignal() Then
			Exit Function
		End If
	End If

	Dim RoundCount = UBound(AllActionRound)+1
	TOTAL_SUB_ROUND_NUM = RoundCount
	For RoundIndex = 1 To RoundCount
		If USER_STOP_REQUESTED Or CheckStopSignal() Then
			Exit For
		End If
		CURRENT_SUB_ROUND_NUM = RoundIndex
		BattlePrint("Round " & RoundIndex)
		Dim ActionsRound = AllActionRound[RoundIndex]
		' ActionsGroup
		Dim ActionsGroupCount = UBound(ActionsRound)+1
		For ActionsGroupIndex = 1 To ActionsGroupCount
			If USER_STOP_REQUESTED Or CheckStopSignal() Then
				Exit For
			End If
			Dim ActionsGroup = ActionsRound[ActionsGroupIndex]
			If Not WaitRoundReadyOrBattleEnd() Then
				Exit For
			End If
			DoGroupActions(ActionsGroup)
			If BATTLE_ENDED_EARLY Or USER_STOP_REQUESTED Then
				Exit For
			End If
		Next
		If Not BATTLE_ENDED_EARLY And Not USER_STOP_REQUESTED Then
			BATTLE_ROUNDS_FINISHED = BATTLE_ROUNDS_FINISHED + 1
		End If
		If BATTLE_ENDED_EARLY Or USER_STOP_REQUESTED Then
			Exit For
		End If
	Next

	If USER_STOP_REQUESTED Then
		TracePrint "Skip remaining battle steps: user stop requested"
		Exit Function
	End If

	If BATTLE_ENDED_EARLY Then
		TracePrint "Skip remaining round actions: battle already ended"
	End If

	' Award
	BattlePrint("award tie")
	If Not WaitAwardTieScreen() Or USER_STOP_REQUESTED Then
		Exit Function
	End If
	Delay AWARD_NORMAL_TAP_AWAIT_MS
	Dim CheckTieUpSuccess = CheckImg2(AWARD_TIE_UP_TAR)
	If CheckTieUpSuccess <> null Then
		TracePrint "缇佺粖鍗囩骇 detected, tap to continue"
		tap AWARD_TAP_COORD[1], AWARD_TAP_COORD[2]
		Delay 500
	End If

	TracePrint "award before treasure"
	Dim HasTreasureNext = CheckNoImgAndTap2(AWARD_TREASURE_NEXT_TAR, AWARD_TAP_COORD)
	If Not HasTreasureNext Or USER_STOP_REQUESTED Then
		TracePrint "award treasure not found in time, stop run to avoid dead loop"
		If Not USER_STOP_REQUESTED Then
			AbortBattle "缁撶畻閬撳叿鐣岄潰绛夊緟瓒呮椂锛屽凡鑷鍔ㄧ粨鏉熸垬鏂楅伩鍏嶅崱姝"
		End If
		HasTicket = false
		Exit Function
	End If
	Delay AWARD_NORMAL_TAP_AWAIT_MS
	TracePrint "award treasure"
	CheckAndTapImg2(AWARD_TREASURE_NEXT_TAR, null)
	If USER_STOP_REQUESTED Then Exit Function

	' Normal Activity Award (Next)
	TracePrint "activity award"
	Delay AWARD_NORMAL_TAP_AWAIT_MS
	Delay BEFORE_ACTIVITY_AWAIT_MS
	Dim CheckActivityAwardSuccess = CheckImg2(AWARD_TREASURE_NEXT_TAR)
	If CheckActivityAwardSuccess <> null Then
		CheckAndTapImg2(AWARD_TREASURE_NEXT_TAR, null)
	End If
	If USER_STOP_REQUESTED Then Exit Function
	
	' Activity Award
	If ACTIVITY_REWARD <> 0 Then
		TracePrint "activity award"
		Delay AWARD_NORMAL_TAP_AWAIT_MS
		CheckAndTapImg2(AWARD_ACTIVITY_NEXT_TAR, null)
	End If
	If USER_STOP_REQUESTED Then Exit Function

	' Add Friend?
	Delay ADD_FRIEND_CHECK_AWAIT_MS
	Dim CheckAddFriendSuccess = CheckImg2(ADD_FRIEND_TAR)
	If CheckAddFriendSuccess <> null Then
		TracePrint "Add Friend: no"
		CheckAndTapImg2(ADD_FRIEND_TAR, null)
		Delay ADD_FRIEND_CHECK_AWAIT_MS
	End If
	If USER_STOP_REQUESTED Then Exit Function

	' Again?
	BattlePrint("again?")
	Dim ContinuousCheckImgTagsResult = ContinuousCheckImgTags(Array(AGAIN_ALERT_AGAIN_TAR, AGAIN_ALERT_CLOSE_TAR, AGAIN_ORDEAL_NO_TICKET_TAR, AGAIN_BATTLE_OUT_MENU_TAR))
	If USER_STOP_REQUESTED Or ContinuousCheckImgTagsResult = 0 Then
		HasTicket = false
		Exit Function
	ElseIf ContinuousCheckImgTagsResult = 3 Then
		TracePrint "again: no ticket"
		CheckAndTapImg2(AGAIN_ORDEAL_NO_TICKET_TAR, null)
		HasTicket = false
	ElseIf ContinuousCheckImgTagsResult = 4 Then
		TracePrint "again: battle ended and back to menu"
		HasTicket = false
	ElseIf CurrentBattleCount < BATTLE_COUNT Then
		TracePrint "again: yes"
		CheckAndTapImg2(AGAIN_ALERT_AGAIN_TAR, null)
	Else
		TracePrint "again: no"
		CheckAndTapImg2(AGAIN_ALERT_CLOSE_TAR, null)
	End If

	' Apple?
	BattlePrint("apple?")
	If CurrentBattleCount < BATTLE_COUNT And HasTicket And Not USER_STOP_REQUESTED Then
		Dim appleStartTime = Time()
		Dim appleMaxWaitSec = 30
		Dim CheckAppleAlertSuccess = null
		Do While (Time() - appleStartTime) < appleMaxWaitSec
			If USER_STOP_REQUESTED Or CheckStopSignal() Then
				Exit Do
			End If
			CheckAppleAlertSuccess = CheckImg2(APPLE_DISPLAY_TAR)
			If CheckAppleAlertSuccess <> null Then
				Exit Do
			End If
			If IsOutMenuConfirmed() Then
				TracePrint "Back to menu during apple check"
				HasTicket = false
				Exit Do
			End If
			If CheckImg2(START_TAR) <> null Or CheckImg2(BATTLE_HERO_SKILL_CHECK_TAR) <> null Or CheckImg2(PREPARE_FRIEND_TITLE_TAR) <> null Or CheckImg2(PREPARE_FRIEND_REFRESH_TAR) <> null Then
				TracePrint "Already entered team/battle/support, AP was sufficient"
				Exit Do
			End If
			Delay 300
		Loop

		If CheckAppleAlertSuccess <> null Then
			If Not HandleEatApple() Or USER_STOP_REQUESTED Or CheckStopSignal() Then
				Exit Function
			End If
		End If
	End If

End Function

Function DetectExtraMethodIndex()
	Dim ScenePoint

	' 1=DoEnhance (浠庤呭己鍖 / 鐏靛熀鍐嶄复鐩稿叧鐣岄潰)
	ScenePoint = CheckImg2(ENHANCE_HERO_TAR)
	If ScenePoint <> null Then
		DetectExtraMethodIndex = 1
		Exit Function
	End If
	ScenePoint = CheckImg2(ENHANCE_ASCEND_TO_HERO_TAR)
	If ScenePoint <> null Then
		DetectExtraMethodIndex = 1
		Exit Function
	End If
	ScenePoint = CheckImg2(ENHANCE_ASCEND_TAR)
	If ScenePoint <> null Then
		DetectExtraMethodIndex = 1
		Exit Function
	End If
	ScenePoint = CheckImg2(ENHANCE_GRAIL_TAR)
	If ScenePoint <> null Then
		DetectExtraMethodIndex = 1
		Exit Function
	End If

	' 2=DoEquipEnhance (礼装强化)
	ScenePoint = CheckImg2(ENHANCE_EQUIP_TAR)
	If ScenePoint <> null Then
		DetectExtraMethodIndex = 2
		Exit Function
	End If

	' 3=DoSkillEnhance (技能强化 / 追加技能强化)
	ScenePoint = CheckImg2(ENHANCE_SKILL_TAR)
	If ScenePoint <> null Then
		DetectExtraMethodIndex = 3
		Exit Function
	End If
	ScenePoint = CheckImg2(ENHANCE_SKILL_APPEND_TAR)
	If ScenePoint <> null Then
		DetectExtraMethodIndex = 3
		Exit Function
	End If
	ScenePoint = CheckImg2(ENHANCE_SKILL_MAX_L10_TAR)
	If ScenePoint <> null Then
		DetectExtraMethodIndex = 3
		Exit Function
	End If

	' 4=DoFriendPool (友情池)
	ScenePoint = CheckImg2(POOLFRIEND_CONTINUE_TAR)
	If ScenePoint <> null Then
		DetectExtraMethodIndex = 4
		Exit Function
	End If
	ScenePoint = CheckImg2(POOLFRIEND_ICON_TAR)
	If ScenePoint <> null Then
		DetectExtraMethodIndex = 4
		Exit Function
	End If

	' 5=DoRoll (无限池)
	ScenePoint = CheckImg2(INFINITE_ROLL_TAR)
	If ScenePoint <> null Then
		DetectExtraMethodIndex = 5
		Exit Function
	End If

	' 容错兜底：若处于临时从者确认弹窗中
	ScenePoint = CheckImg2(ENHANCE_HERO_TEMP_CONFIRM_TAR)
	If ScenePoint <> null Then
		If CheckImg2(ENHANCE_SKILL_TAR) <> null Then
			DetectExtraMethodIndex = 3
		Else
			DetectExtraMethodIndex = 1
		End If
		Exit Function
	End If

	DetectExtraMethodIndex = 0
End Function

Function GetExtraMethodActionName(DetectedMethodIndex)
	If DetectedMethodIndex = 1 Then
		GetExtraMethodActionName = "从者强化"
	ElseIf DetectedMethodIndex = 2 Then
		GetExtraMethodActionName = "礼装强化"
	ElseIf DetectedMethodIndex = 3 Then
		If CheckImg2(ENHANCE_SKILL_APPEND_TAR) <> null Then
			GetExtraMethodActionName = "追加技能强化"
		Else
			GetExtraMethodActionName = "技能强化"
		End If
	ElseIf DetectedMethodIndex = 4 Then
		GetExtraMethodActionName = "友情点召唤"
	ElseIf DetectedMethodIndex = 5 Then
		GetExtraMethodActionName = "无限池抽卡"
	Else
		GetExtraMethodActionName = "未知场景"
	End If
End Function

Function DoRoll()
	CheckAndTapImg2(INFINITE_ROLL_TAR, null)
	Delay 500
	CheckNoImgAndTap2(INFINITE_ROLL_TAR, INFINITE_ROLL_FAST_COORD)
End Function

' 鐩茬偣璺宠繃寮哄寲鍔ㄧ敾骞剁瓑寰呭洖鍒颁粠鑰呭己鍖栦富鐣岄潰
Sub SkipHeroEnhanceAnim()
	TracePrint "寮濮嬬洸鐐硅烦杩囦粠鑰呭己鍖栧姩鐢..."
	Dim animCount = 0
	Dim heroReadyCount = 0
	Dim ascendReadyCount = 0

	Do While animCount < 60
		If USER_STOP_REQUESTED Or CheckStopSignal() Then
			Exit Sub
		End If

		' 0) 妫鏌ユ槸鍚﹀嚭鐜扮礌鏉愯繑杩樺脊绐 (澶ф垚鍔/鏋佸ぇ鎴愬姛杈惧埌涓婇檺杩旇繕绱犳潗)
		Dim refundCloseCoord = CheckImg2(ENHANCE_HERO_REFUND_CLOSE_TAR)
		If refundCloseCoord <> null Then
			TracePrint "强化动画中检测到素材返还弹窗，点击关闭按钮 ->", refundCloseCoord[1], refundCloseCoord[2]
			tap refundCloseCoord[1], refundCloseCoord[2]
			Delay 800
		End If

		' 1) 优先检查是否出现满级突破引导 (前往灵基再临)
		' 1.5) 鏄鍚﹀凡杈炬渶缁堢瓑绾т笂闄 (鍓嶅線鍦ｆ澂杞涓)
		Dim toGrailCoord = CheckImg2(ENHANCE_HERO_TO_GRAIL_TAR)
		If toGrailCoord <> null Then
			TracePrint "寮哄寲锛氭娴嬪埌銆愬墠寰鍦ｆ澂杞涓淬戯紝浠庤呭凡杈炬渶缁堢瓑绾т笂闄"
			Exit Sub
		End If

		Dim toAscendCoord = CheckImg2(ENHANCE_HERO_TO_ASCEND_TAR)
		If toAscendCoord <> null Then
			ascendReadyCount = ascendReadyCount + 1
			If ascendReadyCount >= 2 Then
				TracePrint "寮哄寲鍔ㄧ敾缁撴潫: 妫娴嬪埌浠庤呭凡杈鹃樁娈垫弧绾э紝鍓嶅線鐏靛熀鍐嶄复灏辩华"
				Exit Sub
			End If
		Else
			ascendReadyCount = 0
		End If

		' 2) 妫鏌ュ己鍖栨寜閽鏄鍚﹀凡绋冲畾閲嶆柊鍑虹幇 (鏈杈炬弧绾э紝娓告垙宸茶嚜鍔ㄥ～鍏ョ嫍绮)
		If CheckImg2(ENHANCE_HERO_ENHANCE_TAR) <> null Then
			heroReadyCount = heroReadyCount + 1
			If heroReadyCount >= 2 Then
				TracePrint "寮哄寲鍔ㄧ敾缁撴潫: 寮哄寲鎸夐挳宸查噸鏂板嚭鐜板苟灏辩华"
				Exit Sub
			End If
		Else
			heroReadyCount = 0
		End If

		' 3) 瀹归敊淇濇姢锛氳嫢宸茬洸鐐硅秴杩 15 娆★紝涓旀娴嬪埌寮哄寲鏍囬橈紝鍒ゆ柇鏄鍚︾嫍绮宸茶楀敖
		If animCount > 15 And CheckImg2(ENHANCE_HERO_TAR) <> null Then
			Delay 400
			If CheckImg2(ENHANCE_HERO_ENHANCE_TAR) = null And CheckImg2(ENHANCE_HERO_TO_ASCEND_TAR) = null Then
				TracePrint "寮哄寲鍔ㄧ敾缁撴潫: 宸插洖鍒板己鍖栫晫闈锛屼絾鏃犲己鍖栨寜閽涓庡啀涓村紩瀵 (鐙楃伯涓嶈冻/QP涓嶈冻)"
				Exit Sub
			End If
		End If

		' 鐩茬偣瀹夊叏鍖 (灞呬腑鍋忓彸涓嬬┖鐧藉尯) 璺宠繃杩囧満鍔ㄧ敾
		tap TAP_ENHANCE_BLIND_SKIP[1], TAP_ENHANCE_BLIND_SKIP[2]
		Delay 250
		animCount = animCount + 1
	Loop
End Sub

' 鐏靛熀鍐嶄复鑷鍔ㄥ寲瀛愭祦绋
Function DoHeroAscendFlow()
	TracePrint "=== [绐佺牬] 寮濮嬫墽琛岃嚜鍔ㄧ獊鐮 ==="
	UpdateRunnerStatus "RUNNING", "鐏靛熀鍐嶄复: 姝ｅ湪绛夊緟椤甸潰..."

	' 1. 绛夊緟纭璁ゅ凡杩涘叆鍐嶄复鐣岄潰 (ENHANCE_ASCEND_TAR)
	Dim waitEnter = 0
	Dim enterSuccess = false
	Do While waitEnter < 25
		If USER_STOP_REQUESTED Or CheckStopSignal() Then
			DoHeroAscendFlow = false
			Exit Function
		End If

		If CheckImg2(ENHANCE_ASCEND_TAR) <> null Then
			enterSuccess = true
			Exit Do
		End If
		Delay 300
		waitEnter = waitEnter + 1
	Loop

	If Not enterSuccess Then
		TracePrint "鏈璇嗗埆杩涘叆鍐嶄复鐣岄潰 (瓒呮椂)"
		DoHeroAscendFlow = false
		Exit Function
	End If

	TracePrint "成功进入再临界面，等待数据加载..."
	Delay 800

	' 1.2 容错：检查是否已处于再临完成界面（出现「前往强化从者」按钮）
	Dim returnBtnPre = CheckImg2(ENHANCE_ASCEND_TO_HERO_TAR)
	If returnBtnPre <> null Then
		TracePrint "灵基再临: 检测到已处于再临完成界面，立即点击「前往强化从者」 ->", returnBtnPre[1], returnBtnPre[2]
		UpdateRunnerStatus "RUNNING", "灵基再临已完成，正在返回强化从者..."
		If TAP_ENHANCE_ASCEND_TO_HERO <> null Then
			tap TAP_ENHANCE_ASCEND_TO_HERO[1], TAP_ENHANCE_ASCEND_TO_HERO[2]
		Else
			tap returnBtnPre[1] + 28, returnBtnPre[2] + 15
		End If
		Delay 1000

		Dim waitHeroBackPre = 0
		Do While waitHeroBackPre < 25
			If USER_STOP_REQUESTED Or CheckStopSignal() Then
				Exit Do
			End If
			If CheckImg2(ENHANCE_HERO_TAR) <> null Then
				TracePrint "灵基再临: 已成功返回从者强化主界面"
				DoHeroAscendFlow = true
				Exit Function
			End If
			If waitHeroBackPre Mod 5 = 4 Then
				returnBtnPre = CheckImg2(ENHANCE_ASCEND_TO_HERO_TAR)
				If returnBtnPre <> null Then
					If TAP_ENHANCE_ASCEND_TO_HERO <> null Then
						tap TAP_ENHANCE_ASCEND_TO_HERO[1], TAP_ENHANCE_ASCEND_TO_HERO[2]
					Else
						tap returnBtnPre[1] + 100, returnBtnPre[2] + 16
					End If
				End If
			End If
			Delay 300
			waitHeroBackPre = waitHeroBackPre + 1
		Loop
		DoHeroAscendFlow = true
		Exit Function
	End If

	' 2. 检查是否已处于临时从者提示弹窗或确认弹窗状态（容错）
	Dim tempAscendPre = CheckImg2(ENHANCE_HERO_TEMP_CONFIRM_TAR)
	If tempAscendPre <> null Then
		TracePrint "灵基再临: 容错检测到临时从者提示弹窗，点击「决定」按钮 ->", tempAscendPre[1], tempAscendPre[2]
		If TAP_ENHANCE_HERO_TEMP_CONFIRM <> null Then
			tap TAP_ENHANCE_HERO_TEMP_CONFIRM[1], TAP_ENHANCE_HERO_TEMP_CONFIRM[2]
		Else
			tap tempAscendPre[1] + 43, tempAscendPre[2] + 19
		End If
		Delay 600
	End If

	' 2.1 右下角「强化」执行按钮 (再临界面执行突破，按钮与强化同为「强化」)
	Dim ascendBtnCoord = CheckImg2(ENHANCE_ASCEND_BTN_TAR)
	If ascendBtnCoord = null Then
		ascendBtnCoord = CheckImg2(ENHANCE_HERO_ENHANCE_TAR)
	End If
	Dim confirmCoord = CheckImg2(ENHANCE_ASCEND_CONFIRM_TAR)
	If ascendBtnCoord = null And confirmCoord = null Then
		' 容错：检查是否其实已处于突破完成界面（出现「前往强化从者」按钮）
		Dim toHeroFallback = CheckImg2(ENHANCE_ASCEND_TO_HERO_TAR)
		If toHeroFallback <> null Then
			TracePrint "灵基再临: 检测到已完成突破，点击「前往强化从者」 ->", toHeroFallback[1], toHeroFallback[2]
			UpdateRunnerStatus "RUNNING", "灵基再临已完成，正在返回强化从者..."
			If TAP_ENHANCE_ASCEND_TO_HERO <> null Then
				tap TAP_ENHANCE_ASCEND_TO_HERO[1], TAP_ENHANCE_ASCEND_TO_HERO[2]
			Else
				tap toHeroFallback[1] + 28, toHeroFallback[2] + 15
			End If
			Delay 1200
			DoHeroAscendFlow = true
			Exit Function
		End If

		TracePrint "灵基再临强化按钮未出现或素材/QP不足，安全终止突破"
		UpdateRunnerStatus "IDLE", "灵基再临素材不足或QP不足，无法继续突破"
		DoHeroAscendFlow = false
		Exit Function
	End If

	' 3. 点击再临强化按钮并等待确认弹窗（带重试机制，避免单次点击未响应导致死等）
	If confirmCoord = null Then
		Dim clickRetry = 0
		Do While clickRetry < 4
			TracePrint "点击右下角再临「强化」按钮 ->", ascendBtnCoord[1], ascendBtnCoord[2]
			If EXTRA_DRY_RUN = 1 Then
				TracePrint "[DRY-RUN 仿真安全模式] 拦截点击灵基再临「强化」执行按钮 ->", ascendBtnCoord[1], ascendBtnCoord[2]
				UpdateRunnerStatus "IDLE", "仿真模式：已拦截灵基再临强化点击"
				DoHeroAscendFlow = false
				Exit Function
			End If
			UpdateRunnerStatus "RUNNING", "灵基再临中: 正在点击执行再临..."
			tap ascendBtnCoord[1], ascendBtnCoord[2]
			Delay 800

			' 检查确认弹窗是否出现
			Dim waitPop = 0
			Do While waitPop < 8
				' 检查是否出现临时从者提示弹窗（在点击强化后、确认强化弹窗前出现）
				Dim tempCoord = CheckImg2(ENHANCE_HERO_TEMP_CONFIRM_TAR)
				If tempCoord <> null Then
					TracePrint "灵基再临: 检测到临时从者提示弹窗，点击「决定」按钮 ->", tempCoord[1], tempCoord[2]
					If TAP_ENHANCE_HERO_TEMP_CONFIRM <> null Then
						tap TAP_ENHANCE_HERO_TEMP_CONFIRM[1], TAP_ENHANCE_HERO_TEMP_CONFIRM[2]
					Else
						tap tempCoord[1] + 43, tempCoord[2] + 19
					End If
					Delay 600
				End If

				confirmCoord = CheckImg2(ENHANCE_ASCEND_CONFIRM_TAR)
				If confirmCoord <> null Then
					Exit Do
				End If
				Delay 300
				waitPop = waitPop + 1
			Loop

			If confirmCoord <> null Then
				Exit Do
			End If
			clickRetry = clickRetry + 1
		Loop
	End If

	If confirmCoord = null Then
		TracePrint "未检测到灵基再临确认弹窗，安全退出"
		UpdateRunnerStatus "IDLE", "未检测到灵基再临确认弹窗"
		DoHeroAscendFlow = false
		Exit Function
	End If

	TracePrint "点击灵基再临确认弹窗「决定」按钮 ->", confirmCoord[1], confirmCoord[2]
	If EXTRA_DRY_RUN = 1 Then
		TracePrint "[DRY-RUN 仿真安全模式] 拦截点击灵基再临「二次确认决定」按钮 ->", confirmCoord[1], confirmCoord[2]
		UpdateRunnerStatus "IDLE", "仿真模式：已拦截再临二次确认点击"
		DoHeroAscendFlow = false
		Exit Function
	End If
	If TAP_ENHANCE_ASCEND_CONFIRM <> null Then
		tap TAP_ENHANCE_ASCEND_CONFIRM[1], TAP_ENHANCE_ASCEND_CONFIRM[2]
	Else
		tap confirmCoord[1] + 43, confirmCoord[2] + 19
	End If
	Delay 600

	' 4. 盲点点击跳过再临动画并探测「前往强化从者」按钮
	TracePrint "确认再临，开始盲点加速并等待结束..."
	UpdateRunnerStatus "RUNNING", "灵基再临中: 加速动画..."

	Dim animRetry = 0
	Dim foundReturnBtn = false
	Dim returnBtnCoord = null
	Do While animRetry < 240
		If USER_STOP_REQUESTED Or CheckStopSignal() Then
			DoHeroAscendFlow = false
			Exit Function
		End If

		' 优先检查是否出现「前往强化从者」快捷返回按钮
		returnBtnCoord = CheckImg2(ENHANCE_ASCEND_TO_HERO_TAR)
		If returnBtnCoord <> null Then
			foundReturnBtn = true
			TracePrint "灵基再临: 检测到「前往强化从者」快捷按钮 ->", returnBtnCoord[1], returnBtnCoord[2]
			Exit Do
		End If

		' 盲点加速 (底部空白安全区 1060, 760)
		tap TAP_ENHANCE_BLIND_SKIP[1], TAP_ENHANCE_BLIND_SKIP[2]
		Delay 250
		animRetry = animRetry + 1
		If animRetry Mod 8 = 0 Then
			UpdateRunnerStatus "RUNNING", "灵基再临中: 加速动画与语音(" & Int(animRetry / 4) & "s)..."
		End If
	Loop

	' 5. 鐐瑰嚮蹇鎹锋寜閽杩斿洖寮哄寲 (浼樺厛浣跨敤璇嗗埆鍒扮殑鐩鏍囧乏涓婅掑潗鏍)
	If foundReturnBtn Then
		TracePrint "鐐瑰嚮銆屽墠寰寮哄寲浠庤呫嶅揩鎹锋寜閽杩斿洖寮哄寲 ->", returnBtnCoord[1], returnBtnCoord[2]
		UpdateRunnerStatus "RUNNING", "鐏靛熀鍐嶄复绐佺牬鎴愬姛锛屾ｅ湪杩斿洖寮哄寲浠庤..."
		If TAP_ENHANCE_ASCEND_TO_HERO <> null Then
			tap TAP_ENHANCE_ASCEND_TO_HERO[1], TAP_ENHANCE_ASCEND_TO_HERO[2]
		Else
			tap returnBtnCoord[1] + 100, returnBtnCoord[2] + 16
		End If
		Delay 1000

		' 纭璁ゆ槸鍚︽垚鍔熻繑鍥炲己鍖栫晫闈
		Dim waitBack = 0
		Do While waitBack < 25
			If USER_STOP_REQUESTED Or CheckStopSignal() Then
				Exit Do
			End If
			If CheckImg2(ENHANCE_HERO_TAR) <> null Then
				TracePrint "宸叉垚鍔熻繑鍥炲己鍖栫晫闈锛屽畬鎴愰棴鐜"
				DoHeroAscendFlow = true
				Exit Function
			End If
			' 鑻 1.5s 鍚庝粛鏈杩斿洖锛岄噸璇曠偣鍑诲揩鎹疯繑鍥炴寜閽
			If waitBack Mod 5 = 4 Then
				returnBtnCoord = CheckImg2(ENHANCE_ASCEND_TO_HERO_TAR)
				If returnBtnCoord <> null Then
					If TAP_ENHANCE_ASCEND_TO_HERO <> null Then
						tap TAP_ENHANCE_ASCEND_TO_HERO[1], TAP_ENHANCE_ASCEND_TO_HERO[2]
					Else
						tap returnBtnCoord[1] + 100, returnBtnCoord[2] + 16
					End If
				End If
			End If
			Delay 300
			waitBack = waitBack + 1
		Loop
	Else
		TracePrint "绛夊緟蹇鎹疯繑鍥炴寜閽瓒呮椂锛屽皾璇曠偣鍑诲乏涓婅掕繑鍥炴寜閽"
		Dim backCoord = CheckImg2(ENHANCE_ASCEND_BACK_TAR)
		If backCoord <> null Then
			tap backCoord[1], backCoord[2]
		Else
			tap TAP_ENHANCE_ASCEND_BACK[1], TAP_ENHANCE_ASCEND_BACK[2]
		End If
		Delay 1000
	End If

	DoHeroAscendFlow = true
End Function

' 鑷鍔ㄥ湥鏉杞涓村畬鏁存墽琛屾祦
Function DoHeroGrailFlow()
	TracePrint "=== [鍦ｆ澂杞涓碷 寮濮嬫墽琛岃嚜鍔ㄥ湥鏉杞涓 ==="
	UpdateRunnerStatus "RUNNING", "鍦ｆ澂杞涓: 姝ｅ湪绛夊緟杩涘叆椤甸潰..."

	' 1. 绛夊緟纭璁ゅ凡杩涘叆鍦ｆ澂杞涓翠富鐣岄潰 (ENHANCE_GRAIL_TAR)
	Dim waitEnter = 0
	Dim enterSuccess = false
	Do While waitEnter < 25
		If USER_STOP_REQUESTED Or CheckStopSignal() Then
			DoHeroGrailFlow = false
			Exit Function
		End If

		If CheckImg2(ENHANCE_GRAIL_TAR) <> null Then
			enterSuccess = true
			Exit Do
		End If
		Delay 300
		waitEnter = waitEnter + 1
	Loop

	If Not enterSuccess Then
		TracePrint "鏈璇嗗埆鍒板湥鏉杞涓翠富鐣岄潰 (瓒呮椂)"
		DoHeroGrailFlow = false
		Exit Function
	End If

	TracePrint "成功进入圣杯转临界面，等待数据加载..."
	Delay 800

	' 1.1 转临界面二次防守：若设置了 100 级上限 (EXTRA_HERO_AUTO_GRAIL = 1)，核验转临结果下方当前等级是否已是 100 级
	If EXTRA_HERO_AUTO_GRAIL = 1 Then
		Dim lv100GrailCoord = CheckImg2(ENHANCE_GRAIL_HERO_LV100_TAR)
		If lv100GrailCoord <> null Then
			TracePrint "圣杯转临二次防守: 检测到转临结果等级已达 100 级且设置了 100 上限，安全拦截转临并终止！"
			UpdateRunnerStatus "IDLE", "从者已达 100 级上限，停止圣杯转临"
			DoHeroGrailFlow = false
			Exit Function
		End If
	End If

	' 1.2 容错：检查是否已处于圣杯转临完成界面（出现「前往强化从者」按钮）
	Dim grailReturnBtnPre = CheckImg2(ENHANCE_ASCEND_TO_HERO_TAR)
	If grailReturnBtnPre <> null Then
		TracePrint "圣杯转临: 检测到已处于转临完成界面，立即点击「前往强化从者」 ->", grailReturnBtnPre[1], grailReturnBtnPre[2]
		UpdateRunnerStatus "RUNNING", "圣杯转临已完成，正在返回强化从者..."
		If TAP_ENHANCE_ASCEND_TO_HERO <> null Then
			tap TAP_ENHANCE_ASCEND_TO_HERO[1], TAP_ENHANCE_ASCEND_TO_HERO[2]
		Else
			tap grailReturnBtnPre[1] + 100, grailReturnBtnPre[2] + 16
		End If
		Delay 1000

		Dim waitGrailHeroBackPre = 0
		Do While waitGrailHeroBackPre < 25
			If USER_STOP_REQUESTED Or CheckStopSignal() Then
				Exit Do
			End If
			If CheckImg2(ENHANCE_HERO_TAR) <> null Then
				TracePrint "圣杯转临: 已成功返回从者强化主界面"
				DoHeroGrailFlow = true
				Exit Function
			End If
			If waitGrailHeroBackPre Mod 5 = 4 Then
				grailReturnBtnPre = CheckImg2(ENHANCE_ASCEND_TO_HERO_TAR)
				If grailReturnBtnPre <> null Then
					If TAP_ENHANCE_ASCEND_TO_HERO <> null Then
						tap TAP_ENHANCE_ASCEND_TO_HERO[1], TAP_ENHANCE_ASCEND_TO_HERO[2]
					Else
						tap grailReturnBtnPre[1] + 100, grailReturnBtnPre[2] + 16
					End If
				End If
			End If
			Delay 300
			waitGrailHeroBackPre = waitGrailHeroBackPre + 1
		Loop
		DoHeroGrailFlow = true
		Exit Function
	End If

	' 2. 检查是否已处于临时从者提示弹窗或确认弹窗状态（容错）
	Dim tempGrailPre = CheckImg2(ENHANCE_HERO_TEMP_CONFIRM_TAR)
	If tempGrailPre <> null Then
		TracePrint "圣杯转临: 容错检测到临时从者提示弹窗，点击「决定」按钮 ->", tempGrailPre[1], tempGrailPre[2]
		If TAP_ENHANCE_HERO_TEMP_CONFIRM <> null Then
			tap TAP_ENHANCE_HERO_TEMP_CONFIRM[1], TAP_ENHANCE_HERO_TEMP_CONFIRM[2]
		Else
			tap tempGrailPre[1] + 43, tempGrailPre[2] + 19
		End If
		Delay 600
	End If

	' 2.1 检测右下角「强化」执行按钮 (与再临/强化同为「强化」)
	Dim grailBtnCoord = CheckImg2(ENHANCE_ASCEND_BTN_TAR)
	If grailBtnCoord = null Then
		grailBtnCoord = CheckImg2(ENHANCE_HERO_ENHANCE_TAR)
	End If
	Dim confirmCoord = CheckImg2(ENHANCE_GRAIL_CONFIRM_TAR)
	If confirmCoord = null Then
		confirmCoord = CheckImg2(Array(877, 632, 1006, 698, "Attachment:ENHANCE_GRAIL_CONFIRM.png"))
	End If
	If grailBtnCoord = null And confirmCoord = null Then
		' 容错：检查是否其实已处于突破/转临完成界面（出现「前往强化从者」按钮）
		Dim toHeroFallback = CheckImg2(ENHANCE_ASCEND_TO_HERO_TAR)
		If toHeroFallback <> null Then
			TracePrint "圣杯转临: 检测到已完成转临，点击「前往强化从者」 ->", toHeroFallback[1], toHeroFallback[2]
			UpdateRunnerStatus "RUNNING", "圣杯转临已完成，正在返回强化从者..."
			If TAP_ENHANCE_ASCEND_TO_HERO <> null Then
				tap TAP_ENHANCE_ASCEND_TO_HERO[1], TAP_ENHANCE_ASCEND_TO_HERO[2]
			Else
				tap toHeroFallback[1] + 28, toHeroFallback[2] + 15
			End If
			Delay 1200
			DoHeroGrailFlow = true
			Exit Function
		End If

		TracePrint "圣杯转临「强化」按钮未激活(圣杯/QP不足)，安全终止转临"
		UpdateRunnerStatus "IDLE", "圣杯不足或QP不足，无法转临"
		DoHeroGrailFlow = false
		Exit Function
	End If

	' 3. 点击强化按钮并等待二次确认「决定」按钮（带 4 次重试）
	' 先检查确认弹窗或临时从者提示是否已处于弹出状态（容错：可能上一轮或外部已唤起弹窗）
	Dim tempCoord = CheckImg2(ENHANCE_HERO_TEMP_CONFIRM_TAR)
	If tempCoord <> null Then
		TracePrint "圣杯转临: 容错检测到临时从者提示弹窗，点击「决定」按钮 ->", tempCoord[1], tempCoord[2]
		If TAP_ENHANCE_HERO_TEMP_CONFIRM <> null Then
			tap TAP_ENHANCE_HERO_TEMP_CONFIRM[1], TAP_ENHANCE_HERO_TEMP_CONFIRM[2]
		Else
			tap tempCoord[1] + 43, tempCoord[2] + 19
		End If
		Delay 600
	End If

	confirmCoord = CheckImg2(ENHANCE_GRAIL_CONFIRM_TAR)
	If confirmCoord = null Then
		confirmCoord = CheckImg2(Array(877, 632, 1006, 698, "Attachment:ENHANCE_GRAIL_CONFIRM.png"))
	End If
	If confirmCoord = null Then
		Dim clickRetry = 0
		Do While clickRetry < 4
			TracePrint "点击圣杯转临「强化」按钮 ->", grailBtnCoord[1], grailBtnCoord[2]
			If EXTRA_DRY_RUN = 1 Then
				TracePrint "[DRY-RUN 仿真安全模式] 拦截点击圣杯转临「强化」执行按钮 ->", grailBtnCoord[1], grailBtnCoord[2]
				UpdateRunnerStatus "IDLE", "仿真模式：已拦截圣杯转临强化点击"
				DoHeroGrailFlow = false
				Exit Function
			End If
			UpdateRunnerStatus "RUNNING", "圣杯转临: 正在点击执行..."
			tap grailBtnCoord[1], grailBtnCoord[2]
			Delay 800

			' 检测确认弹窗「决定」按钮是否出现
			Dim waitPop = 0
			Do While waitPop < 8
				tempCoord = CheckImg2(ENHANCE_HERO_TEMP_CONFIRM_TAR)
				If tempCoord <> null Then
					TracePrint "圣杯转临: 检测到临时从者提示弹窗，点击「决定」按钮 ->", tempCoord[1], tempCoord[2]
					If TAP_ENHANCE_HERO_TEMP_CONFIRM <> null Then
						tap TAP_ENHANCE_HERO_TEMP_CONFIRM[1], TAP_ENHANCE_HERO_TEMP_CONFIRM[2]
					Else
						tap tempCoord[1] + 43, tempCoord[2] + 19
					End If
					Delay 600
				End If

				confirmCoord = CheckImg2(ENHANCE_GRAIL_CONFIRM_TAR)
				If confirmCoord = null Then
					confirmCoord = CheckImg2(Array(877, 632, 1006, 698, "Attachment:ENHANCE_GRAIL_CONFIRM.png"))
				End If
				If confirmCoord <> null Then
					Exit Do
				End If
				Delay 300
				waitPop = waitPop + 1
			Loop

			If confirmCoord <> null Then
				Exit Do
			End If
			clickRetry = clickRetry + 1
		Loop
	End If

	If confirmCoord = null Then
		TracePrint "鏈妫娴嬪埌杞涓寸‘璁ゅ脊绐楋紝瀹夊叏閫鍑"
		UpdateRunnerStatus "IDLE", "鏈妫娴嬪埌杞涓寸‘璁ゅ脊绐"
		DoHeroGrailFlow = false
		Exit Function
	End If

	TracePrint "点击确认「决定」按钮 ->", confirmCoord[1], confirmCoord[2]
	If EXTRA_DRY_RUN = 1 Then
		TracePrint "[DRY-RUN 仿真安全模式] 拦截点击圣杯转临「二次确认决定」按钮 ->", confirmCoord[1], confirmCoord[2]
		UpdateRunnerStatus "IDLE", "仿真模式：已拦截转临二次确认点击"
		DoHeroGrailFlow = false
		Exit Function
	End If
	If TAP_ENHANCE_GRAIL_CONFIRM <> null Then
		tap TAP_ENHANCE_GRAIL_CONFIRM[1], TAP_ENHANCE_GRAIL_CONFIRM[2]
	Else
		tap confirmCoord[1] + 40, confirmCoord[2] + 20
	End If
	Delay 600

	' 4. 盲点快速跳过动画并准确探测「前往强化从者」按钮
	TracePrint "已确认，开始盲点跳过圣杯转临动画..."
	UpdateRunnerStatus "RUNNING", "圣杯转临: 跳过动画..."

	Dim animRetry = 0
	Dim foundReturnBtn = false
	Dim returnBtnCoord = null
	Do While animRetry < 100
		If USER_STOP_REQUESTED Or CheckStopSignal() Then
			DoHeroGrailFlow = false
			Exit Function
		End If

		' 4.1 准确检查是否出现「前往强化从者」快捷按钮
		returnBtnCoord = CheckImg2(ENHANCE_ASCEND_TO_HERO_TAR)
		If returnBtnCoord <> null Then
			foundReturnBtn = true
			TracePrint "圣杯转临: 准确检测到「前往强化从者」快捷按钮 ->", returnBtnCoord[1], returnBtnCoord[2]
			Exit Do
		End If

		' 盲点安全区快速跳过动画 (底部空白安全区 1060, 760)
		tap TAP_ENHANCE_BLIND_SKIP[1], TAP_ENHANCE_BLIND_SKIP[2]
		Delay 250
		animRetry = animRetry + 1
		If animRetry Mod 8 = 0 Then
			UpdateRunnerStatus "RUNNING", "圣杯转临: 跳过动画(" & Int(animRetry / 4) & "s)..."
		End If
	Loop

	' 5. 若超时未准确检测到按钮，按安全策略直接报错停机，严禁盲目固定兜底
	If Not foundReturnBtn Then
		TracePrint "圣杯转临超时: 持续 25 秒未准确识别到「前往强化从者」按钮，安全停机！"
		UpdateRunnerStatus "IDLE", "圣杯转临未检测到前往强化按钮，安全停止"
		ABORT_REASON = "圣杯转临未检测到前往强化按钮，安全停止"
		USER_STOP_REQUESTED = true
		DoHeroGrailFlow = false
		Exit Function
	End If

	' 6. 准确检测到按钮，点击返回从者强化
	TracePrint "点击「前往强化从者」快捷按钮返回强化 ->", returnBtnCoord[1] + 28, returnBtnCoord[2] + 15
	UpdateRunnerStatus "RUNNING", "圣杯转临成功，正在返回强化从者..."
	tap returnBtnCoord[1] + 28, returnBtnCoord[2] + 15
	Delay 1000

	' 7. 严格确认是否成功返回强化主界面，杜绝外层死循环
	Dim waitBack = 0
	Dim backSuccess = false
	Do While waitBack < 30
		If USER_STOP_REQUESTED Or CheckStopSignal() Then
			Exit Do
		End If
		If CheckImg2(ENHANCE_HERO_TAR) <> null Then
			TracePrint "已成功从圣杯转临返回从者强化界面，转临闭环完成"
			backSuccess = true
			Exit Do
		End If
		If waitBack Mod 6 = 5 Then
			' 容错重试：若仍处于转临完成界面，重试点击
			returnBtnCoord = CheckImg2(ENHANCE_ASCEND_TO_HERO_TAR)
			If returnBtnCoord <> null Then
				TracePrint "重试点击「前往强化从者」按钮 ->", returnBtnCoord[1] + 28, returnBtnCoord[2] + 15
				tap returnBtnCoord[1] + 28, returnBtnCoord[2] + 15
			End If
		End If
		Delay 300
		waitBack = waitBack + 1
	Loop

	If Not backSuccess Then
		TracePrint "圣杯转临点击返回后超时未进入从者强化主界面，按安全策略报错停机！"
		UpdateRunnerStatus "IDLE", "转临后未成功返回强化主界面，安全停止"
		ABORT_REASON = "转临后未成功返回强化主界面，安全停止"
		USER_STOP_REQUESTED = true
		DoHeroGrailFlow = false
		Exit Function
	End If

	DoHeroGrailFlow = true
End Function


Function DoEnhance()
	' 0. 容错：若停留在再临/转临完成界面，立即点击「前往强化从者」
	Dim toHeroEntry = CheckImg2(ENHANCE_ASCEND_TO_HERO_TAR)
	If toHeroEntry <> null Then
		TracePrint "从者强化入口容错：检测到停留在再临/转临完成界面，立即点击「前往强化从者」 ->", toHeroEntry[1], toHeroEntry[2]
		UpdateRunnerStatus "RUNNING", "检测到再临完成，正在返回强化从者..."
		If TAP_ENHANCE_ASCEND_TO_HERO <> null Then
			tap TAP_ENHANCE_ASCEND_TO_HERO[1], TAP_ENHANCE_ASCEND_TO_HERO[2]
		Else
			tap toHeroEntry[1] + 28, toHeroEntry[2] + 15
		End If
		Delay 1200
		Exit Function
	End If

	' 0.1 容错：检查是否停留在素材返还弹窗或临时从者提示弹窗
	Dim refundCloseEntry = CheckImg2(ENHANCE_HERO_REFUND_CLOSE_TAR)
	If refundCloseEntry <> null Then
		TracePrint "容错检测到素材返还弹窗，点击关闭按钮 ->", refundCloseEntry[1], refundCloseEntry[2]
		tap refundCloseEntry[1], refundCloseEntry[2]
		Delay 800
		SkipHeroEnhanceAnim()
		Delay 500
	End If

	Dim confirmEntry = CheckImg2(ENHANCE_HERO_ENHANCE_CONFIRM_TAR)
	If confirmEntry <> null Then
		TracePrint "容错：检测到停留在强化确认弹窗，点击「决定」按钮 ->", confirmEntry[1], confirmEntry[2]
		If EXTRA_DRY_RUN = 1 Then
			TracePrint "[DRY-RUN 仿真安全模式] 拦截容错强化确认点击 ->", confirmEntry[1], confirmEntry[2]
			UpdateRunnerStatus "IDLE", "仿真模式：已拦截容错强化确认点击"
			HasTicket = false
			Exit Function
		End If
		tap confirmEntry[1] + 43, confirmEntry[2] + 19
		Delay 600
		UpdateRunnerStatus "RUNNING", "跳过强化动画中 (第 " & CurrentBattleCount & "/" & EXTRA_ACTION_COUNT & " 次)..."
		SkipHeroEnhanceAnim()
		Delay 300
		Exit Function
	End If

	Dim tempEntry = CheckImg2(ENHANCE_HERO_TEMP_CONFIRM_TAR)
	If tempEntry <> null Then
		TracePrint "容错：检测到停留在临时从者提示弹窗，点击「决定」按钮 ->", tempEntry[1], tempEntry[2]
		If TAP_ENHANCE_HERO_TEMP_CONFIRM <> null Then
			tap TAP_ENHANCE_HERO_TEMP_CONFIRM[1], TAP_ENHANCE_HERO_TEMP_CONFIRM[2]
		Else
			tap tempEntry[1] + 43, tempEntry[2] + 19
		End If
		Delay 800

		' 容错后续：点击临时从者「决定」后，若紧接着出现强化确认弹窗，一并点击「决定」并跳过动画
		Dim confirmWait = 0
		Do While confirmWait < 8
			Dim postConfirm = CheckImg2(ENHANCE_HERO_ENHANCE_CONFIRM_TAR)
			If postConfirm <> null Then
				TracePrint "容错：临时提示确认后出现强化确认弹窗，点击「决定」按钮 ->", postConfirm[1], postConfirm[2]
				tap postConfirm[1] + 43, postConfirm[2] + 19
				Delay 600
				Exit Do
			End If
			Delay 250
			confirmWait = confirmWait + 1
		Loop

		UpdateRunnerStatus "RUNNING", "跳过强化动画中 (第 " & CurrentBattleCount & "/" & EXTRA_ACTION_COUNT & " 次)..."
		SkipHeroEnhanceAnim()
		Delay 300
		Exit Function
	End If

	' 1. 瀹归敊锛氳嫢褰撳墠涓嶅湪浠庤呭己鍖栦富鐣岄潰锛屾鏌ユ槸鍚﹀仠鐣欏湪鐏靛熀鍐嶄复鐩稿叧鐣岄潰
	If CheckImg2(ENHANCE_HERO_TAR) = null Then
		If CheckImg2(ENHANCE_ASCEND_TO_HERO_TAR) <> null Then
			TracePrint "容错：检测到停留在再临/转临完成界面，自动点击「前往强化从者」"
			If TAP_ENHANCE_ASCEND_TO_HERO <> null Then
				tap TAP_ENHANCE_ASCEND_TO_HERO[1], TAP_ENHANCE_ASCEND_TO_HERO[2]
			Else
				tap 1180, 321
			End If
			Delay 1500
			Exit Function
		ElseIf CheckImg2(ENHANCE_ASCEND_TAR) <> null Then
			TracePrint "容错：检测到当前正处于灵基再临界面，直接执行灵基再临流程..."
			Dim directAscend = DoHeroAscendFlow()
			If Not directAscend Then
				TracePrint "灵基再临未成功，终止强化"
				HasTicket = false
			End If
			Exit Function
		ElseIf CheckImg2(ENHANCE_GRAIL_TAR) <> null Then
			TracePrint "容错：检测到当前在圣杯转临界面，直接执行转临流程..."
			Dim directGrail = DoHeroGrailFlow()
			If Not directGrail Then
				TracePrint "圣杯转临未成功，终止强化"
				HasTicket = false
			End If
			Exit Function
		End If
	End If

' 2. 鏍稿績鍒嗘敮锛氭鏌ユ槸鍚﹀嚭鐜般屽墠寰鐏靛熀鍐嶄复銆嶅紩瀵 (浠庤呭凡杈鹃樁娈垫弧绾)
	Dim toAscendCoord = CheckImg2(ENHANCE_HERO_TO_ASCEND_TAR)
	If toAscendCoord <> null Then
		If EXTRA_HERO_AUTO_ASCEND = 1 Then
			TracePrint "检测到「前往灵基再临」引导，【自动灵基再临】已开启，执行跳转突破..."
			UpdateRunnerStatus "RUNNING", "从者已达阶段满级，正在跳转灵基再临..."
			If EXTRA_DRY_RUN = 1 Then
				TracePrint "[DRY-RUN 仿真安全模式] 拦截点击「前往灵基再临」 ->", toAscendCoord[1], toAscendCoord[2]
				UpdateRunnerStatus "IDLE", "仿真模式：已拦截点击「前往灵基再临」"
				HasTicket = false
				Exit Function
			End If
			tap toAscendCoord[1], toAscendCoord[2]
			Delay 1000

			Dim ascendResult = DoHeroAscendFlow()
			If Not ascendResult Then
				TracePrint "鐏靛熀鍐嶄复鏈鎴愬姛瀹屾垚锛岀粓姝㈠悗缁寮哄寲"
				HasTicket = false
			End If
			Exit Function
		Else
			TracePrint "妫娴嬪埌銆屽墠寰鐏靛熀鍐嶄复銆嶅紩瀵硷紝浣嗘湭鍕鹃夈愯嚜鍔ㄧ伒鍩哄啀涓淬戯紝姝ｅ父缁撴潫鏁村囦换鍔"
			UpdateRunnerStatus "IDLE", "浠庤呭凡杈惧綋鍓嶉樁娈垫弧绾 (鏈寮鍚鑷鍔ㄧ伒鍩哄啀涓)"
			HasTicket = false
			Exit Function
		End If
	End If

	' 2.5 圣杯转临分支：是否出现「前往圣杯转临」 (已达当前等级上限)
	Dim toGrailCoord = CheckImg2(ENHANCE_HERO_TO_GRAIL_TAR)
	If toGrailCoord <> null Then
		If EXTRA_HERO_AUTO_GRAIL = 1 Or EXTRA_HERO_AUTO_GRAIL = 2 Then
			' 强化界面防守：若设置了 100 级上限 (EXTRA_HERO_AUTO_GRAIL = 1)，核验强化结果下方当前等级是否已是 100 级
			If EXTRA_HERO_AUTO_GRAIL = 1 Then
				Dim lv100Coord = CheckImg2(ENHANCE_HERO_LV100_TAR)
				If lv100Coord <> null Then
					TracePrint "强化防守: 检测到强化结果等级已达到 100 级且设置了 100 上限，停止圣杯转临与强化"
					UpdateRunnerStatus "IDLE", "从者已达 100 级上限，强化结束"
					HasTicket = false
					Exit Function
				End If
			End If

			TracePrint "检测到「前往圣杯转临」，自动圣杯转临已开启，执行跳转转临..."
			UpdateRunnerStatus "RUNNING", "已达满级，跳转圣杯转临..."
			If EXTRA_DRY_RUN = 1 Then
				TracePrint "[DRY-RUN 仿真安全模式] 拦截点击「前往圣杯转临」 ->", toGrailCoord[1], toGrailCoord[2]
				UpdateRunnerStatus "IDLE", "仿真模式：已拦截点击「前往圣杯转临」"
				HasTicket = false
				Exit Function
			End If
			tap toGrailCoord[1], toGrailCoord[2]
			Delay 1000

			Dim grailResult = DoHeroGrailFlow()
			If Not grailResult Then
				TracePrint "圣杯转临未成功完成，终止后续强化"
				HasTicket = false
			End If
			Exit Function
		Else
			TracePrint "从者已达等级上限（显示【前往圣杯转临】），自动圣杯转临未开启，强化流程圆满结束"
			UpdateRunnerStatus "IDLE", "从者已达满级(需圣杯转临)"
			HasTicket = false
			Exit Function
		End If
	End If

	' 3. 妫鏌ュ彸涓嬭掋屽己鍖栥嶆寜閽 (娓告垙鍘熺敓宸茶嚜鍔ㄥ～鍏ョ嫍绮)
	Dim enhanceCoord = CheckImg2(ENHANCE_HERO_ENHANCE_TAR)
	If enhanceCoord = null Then
		' 瀹归敊缂撳啿锛氶噸璇 3 娆★紝闃叉㈢綉缁滃欢鏃舵垨鐢婚潰鍔ㄧ敾杩囨浮
		Dim retryIdx = 0
		Do While retryIdx < 3
			Delay 400
			If CheckImg2(ENHANCE_HERO_TO_ASCEND_TAR) <> null Then
				Exit Function ' 鍒锋柊鍑哄啀涓存寜閽锛岄鍑哄綋鍓嶅姩浣滆繘鍏ヤ笅涓杞鍐嶄复鍒嗘敮
			End If
			enhanceCoord = CheckImg2(ENHANCE_HERO_ENHANCE_TAR)
			If enhanceCoord <> null Then
				Exit Do
			End If
			retryIdx = retryIdx + 1
		Loop

		If enhanceCoord = null Then
			TracePrint "鏈鎵惧埌銆屽己鍖栥嶆寜閽涓旀棤鍐嶄复寮曞硷紝鍒ゅ畾涓虹嫍绮鑰楀敖銆丵P涓嶈冻鎴栦笉鍙寮哄寲锛屽畨鍏ㄩ鍑"
			UpdateRunnerStatus "IDLE", "浠庤呭己鍖栫粨鏉 (鐙楃伯涓嶈冻/QP涓嶈冻/鏈閫変粠鑰)"
			HasTicket = false
			Exit Function
		End If
	End If

	' 4. 鐐瑰嚮銆屽己鍖栥嶆寜閽
	TracePrint "从者强化: 准备点击「强化」按钮 ->", enhanceCoord[1], enhanceCoord[2]
	If EXTRA_DRY_RUN = 1 Then
		TracePrint "[DRY-RUN 仿真安全模式] 拦截点击「强化」按钮 ->", enhanceCoord[1], enhanceCoord[2]
		UpdateRunnerStatus "IDLE", "仿真模式：已拦截点击强化（真实点击已屏蔽）"
		HasTicket = false
		Exit Function
	End If
	UpdateRunnerStatus "RUNNING", "浠庤呭己鍖栨墽琛屼腑 (绗 " & CurrentBattleCount & "/" & EXTRA_ACTION_COUNT & " 娆)..."
	tap enhanceCoord[1], enhanceCoord[2]
	Delay 500

	' 4.5 检查是否出现临时从者提示弹窗（在点击强化后、确认强化弹窗前出现）
	Dim waitTemp = 0
	Do While waitTemp < 6
		Dim tempCoord = CheckImg2(ENHANCE_HERO_TEMP_CONFIRM_TAR)
		If tempCoord <> null Then
			TracePrint "从者强化: 检测到临时从者提示弹窗，点击「决定」按钮 ->", tempCoord[1], tempCoord[2]
			If TAP_ENHANCE_HERO_TEMP_CONFIRM <> null Then
				tap TAP_ENHANCE_HERO_TEMP_CONFIRM[1], TAP_ENHANCE_HERO_TEMP_CONFIRM[2]
			Else
				tap tempCoord[1] + 43, tempCoord[2] + 19
			End If
			Delay 600
			Exit Do
		End If
		' 若已直接出现最终确认弹窗，说明无需临时提示，提前结束检测
		If CheckImg2(ENHANCE_HERO_ENHANCE_CONFIRM_TAR) <> null Then
			Exit Do
		End If
		Delay 200
		waitTemp = waitTemp + 1
	Loop

	' 5. 绛夊緟骞剁偣鍑诲己鍖栫‘璁ゅ脊绐椼屽喅瀹氥嶆寜閽
	Dim confirmCoord = ContinuousCheckImg(ENHANCE_HERO_ENHANCE_CONFIRM_TAR)
	If confirmCoord <> null Then
		TracePrint "浠庤呭己鍖: 鐐瑰嚮纭璁ゅ脊绐椼屽喅瀹氥嶆寜閽 ->", confirmCoord[1], confirmCoord[2]
		tap confirmCoord[1] + 43, confirmCoord[2] + 19
		Delay 500
	End If

	' 6. 楂橀戠洸鐐硅烦杩囧己鍖栧姩鐢伙紝骞剁瓑寰呭洖鍒扮ǔ瀹氬己鍖栫晫闈㈡垨绐佺牬寮曞肩晫闈
	UpdateRunnerStatus "RUNNING", "璺宠繃寮哄寲鍔ㄧ敾涓 (绗 " & CurrentBattleCount & "/" & EXTRA_ACTION_COUNT & " 娆)..."
	SkipHeroEnhanceAnim()
	Delay 300
End Function

Function DoFriendPool()
	' 0) 前置安全检测：是否已处于仓库上限弹窗
	If CheckImg2(POOLFRIEND_LIMIT_TAR) <> null Then
		TracePrint "【友情池】检测到「灵基」按钮，仓库已达上限，停止召唤！"
		HasTicket = false
		ABORT_REASON = "Extra [友情点召唤] 停止：仓库已达上限"
		UpdateRunnerStatus "IDLE", ABORT_REASON
		Exit Function
	End If

	' 1) 区分「结算界面继续召唤」与「初始界面发起召唤」
	Dim contPt = CheckImg2(POOLFRIEND_CONTINUE_TAR)
	If contPt <> null Then
		TracePrint "【友情池】结算界面点击继续召唤 ->", contPt[1], contPt[2]
		tap contPt[1], contPt[2]
	ElseIf CheckImg2(POOLFRIEND_ICON_TAR) <> null Then
		' 确认处于友情池初始界面，再点击右侧召唤按钮
		TracePrint "【友情池】初始界面点击右侧召唤按钮 ->", POOLFRIEND_RIGHT_COORD[1], POOLFRIEND_RIGHT_COORD[2]
		tap POOLFRIEND_RIGHT_COORD[1], POOLFRIEND_RIGHT_COORD[2]
		Delay 500
		' 如果过500ms确认弹窗和上限弹窗都没出现，说明右侧按钮可能不存在，补点中间召唤按钮
		If CheckImg2(POOLFRIEND_GO_TAR) = null And CheckImg2(POOLFRIEND_LIMIT_TAR) = null Then
			TracePrint "【友情池】500ms未检测到弹窗，点击中间召唤按钮 ->", POOLFRIEND_MID_COORD[1], POOLFRIEND_MID_COORD[2]
			tap POOLFRIEND_MID_COORD[1], POOLFRIEND_MID_COORD[2]
			Delay 500
		End If
	Else
		' 既不在结算界面，也不在友情池初始界面 -> 立即停止，严禁盲点其他池子！
		TracePrint "【友情池】未检测到友情池结算或初始界面，停止执行！"
		HasTicket = false
		ABORT_REASON = "Extra [友情点召唤] 停止：未处于友情池界面"
		UpdateRunnerStatus "IDLE", ABORT_REASON
		Exit Function
	End If

	' 2) 等待并处理弹窗（确认召唤「决定」 OR 仓库上限「灵基保管室」）
	Dim modalWait = 0
	Dim modalHandled = false
	Do While modalWait < 30
		If USER_STOP_REQUESTED Or CheckStopSignal() Then
			Exit Function
		End If
		If CheckImg2(POOLFRIEND_LIMIT_TAR) <> null Then
			TracePrint "【友情池】检测到「灵基」按钮，仓库已达上限，停止召唤！"
			HasTicket = false
			ABORT_REASON = "Extra [友情点召唤] 停止：仓库已达上限"
			UpdateRunnerStatus "IDLE", ABORT_REASON
			Exit Function
		End If
		Dim goPt = CheckImg2(POOLFRIEND_GO_TAR)
		If goPt <> null Then
			TracePrint "【友情池】检测到确认弹窗「决定」，点击 ->", goPt[1], goPt[2]
			tap goPt[1], goPt[2]
			modalHandled = true
			Exit Do
		End If
		Delay 300
		modalWait = modalWait + 1
	Loop

	If Not modalHandled Then
		TracePrint "【友情池】等待召唤确认弹窗超时（可能友情点不足或未处于召唤界面），停止"
		HasTicket = false
		ABORT_REASON = "Extra [友情点召唤] 停止：未检测到召唤弹窗"
		UpdateRunnerStatus "IDLE", ABORT_REASON
		Exit Function
	End If

	' 3) 跳过召唤过场动画，直到回到结算界面出现「继续召唤」
	Delay 800
	CheckNoImgAndTap2(POOLFRIEND_CONTINUE_TAR, POOLFRIEND_CONTINUE_TAR)
End Function

Function DoEquipEnhance()
	Dim refundSeen = false
	Dim refundCloseEntry = CheckImg2(ENHANCE_HERO_REFUND_CLOSE_TAR)
	If refundCloseEntry <> null Then
		TracePrint "礼装强化入口容错: 检测到素材返还弹窗，点击「关闭」按钮 ->", refundCloseEntry[1], refundCloseEntry[2]
		tap refundCloseEntry[1] + 35, refundCloseEntry[2] + 18
		Delay 800
		refundSeen = true
	End If

	If Not refundSeen Then
		Dim enhanceCoord = null
		Dim checkRetry = 0
		Do While checkRetry < 6
			If USER_STOP_REQUESTED Or CheckStopSignal() Then
				Exit Function
			End If
			If CheckImg2(ENHANCE_EQUIP_ENHANCE_GRAY_TAR) <> null Then
				TracePrint "礼装强化: 检测到「强化」按钮已变灰 (素材不足/未选择或已满级)，停止强化"
				ABORT_REASON = "礼装强化已停止: 强化按钮已变灰 (素材不足/未选择或已满级)"
				HasTicket = false
				Exit Function
			End If
			enhanceCoord = CheckImg2(ENHANCE_EQUIP_ENHANCE_TAR)
			If enhanceCoord <> null Then
				Exit Do
			End If
			Delay 300
			checkRetry = checkRetry + 1
		Loop

		If enhanceCoord = null Then
			TracePrint "礼装强化: 未检测到可点击的「强化」按钮，安全停止"
			ABORT_REASON = "礼装强化已停止: 未检测到可点击的强化按钮"
			HasTicket = false
			Exit Function
		End If

		If EXTRA_DRY_RUN = 1 Then
			TracePrint "[DRY-RUN 仿真安全模式] 拦截点击礼装「强化」按钮 ->", enhanceCoord[1], enhanceCoord[2]
			UpdateRunnerStatus "IDLE", "仿真模式：已拦截点击礼装强化"
			HasTicket = false
			Exit Function
		End If

		tap enhanceCoord[1], enhanceCoord[2]
		Delay 500
		CheckAndTapImg2(ENHANCE_EQUIP_ENHANCE_CONFIRM_TAR, null)
		Delay 500
	End If

	Dim waitRetry = 0
	Do While true
		If USER_STOP_REQUESTED Or CheckStopSignal() Then
			Exit Function
		End If
		Dim refundCloseCoord = CheckImg2(ENHANCE_HERO_REFUND_CLOSE_TAR)
		If refundCloseCoord <> null Then
			TracePrint "礼装强化: 动画中检测到素材返还弹窗，点击「关闭」按钮 ->", refundCloseCoord[1], refundCloseCoord[2]
			tap refundCloseCoord[1] + 35, refundCloseCoord[2] + 18
			Delay 800
			refundSeen = true
		End If
		If CheckImg2(ENHANCE_EQUIP_ENHANCE_GRAY_TAR) <> null Then
			TracePrint "礼装强化: 动画结束后检测到「强化」按钮已变灰 (素材不足或已满级)，停止强化"
			ABORT_REASON = "礼装强化已停止: 强化按钮已变灰 (素材不足/未选择或已满级)"
			HasTicket = false
			Exit Function
		End If
		If CheckImg2(ENHANCE_EQUIP_ENHANCE_TAR) <> null Then
			Exit Do
		End If
		If refundSeen And CheckImg2(ENHANCE_EQUIP_TAR) <> null Then
			TracePrint "礼装强化: 素材返还弹窗关闭并已返回礼装强化界面 (已满级)，停止强化"
			ABORT_REASON = "礼装强化已停止: 礼装已满级 (已关闭素材返还弹窗)"
			HasTicket = false
			Exit Function
		End If
		tap ENHANCE_EQUIP_ENHANCE_CONFIRM_TAR[1], ENHANCE_EQUIP_ENHANCE_CONFIRM_TAR[2]
		Delay 300
		waitRetry = waitRetry + 1
		If waitRetry Mod 10 = 0 Then
			UpdateRunnerStatus "RUNNING", "Extra [" & CURRENT_EXTRA_ACTION_NAME & "] 等待动画(" & Int(waitRetry * 0.3) & "s)..."
		End If
		If waitRetry >= AWARD_NEXT_MAX_RETRY Then
			TracePrint "礼装强化: 等待返回强化界面超时"
			HasTicket = false
			Exit Function
		End If
	Loop
End Function

' 检测右下角「强化」按钮是否可见（兼容按钮表面周期性白色流光导致的容差波动）
Function IsSkillEnhanceBtnVisible()
	IsSkillEnhanceBtnVisible = false
	If CheckImg2(ENHANCE_SKILL_ENHANCE_TAR) <> null Then
		IsSkillEnhanceBtnVisible = true
		Exit Function
	End If
	If CheckPriorityImgEx(ENHANCE_SKILL_ENHANCE_TAR, 0.80, "303030") <> null Then
		IsSkillEnhanceBtnVisible = true
	End If
End Function

' 立即连点跳过技能/追加技能强化动画，并在回到强化界面时立即停手
Function SkipSkillEnhanceAnim()
	SkipSkillEnhanceAnim = false
	UpdateRunnerStatus "RUNNING", "技能强化: 连点加速动画中..."

	' 阶段1：点击决定后立即高频连点（120ms/次 × 8 ≈ 1s），确保第一时间进入加速
	Dim burstTap
	For burstTap = 1 To 8
		If USER_STOP_REQUESTED Or CheckStopSignal() Then
			Exit Function
		End If
		tap ENHANCE_SKILL_CLICK_COORD[1], ENHANCE_SKILL_CLICK_COORD[2]
		Delay 120
	Next

	' 阶段2：每轮检查是否已回到强化界面（必须连续2次间隔>=350ms检测到，防止动画间隙闪帧误判；同时覆盖可点/置灰两种强化按钮状态）
	Dim animRound = 0
	Dim readyHitCount = 0
	Do While animRound < 30
		If USER_STOP_REQUESTED Or CheckStopSignal() Then
			Exit Function
		End If

		Dim hitType = 0
		If IsSkillEnhanceBtnVisible() Then
			hitType = 1
		ElseIf CheckImg2(ENHANCE_EQUIP_ENHANCE_GRAY_TAR) <> null Then
			hitType = 2
		ElseIf CheckImg2(ENHANCE_SKILL_MAX_L10_TAR) <> null Then
			hitType = 3
		ElseIf CheckImg2(ENHANCE_SKILL_HERO_UNSELECTED_TAR) <> null Then
			hitType = 4
		End If

		If hitType > 0 Then
			readyHitCount = readyHitCount + 1
			If readyHitCount >= 2 Then
				If hitType = 4 Then
					TracePrint "技能强化动画结束(2次确认): 从者已自动取消选中 (全部满级)"
					HasTicket = false
					Exit Function
				ElseIf hitType = 3 Then
					TracePrint "技能强化动画结束(2次确认): 当前技能已达10级满级"
				ElseIf hitType = 2 Then
					TracePrint "技能强化动画结束(2次确认): 强化按钮已置灰 (不可点击)"
				Else
					TracePrint "技能强化动画结束(2次确认): 强化按钮已恢复可点击状态"
				End If
				SkipSkillEnhanceAnim = true
				Exit Function
			End If
			' 第1次检测到：可能是动画间隙闪帧，暂停350ms后进行第2次确认（期间不点击）
			Delay 350
		Else
			readyHitCount = 0
			Dim subTap
			For subTap = 1 To 4
				If USER_STOP_REQUESTED Or CheckStopSignal() Then
					Exit Function
				End If
				tap ENHANCE_SKILL_CLICK_COORD[1], ENHANCE_SKILL_CLICK_COORD[2]
				Delay 120
			Next
			animRound = animRound + 1
		End If
	Loop
End Function

Function DoSkillEnhance(MaxLevel)
	Dim autoThree = EXTRA_SKILL_AUTO_THREE
	If autoThree = 1 Then
		' 检测是否为追加技能强化 (右上角带「追加」两字)
		If CheckImg2(ENHANCE_SKILL_APPEND_TAR) <> null Then
			TracePrint "【追加技能强化】检测到右上角「追加」标识，当前处于追加技能强化界面(5技能)。因从者币及强化材料极其珍贵，禁止自动强化全部技能，默认仅强化当前选中的技能(等同于未勾选强化全部技能)！"
			autoThree = 0
		End If
	End If

	If autoThree = 1 Then
		' --- 3鎶鑳介『搴忚繛缁寮哄寲 ---
		TracePrint "=== 鍚鍔3鎶鑳介『搴忓己鍖栨祦绋 (鐩鏍囦笂闄: Lv" & MaxLevel & ") ==="

		' 0) 棣栨: 妫鏌ュ乏渚ф槸鍚︽湭閫変腑浠庤 (鑻ユ湭閫変腑锛岃存槑浠庤3鎶鑳藉凡鍏ㄩ儴婊＄骇鎴栨湭閫夋嫨浠庤)
		If CheckImg2(ENHANCE_SKILL_HERO_UNSELECTED_TAR) <> null Then
			TracePrint "妫娴嬪埌宸︿晶鏈閫変腑浠庤 (浠庤3涓鎶鑳藉凡鍏ㄩ儴寮哄寲婊＄骇)锛屽己鍖栨祦绋嬬洿鎺ョ粨鏉"
			HasTicket = false
			Exit Function
		End If

		' 澶嶄綅: 棣栧厛鐐瑰嚮鍒囨崲鍒版妧鑳1
		TracePrint "澶嶄綅: 鍒囨崲鍒版妧鑳1 ->", TAP_ENHANCE_SKILL_1[1], TAP_ENHANCE_SKILL_1[2]
		tap TAP_ENHANCE_SKILL_1[1], TAP_ENHANCE_SKILL_1[2]
		Delay 800

		Dim k
		For k = 1 To 3
			If USER_STOP_REQUESTED Or CheckStopSignal() Then
				Exit Function
			End If

			' 妫鏌ヤ粠鑰呮槸鍚﹀勪簬鏈閫変腑鐘舵 (3涓鎶鑳藉叏閮ㄦ弧绾у悗鑷鍔ㄥ彇娑堥変腑)
			If CheckImg2(ENHANCE_SKILL_HERO_UNSELECTED_TAR) <> null Then
				TracePrint "妫娴嬪埌宸︿晶浠庤呭凡鍙栨秷閫変腑 (3涓鎶鑳藉凡鍏ㄩ儴寮哄寲婊＄骇)锛屽己鍖栨祦绋嬪叏閮ㄥ畬鎴"
				HasTicket = false
				Exit Function
			End If

			If k > 1 Then
				If k = 2 Then
					TracePrint ">>> 鍒囨崲鑷虫妧鑳 2 ->", TAP_ENHANCE_SKILL_2[1], TAP_ENHANCE_SKILL_2[2]
					tap TAP_ENHANCE_SKILL_2[1], TAP_ENHANCE_SKILL_2[2]
				ElseIf k = 3 Then
					TracePrint ">>> 鍒囨崲鑷虫妧鑳 3 ->", TAP_ENHANCE_SKILL_3[1], TAP_ENHANCE_SKILL_3[2]
					tap TAP_ENHANCE_SKILL_3[1], TAP_ENHANCE_SKILL_3[2]
				End If
				Delay 800
			End If

			Dim skillFinished = false
			Do While skillFinished = false
				If USER_STOP_REQUESTED Or CheckStopSignal() Then
					Exit Function
				End If

				' 寰鐜妫娴嬬晫闈㈠氨缁鐘舵侊紙鏈澶氱瓑寰 3 绉掞級锛岄伩鍏嶅姩鐢绘湭鏀跺熬鎴栫綉缁滃姞杞芥椂璇鍒よ烦杩
				Dim waitUi = 0
				Dim canEnhance = false
				Dim isMaxL10 = false
				Dim isLoreTarget = false

				Do While waitUi < 15
					If USER_STOP_REQUESTED Or CheckStopSignal() Then
						Exit Function
					End If

					' 0) 容错检查：若残留临时从者提示弹窗，点击「决定」
					Dim tempCoordPre = CheckImg2(ENHANCE_HERO_TEMP_CONFIRM_TAR)
					If tempCoordPre <> null Then
						TracePrint "技能强化: 容错检测到残留临时从者提示弹窗，点击「决定」按钮 ->", tempCoordPre[1], tempCoordPre[2]
						If TAP_ENHANCE_HERO_TEMP_CONFIRM <> null Then
							tap TAP_ENHANCE_HERO_TEMP_CONFIRM[1], TAP_ENHANCE_HERO_TEMP_CONFIRM[2]
						Else
							tap tempCoordPre[1] + 43, tempCoordPre[2] + 19
						End If
						Delay 600
					End If

					' 0.5) 满级取消选中判断: 检查从者是否已自动取消选中 (全部技能满级)
					If CheckImg2(ENHANCE_SKILL_HERO_UNSELECTED_TAR) <> null Then
						TracePrint "技能 " & k & " 检测到从者已取消选中 (所有技能均已达10级满级)，强化全部完成"
						HasTicket = false
						Exit Function
					End If

					' 1) 满级判断: 检查右下角是否显示「无法继续强化」
					If CheckImg2(ENHANCE_SKILL_MAX_L10_TAR) <> null Then
						isMaxL10 = true
						Exit Do
					End If

					' 2) 目标等级判断: 若目标不是10级(如Lv9)，检查素材栏是否出现传承结晶
					If MaxLevel <> 10 Then
						If CheckImg2(ENHANCE_SKILL_ENHANCE_L10_TAR) <> null Then
							isLoreTarget = true
							Exit Do
						End If
					End If

					' 3) 检查「强化」按钮
					If IsSkillEnhanceBtnVisible() Then
						canEnhance = true
						Exit Do
					End If

					Delay 200
					waitUi = waitUi + 1
				Loop

				If isMaxL10 Then
					TracePrint "技能 " & k & " 检测到「无法继续强化」(10级满级)，该技能强化完毕"
					skillFinished = true
					Exit Do
				End If

				If isLoreTarget Then
					TracePrint "技能 " & k & " 检测到传承结晶(已达设定目标 Lv" & MaxLevel & ")，该技能强化完毕"
					skillFinished = true
					Exit Do
				End If

				If Not canEnhance Then
					' 若强化按钮未找到，再次确认是否从者已取消选中
					If CheckImg2(ENHANCE_SKILL_HERO_UNSELECTED_TAR) <> null Then
						TracePrint "从者已取消选中 (所有技能均已达10级满级)，强化全部完成"
						HasTicket = false
						Exit Function
					End If
					TracePrint "技能 " & k & " 未找到强化按钮(可能缺少素材/QP或网络加载超时)，跳过该技能"
					skillFinished = true
					Exit Do
				End If

				' 4) 执行点击「强化」按钮（若确认弹窗未打开）
				If CheckImg2(ENHANCE_SKILL_ENHANCE_CONFIRM_TAR) = null Then
					Dim enhanceCoord = CheckImg2(ENHANCE_SKILL_ENHANCE_TAR)
					If enhanceCoord <> null Then
						tap enhanceCoord[1], enhanceCoord[2]
					Else
						tap 1206, 756
					End If
					Delay 500
				End If

				' 5) 等待并点击「确认」弹窗（带超时防死锁）
				Dim confirmCoord = null
				Dim waitConfirm = 0
				Do While waitConfirm < 16
					If USER_STOP_REQUESTED Or CheckStopSignal() Then
						Exit Function
					End If

					confirmCoord = CheckImg2(ENHANCE_SKILL_ENHANCE_CONFIRM_TAR)
					If confirmCoord <> null Then
						Exit Do
					End If
					Delay 250
					waitConfirm = waitConfirm + 1
				Loop

				If confirmCoord = null Then
					TracePrint "技能 " & k & " 未能弹出或识别到强化确认框，重试当前技能状态"
					Delay 400
				Else
					tap confirmCoord[1], confirmCoord[2]
					TracePrint "已点击强化确认框，开始持续盲点跳过升级动画..."
					Dim isAnimFinished = SkipSkillEnhanceAnim()
					If Not HasTicket Or USER_STOP_REQUESTED Or CheckStopSignal() Then
						Exit Function
					End If

					If Not isAnimFinished Then
						' 瓒呮椂鍚庢渶鍚庣‘璁や竴娆℃槸鍚︽湭閫変腑浠庤
						If CheckImg2(ENHANCE_SKILL_HERO_UNSELECTED_TAR) <> null Then
							TracePrint "鍗囩骇鍔ㄧ敾鍚庢娴嬪埌浠庤呭凡鑷鍔ㄥ彇娑堥変腑锛屽己鍖栧叏閮ㄥ畬鎴"
							HasTicket = false
							Exit Function
						End If
						TracePrint "璀﹀憡: 璺宠繃鍗囩骇鍔ㄧ敾绛夊緟瓒呮椂锛屽皾璇曠户缁鍚庣画娴佺▼"
					End If

					CurrentBattleCount = CurrentBattleCount + 1
					UpdateRunnerStatus "RUNNING", "鎶鑳藉己鍖 [鎶鑳" & k & "] 绗 " & CurrentBattleCount & "/" & EXTRA_ACTION_COUNT & " 娆"
					TracePrint "鎶鑳藉己鍖栬繘搴: 鎶鑳 " & k & " 寮哄寲鎴愬姛锛岀疮璁″畬鎴 " & CurrentBattleCount & " 娆"

					If CurrentBattleCount >= EXTRA_ACTION_COUNT Then
						TracePrint "宸茶揪鍒 Extra 鎵ц屾℃暟涓婇檺: " & EXTRA_ACTION_COUNT
						HasTicket = false
						Exit Function
					End If

					Delay 600
				End If
			Loop
		Next

		TracePrint "=== 3涓鎶鑳介『搴忓己鍖栧叏閮ㄥ畬鎴 ==="
		HasTicket = false
	Else
		' --- 单技能强化 (原逻辑兼容器 / 追加技能强化) ---
		If CheckImg2(ENHANCE_SKILL_HERO_UNSELECTED_TAR) <> null Then
			TracePrint "检测到左侧未选中从者，单技能强化结束"
			HasTicket = false
			Exit Function
		End If
		If CheckImg2(ENHANCE_SKILL_MAX_L10_TAR) <> null Then
			HasTicket = false
			TracePrint "ENHANCE_SKILL_MAX_L10_STOP: 当前技能已达10级满级"
			Exit Function
		End If
		If MaxLevel <> 10 Then
			Dim CheckSkillEnhance10TarSuccess = CheckImg2(ENHANCE_SKILL_ENHANCE_L10_TAR)
			If CheckSkillEnhance10TarSuccess <> null Then
				HasTicket = false
				TracePrint "ENHANCE_SKILL_10_STOP: 当前技能已达设定等级 Lv" & MaxLevel
				Exit Function
			End If
		End If
		If Not IsSkillEnhanceBtnVisible() Then
			ContinuousCheckImg(ENHANCE_SKILL_ENHANCE_TAR)
		End If
		' 容错检查：若残留临时从者提示弹窗，优先点击「决定」
		Dim singleTempPre = CheckImg2(ENHANCE_HERO_TEMP_CONFIRM_TAR)
		If singleTempPre <> null Then
			TracePrint "技能强化(单技能): 容错检测到临时从者提示弹窗，点击「决定」按钮 ->", singleTempPre[1], singleTempPre[2]
			If TAP_ENHANCE_HERO_TEMP_CONFIRM <> null Then
				tap TAP_ENHANCE_HERO_TEMP_CONFIRM[1], TAP_ENHANCE_HERO_TEMP_CONFIRM[2]
			Else
				tap singleTempPre[1] + 43, singleTempPre[2] + 19
			End If
			Delay 600
		End If

		If CheckImg2(ENHANCE_SKILL_ENHANCE_CONFIRM_TAR) = null Then
			Dim singleEnhanceCoord = CheckImg2(ENHANCE_SKILL_ENHANCE_TAR)
			If singleEnhanceCoord <> null Then
				tap singleEnhanceCoord[1], singleEnhanceCoord[2]
			Else
				tap 1206, 756
			End If
			Delay 500
		End If

		' 等待并点击「确认」弹窗
		Dim singleConfirmCoord = null
		Dim singleWait = 0
		Do While singleWait < 16
			If USER_STOP_REQUESTED Or CheckStopSignal() Then
				Exit Function
			End If

			singleConfirmCoord = CheckImg2(ENHANCE_SKILL_ENHANCE_CONFIRM_TAR)
			If singleConfirmCoord <> null Then
				Exit Do
			End If
			Delay 250
			singleWait = singleWait + 1
		Loop

		If singleConfirmCoord <> null Then
			tap singleConfirmCoord[1], singleConfirmCoord[2]
		Else
			TracePrint "技能强化(单技能): 未能弹出或识别到强化确认框，重试"
			Exit Function
		End If
		Dim singleAnimOk = SkipSkillEnhanceAnim()
		If Not HasTicket Or USER_STOP_REQUESTED Or CheckStopSignal() Then
			Exit Function
		End If
		If CheckImg2(ENHANCE_EQUIP_ENHANCE_GRAY_TAR) <> null Then
			TracePrint "技能强化(单技能): 检测到强化按钮已置灰 (素材或QP不足)，安全停止"
			ABORT_REASON = "技能强化已停止: 强化按钮已置灰 (素材或QP不足)"
			HasTicket = false
			Exit Function
		End If
	End If
End Function

Sub DoSelectedExtraActionWithIndex(detectedIndex)
	If detectedIndex = 1 Then
		DoEnhance()
	ElseIf detectedIndex = 2 Then
		DoEquipEnhance()
	ElseIf detectedIndex = 3 Then
		DoSkillEnhance(EXTRA_SKILL_MAX_LEVEL)
	ElseIf detectedIndex = 4 Then
		DoFriendPool()
	ElseIf detectedIndex = 5 Then
		DoRoll()
	Else
		TracePrint "INVALID EXTRA DETECTED INDEX:", detectedIndex
		HasTicket = false
	End If
End Sub

Sub StartExtraLoop()
	RUN_MODE = 1
	TracePrint "=== STARTING EXTRA BATCH ==="
	CurrentBattleCount = 0
	HasTicket = true
	USER_STOP_REQUESTED = false
	ABORT_REASON = ""
	CURRENT_SUB_ROUND_NUM = 0
	TOTAL_SUB_ROUND_NUM = 0
	UpdateRunnerStatus "RUNNING", "Extra 辅助启动中..."

	Dim detectedIndex = DetectExtraMethodIndex()
	If detectedIndex = 0 Then
		TracePrint "AUTO DETECT FAILED: NO MATCHED SCENE"
		HasTicket = false
		ABORT_REASON = "未检测到对应 Extra 场景(从者/礼装/技能强化或友情池/无限池)"
		UpdateRunnerStatus "IDLE", ABORT_REASON
		Exit Sub
	End If

	Dim actionName = GetExtraMethodActionName(detectedIndex)
	CURRENT_EXTRA_ACTION_NAME = actionName
	TracePrint "AUTO DETECT EXTRA_METHOD_INDEX:", detectedIndex, "ACTION=", actionName

	Do While true
		If USER_STOP_REQUESTED Or CheckStopSignal() Then
			TracePrint "Extra batch interrupted before action"
			Exit Do
		End If

		CurrentBattleCount = CurrentBattleCount + 1
		UpdateRunnerStatus "RUNNING", "Extra [" & actionName & "] 第 " & CurrentBattleCount & "/" & EXTRA_ACTION_COUNT & " 次"

		DoSelectedExtraActionWithIndex(detectedIndex)

		If USER_STOP_REQUESTED Or CheckStopSignal() Then
			TracePrint "Extra batch interrupted after action " & CurrentBattleCount
			Exit Do
		End If

		TracePrint "ExtraAction Current =", CurrentBattleCount, "Max = ", EXTRA_ACTION_COUNT, "HasTicket = ", HasTicket
		If CurrentBattleCount >= EXTRA_ACTION_COUNT Or HasTicket = false Then
			TracePrint "EXTRAS COMPLETED OR TICKET DEPLETED"
			Exit Do
		End If
		Delay 300
	Loop

	If Len(ABORT_REASON) > 0 Then
		UpdateRunnerStatus "IDLE", ABORT_REASON
	ElseIf USER_STOP_REQUESTED Then
		UpdateRunnerStatus "IDLE", "Extra已停止 (已完成 " & CurrentBattleCount & " 次)"
	ElseIf Not HasTicket Then
		UpdateRunnerStatus "IDLE", "Extra已结束: 材料/票券耗尽或已满级"
	Else
		UpdateRunnerStatus "IDLE", "Extra任务全部完成 (" & EXTRA_ACTION_COUNT & " 次)"
	End If
End Sub

Sub StartBattleLoop()
	RUN_MODE = 0
	TracePrint "=== STARTING BATTLE BATCH ==="
	CurrentBattleCount = 0
	HasTicket = true
	USER_STOP_REQUESTED = false
	ABORT_REASON = ""
	UpdateRunnerStatus "RUNNING", "鎴樻枟鍚鍔ㄤ腑"

	Do While true
		If USER_STOP_REQUESTED Or CheckStopSignal() Then
			TracePrint "Battle batch interrupted before round"
			Exit Do
		End If

		CurrentBattleCount = CurrentBattleCount + 1
		UpdateRunnerStatus "RUNNING", "绗 " & CurrentBattleCount & "/" & BATTLE_COUNT & " 鍦鸿繘琛屼腑"

		DoBattle()

		If USER_STOP_REQUESTED Or CheckStopSignal() Then
			TracePrint "Battle batch interrupted after round " & CurrentBattleCount
			Exit Do
		End If

		TracePrint "BattleCount Current =", CurrentBattleCount, "Max = ", BATTLE_COUNT, "HasTicket = ", HasTicket
		If CurrentBattleCount >= BATTLE_COUNT Or HasTicket = false Then
			TracePrint "END OF BATCH"
			Exit Do
		End If
	Loop

	If Len(ABORT_REASON) > 0 Then
		UpdateRunnerStatus "IDLE", ABORT_REASON
	ElseIf USER_STOP_REQUESTED Then
		UpdateRunnerStatus "IDLE", "宸插仠姝 (宸插畬鎴 " & CurrentBattleCount & " 鍦)"
	ElseIf Not HasTicket Then
		UpdateRunnerStatus "IDLE", "绁ㄥ埜鎴栦綋鍔涜楀敖宸茬粨鏉"
	Else
		UpdateRunnerStatus "IDLE", "鎴樻枟璁″垝宸插叏閮ㄥ畬鎴 (" & BATTLE_COUNT & " 鍦)"
	End If
End Sub

Sub MainStandbyLoop()
	TracePrint "========================================"
	TracePrint "FGO_Q BATTLE V4 RUNNER - STANDBY MODE"
	TracePrint "STANDBY READY. WAITING FOR WEB COMMAND..."
	TracePrint "========================================"

	' 鍚鍔ㄦ椂娓呯悊鍘嗗彶鎸囦护娈嬬暀
	Dim cmdPath = "/sdcard/FGO_Q/cmd.txt"
	zm.FileWrite cmdPath, ""

	UpdateRunnerStatus "IDLE", "寰呭懡涓 (绛夊緟缃戦〉涓嬪彂杩愯屾寚浠)"

	Dim loopCounter = 0
	Do While true
		loopCounter = loopCounter + 1

		' 绾︽瘡 1 绉掑埛鏂颁竴娆″績璺 (500ms * 2 = 1s)
		If loopCounter Mod 2 = 0 Then
			If Len(ABORT_REASON) > 0 Then
				UpdateRunnerStatus "IDLE", ABORT_REASON
			Else
				UpdateRunnerStatus "IDLE", "寰呭懡涓 (灏辩华)"
			End If
		End If

		If Dir.Exist(cmdPath) = 1 Then
			Dim rawCmd = zm.FileRead(cmdPath)
			If Not IsNull(rawCmd) And Len(CStr(rawCmd)) > 0 Then
				Dim cmdText = UCase(Trim(CStr(rawCmd)))
				If cmdText = "START" Or cmdText = "START_BATTLE" Or cmdText = "START_EXTRA" Then
					TracePrint ">>> RECEIVED START COMMAND FROM WEB: " & cmdText & " <<<"
					zm.FileWrite cmdPath, ""
					ABORT_REASON = ""
					USER_STOP_REQUESTED = false
					UpdateRunnerStatus "RUNNING", "任务准备中..."

					If cmdText = "START_EXTRA" Then
						RUN_MODE = 1
					ElseIf cmdText = "START_BATTLE" Then
						RUN_MODE = 0
					Else
						RUN_MODE = -1
					End If
					ReloadConfig()

					Dim targetRunMode = RUN_MODE
					If cmdText = "START_BATTLE" Then
						targetRunMode = 0
						RUN_MODE = 0
					ElseIf cmdText = "START_EXTRA" Then
						targetRunMode = 1
						RUN_MODE = 1
					End If

					If Not CAN_RUN Then
						TracePrint "RUNNER STOPPED: CONFIG VALIDATION FAILED"
						UpdateRunnerStatus "IDLE", "閰嶇疆鏍￠獙鏈閫氳繃锛岃锋鏌 Web 椤甸潰"
					ElseIf targetRunMode = 1 Then
						TracePrint ">>> DISPATCH TO EXTRA LOOP <<<"
						StartExtraLoop()
					Else
						TracePrint ">>> DISPATCH TO BATTLE LOOP <<<"
						StartBattleLoop()
					End If

					If Len(ABORT_REASON) > 0 Then
						UpdateRunnerStatus "IDLE", ABORT_REASON
					Else
						UpdateRunnerStatus "IDLE", "寰呭懡涓 (绛夊緟涓嬩竴缁勬寚浠)"
					End If
				ElseIf cmdText = "STOP" Then
					zm.FileWrite cmdPath, ""
					USER_STOP_REQUESTED = false
					ABORT_REASON = ""
					UpdateRunnerStatus "IDLE", "宸插勪簬寰呭懡鐘舵"
				End If
			End If
		End If

		Delay 500
	Loop
End Sub

// START ENTRY POINT
Traceprint "START FROM", DateTime.Format()
MainStandbyLoop()
Log.Close
