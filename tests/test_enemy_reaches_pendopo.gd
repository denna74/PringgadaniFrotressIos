extends SceneTree

const MAP_SIZE := 20
const MAX_FRAMES := 1500


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var terrain := _build_corridor_terrain()

	var holder := Node3D.new()
	root.add_child(holder)
	NavigationBuilder.build_navigation(terrain, holder, MAP_SIZE * 0.5, false)
	for i in 10:
		await process_frame

	var pendopo := Node3D.new()
	var ps := GDScript.new()
	ps.source_code = """
extends Node3D
var building_id: String = "pendopo"
var hp: float = 1000.0
func take_damage(amount: float) -> void:
	hp -= amount
"""
	ps.reload()
	pendopo.set_script(ps)
	pendopo.position = Vector3(6.0, 0.3, -1.0)
	root.add_child(pendopo)

	var inv: Node3D = load("res://scenes/run/InvasionManager.gd").new()
	inv.name = "InvasionManager"
	root.add_child(inv)
	inv.setup(null, [], terrain, MAP_SIZE)
	inv.set_king_ref(null)
	inv.set_pendopo_refs([pendopo])

	var data: Dictionary = EnemySpawner.spawn_batch(1, 1, 1, [])[0]
	inv._spawn_single_enemy(data, Vector2i(1, 9))
	var enemy: Node3D = inv._enemy_nodes[0]

	var frames := 0
	var reached_near := false
	var final_anim := ""
	var final_pos: Vector3 = enemy.position
	while frames < MAX_FRAMES:
		await process_frame
		frames += 1
		var pos: Vector3 = enemy.position
		final_pos = pos
		final_anim = enemy.get_meta("anim_state", "idle")
		if pos.distance_to(inv._pendopo_world_pos) <= 2.5:
			reached_near = true
		if reached_near and final_anim == "attack":
			break

	print(
		"ENEMY pos=", final_pos,
		" anim=", final_anim,
		" dist=", final_pos.distance_to(inv._pendopo_world_pos),
		" nav_done=", enemy.get_nav().is_navigation_finished()
	)
	if not reached_near:
		print("FAIL: enemy never reached pendopo")
		quit(1)
		return
	if final_anim != "attack":
		print("FAIL: enemy idle near pendopo (anim=", final_anim, ")")
		quit(1)
		return
	if final_pos.y > 0.6:
		print("FAIL: enemy hovering at y=", final_pos.y)
		quit(1)
		return

	# Retrying a stage reuses enemies left by the previous scene. A dead animation,
	# old facing, or old navigation target must not survive the next spawn.
	var old_spawn := Vector3(-9.0, 0.3, -1.0)
	enemy.rotation.y = 1.2
	enemy.get_anim_player().play("enemy/dead")
	enemy.set_meta("enemy_dead", true)
	UnitPool.release_enemy(enemy)
	inv._spawn_single_enemy(data, Vector2i(1, 9))
	var retried_enemy: Node3D = inv._enemy_nodes.back()
	if retried_enemy != enemy:
		print("FAIL: retry did not reuse the pooled enemy for regression coverage")
		quit(1)
		return
	if retried_enemy.rotation != Vector3.ZERO:
		print("FAIL: retry kept the previous enemy facing: ", retried_enemy.rotation)
		quit(1)
		return
	if retried_enemy.get_anim_player().current_animation != "enemy/idle":
		print("FAIL: retry kept the dead pose animation: ",
			retried_enemy.get_anim_player().current_animation)
		quit(1)
		return
	for i in 30:
		await physics_frame
	if retried_enemy.position.distance_to(inv._pendopo_world_pos) >= old_spawn.distance_to(inv._pendopo_world_pos):
		print("FAIL: retried enemy stayed idle at its old spawn position")
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
