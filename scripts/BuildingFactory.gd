class_name BuildingFactory extends RefCounted

static var _mat_cache: Dictionary = {}

static func _get_cached_mat(color: Color) -> StandardMaterial3D:
	var key: String = color.to_html(false)
	if _mat_cache.has(key):
		return (_mat_cache[key] as StandardMaterial3D).duplicate()
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	_mat_cache[key] = mat
	return mat

static func create_building(building_id: String, level: int, grid_size: Vector2i = Vector2i(1, 1)) -> Node3D:
	var glb_model: Node3D = ModelLoader.load_building_model(building_id, grid_size)
	if glb_model != null:
		glb_model.name = building_id.capitalize()
		return glb_model

	var root: Node3D = Node3D.new()
	root.name = building_id.capitalize()

	match building_id:
		"pendopo":
			_build_pendopo(root, level)
		"tambang_emas":
			_build_tambang_emas(root, level)
		"menara":
			_build_menara(root, level)
		"barak":
			_build_military(root, level, Color(0.2, 0.4, 0.8))
		_:
			_build_generic(root, level)

	return root

static func _build_pendopo(root: Node3D, level: int) -> void:
	var base: MeshInstance3D = _box(1.6, 0.1, 1.6, Color(0.6, 0.5, 0.4))
	base.position.y = 0.05
	root.add_child(base)

	var pillar_h: float = 1.2
	var pillar_positions: Array[Vector3] = [
		Vector3(-0.7, pillar_h / 2 + 0.1, -0.7),
		Vector3(0.7, pillar_h / 2 + 0.1, -0.7),
		Vector3(-0.7, pillar_h / 2 + 0.1, 0.7),
		Vector3(0.7, pillar_h / 2 + 0.1, 0.7)
	]
	for pos in pillar_positions:
		var pillar: MeshInstance3D = _cylinder(0.08, pillar_h, Color(0.5, 0.4, 0.3))
		pillar.position = pos
		root.add_child(pillar)

	var roof: MeshInstance3D = _pyramid(1.8, 0.6, Color(0.7, 0.3, 0.2))
	roof.position.y = pillar_h + 0.4
	root.add_child(roof)

static func _build_tambang_emas(root: Node3D, level: int) -> void:
	var mound: MeshInstance3D = _sphere(0.5, Color(0.4, 0.35, 0.3))
	mound.position.y = 0.25
	mound.scale = Vector3(1.2, 0.6, 1.2)
	root.add_child(mound)

	var gold: MeshInstance3D = _sphere(0.15, Color(0.85, 0.65, 0.1))
	gold.position = Vector3(0.2, 0.4, 0.1)
	var gold_mat: StandardMaterial3D = StandardMaterial3D.new()
	gold_mat.albedo_color = Color(0.85, 0.65, 0.1)
	gold_mat.emission_enabled = true
	gold_mat.emission = Color(0.85, 0.65, 0.1)
	gold_mat.emission_energy_multiplier = 0.5
	gold.material_override = gold_mat
	root.add_child(gold)

static func _build_menara(root: Node3D, level: int) -> void:
	var body: MeshInstance3D = _cylinder(0.35, 1.5, Color(0.55, 0.55, 0.55))
	body.position.y = 0.75
	root.add_child(body)

	var roof: MeshInstance3D = _cone(0.5, 0.4, Color(0.5, 0.3, 0.2))
	roof.position.y = 1.7
	root.add_child(roof)

static func _build_military(root: Node3D, level: int, banner_color: Color) -> void:
	var base: MeshInstance3D = _box(1.0, 0.7, 0.8, Color(0.55, 0.45, 0.35))
	base.position.y = 0.35
	root.add_child(base)

	var roof: MeshInstance3D = _box(1.1, 0.1, 0.9, Color(0.45, 0.35, 0.25))
	roof.position.y = 0.75
	root.add_child(roof)

	var banner: MeshInstance3D = _box(0.05, 0.4, 0.3, banner_color)
	banner.position = Vector3(0.55, 0.5, 0)
	root.add_child(banner)

static func _build_generic(root: Node3D, level: int) -> void:
	var box_mesh: MeshInstance3D = _box(0.8, 0.6, 0.8, Color(0.5, 0.5, 0.5))
	box_mesh.position.y = 0.3
	root.add_child(box_mesh)

static func _box(w: float, h: float, d: float, color: Color) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3(w, h, d)
	mi.mesh = box
	mi.material_override = _get_cached_mat(color)
	return mi

static func _cylinder(radius: float, height: float, color: Color) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	var cyl: CylinderMesh = CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = height
	mi.mesh = cyl
	mi.material_override = _get_cached_mat(color)
	return mi

static func _sphere(radius: float, color: Color) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	var sph: SphereMesh = SphereMesh.new()
	sph.radius = radius
	mi.mesh = sph
	mi.material_override = _get_cached_mat(color)
	return mi

static func _cone(radius: float, height: float, color: Color) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	var cone: CylinderMesh = CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = radius
	cone.height = height
	mi.mesh = cone
	mi.material_override = _get_cached_mat(color)
	return mi

static func _pyramid(width: float, height: float, color: Color) -> MeshInstance3D:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var half: float = width / 2
	var tip: Vector3 = Vector3(0, height, 0)
	var corners: Array[Vector3] = [
		Vector3(-half, 0, -half),
		Vector3(half, 0, -half),
		Vector3(half, 0, half),
		Vector3(-half, 0, half)
	]

	for i in range(4):
		var next_idx: int = (i + 1) % 4
		st.add_vertex(corners[i])
		st.add_vertex(corners[next_idx])
		st.add_vertex(tip)

	st.generate_normals()
	var mesh: ArrayMesh = st.commit()

	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _get_cached_mat(color)
	return mi
