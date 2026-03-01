class_name ProductionTable
extends RefCounted
## 演出振り分けテーブル（消灯/フラッシュ/遅れ/たまや）

# 消灯演出振り分け (256分母)
const BLACKOUT_TABLE := {
	PayTable.Flag.HAZURE:    { 0: 128, 1: 0, 2: 0, 3: 128 },
	PayTable.Flag.REPLAY:    { 0: 0, 1: 64, 2: 0, 3: 192 },
	PayTable.Flag.CHERRY_2:  { 0: 64, 1: 64, 2: 0, 3: 128 },
	PayTable.Flag.CHERRY_4:  { 0: 32, 1: 64, 2: 0, 3: 160 },
	PayTable.Flag.BELL:      { 0: 128, 1: 128, 2: 0, 3: 0 },
	PayTable.Flag.ICE:       { 0: 64, 1: 0, 2: 0, 3: 192 },
	PayTable.Flag.BIG_RED:   { 0: 32, 1: 32, 2: 128, 3: 64 },
	PayTable.Flag.BIG_BLUE:  { 0: 32, 1: 32, 2: 128, 3: 64 },
	PayTable.Flag.REG:       { 0: 64, 1: 64, 2: 0, 3: 128 },
}

# フラッシュ演出振り分け (256分母、3消灯時のみ)
const FLASH_TABLE := {
	PayTable.Flag.HAZURE:    { "SPARK": 128, "GLITCH": 96, "NEON_SIGN": 32 },
	PayTable.Flag.REPLAY:    { "SPARK": 64, "GLITCH": 64, "NEON_SIGN": 64, "STROBE": 48, "DROP": 16 },
	PayTable.Flag.CHERRY_2:  { "SPARK": 32, "GLITCH": 48, "NEON_SIGN": 64, "STROBE": 64, "DROP": 32, "BLOOM": 16 },
	PayTable.Flag.CHERRY_4:  { "GLITCH": 16, "NEON_SIGN": 32, "STROBE": 48, "DROP": 64, "BLOOM": 64, "STARMINE": 32 },
	PayTable.Flag.ICE:       { "SPARK": 32, "GLITCH": 32, "NEON_SIGN": 64, "STROBE": 64, "DROP": 48, "BLOOM": 16 },
	PayTable.Flag.BIG_RED:   { "NEON_SIGN": 8, "STROBE": 16, "DROP": 32, "BLOOM": 64, "STARMINE": 96, "TAMAYA": 40 },
	PayTable.Flag.BIG_BLUE:  { "NEON_SIGN": 8, "STROBE": 16, "DROP": 32, "BLOOM": 64, "STARMINE": 96, "TAMAYA": 40 },
	PayTable.Flag.REG:       { "GLITCH": 8, "NEON_SIGN": 24, "STROBE": 48, "DROP": 64, "BLOOM": 64, "STARMINE": 48 },
}

# 遅れ演出テーブル (256分母) - ボーナスフラグのみ発生
const DELAY_TABLE := {
	PayTable.Flag.HAZURE: 0,
	PayTable.Flag.REPLAY: 0,
	PayTable.Flag.CHERRY_2: 0,
	PayTable.Flag.CHERRY_4: 0,
	PayTable.Flag.BELL: 0,
	PayTable.Flag.ICE: 0,
	PayTable.Flag.BIG_RED: 48,
	PayTable.Flag.BIG_BLUE: 48,
	PayTable.Flag.REG: 32,
}

const TAMAYA_DENOMINATOR := 6

static func select_production(flag: PayTable.Flag, bonus_stocked: bool) -> Dictionary:
	var result := {
		"blackout": 0,
		"flash": "",
		"delay": false,
		"tamaya": false,
	}

	result["blackout"] = _weighted_select_int(BLACKOUT_TABLE.get(flag, { 0: 256 }))

	if result["blackout"] == 3 and flag in FLASH_TABLE:
		result["flash"] = _weighted_select_string(FLASH_TABLE[flag])

	var delay_chance: int = DELAY_TABLE.get(flag, 0)
	if delay_chance > 0:
		result["delay"] = (randi() % 256) < delay_chance

	if bonus_stocked:
		result["tamaya"] = (randi() % TAMAYA_DENOMINATOR) == 0

	return result

static func _weighted_select_int(table: Dictionary) -> int:
	var rand := randi() % 256
	var cumulative := 0
	for key in table:
		cumulative += table[key]
		if rand < cumulative:
			return key
	return table.keys()[0]

static func _weighted_select_string(table: Dictionary) -> String:
	var rand := randi() % 256
	var cumulative := 0
	for key in table:
		cumulative += table[key]
		if rand < cumulative:
			return key
	return table.keys()[0]
