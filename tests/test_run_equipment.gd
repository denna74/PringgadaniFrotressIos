extends SceneTree

var _fails: int = 0


func _initialize() -> void:
	_run()


func _check(name: String, ok: bool) -> void:
	if ok:
		print("OK  ", name)
	else:
		_fails += 1
		print("CHECK FAIL: " + name)


func _run() -> void:
	await process_frame

	var sm = root.get_node("/root/SaveManager")
	var runner = load("res://scenes/run/RunController.gd").new()

	sm.equipment = {"head": "", "body": "", "right_hand": "", "left_hand": ""}
	var base: Dictionary = runner._king_stats_for(1, 1, 1)
	_check("unequipped HP follows stage stats", int(base["hp"]) == 600)
	_check("unequipped attack follows stage stats", int(base["attack"]) == 100)
	_check("unequipped defense follows stage stats", int(base["defense"]) == 20)
	_check("unequipped mana is base", int(base["mana_max"]) == 210)
	_check("unequipped stamina is base", int(base["stamina_max"]) == 104)

	sm.equipment = {
		"head": "sumping_gajah_ngulun",
		"body": "sabuk_cinde_puspita",
		"right_hand": "cincin_setyaningampal",
		"left_hand": "cincin_mangkurawan",
	}
	var boosted: Dictionary = runner._king_stats_for(1, 1, 1)
	_check("equipped HP gets body and hand bonuses", int(boosted["hp"]) == 760)
	_check("equipped attack gets head and hand bonuses", int(boosted["attack"]) == 120)
	_check("equipped defense gets body and hand bonuses", int(boosted["defense"]) == 35)
	_check("equipped mana gets head bonus", int(boosted["mana_max"]) == 250)
	_check("equipped stamina gets body bonus", int(boosted["stamina_max"]) == 116)

	var leveled: Dictionary = runner._king_stats_for(2, 1, 1)
	_check("gameplay level does not change stage-based HP", int(leveled["hp"]) == 760)
	_check("gameplay level does not change stage-based attack", int(leveled["attack"]) == 120)
	_check("mana still grows with gameplay level", int(leveled["mana_max"]) > int(boosted["mana_max"]))

	runner.free()

	if _fails == 0:
		print("RUN_EQUIPMENT_PASS")
		quit(0)
	else:
		print("RUN_EQUIPMENT_FAIL: %d" % _fails)
		quit(1)
