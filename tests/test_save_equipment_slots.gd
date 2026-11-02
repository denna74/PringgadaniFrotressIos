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
	_check("old accessory key is gone from defaults", not sm.equipment.has("accessory"))

	sm.equipment = {
		"head": "",
		"body": "",
		"right_hand": "",
		"left_hand": "",
		"accessory": "",
	}
	sm.inventory = [
		{"id": "sumping_gajah_ngulun", "quantity": 1},
		{"id": "cincin_setyaningampal", "quantity": 1},
		{"id": "sabuk_cinde_puspita", "quantity": 1},
	]
	var invalid_ok: Variant = sm.equip_item("accessory", "cincin_setyaningampal")
	_check("invalid slot rejected", invalid_ok != true)
	var wrong_type_ok: Variant = sm.equip_item("head", "sabuk_cinde_puspita")
	_check("wrong category rejected", wrong_type_ok != true)
	var unowned_ok: Variant = sm.equip_item("head", "garuda_mungkur")
	_check("unowned item rejected", unowned_ok != true)
	var unknown_ok: Variant = sm.equip_item("head", "missing_item")
	_check("unknown item rejected", unknown_ok != true)

	var head_ok: Variant = sm.equip_item("head", "sumping_gajah_ngulun")
	_check("head equip succeeds", head_ok == true)
	_check("head stored", sm.get_equipped("head") == "sumping_gajah_ngulun")
	var body_ok: Variant = sm.equip_item("body", "sabuk_cinde_puspita")
	_check("body equip succeeds", body_ok == true)
	_check("body stored", sm.get_equipped("body") == "sabuk_cinde_puspita")

	var right_ok: Variant = sm.equip_item("right_hand", "cincin_setyaningampal")
	_check("right hand equip succeeds", right_ok == true)
	_check("right hand stored", sm.get_equipped("right_hand") == "cincin_setyaningampal")
	var left_ok: Variant = sm.equip_item("left_hand", "cincin_setyaningampal")
	_check("same item moves to left hand", left_ok == true)
	_check("left hand stored", sm.get_equipped("left_hand") == "cincin_setyaningampal")
	_check("right hand cleared after move", sm.get_equipped("right_hand").is_empty())
	var right_again_ok: Variant = sm.equip_item("right_hand", "cincin_setyaningampal")
	_check("same item moves back to right hand", right_again_ok == true)
	_check("right hand stored after move", sm.get_equipped("right_hand") == "cincin_setyaningampal")
	_check("left hand cleared after move", sm.get_equipped("left_hand").is_empty())

	var bad_unequip_ok: Variant = sm.unequip_slot("accessory")
	_check("unequip invalid slot rejected", bad_unequip_ok != true)
	var unequip_ok: Variant = sm.unequip_slot("head")
	_check("unequip head succeeds", unequip_ok == true)
	_check("head cleared", sm.get_equipped("head").is_empty())

	sm.equipment = {
		"head": "sumping_gajah_ngulun",
		"body": "sabuk_cinde_puspita",
		"right_hand": "cincin_setyaningampal",
		"left_hand": "cincin_setyaningampal",
		"accessory": "cincin_bulan",
	}
	sm.sanitize_equipment()
	_check("sanitize keeps valid head", sm.get_equipped("head") == "sumping_gajah_ngulun")
	_check("sanitize keeps valid body", sm.get_equipped("body") == "sabuk_cinde_puspita")
	_check("sanitize removes accessory", not sm.equipment.has("accessory"))
	_check("sanitize collapses duplicate hand", sm.get_equipped("right_hand") == "cincin_setyaningampal")
	_check("sanitize clears duplicate left hand", sm.get_equipped("left_hand").is_empty())

	sm.inventory = [{"id": "sumping_gajah_ngulun", "quantity": 1}]
	sm.equipment = {
		"head": "gartotkaca",
		"body": "sabuk_cinde_puspita",
		"right_hand": "",
		"left_hand": "",
	}
	sm.sanitize_equipment()
	_check("sanitize drops unknown item", sm.get_equipped("head").is_empty())
	_check("sanitize drops unowned item", sm.get_equipped("body").is_empty())

	var data := {
		"equipment": {
			"head": "old_weapon",
			"body": "sabuk_cinde_puspita",
			"right_hand": "cincin_setyaningampal",
			"left_hand": "cincin_setyaningampal",
			"accessory": "cincin_bulan",
		},
		"inventory": [
			{"id": "sabuk_cinde_puspita", "quantity": 1},
			{"id": "cincin_setyaningampal", "quantity": 1},
		],
	}
	var file := FileAccess.open(sm.save_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()
	sm.load_game()
	_check("load drops old equipment id", sm.get_equipped("head").is_empty())
	_check("load drops old accessory slot", not sm.equipment.has("accessory"))
	_check("load keeps valid body", sm.get_equipped("body") == "sabuk_cinde_puspita")
	_check("load keeps valid hand", sm.get_equipped("right_hand") == "cincin_setyaningampal")
	_check("load drops duplicate hand", sm.get_equipped("left_hand").is_empty())

	if _fails == 0:
		print("SAVE_EQUIPMENT_SLOTS_PASS")
		quit(0)
	else:
		print("SAVE_EQUIPMENT_SLOTS_FAIL: %d" % _fails)
		quit(1)
