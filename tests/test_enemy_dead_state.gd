extends SceneTree


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame

	var UPL: GDScript = load("res://scripts/UnitPool.gd")
	var si: Node = root.get_node("SpatialIndex")

	var enemy: Node3D = UPL.acquire_enemy()
	enemy.set_meta("pooled", true)
	enemy.set_meta("current_health", 50.0)
	enemy.set_meta("max_health", 50.0)
	root.add_child(enemy)
	await process_frame
	si.register(enemy, "enemies")

	if not enemy.is_alive():
		print("FAIL: fresh enemy not alive")
		quit(1)
		return

	var nearby: Array = si.get_nearby(enemy.global_position, 1.0, "enemies")
	if not nearby.has(enemy):
		print("FAIL: live enemy not registered in SpatialIndex")
		quit(1)
		return

	enemy.take_damage(999.0)
	await process_frame

	if enemy.is_alive():
		print("FAIL: enemy still alive after fatal damage, hp=", enemy.get_meta("current_health", 0))
		quit(1)
		return

	nearby = si.get_nearby(enemy.global_position, 1.0, "enemies")
	if nearby.has(enemy):
		print("FAIL: dead enemy still targetable in SpatialIndex")
		quit(1)
		return

	var hp_after: float = enemy.get_meta("current_health", 0.0)
	enemy.take_damage(10.0)
	if enemy.get_meta("current_health", 0.0) != hp_after:
		print("FAIL: dead enemy took damage, hp=", enemy.get_meta("current_health", 0.0))
		quit(1)
		return

	enemy.queue_free()
	await process_frame

	print("ENEMY_DEAD_STATE")
	quit(0)
