extends "res://autoload/AdsManager.gd"

# Test double for AdsManager: forces internet on/off on demand, shortens
# timeouts, and counts SDK initialize() calls so the init guard is observable.

var init_calls: int = 0
var force_no_internet: bool = false


func _has_internet() -> bool:
	return not force_no_internet


func _ad_load_timeout() -> float:
	return 0.4


func _ad_complete_timeout() -> float:
	return 0.4


func _call_unity_initialize() -> void:
	init_calls += 1
