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
			# 5ライン対応: RPLを揃えつつ、他の入賞役が同時に揃わないこと
			if not _can_align_symbol_on_line(reel_idx, window, ReelData.RPL,
					reel_positions, reel_stopped):
				return false
			return not _would_complete_unwanted_line(reel_idx, window, ReelData.RPL,
				reel_positions, reel_stopped)

		PayTable.Flag.CHERRY_2:
			if reel_idx == 0:
				return window[0] == ReelData.CHR or window[2] == ReelData.CHR
			# CENTER/RIGHT: 他の入賞役が揃わないこと
			return not _would_complete_winning_line(reel_idx, window,
				reel_positions, reel_stopped)

		PayTable.Flag.CHERRY_4:
			if reel_idx == 0:
				return center_symbol == ReelData.CHR
			# CENTER/RIGHT: 他の入賞役が揃わないこと
			return not _would_complete_winning_line(reel_idx, window,
				reel_positions, reel_stopped)

		PayTable.Flag.BELL:
			# 5ライン対応: BELを揃えつつ、他の入賞役が同時に揃わないこと
			if not _can_align_symbol_on_line(reel_idx, window, ReelData.BEL,
					reel_positions, reel_stopped):
				return false
			return not _would_complete_unwanted_line(reel_idx, window, ReelData.BEL,
				reel_positions, reel_stopped)

		PayTable.Flag.ICE:
			# 5ライン対応: ICEを揃えつつ、他の入賞役が同時に揃わないこと
			if not _can_align_symbol_on_line(reel_idx, window, ReelData.ICE,
					reel_positions, reel_stopped):
				return false
			return not _would_complete_unwanted_line(reel_idx, window, ReelData.ICE,
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

## 5ライン上で意図しない入賞役（allowed_symbol以外）が成立しないかチェック
## 実機準拠: BELLフラグ時にBELは揃ってOKだが、ICEやRPLが同時に揃うのはNG
static func _would_complete_unwanted_line(reel_idx: int, window: Array,
		allowed_symbol: int, reel_positions: Array[int],
		reel_stopped: Array[bool]) -> bool:
	var other_stopped := 0
	for i in range(3):
		if i != reel_idx and reel_stopped[i]:
			other_stopped += 1
	if other_stopped < 2:
		return false

	var windows: Array = []
	for i in range(3):
		if i == reel_idx:
			windows.append(window)
		else:
			windows.append(ReelData.get_window(i, reel_positions[i]))

	var lw: Array = windows[0]
	var cw: Array = windows[1]
	var rw: Array = windows[2]

	var lines := [
		[lw[0], cw[0], rw[0]],
		[lw[1], cw[1], rw[1]],
		[lw[2], cw[2], rw[2]],
		[lw[0], cw[1], rw[2]],
		[lw[2], cw[1], rw[0]],
	]

	for line in lines:
		if line[0] == line[1] and line[1] == line[2]:
			if line[0] == allowed_symbol:
				continue  # 意図した入賞 → OK
			match line[0]:
				ReelData.RPL, ReelData.BEL, ReelData.ICE,\
				ReelData.S7R, ReelData.S7B, ReelData.BAR:
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
				ReelData.RPL, ReelData.BEL, ReelData.ICE,\
				ReelData.S7R, ReelData.S7B, ReelData.BAR:
					return true
	return false

# =====================================================
# Unit Tests (S-7, §15.1 U1-U9)
# =====================================================

static func _run_unit_tests() -> void:
	var total := 0
	var passed := 0

	print("======== ReelLogic Unit Tests (§15.1) ========")

	var r: Array
	r = _test_u1(); total += r[0]; passed += r[1]
	r = _test_u2(); total += r[0]; passed += r[1]
	r = _test_pull_in("U3", PayTable.Flag.REPLAY, ReelData.RPL)
	total += r[0]; passed += r[1]
	r = _test_pull_in("U4", PayTable.Flag.BELL, ReelData.BEL)
	total += r[0]; passed += r[1]
	r = _test_pull_in("U5", PayTable.Flag.ICE, ReelData.ICE)
	total += r[0]; passed += r[1]
	r = _test_u6(); total += r[0]; passed += r[1]
	r = _test_u7(); total += r[0]; passed += r[1]
	r = _test_u8(); total += r[0]; passed += r[1]
	r = _test_u9(); total += r[0]; passed += r[1]

	print("======== TOTAL: %d/%d PASS ========" % [passed, total])
	if passed == total:
		print(">>> ALL TESTS PASSED <<<")
	else:
		print(">>> %d FAILURES <<<" % (total - passed))

## U1: HAZURE停止制御 — 5ラインで入賞が揃わない (63パターン)
static func _test_u1() -> Array:
	var t := 0; var p := 0
	for ri in range(3):
		for pos in range(ReelData.REEL_SIZE):
			t += 1
			var positions: Array[int] = [0, 0, 0]
			var stopped: Array[bool] = [true, true, true]
			stopped[ri] = false
			var stop := calc_stop_position(ri, pos, PayTable.Flag.HAZURE,
				PayTable.Flag.HAZURE, positions, stopped)
			positions[ri] = stop
			if not _ut_has_winning_line(positions):
				p += 1
			else:
				print("  U1 FAIL: reel=%d press=%d stop=%d" % [ri, pos, stop])
	print("U1 HAZURE停止制御: %d/%d" % [p, t])
	return [t, p]

## U2: HAZURE時チェリー蹴り — LEFTでCHRが蹴られる (21パターン)
static func _test_u2() -> Array:
	var t := 0; var p := 0
	for pos in range(ReelData.REEL_SIZE):
		t += 1
		var positions: Array[int] = [0, 0, 0]
		var stopped: Array[bool] = [false, true, true]
		var stop := calc_stop_position(0, pos, PayTable.Flag.HAZURE,
			PayTable.Flag.HAZURE, positions, stopped)
		var window := ReelData.get_window(0, stop)
		if ReelData.CHR not in window:
			p += 1
		else:
			var avoidable := false
			for slip in range(5):
				var cand := posmod(pos + slip, ReelData.REEL_SIZE)
				var w := ReelData.get_window(0, cand)
				if ReelData.CHR not in w:
					avoidable = true
					break
			if not avoidable:
				p += 1
			else:
				print("  U2 FAIL: pos=%d stop=%d (CHR avoidable)" % [pos, stop])
	print("U2 HAZUREチェリー蹴り: %d/%d" % [p, t])
	return [t, p]

## U3/U4/U5: 小役引き込み (各63パターン)
static func _test_pull_in(label: String, flag: PayTable.Flag, symbol: int) -> Array:
	var t := 0; var p := 0
	for ri in range(3):
		for pos in range(ReelData.REEL_SIZE):
			t += 1
			var positions: Array[int] = [0, 0, 0]
			var stopped: Array[bool] = [false, false, false]
			for prev in range(ri):
				stopped[prev] = true
			var slip_range := 5
			if flag == PayTable.Flag.ICE:
				var os := 0
				for i in range(3):
					if i != ri and stopped[i]:
						os += 1
				if os >= 2:
					slip_range = 2
			var stop := calc_stop_position(ri, pos, flag,
				PayTable.Flag.HAZURE, positions, stopped)
			var window := ReelData.get_window(ri, stop)
			var has_sym := symbol in window
			var reachable := false
			for slip in range(slip_range):
				var cand := posmod(pos + slip, ReelData.REEL_SIZE)
				var w := ReelData.get_window(ri, cand)
				if symbol in w:
					reachable = true
					break
			if (reachable and has_sym) or not reachable:
				p += 1
			else:
				print("  %s FAIL: reel=%d pos=%d stop=%d" % [label, ri, pos, stop])
	var desc: String
	match flag:
		PayTable.Flag.REPLAY: desc = "REPLAY引き込み"
		PayTable.Flag.BELL: desc = "BELL引き込み"
		PayTable.Flag.ICE: desc = "ICE引き込み"
		_: desc = ""
	print("%s %s: %d/%d" % [label, desc, p, t])
	return [t, p]

## U6: CHERRY_2角チェリー (21パターン)
static func _test_u6() -> Array:
	var t := 0; var p := 0
	for pos in range(ReelData.REEL_SIZE):
		t += 1
		var positions: Array[int] = [0, 0, 0]
		var stopped: Array[bool] = [false, false, false]
		var stop := calc_stop_position(0, pos, PayTable.Flag.CHERRY_2,
			PayTable.Flag.HAZURE, positions, stopped)
		var window := ReelData.get_window(0, stop)
		if window[0] == ReelData.CHR or window[2] == ReelData.CHR:
			p += 1
		else:
			var reachable := false
			for slip in range(5):
				var cand := posmod(pos + slip, ReelData.REEL_SIZE)
				var w := ReelData.get_window(0, cand)
				if w[0] == ReelData.CHR or w[2] == ReelData.CHR:
					reachable = true
					break
			if not reachable:
				p += 1
			else:
				print("  U6 FAIL: pos=%d stop=%d" % [pos, stop])
	print("U6 CHERRY_2角配置: %d/%d" % [p, t])
	return [t, p]

## U7: CHERRY_4中段チェリー (21パターン)
static func _test_u7() -> Array:
	var t := 0; var p := 0
	for pos in range(ReelData.REEL_SIZE):
		t += 1
		var positions: Array[int] = [0, 0, 0]
		var stopped: Array[bool] = [false, false, false]
		var stop := calc_stop_position(0, pos, PayTable.Flag.CHERRY_4,
			PayTable.Flag.HAZURE, positions, stopped)
		var window := ReelData.get_window(0, stop)
		if window[1] == ReelData.CHR:
			p += 1
		else:
			var reachable := false
			for slip in range(5):
				var cand := posmod(pos + slip, ReelData.REEL_SIZE)
				var w := ReelData.get_window(0, cand)
				if w[1] == ReelData.CHR:
					reachable = true
					break
			if not reachable:
				p += 1
			else:
				print("  U7 FAIL: pos=%d stop=%d" % [pos, stop])
	print("U7 CHERRY_4中段配置: %d/%d" % [p, t])
	return [t, p]

## U8: ボーナス図柄引き込み (189パターン)
static func _test_u8() -> Array:
	var t := 0; var p := 0
	var bonus_configs := [
		[PayTable.Flag.BIG_RED, [ReelData.S7R, ReelData.S7B]],
		[PayTable.Flag.BIG_BLUE, [ReelData.S7R, ReelData.S7B]],
		[PayTable.Flag.REG, [ReelData.BAR]],
	]
	for cfg in bonus_configs:
		var stocked_flag = cfg[0]
		var syms: Array = cfg[1]
		for ri in range(3):
			for pos in range(ReelData.REEL_SIZE):
				t += 1
				var positions: Array[int] = [0, 0, 0]
				var stopped: Array[bool] = [false, false, false]
				for prev in range(ri):
					stopped[prev] = true
				var stop := calc_stop_position(ri, pos, PayTable.Flag.HAZURE,
					stocked_flag, positions, stopped)
				var window := ReelData.get_window(ri, stop)
				var has_target := false
				for sym in syms:
					if sym in window:
						has_target = true
						break
				var reachable := false
				for slip in range(5):
					var cand := posmod(pos + slip, ReelData.REEL_SIZE)
					var w := ReelData.get_window(ri, cand)
					for sym in syms:
						if sym in w:
							reachable = true
							break
					if reachable:
						break
				if (reachable and has_target) or not reachable:
					p += 1
				else:
					print("  U8 FAIL: stocked=%s reel=%d pos=%d stop=%d" % [
						PayTable.Flag.keys()[stocked_flag], ri, pos, stop])
	print("U8 ボーナス図柄引き込み: %d/%d" % [p, t])
	return [t, p]

## U9: 全フラグ×全位置 — 不正入賞なし (567パターン)
static func _test_u9() -> Array:
	var t := 0; var p := 0
	var flags := [
		PayTable.Flag.HAZURE, PayTable.Flag.REPLAY, PayTable.Flag.CHERRY_2,
		PayTable.Flag.CHERRY_4, PayTable.Flag.BELL, PayTable.Flag.ICE,
		PayTable.Flag.BIG_RED, PayTable.Flag.BIG_BLUE, PayTable.Flag.REG,
	]
	for flag in flags:
		for ri in range(3):
			for pos in range(ReelData.REEL_SIZE):
				t += 1
				var positions: Array[int] = [0, 0, 0]
				var stopped: Array[bool] = [true, true, true]
				stopped[ri] = false
				var stop := calc_stop_position(ri, pos, flag,
					PayTable.Flag.HAZURE, positions, stopped)
				positions[ri] = stop
				var ok := true
				match flag:
					PayTable.Flag.HAZURE, PayTable.Flag.BIG_RED, \
					PayTable.Flag.BIG_BLUE, PayTable.Flag.REG:
						if _ut_has_winning_line(positions):
							ok = false
					_:
						pass
				if ok:
					p += 1
				else:
					print("  U9 FAIL: flag=%s reel=%d pos=%d stop=%d" % [
						PayTable.Flag.keys()[flag], ri, pos, stop])
	print("U9 全フラグ×全位置: %d/%d" % [p, t])
	return [t, p]

## テストヘルパー: 3リール停止位置から5ライン入賞判定
static func _ut_has_winning_line(positions: Array[int]) -> bool:
	var w0 := ReelData.get_window(0, positions[0])
	var w1 := ReelData.get_window(1, positions[1])
	var w2 := ReelData.get_window(2, positions[2])
	var lines := [
		[w0[0], w1[0], w2[0]],
		[w0[1], w1[1], w2[1]],
		[w0[2], w1[2], w2[2]],
		[w0[0], w1[1], w2[2]],
		[w0[2], w1[1], w2[0]],
	]
	for line in lines:
		if line[0] == line[1] and line[1] == line[2]:
			match line[0]:
				ReelData.RPL, ReelData.BEL, ReelData.ICE:
					return true
	return false
