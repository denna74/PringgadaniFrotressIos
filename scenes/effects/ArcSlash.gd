extends Node3D

const SLASH_WIDTH: float = 3.6
const SLASH_HEIGHT: float = 3.0
const SLASH_DELAY: float = 0.12
const SLASH_DURATION: float = 0.15
const DEFAULT_SLASH_COLOR: Color = Color(0.9, 0.7, 0.1, 0.8)
const SLASH_TILT_DEG: float = -55.0
const CRESCENT_OUTER_N: float = -0.20
const CRESCENT_OUTER_R: float = 0.37
const CRESCENT_INNER_N: float = -0.50
const CRESCENT_INNER_R: float = 0.55
const CRESCENT_ROT_DEG: float = -40.0
const CRESCENT_LIFT_V: float = 0.15
const TEXTURE_SIZE := 256

static var _cached_textures: Dictionary = {}

var mirror: bool = false
var slash_color: Color = DEFAULT_SLASH_COLOR

var _quad: MeshInstance3D = null
var _material: StandardMaterial3D = null


func _ready() -> void:
	_build_quad()
	_animate()


func _build_quad() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(SLASH_WIDTH, SLASH_HEIGHT)

	_material = StandardMaterial3D.new()
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.disable_receive_shadows = true
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_material.no_depth_test = true
	_material.albedo_texture = _create_slash_texture()
	_material.albedo_color = slash_color
	_material.emission_enabled = true
	_material.emission = slash_color

	_quad = MeshInstance3D.new()
	_quad.mesh = quad
	_quad.material_override = _material
	_quad.rotation_degrees = Vector3(SLASH_TILT_DEG, 0.0, 0.0)
	add_child(_quad)


func _animate() -> void:
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_interval(SLASH_DELAY)
	tween.tween_method(_set_progress, 0.0, 1.0, SLASH_DURATION)
	tween.tween_callback(queue_free)


func _set_progress(t: float) -> void:
	if _quad == null or _material == null:
		return
	var fade_in := clampf(t / 0.18, 0.0, 1.0)
	var fade_out := clampf(1.0 - (t - 0.6) / 0.4, 0.0, 1.0)
	var alpha := minf(fade_in, fade_out)
	_quad.scale = Vector3.ONE * lerpf(0.85, 1.15, t)
	_material.albedo_color = Color(
		slash_color.r, slash_color.g, slash_color.b, slash_color.a * alpha
	)
	_material.emission = slash_color * alpha


func _create_slash_texture() -> ImageTexture:
	var cache_key: String = str(mirror)
	if _cached_textures.has(cache_key):
		return _cached_textures[cache_key] as ImageTexture
	var img := Image.create(TEXTURE_SIZE, TEXTURE_SIZE, false, Image.FORMAT_RGBA8)
	for y in TEXTURE_SIZE:
		for x in TEXTURE_SIZE:
			var u := float(x) / float(TEXTURE_SIZE - 1)
			var v := float(y) / float(TEXTURE_SIZE - 1)
			var sample := Vector2(u, v)
			if mirror:
				sample.x = 1.0 - sample.x
			var alpha := _crescent_alpha(sample)
			img.set_pixel(x, y, Color(1, 1, 1, alpha))
	var texture := ImageTexture.create_from_image(img)
	_cached_textures[cache_key] = texture
	return texture


func _crescent_alpha(p: Vector2) -> float:
	var axis := Vector2(-1.0, 1.0).normalized()
	var naxis := Vector2(1.0, 1.0).normalized()
	var rel := p - Vector2(0.5, 0.5)
	var rot := deg_to_rad(CRESCENT_ROT_DEG)
	var cr := cos(rot)
	var sr := sin(rot)
	rel = Vector2(rel.x * cr - rel.y * sr, rel.x * sr + rel.y * cr)
	rel.y += CRESCENT_LIFT_V
	var s := rel.dot(axis)
	var n := rel.dot(naxis)
	var q_out := CRESCENT_OUTER_R * CRESCENT_OUTER_R - s * s
	var q_in := CRESCENT_INNER_R * CRESCENT_INNER_R - s * s
	if q_out <= 0.0 or q_in <= 0.0:
		return 0.0
	var n_high := CRESCENT_OUTER_N + sqrt(q_out)
	var n_low := CRESCENT_INNER_N + sqrt(q_in)
	var w := n_high - n_low
	if w <= 0.0:
		return 0.0
	var t := clampf((n - n_low) / w, 0.0, 1.0)
	return sin(PI * t)
