extends SceneTree

var failures: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var initial_children: int = root.get_child_count()
	await ModelLoader.warmup_animations(root, 400)

	_check("warmup samples are removed", root.get_child_count() == initial_children)
	_check("king template is cached", ModelLoader._king_template != null)
	_check("infantry template is cached", ModelLoader._soldier_templates.has("default"))
	_check("archer template is cached", ModelLoader._soldier_templates.has("archer"))
	_check("enemy templates are cached",
		ModelLoader._enemy_templates.has("default")
			and ModelLoader._enemy_templates.has("archer"))
	_check("stage boss templates are cached",
		ModelLoader._boss_templates.has("kurawa")
			and ModelLoader._boss_templates.has("boma")
			and ModelLoader._boss_templates.has("aswatama")
			and ModelLoader._boss_templates.has("karna"))
	_cleanup_templates()

	if failures == 0:
		print("ANIMATION_WARMUP_PASS")
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
