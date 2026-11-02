extends SceneTree

# The pause popup is the only way back into a paused mobile run, so its labels must
# localize and its signals must reach the controller. It covers the whole viewport
# with an input-eating backdrop, otherwise the frozen HUD buttons underneath stay
# tappable and the game can be driven while "paused".

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
	var tm = root.get_node("/root/TranslationManager")
	var popup = load("res://scenes/run/PausePopup.gd").new()
	root.add_child(popup)
	await process_frame

	_check(
		"popup covers the viewport",
		is_equal_approx(popup.anchor_right, 1.0) and is_equal_approx(popup.anchor_bottom, 1.0)
	)
	_check("popup eats input", popup.mouse_filter == Control.MOUSE_FILTER_STOP)

	var cont = popup.find_child("ContinueButton", true, false)
	var exit_btn = popup.find_child("ExitButton", true, false)
	_check(
		"continue localized",
		cont != null and cont is Button and cont.text == tm.t("continue")
	)
	_check(
		"exit localized",
		exit_btn != null and exit_btn is Button and exit_btn.text == tm.t("exit")
	)

	var got := [0, 0]
	if cont != null:
		popup.continue_requested.connect(func() -> void: got[0] += 1)
		cont.pressed.emit()
	if exit_btn != null:
		popup.exit_requested.connect(func() -> void: got[1] += 1)
		exit_btn.pressed.emit()
	_check("continue emits", got[0] == 1)
	_check("exit emits", got[1] == 1)

	popup.queue_free()
	await process_frame
	_finish("PAUSE_POPUP_PASS")