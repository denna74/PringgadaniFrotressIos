extends SceneTree

# Every language offered by the settings dropdown needs a catalogue entry, a
# native label, and a strings file that actually loads.

var failures := 0

const EXPECTED := [
	"en", "id", "jp", "es", "fr", "ko",
	"hi", "pt", "de", "it", "ar", "pl",
]
const LABELS := [
	"English", "Bahasa Indonesia", "日本語", "Español", "Français", "한국어",
	"हिन्दी", "Português", "Deutsch", "Italiano", "العربية", "Polski",
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
	var tm = root.get_node("/root/TranslationManager")
	if not tm.has_method("get_languages"):
		_check("TranslationManager exposes a language catalogue", false)
		quit(1)
		return
	var langs: Array = tm.get_languages()
	_check("catalogue lists twelve languages", langs.size() == EXPECTED.size())
	for i in mini(langs.size(), EXPECTED.size()):
		var entry: Dictionary = langs[i]
		_check("%s is at position %d" % [EXPECTED[i], i], entry.get("code") == EXPECTED[i])
		_check("%s label is %s" % [EXPECTED[i], LABELS[i]], entry.get("label") == LABELS[i])
		_check("%s strings file exists" % EXPECTED[i],
			FileAccess.file_exists("res://resources/strings/strings_%s.json" % EXPECTED[i]))
		_check("%s label lookup" % EXPECTED[i], tm.get_language_label(EXPECTED[i]) == LABELS[i])
	_check("unknown code falls back to English", tm.get_language_label("xx") == "English")
	if failures > 0:
		push_error("language catalogue regression")
		quit(1)
	else:
		print("LANGUAGE_CATALOGUE_PASS")
		quit(0)
