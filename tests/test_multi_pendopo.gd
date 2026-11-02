extends SceneTree

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

	_test_pendopo_count()
	_test_pendopo_separation()
	_test_lose_requires_all()
	await _test_king_heals_at_any()
	await _test_enemy_targets_nearest()

	if failures > 0:
		push_error("Multi-pendopo regression (%d failures)" % failures)
		quit(1)
		return
	print("MULTI_PENDOPO_PASS")
	quit(0)


# ─── Placement ───

func _test_pendopo_count() -> void:
	print("-- pendopo count per stage --")
	for s in [1, 30, 49, 50, 100, 149, 150, 250, 400]:
		var picked: Array = _pendopo_tiles(s)
		_check(
			"S%d places %d pendopos (wanted %d)" % [s, picked.size(), ProgressionData.pendopo_count(s)],
			picked.size() == ProgressionData.pendopo_count(s)
		)
	_check("S1 has a single pendopo", _pendopo_tiles(1).size() == 1)


func _pendopo_tiles(stage: int) -> Array:
	return MapGenerator.generate(stage).get("pendopo_plots", [])


func _test_pendopo_separation() -> void:
	print("-- pendopos are far apart --")
	# The user asked for pendopos "over a long distance". Verify over many random
	# map layouts, since MapGenerator randomises the base phase each run.
	#
	# Checked per arena size rather than pooled across them: each size has its own
	# solved bound, and a 2-pendopo arena is deliberately tighter than a 3-pendopo one.
	# Pooling let the tighter case fail the looser case's threshold and pointed the
	# failure at the wrong arena.
	for s in [50, 150, 250]:
		var count: int = ProgressionData.pendopo_count(s)
		var worst := INF
		for trial in 8:
			var picked: Array = _pendopo_tiles(s)
			for i in range(picked.size()):
				for j in range(i + 1, picked.size()):
					worst = minf(worst, Vector2i(picked[i]).distance_to(Vector2i(picked[j])))
		# The non-overlap bound the geometry solves for: two clusters stay apart as long
		# as the bases are at least 2 x scatter_max apart. Derived from the arena, not
		# hand-picked.
		var expected: float = MapGenerator._scatter_max(ProgressionData.map_size(s), count) * 2.0
		_check(
			"S%d (%d pendopos) clear their clusters: >= %.1f (worst %.1f)" % [s, count, expected, worst],
			worst >= expected
		)

	# Two pendopos at stage 50 is the tightest realistic case.
	var tight_worst := INF
	for trial in 8:
		var picked: Array = _pendopo_tiles(50)
		tight_worst = minf(
			tight_worst,
			Vector2i(picked[0]).distance_to(Vector2i(picked[1]))
		)
	var tight_expected: float = MapGenerator._scatter_max(ProgressionData.map_size(50), ProgressionData.pendopo_count(50)) * 2.0
	_check(
		"S50 two pendopos clear their clusters: >= %.1f (worst %.1f)" % [tight_expected, tight_worst],
		tight_worst >= tight_expected
	)

	# A lone pendopo anchors the exact centre, because the king and the edge roads
	# both key off it. With two or more the user asked for no centre pendopo: the
	# bases sit evenly around the middle so none is stranded in the hub.
	var s1: Array = _pendopo_tiles(1)
	_check("S1 has one pendopo at the map centre", Vector2i(s1[0]) == Vector2i(16, 16))
	for s in [50, 150, 250]:
		var ms: int = ProgressionData.map_size(s)
		var centre := Vector2i(ms / 2, ms / 2)
		var at_centre := false
		for p in _pendopo_tiles(s):
			if Vector2i(p) == centre:
				at_centre = true
		_check("S%d has no centre pendopo" % s, not at_centre)


# ─── Lose condition ───

func _test_lose_requires_all() -> void:
	print("-- lose only when all pendopos fall --")
	var objective: ObjectiveState = ObjectiveState.new()
	objective.configure(3)
	_check("starts with 3 alive", objective.alive_count() == 3)
	_check("not lost at start", not objective.is_lost())

	objective.on_pendopo_destroyed()
	_check("2 alive after first fall", objective.alive_count() == 2)
	_check("NOT lost with 2 still standing", not objective.is_lost())

	objective.on_pendopo_destroyed()
	_check("1 alive after second fall", objective.alive_count() == 1)
	_check("NOT lost with 1 still standing", not objective.is_lost())

	objective.on_pendopo_destroyed()
	_check("0 alive after third fall", objective.alive_count() == 0)
	_check("LOST only when the last one falls", objective.is_lost())

	# King death is an independent loss path.
	var k: ObjectiveState = ObjectiveState.new()
	k.configure(3)
	k.on_king_died()
	_check("king death loses immediately even with pendopos up", k.is_lost())
	_check("king death does not clear the pendopo count", k.alive_count() == 3)

	# Single-pendopo stages must still lose as soon as it falls.
	var one: ObjectiveState = ObjectiveState.new()
	one.configure(1)
	one.on_pendopo_destroyed()
	_check("S<50 single pendopo loses on its fall", one.is_lost())

	# Duplicate / extra signals must not push the count negative.
	var d: ObjectiveState = ObjectiveState.new()
	d.configure(2)
	d.on_pendopo_destroyed()
	d.on_pendopo_destroyed()
	d.on_pendopo_destroyed()
	_check("extra falls clamp at 0", d.alive_count() == 0)


# ─── King healing ───

func _test_king_heals_at_any() -> void:
	print("-- king heals at any living pendopo --")
	var king: Node3D = load("res://scenes/run/KingController.gd").new()
	root.add_child(king)
	await process_frame

	var p1 := Vector3(-40, 0, 0)
	var p2 := Vector3(40, 0, 0)
	var both: Array[Vector3] = [p1, p2]
	var heal_rates: Array[float] = [20.0, 40.0]
	king.pendopo_positions = both
	king.pendopo_heal_rates = heal_rates
	king.king_hp = 10.0

	king.position = Vector3(-40, 0, 0)
	king._update_pendopo_healing(1.0)
	_check("heals while standing on the first pendopo", king.healing_active)
	_check("first pendopo restores its specified heal rate", is_equal_approx(king.king_hp, 30.0))

	king.position = Vector3(40, 0, 0)
	king.king_hp = 10.0
	king._update_pendopo_healing(1.0)
	_check("heals while standing on the second pendopo", king.healing_active)
	_check("second pendopo uses its own heal rate", is_equal_approx(king.king_hp, 50.0))

	king.position = Vector3(0, 0, 0)
	king._update_pendopo_healing(1.0)
	_check("does NOT heal between pendopos", not king.healing_active)

	# Falling back to a single-element list keeps old behaviour.
	var solo: Node3D = load("res://scenes/run/KingController.gd").new()
	root.add_child(solo)
	await process_frame
	var single: Array[Vector3] = [p1]
	solo.pendopo_positions = single
	solo.king_hp = 10.0
	solo.position = Vector3(-40, 0, 0)
	solo._update_pendopo_healing(1.0)
	_check("single-pendopo healing still works", solo.healing_active)
	solo.queue_free()
	king.queue_free()


# ─── Enemy targeting ───

func _test_enemy_targets_nearest() -> void:
	print("-- enemies target the nearest living pendopo --")
	var im: Node3D = load("res://scenes/run/InvasionManager.gd").new()
	root.add_child(im)
	await process_frame

	var a := _FakePendopo.new()
	var b := _FakePendopo.new()
	a.position = Vector3(0, 0.3, 0)
	b.position = Vector3(100, 0.3, 0)
	im.set_pendopo_refs([a, b])

	_check("two pendopos registered", im.get_alive_pendopo_count() == 2)
	_check("enemy near A targets A", im._nearest_pendopo_index(Vector3(5, 0, 0)) == 0)
	_check("enemy near B targets B", im._nearest_pendopo_index(Vector3(95, 0, 0)) == 1)
	_check("enemy in the middle picks the closer one", im._nearest_pendopo_index(Vector3(60, 0, 0)) == 1)

	# A destroyed pendopo must be ignored, pulling enemies onto the survivor.
	a.destroyed = true
	_check("destroyed pendopo no longer counted", im.get_alive_pendopo_count() == 1)
	_check("enemies retarget the survivor", im._nearest_pendopo_index(Vector3(5, 0, 0)) == 1)

	b.destroyed = true
	_check("no living pendopos left", im.get_alive_pendopo_count() == 0)
	_check("no target when all are destroyed", im._nearest_pendopo_index(Vector3.ZERO) == -1)
	im.queue_free()


class _FakePendopo extends Node3D:
	var destroyed := false
	func is_destroyed() -> bool:
		return destroyed
