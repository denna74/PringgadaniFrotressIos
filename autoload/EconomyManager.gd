extends Node

signal pending_changed(pending: int)

var _run_active: bool = false
var _pending_earnings: int = 0


func begin_run() -> void:
	_run_active = true
	_pending_earnings = 0


func end_run() -> void:
	_run_active = false
	_pending_earnings = 0
	pending_changed.emit(_pending_earnings)


func get_gold() -> int:
	return SaveManager.gold


func can_afford(cost_gold: int) -> bool:
	return SaveManager.gold >= cost_gold


func spend(amount: int) -> bool:
	return SaveManager.spend_gold(amount)


func get_pending() -> int:
	return _pending_earnings


func add_pending(amount: int) -> void:
	_pending_earnings += amount
	pending_changed.emit(_pending_earnings)