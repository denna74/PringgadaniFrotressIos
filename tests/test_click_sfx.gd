extends SceneTree

# Button feedback is split by screen: the main menu and its settings dialog use select_1,
# the story/hub screens use select_3, destructive or dismissive controls use select_4,
# and starting a stage uses start. These checks prove the shipped streams load, that each
# ClickPlayer entry point selects the right one, and that every screen wires the intended
# entry point instead of the old silent generic call.

var failures := 0

const AUDIO_PATHS := {
	"select_1": "res://assets/sfx/select_1.mp3",
	"select_3": "res://assets/sfx/select_3.mp3",
	"select_4": "res://assets/sfx/select_4.mp3",
	"start": "res://assets/sfx/start.mp3",
}

const METHOD_ROUTES := [
	["play_select_1", "select_1"],
	["play_select_3", "select_3"],
	["play_select_4", "select_4"],
	["play_start", "start"],
]

# [script, function, required source fragment, minimum occurrences]
const SOURCE_ROUTES := [
	["res://scenes/menu/MainMenu.gd", "_on_story_pressed", "ClickPlayer.play_select_1()", 1],
	["res://scenes/menu/MainMenu.gd", "_on_play_pressed", "ClickPlayer.play_select_1()", 1],
	["res://scenes/menu/MainMenu.gd", "_on_settings_pressed", "ClickPlayer.play_select_1()", 1],
	["res://scenes/menu/SettingsPopup.gd", "_build_ui", "ClickPlayer.play_select_1", 3],
	["res://scenes/menu/SettingsPopup.gd", "_on_sfx_changed", "ClickPlayer.play_select_1()", 1],
	["res://scenes/menu/StoryPage.gd", "_make_button", "ClickPlayer.play_select_3", 1],
	["res://scenes/menu/StoryPage.gd", "_make_button", "ClickPlayer.play_select_4", 1],
	["res://scenes/hub/LevelTrack.gd", "_setup_top_bar", "ClickPlayer.play_select_3", 1],
	["res://scenes/hub/LevelTrack.gd", "_build_instant_btn", "ClickPlayer.play_select_3", 1],
	["res://scenes/hub/LevelTrack.gd", "_show_life_popup", "ClickPlayer.play_select_3", 1],
	["res://scenes/hub/LevelTrack.gd", "_show_life_popup", "ClickPlayer.play_select_4", 1],
	["res://scenes/hub/LevelTrack.gd", "_show_gold_popup", "ClickPlayer.play_select_3", 1],
	["res://scenes/hub/LevelTrack.gd", "_show_gold_popup", "ClickPlayer.play_select_4", 1],
	["res://scenes/hub/LevelTrack.gd", "_setup_left_menu", "ClickPlayer.play_select_3", 1],
	["res://scenes/hub/LevelTrack.gd", "_make_stage_button", "ClickPlayer.play_select_3", 1],
	["res://scenes/hub/LevelTrack.gd", "_show_stage_confirm", "ClickPlayer.play_start", 1],
	["res://scenes/hub/LevelTrack.gd", "_show_stage_confirm", "ClickPlayer.play_select_4", 1],
	["res://scenes/hub/LevelTrack.gd", "_show_no_lives", "ClickPlayer.play_select_4", 1],
	["res://scenes/hub/MarketPage.gd", "_build_item_row", "ClickPlayer.play_select_3", 1],
	["res://scenes/hub/MarketPage.gd", "_show_buy_confirm", "ClickPlayer.play_select_3", 3],
	["res://scenes/hub/MarketPage.gd", "_show_buy_confirm", "ClickPlayer.play_select_4", 1],
	["res://scenes/hub/HermitagePage.gd", "_build_upgrade", "ClickPlayer.play_select_3", 1],
	["res://scenes/hub/HermitagePage.gd", "_show_upgrade_confirm", "ClickPlayer.play_select_3", 1],
	["res://scenes/hub/HermitagePage.gd", "_show_upgrade_confirm", "ClickPlayer.play_select_4", 1],
	["res://scenes/hub/ProfilePage.gd", "_build_slot", "ClickPlayer.play_select_3", 1],
	["res://scenes/hub/ProfilePage.gd", "_show_equip_picker", "ClickPlayer.play_select_3", 1],
	["res://scenes/hub/ProfilePage.gd", "_show_equip_picker", "ClickPlayer.play_select_4", 1],
	["res://scenes/hub/ProfilePage.gd", "_build_choice_button", "ClickPlayer.play_select_3", 1],
	["res://scenes/hub/BlacksmithPage.gd", "_setup_ui", "ClickPlayer.play_select_3", 1],
	["res://scenes/hub/BlacksmithPage.gd", "_build_item_card", "ClickPlayer.play_select_3", 2],
	["res://scenes/run/RunHUD.gd", "_build_top_bar", "ClickPlayer.play_select_4", 1],
	["res://scenes/run/PausePopup.gd", "_build", "ClickPlayer.play_select_3", 1],
	["res://scenes/run/PausePopup.gd", "_build", "ClickPlayer.play_select_4", 1],
	["res://scenes/run/RunController.gd", "_show_victory_notification", "ClickPlayer.play_select_3", 2],
	["res://scenes/run/RunController.gd", "_show_victory_notification", "ClickPlayer.play_select_4", 1],
	["res://scenes/run/RunController.gd", "_show_defeat_notification", "ClickPlayer.play_select_3", 1],
	["res://scenes/run/RunController.gd", "_show_defeat_notification", "ClickPlayer.play_select_4", 1],
	["res://scenes/run/PotionsPanel.gd", "_on_potions_pressed", "ClickPlayer.play_select_3", 1],
	["res://scenes/run/PotionsPanel.gd", "_open_popup", "ClickPlayer.play_select_4", 1],
	["res://scenes/run/PotionsPanel.gd", "_consume", "ClickPlayer.play_select_3", 1],
	["res://scenes/run/BuildingPlot.gd", "_show_build_popup", "ClickPlayer.play_select_4", 1],
	["res://scenes/buildings/Barak.gd", "_build_overlay", "ClickPlayer.play_select_3", 1],
	["res://scenes/buildings/Barak.gd", "_build_overlay", "ClickPlayer.play_select_4", 1],
]


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
	_check_audio_assets()
	_check_stream_methods()
	await _check_source_routes()
	_check_no_ambiguous_calls()

	if failures > 0:
		push_error("Click SFX regression (%d failures)" % failures)
		quit(1)
		return
	print("CLICK_SFX_PASS")
	quit(0)


func _check_audio_assets() -> void:
	for key in AUDIO_PATHS:
		var path: String = AUDIO_PATHS[key]
		_check("%s audio exists" % key, ResourceLoader.exists(path))
		_check("%s audio is an AudioStream" % key, load(path) is AudioStream)


func _check_stream_methods() -> void:
	var click = root.get_node("/root/ClickPlayer")
	var player: AudioStreamPlayer = click.player
	_check("ClickPlayer builds its audio player", player != null)
	if player == null:
		return
	for route: Array in METHOD_ROUTES:
		var method: String = route[0]
		var stream: AudioStream = load(AUDIO_PATHS[route[1]])
		click.call(method)
		_check("%s selects %s" % [method, route[1]], player.stream == stream)


func _check_source_routes() -> void:
	await process_frame
	var cache := {}
	for route: Array in SOURCE_ROUTES:
		var path: String = route[0]
		var function: String = route[1]
		var fragment: String = route[2]
		var minimum: int = route[3]
		if not cache.has(path):
			cache[path] = FileAccess.get_file_as_string(path)
		var source: String = cache[path]
		var body := _function_body(source, function)
		var count := _count(body, fragment)
		_check(
			"%s/%s uses %s" % [path.get_file(), function, fragment],
			count >= minimum
		)


func _check_no_ambiguous_calls() -> void:
	for path in _scan_scripts("res://scenes"):
		var source := FileAccess.get_file_as_string(path)
		_check(
			"%s names its click sound" % path,
			not source.contains("ClickPlayer.play()")
			and not source.contains("ClickPlayer.play)")
		)


func _function_body(source: String, function: String) -> String:
	var marker := "func " + function + "("
	var start := source.find(marker)
	if start == -1:
		return ""
	var next := source.find("\nfunc ", start + marker.length())
	if next == -1:
		return source.substr(start)
	return source.substr(start, next - start)


func _count(source: String, needle: String) -> int:
	var total := 0
	var from := 0
	while true:
		var at := source.find(needle, from)
		if at == -1:
			break
		total += 1
		from = at + needle.length()
	return total


func _scan_scripts(path: String) -> Array:
	var found: Array = []
	var dir := DirAccess.open(path)
	if dir == null:
		return found
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if name.begins_with("."):
			name = dir.get_next()
			continue
		var child := path.path_join(name)
		if dir.current_is_dir():
			found.append_array(_scan_scripts(child))
		elif name.ends_with(".gd"):
			found.append(child)
		name = dir.get_next()
	dir.list_dir_end()
	return found
