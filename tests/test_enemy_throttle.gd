extends SceneTree


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame

	var manager: Node3D = load("res://scenes/run/InvasionManager.gd").new()
	var camera := Camera3D.new()
	var enemy: Node3D = load("res://scenes/run/enemy_script.gd").new()
	var anim_player := AnimationPlayer.new()
	var nav := NavigationAgent3D.new()
	nav.name = "NavigationAgent3D"
	enemy.add_child(anim_player)
	enemy.add_child(nav)
	root.add_child(manager)
	root.add_child(camera)
	root.add_child(enemy)
	manager._cam_ref = camera
	enemy.position = Vector3(100.0, 0.0, 0.0)
	manager._update_frame = 1

	manager._enemy_nodes.append(enemy)
	enemy.set_meta("enemy_data", {"speed": 2.5, "type": "infantry"})
	enemy.set_meta("enemy_dead", false)
	enemy.set_meta("anim_state", "idle")
	enemy.set_meta("attack_anim_lock", 0.0)
	enemy.set_nav_target(Vector3.ZERO)
	manager._move_enemies(1.0 / 60.0)
	if enemy.position.length_squared() == 0.0:
		push_error("Distant enemy movement was throttled")
		quit(1)
		return
	if nav.process_mode == Node.PROCESS_MODE_DISABLED or not anim_player.active:
		push_error("Distant enemy processing was disabled")
		quit(1)
		return

	manager.queue_free()
	camera.queue_free()
	enemy.queue_free()
	print("ENEMY_THROTTLE_PASS")
	quit(0)
