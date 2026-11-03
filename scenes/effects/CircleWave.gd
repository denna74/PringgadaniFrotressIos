extends Node3D

const START_SCALE: float = 0.2
const END_SCALE: float = 1.0
const RADIUS: float = 2.5
const DURATION: float = 0.15

var wave_color: Color = Color(1.0, 0.12, 0.08, 0.9)

var _ring: MeshInstance3D
var _material: StandardMaterial3D


func _ready() -> void:
	_build_ring()
	var tween := create_tween()
	tween.tween_method(_set_progress, 0.0, 1.0, DURATION)
	tween.tween_callback(queue_free)


func _build_ring() -> void:
	_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = RADIUS * 0.9
	torus.outer_radius = RADIUS
	torus.rings = 32
	torus.ring_segments = 12
	_ring.mesh = torus
	_ring.rotation.x = PI / 2.0
	_ring.scale = Vector3.ONE * START_SCALE

	_material = StandardMaterial3D.new()
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_material.no_depth_test = true
	_material.emission_enabled = true
	_material.emission = wave_color
	_material.albedo_color = wave_color
	_ring.material_override = _material
	add_child(_ring)


func _set_progress(progress: float) -> void:
	var eased := 1.0 - pow(1.0 - progress, 3.0)
	_ring.scale = Vector3.ONE * lerpf(START_SCALE, END_SCALE, eased)
	var fade := 1.0 - progress
	_material.albedo_color.a = wave_color.a * fade
	_material.emission = Color(wave_color.r, wave_color.g, wave_color.b) * fade
