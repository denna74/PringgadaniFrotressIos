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

	_check("L1 dash damage 0.30", is_equal_approx(SkillData.dash_damage_mult(1), 0.30))
	_check("L1 dash speed 3.5", is_equal_approx(SkillData.dash_speed_mult(1), 3.5))
	_check("L1 quake damage 2.0", is_equal_approx(SkillData.quake_damage_mult(1), 2.0))
	_check("L1 quake mp 40", is_equal_approx(SkillData.quake_mp_cost(1), 40.0))
	_check("L1 berserk atk 1.5", is_equal_approx(SkillData.berserk_attack_mult(1), 1.5))
	_check("L1 berserk def 1.5", is_equal_approx(SkillData.berserk_defense_mult(1), 1.5))
	_check("L1 berserk drain 2.0", is_equal_approx(SkillData.berserk_drain_per_sec(1), 2.0))

	_check("L6 dash damage 0.70", is_equal_approx(SkillData.dash_damage_mult(6), 0.70))
	_check("L6 quake damage 4.0", is_equal_approx(SkillData.quake_damage_mult(6), 4.0))
	_check("L6 quake mp 25", is_equal_approx(SkillData.quake_mp_cost(6), 25.0))
	_check("L6 berserk atk 2.0", is_equal_approx(SkillData.berserk_attack_mult(6), 2.0))
	_check("L6 berserk drain 2.0", is_equal_approx(SkillData.berserk_drain_per_sec(6), 2.0))

	_check("level 0 clamps to L1",
		is_equal_approx(SkillData.dash_damage_mult(0), SkillData.dash_damage_mult(1)))
	_check("negative level clamps to L1",
		is_equal_approx(SkillData.quake_mp_cost(-3), SkillData.quake_mp_cost(1)))
	_check("level 99 clamps to L6",
		is_equal_approx(SkillData.berserk_attack_mult(99), SkillData.berserk_attack_mult(6)))

	_check("dash damage rises",
		SkillData.DASH_DAMAGE == [0.30, 0.38, 0.46, 0.54, 0.62, 0.70])
	_check("berserk drain stays constant",
		SkillData.BERSERK_DRAIN == [2.0, 2.0, 2.0, 2.0, 2.0, 2.0])

	_check("ids complete",
		SkillData.IDS.size() == 3 and SkillData.IDS.has("dash")
		and SkillData.IDS.has("earthquake") and SkillData.IDS.has("berserk"))

	_check("cost 0 at max", SkillData.upgrade_cost("dash", 6) == 0)
	_check("cost 0 past max", SkillData.upgrade_cost("dash", 9) == 0)
	_check("dash upgrade prices", SkillData.UPGRADE_COSTS["dash"] == [3000, 6000, 10000, 14000, 20000])
	_check("earthquake upgrade prices",
		SkillData.UPGRADE_COSTS["earthquake"] == [5000, 8000, 12000, 16000, 22000])
	_check("berserk upgrade prices",
		SkillData.UPGRADE_COSTS["berserk"] == [6000, 10000, 14000, 18000, 24000])
	_check("unknown id costs 0", SkillData.upgrade_cost("nope", 1) == 0)

	_check("dash icon lv1", SkillData.icon_path("dash", 1) == "res://assets/buttons/dash.png")
	_check("dash icon lv3", SkillData.icon_path("dash", 3) == "res://assets/buttons/dash.png")
	_check("dash icon lv4", SkillData.icon_path("dash", 4) == "res://assets/buttons/dash_2.png")
	_check("dash icon lv6", SkillData.icon_path("dash", 6) == "res://assets/buttons/dash_2.png")
	_check("quake icon lv1",
		SkillData.icon_path("earthquake", 1) == "res://assets/buttons/skill_earth_quake.png")
	_check("quake icon lv4",
		SkillData.icon_path("earthquake", 4) == "res://assets/buttons/earthquake_2.png")
	_check("berserk icon lv3",
		SkillData.icon_path("berserk", 3) == "res://assets/buttons/berserk.png")
	_check("berserk icon lv5",
		SkillData.icon_path("berserk", 5) == "res://assets/buttons/berserk_2.png")

	_check("dash name lv1", SkillData.display_name_key("dash", 1) == "skill_dash_t1")
	_check("dash name lv3", SkillData.display_name_key("dash", 3) == "skill_dash_t1")
	_check("dash name lv4", SkillData.display_name_key("dash", 4) == "skill_dash_t2")
	_check("dash name lv6", SkillData.display_name_key("dash", 6) == "skill_dash_t2")
	_check("quake name lv2", SkillData.display_name_key("earthquake", 2) == "skill_earthquake_t1")
	_check("quake name lv6", SkillData.display_name_key("earthquake", 6) == "skill_earthquake_t2")
	_check("berserk name lv1", SkillData.display_name_key("berserk", 1) == "skill_berserk_t1")
	_check("berserk name lv5", SkillData.display_name_key("berserk", 5) == "skill_berserk_t2")

	_check("display level 1", SkillData.display_level(1) == 1)
	_check("display level 3", SkillData.display_level(3) == 3)
	_check("display level 4 resets to 1", SkillData.display_level(4) == 1)
	_check("display level 6 resets to 3", SkillData.display_level(6) == 3)
	_check("display level clamps high", SkillData.display_level(99) == 3)

	if _fails == 0:
		print("SKILL_DATA_PASS")
		quit(0)
	else:
		print("SKILL_DATA_FAIL: %d" % _fails)
		quit(1)
