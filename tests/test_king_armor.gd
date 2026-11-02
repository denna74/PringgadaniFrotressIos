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

	_check("armor 0 leaves damage unchanged", is_equal_approx(ProgressionData.armor_damage(100.0, 0.0), 100.0))
	_check("defense 12 mitigates to 100*100/112", is_equal_approx(ProgressionData.armor_damage(100.0, 12.0), 100.0 * 100.0 / 112.0))
	_check("matches king_stats defense L1 (12)", is_equal_approx(ProgressionData.armor_damage(100.0, ProgressionData.king_stats(1, 1)["defense"]), 100.0 * 100.0 / 112.0))
	_check("never below 1 damage", ProgressionData.armor_damage(1.0, 10000.0) == 1.0)

	if failures > 0:
		push_error("King armor regression (%d failures)" % failures)
		quit(1)
		return
	print("KING_ARMOR_PASS")
	quit(0)