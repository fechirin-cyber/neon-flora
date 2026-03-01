extends Node
## 内部抽選・フラグ管理・滑り制御・状態遷移 (Autoload: SlotEngine)

enum GameState { IDLE, WAITING, SPINNING, STOPPING, PAYING, BONUS, RT }

# === シグナル ===
signal game_state_changed(new_state: GameState)
signal credit_changed(new_credit: int)
signal flag_determined(flag: PayTable.Flag, production: Dictionary)
signal reel_stop_calculated(reel_idx: int, target_pos: int, window: Array)
signal all_reels_stopped()
signal payout_started(amount: int, flag: PayTable.Flag)
signal payout_finished()
signal bonus_triggered(bonus_type: String)
signal bonus_ended(bonus_type: String, total_payout: int)
signal rt_started(max_games: int)
signal rt_ended()
signal wait_started(duration: float)
signal wait_ended()
signal delay_fired()
signal tamaya_fired()
signal reach_me_detected(pattern_name: String)

# === 公開状態 ===
var game_state: GameState = GameState.IDLE
var current_flag: PayTable.Flag = PayTable.Flag.HAZURE
var current_production: Dictionary = {}

# --- リール状態 ---
var reel_positions: Array[int] = [0, 0, 0]
var reel_stopped: Array[bool] = [false, false, false]
var _stopped_count: int = 0

# --- ヘルパー ---
var _bonus: BonusController = BonusController.new()
var _wait_timer: WaitTimer = WaitTimer.new()

# === BET処理 ===
func do_bet(amount: int = 3) -> bool:
	if game_state in [GameState.SPINNING, GameState.STOPPING, GameState.PAYING, GameState.WAITING]:
		return false
	if GameData.credit < amount:
		return false
	GameData.credit -= amount
	GameData.total_in += amount
	credit_changed.emit(GameData.credit)
	return true

# === レバーON ===
func pull_lever() -> void:
	if game_state in [GameState.SPINNING, GameState.STOPPING, GameState.PAYING, GameState.WAITING]:
		return

	# ウェイトチェック
	var current_time := Time.get_ticks_msec() / 1000.0
	if _wait_timer.is_waiting(current_time):
		var remaining := _wait_timer.get_remaining(current_time)
		_change_state(GameState.WAITING)
		wait_started.emit(remaining)
		await get_tree().create_timer(remaining).timeout
		wait_ended.emit()

	_wait_timer.mark_lever_pulled(Time.get_ticks_msec() / 1000.0)

	# ゲーム数カウント（通常時のみ）
	if not _bonus.is_in_bonus():
		GameData.total_games += 1
		_bonus.last_bonus_between += 1
		# RT消化
		if _bonus.rt_active:
			if _bonus.tick_rt():
				rt_ended.emit()

	# 内部抽選
	current_flag = _lottery()

	# ボーナス成立チェック
	if PayTable.is_bonus_flag(current_flag) and not _bonus.is_bonus_stocked():
		if _bonus.rt_active:
			_bonus.cancel_rt()
			rt_ended.emit()
		_bonus.stock_bonus(current_flag)
		current_flag = _lottery_small_role_only()
	elif PayTable.is_bonus_flag(current_flag) and _bonus.is_bonus_stocked():
		# ストック中に再度ボーナス当選 → ハズレに差し替え
		current_flag = PayTable.Flag.HAZURE

	# 演出選択
	var has_bonus := _bonus.is_bonus_stocked()
	var effect_flag := current_flag
	if has_bonus and current_flag == PayTable.Flag.HAZURE:
		effect_flag = _bonus.bonus_flag_stocked
	current_production = ProductionTable.select_production(effect_flag, has_bonus)

	# リール状態リセット
	reel_stopped = [false, false, false]
	_stopped_count = 0

	# 状態遷移
	_change_state(GameState.SPINNING)
	flag_determined.emit(current_flag, current_production)

# === リール停止 ===
func stop_reel(reel_idx: int, pressed_pos: int) -> void:
	if game_state != GameState.SPINNING and game_state != GameState.STOPPING:
		return
	if reel_stopped[reel_idx]:
		return

	var target := ReelLogic.calc_stop_position(
		reel_idx, pressed_pos, current_flag,
		_bonus.bonus_flag_stocked, reel_positions, reel_stopped)
	reel_positions[reel_idx] = target
	reel_stopped[reel_idx] = true
	_stopped_count += 1

	var window := ReelData.get_window(reel_idx, target)
	reel_stop_calculated.emit(reel_idx, target, window)

	if _stopped_count == 1:
		_change_state(GameState.STOPPING)

	if _stopped_count >= 3:
		_on_all_stopped()

# === 全リール停止後の入賞判定（5ライン対応） ===
func _on_all_stopped() -> void:
	all_reels_stopped.emit()

	var windows: Array = []
	for i in range(3):
		windows.append(ReelData.get_window(i, reel_positions[i]))

	# リーチ目検出
	if _bonus.is_bonus_stocked():
		var reach_me := ReachMeTable.check_reach_me(windows)
		if reach_me != "":
			reach_me_detected.emit(reach_me)

	# 入賞判定（5ライン）
	var payout := _judge_payout(windows)
	var is_replay := (current_flag == PayTable.Flag.REPLAY)

	if is_replay:
		payout_started.emit(0, current_flag)
	elif payout > 0:
		GameData.credit += payout
		GameData.total_out += payout
		credit_changed.emit(GameData.credit)
		_change_state(GameState.PAYING)
		payout_started.emit(payout, current_flag)

	# ボーナス中のゲーム数管理（リプレイ除外）
	if _bonus.is_in_bonus():
		if _bonus.tick_bonus_game(is_replay, payout):
			var result := _bonus.end_bonus()
			bonus_ended.emit(result["type"], result["payout"])
			if result["type"] == "BIG":
				_bonus.start_rt(result["internal_flag"])
				_change_state(GameState.RT)
				rt_started.emit(PayTable.RT_MAX_GAMES)
			else:
				_change_state(GameState.IDLE)
			payout_finished.emit()
			_save_game()
			return

	# ボーナス図柄揃い判定（5ライン・統合7対応）
	if _bonus.is_bonus_stocked() and _check_bonus_aligned(windows):
		_start_bonus()
		return

	# ゲーム終了
	_save_game()

	if _bonus.is_in_bonus():
		_change_state(GameState.BONUS)
		payout_finished.emit()
	elif _bonus.rt_active:
		_change_state(GameState.RT)
		payout_finished.emit()
	else:
		_change_state(GameState.IDLE)
		payout_finished.emit()

# === 内部抽選 ===
func _lottery() -> PayTable.Flag:
	var table: Dictionary
	if _bonus.bonus_type == "BIG":
		table = ProbabilityTable.get_big_table()
	elif _bonus.bonus_type == "REG":
		table = ProbabilityTable.get_reg_table()
	elif _bonus.rt_active:
		table = ProbabilityTable.get_rt_table(GameData.setting, _bonus.rt_bonus_rate)
	else:
		table = ProbabilityTable.get_normal_table(GameData.setting)
	return ProbabilityTable.lottery(table)

func _lottery_small_role_only() -> PayTable.Flag:
	var table := ProbabilityTable.get_normal_table(GameData.setting)
	table.erase(PayTable.Flag.REG)
	table.erase(PayTable.Flag.BIG_RED)
	table.erase(PayTable.Flag.BIG_BLUE)
	return ProbabilityTable.lottery(table)

# === 入賞判定（5ライン） ===
func _judge_payout(windows: Array) -> int:
	var lw: Array = windows[0]
	var cw: Array = windows[1]
	var rw: Array = windows[2]

	# チェリー判定（LEFTリール位置依存）
	if lw[1] == ReelData.CHR:
		return 2  # 中段チェリー: 2枚×1ライン
	if lw[0] == ReelData.CHR or lw[2] == ReelData.CHR:
		return 4  # 角チェリー: 2枚×2ライン

	# 5ライン3揃い判定
	var lines := [
		[lw[0], cw[0], rw[0]],  # L1: 横上段
		[lw[1], cw[1], rw[1]],  # L2: 横中段
		[lw[2], cw[2], rw[2]],  # L3: 横下段
		[lw[0], cw[1], rw[2]],  # L4: 斜め右下がり
		[lw[2], cw[1], rw[0]],  # L5: 斜め右上がり
	]

	var total_payout := 0
	for line in lines:
		if line[0] == line[1] and line[1] == line[2]:
			match line[0]:
				ReelData.BEL: total_payout += 10
				ReelData.ICE: total_payout += 15
	return total_payout

## ボーナス図柄揃い判定（5ライン・統合7: 赤7/青7どちらでもBIG成立）
func _check_bonus_aligned(windows: Array) -> bool:
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
		if line[0] != line[1] or line[1] != line[2]:
			continue
		match _bonus.bonus_flag_stocked:
			PayTable.Flag.BIG_RED, PayTable.Flag.BIG_BLUE:
				# 統合揃え: 赤7 or 青7
				if line[0] == ReelData.S7R or line[0] == ReelData.S7B:
					return true
			PayTable.Flag.REG:
				if line[0] == ReelData.BAR:
					return true
	return false

func _start_bonus() -> void:
	var result := _bonus.start_bonus()
	if result["is_big"]:
		GameData.big_count += 1
	else:
		GameData.reg_count += 1
	GameData.add_bonus_history(result["type"], result["between"])
	_change_state(GameState.BONUS)
	bonus_triggered.emit(result["type"])
	payout_finished.emit()

func _change_state(new_state: GameState) -> void:
	game_state = new_state
	game_state_changed.emit(new_state)

func _save_game() -> void:
	GameData.add_history_point()
	GameData.save()

# === 状態取得 ===
func is_bonus_stocked() -> bool:
	return _bonus.is_bonus_stocked()

func get_bonus_type() -> String:
	return _bonus.bonus_type

func get_bonus_remaining() -> int:
	return _bonus.get_bonus_remaining()

func get_rt_remaining() -> int:
	return _bonus.rt_remaining if _bonus.rt_active else 0

func is_rt_active() -> bool:
	return _bonus.rt_active

func get_bonus_payout() -> int:
	return _bonus.bonus_payout

func get_bonus_games_played() -> int:
	return _bonus.bonus_games_played

func get_last_bonus_between() -> int:
	return _bonus.last_bonus_between

func is_in_bonus() -> bool:
	return _bonus.is_in_bonus()

# === 設定変更 ===
func change_setting(s: int) -> void:
	GameData.setting = clampi(s, 1, 6)
	GameData.save()

# === デバッグ ===
func debug_force_bonus(flag: PayTable.Flag) -> void:
	if PayTable.is_bonus_flag(flag):
		_bonus.stock_bonus(flag)

func debug_start_bonus_now(type: String) -> void:
	if type == "BIG":
		_bonus.stock_bonus(PayTable.Flag.BIG_RED)
	elif type == "REG":
		_bonus.stock_bonus(PayTable.Flag.REG)
	_start_bonus()

func debug_add_credit(amount: int) -> void:
	GameData.credit += amount
	GameData.save()
	credit_changed.emit(GameData.credit)

func debug_get_state() -> Dictionary:
	return {
		"game_state": GameState.keys()[game_state],
		"current_flag": current_flag,
		"bonus_stocked": _bonus.bonus_flag_stocked,
		"bonus_type": _bonus.bonus_type,
		"bonus_type_internal": _bonus.bonus_type_internal,
		"bonus_games_played": _bonus.bonus_games_played,
		"bonus_games_max": _bonus.bonus_games_max,
		"bonus_payout": _bonus.bonus_payout,
		"rt_active": _bonus.rt_active,
		"rt_remaining": _bonus.rt_remaining,
		"rt_bonus_rate": _bonus.rt_bonus_rate,
		"reel_positions": reel_positions,
		"credit": GameData.credit,
		"total_games": GameData.total_games,
		"wait_remaining": _wait_timer.get_remaining(Time.get_ticks_msec() / 1000.0),
		"big_count": GameData.big_count,
		"reg_count": GameData.reg_count,
		"total_in": GameData.total_in,
		"total_out": GameData.total_out,
		"last_production": current_production,
	}

func debug_write_state_file(extra: Dictionary = {}) -> void:
	var path := ProjectSettings.globalize_path("res://").path_join("windows/debug_state.json")
	var state := debug_get_state()
	state.merge(extra)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(state))
		file.close()
