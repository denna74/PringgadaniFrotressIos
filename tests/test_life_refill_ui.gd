extends SceneTree

# The refill countdown lives only in the OUT OF LIVES overlay: it ticks down each
# second and flips to "Life refilled!" the moment a life comes back, rather than
# freezing on a stale value. The top bar shows no countdown.

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
	var sm = root.get_node("/root/SaveManager")
	var tm = root.get_node("/root/TranslationManager")
	var save_backup := _backup_save()
	var lives_backup: int = sm.lives
	var loss_backup: int = sm.last_life_loss_time
	var now: int = int(Time.get_unix_time_from_system())

	# One life missing: the top bar carries no refill countdown.
	sm.lives = sm.max_lives - 1
	sm.last_life_loss_time = now
	sm.lives_changed.emit(sm.lives)

	var track: Control = load("res://scenes/hub/LevelTrack.tscn").instantiate()
	root.add_child(track)
	await process_frame
	await process_frame

	var refill_lbl := _find_by_name(track, "RefillLabel") as Label
	_check("top bar has no refill countdown", refill_lbl == null)

	# An elapsed hour still refills lives with no top-bar label to update.
	sm.lives = sm.max_lives - 1
	sm.last_life_loss_time = now - 3600
	sm._on_refill_tick()
	await process_frame
	_check("an elapsed hour refills the hub", sm.lives == sm.max_lives)

	# The OUT OF LIVES overlay counts down live and flips when a life returns.
	sm.lives = 0
	sm.last_life_loss_time = now
	sm.lives_changed.emit(sm.lives)
	track._show_no_lives()
	await process_frame
	var sub := _find_by_name(track, "NoLivesRefill") as Label
	_check("out-of-lives overlay has a countdown", sub != null)
	if sub != null:
		_check("overlay counts down (%s)" % sub.text,
			sub.text == tm.t("no_lives_refill") % "60:00")
		sm.lives_refill_tick.emit(59)
		await process_frame
		_check("a tick updates the overlay (%s)" % sub.text,
			sub.text == tm.t("no_lives_refill") % "0:59")
		sm.lives = 1
		sm._on_refill_tick()
		await process_frame
		_check("the overlay flips once a life returns (%s)" % sub.text,
			sub.text == tm.t("no_lives_refilled"))

	track.queue_free()
	await process_frame

	# Restore the player's real state.
	sm.lives = lives_backup
	sm.last_life_loss_time = loss_backup
	sm.lives_changed.emit(sm.lives)
	_restore_save(save_backup)

	if failures > 0:
		push_error("Life refill UI regression (%d failures)" % failures)
		quit(1)
		return
	print("LIFE_REFILL_UI_PASS")
	quit(0)


func _find_by_name(node: Node, want: String) -> Node:
	if node.name == want:
		return node
	for child in node.get_children():
		var hit := _find_by_name(child, want)
		if hit != null:
			return hit
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