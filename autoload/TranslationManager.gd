extends Node

signal language_changed(lang: String)

const SETTINGS_FILE := "user://settings.cfg"
const SECTION := "settings"

var current_language: String = "en"
var _strings: Dictionary = {}


func _ready() -> void:
	_load_config()
	_load_strings()


func t(key: String) -> String:
	return _strings.get(key, key)


# Item data carries an English `name` or `name_en` and an optional Indonesian `name_id`.
# Pick the one matching the active language, falling back to the English name.
func item_name(item: Dictionary) -> String:
	if current_language == "id":
		var id_name: String = item.get("name_id", "")
		if not id_name.is_empty():
			return id_name
	return item.get("name_en", item.get("name", ""))


func item_description(item: Dictionary) -> String:
	if current_language == "id":
		var id_description: String = item.get("description_id", "")
		if not id_description.is_empty():
			return id_description
	return item.get("description_en", item.get("description", ""))


func switch_language() -> void:
	set_language("id" if current_language == "en" else "en")


func set_language(lang: String) -> void:
	if current_language == lang:
		return
	current_language = lang
	_load_strings()
	_save_config()
	language_changed.emit(current_language)


func get_language_label() -> String:
	match current_language:
		"id": return "🇮🇩  Bahasa Indonesia"
		_: return "🇬🇧  English"


func _load_strings() -> void:
	var path := "res://resources/strings/strings_%s.json" % current_language
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		_strings = {}
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) == OK:
		_strings = json.data
	else:
		_strings = {}


func _load_config() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_FILE) == OK:
		current_language = config.get_value(SECTION, "language", "en")


func _save_config() -> void:
	var config := ConfigFile.new()
	config.load(SETTINGS_FILE)
	config.set_value(SECTION, "language", current_language)
	config.save(SETTINGS_FILE)
