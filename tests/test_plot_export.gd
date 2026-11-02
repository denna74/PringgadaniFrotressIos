extends SceneTree

# The building plot's marker is build_flag.glb. Whatever external textures that model needs
# must also be present in the Android export: the export preset used to strip
# build_flag_*.jpg while the GLB still referenced them, so plots silently vanished on
# device while the editor (reading straight from res://) kept showing them.
#
# This walks BuildingPlot's real visual assets -- the flag GLB and the dirt tile -- and
# fails if any of their external textures are listed in the Android preset's exclude_filter.

const BUILDING_PLOT_SCRIPT: String = "res://scenes/run/BuildingPlot.gd"
const FLAG_GLB: String = "res://assets/models/3D_tiles/build_flag_lite.glb"
const EXPORT_PRESETS: String = "res://export_presets.cfg"
const ANDROID_PRESET_NAME: String = "Android"


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame

	var failures: PackedStringArray = []

	var flag_textures := _collect_external_textures(FLAG_GLB)
	if flag_textures.is_empty():
		failures.append("no external textures found for the plot flag '%s'" % FLAG_GLB)

	var plot_textures := _collect_plot_textures()
	if plot_textures.is_empty():
		failures.append("could not enumerate the building plot's visual resources")

	var exclusions := _android_exclude_filter()
	if exclusions.is_empty():
		failures.append("no Android export preset or exclude filter found")

	var needed: Dictionary = {}
	for p: String in flag_textures:
		needed[p] = true
	for p: String in plot_textures:
		needed[p] = true

	for path: String in needed:
		if _is_excluded(path, exclusions):
			failures.append(
				"plot visual resource '%s' is stripped from the Android export; the plots will not render on device" % path
			)

	if failures.is_empty():
		print("PLOT_EXPORT_PASS")
		quit(0)
	else:
		for f in failures:
			push_error("PLOT EXPORT REGRESSION: " + f)
		quit(1)


# Loads a scene and returns every external resource path it depends on. This is the
# authoritative set: a PackedScene whose dependency is missing from the package can fail to
# load/instantiate as a whole, so every dependency must ship, not just the first material.
func _collect_external_textures(scene_path: String) -> PackedStringArray:
	var out: PackedStringArray = []
	for dep in ResourceLoader.get_dependencies(scene_path):
		var dep_str := str(dep)
		if dep_str.contains("::::"):
			var resolved := dep_str.split("::::")[-1]
			for part in resolved.split(","):
				if part.begins_with("res://"):
					out.append(part)
			continue
		if dep_str.begins_with("res://"):
			out.append(dep_str)
	return out


# Reads BuildingPlot's dirt tile path, mirroring _setup_visual(), so the plot's ground tile
# is covered by the same export check as its flag.
func _collect_plot_textures() -> PackedStringArray:
	var out: PackedStringArray = []
	var tile_paths := TerrainBuilder._get_mesh("dirt_center")
	if tile_paths == null:
		return out
	var theme: String = TileTheme.theme_for_stage(1)
	var tex_path := TileTheme.texture_path(theme, "dirt_center")
	if ResourceLoader.exists(tex_path):
		out.append(tex_path)
	var base_path: String = "res://assets/models/3D_tiles/dirt_center.glb"
	if ResourceLoader.exists(base_path):
		out.append(base_path)
	return out


func _android_exclude_filter() -> PackedStringArray:
	var out: PackedStringArray = []
	var cfg: ConfigFile = ConfigFile.new()
	if cfg.load(EXPORT_PRESETS) != OK:
		return out
	var section := ""
	for s: String in cfg.get_sections():
		if cfg.get_value(s, "name", "") == ANDROID_PRESET_NAME:
			section = s
			break
	if section == "":
		return out
	var value: String = cfg.get_value(section, "exclude_filter", "")
	for part in value.split(","):
		var trimmed := part.strip_edges()
		if trimmed != "":
			out.append(trimmed)
	return out


func _is_excluded(resource_path: String, exclusions: PackedStringArray) -> bool:
	var rel := resource_path.replace("res://", "")
	for excluded in exclusions:
		var e := excluded.replace("res://", "")
		if rel == e or rel.begins_with(e.rstrip("/") + "/"):
			return true
	return false