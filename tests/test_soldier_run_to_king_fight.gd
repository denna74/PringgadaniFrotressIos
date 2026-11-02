extends SceneTree

const MAP_SIZE := 20
const MAX_FRAMES := 900


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var holder := Node3D.new()
	root.add_child(holder)
	var terrain: Array = _build_corridor_terrain()
	NavigationBuilder.build_navigation(terrain, holder, MAP_SIZE * 0.5, false)
	for i in 10:
		await process_frame

	var king := Node3D.new()
	king.name = "King"
	king.add_to_group("king")
	king.position = Vector3(8.0, 0.0, -1.0)
	root.add_child(king)

	var enemy := Node3D.new()
	enemy.name = "Enemy"
	enemy.add_to_group("enemies")
	enemy.position = Vector3(0.0, 0.0, -1.0)
	var es := GDScript.new()
	es.source_code = """
extends Node3D
var hp: float = 24.0
func take_damage(amount: float) -> void:
	hp -= amount
	if hp <= 0.0:
		queue_free()
"""
	es.reload()
	enemy.set_script(es)
	root.add_child(enemy)
	await process_frame
	root.get_node("SpatialIndex").register(enemy, "enemies")

	var soldier: Node3D = load("res://scenes/run/SoldierUnit.gd").new()
	soldier.formation_slot = 0
	soldier.move_speed = 6.0
	soldier.position = Vector3(-8.0, 0.0, -1.0)
	soldier.setup_king_ref(king)
	root.add_child(soldier)

	var enemy_hit := false
	var reached_king := false
	for i in MAX_FRAMES:
		await process_frame
		if is_instance_valid(enemy) and float(enemy.get("hp")) < 24.0:
			enemy_hit = true
		if not is_instance_valid(enemy) and soldier.position.distance_to(king.position) < 3.0:
			reached_king = true
			break
		if soldier.position.distance_to(king.position) < 3.0 and not is_instance_valid(enemy):
			reached_king = true
			break

	print("FIGHT enemy_hit=", enemy_hit, " reached_king=", reached_king, " soldier_pos=", soldier.position)
	if not enemy_hit:
		print("FAIL: soldier did not fight enemy en route")
		quit(1)
		return
	if not reached_king:
		print("FAIL: soldier did not reach king after fighting (pos=", soldier.position, ")")
		quit(1)
		return

	print("VERIFY_PASS")
	quit(0)


func _build_corridor_terrain() -> Array:
	var terrain: Array = []
	for y in range(MAP_SIZE):
		var row: Array = []
		for x in range(MAP_SIZE):
			row.append(0)
		terrain.append(row)
	for y in range(8, 11):
		for x in range(1, 19):
			terrain[y][x] = 1
	return terrain
