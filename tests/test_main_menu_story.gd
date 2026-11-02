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
	var script := load("res://scenes/menu/MainMenu.gd") as GDScript
	_check("main menu script loads", script != null)
	if script == null:
		quit(1)
		return

	var constants: Dictionary = script.get_script_constant_map()
	_check(
		"story scene path",
		constants.get("STORY_SCENE_PATH") == "res://scenes/menu/StoryPage.tscn"
	)

	var menu: Control = script.new()
	menu.set("background_rect", Rect2(100, 50, 900, 600))
	root.add_child(menu)
	await process_frame
	await process_frame

	var background: TextureRect = menu.get("_bg_rect")
	_check(
		"background position and size are configurable",
		background != null
			and background.position == Vector2(100, 50)
			and background.size == Vector2(900, 600)
	)
	var story_btn: Button = menu.get("_story_btn")
	var play_btn: Button = menu.get("_play_btn")
	_check(
		"play button animation pivot is centered",
		play_btn != null and play_btn.pivot_offset == play_btn.size / 2
	)
	_check("story button exists", story_btn != null)
	_check("story button is wired", story_btn != null and story_btn.pressed.get_connections().size() > 0)
	_check("play button exists", play_btn != null)

	var src := FileAccess.get_file_as_string("res://scenes/menu/MainMenu.gd")
	_check("story handler uses the story scene", src.contains("SceneManager.go_to_scene(STORY_SCENE_PATH)"))
	_check("play handler keeps LevelTrack", src.contains("res://scenes/hub/LevelTrack.tscn"))

	menu.queue_free()
	await process_frame
	if failures > 0:
		push_error("Main menu story route regression")
		quit(1)
	else:
		print("MAIN_MENU_STORY_PASS")
		quit(0)
