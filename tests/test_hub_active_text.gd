extends SceneTree

# The hub's section buttons show which section is open by darkening their label to black
# on top of the highlighted artwork. Unselected buttons keep the cream label.
#
# These checks walk the selection around -- gameplay, profile, hermitage, blacksmith,
# market -- and confirm exactly one button is black at a time, and that the black one is
# always the open section.

var failures := 0

const BLACK := Color(0, 0, 0, 1)
const SECTIONS := ["gameplay", "profile", "hermitage", "blacksmith", "market"]


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
	await _check_selection()

	if failures > 0:
		push_error("Hub active-button text regressions (%d failures)" % failures)
		quit(1)
		return
	print("HUB_ACTIVE_TEXT_PASS")
	quit(0)


func _check_selection() -> void:
	var track: Control = load("res://scenes/hub/LevelTrack.gd").new()
	root.add_child(track)
	await process_frame
	await process_frame

	# Gameplay opens by default.
	_check_selected(track, "gameplay")
	_check_unselected(track, _others("gameplay"))

	for id: String in ["profile", "hermitage", "blacksmith", "market", "gameplay"]:
		# Go through the real button, not the handler, so the binding is covered too.
		(track.get("_menu_buttons")[id] as Button).pressed.emit()
		await process_frame
		_check_selected(track, id)
		_check_unselected(track, _others(id))

	# Profile is a normal section button now, not a separate card.
	_check("every section has a menu button", track.get("_menu_buttons").size() == SECTIONS.size())

	track.queue_free()
	await process_frame


func _others(id: String) -> Array:
	var ids: Array = []
	for other: String in SECTIONS:
		if other != id:
			ids.append(other)
	return ids


func _text_colour(track: Control, id: String) -> Color:
	return (track.get("_menu_buttons")[id] as Button).get_theme_color("font_color")


func _is_black(colour: Color) -> bool:
	return colour.r < 0.05 and colour.g < 0.05 and colour.b < 0.05


func _check_selected(track: Control, expected: String) -> void:
	for id: String in SECTIONS:
		var colour := _text_colour(track, id)
		_check(
			"%s label %s when it is the open section" % [
				"black" if id == expected else "not black", id
			],
			_is_black(colour) == (id == expected)
		)


func _check_unselected(track: Control, ids: Array) -> void:
	for id: String in ids:
		_check(
			"%s label is not black" % id,
			not _is_black(_text_colour(track, id))
		)
