extends SceneTree

var failures: int = 0


func _initialize() -> void:
	_run()


func _check(name: String, condition: bool) -> void:
	if condition:
		print("OK  ", name)
	else:
		push_error("FAIL " + name)
		failures += 1


func _run() -> void:
	await process_frame
	var host := Node3D.new()
	root.add_child(host)
	var navigation_map: RID = host.get_world_3d().get_navigation_map()
	var initial_iteration_id: int = NavigationServer3D.map_get_iteration_id(navigation_map)
	var terrain: Array = []
	for _y in range(8):
		var row: Array[int] = []
		row.resize(8)
		row.fill(1)
		terrain.append(row)

	var region: NavigationRegion3D = NavigationBuilder.build_navigation(terrain, host)
	await NavigationBuilder.wait_until_ready(
		region, navigation_map, initial_iteration_id, self
	)
	_check("navigation bake finished", not region.is_baking())
	_check(
		"navigation map synchronized after bake",
		NavigationServer3D.map_get_iteration_id(navigation_map) > initial_iteration_id
	)
	_check("baked navigation mesh has polygons", region.navigation_mesh.get_polygon_count() > 0)

	host.queue_free()
	await process_frame
	if failures > 0:
		quit(1)
		return
	print("NAVIGATION_STARTUP_PASS")
	quit(0)
