extends SceneTree

# The hub has to speak one language at a time.
#
# The section buttons used to be labelled "Gameplay / Main" -- both languages printed on
# the button at once -- instead of picking English or Indonesian from the language
# setting. These checks pin the labels to the active language, live-update them when the
# setting changes, and confirm the four section buttons wear the long button artwork.

var failures := 0
var _had_settings: bool = false
var _settings_backup: String = ""

const ENGLISH := ["Gameplay", "Hermitage", "Blacksmith", "Market", "Profile"]
const INDONESIAN := ["Main", "Pertapaan", "Pandai Besi", "Pasar", "Profil"]


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
	await _check_hub()

	if failures > 0:
		push_error("Hub language regression (%d failures)" % failures)
		_restore()
		quit(1)
		return
	print("HUB_LANGUAGE_PASS")
	_restore()
	quit(0)


func _check_hub() -> void:
	var tm = root.get_node("/root/TranslationManager")
	_backup_settings(tm)
	_set_language(tm, "en")

	var track: Control = load("res://scenes/hub/LevelTrack.gd").new()
	root.add_child(track)
	await process_frame
	await process_frame

	var labels := _labels(track)
	_check("hub built every button", labels.size() == 5)

	_check_labels("English", labels, ENGLISH)
	_check_no_slashes("English", labels)
	_check_long_button_art(track)
	# The lives caption sits above the strips in the top bar, so it follows the
	# language setting like every other label on this screen.
	_check("English life prefix", _prefix_text(track) == tm.t("hud_lives_prefix"))
	_check_stage_confirmation(track, tm, "en")

	# Switching language has to relabel the open hub, not just the next one built.
	_set_language(tm, "id")
	await process_frame
	await process_frame
	_check_stage_confirmation(track, tm, "id")

	labels = _labels(track)
	_check_labels("Indonesian", labels, INDONESIAN)
	_check_no_slashes("Indonesian", labels)
	_check("Indonesian life prefix", _prefix_text(track) == tm.t("hud_lives_prefix"))

	_set_language(tm, "en")
	await process_frame
	_check_labels("back to English", _labels(track), ENGLISH)
	_check("life prefix back to English", _prefix_text(track) == tm.t("hud_lives_prefix"))

	track.queue_free()
	await process_frame


func _check_stage_confirmation(track: Control, tm: Node, language: String) -> void:
	track._show_stage_confirm(3)
	var overlay := track.get_window().get_node("ConfirmOverlay")
	var panel := overlay.get_node("ConfirmPanel") as Control
	_check(
		"%s stage confirmation is centered" % language,
		(panel.get_global_rect().get_center()
			- overlay.get_global_rect().get_center()).length() < 0.5
	)
	_check(
		"%s stage confirmation title is translated" % language,
		overlay.get_node("ConfirmPanel/ConfirmTitle").text == tm.t("play_stage_confirm") % 3
	)
	_check(
		"%s stage confirmation buttons are translated" % language,
		overlay.get_node("ConfirmPanel/ConfirmPlayButton").text == tm.t("play")
		and overlay.get_node("ConfirmPanel/ConfirmCancelButton").text == tm.t("cancel")
	)
	overlay.queue_free()


## The lives caption drawn before the icon strip. Empty means no such label.
func _prefix_text(node: Node) -> String:
	if node is Label and node.name == "LivesPrefix":
		return (node as Label).text
	for child in node.get_children():
		var hit := _prefix_text(child)
		if hit != "":
			return hit
	return ""


func _labels(track: Control) -> Dictionary:
	var found := {}
	for id: String in ["gameplay", "profile", "hermitage", "blacksmith", "market"]:
		var btn := track.get("_menu_buttons").get(id) as Button
		if btn != null:
			found[id] = btn.text
	return found


func _check_labels(lang: String, labels: Dictionary, expected: Array) -> void:
	var keys := ["gameplay", "hermitage", "blacksmith", "market", "profile"]
	for i in keys.size():
		var got: String = labels.get(keys[i], "<missing>")
		_check(
			"%s %s button reads '%s'" % [lang, keys[i], expected[i]],
			got == expected[i]
		)


func _check_no_slashes(lang: String, labels: Dictionary) -> void:
	for key: String in labels:
		_check(
			"%s %s button is not bilingual" % [lang, key],
			not (labels[key] as String).contains("/")
		)


func _check_long_button_art(track: Control) -> void:
	for id: String in ["gameplay", "profile", "hermitage", "blacksmith", "market"]:
		var btn := track.get("_menu_buttons").get(id) as Button
		if btn == null:
			_check("%s button exists" % id, false)
			continue
		var style := btn.get_theme_stylebox("normal") as StyleBoxTexture
		var path: String = style.texture.resource_path if style != null and style.texture != null else ""
		_check("%s button uses long_button.png" % id, path.get_file() == "long_button.png")


func _set_language(tm: Node, lang: String) -> void:
	# switch_language() toggles, so walk it rather than poking the field and reloading
	# the string table by hand.
	var guard := 0
	while tm.current_language != lang and guard < 4:
		tm.switch_language()
		guard += 1


func _backup_settings(tm: Node) -> void:
	_had_settings = FileAccess.file_exists(tm.SETTINGS_FILE)
	if _had_settings:
		var f := FileAccess.open(tm.SETTINGS_FILE, FileAccess.READ)
		_settings_backup = f.get_as_text()
		f.close()


func _restore() -> void:
	var tm = root.get_node("/root/TranslationManager")
	if _had_settings:
		var f := FileAccess.open(tm.SETTINGS_FILE, FileAccess.WRITE)
		f.store_string(_settings_backup)
		f.close()
	else:
		DirAccess.remove_absolute(tm.SETTINGS_FILE)
	_set_language(tm, "en")