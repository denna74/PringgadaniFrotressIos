extends SceneTree

# Guards the archer prewarm actually building its templates.
#
# Warming the file cache is not sufficient: the cost is in _build_soldier_template, which
# instantiates four ~8 MB GLBs and merges their animation sets. Measured at ~1.25 s per
# archer template on desktop and far longer on a phone. If prewarm stops building the
# templates, that cost returns to first use and freezes the game mid-run, so this asserts
# the caches are populated rather than trusting a stopwatch.


func _initialize() -> void:
	_run()


var _fails: int = 0


func _fail(msg: String) -> void:
	_fails += 1
	print("CHECK FAIL: " + msg)


func _run() -> void:
	await process_frame

	# Awaited directly rather than through a helper: prewarm_archer_models is a coroutine,
	# and routing it through a lambda loses the await, which is exactly how this stall
	# reached the first archer spawn in the first place.
	var start := Time.get_ticks_msec()
	await ModelLoader.prewarm_archer_models()
	print("%-28s %6d ms" % ["prewarm_archer_models()", Time.get_ticks_msec() - start])

	if not ModelLoader._soldier_templates.has("archer"):
		_fail("prewarm_archer_models() did not build the archer soldier template")
	if not ModelLoader._enemy_templates.has("archer"):
		_fail("prewarm_archer_models() did not build the archer enemy template")

	# The templates must now be usable, and each call must hand out its own instance.
	var a: Node3D = ModelLoader.load_soldier("archer")
	var b: Node3D = ModelLoader.load_soldier("archer")
	if a == null or b == null:
		_fail("load_soldier(archer) returned nothing after prewarm")
	elif a == b:
		_fail("load_soldier(archer) returned the same node twice; it must duplicate the template")

	var ap: AnimationPlayer = ModelLoader.find_animation_player(a)
	if ap == null:
		_fail("archer template has no AnimationPlayer")
	elif not ap.has_animation_library("soldier"):
		_fail("archer template is missing the merged 'soldier' animation library")

	# Cached, so these must now be near-free. This is the property that keeps the stall
	# off the first archer spawn.
	var t0 := Time.get_ticks_msec()
	ModelLoader.load_soldier("archer")
	print("%-28s %6d ms" % ["load_soldier(archer) cached", Time.get_ticks_msec() - t0])
	var t1 := Time.get_ticks_msec()
	ModelLoader.load_enemy("archer")
	print("%-28s %6d ms" % ["load_enemy(archer) cached", Time.get_ticks_msec() - t1])

	if _fails == 0:
		print("VERIFY_PASS: archer prewarm builds templates")
		quit(0)
	else:
		print("VERIFY_FAIL: %d checks failed" % _fails)
		quit(1)
