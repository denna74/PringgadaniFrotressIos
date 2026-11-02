extends SceneTree

var _fails: int = 0


func _initialize() -> void:
	_run()


func _check(name: String, ok: bool) -> void:
	if ok:
		print("OK  ", name)
	else:
		_fails += 1
		push_error("FAIL " + name)


func _run() -> void:
	await process_frame
	var controller: Node3D = load("res://scenes/run/RunController.gd").new()
	var near_pendopo := Node3D.new()
	near_pendopo.position = Vector3(0, 0, 0)
	var far_pendopo := Node3D.new()
	far_pendopo.position = Vector3(20, 0, 0)
	var first_soldier: Node3D = load("res://scenes/run/SoldierUnit.gd").new()
	first_soldier.position = Vector3(2, 0, 0)
	var second_soldier: Node3D = load("res://scenes/run/SoldierUnit.gd").new()
	second_soldier.position = Vector3(18, 0, 0)
	root.add_child(near_pendopo)
	root.add_child(far_pendopo)
	root.add_child(first_soldier)
	root.add_child(second_soldier)

	var pendopos: Array = controller.get("pendopo_nodes")
	pendopos.append_array([near_pendopo, far_pendopo])
	var soldiers: Array = controller.get("_soldier_units")
	soldiers.append_array([first_soldier, second_soldier])

	controller._guard_soldiers_at_nearest_pendopo()
	_check("each soldier is assigned to its nearest Pendopo",
		first_soldier.get("_formation_target") == near_pendopo
			and second_soldier.get("_formation_target") == far_pendopo)

	controller._gather_soldiers()
	_check("gather command resets both soldiers to Gatotkaca",
		first_soldier.get("_formation_target") == null
			and second_soldier.get("_formation_target") == null)

	first_soldier.queue_free()
	second_soldier.queue_free()
	near_pendopo.queue_free()
	far_pendopo.queue_free()
	await process_frame
	if _fails == 0:
		print("SOLDIER_COMMAND_PASS")
		quit(0)
	else:
		print("SOLDIER_COMMAND_FAIL: %d" % _fails)
		quit(1)
