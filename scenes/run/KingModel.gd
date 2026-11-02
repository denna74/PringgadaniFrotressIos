extends Node3D

var enemy_type: String = "infantry"
var is_boss: bool = false

var _skeleton: Skeleton3D = null
var _animation_player: AnimationPlayer = null
var _anim_lib: AnimationLibrary = null
var _current_animation: String = "idle"


func _ready() -> void:
	scale = Vector3(2.2, 2.2, 2.2)
	_build_skeleton()
	_build_meshes()
	_create_animations()
	if _animation_player:
		_animation_player.play("idle")


func _build_skeleton() -> void:
	_skeleton = Skeleton3D.new()
	_skeleton.name = "Skeleton3D"
	add_child(_skeleton)

	_add_bone("Hips", "", Vector3(0, 0.9, 0))
	_add_bone("Spine", "Hips", Vector3(0, 0.15, 0))
	_add_bone("Chest", "Spine", Vector3(0, 0.2, 0))
	_add_bone("Neck", "Chest", Vector3(0, 0.25, 0))
	_add_bone("Head", "Neck", Vector3(0, 0.15, 0))
	_add_bone("LeftUpperArm", "Chest", Vector3(-0.35, 0.15, 0))
	_add_bone("LeftLowerArm", "LeftUpperArm", Vector3(-0.25, 0, 0))
	_add_bone("LeftHand", "LeftLowerArm", Vector3(-0.2, 0, 0))
	_add_bone("RightUpperArm", "Chest", Vector3(0.35, 0.15, 0))
	_add_bone("RightLowerArm", "RightUpperArm", Vector3(0.25, 0, 0))
	_add_bone("RightHand", "RightLowerArm", Vector3(0.2, 0, 0))
	_add_bone("LeftUpperLeg", "Hips", Vector3(-0.12, -0.05, 0))
	_add_bone("LeftLowerLeg", "LeftUpperLeg", Vector3(0, -0.35, 0))
	_add_bone("LeftFoot", "LeftLowerLeg", Vector3(0, -0.35, 0.05))
	_add_bone("RightUpperLeg", "Hips", Vector3(0.12, -0.05, 0))
	_add_bone("RightLowerLeg", "RightUpperLeg", Vector3(0, -0.35, 0))
	_add_bone("RightFoot", "RightLowerLeg", Vector3(0, -0.35, 0.05))


func _add_bone(bone_name: String, parent_name: String, position: Vector3) -> void:
	var bone_idx := _skeleton.add_bone(bone_name)
	if parent_name != "":
		var parent_idx := _skeleton.find_bone(parent_name)
		_skeleton.set_bone_parent(bone_idx, parent_idx)
	var rest := Transform3D(Basis.IDENTITY, position)
	_skeleton.set_bone_rest(bone_idx, rest)


func _build_meshes() -> void:
	var skin_color := Color(0.87, 0.72, 0.52)
	var cloth_color := Color(0.82, 0.62, 0.30)
	var shoe_color := Color(0.4, 0.25, 0.15)
	var crown_color := Color(0.95, 0.85, 0.20)

	_attach_mesh("Head", _make_sphere(0.18), _make_mat(skin_color))
	_attach_mesh("Chest", _make_box(0.4, 0.35, 0.25), _make_mat(cloth_color))
	_attach_mesh("LeftUpperArm", _make_cylinder(0.06, 0.25), _make_mat(skin_color))
	_attach_mesh("LeftLowerArm", _make_cylinder(0.05, 0.22), _make_mat(skin_color))
	_attach_mesh("LeftHand", _make_sphere(0.05), _make_mat(skin_color))
	_attach_mesh("RightUpperArm", _make_cylinder(0.06, 0.25), _make_mat(skin_color))
	_attach_mesh("RightLowerArm", _make_cylinder(0.05, 0.22), _make_mat(skin_color))
	_attach_mesh("RightHand", _make_sphere(0.05), _make_mat(skin_color))
	_attach_mesh("LeftUpperLeg", _make_cylinder(0.07, 0.35), _make_mat(cloth_color))
	_attach_mesh("LeftLowerLeg", _make_cylinder(0.06, 0.32), _make_mat(cloth_color))
	_attach_mesh("LeftFoot", _make_box(0.1, 0.06, 0.15), _make_mat(shoe_color))
	_attach_mesh("RightUpperLeg", _make_cylinder(0.07, 0.35), _make_mat(cloth_color))
	_attach_mesh("RightLowerLeg", _make_cylinder(0.06, 0.32), _make_mat(cloth_color))
	_attach_mesh("RightFoot", _make_box(0.1, 0.06, 0.15), _make_mat(shoe_color))

	var crown_mesh := _make_box(0.22, 0.1, 0.22)
	_attach_mesh("Head", crown_mesh, _make_mat(crown_color), Vector3(0, 0.22, 0))


func _attach_mesh(bone_name: String, mesh: Mesh, mat: Material, offset: Vector3 = Vector3.ZERO) -> void:
	var attachment := BoneAttachment3D.new()
	attachment.bone_name = bone_name
	_skeleton.add_child(attachment)

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = mesh
	mesh_instance.material_override = mat
	mesh_instance.position = offset
	attachment.add_child(mesh_instance)


func _create_animations() -> void:
	_animation_player = AnimationPlayer.new()
	_animation_player.name = "AnimationPlayer"
	_anim_lib = AnimationLibrary.new()
	_animation_player.add_animation_library("", _anim_lib)
	add_child(_animation_player)

	_create_idle_animation()
	_create_walk_animation()
	_create_attack_animation()


func _create_idle_animation() -> void:
	var anim := Animation.new()
	anim.length = 1.5
	anim.loop_mode = Animation.LOOP_LINEAR

	var spine_idx := _skeleton.find_bone("Spine")
	var track_idx := anim.add_track(Animation.TYPE_POSITION_3D)
	anim.track_set_path(track_idx, "Skeleton3D/Spine")
	anim.track_insert_key(track_idx, 0.0, Vector3(0, 0.15, 0))
	anim.track_insert_key(track_idx, 0.75, Vector3(0, 0.17, 0))
	anim.track_insert_key(track_idx, 1.5, Vector3(0, 0.15, 0))

	_anim_lib.add_animation("idle", anim)


func _create_walk_animation() -> void:
	var anim := Animation.new()
	anim.length = 0.6
	anim.loop_mode = Animation.LOOP_LINEAR

	var bones := ["LeftUpperLeg", "RightUpperLeg", "LeftUpperArm", "RightUpperArm", "Spine"]
	for bone_name in bones:
		var track_idx := anim.add_track(Animation.TYPE_POSITION_3D)
		anim.track_set_path(track_idx, "Skeleton3D/" + bone_name)

	# Left leg forward, right leg back
	var left_leg_idx := 0
	var right_leg_idx := 1
	anim.track_insert_key(left_leg_idx, 0.0, Vector3(-0.12, -0.05, 0.1))
	anim.track_insert_key(left_leg_idx, 0.3, Vector3(-0.12, -0.05, -0.1))
	anim.track_insert_key(left_leg_idx, 0.6, Vector3(-0.12, -0.05, 0.1))

	anim.track_insert_key(right_leg_idx, 0.0, Vector3(0.12, -0.05, -0.1))
	anim.track_insert_key(right_leg_idx, 0.3, Vector3(0.12, -0.05, 0.1))
	anim.track_insert_key(right_leg_idx, 0.6, Vector3(0.12, -0.05, -0.1))

	# Arms swing opposite to legs
	var left_arm_idx := 2
	var right_arm_idx := 3
	anim.track_insert_key(left_arm_idx, 0.0, Vector3(-0.35, 0.15, -0.08))
	anim.track_insert_key(left_arm_idx, 0.3, Vector3(-0.35, 0.15, 0.08))
	anim.track_insert_key(left_arm_idx, 0.6, Vector3(-0.35, 0.15, -0.08))

	anim.track_insert_key(right_arm_idx, 0.0, Vector3(0.35, 0.15, 0.08))
	anim.track_insert_key(right_arm_idx, 0.3, Vector3(0.35, 0.15, -0.08))
	anim.track_insert_key(right_arm_idx, 0.6, Vector3(0.35, 0.15, 0.08))

	# Body bob
	var spine_idx := 4
	anim.track_insert_key(spine_idx, 0.0, Vector3(0, 0.15, 0))
	anim.track_insert_key(spine_idx, 0.15, Vector3(0, 0.17, 0))
	anim.track_insert_key(spine_idx, 0.3, Vector3(0, 0.15, 0))
	anim.track_insert_key(spine_idx, 0.45, Vector3(0, 0.17, 0))
	anim.track_insert_key(spine_idx, 0.6, Vector3(0, 0.15, 0))

	_anim_lib.add_animation("walk", anim)


func _create_attack_animation() -> void:
	var anim := Animation.new()
	anim.length = 0.35

	var right_arm_idx := anim.add_track(Animation.TYPE_ROTATION_3D)
	anim.track_set_path(right_arm_idx, "Skeleton3D/RightUpperArm")
	anim.track_insert_key(right_arm_idx, 0.0, Quaternion.IDENTITY)
	anim.track_insert_key(right_arm_idx, 0.1, Quaternion(Vector3(0, 0, 1), -1.2))
	anim.track_insert_key(right_arm_idx, 0.25, Quaternion(Vector3(0, 0, 1), 0.3))
	anim.track_insert_key(right_arm_idx, 0.35, Quaternion.IDENTITY)

	var chest_idx := anim.add_track(Animation.TYPE_ROTATION_3D)
	anim.track_set_path(chest_idx, "Skeleton3D/Chest")
	anim.track_insert_key(chest_idx, 0.0, Quaternion.IDENTITY)
	anim.track_insert_key(chest_idx, 0.1, Quaternion(Vector3(0, 0, 1), -0.15))
	anim.track_insert_key(chest_idx, 0.35, Quaternion.IDENTITY)

	_anim_lib.add_animation("attack", anim)


func play_walk() -> void:
	if _current_animation != "walk":
		_current_animation = "walk"
		if _animation_player:
			_animation_player.play("walk")


func play_idle() -> void:
	if _current_animation != "idle":
		_current_animation = "idle"
		if _animation_player:
			_animation_player.play("idle")


func play_attack() -> void:
	_current_animation = "attack"
	if _animation_player:
		_animation_player.play("attack")
		await _animation_player.animation_finished
		_current_animation = "idle"
		_animation_player.play("idle")


func _make_cylinder(radius: float, height: float) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 8
	return mesh


func _make_sphere(radius: float) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.radial_segments = 8
	mesh.rings = 4
	return mesh


func _make_box(size_x: float, size_y: float, size_z: float) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(size_x, size_y, size_z)
	return mesh


func _make_mat(albedo: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = albedo
	mat.roughness = 0.8
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	return mat
