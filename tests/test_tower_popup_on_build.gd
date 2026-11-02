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
		if run_ctl.garrison != null:
			break
	if run_ctl.garrison == null:
		print("TOWER_TAP_BOOT_FAIL")
		_finish(1)
		return
	await process_frame

	var plot = null
	for p in run_ctl.plot_nodes:
		if not p.occupied:
			plot = p
			break
	if plot == null:
		print("TOWER_TAP_NO_PLOT")
		_finish(1)
		return

	var menara_data: Dictionary = {}
	for d in BuildingData.get_all_buildings():
		if d.get("id", "") == "menara":
			menara_data = d
			break
	if menara_data.is_empty():
		print("TOWER_TAP_NO_DATA")
		_finish(1)
		return

	plot._show_build_popup()
	await process_frame
	var popup_open_before: bool = BuildingUIState.is_popup_open()

	var menara_name := "Tower"
	for d in BuildingData.get_all_buildings():
		if d.get("id", "") == "menara":
			menara_name = d.get("name_en", "Tower")
			break
	var card: ColorRect = null
	for child in plot._popup.get_children():
		if child is Label and (child as Label).text == menara_name:
			var card_y: float = child.position.y - 2
			for c in plot._popup.get_children():
				if c is ColorRect and c.size == Vector2(320, 78) and absf(c.position.y - card_y) < 3.0:
					card = c
					break
			break
	if card == null:
		print("TOWER_TAP_NO_CARD")
		_finish(1)
		return
	print("card mouse_filter: ", card.mouse_filter, " (expect STOP=", Control.MOUSE_FILTER_STOP, ")")
	if card.mouse_filter != Control.MOUSE_FILTER_STOP:
		print("TOWER_TAP_CARD_NOT_STOP")
		_finish(1)
		return

	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = Vector2(640, 279)

	plot._on_card_tap(press, menara_data)

	var building = plot.current_building
	var placed: bool = building != null
	var popup_closed: bool = plot._popup == null
	var overlay_open_before_stray: bool = placed and building.has_overlay_open()

	var stray := InputEventMouseButton.new()
	stray.button_index = MOUSE_BUTTON_LEFT
	stray.pressed = true
	stray.position = Vector2(640, 279)
	plot._on_input_event(null, stray, Vector3.ZERO, Vector3.UP, 0)
	var overlay_open_after_stray: bool = placed and building.has_overlay_open()
	await process_frame
	print("popup open before: ", popup_open_before)
	print("building placed: ", placed)
	print("popup closed after tap: ", popup_closed)
	print("overlay open before stray: ", overlay_open_before_stray)
	print("overlay open after stray press: ", overlay_open_after_stray)

	if not (popup_open_before and placed and popup_closed):
		print("TOWER_TAP_BUILD_FAIL")
		_finish(1)
		return
	if overlay_open_after_stray:
		print("TOWER_TAP_OVERLAY_LEAK")
		_finish(1)
		return

	var waited := 0
	while plot._suppress_press and waited < 1200:
		await process_frame
		waited += 1
	if plot._suppress_press:
		print("TOWER_TAP_SUPPRESS_STUCK")
		_finish(1)
		return
	if building.has_overlay_open():
		print("TOWER_TAP_OVERLAY_OPENED_BEFORE_TAP")
		_finish(1)
		return
	var later_tap := InputEventMouseButton.new()
	later_tap.button_index = MOUSE_BUTTON_LEFT
	later_tap.pressed = true
	later_tap.position = Vector2(640, 279)
	plot._on_input_event(null, later_tap, Vector3.ZERO, Vector3.UP, 0)
	await process_frame
	var overlay_after_later_tap: bool = building.has_overlay_open()
	print("overlay open after later tap (expect false): ", overlay_after_later_tap)
	if overlay_after_later_tap:
		print("TOWER_TAP_OVERLAY_SHOULD_BE_REMOVED")
		_finish(1)
		return

	print("TOWER_TAP_BUILD_PASS")
	_finish(0)