class_name SevenSegDisplay
extends Control
## 7セグ表示 — DSEG7フォント + 非点灯セグメント再現 (§8.5)

const LED_COLOR := Color(0.0, 1.0, 0.53, 1.0)  # #00FF88
const UNLIT_COLOR := Color(0.102, 0.102, 0.18, 0.3)  # #1A1A2E, alpha 0.3

var _bg_label: Label
var _fg_label: Label
var _digit_count: int = 4

func setup(seg_size: Vector2, digits: int, title: String = "") -> void:
	_digit_count = digits
	size = seg_size
	var font = load("res://assets/fonts/DSEG7Classic-Regular.ttf")

	# タイトルラベル
	if title != "":
		var tl := Label.new()
		tl.text = title
		tl.add_theme_font_size_override("font_size", 11)
		tl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
		tl.position = Vector2(0, 2)
		tl.size = Vector2(seg_size.x, 14)
		tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(tl)

	var y := 18.0 if title != "" else 8.0
	var fs := int((seg_size.y - y - 8.0) * 0.65)

	# 背面: 非点灯セグメント ("888...")
	_bg_label = Label.new()
	_bg_label.text = "8".repeat(digits)
	if font:
		_bg_label.add_theme_font_override("font", font)
	_bg_label.add_theme_font_size_override("font_size", fs)
	_bg_label.add_theme_color_override("font_color", UNLIT_COLOR)
	_bg_label.position = Vector2(0, y)
	_bg_label.size = Vector2(seg_size.x, seg_size.y - y)
	_bg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_bg_label)

	# 前面: 実際の値
	_fg_label = Label.new()
	_fg_label.text = "0".repeat(digits)
	if font:
		_fg_label.add_theme_font_override("font", font)
	_fg_label.add_theme_font_size_override("font_size", fs)
	_fg_label.add_theme_color_override("font_color", LED_COLOR)
	_fg_label.position = Vector2(0, y)
	_fg_label.size = Vector2(seg_size.x, seg_size.y - y)
	_fg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_fg_label)

func set_value(value: int) -> void:
	var text := str(value)
	while text.length() < _digit_count:
		text = " " + text
	_fg_label.text = text
