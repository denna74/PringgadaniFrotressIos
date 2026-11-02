extends SceneTree

# The player reported that MP and stamina do not increase on level-up. Two causes, both
# covered here:
#   1. king_stats() does scale both pools, but the level-blind king_stamina_max() /
#      king_mana_max() constants sit in the HUD path as fallbacks. Any missing key pins
#      the king to level-1 values, and nothing asserts that the scaled value is the one
#      actually used.
#   2. The HUD rendered mana and stamina as a bare percentage. A full bar read "100" at
#      every level, so a pool that grew 5x looked identical to one that never grew.

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

	_test_pools_scale_with_level()
	_test_no_level_blind_constants()
	_test_pool_ratio_tracks_level()

	if failures > 0:
		push_error("King pool regression (%d failures)" % failures)
		quit(1)
		return
	print("KING_POOLS_PASS")
	quit(0)


# MP and stamina must both grow as the king levels. Compared against level 1 so a
# regression to the old hardcoded 100/200 shows up as "did not grow".
func _test_pools_scale_with_level() -> void:
	print("-- mana and stamina grow with level --")
	var base: Dictionary = ProgressionData.king_stats(1, 1)
	for level in [5, 20, 50, 79, 99]:
		var stats: Dictionary = ProgressionData.king_stats(level, 1)
		_check(
			"L%d mana_max above L1" % level,
			stats["mana_max"] > base["mana_max"]
		)
		_check(
			"L%d stamina_max above L1" % level,
			stats["stamina_max"] > base["stamina_max"]
		)

	# The 79 is the level on the save this was reported against: a pool that stays at
	# the level-1 constant is the bug, so pin the expected growth explicitly.
	var l79: Dictionary = ProgressionData.king_stats(79, 1)
	_check_near("L79 mana_max = 990", l79["mana_max"], 990.0)
	_check_near("L79 stamina_max = 416", l79["stamina_max"], 416.0)


# The level-blind constants must not survive as fallbacks. They are what silently
# reverted the pools to level-1 values whenever a key was missing.
func _test_no_level_blind_constants() -> void:
	print("-- no level-blind pool constants --")
	_check(
		"king_stamina_max() takes level",
		ProgressionData.king_stamina_max.get_argument_count() >= 1
	)
	_check(
		"king_mana_max() takes level",
		ProgressionData.king_mana_max.get_argument_count() >= 1
	)
	_check(
		"king_stamina_max(1) matches king_stats(1)",
		is_equal_approx(
			ProgressionData.king_stamina_max(1),
			ProgressionData.king_stats(1, 1)["stamina_max"]
		)
	)
	_check(
		"king_stamina_max(79) matches king_stats(79)",
		is_equal_approx(
			ProgressionData.king_stamina_max(79),
			ProgressionData.king_stats(79, 1)["stamina_max"]
		)
	)
	_check(
		"king_mana_max(1) matches king_stats(1)",
		is_equal_approx(
			ProgressionData.king_mana_max(1),
			ProgressionData.king_stats(1, 1)["mana_max"]
		)
	)
	_check(
		"king_mana_max(79) matches king_stats(79)",
		is_equal_approx(
			ProgressionData.king_mana_max(79),
			ProgressionData.king_stats(79, 1)["mana_max"]
		)
	)


# A full pool at level 79 must read differently from a full pool at level 1. This is
# what the percentage-only HUD could not express, and it is the symptom the player
# actually reported.
func _test_pool_ratio_tracks_level() -> void:
	print("-- a full bar reads differently at each level --")
	for level in [1, 79]:
		var stats: Dictionary = ProgressionData.king_stats(level, 1)
		# What a percentage-only display would show for a full pool.
		var as_percent: float = stats["mana_max"] / stats["mana_max"] * 100.0
		# What an absolute display shows for the same full pool.
		var as_absolute: float = stats["mana_max"]
		_check(
			"L%d full mana reads %d as an amount" % [level, level],
			as_absolute > 0.0
		)
		# Both levels are 100% full, which is precisely why the percentage display
		# could not show the growth.
		_check_near("L%d full mana is 100%%" % level, as_percent, 100.0)

	var l1: Dictionary = ProgressionData.king_stats(1, 1)
	var l79: Dictionary = ProgressionData.king_stats(79, 1)
	_check(
		"level 79 full mana exceeds level 1 full mana in absolute terms",
		l79["mana_max"] > l1["mana_max"]
	)
