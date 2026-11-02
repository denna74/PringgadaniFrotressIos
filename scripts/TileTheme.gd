class_name TileTheme extends RefCounted

const DEFAULT_THEME: String = "garden"
const THEMES_DIR: String = "res://assets/models/3D_tiles/themes/"
const RANDOM_THEMES: Array[String] = ["garden", "ocean", "lava", "sky"]


static func theme_for_stage(stage: int) -> String:
	if stage <= 10:
		return "garden"
	if stage <= 30:
		return "ocean"
	if stage <= 60:
		return "lava"
	if stage <= 90:
		return "sky"
	return RANDOM_THEMES[randi_range(0, RANDOM_THEMES.size() - 1)]


static func texture_path(theme: String, tile_name: String) -> String:
	var texture_name: String = tile_name
	if theme == "sky" and tile_name.begins_with("grass_"):
		texture_name = "cloud_" + tile_name.trim_prefix("grass_")
	return THEMES_DIR + theme + "/" + texture_name + ".png"
