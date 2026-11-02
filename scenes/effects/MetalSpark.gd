extends Node3D

## Metal-on-weapon impact: a short orange/yellow spark burst plus a billboard flash, spawned
## wherever a damaging hit lands on a unit (enemy, soldier, king). Buildings are deliberately
## excluded -- no building receiver calls spawn().
##
## Hot path: a packed earthquake or a volley of tower arrows can land a dozen hits in one
## frame, so instances are pooled (no spawn/free churn per hit), share every mesh/material/
## texture statically, and are bounded by MAX_SPARKS_PER_FRAME so a burst cannot snowball.
## Everything below is a tuning knob; the colours are procedural (no art assets).

const SELF_PATH: String = "res://scenes/effects/MetalSpark.gd"

const POOL_SIZE: int = 20
const MAX_SPARKS_PER_FRAME: int = 3

const HIT_HEIGHT: float = 1.0
const FLASH_TIME: float = 0.12
const SPARK_LIFETIME: float = 0.4

const SPARK_COLOR: Color = Color(1.0, 0.78, 0.25)
const SPARK_MID: Color = Color(1.0, 0.5, 0.08)
const SPARK_END: Color = Color(1.0, 0.28, 0.02)
const FLASH_COLOR: Color = Color(1.0, 0.68, 0.22)

const SPARK_AMOUNT: int = 14
const SPARK_PARTICLE_LIFETIME: float = 0.3
const SPARK_VELOCITY_MIN: float = 3.0
const SPARK_VELOCITY_MAX: float = 6.0
const SPARK_SPREAD_DEG: float = 105.0
const SPARK_EMIT_RADIUS: float = 0.4
const SPARK_GRAVITY: float = 9.0
const SPARK_QUAD := Vector2(0.045, 0.2)

const FLASH_SIZE := 0.32
const FLASH_START_SCALE: float = 0.3
const FLASH_END_SCALE: float = 0.85

const TEXTURE_SIZE := 128

static var _pool: Array[Node3D] = []
static var _last_frame: int = -1
static var _spawned_this_frame: int = 0

static var _glow_tex: ImageTexture = null
static var _spark_mesh: QuadMesh = null
static var _spark_mat: StandardMaterial3D = null
static var _flash_mesh: QuadMesh = null

var _particles: CPUParticles3D = null
var _flash: MeshInstance3D = null
var _flash_mat: StandardMaterial3D = null
var _tween: Tween = null
var _active: bool = false


## Spawns one spark at the strike point of `victim`, parented to the victim's parent so it
## stays world-anchored (the victim itself may move, die, or be recycled into a pool).
static func spawn(victim: Node3D) -> void:
	if victim == null or not is_instance_valid(victim) or not victim.is_inside_tree():
		return
	var parent: Node = victim.get_parent()
	if parent == null or not parent.is_inside_tree():
		return
	var frame: int = Engine.get_physics_frames()
	if frame != _last_frame:
		_last_frame = frame
		_spawned_this_frame = 0
	if _spawned_this_frame >= MAX_SPARKS_PER_FRAME:
		return
	_spawned_this_frame += 1
	var spark: Node3D = _acquire()
	spark.name = "MetalSpark"
	parent.add_child(spark)
	spark.global_position = victim.global_position + Vector3(0.0, HIT_HEIGHT, 0.0)
	spark.call("play")


static func _acquire() -> Node3D:
	while not _pool.is_empty():
		var spark: Node3D = _pool.pop_back()
		if is_instance_valid(spark):
			return spark
	var spark := Node3D.new()
	spark.set_script(load(SELF_PATH))
	return spark


func _ready() -> void:
	if get_child_count() == 0:
		_build()


func _build() -> void:
	_spark_mat = _get_spark_material()

	_particles = CPUParticles3D.new()
	_particles.name = "Sparks"
	_particles.mesh = _get_spark_mesh()
	_particles.amount = SPARK_AMOUNT
	_particles.lifetime = SPARK_PARTICLE_LIFETIME
	_particles.one_shot = true
	_particles.emitting = false
	_particles.explosiveness = 0.95
	_particles.spread = SPARK_SPREAD_DEG
	_particles.direction = Vector3.UP
	_particles.gravity = Vector3(0.0, -SPARK_GRAVITY, 0.0)
	_particles.initial_velocity_min = SPARK_VELOCITY_MIN
	_particles.initial_velocity_max = SPARK_VELOCITY_MAX
	_particles.scale_amount_min = 0.35
	_particles.scale_amount_max = 0.7
	_particles.fixed_fps = 30
	_particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_particles.emission_sphere_radius = SPARK_EMIT_RADIUS
	_particles.color_ramp = _create_ramp()
	_particles.cast_shadow = GeometryInstance3D.ShadowCastingSetting.SHADOW_CASTING_SETTING_OFF
	add_child(_particles)

	_flash_mat = _make_flash_material()
	_flash = MeshInstance3D.new()
	_flash.name = "Flash"
	_flash.mesh = _get_flash_mesh()
	_flash.material_override = _flash_mat
	_flash.cast_shadow = GeometryInstance3D.ShadowCastingSetting.SHADOW_CASTING_SETTING_OFF
	add_child(_flash)


func play() -> void:
	_active = true
	visible = true
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_set_flash(0.0)
	if _particles != null:
		_particles.restart()
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_QUAD)
	_tween.set_ease(Tween.EASE_OUT)
	_tween.tween_method(_set_flash, 0.0, 1.0, FLASH_TIME)
	var wait: float = maxf(0.0, SPARK_LIFETIME - FLASH_TIME)
	if wait > 0.0:
		_tween.tween_interval(wait)
	_tween.tween_callback(_release)


func _set_flash(t: float) -> void:
	if _flash == null or _flash_mat == null:
		return
	var alpha: float = clampf(1.0 - t, 0.0, 1.0)
	_flash_mat.albedo_color = Color(FLASH_COLOR.r, FLASH_COLOR.g, FLASH_COLOR.b, alpha)
	_flash.scale = Vector3.ONE * lerpf(FLASH_START_SCALE, FLASH_END_SCALE, t)


func _release() -> void:
	if not _active:
		return
	_active = false
	if _particles != null:
		_particles.emitting = false
	visible = false
	if _pool.size() >= POOL_SIZE:
		queue_free()
		return
	var parent: Node = get_parent()
	if parent != null and is_inside_tree():
		parent.remove_child(self)
	if is_instance_valid(self):
		_pool.append(self)


static func _get_spark_material() -> StandardMaterial3D:
	if _spark_mat == null:
		_spark_mat = StandardMaterial3D.new()
		_spark_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_spark_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_spark_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_spark_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		_spark_mat.no_depth_test = true
		_spark_mat.disable_receive_shadows = true
		# Without this the CPUParticles3D color_ramp is ignored and every spark draws white.
		_spark_mat.vertex_color_use_as_albedo = true
		_spark_mat.albedo_texture = _get_glow_texture()
		_spark_mat.albedo_color = Color.WHITE
	return _spark_mat


static func _get_spark_mesh() -> QuadMesh:
	if _spark_mesh == null:
		var quad := QuadMesh.new()
		quad.size = SPARK_QUAD
		quad.material = _get_spark_material()
		_spark_mesh = quad
	return _spark_mesh


static func _get_flash_mesh() -> QuadMesh:
	if _flash_mesh == null:
		var quad := QuadMesh.new()
		quad.size = Vector2(FLASH_SIZE, FLASH_SIZE)
		_flash_mesh = quad
	return _flash_mesh


static func _make_flash_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.no_depth_test = true
	material.disable_receive_shadows = true
	material.albedo_texture = _get_glow_texture()
	material.albedo_color = Color(FLASH_COLOR.r, FLASH_COLOR.g, FLASH_COLOR.b, 1.0)
	return material


static func _get_glow_texture() -> ImageTexture:
	if _glow_tex == null:
		var img := Image.create(TEXTURE_SIZE, TEXTURE_SIZE, false, Image.FORMAT_RGBA8)
		var center := Vector2(TEXTURE_SIZE - 1, TEXTURE_SIZE - 1) * 0.5
		var max_dist := center.length()
		for y in TEXTURE_SIZE:
			for x in TEXTURE_SIZE:
				var d: float = Vector2(x, y).distance_to(center) / max_dist
				var alpha := pow(clampf(1.0 - d, 0.0, 1.0), 2.0)
				img.set_pixel(x, y, Color(1, 1, 1, alpha))
		_glow_tex = ImageTexture.create_from_image(img)
	return _glow_tex


static func _create_ramp() -> Gradient:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	gradient.colors = PackedColorArray([
		Color(SPARK_COLOR.r, SPARK_COLOR.g, SPARK_COLOR.b, 1.0),
		Color(SPARK_MID.r, SPARK_MID.g, SPARK_MID.b, 0.9),
		Color(SPARK_END.r, SPARK_END.g, SPARK_END.b, 0.0),
	])
	return gradient
