extends SceneTree

# Tests used to run against the player's real save (user://pringgadani.save), writing
# intermediate mutated states that only got undone by each test's own restore. One
# interrupted test was enough to corrupt real progress. Tests now run in script mode
# (`-s`), where SaveManager must redirect to a throw-away file so the real save can
# never be touched.

var failures := 0

const REAL_SAVE := "user://pringgadani.save"


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
	var sm = root.get_node("/root/SaveManager")

	_check("tests do not use the real save path", str(sm.save_path) != REAL_SAVE)
	var test_path: String = sm.save_path
	_check("tests use a dedicated per-process test save",
		test_path.get_file().begins_with("pringgadani_test_")
			and test_path != REAL_SAVE)

	# Even an accidental path override from test code must not redirect
	# SaveManager's script-mode reads or writes to the player's save.
	sm.save_path = REAL_SAVE
	_check("script tests cannot override the isolated save path", sm.save_path == test_path)

	# Saving must continue to resolve to the test-only path after an attempted override.
	sm.save_game()
	_check("saving during a test keeps using its isolated path", sm.save_path == test_path)

	if failures > 0:
		push_error("Save isolation regression (%d failures)" % failures)
		quit(1)
		return
	print("SAVE_ISOLATION_PASS")
	quit(0)