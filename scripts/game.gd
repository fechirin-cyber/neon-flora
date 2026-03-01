extends Control
## ゲーム画面制御（プリプロ: テキストUI）

var _bet_done: bool = false

@onready var _state_label: Label = $StateLabel
@onready var _credit_label: Label = $CreditLabel
@onready var _reel_label: Label = $ReelLabel
@onready var _info_label: Label = $InfoLabel
@onready var _buttons_label: Label = $ButtonsLabel

func _ready() -> void:
	SlotEngine.game_state_changed.connect(_on_state_changed)
	SlotEngine.credit_changed.connect(_on_credit_changed)
	SlotEngine.flag_determined.connect(_on_flag_determined)
	SlotEngine.reel_stop_calculated.connect(_on_reel_stopped)
	SlotEngine.all_reels_stopped.connect(_on_all_stopped)
	SlotEngine.payout_started.connect(_on_payout_started)
	SlotEngine.payout_finished.connect(_on_payout_finished)
	SlotEngine.bonus_triggered.connect(_on_bonus_triggered)
	SlotEngine.bonus_ended.connect(_on_bonus_ended)
	SlotEngine.rt_started.connect(_on_rt_started)
	SlotEngine.rt_ended.connect(_on_rt_ended)
	SlotEngine.reach_me_detected.connect(_on_reach_me)
	_update_display()

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return

	match event.keycode:
		KEY_B:
			_do_bet()
		KEY_SPACE:
			_do_lever()
		KEY_Z:
			_do_stop(0)
		KEY_X:
			_do_stop(1)
		KEY_C:
			_do_stop(2)
		KEY_D:
			SlotEngine.debug_start_bonus_now("BIG")
		KEY_R:
			SlotEngine.debug_start_bonus_now("REG")
		KEY_T:
			SlotEngine.debug_add_credit(1000)
		KEY_P:
			SlotEngine.debug_write_state_file()
			_info_label.text = "State written to debug_state.json"

func _do_bet() -> void:
	var state := SlotEngine.game_state
	if state != SlotEngine.GameState.IDLE and state != SlotEngine.GameState.BONUS and state != SlotEngine.GameState.RT:
		return
	if SlotEngine.do_bet(3):
		_bet_done = true
		_update_display()

func _do_lever() -> void:
	if not _bet_done:
		return
	_bet_done = false
	_reel_label.text = ""
	SlotEngine.pull_lever()

func _do_stop(reel_idx: int) -> void:
	var state := SlotEngine.game_state
	if state != SlotEngine.GameState.SPINNING and state != SlotEngine.GameState.STOPPING:
		return
	# プリプロ: ランダム停止位置（目押し相当）
	var pressed_pos := randi() % ReelData.REEL_SIZE
	SlotEngine.stop_reel(reel_idx, pressed_pos)

# --- Signal handlers ---
func _on_state_changed(_new_state: SlotEngine.GameState) -> void:
	_update_display()

func _on_credit_changed(_new_credit: int) -> void:
	_update_display()

func _on_flag_determined(flag: PayTable.Flag, production: Dictionary) -> void:
	var flag_name: String = PayTable.Flag.keys()[flag]
	var blackout: int = production.get("blackout", 0)
	var delay: bool = production.get("delay", false)
	_info_label.text = "Flag: %s | 消灯: %d%s" % [flag_name, blackout, " | 遅れ!" if delay else ""]

func _on_reel_stopped(reel_idx: int, _target_pos: int, window: Array) -> void:
	var names := ["LEFT", "CENTER", "RIGHT"]
	var symbols: Array[String] = []
	for s in window:
		symbols.append(SymbolTable.get_symbol_name(s))
	var line := "%s: [%s | %s | %s]" % [names[reel_idx], symbols[0], symbols[1], symbols[2]]
	if _reel_label.text == "":
		_reel_label.text = line
	else:
		_reel_label.text += "\n" + line
	_update_display()

func _on_all_stopped() -> void:
	pass

func _on_payout_started(amount: int, flag: PayTable.Flag) -> void:
	if flag == PayTable.Flag.REPLAY:
		_info_label.text = "REPLAY!"
		_bet_done = true  # リプレイ: BET不要で次ゲーム
	elif amount > 0:
		_info_label.text = "WIN: %d枚" % amount

func _on_payout_finished() -> void:
	_update_display()

func _on_bonus_triggered(bonus_type: String) -> void:
	_info_label.text = "*** %s BONUS START! ***" % bonus_type

func _on_bonus_ended(bonus_type: String, total_payout: int) -> void:
	_info_label.text = "%s BONUS END — Total: %d枚" % [bonus_type, total_payout]

func _on_rt_started(max_games: int) -> void:
	_info_label.text = "RT START (%dG)" % max_games

func _on_rt_ended() -> void:
	_info_label.text = "RT END"

func _on_reach_me(pattern_name: String) -> void:
	_info_label.text = "REACH ME: %s" % pattern_name

# --- Display ---
func _update_display() -> void:
	var state_name: String = SlotEngine.GameState.keys()[SlotEngine.game_state]
	_state_label.text = "State: %s | G: %d | BIG: %d | REG: %d" % [
		state_name, GameData.total_games, GameData.big_count, GameData.reg_count]

	var cr_text := "CREDIT: %d | IN: %d | OUT: %d" % [
		GameData.credit, GameData.total_in, GameData.total_out]
	if SlotEngine.is_in_bonus():
		var remaining := SlotEngine.get_bonus_remaining()
		var played := SlotEngine.get_bonus_games_played()
		cr_text += " | BONUS: %d/%dG PAY:%d" % [played, played + remaining, SlotEngine.get_bonus_payout()]
	if SlotEngine.is_rt_active():
		cr_text += " | RT: %dG" % SlotEngine.get_rt_remaining()
	_credit_label.text = cr_text

	_update_buttons_display()

func _update_buttons_display() -> void:
	var state := SlotEngine.game_state
	var btns := ""
	match state:
		SlotEngine.GameState.IDLE, SlotEngine.GameState.BONUS, SlotEngine.GameState.RT:
			if _bet_done:
				btns = "[B:--] [SPACE:LEVER] [Z:--] [X:--] [C:--]"
			elif GameData.credit >= 3:
				btns = "[B:BET] [SPACE:--] [Z:--] [X:--] [C:--]"
			else:
				btns = "CREDIT不足"
		SlotEngine.GameState.SPINNING, SlotEngine.GameState.STOPPING:
			var z := "STOP" if not SlotEngine.reel_stopped[0] else "--"
			var x := "STOP" if not SlotEngine.reel_stopped[1] else "--"
			var c := "STOP" if not SlotEngine.reel_stopped[2] else "--"
			btns = "[B:--] [SPACE:--] [Z:%s] [X:%s] [C:%s]" % [z, x, c]
		_:
			btns = "..."
	_buttons_label.text = btns
