extends SceneTree

# The stage star rule and its persistence.
#
# Rating a cleared stage:
#   3 stars -- every pendopo standing AND the king above half health
#   2 stars -- every pendopo standing AND the king at or below half health
#   1 star  -- at least one pendopo fell
# A defeat awards nothing; whatever the stage already held is kept.

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

	_check_rule()
	_check_persistence()

	if failures > 0:
		push_error("Stage stars regression (%d failures)" % failures)
		quit(1)
		return
	print("STAGE_STARS_PASS")
	quit(0)


func _check_rule() -> void:
	_check(
		"all pendopo, full hp = 3",
		ProgressionData.stage_stars(3, 3, 300.0, 300.0) == 3
	)
	_check(
		"all pendopo, hp just above half = 3",
		ProgressionData.stage_stars(3, 3, 151.0, 300.0) == 3
	)
	_check(
		"all pendopo, hp exactly half = 2",
		ProgressionData.stage_stars(3, 3, 150.0, 300.0) == 2
	)
	_check(
		"all pendopo, hp under half = 2",
		ProgressionData.stage_stars(3, 3, 10.0, 300.0) == 2
	)
	_check(
		"all pendopo, hp zero = 2",
		ProgressionData.stage_stars(3, 3, 0.0, 300.0) == 2
	)

	_check(
		"one pendopo lost, full hp = 1",
		ProgressionData.stage_stars(2, 3, 300.0, 300.0) == 1
	)
	_check(
		"one pendopo lost, half hp = 1",
		ProgressionData.stage_stars(2, 3, 150.0, 300.0) == 1
	)
	_check(
		"every pendopo lost = 1",
		ProgressionData.stage_stars(0, 3, 300.0, 300.0) == 1
	)

	# A stage whose pendopo count is unknown cannot claim a clean sweep, and a zero
	# max hp must not divide by zero.
	_check(
		"no pendopo known = 1",
		ProgressionData.stage_stars(0, 0, 300.0, 300.0) == 1
	)
	_check(
		"zero max hp = 2",
		ProgressionData.stage_stars(3, 3, 300.0, 0.0) == 2
	)


func _check_persistence() -> void:
	var sm = root.get_node("/root/SaveManager")
	var save_backup := _backup_save()
	sm.stage_stars = {}
	sm.save_game()

	_check("unplayed stage reads 0", sm.get_stage_stars(7) == 0)

	sm.record_stage_stars(3, 2)
	_check("recorded 2 reads back 2", sm.get_stage_stars(3) == 2)

	# Replaying badly must not take the record away.
	sm.record_stage_stars(3, 1)
	_check("worse replay keeps 2", sm.get_stage_stars(3) == 2)

	sm.record_stage_stars(3, 3)
	_check("better replay raises to 3", sm.get_stage_stars(3) == 3)

	_check("other stages unaffected", sm.get_stage_stars(4) == 0)

	sm.record_stage_stars(5, 9)
	_check("out of range rating clamps to 3", sm.get_stage_stars(5) == 3)
	sm.record_stage_stars(6, -4)
	_check("negative rating clamps to 0", sm.get_stage_stars(6) == 0)

	sm.save_game()
	sm.stage_stars = {}
	sm.load_game()
	_check("stage 3 survives a save/load cycle", sm.get_stage_stars(3) == 3)
	_check("stage 5 survives a save/load cycle", sm.get_stage_stars(5) == 3)
	_check("stage 6 survives a save/load cycle", sm.get_stage_stars(6) == 0)

	_restore_save(save_backup)


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