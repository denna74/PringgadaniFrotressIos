extends SceneTree

var failures := 0
var PNG_SIGNATURE := PackedByteArray([137, 80, 78, 71, 13, 10, 26, 10])
const IMAGE_PATHS := [
	"res://assets/sprites/story_pages/1.png",
	"res://assets/sprites/story_pages/2.png",
	"res://assets/sprites/story_pages/3.png",
	"res://assets/sprites/story_pages/4.png",
	"res://assets/sprites/story_pages/5.png",
	"res://assets/sprites/story_pages/6.png",
	"res://assets/sprites/story_pages/7.png",
	"res://assets/sprites/story_pages/8.png",
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
	for path: String in IMAGE_PATHS:
		_check("%s exists" % path, FileAccess.file_exists(path))
		var f := FileAccess.open(path, FileAccess.READ)
		_check("%s is real PNG" % path, f != null and f.get_buffer(8) == PNG_SIGNATURE)
		var tex := load(path) as Texture2D
		_check("%s loads as texture" % path, tex != null)
		if tex != null:
			_check("%s is 944px wide" % path, tex.get_width() == 944)
			_check("%s is about 1135px tall" % path, abs(tex.get_height() - 1135) <= 1)

	for lang in ["en", "id"]:
		var data: Dictionary = JSON.parse_string(
			FileAccess.get_file_as_string("res://resources/strings/strings_%s.json" % lang)
		)
		for key in [
			"prev", "next", "finish", "page_indicator", "story_text_placeholder",
			"build_menu_title", "build_not_enough_gold", "potions_title", "building_level",
			"building_damage", "building_hp", "cancel", "close",
		]:
			_check("%s has %s" % [lang, key], data.has(key))
		for i in range(1, 9):
			var story_key := "story_page_%d" % i
			_check("%s has %s" % [lang, story_key], data.has(story_key))
			_check("%s has text for %s" % [lang, story_key], not data[story_key].is_empty())

	if failures > 0:
		push_error("Story assets regression")
		quit(1)
	else:
		print("STORY_ASSETS_PASS")
		quit(0)
