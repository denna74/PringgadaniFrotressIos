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

	_check("win_xp(S1) = 50", ProgressionData.win_xp(1) == 50)
	_check("win_xp(S5) = 250", ProgressionData.win_xp(5) == 250)
	_check("win_xp(S10) = 500", ProgressionData.win_xp(10) == 500)

	_check("xp_to_next(L1) = 7", ProgressionData.xp_to_next(1) == 7)
	_check("xp_to_next(L5) = 163", ProgressionData.xp_to_next(5) == 163)
	_check("xp_to_next(L10) = 650", ProgressionData.xp_to_next(10) == 650)
	_check("xp_to_next(L15) = 1463", ProgressionData.xp_to_next(15) == 1463)
	_check("xp_to_next(L20) = 2600", ProgressionData.xp_to_next(20) == 2600)
	_check("xp_to_next(L99) = 0 (capped)", ProgressionData.xp_to_next(99) == 0)

	var base: Dictionary = ProgressionData.king_stats(1, 1)
	_check("king_stats(L1,★1) hp = 330", is_equal_approx(base["hp"], 330.0))
	_check("king_stats(L1,★1) attack = 28", is_equal_approx(base["attack"], 28.0))
	_check("king_stats(L1,★1) defense = 12", is_equal_approx(base["defense"], 12.0))
	_check("king_stats(L1,★1) stamina_max = 104", is_equal_approx(base["stamina_max"], 104.0))
	_check("king_stats(L1,★1) mana_max = 210", is_equal_approx(base["mana_max"], 210.0))

	var five_star: Dictionary = ProgressionData.king_stats(1, 5)
	_check("king_stats(L1,★5) hp = 435.6", is_equal_approx(five_star["hp"], 330.0 * 1.32))
	_check("king_stats(L1,★5) attack = 36.96", is_equal_approx(five_star["attack"], 28.0 * 1.32))

	var sm = root.get_node("/root/SaveManager")
	var save_backup := _backup_save()
	sm.heroes["gatotkaca"] = {"level": 1, "stars": 1, "xp": 5}
	sm.save_game()
	var xp_result: Dictionary = sm.add_king_xp(20)
	_check("add_king_xp returns dict levels_gained = 1", xp_result.get("levels_gained", -1) == 1)
	_check("add_king_xp result level = 2", xp_result.get("level", -1) == 2)
	_check("add_king_xp result xp = 18", xp_result.get("xp", -1) == 18)
	_check("add_king_xp result xp_to_next = 26", xp_result.get("xp_to_next", -1) == 26)
	var saved_hero: Dictionary = sm.heroes.get("gatotkaca", {})
	_check("add_king_xp persisted level 2", saved_hero.get("level", -1) == 2)
	_check("add_king_xp persisted xp 18", saved_hero.get("xp", -1) == 18)
	_restore_save(save_backup)

	if failures > 0:
		push_error("XP progression regression (%d failures)" % failures)
		quit(1)
		return
	print("XP_PROGRESSION_PASS")
	quit(0)


func _backup_save() -> Dictionary:
	var sm = root.get_node("/root/SaveManager")
	if not FileAccess.file_exists(sm.save_path):
		return {"exists": false}
	var f := FileAccess.open(sm.save_path, FileAccess.READ)
	var text: String = f.get_as_text()
	f.close()
	return {"exists": true, "data": text}


func _restore_save(backup: Dictionary) -> void:
	var sm = root.get_node("/root/SaveManager")
	if backup.get("exists", false):
		var f := FileAccess.open(sm.save_path, FileAccess.WRITE)
		f.store_string(backup["data"])
		f.close()
	else:
		DirAccess.remove_absolute(sm.save_path)
	sm.load_game()