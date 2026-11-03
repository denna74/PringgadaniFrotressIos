extends SceneTree

# How the stage track picks the artwork for each node.
#
# A cleared stage shows the rating it earned. The top unlocked stage shows the
# unplayed artwork. Everything past it is locked: the same unplayed artwork,
# greyed out and faded back. A stage cleared before ratings existed has no record
# to show, so it falls back to one star rather than pretending it was never played.

var failures := 0

## How far the number is dropped below the middle of its node.
const STAGE_TITLE_DROP := 10.0


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
	await _check_nodes()

	if failures > 0:
		push_error("Stage track nodes regression (%d failures)" % failures)
		quit(1)
		return
	print("STAGE_TRACK_NODES_PASS")
	quit(0)


func _check_nodes() -> void:
	var sm = root.get_node("/root/SaveManager")
	var stage_backup: int = sm.stage_number
	var stars_backup: Dictionary = sm.stage_stars.duplicate()
	var save_backup := _backup_save()

	sm.stage_number = 4
	sm.stage_stars = {"3": 3, "2": 1}
	sm.save_game()

	var track: Control = load("res://scenes/hub/LevelTrack.gd").new()
	root.add_child(track)
	await process_frame
	await process_frame

	var container: VBoxContainer = track.get("_stage_container")
	_check("stage container exists", container != null)
	if container == null:
		_restore(save_backup, stage_backup, stars_backup)
		track.queue_free()
		await process_frame
		return

	_check("stage nodes cover the unlocked range", container.get_child_count() == 6)

	_check_art(container, 6, "stage_locked.png", true)
	_check_art(container, 5, "stage_locked.png", true)
	_check_art(container, 4, "stage_incomplete.png", false)
	_check_art(container, 3, "stage_3_star.png", false)
	_check_art(container, 2, "stage_1_star.png", false)
	_check_art(container, 1, "stage_1_star.png", false)

	var current: Button = _node_for(container, 4)
	var cleared: Button = _node_for(container, 3)
	_check(
		"cleared nodes stay 160x135",
		cleared != null and cleared.custom_minimum_size == Vector2(160, 135)
	)
	# The top unlocked stage is drawn larger so it reads as where you are next. Both
	# sizes keep the star art's own aspect, or the artwork would letterbox.
	_check(
		"current node is bigger than a cleared one",
		current != null and cleared != null
			and current.custom_minimum_size.x > cleared.custom_minimum_size.x
	)
	_check(
		"current node keeps the artwork aspect",
		current != null and absf(
			current.custom_minimum_size.x / current.custom_minimum_size.y - 553.0 / 467.0
		) < 0.01
	)
	_check(
		"current node's number sits %.0fpx below centre (%.1f)" % [STAGE_TITLE_DROP, _title_offset(container, 4)],
		absf(_title_offset(container, 4) - STAGE_TITLE_DROP) <= 1.0
	)
	_check(
		"cleared node's number sits %.0fpx below centre (%.1f)" % [STAGE_TITLE_DROP, _title_offset(container, 3)],
		absf(_title_offset(container, 3) - STAGE_TITLE_DROP) <= 1.0
	)

	# The artwork already says what a node is, so the label is only the number.
	for stage: int in [1, 2, 3, 4, 5, 6]:
		_check(
			"stage %d is labelled just %d" % [stage, stage],
			_title_is_number_only(container, stage)
		)

	_check("no node shows a gold/wave estimate", _has_no_reward_line(container))

	var gap: float = _max_gap(container)
	_check("nodes are packed tighter (gap %.1f <= 8)" % gap, gap <= 8.0)

	var locked: Button = _node_for(container, 6)
	_check("locked node is disabled", locked != null and locked.disabled)

	track.queue_free()
	await process_frame

	_restore(save_backup, stage_backup, stars_backup)


func _node_for(container: VBoxContainer, stage: int) -> Button:
	for child in container.get_children():
		var btn := child as Button
		if btn != null and btn.name == "Stage%d" % stage:
			return btn
	return null


func _check_art(container: VBoxContainer, stage: int, file: String, faded: bool) -> void:
	var btn: Button = _node_for(container, stage)
	if btn == null:
		_check("stage %d node exists" % stage, false)
		return
	var art: TextureRect = btn.get_node_or_null("StageArt")
	if art == null:
		_check("stage %d has art" % stage, false)
		return

	var path: String = art.texture.resource_path if art.texture != null else ""
	_check(
		"stage %d shows %s" % [stage, file],
		path.get_file() == file
	)
	_check(
		"stage %d %s" % [stage, "is faded back" if faded else "is fully opaque"],
		art.modulate.a < 0.999 if faded else is_equal_approx(art.modulate.a, 1.0)
	)


func _title_is_number_only(container: VBoxContainer, stage: int) -> bool:
	var btn: Button = _node_for(container, stage)
	if btn == null:
		return false
	var title := btn.get_node_or_null("StageTitle") as Label
	if title == null:
		return false
	return title.text == str(stage)


# The lone number sits a little below the middle of the node, at the same drop whatever
# size that node is.
func _title_offset(container: VBoxContainer, stage: int) -> float:
	var btn: Button = _node_for(container, stage)
	if btn == null:
		return -999.0
	var title := btn.get_node_or_null("StageTitle") as Label
	if title == null:
		return -999.0
	var title_centre: float = title.position.y + title.size.y / 2.0
	return title_centre - btn.custom_minimum_size.y / 2.0


func _has_no_reward_line(container: VBoxContainer) -> bool:
	for child in container.get_children():
		for node in (child as Button).get_children():
			var label := node as Label
			if label != null and ("gold" in label.text or "wave" in label.text):
				return false
	return true


# The real rendered space between neighbouring nodes, so this measures the layout the
# player sees rather than the constant that was configured.
func _max_gap(container: VBoxContainer) -> float:
	var kids := container.get_children()
	var gap := 0.0
	for i in range(1, kids.size()):
		var above := kids[i - 1] as Control
		var below := kids[i] as Control
		gap = maxf(gap, below.position.y - (above.position.y + above.size.y))
	return gap


func _backup_save() -> Dictionary:
	var sm = root.get_node("/root/SaveManager")
	if not FileAccess.file_exists(sm.save_path):
		return {"exists": false}
	var f := FileAccess.open(sm.save_path, FileAccess.READ)
	var text: String = f.get_as_text()
	f.close()
	return {"exists": true, "data": text}


func _restore(backup: Dictionary, stage_number: int, stars: Dictionary) -> void:
	var sm = root.get_node("/root/SaveManager")
	if backup.get("exists", false):
		var f := FileAccess.open(sm.save_path, FileAccess.WRITE)
		f.store_string(backup["data"])
		f.close()
	else:
		DirAccess.remove_absolute(sm.save_path)
	sm.stage_number = stage_number
	sm.stage_stars = stars
	sm.load_game()