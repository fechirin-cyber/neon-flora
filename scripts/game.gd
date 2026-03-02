extends Control
## ゲーム画面制御（α: §8.2レイアウト + 7セグ + SubViewportリール + 消灯/フラッシュ演出）

var _bet_done: bool = false
var _delay_pending: bool = false
var _blackout_tween: Tween
var _flash_tween: Tween
var _wait_tick_timer: Timer

# ボタン色定数 (§8.4)
const COLOR_BET_ACTIVE := Color(1.0, 0.843, 0.0)       # #FFD700 ゴールド
const COLOR_LEVER_ACTIVE := Color(1.0, 0.702, 0.278)    # #FFB347 オレンジ
const COLOR_STOP_ACTIVE := Color(0.918, 0.918, 1.0)     # #EAEAFF 白
const COLOR_DISABLED := Color(0.176, 0.176, 0.267)      # #2D2D44

# ボタンテキスト色 (PM-3: WCAG AA 4.5:1以上)
const COLOR_BET_TEXT := Color(0.1, 0.08, 0.0)           # 暗褐色 on ゴールド
const COLOR_LEVER_TEXT := Color(0.12, 0.06, 0.0)        # 暗褐色 on オレンジ
const COLOR_STOP_TEXT := Color(0.06, 0.06, 0.12)        # 暗紺 on 白

# LEDインジケータ色 (§8.4)
const COLOR_LED_ACTIVE := Color(0.0, 1.0, 0.533)       # #00FF88
const COLOR_LED_INACTIVE := Color(0.102, 0.102, 0.118)  # #1A1A1E

@onready var _info_label: Label = $InfoLabel
@onready var _debug_label: Label = $DebugLabel
@onready var _blackout_overlay: ColorRect = $BlackoutOverlay
@onready var _flash_overlay: ColorRect = $FlashOverlay
@onready var _reel_renderer: Control = $ReelRenderer

# ボタンパネル
@onready var _bet_btn: Button = $ButtonPanel/BetButton
@onready var _lever_btn: Button = $ButtonPanel/LeverButton
@onready var _stop_l_btn: Button = $ButtonPanel/StopLButton
@onready var _stop_c_btn: Button = $ButtonPanel/StopCButton
@onready var _stop_r_btn: Button = $ButtonPanel/StopRButton

# 7セグ表示
var _credit_seg: SevenSegDisplay
var _payout_seg: SevenSegDisplay
var _bet_seg: SevenSegDisplay

# データカウンター
var _big_label: Label
var _reg_label: Label
var _diff_label: Label
var _games_label: Label

# LEDインジケータ (PM-4)
var _led_rects: Dictionary = {}  # Button -> ColorRect

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
	SlotEngine.wait_started.connect(_on_wait_started)
	SlotEngine.wait_ended.connect(_on_wait_ended)

	# ボタンシグナル接続
	_bet_btn.pressed.connect(_do_bet)
	_lever_btn.pressed.connect(_do_lever)
	_stop_l_btn.pressed.connect(_do_stop.bind(0))
	_stop_c_btn.pressed.connect(_do_stop.bind(1))
	_stop_r_btn.pressed.connect(_do_stop.bind(2))

	# ボタンスタイル初期化 (§8.4)
	_init_button_style(_bet_btn, COLOR_BET_ACTIVE, COLOR_BET_TEXT)
	_init_button_style(_lever_btn, COLOR_LEVER_ACTIVE, COLOR_LEVER_TEXT)
	_init_button_style(_stop_l_btn, COLOR_STOP_ACTIVE, COLOR_STOP_TEXT)
	_init_button_style(_stop_c_btn, COLOR_STOP_ACTIVE, COLOR_STOP_TEXT)
	_init_button_style(_stop_r_btn, COLOR_STOP_ACTIVE, COLOR_STOP_TEXT)

	# LEDインジケータ初期化 (PM-4: §8.4)
	_setup_led_indicators()

	# ゲーム背景画像適用
	_setup_game_background()

	# クロームフレーム (§8.3)
	_setup_chrome_frame()

	# 7セグ表示セットアップ (§8.5)
	_setup_seven_seg()

	# データカウンターセットアップ
	_setup_data_counter()

	# S-5: 初期BGM再生
	AudioManager.play_bgm("normal", 0.0)

	# S-2: 中断復帰
	SlotEngine.restore_from_save()

	_update_display()

# --- 7セグ表示セットアップ (§8.5) ---
func _setup_seven_seg() -> void:
	var panel: Control = $SevenSegPanel
	var panel_w := 900.0
	var seg_h := 80.0

	# CREDIT: 4桁 (左寄り)
	_credit_seg = SevenSegDisplay.new()
	_credit_seg.position = Vector2(115.0, 0.0)
	_credit_seg.setup(Vector2(200.0, seg_h), 4, "CREDIT")
	panel.add_child(_credit_seg)

	# PAYOUT: 3桁 (中央)
	_payout_seg = SevenSegDisplay.new()
	_payout_seg.position = Vector2(350.0, 0.0)
	_payout_seg.setup(Vector2(200.0, seg_h), 3, "PAYOUT")
	panel.add_child(_payout_seg)

	# BET: 1桁 (右寄り)
	_bet_seg = SevenSegDisplay.new()
	_bet_seg.position = Vector2(585.0, 0.0)
	_bet_seg.setup(Vector2(200.0, seg_h), 1, "BET")
	panel.add_child(_bet_seg)

# --- データカウンター ---
func _setup_data_counter() -> void:
	var panel: Control = $DataCounterPanel
	var bg := ColorRect.new()
	bg.size = Vector2(900.0, 80.0)
	bg.color = Color(0.02, 0.02, 0.06, 1.0)
	panel.add_child(bg)

	var font_size := 22
	var label_color := Color(0.0, 1.0, 0.53, 0.7)

	_games_label = Label.new()
	_games_label.position = Vector2(30.0, 10.0)
	_games_label.size = Vector2(200.0, 30.0)
	_games_label.add_theme_font_size_override("font_size", font_size)
	_games_label.add_theme_color_override("font_color", label_color)
	_games_label.text = "G: 0"
	panel.add_child(_games_label)

	_big_label = Label.new()
	_big_label.position = Vector2(30.0, 44.0)
	_big_label.size = Vector2(200.0, 30.0)
	_big_label.add_theme_font_size_override("font_size", font_size)
	_big_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3, 0.8))
	_big_label.text = "BIG: 0"
	panel.add_child(_big_label)

	_reg_label = Label.new()
	_reg_label.position = Vector2(250.0, 44.0)
	_reg_label.size = Vector2(200.0, 30.0)
	_reg_label.add_theme_font_size_override("font_size", font_size)
	_reg_label.add_theme_color_override("font_color", Color(0.3, 0.5, 1.0, 0.8))
	_reg_label.text = "REG: 0"
	panel.add_child(_reg_label)

	_diff_label = Label.new()
	_diff_label.position = Vector2(500.0, 10.0)
	_diff_label.size = Vector2(370.0, 60.0)
	_diff_label.add_theme_font_size_override("font_size", font_size)
	_diff_label.add_theme_color_override("font_color", label_color)
	_diff_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_diff_label.text = "DIFF: +0"
	panel.add_child(_diff_label)

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
		KEY_U:
			ReelLogic._run_unit_tests()
			_info_label.text = "Unit tests — see console output"

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
	_delay_pending = false
	# Tween kill管理 (M-3)
	if _blackout_tween and _blackout_tween.is_valid():
		_blackout_tween.kill()
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()
	_blackout_overlay.color.a = 0.0
	_flash_overlay.color.a = 0.0
	AudioManager.play_se("lever_pull")
	SlotEngine.pull_lever()
	# PM-7: reel_start SEは_on_state_changed(SPINNING)で再生（delay_pendingタイミング問題回避）

func _do_stop(reel_idx: int) -> void:
	var state := SlotEngine.game_state
	if state != SlotEngine.GameState.SPINNING and state != SlotEngine.GameState.STOPPING:
		return
	# CRITICAL FIX: ReelStripから実際の中段表示位置を取得（ランダム値ではなく）
	var strip = _reel_renderer.get_strip(reel_idx)
	var pressed_pos: int = strip.get_current_center_pos() if strip else randi() % ReelData.REEL_SIZE
	var stop_se := ["reel_stop_l", "reel_stop_c", "reel_stop_r"]
	AudioManager.play_se(stop_se[reel_idx])
	SlotEngine.stop_reel(reel_idx, pressed_pos)

# --- Signal handlers ---
func _on_state_changed(new_state: SlotEngine.GameState) -> void:
	# PM-7: reel_start SEをSPINNING遷移時に再生（delay_pendingが正しく設定された後）
	if new_state == SlotEngine.GameState.SPINNING:
		if _delay_pending:
			get_tree().create_timer(0.4).timeout.connect(
				func() -> void: AudioManager.play_se("reel_start"))
		else:
			AudioManager.play_se("reel_start")
	_update_display()

func _on_credit_changed(_new_credit: int) -> void:
	_update_display()

func _on_flag_determined(flag: PayTable.Flag, production: Dictionary) -> void:
	var flag_name: String = PayTable.Flag.keys()[flag]
	var blackout: int = production.get("blackout", 0)
	_info_label.text = "Flag: %s | BL: %d" % [flag_name, blackout]

func _on_delay_fired() -> void:
	_delay_pending = true
	_info_label.text += " | DELAY!"

func _on_tamaya_fired() -> void:
	_info_label.text += " | TAMAYA!"
	AudioManager.play_se("tamaya")

func _on_reel_stopped(reel_idx: int, _target_pos: int, window: Array) -> void:
	var names := ["L", "C", "R"]
	var symbols: Array[String] = []
	for s in window:
		symbols.append(SymbolTable.get_symbol_name(s))
	var line := "%s:[%s|%s|%s]" % [names[reel_idx], symbols[0], symbols[1], symbols[2]]
	if _debug_label.text == "":
		_debug_label.text = line
	else:
		_debug_label.text += " " + line
	_update_display()

func _on_all_stopped() -> void:
	var blackout_level: int = SlotEngine.current_production.get("blackout", 0)
	_play_blackout(blackout_level)
	if blackout_level >= 3:
		var flash_type: String = SlotEngine.current_production.get("flash", "SPARK")
		_play_flash(flash_type)

func _on_payout_started(amount: int, flag: PayTable.Flag) -> void:
	# S-1: 入賞グロー開始
	if amount > 0 and flag != PayTable.Flag.REPLAY:
		_reel_renderer.set_payout_glow(true)
	if flag == PayTable.Flag.REPLAY:
		_info_label.text = "REPLAY!"
		AudioManager.play_se("replay_win")
		_bet_done = true
	elif amount > 0:
		_info_label.text = "WIN: %d" % amount
		_payout_seg.set_value(amount)
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
	# S-1: 入賞グロー終了
	_reel_renderer.set_payout_glow(false)
	_update_display()

func _on_bonus_triggered(bonus_type: String) -> void:
	_info_label.text = "*** %s BONUS START! ***" % bonus_type
	AudioManager.play_se("bonus_align")  # ボーナス図柄揃い音
	# PM-6: ファンファーレを0.5s遅延（bonus_alignのダッキング-12dBと競合回避）
	get_tree().create_timer(0.5).timeout.connect(func() -> void:
		if bonus_type == "BIG":
			AudioManager.play_se("big_fanfare")
			AudioManager.play_bgm("bonus_big", 0.5)
		else:
			AudioManager.play_se("reg_fanfare")
			AudioManager.play_bgm("bonus_reg", 0.5)
	)

func _on_bonus_ended(bonus_type: String, total_payout: int) -> void:
	_info_label.text = "%s END — Total: %d" % [bonus_type, total_payout]
	AudioManager.play_se("bonus_end")
	if bonus_type == "REG":
		AudioManager.play_bgm("normal", 0.5)

func _on_rt_started(max_games: int) -> void:
	_info_label.text = "RT START (%dG)" % max_games
	AudioManager.play_se("rt_start")
	AudioManager.play_bgm("rt", 0.5)

func _on_rt_ended() -> void:
	_info_label.text = "RT END"
	AudioManager.play_bgm("normal", 1.0)

func _on_reach_me(pattern_name: String) -> void:
	_info_label.text = "REACH ME: %s" % pattern_name
	AudioManager.play_se("reach_me")

# --- ゲーム背景画像 ---
var _bg_texture_rect: TextureRect

func _setup_game_background() -> void:
	var bg_node := $Background
	var tex: Texture2D = AssetRegistry.load_background("game")
	if tex:
		_bg_texture_rect = TextureRect.new()
		_bg_texture_rect.texture = tex
		_bg_texture_rect.anchors_preset = Control.PRESET_FULL_RECT
		_bg_texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_bg_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		_bg_texture_rect.modulate.a = 0.55
		bg_node.add_child(_bg_texture_rect)

func _swap_background(bg_name: String) -> void:
	var tex: Texture2D = AssetRegistry.load_background(bg_name)
	if tex and _bg_texture_rect:
		_bg_texture_rect.texture = tex

# --- クロームフレーム (§8.3) ---
func _setup_chrome_frame() -> void:
	var shader_path := "res://shaders/chrome_frame.gdshader"
	if not ResourceLoader.exists(shader_path):
		return
	var shader: Shader = load(shader_path)
	var reel_rect := Rect2(
		_reel_renderer.position.x - 15.0,
		_reel_renderer.position.y - 15.0,
		_reel_renderer.size.x + 30.0,
		_reel_renderer.size.y + 30.0
	)
	var frame_width := 15.0
	# 上辺
	_add_frame_piece(shader, Vector2(reel_rect.position.x, reel_rect.position.y),
		Vector2(reel_rect.size.x, frame_width))
	# 下辺
	_add_frame_piece(shader, Vector2(reel_rect.position.x, reel_rect.position.y + reel_rect.size.y - frame_width),
		Vector2(reel_rect.size.x, frame_width))
	# 左辺
	_add_frame_piece(shader, Vector2(reel_rect.position.x, reel_rect.position.y),
		Vector2(frame_width, reel_rect.size.y))
	# 右辺
	_add_frame_piece(shader, Vector2(reel_rect.position.x + reel_rect.size.x - frame_width, reel_rect.position.y),
		Vector2(frame_width, reel_rect.size.y))

func _add_frame_piece(shader: Shader, pos: Vector2, frame_size: Vector2) -> void:
	var rect := ColorRect.new()
	rect.position = pos
	rect.size = frame_size
	var mat := ShaderMaterial.new()
	mat.shader = shader
	rect.material = mat
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rect)
	# FlashOverlayの下に配置（BlackoutOverlayの手前）
	move_child(rect, _blackout_overlay.get_index())

# --- VFX: 消灯演出（4段階） ---
func _play_blackout(level: int) -> void:
	var target_alpha := [0.0, 0.3, 0.55, 0.8]
	if level < 0 or level >= target_alpha.size():
		return
	if level == 0:
		_blackout_overlay.color.a = 0.0
		return

	# 消灯レベル別音量 (§10.1: level1=-12dB, level2=-6dB, level3=0dB)
	var blackout_vol := [-80.0, -12.0, -6.0, 0.0]
	AudioManager.play_se("blackout", blackout_vol[level])
	if _blackout_tween and _blackout_tween.is_valid():
		_blackout_tween.kill()
	_blackout_tween = create_tween()
	_blackout_tween.tween_property(_blackout_overlay, "color:a", target_alpha[level], 0.3)
	_blackout_tween.tween_interval(1.0)
	_blackout_tween.tween_property(_blackout_overlay, "color:a", 0.0, 0.5)

# --- VFX: フラッシュ演出（8種差別化 §7.4） ---
func _play_flash(flash_type: String) -> void:
	var flash_color := Color.WHITE
	match flash_type:
		"SPARK": flash_color = Color.WHITE
		"GLITCH": flash_color = Color(0.0, 0.83, 1.0)
		"NEON_SIGN": flash_color = Color(0.0, 1.0, 0.53)
		"STROBE": flash_color = Color(1.0, 0.08, 0.58)
		"DROP": flash_color = Color(1.0, 0.843, 0.0)
		"BLOOM": flash_color = Color(0.69, 0.31, 1.0)
		"STARMINE": flash_color = Color(1.0, 0.2, 0.2)
		"TAMAYA": flash_color = Color(1.0, 0.843, 0.0)

	_flash_overlay.color = Color(flash_color.r, flash_color.g, flash_color.b, 0.0)
	# S-4: 形状差別化のためスケール/位置をリセット
	_flash_overlay.pivot_offset = _flash_overlay.size / 2.0
	_flash_overlay.scale = Vector2.ONE

	if flash_type in ["BLOOM", "STARMINE", "TAMAYA"]:
		AudioManager.play_se("flash_premium")
	else:
		AudioManager.play_se("flash")

	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()
	_flash_tween = create_tween()

	match flash_type:
		"SPARK":
			# S-4: 線香花火: 中央から小さく爆発→消える
			_flash_overlay.scale = Vector2(0.3, 0.3)
			_flash_tween.tween_property(_flash_overlay, "scale", Vector2(1.2, 1.2), 0.08)
			_flash_tween.parallel().tween_property(_flash_overlay, "color:a", 0.4, 0.05)
			_flash_tween.tween_property(_flash_overlay, "color:a", 0.0, 0.3)
			_flash_tween.parallel().tween_property(_flash_overlay, "scale", Vector2.ONE, 0.3)
		"GLITCH":
			# グリッチ: 高速明滅3回（位置ずれ付き）
			for i in range(3):
				var offset_x := randf_range(-10.0, 10.0)
				_flash_tween.tween_property(_flash_overlay, "position:x", offset_x, 0.01)
				_flash_tween.tween_property(_flash_overlay, "color:a", 0.7, 0.02)
				_flash_tween.tween_property(_flash_overlay, "color:a", 0.0, 0.04)
				_flash_tween.tween_interval(0.03)
			_flash_tween.tween_property(_flash_overlay, "position:x", 0.0, 0.01)
		"NEON_SIGN":
			# S-4: ネオンサイン: 点滅しながらじわっと→長い残光（実際のネオン管風）
			_flash_tween.tween_property(_flash_overlay, "color:a", 0.2, 0.05)
			_flash_tween.tween_property(_flash_overlay, "color:a", 0.0, 0.03)
			_flash_tween.tween_property(_flash_overlay, "color:a", 0.35, 0.04)
			_flash_tween.tween_property(_flash_overlay, "color:a", 0.1, 0.03)
			_flash_tween.tween_property(_flash_overlay, "color:a", 0.5, 0.1)
			_flash_tween.tween_property(_flash_overlay, "color:a", 0.0, 0.8)
		"STROBE":
			# ストロボ: 高速4回点滅
			for i in range(4):
				_flash_tween.tween_property(_flash_overlay, "color:a", 0.8, 0.01)
				_flash_tween.tween_property(_flash_overlay, "color:a", 0.0, 0.01)
				_flash_tween.tween_interval(0.06)
		"DROP":
			# S-4: 落下花火: 上から下にスケール収縮しながらフェード
			_flash_overlay.scale = Vector2(1.0, 1.5)
			_flash_tween.tween_property(_flash_overlay, "color:a", 0.7, 0.05)
			_flash_tween.parallel().tween_property(_flash_overlay, "scale", Vector2(0.8, 0.5), 0.6).set_ease(Tween.EASE_IN)
			_flash_tween.parallel().tween_property(_flash_overlay, "color:a", 0.0, 0.6).set_ease(Tween.EASE_IN)
			_flash_tween.tween_property(_flash_overlay, "scale", Vector2.ONE, 0.01)
		"BLOOM":
			# S-4: 大輪: 中央から膨張→最大で全面→消える
			_flash_overlay.scale = Vector2(0.1, 0.1)
			_flash_tween.tween_property(_flash_overlay, "scale", Vector2(0.5, 0.5), 0.15)
			_flash_tween.parallel().tween_property(_flash_overlay, "color:a", 0.3, 0.15)
			_flash_tween.tween_property(_flash_overlay, "scale", Vector2(1.3, 1.3), 0.3)
			_flash_tween.parallel().tween_property(_flash_overlay, "color:a", 0.9, 0.3)
			_flash_tween.tween_property(_flash_overlay, "color:a", 0.0, 0.5)
			_flash_tween.parallel().tween_property(_flash_overlay, "scale", Vector2.ONE, 0.5)
		"STARMINE":
			# スターマイン: 連続爆発3発（スケール変化付き）
			for i in range(3):
				var intensity := 0.5 + float(i) * 0.2
				var s := 0.8 + float(i) * 0.15
				_flash_tween.tween_property(_flash_overlay, "scale", Vector2(s, s), 0.02)
				_flash_tween.tween_property(_flash_overlay, "color:a", intensity, 0.04)
				_flash_tween.tween_property(_flash_overlay, "color:a", 0.1, 0.08)
			_flash_tween.tween_property(_flash_overlay, "color:a", 0.0, 0.3)
			_flash_tween.parallel().tween_property(_flash_overlay, "scale", Vector2.ONE, 0.3)
		"TAMAYA":
			# たーまやー: 溜め→大爆発→残光→第2波
			_flash_overlay.scale = Vector2(0.5, 0.5)
			_flash_tween.tween_property(_flash_overlay, "color:a", 0.2, 0.3)
			_flash_tween.parallel().tween_property(_flash_overlay, "scale", Vector2(0.8, 0.8), 0.3)
			_flash_tween.tween_property(_flash_overlay, "color:a", 1.0, 0.05)
			_flash_tween.parallel().tween_property(_flash_overlay, "scale", Vector2(1.5, 1.5), 0.05)
			_flash_tween.tween_property(_flash_overlay, "color:a", 0.3, 0.2)
			_flash_tween.parallel().tween_property(_flash_overlay, "scale", Vector2(1.2, 1.2), 0.2)
			_flash_tween.tween_interval(0.15)
			_flash_tween.tween_property(_flash_overlay, "color:a", 0.8, 0.05)
			_flash_tween.tween_property(_flash_overlay, "color:a", 0.0, 0.6)
			_flash_tween.parallel().tween_property(_flash_overlay, "scale", Vector2.ONE, 0.6)
		_:
			# デフォルト
			_flash_tween.tween_property(_flash_overlay, "color:a", 0.6, 0.08)
			_flash_tween.tween_property(_flash_overlay, "color:a", 0.0, 0.4)

# --- Button Style (§8.4) ---
func _init_button_style(btn: Button, active_color: Color, text_color: Color) -> void:
	# S-2: ベベル効果付きStyleBox
	var normal := StyleBoxFlat.new()
	normal.bg_color = active_color
	normal.set_corner_radius_all(6)
	# ベベルハイライト（上辺）
	normal.border_width_top = 2
	normal.border_color = active_color.lightened(0.3)
	# ベベルシャドウ（下辺）
	normal.border_width_bottom = 3
	normal.shadow_color = Color(0.0, 0.0, 0.0, 0.3)
	normal.shadow_size = 4

	var hover := normal.duplicate()
	hover.bg_color = active_color.lightened(0.15)
	hover.shadow_size = 6

	var pressed := normal.duplicate()
	pressed.bg_color = active_color.darkened(0.2)
	pressed.border_width_top = 0
	pressed.border_width_bottom = 1
	pressed.shadow_size = 1

	var disabled := StyleBoxFlat.new()
	disabled.bg_color = COLOR_DISABLED
	disabled.set_corner_radius_all(6)

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("disabled", disabled)
	# PM-3: 暗色テキスト（WCAG AA 4.5:1以上）
	btn.add_theme_color_override("font_color", text_color)

# --- LED Indicators (PM-4: §8.4) ---
func _setup_led_indicators() -> void:
	var panel: HBoxContainer = $ButtonPanel
	# LEDパネルをボタンパネルの直下に配置
	var led_panel := HBoxContainer.new()
	led_panel.name = "LedPanel"
	led_panel.layout_mode = 1
	led_panel.offset_left = panel.offset_left
	led_panel.offset_top = panel.offset_bottom
	led_panel.offset_right = panel.offset_right
	led_panel.offset_bottom = panel.offset_bottom + 8.0
	led_panel.alignment = BoxContainer.ALIGNMENT_CENTER
	led_panel.add_theme_constant_override("separation", 10)
	add_child(led_panel)

	var buttons: Array[Button] = [_bet_btn, _stop_l_btn, _stop_c_btn, _stop_r_btn, _lever_btn]
	for btn in buttons:
		var led := ColorRect.new()
		led.custom_minimum_size = Vector2(btn.custom_minimum_size.x, 8.0)
		led.color = COLOR_LED_INACTIVE
		led_panel.add_child(led)
		_led_rects[btn] = led

# --- Wait Tick (PM-5: §10.1) ---
func _on_wait_started(_duration: float) -> void:
	if _wait_tick_timer != null:
		_wait_tick_timer.queue_free()
	_wait_tick_timer = Timer.new()
	_wait_tick_timer.wait_time = 1.0
	_wait_tick_timer.autostart = true
	_wait_tick_timer.timeout.connect(func() -> void: AudioManager.play_se("wait_tick"))
	add_child(_wait_tick_timer)

func _on_wait_ended() -> void:
	if _wait_tick_timer != null:
		_wait_tick_timer.stop()
		_wait_tick_timer.queue_free()
		_wait_tick_timer = null

# --- Display ---
func _update_display() -> void:
	# 7セグ更新
	_credit_seg.set_value(GameData.credit)
	_bet_seg.set_value(3 if _bet_done else 0)
	if not SlotEngine.is_in_bonus():
		_payout_seg.set_value(0)

	# データカウンター更新
	_games_label.text = "G: %d" % GameData.total_games
	_big_label.text = "BIG: %d" % GameData.big_count
	_reg_label.text = "REG: %d" % GameData.reg_count
	var diff: int = GameData.total_out - GameData.total_in
	_diff_label.text = "DIFF: %s%d | IN:%d OUT:%d" % [
		"+" if diff >= 0 else "", diff, GameData.total_in, GameData.total_out]

	# ボーナス/RT情報
	if SlotEngine.is_in_bonus():
		var remaining := SlotEngine.get_bonus_remaining()
		var played := SlotEngine.get_bonus_games_played()
		_info_label.text = "BONUS: %d/%dG PAY:%d" % [
			played, played + remaining, SlotEngine.get_bonus_payout()]
	if SlotEngine.is_rt_active():
		_games_label.text += " | RT: %dG" % SlotEngine.get_rt_remaining()

	# デバッグリール情報クリア（レバー時）
	if SlotEngine.game_state == SlotEngine.GameState.SPINNING:
		_debug_label.text = ""

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
	# PM-4: LED更新
	_update_leds()

func _update_leds() -> void:
	for btn: Button in _led_rects:
		var led: ColorRect = _led_rects[btn]
		led.color = COLOR_LED_INACTIVE if btn.disabled else COLOR_LED_ACTIVE
