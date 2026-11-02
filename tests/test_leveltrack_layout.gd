extends SceneTree

# The hub's right pane is split: the king's model in its own always-visible panel on the
# left, and the selected section in a content panel beside it. These checks pin the split
# geometry to the Profile page's old model and right-column coordinates, and confirm the
# king panel survives every section switch.

var failures := 0

const KING_PANEL_POSITION := Vector2(22, 18)
const KING_PANEL_SIZE := Vector2(320, 640)
const CONTENT_PANEL_POSITION := Vector2(320, 18)
const CONTENT_PANEL_SIZE := Vector2(532, 610)


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
	var track: Control = load("res://scenes/hub/LevelTrack.tscn").instantiate()
	root.add_child(track)
	await process_frame
	await process_frame

	var king = track.get("_king_panel")
	_check("king panel exists", king != null)
	if king == null:
		quit(1)
		return

	_check("king panel is a KingModelPanel", king is KingModelPanel)
	_check("king panel sits at the profile model spot", (king as Control).position == KING_PANEL_POSITION)
	_check("king panel keeps the profile model size", (king as Control).size == KING_PANEL_SIZE)
	_check("king panel is visible", (king as Control).visible)

	var layer = track.get("_page_layer")
	_check("page layer exists", layer != null)
	if layer != null:
		_check("page layer sits at the profile content spot", (layer as Control).position == CONTENT_PANEL_POSITION)
		_check("page layer keeps the profile content size", (layer as Control).size == CONTENT_PANEL_SIZE)

	var scroll: ScrollContainer = track.get("_stage_scroll")
	_check("stage scroll fills the content panel", scroll != null and scroll.size == CONTENT_PANEL_SIZE)

	# Walk every section: the king panel must stay on screen and each page must be a
	# child of the content layer at the content size.
	var buttons: Dictionary = track.get("_menu_buttons")
	for id: String in ["profile", "hermitage", "blacksmith", "market", "gameplay"]:
		(buttons[id] as Button).pressed.emit()
		await process_frame
		_check("king panel stays visible on %s" % id, (king as Control).visible and (king as Control).is_visible_in_tree())
		if id == "gameplay":
			continue
		var page = track.get("_pages").get(id)
		_check("%s page created" % id, page != null)
		if page != null:
			_check("%s page is in the content layer" % id, (page as Control).get_parent() == layer)
			_check("%s page fills the content panel" % id, (page as Control).size == CONTENT_PANEL_SIZE)

	track.queue_free()
	await process_frame
	if failures > 0:
		push_error("LevelTrack layout regression")
		quit(1)
	else:
		print("LEVELTRACK_LAYOUT_PASS")
		quit(0)
