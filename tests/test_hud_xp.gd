extends SceneTree

var fail_count := 0


func _initialize() -> void:
	_run()


func _collect_labels(node: Node, out: Array) -> void:
	if node is Label:
		out.append((node as Label).text)
	for child in node.get_children():
		_collect_labels(child, out)


func _check(name: String, found: bool) -> void:
	if found:
		print("OK  ", name)
	else:
		push_error("FAIL " + name)
		fail_count += 1


func _find_xp_bar(node: Node) -> ProgressBar:
	if node is ProgressBar and (node as ProgressBar).max_value == 430.0:
		return node
	for child in node.get_children():
		var hit: ProgressBar = _find_xp_bar(child)
		if hit != null:
			return hit
	return null


func _run() -> void:
	await process_frame
	var hud: CanvasLayer = CanvasLayer.new()
	hud.set_script(load("res://scenes/run/RunHUD.gd"))
	root.add_child(hud)
	await process_frame

	var tm = root.get_node("/root/TranslationManager")
	hud.setup_king_progress(12, 240, 430)
	await process_frame

	var texts: Array = []
	_collect_labels(hud, texts)

	_check("shows centered LV 12", texts.has("LV 12"))
	_check("shows EXP caption", texts.has("EXP"))
	_check("shows translated gold caption", texts.has(tm.t("resource_gold")))
	_check("shows HP caption", texts.has("HP"))
	_check("shows MP caption", texts.has("MP"))
	_check("shows STA caption", texts.has("STA"))
	_check("shows XP readout 240 / 430", texts.has("240 / 430"))

	# The panel is found by what it holds, never by where it sits: nudging the top bar or
	# the status panel must not be able to invalidate these checks.
	var xp_bar: ProgressBar = _find_xp_bar(hud)
	var grid_found := false
	var xp_bar_styled := false
	var xp_num: Label = null
	var sta_in_box := false
	var lv_centered := false
	var panel_ref: Panel = null
	if xp_bar != null and xp_bar.get_parent() is GridContainer:
		var grid: GridContainer = xp_bar.get_parent() as GridContainer
		grid_found = grid.get_parent() is Panel
		panel_ref = grid.get_parent() as Panel
		for cell in grid.get_children():
			if cell is Label and (cell as Label).text == "240 / 430":
				xp_num = cell
			if cell is Label and (cell as Label).text == "STA":
				sta_in_box = panel_ref != null and panel_ref.get_global_rect().encloses(cell.get_global_rect())
		if panel_ref != null:
			for child in panel_ref.get_children():
				if child is Label and (child as Label).text == "LV 12":
					lv_centered = (child as Label).horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER
	xp_bar_styled = xp_bar != null and xp_bar.has_theme_stylebox_override("fill")
	_check("status panel found", panel_ref != null)
	_check("uses GridContainer layout", grid_found)
	_check("XP bar has styled fill", xp_bar_styled)
	_check("STA row fits inside the box", sta_in_box)
	_check("LV info is centered", lv_centered)

	var no_overlap := false
	if xp_bar != null and xp_num != null:
		no_overlap = not xp_bar.get_global_rect().intersects(xp_num.get_global_rect())
	_check("EXP bar and readout do not overlap", no_overlap)

	hud.setup_king_progress(99, 0, 0)
	await process_frame
	var max_xp_bar := hud.get("_king_xp_bar") as ProgressBar
	var max_xp_label := hud.get("_king_xp_num") as Label
	_check(
		"EXP bar is full at max level",
		max_xp_bar != null and max_xp_bar.value == max_xp_bar.max_value
	)
	_check(
		"EXP readout shows maximum at max level",
		max_xp_label != null and max_xp_label.text == tm.t("xp_maximum")
	)

	await process_frame
	if fail_count > 0:
		quit(1)
		return
	print("HUD_XP_PASS")
	quit(0)