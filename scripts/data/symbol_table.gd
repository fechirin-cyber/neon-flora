class_name SymbolTable
extends RefCounted
## 図柄定義（ID、名前、テクスチャパス、フォールバック色）

const SYMBOLS := {
	ReelData.S7R: {
		"name": "赤7",
		"texture": "res://assets/images/symbols/symbol_s7r.png",
		"color": Color(1.0, 0.08, 0.58),  # #FF1493 ネオンピンク
	},
	ReelData.S7B: {
		"name": "青7",
		"texture": "res://assets/images/symbols/symbol_s7b.png",
		"color": Color(0.0, 0.83, 1.0),  # #00D4FF シアンブルー
	},
	ReelData.BAR: {
		"name": "BAR",
		"texture": "res://assets/images/symbols/symbol_bar.png",
		"color": Color(1.0, 0.7, 0.28),  # #FFB347 アンバーオレンジ
	},
	ReelData.CHR: {
		"name": "チェリー",
		"texture": "res://assets/images/symbols/symbol_chr.png",
		"color": Color(0.69, 0.31, 1.0),  # #B14EFF パープル
	},
	ReelData.BEL: {
		"name": "ベル",
		"texture": "res://assets/images/symbols/symbol_bel.png",
		"color": Color(1.0, 0.843, 0.0),  # #FFD700 ゴールド
	},
	ReelData.ICE: {
		"name": "氷",
		"texture": "res://assets/images/symbols/symbol_ice.png",
		"color": Color(0.0, 1.0, 0.53),  # #00FF88 ネオングリーン
	},
	ReelData.RPL: {
		"name": "リプレイ",
		"texture": "res://assets/images/symbols/symbol_rpl.png",
		"color": Color(0.92, 0.92, 1.0),  # #EAEAFF ゴーストホワイト
	},
}

static func get_symbol_name(symbol_id: int) -> String:
	return SYMBOLS[symbol_id]["name"]

static func get_texture_path(symbol_id: int) -> String:
	return SYMBOLS[symbol_id]["texture"]

static func get_color(symbol_id: int) -> Color:
	return SYMBOLS[symbol_id]["color"]
