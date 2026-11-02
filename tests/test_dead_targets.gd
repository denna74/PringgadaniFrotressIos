extends SceneTree


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame

	var target_script := GDScript.new()
	target_script.source_code = """
extends Node3D
var hp: float = 50.0
var damaged: int = 0
func is_alive() -> bool:
	return hp > 0
func take_damage(amount: float) -> void:
	damaged += 1
	hp -= amount
"""
	target_script.reload()

	var kc: Node3D = load("res://scenes/run/KingController.tscn").instantiate()
	kc.position = Vector3(0, 0, 0)
	kc._facing = 0.0
	root.add_child(kc)
	for i in 20:
		await process_frame

	var dead: Node3D = Node3D.new()
	dead.name = "DeadEnemy"
	dead.set_script(target_script)
	dead.position = Vector3(0, 0, 1.2)
	dead.hp = 0
	root.add_child(dead)
	await process_frame
	root.get_node("SpatialIndex").register(dead, "enemies")

	kc.attack()
	await process_frame

	if dead.damaged != 0:
		print("FAIL: king damaged an already-dead enemy, damaged=", dead.damaged)
		quit(1)
		return

	var alive: Node3D = Node3D.new()
	alive.name = "AliveEnemy"
	alive.set_script(target_script)
	alive.position = Vector3(0, 0, 1.2)
	root.add_child(alive)
	await process_frame
	root.get_node("SpatialIndex").register(alive, "enemies")

	kc.attack()
	await process_frame

	if alive.damaged != 1:
		print("FAIL: king did not damage the alive enemy, damaged=", alive.damaged)
		quit(1)
		return

	var data := {
		"id": "menara",
		"name_en": "Tower",
		"base_cost_gold": 100,
		"grid_size": {"w": 1, "h": 1},
		"max_level": 5,
	}
	var tower: Node3D = load("res://scenes/buildings/Tower.gd").new(data, null)
	tower.position = Vector3(0, 0, 0)
	root.add_child(tower)
	await process_frame
	tower.attack_range = 10.0

	var closer_dead: Node3D = Node3D.new()
	closer_dead.name = "CloserDead"
	closer_dead.set_script(target_script)
	closer_dead.position = Vector3(1.0, 0, 0)
	closer_dead.hp = 0
	root.add_child(closer_dead)
	await process_frame
	root.get_node("SpatialIndex").register(closer_dead, "enemies")

	var farther_alive: Node3D = Node3D.new()
	farther_alive.name = "FartherAlive"
	farther_alive.set_script(target_script)
	farther_alive.position = Vector3(3.0, 0, 0)
	root.add_child(farther_alive)
	await process_frame
	root.get_node("SpatialIndex").register(farther_alive, "enemies")

	tower._target = null
	tower._find_timer = 0.0
	tower._find_target()

	if tower._target == null:
		print("FAIL: tower found no target")
		quit(1)
		return
	if tower._target == closer_dead or tower._target == dead:
		print("FAIL: tower picked a dead enemy as target, got ", tower._target.name)
		quit(1)
		return
	if not tower._target.is_alive():
		print("FAIL: tower target is not alive, got ", tower._target.name)
		quit(1)
		return

	print("DEAD_TARGETS")
	quit(0)
