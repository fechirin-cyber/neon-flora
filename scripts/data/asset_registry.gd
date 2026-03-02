class_name AssetRegistry
extends RefCounted
## 全アセットパスの中央レジストリ (差し替え構造)
## 外注アセット(アプローチB)適用時はこのファイルのパスのみ変更する

# === 図柄テクスチャ: sym_id → path ===
const SYMBOL_TEXTURES := {
	ReelData.S7R: "res://assets/images/symbols/symbol_s7r.png",
	ReelData.S7B: "res://assets/images/symbols/symbol_s7b.png",
	ReelData.BAR: "res://assets/images/symbols/symbol_bar.png",
	ReelData.CHR: "res://assets/images/symbols/symbol_chr.png",
	ReelData.BEL: "res://assets/images/symbols/symbol_bel.png",
	ReelData.ICE: "res://assets/images/symbols/symbol_ice.png",
	ReelData.RPL: "res://assets/images/symbols/symbol_rpl.png",
}

# === キャラクター: char_name → { reaction → path } ===
const CHARACTER_TEXTURES := {
	"hikari": {
		"idle":     "res://assets/images/characters/hikari_idle.png",
		"expect":   "res://assets/images/characters/hikari_expect.png",
		"happy":    "res://assets/images/characters/hikari_happy.png",
		"sad":      "res://assets/images/characters/hikari_sad.png",
		"excited":  "res://assets/images/characters/hikari_excited.png",
		"reach_me": "res://assets/images/characters/hikari_reach_me.png",
	},
	"luna": {
		"excited": "res://assets/images/characters/luna_excited.png",
		"bonus":   "res://assets/images/characters/luna_bonus.png",
	},
	"koharu": {
		"happy": "res://assets/images/characters/koharu_happy.png",
		"bonus": "res://assets/images/characters/koharu_bonus.png",
	},
}

# === 背景: name → path ===
const BACKGROUNDS := {
	"title":  "res://assets/images/title_bg.png",
	"game":   "res://assets/images/game_bg.png",
	"bonus":  "res://assets/images/bonus_bg.png",
	"rt":     "res://assets/images/rt_bg.png",
}

# === コンセプトアート ===
const CONCEPT_ART := "res://assets/images/concept_art.png"

# === プレースホルダー色 ===
const PLACEHOLDER_COLORS := {
	"symbol":     Color(0.3, 0.3, 0.4, 1.0),
	"character":  Color(0.2, 0.15, 0.3, 1.0),
	"background": Color(0.039, 0.039, 0.118, 1.0),
}

# === テクスチャロード（存在チェック付き）===

static func load_texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path)
	push_warning("AssetRegistry: texture not found: %s" % path)
	return null

static func load_symbol_texture(symbol_id: int) -> Texture2D:
	if not SYMBOL_TEXTURES.has(symbol_id):
		return null
	return load_texture(SYMBOL_TEXTURES[symbol_id])

static func load_character_texture(char_name: String, reaction: String) -> Texture2D:
	if not CHARACTER_TEXTURES.has(char_name):
		return null
	var char_dict: Dictionary = CHARACTER_TEXTURES[char_name]
	if not char_dict.has(reaction):
		return null
	return load_texture(char_dict[reaction])

static func load_background(bg_name: String) -> Texture2D:
	if not BACKGROUNDS.has(bg_name):
		return null
	return load_texture(BACKGROUNDS[bg_name])

# === キャラクター情報取得 ===

static func get_character_reactions(char_name: String) -> Array[String]:
	if not CHARACTER_TEXTURES.has(char_name):
		return []
	var result: Array[String] = []
	for key in CHARACTER_TEXTURES[char_name]:
		result.append(key)
	return result

static func get_all_characters() -> Array[String]:
	var result: Array[String] = []
	for key in CHARACTER_TEXTURES:
		result.append(key)
	return result

# === プレースホルダー生成（アセット欠損時のクラッシュ防止）===

static func create_placeholder(target_size: Vector2, color: Color) -> ImageTexture:
	var img := Image.create(int(target_size.x), int(target_size.y), false, Image.FORMAT_RGBA8)
	img.fill(color)
	var border_color := color.lightened(0.3)
	for x in range(int(target_size.x)):
		img.set_pixel(x, 0, border_color)
		img.set_pixel(x, int(target_size.y) - 1, border_color)
	for y in range(int(target_size.y)):
		img.set_pixel(0, y, border_color)
		img.set_pixel(int(target_size.x) - 1, y, border_color)
	return ImageTexture.create_from_image(img)
