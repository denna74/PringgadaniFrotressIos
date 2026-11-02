extends SceneTree

var _fails: int = 0


func _initialize() -> void:
	_run()


func _fail(msg: String) -> void:
	_fails += 1
	print("CHECK FAIL: " + msg)


func _finish() -> void:
	if _fails == 0:
		print("VERIFY_PASS: king anim merge")
		quit(0)
	else:
		print("VERIFY_FAIL: %d checks failed" % _fails)
		quit(1)


# load_king() now caches a merged template and hands out duplicates, so the shader
# warmup pass and the run itself do not each pay for the seven-GLB animation merge. A
# duplicate that drops the AnimationPlayer or the merged library would leave the king
# frozen on the first run and silent on every one after it.
func _test_load_king_cached() -> void:
	var first: Node3D = ModelLoader.load_king()
	if first == null:
		_fail("load_king() returned nothing")
		return
	var second: Node3D = ModelLoader.load_king()
	if second == null:
		_fail("second load_king() returned nothing")
		return
	if first == second:
		_fail("load_king() handed back the same node twice; it must duplicate the template")

	var ap_first: AnimationPlayer = ModelLoader.find_animation_player(first)
	var ap_second: AnimationPlayer = ModelLoader.find_animation_player(second)
	if ap_first == null:
		_fail("cached king template has no AnimationPlayer")
		return
	if ap_second == null:
		_fail("duplicated king has no AnimationPlayer")
		return
	if not ap_first.has_animation_library("king"):
		_fail("cached king template lost the merged 'king' library")
		return
	if not ap_second.has_animation_library("king"):
		_fail("duplicated king lost the merged 'king' library")
		return
	if not ap_second.has_animation("king/idle"):
		_fail("duplicated king is missing king/idle (got %s)" % str(ap_second.get_animation_list()))
		return
	# The two instances must not share one AnimationPlayer, or animating one king would
	# animate every king loaded after it.
	if ap_first == ap_second:
		_fail("duplicated king shares the template's AnimationPlayer")


func _synth(clip_in_default_lib: bool) -> Node3D:
	var root := Node3D.new()
	var ap := AnimationPlayer.new()
	ap.name = "AnimationPlayer"
	root.add_child(ap)

	var anim := Animation.new()
	anim.length = 1.0

	if clip_in_default_lib:
		var default_lib := AnimationLibrary.new()
		ap.add_animation_library("", default_lib)
		default_lib.add_animation("clip0", anim)
	else:
		# The base clip already lives in a named "king" library, which is what a
		# re-exported GLB can look like. Nothing lands in the default library.
		var king_lib := AnimationLibrary.new()
		ap.add_animation_library("king", king_lib)
		king_lib.add_animation("Idle", anim)
	return root


func _player(root: Node3D) -> AnimationPlayer:
	return root.get_node("AnimationPlayer")


func _run() -> void:
	await process_frame

	_test_load_king_cached()

	# The real asset keeps its clip in the default library; this must keep working.
	var ok_root := _synth(true)
	ModelLoader._merge_king_animations(ok_root)
	if not _player(ok_root).has_animation("king/idle"):
		_fail("default-library clip: king/idle was not created")
	if _player(ok_root).current_animation != "king/idle":
		_fail("default-library clip: king/idle is not playing (got %s)" % _player(ok_root).current_animation)
	ok_root.free()

	# A re-exported GLB that already names its clip "Idle" inside the "king" library
	# must still end up with a usable king/idle, and must not log a missing animation.
	var named_root := _synth(false)
	ModelLoader._merge_king_animations(named_root)
	var named_ap := _player(named_root)
	if not named_ap.has_animation("king/idle"):
		_fail("named-library clip: king/idle was not created")
	elif named_ap.get_animation("king/idle").length <= 0.0:
		_fail("named-library clip: king/idle has no length")
	named_root.free()

	# A base model with nothing usable must not be left playing a missing animation.
	# Note: this case covers crash-safety only. The has_animation() guard on the
	# play() call cannot be asserted here because its only observable effect is
	# suppressing Godot's "Animation not found" log, which is not readable in-process.
	var empty_root := Node3D.new()
	var empty_ap := AnimationPlayer.new()
	empty_ap.name = "AnimationPlayer"
	empty_root.add_child(empty_ap)
	empty_ap.add_animation_library("king", AnimationLibrary.new())
	ModelLoader._merge_king_animations(empty_root)
	var playing: String = empty_ap.current_animation
	if playing != "" and not empty_ap.has_animation(playing):
		_fail("empty model: left playing a missing animation (%s)" % playing)
	empty_root.free()

	_finish()
