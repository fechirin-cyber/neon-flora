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

# LEFT（3連BEL配置 pos1-3 — ハナビの3連どんちゃんに相当）
# クロスアライメント最適化済: 異なる入賞役が同時に揃わない配置
# BEL gap≤5, RPL gap≤5（4コマ滑りで常に到達可能）
const LEFT: Array[int] = [
	CHR, BEL, BEL, BEL, RPL, BAR, BEL, BEL, RPL, CHR,
	BEL, BEL, BEL, RPL, ICE, S7R, ICE, BEL, RPL, S7B, RPL
]

# CENTER（BEL/RPLがLEFTと異なる相対位置に配置 → 水平ライン干渉を防止）
const CENTER: Array[int] = [
	RPL, BEL, BEL, BEL, S7R, RPL, RPL, BEL, S7B, ICE,
	RPL, BEL, BEL, ICE, RPL, BAR, RPL, BEL, BEL, BEL, ICE
]

# RIGHT（BEL-RPL交互配置で他リールとの位相差を最大化）
const RIGHT: Array[int] = [
	BEL, RPL, BEL, ICE, S7R, ICE, RPL, BEL, ICE, BEL,
	RPL, BEL, S7B, BEL, RPL, BEL, BAR, BEL, RPL, BEL, RPL
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
