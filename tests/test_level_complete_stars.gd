extends SceneTree

# What clearing a stage actually files away.
#
# Boots a real run, forces the outcome, and checks the star rating that lands in the
# save -- plus that a defeat files nothing at all, and that the victory panel shows the
# rating that was just earned.

var _fails: int = 0
var _had_save: bool = false
var _save_backup: String = ""


func _initialize() -> void:
	_run()


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("OK  ", msg)
	else:
		_fail(msg)


func _fail(msg: String) -> void:
	_fails += 1
	print("CHECK FAIL: " + msg)


func _run() -> void:
	await process_frame

	var sm = root.get_node("/root/SaveManager")
	_had_save = FileAccess.file_exists(sm.save_path)
	if _had_save:
		var cf := FileAccess.open(sm.save_path, FileAccess.READ)
		_save_backup = cf.get_as_text()
		cf.close()

	await _check_clean_sweep_full_hp(sm)
	await _check_clean_sweep_half_hp(sm)
	await _check_lost_pendopo(sm)
	await _check_defeat_files_nothing(sm)

	if _fails > 0:
		print("VERIFY_FAIL: %d checks failed" % _fails)
		_restore()
		quit(1)
		return
	print("LEVEL_COMPLETE_STARS_PASS")
	_restore()
	quit(0)


func _check_clean_sweep_full_hp(sm: Node) -> void:
	sm.stage_stars = {}
	var run_ctl := await _boot_stage()
	if not _booted(run_ctl):
		return
	_clear(sm)

	var total: int = run_ctl._objective.total_count()
	if total <= 0:
		_fail("run booted with no pendopo, cannot rate a clean sweep")
		await _teardown(run_ctl)
		return

	run_ctl._level_complete()
	await process_frame

	_check(
		sm.get_stage_stars(run_ctl.stage_number) == 3,
		"clean sweep at full health files 3 stars"
	)
	_check(
		_star_icon_count(run_ctl) == 3,
		"victory panel shows 3 star icons"
	)
	_check(
		_find(run_ctl.hud_ui, "EarnedStars") == null,
		"victory panel drops the stage node art"
	)
	await _teardown(run_ctl)


func _check_clean_sweep_half_hp(sm: Node) -> void:
	sm.stage_stars = {}
	var run_ctl := await _boot_stage()
	if not _booted(run_ctl):
		return
	_clear(sm)

	if run_ctl._objective.total_count() <= 0:
		_fail("run booted with no pendopo, cannot rate a clean sweep")
		await _teardown(run_ctl)
		return

	var king: Node3D = run_ctl._king_controller
	king.king_hp = king.king_max_hp * 0.5
	run_ctl._level_complete()
	await process_frame

	_check(
		sm.get_stage_stars(run_ctl.stage_number) == 2,
		"clean sweep at exactly half health files 2 stars"
	)
	_check(
		_star_icon_count(run_ctl) == 2,
		"victory panel shows 2 star icons"
	)
	await _teardown(run_ctl)


func _check_lost_pendopo(sm: Node) -> void:
	sm.stage_stars = {}
	var run_ctl := await _boot_stage()
	if not _booted(run_ctl):
		return
	_clear(sm)

	if run_ctl._objective.total_count() <= 0:
		_fail("run booted with no pendopo, cannot rate a fallen fort")
		await _teardown(run_ctl)
		return

	run_ctl._objective.on_pendopo_destroyed()
	run_ctl._level_complete()
	await process_frame

	_check(
		sm.get_stage_stars(run_ctl.stage_number) == 1,
		"a fallen pendopo files 1 star even at full health"
	)
	_check(
		_star_icon_count(run_ctl) == 1,
		"victory panel shows 1 star icon"
	)
	await _teardown(run_ctl)


func _check_defeat_files_nothing(sm: Node) -> void:
	sm.stage_stars = {}
	var run_ctl := await _boot_stage()
	if not _booted(run_ctl):
		return
	_clear(sm)

	run_ctl._level_failed()
	await process_frame

	_check(
		sm.get_stage_stars(run_ctl.stage_number) == 0,
		"a defeat files no stars"
	)
	await _teardown(run_ctl)


func _boot_stage() -> Node3D:
	var run_ctl: Node3D = load("res://scenes/run/RunController.tscn").instantiate()
	root.add_child(run_ctl)
	for i in 400:
		await process_frame
		if run_ctl.garrison != null and run_ctl._king_controller != null:
			break
	return run_ctl


func _booted(run_ctl: Node3D) -> bool:
	if run_ctl == null or run_ctl._king_controller == null:
		_fail("level did not boot a king")
		return false
	return true


func _teardown(run_ctl: Node3D) -> void:
	run_ctl.queue_free()
	for i in 10:
		await process_frame


func _clear(sm: Node) -> void:
	sm.stage_number = 1
	sm.stage_stars = {}
	sm.gold = 500


## The rating is a row of star icons in the panel's info block, one per earned star.
## Counted by their texture so nothing else can be mistaken for a rating.
func _star_icon_count(run_ctl: Node3D) -> int:
	return _count_star_icons(run_ctl.hud_ui)


func _count_star_icons(node: Node) -> int:
	var n := 0
	if node is TextureRect:
		var tr := node as TextureRect
		if tr.texture != null and tr.texture.resource_path.get_file() == "star.png":
			n += 1
	for child in node.get_children():
		n += _count_star_icons(child)
	return n


func _find(node: Node, target: String) -> Node:
	if node.name == target:
		return node
	for child in node.get_children():
		var hit := _find(child, target)
		if hit != null:
			return hit
	return null


func _restore() -> void:
	var sm = root.get_node("/root/SaveManager")
	if _had_save:
		var f := FileAccess.open(sm.save_path, FileAccess.WRITE)
		f.store_string(_save_backup)
		f.close()
	else:
		DirAccess.remove_absolute(sm.save_path)
	sm.load_game()