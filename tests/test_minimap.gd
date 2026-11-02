extends SceneTree


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var minimap: Control = load("res://scenes/run/Minimap.tscn").instantiate()
	root.add_child(minimap)
	await process_frame

	var ok := true
	if minimap.size != Vector2(220, 220):
		push_error("Minimap default size wrong: ", minimap.size)
		ok = false

	var terrain := [
		[0, 0, 0, 0, 0, 0, 0, 0],
		[0, 1, 1, 1, 1, 1, 1, 0],
		[0, 1, 2, 2, 3, 1, 1, 0],
		[0, 1, 2, 0, 1, 1, 1, 0],
		[0, 1, 3, 1, 0, 1, 1, 0],
		[0, 1, 1, 1, 1, 1, 4, 0],
		[0, 1, 1, 1, 1, 1, 1, 0],
		[0, 0, 0, 0, 0, 0, 0, 0],
	]
	minimap.setup(terrain, 8)
	if minimap._terrain_tex == null:
		push_error("Terrain texture not baked")
		ok = false

	var color_grass: Color = minimap._tile_color(0)
	var color_path: Color = minimap._tile_color(1)
	var color_obstacle: Color = minimap._tile_color(2)
	if color_grass.a != 0.0:
		push_error("Grass tile should be transparent, got ", color_grass)
		ok = false
	if color_path.r <= color_path.g or color_path.a == 0.0:
		push_error("Path tile should be light brown, got ", color_path)
		ok = false
	if color_obstacle.a == 0.0:
		push_error("Obstacle tile should be opaque, got ", color_obstacle)
		ok = false

	var center: Vector2 = minimap._to_pixel(Vector3(0, 0, 0))
	var expect_center: Vector2 = Vector2(110, 110)
	if center.distance_to(expect_center) > 0.01:
		push_error("World center should map to pixel ", expect_center, ", got ", center)
		ok = false

	var corner: Vector2 = minimap._to_pixel(Vector3(-4, 0, -4))
	if corner.distance_to(Vector2(0, 0)) > 0.01:
		push_error("World (-4,-4) should map to pixel (0,0), got ", corner)
		ok = false

	minimap.update_positions(
		Vector3(0, 0, 0),
		[Vector3(2, 0, 2), Vector3(-2, 0, 1)],
		[Vector3(1, 0, 3)],
		[Vector3(-1, 0, -1)],
		[Vector3(0, 0, -2), Vector3(6, 0, 6)]
	)
	if minimap._enemy_positions.size() != 2:
		push_error("Expected 2 enemy dots, got ", minimap._enemy_positions.size())
		ok = false
	if minimap._troop_positions.size() != 1:
		push_error("Expected 1 troop dot, got ", minimap._troop_positions.size())
		ok = false
	if minimap._building_positions.size() != 1:
		push_error("Expected 1 building dot, got ", minimap._building_positions.size())
		ok = false
	if minimap._pendopo_positions.size() != 2:
		push_error("Expected 2 pendopo dots, got ", minimap._pendopo_positions.size())
		ok = false

	if ok:
		print("MINIMAP_PASS")
		quit(0)
	else:
		push_error("Minimap regression")
		quit(1)
