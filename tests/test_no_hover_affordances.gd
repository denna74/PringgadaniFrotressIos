extends SceneTree

# This is a mobile game, so the UI must not repaint when a pointer rests on it.
#
# Stripping our own "hover" overrides is not enough on its own: Godot's default theme
# hands every Button a hover stylebox and a slightly brighter font_hover_color, so an
# otherwise untouched button still gains a panel and a paler label the moment a mouse
# touches it. On a touchscreen that never happens, which makes it dead weight here -- and
# on a desktop test build it looks like a stuck highlight.
#
# These checks therefore assert what a button *resolves to*, not whether we happened to
# set an override: the same artwork resting and hovered, hover text identical to resting
# text, and the default cursor. The pressed state stays, because that is the feedback a
# finger produces.

var failures := 0

## Only shipped UI counts. `tests/` is skipped on purpose: this file names the things it
## looks for, so scanning it would just find itself.
const SKIP_DIRS := ["android", "addons", "tests", ".godot"]


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
	await _check_button_builder()
	await _check_screens()
	await _check_no_cursor_plumbing()
	await _check_no_dead_hover_handlers()
	await _check_hand_built_buttons_mirror_their_label()

	if failures > 0:
		push_error("Hover repaints still reachable in the UI (%d failures)" % failures)
		quit(1)
		return
	print("NO_HOVER_AFFORDANCES_PASS")
	quit(0)


func _check_button_builder() -> void:
	var menu := ButtonBuilder.create_menu_button("Play", 120, 32)
	_check_hover_inert(menu, "ButtonBuilder.create_menu_button")
	var small := ButtonBuilder.create_small_button("Back", 120, 32)
	_check_hover_inert(small, "ButtonBuilder.create_small_button")
	_check(
		"small button text is yellow in normal and pressed states",
		small.get_theme_color("font_color").is_equal_approx(Color(1.0, 0.85, 0.2, 1.0))
		and small.get_theme_color("font_pressed_color").is_equal_approx(
			Color(1.0, 0.85, 0.2, 1.0)
		)
	)
	_check(
		"small button text stays yellow when disabled",
		small.get_theme_color("font_disabled_color").is_equal_approx(
			Color(1.0, 0.85, 0.2, 1.0)
		)
	)
	# A finger still needs to see that it landed.
	_check("menu button keeps pressed feedback", menu.has_theme_stylebox_override("pressed"))


func _check_screens() -> void:
	for spec: Array in [
		["res://scenes/hub/LevelTrack.gd", "LevelTrack"],
		["res://scenes/menu/MainMenu.gd", "MainMenu"],
		["res://scenes/menu/StoryPage.gd", "StoryPage"],
	]:
		var screen: Node = load(spec[0]).new()
		root.add_child(screen)
		await process_frame
		await process_frame

		var buttons := _all_buttons(screen)
		_check("%s builds buttons" % spec[1], buttons.size() > 0)
		for btn: Button in buttons:
			_check_hover_inert(btn, "%s/%s" % [spec[1], btn.name])

		screen.queue_free()
		await process_frame


func _check_hover_inert(btn: Button, where: String) -> void:
	# Button does not draw its normal box while hovered -- it *swaps* in the hover box.
	# So the answer to a resting pointer is "paint exactly what you were already
	# painting", not "paint nothing": an empty hover box makes the artwork disappear the
	# moment a pointer arrives, and a different box repainted on top is just a hover
	# effect wearing a different hat. Both count as a change.
	var resting_box := btn.get_theme_stylebox("normal")
	var hovered_box := btn.get_theme_stylebox("hover")
	_check(
		"%s paints the resting artwork on hover" % where,
		hovered_box == resting_box
	)
	# A brighter hover label is the same bug wearing different clothes.
	var resting := btn.get_theme_color("font_color")
	var hovered := btn.get_theme_color("font_hover_color")
	_check(
		"%s keeps its label colour on hover" % where,
		hovered.is_equal_approx(resting)
	)
	_check(
		"%s shows no pointer cursor" % where,
		btn.get_cursor_shape() == Control.CURSOR_ARROW
	)


func _all_buttons(node: Node) -> Array:
	var found: Array = []
	if node is Button:
		found.append(node)
	for child in node.get_children():
		found.append_array(_all_buttons(child))
	return found


## Cursor shapes only mean anything to a mouse, so the UI should not be asking for one.
## The theme covers every button's hover panel, but a theme cannot promise the label
## colour, which is mirrored per button instead. So any file that hand-builds a Button
## has to mirror the same number of them, or a button added later quietly picks the
## default theme's brighter hover text.
func _check_hand_built_buttons_mirror_their_label() -> void:
	for path: String in _scan_for("res://scenes", ".gd"):
		var source := FileAccess.get_file_as_string(path)
		var built := _count(source, "Button.new()")
		var mirrored := _count(source, "make_hover_inert")
		_check(
			"%s mirrors hover text for all %d hand-built buttons" % [path, built],
			mirrored >= built
		)


func _count(source: String, needle: String) -> int:
	var count := 0
	var from := 0
	while true:
		var at := source.find(needle, from)
		if at == -1:
			break
		count += 1
		from = at + needle.length()
	return count


func _check_no_cursor_plumbing() -> void:
	var offenders: Array[String] = []
	for path: String in _scan_for("res://", ".gd"):
		if "mouse_default_cursor_shape" in FileAccess.get_file_as_string(path):
			offenders.append(path)
	_check("no script sets a cursor shape", offenders.is_empty())
	for path in offenders:
		print("      cursor plumbing in ", path)


func _check_no_dead_hover_handlers() -> void:
	# _on_mouse_entered was never connected to anything, on any screen. Read the source
	# rather than instantiating: Barak's _init wants building arguments.
	var source := FileAccess.get_file_as_string("res://scenes/buildings/Barak.gd")
	_check("Barak source readable", not source.is_empty())
	_check("Barak has no orphaned _on_mouse_entered", not source.contains("_on_mouse_entered"))


func _scan_for(dir_path: String, suffix: String) -> Array:
	var out: Array = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return out
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if entry.begins_with("."):
			entry = dir.get_next()
			continue
		var full := dir_path.path_join(entry)
		if dir.current_is_dir():
			if not SKIP_DIRS.has(entry):
				out.append_array(_scan_for(full, suffix))
		elif entry.ends_with(suffix):
			out.append(full)
		entry = dir.get_next()
	dir.list_dir_end()
	return out
