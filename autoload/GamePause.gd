extends Node

# Owns get_tree().paused. Each distinct freeze reason is counted independently so
# two overlapping freezes -- say an open build popup and a finished run -- release
# without unpausing each other. SceneManager.clear() wipes every reason on a switch.

const UI_POPUP := "ui_popup"
const FINISHED := "finished"

var _reasons: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func acquire(reason: String) -> void:
	_reasons[reason] = int(_reasons.get(reason, 0)) + 1
	_apply()


func release(reason: String) -> void:
	if not _reasons.has(reason):
		return
	var left: int = int(_reasons[reason]) - 1
	if left <= 0:
		_reasons.erase(reason)
	else:
		_reasons[reason] = left
	_apply()


func clear() -> void:
	_reasons.clear()
	_apply()


func is_paused() -> bool:
	return not _reasons.is_empty()


func _apply() -> void:
	var tree := get_tree()
	if tree == null:
		return
	tree.paused = not _reasons.is_empty()
