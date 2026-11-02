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


func _find_ok_button(node: Node) -> Button:
	for child in node.get_children():
		if child is Button and (child as Button).text == "OK":
			return child
		var found := _find_ok_button(child)
		if found:
			return found
	return null


func _find_labels(node: Node, needle: String) -> Array:
	var out: Array = []
	for child in node.get_children():
		if child is Label and (child as Label).text.contains(needle):
			out.append(child)
		out.append_array(_find_labels(child, needle))
	return out


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

	print("waiting for level boot...")
	# Level boot takes ~5.3 s of real work (model prewarm, map gen, navmesh).
	for i in 600:
		await process_frame
		if run_ctl.garrison != null:
			break
	print("garrison after boot: ", run_ctl.garrison != null)
	print("king after boot: ", run_ctl._king_controller != null)
	if run_ctl.garrison == null:
		print("FAIL: level did not boot")
		_finish(1)
		return

	await process_frame

	var plot: Node3D = null
	var king_pos: Vector3 = run_ctl._king_controller.position if run_ctl._king_controller else Vector3.ZERO
	var farthest_dist := -1.0
	for p in run_ctl.plot_nodes:
		if not p.occupied:
			var d: float = p.position.distance_to(king_pos)
			if d > farthest_dist:
				farthest_dist = d
				plot = p
	print("available plot: ", plot != null)
	if plot == null:
		print("FAIL: no available plot")
		_finish(1)
		return

	var barak_data: Dictionary = {
		"id": "barak",
		"name_en": "Barak",
		"name_id": "Barak",
		"type": "military",
		"max_level": 15,
		"base_cost_gold": 40,
		"gold_per_day": 0,
		"troop_type": "infantry",
		"training_speed": 3,
		"grid_size": {"w": 3, "h": 3},
	}
	plot._place_building_from_data(barak_data)
	await process_frame
	var building: Node3D = plot.current_building
	print("building placed: ", building != null)
	print("building script: ", building.get_script().resource_path if building else "none")
	print("barak garrison set: ", building != null and building.garrison != null)
	if building == null:
		print("FAIL: building not placed")
		_finish(1)
		return

	var econ = root.get_node("/root/EconomyManager")
	var gold_before: int = econ.get_gold()
	building._on_train_pressed()
	print("gold before: ", gold_before, " after: ", econ.get_gold())
	print("queue: ", building._training_queue)

	var t = building._training_timer
	print("timer node: ", t != null)
	if t:
		print("timer wait_time: ", t.wait_time)
		print("timer one_shot: ", t.one_shot)
		print("timer stopped before: ", t.is_stopped())
		print("timer paused: ", t.paused)

	print("waiting for training timer (3s)...")
	var spawned_at_frame := -1
	for i in 900:
		await process_frame
		if run_ctl._soldier_units.size() > 0:
			spawned_at_frame = i
			break
		if t and i % 200 == 0:
			print("timer at frame ", i, " stopped=", t.is_stopped(), " time_left=", t.time_left)
	print("spawned_at_frame: ", spawned_at_frame)
	print("infantry count: ", run_ctl.garrison.infantry)
	print("soldiers spawned: ", run_ctl._soldier_units.size())
	if run_ctl._soldier_units.size() > 0:
		var s = run_ctl._soldier_units[0]
		print("soldier in tree: ", s.is_inside_tree(), " pos: ", s.position)
		print("soldier model children: ", s.get_child_count())

		var center: float = run_ctl._map_size * 0.5
		var tile := Vector2i(floori(s.position.x + center), floori(s.position.z + center))
		var on_path: bool = MapGenerator.is_walkable(run_ctl._terrain, tile)
		var barak_dist: float = s.position.distance_to(building.position)
		var king_dist: float = s.position.distance_to(run_ctl._king_controller.position)
		var barak_tile: Vector2i = plot.plot_position
		var spawn_offset: Vector2i = tile - barak_tile
		print("soldier on path: ", on_path, " barak_dist: ", barak_dist, " king_dist: ", king_dist)
		if not on_path:
			print("FAIL: soldier not spawned on a path tile")
			_finish(1)
			return
		if absi(spawn_offset.x) <= 1 and absi(spawn_offset.y) <= 1:
			print("FAIL: soldier spawned inside the barracks footprint (tile=", tile, ")")
			_finish(1)
			return
		if barak_dist >= 8.0:
			print("FAIL: soldier spawned far from barak (", barak_dist, ")")
			print("map_size=", run_ctl._map_size, " center=", run_ctl._map_size * 0.5)
			print("plot.plot_position=", plot.plot_position, " plot.position=", plot.position)
			print("building.position=", building.position)
			print("soldier.position=", s.position)
			var bplot = building.get("plot")
			print("building.plot=", bplot, " bplot.plot_position=", (bplot.plot_position if bplot else "n/a"))
			_finish(1)
			return
	else:
		print("E2E_FAIL")
		_finish(1)

	if run_ctl._soldier_units.size() > 0:
		var popup_plot: Node3D = null
		for p in run_ctl.plot_nodes:
			if p.has_method("_show_build_popup") and not p.occupied:
				popup_plot = p
				break
		if popup_plot == null:
			print("FAIL: no unoccupied plot for popup-close check")
			_finish(1)
			return
		popup_plot._show_build_popup()
		var popup_was_open: bool = BuildingUIState.is_popup_open()
		run_ctl._level_complete()
		var popup_closed_on_end: bool = not BuildingUIState.is_popup_open()
		print("popup open at victory: ", popup_was_open, " closed before result: ", popup_closed_on_end)
		if not (popup_was_open and popup_closed_on_end):
			print("E2E_POPUP_CLOSE_FAIL")
			_finish(1)
			return
		var ok_btn: Button = _find_ok_button(run_ctl.hud_ui)
		var ok_size_ok: bool = ok_btn != null and ok_btn.custom_minimum_size.x >= 120 and ok_btn.custom_minimum_size.y >= 40
		var ok_centered: bool = ok_btn != null and absf(ok_btn.get_global_rect().get_center().x - 640.0) < 40.0
		print("result OK button found: ", ok_btn != null, " size: ", (ok_btn.custom_minimum_size if ok_btn else "n/a"), " centered: ", ok_centered)
		if not ok_size_ok:
			print("E2E_OK_BUTTON_SMALL")
			_finish(1)
			return
		if not ok_centered:
			print("E2E_OK_BUTTON_OFF_CENTER")
			_finish(1)
			return
		var info_labels: Array = _find_labels(run_ctl.hud_ui, "Reward:")
		info_labels.append_array(_find_labels(run_ctl.hud_ui, "Mine:"))
		info_labels.append_array(_find_labels(run_ctl.hud_ui, "Total:"))
		var infos_centered := true
		var info_report := "n/a"
		if info_labels.size() > 0:
			info_report = ""
			for lbl in info_labels:
				var ctr: float = (lbl as Label).get_global_rect().get_center().x
				var aligned: bool = (lbl as Label).horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER
				info_report += " x=%.1f align=%d; " % [ctr, (lbl as Label).horizontal_alignment]
				if ctr < 600.0 or ctr > 680.0 or not aligned:
					infos_centered = false
		print("result info labels centered: ", infos_centered, " [", info_report, "]")
		if not infos_centered:
			print("E2E_RESULT_INFO_OFF_CENTER")
			_finish(1)
			return
		print("E2E_PASS")
		_finish(0)
	else:
		print("E2E_FAIL")
		_finish(1)
