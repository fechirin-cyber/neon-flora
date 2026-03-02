class_name CharacterPanel
extends Control
## キャラクターパネル — 3キャラ×リアクション表示切替 (§7.7)

enum Reaction { IDLE, EXPECT, HAPPY, SAD, EXCITED, BONUS, REACH_ME }

const CHARACTER_SIZE := Vector2(300.0, 200.0)

var _current_character: String = "hikari"
var _current_reaction: Reaction = Reaction.IDLE
var _char_sprite: TextureRect
var _textures: Dictionary = {}

func _ready() -> void:
	_build_ui()
	_load_textures()
	_connect_signals()
	show_character("hikari", Reaction.IDLE)

func _build_ui() -> void:
	_char_sprite = TextureRect.new()
	_char_sprite.size = CHARACTER_SIZE
	_char_sprite.position = Vector2((size.x - CHARACTER_SIZE.x) / 2.0, 0.0)
	_char_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_char_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	add_child(_char_sprite)

func _load_textures() -> void:
	for char_name in AssetRegistry.get_all_characters():
		for react in AssetRegistry.get_character_reactions(char_name):
			var key := "%s_%s" % [char_name, react]
			var tex: Texture2D = AssetRegistry.load_character_texture(char_name, react)
			if tex:
				_textures[key] = tex
			else:
				_textures[key] = AssetRegistry.create_placeholder(
					CHARACTER_SIZE, AssetRegistry.PLACEHOLDER_COLORS["character"]
				)

func _connect_signals() -> void:
	SlotEngine.flag_determined.connect(_on_flag_determined)
	SlotEngine.payout_started.connect(_on_payout_started)
	SlotEngine.bonus_triggered.connect(_on_bonus_triggered)
	SlotEngine.bonus_ended.connect(_on_bonus_ended)
	SlotEngine.rt_started.connect(_on_rt_started)
	SlotEngine.rt_ended.connect(_on_rt_ended)
	SlotEngine.reach_me_detected.connect(_on_reach_me)
	SlotEngine.all_reels_stopped.connect(_on_all_stopped)

func show_character(char_name: String, reaction: Reaction) -> void:
	_current_character = char_name
	_current_reaction = reaction
	var react_names := ["idle", "expect", "happy", "sad", "excited", "bonus", "reach_me"]
	var key := "%s_%s" % [char_name, react_names[reaction]]
	if _textures.has(key):
		_char_sprite.texture = _textures[key]
	else:
		_char_sprite.texture = null

# --- Signal handlers (§7.7) ---

func _on_flag_determined(flag: PayTable.Flag, production: Dictionary) -> void:
	var blackout: int = production.get("blackout", 0)
	if blackout >= 2:
		show_character("hikari", Reaction.EXPECT)
	else:
		show_character("hikari", Reaction.IDLE)

func _on_payout_started(_amount: int, flag: PayTable.Flag) -> void:
	match flag:
		PayTable.Flag.REPLAY:
			show_character("hikari", Reaction.HAPPY)
		PayTable.Flag.CHERRY_2, PayTable.Flag.CHERRY_4, PayTable.Flag.BELL:
			show_character("hikari", Reaction.HAPPY)
		PayTable.Flag.ICE:
			show_character("hikari", Reaction.EXCITED)
		_:
			pass

func _on_all_stopped() -> void:
	var blackout: int = SlotEngine.current_production.get("blackout", 0)
	var flag: PayTable.Flag = SlotEngine.current_flag
	# ガセ演出: 3消灯→HAZURE = SAD
	if blackout >= 3 and flag == PayTable.Flag.HAZURE:
		show_character("hikari", Reaction.SAD)
		return
	# 通常: IDLEに戻す（payout_started で上書きされる場合あり）
	if not SlotEngine.is_in_bonus():
		show_character("hikari", Reaction.IDLE)

func _on_bonus_triggered(bonus_type: String) -> void:
	if bonus_type == "BIG":
		show_character("luna", Reaction.EXCITED)
	else:
		show_character("koharu", Reaction.HAPPY)

func _on_bonus_ended(_bonus_type: String, _total_payout: int) -> void:
	show_character("hikari", Reaction.IDLE)

func _on_rt_started(_max_games: int) -> void:
	show_character("hikari", Reaction.EXPECT)

func _on_rt_ended() -> void:
	show_character("hikari", Reaction.IDLE)

func _on_reach_me(_pattern_name: String) -> void:
	show_character("hikari", Reaction.REACH_ME)
