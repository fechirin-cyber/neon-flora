extends Control
## ReelStrip — 1リールの描画+スクロールアニメーション (§9.1-9.3)
## 実機準拠: 80RPM回転、STOPボタン後0-4コマ滑り即停止（190ms以内）
## ステッピングモーター制御を再現: 減速カーブなし、コマ送り後スナップ停止

enum ReelState { IDLE, ACCELERATING, FULL_SPEED, BOUNCING }

# === 物理パラメータ（実機準拠 — 法規制/特許文献ベース） ===
# 回転速度: 80 RPM (法規制上限: 別表第5「1分間に80回転を超えるものでないこと」)
# 1周: 21コマ × 164px = 3444px → 80RPM = 1.333回転/秒 → 3444 × 1.333 = 4592 px/sec
# 1コマ通過: 164px / 4592px/s = 35.7ms
const MAX_SPEED := 4592.0       # px/sec (80RPM実機準拠)
const ACCEL_TIME := 0.4         # 加速時間 (特許JP2002159626A: 約0.4秒でフル回転到達)

# バウンス（ステッピングモーター停止時の微振動再現）
# 実機: ホールディングトルクで即座に位置保持。バウンスは極微小
const BOUNCE_DOWN := 1.5        # 下方向 1.5px (実機はほぼゼロ)
const BOUNCE_DOWN_TIME := 0.02  # 20ms
const BOUNCE_UP_TIME := 0.03   # 30ms
# 合計バウンス: 50ms（実機の「パシッ」という停止感を表現）

# === 図柄サイズ (§4.1, §9.1) ===
const SYMBOL_W := 200.0         # 図柄幅
const SYMBOL_H := 160.0         # 図柄高さ
const GAP_H := 4.0              # 図柄間隙間
const CELL_H := SYMBOL_H + GAP_H  # 164px (1コマ)
const VISIBLE_COUNT := 3        # 表示段数（上段・中段・下段）
const BUFFER_COUNT := 1         # 上下バッファ
const TOTAL_DISPLAY := VISIBLE_COUNT + BUFFER_COUNT * 2  # 5

# === リールストリップ背景色（実機のリール帯 = 暗いアイボリー） ===
const STRIP_BG := Color(0.18, 0.17, 0.15, 1.0)

# === 状態 ===
var _state: ReelState = ReelState.IDLE
var _reel_idx: int = 0
var _current_speed: float = 0.0
var _accel_elapsed: float = 0.0

# 停止ターゲット（request_stop用）
var _slip_target_pos: int = 0

# バウンス
var _bounce_phase: int = 0
var _bounce_timer: float = 0.0
var _bounce_base_y: float = 0.0

# リールデータ
var _reel_index_top: int = 0  # 表示窓の最上段の図柄インデックス
var _scroll_offset: float = 0.0  # 細かいスクロールオフセット (0 〜 CELL_H)

# ストリップコンテナ（全図柄を含む単一Controlノード）
var _strip_node: Control
var _strip_total_h: float = 0.0  # 1周分の高さ
var _reel_size: int = 0

var _textures: Dictionary = {}  # sym_id -> Texture2D

signal reel_stopped(reel_idx: int)
signal accel_done(reel_idx: int)  # 加速完了通知（STOPボタン有効化タイミング用）

func setup(reel_idx: int, textures: Dictionary) -> void:
	_reel_idx = reel_idx
	_textures = textures
	_reel_size = ReelData.REEL_SIZE
	_build_strip()
	_set_display_position(0)

func _build_strip() -> void:
	## 全図柄を1枚のアトラステクスチャに合成して継ぎ目のない表示を実現
	for child in get_children():
		child.queue_free()

	var extra := TOTAL_DISPLAY
	var total_symbols := _reel_size + extra
	var total_h := int(float(total_symbols) * CELL_H)
	_strip_total_h = float(_reel_size) * CELL_H

	_strip_node = Control.new()
	_strip_node.size = Vector2(SYMBOL_W, float(total_h))
	add_child(_strip_node)

	# 1枚のアトラスImageを生成
	var atlas_img := Image.create(int(SYMBOL_W), total_h, false, Image.FORMAT_RGBA8)
	atlas_img.fill(STRIP_BG)

	for i in range(total_symbols):
		var data_idx := posmod(i, _reel_size)
		var sym_id: int = ReelData.get_symbol_at(_reel_idx, data_idx)
		if not _textures.has(sym_id):
			continue
		var tex: Texture2D = _textures[sym_id]
		var src_img: Image = tex.get_image()
		if src_img == null:
			continue
		if src_img.get_format() != Image.FORMAT_RGBA8:
			src_img = src_img.duplicate()
			src_img.convert(Image.FORMAT_RGBA8)
		if src_img.get_width() != int(SYMBOL_W) or src_img.get_height() != int(SYMBOL_H):
			if src_img.get_format() == Image.FORMAT_RGBA8 and not src_img.is_empty():
				src_img = src_img.duplicate()
			src_img.resize(int(SYMBOL_W), int(SYMBOL_H))
		var dst_y := int(float(i) * CELL_H)
		atlas_img.blit_rect(src_img, Rect2i(0, 0, int(SYMBOL_W), int(SYMBOL_H)), Vector2i(0, dst_y))

	var atlas_tex := ImageTexture.create_from_image(atlas_img)
	var tex_rect := TextureRect.new()
	tex_rect.texture = atlas_tex
	tex_rect.size = Vector2(SYMBOL_W, float(total_h))
	tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex_rect.stretch_mode = TextureRect.STRETCH_SCALE
	_strip_node.add_child(tex_rect)

	size = Vector2(SYMBOL_W, float(total_h))

func _set_display_position(top_index: int) -> void:
	_reel_index_top = top_index
	_scroll_offset = 0.0
	_update_strip_position()

func _update_strip_position() -> void:
	var base_y := -float(_reel_index_top) * CELL_H
	_strip_node.position.y = base_y + _scroll_offset

# === 公開API ===

func start_spin() -> void:
	if _state != ReelState.IDLE:
		return
	_state = ReelState.ACCELERATING
	_current_speed = 0.0
	_accel_elapsed = 0.0

func request_stop(target_pos: int) -> void:
	## 実機準拠の即停止制御（ステッピングモーター全相励磁制動再現）
	## STOPボタン押下 → 即座にスナップ停止 → 微バウンス
	## 実機: 0〜4コマ滑り(0〜143ms)は体感的に「即停止」
	## ステッピングモーターの全相励磁制動により、ボタンを押した瞬間に停止する感覚
	_slip_target_pos = target_pos
	_current_speed = 0.0
	_snap_to_position(target_pos)
	_start_bounce()

func get_state() -> ReelState:
	return _state

func get_current_center_pos() -> int:
	## 現在の中段表示位置を返す（STOPボタン押下時の目押し位置）
	## scroll_offset考慮: 半コマ以上進んでいたら次の図柄に丸める
	if _scroll_offset >= CELL_H * 0.5:
		return posmod(_reel_index_top, _reel_size)
	return posmod(_reel_index_top + 1, _reel_size)

func snap_to_position(reel_pos: int) -> void:
	## 外部からの位置設定（中断復帰用）
	_snap_to_position(reel_pos)

# === _physics_process ===

func _physics_process(delta: float) -> void:
	match _state:
		ReelState.IDLE:
			pass
		ReelState.ACCELERATING:
			_process_accelerating(delta)
		ReelState.FULL_SPEED:
			_process_full_speed(delta)
		ReelState.BOUNCING:
			_process_bouncing(delta)

func _process_accelerating(delta: float) -> void:
	## 実機準拠: 0.4秒でフル回転速度に到達（ステッピングモーター段階的加速）
	_accel_elapsed += delta
	var t := clampf(_accel_elapsed / ACCEL_TIME, 0.0, 1.0)
	_current_speed = MAX_SPEED * t * t  # ease-in (段階的加速)
	_scroll(delta)
	if t >= 1.0:
		_state = ReelState.FULL_SPEED
		_current_speed = MAX_SPEED
		accel_done.emit(_reel_idx)

func _process_full_speed(delta: float) -> void:
	## 80RPM定速回転
	_scroll(delta)


func _process_bouncing(delta: float) -> void:
	## ステッピングモーター停止時の微振動（ホールディングトルクで即収束）
	_bounce_timer += delta
	if _bounce_phase == 0:
		var t := clampf(_bounce_timer / BOUNCE_DOWN_TIME, 0.0, 1.0)
		_strip_node.position.y = _bounce_base_y + BOUNCE_DOWN * t
		if t >= 1.0:
			_bounce_phase = 1
			_bounce_timer = 0.0
	else:
		var t := clampf(_bounce_timer / BOUNCE_UP_TIME, 0.0, 1.0)
		_strip_node.position.y = _bounce_base_y + BOUNCE_DOWN * (1.0 - t)
		if t >= 1.0:
			_strip_node.position.y = _bounce_base_y
			_current_speed = 0.0  # 安全弁: IDLE時は必ず速度ゼロ
			_state = ReelState.IDLE
			reel_stopped.emit(_reel_idx)

# === スクロール処理 ===

func _scroll(delta: float) -> void:
	_scroll_offset += _current_speed * delta
	# 1コマ分スクロールしたらインデックスを進める（実機準拠: 図柄は上→下に流れる）
	while _scroll_offset >= CELL_H:
		_scroll_offset -= CELL_H
		_reel_index_top = posmod(_reel_index_top - 1, _reel_size)
	_update_strip_position()


func _snap_to_position(reel_pos: int) -> void:
	# reel_pos は中段位置。表示top = reel_pos - 1（上段が1つ前）
	var top_idx := posmod(reel_pos - 1, _reel_size)
	_set_display_position(top_idx)

func _start_bounce() -> void:
	_current_speed = 0.0  # ブラー即解除（停止 = 速度ゼロ）
	_state = ReelState.BOUNCING
	_bounce_phase = 0
	_bounce_timer = 0.0
	_bounce_base_y = _strip_node.position.y
