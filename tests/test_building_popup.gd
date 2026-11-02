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


func _find_button(parent: Node, text: String) -> Button:
	for child in parent.get_children():
		if child is Button and (child as Button).text == text:
			return child
	return null


func _make_click() -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	return ev


func _make_plot():
	var plot = load("res://scenes/run/BuildingPlot.tscn").instantiate()
	root.add_child(plot)
	return plot


func _make_building_data() -> Dictionary:
	return {
		"id": "barak",
		"name_en": "Barak",
		"type": "military",
		"max_level": 15,
		"base_cost_gold": 40,
		"gold_per_day": 0,
		"grid_size": {"w": 3, "h": 3},
	}


func _run() -> void:
	await process_frame
	var tm = root.get_node("/root/TranslationManager")
	var original_language: String = tm.current_language
	tm.set_language("en")

	await _test_plot_touch_area_size()
	await _test_build_menu_centered_and_closeable()
	await _test_build_menu_warmup()
	await _test_build_menu_localization()
	await _test_build_menu_close_button()
	await _test_blocking_other_plots()
	await _test_building_overlay_close_and_center()
	await _test_tower_and_gold_mine_overlays_disabled()
	await _test_barak_overlay_close()
	await _test_controller_close_all_popups()
	tm.set_language(original_language)

	if failures > 0:
		push_error("Building popup regression")
		quit(1)
	else:
		print("BUILDING_POPUP_PASS")
		quit(0)


func _test_plot_touch_area_size() -> void:
	var plot = _make_plot()
	await process_frame
	var shape_node: CollisionShape3D = plot.get_node("CollisionShape3D")
	var box: BoxShape3D = shape_node.shape
	_check("plot touch area is 1.5x1.5 tiles", box.size.x == 1.5 and box.size.z == 1.5)
	_check("plot touch area keeps its height", box.size.y == 1.5)
	var highlight_box: BoxMesh = plot._highlight.mesh
	_check("green highlight is 1.5x1.5 tiles", highlight_box.size.x == 1.5 and highlight_box.size.z == 1.5)
	plot.queue_free()
	await process_frame


func _test_build_menu_centered_and_closeable() -> void:
	var plot = _make_plot()
	await process_frame

	plot._show_build_popup()
	var vp: Vector2 = root.get_visible_rect().size
	var expected: Vector2 = vp / 2 - plot._popup.size / 2
	_check("build menu centered", plot._popup.position.distance_to(expected) < 0.5)
	_check("build menu sized 360x500", plot._popup.size == Vector2(360, 500))
	_check("counter open after show", BuildingUIState.is_popup_open())

	plot._close_popup()
	_check("counter closed after close", not BuildingUIState.is_popup_open())

	plot.queue_free()
	await process_frame


func _test_build_menu_close_button() -> void:
	var plot = _make_plot()
	await process_frame

	plot._show_build_popup()
	var tm = root.get_node("/root/TranslationManager")
	var close_btn: Button = _find_button(plot._popup, tm.t("close"))
	_check("close button present on build menu", close_btn != null)
	if close_btn:
		close_btn.pressed.emit()
	_check("close button closes build menu", plot._popup == null)
	_check("counter drained by close button", not BuildingUIState.is_popup_open())

	plot.queue_free()
	await process_frame


func _test_build_menu_warmup() -> void:
	var plot = _make_plot()
	await process_frame

	var popup_count: int = BuildingUIState.popup_open_count
	await GameplayWarmup.warm_build_popup(plot)
	_check("warmup leaves build menu closed", plot._popup == null and plot._popup_layer == null)
	_check("warmup does not change popup state", BuildingUIState.popup_open_count == popup_count)

	plot.queue_free()
	await process_frame


func _test_build_menu_localization() -> void:
	var tm = root.get_node("/root/TranslationManager")
	var original_language: String = tm.current_language
	var plot = _make_plot()
	await process_frame

	for language in ["en", "id"]:
		tm.set_language(language)
		plot._show_build_popup()
		var title: Label = plot._popup.get_node("PopupTitle")
		var mine_name: Label = plot._popup.get_node("BuildingName_tambang_emas")
		var tower_name: Label = plot._popup.get_node("BuildingName_menara")
		var barracks_name: Label = plot._popup.get_node("BuildingName_barak")
		var close_btn: Button = _find_button(plot._popup, tm.t("close"))
		_check("%s build title is translated" % language, title.text == tm.t("build_menu_title"))
		_check(
			"%s building names use one language" % language,
			mine_name.text == ("Gold Mine" if language == "en" else "Tambang Emas")
			and tower_name.text == ("Tower" if language == "en" else "Menara")
			and barracks_name.text == ("Barracks" if language == "en" else "Barak")
		)
		_check("%s build close button is translated" % language, close_btn != null)
		plot._close_popup()

	tm.set_language(original_language)
	plot.queue_free()
	await process_frame


func _test_blocking_other_plots() -> void:
	var plot_a = _make_plot()
	var plot_b = _make_plot()
	await process_frame

	plot_a._show_build_popup()
	var open_count: int = BuildingUIState.popup_open_count
	var ev := _make_click()

	plot_b._on_input_event(null, ev, Vector3.ZERO, Vector3.UP, 0)
	_check("other plot blocked: no highlight", plot_b._highlight == null or not plot_b._highlight.visible)
	_check("other plot blocked: no popup", plot_b._popup == null)
	_check("counter unchanged by blocked click", BuildingUIState.popup_open_count == open_count)

	plot_a._on_input_event(null, ev, Vector3.ZERO, Vector3.UP, 0)
	_check("owner click closes build menu", plot_a._popup == null)
	_check("counter drained after owner click", not BuildingUIState.is_popup_open())

	plot_b._on_input_event(null, ev, Vector3.ZERO, Vector3.UP, 0)
	_check("popup opens on other plot after close", plot_b._popup != null and BuildingUIState.is_popup_open())

	if plot_b._popup != null:
		plot_b._close_popup()
	plot_a.queue_free()
	plot_b.queue_free()
	await process_frame


func _test_building_overlay_close_and_center() -> void:
	var BuildingScript: GDScript = load("res://scenes/buildings/Building.gd")
	var bld = BuildingScript.new(_make_building_data(), null)
	root.add_child(bld)
	await process_frame

	_check("has_overlay_open false initially", bld.has_overlay_open() == false)

	bld.show_overlay()
	await process_frame
	_check("counter open after show_overlay", BuildingUIState.is_popup_open())
	_check("has_overlay_open true after show", bld.has_overlay_open())
	var vp: Vector2 = root.get_visible_rect().size
	_check("overlay centered", bld._overlay.position.distance_to(vp / 2 - bld._overlay.size / 2) < 0.5)

	var close_btn: Button = bld._overlay.get_node("CloseBtn")
	_check("close button present on building overlay", close_btn != null)
	_check("in-run building upgrade button removed", bld._overlay.get_node_or_null("UpgradeBtn") == null)
	if close_btn:
		close_btn.pressed.emit()
	_check("close button hides overlay", bld.has_overlay_open() == false)
	_check("counter drained after overlay close", not BuildingUIState.is_popup_open())

	bld.show_overlay()
	_check("counter reopens on show_overlay", BuildingUIState.is_popup_open())
	bld.hide_overlay()
	_check("counter drains on hide_overlay", not BuildingUIState.is_popup_open())
	_check("has_overlay_open false after hide", bld.has_overlay_open() == false)

	bld.queue_free()
	await process_frame


func _test_tower_and_gold_mine_overlays_disabled() -> void:
	var tower_script: GDScript = load("res://scenes/buildings/Tower.gd")
	var data := _make_building_data()
	data["id"] = "menara"
	var tower = tower_script.new(data, null)
	root.add_child(tower)
	await process_frame

	tower.show_overlay()
	tower.toggle_overlay()
	_check("tower popup stays disabled", not tower.has_overlay_open())
	_check("tower does not open the popup counter", not BuildingUIState.is_popup_open())
	tower.queue_free()

	var mine_script: GDScript = load("res://scenes/buildings/TambangEmas.gd")
	data["id"] = "tambang_emas"
	var mine = mine_script.new(data, null)
	root.add_child(mine)
	await process_frame
	mine.show_overlay()
	mine.toggle_overlay()
	_check("gold mine popup stays disabled", not mine.has_overlay_open())
	_check("gold mine does not open the popup counter", not BuildingUIState.is_popup_open())
	mine.queue_free()
	await process_frame


func _test_barak_overlay_close() -> void:
	var barak_script: GDScript = load("res://scenes/buildings/Barak.gd")
	var barak = barak_script.new(_make_building_data(), null)
	root.add_child(barak)
	await process_frame

	barak.show_overlay()
	_check("barak counter open after show", BuildingUIState.is_popup_open())

	var close_btn: Button = barak._overlay.get_node("CancelBtn")
	_check("close button present on barak overlay", close_btn != null)
	if close_btn:
		close_btn.pressed.emit()
	_check("barak overlay closed by button", not barak.has_overlay_open())
	_check("barak counter drained by button", not BuildingUIState.is_popup_open())

	barak.queue_free()
	await process_frame


func _test_controller_close_all_popups() -> void:
	var rc = load("res://scenes/run/RunController.gd").new()

	var plot_menu = _make_plot()
	var plot_occ = _make_plot()
	await process_frame

	var BuildingScript: GDScript = load("res://scenes/buildings/Building.gd")
	var bld = BuildingScript.new(_make_building_data(), plot_occ)
	root.add_child(bld)
	await process_frame
	plot_occ.place_building(bld)

	plot_menu._show_build_popup()
	bld.show_overlay()
	_check("counter open before close_all (menu + overlay)", BuildingUIState.is_popup_open())

	rc.plot_nodes.clear()
	rc.plot_nodes.append(plot_menu)
	rc.plot_nodes.append(plot_occ)
	rc._close_all_building_popups()

	_check("build menu closed by close_all", plot_menu._popup == null)
	_check("overlay closed by close_all", bld.has_overlay_open() == false)
	_check("counter drained by close_all", not BuildingUIState.is_popup_open())

	bld.queue_free()
	plot_menu.queue_free()
	plot_occ.queue_free()
	rc.free()
	await process_frame