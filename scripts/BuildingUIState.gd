class_name BuildingUIState
extends RefCounted


static var popup_open_count: int = 0


static func is_popup_open() -> bool:
	return popup_open_count > 0


static func note_popup_opened() -> void:
	var was := popup_open_count
	popup_open_count += 1
	if was == 0:
		_pause_acquire()


static func note_popup_closed() -> void:
	var was := popup_open_count
	popup_open_count = maxi(popup_open_count - 1, 0)
	if was > 0 and popup_open_count == 0:
		_pause_release()


static func _pause_node() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null("GamePause")


static func _pause_acquire() -> void:
	var gp := _pause_node()
	if gp != null:
		gp.acquire("ui_popup")


static func _pause_release() -> void:
	var gp := _pause_node()
	if gp != null:
		gp.release("ui_popup")