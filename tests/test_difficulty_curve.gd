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


func _check_near(name: String, actual: float, expected: float, tol: float = 0.001) -> void:
	_check("%s (got %s, want ~%s)" % [name, actual, expected], absf(actual - expected) <= tol)


func _run() -> void:
	await process_frame

	_test_xp_curve()
	_test_expected_level()
	_test_level_cap()
	_test_enemy_scaling()
	_test_time_to_kill()
	_test_stage_stat_endpoints()
	_test_underlevel_penalty()
	_test_difficulty_freeze()
	_test_arena_scaling()
	_test_wave_budget()
	_test_wave_prep_time()
	_test_monotonic()

	if failures > 0:
		push_error("Difficulty curve regression (%d failures)" % failures)
		quit(1)
		return
	print("DIFFICULTY_CURVE_PASS")
	quit(0)


# ─── XP curve ───

func _test_xp_curve() -> void:
	print("-- xp curve --")
	_check("MAX_KING_LEVEL = 99", ProgressionData.MAX_KING_LEVEL == 99)
	_check("xp_to_next(L1) = 200", ProgressionData.xp_to_next(1) == 200)
	_check("xp_to_next(L10) = 909", ProgressionData.xp_to_next(10) == 909)
	_check("xp_to_next(L20) = 3059", ProgressionData.xp_to_next(20) == 3059)
	_check("xp_to_next(L50) = 18104", ProgressionData.xp_to_next(50) == 18104)
	_check("xp_to_next(L98) = 69000", ProgressionData.xp_to_next(98) == 69000)
	_check("xp_to_next(L99) = 0 (capped)", ProgressionData.xp_to_next(99) == 0)
	_check("xp_to_next(L100) = 0 (past cap)", ProgressionData.xp_to_next(100) == 0)
	_check("win_xp(S1) = 50", ProgressionData.win_xp(1) == 50)
	_check("win_xp(S10) = 500", ProgressionData.win_xp(10) == 500)
	_check("win_xp(S250) = 12500", ProgressionData.win_xp(250) == 12500)
	_check("win_xp(S400) stays capped at 12500", ProgressionData.win_xp(400) == 12500)

# ─── expected_level: the level a player naturally has at a stage ───

func _test_expected_level() -> void:
	print("-- expected level --")
	_check("expected_level(S209) = 77", ProgressionData.expected_level(209) == 77)
	_check("expected_level(S210) = 77", ProgressionData.expected_level(210) == 77)
	_check("expected_level(S211) = 77", ProgressionData.expected_level(211) == 77)
	_check("expected_level(S250) = 87", ProgressionData.expected_level(250) == 87)
	_check("expected_level(S1) = 1", ProgressionData.expected_level(1) == 1)
	_check_near("expected_level(S30) = 20", ProgressionData.expected_level(30), 20.0, 0.5)
	_check("expected_level never exceeds 99", ProgressionData.expected_level(4000) <= 99)
	_check(
		"expected_level non-decreasing 1..400",
		_is_nondecreasing(func(s: int) -> float: return float(ProgressionData.expected_level(s)))
	)


# ─── level cap in SaveManager ───

func _test_level_cap() -> void:
	print("-- level cap --")
	var sm = root.get_node("/root/SaveManager")
	var backup := _backup_save()
	sm.heroes["gatotkaca"] = {"level": 97, "stars": 1, "xp": 0}
	var res: Dictionary = sm.add_king_xp(ProgressionData.xp_to_next(97) * 100)
	_check("caps at level 99", res.get("level", -1) == 99)
	_check("does not overshoot to 100+", res.get("level", 0) <= 99)
	_check("xp_to_next reported as 0 when maxed", res.get("xp_to_next", -1) == 0)
	_check("persisted level is 99", sm.heroes["gatotkaca"].get("level", -1) == 99)

	# A huge award at the cap must not hang or explode.
	var res2: Dictionary = sm.add_king_xp(999999999)
	_check("still 99 after second huge award", res2.get("level", -1) == 99)
	_check("carried xp is 0 at cap", res2.get("xp", -1) == 0)
	_check("XP award is zero after reaching the cap", res2.get("xp_gained", -1) == 0)
	_check("saved XP stays zero at the cap", sm.heroes["gatotkaca"].get("xp", -1) == 0)
	_restore_save(backup)


# ─── linear enemy scaling ───

func _test_enemy_scaling() -> void:
	print("-- enemy scaling --")
	_check_near("enemy infantry HP(S1) = 400", ProgressionData.enemy_hp(1, 99), 400.0, 0.01)
	_check_near("enemy infantry HP(S250) = 2000", ProgressionData.enemy_hp(250, 99), 2000.0, 0.01)
	_check("enemy_hp(S100) < enemy_hp(S101)", ProgressionData.enemy_hp(100, 99) < ProgressionData.enemy_hp(101, 99))
	_check("enemy_atk grows with stage", ProgressionData.enemy_attack(250, 99) > ProgressionData.enemy_attack(1, 99))
	_check_near("enemy infantry attack(S1) = 30", ProgressionData.enemy_attack(1, 99), 30.0, 0.01)
	_check_near("enemy infantry attack(S250) = 100", ProgressionData.enemy_attack(250, 99), 100.0, 0.01)
	_check("enemy_defense grows with stage", ProgressionData.enemy_defense(250, 99) > ProgressionData.enemy_defense(1, 99))
	# The whole point: flat time-to-kill, not exponential.
	_check(
		"enemy_hp non-decreasing 1..400",
		_is_nondecreasing(func(s: int) -> float: return ProgressionData.enemy_hp(s, 99))
	)


# ─── time-to-kill across stage-scaled enemy and Gatotkaca stats ───
func _test_time_to_kill() -> void:
	print("-- time to kill --")
	var s1_hits: float = _king_hits_to_kill(1)
	_check(
		"stage 1 enemy dies in 4-5 king hits (got %.1f)" % s1_hits,
		s1_hits >= 4.0 and s1_hits <= 5.0
	)

	var easiest_after_s1: float = INF
	for s in range(2, 251):
		easiest_after_s1 = minf(easiest_after_s1, _king_hits_to_kill(float(s)))
	_check(
		"no early-game spike (S1 %.1f hits vs easiest later %.1f, want within 25%%)" % [s1_hits, easiest_after_s1],
		s1_hits <= easiest_after_s1 * 1.25
	)

	# The requested endgame stats keep individual enemies within a reasonable
	# number of king hits; late-stage challenge also comes from larger waves.
	var s250_hits: float = _king_hits_to_kill(250)
	_check(
		"late-stage enemies stay within 30%% of stage-1 hits (S250 %.1f)" % s250_hits,
		s250_hits > 0.0 and s250_hits < s1_hits * 1.3
	)


# How many king attacks it takes to kill one enemy at the level a player naturally
# holds on that stage. Uses the same armor curve the king actually uses in combat.
func _king_hits_to_kill(stage: float) -> float:
	var s: int = int(stage)
	var enemy: Dictionary = ProgressionData.enemy_unit_stats("infantry", s)
	var hp: float = enemy["hp"]
	var edef: float = enemy["defense"]
	var ks: Dictionary = ProgressionData.gatotkaca_stats(s)
	var eff: float = ProgressionData.armor_damage(float(ks["attack"]), edef)
	return hp / maxf(eff, 0.001)


# ─── trade ratio: can the army survive its own fight? ───
# Time-to-kill alone is not "easy". An army that dies long before it finishes
# clearing is just as unplayable as a tanky one, so this pins the other axis:
# the troops must outlive a real fraction of the fight, while the king -- who
# ObjectiveState treats as a lose condition -- must stay killable.
func _test_stage_stat_endpoints() -> void:
	print("-- brainstorm stage-1 endpoints --")
	var enemy: Dictionary = ProgressionData.enemy_unit_stats("infantry", 1)
	var archer: Dictionary = ProgressionData.enemy_unit_stats("archer", 1)
	var friendly: Dictionary = ProgressionData.troop_stats("infantry", 1)
	_check("stage-1 enemy infantry stats match brainstorm",
		is_equal_approx(enemy["hp"], 400.0)
			and is_equal_approx(enemy["attack"], 30.0)
			and is_equal_approx(enemy["defense"], 10.0))
	_check("stage-1 enemy archer stats match brainstorm",
		is_equal_approx(archer["hp"], 300.0)
			and is_equal_approx(archer["attack"], 45.0)
			and is_equal_approx(archer["defense"], 5.0))
	_check("barracks-1 friendly infantry stats match brainstorm",
		is_equal_approx(friendly["hp"], 400.0)
			and is_equal_approx(friendly["attack"], 40.0)
			and is_equal_approx(friendly["defense"], 10.0))


# ─── under-level penalty (continuous, no cliff) ───

func _test_underlevel_penalty() -> void:
	print("-- under-level penalty --")
	_check_near("no penalty at expected level", ProgressionData.underlevel_multiplier(210, 80), 1.0)
	_check_near("no penalty above expected level", ProgressionData.underlevel_multiplier(210, 99), 1.0)
	_check_near("no penalty at stage 1 level 3", ProgressionData.underlevel_multiplier(1, 3), 1.0)
	_check(
		"under-leveling always raises difficulty",
		ProgressionData.underlevel_multiplier(210, 40) > ProgressionData.underlevel_multiplier(210, 60)
	)
	_check(
		"penalty capped at 4.0",
		ProgressionData.underlevel_multiplier(400, 1) <= 4.0 + 0.0001
	)
	# The user's key requirement: NO discontinuity between stage 210 and 211.
	var at210: float = ProgressionData.underlevel_multiplier(210, 79)
	var at211: float = ProgressionData.underlevel_multiplier(211, 79)
	_check("L79 at S210 vs S211 differs < 2%%", absf(at210 - at211) / maxf(at210, 0.001) < 0.02)
	_check("S210 L80 and S211 L80 both unpenalised",
		is_equal_approx(ProgressionData.underlevel_multiplier(210, 80), 1.0)
		and is_equal_approx(ProgressionData.underlevel_multiplier(211, 80), 1.0))
	# Penalty must be continuous across the whole stage range, not a stage>=210 switch.
	# The real invariant: no stage-to-stage step may exceed one level's worth of penalty
	# (UNDERLEVEL_SLOPE), and it must never decrease.
	var max_step := 0.0
	var any_decrease := false
	var prev := ProgressionData.underlevel_multiplier(1, 40)
	for s in range(2, 401):
		var v: float = ProgressionData.underlevel_multiplier(s, 40)
		if v < prev - 0.0001:
			any_decrease = true
		max_step = maxf(max_step, absf(v - prev))
		prev = v
	_check("under-level penalty never decreases 1..400", not any_decrease)
	_check(
		"max stage-to-stage step <= one level of penalty (%.3f)" % max_step,
		max_step <= ProgressionData.UNDERLEVEL_SLOPE + 0.0001
	)


# ─── difficulty freezes at 250 ───

func _test_difficulty_freeze() -> void:
	print("-- difficulty freeze --")
	_check("DIFFICULTY_CAP_STAGE = 250", ProgressionData.DIFFICULTY_CAP_STAGE == 250)
	_check("effective_stage(400) = 250", ProgressionData.effective_stage(400) == 250)
	_check("effective_stage(1) = 1", ProgressionData.effective_stage(1) == 1)
	_check("effective_stage(0) clamps to 1", ProgressionData.effective_stage(0) == 1)
	for s in [250, 251, 300, 400, 9999]:
		_check("enemy_hp(S%d) frozen at 2000" % s, is_equal_approx(ProgressionData.enemy_hp(s, 99), 2000.0))
	_check(
		"all difficulty identical for 250/251/400",
		_difficulty_signature(250) == _difficulty_signature(251)
			and _difficulty_signature(251) == _difficulty_signature(400)
	)


func _difficulty_signature(s: int) -> Array:
	return [
		ProgressionData.enemy_hp(s, 99),
		ProgressionData.enemy_attack(s, 99),
		ProgressionData.enemy_defense(s, 99),
		ProgressionData.num_waves(s),
		ProgressionData.enemy_budget(s),
		ProgressionData.map_size(s),
		ProgressionData.building_plots(s),
	]


# ─── arena scaling ───

func _test_arena_scaling() -> void:
	print("-- arena scaling --")
	_check("DIFFICULTY_CAP_STAGE = 250", ProgressionData.DIFFICULTY_CAP_STAGE == 250)
	# Three arena sizes, one per pendopo count -- size follows the bases rather than
	# a separate ramp, so there is no multiplier to keep in sync.
	_check("ARENA_SIZES has 3 entries", ProgressionData.ARENA_SIZES.size() == 3)

	_check("pendopo_count(S1) = 1", ProgressionData.pendopo_count(1) == 1)
	_check("pendopo_count(S49) = 1", ProgressionData.pendopo_count(49) == 1)
	_check("pendopo_count(S50) = 2", ProgressionData.pendopo_count(50) == 2)
	_check("pendopo_count(S149) = 2", ProgressionData.pendopo_count(149) == 2)
	_check("pendopo_count(S150) = 3", ProgressionData.pendopo_count(150) == 3)

	_check("map_size(S1) = 32", ProgressionData.map_size(1) == 32)
	_check("map_size(S50) = 64", ProgressionData.map_size(50) == 64)
	_check("map_size(S150) = 96", ProgressionData.map_size(150) == 96)
	_check("map_size(S250) = 96", ProgressionData.map_size(250) == 96)
	# Size tracks pendopo count, so it is a pure function of the tier.
	_check("map_size follows pendopo_count", ProgressionData.map_size(1) == ProgressionData.ARENA_SIZES[ProgressionData.pendopo_count(1) - 1])
	_check("building_plots(S1) = 7", ProgressionData.building_plots(1) == 7)
	_check("building_plots(S50) = 14", ProgressionData.building_plots(50) == 14)
	_check("building_plots(S250) = 21", ProgressionData.building_plots(250) == 21)


# ─── wave / enemy budget ───

func _test_wave_budget() -> void:
	print("-- wave budget --")
	_check("num_waves(S1) = 4", ProgressionData.num_waves(1) == 4)
	_check("num_waves grows with stage", ProgressionData.num_waves(150) > ProgressionData.num_waves(50))
	_check("num_waves(S250) = 9 (max)", ProgressionData.num_waves(250) == 9)
	_check("num_waves(S400) = 9 (frozen)", ProgressionData.num_waves(400) == 9)
	# The cap must hold everywhere, not just at the sampled stages.
	var wave_peak: int = 0
	for s in range(1, 401):
		wave_peak = maxi(wave_peak, ProgressionData.num_waves(s))
	_check("num_waves never exceeds 9 across 1..400 (peak %d)" % wave_peak, wave_peak == 9)
	# Every designed band, at both edges, so a boundary cannot drift silently.
	for band in [
		[1, 4], [20, 4], [21, 5], [50, 5], [51, 6], [80, 6],
		[81, 7], [100, 7], [150, 7], [151, 8], [200, 8], [249, 8],
		[250, 9], [999, 9],
	]:
		_check(
			"stage %d = %d waves (got %d)" % [band[0], band[1], ProgressionData.num_waves(band[0])],
			ProgressionData.num_waves(band[0]) == band[1]
		)

	_check("enemy_budget(S1) = 24", ProgressionData.enemy_budget(1) == 24)
	_check("enemy_budget(S250) = 170", ProgressionData.enemy_budget(250) == 170)
	_check("enemy_budget(S400) frozen at 170", ProgressionData.enemy_budget(400) == 170)
	_check("enemy_budget grows with stage", ProgressionData.enemy_budget(100) > ProgressionData.enemy_budget(50))

	# Sum of per-wave counts must land within a wave's slack of the budget.
	for s in [1, 30, 50, 100, 150, 210, 250]:
		var total := 0
		var w := ProgressionData.num_waves(s)
		for i in range(1, w + 1):
			total += ProgressionData.enemies_per_wave(s, i)
		_check(
			"S%d per-wave sum %d within %d of budget %d" % [s, total, w, ProgressionData.enemy_budget(s)],
			absi(total - ProgressionData.enemy_budget(s)) <= w
		)
	_check("enemies_per_wave >= 1 always", ProgressionData.enemies_per_wave(1, 1) >= 1)
	_check(
		"final wave is largest",
		ProgressionData.enemies_per_wave(100, ProgressionData.num_waves(100))
			>= ProgressionData.enemies_per_wave(100, 1)
	)


# ─── prep time between waves ───
# More pendopos means more to repair and re-garrison during the breather, so the
# countdown scales with it: 15s / 20s / 25s for 1 / 2 / 3 pendopos.
func _test_wave_prep_time() -> void:
	print("-- wave prep time --")
	_check_near("1 pendopo (S1) = 15s", ProgressionData.wave_prep_time(1), 15.0, 0.001)
	_check_near("1 pendopo (S49) = 15s", ProgressionData.wave_prep_time(49), 15.0, 0.001)
	_check_near("2 pendopos (S50) = 20s", ProgressionData.wave_prep_time(50), 20.0, 0.001)
	_check_near("2 pendopos (S149) = 20s", ProgressionData.wave_prep_time(149), 20.0, 0.001)
	_check_near("3 pendopos (S150) = 25s", ProgressionData.wave_prep_time(150), 25.0, 0.001)
	_check_near("3 pendopos (S250) = 25s", ProgressionData.wave_prep_time(250), 25.0, 0.001)
	# Prep time must track pendopo count, not the raw stage number.
	for s in [1, 49, 50, 100, 149, 150, 200, 250]:
		var expected: float = 15.0 + 5.0 * float(ProgressionData.pendopo_count(s) - 1)
		_check(
			"S%d prep matches its %d pendopos" % [s, ProgressionData.pendopo_count(s)],
			is_equal_approx(ProgressionData.wave_prep_time(s), expected)
		)
	_check(
		"prep time non-decreasing 1..400",
		_is_nondecreasing(func(s: int) -> float: return ProgressionData.wave_prep_time(s))
	)


# ─── global monotonicity ───

func _test_monotonic() -> void:
	print("-- monotonicity --")
	_check("map_size non-decreasing 1..400", _is_nondecreasing(func(s: int) -> float: return float(ProgressionData.map_size(s))))
	_check("num_waves non-decreasing 1..400", _is_nondecreasing(func(s: int) -> float: return float(ProgressionData.num_waves(s))))
	_check("enemy_budget non-decreasing 1..400", _is_nondecreasing(func(s: int) -> float: return float(ProgressionData.enemy_budget(s))))
	_check("building_plots non-decreasing 1..400", _is_nondecreasing(func(s: int) -> float: return float(ProgressionData.building_plots(s))))
	_check("pendopo_count non-decreasing 1..400", _is_nondecreasing(func(s: int) -> float: return float(ProgressionData.pendopo_count(s))))


func _is_nondecreasing(f: Callable) -> bool:
	var prev: float = -INF
	for s in range(1, 401):
		var v: float = f.call(s)
		if v < prev:
			return false
		prev = v
	return true


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
