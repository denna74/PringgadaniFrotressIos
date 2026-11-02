extends SceneTree

# Every popup in the game funnels through BuildingUIState. Hooking the pause there
# means build, potions and the pause popup all freeze the tree with one edit, and
# the freeze is released exactly when the last popup closes -- never early.

var failures := 0


func _initialize() -> void:
	_run()


func _check(name: String, cond: bool) -> void:
	if cond:
		print("OK  ", name)
	else:
		push_error("FAIL " + name)
		failures += 1


func _finish(token: String) -> void:
	if failures > 0:
		push_error("%s regression (%d failures)" % [token, failures])
		quit(1)
		return
	print(token)
	quit(0)


func _run() -> void:
	await process_frame
	var gp = root.get_node("/root/GamePause")
	gp.clear()
	BuildingUIState.popup_open_count = 0

	BuildingUIState.note_popup_opened()
	_check("first popup pauses", gp.is_paused())
	BuildingUIState.note_popup_opened()
	BuildingUIState.note_popup_closed()
	_check("closing one of two stays paused", gp.is_paused())
	BuildingUIState.note_popup_closed()
	_check("closing the last unpauses", not gp.is_paused())
	_check("count returns to zero", BuildingUIState.popup_open_count == 0)

	_finish("UI_PAUSE_WIRING_PASS")
