extends SceneTree

# Slice C behaviour: an archer holds a 10-tile stand-off and shoots arrows,
# while an infantryman still closes to melee range.

var failures := 0


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
	for y in range(40):
		var row: Array = []
		for x in range(40):
			row.append(1)
		terrain.append(row)
	NavigationBuilder.build_navigation(terrain, holder, 0.0, false)
	for i in 10:
		await process_frame

	var king := Node3D.new()
	king.name = "King"
	king.add_to_group("king")
	root.add_child(king)

	await _test_archer_holds_range()
	await _test_infantry_closes()
	await _test_reused_soldier_moves_after_retry()
	await _test_distant_soldier_keeps_moving_and_animating()
	_test_spawn_stays_outside_building_footprints()
	await _test_archer_fires_arrow()
	await _test_archer_models()
	await _test_model_follows_troop_type_on_reuse()

	holder.queue_free()
	await process_frame

	if failures > 0:
		push_error("Archer soldier regression (%d failures)" % failures)
		quit(1)
		return
	print("ARCHER_SOLDIER_PASS")
	quit(0)


func _make_target(pos: Vector3) -> Node3D:
	var enemy := Node3D.new()
	enemy.add_to_group("enemies")
	enemy.position = pos
	var es := GDScript.new()
	es.source_code = """
extends Node3D
var hp: float = 500.0
func take_damage(amount: float) -> void:
	hp -= amount
func get_health() -> float:
	return hp
func is_alive() -> bool:
	return hp > 0.0
"""
	es.reload()
	enemy.set_script(es)
	root.add_child(enemy)
	await process_frame
	root.get_node("SpatialIndex").register(enemy, "enemies")
	return enemy


func _spawn(troop_type: String, pos: Vector3) -> Node3D:
	var s = load("res://scenes/run/SoldierUnit.gd").new()
	s.troop_type = troop_type
	s.position = pos
	root.add_child(s)
	s.setup_king_ref(root.get_node("King"))
	s.configure()
	s.move_speed = 50.0
	return s


func _clear_targets() -> void:
	var idx = root.get_node("SpatialIndex")
	var king = root.get_node_or_null("King")
	var doomed: Array = []
	for e in idx.get_nearby(Vector3(0, 0, 0), 200.0, "enemies"):
		doomed.append(e)
	for t in root.get_tree().get_nodes_in_group("troops"):
		if t != king:
			doomed.append(t)
	for d in doomed:
		if not is_instance_valid(d):
			continue
		idx.unregister(d)
		d.queue_free()
	for i in 4:
		await process_frame


func _test_archer_holds_range() -> void:
	var enemy := await _make_target(Vector3(8.0, 0, 0))
	var archer := _spawn("archer", Vector3.ZERO)

	_check("archer attack range is 10", is_equal_approx(archer.attack_range, 10.0))
	_check("archer is flagged ranged", archer.is_ranged())

	for i in 90:
		await process_frame

	var dist: float = archer.global_position.distance_to(Vector3(8.0, 0, 0))
	_check("archer did NOT close to melee (dist %.2f, stayed >= 7.0)" % dist, dist >= 7.0)
	_check("archer stayed within its 10-unit range (dist %.2f)" % dist, dist <= 10.5)

	await _clear_targets()


func _test_infantry_closes() -> void:
	var enemy := await _make_target(Vector3(4.0, 0, 0))
	var infantry := _spawn("infantry", Vector3.ZERO)
	infantry.attack_damage = 0.0

	_check("infantry is NOT ranged", not infantry.is_ranged())
	_check("infantry range stays melee", infantry.attack_range < 2.0)

	for i in 90:
		await process_frame

	var dist: float = infantry.global_position.distance_to(Vector3(4.0, 0, 0))
	_check("infantry closed to melee (dist %.2f <= 2.5)" % dist, dist <= 2.5)

	await _clear_targets()


func _test_distant_soldier_keeps_moving_and_animating() -> void:
	var king := root.get_node("King") as Node3D
	king.position = Vector3(0, 0, 10)
	var camera := Camera3D.new()
	camera.position = Vector3(0, 0, 50)
	root.add_child(camera)
	camera.make_current()
	await process_frame

	for troop_type in ["infantry", "archer"]:
		var soldier := _spawn(troop_type, Vector3(0, 0, 15))
		for i in 180:
			await physics_frame

		var distance_moved := soldier.global_position.distance_to(Vector3(0, 0, 15))
		_check("distant %s keeps moving (moved %.2f)" % [troop_type, distance_moved], distance_moved > 3.0)
		_check("distant %s animation remains active" % troop_type, soldier.get("_anim_player").active)
		await _clear_targets()

	camera.queue_free()
	king.position = Vector3.ZERO
	await process_frame


func _test_reused_soldier_moves_after_retry() -> void:
	var king := root.get_node("King") as Node3D
	king.position = Vector3.ZERO
	var unit_pool: GDScript = load("res://scripts/UnitPool.gd")
	var soldier = unit_pool.acquire_soldier()
	soldier.troop_type = "infantry"
	soldier.position = Vector3(4, 0, 0)
	root.add_child(soldier)
	soldier.setup_king_ref(king)
	soldier.configure()
	for i in 30:
		await physics_frame
	unit_pool.release_soldier(soldier)

	king.position = Vector3(12, 0, 0)
	var retrained = unit_pool.acquire_soldier()
	_check("retry reuses the pooled soldier", retrained == soldier)
	retrained.troop_type = "archer"
	retrained.position = Vector3(8, 0, 0)
	root.add_child(retrained)
	retrained.setup_king_ref(king)
	retrained.configure()
	_check("retrained pooled soldier picks up archer stats", retrained.is_ranged())
	var retry_map := NavigationServer3D.map_create()
	NavigationServer3D.map_set_active(retry_map, true)
	retrained.get_nav().set_navigation_map(retry_map)
	for i in 12:
		await physics_frame
	retrained.get_nav().set_navigation_map(retrained.get_world_3d().get_navigation_map())
	for i in 90:
		await physics_frame

	var moved: float = retrained.global_position.distance_to(Vector3(8, 0, 0))
	_check("retrained pooled soldier recovers from a temporarily unavailable nav map (moved %.2f)" % moved,
		moved > 1.0)
	_check("retrained pooled soldier resumes its run animation", retrained.current_anim() == "run")
	NavigationServer3D.free_rid(retry_map)
	unit_pool.release_soldier(retrained)
	king.position = Vector3.ZERO


func _test_spawn_stays_outside_building_footprints() -> void:
	var controller_script: GDScript = load("res://scenes/run/RunController.gd")
	var controller = controller_script.new()
	controller._map_size = 12
	controller._terrain = []
	for y in range(12):
		var row: Array = []
		for x in range(12):
			row.append(MapGenerator.TILE_PATH)
		controller._terrain.append(row)

	var barak_plot: Node3D = load("res://scenes/run/BuildingPlot.tscn").instantiate()
	barak_plot.plot_position = Vector2i(6, 6)
	barak_plot.occupied = true
	controller.plot_nodes.append(barak_plot)
	var barak := Node3D.new()

	var spawn: Vector3 = controller._find_troop_spawn_point(barak)
	var spawn_tile: Vector2i = Vector2i(roundi(spawn.x + 6), roundi(spawn.z + 6))
	var footprint_offset: Vector2i = spawn_tile - barak_plot.plot_position
	_check("trained soldier spawns outside the 3x3 barracks footprint",
		absi(footprint_offset.x) > 1 or absi(footprint_offset.y) > 1)

	controller.free()
	barak_plot.free()
	barak.free()


func _test_archer_fires_arrow() -> void:
	var enemy := await _make_target(Vector3(8.0, 0, 0))
	var archer := _spawn("archer", Vector3.ZERO)

	var arrows := _find_arrows()
	_check("no arrow before the archer shoots", arrows == 0)

	var hp_before: float = enemy.get("hp")
	for i in 240:
		await process_frame
		if _find_arrows() > 0 or float(enemy.get("hp")) < hp_before:
			break

	_check("archer spawned an arrow projectile", _find_arrows() > 0)

	for i in 300:
		await process_frame
		if float(enemy.get("hp")) < hp_before:
			break
	var hp_after: float = enemy.get("hp")
	_check("arrow dealt damage over the stand-off gap (%.0f -> %.0f)" % [hp_before, hp_after],
		hp_after < hp_before)

	await _clear_targets()


func _find_arrows() -> int:
	var n := 0
	for child in root.get_children():
		n += _count_arrows(child)
	return n


func _count_arrows(node: Node) -> int:
	var n := 0
	if node.get_script() != null and node.get_script().resource_path.ends_with("arrow_projectile.gd"):
		if (node as Node3D).visible:
			n += 1
	for c in node.get_children():
		n += _count_arrows(c)
	return n


# UnitPool hands back soldiers that already have a model attached, so switching
# troop_type on a reused unit has to swap the mesh, not keep the old one.
func _test_model_follows_troop_type_on_reuse() -> void:
	var soldier = load("res://scenes/run/SoldierUnit.gd").new()
	soldier.troop_type = "infantry"
	root.add_child(soldier)
	soldier.configure()
	soldier.set("_is_dying", true)
	soldier.configure()
	_check("reused soldier clears its dying state", not soldier.get("_is_dying"))
	_check("reused soldier resumes idle animation",
		soldier.get("_anim_player").current_animation == "soldier/idle")
	var inf_model = soldier.get("_model")
	_check("infantry unit has a model", inf_model != null)
	_check("infantry unit range is melee", is_equal_approx(soldier.attack_range, 1.6))

	soldier.troop_type = "archer"
	soldier.configure()
	var arc_model = soldier.get("_model")
	_check("reused unit swapped its model", arc_model != null and arc_model != inf_model)
	_check("reused unit picked up archer range", is_equal_approx(soldier.attack_range, 10.0))
	_check("reused unit re-derived max hp", is_equal_approx(soldier.soldier_max_hp, 300.0))
	_check("reused unit reports ranged", soldier.is_ranged())

	# And back again, so the switch is not one-way. ModelLoader hands out
	# duplicates, so compare the underlying mesh rather than the node identity.
	_check("archer used the archer mesh", _mesh_id(arc_model) != _mesh_id(inf_model))
	soldier.troop_type = "infantry"
	soldier.configure()
	_check("switching back restores the default mesh",
		_mesh_id(soldier.get("_model")) == _mesh_id(inf_model))
	_check("switching back restores melee range", is_equal_approx(soldier.attack_range, 1.6))

	root.get_node("SpatialIndex").unregister(soldier)
	soldier.queue_free()
	await process_frame


func _mesh_id(model: Node3D) -> String:
	if model == null or not is_instance_valid(model):
		return ""
	for c in model.find_children("*", "MeshInstance3D", true):
		var mi := c as MeshInstance3D
		if mi and mi.mesh:
			return mi.mesh.resource_path
	return ""


func _test_archer_models() -> void:
	for t in ["archer", "infantry"]:
		var m: Node3D = ModelLoader.load_soldier(t)
		_check("%s soldier model loads" % t, m != null)
		if m == null:
			continue
		var ap := ModelLoader.find_animation_player(m)
		_check("%s soldier model has an AnimationPlayer" % t, ap != null)
		if ap == null:
			continue
		_check("%s soldier model has a merged library" % t, ap.has_animation_library("soldier"))
		if ap.has_animation_library("soldier"):
			var lib: AnimationLibrary = ap.get_animation_library("soldier")
			for a in ["idle", "run", "attack", "dead"]:
				_check("%s soldier has %s animation" % [t, a], lib.has_animation(a))
		m.free()

	for t in ["archer", "infantry"]:
		var e: Node3D = ModelLoader.load_enemy(t, false)
		_check("%s enemy model loads" % t, e != null)
		if e == null:
			continue
		var ap := ModelLoader.find_animation_player(e)
		if ap != null and ap.has_animation_library("enemy"):
			var lib: AnimationLibrary = ap.get_animation_library("enemy")
			for a in ["idle", "run", "attack", "dead"]:
				_check("%s enemy has %s animation" % [t, a], lib.has_animation(a))
		else:
			_check("%s enemy has a merged library" % t, false)
		e.free()

	# A boss must still get the boss rig, never the archer.
	var boss: Node3D = ModelLoader.load_enemy("archer", true)
	var bap := ModelLoader.find_animation_player(boss)
	_check("boss still uses the boss rig", bap != null and bap.has_animation_library("boss"))
	boss.free()
