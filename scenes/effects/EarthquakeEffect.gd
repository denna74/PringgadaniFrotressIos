extends Node3D

const WAVE_FINAL_RADIUS: float = 3.5
const WAVE_DURATION: float = 0.8
const WAVE_COLOR: Color = Color(1.0, 0.2, 0.1, 0.55)
const TOTAL_LIFETIME: float = 1.05

const FIRE_AMOUNT: int = 70
const FIRE_LIFETIME: float = 0.9
const FIRE_RING_RADIUS: float = 1.0
const FIRE_SCALE_MIN: float = 0.3
const FIRE_SCALE_MAX: float = 0.7

const ENHANCED_WAVE_FINAL_RADIUS: float = 6.5
const ENHANCED_WAVE_DURATION: float = 0.55
const ENHANCED_WAVE_COLOR: Color = Color(1.0, 0.25, 0.2, 0.9)
const ENHANCED_TOTAL_LIFETIME: float = 1.25
const ENHANCED_FIRE_AMOUNT: int = 80
const ENHANCED_RING_ENERGY: float = 2.0

var enhanced: bool = false

var _wave_final_radius: float = WAVE_FINAL_RADIUS
var _wave_duration: float = WAVE_DURATION
var _wave_color: Color = WAVE_COLOR
var _total_lifetime: float = TOTAL_LIFETIME
var _fire_amount: int = FIRE_AMOUNT
var _ring_energy: float = 1.0

var _ring: MeshInstance3D = null
var _ring_material: StandardMaterial3D = null


func _ready() -> void:
	if enhanced:
		_wave_final_radius = ENHANCED_WAVE_FINAL_RADIUS
		_wave_duration = ENHANCED_WAVE_DURATION
		_wave_color = ENHANCED_WAVE_COLOR
		_total_lifetime = ENHANCED_TOTAL_LIFETIME
		_fire_amount = ENHANCED_FIRE_AMOUNT
		_ring_energy = ENHANCED_RING_ENERGY
	_build_ring()
	_build_fire()
	_animate_ring()
	get_tree().create_timer(_total_lifetime).timeout.connect(queue_free)


func _build_ring() -> void:
	_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.9
	torus.outer_radius = 1.0
	torus.rings = 48
	torus.ring_segments = 16
	_ring.mesh = torus
	_ring.rotation.x = PI / 2.0
	_ring_material = StandardMaterial3D.new()
	_ring_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_ring_material.no_depth_test = true
	_ring_material.albedo_texture = _create_ring_texture()
	_ring_material.emission_enabled = true
	_ring_material.emission = _wave_color
	_ring_material.emission_energy_multiplier = _ring_energy
	_ring_material.albedo_color = _wave_color
	_ring.material_override = _ring_material
	_ring.scale = Vector3.ONE * 0.05
	add_child(_ring)


func _build_fire() -> void:
	var glow_texture := _create_glow_texture()
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.disable_receive_shadows = true
	mat.albedo_texture = glow_texture
	mat.albedo_color = Color.WHITE
	if enhanced:
		mat.vertex_color_use_as_albedo = true

	var quad := QuadMesh.new()
	quad.size = Vector2(0.6, 0.6)
	quad.material = mat

	var particles := CPUParticles3D.new()
	particles.name = "FireParticles"
	particles.mesh = quad
	particles.amount = _fire_amount
	particles.lifetime = FIRE_LIFETIME
	particles.one_shot = true
	particles.emitting = false
	particles.direction = Vector3(0, 1, 0)
	particles.spread = 12.0
	particles.gravity = Vector3(0, -1.5, 0)
	particles.initial_velocity_min = 1.5
	particles.initial_velocity_max = 2.4
	particles.scale_amount_min = FIRE_SCALE_MIN
	particles.scale_amount_max = FIRE_SCALE_MAX
	particles.fixed_fps = 30
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	particles.emission_ring_radius = FIRE_RING_RADIUS
	particles.emission_ring_inner_radius = 0.0
	particles.emission_ring_height = 0.05
	if enhanced:
		particles.explosiveness = 0.92
		particles.gravity = Vector3(0, -2.0, 0)
		particles.initial_velocity_min = 3.0
		particles.initial_velocity_max = 7.0
		particles.scale_amount_min = 1.2
		particles.scale_amount_max = 2.6
		particles.spread = 45.0
		particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		particles.emission_sphere_radius = 2.0
		particles.color_ramp = _make_enhanced_fire_ramp()
	else:
		particles.color_ramp = _make_fire_ramp()
	particles.cast_shadow = GeometryInstance3D.ShadowCastingSetting.SHADOW_CASTING_SETTING_OFF
	add_child(particles)
	particles.emitting = true


func _animate_ring() -> void:
	var tween := create_tween()
	tween.tween_method(_set_wave_progress, 0.0, 1.0, _wave_duration)


func _set_wave_progress(t: float) -> void:
	if _ring == null or _ring_material == null:
		return
	var eased := 1.0 - pow(1.0 - t, 3.0)
	_ring.scale = Vector3.ONE * lerpf(0.05, _wave_final_radius, eased)
	var fade := 1.0 - t
	_ring_material.albedo_color.a = _wave_color.a * fade
	_ring_material.emission = Color(_wave_color.r, _wave_color.g, _wave_color.b) * fade


func _make_fire_ramp() -> Gradient:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	gradient.colors = PackedColorArray([
		Color(1.0, 0.85, 0.3, 1.0),
		Color(1.0, 0.35, 0.1, 1.0),
		Color(0.5, 0.05, 0.02, 0.0),
	])
	return gradient


func _make_enhanced_fire_ramp() -> Gradient:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	gradient.colors = PackedColorArray([
		Color(1.0, 0.95, 0.4, 1.0),
		Color(1.0, 0.75, 0.15, 0.9),
		Color(0.6, 0.25, 0.0, 0.0),
	])
	return gradient


func _create_glow_texture() -> ImageTexture:
	var size := 64
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := Vector2(size - 1, size - 1) * 0.5
	var max_dist := center.length()
	for y in size:
		for x in size:
			var d: float = Vector2(x, y).distance_to(center) / max_dist
			var alpha := pow(clampf(1.0 - d, 0.0, 1.0), 2.0)
			img.set_pixel(x, y, Color(1, 1, 1, alpha))
	return ImageTexture.create_from_image(img)


func _create_ring_texture() -> ImageTexture:
	var size := 64
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		var edge: float = float(y) / float(size - 1)
		var grad := clampf(1.0 - absf(edge - 0.5) * 2.0, 0.0, 1.0)
		var alpha := pow(grad, 2.0)
		for x in size:
			img.set_pixel(x, y, Color(1, 1, 1, alpha))
	return ImageTexture.create_from_image(img)