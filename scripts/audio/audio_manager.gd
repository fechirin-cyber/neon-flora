extends Node
## AudioManager — SE/BGM管理 (Autoload)
## 仕様書 §10 準拠: SE23種、BGM5曲、ダッキング、クロスフェード、プロシージャルフォールバック

# --- AudioBus定数 ---
const BUS_MASTER := "Master"
const BUS_BGM := "BGM"
const BUS_SE := "SE"

# デフォルト音量 (§10.3)
const DEFAULT_BGM_DB := -8.0
const DEFAULT_SE_DB := -3.0

# --- SE ファイルマップ (§10.1) ---
const SE_FILES := {
	"lever_pull": "res://assets/audio/se/lever_pull.wav",
	"reel_start": "res://assets/audio/se/reel_start.wav",
	"reel_stop_l": "res://assets/audio/se/reel_stop_l.wav",
	"reel_stop_c": "res://assets/audio/se/reel_stop_c.wav",
	"reel_stop_r": "res://assets/audio/se/reel_stop_r.wav",
	"bet_insert": "res://assets/audio/se/bet_insert.wav",
	"medal_out": "res://assets/audio/se/medal_out.wav",
	"medal_single": "res://assets/audio/se/medal_single.wav",
	"wait_tick": "res://assets/audio/se/wait_tick.wav",
	"big_fanfare": "res://assets/audio/se/big_fanfare.wav",
	"reg_fanfare": "res://assets/audio/se/reg_fanfare.wav",
	"bonus_end": "res://assets/audio/se/bonus_end.wav",
	"cherry_win": "res://assets/audio/se/cherry_win.wav",
	"bell_win": "res://assets/audio/se/bell_win.wav",
	"replay_win": "res://assets/audio/se/replay_win.wav",
	"ice_win": "res://assets/audio/se/ice_win.wav",
	"reach_me": "res://assets/audio/se/reach_me.wav",
	"tamaya": "res://assets/audio/se/tamaya.wav",
	"blackout": "res://assets/audio/se/blackout.wav",
	"flash": "res://assets/audio/se/flash.wav",
	"flash_premium": "res://assets/audio/se/flash_premium.wav",
	"bonus_align": "res://assets/audio/se/bonus_align.wav",
	"rt_start": "res://assets/audio/se/rt_start.wav",
}

# --- BGM ファイルマップ (§10.2) ---
const BGM_FILES := {
	"title": "res://assets/audio/bgm/title.ogg",
	"normal": "res://assets/audio/bgm/normal.ogg",
	"bonus_big": "res://assets/audio/bgm/bonus_big.ogg",
	"bonus_reg": "res://assets/audio/bgm/bonus_reg.ogg",
	"rt": "res://assets/audio/bgm/rt.ogg",
}

# --- ダッキング設定 (§10.4) ---
const DUCK_RULES := {
	"big_fanfare": {"db": -20.0, "attack": 0.0, "release": 0.5},
	"reg_fanfare": {"db": -20.0, "attack": 0.0, "release": 0.5},
	"bonus_align": {"db": -12.0, "attack": 0.1, "release": 0.3},
	"tamaya": {"db": -15.0, "attack": 0.0, "release": 0.3},
	"medal_out": {"db": -6.0, "attack": 0.2, "release": 0.3},
}

# --- SEプール ---
const SE_POOL_SIZE := 8
var _se_players: Array[AudioStreamPlayer] = []
var _se_cache: Dictionary = {}  # name -> AudioStream

# --- BGMプレーヤー (クロスフェード用にA/B) ---
var _bgm_a: AudioStreamPlayer
var _bgm_b: AudioStreamPlayer
var _bgm_active: AudioStreamPlayer  # 現在再生中
var _current_bgm: String = ""

# S-3: BGMクロスフェード Tween kill管理
var _bgm_crossfade_tween: Tween

# --- ダッキング ---
var _duck_tween: Tween
var _bgm_bus_idx: int = -1
var _se_bus_idx: int = -1

# --- プロシージャル生成 ---
var _sound_gen: Node  # SoundGenerator

func _ready() -> void:
	_setup_audio_buses()
	_create_se_pool()
	_create_bgm_players()
	_load_sound_generator()
	# 保存された音量を適用
	apply_saved_volumes()
	# テスト時はマスター音量を最小（ミュートしない範囲で最小）
	if OS.get_cmdline_args().has("--auto-test") or OS.get_cmdline_user_args().has("--auto-test"):
		var master_idx := AudioServer.get_bus_index(BUS_MASTER)
		AudioServer.set_bus_volume_db(master_idx, -60.0)

func _setup_audio_buses() -> void:
	# BGMバスが無ければ追加
	if AudioServer.get_bus_index(BUS_BGM) == -1:
		var idx := AudioServer.bus_count
		AudioServer.add_bus(idx)
		AudioServer.set_bus_name(idx, BUS_BGM)
		AudioServer.set_bus_send(idx, BUS_MASTER)
		AudioServer.set_bus_volume_db(idx, DEFAULT_BGM_DB)

	# SEバスが無ければ追加
	if AudioServer.get_bus_index(BUS_SE) == -1:
		var idx := AudioServer.bus_count
		AudioServer.add_bus(idx)
		AudioServer.set_bus_name(idx, BUS_SE)
		AudioServer.set_bus_send(idx, BUS_MASTER)
		AudioServer.set_bus_volume_db(idx, DEFAULT_SE_DB)

	_bgm_bus_idx = AudioServer.get_bus_index(BUS_BGM)
	_se_bus_idx = AudioServer.get_bus_index(BUS_SE)

func _create_se_pool() -> void:
	for i in range(SE_POOL_SIZE):
		var player := AudioStreamPlayer.new()
		player.bus = BUS_SE
		add_child(player)
		_se_players.append(player)

func _create_bgm_players() -> void:
	_bgm_a = AudioStreamPlayer.new()
	_bgm_a.bus = BUS_BGM
	add_child(_bgm_a)

	_bgm_b = AudioStreamPlayer.new()
	_bgm_b.bus = BUS_BGM
	_bgm_b.volume_db = -80.0
	add_child(_bgm_b)

	_bgm_active = _bgm_a

func _load_sound_generator() -> void:
	var script_path := "res://scripts/audio/sound_generator.gd"
	if ResourceLoader.exists(script_path):
		var script: GDScript = load(script_path)
		_sound_gen = Node.new()
		_sound_gen.set_script(script)
		add_child(_sound_gen)

# --- 音量制御API ---

## BGM音量設定 (0-100%)
func set_bgm_volume(percent: float) -> void:
	percent = clampf(percent, 0.0, 100.0)
	if _bgm_bus_idx >= 0:
		var db := _percent_to_db(percent)
		AudioServer.set_bus_volume_db(_bgm_bus_idx, db)

## SE音量設定 (0-100%)
func set_se_volume(percent: float) -> void:
	percent = clampf(percent, 0.0, 100.0)
	if _se_bus_idx >= 0:
		var db := _percent_to_db(percent)
		AudioServer.set_bus_volume_db(_se_bus_idx, db)

## パーセントをdBに変換 (0%=-60dB, 100%=0dB)
func _percent_to_db(percent: float) -> float:
	if percent <= 0.0:
		return -80.0
	return linear_to_db(percent / 100.0)

## 保存された音量を適用
func apply_saved_volumes() -> void:
	set_bgm_volume(GameData.bgm_volume)
	set_se_volume(GameData.se_volume)

## §7.9/7.10: BGM再生速度変更（テンポ変化）
func set_bgm_playback_speed(factor: float) -> void:
	if _bgm_active and _bgm_active.playing:
		_bgm_active.pitch_scale = factor

## BGM再生速度をリセット
func reset_bgm_playback_speed() -> void:
	set_bgm_playback_speed(1.0)

# --- 公開API ---

## SE再生 (volume_db: 追加音量オフセット, 0.0=デフォルト)
func play_se(se_name: String, volume_db: float = 0.0) -> void:
	var stream := _get_se_stream(se_name)
	if stream == null:
		return

	var player := _get_free_se_player()
	if player == null:
		return

	player.stream = stream
	player.volume_db = volume_db
	player.play()

	# ダッキング判定
	if DUCK_RULES.has(se_name):
		_apply_duck(DUCK_RULES[se_name], stream)

## BGM再生 (クロスフェード §10.6)
func play_bgm(bgm_name: String, fade_time: float = 0.5) -> void:
	if bgm_name == _current_bgm:
		return

	var stream := _get_bgm_stream(bgm_name)
	if stream == null:
		return

	_current_bgm = bgm_name

	# S-3: 既存クロスフェードTweenをkill
	if _bgm_crossfade_tween and _bgm_crossfade_tween.is_valid():
		_bgm_crossfade_tween.kill()

	# クロスフェード: 現在のBGMをフェードアウト、新しい方をフェードイン
	var new_player: AudioStreamPlayer
	if _bgm_active == _bgm_a:
		new_player = _bgm_b
	else:
		new_player = _bgm_a

	new_player.stream = stream
	new_player.volume_db = -80.0
	new_player.play()

	_bgm_crossfade_tween = create_tween()
	_bgm_crossfade_tween.set_parallel(true)
	_bgm_crossfade_tween.tween_property(_bgm_active, "volume_db", -80.0, fade_time)
	_bgm_crossfade_tween.tween_property(new_player, "volume_db", 0.0, fade_time)
	_bgm_crossfade_tween.set_parallel(false)
	_bgm_crossfade_tween.tween_callback(_bgm_active.stop)

	_bgm_active = new_player

## BGM停止
func stop_bgm(fade_time: float = 0.5) -> void:
	if not _bgm_active.playing:
		return
	_current_bgm = ""
	if _bgm_crossfade_tween and _bgm_crossfade_tween.is_valid():
		_bgm_crossfade_tween.kill()
	_bgm_crossfade_tween = create_tween()
	_bgm_crossfade_tween.tween_property(_bgm_active, "volume_db", -80.0, fade_time)
	_bgm_crossfade_tween.tween_callback(_bgm_active.stop)

## ダッキング (BGM音量を一時的に下げる)
func duck_bgm(target_db: float, attack_time: float) -> void:
	if _bgm_bus_idx < 0:
		return
	if _duck_tween and _duck_tween.is_valid():
		_duck_tween.kill()
	_duck_tween = create_tween()
	var current_db := AudioServer.get_bus_volume_db(_bgm_bus_idx)
	if attack_time <= 0.0:
		AudioServer.set_bus_volume_db(_bgm_bus_idx, target_db)
	else:
		_duck_tween.tween_method(
			func(db: float) -> void: AudioServer.set_bus_volume_db(_bgm_bus_idx, db),
			current_db, target_db, attack_time)

## ダッキング復帰
func unduck_bgm(release_time: float) -> void:
	if _bgm_bus_idx < 0:
		return
	if _duck_tween and _duck_tween.is_valid():
		_duck_tween.kill()
	_duck_tween = create_tween()
	var current_db := AudioServer.get_bus_volume_db(_bgm_bus_idx)
	_duck_tween.tween_method(
		func(db: float) -> void: AudioServer.set_bus_volume_db(_bgm_bus_idx, db),
		current_db, DEFAULT_BGM_DB, release_time)

# --- メダル払出SE (§10.5) ---

## 配当枚数に応じたメダル払出SE
func play_medal_payout(amount: int) -> void:
	if amount <= 0:
		return
	if amount <= 2:
		# medal_single × 配当枚数（0.1秒間隔）
		for i in range(amount):
			get_tree().create_timer(0.1 * i).timeout.connect(
				func() -> void: play_se("medal_single"))
	elif amount <= 9:
		# medal_single × 3回（0.08秒間隔）+ medal_out
		for i in range(3):
			get_tree().create_timer(0.08 * i).timeout.connect(
				func() -> void: play_se("medal_single"))
		get_tree().create_timer(0.24).timeout.connect(
			func() -> void: play_se("medal_out"))
	else:
		# medal_out（ループ相当）
		play_se("medal_out")

# --- 内部メソッド ---

func _get_se_stream(se_name: String) -> AudioStream:
	# キャッシュチェック
	if _se_cache.has(se_name):
		return _se_cache[se_name]

	# ファイルから読み込み
	if SE_FILES.has(se_name):
		var path: String = SE_FILES[se_name]
		if ResourceLoader.exists(path):
			var stream: AudioStream = load(path)
			_se_cache[se_name] = stream
			return stream

	# プロシージャルフォールバック (§10.8)
	if _sound_gen and _sound_gen.has_method("generate_se"):
		var stream: AudioStream = _sound_gen.generate_se(se_name)
		if stream:
			_se_cache[se_name] = stream
			return stream

	return null

func _get_bgm_stream(bgm_name: String) -> AudioStream:
	if BGM_FILES.has(bgm_name):
		var path: String = BGM_FILES[bgm_name]
		if ResourceLoader.exists(path):
			return load(path)
	# プロシージャルBGMフォールバック (§10.8)
	if _sound_gen and _sound_gen.has_method("generate_bgm"):
		return _sound_gen.generate_bgm(bgm_name)
	return null

func _get_free_se_player() -> AudioStreamPlayer:
	for player in _se_players:
		if not player.playing:
			return player
	# 全て使用中 → 最も古いものを再利用
	return _se_players[0]

func _apply_duck(rule: Dictionary, stream: AudioStream) -> void:
	var target_db: float = rule["db"]
	var attack: float = rule["attack"]
	var release: float = rule["release"]

	duck_bgm(target_db, attack)

	# SE終了後にunduck（大まかなストリーム長を推定）
	var duration := 1.0
	if stream is AudioStreamWAV:
		var wav := stream as AudioStreamWAV
		if wav.mix_rate > 0:
			duration = float(wav.data.size()) / float(wav.mix_rate * 2)  # 16bit mono
	elif stream.has_method("get_length"):
		duration = stream.get_length()

	get_tree().create_timer(duration).timeout.connect(
		func() -> void: unduck_bgm(release))
