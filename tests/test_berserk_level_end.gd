extends SceneTree

var _fails: int = 0
var _had_save: bool = false
var _save_backup: String = ""


func _initialize() -> void:
	_run()


func _fail(msg: String) -> void:
	_fails += 1
	print("CHECK FAIL: " + msg)


func _finish(code: int) -> void:
	var sm = root.get_node("/root/SaveManager")
	if _had_save:
		var f := FileAccess.open(sm.save_path, FileAccess.WRITE)
		f.store_string(_save_backup)
		f.close()
	else:
		DirAccess.remove_absolute(sm.save_path)
	if code == 0:
		print("VERIFY_PASS: berserk level end")
	else:
		print("VERIFY_FAIL: %d checks failed" % _fails)
	quit(code)


func _wait_aura_gone(king: Node) -> void:
	# Deactivation now fades the aura out over a fraction of a second, so give the
	# fade a generous window to finish before asserting the node is gone.
	for i in 120:
		await process_frame
		if king.get_node_or_null("BerserkAura") == null:
			return


func _run() -> void:
	await process_frame

	var sm = root.get_node("/root/SaveManager")
	_had_save = FileAccess.file_exists(sm.save_path)
	if _had_save:
		var cf := FileAccess.open(sm.save_path, FileAccess.READ)
		_save_backup = cf.get_as_text()
		cf.close()
	sm.gold = 500
	# The save is isolated per test now, so this test must stand on its own. Pinning the
	# king at max level keeps _level_complete() from awarding a level-up that would change
	# his attack mid-test -- the berserk-teardown checks below are not about levelling.
	sm.heroes["gatotkaca"] = {
		"level": ProgressionData.MAX_KING_LEVEL, "stars": 1, "xp": 0
	}

	var run_ctl: Node3D = load("res://scenes/run/RunController.tscn").instantiate()
	root.add_child(run_ctl)

	for i in 400:
		await process_frame
		if run_ctl.garrison != null and run_ctl._king_controller != null:
			break

	var king: Node3D = run_ctl._king_controller
	if king == null:
		_fail("level did not boot a king")
		_finish(1)
		return

	var base_attack: float = king.get("king_attack")

	king.request_berserk()
	await process_frame
	if not bool(king.get("berserk_active")):
		_fail("berserk did not activate on the live level king")
		_finish(1)
		return

	# The aura is delayed, so let it land before checking the level-end teardown.
	for i in 40:
		await physics_frame
		if king.get_node_or_null("BerserkAura") != null:
			break
	if king.get_node_or_null("BerserkAura") == null:
		_fail("no BerserkAura on the live level king")
		_finish(1)
		return

	run_ctl._level_complete()
	await _wait_aura_gone(king)
	if bool(king.get("berserk_active")):
		_fail("berserk still active after _level_complete()")
	if king.get_node_or_null("BerserkAura") != null:
		_fail("BerserkAura survived _level_complete()")
	if not is_equal_approx(float(king.get("king_attack")), base_attack):
		_fail("attack = %s after _level_complete(), want %f" % [king.get("king_attack"), base_attack])

	king.set_berserk(true)
	await process_frame
	if not bool(king.get("berserk_active")):
		_fail("could not re-arm berserk for the defeat check")

	run_ctl._level_failed()
	await _wait_aura_gone(king)
	if bool(king.get("berserk_active")):
		_fail("berserk still active after _level_failed()")
	if king.get_node_or_null("BerserkAura") != null:
		_fail("BerserkAura survived _level_failed()")
	if not is_equal_approx(float(king.get("king_attack")), base_attack):
		_fail("attack = %s after _level_failed(), want %f" % [king.get("king_attack"), base_attack])

	var sfx: Node = root.get_node("/root/SFXManager")
	if sfx.has_method("is_berserk_loop_playing") and sfx.is_berserk_loop_playing():
		_fail("berserk audio still looping after the level ended")

	_finish(0 if _fails == 0 else 1)
