extends Control
## ReelRenderer — 3リール管理 + SlotEngineシグナル接続 (§9.1)
## 実機準拠: clip_contentsでリール窓をクリッピング + ドラム曲面シェーダー

const REEL_WIDTH := 200.0
const REEL_GAP := 15.0
const REEL_WINDOW_H := 520.0    # 外枠の高さ
const VIEWPORT_H := 488.0       # 実図柄表示域（3段 * 164px ≒ 492px、微調整）
const MARGIN_TOP := 16.0        # (520-488)/2

# シェーダー
var _drum_shader: Shader
var _glass_shader: Shader
var _glow_shader: Shader
var _blur_shader: Shader

var _reel_containers: Array[Control] = []
var _reel_strips: Array = []  # ReelStrip instances
var _textures: Dictionary = {}
var _glow_overlays: Array[ColorRect] = []
var _blur_materials: Array[ShaderMaterial] = []  # 各リールのブラーマテリアル

# STOPボタン有効化制御（実機: 全リールフル回転到達後に有効）
var _accel_done_count: int = 0
signal all_reels_at_full_speed()  # game.gdがSTOPボタンを有効化するトリガー

func _ready() -> void:
	_load_shaders()
	_load_textures()
	_build_reels()
	_connect_signals()

func _load_shaders() -> void:
	_drum_shader = load("res://shaders/reel_drum.gdshader")
	_glass_shader = load("res://shaders/reel_glass.gdshader")
	if ResourceLoader.exists("res://shaders/symbol_glow.gdshader"):
		_glow_shader = load("res://shaders/symbol_glow.gdshader")
	else:
		push_warning("symbol_glow.gdshader not found, payout glow disabled")
	if ResourceLoader.exists("res://shaders/reel_blur.gdshader"):
		_blur_shader = load("res://shaders/reel_blur.gdshader")
	else:
		push_warning("reel_blur.gdshader not found, motion blur disabled")

func _load_textures() -> void:
	for sym_id in AssetRegistry.SYMBOL_TEXTURES:
		var tex: Texture2D = AssetRegistry.load_symbol_texture(sym_id)
		if tex:
			_textures[sym_id] = tex
		else:
			_textures[sym_id] = AssetRegistry.create_placeholder(
				Vector2(200, 160), SymbolTable.get_color(sym_id)
			)

func _build_reels() -> void:
	var total_w := REEL_WIDTH * 3 + REEL_GAP * 2  # 630px
	var start_x := (size.x - total_w) / 2.0

	for i in range(3):
		# Clipping container（リール窓 = この範囲外は見えない）
		var container := Control.new()
		container.clip_contents = true
		container.position = Vector2(start_x + i * (REEL_WIDTH + REEL_GAP), MARGIN_TOP)
		container.size = Vector2(REEL_WIDTH, VIEWPORT_H)
		add_child(container)
		_reel_containers.append(container)

		# ReelStrip（clip_contents内に直接配置）
		var strip_script: GDScript = preload("res://scripts/ui/reel_strip.gd")
		var strip := Control.new()
		strip.set_script(strip_script)
		container.add_child(strip)
		strip.setup(i, _textures)
		strip.reel_stopped.connect(_on_strip_stopped)
		strip.accel_done.connect(_on_strip_accel_done)
		_reel_strips.append(strip)

		# モーションブラー（実機の回転中残像を再現）
		if _blur_shader:
			var blur_mat := ShaderMaterial.new()
			blur_mat.shader = _blur_shader
			blur_mat.set_shader_parameter("blur_strength", 0.0)
			_blur_materials.append(blur_mat)
		else:
			_blur_materials.append(null)

		# ドラム曲面シェーダー（blend_mixで端の暗化を実現）
		if _drum_shader:
			var drum_overlay := ColorRect.new()
			drum_overlay.size = Vector2(REEL_WIDTH, VIEWPORT_H)
			drum_overlay.color = Color(0.0, 0.0, 0.0, 0.0)  # 透明ベース
			drum_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var drum_mat := ShaderMaterial.new()
			drum_mat.shader = _drum_shader
			drum_overlay.material = drum_mat
			container.add_child(drum_overlay)

		# ガラス反射オーバーレイ（最前面、マウス透過）
		if _glass_shader:
			var glass := ColorRect.new()
			glass.size = Vector2(REEL_WIDTH, VIEWPORT_H)
			glass.color = Color(1.0, 1.0, 1.0, 0.0)  # 透明ベース
			glass.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var glass_mat := ShaderMaterial.new()
			glass_mat.shader = _glass_shader
			glass.material = glass_mat
			container.add_child(glass)

	# グローオーバーレイ（S-1: symbol_glow）
	for i in range(3):
		var glow_rect := ColorRect.new()
		glow_rect.size = Vector2(REEL_WIDTH, VIEWPORT_H)
		glow_rect.position = _reel_containers[i].position
		glow_rect.color = Color(1.0, 1.0, 1.0, 0.0)
		glow_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		glow_rect.visible = false
		if _glow_shader:
			var glow_mat := ShaderMaterial.new()
			glow_mat.shader = _glow_shader
			glow_mat.set_shader_parameter("active", 0.0)
			glow_rect.material = glow_mat
		add_child(glow_rect)
		_glow_overlays.append(glow_rect)

func _connect_signals() -> void:
	SlotEngine.game_state_changed.connect(_on_state_changed)
	SlotEngine.reel_stop_calculated.connect(_on_reel_stop_calculated)

func _on_state_changed(new_state: SlotEngine.GameState) -> void:
	if new_state == SlotEngine.GameState.SPINNING:
		_accel_done_count = 0
		for strip in _reel_strips:
			strip.start_spin()

func _on_strip_accel_done(_reel_idx: int) -> void:
	_accel_done_count += 1
	if _accel_done_count >= 3:
		all_reels_at_full_speed.emit()

func _physics_process(_delta: float) -> void:
	# モーションブラー強度をリール速度に連動（FULL_SPEED時にフル適用）
	for i in range(_reel_strips.size()):
		var mat: ShaderMaterial = _blur_materials[i] if i < _blur_materials.size() else null
		if mat == null:
			continue
		var strip = _reel_strips[i]
		# 速度比率を blur_strength として渡す（加速中は徐々に強まる、停止で即ゼロ）
		var strength: float = strip.get_speed_ratio()
		mat.set_shader_parameter("blur_strength", strength)
		# TextureRect にシェーダーマテリアルを適用（未適用なら設定）
		if strip._strip_node and strip._strip_node.get_child_count() > 0:
			var tex_rect: TextureRect = strip._strip_node.get_child(0) as TextureRect
			if tex_rect == null:
				continue
			if tex_rect.material != mat:
				tex_rect.material = mat

func _on_reel_stop_calculated(reel_idx: int, target_pos: int, _window: Array) -> void:
	if reel_idx >= 0 and reel_idx < _reel_strips.size():
		_reel_strips[reel_idx].request_stop(target_pos)

func _on_strip_stopped(_reel_idx: int) -> void:
	# リール停止SE は game.gd 側で管理するのでここでは何もしない
	pass

# === 公開API ===

func get_strip(reel_idx: int):
	if reel_idx >= 0 and reel_idx < _reel_strips.size():
		return _reel_strips[reel_idx]
	return null

func set_initial_positions(positions: Array[int]) -> void:
	for i in range(mini(positions.size(), _reel_strips.size())):
		_reel_strips[i].snap_to_position(positions[i])

# S-1: 入賞グロー制御
func set_payout_glow(active: bool, glow_color: Color = Color(0.0, 1.0, 0.53, 1.0)) -> void:
	for glow_rect in _glow_overlays:
		glow_rect.visible = active
		if glow_rect.material:
			glow_rect.material.set_shader_parameter("active", 1.0 if active else 0.0)
			glow_rect.material.set_shader_parameter("glow_color", glow_color)
