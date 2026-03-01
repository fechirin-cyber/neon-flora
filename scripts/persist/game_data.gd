extends Node
## GameData — セーブ/ロード・統計・セッション管理 (Autoload)

const SAVE_PATH := "user://neonflora_save.json"
const BACKUP_PATH := "user://neonflora_save.json.bak"
const MAX_CREDIT := 9999
const MAX_COIN_HISTORY := 1000
const MAX_BONUS_HISTORY := 100

# 統計
var setting: int = 3
var credit: int = 50
var total_games: int = 0
var big_count: int = 0
var reg_count: int = 0
var total_in: int = 0
var total_out: int = 0
var coin_history: Array = []
var bonus_history: Array = []
var session_count: int = 0
var total_play_time_sec: int = 0
var achievements: Array = []

func _ready() -> void:
	load_data()
	session_count += 1

func save() -> void:
	var data := {
		"version": 1,
		"setting": setting,
		"credit": credit,
		"total_games": total_games,
		"big_count": big_count,
		"reg_count": reg_count,
		"total_in": total_in,
		"total_out": total_out,
		"coin_history": coin_history,
		"bonus_history": bonus_history,
		"session_count": session_count,
		"total_play_time_sec": total_play_time_sec,
		"achievements": achievements,
	}

	# 既存セーブのバックアップ
	if FileAccess.file_exists(SAVE_PATH):
		var existing := FileAccess.get_file_as_string(SAVE_PATH)
		var backup := FileAccess.open(BACKUP_PATH, FileAccess.WRITE)
		if backup:
			backup.store_string(existing)
			backup.close()

	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()

func load_data() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		if FileAccess.file_exists(BACKUP_PATH):
			_load_from_path(BACKUP_PATH)
		return
	_load_from_path(SAVE_PATH)

func _load_from_path(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		push_warning("GameData: Failed to open %s" % path)
		return
	var text := file.get_as_text()
	file.close()

	var json := JSON.new()
	if json.parse(text) != OK:
		push_warning("GameData: JSON parse error in %s" % path)
		return

	var data: Dictionary = json.data
	_apply_data(data)

func _apply_data(data: Dictionary) -> void:
	setting = clampi(data.get("setting", 3), 1, 6)
	credit = clampi(data.get("credit", 50), 0, MAX_CREDIT)
	total_games = maxi(data.get("total_games", 0), 0)
	big_count = maxi(data.get("big_count", 0), 0)
	reg_count = maxi(data.get("reg_count", 0), 0)
	total_in = maxi(data.get("total_in", 0), 0)
	total_out = maxi(data.get("total_out", 0), 0)
	session_count = maxi(data.get("session_count", 0), 0)
	total_play_time_sec = maxi(data.get("total_play_time_sec", 0), 0)

	coin_history = data.get("coin_history", [])
	if coin_history.size() > MAX_COIN_HISTORY:
		coin_history = coin_history.slice(-MAX_COIN_HISTORY)

	bonus_history = data.get("bonus_history", [])
	if bonus_history.size() > MAX_BONUS_HISTORY:
		bonus_history = bonus_history.slice(-MAX_BONUS_HISTORY)

	achievements = data.get("achievements", [])

func add_history_point() -> void:
	var diff := total_out - total_in
	coin_history.append(diff)
	if coin_history.size() > MAX_COIN_HISTORY:
		coin_history = coin_history.slice(-MAX_COIN_HISTORY)

func add_bonus_history(type: String, between: int) -> void:
	bonus_history.append({"type": type, "between": between, "game": total_games})
	if bonus_history.size() > MAX_BONUS_HISTORY:
		bonus_history = bonus_history.slice(-MAX_BONUS_HISTORY)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save()
