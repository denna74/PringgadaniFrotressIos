extends SceneTree

var _had_save: bool = false
var _save_backup: String = ""


func _initialize() -> void:
	_run()


func _finish(code: int) -> void:
	var sm = root.get_node("/root/SaveManager")
	if _had_save:
		var f := FileAccess.open(sm.save_path, FileAccess.WRITE)
		f.store_string(_save_backup)
		f.close()
	else:
		DirAccess.remove_absolute(sm.save_path)
	quit(code)


func _run() -> void:
	await process_frame

	var sm = root.get_node("/root/SaveManager")
	_had_save = FileAccess.file_exists(sm.save_path)
	if _had_save:
		var cf := FileAccess.open(sm.save_path, FileAccess.READ)
		_save_backup = cf.get_as_text()
		cf.close()
	sm.gold = 500

	var run_ctl: Node3D = load("res://scenes/run/RunController.tscn").instantiate()
	root.add_child(run_ctl)

	# Level boot takes ~5.3 s of real work (model prewarm, map gen, navmesh).
	for i in 600:
		await process_frame
		if run_ctl._king_controller != null:
			break

	if run_ctl._king_controller == null:
		print("FAIL: king never placed")
		_finish(1)
		return

	await process_frame

	var hud = run_ctl.hud_ui
	var bar: ProgressBar = hud.get("_mana_bar")
	var num: Label = hud.get("_mana_num")
	var king = run_ctl._king_controller

	print("mana bar value=", bar.value, " max=", bar.max_value,
		" modulate=", bar.modulate,
		" num=", num.text,
		" king_mana=", king.get_mana_percent())

	if king.get_mana_percent() < 0.99:
		print("FAIL: MP not full on boot")
		_finish(1)
		return
	# The bar is scaled to the king's real pool, not a fixed 100, and the label shows the
	# absolute amount. A percentage-only bar read "100" at every level, which is why a
	# levelled king's MP looked like it never grew.
	if not is_equal_approx(bar.max_value, king.mana_max):
		print("FAIL: MP bar max %f is not the king's pool %f" % [bar.max_value, king.mana_max])
		_finish(1)
		return
	if bar.value < bar.max_value - 0.5:
		print("FAIL: MP bar not showing full on boot")
		_finish(1)
		return
	var expected_num: String = "%d/%d" % [ceili(king.mana), ceili(king.mana_max)]
	if num.text != expected_num:
		print("FAIL: MP label %s, want %s" % [num.text, expected_num])
		_finish(1)
		return
	if bar.modulate != Color.WHITE:
		print("FAIL: MP bar modulate is dimmed on boot")
		_finish(1)
		return

	# Stamina scales with level on the same footing as MP, so the same guarantee applies.
	var sta_bar: ProgressBar = hud.get("_stamina_bar")
	var sta_num: Label = hud.get("_stamina_num")
	if sta_bar != null:
		if not is_equal_approx(sta_bar.max_value, king.stamina_max):
			print("FAIL: stamina bar max %f is not the king's pool %f" % [sta_bar.max_value, king.stamina_max])
			_finish(1)
			return
		var expected_sta: String = "%d/%d" % [ceili(king.stamina), ceili(king.stamina_max)]
		if sta_num != null and sta_num.text != expected_sta:
			print("FAIL: stamina label %s, want %s" % [sta_num.text, expected_sta])
			_finish(1)
			return

	# The pools must come from the saved level, not a level-blind constant.
	var expected_mana: float = ProgressionData.king_stats(king_level_from_save(), 1)["mana_max"]
	if not is_equal_approx(king.mana_max, expected_mana):
		print("FAIL: mana_max %f does not match the saved level's pool %f" % [king.mana_max, expected_mana])
		_finish(1)
		return

	print("MANA_INIT_PASS")
	_finish(0)


func king_level_from_save() -> int:
	var sm = root.get_node("/root/SaveManager")
	var gk: Dictionary = sm.heroes.get("gatotkaca", {}) as Dictionary
	return gk.get("level", 1)
