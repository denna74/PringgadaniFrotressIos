extends Node3D

## Bayu Bajra's dash guard: a translucent blue half-sphere bowl projected in front
## of the king -- a wide, shallow bowl that also reaches lower toward the ground.
## Cheap by design: one low-poly hemisphere and a single gradient texture shared
## by every instance.

const DOME_RADIUS: float = 0.8
const BOWL_WIDTH: float = 1.6
const BOWL_HEIGHT: float = 1.35
const BOWL_DEPTH: float = 0.9
const DOME_COLOR: Color = Color(0.25, 0.6, 1.0, 0.28)
const FADE_IN_DURATION: float = 0.08
const FADE_OUT_DURATION: float = 0.1

static var _cached_gradient: ImageTexture = null

var _dome: MeshInstance3D = null
var _dome_material: StandardMaterial3D = null


func _ready() -> void:
	_build_dome()
	_fade_in()


func _build_dome() -> void:
	var sphere := SphereMesh.new()
	sphere.radius = DOME_RADIUS
	# is_hemisphere only produces a half sphere when height == radius; with
	# height == radius * 2 Godot renders an (almost) full ball instead.
	sphere.height = DOME_RADIUS
	sphere.is_hemisphere = true
	sphere.radial_segments = 24
	sphere.rings = 12

	_dome_material = StandardMaterial3D.new()
	_dome_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_dome_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	# Front faces only: the shell reads as a thin bubble, not a solid cut ball.
	_dome_material.cull_mode = BaseMaterial3D.CULL_BACK
	_dome_material.disable_receive_shadows = true
	_dome_material.albedo_texture = _create_gradient_texture()
	_dome_material.albedo_color = DOME_COLOR
	_dome_material.emission_enabled = true
	_dome_material.emission = DOME_COLOR
	_dome_material.emission_energy_multiplier = 0.6

	_dome = MeshInstance3D.new()
	_dome.name = "Dome"
	_dome.mesh = sphere
	_dome.material_override = _dome_material
	# The bowl's flat cut sits on local y=0 and the dome bulges toward +y; tip it
	# forward so the bowl covers what the king is dashing into. The non-uniform
	# scale then flattens it wide and stretches it down toward the ground.
	_dome.rotation.x = PI / 2.0
	_dome.scale = Vector3(BOWL_WIDTH, BOWL_HEIGHT, BOWL_DEPTH)
	add_child(_dome)


func _fade_in() -> void:
	_dome_material.albedo_color.a = 0.0
	var tween := create_tween()
	tween.tween_property(_dome_material, "albedo_color:a", DOME_COLOR.a, FADE_IN_DURATION)


func fade_out() -> void:
	if _dome_material == null:
		queue_free()
		return
	var tween := create_tween()
	tween.tween_property(_dome_material, "albedo_color:a", 0.0, FADE_OUT_DURATION)
	tween.tween_callback(queue_free)


# Radial alpha ramp: the rim of the shell is nearly opaque while the middle
# fades out, matching the reference's bright edge with a see-through centre.
# Built once and shared so repeated dashes allocate no new images.
func _create_gradient_texture() -> ImageTexture:
	if _cached_gradient != null:
		return _cached_gradient
	var size := 64
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := float(size - 1) * 0.5
	for y in size:
		for x in size:
			# Ellipse (wide, slightly flat) so the rim brightens along the bowl.
			var dx := (float(x) - center) / center
			var dy := (float(y) - center) / center
			var d := sqrt(dx * dx + dy * dy)
			var alpha := smoothstep(0.0, 1.0, d)
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, clampf(alpha, 0.0, 1.0)))
	_cached_gradient = ImageTexture.create_from_image(img)
	return _cached_gradient
