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
Dim MANUAL_FORCE_COLOR_CARD = 0

' --- Extra 辅助功能与全局运行模式 ---
Dim RUN_MODE = 0  ' 0=战术战斗(Battle), 1=Extra辅助(Extra)
Dim EXTRA_ENABLE = 0  ' 兼容旧版开关字段
Dim EXTRA_ACTION_COUNT = 30  ' Extra 连续执行次数上限
Dim EXTRA_SKILL_MAX_LEVEL = 9  ' 技能强化目标上限 (1~10)
Dim EXTRA_SKILL_AUTO_THREE = 1  ' 技能强化是否顺序强化3个技能 (0=关, 1=开)
Dim EXTRA_HERO_AUTO_ASCEND = 1  ' 从者强化是否自动灵基再临 (0=关, 1=开)
Dim EXTRA_HERO_AUTO_GRAIL = 0   ' 从者强化是否自动圣杯转临 (0=关, 1=开)

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
Dim APPLE_ENABLE = 0
Dim FORCE_COLOR_CARD = 0
Dim ACTIVITY_REWARD = 1
Dim CAN_RUN = false

Dim selectedDsl = ""
Dim selectedActivityDsl = ""
Dim selectedFriendKey = ""

Dim CurrentBattleSequence = Array()
Dim AllActionRound = Array()
Dim PREPARE_FRIEND_TAR = Array()
Dim HAS_FRIEND_CONFIG = false

Dim USER_STOP_REQUESTED = false
Dim ABORT_REASON = ""
Dim CURRENT_SUB_ROUND_NUM = 0
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
				
				If LCase(valStr) = "b" Then
					actGroup[actIndex + 1] = "B"
				ElseIf LCase(valStr) = "a" Then
					actGroup[actIndex + 1] = "A"
				ElseIf LCase(valStr) = "q" Then
					actGroup[actIndex + 1] = "Q"
				ElseIf IsNumeric(valStr) Then
					actGroup[actIndex + 1] = CInt(valStr)
				Else
					actGroup[actIndex + 1] = valStr
				End If
				
				actIndex = actIndex + 1
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
	' 降低文件轮询：每 4 次调用才真实读一次 cmd.txt（约 2s 间隔），减少 IO 负担
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
				ABORT_REASON = "收到网页停止指令"
				zm.FileWrite cmdPath, ""
				UpdateRunnerStatus "STOPPING", "收到网页停止指令"
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

' 閰嶇疆鐑閲嶈浇鍑芥暟锛氭瘡娆℃敹鍒 START 鎸囦护鏃堕噸鏂板姞杞芥渶鏂伴厤缃
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
	APPLE_GLODEN_COORD = ParseCoord(CfgGet("tap_apple_golden", CfgGet("apple_gloden_coord", "")), APPLE_GLODEN_COORD)
	APPLE_SILVER_COORD = ParseCoord(CfgGet("tap_apple_silver", CfgGet("apple_silver_coord", "")), APPLE_SILVER_COORD)
	APPLE_CLOSE_COORD = ParseCoord(CfgGet("tap_apple_close", CfgGet("apple_close_coord", "")), APPLE_CLOSE_COORD)
	APPLE_CHECK_AWAIT_MS = Int(CfgGet("apple_check_await_ms", CStr(APPLE_CHECK_AWAIT_MS)))

	' 13. FRIEND PREPARE
	PREPARE_FRIEND_EQUIP_TAR = ParseTarget(CfgGet("prepare_friend_equip_tar", CfgGet("friend_equip_goodness", "")), PREPARE_FRIEND_EQUIP_TAR)
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
	ENHANCE_HERO_REFUND_CLOSE_TAR = ParseTarget(CfgGet("enhance_hero_refund_close_tar", ""), ENHANCE_HERO_REFUND_CLOSE_TAR)
	TAP_ENHANCE_HERO_REFUND_CLOSE = ParseCoord(CfgGet("tap_enhance_hero_refund_close", ""), TAP_ENHANCE_HERO_REFUND_CLOSE)
	ENHANCE_HERO_TO_ASCEND_TAR = ParseTarget(CfgGet("enhance_hero_to_ascend_tar", ""), ENHANCE_HERO_TO_ASCEND_TAR)
	ENHANCE_HERO_TO_GRAIL_TAR = ParseTarget(CfgGet("enhance_hero_to_grail_tar", ""), ENHANCE_HERO_TO_GRAIL_TAR)
	ENHANCE_ASCEND_TAR = ParseTarget(CfgGet("enhance_ascend_tar", ""), ENHANCE_ASCEND_TAR)
	ENHANCE_GRAIL_TAR = ParseTarget(CfgGet("enhance_grail_tar", ""), ENHANCE_GRAIL_TAR)
	ENHANCE_GRAIL_CONFIRM_TAR = ParseTarget(CfgGet("enhance_grail_confirm_tar", ""), ENHANCE_GRAIL_CONFIRM_TAR)
	TAP_ENHANCE_GRAIL_CONFIRM = ParseCoord(CfgGet("tap_enhance_grail_confirm", ""), TAP_ENHANCE_GRAIL_CONFIRM)
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
	POOLFRIEND_CONTINUE_TAR = ParseTarget(CfgGet("poolfriend_continue_tar", ""), POOLFRIEND_CONTINUE_TAR)
	POOLFRIEND_GO_TAR = ParseTarget(CfgGet("poolfriend_go_tar", ""), POOLFRIEND_GO_TAR)
	ENHANCE_EQUIP_TAR = ParseTarget(CfgGet("enhance_equip_tar", ""), ENHANCE_EQUIP_TAR)
	ENHANCE_EQUIP_ENHANCE_TAR = ParseTarget(CfgGet("enhance_equip_enhance_tar", ""), ENHANCE_EQUIP_ENHANCE_TAR)
	ENHANCE_EQUIP_ENHANCE_CONFIRM_TAR = ParseTarget(CfgGet("enhance_equip_enhance_confirm_tar", ""), ENHANCE_EQUIP_ENHANCE_CONFIRM_TAR)
	ENHANCE_SKILL_TAR = ParseTarget(CfgGet("enhance_skill_tar", ""), ENHANCE_SKILL_TAR)
	ENHANCE_SKILL_ENHANCE_TAR = ParseTarget(CfgGet("enhance_skill_enhance_tar", ""), ENHANCE_SKILL_ENHANCE_TAR)
	ENHANCE_SKILL_ENHANCE_CONFIRM_TAR = ParseTarget(CfgGet("enhance_skill_enhance_confirm_tar", ""), ENHANCE_SKILL_ENHANCE_CONFIRM_TAR)
	ENHANCE_SKILL_ENHANCE_L10_TAR = ParseTarget(CfgGet("enhance_skill_enhance_l10_tar", ""), ENHANCE_SKILL_ENHANCE_L10_TAR)
	ENHANCE_SKILL_CLICK_COORD = ParseCoord(CfgGet("enhance_skill_click_coord", ""), ENHANCE_SKILL_CLICK_COORD)
	ENHANCE_SKILL_MAX_L10_TAR = ParseTarget(CfgGet("enhance_skill_max_l10_tar", ""), ENHANCE_SKILL_MAX_L10_TAR)
	TAP_ENHANCE_SKILL_1 = ParseCoord(CfgGet("tap_enhance_skill_1", ""), TAP_ENHANCE_SKILL_1)
	TAP_ENHANCE_SKILL_2 = ParseCoord(CfgGet("tap_enhance_skill_2", ""), TAP_ENHANCE_SKILL_2)
	TAP_ENHANCE_SKILL_3 = ParseCoord(CfgGet("tap_enhance_skill_3", ""), TAP_ENHANCE_SKILL_3)
	ENHANCE_SKILL_HERO_UNSELECTED_TAR = ParseTarget(CfgGet("enhance_skill_hero_unselected_tar", ""), ENHANCE_SKILL_HERO_UNSELECTED_TAR)
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

	' 浼樺厛妫鏌 FGO_Q 鐩存帹鐩褰曚腑鐨勬渶鏂伴厤缃
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

	RUN_MODE = Int(CfgGet("run_mode", CfgGet("extra_enable", "0")))
	EXTRA_ENABLE = RUN_MODE
	EXTRA_ACTION_COUNT = Int(CfgGet("extra_action_count", "30"))
	EXTRA_SKILL_MAX_LEVEL = Int(CfgGet("extra_skill_max_level", "9"))
	EXTRA_SKILL_AUTO_THREE = Int(CfgGet("extra_skill_auto_three", "1"))
	EXTRA_HERO_AUTO_ASCEND = Int(CfgGet("extra_hero_auto_ascend", "1"))
	EXTRA_HERO_AUTO_GRAIL = Int(CfgGet("extra_hero_auto_grail", "0"))
	CFG_ACTION_GROUP_INDEX = Int(CfgGet("action_group_index", CfgGet("cfg_action_group_index", "0")))
	MANUAL_BATTLE_COUNT = Int(CfgGet("battle_count", CfgGet("manual_battle_count", "0")))
	MANUAL_APPLE_ENABLE = Int(CfgGet("apple_enable", CfgGet("manual_apple_enable", "0")))
	MANUAL_CHOOSE_FRIEND = Int(CfgGet("manual_choose_friend", CfgGet("choose_friend_manual", "0")))
	MANUAL_FORCE_COLOR_CARD = Int(CfgGet("force_color_card", CfgGet("manual_force_color_card", "0")))

	CFG_FRIEND = CStr(CfgGet("friend", ""))
	CFG_ACTION_INDEX = PickActionIndexByGroup(CFG_ACTION_GROUP_INDEX)
	CFG_ACTIVITY_REWARD = PickActivityRewardByGroupAndIndex(CFG_ACTION_GROUP_INDEX, CFG_ACTION_INDEX)

	BATTLE_COUNT = Int(MANUAL_BATTLE_COUNT)
	CHOOSE_FRIEND_MANUAL = Int(MANUAL_CHOOSE_FRIEND)
	APPLE_ENABLE = Int(MANUAL_APPLE_ENABLE)
	FORCE_COLOR_CARD = Int(MANUAL_FORCE_COLOR_CARD)
	ACTIVITY_REWARD = CFG_ACTIVITY_REWARD

	ApplyConfigTargets()

	TracePrint "CONFIG PARSED", "group=", CFG_ACTION_GROUP_INDEX, "index=", CFG_ACTION_INDEX, "battle_count=", BATTLE_COUNT, "friend=", CFG_FRIEND, "manual_choose_friend=", CHOOSE_FRIEND_MANUAL, "force_color_card=", FORCE_COLOR_CARD

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

	If RUN_MODE = 0 Then
		If Len(selectedDsl) = 0 Then
			TracePrint "CONFIG DSL EMPTY, STOP"
			CAN_RUN = false
		End If
	Else
		' Extra 辅助模式无需战术 DSL
		CAN_RUN = true
	End If

	If CAN_RUN Then
		TracePrint "SELECTED DSL HEAD:", Left(CStr(selectedDsl), 120)
		CurrentBattleSequence = BuildRoundsFromFlatText(selectedDsl)
		AllActionRound = ParseBattleSequence(CurrentBattleSequence)
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
		End If
	End If

	If RUN_MODE = 0 Then
		If Not HAS_FRIEND_CONFIG And CHOOSE_FRIEND_MANUAL <= 0 Then
			TracePrint "FRIEND CONFIG INVALID OR EMPTY, STOP"
			CAN_RUN = false
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

Dim BATTLE_ATTACK_BACK_TAR = Array(1300, 750, 1390, 785, "Attachment:BATTLE_ATTACK_BACK.png") 

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
Dim BATTLE_ATTACK_CARD_BUSTER_TAR = Array(55, 460, 1390, 690, "Attachment:BATTLE_ATTACK_CARD_BUSTER.png")
Dim BATTLE_ATTACK_CARD_PRIORITY_TARS = Array()
BATTLE_ATTACK_CARD_PRIORITY_TARS[1] = "Attachment:BATTLE_ATTACK_Hero_Card_okita.png"
BATTLE_ATTACK_CARD_PRIORITY_TARS[2] = "Attachment:BATTLE_ATTACK_Hero_Card_beni.png"
Dim BATTLE_ATTACK_CARD_PRIORITY_COUNT = 2
Dim BATTLE_ATTACK_CARD_PRIORITY_SIM = 0.78

Dim BATTLE_ATTACK_CARD_ARTS_TAR = Array(55, 460, 1390, 690, "Attachment:BATTLE_ATTACK_CARD_ARTS.png")
Dim BATTLE_ATTACK_CARD_ARTS_PRIORITY_TARS = Array()
Dim BATTLE_ATTACK_CARD_ARTS_PRIORITY_COUNT = 0
Dim BATTLE_ATTACK_CARD_ARTS_PRIORITY_SIM = 0.78

Dim BATTLE_ATTACK_CARD_QUICK_TAR = Array(55, 460, 1390, 690, "Attachment:BATTLE_ATTACK_CARD_QUICK.png")
Dim BATTLE_ATTACK_CARD_QUICK_PRIORITY_TARS = Array()
Dim BATTLE_ATTACK_CARD_QUICK_PRIORITY_COUNT = 0
Dim BATTLE_ATTACK_CARD_QUICK_PRIORITY_SIM = 0.78

Dim BATTLE_CARD_CHOSEN = Array(0, 0, 0, 0, 0)
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
Dim APPLE_CONFIRM_TAR = Array(895, 608, 992, 660, "Attachment:APPLE_CONFIRM.png")
Dim APPLE_CLOSE_COORD = Array(720, 695)

' ==================== EXTRA TARGETS ====================
Dim INFINITE_ROLL_TAR = Array(330, 370, 620, 610, "Attachment:ROLL100.png|Attachment:ROLL100-1.png|Attachment:ROLL10.png|Attachment:ROLL10-1.png")
Dim INFINITE_ROLL_FAST_COORD = Array(300, 400)

Dim ENHANCE_HERO_TAR = Array(880, 5, 1300, 70, "Attachment:ENHANCE_HERO.png")
Dim ENHANCE_HERO_RECOMMAND_TAR = Array(1240, 150, 1370, 208, "Attachment:ENHANCE_HERO_RECOMMAND.png")
Dim ENHANCE_HERO_RECOMMAND_CONFIRM_TAR = Array(880, 680, 1006, 745, "Attachment:ENHANCE_HERO_RECOMMAND_CONFIRM.png")
Dim ENHANCE_HERO_ENHANCE_TAR = Array(1340, 716, 1438, 798, "Attachment:ENHANCE_HERO_ENHANCE.png")
Dim ENHANCE_HERO_ENHANCE_CONFIRM_TAR = Array(877, 632, 1006, 698, "Attachment:ENHANCE_HERO_ENHANCE_CONFIRM.png")
Dim ENHANCE_HERO_REFUND_CLOSE_TAR = Array(550, 580, 890, 680, "Attachment:ENHANCE_HERO_REFUND_CLOSE.png")
Dim TAP_ENHANCE_HERO_REFUND_CLOSE = Array(686, 614)
Dim ENHANCE_HERO_TO_ASCEND_TAR = Array(1050, 580, 1320, 680, "Attachment:ENHANCE_HERO_TO_ASCEND.png")
Dim ENHANCE_HERO_TO_GRAIL_TAR = Array(1050, 580, 1320, 680, "Attachment:ENHANCE_HERO_TO_GRAIL.png")
Dim ENHANCE_ASCEND_TAR = Array(880, 5, 1300, 70, "Attachment:ENHANCE_ASCEND.png")
Dim ENHANCE_GRAIL_TAR = Array(1050, 5, 1420, 70, "Attachment:ENHANCE_GRAIL.png")
Dim ENHANCE_GRAIL_CONFIRM_TAR = Array(877, 632, 1006, 698, "Attachment:ENHANCE_HERO_ENHANCE_CONFIRM.png")
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
Dim TAP_ENHANCE_BLIND_SKIP = Array(940, 660)

Dim POOLFRIEND_CONTINUE_TAR = Array(720, 720, 990, 800, "Attachment:POOLFRIEND_CONTINUE.png")
Dim POOLFRIEND_GO_TAR = Array(830, 600, 1080, 670, "Attachment:POOLFRIEND_GO.png")

Dim ENHANCE_EQUIP_TAR = Array(880, 5, 1300, 70, "Attachment:ENHANCE_EQUIP.png")
Dim ENHANCE_EQUIP_ENHANCE_TAR = Array(1340, 716, 1438, 798, "Attachment:ENHANCE_EQUIP_ENHANCE.png")
Dim ENHANCE_EQUIP_ENHANCE_CONFIRM_TAR = Array(877, 632, 1006, 698, "Attachment:ENHANCE_EQUIP_ENHANCE_CONFIRM.png")

Dim ENHANCE_SKILL_TAR = Array(880, 5, 1300, 70, "Attachment:ENHANCE_SKILL.png")
Dim ENHANCE_SKILL_ENHANCE_TAR = Array(1185, 725, 1230, 785, "Attachment:ENHANCE_SKILL_ENHANCE.png")
Dim ENHANCE_SKILL_ENHANCE_CONFIRM_TAR = Array(820, 640, 890, 690, "Attachment:ENHANCE_SKILL_ENHANCE_CONFIRM.png")
Dim ENHANCE_SKILL_ENHANCE_L10_TAR = Array(450, 490, 610, 630, "Attachment:ENHANCE_SKILL_ENHANCE_L10.png")
Dim ENHANCE_SKILL_CLICK_COORD = Array(1100, 765)
Dim ENHANCE_SKILL_MAX_L10_TAR = Array(1150, 720, 1410, 800, "Attachment:ENHANCE_SKILL_MAX_L10.png")
Dim TAP_ENHANCE_SKILL_1 = Array(532, 286)
Dim TAP_ENHANCE_SKILL_2 = Array(852, 286)
Dim TAP_ENHANCE_SKILL_3 = Array(1172, 286)
Dim ENHANCE_SKILL_HERO_UNSELECTED_TAR = Array(140, 560, 300, 630, "Attachment:ENHANCE_SKILL_HERO_UNSELECTED.png")









' VARIATE

' Dim 灞忓箷妯鍧愭爣X,灞忓箷绾靛潗鏍嘫
' 灞忓箷妯鍧愭爣X=GetScreenX()
' 灞忓箷绾靛潗鏍嘫=GetScreenY()
' TracePrint 灞忓箷妯鍧愭爣X,灞忓箷绾靛潗鏍嘫
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
End Function

Function IsBattleEndDetected()
	Dim ConfirmIndex
	Dim LastTiePoint
	For ConfirmIndex = 1 To BATTLE_END_CONFIRM_COUNT
		' 鍙瑕佹敾鍑婚敭鍥炴潵锛屽氨鍒ゅ畾浠嶅湪鎴樻枟
		If CheckImg2(BATTLE_HERO_SKILL_CHECK_TAR) <> null Then
			IsBattleEndDetected = false
			Exit Function
		End If

		Dim TiePoint = CheckImg2(AWARD_TIE_TAR)
		If TiePoint = null Then
			IsBattleEndDetected = false
			Exit Function
		End If

		' 璇璇嗗埆閫氬父鍧愭爣浼氭姈鍔锛岃佹眰杩炵画鍛戒腑浣嶇疆绋冲畾
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

		If CheckImg2(BATTLE_HERO_SKILL_CHECK_TAR) <> null Then
			WaitRoundReadyOrBattleEnd = true
			Exit Function
		End If

		' 技能/攻击/动画过渡期先给宽限，避免攻击键短暂消失时误判结束
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
		' 心跳维持：每 3 秒刷新一次状态，防止状态被误判为离线/未启动
		If HeartbeatCounter Mod 10 = 0 Then
			UpdateRunnerStatus "RUNNING", "等待回合就绪(" & Int(WaitedMs / 1000) & "s)..."
		End If

		' 异常场景探测（如已意外退回地图）
		If WaitedMs >= 6000 And (HeartbeatCounter Mod 15 = 0) Then
			If CheckImg2(AGAIN_BATTLE_OUT_MENU_TAR) <> null Then
				AbortBattle "检测到已返回主界面/地图菜单，自动结束战斗"
				WaitRoundReadyOrBattleEnd = false
				Exit Function
			End If
		End If

		' 超时保护：最多等待 90 秒（涵盖绝大部分最长宝具动画+敌方行动）
		If WaitedMs >= 90000 Then
			If IsBattleEndDetected() Or CheckImg2(AWARD_TREASURE_NEXT_TAR) <> null Then
				TracePrint "Battle end detected at timeout boundary"
				BATTLE_ENDED_EARLY = true
				WaitRoundReadyOrBattleEnd = false
				Exit Function
			Else
				AbortBattle "等待回合就绪超时(90s)，已自动结束战斗避免卡死"
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









// 鍙栧浘娉>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

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

Function ContinuousCheckImg(Target)
	Dim GetImgCoord
	Dim waitCount = 0
	Do While true
		If USER_STOP_REQUESTED Or CheckStopSignal() Then
			ContinuousCheckImg = null
			Exit Function
		End If
		GetImgCoord = CheckImg2(Target)
		If GetImgCoord <> null Then
			ContinuousCheckImg = Array(GetImgCoord[1], GetImgCoord[2])
			Exit Do
		End If
		waitCount = waitCount + 1
		If waitCount Mod 6 = 0 Then
			UpdateRunnerStatus "RUNNING", "等待图片(" & Int(waitCount / 2) & "s): " & Target[5]
		End If

		' 异常场景探测（如已在主界面/地图，或体力弹窗出现）
		If waitCount >= 8 And (waitCount Mod 4 = 0) Then
			If CheckImg2(AGAIN_BATTLE_OUT_MENU_TAR) <> null Then
				AbortBattle "检测到已返回主界面/地图菜单，自动结束战斗"
				ContinuousCheckImg = null
				Exit Function
			End If
			If CheckImg2(APPLE_DISPLAY_TAR) <> null Then
				If APPLE_ENABLE <= 0 Then
					TracePrint "AP depleted and apple disabled, keeping dialog open for manual decision"
					AbortBattle "检测到体力不足且未开启吃苹果，保留弹窗并终止"
					ContinuousCheckImg = null
					Exit Function
				End If
			End If
		End If

		' 超时保护：最多等待 60 次 (约 30 秒)
		If waitCount >= 60 Then
			AbortBattle "找图超时(30s): " & Target[5] & "，已自动结束战斗避免卡死"
			ContinuousCheckImg = null
			Exit Function
		End If

		Delay 500
	Loop
	TracePrint "found: ", GetImgCoord[1], GetImgCoord[2]
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
			UpdateRunnerStatus "RUNNING", "等待结算出击选项(" & Int(waitCount * 0.7) & "s)..."
		End If

		' 超时保护：最多等待约 45 秒 (60 次)
		If waitCount >= 60 Then
			AbortBattle "结算出击选项匹配超时(45s)，已自动结束战斗避免卡死"
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
			UpdateRunnerStatus "RUNNING", "等待图片消失: " & Target[5]
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
			UpdateRunnerStatus "RUNNING", "结算等待下一步(" & Int(RetryCount * 0.3) & "s)..."
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
		sdPath = "/sdcard/FGO_Q/images/" & fileName
		If Dir.Exist(sdPath) = 1 Then
			pickedPath = sdPath
		Else
			sdPath = "/storage/emulated/0/FGO_Q/images/" & fileName
			If Dir.Exist(sdPath) = 1 Then
				pickedPath = sdPath
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
End Function

Function CheckPriorityImg(Target, Similarity)
	If IsNull(Similarity) Then
		Similarity = BATTLE_ATTACK_CARD_PRIORITY_SIM
	End If
	Dim Area = Target
	Dim AttachedImg = ResolveTargetImg(Target[5])
	Dim intX, intY
	intX = -1 : intY = -1
	FindPic Area[1], Area[2], Area[3], Area[4], AttachedImg, "000000", 0, Similarity, intX, intY
	If intX > -1 And intY > -1 Then
		CheckPriorityImg = Array(intX, intY)
		Exit Function
	End If
	If InStr(1, AttachedImg, "|") > 0 Then
		Dim subImgs = Split(AttachedImg, "|")
		Dim oneSub
		For Each oneSub In subImgs
			oneSub = Trim(CStr(oneSub))
			If Len(oneSub) > 0 Then
				intX = -1 : intY = -1
				FindPic Area[1], Area[2], Area[3], Area[4], oneSub, "000000", 0, Similarity, intX, intY
				If intX > -1 And intY > -1 Then
					CheckPriorityImg = Array(intX, intY)
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

// 鎷栨嫿>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
Function TouchMoveWithDownTime(Target,DownTime)
	TouchDown Target[1], Target[2], 1 //鎸変綇灞忓箷涓婄殑a鍧愭爣涓嶆斁,骞惰剧疆姝よЕ鐐笽D=1
	If IsNull(DownTime) Then
    	DownTime = 500
	End If
	Delay DownTime
	TouchMove Target[3], Target[4], 1, 500 //灏咺D=1鐨勮Е鐐硅姳x姣绉掔Щ鍔ㄨ嚦b鍧愭爣
	Delay 500
	TouchUp 1//鏉惧紑寮硅捣ID=1鐨勮Е鐐
End Function

// do Battle >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
Function ChooseFriend()
	BattlePrint("Choose Friend: key=" & selectedFriendKey & ", area=(" & PREPARE_FRIEND_TAR[1] & "," & PREPARE_FRIEND_TAR[2] & "," & PREPARE_FRIEND_TAR[3] & "," & PREPARE_FRIEND_TAR[4] & ")")
	Dim Point = ContinuousCheckImg(PREPARE_FRIEND_TAR)
	If Point = null Or USER_STOP_REQUESTED Then
		If Not USER_STOP_REQUESTED Then
			AbortBattle "未找到助战好友(" & selectedFriendKey & ")，已自动结束战斗避免卡死"
		End If
		Exit Function
	End If
	Dim TapPointX = Point[1]
	Dim TapPointY = Point[2]
	// todo check friend equip
	Delay 100
	CheckAndTapImg2(PREPARE_FRIEND_TAR, null)
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

		Dim StartPoint = CheckImg2(START_TAR)
		If StartPoint <> null Then
			TracePrint "Battle Start: START found (team confirm screen), tap START"
			tap StartPoint[1], StartPoint[2]
			Delay 1000
		Else
			Delay 300
		End If

		checkWaitCount = checkWaitCount + 1
		If checkWaitCount Mod 8 = 0 Then
			UpdateRunnerStatus "RUNNING", "等待进入战斗(" & Int(checkWaitCount * 0.4) & "s)..."
		End If

		' 异常场景探测
		If checkWaitCount >= 10 And (checkWaitCount Mod 5 = 0) Then
			If CheckImg2(AGAIN_BATTLE_OUT_MENU_TAR) <> null Then
				AbortBattle "检测到已返回主界面/地图菜单，无法开始战斗，已自动结束战斗"
				CheckBattleStart = false
				Exit Function
			End If
			If CheckImg2(APPLE_DISPLAY_TAR) <> null Then
				If APPLE_ENABLE <= 0 Then
					TracePrint "AP depleted and apple disabled, keeping dialog open for manual decision"
					AbortBattle "检测到体力不足且未开启吃苹果，保留弹窗并终止"
					CheckBattleStart = false
					Exit Function
				End If
			End If
		End If

		' 超时保护：最多约 60 秒 (150 次)
		If checkWaitCount >= 150 Then
			AbortBattle "等待进入战斗超时(60s)，已自动结束战斗避免卡死"
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
				CurrentActionArr(CurrentActionIndex) = Int(Mid(CStr(CurrentAction), CurrentActionIndex, 1)) ' 瀛樺叆鏁扮粍锛岀储寮曚粠0寮濮
			Next
			Dim SkillIndex = CurrentActionArr(1)
			Dim SkillTargetIndex = CurrentActionArr(2)
			Dim SkillActionType = CurrentActionArr(3)
			If IsNull(SkillIndex) Or SkillIndex <= 0 Then
				TracePrint "invalid skill action, skip", CurrentAction
			Else
				If SkillTargetIndex > 0 Then
					' 指向队友技能：循环点击尝试，直至目标弹窗打开
					Dim targetWaitCount = 0
					Do While true
						If USER_STOP_REQUESTED Or CheckStopSignal() Then
							Exit Do
						End If
						If CheckImg2(BATTLE_SKILL_GRANT_CHECK_TAR) <> null Then
							Exit Do
						End If
						tap BATTLE_HERO_SKILL_COORDS[SkillIndex][1], BATTLE_HERO_SKILL_COORDS[SkillIndex][2]
						Delay 400
						targetWaitCount = targetWaitCount + 1
						If targetWaitCount Mod 5 = 0 Then
							UpdateRunnerStatus "RUNNING", "等待技能目标弹窗(" & Int(targetWaitCount * 0.4) & "s)..."
						End If
						If targetWaitCount >= 25 Then
							AbortBattle "等待技能目标弹窗超时(10s): " & BATTLE_SKILL_GRANT_CHECK_TAR[5]
							Exit Do
						End If
					Loop
					If Not USER_STOP_REQUESTED And Not CheckStopSignal() Then
						Delay 100
						tap BATTLE_SKILL_GRANT_HREO_COORDS[SkillTargetIndex][1], BATTLE_SKILL_GRANT_HREO_COORDS[SkillTargetIndex][2]
						Delay 300
						clickAndWaitSkillAction()
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
				CurrentActionArr(CurrentActionIndex) = Int(Mid(CStr(CurrentAction), CurrentActionIndex, 1)) ' 瀛樺叆鏁扮粍锛岀储寮曚粠0寮濮
			Next
			Dim SkillIndex = CurrentActionArr(1)
			Dim SkillTargetIndex = CurrentActionArr(2)
			Dim SkillActionType = CurrentActionArr(3)
			If IsNull(SkillIndex) Or SkillIndex <= 0 Then
				TracePrint "invalid master action, skip", CurrentAction
			Else
				ContinuousCheckImg(BATTLE_MASTER_SKILL_DISPLAY_TAR)
				Delay 200
				tap BATTLE_MASTER_SKILL_COORDS[SkillIndex][1], BATTLE_MASTER_SKILL_COORDS[SkillIndex][2]

				If SkillActionType = 0 Then		' Special Skill(0):change
					Dim SkillChangeTargetIndex1 = CurrentActionArr(4)
					Dim SkillChangeTargetIndex2 = CurrentActionArr(5)
					CheckAndTapImg2(BATTLE_SKILL_CHANGE_CHECK_TAR, BATTLE_SKILL_CHANGE_HERO_COORDS[SkillChangeTargetIndex1])
					Delay BATTLE_SKILL_CHANGE_SELECTED_AWAIT_MS
					CheckAndTapImg2(BATTLE_SKILL_CHANGE_CHECK_TAR, BATTLE_SKILL_CHANGE_HERO_COORDS[SkillChangeTargetIndex2])
					CheckAndTapImg2(BATTLE_SKILL_CHANGE_SELECTEED_CHECK_TAR, null)
				End If
				If SkillTargetIndex > 0 Then
					Dim masterTargetWait = 0
					Do While true
						If USER_STOP_REQUESTED Or CheckStopSignal() Then
							Exit Do
						End If
						If CheckImg2(BATTLE_SKILL_GRANT_CHECK_TAR) <> null Then
							Exit Do
						End If
						tap BATTLE_MASTER_SKILL_COORDS[SkillIndex][1], BATTLE_MASTER_SKILL_COORDS[SkillIndex][2]
						Delay 400
						masterTargetWait = masterTargetWait + 1
						If masterTargetWait >= 25 Then
							AbortBattle "等待御主技能目标弹窗超时(10s): " & BATTLE_SKILL_GRANT_CHECK_TAR[5]
							Exit Do
						End If
					Loop
					If Not USER_STOP_REQUESTED And Not CheckStopSignal() Then
						Delay 100
						tap BATTLE_SKILL_GRANT_HREO_COORDS[SkillTargetIndex][1], BATTLE_SKILL_GRANT_HREO_COORDS[SkillTargetIndex][2]
						Delay 300
					End If
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

Function SelectPriorityBusterCard()
	Dim PriorityCount = BATTLE_ATTACK_CARD_PRIORITY_COUNT
	Dim BusterCards = Array()
	Dim BusterCount = 0
	Dim i
	For i = 1 To 5
		If BATTLE_CARD_CHOSEN[i] = 0 Then
			Dim cx = BATTLE_ATTACK_CARD_COORDS[i][1]
			Dim busterArea = Array(cx - 130, 460, cx + 130, 750, "Attachment:BATTLE_ATTACK_CARD_BUSTER.png")
			Dim getBuster = CheckImg2(busterArea)
			If getBuster <> null Then
				BusterCount = BusterCount + 1
				BusterCards[BusterCount] = i
			End If
		End If
	Next
	
	If BusterCount = 0 Then
		If FORCE_COLOR_CARD > 0 Then
			TracePrint "No Buster Card found, force wait: fallback to default"
			CheckAndTapImg2(BATTLE_ATTACK_CARD_BUSTER_TAR, null)
			Exit Function
		Else
			TracePrint "No Buster Card found, fallback to 54321"
			SelectFallbackCard()
			Exit Function
		End If
	End If
	
	Dim p
	If PriorityCount >= 1 Then
		For p = 1 To PriorityCount
			If BATTLE_ATTACK_CARD_PRIORITY_TARS[p] <> null Then
				Dim b
				For b = 1 To BusterCount
					Dim cIdx = BusterCards[b]
					cx = BATTLE_ATTACK_CARD_COORDS[cIdx][1]
					Dim heroTar = Array(cx - 100, 350, cx + 100, 550, BATTLE_ATTACK_CARD_PRIORITY_TARS[p])
					Dim getHero = CheckPriorityImg(heroTar, BATTLE_ATTACK_CARD_PRIORITY_SIM)
					If getHero <> null Then
						TracePrint "Found Priority Buster Card:", BATTLE_ATTACK_CARD_PRIORITY_TARS[p], "at card", cIdx, "sim", BATTLE_ATTACK_CARD_PRIORITY_SIM
						BATTLE_CARD_CHOSEN[cIdx] = 1
						tap BATTLE_ATTACK_CARD_COORDS[cIdx][1], BATTLE_ATTACK_CARD_COORDS[cIdx][2]
						Exit Function
					End If
				Next
			End If
		Next
	End If
	
	' Fallback
	Dim firstBusterIdx = BusterCards[1]
	TracePrint "No priority matched, tap first Buster Card:", firstBusterIdx
	BATTLE_CARD_CHOSEN[firstBusterIdx] = 1
	tap BATTLE_ATTACK_CARD_COORDS[firstBusterIdx][1], BATTLE_ATTACK_CARD_COORDS[firstBusterIdx][2]
End Function

Function SelectPriorityArtsCard()
	Dim PriorityCount = BATTLE_ATTACK_CARD_ARTS_PRIORITY_COUNT
	Dim ArtsCards = Array()
	Dim ArtsCount = 0
	Dim i
	For i = 1 To 5
		If BATTLE_CARD_CHOSEN[i] = 0 Then
			Dim cx = BATTLE_ATTACK_CARD_COORDS[i][1]
			Dim artsArea = Array(cx - 130, 460, cx + 130, 750, "Attachment:BATTLE_ATTACK_CARD_ARTS.png")
			Dim getArts = CheckImg2(artsArea)
			If getArts <> null Then
				ArtsCount = ArtsCount + 1
				ArtsCards[ArtsCount] = i
			End If
		End If
	Next

	If ArtsCount = 0 Then
		If FORCE_COLOR_CARD > 0 Then
			TracePrint "No Arts Card found, force wait: fallback to default"
			CheckAndTapImg2(BATTLE_ATTACK_CARD_ARTS_TAR, null)
			Exit Function
		Else
			TracePrint "No Arts Card found, fallback to 54321"
			SelectFallbackCard()
			Exit Function
		End If
	End If

	Dim p
	If PriorityCount >= 1 Then
		For p = 1 To PriorityCount
			If BATTLE_ATTACK_CARD_ARTS_PRIORITY_TARS[p] <> null Then
				Dim a
				For a = 1 To ArtsCount
					Dim cIdx = ArtsCards[a]
					cx = BATTLE_ATTACK_CARD_COORDS[cIdx][1]
					Dim heroTar = Array(cx - 100, 350, cx + 100, 550, BATTLE_ATTACK_CARD_ARTS_PRIORITY_TARS[p])
					Dim getHero = CheckPriorityImg(heroTar, BATTLE_ATTACK_CARD_ARTS_PRIORITY_SIM)
					If getHero <> null Then
						TracePrint "Found Priority Arts Card:", BATTLE_ATTACK_CARD_ARTS_PRIORITY_TARS[p], "at card", cIdx, "sim", BATTLE_ATTACK_CARD_ARTS_PRIORITY_SIM
						BATTLE_CARD_CHOSEN[cIdx] = 1
						tap BATTLE_ATTACK_CARD_COORDS[cIdx][1], BATTLE_ATTACK_CARD_COORDS[cIdx][2]
						Exit Function
					End If
				Next
			End If
		Next
	End If

	Dim firstArtsIdx = ArtsCards[1]
	TracePrint "No priority matched, tap first Arts Card:", firstArtsIdx
	BATTLE_CARD_CHOSEN[firstArtsIdx] = 1
	tap BATTLE_ATTACK_CARD_COORDS[firstArtsIdx][1], BATTLE_ATTACK_CARD_COORDS[firstArtsIdx][2]
End Function

Function SelectPriorityQuickCard()
	Dim PriorityCount = BATTLE_ATTACK_CARD_QUICK_PRIORITY_COUNT
	Dim QuickCards = Array()
	Dim QuickCount = 0
	Dim i
	For i = 1 To 5
		If BATTLE_CARD_CHOSEN[i] = 0 Then
			Dim cx = BATTLE_ATTACK_CARD_COORDS[i][1]
			Dim quickArea = Array(cx - 130, 460, cx + 130, 750, "Attachment:BATTLE_ATTACK_CARD_QUICK.png")
			Dim getQuick = CheckImg2(quickArea)
			If getQuick <> null Then
				QuickCount = QuickCount + 1
				QuickCards[QuickCount] = i
			End If
		End If
	Next

	If QuickCount = 0 Then
		If FORCE_COLOR_CARD > 0 Then
			TracePrint "No Quick Card found, force wait: fallback to default"
			CheckAndTapImg2(BATTLE_ATTACK_CARD_QUICK_TAR, null)
			Exit Function
		Else
			TracePrint "No Quick Card found, fallback to 54321"
			SelectFallbackCard()
			Exit Function
		End If
	End If

	Dim p
	If PriorityCount >= 1 Then
		For p = 1 To PriorityCount
			If BATTLE_ATTACK_CARD_QUICK_PRIORITY_TARS[p] <> null Then
				Dim q
				For q = 1 To QuickCount
					Dim cIdx = QuickCards[q]
					cx = BATTLE_ATTACK_CARD_COORDS[cIdx][1]
					Dim heroTar = Array(cx - 100, 350, cx + 100, 550, BATTLE_ATTACK_CARD_QUICK_PRIORITY_TARS[p])
					Dim getHero = CheckPriorityImg(heroTar, BATTLE_ATTACK_CARD_QUICK_PRIORITY_SIM)
					If getHero <> null Then
						TracePrint "Found Priority Quick Card:", BATTLE_ATTACK_CARD_QUICK_PRIORITY_TARS[p], "at card", cIdx, "sim", BATTLE_ATTACK_CARD_QUICK_PRIORITY_SIM
						BATTLE_CARD_CHOSEN[cIdx] = 1
						tap BATTLE_ATTACK_CARD_COORDS[cIdx][1], BATTLE_ATTACK_CARD_COORDS[cIdx][2]
						Exit Function
					End If
				Next
			End If
		Next
	End If

	Dim firstQuickIdx = QuickCards[1]
	TracePrint "No priority matched, tap first Quick Card:", firstQuickIdx
	BATTLE_CARD_CHOSEN[firstQuickIdx] = 1
	tap BATTLE_ATTACK_CARD_COORDS[firstQuickIdx][1], BATTLE_ATTACK_CARD_COORDS[firstQuickIdx][2]
End Function

Function SelectAttackCard(CardIndex)
	If IsNumeric(CardIndex) Then
		Dim cardNum = Int(CardIndex)
		If cardNum >= 1 And cardNum <= 5 Then
			BATTLE_CARD_CHOSEN[cardNum] = 1
		End If
		CheckAndTapImg2(BATTLE_ATTACK_BACK_TAR, BATTLE_ATTACK_CARD_COORDS[CardIndex])
	Else
		Dim CardMark = UCase(CStr(CardIndex))
		If CardMark = "B" Then
			TracePrint "B"
			SelectPriorityBusterCard()
		ElseIf CardMark = "A" Then
			TracePrint "A"
			SelectPriorityArtsCard()
		ElseIf CardMark = "Q" Then
			TracePrint "Q"
			SelectPriorityQuickCard()
		End If
	End If
	
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

	CheckAndTapImg2(BATTLE_HERO_SKILL_CHECK_TAR, null)
	Delay BATTLE_ULTIMATE_DISPLAY_AWAIT_MS
	
	Dim FirstCardIndex = ActionsGroup[2]
	SelectAttackCard(FirstCardIndex)
	'CheckAndTapImg2(BATTLE_ATTACK_BACK_TAR, BATTLE_ATTACK_CARD_COORDS[FirstCardIndex])
	Delay BATTLE_CARD_TAPED_AWAIT_MS

	Dim SecondCardIndex = ActionsGroup[3]
	If SecondCardIndex <> null Then
		SelectAttackCard(SecondCardIndex)
		'CheckAndTapImg2(BATTLE_ATTACK_BACK_TAR, BATTLE_ATTACK_CARD_COORDS[SecondCardIndex])
		'CheckAndTapImg2(BATTLE_ATTACK_CARD_FIRST_TAPED_TARS[FirstCardIndex], BATTLE_ATTACK_CARD_COORDS[SecondCardIndex])
		Delay BATTLE_CARD_TAPED_AWAIT_MS
	End If

	Dim ThirdCardIndex = ActionsGroup[4]
	If ThirdCardIndex <> null Then
		SelectAttackCard(ThirdCardIndex)
		'CheckAndTapImg2(BATTLE_ATTACK_BACK_TAR, BATTLE_ATTACK_CARD_COORDS[ThirdCardIndex])
		'CheckAndTapImg2(BATTLE_ATTACK_CARD_SECON_TAPED_TARS[SecondCardIndex], BATTLE_ATTACK_CARD_COORDS[ThirdCardIndex])
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
	
	If CHOOSE_FRIEND_MANUAL <= 0 Then
		If CheckImg2(BATTLE_HERO_SKILL_CHECK_TAR) <> null Or CheckImg2(BATTLE_ATTACK_BACK_TAR) <> null Or CheckImg2(START_TAR) <> null Then
			TracePrint "Already in battle or team screen (Attack/Start found), skip ChooseFriend"
		Else
			ChooseFriend()
		End If
	Else
		TracePrint "Manual choose friend mode (CHOOSE_FRIEND_MANUAL>0), skip ChooseFriend"
	End If
	If USER_STOP_REQUESTED Or CheckStopSignal() Then
		Exit Function
	End If
	If Not CheckBattleStart() Or USER_STOP_REQUESTED Or CheckStopSignal() Then
		Exit Function
	End If

	Dim RoundCount = UBound(AllActionRound)+1
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
	CheckAndTapImg2(AWARD_TIE_TAR, AWARD_TAP_COORD)
	If USER_STOP_REQUESTED Then Exit Function

	Delay AWARD_NORMAL_TAP_AWAIT_MS
	Dim CheckTieUpSuccess = CheckImg2(AWARD_TIE_UP_TAR)
	If CheckTieUpSuccess <> null Then
		Dim msgResult = Dialog.MsgBox("羁绊升级", 0)
	End If

	TracePrint "award before treasure"
	Dim HasTreasureNext = CheckNoImgAndTap2(AWARD_TREASURE_NEXT_TAR, AWARD_TAP_COORD)
	If Not HasTreasureNext Or USER_STOP_REQUESTED Then
		TracePrint "award treasure not found in time, stop run to avoid dead loop"
		If Not USER_STOP_REQUESTED Then
			AbortBattle "结算道具界面等待超时，已自动结束战斗避免卡死"
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
		Dim appleWaitCount = 0
		Dim CheckAppleAlertSuccess = null
		Do While appleWaitCount < 10
			If USER_STOP_REQUESTED Or CheckStopSignal() Then
				Exit Do
			End If
			CheckAppleAlertSuccess = CheckImg2(APPLE_DISPLAY_TAR)
			If CheckAppleAlertSuccess <> null Then
				Exit Do
			End If
			If CheckImg2(AGAIN_BATTLE_OUT_MENU_TAR) <> null Then
				TracePrint "Back to menu during apple check"
				HasTicket = false
				Exit Do
			End If
			If CheckImg2(START_TAR) <> null Or CheckImg2(BATTLE_HERO_SKILL_CHECK_TAR) <> null Then
				TracePrint "Already entered team/battle, AP was sufficient"
				Exit Do
			End If
			Delay 300
			appleWaitCount = appleWaitCount + 1
		Loop

		If CheckAppleAlertSuccess <> null Then
			If APPLE_ENABLE > 0 Then
				TracePrint "Eating golden apple..."
				UpdateRunnerStatus "RUNNING", "补充体力中..."
				CheckAndTapImg2(APPLE_DISPLAY_TAR, APPLE_GLODEN_COORD)
				Delay 500
				CheckAndTapImg2(APPLE_CONFIRM_TAR, null)
				Delay 1500
			Else
				TracePrint "AP depleted and apple disabled, keeping dialog open for manual decision"
				AbortBattle "体力不足且未开启吃苹果，保留弹窗等待人工处理"
				Exit Function
			End If
		End If
	End If

End Function

Function DetectExtraMethodIndex()
	Dim ScenePoint

	' 1=DoEnhance (从者强化 / 灵基再临相关界面)
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

	' 3=DoSkillEnhance (技能强化)
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

	' 5=DoRoll (无限池)
	ScenePoint = CheckImg2(INFINITE_ROLL_TAR)
	If ScenePoint <> null Then
		DetectExtraMethodIndex = 5
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
		GetExtraMethodActionName = "技能强化"
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

' 盲点跳过强化动画并等待回到从者强化主界面
Sub SkipHeroEnhanceAnim()
	TracePrint "开始盲点跳过从者强化动画..."
	Dim animCount = 0
	Dim heroReadyCount = 0
	Dim ascendReadyCount = 0

	Do While animCount < 60
		If USER_STOP_REQUESTED Or CheckStopSignal() Then
			Exit Sub
		End If

		' 0) 检查是否出现素材返还弹窗 (大成功/极大成功达到上限返还素材)
		Dim refundCloseCoord = CheckImg2(ENHANCE_HERO_REFUND_CLOSE_TAR)
		If refundCloseCoord <> null Then
			TracePrint "强化动画中检测到素材返还弹窗，点击关闭按钮 ->", refundCloseCoord[1], refundCloseCoord[2]
			tap refundCloseCoord[1], refundCloseCoord[2]
			Delay 800
		End If

		' 1) 优先检查是否出现满级突破引导 (前往灵基再临)
		' 1.5) 是否已达最终等级上限 (前往圣杯转临)
		Dim toGrailCoord = CheckImg2(ENHANCE_HERO_TO_GRAIL_TAR)
		If toGrailCoord <> null Then
			TracePrint "强化：检测到【前往圣杯转临】，从者已达最终等级上限"
			Exit Sub
		End If

		Dim toAscendCoord = CheckImg2(ENHANCE_HERO_TO_ASCEND_TAR)
		If toAscendCoord <> null Then
			ascendReadyCount = ascendReadyCount + 1
			If ascendReadyCount >= 2 Then
				TracePrint "强化动画结束: 检测到从者已达阶段满级，前往灵基再临就绪"
				Exit Sub
			End If
		Else
			ascendReadyCount = 0
		End If

		' 2) 检查强化按钮是否已稳定重新出现 (未达满级，游戏已自动填入狗粮)
		If CheckImg2(ENHANCE_HERO_ENHANCE_TAR) <> null Then
			heroReadyCount = heroReadyCount + 1
			If heroReadyCount >= 2 Then
				TracePrint "强化动画结束: 强化按钮已重新出现并就绪"
				Exit Sub
			End If
		Else
			heroReadyCount = 0
		End If

		' 3) 容错保护：若已盲点超过 15 次，且检测到强化标题，判断是否狗粮已耗尽
		If animCount > 15 And CheckImg2(ENHANCE_HERO_TAR) <> null Then
			Delay 400
			If CheckImg2(ENHANCE_HERO_ENHANCE_TAR) = null And CheckImg2(ENHANCE_HERO_TO_ASCEND_TAR) = null Then
				TracePrint "强化动画结束: 已回到强化界面，但无强化按钮与再临引导 (狗粮不足/QP不足)"
				Exit Sub
			End If
		End If

		' 盲点安全区 (居中偏右下空白区) 跳过过场动画
		tap TAP_ENHANCE_BLIND_SKIP[1], TAP_ENHANCE_BLIND_SKIP[2]
		Delay 250
		animCount = animCount + 1
	Loop
End Sub

' 灵基再临自动化子流程
Function DoHeroAscendFlow()
	TracePrint "=== [突破] 开始执行自动突破 ==="
	UpdateRunnerStatus "RUNNING", "灵基再临: 正在等待页面..."

	' 1. 等待确认已进入再临界面 (ENHANCE_ASCEND_TAR)
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
		TracePrint "未识别进入再临界面 (超时)"
		DoHeroAscendFlow = false
		Exit Function
	End If

	TracePrint "成功进入再临界面，等待数据加载..."
	Delay 800

	' 2. 右下角「强化」执行按钮 (再临界面执行突破，按钮与强化同为「强化」)
	Dim ascendBtnCoord = CheckImg2(ENHANCE_ASCEND_BTN_TAR)
	If ascendBtnCoord = null Then
		ascendBtnCoord = CheckImg2(ENHANCE_HERO_ENHANCE_TAR)
	End If
	If ascendBtnCoord = null Then
		TracePrint "灵基再临强化按钮未出现或材料/QP不足，安全终止突破"
		UpdateRunnerStatus "IDLE", "灵基再临素材不足或QP不足，无法继续突破"
		DoHeroAscendFlow = false
		Exit Function
	End If

	' 3. 点击再临强化按钮并等待确认弹窗（带重试机制，避免单次点击未响应导致死等）
	Dim confirmCoord = null
	Dim clickRetry = 0
	Do While clickRetry < 4
		TracePrint "点击右下角再临「强化」按钮 ->", ascendBtnCoord[1], ascendBtnCoord[2]
		UpdateRunnerStatus "RUNNING", "灵基再临中: 正在点击执行再临..."
		tap ascendBtnCoord[1], ascendBtnCoord[2]
		Delay 800

		' 检查确认弹窗是否出现
		Dim waitPop = 0
		Do While waitPop < 6
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

	If confirmCoord = null Then
		TracePrint "未检测到灵基再临确认弹窗，安全退出"
		UpdateRunnerStatus "IDLE", "未检测到灵基再临确认弹窗"
		DoHeroAscendFlow = false
		Exit Function
	End If

	TracePrint "点击灵基再临确认弹窗「决定」按钮 ->", confirmCoord[1], confirmCoord[2]
	tap confirmCoord[1], confirmCoord[2]
	Delay 600

	' 4. 盲点击跳过再临动画 (约普通强化的 2 倍时长)，探测「前往强化从者」按钮
	TracePrint "确认再临，开始盲点击加速并等待结束..."
	UpdateRunnerStatus "RUNNING", "灵基再临中: 加速动画..."

	Dim animRetry = 0
	Dim foundReturnBtn = false
	Dim returnBtnCoord = null
	Do While animRetry < 240
		If USER_STOP_REQUESTED Or CheckStopSignal() Then
			DoHeroAscendFlow = false
			Exit Function
		End If

		' 检查是否出现「前往强化从者」快捷返回按钮
		returnBtnCoord = CheckImg2(ENHANCE_ASCEND_TO_HERO_TAR)
		If returnBtnCoord <> null Then
			Delay 300
			returnBtnCoord = CheckImg2(ENHANCE_ASCEND_TO_HERO_TAR)
			If returnBtnCoord <> null Then
				foundReturnBtn = true
				TracePrint "检测到「前往强化从者」快捷按钮稳定 ->", returnBtnCoord[1], returnBtnCoord[2]
				Exit Do
			End If
		End If

		' 盲点击加速
		tap TAP_ENHANCE_BLIND_SKIP[1], TAP_ENHANCE_BLIND_SKIP[2]
		Delay 250
		animRetry = animRetry + 1
		If animRetry Mod 8 = 0 Then
			UpdateRunnerStatus "RUNNING", "灵基再临中: 加速动画与语音(" & Int(animRetry / 4) & "s)..."
		End If
	Loop

	' 5. 点击快捷按钮返回强化 (优先使用识别到的目标左上角坐标)
	If foundReturnBtn Then
		TracePrint "点击「前往强化从者」快捷按钮返回强化 ->", returnBtnCoord[1], returnBtnCoord[2]
		UpdateRunnerStatus "RUNNING", "灵基再临突破成功，正在返回强化从者..."
		tap returnBtnCoord[1], returnBtnCoord[2]
		Delay 1000

		' 确认是否成功返回强化界面
		Dim waitBack = 0
		Do While waitBack < 25
			If USER_STOP_REQUESTED Or CheckStopSignal() Then
				Exit Do
			End If
			If CheckImg2(ENHANCE_HERO_TAR) <> null Then
				TracePrint "已成功返回强化界面，完成闭环"
				DoHeroAscendFlow = true
				Exit Function
			End If
			' 若 1.5s 后仍未返回，重试点击快捷返回按钮
			If waitBack Mod 5 = 4 Then
				returnBtnCoord = CheckImg2(ENHANCE_ASCEND_TO_HERO_TAR)
				If returnBtnCoord <> null Then
					tap returnBtnCoord[1], returnBtnCoord[2]
				End If
			End If
			Delay 300
			waitBack = waitBack + 1
		Loop
	Else
		TracePrint "等待快捷返回按钮超时，尝试点击左上角返回按钮"
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

' 自动圣杯转临完整执行流
Function DoHeroGrailFlow()
	TracePrint "=== [圣杯转临] 开始执行自动圣杯转临 ==="
	UpdateRunnerStatus "RUNNING", "圣杯转临: 正在等待进入页面..."

	' 1. 等待确认已进入圣杯转临主界面 (ENHANCE_GRAIL_TAR)
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
		TracePrint "未识别到圣杯转临主界面 (超时)"
		DoHeroGrailFlow = false
		Exit Function
	End If

	TracePrint "成功进入圣杯转临界面，等待数据加载..."
	Delay 800

	' 2. 检测右下角「强化」执行按钮 (与再临/强化同为「强化」)
	Dim grailBtnCoord = CheckImg2(ENHANCE_ASCEND_BTN_TAR)
	If grailBtnCoord = null Then
		grailBtnCoord = CheckImg2(ENHANCE_HERO_ENHANCE_TAR)
	End If
	If grailBtnCoord = null Then
		TracePrint "圣杯转临「强化」按钮未激活(圣杯/QP不足)，安全终止转临"
		UpdateRunnerStatus "IDLE", "圣杯不足或QP不足，无法转临"
		DoHeroGrailFlow = false
		Exit Function
	End If

	' 3. 点击强化按钮并等待二次确认「决定」按钮（带 4 次重试）
	Dim confirmCoord = null
	Dim clickRetry = 0
	Do While clickRetry < 4
		TracePrint "点击圣杯转临「强化」按钮 ->", grailBtnCoord[1], grailBtnCoord[2]
		UpdateRunnerStatus "RUNNING", "圣杯转临: 正在点击执行..."
		tap grailBtnCoord[1], grailBtnCoord[2]
		Delay 800

		' 检测确认弹窗「决定」按钮是否出现
		Dim waitPop = 0
		Do While waitPop < 6
			confirmCoord = CheckImg2(ENHANCE_GRAIL_CONFIRM_TAR)
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

	If confirmCoord = null Then
		TracePrint "未检测到转临确认弹窗，安全退出"
		UpdateRunnerStatus "IDLE", "未检测到转临确认弹窗"
		DoHeroGrailFlow = false
		Exit Function
	End If

	TracePrint "点击确认「决定」按钮 ->", confirmCoord[1], confirmCoord[2]
	tap confirmCoord[1], confirmCoord[2]
	Delay 600

	' 4. 盲点快速跳过动画 (包含语音与动画，上限约 60 秒) 并探测「前往强化从者」按钮
	TracePrint "已确认，开始盲点跳过圣杯转临动画..."
	UpdateRunnerStatus "RUNNING", "圣杯转临: 跳过动画..."

	Dim animRetry = 0
	Dim foundReturnBtn = false
	Dim returnBtnCoord = null
	Do While animRetry < 240
		If USER_STOP_REQUESTED Or CheckStopSignal() Then
			DoHeroGrailFlow = false
			Exit Function
		End If

		' 是否出现「前往强化从者」快捷返回按钮 (跟灵基再临完全一样)
		returnBtnCoord = CheckImg2(ENHANCE_ASCEND_TO_HERO_TAR)
		If returnBtnCoord <> null Then
			Delay 300
			returnBtnCoord = CheckImg2(ENHANCE_ASCEND_TO_HERO_TAR)
			If returnBtnCoord <> null Then
				foundReturnBtn = true
				TracePrint "检测到「前往强化从者」快捷按钮稳定重现 ->", returnBtnCoord[1], returnBtnCoord[2]
				Exit Do
			End If
		End If

		' 盲点安全区快速跳过动画
		tap TAP_ENHANCE_BLIND_SKIP[1], TAP_ENHANCE_BLIND_SKIP[2]
		Delay 250
		animRetry = animRetry + 1
		If animRetry Mod 8 = 0 Then
			UpdateRunnerStatus "RUNNING", "圣杯转临: 跳过动画(" & Int(animRetry / 4) & "s)..."
		End If
	Loop

	' 5. 点击快捷按钮返回强化 (若超时则使用左上角返回按钮兜底)
	If foundReturnBtn Then
		TracePrint "点击「前往强化从者」快捷按钮返回强化 ->", returnBtnCoord[1], returnBtnCoord[2]
		UpdateRunnerStatus "RUNNING", "圣杯转临成功，正在返回强化..."
		tap returnBtnCoord[1], returnBtnCoord[2]
		Delay 1000

		' 确认是否成功返回强化主界面
		Dim waitBack = 0
		Do While waitBack < 25
			If USER_STOP_REQUESTED Or CheckStopSignal() Then
				Exit Do
			End If
			If CheckImg2(ENHANCE_HERO_TAR) <> null Then
				TracePrint "已成功返回从者强化界面，转临闭环完成"
				DoHeroGrailFlow = true
				Exit Function
			End If
			If waitBack Mod 5 = 4 Then
				returnBtnCoord = CheckImg2(ENHANCE_ASCEND_TO_HERO_TAR)
				If returnBtnCoord <> null Then
					tap returnBtnCoord[1], returnBtnCoord[2]
				End If
			End If
			Delay 300
			waitBack = waitBack + 1
		Loop
	Else
		TracePrint "等待快捷返回按钮超时，尝试点击左上角返回按钮"
		Dim backCoord = CheckImg2(ENHANCE_ASCEND_BACK_TAR)
		If backCoord <> null Then
			tap backCoord[1], backCoord[2]
		Else
			tap TAP_ENHANCE_ASCEND_BACK[1], TAP_ENHANCE_ASCEND_BACK[2]
		End If
		Delay 1000
	End If

	DoHeroGrailFlow = true
End Function


Function DoEnhance()
	' 0. 容错：检查是否停留在素材返还弹窗
	Dim refundCloseEntry = CheckImg2(ENHANCE_HERO_REFUND_CLOSE_TAR)
	If refundCloseEntry <> null Then
		TracePrint "容错检测到素材返还弹窗，点击关闭按钮 ->", refundCloseEntry[1], refundCloseEntry[2]
		tap refundCloseEntry[1], refundCloseEntry[2]
		Delay 800
		SkipHeroEnhanceAnim()
		Delay 500
	End If

	' 1. 容错：若当前不在从者强化主界面，检查是否停留在灵基再临相关界面
	If CheckImg2(ENHANCE_HERO_TAR) = null Then
		If CheckImg2(ENHANCE_ASCEND_TAR) <> null Then
			TracePrint "容错检测到当前正处于灵基再临界面，直接执行灵基再临流程..."
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
		ElseIf CheckImg2(ENHANCE_ASCEND_TO_HERO_TAR) <> null Then
			TracePrint "容错检测到停留在再临完成界面，自动点击「前往强化从者」"
			tap TAP_ENHANCE_ASCEND_TO_HERO[1], TAP_ENHANCE_ASCEND_TO_HERO[2]
			Delay 1000
		End If
	End If

' 2. 核心分支：检查是否出现「前往灵基再临」引导 (从者已达阶段满级)
	Dim toAscendCoord = CheckImg2(ENHANCE_HERO_TO_ASCEND_TAR)
	If toAscendCoord <> null Then
		If EXTRA_HERO_AUTO_ASCEND = 1 Then
			TracePrint "检测到「前往灵基再临」引导，【自动灵基再临】已开启，执行跳转突破..."
			UpdateRunnerStatus "RUNNING", "从者已达阶段满级，正在跳转灵基再临..."
			tap toAscendCoord[1], toAscendCoord[2]
			Delay 1000

			Dim ascendResult = DoHeroAscendFlow()
			If Not ascendResult Then
				TracePrint "灵基再临未成功完成，终止后续强化"
				HasTicket = false
			End If
			Exit Function
		Else
			TracePrint "检测到「前往灵基再临」引导，但未勾选【自动灵基再临】，正常结束整备任务"
			UpdateRunnerStatus "IDLE", "从者已达当前阶段满级 (未开启自动灵基再临)"
			HasTicket = false
			Exit Function
		End If
	End If

	' 2.5 圣杯转临分支：是否出现「前往圣杯转临」 (已达最终等级上限)
	Dim toGrailCoord = CheckImg2(ENHANCE_HERO_TO_GRAIL_TAR)
	If toGrailCoord <> null Then
		If EXTRA_HERO_AUTO_GRAIL = 1 Then
			TracePrint "检测到「前往圣杯转临」，自动圣杯转临已开启，执行跳转转临..."
			UpdateRunnerStatus "RUNNING", "已达满级，跳转圣杯转临..."
			tap toGrailCoord[1], toGrailCoord[2]
			Delay 1000

			Dim grailResult = DoHeroGrailFlow()
			If Not grailResult Then
				TracePrint "圣杯转临未成功完成，终止后续强化"
				HasTicket = false
			End If
			Exit Function
		Else
			TracePrint "从者已达最终等级上限（显示【前往圣杯转临】），自动圣杯转临未开启，强化流程圆满结束"
			UpdateRunnerStatus "IDLE", "从者已达满级(需圣杯转临)"
			HasTicket = false
			Exit Function
		End If
	End If

	' 3. 检查右下角「强化」按钮 (游戏原生已自动填入狗粮)
	Dim enhanceCoord = CheckImg2(ENHANCE_HERO_ENHANCE_TAR)
	If enhanceCoord = null Then
		' 容错缓冲：重试 3 次，防止网络延时或画面动画过渡
		Dim retryIdx = 0
		Do While retryIdx < 3
			Delay 400
			If CheckImg2(ENHANCE_HERO_TO_ASCEND_TAR) <> null Then
				Exit Function ' 刷新出再临按钮，退出当前动作进入下一轮再临分支
			End If
			enhanceCoord = CheckImg2(ENHANCE_HERO_ENHANCE_TAR)
			If enhanceCoord <> null Then
				Exit Do
			End If
			retryIdx = retryIdx + 1
		Loop

		If enhanceCoord = null Then
			TracePrint "未找到「强化」按钮且无再临引导，判定为狗粮耗尽、QP不足或不可强化，安全退出"
			UpdateRunnerStatus "IDLE", "从者强化结束 (狗粮不足/QP不足/未选从者)"
			HasTicket = false
			Exit Function
		End If
	End If

	' 4. 点击「强化」按钮
	TracePrint "从者强化: 点击「强化」按钮 ->", enhanceCoord[1], enhanceCoord[2]
	UpdateRunnerStatus "RUNNING", "从者强化执行中 (第 " & CurrentBattleCount & "/" & EXTRA_ACTION_COUNT & " 次)..."
	tap enhanceCoord[1], enhanceCoord[2]
	Delay 500

	' 5. 等待并点击强化确认弹窗「决定」按钮
	Dim confirmCoord = ContinuousCheckImg(ENHANCE_HERO_ENHANCE_CONFIRM_TAR)
	If confirmCoord <> null Then
		TracePrint "从者强化: 点击确认弹窗「决定」按钮 ->", confirmCoord[1], confirmCoord[2]
		tap confirmCoord[1], confirmCoord[2]
		Delay 500
	End If

	' 6. 高频盲点跳过强化动画，并等待回到稳定强化界面或突破引导界面
	UpdateRunnerStatus "RUNNING", "跳过强化动画中 (第 " & CurrentBattleCount & "/" & EXTRA_ACTION_COUNT & " 次)..."
	SkipHeroEnhanceAnim()
	Delay 300
End Function

Function DoFriendPool()
	CheckAndTapImg2(POOLFRIEND_CONTINUE_TAR, null)
	Delay 500
	CheckAndTapImg2(POOLFRIEND_GO_TAR, null)
	Delay 800
	CheckNoImgAndTap2(POOLFRIEND_CONTINUE_TAR, POOLFRIEND_CONTINUE_TAR)
End Function

Function DoEquipEnhance()
	CheckAndTapImg2(ENHANCE_EQUIP_ENHANCE_TAR, null)
	Delay 500
	CheckAndTapImg2(ENHANCE_EQUIP_ENHANCE_CONFIRM_TAR, null)
	Delay 500
	CheckNoImgAndTap2(ENHANCE_EQUIP_ENHANCE_TAR, ENHANCE_EQUIP_ENHANCE_CONFIRM_TAR)
End Function

Function DoSkillEnhance(MaxLevel)
	If EXTRA_SKILL_AUTO_THREE = 1 Then
		' --- 3技能顺序连续强化 ---
		TracePrint "=== 启动3技能顺序强化流程 (目标上限: Lv" & MaxLevel & ") ==="

		' 0) 首检: 检查左侧是否未选中从者 (若未选中，说明从者3技能已全部满级或未选择从者)
		If CheckImg2(ENHANCE_SKILL_HERO_UNSELECTED_TAR) <> null Then
			TracePrint "检测到左侧未选中从者 (从者3个技能已全部强化满级)，强化流程直接结束"
			HasTicket = false
			Exit Function
		End If

		' 复位: 首先点击切换到技能1
		TracePrint "复位: 切换到技能1 ->", TAP_ENHANCE_SKILL_1[1], TAP_ENHANCE_SKILL_1[2]
		tap TAP_ENHANCE_SKILL_1[1], TAP_ENHANCE_SKILL_1[2]
		Delay 800

		Dim k
		For k = 1 To 3
			If USER_STOP_REQUESTED Or CheckStopSignal() Then
				Exit Function
			End If

			' 检查从者是否处于未选中状态 (3个技能全部满级后自动取消选中)
			If CheckImg2(ENHANCE_SKILL_HERO_UNSELECTED_TAR) <> null Then
				TracePrint "检测到左侧从者已取消选中 (3个技能已全部强化满级)，强化流程全部完成"
				HasTicket = false
				Exit Function
			End If

			If k > 1 Then
				If k = 2 Then
					TracePrint ">>> 切换至技能 2 ->", TAP_ENHANCE_SKILL_2[1], TAP_ENHANCE_SKILL_2[2]
					tap TAP_ENHANCE_SKILL_2[1], TAP_ENHANCE_SKILL_2[2]
				ElseIf k = 3 Then
					TracePrint ">>> 切换至技能 3 ->", TAP_ENHANCE_SKILL_3[1], TAP_ENHANCE_SKILL_3[2]
					tap TAP_ENHANCE_SKILL_3[1], TAP_ENHANCE_SKILL_3[2]
				End If
				Delay 800
			End If

			Dim skillFinished = false
			Do While skillFinished = false
				If USER_STOP_REQUESTED Or CheckStopSignal() Then
					Exit Function
				End If

				' 循环检测界面就绪状态（最多等待 3 秒），避免动画未收尾或网络加载时误判跳过
				Dim waitUi = 0
				Dim canEnhance = false
				Dim isMaxL10 = false
				Dim isLoreTarget = false

				Do While waitUi < 15
					If USER_STOP_REQUESTED Or CheckStopSignal() Then
						Exit Function
					End If

					' 0) 满级取消选中判断: 检查从者是否已自动取消选中 (全部技能满级)
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
					If CheckImg2(ENHANCE_SKILL_ENHANCE_TAR) <> null Then
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

				' 4) 执行点击「强化」按钮
				Dim enhanceCoord = CheckImg2(ENHANCE_SKILL_ENHANCE_TAR)
				If enhanceCoord <> null Then
					tap enhanceCoord[1], enhanceCoord[2]
				Else
					tap 1206, 756
				End If
				Delay 500

				' 5) 等待并点击「确认」弹窗（带超时，杜绝死锁）
				Dim confirmCoord = null
				Dim waitConfirm = 0
				Do While waitConfirm < 12
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
					Delay 400

					' 阶段 A：纯盲点跳过阶段 (持续快速点击屏幕跳过光效、台词与动画，不在此期间判断找图防误判)
					' 参考实测耗时约为 2.5~3 秒，此处持续点击 8 次 (约 2.4 秒)
					Dim blindTap
					For blindTap = 1 To 8
						If USER_STOP_REQUESTED Or CheckStopSignal() Then
							Exit Function
						End If
						tap ENHANCE_SKILL_CLICK_COORD[1], ENHANCE_SKILL_CLICK_COORD[2]
						Delay 300
					Next

					' 阶段 B：安全间隔后的防抖稳定判定阶段 (边点边检测是否真正回到就绪状态)
					Dim animRetry = 0
					Dim isAnimFinished = false
					Do While animRetry < 30
						If USER_STOP_REQUESTED Or CheckStopSignal() Then
							Exit Function
						End If

						' 0) 检测是否已自动取消选中从者 (3个技能全部升至10级满级后自动取消选中)
						If CheckImg2(ENHANCE_SKILL_HERO_UNSELECTED_TAR) <> null Then
							Delay 350
							If CheckImg2(ENHANCE_SKILL_HERO_UNSELECTED_TAR) <> null Then
								TracePrint "升级动画结束确认: 检测到从者已自动取消选中 (3个技能全部满级)，强化全部完成"
								HasTicket = false
								Exit Function
							End If
						End If

						' 1) 优先检测 10 级满级 (无法继续强化)
						If CheckImg2(ENHANCE_SKILL_MAX_L10_TAR) <> null Then
							Delay 350
							' 二次确认防抖：若再次检测依然存在，确认界面稳定处于满级状态
							If CheckImg2(ENHANCE_SKILL_MAX_L10_TAR) <> null Then
								TracePrint "升级动画结束确认: 当前技能已升至10级满级"
								isAnimFinished = true
								Exit Do
							End If
						End If

						' 2) 检测强化按钮是否稳定重新出现 (未满级继续强化)
						If CheckImg2(ENHANCE_SKILL_ENHANCE_TAR) <> null Then
							Delay 350
							' 二次确认防抖：若再次检测依然存在，确认界面稳定恢复就绪
							If CheckImg2(ENHANCE_SKILL_ENHANCE_TAR) <> null Then
								TracePrint "升级动画结束确认: 强化按钮已稳定重新出现"
								isAnimFinished = true
								Exit Do
							End If
						End If

						' 继续点击以推进可能残留的等级提升提示框或长台词
						tap ENHANCE_SKILL_CLICK_COORD[1], ENHANCE_SKILL_CLICK_COORD[2]
						Delay 300
						animRetry = animRetry + 1
					Loop

					If Not isAnimFinished Then
						' 超时后最后确认一次是否未选中从者
						If CheckImg2(ENHANCE_SKILL_HERO_UNSELECTED_TAR) <> null Then
							TracePrint "升级动画后检测到从者已自动取消选中，强化全部完成"
							HasTicket = false
							Exit Function
						End If
						TracePrint "警告: 跳过升级动画等待超时，尝试继续后续流程"
					End If

					CurrentBattleCount = CurrentBattleCount + 1
					UpdateRunnerStatus "RUNNING", "技能强化 [技能" & k & "] 第 " & CurrentBattleCount & "/" & EXTRA_ACTION_COUNT & " 次"
					TracePrint "技能强化进度: 技能 " & k & " 强化成功，累计完成 " & CurrentBattleCount & " 次"

					If CurrentBattleCount >= EXTRA_ACTION_COUNT Then
						TracePrint "已达到 Extra 执行次数上限: " & EXTRA_ACTION_COUNT
						HasTicket = false
						Exit Function
					End If

					Delay 600
				End If
			Loop
		Next

		TracePrint "=== 3个技能顺序强化全部完成 ==="
		HasTicket = false
	Else
		' --- 单技能强化 (原逻辑兼容器) ---
		If CheckImg2(ENHANCE_SKILL_HERO_UNSELECTED_TAR) <> null Then
			TracePrint "检测到左侧未选中从者，单技能强化结束"
			HasTicket = false
			Exit Function
		End If
		ContinuousCheckImg(ENHANCE_SKILL_ENHANCE_TAR)
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
		CheckAndTapImg2(ENHANCE_SKILL_ENHANCE_TAR, null)
		CheckAndTapImg2(ENHANCE_SKILL_ENHANCE_CONFIRM_TAR, null)
		Delay 400
		Dim legacyBlindTap
		For legacyBlindTap = 1 To 8
			If USER_STOP_REQUESTED Or CheckStopSignal() Then
				Exit Function
			End If
			tap ENHANCE_SKILL_CLICK_COORD[1], ENHANCE_SKILL_CLICK_COORD[2]
			Delay 300
		Next
		Dim legacyAnimRetry = 0
		Do While legacyAnimRetry < 30
			If USER_STOP_REQUESTED Or CheckStopSignal() Then
				Exit Function
			End If
			If CheckImg2(ENHANCE_SKILL_HERO_UNSELECTED_TAR) <> null Then
				HasTicket = false
				Exit Function
			End If
			If CheckImg2(ENHANCE_SKILL_MAX_L10_TAR) <> null Then
				Delay 350
				If CheckImg2(ENHANCE_SKILL_MAX_L10_TAR) <> null Then
					Exit Do
				End If
			End If
			If CheckImg2(ENHANCE_SKILL_ENHANCE_TAR) <> null Then
				Delay 350
				If CheckImg2(ENHANCE_SKILL_ENHANCE_TAR) <> null Then
					Exit Do
				End If
			End If
			tap ENHANCE_SKILL_CLICK_COORD[1], ENHANCE_SKILL_CLICK_COORD[2]
			Delay 300
			legacyAnimRetry = legacyAnimRetry + 1
		Loop
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
	UpdateRunnerStatus "RUNNING", "Extra 辅助启动中..."

	Dim detectedIndex = DetectExtraMethodIndex()
	If detectedIndex = 0 Then
		TracePrint "AUTO DETECT FAILED: NO MATCHED SCENE"
		UpdateRunnerStatus "IDLE", "未检测到对应 Extra 场景(从者/礼装/技能强化或友情池/无限池)"
		Exit Sub
	End If

	Dim actionName = GetExtraMethodActionName(detectedIndex)
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
	UpdateRunnerStatus "RUNNING", "战斗启动中"

	Do While true
		If USER_STOP_REQUESTED Or CheckStopSignal() Then
			TracePrint "Battle batch interrupted before round"
			Exit Do
		End If

		CurrentBattleCount = CurrentBattleCount + 1
		UpdateRunnerStatus "RUNNING", "第 " & CurrentBattleCount & "/" & BATTLE_COUNT & " 场进行中"

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
		UpdateRunnerStatus "IDLE", "已停止 (已完成 " & CurrentBattleCount & " 场)"
	ElseIf Not HasTicket Then
		UpdateRunnerStatus "IDLE", "票券或体力耗尽已结束"
	Else
		UpdateRunnerStatus "IDLE", "战斗计划已全部完成 (" & BATTLE_COUNT & " 场)"
	End If
End Sub

Sub MainStandbyLoop()
	TracePrint "========================================"
	TracePrint "FGO_Q BATTLE V4 RUNNER - STANDBY MODE"
	TracePrint "STANDBY READY. WAITING FOR WEB COMMAND..."
	TracePrint "========================================"

	' 启动时清理历史指令残留
	Dim cmdPath = "/sdcard/FGO_Q/cmd.txt"
	zm.FileWrite cmdPath, ""

	UpdateRunnerStatus "IDLE", "待命中 (等待网页下发运行指令)"

	Dim loopCounter = 0
	Do While true
		loopCounter = loopCounter + 1

		' 约每 1 秒刷新一次心跳 (500ms * 2 = 1s)
		If loopCounter Mod 2 = 0 Then
			If Len(ABORT_REASON) > 0 Then
				UpdateRunnerStatus "IDLE", ABORT_REASON
			Else
				UpdateRunnerStatus "IDLE", "待命中 (就绪)"
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
						UpdateRunnerStatus "IDLE", "配置校验未通过，请检查 Web 页面"
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
						UpdateRunnerStatus "IDLE", "待命中 (等待下一组指令)"
					End If
				ElseIf cmdText = "STOP" Then
					zm.FileWrite cmdPath, ""
					USER_STOP_REQUESTED = false
					ABORT_REASON = ""
					UpdateRunnerStatus "IDLE", "已处于待命状态"
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
