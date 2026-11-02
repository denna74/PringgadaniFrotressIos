extends SceneTree

# Layout lives in hand-tuned constants (see LevelTrack's TOP_* positions), and positions are
# deliberately adjustable, so this does not assert where anything sits. What it does pin is
# mechanism: the main menu button exists on the bar, is wired to the scene switch, and wears
# the shared long-button artwork instead of a bare box.

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

	var top_panel: Control = null
	for child in track.get_children():
		if child is Control and child.name == "TopBar":
			top_panel = child
			break
	if top_panel == null:
		for child in track.get_children():
			if child is TextureRect:
				top_panel = child
				break

	if top_panel == null:
		push_error("FAIL top bar panel not found")
		quit(1)
		return

	var tm = root.get_node("/root/TranslationManager")
	var menu_btn: Button = null
	for child in top_panel.get_children():
		if child is Button and (child as Button).text == tm.t("hub_main_menu"):
			menu_btn = child

	_check("main menu button present", menu_btn != null)
	_check("main menu wired", menu_btn != null and menu_btn.pressed.get_connections().size() > 0)

	var menu_style: StyleBoxTexture = null
	if menu_btn != null:
		menu_style = menu_btn.get_theme_stylebox("normal") as StyleBoxTexture
	var menu_path: String = (
		menu_style.texture.resource_path if menu_style != null and menu_style.texture != null else ""
	)
	_check("main menu uses long_button art", menu_path.get_file() == "long_button.png")

	track.queue_free()
	await process_frame
	if failures > 0:
		push_error("LevelTrack top bar regression")
		quit(1)
	else:
		print("LEVELTRACK_TOPBAR_PASS")
		quit(0)
