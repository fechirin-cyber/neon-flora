extends Node
## SoundGenerator — プロシージャル音声生成 (§10.8 フォールバック)
## wavファイルが存在しない場合にAudioStreamWAVをコードで生成

const SAMPLE_RATE := 44100
const MIX_RATE := 44100

# ADSR設定 (§10.8)
const ADSR_METAL := {"attack": 0.002, "decay": 0.05, "sustain": 0.3, "release": 0.1}
const ADSR_CHIME := {"attack": 0.005, "decay": 0.1, "sustain": 0.4, "release": 0.2}
const ADSR_CLICK := {"attack": 0.001, "decay": 0.02, "sustain": 0.0, "release": 0.02}
const ADSR_BEEP := {"attack": 0.001, "decay": 0.01, "sustain": 0.8, "release": 0.05}

# SE名→生成関数マッピング
var _generators: Dictionary = {}

func _ready() -> void:
	_generators = {
		"lever_pull": _gen_lever_pull,
		"reel_start": _gen_reel_start,
		"reel_stop_l": _gen_reel_stop.bind(220.0),
		"reel_stop_c": _gen_reel_stop.bind(330.0),
		"reel_stop_r": _gen_reel_stop.bind(440.0),
		"bet_insert": _gen_coin,
		"medal_single": _gen_coin,
		"medal_out": _gen_medal_out,
		"wait_tick": _gen_beep.bind(1000.0, 0.05),
		"big_fanfare": _gen_fanfare_big,
		"reg_fanfare": _gen_fanfare_reg,
		"bonus_end": _gen_bonus_end,
		"cherry_win": _gen_chime.bind([880.0, 1100.0]),
		"bell_win": _gen_chime.bind([660.0, 880.0, 1100.0]),
		"replay_win": _gen_beep.bind(800.0, 0.1),
		"ice_win": _gen_crystal,
		"reach_me": _gen_low_rumble,
		"tamaya": _gen_tamaya,
		"blackout": _gen_blackout_se,
		"flash": _gen_flash_se,
		"flash_premium": _gen_flash_premium,
		"bonus_align": _gen_bonus_align,
		"rt_start": _gen_rt_start,
	}

## AudioManagerから呼ばれるエントリーポイント
func generate_se(se_name: String) -> AudioStream:
	if _generators.has(se_name):
		return _generators[se_name].call()
	return _gen_beep.call(440.0, 0.1)  # デフォルト

# --- 基本波形生成 ---

func _make_wav(data: PackedByteArray) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.data = data
	return wav

func _adsr_envelope(t: float, duration: float, adsr: Dictionary) -> float:
	var a: float = adsr["attack"]
	var d: float = adsr["decay"]
	var s: float = adsr["sustain"]
	var r: float = adsr["release"]
	var release_start := duration - r

	if t < a:
		return t / a if a > 0 else 1.0
	elif t < a + d:
		return 1.0 - (1.0 - s) * ((t - a) / d) if d > 0 else s
	elif t < release_start:
		return s
	else:
		var rel_t := (t - release_start) / r if r > 0 else 0.0
		return s * (1.0 - rel_t)

func _sine(phase: float) -> float:
	return sin(phase * TAU)

func _noise() -> float:
	return randf() * 2.0 - 1.0

func _samples_for(duration: float) -> int:
	return int(duration * SAMPLE_RATE)

func _pack_sample(value: float) -> PackedByteArray:
	var s := clampi(int(value * 32767.0), -32768, 32767)
	var bytes := PackedByteArray()
	bytes.resize(2)
	bytes.encode_s16(0, s)
	return bytes

# --- SE生成関数 ---

## レバー: 金属音 = 基本周波数 + ノイズ(0.3) + 2.5倍音(0.15)
func _gen_lever_pull() -> AudioStreamWAV:
	var duration := 0.2
	var freq := 300.0
	var data := PackedByteArray()
	for i in range(_samples_for(duration)):
		var t := float(i) / SAMPLE_RATE
		var env := _adsr_envelope(t, duration, ADSR_METAL)
		var phase := t * freq
		var val := _sine(phase) * 0.5 + _noise() * 0.3 + _sine(phase * 2.5) * 0.15
		data.append_array(_pack_sample(val * env * 0.6))
	return _make_wav(data)

## リール回転開始: 上昇するモーター音
func _gen_reel_start() -> AudioStreamWAV:
	var duration := 0.4
	var data := PackedByteArray()
	for i in range(_samples_for(duration)):
		var t := float(i) / SAMPLE_RATE
		var env := _adsr_envelope(t, duration, ADSR_BEEP)
		var freq := lerpf(100.0, 400.0, t / duration)
		var phase := t * freq
		var val := _sine(phase) * 0.4 + _noise() * 0.1
		data.append_array(_pack_sample(val * env * 0.5))
	return _make_wav(data)

## リール停止: クリック音 (周波数可変)
func _gen_reel_stop(freq: float) -> AudioStreamWAV:
	var duration := 0.05
	var data := PackedByteArray()
	for i in range(_samples_for(duration)):
		var t := float(i) / SAMPLE_RATE
		var env := _adsr_envelope(t, duration, ADSR_CLICK)
		var val := _sine(t * freq) * 0.6 + _noise() * 0.4
		data.append_array(_pack_sample(val * env * 0.7))
	return _make_wav(data)

## コイン音: チャリン
func _gen_coin() -> AudioStreamWAV:
	var duration := 0.15
	var data := PackedByteArray()
	for i in range(_samples_for(duration)):
		var t := float(i) / SAMPLE_RATE
		var env := _adsr_envelope(t, duration, ADSR_METAL)
		var val := _sine(t * 2200.0) * 0.4 + _sine(t * 3300.0) * 0.3 + _noise() * 0.1
		data.append_array(_pack_sample(val * env * 0.5))
	return _make_wav(data)

## メダル払出: ジャラジャラ
func _gen_medal_out() -> AudioStreamWAV:
	var duration := 0.6
	var data := PackedByteArray()
	for i in range(_samples_for(duration)):
		var t := float(i) / SAMPLE_RATE
		var env := _adsr_envelope(t, duration, ADSR_METAL)
		var coin_freq := 2200.0 + sin(t * 30.0) * 500.0
		var val := _sine(t * coin_freq) * 0.3 + _noise() * 0.3
		data.append_array(_pack_sample(val * env * 0.5))
	return _make_wav(data)

## ビープ音 (汎用)
func _gen_beep(freq: float, duration: float) -> AudioStreamWAV:
	var data := PackedByteArray()
	for i in range(_samples_for(duration)):
		var t := float(i) / SAMPLE_RATE
		var env := _adsr_envelope(t, duration, ADSR_BEEP)
		var val := _sine(t * freq)
		data.append_array(_pack_sample(val * env * 0.5))
	return _make_wav(data)

## チャイム音 (入賞系): 複数音の上行
func _gen_chime(freqs: Array) -> AudioStreamWAV:
	var note_dur := 0.15
	var duration := note_dur * freqs.size() + 0.2
	var data := PackedByteArray()
	for i in range(_samples_for(duration)):
		var t := float(i) / SAMPLE_RATE
		var val := 0.0
		for idx in range(freqs.size()):
			var note_start := note_dur * idx
			var note_t := t - note_start
			if note_t >= 0.0 and note_t < note_dur + 0.2:
				var env := _adsr_envelope(note_t, note_dur + 0.2, ADSR_CHIME)
				var freq: float = freqs[idx]
				val += _sine(note_t * freq) * env * 0.3
				val += _sine(note_t * freq * 2.0) * env * 0.1  # 2倍音
		data.append_array(_pack_sample(val * 0.6))
	return _make_wav(data)

## クリスタル音 (氷入賞)
func _gen_crystal() -> AudioStreamWAV:
	var duration := 0.4
	var data := PackedByteArray()
	for i in range(_samples_for(duration)):
		var t := float(i) / SAMPLE_RATE
		var env := _adsr_envelope(t, duration, ADSR_CHIME)
		var val := _sine(t * 2000.0) * 0.3 + _sine(t * 3000.0) * 0.2 + _sine(t * 4500.0) * 0.1
		val *= (1.0 + sin(t * 20.0) * 0.3)  # きらきらモジュレーション
		data.append_array(_pack_sample(val * env * 0.5))
	return _make_wav(data)

## 低音ルンブル (リーチ目)
func _gen_low_rumble() -> AudioStreamWAV:
	var duration := 0.3
	var data := PackedByteArray()
	for i in range(_samples_for(duration)):
		var t := float(i) / SAMPLE_RATE
		var env := _adsr_envelope(t, duration, ADSR_BEEP)
		var val := _sine(t * 80.0) * 0.6 + _sine(t * 120.0) * 0.3 + _noise() * 0.1
		data.append_array(_pack_sample(val * env * 0.7))
	return _make_wav(data)

## BIGファンファーレ (Cメジャー進行, 3秒)
func _gen_fanfare_big() -> AudioStreamWAV:
	# C-E-G-C(oct) の上行アルペジオ
	var notes := [261.6, 329.6, 392.0, 523.3]
	var note_dur := 0.5
	var duration := 3.0
	var data := PackedByteArray()
	for i in range(_samples_for(duration)):
		var t := float(i) / SAMPLE_RATE
		var val := 0.0
		for idx in range(notes.size()):
			var start := note_dur * idx
			var nt := t - start
			if nt >= 0.0:
				var env := maxf(0.0, 1.0 - nt * 0.4)
				val += _sine(nt * notes[idx]) * env * 0.25
				val += _sine(nt * notes[idx] * 2.0) * env * 0.1
		# 最後のコード持続
		if t > 2.0:
			var chord_env := maxf(0.0, 1.0 - (t - 2.0))
			val += _sine(t * 261.6) * chord_env * 0.15
			val += _sine(t * 329.6) * chord_env * 0.15
			val += _sine(t * 392.0) * chord_env * 0.15
		data.append_array(_pack_sample(val * 0.6))
	return _make_wav(data)

## REGファンファーレ (控えめ, 2秒)
func _gen_fanfare_reg() -> AudioStreamWAV:
	var notes := [392.0, 440.0, 523.3]
	var note_dur := 0.3
	var duration := 2.0
	var data := PackedByteArray()
	for i in range(_samples_for(duration)):
		var t := float(i) / SAMPLE_RATE
		var val := 0.0
		for idx in range(notes.size()):
			var start := note_dur * idx
			var nt := t - start
			if nt >= 0.0:
				var env := maxf(0.0, 1.0 - nt * 0.6)
				val += _sine(nt * notes[idx]) * env * 0.2
		data.append_array(_pack_sample(val * 0.5))
	return _make_wav(data)

## ボーナス終了ジングル (1.5秒)
func _gen_bonus_end() -> AudioStreamWAV:
	var notes := [523.3, 440.0, 349.2]  # 下行
	var note_dur := 0.3
	var duration := 1.5
	var data := PackedByteArray()
	for i in range(_samples_for(duration)):
		var t := float(i) / SAMPLE_RATE
		var val := 0.0
		for idx in range(notes.size()):
			var start := note_dur * idx
			var nt := t - start
			if nt >= 0.0:
				var env := maxf(0.0, 1.0 - nt * 0.5)
				val += _sine(nt * notes[idx]) * env * 0.2
		data.append_array(_pack_sample(val * 0.5))
	return _make_wav(data)

## たーまやー (ボイス風電子音)
func _gen_tamaya() -> AudioStreamWAV:
	var duration := 1.0
	var data := PackedByteArray()
	for i in range(_samples_for(duration)):
		var t := float(i) / SAMPLE_RATE
		var env := _adsr_envelope(t, duration, ADSR_CHIME)
		# フォルマント風: 複数周波数
		var val := _sine(t * 400.0) * 0.3 + _sine(t * 800.0) * 0.2 + _sine(t * 1200.0) * 0.1
		# ビブラート
		val *= (1.0 + sin(t * 6.0) * 0.15)
		data.append_array(_pack_sample(val * env * 0.6))
	return _make_wav(data)

## 消灯SE (低い「ドン」)
func _gen_blackout_se() -> AudioStreamWAV:
	var duration := 0.15
	var data := PackedByteArray()
	for i in range(_samples_for(duration)):
		var t := float(i) / SAMPLE_RATE
		var env := _adsr_envelope(t, duration, ADSR_CLICK)
		var val := _sine(t * 100.0) * 0.7 + _noise() * 0.2
		data.append_array(_pack_sample(val * env * 0.7))
	return _make_wav(data)

## フラッシュSE (キラッ)
func _gen_flash_se() -> AudioStreamWAV:
	var duration := 0.1
	var data := PackedByteArray()
	for i in range(_samples_for(duration)):
		var t := float(i) / SAMPLE_RATE
		var env := _adsr_envelope(t, duration, ADSR_CLICK)
		var val := _sine(t * 2000.0) * 0.5 + _sine(t * 4000.0) * 0.2
		data.append_array(_pack_sample(val * env * 0.6))
	return _make_wav(data)

## フラッシュ・プレミアム (BLOOM-TAMAYA用, 和音)
func _gen_flash_premium() -> AudioStreamWAV:
	var duration := 0.3
	var data := PackedByteArray()
	for i in range(_samples_for(duration)):
		var t := float(i) / SAMPLE_RATE
		var env := _adsr_envelope(t, duration, ADSR_CHIME)
		var val := _sine(t * 1500.0) * 0.2 + _sine(t * 2000.0) * 0.2 + _sine(t * 2500.0) * 0.2
		val += _sine(t * 3000.0) * 0.1
		data.append_array(_pack_sample(val * env * 0.5))
	return _make_wav(data)

## ボーナス図柄揃い (ドラマチック)
func _gen_bonus_align() -> AudioStreamWAV:
	var duration := 0.5
	var data := PackedByteArray()
	for i in range(_samples_for(duration)):
		var t := float(i) / SAMPLE_RATE
		var env := _adsr_envelope(t, duration, ADSR_METAL)
		var val := _sine(t * 200.0) * 0.4 + _sine(t * 400.0) * 0.3
		val += _noise() * 0.2 * maxf(0.0, 1.0 - t * 4.0)  # ノイズバースト
		val += _sine(t * 600.0) * 0.15
		data.append_array(_pack_sample(val * env * 0.6))
	return _make_wav(data)

## RT開始 (上昇音)
func _gen_rt_start() -> AudioStreamWAV:
	var duration := 0.3
	var data := PackedByteArray()
	for i in range(_samples_for(duration)):
		var t := float(i) / SAMPLE_RATE
		var env := _adsr_envelope(t, duration, ADSR_BEEP)
		var freq := lerpf(400.0, 1200.0, t / duration)
		var val := _sine(t * freq) * 0.5
		data.append_array(_pack_sample(val * env * 0.5))
	return _make_wav(data)
