class_name TerrainBuilder extends RefCounted

const TILE_SIZE: float = 1.0
const TILES_DIR: String = "res://assets/models/3D_tiles/"
const DEFAULT_THEME: String = TileTheme.DEFAULT_THEME

enum TileType { GRASS = 0, PATH = 1, OBSTACLE = 2, RESOURCE = 3, SPAWN = 4 }

const GRASS_TILES: Array[String] = [
	"land_center",
	"grass_straight",
	"grass_left_top", "grass_right_top",
	"grass_left_bottom", "grass_right_bottom",
	"grass_center_1", "grass_center_2", "grass_center_3",
]

const DIRT_TILES: Array[String] = [
	"dirt_center",
	"dirt_top", "dirt_bottom", "dirt_left", "dirt_right",
	"dirt_left_top", "dirt_right_top",
	"dirt_left_bottom", "dirt_right_bottom",
]

const GRASS_BORDER: String = "grass_straight"
const GRASS_DIAGONALS: Array[String] = [
	"grass_left_top", "grass_right_top",
	"grass_left_bottom", "grass_right_bottom",
]
const GRASS_CENTERS: Array[String] = [
	"grass_center_1", "grass_center_2", "grass_center_3",
]
const PLAIN_GRASS: String = "land_center"
const DIRT_CENTER: String = "dirt_center"

static var _scene_cache: Dictionary = {}
static var _processed_mesh_cache: Dictionary = {}
static var _processed_mat_cache: Dictionary = {}
static var _base_mat_cache: Dictionary = {}
static var instance_registry: Dictionary = {}


static func build_terrain(terrain: Array, parent: Node3D, center_offset: float = 0.0, theme: String = DEFAULT_THEME) -> Dictionary:
	instance_registry.clear()
	var terrain_node: Node3D = Node3D.new()
	terrain_node.name = "Terrain"

	var rows: int = terrain.size()
	if rows == 0:
		return {"node": terrain_node, "tile_groups": {}}
	var cols: int = terrain[0].size()

	var tile_positions: Dictionary = {}

	for y in range(rows):
		for x in range(cols):
			var tile_type: int = terrain[y][x]
			var world_pos := Vector3(
				(x - center_offset) * TILE_SIZE,
				0.0,
				(y - center_offset) * TILE_SIZE
			)
			var tile_name: String = _pick_tile(terrain, x, y, tile_type)
			if not tile_positions.has(tile_name):
				tile_positions[tile_name] = []
			tile_positions[tile_name].append(world_pos)

	for tile_name: String in tile_positions:
		var positions: Array = tile_positions[tile_name]
		var mmi: MultiMeshInstance3D = _create_tile_multimesh(tile_name, positions, theme)
		if mmi:
			terrain_node.add_child(mmi)

	parent.add_child(terrain_node)
	terrain_node.owner = parent.owner if parent.owner else parent

	return {"node": terrain_node, "tile_groups": {}}


static func _create_tile_multimesh(tile_name: String, positions: Array, theme: String = DEFAULT_THEME) -> MultiMeshInstance3D:
	var mesh: ArrayMesh = _get_mesh(tile_name)
	if mesh == null:
		return null

	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = positions.size()

	for i in range(positions.size()):
		var t: Transform3D = Transform3D(Basis.IDENTITY, positions[i])
		mm.set_instance_transform(i, t)

	var mmi: MultiMeshInstance3D = MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.name = tile_name

	var mat: Material = _get_material(tile_name, theme)
	if mat and mat is BaseMaterial3D:
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		mmi.material_override = mat

	for i in range(positions.size()):
		instance_registry[positions[i]] = {
			"mmi": mmi,
			"index": i,
			"base": Transform3D(Basis.IDENTITY, positions[i]),
		}

	return mmi


static func _get_mesh(tile_name: String) -> ArrayMesh:
	if _processed_mesh_cache.has(tile_name):
		return _processed_mesh_cache[tile_name]

	var path: String = TILES_DIR + tile_name + ".glb"
	if not ResourceLoader.exists(path):
		return null
	var scene: PackedScene = load(path)
	if scene == null:
		return null

	var temp: Node3D = scene.instantiate()
	var result_mat: Material = null

	for child in temp.find_children("*", "MeshInstance3D", true):
		var mi: MeshInstance3D = child as MeshInstance3D
		if mi == null:
			continue
		var orig_mat: Material = mi.get_active_material(0)
		if orig_mat:
			result_mat = orig_mat
		break

	temp.queue_free()

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	st.set_normal(Vector3(0, 1, 0))
	st.set_uv(Vector2(0, 0))
	st.add_vertex(Vector3(-0.5, 0.0, -0.5))

	st.set_normal(Vector3(0, 1, 0))
	st.set_uv(Vector2(1, 0))
	st.add_vertex(Vector3(0.5, 0.0, -0.5))

	st.set_normal(Vector3(0, 1, 0))
	st.set_uv(Vector2(1, 1))
	st.add_vertex(Vector3(0.5, 0.0, 0.5))

	st.set_normal(Vector3(0, 1, 0))
	st.set_uv(Vector2(0, 0))
	st.add_vertex(Vector3(-0.5, 0.0, -0.5))

	st.set_normal(Vector3(0, 1, 0))
	st.set_uv(Vector2(1, 1))
	st.add_vertex(Vector3(0.5, 0.0, 0.5))

	st.set_normal(Vector3(0, 1, 0))
	st.set_uv(Vector2(0, 1))
	st.add_vertex(Vector3(-0.5, 0.0, 0.5))

	var result_mesh: ArrayMesh = st.commit()

	_processed_mesh_cache[tile_name] = result_mesh
	_base_mat_cache[tile_name] = result_mat

	return result_mesh


static func _get_material(tile_name: String, theme: String = DEFAULT_THEME) -> Material:
	var key: String = theme + ":" + tile_name
	if _processed_mat_cache.has(key):
		return _processed_mat_cache[key]

	if not _base_mat_cache.has(tile_name):
		_get_mesh(tile_name)

	var base_mat: Material = _base_mat_cache.get(tile_name)
	if theme == DEFAULT_THEME:
		_processed_mat_cache[key] = base_mat
		return base_mat

	if base_mat is StandardMaterial3D:
		var themed_mat: StandardMaterial3D = (base_mat as StandardMaterial3D).duplicate()
		var tex: Texture2D = load(TileTheme.texture_path(theme, tile_name))
		if tex:
			themed_mat.albedo_texture = tex
			themed_mat.albedo_color = Color.WHITE
			if theme == "sky":
				themed_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			_processed_mat_cache[key] = themed_mat
			return themed_mat
		push_warning("TerrainBuilder: missing texture for theme '%s' tile '%s'" % [theme, tile_name])

	_processed_mat_cache[key] = base_mat
	return base_mat


static func _pick_tile(terrain: Array, x: int, y: int, tile_type: int) -> String:
	if tile_type == TileType.PATH:
		return DIRT_CENTER

	var rows: int = terrain.size()
	var cols: int = terrain[0].size()

	if tile_type == TileType.OBSTACLE or tile_type == TileType.RESOURCE or tile_type == TileType.SPAWN:
		var has_n := _is_path(terrain, x, y - 1, cols, rows)
		var has_s := _is_path(terrain, x, y + 1, cols, rows)
		var has_w := _is_path(terrain, x - 1, y, cols, rows)
		var has_e := _is_path(terrain, x + 1, y, cols, rows)
		if has_n or has_s or has_w or has_e:
			return DIRT_CENTER
		return PLAIN_GRASS

	var has_n := _is_path(terrain, x, y - 1, cols, rows)
	var has_s := _is_path(terrain, x, y + 1, cols, rows)
	var has_w := _is_path(terrain, x - 1, y, cols, rows)
	var has_e := _is_path(terrain, x + 1, y, cols, rows)

	var cardinal_count := int(has_n) + int(has_s) + int(has_w) + int(has_e)

	if cardinal_count >= 3:
		return DIRT_CENTER

	if cardinal_count == 2:
		if has_n and has_s:
			return DIRT_CENTER
		if has_w and has_e:
			return DIRT_CENTER
		if has_n and has_w:
			return "land_left_top"
		if has_n and has_e:
			return "land_right_top"
		if has_s and has_e:
			return "land_right_bottom"
		if has_s and has_w:
			return "land_left_bottom"

	if cardinal_count == 1:
		if has_n:
			return "dirt_bottom"
		if has_s:
			return "dirt_top"
		if has_w:
			return "dirt_right"
		if has_e:
			return "dirt_left"

	var has_ne := _is_path(terrain, x + 1, y - 1, cols, rows)
	var has_nw := _is_path(terrain, x - 1, y - 1, cols, rows)
	var has_se := _is_path(terrain, x + 1, y + 1, cols, rows)
	var has_sw := _is_path(terrain, x - 1, y + 1, cols, rows)

	if has_ne:
		return "dirt_left_bottom"
	if has_nw:
		return "dirt_right_bottom"
	if has_se:
		return "dirt_left_top"
	if has_sw:
		return "dirt_right_top"

	return GRASS_CENTERS[randi() % GRASS_CENTERS.size()]


static func _is_path(terrain: Array, x: int, y: int, cols: int, rows: int) -> bool:
	if x < 0 or x >= cols or y < 0 or y >= rows:
		return false
	return terrain[y][x] == TileType.PATH


static func get_tile_entries_near(center_origin: Vector3, radius: int = 1) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for dz in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			var key := Vector3(
				center_origin.x + dx * TILE_SIZE,
				center_origin.y,
				center_origin.z + dz * TILE_SIZE
			)
			var entry: Variant = instance_registry.get(key)
			if entry == null:
				continue
			var dist := maxi(absi(dx), absi(dz))
			var strength: float = {0: 0.16, 1: 0.10, 2: 0.06}.get(dist, 0.04)
			var mmi: MultiMeshInstance3D = entry["mmi"]
			var base: Transform3D = entry["base"]
			entries.append({"mmi": mmi, "index": entry["index"], "base": base, "strength": strength})
	return entries
