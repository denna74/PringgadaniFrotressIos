extends SceneTree

# The hub's lives used to be a Label full of heart glyphs ("❤❤🖤"), which is a text
# symbol, not an icon -- and it cannot animate, so a flame could never live there.
#
# The slot now holds one TextureRect per life: an animated blue flame while the life is
# held, and the skull art for one that has been spent. These checks pin the whole shape
# of that: how many slots, what plays in each one, and that no heart glyph is left
# anywhere in the top bar.

var failures := 0

const FIRE_FRAME_COUNT := 19
const SKULL_FILE := "head-skull.png"


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
	var sm = root.get_node("/root/SaveManager")
	var save_backup := _backup_save()
	var lives_backup: int = sm.lives

	await _check_all_lives_hold_a_flame(sm)
	await _check_spent_life_shows_skull(sm)

	# Restore the player's real lives before writing anything back.
	sm.lives = lives_backup
	sm.lives_changed.emit(sm.lives)
	await _check_no_heart_glyphs_left()

	_restore_save(save_backup)

	if failures > 0:
		push_error("Lives icon regression (%d failures)" % failures)
		quit(1)
		return
	print("LIVES_ICONS_PASS")
	quit(0)


func _instantiate_track() -> Control:
	var track: Control = load("res://scenes/hub/LevelTrack.tscn").instantiate()
	root.add_child(track)
	return track


func _lives_slot(track: Control) -> Container:
	# The slot sits in the top bar's hbox, named so tests and future code can find it
	# without poking at texture state.
	var found: Container = _find_by_name(track, "LivesIcons")
	return found


func _find_by_name(node: Node, want: String) -> Node:
	if node.name == want:
		return node
	for child in node.get_children():
		var hit := _find_by_name(child, want)
		if hit != null:
			return hit
	return null


func _check_all_lives_hold_a_flame(sm: Node) -> void:
	sm.lives = sm.max_lives
	var track := _instantiate_track()
	await process_frame
	await process_frame

	var slot := _lives_slot(track)
	_check("lives slot present", slot != null)
	if slot == null:
		track.queue_free()
		await process_frame
		return

	# The strip is placed on the bar by its own constant, like the bar's other readouts,
	# rather than riding along after the caption.
	var holder := slot.get_parent()
	_check(
		"the strip hangs off the top bar",
		holder != null and holder.name == "TopBar"
	)

	var kids := slot.get_children()
	_check(
		"one slot per life (%d)" % sm.max_lives,
		kids.size() == sm.max_lives
	)

	var flames := 0
	for child in kids:
		if not child is TextureRect:
			_check("slot %s is a TextureRect" % child.name, false)
			continue
		_check(
			"%s sits out of touch input" % child.name,
			(child as TextureRect).mouse_filter == Control.MOUSE_FILTER_IGNORE
		)
		var tex := (child as TextureRect).texture
		if tex is AnimatedTexture:
			flames += 1
			var anim := tex as AnimatedTexture
			_check("flame plays every frame", anim.frames == FIRE_FRAME_COUNT)
			# AnimatedTexture loops unless one_shot is set, and timing lives per frame.
			_check("flame repeats", not anim.one_shot)
			_check(
				"flame runs at gif speed",
				absf(anim.get_frame_duration(0) - 1.0 / 10.0) < 0.001
			)
		else:
			_check(
				"held life %s plays the flame, not %s" % [child.name, str(tex)],
				false
			)

	_check("every held life shows the flame", flames == sm.max_lives)

	track.queue_free()
	await process_frame


func _check_spent_life_shows_skull(sm: Node) -> void:
	sm.lives = sm.max_lives
	var track := _instantiate_track()
	await process_frame
	await process_frame

	var slot := _lives_slot(track)
	if slot == null:
		_check("lives slot present for spend", false)
		track.queue_free()
		await process_frame
		return

	# Spend one life the way the game does, so the rebuild path is what we exercise.
	sm.lives = sm.max_lives - 1
	sm.lives_changed.emit(sm.lives)
	await process_frame
	await process_frame

	var kids := slot.get_children()
	_check("slot count survives a spend", kids.size() == sm.max_lives)

	var spent_shown := 0
	for i in kids.size():
		var rect := kids[i] as TextureRect
		if rect == null:
			continue
		var tex := rect.texture
		var held: bool = i < sm.lives
		if held:
			_check("held life %d still burns" % i, tex is AnimatedTexture)
		else:
			var path: String = tex.resource_path if tex != null else ""
			_check(
				"spent life %d shows %s" % [i, SKULL_FILE],
				path.get_file() == SKULL_FILE
			)
			spent_shown += 1

	_check("spent slot renders the skull", spent_shown == 1)

	track.queue_free()
	await process_frame


func _check_no_heart_glyphs_left() -> void:
	var track := _instantiate_track()
	await process_frame
	await process_frame

	var glyphs := 0
	for label in _all_labels(track):
		if (label as Label).text.contains("❤") or (label as Label).text.contains("🖤"):
			glyphs += 1
	_check("no heart glyph survives in the top bar", glyphs == 0)

	track.queue_free()
	await process_frame


func _all_labels(node: Node) -> Array:
	var found: Array = []
	if node is Label:
		found.append(node)
	for child in node.get_children():
		found.append_array(_all_labels(child))
	return found


func _backup_save() -> Dictionary:
	var sm = root.get_node("/root/SaveManager")
	if not FileAccess.file_exists(sm.save_path):
		return {"exists": false}
	var f := FileAccess.open(sm.save_path, FileAccess.READ)
	var text: String = f.get_as_text()
	f.close()
	return {"exists": true, "data": text}


func _restore_save(backup: Dictionary) -> void:
	var sm = root.get_node("/root/SaveManager")
	if backup.get("exists", false):
		var f := FileAccess.open(sm.save_path, FileAccess.WRITE)
		f.store_string(backup["data"])
		f.close()
	else:
		DirAccess.remove_absolute(sm.save_path)
	sm.load_game()
