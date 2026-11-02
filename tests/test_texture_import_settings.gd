extends SceneTree

# Mobile memory guard for world textures. A texture that imports with Godot's defaults
# (compress/mode=0, process/size_limit=0) is uploaded to the GPU uncompressed and at full
# resolution -- a single 4096x4096 surface is 64 MB of VRAM. On a low-RAM phone that blows
# the loading screen's memory budget and the run never starts.
#
# Every external texture the plot flag and the building models depend on must therefore be
# imported VRAM-compressed (mode=2, i.e. ETC2/ASTC on mobile), downscaled (size_limit), and
# must not be auto-re-imported by the 3D detection hook (detect_3d/compress_to).

const FLAG_GLB: String = "res://assets/models/3D_tiles/build_flag_lite.glb"
const MAX_SIZE_LIMIT: int = 1024
const VRAM_COMPRESS_MODE: int = 2

func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame

	var failures: Array[String] = []
	var scenes: Array[String] = [FLAG_GLB]
	for building_id: String in ModelLoader.BUILDING_MODEL_PATHS:
		scenes.append(ModelLoader.BUILDING_MODEL_PATHS[building_id])

	var checked := 0
	for scene_path: String in scenes:
		for tex: String in _collect_textures(scene_path):
			if not _is_texture(tex):
				continue
			checked += 1
			failures.append_array(_check_texture(tex))

	if checked == 0:
		failures.append("no building/flag textures found to check -- dependency walk is broken")

	if failures.is_empty():
		print("TEXTURE_IMPORT_PASS (%d textures)" % checked)
		quit(0)
		return
	for f in failures:
		push_error("TEXTURE IMPORT REGRESSION: " + f)
	quit(1)


# Mirrors test_plot_export's dependency walk: a scene's external texture deps appear either
# as a plain res:// path or packed into a "::::"-joined list.
func _collect_textures(scene_path: String) -> PackedStringArray:
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


func _is_texture(path: String) -> bool:
	var lower := path.to_lower()
	return lower.ends_with(".jpg") or lower.ends_with(".jpeg") \
		or lower.ends_with(".png") or lower.ends_with(".webp")


func _check_texture(tex: String) -> Array[String]:
	var failures: Array[String] = []
	var import_path := tex + ".import"
	if not ResourceLoader.exists(import_path) and not FileAccess.file_exists(import_path):
		failures.append("no .import file for texture '%s'" % tex)
		return failures
	var cfg := ConfigFile.new()
	if cfg.load(import_path) != OK:
		failures.append("could not read import settings for '%s'" % tex)
		return failures
	var mode: int = int(cfg.get_value("params", "compress/mode", -1))
	var size_limit: int = int(cfg.get_value("params", "process/size_limit", -1))
	var detect_3d: int = int(cfg.get_value("params", "detect_3d/compress_to", -1))
	if mode != VRAM_COMPRESS_MODE:
		failures.append("'%s' compress/mode=%d (must be %d / VRAM compressed)" % [tex, mode, VRAM_COMPRESS_MODE])
	if size_limit <= 0 or size_limit > MAX_SIZE_LIMIT:
		failures.append("texture '%s' has process/size_limit=%d (must be 1..%d)" % [tex, size_limit, MAX_SIZE_LIMIT])
	if cfg.get_value("params", "detect_3d/compress_to", 1) != 0:
		failures.append("texture '%s' must set detect_3d/compress_to=0" % tex)
	return failures
