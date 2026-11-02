extends SceneTree

# Slice C: fixed 10-tile arrow range, per-troop stats, and stage-gated enemy rosters.

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

	_test_arrow_range_constant()
	_test_tower_range_is_fixed()
	_test_troop_stats()
	_test_archer_outranges_infantry()
	_test_enemy_roster_gating()
	_test_troop_key_normalisation()

	if failures > 0:
		push_error("Ranged combat regression (%d failures)" % failures)
		quit(1)
		return
	print("RANGED_COMBAT_PASS")
	quit(0)


func _test_arrow_range_constant() -> void:
	_check("ARROW_RANGE is 10 world units (10 tiles)", is_equal_approx(ProgressionData.ARROW_RANGE, 10.0))


func _test_tower_range_is_fixed() -> void:
	var seen: Dictionary = {}
	for lvl in range(1, 11):
		seen[ProgressionData.tower_range(lvl)] = true
	_check("tower range never exceeds 10 units at any level", ProgressionData.tower_range(10) <= 10.0)
	_check("tower range is level-invariant (1 key for levels 1-10)", seen.size() == 1)
	_check("tower range equals ARROW_RANGE", is_equal_approx(ProgressionData.tower_range(1), ProgressionData.ARROW_RANGE))


func _test_troop_stats() -> void:
	for type in ["infantry", "archer"]:
		var s: Dictionary = ProgressionData.troop_stats(type)
		_check("%s has hp/attack/range/cooldown/speed" % type, not s.is_empty() and s.has("hp")
			and s.has("attack") and s.has("range") and s.has("cooldown") and s.has("speed"))
		_check("%s hp > 0" % type, s.get("hp", 0.0) > 0.0)
		_check("%s attack > 0" % type, s.get("attack", 0.0) > 0.0)
		_check("%s speed > 0" % type, s.get("speed", 0.0) > 0.0)

	# Archers are fragile glass cannons: more range, less health, slower.
	var inf: Dictionary = ProgressionData.troop_stats("infantry")
	var arc: Dictionary = ProgressionData.troop_stats("archer")
	var barracks6_inf: Dictionary = ProgressionData.troop_stats("infantry", 6)
	var barracks6_arc: Dictionary = ProgressionData.troop_stats("archer", 6)
	_check("friendly infantry speed is 2.0", is_equal_approx(inf["speed"], 2.0))
	_check("friendly archer speed is 2.0", is_equal_approx(arc["speed"], 2.0))
	_check("archer range == 10", is_equal_approx(arc.get("range", 0.0), 10.0))
	_check("archer hp < infantry hp", arc.get("hp", 99.0) < inf.get("hp", 0.0))
	_check("archer attack cooldown is slower than infantry",
		arc.get("cooldown", 0.0) > inf.get("cooldown", 99.0))
	# Barracks-level scaling is the stat source of truth for ally soldiers.
	_check("infantry grows from barracks level 1 to level 6", is_equal_approx(barracks6_inf["hp"], 2000.0)
		and is_equal_approx(barracks6_inf["attack"], 100.0)
		and is_equal_approx(barracks6_inf["defense"], 30.0))
	_check("archer grows from barracks level 1 to level 6", is_equal_approx(barracks6_arc["hp"], 1600.0)
		and is_equal_approx(barracks6_arc["attack"], 120.0)
		and is_equal_approx(barracks6_arc["defense"], 20.0))
	# Detection must outrange the weapon, or an archer can never see a target.
	_check("archer detection >= archer range", arc.get("detection", 0.0) >= arc.get("range", 99.0))

	_check("unknown troop type falls back to infantry",
		ProgressionData.troop_stats("dragon") == ProgressionData.troop_stats("infantry"))


func _test_archer_outranges_infantry() -> void:
	_check("archer outranges infantry by >5 units",
		ProgressionData.troop_stats("archer")["range"] - ProgressionData.troop_stats("infantry")["range"] > 5.0)


func _test_enemy_roster_gating() -> void:
	_check("no archers before stage 30", not EnemySpawner.available_types(1).has("archer"))
	_check("no archers before stage 30 (stage 29)", not EnemySpawner.available_types(29).has("archer"))
	_check("archers from stage 30", EnemySpawner.available_types(30).has("archer"))
	_check("archers at stage 200", EnemySpawner.available_types(200).has("archer"))
	_check("infantry always available", EnemySpawner.available_types(1).has("infantry"))
	_check("early roster is infantry only", EnemySpawner.available_types(10) == ["infantry"])
	_check("late roster is infantry and archer", EnemySpawner.available_types(100).size() == 2)
	_check("cavalry is not in the enemy roster",
		not EnemySpawner.available_types(100).has("cavalry"))
	var enemy: Dictionary = EnemySpawner.spawn_batch(1, 1, 1, [])[0]
	_check("enemy infantry speed is 1.9", is_equal_approx(enemy["speed"], 1.9))


func _test_troop_key_normalisation() -> void:
	# buildings.json, EnemySpawner and the HUD all say "archer", but PlayerGarrison
	# historically used "archers" and silently dropped the singular key.
	var g := PlayerGarrison.new()
	g.add_troops("archer", 2)
	_check("add_troops(\"archer\") is counted", g.archers == 2)
	g.add_troops("archers", 1)
	_check("add_troops(\"archers\") is an accepted alias", g.archers == 3)
	_check("_get_count(\"archer\") matches", g._get_count("archer") == 3)
	_check("has_troops(\"archer\") sees the count", g.has_troops("archer", 3))
	_check("get_total counts archers", g.get_total() == 3)
	g.remove_troops("archer", 1)
	_check("remove_troops(\"archer\") works", g.archers == 2)
	var dist: Dictionary = g.get_distributed({"infantry": 0.5, "archer": 0.5})
	_check("formation can distribute archers", dist.has("archer"))
