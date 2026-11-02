extends SceneTree

# Regression: an enemy archer must not be drawn on an infantry body.
#
# The enemy pool is keyed by type, because archer and infantry are different rigs
# with different skeletons. Before the fix the pool was a single bucket that always
# built "infantry", and a reused node kept its old mesh, so an archer walked around
# shooting arrows while looking like a plain soldier.

var failures := 0


func _initialize() -> void:
	_run()


func _check(name: String, cond: bool) -> void:
	if cond:
		print("OK  ", name)
	else:
		push_error("FAIL " + name)
		failures += 1


func _rig_of(node: Node3D) -> String:
	# The two rigs have different root skeletons, which is exactly how the model
	# mismatch is visible on screen.
	if node.get_node_or_null("Armature") != null:
		return "infantry"
	if node.get_node_or_null("target_character") != null:
		return "archer"
	return "unknown"


func _run() -> void:
	await process_frame

	# Loaded by path, not referenced as the UnitPool identifier: SoldierUnit and
	# enemy_script reference the SpatialIndex autoload, and a direct global
	# reference compiles this test before that autoload is registered.
	var UPL: GDScript = load("res://scripts/UnitPool.gd")

	# An archer drawn fresh must be on the archer rig.
	_check("fresh archer is on the archer rig", _rig_of(ModelLoader.load_enemy("archer", false)) == "archer")
	_check("fresh infantry is on the infantry rig", _rig_of(ModelLoader.load_enemy("infantry", false)) == "infantry")

	# Acquiring by type must yield the matching rig, including after a node has
	# been released back into the pool and handed out again.
	var archer: Node3D = UPL.acquire_enemy("archer")
	_check("acquire_enemy('archer') gives the archer rig", _rig_of(archer) == "archer")
	archer.set_meta("enemy_data", {"type": "archer"})
	root.add_child(archer)
	UPL.release_enemy(archer)

	var infantry: Node3D = UPL.acquire_enemy("infantry")
	_check("acquire_enemy('infantry') gives the infantry rig", _rig_of(infantry) == "infantry")
	infantry.set_meta("enemy_data", {"type": "infantry"})
	root.add_child(infantry)
	UPL.release_enemy(infantry)

	# Release, then re-acquire the same type repeatedly: a recycled node must never
	# come back as the other type.
	var swapped := false
	for i in 6:
		var a: Node3D = UPL.acquire_enemy("archer")
		if _rig_of(a) != "archer":
			swapped = true
		a.set_meta("enemy_data", {"type": "archer"})
		root.add_child(a)
		UPL.release_enemy(a)

		var inf: Node3D = UPL.acquire_enemy("infantry")
		if _rig_of(inf) != "infantry":
			swapped = true
		inf.set_meta("enemy_data", {"type": "infantry"})
		root.add_child(inf)
		UPL.release_enemy(inf)
	_check("6 recycle rounds never swapped the rig", not swapped)

	# Damage behaviour itself is unchanged: only archers shoot.
	_check("only archers are ranged", ProgressionData.troop_stats("archer")["ranged"] == true)
	_check("infantry is not ranged", ProgressionData.troop_stats("infantry")["ranged"] == false)

	if failures == 0:
		print("ENEMY_RIG_TEST_PASS")
		quit(0)
	else:
		print("ENEMY_RIG_TEST_FAIL")
		quit(1)
