extends SceneTree

const TILE_GRASS := 0
const TILE_PATH := 1

const MAP_SIZE := 16
const MAX_FRAMES := 480
const TOLERANCE := 0.8


func _initialize() -> void:
	_run()


func _run() -> void:
	var terrain: Array = _build_l_path_terrain()

	await process_frame
	var holder := Node3D.new()
	root.add_child(holder)
	NavigationBuilder.build_navigation(terrain, holder, MAP_SIZE * 0.5, false)
	for i in 10:
		await process_frame

	var king := Node3D.new()
	king.name = "King"
	king.add_to_group("king")
	king.position = _tile_world(Vector2i(13, 2), MAP_SIZE)
	root.add_child(king)

	var soldier: Node3D = load("res://scenes/run/SoldierUnit.gd").new()
	soldier.formation_slot = 0
	soldier.move_speed = 6.0
	soldier.position = _tile_world(Vector2i(2, 8), MAP_SIZE)
	soldier.setup_king_ref(king)
	root.add_child(soldier)

	var off_path := false
	var moved := 0.0
	var prev: Vector3 = soldier.position
	var frames := 0
	while frames < MAX_FRAMES:
		await process_frame
		frames += 1
		var p: Vector3 = soldier.position
		moved += prev.distance_to(p)
		prev = p
		if not _on_path(terrain, p):
			off_path = true
			print("FAIL: soldier off path at frame ", frames, " pos ", p)
			break
		if p.distance_to(king.position) < 2.5:
			break

	if off_path:
		quit(1)
		return
	if moved < 8.0:
		print("FAIL: soldier barely moved (", moved, ")")
		quit(1)
		return
	if prev.distance_to(king.position) > 3.0:
		print("FAIL: soldier did not reach king (", prev.distance_to(king.position), ")")
		quit(1)
		return

	print("VERIFY_PASS")
	quit(0)


func _build_l_path_terrain() -> Array:
	var terrain: Array = []
	for y in range(MAP_SIZE):
		var row: Array = []
		for x in range(MAP_SIZE):
			row.append(TILE_GRASS)
		terrain.append(row)
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			for x in range(2, 14):
				terrain[8 + dy][x + dx] = TILE_PATH
	for y in range(2, 9):
		for dx in range(-1, 2):
			terrain[y][13 + dx] = TILE_PATH
	return terrain


func _tile_world(tile: Vector2i, map_size: int) -> Vector3:
	return Vector3(tile.x - map_size * 0.5, 0.0, tile.y - map_size * 0.5)


func _on_path(terrain: Array, pos: Vector3) -> bool:
	var ox: float = pos.x + MAP_SIZE * 0.5
	var oz: float = pos.z + MAP_SIZE * 0.5
	var tx := floori(ox)
	var tz := floori(oz)
	if MapGenerator.is_walkable(terrain, Vector2i(tx, tz)):
		return true
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var tile := Vector2i(tx + dx, tz + dy)
			if MapGenerator.is_walkable(terrain, tile):
				var center := Vector2(tile.x, tile.y)
				if center.distance_to(Vector2(ox, oz)) <= TOLERANCE:
					return true
	return false
