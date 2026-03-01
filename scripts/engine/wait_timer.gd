class_name WaitTimer
extends RefCounted
## 4.1秒ウェイト制御

const WAIT_DURATION := 4.1  # レバー間最小間隔（秒）

var _last_lever_time: float = -WAIT_DURATION  # 初回はウェイトなし

func get_remaining(current_time: float) -> float:
	var elapsed := current_time - _last_lever_time
	return maxf(WAIT_DURATION - elapsed, 0.0)

func is_waiting(current_time: float) -> bool:
	return get_remaining(current_time) > 0.0

func mark_lever_pulled(current_time: float) -> void:
	_last_lever_time = current_time

func reset() -> void:
	_last_lever_time = -WAIT_DURATION
