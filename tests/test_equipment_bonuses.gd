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


func _close(got: float, want: float) -> bool:
	return absf(got - want) < 0.01


func _run() -> void:
	await process_frame

	var head: Dictionary = EquipmentDatabase.get_item("sumping_gajah_ngulun")
	var right: Dictionary = EquipmentDatabase.get_item("cincin_setyaningampal")
	var left: Dictionary = EquipmentDatabase.get_item("cincin_mangkurawan")
	var body: Dictionary = EquipmentDatabase.get_item("sabuk_cinde_puspita")

	_check("head fits head", EquipmentDatabase.item_fits_slot(head, "head"))
	_check("head rejects hand", not EquipmentDatabase.item_fits_slot(head, "right_hand"))
	_check("hand fits right", EquipmentDatabase.item_fits_slot(right, "right_hand"))
	_check("hand fits left", EquipmentDatabase.item_fits_slot(right, "left_hand"))
	_check("hand rejects head", not EquipmentDatabase.item_fits_slot(right, "head"))
	_check("body fits body", EquipmentDatabase.item_fits_slot(body, "body"))
	_check("can_equip known item", EquipmentDatabase.can_equip("sumping_gajah_ngulun", "head"))
	_check("cannot equip wrong slot", not EquipmentDatabase.can_equip("sumping_gajah_ngulun", "body"))
	_check("cannot equip unknown item", not EquipmentDatabase.can_equip("missing_item", "head"))

	var equipped := {
		"head": "sumping_gajah_ngulun",
		"body": "sabuk_cinde_puspita",
		"right_hand": "cincin_setyaningampal",
		"left_hand": "cincin_mangkurawan",
	}
	var bonuses: Dictionary = EquipmentDatabase.get_bonuses(equipped)
	_check("attack sums both hands", _close(float(bonuses["attack"]), 20.0))
	_check("defense sums all slots", _close(float(bonuses["defense"]), 15.0))
	_check("hp sums all slots", _close(float(bonuses["hp"]), 160.0))
	_check("mana mapped", _close(float(bonuses["mana_max"]), 40.0))
	_check("stamina mapped", _close(float(bonuses["stamina_max"]), 12.0))

	var empty_bonuses: Dictionary = EquipmentDatabase.get_bonuses({})
	for key: String in ["attack", "defense", "hp", "mana_max", "stamina_max"]:
		_check("empty %s is zero" % key, _close(float(empty_bonuses[key]), 0.0))

	var base := {
		"attack": 25.0,
		"defense": 0.0,
		"hp": 300.0,
		"mana_max": 200.0,
		"stamina_max": 100.0,
	}
	var final_stats: Dictionary = EquipmentDatabase.apply_to_stats(base, equipped)
	_check("base attack boosted", _close(float(final_stats["attack"]), 45.0))
	_check("base defense boosted", _close(float(final_stats["defense"]), 15.0))
	_check("base hp boosted", _close(float(final_stats["hp"]), 460.0))
	_check("base mana boosted", _close(float(final_stats["mana_max"]), 240.0))
	_check("base stamina boosted", _close(float(final_stats["stamina_max"]), 112.0))
	_check("base stats not mutated", _close(float(base["attack"]), 25.0) and _close(float(base["hp"]), 300.0))

	_check("head stat text", EquipmentDatabase.format_stats(head) == "ATK+6  MP+40")
	_check("hand stat text", EquipmentDatabase.format_stats(right) == "ATK+5  DEF+3  HP+20")
	_check("body stat text", EquipmentDatabase.format_stats(body) == "DEF+6  HP+100  STA+12")

	var tm = root.get_node("/root/TranslationManager")
	var previous_lang: String = tm.current_language
	tm.current_language = "en"
	_check("equipment descriptions are absent", tm.item_description(head).is_empty())
	tm.current_language = "id"
	_check("equipment descriptions stay absent in Indonesian", tm.item_description(head).is_empty())
	tm.current_language = previous_lang

	if _fails == 0:
		print("EQUIPMENT_BONUSES_PASS")
		quit(0)
	else:
		print("EQUIPMENT_BONUSES_FAIL: %d" % _fails)
		quit(1)
