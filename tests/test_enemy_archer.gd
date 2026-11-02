extends SceneTree

# Slice C behaviour: enemy archers stop 10 tiles out and shoot, while melee
# enemies keep walking into the pendopo.

var failures := 0
var _idx: Node = null
var _terrain: Array = []


func _initialize() -> void:
	_run()


func _check(name: String, cond: bool) -> void:
	if cond:
		print("OK  ", name)
	else:
		push_error("FAIL " + name)
		failures += 1


func _run() -> void:
	await process_frame

	var holder := Node3D.new()
	root.add_child(holder)
	var terrain: Array = []
	for y in range(60):
		var row: Array = []
		for x in range(60):
			row.append(1)
		terrain.append(row)
	NavigationBuilder.build_navigation(terrain, holder, 30.0, false)
	for i in 10:
		await process_frame
	_idx = root.get_node("SpatialIndex")
	_terrain = terrain

	var king := Node3D.new()
	king.name = "King"
	king.add_to_group("king")
	root.add_child(king)

	await _test_roster_gate()
	await _test_enemy_archer_stops_and_shoots()
	await _test_melee_still_melee()

	holder.queue_free()
	await process_frame

	if failures > 0:
		push_error("Enemy archer regression (%d failures)" % failures)
		quit(1)
		return
	print("ENEMY_ARCHER_PASS")
	quit(0)


func _test_roster_gate() -> void:
	# 4000 draws at stage 1 and stage 45 must never produce an archer.
	var early_archers := 0
	for i in 4000:
		if EnemySpawner.spawn_batch(1, 1, 1, [])[0]["type"] == "archer":
			early_archers += 1
	_check("no archer spawns at stage 1 over 4000 draws (%d)" % early_archers, early_archers == 0)

	var mid := 0
	for i in 2000:
		if EnemySpawner.spawn_batch(1, 1, 29, [])[0]["type"] == "archer":
			mid += 1
	_check("no archer spawns at stage 29 (%d)" % mid, mid == 0)

	var late := 0
	for i in 2000:
		if EnemySpawner.spawn_batch(1, 1, 30, [])[0]["type"] == "archer":
			late += 1
	_check("archers do spawn at stage 30 (%d of 2000)" % late, late > 100)

	# Past the difficulty cap the gate must stay open, not close at 250.
	_check("archer roster still open at stage 400",
		EnemySpawner.available_types(400).has("archer"))


func _make_pendopo(pos: Vector3) -> Node3D:
	var p := Node3D.new()
	p.position = pos
	var ps := GDScript.new()
	ps.source_code = """
extends Node3D
var building_id: String = "pendopo"
var hp: float = 4000.0
var destroyed: bool = false
func take_damage(amount: float) -> void:
	hp -= amount
func is_destroyed() -> bool:
	return destroyed
"""
	ps.reload()
	p.set_script(ps)
	root.add_child(p)
	return p


func _make_invasion() -> Node3D:
	var inv: Node3D = load("res://scenes/run/InvasionManager.gd").new()
	inv.name = "InvasionManager"
	root.add_child(inv)
	inv.setup(null, [], _terrain, 60)
	inv.set_king_ref(root.get_node("King"))
	return inv


func _spawn(inv: Node3D, type: String, pos: Vector3) -> Node3D:
	var data: Dictionary = {
		"type": type, "attack": 6.0, "defense": 1.0, "health": 4000.0,
		"max_health": 4000.0, "name": type, "is_boss": false,
		"color": Color.RED, "speed": 2.5,
	}
	var e: Node3D = inv._create_enemy_node(data, pos)
	inv.add_child(e)
	inv._enemy_nodes.append(e)
	return e


func _teardown(inv: Node3D, extras: Array) -> void:
	for n in extras:
		if is_instance_valid(n):
			n.queue_free()
	for e in inv._enemy_nodes.duplicate():
		if is_instance_valid(e):
			_idx.unregister(e)
			e.queue_free()
	inv._enemy_nodes.clear()
	inv.queue_free()
	for i in 4:
		await process_frame


func _count_arrows() -> int:
	var n := 0
	for child in root.get_children():
		n += _count(child)
	return n


func _count(node: Node) -> int:
	var n := 0
	if node.get_script() != null and node.get_script().resource_path.ends_with("arrow_projectile.gd"):
		if (node as Node3D).visible:
			n += 1
	for c in node.get_children():
		n += _count(c)
	return n


func _test_enemy_archer_stops_and_shoots() -> void:
	var pendopo := _make_pendopo(Vector3(20.0, 0.3, 0.0))
	var inv := _make_invasion()
	inv.set_pendopo_refs([pendopo])
	var archer := _spawn(inv, "archer", Vector3(0.0, 0.3, 0.0))

	_check("archer enemy is flagged ranged", inv.is_enemy_ranged(archer))
	var hp_before: float = float(pendopo.get("hp"))

	var saw_arrow := false
	var closed_in := 0.0
	for i in 1500:
		await physics_frame
		if _count_arrows() > 0:
			saw_arrow = true
		closed_in = archer.global_position.distance_to(Vector3(20.0, 0.3, 0.0))
		if saw_arrow and float(pendopo.get("hp")) < hp_before:
			break

	var dist: float = archer.global_position.distance_to(Vector3(20.0, 0.3, 0.0))
	_check("enemy archer walked in (dist %.2f)" % dist, dist < 19.0)
	_check("enemy archer never closed inside melee (dist %.2f, stayed > 8.0)" % closed_in, closed_in > 8.0)
	_check("enemy archer held the 10-tile stand-off (dist %.2f)" % dist, dist <= 10.6)
	_check("enemy archer shot an arrow", saw_arrow)
	_check("enemy archer damaged the pendopo from range (%.0f -> %.0f)" % [hp_before, float(pendopo.get("hp"))],
		float(pendopo.get("hp")) < hp_before)

	await _teardown(inv, [pendopo])


func _test_melee_still_melee() -> void:
	var pendopo := _make_pendopo(Vector3(20.0, 0.3, 0.0))
	var inv := _make_invasion()
	inv.set_pendopo_refs([pendopo])
	var grunt := _spawn(inv, "infantry", Vector3(0.0, 0.3, 0.0))

	_check("infantry enemy is NOT ranged", not inv.is_enemy_ranged(grunt))

	# Wait for arrival first, then for the swing: arriving is not the same as
	# landing a hit, and the two happen on different frames.
	for i in 2000:
		await physics_frame
		if grunt.global_position.distance_to(Vector3(20.0, 0.3, 0.0)) < 2.0 \
				and float(pendopo.get("hp")) < 4000.0:
			break
	# A melee enemy must come to rest inside its own reach, otherwise it parks
	# just out of range and never swings.
	var dist: float = grunt.global_position.distance_to(Vector3(20.0, 0.3, 0.0))
	_check("infantry still walked into melee (dist %.2f <= 2.5)" % dist, dist <= 2.5)
	_check("infantry rests inside its own attack range (dist %.2f <= %.2f)" % [dist, inv.ENEMY_ATTACK_RANGE],
		dist <= inv.ENEMY_ATTACK_RANGE)

	for i in 600:
		await physics_frame
		if float(pendopo.get("hp")) < 4000.0:
			break
	_check("infantry damaged the pendopo", float(pendopo.get("hp")) < 4000.0)

	await _teardown(inv, [pendopo])
