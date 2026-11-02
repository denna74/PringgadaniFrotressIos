extends SceneTree

# GamePause is the single owner of get_tree().paused. It counts acquirers per reason
# so two overlapping freezes (a popup and a finished run) cannot unpause each other.

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
	var gp = root.get_node_or_null("/root/GamePause")
	_check("GamePause autoload present", gp != null)
	if gp == null:
		_finish("GAME_PAUSE_FAIL")
		return

	gp.clear()
	_check("starts unpaused", not gp.is_paused())
	_check("tree starts unpaused", not paused)

	gp.acquire("ui_popup")
	_check("acquire pauses", gp.is_paused())
	_check("tree mirrors pause", paused)

	gp.acquire("finished")
	_check("two reasons still paused", gp.is_paused())
	gp.release("ui_popup")
	_check("overlapping release keeps paused", gp.is_paused())
	gp.release("finished")
	_check("last release unpauses", not gp.is_paused())
	_check("tree mirrors unpause", not paused)

	gp.acquire("ui_popup")
	gp.acquire("ui_popup")
	gp.release("ui_popup")
	_check("counted acquire survives one release", gp.is_paused())
	gp.release("ui_popup")
	_check("second release unpauses", not gp.is_paused())

	gp.release("finished")
	_check("stray release is safe", not gp.is_paused())

	gp.acquire("finished")
	gp.clear()
	_check("clear unpauses", not gp.is_paused())
	_check("clear unpauses tree", not paused)

	_finish("GAME_PAUSE_PASS")
