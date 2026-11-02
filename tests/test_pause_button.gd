extends SceneTree

# The pause button must be tappable while playable, must refuse taps while any
# modal is open (including its own popup), and must be dark during loading and
# after the run ends. RunHUD is a mobile HUD, so the button lives on the top bar
# and reports through a signal rather than reaching into the controller.

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
	BuildingUIState.popup_open_count = 0
	var gp = root.get_node("/root/GamePause")
	gp.clear()

	var hud = load("res://scenes/run/RunHUD.tscn").instantiate()
	root.add_child(hud)
	await process_frame
	await process_frame

	var btn = hud.get_node_or_null("PauseButton")
	_check("pause button present", btn != null and btn is Button)
	if btn == null:
		hud.queue_free()
		await process_frame
		_finish("PAUSE_BUTTON_FAIL")
		return

	_check("pause button starts disabled", btn.disabled)

	var fired := [0]
	hud.pause_requested.connect(func() -> void: fired[0] += 1)
	btn.pressed.emit()
	_check("pause button emits pause_requested", fired[0] == 1)

	hud.set_pause_enabled(true)
	await process_frame
	_check("enabled when playable", not btn.disabled)

	BuildingUIState.note_popup_opened()
	await process_frame
	_check("blocked while a popup is open", btn.disabled)

	BuildingUIState.note_popup_closed()
	await process_frame
	_check("re-enabled after the popup closes", not btn.disabled)

	hud.queue_free()
	await process_frame
	_finish("PAUSE_BUTTON_PASS")
