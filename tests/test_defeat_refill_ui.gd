extends SceneTree

# The defeat popup reports the lives left, but the player is stuck on a frozen run
# screen until they tap OK. The countdown to the next life has to keep ticking under
# that freeze, and flip to "Life restored!" the moment a life comes back, so the screen
# does not lie about how long is left.

var failures := 0


func _initialize() -> void:
	_run()


func _check(name: String, cond: bool) -> void:
	if cond:
		print("OK  ", name)
	else:
		push_error("FAIL " + name)
		failures += 1


func _run() -> void:
	await process_frame
	var gp = root.get_node("/root/GamePause")
	gp.clear()
	var sm = root.get_node("/root/SaveManager")
	var save_backup := _backup_save()
	var lives_backup: int = sm.lives
	var loss_backup: int = sm.last_life_loss_time
	var now: int = int(Time.get_unix_time_from_system())

	sm.lives = sm.max_lives - 1
	sm.last_life_loss_time = now

	var hud := CanvasLayer.new()
	hud.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(hud)

	var rc = load("res://scenes/run/RunController.gd").new()
	rc.hud_ui = hud

	# A finished run freezes the tree; the countdown must still advance.
	gp.acquire("finished")
	rc._show_defeat_notification()

	var overlay = hud.get_node_or_null("DefeatOverlay")
	_check("defeat overlay exists", overlay != null)

	var countdown: Label = null
	var result_buttons: Array[String] = []
	if overlay != null:
		countdown = _find_label_containing(overlay, "Next life in")
		for child in overlay.get_children():
			if child is Button:
				result_buttons.append((child as Button).text)
	_check("defeat shows a next-life countdown", countdown != null)
	_check(
		"defeat with lives offers retry and quit",
		result_buttons == [
			root.get_node("/root/TranslationManager").t("result_retry"),
			root.get_node("/root/TranslationManager").t("result_quit"),
		]
	)

	if countdown != null:
		sm.lives_refill_tick.emit(75)
		await process_frame
		_check("a tick advances the defeat countdown (%s)" % countdown.text, countdown.text == "Next life in 1:15")
		sm.lives = sm.max_lives
		sm.lives_refill_tick.emit(0)
		await process_frame
		_check("the countdown flips once a life returns (%s)" % countdown.text, countdown.text == "Life restored!")

	overlay.queue_free()
	await process_frame
	sm.lives = 0
	rc._show_defeat_notification()
	overlay = hud.get_node_or_null("DefeatOverlay")
	var retry_button := _find_button(
		overlay, root.get_node("/root/TranslationManager").t("result_retry")
	)
	_check("defeat hides retry when no lives remain", retry_button == null)

	gp.clear()
	rc.free()
	hud.queue_free()
	await process_frame

	sm.lives = lives_backup
	sm.last_life_loss_time = loss_backup
	sm.lives_changed.emit(sm.lives)
	_restore_save(save_backup)

	if failures > 0:
		push_error("Defeat refill UI regression (%d failures)" % failures)
		quit(1)
		return
	print("DEFEAT_REFILL_UI_PASS")
	quit(0)


func _find_label_containing(node: Node, needle: String) -> Label:
	if node is Label and (node as Label).text.contains(needle):
		return node
	for child in node.get_children():
		var hit := _find_label_containing(child, needle)
		if hit != null:
			return hit
	return null


func _find_button(node: Node, text: String) -> Button:
	for child in node.get_children():
		if child is Button and (child as Button).text == text:
			return child
		var nested := _find_button(child, text)
		if nested != null:
			return nested
	return null


func _backup_save() -> Dictionary:
	var sm = root.get_node("/root/SaveManager")
	if not FileAccess.file_exists(sm.save_path):
		return {"exists": false}
	var f := FileAccess.open(sm.save_path, FileAccess.READ)
	var text: String = f.get_as_text()
	f.close()
	return {"exists": true, "data": text}


func _restore_save(backup: Dictionary) -> void:
	var sm = root.get_node("/root/SaveManager")
	if backup.get("exists", false):
		var f := FileAccess.open(sm.save_path, FileAccess.WRITE)
		f.store_string(backup["data"])
		f.close()
	else:
		DirAccess.remove_absolute(sm.save_path)
	sm.load_game()