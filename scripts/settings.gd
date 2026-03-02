extends Control
## 設定画面 (§12)

func _ready() -> void:
	# 背景
	var bg := ColorRect.new()
	bg.anchors_preset = Control.PRESET_FULL_RECT
	bg.color = Color(0.039, 0.039, 0.118, 1.0)
	add_child(bg)

	# タイトル
	var title := Label.new()
	title.text = "SETTINGS"
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(0.0, 1.0, 0.53, 1.0))
	title.position = Vector2(0.0, 60.0)
	title.size = Vector2(900.0, 60.0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)

	# 統計表示
	var y := 180.0
	var stats := [
		["Total Games", str(GameData.total_games)],
		["Total IN", str(GameData.total_in)],
		["Total OUT", str(GameData.total_out)],
		["BIG Count", str(GameData.big_count)],
		["REG Count", str(GameData.reg_count)],
		["Credit", str(GameData.credit)],
	]
	for stat in stats:
		var lbl := Label.new()
		lbl.text = "%s: %s" % [stat[0], stat[1]]
		lbl.add_theme_font_size_override("font_size", 22)
		lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.9, 1.0))
		lbl.position = Vector2(100.0, y)
		lbl.size = Vector2(700.0, 40.0)
		add_child(lbl)
		y += 50.0

	# リセットボタン
	var reset_btn := Button.new()
	reset_btn.text = "RESET STATS"
	reset_btn.custom_minimum_size = Vector2(250.0, 60.0)
	reset_btn.position = Vector2(325.0, y + 40.0)
	reset_btn.add_theme_font_size_override("font_size", 20)
	var reset_style := StyleBoxFlat.new()
	reset_style.bg_color = Color(0.8, 0.1, 0.1, 1.0)
	reset_style.set_corner_radius_all(8)
	reset_btn.add_theme_stylebox_override("normal", reset_style)
	reset_btn.pressed.connect(_on_reset)
	add_child(reset_btn)

	# 戻るボタン
	var back_btn := Button.new()
	back_btn.text = "BACK"
	back_btn.custom_minimum_size = Vector2(250.0, 60.0)
	back_btn.position = Vector2(325.0, y + 130.0)
	back_btn.add_theme_font_size_override("font_size", 20)
	var back_style := StyleBoxFlat.new()
	back_style.bg_color = Color(0.176, 0.176, 0.267, 1.0)
	back_style.set_corner_radius_all(8)
	back_btn.add_theme_stylebox_override("normal", back_style)
	back_btn.pressed.connect(_on_back)
	add_child(back_btn)

func _on_reset() -> void:
	GameData.reset_stats()

func _on_back() -> void:
	get_tree().change_scene_to_file("res://scenes/TitleScreen.tscn")
