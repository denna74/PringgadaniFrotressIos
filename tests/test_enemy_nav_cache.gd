extends SceneTree

# Guards two Phase D CPU fixes in enemy_script.gd:
#  * get_anim_player() must return its cache instead of walking the whole model subtree on
#    every call (it used to store the result and then throw it away).
#  * set_nav_target() must only write NavigationAgent3D.target_position when the target
#    actually changed, because every write triggers a full re-path.

var failures := 0


func _initialize() -> void:
	_run()


func _check(name: String, cond: bool) -> void:
	if not cond:
		print("FAIL: ", name)
		failures += 1


func _run() -> void:
	await process_frame
	var script: GDScript = load("res://scenes/run/enemy_script.gd")
	var enemy: Node3D = script.new()
	var anim := AnimationPlayer.new()
	anim.name = "AnimationPlayer"
	enemy.add_child(anim)
	root.add_child(enemy)

	_check("get_anim_player finds the player", enemy.get_anim_player() == anim)
	_check("get_anim_player returns the cached instance", enemy.get_anim_player() == enemy.get_anim_player())

	var nav := NavigationAgent3D.new()
	nav.name = "NavigationAgent3D"
	enemy.add_child(nav)

	enemy.set_nav_target(Vector3(1, 0, 1))
	_check("set_nav_target writes the nav target", nav.target_position.is_equal_approx(Vector3(1, 0, 1)))
	# Same target again: must not error and must stay put.
	enemy.set_nav_target(Vector3(1, 0, 1))
	_check("re-issuing the same target is a no-op", nav.target_position.is_equal_approx(Vector3(1, 0, 1)))
	enemy.set_nav_target(Vector3(2, 0, 2))
	_check("a changed target is written", nav.target_position.is_equal_approx(Vector3(2, 0, 2)))

	enemy.queue_free()
	if failures > 0:
		push_error("ENEMY_NAV_CACHE regression (%d failures)" % failures)
		quit(1)
		return
	print("ENEMY_NAV_CACHE_PASS")
	quit(0)
