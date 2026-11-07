extends SceneTree

# The main menu's language button grew into a settings button that opens a popup holding
# language, background music and sound effect controls. These checks pin the whole loop:
# the menu builds the gear button, pressing it opens the popup, the sliders drive the
# audio managers, the language button toggles, and Cancel rewinds every setting.

var failures := 0
var _had_settings: bool = false
var _settings_backup: String = ""


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
	_backup_settings()
	await _check_menu()

	if failures > 0:
		push_error("Settings popup regression (%d failures)" % failures)
		_restore()
		quit(1)
		return
	print("SETTINGS_POPUP_PASS")
	_restore()
	quit(0)


func _check_menu() -> void:
	var music = root.get_node("/root/MusicManager")
	var sfx_mgr = root.get_node("/root/SFXManager")
	var tm = root.get_node("/root/TranslationManager")

	var menu: Control = load("res://scenes/menu/MainMenu.gd").new()
	root.add_child(menu)
	await process_frame
	await process_frame

	var settings_btn: Button = menu.get("_settings_btn")
	_check("main menu builds a settings button", settings_btn != null)
	_check("settings button reads the settings label", settings_btn.text == tm.t("settings"))

	var gear := _find_gear(settings_btn)
	_check("settings button shows the gear icon", gear != null and gear.texture != null)

	settings_btn.pressed.emit()
	await process_frame
	var popup: Control = menu.get("_settings_popup")
	_check("pressing the settings button opens the popup", is_instance_valid(popup))

	var lang_option: OptionButton = popup.get("_language_option")
	var bgm_slider: HSlider = popup.get("_bgm_slider")
	var sfx_slider: HSlider = popup.get("_sfx_slider")
	var save_btn: Button = popup.get("_save_btn")
	var cancel_btn: Button = popup.get("_cancel_btn")
	_check("popup has a language dropdown", lang_option != null)
	if lang_option == null:
		menu.queue_free()
		await process_frame
		return
	_check("language dropdown lists twelve languages", lang_option.item_count == 12)
	var langs: Array = tm.get_languages()
	var codes_match := true
	for i in mini(lang_option.item_count, langs.size()):
		codes_match = codes_match \
			and str(lang_option.get_item_metadata(i)) == str(langs[i]["code"])
	_check("language dropdown follows the catalogue order", codes_match)
	_check("language dropdown stays within its column",
		lang_option.get_combined_minimum_size().x <= 200)
	_check("language list is height-capped so it scrolls",
		lang_option.get_popup().max_size.y > 0)
	_check("language dropdown marks the current language",
		str(lang_option.get_item_metadata(lang_option.selected)) == tm.current_language)
	_check("popup has a background music slider", bgm_slider != null)
	_check("popup has a sound effect slider", sfx_slider != null)
	var pointer: Texture2D = load("res://assets/buttons/sound_pointer.png")
	_check("bgm slider uses the sound pointer", bgm_slider.get_theme_icon("grabber") == pointer)
	_check("sfx slider uses the sound pointer", sfx_slider.get_theme_icon("grabber") == pointer)
	_check("sound pointer is slightly larger than the default grabber", pointer.get_size() == Vector2(40, 40))
	var bgm_track: StyleBoxFlat = bgm_slider.get_theme_stylebox("slider")
	var sfx_track: StyleBoxFlat = sfx_slider.get_theme_stylebox("slider")
	var bgm_fill: StyleBoxFlat = bgm_slider.get_theme_stylebox("grabber_area")
	var sfx_fill: StyleBoxFlat = sfx_slider.get_theme_stylebox("grabber_area")
	_check("bgm slider fill is olive green and remainder is gray", bgm_fill.bg_color == Color(0.42, 0.50, 0.16) and bgm_track.bg_color == Color(0.35, 0.35, 0.35))
	_check("sfx slider fill is olive green and remainder is gray", sfx_fill.bg_color == Color(0.42, 0.50, 0.16) and sfx_track.bg_color == Color(0.35, 0.35, 0.35))
	_check("popup has save and cancel", save_btn != null and cancel_btn != null)

	var start_bgm: int = music.bgm_level
	var target_bgm: int = 1 if start_bgm != 1 else 0
	bgm_slider.value = target_bgm
	await process_frame
	_check("bgm slider sets MusicManager.bgm_level", music.bgm_level == target_bgm)
	var music_idx := AudioServer.get_bus_index("Music")
	_check("bgm at 0 mutes the Music bus", target_bgm != 0 or AudioServer.is_bus_mute(music_idx))

	var start_sfx: int = sfx_mgr.sfx_level
	var target_sfx: int = 1 if start_sfx != 1 else 0
	sfx_slider.value = target_sfx
	await process_frame
	_check("sfx slider sets SFXManager.sfx_level", sfx_mgr.sfx_level == target_sfx)

	var start_lang: String = tm.current_language
	var start_index: int = lang_option.selected
	var target_index: int = (start_index + 1) % lang_option.item_count
	lang_option.select(target_index)
	lang_option.item_selected.emit(target_index)
	await process_frame
	_check("choosing a language applies it",
		tm.current_language == str(lang_option.get_item_metadata(target_index)))
	_check("choosing a language updates the displayed selection",
		lang_option.selected == target_index)

	# Same-language selection must be harmless.
	lang_option.item_selected.emit(target_index)
	await process_frame
	_check("re-selecting the active language keeps it",
		tm.current_language == str(lang_option.get_item_metadata(target_index)))

	# A persisted code outside the catalogue must fall back to the first item.
	var saved_lang: String = tm.current_language
	tm.current_language = "xx"
	popup._select_current_language()
	_check("unknown persisted code falls back to English", lang_option.selected == 0)
	tm.current_language = saved_lang
	popup._select_current_language()

	# Cancel must rewind the displayed selection too, not just the translation.
	# The dictionary carries the value out of the closure.
	var rewound := {"selection": -1}
	popup.cancelled.connect(func() -> void:
		rewound["selection"] = lang_option.selected
	)

	cancel_btn.pressed.emit()
	await process_frame
	_check("cancel closes the popup", not is_instance_valid(popup))
	_check("cancel rewinds the language", tm.current_language == start_lang)
	_check("cancel rewinds the dropdown selection", rewound["selection"] == start_index)
	_check("cancel rewinds the bgm level", music.bgm_level == start_bgm)
	_check("cancel rewinds the sfx level", sfx_mgr.sfx_level == start_sfx)

	menu.queue_free()
	await process_frame


## The gear rides as a TextureRect child of the settings button.
func _find_gear(btn: Button) -> TextureRect:
	if btn == null:
		return null
	for child in btn.get_children():
		if child is TextureRect:
			return child
	return null


func _backup_settings() -> void:
	var tm = root.get_node("/root/TranslationManager")
	_had_settings = FileAccess.file_exists(tm.SETTINGS_FILE)
	if _had_settings:
		var f := FileAccess.open(tm.SETTINGS_FILE, FileAccess.READ)
		_settings_backup = f.get_as_text()
		f.close()


func _restore() -> void:
	var tm = root.get_node("/root/TranslationManager")
	var music = root.get_node("/root/MusicManager")
	var sfx_mgr = root.get_node("/root/SFXManager")
	if _had_settings:
		var f := FileAccess.open(tm.SETTINGS_FILE, FileAccess.WRITE)
		f.store_string(_settings_backup)
		f.close()
	else:
		DirAccess.remove_absolute(tm.SETTINGS_FILE)
	music.set_bgm_level(music.MAX_LEVEL)
	sfx_mgr.set_sfx_level(sfx_mgr.MAX_LEVEL)
