extends SceneTree

const TERRAIN: Array = [
	[0, 1, 0],
	[1, 1, 1],
	[0, 1, 0],
]


func _initialize() -> void:
	_run()


func _check_material_theme(holder: Node3D, theme: String) -> bool:
	var ok := true
	for mmi in holder.find_children("*", "MultiMeshInstance3D", true):
		var mat: StandardMaterial3D = mmi.material_override as StandardMaterial3D
		if mat == null or mat.albedo_texture == null:
			push_error("%s tile missing textured material: %s" % [theme, mmi.name])
			ok = false
		elif not mat.albedo_texture.resource_path.contains("themes/" + theme):
			push_error("%s tile uses wrong texture: %s" % [theme, mat.albedo_texture.resource_path])
			ok = false
	return ok


func _run() -> void:
	await process_frame

	var ok := true

	var lava_holder := Node3D.new()
	root.add_child(lava_holder)
	TerrainBuilder.build_terrain(TERRAIN, lava_holder, 1.5, "lava")
	if not _check_material_theme(lava_holder, "lava"):
		ok = false
	lava_holder.queue_free()
	await process_frame

	var ocean_holder := Node3D.new()
	root.add_child(ocean_holder)
	TerrainBuilder.build_terrain(TERRAIN, ocean_holder, 1.5, "ocean")
	if not _check_material_theme(ocean_holder, "ocean"):
		ok = false
	ocean_holder.queue_free()
	await process_frame

	var garden_holder := Node3D.new()
	root.add_child(garden_holder)
	TerrainBuilder.build_terrain(TERRAIN, garden_holder, 1.5, "garden")
	if not _check_material_theme(garden_holder, "garden"):
		ok = false
	garden_holder.queue_free()
	await process_frame

	var default_mat: Material = TerrainBuilder._get_material("dirt_center")
	var garden_mat: Material = TerrainBuilder._get_material("dirt_center", "garden")
	if garden_mat != default_mat:
		push_error("Garden material should reuse the default glb material")
		ok = false

	var lava_mat: Material = TerrainBuilder._get_material("dirt_center", "lava")
	if lava_mat == default_mat:
		push_error("Lava material should be a separate themed material")
		ok = false

	if ok:
		print("TERRAIN_THEME_PASS")
		quit(0)
	else:
		push_error("TerrainTheme regression")
		quit(1)
