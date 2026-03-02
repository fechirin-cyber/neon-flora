extends Control
## タイトル画面 — ビジュアル強化版 (§8.1)

var _title_label: Label
var _glow_label: Label
var _play_btn: Button

func _ready() -> void:
	_setup_background()
	_setup_character_silhouette()
	_setup_title()
	_setup_buttons()
	_start_breathing_animation()
	# タイトルBGM再生 (§10.2)
	AudioManager.play_bgm("title", 0.0)

# === 背景 ===

func _setup_background() -> void:
	# 背景画像: title_bg → game_bg → concept_art → ソリッドカラー
	var bg_tex: Texture2D = AssetRegistry.load_background("title")
	if bg_tex == null:
		bg_tex = AssetRegistry.load_background("game")
	if bg_tex == null:
		bg_tex = AssetRegistry.load_texture(AssetRegistry.CONCEPT_ART)
	if bg_tex:
		var bg_rect := TextureRect.new()
		bg_rect.texture = bg_tex
		bg_rect.anchors_preset = Control.PRESET_FULL_RECT
		bg_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		add_child(bg_rect)
	else:
		var bg := ColorRect.new()
		bg.anchors_preset = Control.PRESET_FULL_RECT
		bg.color = AssetRegistry.PLACEHOLDER_COLORS["background"]
		add_child(bg)

	# グラデーションオーバーレイ: 上=やや暗い、下=かなり暗い（テキスト視認性確保）
	var grad_overlay := ColorRect.new()
	grad_overlay.anchors_preset = Control.PRESET_FULL_RECT
	# ShaderMaterialでグラデーションを実現
	var shader := Shader.new()
	shader.code = """shader_type canvas_item;
void fragment() {
	float t = UV.y;
	float alpha_top = 0.2;
	float alpha_bottom = 0.55;
	float a = mix(alpha_top, alpha_bottom, t * t);
	COLOR = vec4(0.0, 0.0, 0.0, a);
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	grad_overlay.material = mat
	grad_overlay.color = Color(1.0, 1.0, 1.0, 1.0)
	add_child(grad_overlay)

# === キャラクターシルエット ===

func _setup_character_silhouette() -> void:
	var char_tex: Texture2D = AssetRegistry.load_character_texture("hikari", "idle")
	if char_tex == null:
		return
	var char_rect := TextureRect.new()
	char_rect.texture = char_tex
	char_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	char_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	char_rect.size = Vector2(500.0, 500.0)
	char_rect.position = Vector2(200.0, 180.0)
	char_rect.modulate = Color(1.0, 1.0, 1.0, 0.15)
	add_child(char_rect)

# === タイトルテキスト ===

func _setup_title() -> void:
	# グローレイヤー（ぼかし模擬: 大きめフォント + 半透明で下に配置）
	_glow_label = Label.new()
	_glow_label.text = "NEON FLORA"
	_glow_label.add_theme_font_size_override("font_size", 60)
	_glow_label.add_theme_color_override("font_color", Color(0.0, 1.0, 0.53, 0.3))
	_glow_label.position = Vector2(-2.0, 398.0)
	_glow_label.size = Vector2(904.0, 104.0)
	_glow_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_glow_label)

	# メインタイトル（ネオングリーン）
	_title_label = Label.new()
	_title_label.text = "NEON FLORA"
	_title_label.add_theme_font_size_override("font_size", 56)
	_title_label.add_theme_color_override("font_color", Color(0.0, 1.0, 0.53, 1.0))
	_title_label.add_theme_color_override("font_outline_color", Color(0.0, 0.6, 0.3, 0.8))
	_title_label.add_theme_constant_override("outline_size", 3)
	_title_label.position = Vector2(0.0, 400.0)
	_title_label.size = Vector2(900.0, 100.0)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_title_label)

	# サブタイトル
	var subtitle := Label.new()
	subtitle.text = "4号機A-Type パチスロ"
	subtitle.add_theme_font_size_override("font_size", 24)
	subtitle.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7, 0.8))
	subtitle.position = Vector2(0.0, 500.0)
	subtitle.size = Vector2(900.0, 40.0)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(subtitle)

	# バージョン表示
	var version := Label.new()
	version.text = "v0.3.0 Alpha"
	version.add_theme_font_size_override("font_size", 18)
	version.add_theme_color_override("font_color", Color(0.4, 0.4, 0.5, 0.5))
	version.position = Vector2(0.0, 1550.0)
	version.size = Vector2(900.0, 30.0)
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(version)

# === ボタン ===

func _setup_buttons() -> void:
	# PLAYボタン — ベベルシェーダー付き
	_play_btn = Button.new()
	_play_btn.text = "PLAY"
	_play_btn.custom_minimum_size = Vector2(300.0, 80.0)
	_play_btn.position = Vector2(300.0, 700.0)
	_play_btn.add_theme_font_size_override("font_size", 28)
	_play_btn.add_theme_color_override("font_color", Color(0.0, 0.0, 0.0, 1.0))

	var play_style := StyleBoxFlat.new()
	play_style.bg_color = Color(0.0, 1.0, 0.53, 1.0)
	play_style.set_corner_radius_all(12)
	play_style.border_width_bottom = 4
	play_style.border_color = Color(0.0, 0.7, 0.35, 1.0)
	play_style.shadow_color = Color(0.0, 1.0, 0.53, 0.3)
	play_style.shadow_size = 8
	_play_btn.add_theme_stylebox_override("normal", play_style)

	var play_hover := play_style.duplicate()
	play_hover.bg_color = Color(0.0, 1.0, 0.53, 1.0).lightened(0.15)
	play_hover.shadow_size = 12
	_play_btn.add_theme_stylebox_override("hover", play_hover)

	var play_pressed := play_style.duplicate()
	play_pressed.bg_color = Color(0.0, 0.8, 0.42, 1.0)
	play_pressed.border_width_bottom = 1
	play_pressed.shadow_size = 2
	_play_btn.add_theme_stylebox_override("pressed", play_pressed)

	_play_btn.pressed.connect(_on_play)
	add_child(_play_btn)

	# SETTINGSボタン
	var settings_btn := Button.new()
	settings_btn.text = "SETTINGS"
	settings_btn.custom_minimum_size = Vector2(300.0, 60.0)
	settings_btn.position = Vector2(300.0, 820.0)
	settings_btn.add_theme_font_size_override("font_size", 20)
	settings_btn.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8, 1.0))

	var set_style := StyleBoxFlat.new()
	set_style.bg_color = Color(0.12, 0.12, 0.2, 0.8)
	set_style.set_corner_radius_all(8)
	set_style.border_width_left = 1
	set_style.border_width_top = 1
	set_style.border_width_right = 1
	set_style.border_width_bottom = 1
	set_style.border_color = Color(0.3, 0.3, 0.5, 0.5)
	settings_btn.add_theme_stylebox_override("normal", set_style)

	var set_hover := set_style.duplicate()
	set_hover.bg_color = Color(0.15, 0.15, 0.25, 0.9)
	set_hover.border_color = Color(0.0, 1.0, 0.53, 0.5)
	settings_btn.add_theme_stylebox_override("hover", set_hover)

	settings_btn.pressed.connect(_on_settings)
	add_child(settings_btn)

# === 呼吸アニメーション ===

func _start_breathing_animation() -> void:
	# タイトルテキストの明滅（呼吸）
	var tween := create_tween()
	tween.set_loops()
	tween.tween_property(_title_label, "modulate:a", 0.7, 2.0).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	tween.tween_property(_title_label, "modulate:a", 1.0, 2.0).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)

	# グローレイヤーも連動（逆位相）
	var glow_tween := create_tween()
	glow_tween.set_loops()
	glow_tween.tween_property(_glow_label, "modulate:a", 1.0, 2.0).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	glow_tween.tween_property(_glow_label, "modulate:a", 0.5, 2.0).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)

# === シグナルハンドラ ===

func _on_play() -> void:
	AudioManager.stop_bgm(0.3)
	get_tree().change_scene_to_file("res://scenes/Game.tscn")

func _on_settings() -> void:
	get_tree().change_scene_to_file("res://scenes/Settings.tscn")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE or event.keycode == KEY_ENTER:
			_on_play()
