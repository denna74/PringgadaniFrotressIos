extends SceneTree

var failures := 0


func _initialize() -> void:
	_run()


func _check(name: String, condition: bool) -> void:
	if condition:
		print("OK  ", name)
	else:
		push_error("FAIL " + name)
		failures += 1


func _run() -> void:
	await process_frame
	var loading_screen: CanvasLayer = load("res://scenes/run/LoadingScreen.tscn").instantiate()
	root.add_child(loading_screen)
	await process_frame

	var logo: AnimatedSprite2D = loading_screen.get_node("LogoSpin")
	_check("logo has sprite frames", logo.sprite_frames != null)
	if logo.sprite_frames != null:
		_check("logo spin has all 48 frames", logo.sprite_frames.get_frame_count("spin") == 48)
		_check("logo spin animation loops", logo.sprite_frames.get_animation_loop("spin"))
		_check("logo spin is playing", logo.is_playing())
		_check("logo first frame has a texture", logo.sprite_frames.get_frame_texture("spin", 0) != null)

	if failures > 0:
		push_error("Loading logo frames regression")
		quit(1)
	else:
		print("LOADING_LOGO_FRAMES_PASS")
		quit(0)
