class_name SymbolTable
extends RefCounted
## 図柄定義（ID、名前、フォールバック色）
## テクスチャパスは AssetRegistry に一元管理

const SYMBOLS := {
	ReelData.S7R: {
		"name": "赤7",
		"color": Color(1.0, 0.08, 0.58),  # #FF1493 ネオンピンク
	},
	ReelData.S7B: {
		"name": "青7",
		"color": Color(0.0, 0.83, 1.0),  # #00D4FF シアンブルー
	},
	ReelData.BAR: {
		"name": "BAR",
		"color": Color(1.0, 0.7, 0.28),  # #FFB347 アンバーオレンジ
	},
	ReelData.CHR: {
		"name": "チェリー",
		"color": Color(0.69, 0.31, 1.0),  # #B14EFF パープル
	},
	ReelData.BEL: {
		"name": "ベル",
		"color": Color(1.0, 0.843, 0.0),  # #FFD700 ゴールド
	},
	ReelData.ICE: {
		"name": "氷",
		"color": Color(0.0, 1.0, 0.53),  # #00FF88 ネオングリーン
	},
	ReelData.RPL: {
		"name": "リプレイ",
		"color": Color(0.92, 0.92, 1.0),  # #EAEAFF ゴーストホワイト
	},
}

static func get_symbol_name(symbol_id: int) -> String:
	return SYMBOLS[symbol_id]["name"]

static func get_color(symbol_id: int) -> Color:
	return SYMBOLS[symbol_id]["color"]
