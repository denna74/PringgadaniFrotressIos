extends SceneTree

# The gameplay bar shows four readouts: lives, stage, wave, wave timer.
#
# Lives used to live only in the hub, so a run told you nothing about how close you were
# to being out. The enemies readout went the other way -- it never earned its space, so
# it is gone rather than merely hidden.
#
# Where the readouts sit is hand-tuned layout (RunHUD's TOP_* constants) and is not
# asserted here; these checks pin that each readout builds, the life strip swaps slots to
# a skull when a life is spent, and that the enemies readout is really deleted.

var failures := 0
var _had_settings: bool = false
var _settings_backup: String = ""


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
	var sm = root.get_node("/root/SaveManager")
	var tm = root.get_node("/root/TranslationManager")
	var original_language: String = tm.current_language
	var save_backup := _backup_save()
	_backup_settings(tm)
	var lives_backup: int = sm.lives

	tm.set_language("en")
	var hud: CanvasLayer = CanvasLayer.new()
	hud.set_script(load("res://scenes/run/RunHUD.gd"))
	root.add_child(hud)
	await process_frame
	await process_frame

	# Give the two conditional labels something to identify them by.
	hud.update_wave(1, 5)
	hud.update_countdown(7)
	await process_frame

	var countdown := _find_label(hud, tm.t("wave_in")) as Label
	_check(
		"countdown above five uses normal color",
		countdown != null and countdown.get_theme_color("font_color").is_equal_approx(Color(0.25, 0.15, 0.08))
	)
	_check(
		"countdown above five stays normal size",
		countdown != null and countdown.scale.is_equal_approx(Vector2.ONE)
	)
	hud.update_countdown(5)
	_check(
		"countdown turns red at five",
		countdown != null and countdown.get_theme_color("font_color").is_equal_approx(Color(1.0, 0.1, 0.1))
	)
	_check(
		"countdown starts enlarged at five",
		countdown != null and countdown.scale.x > 1.2 and countdown.scale.y > 1.2
	)
	await create_timer(0.35).timeout
	_check(
		"countdown scales back to normal",
		countdown != null and countdown.scale.is_equal_approx(Vector2.ONE)
	)
	hud.update_countdown(4)
	_check(
		"next warning number pulses",
		countdown != null and countdown.scale.x > 1.2 and countdown.scale.y > 1.2
	)
	hud.update_countdown(-1)
	_check(
		"beat them all text is red",
		countdown != null and countdown.get_theme_color("font_color").is_equal_approx(Color(1.0, 0.1, 0.1))
	)
	_check(
		"beat them all text is bold",
		countdown != null and countdown.get_theme_font("font") is FontVariation
	)
	hud.update_countdown(0)
	_check(
		"combat countdown color resets",
		countdown != null and countdown.get_theme_color("font_color").is_equal_approx(Color(0.25, 0.15, 0.08))
	)
	_check(
		"countdown text is not bold",
		countdown != null and not (countdown.get_theme_font("font") is FontVariation)
	)
	hud.update_countdown(3)

	_check_readouts(hud)
	var guard_button := _find_by_name(hud, "GuardPendopoButton") as Button
	var gather_button := _find_by_name(hud, "GatherSoldiersButton") as Button
	_check("soldier command buttons are present",
		guard_button != null and gather_button != null)
	var commands := {"guard": 0, "gather": 0}
	hud.guard_pendopo_pressed.connect(func() -> void: commands["guard"] += 1)
	hud.gather_soldiers_pressed.connect(func() -> void: commands["gather"] += 1)
	guard_button.pressed.emit()
	gather_button.pressed.emit()
	_check("command buttons emit their army commands",
		commands["guard"] == 1 and commands["gather"] == 1)
	tm.set_language("id")
	await process_frame
	_check("Indonesian top bar life caption", _find_label(hud, "NYAWA ") != null)
	_check("Indonesian top bar stage caption", _find_label(hud, "Babak 0") != null)
	_check("Indonesian top bar wave caption", _find_label(hud, "Gelombang: 1 / 5") != null)
	_check("Indonesian HUD gold caption", _find_label(hud, "Emas") != null)
	_check("soldier command buttons are translated",
		guard_button != null and gather_button != null
			and guard_button.text == tm.t("soldier_command_pendopo")
			and gather_button.text == tm.t("soldier_command_gather"))
	tm.set_language(original_language)
	await process_frame
	await _check_life_strip(hud, sm)
	_check(
		"enemies readout deleted",
		not hud.has_method("update_enemy_count")
	)
	_check("no enemies text anywhere", not _any_label_contains(hud, "—"))

	sm.lives = lives_backup
	sm.lives_changed.emit(sm.lives)
	hud.queue_free()
	await process_frame

	_restore_save(save_backup)
	_restore_settings()

	if failures > 0:
		push_error("Run top bar regression (%d failures)" % failures)
		quit(1)
		return
	print("RUN_HUD_TOPBAR_PASS")
	quit(0)


func _check_readouts(hud: Node) -> void:
	var tm = root.get_node("/root/TranslationManager")
	var lives := _find_by_name(hud, "LivesIcons")
	_check("lives strip present", lives != null)

	var prefix := _find_by_name(hud, "LivesPrefix") as Label
	_check("lives caption translated", prefix != null and prefix.text == tm.t("hud_lives_prefix"))

	var stage := _find_label(hud, tm.t("hud_stage") % 0)
	var wave := _find_label(hud, tm.t("hud_wave") % [1, 5])
	var timer := _find_label(hud, tm.t("wave_in"))
	_check("stage shown translated", stage != null)
	_check("wave shown translated", wave != null)
	_check("wave timer shown", timer != null)


func _check_life_strip(hud: Node, sm: Node) -> void:
	sm.lives = sm.max_lives
	sm.lives_changed.emit(sm.lives)
	await process_frame
	await process_frame

	var slot := _find_by_name(hud, "LivesIcons")
	if slot == null:
		return

	var icons := slot.get_children()
	_check("one icon per life", icons.size() == sm.max_lives)

	var flames := 0
	for icon in icons:
		if icon is TextureRect and (icon.texture is AnimatedTexture):
			flames += 1
	_check("held lives burn in the run too", flames == sm.max_lives)

	# Losing a life mid-run has to swap that slot to the skull, same as the hub.
	sm.lives = sm.max_lives - 1
	sm.lives_changed.emit(sm.lives)
	await process_frame
	await process_frame

	var last := icons[icons.size() - 1] as TextureRect
	var path: String = last.texture.resource_path if last.texture != null else ""
	_check("spent life shows skull in the run", path.get_file() == "head-skull.png")
	_check("survivors still burn", icons[0] is TextureRect and icons[0].texture is AnimatedTexture)

	sm.lives = sm.max_lives
	sm.lives_changed.emit(sm.lives)
	await process_frame


func _find_by_name(node: Node, want: String) -> Node:
	if node.name == want:
		return node
	for child in node.get_children():
		var hit := _find_by_name(child, want)
		if hit != null:
			return hit
	return null


func _find_label(node: Node, prefix: String) -> Node:
	if node is Label and (node as Label).text.begins_with(prefix):
		return node
	for child in node.get_children():
		var hit := _find_label(child, prefix)
		if hit != null:
			return hit
	return null


func _any_label_contains(node: Node, needle: String) -> bool:
	if node is Label and (node as Label).text.contains(needle):
		return true
	for child in node.get_children():
		if _any_label_contains(child, needle):
			return true
	return false


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


func _backup_settings(tm: Node) -> void:
	_had_settings = FileAccess.file_exists(tm.SETTINGS_FILE)
	if _had_settings:
		var f := FileAccess.open(tm.SETTINGS_FILE, FileAccess.READ)
		_settings_backup = f.get_as_text()
		f.close()


func _restore_settings() -> void:
	var tm = root.get_node("/root/TranslationManager")
	if _had_settings:
		var f := FileAccess.open(tm.SETTINGS_FILE, FileAccess.WRITE)
		f.store_string(_settings_backup)
		f.close()
	else:
		DirAccess.remove_absolute(tm.SETTINGS_FILE)
