extends SceneTree

# A lost life refills on a real-time clock, one life per hour, and the clock keeps
# running while the app is open. These checks pin the rate, that a refill is granted
# exactly once per elapsed hour (no double-granting), and that the autoload exposes a
# ticking signal so the hub and the defeat screen can count down live.

var failures := 0

const ONE_HOUR := 3600


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
	var save_backup := _backup_save()
	var lives_backup: int = sm.lives
	var loss_backup: int = sm.last_life_loss_time

	var consts: Dictionary = sm.get_script().get_script_constant_map()
	_check("refill rate is one hour", int(consts.get("LIFE_REFILL_SECONDS", 0)) == ONE_HOUR)

	var has_apply: bool = sm.has_method("apply_elapsed_refills")
	var has_tick: bool = sm.has_method("_on_refill_tick")
	var has_sync: bool = sm.has_method("_sync_refill_timer")
	_check("SaveManager exposes apply_elapsed_refills", has_apply)
	_check("SaveManager exposes _on_refill_tick", has_tick)
	_check("SaveManager exposes _sync_refill_timer", has_sync)
	_check("SaveManager exposes the lives_refill_tick signal", sm.has_signal("lives_refill_tick"))
	if not (has_apply and has_tick and has_sync and sm.has_signal("lives_refill_tick")):
		_restore(sm, save_backup, lives_backup, loss_backup)
		_finish()
		return

	var now: int = int(Time.get_unix_time_from_system())

	# Full lives: nothing to count down.
	sm.lives = sm.max_lives
	sm.last_life_loss_time = now
	sm.lives_changed.emit(sm.lives)
	_check("full lives have no countdown", sm.get_lives_refill_seconds() == 0)

	# A lost life starts a countdown just under an hour.
	sm.lives = sm.max_lives - 1
	sm.last_life_loss_time = now
	sm.lives_changed.emit(sm.lives)
	var fresh: int = sm.get_lives_refill_seconds()
	_check("a lost life starts a countdown (%d)" % fresh, fresh > ONE_HOUR - 10 and fresh <= ONE_HOUR)

	# An hour elapsed grants exactly one life and advances the clock, so an immediate
	# second check grants nothing more.
	sm.lives = sm.max_lives - 2
	sm.last_life_loss_time = now - ONE_HOUR
	sm.apply_elapsed_refills()
	_check("an elapsed hour grants one life", sm.lives == sm.max_lives - 1)
	sm.apply_elapsed_refills()
	_check("an extra check does not double-grant", sm.lives == sm.max_lives - 1)

	# Two hours away grants two lives and lands the clock back on "now".
	sm.lives = sm.max_lives - 3
	sm.last_life_loss_time = now - 2 * ONE_HOUR
	sm.apply_elapsed_refills()
	_check("two elapsed hours grant two lives", sm.lives == sm.max_lives - 1)
	_check("the clock advances past the granted lives", absi(sm.last_life_loss_time - now) <= 2)

	# The signal reports the seconds remaining while a life is still missing.
	sm.lives = sm.max_lives - 1
	sm.last_life_loss_time = now - 10
	var seen: Array = []
	sm.lives_refill_tick.connect(func(secs: int) -> void: seen.append(secs))
	sm._on_refill_tick()
	_check("the tick signal fires", seen.size() == 1)
	if seen.size() == 1:
		var secs: int = seen[0]
		_check("the tick reports under an hour left (%d)" % secs, secs > 0 and secs <= ONE_HOUR)

	# The refill clock runs only while a life is missing.
	sm.lives = sm.max_lives - 1
	sm._sync_refill_timer()
	var timer = sm.get("_refill_timer")
	_check("the refill clock runs while a life is missing", timer != null and not timer.is_stopped())
	sm.lives = sm.max_lives
	sm._sync_refill_timer()
	_check("the refill clock stops when full", timer != null and timer.is_stopped())

	_restore(sm, save_backup, lives_backup, loss_backup)
	_finish()


func _restore(sm, save_backup: Dictionary, lives_backup: int, loss_backup: int) -> void:
	sm.lives = lives_backup
	sm.last_life_loss_time = loss_backup
	sm.lives_changed.emit(sm.lives)
	if sm.has_method("_sync_refill_timer"):
		sm._sync_refill_timer()
	_restore_save(save_backup)


func _finish() -> void:
	if failures > 0:
		push_error("Life refill timer regression (%d failures)" % failures)
		quit(1)
		return
	print("LIFE_REFILL_TIMER_PASS")
	quit(0)


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