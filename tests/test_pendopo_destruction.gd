extends SceneTree

# A destroyed pendopo must not survive as an intact-looking fort, and must not keep
# serving as a heal anchor. Before this:
#   - take_damage(9999) only set a bool and emitted; the mesh stayed fully visible and the
#     ruin kept drawing its HP bar, its minimap dot, and its heal ring.
#   - RunController.get_pendopo_positions() returned every pendopo regardless of state, so
#     Gatotkaca healed himself on rubble and the minimap drew the ruin as a live objective.
#   - _on_pendopo_destroyed() never re-synced, so the king's target list kept the corpse.
#   - healing_changed was connected to pendopo #1 only, so the ring showed on the wrong
#     pendopo at 2-3 pendopo stages and kept showing over a destroyed one.

var _fails: int = 0
var _stage: Node3D = null


func _initialize() -> void:
	_run()


func _fail(msg: String) -> void:
	_fails += 1
	print("CHECK FAIL: " + msg)


func _run() -> void:
	await process_frame

	_stage = Node3D.new()
	root.add_child(_stage)

	_test_heals_while_alive()
	_test_destruction_removes_pendopo_from_heal_targets()
	_test_destruction_stops_processing()
	_test_heal_ring_dies_with_the_pendopo()
	_test_destruction_spawns_an_explosion()
	_test_destruction_places_explosion_at_world_position()
	_test_heal_ring_wired_to_every_pendopo()
	_test_destroyed_pendopo_releases_its_heal_ring()

	if _stage != null:
		_stage.free()
	if _fails == 0:
		print("VERIFY_PASS: pendopo destruction")
		quit(0)
	else:
		print("VERIFY_FAIL: %d checks failed" % _fails)
		quit(1)


func _make_pendopo() -> Node3D:
	return _make_pendopo_at(Vector3(10.0, 0.0, 20.0))


func _make_pendopo_at(pos: Vector3) -> Node3D:
	var pendopo: Node3D = load("res://scenes/buildings/Pendopo.gd").new({"id": "pendopo"}, null)
	_stage.add_child(pendopo)
	pendopo.position = pos
	return pendopo


func _make_king() -> Node3D:
	var king: Node3D = load("res://scenes/run/KingController.gd").new()
	_stage.add_child(king)
	return king


# RunController keeps its @onready node deps unresolvable when it is never added to the
# tree, which is how test_building_popup.gd uses it too. The pendopo bookkeeping methods
# under test do not touch those deps.
func _make_controller(pendopo: Node3D) -> Node:
	var controller: Node = load("res://scenes/run/RunController.gd").new()
	controller.pendopo_nodes = _typed([pendopo])
	controller._king_controller = _make_king()
	# _sync_objective_state() pushes the pendopo list into the invasion manager, so the
	# controller needs one even though it is never added to the tree itself.
	var invasion: Node3D = load("res://scenes/run/InvasionManager.gd").new()
	_stage.add_child(invasion)
	controller.invasion_manager = invasion
	return controller


# pendopo_nodes is Array[Node3D], so an untyped literal is rejected on assignment.
func _typed(nodes: Array) -> Array[Node3D]:
	var out: Array[Node3D] = []
	for node in nodes:
		out.append(node)
	return out


# While alive, the pendopo must still be a valid heal anchor -- otherwise the fix would be
# "correct" but also useless.
func _test_heals_while_alive() -> void:
	var pendopo := _make_pendopo()
	var controller := _make_controller(pendopo)
	controller._sync_objective_state()

	if controller.get_pendopo_positions().size() != 1:
		_fail("a live pendopo must be offered to Gatotkaca as a heal target")
	var king: Node3D = controller._king_controller
	if king.pendopo_positions.size() != 1:
		_fail("a live pendopo did not reach the king's heal target list")

	controller._king_controller = null
	king.queue_free()
	pendopo.queue_free()


# The core of the request: Gatotkaca must not be able to heal on a destroyed pendopo.
func _test_destruction_removes_pendopo_from_heal_targets() -> void:
	var pendopo := _make_pendopo()
	var controller := _make_controller(pendopo)
	controller._sync_objective_state()

	pendopo.take_damage(99999.0)
	if not pendopo.is_destroyed():
		_fail("lethal damage did not mark the pendopo destroyed")
		return

	# A second, living pendopo keeps this from tripping the loss path (which reaches into
	# hud_ui and the scene tree). The heal-target filter is what is under test here.
	controller.pendopo_nodes.append(_make_pendopo_at(Vector3(-30.0, 0.0, 20.0)))
	controller._sync_objective_state()

	# _on_pendopo_destroyed() must re-sync on its own; it used to skip it entirely, so the
	# king kept healing on the corpse even though the objective had already been told.
	controller._on_pendopo_destroyed()

	if controller.get_pendopo_positions().size() != 1:
		_fail("a destroyed pendopo is still offered as a heal target (%d targets remain)" % controller.get_pendopo_positions().size())
	var king: Node3D = controller._king_controller
	if king.pendopo_positions.size() != 1:
		_fail("Gatotkaca kept %d heal targets after the pendopo fell, wanted 1" % king.pendopo_positions.size())

	controller._king_controller = null
	king.queue_free()


# A dead pendopo must not keep redrawing its HP bar from _process().
func _test_destruction_stops_processing() -> void:
	var pendopo := _make_pendopo()
	if not pendopo.is_processing():
		_fail("a live pendopo should be processing its HP bar")

	pendopo.take_damage(99999.0)
	if pendopo.is_processing():
		_fail("a destroyed pendopo is still running _process and redrawing its HP bar")


# The heal ring is built unconditionally in _ready(), so destruction must switch it off.
func _test_heal_ring_dies_with_the_pendopo() -> void:
	var pendopo := _make_pendopo()
	var zone := pendopo.get_node_or_null("HealZone")
	if zone == null:
		_fail("pendopo has no HealZone to begin with")
		return
	if not zone.has_method("is_healing_active"):
		_fail("HealZone cannot report whether it is healing")
		return

	pendopo.begin_heal_effect(true)
	if not zone.is_healing_active():
		_fail("begin_heal_effect(true) did not light the heal ring")

	pendopo.take_damage(99999.0)
	if zone.is_healing_active():
		_fail("a destroyed pendopo is still showing the heal ring")


# The pendopo must vanish and leave an explosion behind it, rather than standing there
# looking intact.
func _test_destruction_spawns_an_explosion() -> void:
	var pendopo := _make_pendopo()
	pendopo.take_damage(99999.0)

	if not pendopo.is_queued_for_deletion():
		_fail("the destroyed pendopo was never queued for deletion, so the ruin stays in the game")
	if _count_explosions(_stage) == 0:
		_fail("no explosion was spawned when the pendopo fell")
	if _count_explosions(root) == 0 and _count_explosions(_stage) == 0:
		_fail("the explosion was not spawned into the tree where it can be seen")


# The explosion is spawned before the pendopo is freed, and it must land at the pendopo's
# world position. It used to emit `get_global_transform` "!is_inside_tree()" errors and land
# at the wrong world position whenever the parent transform was not identity, because
# explosion.global_position was assigned while the explosion was still detached from the tree.
func _test_destruction_places_explosion_at_world_position() -> void:
	var holder := Node3D.new()
	holder.position = Vector3(500.0, 0.0, 300.0)
	_stage.add_child(holder)

	var pendopo: Node3D = load("res://scenes/buildings/Pendopo.gd").new({"id": "pendopo"}, null)
	holder.add_child(pendopo)
	pendopo.position = Vector3(2.0, 0.3, 5.0)

	var expect_world: Vector3 = pendopo.global_position
	pendopo.take_damage(99999.0)

	var explosion := _find_explosion(holder)
	if explosion == null:
		_fail("the collapse effect was not spawned into the tree")
	else:
		var got := explosion.global_position
		if not got.is_equal_approx(expect_world):
			_fail("explosion landed at %s, wanted world %s" % [got, expect_world])

	holder.queue_free()


func _count_explosions(parent: Node) -> int:
	if parent == null:
		return 0
	var count := 0
	for child in parent.get_children():
		var script: GDScript = child.get_script()
		if script != null and "PendopoExplosion" in script.resource_path:
			count += 1
	return count


func _find_explosion(parent: Node) -> Node3D:
	if parent == null:
		return null
	for child in parent.get_children():
		var script: GDScript = child.get_script()
		if script != null and "PendopoExplosion" in script.resource_path:
			return child
		var found := _find_explosion(child)
		if found != null:
			return found
	return null


# At 2-3 pendopo stages the king walks between pendopos, so the ring must follow him
# instead of being pinned to whichever pendopo was placed first.
func _test_heal_ring_wired_to_every_pendopo() -> void:
	var first := _make_pendopo()
	var controller := _make_controller(first)
	controller._sync_objective_state()
	var second := _make_pendopo()
	controller.pendopo_nodes.append(second)
	controller._sync_objective_state()

	if not controller._heal_ring_is_wired(first):
		_fail("healing_changed is not connected to the first pendopo")
	if not controller._heal_ring_is_wired(controller.pendopo_nodes[1]):
		_fail("healing_changed is not connected to the second pendopo, so the ring would show on the wrong one")

	var king: Node3D = controller._king_controller
	king.queue_free()
	first.queue_free()
	controller.pendopo_nodes[1].queue_free()


func _test_destroyed_pendopo_releases_its_heal_ring() -> void:
	var first := _make_pendopo()
	var controller := _make_controller(first)
	controller._sync_objective_state()
	var second := _make_pendopo()
	controller.pendopo_nodes.append(second)
	controller._sync_objective_state()

	second.take_damage(99999.0)
	controller._on_pendopo_destroyed()

	if controller._heal_ring_is_wired(second):
		_fail("a destroyed pendopo is still connected to healing_changed")
	if not controller._heal_ring_is_wired(first):
		_fail("releasing the fallen pendopo also broke the surviving one's heal ring")

	var king: Node3D = controller._king_controller
	king.queue_free()
	first.queue_free()
