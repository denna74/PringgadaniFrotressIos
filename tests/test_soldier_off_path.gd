extends SceneTree

const TILE_GRASS := 0
const TILE_PATH := 1

const MAP_SIZE := 16
const MAX_FRAMES := 900
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
	king.position = _tile_world(Vector2i(5, 8), MAP_SIZE)
	root.add_child(king)
	var king_start: Vector3 = king.position
	var king_end: Vector3 = _tile_world(Vector2i(5, 3), MAP_SIZE)
	const KING_MOVE_FRAMES := 240

	var soldier: Node3D = load("res://scenes/run/SoldierUnit.gd").new()
	soldier.formation_slot = 0
	soldier.move_speed = 6.0
	soldier.position = _tile_world(Vector2i(8, 8), MAP_SIZE)
	soldier.setup_king_ref(king)
	root.add_child(soldier)

	var fail_reason := ""
	var moved := 0.0
	var prev: Vector3 = soldier.position
	var stopped_frames := 0
	var frames := 0
	while frames < MAX_FRAMES:
		await physics_frame
		frames += 1
		if frames <= KING_MOVE_FRAMES:
			king.position = king_start.lerp(king_end, float(frames) / float(KING_MOVE_FRAMES))
		else:
			king.position = king_end
		var p: Vector3 = soldier.position
		var step: float = prev.distance_to(p)
		moved += step
		prev = p
		var anim: String = soldier.current_anim()
		if not _on_path(terrain, p):
			fail_reason = "soldier off path at frame %d pos %s" % [frames, p]
			break
		if step < 0.001 and anim == "run":
			fail_reason = "soldier running in place at frame %d pos %s" % [frames, p]
			break
		if step < 0.001:
			stopped_frames += 1
		else:
			stopped_frames = 0
		if frames % 120 == 0:
			print("DBG f=", frames, " pos=", p, " anim=", anim, " nav_fin=", soldier.get_nav().is_navigation_finished())
		if stopped_frames >= 60:
			break

	if fail_reason != "":
		print("FAIL: ", fail_reason)
		quit(1)
		return
	if moved < 1.5:
		print("FAIL: soldier barely moved (", moved, ")")
		quit(1)
		return
	if soldier.current_anim() != "idle":
		print("FAIL: soldier not idle at end (", soldier.current_anim(), ")")
		quit(1)
		return

	var king_ground := Vector3(king.position.x, 0.0, king.position.z)
	var formation := king_ground + Vector3(1.5, 0.0, 0.0)
	var nearest := _nearest_path_point(terrain, formation)
	if soldier.position.distance_to(nearest) > 2.0:
		print("FAIL: soldier stopped far from path edge near king (", soldier.position.distance_to(nearest), " vs ", nearest, ")")
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


func _nearest_path_point(terrain: Array, world_pos: Vector3) -> Vector3:
	var best: Vector3 = world_pos
	var best_dist := INF
	for y in range(MAP_SIZE):
		for x in range(MAP_SIZE):
			if not MapGenerator.is_walkable(terrain, Vector2i(x, y)):
				continue
			var wp := _tile_world(Vector2i(x, y), MAP_SIZE)
			var d := Vector2(wp.x, wp.z).distance_to(Vector2(world_pos.x, world_pos.z))
			if d < best_dist:
				best_dist = d
				best = wp
	return best
