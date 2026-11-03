extends Node3D

const SPEED := 23.0
const HIT_RADIUS := 1.0
const POOL_SIZE := 16

const STYLE_NORMAL: String = "normal"
const STYLE_BOMA_RED: String = "boma_red"

# Boma's arrow drags a wide red slash shadow behind it, so it reads as a
# horizontal streak rather than a thin projectile.
const SLASH_WIDTH := 2.0
const SLASH_LENGTH := 1.0
const SLASH_BACK_OFFSET := -1.1

var _target: Node3D
var _target_position: Vector3
var _damage: float
var _released: bool = false
var _style: String = STYLE_NORMAL
var _slash_shadow: Node3D = null
var _power_aura: CPUParticles3D = null

static var _pool: Array[Node3D] = []
static var _shaft_mesh: Mesh = null
static var _tip_mesh: Mesh = null
static var _shaft_mat: Material = null
static var _tip_mat: Material = null
static var _style_shaft: String = STYLE_NORMAL
static var _style_tip: String = STYLE_NORMAL


static func acquire() -> Node3D:
	while not _pool.is_empty():
		var arrow := _pool.pop_back()
		if is_instance_valid(arrow):
			return arrow
	return _create_arrow()


static func _create_arrow() -> Node3D:
	var arrow := Node3D.new()
	arrow.set_script(load("res://scenes/projectiles/arrow_projectile.gd"))
	return arrow


static func _get_shaft_mesh() -> Mesh:
	if _shaft_mesh == null:
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.05
		cyl.bottom_radius = 0.05
		cyl.height = 0.6
		_shaft_mesh = cyl
	return _shaft_mesh


static func shaft_radius() -> float:
	return 0.12


static func _get_tip_mesh() -> Mesh:
	if _tip_mesh == null:
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = 0.1
		cone.height = 0.2
		_tip_mesh = cone
	return _tip_mesh


func setup(
	target: Node3D,
	from: Vector3,
	damage: float,
	style: String = STYLE_NORMAL,
	power_aura: bool = false
) -> void:
	_released = false
	_target = target
	_target_position = target.global_position
	_damage = damage
	_style = style
	visible = true
	set_physics_process(true)
	look_at_from_position(from, _target_position, Vector3.UP)
	_apply_style()
	if power_aura:
		_build_power_aura()


func get_arrow_style() -> String:
	return _style


func get_slash_shadow() -> Node3D:
	return _slash_shadow


func _apply_style() -> void:
	# Pooled arrows come back with the previous style's mesh still attached.
	if _slash_shadow != null and is_instance_valid(_slash_shadow):
		_slash_shadow.queue_free()
		_slash_shadow = null
	if _power_aura != null and is_instance_valid(_power_aura):
		_power_aura.queue_free()
		_power_aura = null
	_shaft_mat = null
	_tip_mat = null
	_style_shaft = STYLE_NORMAL
	_style_tip = STYLE_NORMAL
	if _style == STYLE_BOMA_RED:
		_style_shaft = STYLE_BOMA_RED
		_style_tip = STYLE_BOMA_RED
		_build_slash_shadow()
	_restyle_existing_mesh()


func has_power_aura() -> bool:
	return _power_aura != null and is_instance_valid(_power_aura)


func _build_power_aura() -> void:
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.albedo_texture = _create_aura_texture()
	material.albedo_color = Color(1.0, 0.18, 0.06, 0.9)
	material.emission_enabled = true
	material.emission = Color(1.0, 0.12, 0.02)
	material.emission_energy_multiplier = 2.0

	var quad := QuadMesh.new()
	quad.size = Vector2(0.7, 0.7)
	quad.material = material

	_power_aura = CPUParticles3D.new()
	_power_aura.name = "PowerAttackAura"
	_power_aura.mesh = quad
	_power_aura.amount = 32
	_power_aura.lifetime = 0.35
	_power_aura.explosiveness = 0.0
	_power_aura.emitting = true
	_power_aura.direction = Vector3(0.0, 0.0, 1.0)
	_power_aura.spread = 35.0
	_power_aura.initial_velocity_min = 0.8
	_power_aura.initial_velocity_max = 2.0
	_power_aura.gravity = Vector3.ZERO
	_power_aura.scale_amount_min = 0.35
	_power_aura.scale_amount_max = 0.8
	_power_aura.color_ramp = _create_aura_gradient()
	_power_aura.position = Vector3(0.0, 0.0, 0.4)
	_power_aura.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_power_aura)


func _create_aura_gradient() -> Gradient:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	gradient.colors = PackedColorArray([
		Color(1.0, 0.9, 0.3, 1.0),
		Color(1.0, 0.2, 0.05, 0.8),
		Color(0.8, 0.02, 0.0, 0.0),
	])
	return gradient


func _create_aura_texture() -> Texture2D:
	var image := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	var center := Vector2(15.5, 15.5)
	for y in 32:
		for x in 32:
			var distance := Vector2(x, y).distance_to(center) / center.length()
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, pow(clampf(1.0 - distance, 0.0, 1.0), 2.0)))
	return ImageTexture.create_from_image(image)


func _restyle_existing_mesh() -> void:
	# The pooled arrow may already carry a mesh built for the previous style.
	for child in get_children():
		if not (child is MeshInstance3D):
			continue
		var mi := child as MeshInstance3D
		if mi.name == "Shaft":
			mi.material_override = _shaft_material()
		elif mi.name == "Tip":
			mi.material_override = _tip_material()


func _shaft_material() -> Material:
	if _shaft_mat == null:
		_shaft_mat = StandardMaterial3D.new()
	_shaft_mat.albedo_color = _style_color(_style_shaft)
	return _shaft_mat


func _tip_material() -> Material:
	if _tip_mat == null:
		_tip_mat = StandardMaterial3D.new()
	_tip_mat.albedo_color = _style_color(_style_tip)
	return _tip_mat


func _style_color(style: String) -> Color:
	if style == STYLE_BOMA_RED:
		return Color(0.95, 0.1, 0.1)
	if style == "shaft":
		return Color(0.55, 0.35, 0.15)
	return Color(0.3, 0.3, 0.3)


func _build_slash_shadow() -> void:
	_slash_shadow = Node3D.new()
	_slash_shadow.name = "SlashShadow"
	_slash_shadow.position = Vector3(0.0, 0.0, SLASH_BACK_OFFSET)
	add_child(_slash_shadow)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.15, 0.15, 0.65)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD

	# A wide, flat, angled blade of red: the "shadow behind the arrow".
	for i in 2:
		var blade := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2(SLASH_WIDTH, SLASH_LENGTH)
		blade.mesh = quad
		blade.material_override = mat
		blade.rotation.x = PI * 0.5
		blade.rotation.z = deg_to_rad(18.0 + 22.0 * float(i))
		blade.position = Vector3(0.0, 0.0, -0.35 * float(i))
		blade.scale = Vector3(1.0, 1.0, 1.0 - 0.3 * float(i))
		_slash_shadow.add_child(blade)


func _ready() -> void:
	# Stay inert until setup() hands us a target. An arrow added to the tree
	# before setup() would otherwise self-release into the pool immediately.
	# setup() may also run before the arrow is re-parented, so only cut the
	# physics tick when there is genuinely nothing to chase yet.
	if _target == null:
		set_physics_process(false)
	if get_child_count() == 0:
		_build_mesh()
	elif _slash_shadow == null and _style == STYLE_BOMA_RED:
		_build_slash_shadow()


func _build_mesh() -> void:
	var shaft := MeshInstance3D.new()
	shaft.name = "Shaft"
	var cyl := _get_shaft_mesh()
	shaft.mesh = cyl
	shaft.material_override = _shaft_material()
	shaft.rotation.x = PI / 2
	shaft.position.z = -0.3
	add_child(shaft)

	var tip := MeshInstance3D.new()
	tip.name = "Tip"
	var cone := _get_tip_mesh()
	tip.mesh = cone
	tip.material_override = _tip_material()
	tip.rotation.x = -PI / 2
	tip.position.z = -0.7
	add_child(tip)


func _physics_process(delta: float) -> void:
	if not is_instance_valid(_target) or not _target.is_inside_tree():
		_release()
		return
	if _target.has_method("is_alive") and not _target.is_alive():
		_release()
		return

	var step := SPEED * delta
	var dir := (_target_position - global_position).normalized()
	var dist := global_position.distance_to(_target_position)

	if dist <= step + HIT_RADIUS:
		_hit()
		return

	global_position += dir * step


func _hit() -> void:
	if _target and is_instance_valid(_target) and _target.is_inside_tree() and _target.has_method("take_damage"):
		if _target.has_method("is_alive") and not _target.is_alive():
			_release()
			return
		_target.take_damage(_damage)
	_release()


func _release() -> void:
	if _released:
		return
	_released = true
	_target = null
	set_physics_process(false)
	visible = false
	if _pool.size() >= POOL_SIZE:
		queue_free()
	else:
		if is_inside_tree() and get_parent():
			get_parent().remove_child(self)
		_pool.append(self)
