extends SceneTree


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var barak_script = load("res://scenes/buildings/Barak.gd")
	var building_data := {
		"id": "barak",
		"name_en": "Barak",
		"troop_type": "infantry",
		"training_speed": 3,
		"base_cost_gold": 10,
		"grid_size": {"w": 2, "h": 2},
		"max_level": 5,
		"type": "barracks",
	}
	var barak = barak_script.new(building_data, null)
	root.add_child(barak)
	await process_frame

	var overlay = barak._overlay
	var viewport: Viewport = barak.get_viewport()
	var mouse_pos: Vector2 = viewport.get_mouse_position()
	print("viewport mouse: ", mouse_pos)

	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = mouse_pos

	overlay.visible = true
	overlay.position = mouse_pos - Vector2(80, 45)
	barak._input(click)
	print("inside-click overlay visible: ", overlay.visible, " (expect true)")
	var inside_ok: bool = overlay.visible

	overlay.visible = true
	overlay.position = Vector2(1000, 1000)
	barak._input(click)
	print("outside-click overlay visible: ", overlay.visible, " (expect false)")
	var outside_ok: bool = not overlay.visible

	if inside_ok and outside_ok:
		print("CLICK_SWALLOW_PASS")
		quit(0)
	else:
		push_error("Barak._input overlay swallow regression")
		quit(1)
