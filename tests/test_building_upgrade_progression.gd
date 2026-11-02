extends SceneTree

var _fails: int = 0


func _initialize() -> void:
	_run()


func _check(name: String, ok: bool) -> void:
	if ok:
		print("OK  ", name)
	else:
		_fails += 1
		push_error("FAIL " + name)


func _run() -> void:
	await process_frame
	var expected_effects := {
		"pendopo": [1000.0, 1500.0, 2700.0, 5500.0, 7500.0, 10000.0],
		"pendopo_heal": [20.0, 25.0, 40.0, 55.0, 75.0, 100.0],
		"menara": [25.0, 30.0, 40.0, 50.0, 65.0, 80.0],
		"tambang_emas": [5.0, 10.0, 17.0, 25.0, 35.0, 50.0],
	}
	var expected_costs := {
		"pendopo": [7000, 20000, 35000, 50000, 70000],
		"menara": [5000, 15000, 27000, 40000, 55000],
		"tambang_emas": [8500, 23000, 40000, 60000, 85000],
		"barak": [6500, 21000, 38000, 55000, 80000],
	}
	var all_effects_match := true
	for level in BuildingUpgradeData.MAX_LEVEL:
		all_effects_match = all_effects_match \
			and ProgressionData.pendopo_hp(level + 1) == expected_effects["pendopo"][level] \
			and ProgressionData.pendopo_heal(level + 1) == expected_effects["pendopo_heal"][level] \
			and ProgressionData.tower_damage(level + 1) == expected_effects["menara"][level] \
			and BuildingUpgradeData.current_effect("tambang_emas", level + 1) == expected_effects["tambang_emas"][level]
	_check("all building effects match specification", all_effects_match)
	var all_costs_match := true
	for id in expected_costs:
		for current_level in range(1, BuildingUpgradeData.MAX_LEVEL):
			all_costs_match = all_costs_match \
				and BuildingUpgradeData.upgrade_cost(id, current_level) \
				== expected_costs[id][current_level - 1]
	_check("all building upgrade prices match specification", all_costs_match)
	_check("barracks trains faster at higher level",
		BuildingUpgradeData.barracks_training_time(3.0, 6)
		< BuildingUpgradeData.barracks_training_time(3.0, 1))

	var save = root.get_node("/root/SaveManager")
	save.gold = 100000
	save.building_upgrade_levels = {
		"pendopo": 1, "menara": 1, "barak": 1, "tambang_emas": 1
	}
	var old_gold: int = save.gold
	var cost: int = BuildingUpgradeData.upgrade_cost("menara", 1)
	_check("building upgrade succeeds", save.upgrade_building("menara"))
	_check("building level persists in save state", save.get_building_upgrade_level("menara") == 2)
	_check("building upgrade deducts gold", save.gold == old_gold - cost)
	_check("unknown building upgrade rejected", not save.upgrade_building("unknown"))
	save.save_game()
	save.building_upgrade_levels["menara"] = 1
	save.load_game()
	_check("building level survives save reload", save.get_building_upgrade_level("menara") == 2)

	var plot = load("res://scenes/run/BuildingPlot.tscn").instantiate()
	root.add_child(plot)
	await process_frame
	plot._place_building_from_data(BuildingData.get_building_data("menara"))
	await process_frame
	var tower = plot.current_building
	_check("placed tower inherits Undagi level", tower != null and tower.level == 2)
	_check("placed tower uses upgraded gameplay damage",
		tower != null and 		is_equal_approx(tower.attack_damage, 30.0))
	plot.queue_free()
	await process_frame

	var barak = load("res://scenes/buildings/Barak.gd").new(
		BuildingData.get_building_data("barak"), null
	)
	barak.level = 2
	root.add_child(barak)
	await process_frame
	_check("placed barracks uses faster upgraded training",
		is_equal_approx(barak._training_timer.wait_time, 2.7))
	_check("barracks progression does not increase troop cost",
		barak.get_training_cost() == 6)
	barak.queue_free()
	await process_frame

	var mine = load("res://scenes/buildings/TambangEmas.gd").new(
		BuildingData.get_building_data("tambang_emas"), null
	)
	mine.level = 2
	root.add_child(mine)
	await process_frame
	_check("upgraded gold mine uses increased gameplay production",
		mine.get_gold_production() == 10)
	mine.queue_free()
	await process_frame

	if _fails == 0:
		print("BUILDING_UPGRADE_PROGRESSION_PASS")
		quit(0)
	else:
		print("BUILDING_UPGRADE_PROGRESSION_FAIL: %d" % _fails)
		quit(1)
