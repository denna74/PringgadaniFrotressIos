extends SceneTree


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var holder := Node3D.new()
	root.add_child(holder)
	var UnitPoolScript := load("res://scripts/UnitPool.gd")

	var soldier_a: Node3D = UnitPoolScript.acquire_soldier()
	if soldier_a == null:
		print("FAIL: acquire_soldier returned null")
		quit(1)
		return
	soldier_a.position = Vector3(1, 0, 1)
	holder.add_child(soldier_a)
	await process_frame
	if not soldier_a.is_inside_tree():
		print("FAIL: soldier not in tree after acquire")
		quit(1)
		return

	soldier_a.soldier_hp = 5.0
	UnitPoolScript.release_soldier(soldier_a)
	if soldier_a.is_inside_tree():
		print("FAIL: released soldier still in tree")
		quit(1)
		return

	var soldier_b: Node3D = UnitPoolScript.acquire_soldier()
	if soldier_b != soldier_a:
		print("FAIL: pool did not reuse soldier instance")
		quit(1)
		return
	soldier_b.configure()
	if soldier_b.soldier_hp != soldier_b.soldier_max_hp:
		print("FAIL: configure did not reset hp")
		quit(1)
		return

	var enemy_a: Node3D = UnitPoolScript.acquire_enemy()
	if enemy_a == null:
		print("FAIL: acquire_enemy returned null")
		quit(1)
		return
	if enemy_a.get_node_or_null("NavigationAgent3D") == null:
		print("FAIL: pooled enemy missing NavigationAgent3D")
		quit(1)
		return
	if enemy_a.get_node_or_null("HPBar") == null:
		print("FAIL: pooled enemy missing HPBar")
		quit(1)
		return
	enemy_a.get_nav().process_mode = Node.PROCESS_MODE_DISABLED
	enemy_a.get_anim_player().active = false
	holder.add_child(enemy_a)
	await process_frame
	if not enemy_a.is_inside_tree():
		print("FAIL: enemy not in tree after acquire")
		quit(1)
		return

	var enemy_anim: AnimationPlayer = enemy_a.get_anim_player()
	if enemy_anim == null or not enemy_anim.has_animation("enemy/dead"):
		print("FAIL: pooled enemy missing death animation")
		quit(1)
		return
	enemy_anim.play("enemy/dead")
	UnitPoolScript.release_enemy(enemy_a)
	if enemy_a.is_inside_tree():
		print("FAIL: released enemy still in tree")
		quit(1)
		return

	var enemy_b: Node3D = UnitPoolScript.acquire_enemy()
	if enemy_b != enemy_a:
		print("FAIL: pool did not reuse enemy instance")
		quit(1)
		return
	if enemy_b.get_anim_player().current_animation != "enemy/idle":
		print("FAIL: reused enemy retained its previous animation")
		quit(1)
		return
	if enemy_b.get_nav().process_mode != Node.PROCESS_MODE_INHERIT:
		print("FAIL: reused enemy retained disabled navigation")
		quit(1)
		return
	if not enemy_b.get_anim_player().active:
		print("FAIL: reused enemy retained disabled animation")
		quit(1)
		return

	holder.add_child(enemy_b)
	UnitPoolScript.release_enemy(enemy_b)
	UnitPoolScript.clear_enemy_pool()
	if not enemy_b.is_queued_for_deletion():
		print("FAIL: clearing enemy pool did not discard pooled enemies")
		quit(1)
		return
	var enemy_c: Node3D = UnitPoolScript.acquire_enemy()
	if enemy_c == enemy_b:
		print("FAIL: cleared enemy pool reused an old enemy")
		quit(1)
		return
	holder.add_child(enemy_c)
	UnitPoolScript.release_enemy(enemy_c)

	var plain := Node3D.new()
	holder.add_child(plain)
	UnitPoolScript.release_enemy(plain)
	if not plain.is_queued_for_deletion():
		print("FAIL: non-pooled release_enemy did not free")
		quit(1)
		return

	print("VERIFY_PASS")
	quit(0)