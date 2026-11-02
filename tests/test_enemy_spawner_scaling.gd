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

	_test_spawn_batch_scaling()
	_test_spawn_batch_underlevel()
	_test_spawn_boss_scaling()
	_test_per_wave_counts()
	_test_monotonic_across_stages()

	if failures > 0:
		push_error("Enemy spawner regression (%d failures)" % failures)
		quit(1)
		return
	print("ENEMY_SPAWNER_PASS")
	quit(0)


func _batch(s: int, w: int, king_level: int) -> Array:
	return EnemySpawner.spawn_batch(3, w, s, [], king_level)


func _test_spawn_batch_scaling() -> void:
	print("-- spawn_batch uses per-unit stage stats --")
	var e1: Dictionary = _batch(1, 1, 99)[0]
	var e100: Dictionary = _batch(100, 1, 99)[0]
	var e250: Dictionary = _batch(250, 1, 99)[0]
	_check_near("S1 infantry HP matches brainstorm", e1.get("health", 0.0), 400.0, 0.01)
	for pair in [[100, e100], [250, e250]]:
		var stats: Dictionary = ProgressionData.enemy_unit_stats(
			str(pair[1].get("type", "infantry")), int(pair[0])
		)
		_check_near("S%d HP matches unit type" % int(pair[0]),
			float(pair[1].get("health", 0.0)), float(stats["hp"]), 0.01)
		_check_near("S%d attack matches unit type" % int(pair[0]),
			float(pair[1].get("attack", 0.0)), float(stats["attack"]), 0.01)
		_check_near("S%d defense matches unit type" % int(pair[0]),
			float(pair[1].get("defense", 0.0)), float(stats["defense"]), 0.01)
	_check("max_health mirrors health", is_equal_approx(e250.get("max_health", 0.0), e250.get("health", -1.0)))


func _test_spawn_batch_underlevel() -> void:
	print("-- spawn stats are stage-based, not king-level-based --")
	seed(78123)
	var on_level: Dictionary = _batch(100, 1, 99)[0]
	seed(78123)
	var under: Dictionary = _batch(100, 1, 40)[0]
	_check("same enemy type regardless of king level",
		under.get("type", "") == on_level.get("type", ""))
	_check("underlevel does not change enemy HP",
		is_equal_approx(float(under["health"]), float(on_level["health"])))
	_check("underlevel does not change enemy attack",
		is_equal_approx(float(under["attack"]), float(on_level["attack"])))


func _test_spawn_boss_scaling() -> void:
	print("-- spawn_boss uses linear scaling --")
	var b1: Dictionary = EnemySpawner.spawn_boss(1, 1, 99)
	var b250: Dictionary = EnemySpawner.spawn_boss(1, 250, 99)
	_check("boss is_boss true", b250.get("is_boss", false) == true)
	for id in ["kalapracona", "boma", "aswatama", "karna"]:
		var boss: Dictionary = EnemySpawner.spawn_boss(1, 250, 99, id)
		_check_near(
			"%s stage-250 HP matches brainstorm" % id,
			boss.get("health", 0.0),
			ProgressionData.boss_stats(id, 250)["hp"],
			0.01
		)
		_check_near(
			"%s stage-250 attack matches brainstorm" % id,
			boss.get("attack", 0.0),
			ProgressionData.boss_stats(id, 250)["attack"],
			0.01
		)
		_check_near(
			"%s stage-250 defense matches brainstorm" % id,
			boss.get("defense", 0.0),
			ProgressionData.boss_stats(id, 250)["defense"],
			0.01
		)
	_check(
		"final boss outguns the Kalapracona miniboss",
		float(EnemySpawner.spawn_boss(1, 250, 99, "boma")["health"])
			> float(EnemySpawner.spawn_boss(1, 250, 99, "kalapracona")["health"])
	)
	_check("boss health > grunt health", b250.get("health", 0.0) > b1.get("health", 0.0))
	_check("boss beyond cap frozen", is_equal_approx(
		EnemySpawner.spawn_boss(1, 400, 99).get("health", 0.0),
		b250.get("health", -1.0)
	))


func _test_per_wave_counts() -> void:
	print("-- wave composition --")
	# A full stage must total roughly the budget, and the final wave must be the biggest.
	var stage_one_total := 0
	for wave in range(1, ProgressionData.num_waves(1) + 1):
		stage_one_total += EnemySpawner.spawn_wave(
			wave, ProgressionData.num_waves(1), 1, [], 99
		).size()
	_check("S1 spawns 25 enemies", stage_one_total == 25)

	for s in [1, 50, 150, 250]:
		var total := 0
		var w: int = ProgressionData.num_waves(s)
		for i in range(1, w + 1):
			var enemies: Array = EnemySpawner.spawn_wave(i, w, s, [], 99)
			total += enemies.size()
			var boss_count := 0
			for e in enemies:
				if e.get("is_boss", false):
					boss_count += 1
			if i == w:
				_check("S%d final wave has exactly 1 boss" % s, boss_count == 1)
			else:
				_check("S%d wave %d has no boss" % [s, i], boss_count == 0)
		_check(
			"S%d total spawned %d within %d of budget %d" % [s, total, w, ProgressionData.enemy_budget(s)],
			absi(total - ProgressionData.enemy_budget(s)) <= w
		)


func _test_monotonic_across_stages() -> void:
	print("-- no exponential blowup across stages --")
	_check(
		"infantry health non-decreasing S1..400",
		_is_nondecreasing(func(s: int) -> float:
			return ProgressionData.enemy_unit_stats("infantry", s)["hp"])
	)
	# The old curve reached 5.5e15 HP at stage 250. Guard against any return to that.
	var peak: float = ProgressionData.enemy_unit_stats("infantry", 250)["hp"]
	_check("S250 grunt health under 100000 (was 5.5e15)", peak < 100000.0)
	_check("S400 grunt health identical to S250", is_equal_approx(
		float(ProgressionData.enemy_unit_stats("infantry", 400)["hp"]), peak
	))


func _check_near(name: String, actual: float, expected: float, tol: float) -> void:
	_check("%s (got %s, want ~%s)" % [name, actual, expected], absf(actual - expected) <= tol)


func _is_near(a: float, b: float) -> bool:
	return absf(a - b) <= 0.01


func _is_nondecreasing(f: Callable) -> bool:
	var prev: float = -INF
	for s in range(1, 401):
		var v: float = f.call(s)
		if v < prev:
			return false
		prev = v
	return true
