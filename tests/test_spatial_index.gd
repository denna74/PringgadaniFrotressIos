extends SceneTree

# SpatialIndex is a pure logic class, so it gets a fresh instance rather than the
# autoload singleton.

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
	_test_register_and_get_nearby()
	_test_get_nearby_wrong_group()
	_test_get_nearby_out_of_range()
	_test_unregister()
	_test_cell_migration()

	if failures > 0:
		push_error("SpatialIndex regression (%d failures)" % failures)
		quit(1)
		return
	print("SPATIAL_INDEX_PASS")
	quit(0)


func _make_index() -> Node:
	var si: Node = load("res://autoload/SpatialIndex.gd").new()
	si._cells.clear()
	si._unit_cells.clear()
	root.add_child(si)
	return si


func _make_node(pos: Vector3) -> Node3D:
	var node := Node3D.new()
	node.position = pos
	root.add_child(node)
	return node


func _test_register_and_get_nearby() -> void:
	var si: Node = _make_index()
	var node: Node3D = _make_node(Vector3(2, 0, 2))
	si.register(node, "troops")
	si.update()
	var nearby: Array = si.get_nearby(Vector3(0, 0, 0), 5.0, "troops")
	_check("registers and finds a nearby node", nearby.size() == 1 and nearby[0] == node)
	node.queue_free()
	si.queue_free()


func _test_get_nearby_wrong_group() -> void:
	var si: Node = _make_index()
	var node: Node3D = _make_node(Vector3(2, 0, 2))
	si.register(node, "troops")
	si.update()
	var nearby: Array = si.get_nearby(Vector3(0, 0, 0), 5.0, "enemies")
	_check("a troops node is not returned for an enemies query", nearby.size() == 0)
	node.queue_free()
	si.queue_free()


func _test_get_nearby_out_of_range() -> void:
	var si: Node = _make_index()
	var node: Node3D = _make_node(Vector3(20, 0, 20))
	si.register(node, "troops")
	si.update()
	var nearby: Array = si.get_nearby(Vector3(0, 0, 0), 5.0, "troops")
	_check("a node beyond the radius is not returned", nearby.size() == 0)
	node.queue_free()
	si.queue_free()


func _test_unregister() -> void:
	var si: Node = _make_index()
	var node: Node3D = _make_node(Vector3(2, 0, 2))
	si.register(node, "troops")
	si.update()
	si.unregister(node)
	si.update()
	var nearby: Array = si.get_nearby(Vector3(0, 0, 0), 5.0, "troops")
	_check("an unregistered node disappears", nearby.size() == 0)
	node.queue_free()
	si.queue_free()


func _test_cell_migration() -> void:
	var si: Node = _make_index()
	var node: Node3D = _make_node(Vector3(2, 0, 2))
	si.register(node, "troops")
	si.update()
	node.position = Vector3(10, 0, 10)
	si.update()
	var nearby: Array = si.get_nearby(Vector3(10, 0, 10), 5.0, "troops")
	_check("a node that moves is re-bucketed into its new cell",
		nearby.size() == 1 and nearby[0] == node)
	var stale: Array = si.get_nearby(Vector3(0, 0, 0), 5.0, "troops")
	_check("the old cell no longer returns the moved node", stale.size() == 0)
	node.queue_free()
	si.queue_free()
