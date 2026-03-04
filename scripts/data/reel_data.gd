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

# LEFT（3連S7R配置 pos12-14 — ハナビの3連どんちゃんに相当）
# クロスアライメント最適化済: 異なる入賞役が同時に揃わない配置
# S7R×3, S7B×1, BAR×1, CHR×2, BEL×7, ICE×2, RPL×5
# BEL gap≤5, RPL gap≤5（4コマ滑りで常に到達可能）
const LEFT: Array[int] = [
	RPL, CHR, BEL, RPL, ICE, BEL, BAR, BEL, RPL, S7B,
	BEL, RPL, S7R, S7R, S7R, BEL, RPL, ICE, BEL, CHR, BEL
]

# CENTER（クロスアライメント最適化済）
# S7R×1, S7B×1, BAR×1, BEL×9, ICE×3, RPL×6
# BEL gap≤3, RPL gap≤5
const CENTER: Array[int] = [
	BEL, RPL, BEL, ICE, BEL, RPL, BEL, ICE, RPL, BEL,
	ICE, BEL, S7R, RPL, BEL, BAR, RPL, BEL, RPL, BEL, S7B
]

# RIGHT（クロスアライメント最適化済）
# S7R×1, S7B×1, BAR×1, BEL×9, ICE×3, RPL×6
# BEL gap≤5, RPL gap≤4
const RIGHT: Array[int] = [
	BAR, RPL, BEL, ICE, RPL, BEL, BEL, S7B, RPL, BEL,
	BEL, ICE, RPL, BEL, BEL, ICE, RPL, BEL, BEL, S7R, RPL
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
