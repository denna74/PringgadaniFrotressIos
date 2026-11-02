extends SceneTree

# Auto-generated mesh LODs corrupt skinned meshes (Godot #106393 / #84479): the reduced
# mesh is built from rest-pose bind data, so once it is picked the character renders as a
# broken, twisted body -- exactly what the King does while moving. The engine docs call out
# skinned rigs specifically as unsafe for LOD generation. Skinned rigs must therefore import
# with meshes/generate_lods=false and keep their full-resolution mesh for animation. Static
# props (buildings, plot tiles) are safe and keep LODs enabled.

const RIG_DIRS: Array[String] = [
	"res://assets/models/king",
	"res://assets/models/enemy",
	"res://assets/models/enemy_archer",
	"res://assets/models/soldier",
	"res://assets/models/soldier_archer",
	"res://assets/models/boss",
]
const RIG_EXTRA: Array[String] = ["res://assets/models/gatotkaca_stand.glb"]
const STATIC_DIRS: Array[String] = ["res://assets/models/buildings", "res://assets/models/3D_tiles"]


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame

	var failures: Array[String] = []
	var rigs := _collect(RIG_DIRS, RIG_EXTRA)
	var statics := _collect(STATIC_DIRS, [] as Array[String])

	if rigs.is_empty() or statics.is_empty():
		failures.append("model survey found %d rigs / %d static props -- discovery is broken" % [rigs.size(), statics.size()])

	for glb: String in rigs:
		failures.append_array(_expect_lods(glb, false))
	for glb: String in statics:
		failures.append_array(_expect_lods(glb, true))

	if failures.is_empty():
		print("SKINNED_LODS_PASS (%d rigs, %d static)" % [rigs.size(), statics.size()])
		quit(0)
		return
	for f in failures:
		push_error("MESH LOD REGRESSION: " + f)
	quit(1)


func _collect(dirs: Array[String], extra: Array[String]) -> Array[String]:
	var out: Array[String] = []
	for d: String in dirs:
		for f: String in _walk(d):
			if f.ends_with(".glb"):
				out.append(f)
	for g: String in extra:
		if FileAccess.file_exists(g):
			out.append(g)
	return out


func _expect_lods(glb_path: String, want: bool) -> Array[String]:
	var failures: Array[String] = []
	var import_path := glb_path + ".import"
	if not FileAccess.file_exists(import_path):
		failures.append("missing import file for " + glb_path)
		return failures
	var got := _read_generate_lods(import_path)
	if got != want:
		failures.append("%s has meshes/generate_lods=%s (want %s)" % [glb_path, str(got), str(want)])
	return failures


func _read_generate_lods(import_path: String) -> Variant:
	var file := FileAccess.open(import_path, FileAccess.READ)
	if file == null:
		return null
	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		if line.begins_with("meshes/generate_lods="):
			return line.split("=")[1].to_lower() == "true"
	return null


func _walk(dir_path: String) -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return out
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		var full := dir_path.path_join(name)
		if dir.current_is_dir():
			out.append_array(_walk(full))
		else:
			out.append(full)
		name = dir.get_next()
	dir.list_dir_end()
	return out
