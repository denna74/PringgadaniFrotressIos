extends SceneTree

# Regression guard for godotengine/godot#121124: on Android, a threaded PackedScene load can
# intermittently stay THREAD_LOAD_IN_PROGRESS forever. Any code that polls
# ResourceLoader.load_threaded_get_status() in a loop will then hang the loading screen with
# no recovery. This was the cause of the run being stuck at "Loading soldier models...".
#
# Desktop and --headless runs never reproduce it, so no behavioural test can catch it here.
# The only reliable guard is to forbid the threaded-loader API in shipping code.

const DIRS: Array[String] = ["res://scripts", "res://scenes", "res://autoload"]

func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var hits: Array[String] = []
	for dir: String in DIRS:
		_scan(dir, hits)
	if hits.is_empty():
		print("NO_THREADED_LOAD_PASS")
		quit(0)
		return
	for h in hits:
		push_error("THREADED LOAD REGRESSION (godot#121124 hang on Android): " + h)
	quit(1)


func _scan(dir: String, hits: Array[String]) -> void:
	var da := DirAccess.open(dir)
	if da == null:
		return
	da.list_dir_begin()
	var f := da.get_next()
	while f != "":
		var p := dir.path_join(f)
		if da.current_is_dir():
			if not f.begins_with("."):
				_scan(p, hits)
		elif f.ends_with(".gd"):
			_check_file(p, hits)
		f = da.get_next()
	da.list_dir_end()


func _check_file(path: String, hits: Array[String]) -> void:
	var fa := FileAccess.open(path, FileAccess.READ)
	if fa == null:
		return
	var ln := 0
	while not fa.eof_reached():
		ln += 1
		var line := fa.get_line()
		if line.strip_edges().begins_with("#"):
			continue
		if line.contains("load_threaded_request("):
			hits.append("%s:%d" % [path, ln])
