extends SceneTree


func _initialize() -> void:
	_run()


func _run() -> void:
	var spatial: Node = load("res://autoload/SpatialIndex.gd").new()
	root.add_child(spatial)

	var enemy := Node3D.new()
	enemy.name = "Enemy"
	enemy.position = Vector3(0, 0, 0)
	root.add_child(enemy)

	var soldier := Node3D.new()
	soldier.name = "Soldier"
	soldier.add_to_group("troops")
	soldier.position = Vector3(1, 0, 0)
	root.add_child(soldier)

	var far_soldier := Node3D.new()
	far_soldier.name = "FarSoldier"
	far_soldier.add_to_group("troops")
	far_soldier.position = Vector3(50, 0, 0)
	root.add_child(far_soldier)

	await process_frame
	spatial.register(enemy, "enemies")
	spatial.register(soldier, "troops")
	spatial.register(far_soldier, "troops")

	var hit: Node3D = spatial.get_nearest(enemy.global_position, 5.0, "troops")
	if hit != soldier:
		print("FAIL: expected nearest soldier, got ", hit)
		quit(1)
		return
	var miss: Node3D = spatial.get_nearest(enemy.global_position, 0.5, "troops")
	if miss != null:
		print("FAIL: expected no soldier in tiny range")
		quit(1)
		return
	print("VERIFY_PASS")
	quit(0)
