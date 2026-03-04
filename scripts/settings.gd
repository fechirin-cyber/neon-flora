extends Control
## 設定画面 (§12) — 設定変更、音量、統計、リセット

const NEON_GREEN := Color(0.0, 1.0, 0.53, 1.0)
const BG_COLOR := Color(0.039, 0.039, 0.118, 1.0)
const PANEL_COLOR := Color(0.08, 0.08, 0.18, 1.0)
const LABEL_COLOR := Color(0.75, 0.75, 0.85, 1.0)
const VALUE_COLOR := Color(1.0, 1.0, 1.0, 1.0)
const ACTIVE_BTN_COLOR := Color(0.0, 0.8, 0.4, 1.0)
const INACTIVE_BTN_COLOR := Color(0.15, 0.15, 0.25, 1.0)
const DANGER_COLOR := Color(0.9, 0.15, 0.15, 1.0)

var _setting_buttons: Array[Button] = []
var _bgm_slider: HSlider
var _se_slider: HSlider
var _bgm_value_label: Label
var _se_value_label: Label
var _stat_labels: Dictionary = {}  # key -> Label
var _scroll: ScrollContainer
var _confirm_overlay: Control  # 確認ダイアログ用

func _ready() -> void:
	_build_ui()
	_update_setting_buttons()
	_update_stats()

func _build_ui() -> void:
	# 背景
	var bg := ColorRect.new()
	bg.anchors_preset = Control.PRESET_FULL_RECT
	bg.color = BG_COLOR
	add_child(bg)

	# スクロール可能にする（縦長コンテンツ対応）
	_scroll = ScrollContainer.new()
	_scroll.anchors_preset = Control.PRESET_FULL_RECT
	_scroll.anchor_top = 0.0
	_scroll.anchor_bottom = 1.0
	_scroll.size = Vector2(900.0, 1600.0)
	add_child(_scroll)

	var container := VBoxContainer.new()
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.custom_minimum_size = Vector2(900.0, 0.0)
	container.add_theme_constant_override("separation", 12)
	_scroll.add_child(container)

	# タイトル
	var title := Label.new()
	title.text = "SETTINGS"
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", NEON_GREEN)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.custom_minimum_size = Vector2(900.0, 80.0)
	container.add_child(title)

	# --- §12.1 設定変更 ---
	container.add_child(_make_section_label("SETTING"))
	var setting_row := HBoxContainer.new()
	setting_row.alignment = BoxContainer.ALIGNMENT_CENTER
	setting_row.add_theme_constant_override("separation", 12)
	container.add_child(setting_row)

	for i in range(1, 7):
		var btn := Button.new()
		btn.text = str(i)
		btn.custom_minimum_size = Vector2(110.0, 70.0)
		btn.add_theme_font_size_override("font_size", 28)
		var idx := i
		btn.pressed.connect(func() -> void: _on_setting_changed(idx))
		setting_row.add_child(btn)
		_setting_buttons.append(btn)

	# --- §12.1 BGM音量 ---
	container.add_child(_make_section_label("BGM VOLUME"))
	var bgm_row := _make_slider_row()
	_bgm_slider = bgm_row[0]
	_bgm_value_label = bgm_row[1]
	_bgm_slider.value = GameData.bgm_volume
	_bgm_value_label.text = "%d%%" % int(GameData.bgm_volume)
	_bgm_slider.value_changed.connect(_on_bgm_volume_changed)
	container.add_child(bgm_row[2])

	# --- §12.1 SE音量 ---
	container.add_child(_make_section_label("SE VOLUME"))
	var se_row := _make_slider_row()
	_se_slider = se_row[0]
	_se_value_label = se_row[1]
	_se_slider.value = GameData.se_volume
	_se_value_label.text = "%d%%" % int(GameData.se_volume)
	_se_slider.value_changed.connect(_on_se_volume_changed)
	container.add_child(se_row[2])

	# --- §12.2 統計表示 ---
	container.add_child(_make_section_label("STATISTICS"))
	var stat_panel := _make_panel()
	container.add_child(stat_panel)

	var stat_vbox := VBoxContainer.new()
	stat_vbox.add_theme_constant_override("separation", 6)
	stat_panel.add_child(stat_vbox)

	var stat_items: Array[Array] = [
		["total_games", "Total Games"],
		["big_count", "BIG"],
		["reg_count", "REG"],
		["bonus_prob", "Bonus Prob"],
		["big_prob", "BIG Prob"],
		["reg_prob", "REG Prob"],
		["diff_medals", "Diff Medals"],
		["payout_rate", "Payout Rate"],
	]
	for item in stat_items:
		var row := _make_stat_row(item[1])
		_stat_labels[item[0]] = row[1]
		stat_vbox.add_child(row[0])

	# --- §12.1 リセットボタン ---
	container.add_child(_make_spacer(20.0))

	var reset_row := HBoxContainer.new()
	reset_row.alignment = BoxContainer.ALIGNMENT_CENTER
	reset_row.add_theme_constant_override("separation", 20)
	container.add_child(reset_row)

	var credit_reset := _make_button("CREDIT RESET", DANGER_COLOR, 200.0)
	credit_reset.pressed.connect(func() -> void: _show_confirm(
		"Reset credit to 50?", _on_credit_reset))
	reset_row.add_child(credit_reset)

	var data_reset := _make_button("DATA RESET", DANGER_COLOR, 200.0)
	data_reset.pressed.connect(func() -> void: _show_confirm(
		"Reset all statistics?", _on_data_reset))
	reset_row.add_child(data_reset)

	# --- 戻るボタン ---
	container.add_child(_make_spacer(20.0))
	var back_row := HBoxContainer.new()
	back_row.alignment = BoxContainer.ALIGNMENT_CENTER
	container.add_child(back_row)

	var back_btn := _make_button("BACK", Color(0.2, 0.2, 0.35, 1.0), 300.0)
	back_btn.pressed.connect(_on_back)
	back_row.add_child(back_btn)

	container.add_child(_make_spacer(40.0))

# --- UIヘルパー ---

func _make_section_label(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 24)
	lbl.add_theme_color_override("font_color", NEON_GREEN)
	lbl.custom_minimum_size = Vector2(900.0, 40.0)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return lbl

func _make_slider_row() -> Array:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	row.custom_minimum_size = Vector2(900.0, 60.0)

	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 100.0
	slider.step = 1.0
	slider.custom_minimum_size = Vector2(550.0, 40.0)
	# スライダーのスタイル
	var grabber_style := StyleBoxFlat.new()
	grabber_style.bg_color = NEON_GREEN
	grabber_style.set_corner_radius_all(12)
	grabber_style.content_margin_left = 12
	grabber_style.content_margin_right = 12
	grabber_style.content_margin_top = 12
	grabber_style.content_margin_bottom = 12
	slider.add_theme_stylebox_override("grabber_area", grabber_style)
	slider.add_theme_stylebox_override("grabber_area_highlight", grabber_style)
	row.add_child(slider)

	var value_lbl := Label.new()
	value_lbl.add_theme_font_size_override("font_size", 24)
	value_lbl.add_theme_color_override("font_color", VALUE_COLOR)
	value_lbl.custom_minimum_size = Vector2(80.0, 40.0)
	value_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value_lbl)

	return [slider, value_lbl, row]

func _make_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_COLOR
	style.set_corner_radius_all(8)
	style.content_margin_left = 40
	style.content_margin_right = 40
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel", style)
	return panel

func _make_stat_row(label_text: String) -> Array:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0.0, 36.0)

	var lbl := Label.new()
	lbl.text = label_text
	lbl.add_theme_font_size_override("font_size", 22)
	lbl.add_theme_color_override("font_color", LABEL_COLOR)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(lbl)

	var val := Label.new()
	val.text = "---"
	val.add_theme_font_size_override("font_size", 22)
	val.add_theme_color_override("font_color", VALUE_COLOR)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val.custom_minimum_size = Vector2(200.0, 0.0)
	row.add_child(val)

	return [row, val]

func _make_button(text: String, color: Color, min_w: float) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(min_w, 70.0)
	btn.add_theme_font_size_override("font_size", 22)
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(8)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("hover", style)
	btn.add_theme_stylebox_override("pressed", style)
	return btn

func _make_spacer(h: float) -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0.0, h)
	return spacer

# --- ロジック ---

func _on_setting_changed(new_setting: int) -> void:
	GameData.setting = new_setting
	GameData.save()
	_update_setting_buttons()

func _update_setting_buttons() -> void:
	for i in range(6):
		var btn := _setting_buttons[i]
		var is_active := (i + 1) == GameData.setting
		var style := StyleBoxFlat.new()
		style.bg_color = ACTIVE_BTN_COLOR if is_active else INACTIVE_BTN_COLOR
		style.set_corner_radius_all(8)
		style.content_margin_left = 8
		style.content_margin_right = 8
		style.content_margin_top = 8
		style.content_margin_bottom = 8
		btn.add_theme_stylebox_override("normal", style)
		btn.add_theme_stylebox_override("hover", style)
		btn.add_theme_stylebox_override("pressed", style)
		btn.add_theme_color_override("font_color",
			Color.BLACK if is_active else Color.WHITE)

func _on_bgm_volume_changed(value: float) -> void:
	_bgm_value_label.text = "%d%%" % int(value)
	GameData.bgm_volume = value
	AudioManager.set_bgm_volume(value)
	GameData.save()

func _on_se_volume_changed(value: float) -> void:
	_se_value_label.text = "%d%%" % int(value)
	GameData.se_volume = value
	AudioManager.set_se_volume(value)
	GameData.save()
	# SE試聴用: スライダー離した時にSE再生
	AudioManager.play_se("bet_insert")

func _update_stats() -> void:
	var tg := GameData.total_games
	var bc := GameData.big_count
	var rc := GameData.reg_count
	var ti := GameData.total_in
	var to_ := GameData.total_out

	_stat_labels["total_games"].text = str(tg)
	_stat_labels["big_count"].text = str(bc)
	_stat_labels["reg_count"].text = str(rc)

	# §12.2 確率表示（ゼロ除算対策）
	var bonus_total := bc + rc
	_stat_labels["bonus_prob"].text = ("1/%.1f" % (float(tg) / float(bonus_total))) if bonus_total > 0 else "---"
	_stat_labels["big_prob"].text = ("1/%.1f" % (float(tg) / float(bc))) if bc > 0 else "---"
	_stat_labels["reg_prob"].text = ("1/%.1f" % (float(tg) / float(rc))) if rc > 0 else "---"
	_stat_labels["diff_medals"].text = str(to_ - ti)
	_stat_labels["payout_rate"].text = ("%.1f%%" % (float(to_) / float(ti) * 100.0)) if ti > 0 else "---"

# --- 確認ダイアログ ---

func _show_confirm(message: String, on_confirm: Callable) -> void:
	if _confirm_overlay:
		_confirm_overlay.queue_free()

	_confirm_overlay = Control.new()
	_confirm_overlay.anchors_preset = Control.PRESET_FULL_RECT
	_confirm_overlay.z_index = 100
	add_child(_confirm_overlay)

	# 半透明背景
	var dim := ColorRect.new()
	dim.anchors_preset = Control.PRESET_FULL_RECT
	dim.color = Color(0.0, 0.0, 0.0, 0.6)
	_confirm_overlay.add_child(dim)

	# ダイアログパネル
	var panel := PanelContainer.new()
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.1, 0.1, 0.2, 1.0)
	panel_style.set_corner_radius_all(12)
	panel_style.set_border_width_all(2)
	panel_style.border_color = NEON_GREEN
	panel_style.content_margin_left = 40
	panel_style.content_margin_right = 40
	panel_style.content_margin_top = 30
	panel_style.content_margin_bottom = 30
	panel.add_theme_stylebox_override("panel", panel_style)
	panel.position = Vector2(150.0, 600.0)
	panel.size = Vector2(600.0, 250.0)
	_confirm_overlay.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 30)
	panel.add_child(vbox)

	var msg_label := Label.new()
	msg_label.text = message
	msg_label.add_theme_font_size_override("font_size", 26)
	msg_label.add_theme_color_override("font_color", VALUE_COLOR)
	msg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(msg_label)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 40)
	vbox.add_child(btn_row)

	var yes_btn := _make_button("YES", DANGER_COLOR, 160.0)
	yes_btn.pressed.connect(func() -> void:
		on_confirm.call()
		_dismiss_confirm()
	)
	btn_row.add_child(yes_btn)

	var no_btn := _make_button("NO", Color(0.3, 0.3, 0.45, 1.0), 160.0)
	no_btn.pressed.connect(_dismiss_confirm)
	btn_row.add_child(no_btn)

func _dismiss_confirm() -> void:
	if _confirm_overlay:
		_confirm_overlay.queue_free()
		_confirm_overlay = null

func _on_credit_reset() -> void:
	GameData.credit = 50
	GameData.save()
	_update_stats()

func _on_data_reset() -> void:
	GameData.reset_stats()
	_update_stats()

func _on_back() -> void:
	get_tree().change_scene_to_file("res://scenes/TitleScreen.tscn")
