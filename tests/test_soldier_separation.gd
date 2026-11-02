extends SceneTree

const TILE_GRASS := 0
const TILE_PATH := 1

const MAP_SIZE := 16
const MAX_FRAMES := 600
const TOLERANCE := 0.8
const MIN_SEPARATION := 0.5


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

	var soldiers: Array[Node3D] = []
	for i in 3:
		var soldier: Node3D = load("res://scenes/run/SoldierUnit.gd").new()
		soldier.formation_slot = 0
		soldier.move_speed = 6.0
		soldier.position = _tile_world(Vector2i(2 + i * 2, 8), MAP_SIZE)
		soldier.setup_king_ref(king)
		root.add_child(soldier)
		soldiers.append(soldier)

	var frames := 0
	while frames < MAX_FRAMES:
		await process_frame
		frames += 1
		var settled := true
		for s in soldiers:
			if s.current_anim() == "run":
				settled = false
				break
		if settled:
			break

	for i in range(soldiers.size()):
		for j in range(i + 1, soldiers.size()):
			var d: float = Vector2(soldiers[i].position.x, soldiers[i].position.z).distance_to(
				Vector2(soldiers[j].position.x, soldiers[j].position.z)
			)
			print("SEP soldier", i, "-", j, " dist=", d)
			if d < MIN_SEPARATION:
				print("FAIL: soldiers overlap (", d, ")")
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
