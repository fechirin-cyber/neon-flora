extends Control
## ゲーム画面制御（プリプロ: テキストUI + 図柄画像 + ボタンパネル + 消灯/フラッシュ演出）

var _bet_done: bool = false
var _blackout_tween: Tween
var _flash_tween: Tween
var _reel_cells: Array = []  # [reel_idx][row] = TextureRect
var _loaded_textures: Dictionary = {}

# ボタン色定数 (M-6)
const COLOR_BET_ACTIVE := Color(0.0, 1.0, 0.53)      # #00FF88
const COLOR_LEVER_ACTIVE := Color(1.0, 0.843, 0.0)    # #FFD700
const COLOR_STOP_ACTIVE := Color(0.0, 0.83, 1.0)      # #00D4FF
const COLOR_DISABLED := Color(0.176, 0.176, 0.267)     # #2D2D44

@onready var _state_label: Label = $StateLabel
@onready var _credit_label: Label = $CreditLabel
@onready var _reel_label: Label = $ReelLabel
@onready var _info_label: Label = $InfoLabel
@onready var _blackout_overlay: ColorRect = $BlackoutOverlay
@onready var _flash_overlay: ColorRect = $FlashOverlay
@onready var _reel_display: Control = $ReelDisplay

# ボタンパネル
@onready var _bet_btn: Button = $ButtonPanel/BetButton
@onready var _lever_btn: Button = $ButtonPanel/LeverButton
@onready var _stop_l_btn: Button = $ButtonPanel/StopLButton
@onready var _stop_c_btn: Button = $ButtonPanel/StopCButton
@onready var _stop_r_btn: Button = $ButtonPanel/StopRButton

func _ready() -> void:
	SlotEngine.game_state_changed.connect(_on_state_changed)
	SlotEngine.credit_changed.connect(_on_credit_changed)
	SlotEngine.flag_determined.connect(_on_flag_determined)
	SlotEngine.reel_stop_calculated.connect(_on_reel_stopped)
	SlotEngine.all_reels_stopped.connect(_on_all_stopped)
	SlotEngine.payout_started.connect(_on_payout_started)
	SlotEngine.payout_finished.connect(_on_payout_finished)
	SlotEngine.bonus_triggered.connect(_on_bonus_triggered)
	SlotEngine.bonus_ended.connect(_on_bonus_ended)
	SlotEngine.rt_started.connect(_on_rt_started)
	SlotEngine.rt_ended.connect(_on_rt_ended)
	SlotEngine.reach_me_detected.connect(_on_reach_me)
	SlotEngine.delay_fired.connect(_on_delay_fired)
	SlotEngine.tamaya_fired.connect(_on_tamaya_fired)

	# ボタンシグナル接続
	_bet_btn.pressed.connect(_do_bet)
	_lever_btn.pressed.connect(_do_lever)
	_stop_l_btn.pressed.connect(_do_stop.bind(0))
	_stop_c_btn.pressed.connect(_do_stop.bind(1))
	_stop_r_btn.pressed.connect(_do_stop.bind(2))

	# ボタンスタイル初期化 (M-6)
	_init_button_style(_bet_btn, COLOR_BET_ACTIVE)
	_init_button_style(_lever_btn, COLOR_LEVER_ACTIVE)
	_init_button_style(_stop_l_btn, COLOR_STOP_ACTIVE)
	_init_button_style(_stop_c_btn, COLOR_STOP_ACTIVE)
	_init_button_style(_stop_r_btn, COLOR_STOP_ACTIVE)

	# 図柄画像セットアップ (M-5)
	_setup_reel_display()
	_update_display()

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return

	match event.keycode:
		KEY_B:
			_do_bet()
		KEY_SPACE:
			_do_lever()
		KEY_Z:
			_do_stop(0)
		KEY_X:
			_do_stop(1)
		KEY_C:
			_do_stop(2)
		KEY_D:
			SlotEngine.debug_start_bonus_now("BIG")
		KEY_R:
			SlotEngine.debug_start_bonus_now("REG")
		KEY_T:
			SlotEngine.debug_add_credit(1000)
		KEY_P:
			SlotEngine.debug_write_state_file()
			_info_label.text = "State written to debug_state.json"

func _do_bet() -> void:
	var state := SlotEngine.game_state
	if state != SlotEngine.GameState.IDLE and state != SlotEngine.GameState.BONUS and state != SlotEngine.GameState.RT:
		return
	if SlotEngine.do_bet(3):
		_bet_done = true
		AudioManager.play_se("bet_insert")
		_update_display()

func _do_lever() -> void:
	if not _bet_done:
		return
	_bet_done = false
	_reel_label.text = ""
	# Tween kill管理 (M-3)
	if _blackout_tween and _blackout_tween.is_valid():
		_blackout_tween.kill()
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()
	_blackout_overlay.color.a = 0.0
	_flash_overlay.color.a = 0.0
	_clear_reel_display()
	AudioManager.play_se("lever_pull")
	SlotEngine.pull_lever()

func _do_stop(reel_idx: int) -> void:
	var state := SlotEngine.game_state
	if state != SlotEngine.GameState.SPINNING and state != SlotEngine.GameState.STOPPING:
		return
	# プリプロ: ランダム停止位置（目押し相当）
	var pressed_pos := randi() % ReelData.REEL_SIZE
	var stop_se := ["reel_stop_l", "reel_stop_c", "reel_stop_r"]
	AudioManager.play_se(stop_se[reel_idx])
	SlotEngine.stop_reel(reel_idx, pressed_pos)

# --- Signal handlers ---
func _on_state_changed(_new_state: SlotEngine.GameState) -> void:
	_update_display()

func _on_credit_changed(_new_credit: int) -> void:
	_update_display()

func _on_flag_determined(flag: PayTable.Flag, production: Dictionary) -> void:
	var flag_name: String = PayTable.Flag.keys()[flag]
	var blackout: int = production.get("blackout", 0)
	_info_label.text = "Flag: %s | 消灯: %d" % [flag_name, blackout]

func _on_delay_fired() -> void:
	_info_label.text += " | DELAY!"

func _on_tamaya_fired() -> void:
	_info_label.text += " | TAMAYA!"
	AudioManager.play_se("tamaya")

func _on_reel_stopped(reel_idx: int, _target_pos: int, window: Array) -> void:
	# テキスト表示
	var names := ["LEFT", "CENTER", "RIGHT"]
	var symbols: Array[String] = []
	for s in window:
		symbols.append(SymbolTable.get_symbol_name(s))
	var line := "%s: [%s | %s | %s]" % [names[reel_idx], symbols[0], symbols[1], symbols[2]]
	if _reel_label.text == "":
		_reel_label.text = line
	else:
		_reel_label.text += "\n" + line

	# 図柄画像表示 (M-5)
	if reel_idx < _reel_cells.size():
		for row in range(3):
			var sym_id: int = window[row]
			_update_reel_cell(reel_idx, row, sym_id)

	_update_display()

func _on_all_stopped() -> void:
	var blackout_level: int = SlotEngine.current_production.get("blackout", 0)
	_play_blackout(blackout_level)
	if blackout_level >= 3:
		var flash_type: String = SlotEngine.current_production.get("flash", "SPARK")
		_play_flash(flash_type)

func _on_payout_started(amount: int, flag: PayTable.Flag) -> void:
	if flag == PayTable.Flag.REPLAY:
		_info_label.text = "REPLAY!"
		AudioManager.play_se("replay_win")
		_bet_done = true
	elif amount > 0:
		_info_label.text = "WIN: %d枚" % amount
		match flag:
			PayTable.Flag.CHERRY_2, PayTable.Flag.CHERRY_4:
				AudioManager.play_se("cherry_win")
			PayTable.Flag.BELL:
				AudioManager.play_se("bell_win")
			PayTable.Flag.ICE:
				AudioManager.play_se("ice_win")
			_:
				AudioManager.play_medal_payout(amount)

func _on_payout_finished() -> void:
	_update_display()

func _on_bonus_triggered(bonus_type: String) -> void:
	_info_label.text = "*** %s BONUS START! ***" % bonus_type
	if bonus_type == "BIG":
		AudioManager.play_se("big_fanfare")
	else:
		AudioManager.play_se("reg_fanfare")

func _on_bonus_ended(bonus_type: String, total_payout: int) -> void:
	_info_label.text = "%s BONUS END — Total: %d枚" % [bonus_type, total_payout]
	AudioManager.play_se("bonus_end")

func _on_rt_started(max_games: int) -> void:
	_info_label.text = "RT START (%dG)" % max_games
	AudioManager.play_se("rt_start")

func _on_rt_ended() -> void:
	_info_label.text = "RT END"

func _on_reach_me(pattern_name: String) -> void:
	_info_label.text = "REACH ME: %s" % pattern_name
	AudioManager.play_se("reach_me")

# --- VFX: 消灯演出（4段階、ColorRectアルファ制御、Tween kill管理） ---
func _play_blackout(level: int) -> void:
	var target_alpha := [0.0, 0.3, 0.55, 0.8]
	if level < 0 or level >= target_alpha.size():
		return
	if level == 0:
		_blackout_overlay.color.a = 0.0
		return

	AudioManager.play_se("blackout")
	if _blackout_tween and _blackout_tween.is_valid():
		_blackout_tween.kill()
	_blackout_tween = create_tween()
	_blackout_tween.tween_property(_blackout_overlay, "color:a", target_alpha[level], 0.3)
	_blackout_tween.tween_interval(1.0)
	_blackout_tween.tween_property(_blackout_overlay, "color:a", 0.0, 0.5)

# --- VFX: フラッシュ演出（Tween kill管理） ---
func _play_flash(flash_type: String) -> void:
	var flash_color := Color.WHITE
	match flash_type:
		"SPARK":
			flash_color = Color.WHITE
		"GLITCH":
			flash_color = Color(0.0, 0.83, 1.0)
		"NEON_SIGN":
			flash_color = Color(0.0, 1.0, 0.53)
		"STROBE":
			flash_color = Color(1.0, 0.08, 0.58)
		"DROP":
			flash_color = Color(1.0, 0.843, 0.0)
		"BLOOM":
			flash_color = Color(0.69, 0.31, 1.0)
		"STARMINE":
			flash_color = Color(1.0, 0.2, 0.2)
		"TAMAYA":
			flash_color = Color(1.0, 0.843, 0.0)

	_flash_overlay.color = Color(flash_color.r, flash_color.g, flash_color.b, 0.0)

	if flash_type in ["BLOOM", "STARMINE", "TAMAYA"]:
		AudioManager.play_se("flash_premium")
	else:
		AudioManager.play_se("flash")

	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()
	_flash_tween = create_tween()
	_flash_tween.tween_property(_flash_overlay, "color:a", 0.6, 0.08)
	_flash_tween.tween_property(_flash_overlay, "color:a", 0.0, 0.4)

	if flash_type == "TAMAYA":
		_flash_tween.tween_interval(0.15)
		_flash_tween.tween_property(_flash_overlay, "color:a", 0.8, 0.05)
		_flash_tween.tween_property(_flash_overlay, "color:a", 0.0, 0.6)

# --- Reel Display: 図柄画像表示 (M-5) ---
func _setup_reel_display() -> void:
	var tex_map := {
		ReelData.S7R: "res://assets/images/symbols/symbol_s7r.png",
		ReelData.S7B: "res://assets/images/symbols/symbol_s7b.png",
		ReelData.BAR: "res://assets/images/symbols/symbol_bar.png",
		ReelData.CHR: "res://assets/images/symbols/symbol_chr.png",
		ReelData.BEL: "res://assets/images/symbols/symbol_bel.png",
		ReelData.ICE: "res://assets/images/symbols/symbol_ice.png",
		ReelData.RPL: "res://assets/images/symbols/symbol_rpl.png",
	}
	for sym_id in tex_map:
		var path: String = tex_map[sym_id]
		if ResourceLoader.exists(path):
			_loaded_textures[sym_id] = load(path)

	var cell_w := 240.0
	var cell_h := 105.0
	var gap_x := 15.0
	var gap_y := 8.0
	var total_w := cell_w * 3 + gap_x * 2
	var total_h := cell_h * 3 + gap_y * 2
	var start_x := (840.0 - total_w) / 2.0
	var start_y := (360.0 - total_h) / 2.0

	for reel_idx in range(3):
		var col: Array = []
		for row in range(3):
			var cell := TextureRect.new()
			cell.position = Vector2(
				start_x + reel_idx * (cell_w + gap_x),
				start_y + row * (cell_h + gap_y)
			)
			cell.size = Vector2(cell_w, cell_h)
			cell.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			cell.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			_reel_display.add_child(cell)
			col.append(cell)
		_reel_cells.append(col)

func _update_reel_cell(reel_idx: int, row: int, sym_id: int) -> void:
	var cell: TextureRect = _reel_cells[reel_idx][row]
	if _loaded_textures.has(sym_id):
		cell.texture = _loaded_textures[sym_id]
	else:
		cell.self_modulate = SymbolTable.get_color(sym_id)

func _clear_reel_display() -> void:
	for col in _reel_cells:
		for cell in col:
			cell.texture = null
			cell.self_modulate = Color.WHITE

# --- Button Style: 有効/無効の視覚区別 (M-6) ---
func _init_button_style(btn: Button, active_color: Color) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = active_color
	normal.set_corner_radius_all(6)

	var hover := normal.duplicate()
	hover.bg_color = active_color.lightened(0.15)

	var pressed := normal.duplicate()
	pressed.bg_color = active_color.darkened(0.2)

	var disabled := StyleBoxFlat.new()
	disabled.bg_color = COLOR_DISABLED
	disabled.set_corner_radius_all(6)

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("disabled", disabled)

# --- Display ---
func _update_display() -> void:
	var state_name: String = SlotEngine.GameState.keys()[SlotEngine.game_state]
	_state_label.text = "State: %s | G: %d | BIG: %d | REG: %d" % [
		state_name, GameData.total_games, GameData.big_count, GameData.reg_count]

	var cr_text := "CREDIT: %d | IN: %d | OUT: %d" % [
		GameData.credit, GameData.total_in, GameData.total_out]
	if SlotEngine.is_in_bonus():
		var remaining := SlotEngine.get_bonus_remaining()
		var played := SlotEngine.get_bonus_games_played()
		cr_text += " | BONUS: %d/%dG PAY:%d" % [played, played + remaining, SlotEngine.get_bonus_payout()]
	if SlotEngine.is_rt_active():
		cr_text += " | RT: %dG" % SlotEngine.get_rt_remaining()
	_credit_label.text = cr_text

	_update_buttons()

func _update_buttons() -> void:
	var state := SlotEngine.game_state
	match state:
		SlotEngine.GameState.IDLE, SlotEngine.GameState.BONUS, SlotEngine.GameState.RT:
			_bet_btn.disabled = _bet_done or GameData.credit < 3
			_lever_btn.disabled = not _bet_done
			_stop_l_btn.disabled = true
			_stop_c_btn.disabled = true
			_stop_r_btn.disabled = true
		SlotEngine.GameState.SPINNING, SlotEngine.GameState.STOPPING:
			_bet_btn.disabled = true
			_lever_btn.disabled = true
			_stop_l_btn.disabled = SlotEngine.reel_stopped[0]
			_stop_c_btn.disabled = SlotEngine.reel_stopped[1]
			_stop_r_btn.disabled = SlotEngine.reel_stopped[2]
		_:
			_bet_btn.disabled = true
			_lever_btn.disabled = true
			_stop_l_btn.disabled = true
			_stop_c_btn.disabled = true
			_stop_r_btn.disabled = true
