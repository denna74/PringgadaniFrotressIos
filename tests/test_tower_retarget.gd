extends SceneTree

var _fails: int = 0


func _initialize() -> void:
	_run()


func _check(name: String, ok: bool) -> void:
	if ok:
		print("OK  ", name)
	else:
		_fails += 1
		print("CHECK FAIL: ", name)


func _run() -> void:
	await process_frame

	var target_script := GDScript.new()
	target_script.source_code = """
extends Node3D
var hp: float = 50.0
func is_alive() -> bool:
	return hp > 0
func take_damage(amount: float) -> void:
	hp -= amount
"""
	target_script.reload()

	var data := {
		"id": "menara",
		"name_en": "Tower",
		"base_cost_gold": 100,
		"grid_size": {"w": 1, "h": 1},
		"max_level": 5,
	}
	var tower: Node3D = load("res://scenes/buildings/Tower.gd").new(data, null)
	tower.position = Vector3.ZERO
	root.add_child(tower)
	await process_frame
	tower.attack_range = 10.0
	tower._attack_timer = 999.0

	var far_alive := _make_target("FarAlive", Vector3(4, 0, 0), target_script)
	var near_alive := _make_target("NearAlive", Vector3(2, 0, 0), target_script)
	await process_frame
	root.get_node("SpatialIndex").register(far_alive, "enemies")
	root.get_node("SpatialIndex").register(near_alive, "enemies")

	tower._target = far_alive
	tower._find_timer = 0.0
	tower._process(0.016)
	_check("tower switches to the nearest living enemy", tower._target == near_alive)

	var backup := _make_target("Backup", Vector3(6, 0, 0), target_script)
	await process_frame
	root.get_node("SpatialIndex").register(backup, "enemies")

	far_alive.hp = 0.0
	near_alive.hp = 0.0
	tower._target = near_alive
	tower._find_timer = 0.0
	tower._process(0.016)
	_check("tower drops a dead target and picks a living one", tower._target == backup)

	tower._target = near_alive
	tower._find_timer = 999.0
	tower._attack_timer = 0.0
	tower._process(0.016)
	_check("tower retargets immediately when its target dies", tower._target == backup)

	if _fails > 0:
		print("TOWER_RETARGET_FAIL: ", _fails)
		quit(1)
		return
	print("TOWER_RETARGET_PASS")
	quit(0)


func _make_target(name: String, pos: Vector3, script: GDScript) -> Node3D:
	var target := Node3D.new()
	target.name = name
	target.set_script(script)
	target.position = pos
	root.add_child(target)
	return target
