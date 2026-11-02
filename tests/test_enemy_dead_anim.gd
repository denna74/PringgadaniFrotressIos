extends SceneTree


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var MLL: GDScript = load("res://scripts/ModelLoader.gd")
	var UPL: GDScript = load("res://scripts/UnitPool.gd")

	var enemy: Node3D = MLL.load_enemy("infantry", false)
	enemy.set_script(UPL.ENEMY_SCRIPT)
	enemy.set_meta("pooled", true)
	enemy.set_meta("current_health", 10.0)
	enemy.set_meta("max_health", 10.0)
	enemy.add_to_group("enemies")
	UPL.attach_common_children(enemy)
	root.add_child(enemy)
	await process_frame

	var ap: AnimationPlayer = MLL.find_animation_player(enemy)
	if ap == null or not ap.has_animation("enemy/dead"):
		print("FAIL: enemy model has no enemy/dead animation")
		quit(1)
		return

	enemy.take_damage(999.0)

	var conns: Array = ap.animation_finished.get_connections()
	if conns.is_empty():
		print("FAIL: death path did not connect to animation_finished")
		quit(1)
		return

	for c in conns:
		c.callable.call("enemy/dead")
	await process_frame

	if is_instance_valid(enemy) and enemy.is_inside_tree():
		print("FAIL: connected callable ignored signal arg (release never ran)")
		quit(1)
		return

	print("ENEMY_DEAD_ANIM_PASS")
	quit(0)