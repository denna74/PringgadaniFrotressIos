extends SceneTree

const TERRAIN: Array = [
	[0, 0, 0],
	[0, 0, 0],
	[0, 0, 0],
]


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var ok := true

	var holder := Node3D.new()
	root.add_child(holder)
	TerrainBuilder.build_terrain(TERRAIN, holder, 1.5)
	await process_frame

	var center: Vector3 = Vector3(-0.5, 0, -0.5)
	var base_transform: Transform3D = TerrainBuilder.instance_registry[center]["base"]

	var effects = root.get_node("/root/BuildEffects")
	if effects == null:
		push_error("BuildEffects autoload missing")
		quit(1)
		return

	var mmi: MultiMeshInstance3D = TerrainBuilder.instance_registry[center]["mmi"]
	var tile_key := "%d:%d" % [mmi.get_instance_id(), TerrainBuilder.instance_registry[center]["index"]]

	var tween: Tween = effects.shake_tiles(center, 1, 0.5)
	await process_frame

	var mid_key: Variant = effects.last_written.get(tile_key)
	if mid_key == null or not effects.last_written.has(tile_key):
		push_error("no shake write recorded for center tile")
		ok = false
	else:
		var mid_transform: Transform3D = effects.last_written[tile_key]
		if is_equal_approx(mid_transform.origin.y, base_transform.origin.y):
			push_error("tile did not move during shake")
			ok = false

	await tween.finished
	var end_transform: Transform3D = effects.last_written[tile_key]
	if not is_equal_approx(end_transform.origin.y, base_transform.origin.y):
		push_error("tile did not settle back after shake: %f vs %f" % [end_transform.origin.y, base_transform.origin.y])
		ok = false
	if not end_transform.origin.is_equal_approx(base_transform.origin):
		push_error("tile origin not restored after shake")
		ok = false

	holder.queue_free()
	if ok:
		print("TILE_SHAKE_PASS")
		quit(0)
	else:
		push_error("TileShake regression")
		quit(1)