extends Control
## ReelStrip — 1リールの描画+スクロールアニメーション (§9.1-9.3)
## 実機準拠: 21図柄+ループ用追加分を単一Controlコンテナに配置し、コンテナごとスクロール
## SubViewport内に配置され、Y位置を毎フレーム更新してリール回転を実現

enum ReelState { IDLE, ACCELERATING, FULL_SPEED, DECELERATING, BOUNCING }

# === 物理パラメータ (§9.2) ===
const MAX_SPEED := 2800.0       # px/sec
const ACCEL_TIME := 0.25        # 加速時間
const DECEL_STEPS := 8          # コマ送りステップ数
const DECEL_INTERVAL := 0.06    # 1ステップ間隔
const BOUNCE_DOWN := 3.0        # バウンス下方向
const BOUNCE_DOWN_TIME := 0.04
const BOUNCE_UP_TIME := 0.08

# === 図柄サイズ (§4.1, §9.1) ===
const SYMBOL_W := 200.0         # 図柄幅
const SYMBOL_H := 160.0         # 図柄高さ
const GAP_H := 4.0              # 図柄間隙間
const CELL_H := SYMBOL_H + GAP_H  # 164px
const VISIBLE_COUNT := 3        # 表示段数
const BUFFER_COUNT := 1         # 上下バッファ
const TOTAL_DISPLAY := VISIBLE_COUNT + BUFFER_COUNT * 2  # 5スロット表示

# === リールストリップ背景色（実機のリール帯 = 暗いアイボリー） ===
const STRIP_BG := Color(0.18, 0.17, 0.15, 1.0)

# === 状態 ===
var _state: ReelState = ReelState.IDLE
var _reel_idx: int = 0
var _current_speed: float = 0.0
var _accel_elapsed: float = 0.0

# コマ送り減速
var _decel_target_pos: int = 0     # 目標停止位置
var _decel_step: int = 0           # 現在のステップ
var _decel_timer: float = 0.0
var _decel_positions: Array[int] = []  # 各ステップの表示位置

# バウンス
var _bounce_phase: int = 0
var _bounce_timer: float = 0.0
var _bounce_base_y: float = 0.0

# リールデータ
var _reel_index_top: int = 0  # 表示窓の最上段の図柄インデックス
var _scroll_offset: float = 0.0  # 細かいスクロールオフセット

# ストリップコンテナ（全図柄を含む単一Controlノード）
var _strip_node: Control
var _strip_total_h: float = 0.0  # 1周分の高さ
var _reel_size: int = 0

var _textures: Dictionary = {}  # sym_id -> Texture2D

signal reel_stopped(reel_idx: int)

func setup(reel_idx: int, textures: Dictionary) -> void:
	_reel_idx = reel_idx
	_textures = textures
	_reel_size = ReelData.REEL_SIZE
	_build_strip()
	# 初期位置: リール位置0の窓を表示
	_set_display_position(0)

func _build_strip() -> void:
	## 21図柄+ループ用追加分を単一Controlコンテナに配置
	## 構造: [図柄0][隙間][図柄1][隙間]...[図柄20][隙間][図柄0]...[図柄4]
	# 既存ノードをクリア
	for child in get_children():
		child.queue_free()

	var extra := TOTAL_DISPLAY  # ループ用追加図柄数
	var total_symbols := _reel_size + extra
	var total_h := float(total_symbols) * CELL_H
	_strip_total_h = float(_reel_size) * CELL_H  # 1周分の高さ

	# ストリップコンテナ（全図柄を格納する単一ノード）
	_strip_node = Control.new()
	_strip_node.size = Vector2(SYMBOL_W, total_h)
	add_child(_strip_node)

	# 背景（リール帯色）
	var bg := ColorRect.new()
	bg.size = Vector2(SYMBOL_W, total_h)
	bg.color = STRIP_BG
	_strip_node.add_child(bg)

	# 各図柄をTextureRectとして配置
	for i in range(total_symbols):
		var data_idx := posmod(i, _reel_size)
		var sym_id: int = ReelData.get_symbol_at(_reel_idx, data_idx)
		if not _textures.has(sym_id):
			continue  # プレースホルダー保証済みだが安全策
		var tex_rect := TextureRect.new()
		tex_rect.texture = _textures[sym_id]
		tex_rect.position = Vector2(0.0, float(i) * CELL_H)
		tex_rect.size = Vector2(SYMBOL_W, SYMBOL_H)
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_strip_node.add_child(tex_rect)

	# Control全体のサイズ
	size = Vector2(SYMBOL_W, total_h)

func _set_display_position(top_index: int) -> void:
	_reel_index_top = top_index
	_scroll_offset = 0.0
	_update_strip_position()

func _update_strip_position() -> void:
	## ストリップのY位置を更新
	## top_indexの図柄が表示窓の最上段に来るようにする
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
	if _state != ReelState.FULL_SPEED:
		# まだ定速でない場合は即座に定速にしてから停止
		_current_speed = MAX_SPEED
	_decel_target_pos = target_pos
	_prepare_decel_sequence()
	_state = ReelState.DECELERATING
	_decel_step = 0
	_decel_timer = 0.0

func get_state() -> ReelState:
	return _state

func get_current_center_pos() -> int:
	## 現在の中段表示位置を返す（ストップボタン押下時の実リール位置）
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
		ReelState.DECELERATING:
			_process_decelerating(delta)
		ReelState.BOUNCING:
			_process_bouncing(delta)

func _process_accelerating(delta: float) -> void:
	_accel_elapsed += delta
	var t := clampf(_accel_elapsed / ACCEL_TIME, 0.0, 1.0)
	_current_speed = MAX_SPEED * t * t  # ease-in
	_scroll(delta)
	if t >= 1.0:
		_state = ReelState.FULL_SPEED
		_current_speed = MAX_SPEED

func _process_full_speed(delta: float) -> void:
	_scroll(delta)

func _process_decelerating(delta: float) -> void:
	_decel_timer += delta
	if _decel_timer >= DECEL_INTERVAL:
		_decel_timer -= DECEL_INTERVAL
		_decel_step += 1
		if _decel_step >= _decel_positions.size():
			# 減速完了 → 目標位置にスナップ → バウンス
			_snap_to_position(_decel_target_pos)
			_start_bounce()
			return
		# 次のコマ位置にスナップ
		_snap_to_position(_decel_positions[_decel_step])

func _process_bouncing(delta: float) -> void:
	_bounce_timer += delta
	if _bounce_phase == 0:
		# 下方向
		var t := clampf(_bounce_timer / BOUNCE_DOWN_TIME, 0.0, 1.0)
		_strip_node.position.y = _bounce_base_y + BOUNCE_DOWN * t
		if t >= 1.0:
			_bounce_phase = 1
			_bounce_timer = 0.0
	else:
		# 戻り
		var t := clampf(_bounce_timer / BOUNCE_UP_TIME, 0.0, 1.0)
		_strip_node.position.y = _bounce_base_y + BOUNCE_DOWN * (1.0 - t)
		if t >= 1.0:
			_strip_node.position.y = _bounce_base_y
			_state = ReelState.IDLE
			reel_stopped.emit(_reel_idx)

# === スクロール処理 ===

func _scroll(delta: float) -> void:
	_scroll_offset += _current_speed * delta

	# 1図柄分スクロールしたらインデックスを進める（実機準拠: 図柄は上→下に流れる）
	while _scroll_offset >= CELL_H:
		_scroll_offset -= CELL_H
		_reel_index_top = posmod(_reel_index_top - 1, _reel_size)

	# ストリップ位置を更新
	_update_strip_position()

func _snap_to_position(reel_pos: int) -> void:
	# reel_pos は中段位置。表示top = reel_pos - 1（上段が1つ前）
	var top_idx := posmod(reel_pos - 1, _reel_size)
	_set_display_position(top_idx)

func _start_bounce() -> void:
	_state = ReelState.BOUNCING
	_bounce_phase = 0
	_bounce_timer = 0.0
	_bounce_base_y = _strip_node.position.y

# === 減速シーケンス準備 ===

func _prepare_decel_sequence() -> void:
	_decel_positions.clear()
	# 現在の中段位置を推定
	var current_center := posmod(_reel_index_top + 1, _reel_size)
	# 目標までの距離（実機準拠: インデックスが減少する方向に回転）
	var distance := posmod(current_center - _decel_target_pos, _reel_size)
	if distance < DECEL_STEPS:
		distance += _reel_size  # 少なくとも1周分

	# 等間隔にステップを配置（最後のステップは目標位置）
	for i in range(DECEL_STEPS):
		var step_pos: int
		if i == DECEL_STEPS - 1:
			step_pos = _decel_target_pos
		else:
			var progress := float(i + 1) / float(DECEL_STEPS)
			var offset := int(distance * progress)
			step_pos = posmod(current_center - offset, _reel_size)
		_decel_positions.append(step_pos)
