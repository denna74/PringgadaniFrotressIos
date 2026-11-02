extends Node3D

const TRAIL_LENGTH: float = 5.0
const TRAIL_WIDTH: float = 1.1
const TRAIL_HEIGHT: float = 1.5
const TRAIL_FADE: float = 0.16
const TRAIL_COLOR: Color = Color(0.25, 0.6, 1.0, 0.85)
const GLOW_COLOR: Color = Color(0.4, 0.75, 1.0)
const PARTICLE_AMOUNT: int = 48
const PARTICLE_LIFETIME: float = 0.45
const PARTICLE_OFFSET: float = 1.4
const TEXTURE_SIZE := 128

var facing: float = 0.0

var _streak: MeshInstance3D = null
var _streak_material: StandardMaterial3D = null
var _ground: MeshInstance3D = null
var _ground_material: StandardMaterial3D = null
var _particles: CPUParticles3D = null


func _ready() -> void:
	var fwd := Vector3(sin(facing), 0.0, cos(facing))
	_build_streak(fwd)
	_build_ground(fwd)
	_build_particles(fwd)
	_animate()


func _build_streak(fwd: Vector3) -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(TRAIL_LENGTH, TRAIL_HEIGHT)

	_streak_material = _make_material(_create_gradient_texture())
	_streak = MeshInstance3D.new()
	_streak.name = "Streak"
	_streak.mesh = quad
	_streak.material_override = _streak_material
	_streak.cast_shadow = GeometryInstance3D.ShadowCastingSetting.SHADOW_CASTING_SETTING_OFF
	_streak.rotation = Vector3(-deg_to_rad(70.0), facing - PI / 2.0, 0.0)
	_streak.position = -fwd * (TRAIL_LENGTH * 0.5) + Vector3(0, TRAIL_HEIGHT * 0.45, 0)
	add_child(_streak)


func _build_ground(fwd: Vector3) -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(TRAIL_WIDTH, TRAIL_LENGTH)
	plane.orientation = PlaneMesh.FACE_Y

	_ground_material = _make_material(_create_fade_texture())
	_ground = MeshInstance3D.new()
	_ground.name = "GroundStreak"
	_ground.mesh = plane
	_ground.material_override = _ground_material
	_ground.cast_shadow = GeometryInstance3D.ShadowCastingSetting.SHADOW_CASTING_SETTING_OFF
	_ground.rotation.y = facing
	_ground.position = -fwd * (TRAIL_LENGTH * 0.5) + Vector3(0, 0.06, 0)
	add_child(_ground)


func _build_particles(fwd: Vector3) -> void:
	var glow := _create_glow_texture()
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.disable_receive_shadows = true
	material.albedo_texture = glow
	material.albedo_color = GLOW_COLOR

	var quad := QuadMesh.new()
	quad.size = Vector2(0.7, 0.7)
	quad.material = material

	_particles = CPUParticles3D.new()
	_particles.name = "TrailParticles"
	_particles.mesh = quad
	_particles.amount = PARTICLE_AMOUNT
	_particles.lifetime = PARTICLE_LIFETIME
	_particles.one_shot = true
	_particles.emitting = true
	_particles.explosiveness = 0.85
	_particles.spread = 12.0
	_particles.direction = -fwd
	_particles.gravity = Vector3(0, 0.4, 0)
	_particles.initial_velocity_min = 2.2
	_particles.initial_velocity_max = 4.4
	_particles.scale_amount_min = 0.4
	_particles.scale_amount_max = 0.9
	_particles.fixed_fps = 30
	_particles.color_ramp = _create_fade_gradient()
	_particles.position = -fwd * PARTICLE_OFFSET + Vector3(0, 0.9, 0)
	_particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_particles.emission_sphere_radius = 0.5
	_particles.cast_shadow = GeometryInstance3D.ShadowCastingSetting.SHADOW_CASTING_SETTING_OFF
	add_child(_particles)


func _make_material(texture: Texture2D) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.no_depth_test = true
	material.disable_receive_shadows = true
	material.albedo_texture = texture
	material.albedo_color = TRAIL_COLOR
	material.emission_enabled = true
	material.emission = Color(TRAIL_COLOR.r, TRAIL_COLOR.g, TRAIL_COLOR.b)
	material.emission_energy_multiplier = 1.4
	return material


func _animate() -> void:
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_method(_set_fade, 1.0, 0.0, TRAIL_FADE)
	tween.tween_callback(queue_free)


func _set_fade(alpha: float) -> void:
	var c := TRAIL_COLOR
	_streak_material.albedo_color = Color(c.r, c.g, c.b, alpha)
	_streak_material.emission = Color(c.r, c.g, c.b) * alpha
	_ground_material.albedo_color = Color(c.r, c.g, c.b, alpha * 0.8)
	_ground_material.emission = Color(c.r, c.g, c.b) * alpha


func _create_gradient_texture() -> ImageTexture:
	var img := Image.create(TEXTURE_SIZE, TEXTURE_SIZE, false, Image.FORMAT_RGBA8)
	for y in TEXTURE_SIZE:
		for x in TEXTURE_SIZE:
			var t := float(x) / float(TEXTURE_SIZE - 1)
			var alpha := pow(clampf(t, 0.0, 1.0), 1.6)
			img.set_pixel(x, y, Color(1, 1, 1, alpha))
	return ImageTexture.create_from_image(img)


func _create_fade_texture() -> ImageTexture:
	var img := Image.create(TEXTURE_SIZE, TEXTURE_SIZE, false, Image.FORMAT_RGBA8)
	for y in TEXTURE_SIZE:
		for x in TEXTURE_SIZE:
			var t := float(y) / float(TEXTURE_SIZE - 1)
			var alpha := pow(clampf(t, 0.0, 1.0), 1.8)
			img.set_pixel(x, y, Color(1, 1, 1, alpha))
	return ImageTexture.create_from_image(img)


func _create_glow_texture() -> ImageTexture:
	var img := Image.create(TEXTURE_SIZE, TEXTURE_SIZE, false, Image.FORMAT_RGBA8)
	var center := Vector2(TEXTURE_SIZE - 1, TEXTURE_SIZE - 1) * 0.5
	var max_dist := center.length()
	for y in TEXTURE_SIZE:
		for x in TEXTURE_SIZE:
			var d: float = Vector2(x, y).distance_to(center) / max_dist
			var alpha := pow(clampf(1.0 - d, 0.0, 1.0), 2.0)
			img.set_pixel(x, y, Color(1, 1, 1, alpha))
	return ImageTexture.create_from_image(img)


func _create_fade_gradient() -> Gradient:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.7, 1.0])
	gradient.colors = PackedColorArray([
		Color(GLOW_COLOR.r, GLOW_COLOR.g, GLOW_COLOR.b, 1.0),
		Color(GLOW_COLOR.r, GLOW_COLOR.g, GLOW_COLOR.b, 0.5),
		Color(GLOW_COLOR.r, GLOW_COLOR.g, GLOW_COLOR.b, 0.0),
	])
	return gradient