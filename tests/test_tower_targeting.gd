extends SceneTree


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame

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

	var live_enemy := Node3D.new()
	live_enemy.name = "LiveEnemy"
	live_enemy.position = Vector3(3.0, 0, 0)
	root.add_child(live_enemy)
	await process_frame
	root.get_node("SpatialIndex").register(live_enemy, "enemies")

	var pooled_enemy := Node3D.new()
	pooled_enemy.name = "PooledEnemy"
	pooled_enemy.position = Vector3(2.0, 0, 0)

	tower._target = pooled_enemy
	tower._find_timer = 0.0
	tower._attack_timer = 999.0
	tower._process(0.016)

	if tower._target == pooled_enemy:
		print("FAIL: tower kept stale pooled target")
		quit(1)
		return
	if tower._target != live_enemy:
		print("FAIL: tower did not re-acquire live enemy, got ", tower._target)
		quit(1)
		return

	print("VERIFY_PASS")
	quit(0)