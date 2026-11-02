extends SceneTree

var failures := 0


func _initialize() -> void:
	_run()


func _check(name: String, cond: bool) -> void:
	if cond:
		print("OK  ", name)
	else:
		push_error("FAIL " + name)
		failures += 1


func _find_button(node: Node, text: String) -> Button:
	if node is Button and (node as Button).text == text:
		return node
	for child in node.get_children():
		var found := _find_button(child, text)
		if found != null:
			return found
	return null


func _run() -> void:
	await process_frame
	var track: Control = load("res://scenes/hub/LevelTrack.tscn").instantiate()
	root.add_child(track)
	await process_frame

	var frame: TextureRect = null
	for child in track.get_children():
		if child is TextureRect and (child as Control).name == "MenuFrame":
			frame = child
			break

	_check("menu frame exists", frame != null)
	if frame == null:
		quit(1)
		return

	_check("menu frame has a texture", frame.texture != null)
	var path: String = frame.texture.resource_path if frame.texture != null else ""
	_check("menu frame uses the dialog-box art", path.get_file() == "menu_dialog_box.png")
	_check("menu frame ignores the mouse", frame.mouse_filter == Control.MOUSE_FILTER_IGNORE)
	_check("menu frame scales to its box", frame.stretch_mode == TextureRect.STRETCH_SCALE)

	# The buttons are children of the frame, so they always draw over it.
	var gameplay_btn := _find_button(track, root.get_node("/root/TranslationManager").t("hub_gameplay"))
	_check("gameplay menu button present", gameplay_btn != null)
	if gameplay_btn != null:
		_check("menu frame is the buttons' backing", frame.is_ancestor_of(gameplay_btn))

	# The old flat panel is gone: no ColorRect may sit in the left-menu region below the
	# top bar (the top bar itself is the only ColorRect and sits at y=0).
	var stray_panel := false
	for child in track.get_children():
		if child is ColorRect and (child as Control).position.y > 60.0:
			stray_panel = true
	_check("flat color panel removed", not stray_panel)

	track.queue_free()
	await process_frame
	if failures > 0:
		push_error("LevelTrack menu frame regression")
		quit(1)
	else:
		print("LEVELTRACK_MENU_FRAME_PASS")
		quit(0)
