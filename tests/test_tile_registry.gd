extends SceneTree

const TERRAIN: Array = [
	[0, 0, 0],
	[0, 0, 0],
	[0, 0, 0],
]

const STRENGTH_BY_DIST: Dictionary = {0: 0.16, 1: 0.10, 2: 0.06}


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var ok := true

	var holder := Node3D.new()
	root.add_child(holder)
	TerrainBuilder.build_terrain(TERRAIN, holder, 1.5)
	await process_frame

	if TerrainBuilder.instance_registry.size() != 9:
		push_error("registry size = %d, expected 9" % TerrainBuilder.instance_registry.size())
		ok = false

	for key in TerrainBuilder.instance_registry:
		var entry: Dictionary = TerrainBuilder.instance_registry[key]
		var mmi: MultiMeshInstance3D = entry.get("mmi")
		var idx: int = entry.get("index")
		if mmi == null or mmi.multimesh == null or idx < 0 or idx >= mmi.multimesh.instance_count:
			push_error("invalid registry entry for %s" % key)
			ok = false

	var center: Vector3 = Vector3(-0.5, 0, -0.5)
	var near_center: Array = TerrainBuilder.get_tile_entries_near(center, 1)
	if near_center.size() != 9:
		push_error("near(center) size = %d, expected 9" % near_center.size())
		ok = false

	for entry in near_center:
		var base: Transform3D = entry["base"]
		var dist := maxi(absi(roundi(base.origin.x - center.x)), absi(roundi(base.origin.z - center.z)))
		var expected_strength: float = STRENGTH_BY_DIST[dist]
		if not is_equal_approx(entry["strength"], expected_strength):
			push_error("entry at %v strength %f, expected %f" % [base.origin, entry["strength"], expected_strength])
			ok = false

	var edge: Vector3 = Vector3(-1.5, 0, -0.5)
	if TerrainBuilder.get_tile_entries_near(edge, 1).size() != 6:
		push_error("near(edge) size should be 6")
		ok = false

	var corner: Vector3 = Vector3(-1.5, 0, -1.5)
	if TerrainBuilder.get_tile_entries_near(corner, 1).size() != 4:
		push_error("near(corner) size should be 4")
		ok = false

	holder.queue_free()
	if ok:
		print("TILE_REGISTRY_PASS")
		quit(0)
	else:
		push_error("TileRegistry regression")
		quit(1)