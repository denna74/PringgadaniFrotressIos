extends Node3D

# What a pendopo leaves behind when it falls.
#
# There is no building death art in the project -- pendopo_lite.glb is a static mesh with
# no skeleton or animation library -- so the collapse is done procedurally, following the
# EarthquakeEffect.gd pattern: an expanding shock ring, a fire burst, and a clone of the
# falling fort that sinks into the ground as the real building is freed.
#
# The fort copy is duplicated rather than reparented so the effect survives
# Pendopo.queue_free() -- that is the whole reason this is a separate node at all.

const RING_LIFETIME: float = 0.55
const FIRE_LIFETIME: float = 0.9
const SINK_DISTANCE: float = 4.0
const SINK_DURATION: float = 0.7
const FADE_DURATION: float = 0.7
const TOTAL_LIFETIME: float = 1.25

# The pendopo mesh is authored at 1 unit and scaled x3 by ModelLoader, so the ring has to
# be roughly three times the earthquake's to cover the footprint.
const RING_TARGET_SCALE: float = 6.5
const RING_START_SCALE: float = 0.6

var _ring: MeshInstance3D = null
var _fire: CPUParticles3D = null


func _ready() -> void:
	_build_ring()
	_build_fire()
	_animate_ring()
	_animate_fire()

	var cleanup: SceneTreeTimer = get_tree().create_timer(TOTAL_LIFETIME)
	cleanup.timeout.connect(queue_free)


func build_collapse(building: Node3D) -> void:
	# The collapse copy must sit in world space because the building it replaces is about to
	# be freed, taking its transform with it.
	var collapse := Node3D.new()
	collapse.name = "Collapse"
	collapse.global_transform = building.global_transform
	add_child(collapse)

	for child in building.get_children():
		if _should_skip(child):
			continue
		var copy := child.duplicate()
		copy.top_level = true
		copy.global_transform = child.global_transform
		collapse.add_child(copy)

	_animate_collapse(collapse)


# HP bars, the heal zone and the click overlay have no business collapsing with the fort.
func _should_skip(child: Node) -> bool:
	if child is Sprite3D or child is CPUParticles3D:
		return true
	var script: GDScript = child.get_script()
	return script == null or "heal_zone" in script.resource_path


func _build_ring() -> void:
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.9
	mesh.outer_radius = 1.0
	mesh.rings = 24
	mesh.ring_segments = 8

	_ring = MeshInstance3D.new()
	_ring.mesh = mesh
	_ring.scale = Vector3.ONE * RING_START_SCALE
	_ring.position.y = 0.15

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.no_depth_test = true
	mat.albedo_color = Color(1.0, 0.75, 0.35, 0.9)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.5, 0.15)
	mat.emission_energy_multiplier = 2.0
	mat.albedo_texture = _create_ring_texture()
	_ring.material_override = mat

	add_child(_ring)


func _build_fire() -> void:
	_fire = CPUParticles3D.new()
	_fire.amount = 80
	_fire.one_shot = true
	_fire.explosiveness = 0.92
	_fire.lifetime = FIRE_LIFETIME
	_fire.spread = 18.0
	_fire.gravity = Vector3(0, -2.0, 0)
	_fire.initial_velocity_min = 3.0
	_fire.initial_velocity_max = 7.0
	_fire.scale_amount_min = 1.2
	_fire.scale_amount_max = 2.6
	_fire.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_fire.emission_sphere_radius = 2.0
	_fire.direction = Vector3(0, 1, 0)
	_fire.spread = 45.0

	var quad := QuadMesh.new()
	quad.size = Vector2(0.9, 0.9)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = _create_glow_texture()
	quad.material = mat

	_fire.mesh = quad
	_fire.material_override = mat
	_fire.color_ramp = _make_fire_ramp()
	_fire.position.y = 1.2

	add_child(_fire)


func _animate_ring() -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(_ring, "scale", Vector3.ONE * RING_TARGET_SCALE, RING_LIFETIME)
	_fade_material(_ring, RING_LIFETIME)


func _animate_fire() -> void:
	_fire.emitting = true


# The fort sinks and fades out, so the explosion reads as a collapse rather than a puff
# over a castle that is still standing there.
func _animate_collapse(collapse: Node3D) -> void:
	var materials: Array[BaseMaterial3D] = _collect_materials(collapse)
	for mat in materials:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property(collapse, "position:y", -SINK_DISTANCE, SINK_DURATION)
	for mat in materials:
		tween.tween_property(mat, "albedo_color:a", 0.0, FADE_DURATION)


func _collect_materials(node: Node) -> Array[BaseMaterial3D]:
	var found: Array[BaseMaterial3D] = []
	for child in node.get_children():
		if child is MeshInstance3D:
			var mesh_instance := child as MeshInstance3D
			if mesh_instance.material_override == null:
				mesh_instance.material_override = _clone_surface_material(mesh_instance.mesh)
			found.append(mesh_instance.material_override)
		found.append_array(_collect_materials(child))
	return found


func _clone_surface_material(mesh: Mesh) -> BaseMaterial3D:
	if mesh == null or mesh.get_surface_count() == 0:
		return null
	var source := mesh.surface_get_material(0)
	var copy: BaseMaterial3D
	if source != null:
		copy = source.duplicate() as BaseMaterial3D
	else:
		copy = StandardMaterial3D.new()
	copy.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return copy


func _fade_material(mesh_instance: MeshInstance3D, duration: float) -> void:
	var mat := mesh_instance.material_override as BaseMaterial3D
	if mat == null:
		return
	var tween := create_tween()
	tween.tween_property(mat, "albedo_color:a", 0.0, duration)


func _make_fire_ramp() -> Gradient:
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	ramp.colors = PackedColorArray([
		Color(1.0, 1.0, 0.85, 1.0),
		Color(1.0, 0.6, 0.15, 0.9),
		Color(0.5, 0.15, 0.05, 0.0),
	])
	return ramp


func _create_glow_texture() -> ImageTexture:
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	var center := Vector2(32, 32)
	for y in range(64):
		for x in range(64):
			var dist := Vector2(x, y).distance_to(center) / 32.0
			var a: float = clampf(1.0 - dist, 0.0, 1.0)
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a * a))
	return ImageTexture.create_from_image(img)


func _create_ring_texture() -> ImageTexture:
	var img := Image.create(64, 8, false, Image.FORMAT_RGBA8)
	for y in range(8):
		for x in range(64):
			var t: float = float(y) / 7.0
			var a: float = clampf(1.0 - absf(t - 0.5) * 2.0, 0.0, 1.0)
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))
	return ImageTexture.create_from_image(img)
