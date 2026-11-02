extends SceneTree

# The king's 3D model used to be built lazily inside the Profile page, so the first click
# into Profile stalled while the model loaded, uploaded to the GPU and compiled its shader.
# It now lives in a shared KingModelPanel that the hub always shows. These checks pin the
# panel as the single owner of the hero viewport and confirm the hub hosts it.

var failures := 0


func _initialize() -> void:
	_run()


func _check(name: String, cond: bool) -> void:
	if cond:
		print("OK  ", name)
	else:
		push_error("FAIL " + name)
		failures += 1


func _find_subviewport(node: Node) -> SubViewport:
	if node is SubViewport:
		return node
	for child in node.get_children():
		var result: SubViewport = _find_subviewport(child)
		if result != null:
			return result
	return null


func _run() -> void:
	await process_frame

	var panel_script: GDScript = load("res://scenes/hub/KingModelPanel.gd")
	_check("KingModelPanel script loads", panel_script != null)

	var panel: Control = panel_script.new()
	root.add_child(panel)
	await process_frame
	var viewport := _find_subviewport(panel)
	_check("KingModelPanel builds its 3D hero viewport", viewport is SubViewport)
	if viewport != null:
		_check("visible hero viewport force-renders",
			viewport.render_target_update_mode == SubViewport.UPDATE_ALWAYS)
		panel.visible = false
		await process_frame
		_check("hidden hero viewport stops rendering",
			viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED)
		panel.visible = true
		await process_frame
		_check("re-shown hero viewport resumes rendering",
			viewport.render_target_update_mode == SubViewport.UPDATE_ALWAYS)
	panel.queue_free()
	await process_frame

	var hub_src := FileAccess.get_file_as_string("res://scenes/hub/LevelTrack.gd")
	_check("hub builds a KingModelPanel", hub_src.contains("KingModelPanel"))
	var profile_src := FileAccess.get_file_as_string("res://scenes/hub/ProfilePage.gd")
	_check("ProfilePage no longer builds the model", not profile_src.contains("build_model_viewport"))

	if failures > 0:
		push_error("King model panel regression (%d failures)" % failures)
		quit(1)
		return
	print("PROFILE_PREWARM_PASS")
	quit(0)
