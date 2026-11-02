extends Node3D

var enemy_type: String = "infantry"
var is_boss: bool = false


func _ready() -> void:
	_apply_materials()
	_match_type()


func _apply_materials() -> void:
	var body: MeshInstance3D = get_node_or_null("Body")
	if body:
		body.material_override = _make_material(Color(0.7, 0.2, 0.2))

	var head: MeshInstance3D = get_node_or_null("Head")
	if head:
		head.material_override = _make_material(Color(0.75, 0.6, 0.45))


func _match_type() -> void:
	var body: MeshInstance3D = get_node_or_null("Body")
	if not body:
		return

	match enemy_type:
		"infantry":
			body.material_override = _make_material(Color(0.7, 0.2, 0.2))
		"archer":
			body.material_override = _make_material(Color(0.3, 0.5, 0.3))
			_add_bow()

	if is_boss:
		_apply_boss_scale()
		_add_crown()


func _add_bow() -> void:
	var bow := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.05, 0.5, 0.05)
	bow.mesh = box
	bow.material_override = _make_material(Color(0.55, 0.35, 0.15))
	bow.position = Vector3(0.35, 0.1, 0)
	add_child(bow)


func _add_crown() -> void:
	var crown := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.25, 0.12, 0.25)
	crown.mesh = box
	crown.material_override = _make_material(Color(0.95, 0.85, 0.20))
	crown.position = Vector3(0, 0.82, 0)
	add_child(crown)


func _apply_boss_scale() -> void:
	scale = Vector3(1.5, 1.5, 1.5)


func _make_material(albedo: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = albedo
	mat.roughness = 0.8
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	return mat
