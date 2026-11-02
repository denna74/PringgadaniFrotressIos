extends SceneTree

# Defeat, pause-exit and app-close all cost exactly one life and throw away the
# gold mined that run; victory does not. The shared _apply_run_loss() helper is
# what every loss path calls, and it is idempotent for the already-dead cases.

var failures := 0


class FakeKing:
	extends Node3D
	var frozen := false


class FakeInvasion:
	extends Node3D
	func stop_wave_timer() -> void:
		pass


class FakeHud:
	extends CanvasLayer
	func set_pause_enabled(_value: bool) -> void:
		pass


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
	var sm = root.get_node("/root/SaveManager")
	var em = root.get_node("/root/EconomyManager")
	var gp = root.get_node("/root/GamePause")
	gp.clear()
	BuildingUIState.popup_open_count = 0

	var save_backup := _backup_save()
	var lives_backup: int = sm.lives
	var gold_backup: int = sm.gold

	# A fake HUD keeps the pause popup parented without booting the real run scene.
	var hud := FakeHud.new()
	hud.name = "FakeRunHUD"
	root.add_child(hud)

	var rc = load("res://scenes/run/RunController.gd").new()
	rc.hud_ui = hud

	# --- pause popup round-trip ---
	rc._playing = true
	rc.set_paused(true)
	_check("pause shows the popup", rc.get("_pause_popup") != null)
	_check("pausing freezes the tree", gp.is_paused())
	rc._on_pause_continue()
	_check("continue closes the popup", rc.get("_pause_popup") == null)
	_check("continue unfreezes the tree", not gp.is_paused())

	# --- pause cannot stack on a build popup ---
	BuildingUIState.note_popup_opened()
	rc._on_pause_pressed()
	_check("pause ignored while a build popup is open", not rc._paused)
	BuildingUIState.note_popup_closed()

	# --- loss costs one life and discards mined gold ---
	sm.lives = 3
	sm.max_lives = 3
	sm.gold = 1000
	em.begin_run()
	em.add_pending(77)
	rc._playing = true
	rc._apply_run_loss()
	_check("loss costs one life", sm.lives == 2)
	_check("mined gold is discarded", em.get_pending() == 0)
	_check("mined gold is not paid out", sm.gold == 1000)
	_check("loss marks the run unplayable", not rc._playing)

	# --- app-close while paused costs exactly one life ---
	sm.lives = 3
	sm.gold = 1000
	em.begin_run()
	em.add_pending(55)
	rc._playing = true
	rc.set_paused(true)
	rc._on_close_requested()
	_check("close while paused costs one life", sm.lives == 2)
	_check("close while paused discards gold", em.get_pending() == 0)
	_check("close while paused unpauses", not gp.is_paused())

	# --- dead runs ignore further loss events ---
	sm.lives = 3
	rc._playing = false
	rc._on_close_requested()
	rc._on_pause_exit()
	_check("dead run ignores close and pause-exit", sm.lives == 3)

	# --- defeat path costs exactly one life and is idempotent ---
	sm.lives = 3
	sm.max_lives = 3
	sm.gold = 1000
	em.begin_run()
	em.add_pending(88)
	rc._playing = true
	rc._king_controller = FakeKing.new()
	rc.invasion_manager = FakeInvasion.new()
	rc._level_failed()
	_check("defeat costs one life", sm.lives == 2)
	_check("defeat discards mined gold", em.get_pending() == 0)
	_check("defeat is not paid out", sm.gold == 1000)
	_check("defeat marks the run unplayable", not rc._playing)
	_check("defeat freezes the tree for the fight UI", gp.is_paused())
	rc._king_controller = FakeKing.new()
	rc.invasion_manager = FakeInvasion.new()
	rc._level_failed()
	_check("a repeated defeat costs no second life", sm.lives == 2)
	_check("a repeated defeat pays nothing again", sm.gold == 1000)

	gp.clear()
	sm.lives = lives_backup
	sm.lives_changed.emit(sm.lives)
	sm.gold = gold_backup
	_restore_save(save_backup)

	rc.free()
	hud.queue_free()
	await process_frame
	_finish("RUN_PAUSE_LIFE_LOSS_PASS")


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