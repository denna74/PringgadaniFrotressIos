extends SceneTree

# Verifies the real RunController spawns the right number of pendopos and only
# fails the run once the last one falls.

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

	for stage in [1, 60, 200]:
		await _test_stage(stage)

	if failures > 0:
		push_error("Run controller pendopo regression (%d failures)" % failures)
		quit(1)
		return
	print("RUN_PENDOPO_COUNT_PASS")
	quit(0)


func _test_stage(stage: int) -> void:
	print("-- stage %d --" % stage)
	var sm = root.get_node("/root/SaveManager")
	sm.heroes["gatotkaca"] = {"level": 50, "stars": 1, "xp": 0}
	var rc: Node3D = load("res://scenes/run/RunController.tscn").instantiate()
	var sc = root.get_node("/root/SceneManager")
	sc._pending_params = {"stage_number": stage}
	root.add_child(rc)
	# RunController defers _start_level and it awaits many frames (map gen, model
	# prewarm, navmesh), so wait for the garrison to come up.
	for i in 400:
		await process_frame
		if rc.garrison != null:
			break
	if rc.garrison == null:
		_check("stage %d booted" % stage, false)
		rc.queue_free()
		await process_frame
		return

	var expected: int = ProgressionData.pendopo_count(stage)
	var placed: Array = rc.get("pendopo_nodes")
	_check("stage %d placed %d pendopos" % [stage, placed.size()], placed.size() == expected)

	var objective: ObjectiveState = rc.get("_objective")
	_check("objective knows %d total" % expected, objective.total_count() == expected)
	_check("all alive at start", objective.alive_count() == expected)
	_check("run not lost at start", not objective.is_lost())

	var king: Node3D = rc.get("_king_controller")
	_check("king knows every pendopo position", king.pendopo_positions.size() == expected)

	var im: Node3D = rc.get("invasion_manager")
	_check("invasion manager sees %d pendopos" % expected, im.get_alive_pendopo_count() == expected)

	# Fall them one at a time; the run must survive until the last.
	for i in range(placed.size()):
		var last: bool = i == placed.size() - 1
		placed[i].take_damage(99999.0)
		await process_frame
		if last:
			_check("stage %d LOST on the final fall" % stage, objective.is_lost())
		else:
			_check(
				"stage %d survives fall %d of %d" % [stage, i + 1, placed.size()],
				not objective.is_lost()
			)
		_check(
			"stage %d invaders see %d living after fall %d" % [stage, expected - i - 1, i + 1],
			im.get_alive_pendopo_count() == expected - i - 1
		)

	rc.queue_free()
	await process_frame
