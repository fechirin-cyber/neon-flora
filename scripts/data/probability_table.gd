class_name ProbabilityTable
extends RefCounted
## 内部抽選テーブル（設定1-6、65536分母）

static func get_normal_table(setting: int) -> Dictionary:
	var big_red_w: int
	var big_blue_w: int
	var reg_w: int
	var cherry_2_w := 7999
	var cherry_4_w := 272
	var bell_w := 916
	var ice_w := 920
	var replay_w := 8979

	match setting:
		1:
			big_red_w = 110
			big_blue_w = 110
			reg_w = 156
		2:
			big_red_w = 116
			big_blue_w = 116
			reg_w = 156
		3:
			big_red_w = 122
			big_blue_w = 122
			reg_w = 156
		4:
			big_red_w = 132
			big_blue_w = 132
			reg_w = 156
		5:
			big_red_w = 136
			big_blue_w = 136
			reg_w = 168
		6:
			big_red_w = 142
			big_blue_w = 142
			reg_w = 180
		_:
			big_red_w = 110
			big_blue_w = 110
			reg_w = 156

	return {
		PayTable.Flag.REPLAY: replay_w,
		PayTable.Flag.CHERRY_2: cherry_2_w,
		PayTable.Flag.CHERRY_4: cherry_4_w,
		PayTable.Flag.BELL: bell_w,
		PayTable.Flag.ICE: ice_w,
		PayTable.Flag.BIG_RED: big_red_w,
		PayTable.Flag.BIG_BLUE: big_blue_w,
		PayTable.Flag.REG: reg_w,
	}

static func get_big_table() -> Dictionary:
	return {
		PayTable.Flag.REPLAY: 19988,
		PayTable.Flag.CHERRY_2: 128,
		PayTable.Flag.CHERRY_4: 0,
		PayTable.Flag.BELL: 27000,
		PayTable.Flag.ICE: 5464,
		PayTable.Flag.BIG_RED: 0,
		PayTable.Flag.BIG_BLUE: 0,
		PayTable.Flag.REG: 0,
	}

static func get_reg_table() -> Dictionary:
	return get_big_table()

static func get_rt_table(setting: int, bonus_rate: float = 1.0) -> Dictionary:
	var table := get_normal_table(setting)
	table[PayTable.Flag.REPLAY] = 36409
	# BIG_BLUE後はボーナス確率を補正
	if bonus_rate != 1.0:
		table[PayTable.Flag.BIG_RED] = int(table[PayTable.Flag.BIG_RED] * bonus_rate)
		table[PayTable.Flag.BIG_BLUE] = int(table[PayTable.Flag.BIG_BLUE] * bonus_rate)
		table[PayTable.Flag.REG] = int(table[PayTable.Flag.REG] * bonus_rate)
	return table

static func lottery(table: Dictionary) -> PayTable.Flag:
	var rand := randi() % 65536
	var cumulative := 0
	for flag in table:
		cumulative += table[flag]
		if rand < cumulative:
			return flag
	return PayTable.Flag.HAZURE
