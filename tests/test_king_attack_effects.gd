extends SceneTree

var ok := true


func _check(label: String, cond: bool) -> void:
	if cond:
		print("OK  ", label)
	else:
		push_error("FAIL: " + label)
		ok = false


func _slash_count(kc: Node3D) -> int:
	var n := 0
	for child in kc.get_children():
		if child.name == "ArcSlash":
			n += 1
	return n


func _last_child(kc: Node3D) -> Node:
	return kc.get_child(kc.get_child_count() - 1)


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame

	var kc: Node3D = load("res://scenes/run/KingController.tscn").instantiate()
	kc.position = Vector3(0, 0, 0)
	root.add_child(kc)
	for i in 20:
		await process_frame

	var before: int = _slash_count(kc)

	kc.attack()
	await process_frame
	_check("attack_1 spawns an ArcSlash", _slash_count(kc) == before + 1)
	var slash1: Node = _last_child(kc)
	if slash1.name == "ArcSlash":
		_check("attack_1 slash shows top-right -> bottom-left", bool(slash1.mirror))
	else:
		_check("attack_1 slash shows top-right -> bottom-left", false)
	if slash1 is Node:
		slash1.queue_free()
	await process_frame

	kc.attack()
	await process_frame
	_check("attack_2 spawns an ArcSlash", _slash_count(kc) == before + 1)
	var slash2: Node = _last_child(kc)
	if slash2.name == "ArcSlash":
		_check("attack_2 slash shows top-left -> bottom-right", not bool(slash2.mirror))
	else:
		_check("attack_2 slash shows top-left -> bottom-right", false)
	if slash2 is Node:
		slash2.queue_free()
	await process_frame

	kc.attack()
	await process_frame
	_check("attack_3 keeps the punch ring, no ArcSlash", _slash_count(kc) == before)
	_check("attack_3 punch ring exists", kc.get("_punch_ring") != null)

	if ok:
		print("KING_ATTACK_EFFECTS_PASS")
		quit(0)
	else:
		quit(1)