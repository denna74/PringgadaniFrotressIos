extends SceneTree

var failures := 0


func _initialize() -> void:
	_run()


func _check(name: String, condition: bool) -> void:
	if condition:
		print("OK  ", name)
	else:
		push_error("FAIL " + name)
		failures += 1


func _check_stats(stats: Dictionary, hp: float, attack: float, defense: float, label: String) -> void:
	_check("%s HP" % label, is_equal_approx(float(stats["hp"]), hp))
	_check("%s attack" % label, is_equal_approx(float(stats["attack"]), attack))
	_check("%s defense" % label, is_equal_approx(float(stats["defense"]), defense))


func _run() -> void:
	await process_frame
	_check_stats(ProgressionData.enemy_unit_stats("infantry", 1), 400.0, 30.0, 10.0, "S1 enemy melee")
	_check_stats(ProgressionData.enemy_unit_stats("infantry", 250), 2000.0, 100.0, 30.0, "S250 enemy melee")
	_check_stats(ProgressionData.enemy_unit_stats("archer", 1), 300.0, 45.0, 5.0, "S1 enemy archer")
	_check_stats(ProgressionData.enemy_unit_stats("archer", 250), 1600.0, 120.0, 20.0, "S250 enemy archer")
	_check_stats(ProgressionData.troop_stats("infantry", 1), 400.0, 40.0, 10.0, "Barracks 1 ally melee")
	_check_stats(ProgressionData.troop_stats("infantry", 6), 2000.0, 100.0, 30.0, "Barracks 6 ally melee")
	_check_stats(ProgressionData.troop_stats("archer", 1), 300.0, 45.0, 5.0, "Barracks 1 ally archer")
	_check_stats(ProgressionData.troop_stats("archer", 6), 1600.0, 120.0, 20.0, "Barracks 6 ally archer")
	_check_stats(ProgressionData.gatotkaca_stats(1), 600.0, 100.0, 20.0, "S1 Gatotkaca")
	_check_stats(ProgressionData.gatotkaca_stats(250), 7500.0, 700.0, 60.0, "S250 Gatotkaca")

	var boss_endpoints: Dictionary = {
		"kalapracona": [[500.0, 80.0, 12.0], [3600.0, 240.0, 36.0]],
		"boma": [[520.0, 100.0, 20.0], [4500.0, 360.0, 50.0]],
		"aswatama": [[600.0, 90.0, 16.0], [5500.0, 300.0, 42.0]],
		"karna": [[800.0, 120.0, 30.0], [8500.0, 400.0, 80.0]],
	}
	for boss_id: String in boss_endpoints:
		var values: Array = boss_endpoints[boss_id]
		_check_stats(
			ProgressionData.boss_stats(boss_id, 1),
			values[0][0], values[0][1], values[0][2], "S1 %s" % boss_id
		)
		_check_stats(
			ProgressionData.boss_stats(boss_id, 250),
			values[1][0], values[1][1], values[1][2], "S250 %s" % boss_id
		)

	_check("enemy stage stats cap at stage 250",
		ProgressionData.enemy_unit_stats("archer", 400)
			== ProgressionData.enemy_unit_stats("archer", 250))
	if failures > 0:
		quit(1)
		return
	print("CHARACTER_STATS_PASS")
	quit(0)
