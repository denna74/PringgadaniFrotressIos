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


func _run() -> void:
	await process_frame
	var track: Control = load("res://scenes/hub/LevelTrack.tscn").instantiate()
	root.add_child(track)
	await process_frame

	var bg: TextureRect = null
	for child in track.get_children():
		if child is TextureRect and (child as Control).name == "Background":
			bg = child
			break

	_check("background exists", bg != null)
	if bg == null:
		quit(1)
		return

	_check("background is behind everything", track.get_child(0) == bg)
	_check("background has a texture", bg.texture != null)
	_check("background covers the screen", bg.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_COVERED)
	_check("background ignores the mouse", bg.mouse_filter == Control.MOUSE_FILTER_IGNORE)
	_check("background fills the rect", is_equal_approx(bg.anchor_right, 1.0) and is_equal_approx(bg.anchor_bottom, 1.0))

	var video: VideoStreamPlayer = null
	for child in track.get_children():
		if child is VideoStreamPlayer:
			video = child
	_check("background video player present", video != null)
	_check("background video loops", video != null and video.loop)
	_check("background video stream set", video != null and video.stream != null)

	track.queue_free()
	await process_frame
	if failures > 0:
		push_error("LevelTrack background regression")
		quit(1)
	else:
		print("LEVELTRACK_BACKGROUND_PASS")
		quit(0)
