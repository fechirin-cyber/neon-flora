class_name ReelLogic
extends RefCounted
## 滑り制御・停止位置計算（5ライン・ICE技術介入対応）

## 停止位置計算（最大4コマ滑り、ICE最終リールは1コマ）
static func calc_stop_position(reel_idx: int, pressed_pos: int, current_flag: PayTable.Flag,
		bonus_flag_stocked: PayTable.Flag, reel_positions: Array[int],
		reel_stopped: Array[bool]) -> int:
	# ICE技術介入: 最終停止リールは1コマ引き込み
	var max_slip := 5  # 0〜4コマ
	if current_flag == PayTable.Flag.ICE:
		var other_stopped := 0
		for i in range(3):
			if i != reel_idx and reel_stopped[i]:
				other_stopped += 1
		if other_stopped >= 2:
			max_slip = 2  # 0〜1コマ

	for slip in range(max_slip):
		var candidate := posmod(pressed_pos + slip, ReelData.REEL_SIZE)
		var window := ReelData.get_window(reel_idx, candidate)
		if is_valid_stop(reel_idx, window, candidate, current_flag,
				bonus_flag_stocked, reel_positions, reel_stopped):
			return candidate
	return pressed_pos  # フェイルセーフ

## この停止位置が現在のフラグに対して有効か判定
static func is_valid_stop(reel_idx: int, window: Array, _pos: int,
		active_flag: PayTable.Flag, bonus_flag_stocked: PayTable.Flag,
		reel_positions: Array[int], reel_stopped: Array[bool]) -> bool:
	var center_symbol: int = window[1]

	var try_bonus_align := (bonus_flag_stocked != PayTable.Flag.HAZURE and
		active_flag == PayTable.Flag.HAZURE)

	match active_flag:
		PayTable.Flag.HAZURE:
			# LEFT: チェリーを蹴る
			if reel_idx == 0:
				if ReelData.CHR in window:
					return false
			# ボーナスストック中: 揃え方向に引き込む
			if try_bonus_align:
				if not _can_align_bonus(reel_idx, window, bonus_flag_stocked,
						reel_positions, reel_stopped):
					return false
			# 5ライン全てで入賞図柄が揃わないこと
			return not _would_complete_winning_line(reel_idx, window,
				reel_positions, reel_stopped)

		PayTable.Flag.REPLAY:
			# 5ライン対応: いずれかのラインでRPLを揃える（中段優先は滑り順で実現）
			return _can_align_symbol_on_line(reel_idx, window, ReelData.RPL,
				reel_positions, reel_stopped)

		PayTable.Flag.CHERRY_2:
			if reel_idx == 0:
				return window[0] == ReelData.CHR or window[2] == ReelData.CHR
			return true

		PayTable.Flag.CHERRY_4:
			if reel_idx == 0:
				return center_symbol == ReelData.CHR
			return true

		PayTable.Flag.BELL:
			# 5ライン対応: いずれかのラインでBELを揃える
			return _can_align_symbol_on_line(reel_idx, window, ReelData.BEL,
				reel_positions, reel_stopped)

		PayTable.Flag.ICE:
			# 5ライン対応: いずれかのラインでICEを揃える
			return _can_align_symbol_on_line(reel_idx, window, ReelData.ICE,
				reel_positions, reel_stopped)

		PayTable.Flag.BIG_RED, PayTable.Flag.BIG_BLUE, PayTable.Flag.REG:
			# ボーナスフラグ成立ゲームでは入賞を蹴る
			return not _would_complete_winning_line(reel_idx, window,
				reel_positions, reel_stopped)

	return true

## ボーナス揃え判定（統合7: 赤7/青7どちらでもBIG成立、5ライン対応）
static func _can_align_bonus(reel_idx: int, window: Array, bonus_flag: PayTable.Flag,
		reel_positions: Array[int] = [], reel_stopped: Array[bool] = []) -> bool:
	match bonus_flag:
		PayTable.Flag.BIG_RED, PayTable.Flag.BIG_BLUE:
			# 統合揃え: 赤7 or 青7 のどちらでもOK
			return (_can_align_symbol_on_line(reel_idx, window, ReelData.S7R,
					reel_positions, reel_stopped) or
				_can_align_symbol_on_line(reel_idx, window, ReelData.S7B,
					reel_positions, reel_stopped))
		PayTable.Flag.REG:
			return _can_align_symbol_on_line(reel_idx, window, ReelData.BAR,
				reel_positions, reel_stopped)
		_:
			return true

## 5ライン上でシンボルを揃えられる停止位置かチェック
## 中段ライン優先は calc_stop_position の滑り順（0→4）で自然に実現される
static func _can_align_symbol_on_line(reel_idx: int, window: Array, symbol: int,
		reel_positions: Array[int], reel_stopped: Array[bool]) -> bool:
	# 5ライン定義: 各リールの行インデックス [LEFT, CENTER, RIGHT]
	var line_rows := [
		[0, 0, 0],  # L1: 横上段
		[1, 1, 1],  # L2: 横中段
		[2, 2, 2],  # L3: 横下段
		[0, 1, 2],  # L4: 斜め右下がり
		[2, 1, 0],  # L5: 斜め右上がり
	]

	for line in line_rows:
		var my_row: int = line[reel_idx]
		if window[my_row] != symbol:
			continue
		# この行にターゲットシンボルがある → 他リールとの整合性チェック
		var line_possible := true
		for other_reel in range(3):
			if other_reel == reel_idx:
				continue
			if not reel_stopped[other_reel]:
				continue  # 未停止リールは制約なし
			var other_window := ReelData.get_window(other_reel, reel_positions[other_reel])
			var other_row: int = line[other_reel]
			if other_window[other_row] != symbol:
				line_possible = false
				break
		if line_possible:
			return true
	return false

## 5ライン全てで入賞図柄の3揃いが発生しないかチェック
static func _would_complete_winning_line(reel_idx: int, window: Array,
		reel_positions: Array[int], reel_stopped: Array[bool]) -> bool:
	# 他の2リールが停止済みでなければ揃い不可能
	var other_stopped := 0
	for i in range(3):
		if i != reel_idx and reel_stopped[i]:
			other_stopped += 1
	if other_stopped < 2:
		return false

	# 3リール分のwindowを構築
	var windows: Array = []
	for i in range(3):
		if i == reel_idx:
			windows.append(window)
		else:
			windows.append(ReelData.get_window(i, reel_positions[i]))

	var lw: Array = windows[0]
	var cw: Array = windows[1]
	var rw: Array = windows[2]

	# 5ライン判定
	var lines := [
		[lw[0], cw[0], rw[0]],  # L1: 横上段
		[lw[1], cw[1], rw[1]],  # L2: 横中段
		[lw[2], cw[2], rw[2]],  # L3: 横下段
		[lw[0], cw[1], rw[2]],  # L4: 斜め右下がり
		[lw[2], cw[1], rw[0]],  # L5: 斜め右上がり
	]

	for line in lines:
		if line[0] == line[1] and line[1] == line[2]:
			match line[0]:
				ReelData.RPL, ReelData.BEL, ReelData.ICE:
					return true
	return false
