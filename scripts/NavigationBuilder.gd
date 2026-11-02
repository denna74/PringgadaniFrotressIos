class_name NavigationBuilder extends RefCounted

const TILE_SIZE: float = 1.0
const PATH_HEIGHT: float = 0.3


static func build_navigation(terrain: Array, parent: Node3D, center_offset: float = 0.0, on_thread: bool = true) -> NavigationRegion3D:
	var nav_region: NavigationRegion3D = NavigationRegion3D.new()
	nav_region.name = "NavigationRegion3D"

	var nav_mesh: NavigationMesh = NavigationMesh.new()
	nav_mesh.agent_radius = 0.3
	nav_mesh.agent_height = 1.0
	nav_mesh.cell_size = 0.5
	nav_mesh.cell_height = 0.1
	nav_region.navigation_mesh = nav_mesh
	parent.add_child(nav_region)
	nav_region.owner = parent.owner if parent.owner else parent
	var world_3d := parent.get_world_3d()
	if world_3d != null:
		NavigationServer3D.map_set_cell_height(world_3d.get_navigation_map(), nav_mesh.cell_height)

	var body := StaticBody3D.new()
	body.name = "NavGeometry"
	nav_region.add_child(body)
	_add_walkable_colliders(body, terrain, center_offset)

	var source_geometry: NavigationMeshSourceGeometryData3D = NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(nav_mesh, source_geometry, nav_region, Callable())
	nav_region.bake_navigation_mesh(on_thread)

	return nav_region


static func wait_until_ready(
	region: NavigationRegion3D,
	navigation_map: RID,
	initial_iteration_id: int,
	tree: SceneTree
) -> void:
	if region.is_baking():
		await region.bake_finished
	while NavigationServer3D.map_get_iteration_id(navigation_map) <= initial_iteration_id:
		await tree.physics_frame


static func _add_walkable_colliders(body: StaticBody3D, terrain: Array, center_offset: float = 0.0) -> void:
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(TILE_SIZE, 0.3, TILE_SIZE)
	for y in range(terrain.size()):
		for x in range(terrain[y].size()):
			if terrain[y][x] == 1:
				var coll := CollisionShape3D.new()
				coll.shape = box_shape
				coll.position = Vector3(
					(x - center_offset) * TILE_SIZE,
					0.1,
					(y - center_offset) * TILE_SIZE
				)
				body.add_child(coll)


static func get_path_world_positions(terrain: Array) -> Array[Vector3]:
	var positions: Array[Vector3] = []
	for y in range(terrain.size()):
		for x in range(terrain[y].size()):
			if terrain[y][x] == 1:
				positions.append(Vector3(x * TILE_SIZE, PATH_HEIGHT, y * TILE_SIZE))
	return positions


static func get_spawn_positions(terrain: Array) -> Array[Vector3]:
	var positions: Array[Vector3] = []
	for y in range(terrain.size()):
		for x in range(terrain[y].size()):
			if terrain[y][x] == 4:
				positions.append(Vector3(x * TILE_SIZE, PATH_HEIGHT, y * TILE_SIZE))
	return positions
