class_name ReelData
extends RefCounted
## リール配列定義（各21コマ、BLKなし）

const S7R = 0  # 赤7
const S7B = 1  # 青7
const BAR = 2  # BAR
const CHR = 3  # チェリー
const BEL = 4  # ベル
const ICE = 5  # 氷
const RPL = 6  # リプレイ

const REEL_SIZE := 21

# LEFT（3連BEL配置 pos2-4 — ハナビの3連どんちゃんに相当）
const LEFT: Array[int] = [
	CHR, RPL, BEL, BEL, BEL, S7R, ICE, RPL, BEL, RPL,
	S7B, BEL, CHR, RPL, BEL, ICE, BEL, BAR, RPL, BEL, BEL
]

# CENTER
const CENTER: Array[int] = [
	S7R, RPL, BEL, ICE, RPL, BEL, BEL, RPL, BEL, S7B,
	ICE, RPL, BEL, BEL, RPL, ICE, BEL, BAR, RPL, BEL, BEL
]

# RIGHT
const RIGHT: Array[int] = [
	BEL, RPL, S7R, BEL, ICE, RPL, BEL, RPL, BEL, BEL,
	BAR, RPL, ICE, BEL, RPL, S7B, BEL, ICE, RPL, BEL, BEL
]

static func get_reel(index: int) -> Array[int]:
	match index:
		0: return LEFT
		1: return CENTER
		2: return RIGHT
		_: return LEFT

static func get_symbol_at(reel_idx: int, pos: int) -> int:
	var reel := get_reel(reel_idx)
	return reel[posmod(pos, REEL_SIZE)]

static func get_window(reel_idx: int, center_pos: int) -> Array[int]:
	var reel := get_reel(reel_idx)
	return [
		reel[posmod(center_pos - 1, REEL_SIZE)],
		reel[posmod(center_pos, REEL_SIZE)],
		reel[posmod(center_pos + 1, REEL_SIZE)],
	]
