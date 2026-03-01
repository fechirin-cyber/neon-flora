class_name PayTable
extends RefCounted
## 配当テーブル（役→払出枚数）+ ボーナス定数

# フラグ定義
enum Flag {
	HAZURE = 0,     # ハズレ
	REPLAY = 1,     # リプレイ
	CHERRY_2 = 2,   # 角チェリー（4枚 = 2枚×2ライン）
	CHERRY_4 = 3,   # 中段チェリー（2枚 = 2枚×1ライン）
	BELL = 4,       # ベル10枚
	ICE = 5,        # 氷15枚
	BIG_RED = 6,    # BIG（赤7）— 内部区分のみ
	BIG_BLUE = 7,   # BIG（青7）— 内部区分のみ
	REG = 8,        # REG（BAR揃い）
}

# 1ライン配当枚数
const PAYOUT_PER_LINE := {
	Flag.HAZURE: 0,
	Flag.REPLAY: 0,
	Flag.CHERRY_2: 2,   # 角チェリー: 2枚×2ライン = 4枚
	Flag.CHERRY_4: 2,   # 中段チェリー: 2枚×1ライン = 2枚
	Flag.BELL: 10,
	Flag.ICE: 15,
	Flag.BIG_RED: 0,
	Flag.BIG_BLUE: 0,
	Flag.REG: 0,
}

# ボーナス規定ゲーム数（リプレイ除外）
const BIG_MAX_GAMES := 45
const REG_MAX_GAMES := 14
const RT_MAX_GAMES := 40

static func get_payout_per_line(flag: Flag) -> int:
	return PAYOUT_PER_LINE[flag]

static func is_bonus_flag(flag: Flag) -> bool:
	return flag in [Flag.REG, Flag.BIG_RED, Flag.BIG_BLUE]

static func is_big(flag: Flag) -> bool:
	return flag in [Flag.BIG_RED, Flag.BIG_BLUE]

static func is_small_role(flag: Flag) -> bool:
	return flag in [Flag.CHERRY_2, Flag.CHERRY_4, Flag.BELL, Flag.ICE]
