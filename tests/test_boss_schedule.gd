extends SceneTree

# Slice D integration: the boss schedule must actually reach the battlefield --
# right boss, right rig, on the right wave.

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
	await _test_schedule_reaches_waves()
	await _test_boma_fires_red_arrow()

	if failures > 0:
		push_error("Boss schedule integration (%d failures)" % failures)
		quit(1)
		return
	print("BOSS_SCHEDULE_PASS")
	quit(0)


func _test_schedule_reaches_waves() -> void:
	for stage in [10, 11, 31, 61, 91, 131, 171, 211, 251]:
		var mgr: Node = _make_manager(stage)
		var waves: int = ProgressionData.num_waves(stage)
		var expected: Dictionary = {}
		for entry in ProgressionData.boss_schedule(stage, waves):
			expected[int(entry["wave"])] = str(entry["boss_id"])

		var seen: Dictionary = {}
		for wave in range(1, waves + 1):
			mgr.stage_number = stage
			mgr.total_waves = waves
			mgr.king_level = 30
			mgr.start_wave_timer(wave)
			var id: String = mgr._boss_for_wave(wave)
			if id != "":
				seen[wave] = id
				var data: Dictionary = EnemySpawner.spawn_boss(wave, stage, 30, id)
				_check("stage %d wave %d: %s spawns flagged and ranged-correct" % [stage, wave, id],
					data.get("is_boss", false) == true and data.get("boss_id", "") == id)

		_check("stage %d spawns exactly the scheduled bosses" % stage, seen == expected)
		_check("stage %d always ends on its final boss (%s on wave %d)" % [
			stage, ProgressionData.final_boss_id(stage), waves],
			str(seen.get(waves, "")) == ProgressionData.final_boss_id(stage))
		_check("stage %d includes its scheduled boss" % stage, seen.size() > 0)
		mgr.queue_free()

	_check("stage 0 (no stage) spawns no bosses at all",
		_count(_make_manager(0), "kalapracona") == 0)


func _count(mgr: Node, boss_id: String) -> int:
	var n := 0
	for wave in range(1, mgr.total_waves + 1):
		if mgr._boss_for_wave(wave) == boss_id:
			n += 1
	return n


func _make_manager(stage: int) -> Node:
	var mgr: Node = load("res://scenes/run/InvasionManager.gd").new()
	root.add_child(mgr)
	mgr.stage_number = stage
	mgr.king_level = 30
	return mgr


func _test_boma_fires_red_arrow() -> void:
	# Build a real Boma through the spawner, drop it in front of a live soldier
	# and confirm the arrow it looses carries the red slash shadow.
	var mgr: Node = load("res://scenes/run/InvasionManager.gd").new()
	root.add_child(mgr)
	mgr.stage_number = 200
	mgr.king_level = 30
	mgr.total_waves = ProgressionData.num_waves(200)

	var soldier: Node3D = load("res://scenes/run/SoldierUnit.gd").new()
	soldier.position = Vector3(3.0, 0.0, 0.0)
	mgr.add_child(soldier)
	soldier.troop_type = "infantry"
	soldier.configure()
	await process_frame

	var data: Dictionary = EnemySpawner.spawn_boss(3, 200, 30, "boma")
	var boma: Node3D = mgr._create_enemy_node(data, Vector3.ZERO)
	mgr.add_child(boma)
	# Register it the way _spawn_single_enemy does, so _move_enemies drives it.
	mgr._enemy_nodes.append(boma)
	boma.set_meta("current_health", data.get("health", 100.0))
	boma.set_meta("max_health", data.get("health", 100.0))
	boma.set_meta("enemy_dead", false)
	await process_frame

	_check("Boma is built as a boss node", boma.is_in_group("enemies"))
	_check("Boma uses its own rig, not the Kurawa one",
		ModelLoader.find_animation_player(boma) != null
		and ModelLoader.find_animation_player(boma).has_animation_library("boss"))
	_check("Boma counts as a ranged enemy", mgr.is_enemy_ranged(boma))
	_check("Boma keeps the shared 10-tile standoff",
		is_equal_approx(mgr._enemy_standoff(data), ProgressionData.ARROW_RANGE))

	# Keep nudging until the arrow is in flight, then inspect it.
	var arrow: Node3D = null
	for i in 240:
		await physics_frame
		for child in root.get_children():
			if child is Node3D and child.has_method("get_arrow_style") \
					and child.get_arrow_style() == "boma_red":
				arrow = child
				break
		if arrow != null:
			break

	_check("Boma looses a boma_red arrow", arrow != null)
	if arrow != null:
		_check("Boma's arrow drags a red slash shadow", arrow.get_slash_shadow() != null)
		_check("Boma's arrow flies", arrow.is_inside_tree())

	mgr.queue_free()
	await process_frame
