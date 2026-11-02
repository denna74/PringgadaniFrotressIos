extends SceneTree

# Pins the two instant buttons on the hub top bar: they exist, sit inside the
# gaps between their neighbouring readouts (measured at runtime), keep the
# art's 216x71 aspect, carry the localized overlay label clear of the icon,
# and the life button greys out at full lives.

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
	var track: Control = load("res://scenes/hub/LevelTrack.tscn").instantiate()
	root.add_child(track)
	await process_frame
	await process_frame

	var top: Control = track.get_node_or_null("TopBar")
	_check("top bar present", top != null)
	if top == null:
		quit(1)
		return

	var life_btn := top.get_node_or_null("InstantLifeBtn") as TextureButton
	var gold_btn := top.get_node_or_null("InstantGoldBtn") as TextureButton
	_check("life button present", life_btn != null)
	_check("gold button present", gold_btn != null)
	if life_btn == null or gold_btn == null:
		quit(1)
		return

	_check("life art loaded", life_btn.texture_normal != null)
	_check("gold art loaded", gold_btn.texture_normal != null)
	_check("life button sized", life_btn.size == Vector2(170, 76))
	_check("gold button sized", gold_btn.size == Vector2(170, 76))
	_check("gold button matches life size", gold_btn.size.is_equal_approx(life_btn.size))

	var icons := top.get_node_or_null("LivesIcons") as Control
	var gold_row := top.get_node_or_null("GoldRow") as Control
	_check("stage indicator removed from top bar",
		top.get_node_or_null("StageRow") == null)
	_check("neighbouring readouts present",
		icons != null and gold_row != null)
	if icons != null and gold_row != null:
		var icons_right: float = icons.position.x + icons.size.x
		var gold_right: float = gold_row.position.x + gold_row.size.x
		_check("life button after lives icons", life_btn.position.x >= icons_right)
		_check("life button before gold row",
			life_btn.position.x + life_btn.size.x <= gold_row.position.x + 1.0)
		_check("gold button after gold row", gold_btn.position.x >= gold_right - 1.0)

	var tm = root.get_node("/root/TranslationManager")
	var life_lbl := life_btn.get_node_or_null("BtnLabel") as Label
	var gold_lbl := gold_btn.get_node_or_null("BtnLabel") as Label
	_check("life label present", life_lbl != null)
	_check("gold label present", gold_lbl != null)
	if life_lbl != null and gold_lbl != null:
		_check("life label matches translation",
			life_lbl.text == tm.t("instant_life_label"))
		_check("gold label matches translation",
			gold_lbl.text == tm.t("instant_gold_label"))
		_check("label clears the icon area", life_lbl.anchor_left >= 80.0 / 216.0 - 0.001)
		_check("labels ignore the pointer", life_lbl.mouse_filter == Control.MOUSE_FILTER_IGNORE)
		_check("life label wraps to two lines",
			life_lbl.autowrap_mode != TextServer.AUTOWRAP_OFF and life_lbl.get_line_count() == 2)
		_check("gold label wraps to two lines",
			gold_lbl.autowrap_mode != TextServer.AUTOWRAP_OFF and gold_lbl.get_line_count() == 2)

		var orig_lang: String = tm.current_language
		tm.switch_language()
		await process_frame
		_check("life label follows language switch",
			life_lbl.text == tm.t("instant_life_label"))
		_check("gold label follows language switch",
			gold_lbl.text == tm.t("instant_gold_label"))
		if tm.current_language != orig_lang:
			tm.set_language(orig_lang)
			await process_frame
		_check("labels restored", gold_lbl.text == tm.t("instant_gold_label"))

	var sm = root.get_node("/root/SaveManager")
	_check("life button disabled at full lives", life_btn.disabled)
	sm.lose_life()
	await process_frame
	_check("life button enabled below max", not life_btn.disabled)
	sm.refill_life()
	await process_frame
	_check("life button re-disabled after refill", life_btn.disabled)

	track.queue_free()
	await process_frame
	if failures > 0:
		push_error("instant top bar regression")
		quit(1)
	else:
		print("INSTANT_TOPBAR_PASS")
		quit(0)
