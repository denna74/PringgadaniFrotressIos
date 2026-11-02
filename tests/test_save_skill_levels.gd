extends SceneTree

var _fails: int = 0
var _sig_id: String = ""
var _sig_level: int = 0


func _initialize() -> void:
	_run()


func _check(name: String, ok: bool) -> void:
	if ok:
		print("OK  ", name)
	else:
		_fails += 1
		print("CHECK FAIL: " + name)


func _on_skill_changed(id: String, level: int) -> void:
	_sig_id = id
	_sig_level = level


func _run() -> void:
	await process_frame
	var sm = root.get_node("/root/SaveManager")

	_check("default dash 1", sm.get_skill_level("dash") == 1)
	_check("default quake 1", sm.get_skill_level("earthquake") == 1)
	_check("default berserk 1", sm.get_skill_level("berserk") == 1)
	_check("unknown id reads 1", sm.get_skill_level("mystery") == 1)

	sm.gold = 1000
	_check("upgrade returns true", sm.upgrade_skill("dash"))
	_check("gold deducted exactly", sm.gold == 700)
	_check("level now 2", sm.get_skill_level("dash") == 2)

	sm.gold = 0
	_check("no gold fails", not sm.upgrade_skill("dash"))
	_check("no gold spends nothing", sm.gold == 0)
	_check("no gold keeps level", sm.get_skill_level("dash") == 2)

	sm.gold = 100000
	_check("unknown id fails", not sm.upgrade_skill("nope"))
	_check("unknown id spends nothing", sm.gold == 100000)

	# Exact-cost boundary: dash L2->L3 costs 600.
	sm.gold = 600
	_check("exact gold succeeds", sm.upgrade_skill("dash"))
	_check("exact gold leaves 0", sm.gold == 0)
	_check("level now 3", sm.get_skill_level("dash") == 3)

	sm.gold = 599
	_check("one short fails", not sm.upgrade_skill("dash"))
	_check("one short spends nothing", sm.gold == 599)

	sm.gold = 1000000000
	for i in 20:
		sm.upgrade_skill("dash")
	_check("caps at max 6", sm.get_skill_level("dash") == SkillData.MAX_LEVEL)

	var gold_before_quake: int = sm.gold
	sm.skill_level_changed.connect(_on_skill_changed)
	sm.upgrade_skill("earthquake")
	_check("signal id", _sig_id == "earthquake")
	_check("signal level 2", _sig_level == 2)
	_check("signal gold spent", sm.gold == gold_before_quake - SkillData.upgrade_cost("earthquake", 1))

	# Round-trips through the save file.
	sm.skill_levels["berserk"] = 4
	sm.save_game()
	sm.skill_levels = {"dash": 1, "earthquake": 1, "berserk": 1}
	sm.load_game()
	_check("berserk persisted", sm.get_skill_level("berserk") == 4)
	_check("dash persisted", sm.get_skill_level("dash") == SkillData.MAX_LEVEL)

	# Old save with no skill_levels key falls back to all level 1.
	var path: String = sm.save_path
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string('{"gold": 1234, "lives": 3}')
	f.close()
	sm.skill_levels = {"dash": 5, "earthquake": 5, "berserk": 5}
	sm.load_game()
	_check("missing key dash 1", sm.get_skill_level("dash") == 1)
	_check("missing key berserk 1", sm.get_skill_level("berserk") == 1)

	# A corrupted save clamps out-of-range levels on load.
	var f2 := FileAccess.open(path, FileAccess.WRITE)
	f2.store_string('{"gold": 0, "skill_levels": {"dash": 0, "earthquake": -4, "berserk": 99}}')
	f2.close()
	sm.skill_levels = {"dash": 1, "earthquake": 1, "berserk": 1}
	sm.load_game()
	_check("corrupt dash clamps to 1", sm.get_skill_level("dash") == 1)
	_check("corrupt quake clamps to 1", sm.get_skill_level("earthquake") == 1)
	_check("corrupt berserk clamps to max", sm.get_skill_level("berserk") == SkillData.MAX_LEVEL)

	if _fails == 0:
		print("SAVE_SKILL_LEVELS_PASS")
		quit(0)
	else:
		print("SAVE_SKILL_LEVELS_FAIL: %d" % _fails)
		quit(1)
