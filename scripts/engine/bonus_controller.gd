class_name BonusController
extends RefCounted
## ボーナス/RT管理（ゲーム数管理方式）

# §7.9: BIG演出フェーズ
enum BonusPhase { NONE, OPENING, CLIMAX, FINALE }
# §7.10: RT演出フェーズ
enum RtPhase { NONE, CALM, RISING, CLIMAX }

var bonus_flag_stocked: PayTable.Flag = PayTable.Flag.HAZURE
var bonus_type: String = ""  # "BIG" or "REG" or ""
var bonus_type_internal: PayTable.Flag = PayTable.Flag.HAZURE  # 内部区分保持（BIG_RED/BIG_BLUE/REG）
var bonus_games_played: int = 0  # リプレイ除外ゲーム数
var bonus_games_max: int = 0
var bonus_payout: int = 0  # 配当合計（表示用）
var last_bonus_between: int = 0
var bonus_phase: BonusPhase = BonusPhase.NONE

var rt_active: bool = false
var rt_remaining: int = 0
var rt_bonus_rate: float = 1.0  # BIG_BLUE後は1.5倍
var rt_phase: RtPhase = RtPhase.NONE
var rt_is_blue: bool = false  # BIG_BLUE後RTかどうか

func is_bonus_stocked() -> bool:
	return bonus_flag_stocked != PayTable.Flag.HAZURE

func is_in_bonus() -> bool:
	return bonus_type != ""

func stock_bonus(flag: PayTable.Flag) -> void:
	bonus_flag_stocked = flag

func start_bonus() -> Dictionary:
	bonus_type_internal = bonus_flag_stocked
	var is_big := PayTable.is_big(bonus_flag_stocked)
	if is_big:
		bonus_type = "BIG"
		bonus_games_max = PayTable.BIG_MAX_GAMES
	else:
		bonus_type = "REG"
		bonus_games_max = PayTable.REG_MAX_GAMES
	bonus_games_played = 0
	bonus_payout = 0
	bonus_phase = BonusPhase.OPENING if is_big else BonusPhase.NONE
	var type := bonus_type
	bonus_flag_stocked = PayTable.Flag.HAZURE
	var between := last_bonus_between
	last_bonus_between = 0
	return {"type": type, "between": between, "is_big": is_big, "internal_flag": bonus_type_internal}

func tick_bonus_game(is_replay: bool, payout: int) -> bool:
	## ボーナス1ゲーム消化。リプレイ除外でカウント。終了時trueを返す
	bonus_payout += payout
	if is_replay:
		return false
	bonus_games_played += 1
	return bonus_games_played >= bonus_games_max

func end_bonus() -> Dictionary:
	var type := bonus_type
	var payout := bonus_payout
	var games := bonus_games_played
	var internal_flag := bonus_type_internal
	bonus_type = ""
	bonus_games_played = 0
	bonus_games_max = 0
	bonus_payout = 0
	bonus_phase = BonusPhase.NONE
	bonus_type_internal = PayTable.Flag.HAZURE
	return {"type": type, "payout": payout, "games": games, "internal_flag": internal_flag}

func start_rt(bonus_internal_flag: PayTable.Flag) -> void:
	rt_active = true
	rt_remaining = PayTable.RT_MAX_GAMES
	rt_is_blue = bonus_internal_flag == PayTable.Flag.BIG_BLUE
	rt_phase = RtPhase.CALM
	# BIG_BLUE後はボーナス確率1.5倍
	rt_bonus_rate = 1.5 if rt_is_blue else 1.0

func tick_rt() -> bool:
	## Returns true if RT ended
	if not rt_active:
		return false
	rt_remaining -= 1
	if rt_remaining <= 0:
		rt_active = false
		rt_remaining = 0
		rt_bonus_rate = 1.0
		return true
	return false

func cancel_rt() -> void:
	rt_active = false
	rt_remaining = 0
	rt_bonus_rate = 1.0
	rt_phase = RtPhase.NONE
	rt_is_blue = false

func get_bonus_remaining() -> int:
	return bonus_games_max - bonus_games_played

## §7.9: BIGフェーズ判定（リプレイ除外ゲーム数ベース）
func get_bonus_phase() -> BonusPhase:
	if bonus_type != "BIG":
		return BonusPhase.NONE
	if bonus_games_played <= 15:
		return BonusPhase.OPENING
	elif bonus_games_played <= 35:
		return BonusPhase.CLIMAX
	else:
		return BonusPhase.FINALE

## §7.9: フェーズ更新（tick後に呼ぶ）。フェーズ変化時にtrueを返す
func update_bonus_phase() -> bool:
	var new_phase := get_bonus_phase()
	if new_phase != bonus_phase:
		bonus_phase = new_phase
		return true
	return false

## §7.10: RTフェーズ判定（消化ゲーム数 = 40 - remaining）
func get_rt_phase() -> RtPhase:
	if not rt_active:
		return RtPhase.NONE
	var played := PayTable.RT_MAX_GAMES - rt_remaining
	if played < 15:
		return RtPhase.CALM
	elif played < 30:
		return RtPhase.RISING
	else:
		return RtPhase.CLIMAX

## §7.10: RTフェーズ更新。変化時にtrueを返す
func update_rt_phase() -> bool:
	var new_phase := get_rt_phase()
	if new_phase != rt_phase:
		rt_phase = new_phase
		return true
	return false
