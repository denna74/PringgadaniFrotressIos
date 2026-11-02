extends SceneTree

# Victory plays on a frozen tree (GamePause acquires "finished" before the popup is
# built), so the XP-bar and level-up tweens must run on the always-processing overlay,
# not on the paused RunController. Otherwise the bar sits at its start value while the
# label reports the total -- a visibly broken reward screen.

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

	# RunHUD is always-processing in the real run; mirror that so the overlay tween
	# can step while the tree is frozen.
	var hud := CanvasLayer.new()
	hud.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(hud)

	var rc = load("res://scenes/run/RunController.gd").new()
	rc.hud_ui = hud

	# A finished run freezes the tree; the victory animation must still play through.
	gp.acquire("finished")
	rc._show_victory_notification(10, 20, 50, 0, 1, 100, 100, 2)

	var overlay = hud.get_node_or_null("VictoryOverlay")
	_check("victory overlay exists", overlay != null)

	var bar: ProgressBar = null
	var result_buttons: Array[String] = []
	if overlay != null:
		for child in overlay.get_children():
			if child is ProgressBar:
				bar = child
			elif child is Button:
				result_buttons.append((child as Button).text)
	_check("xp bar present", bar != null)
	_check(
		"victory offers retry, quit, and next stage",
		result_buttons == [
			root.get_node("/root/TranslationManager").t("result_retry"),
			root.get_node("/root/TranslationManager").t("result_quit"),
			root.get_node("/root/TranslationManager").t("result_next_stage"),
		]
	)

	if bar != null:
		var reached := false
		var started_ms := Time.get_ticks_msec()
		while Time.get_ticks_msec() - started_ms < 3000:
			await process_frame
			if absf(bar.value - 100.0) < 0.5:
				reached = true
				break
		_check("xp bar animates to total while frozen", reached)

	if overlay != null:
		overlay.queue_free()
		await process_frame
	var tm = root.get_node("/root/TranslationManager")
	rc._show_victory_notification(10, 20, 0, 0, 99, 0, 0, 2)
	var capped_label: Label = hud.find_child("VictoryXpLabel", true, false) as Label
	var capped_bar: ProgressBar = hud.find_child("VictoryXpBar", true, false) as ProgressBar
	_check(
		"max-level victory XP readout shows maximum",
		capped_label != null and capped_label.text.contains(tm.t("xp_maximum"))
	)
	_check(
		"max-level victory XP bar is full",
		capped_bar != null and capped_bar.value == capped_bar.max_value
	)

	gp.clear()
	rc.free()
	hud.queue_free()
	await process_frame
	_finish("VICTORY_TWEEN_PASS")