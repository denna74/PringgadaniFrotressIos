extends SceneTree


const HEIGHT_TOLERANCE: float = 0.02


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var checks: Array[Array] = [
		["Gatotkaca", 1.72, func() -> Node3D: return ModelLoader.load_king()],
		["Friendly infantry", 1.53, func() -> Node3D: return ModelLoader.load_soldier("infantry")],
		["Friendly archer", 1.48, func() -> Node3D: return ModelLoader.load_soldier("archer")],
		["Enemy infantry", 1.53, func() -> Node3D: return ModelLoader.load_enemy("infantry")],
		["Enemy archer", 1.48, func() -> Node3D: return ModelLoader.load_enemy("archer")],
		["Kalapracona", 2.09, func() -> Node3D: return ModelLoader.load_boss("kurawa")],
		["Boma Narakasura", 1.72, func() -> Node3D: return ModelLoader.load_boss("boma")],
		["Aswatama", 1.72, func() -> Node3D: return ModelLoader.load_boss("aswatama")],
		["Karna", 1.72, func() -> Node3D: return ModelLoader.load_boss("karna")],
	]
	var failures := 0
	for entry: Array in checks:
		var model: Node3D = entry[2].call()
		root.add_child(model)
		await process_frame
		var height: float = _skeleton_height(model)
		if absf(height - float(entry[1])) > HEIGHT_TOLERANCE:
			push_error("%s height %.3fm, expected %.2fm" % [entry[0], height, entry[1]])
			failures += 1
		model.queue_free()
		await process_frame
	if failures == 0:
		print("CHARACTER_HEIGHTS_PASS")
		quit(0)
	else:
		quit(1)


func _skeleton_height(model: Node3D) -> float:
	for node: Node in model.find_children("*", "Skeleton3D", true, false):
		var skeleton := node as Skeleton3D
		var min_y := INF
		var max_y := -INF
		for i in skeleton.get_bone_count():
			var point: Vector3 = skeleton.global_transform * skeleton.get_bone_global_rest(i).origin
			min_y = minf(min_y, point.y)
			max_y = maxf(max_y, point.y)
		return max_y - min_y
	return 0.0
