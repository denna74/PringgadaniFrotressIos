extends SceneTree

var failures: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var world := Node3D.new()
	root.add_child(world)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(0.0, 20.0, 20.0)
	camera.look_at(Vector3.ZERO, Vector3.UP)
	camera.make_current()
	await process_frame

	await ModelLoader.warmup_animations(world, 1)

	_check("warmup leaves only the camera in the scene", world.get_child_count() == 1)
	_check("warmup built the king template", ModelLoader._king_template != null)
	_check("warmup built infantry and archer templates",
		ModelLoader._soldier_templates.has("default")
			and ModelLoader._soldier_templates.has("archer"))
	_check("warmup built infantry and archer enemy templates",
		ModelLoader._enemy_templates.has("default")
			and ModelLoader._enemy_templates.has("archer"))
	_check("warmup built this stage's boss template",
		ModelLoader._boss_templates.has("kurawa"))

	_cleanup_templates()
	world.queue_free()
	await process_frame
	if failures == 0:
		print("ANIMATION_RENDER_WARMUP_PASS")
		quit(0)
	else:
		quit(1)


func _check(label: String, condition: bool) -> void:
	if condition:
		print("OK  ", label)
	else:
		failures += 1
		push_error("FAIL " + label)


func _cleanup_templates() -> void:
	for template: Node3D in ModelLoader._soldier_templates.values():
		template.free()
	ModelLoader._soldier_templates.clear()
	for template: Node3D in ModelLoader._enemy_templates.values():
		template.free()
	ModelLoader._enemy_templates.clear()
	for template: Node3D in ModelLoader._boss_templates.values():
		template.free()
	ModelLoader._boss_templates.clear()
	ModelLoader._king_template.free()
	ModelLoader._king_template = null
