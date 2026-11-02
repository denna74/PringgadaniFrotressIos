extends SceneTree


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var ok := true

	var holder := Node3D.new()
	root.add_child(holder)

	var plot := Area3D.new()
	plot.position = Vector3(2.0, 0.0, 3.0)
	holder.add_child(plot)

	var data := {
		"id": "barak",
		"name_en": "Barak",
		"type": "military",
		"max_level": 15,
		"base_cost_gold": 40,
		"gold_per_day": 0,
		"grid_size": {"w": 3, "h": 3},
	}
	var BuildingScript: GDScript = load("res://scenes/buildings/Building.gd")
	var building = BuildingScript.new(data, plot)
	building.position = plot.position + Vector3(0, building.RISE_START_Y, 0)
	holder.add_child(building)
	await process_frame

	if not is_equal_approx(building.position.y, building.RISE_START_Y):
		push_error("building should start at RISE_START_Y, got %f" % building.position.y)
		ok = false

	building.animate_construction(0.2)
	var expected_y: float = plot.position.y + 0.2
	var waited := 0
	while not is_equal_approx(building.position.y, expected_y) and waited < 3000:
		await process_frame
		waited += 1

	if not is_equal_approx(building.position.y, expected_y):
		push_error("building did not finish rise: y=%f expected=%f" % [building.position.y, expected_y])
		ok = false

	building.queue_free()
	plot.queue_free()
	holder.queue_free()
	if ok:
		print("BUILD_CONSTRUCTION_PASS")
		quit(0)
	else:
		push_error("Construction regression")
		quit(1)