class_name ModelLoader extends RefCounted

const ENEMY_IDLE_PATH: String = "res://assets/models/enemy/idle.glb"
const ENEMY_RUN_PATH: String = "res://assets/models/enemy/run.glb"
const ENEMY_ATTACK_PATH: String = "res://assets/models/enemy/attack.glb"
const ENEMY_DEAD_PATH: String = "res://assets/models/enemy/dead.glb"
const KING_IDLE_PATH: String = "res://assets/models/king/idle.glb"
const KING_DASH_PATH: String = "res://assets/models/king/dash.glb"
const KING_FLY_PATH: String = "res://assets/models/king/fly.glb"
const KING_ATTACK1_PATH: String = "res://assets/models/king/attack_1.glb"
const KING_ATTACK2_PATH: String = "res://assets/models/king/attack_2.glb"
const KING_ATTACK3_PATH: String = "res://assets/models/king/attack_3.glb"
const BOMA_IDLE_PATH: String = "res://assets/models/boss/boma/idle.glb"
const BOMA_RUN_PATH: String = "res://assets/models/boss/boma/run.glb"
const BOMA_ATTACK_PATH: String = "res://assets/models/boss/boma/attack.glb"
const BOMA_DEAD_PATH: String = "res://assets/models/boss/boma/dead.glb"
const BOMA_DASH_PATH: String = "res://assets/models/boss/boma/dash.glb"
const BOMA_POWER_ATTACK_PATH: String = "res://assets/models/boss/boma/power_attack_skill.glb"
const ASWATAMA_IDLE_PATH: String = "res://assets/models/boss/aswatama/idle.glb"
const ASWATAMA_RUN_PATH: String = "res://assets/models/boss/aswatama/run.glb"
const ASWATAMA_ATTACK_PATH: String = "res://assets/models/boss/aswatama/attack.glb"
const ASWATAMA_DEAD_PATH: String = "res://assets/models/boss/aswatama/dead.glb"
const ASWATAMA_DASH_PATH: String = "res://assets/models/boss/aswatama/dash.glb"
const ASWATAMA_EARTHQUAKE_PATH: String = "res://assets/models/boss/aswatama/earthquake_skill.glb"
const KARNA_IDLE_PATH: String = "res://assets/models/boss/karna/idle.glb"
const KARNA_RUN_PATH: String = "res://assets/models/boss/karna/run.glb"
const KARNA_ATTACK1_PATH: String = "res://assets/models/boss/karna/attack_1.glb"
const KARNA_ATTACK2_PATH: String = "res://assets/models/boss/karna/attack_2.glb"
const KARNA_ATTACK3_PATH: String = "res://assets/models/boss/karna/attack_3.glb"
const KARNA_DEAD_PATH: String = "res://assets/models/boss/karna/dead.glb"
const KARNA_DASH_PATH: String = "res://assets/models/boss/karna/dash.glb"
const KARNA_EARTHQUAKE_PATH: String = "res://assets/models/boss/karna/earth_quake.glb"
const KARNA_BERSERK_PATH: String = "res://assets/models/boss/karna/berserk.glb"
const BOSS_IDLE_PATH: String = "res://assets/models/boss/kurawa_boss_idle.glb"
const BOSS_RUN_PATH: String = "res://assets/models/boss/kurawa_boss_run.glb"
const BOSS_ATTACK_PATH: String = "res://assets/models/boss/kurawa_boss_attack.glb"
const BOSS_DEAD_PATH: String = "res://assets/models/boss/kurawa_boss_dead.glb"
const SOLDIER_ARCHER_IDLE_PATH: String = "res://assets/models/soldier_archer/idle.glb"
const SOLDIER_ARCHER_RUN_PATH: String = "res://assets/models/soldier_archer/run.glb"
const SOLDIER_ARCHER_ATTACK_PATH: String = "res://assets/models/soldier_archer/attack.glb"
const SOLDIER_ARCHER_DEAD_PATH: String = "res://assets/models/soldier_archer/dead.glb"
const ENEMY_ARCHER_IDLE_PATH: String = "res://assets/models/enemy_archer/idle.glb"
const ENEMY_ARCHER_RUN_PATH: String = "res://assets/models/enemy_archer/run.glb"
const ENEMY_ARCHER_ATTACK_PATH: String = "res://assets/models/enemy_archer/attack.glb"
const ENEMY_ARCHER_DEAD_PATH: String = "res://assets/models/enemy_archer/dead.glb"
const SOLDIER_IDLE_PATH: String = "res://assets/models/soldier/idle.glb"
const SOLDIER_RUN_PATH: String = "res://assets/models/soldier/run.glb"
const SOLDIER_ATTACK_PATH: String = "res://assets/models/soldier/attack.glb"
const SOLDIER_DEAD_PATH: String = "res://assets/models/soldier/dead.glb"
const KING_EARTH_QUAKE_PATH: String = "res://assets/models/king/earth_quake_skill.glb"
const KING_BERSERK_PATH: String = "res://assets/models/king/berserk.glb"

const BUILDING_MODEL_PATHS: Dictionary = {
	"pendopo": "res://assets/models/buildings/pendopo_mobile.glb",
	"barak": "res://assets/models/buildings/barak_mobile.glb",
	"tambang_emas": "res://assets/models/buildings/tambang_mobile.glb",
	"menara": "res://assets/models/buildings/archer_tower_mobile.glb",
}

# Positive value favors coarser auto-generated LODs. Buildings are the heaviest static
# meshes in a run, so biasing them toward cheaper LODs is the cheapest triangle win.
const BUILDING_LOD_BIAS: float = 2.0
const KING_HEIGHT_SCALE: float = 1.148
const SOLDIER_INFANTRY_HEIGHT_SCALE: float = 0.913
const SOLDIER_ARCHER_HEIGHT_SCALE: float = 0.918

static func load_building_model(building_id: String, grid_size: Vector2i = Vector2i(1, 1)) -> Node3D:
	if not BUILDING_MODEL_PATHS.has(building_id):
		return null
	var glb_path: String = BUILDING_MODEL_PATHS[building_id]
	if not ResourceLoader.exists(glb_path):
		return null
	var scene: PackedScene = load(glb_path)
	if scene == null:
		return null
	var instance: Node3D = scene.instantiate()
	var grid_scale: float = maxf(grid_size.x, grid_size.y)
	var unscaled_min_y: float = _find_min_y_unscaled(instance)
	instance.position.y = -unscaled_min_y * grid_scale
	instance.scale = Vector3(grid_scale, grid_scale, grid_scale)
	# The *_mobile.glb builds are decimated to ~50k triangles each (down from 200k-678k),
	# so they are cheap enough to keep casting shadows like every other world object.
	# Godot generates LODs for these GLBs on import (meshes/generate_lods). A positive
	# instance LOD bias makes the renderer pick a coarser level sooner, which cuts the
	# triangle budget on the small phone screens this game targets. Only buildings get
	# this; skinned rigs need their full-resolution mesh for animation.
	_set_lod_bias(instance, BUILDING_LOD_BIAS)
	return instance
	return instance


static func _set_lod_bias(root: Node3D, bias: float) -> void:
	for child in root.find_children("*", "MeshInstance3D", true):
		var mi := child as MeshInstance3D
		if mi:
			mi.lod_bias = bias


static func _find_min_y_unscaled(node: Node3D) -> float:
	var min_y: float = 0.0
	for child in node.get_children():
		if child is MeshInstance3D:
			var mesh: Mesh = child.mesh
			if mesh == null:
				continue
			var aabb: AABB = mesh.get_aabb()
			var y: float = child.position.y + aabb.position.y
			if y < min_y:
				min_y = y
		elif child is Node3D:
			var child_min: float = _find_min_y_unscaled(child) + child.position.y
			if child_min < min_y:
				min_y = child_min
	return min_y

static func load_model(fbx_path: String, fallback_scene: PackedScene = null) -> Node3D:
	if ResourceLoader.exists(fbx_path):
		var scene: PackedScene = load(fbx_path)
		if scene:
			var instance: Node3D = scene.instantiate()
			_setup_animations(instance)
			return instance

	if fallback_scene:
		return fallback_scene.instantiate()

	return _create_primitive_fallback()

static var _enemy_templates: Dictionary = {}
static var _boss_templates: Dictionary = {}
static var _king_template: Node3D = null


# The king is the heaviest model in the game: it merges seven GLB animation sets on
# load. Cache the merged template like the enemies and bosses do, so the warmup pass and
# the run itself do not each pay for that merge.
static func load_king() -> Node3D:
	if _king_template == null:
		_king_template = _build_king_template()
	return _king_template.duplicate()


static func _build_king_template() -> Node3D:
	var model: Node3D

	if ResourceLoader.exists(KING_IDLE_PATH):
		model = load_model(KING_IDLE_PATH)
		_merge_king_animations(model)
	else:
		model = _create_primitive_fallback()
	model.scale = Vector3.ONE * KING_HEIGHT_SCALE

	return model


# One template per boss rig, built on first use and duplicated thereafter.
# The requested rig is always the key: the cache check below builds it on first use,
# and an unknown rig falls back to kurawa inside boss_animation_paths().
static func load_boss(rig: String = "kurawa") -> Node3D:
	if not _boss_templates.has(rig):
		_boss_templates[rig] = _build_boss_template(rig)
	return _boss_templates[rig].duplicate()

static func load_enemy(type: String, is_boss: bool = false) -> Node3D:
	if is_boss:
		return load_boss("kurawa")

	var key: String = type if type == "archer" else "default"
	if not _enemy_templates.has(key):
		_enemy_templates[key] = _build_enemy_template(type == "archer")
	return _enemy_templates[key].duplicate()


# These ranged attack clips hold the bow out to the side, so the body pose is offset
# from the arrow's firing line. Rotate the torso to align the pose with the target.
const RANGED_ATTACK_YAW_OFFSET_DEG: float = -90.0


# World position of the bow hand. In the archery clips the LEFT hand holds the bow
# extended out to the side while the right hand draws the string in to the chest, so
# firing from the body centreline makes the arrow look like it leaves from beside the
# archer. Sourcing the muzzle from the bone puts it where the hand (and bow) actually is.
static func bow_hand_point(root: Node3D) -> Vector3:
	var fallback: Vector3 = root.global_position + Vector3(0.0, 1.1, 0.0)
	for child in root.find_children("*", "Skeleton3D", true, false):
		var skeleton := child as Skeleton3D
		var bone_idx: int = skeleton.find_bone("mixamorig_LeftHand")
		if bone_idx < 0:
			bone_idx = skeleton.find_bone("LeftHand")
		if bone_idx < 0:
			break
		var origin: Vector3 = skeleton.get_bone_global_pose(bone_idx).origin
		if origin == Vector3.ZERO:
			origin = skeleton.get_bone_global_rest(bone_idx).origin
		return skeleton.to_global(origin)
	return fallback


static func set_ground_shadow(root: Node3D, enabled: bool, size: Vector2) -> void:
	var shadow := root.get_node_or_null("CharacterGroundShadow") as MeshInstance3D
	if shadow == null:
		shadow = MeshInstance3D.new()
		shadow.name = "CharacterGroundShadow"
		var plane := PlaneMesh.new()
		plane.size = size
		shadow.mesh = plane
		var material := ShaderMaterial.new()
		var shader := Shader.new()
		shader.code = """
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded;

void fragment() {
	float radius = length(UV * 2.0 - vec2(1.0));
	float opacity = (1.0 - smoothstep(0.25, 1.0, radius)) * 0.3;
	ALBEDO = vec3(0.015, 0.02, 0.035);
	ALPHA = opacity;
}
"""
		material.shader = shader
		shadow.material_override = material
		shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(shadow)
	else:
		var plane := shadow.mesh as PlaneMesh
		if plane != null:
			plane.size = size
	shadow.position = Vector3(0.0, -root.position.y + 0.025, 0.0)
	shadow.visible = enabled


static func boss_animation_paths(rig: String = "kurawa") -> Dictionary:
	match rig:
		"boma":
			return {
				"idle": BOMA_IDLE_PATH, "run": BOMA_RUN_PATH, "attack": BOMA_ATTACK_PATH,
				"dead": BOMA_DEAD_PATH, "dash": BOMA_DASH_PATH,
				"power_attack": BOMA_POWER_ATTACK_PATH,
			}
		"aswatama":
			return {
				"idle": ASWATAMA_IDLE_PATH, "run": ASWATAMA_RUN_PATH, "attack": ASWATAMA_ATTACK_PATH,
				"dead": ASWATAMA_DEAD_PATH, "dash": ASWATAMA_DASH_PATH,
				"earthquake": ASWATAMA_EARTHQUAKE_PATH,
			}
		"karna":
			return {
				"idle": KARNA_IDLE_PATH, "run": KARNA_RUN_PATH,
				"attack": KARNA_ATTACK1_PATH, "attack_2": KARNA_ATTACK2_PATH,
				"attack_3": KARNA_ATTACK3_PATH, "dead": KARNA_DEAD_PATH,
				"dash": KARNA_DASH_PATH, "earthquake": KARNA_EARTHQUAKE_PATH,
				"berserk": KARNA_BERSERK_PATH,
			}
		_:
			return {
				"idle": BOSS_IDLE_PATH, "run": BOSS_RUN_PATH,
				"attack": BOSS_ATTACK_PATH, "dead": BOSS_DEAD_PATH,
			}


static func _build_boss_template(rig: String = "kurawa") -> Node3D:
	var paths: Dictionary = boss_animation_paths(rig)
	var model: Node3D
	if ResourceLoader.exists(paths["idle"]):
		model = load_model(paths["idle"])
		model.set_meta("boss_rig", rig)
		_merge_boss_animations(model, paths)
	else:
		model = _create_enemy_primitive("infantry")
	var height_scale: float = 1.5
	match rig:
		"boma":
			height_scale = 1.157
		"aswatama":
			height_scale = 1.260
		"karna":
			height_scale = 1.001
	model.scale = Vector3.ONE * height_scale
	return model


static func _build_enemy_template(archer: bool = false) -> Node3D:
	var paths: Dictionary = enemy_animation_paths(archer)
	var model: Node3D
	if ResourceLoader.exists(paths["idle"]):
		model = load_model(paths["idle"])
		_merge_anim_set(model, "enemy", paths)
	else:
		model = _create_enemy_primitive("archer" if archer else "infantry")
	if archer:
		# The archer rig's skeleton renders ~4.5% taller than the infantry rig (head peak
		# 1.256 vs 1.202), so scale it down to match the soldier's height exactly.
		model.scale = Vector3(0.957, 0.957, 0.957)
	else:
		model.scale = Vector3.ONE
	return model


static func enemy_animation_paths(archer: bool = false) -> Dictionary:
	if archer:
		return {
			"idle": ENEMY_ARCHER_IDLE_PATH, "run": ENEMY_ARCHER_RUN_PATH,
			"attack": ENEMY_ARCHER_ATTACK_PATH, "dead": ENEMY_ARCHER_DEAD_PATH,
		}
	return {
		"idle": ENEMY_IDLE_PATH, "run": ENEMY_RUN_PATH,
		"attack": ENEMY_ATTACK_PATH, "dead": ENEMY_DEAD_PATH,
	}


static func soldier_animation_paths(archer: bool = false) -> Dictionary:
	if archer:
		return {
			"idle": SOLDIER_ARCHER_IDLE_PATH, "run": SOLDIER_ARCHER_RUN_PATH,
			"attack": SOLDIER_ARCHER_ATTACK_PATH, "dead": SOLDIER_ARCHER_DEAD_PATH,
		}
	return {
		"idle": SOLDIER_IDLE_PATH, "run": SOLDIER_RUN_PATH,
		"attack": SOLDIER_ATTACK_PATH, "dead": SOLDIER_DEAD_PATH,
	}


static func _merge_king_animations(root: Node3D) -> void:
	var anim_player: AnimationPlayer = find_animation_player(root)
	if anim_player == null:
		return

	var anim_library: AnimationLibrary
	if anim_player.has_animation_library("king"):
		anim_library = anim_player.get_animation_library("king")
	else:
		anim_library = AnimationLibrary.new()
		anim_player.add_animation_library("king", anim_library)

	# Fill the "idle" slot from the base GLB. The clip is normally an unprefixed one
	# in the default library; if a re-export leaves it inside the "king" library
	# instead, alias it so king/idle still exists.
	var base_idle_clip := ""
	for candidate: String in anim_player.get_animation_list():
		if candidate.begins_with("king/"):
			continue
		if anim_player.get_animation(candidate):
			base_idle_clip = candidate
			break

	if base_idle_clip != "" and anim_player.has_animation_library(""):
		anim_library.add_animation("idle", anim_player.get_animation(base_idle_clip))
		var default_lib: AnimationLibrary = anim_player.get_animation_library("")
		default_lib.remove_animation(base_idle_clip)
	elif not anim_library.has_animation("idle"):
		for candidate: String in anim_library.get_animation_list():
			if candidate.to_lower() == "idle":
				anim_library.add_animation("idle", anim_library.get_animation(candidate))
				break

	var animation_map: Dictionary = {
		KING_DASH_PATH: "dash",
		KING_FLY_PATH: "fly",
		KING_ATTACK1_PATH: "attack_1",
		KING_ATTACK2_PATH: "attack_2",
		KING_ATTACK3_PATH: "attack_3",
		KING_EARTH_QUAKE_PATH: "earth_quake",
		KING_BERSERK_PATH: "berserk",
	}

	for glb_path: String in animation_map:
		if not ResourceLoader.exists(glb_path):
			continue
		var scene: PackedScene = load(glb_path)
		if scene == null:
			continue
		var instance: Node3D = scene.instantiate()
		var source_player: AnimationPlayer = find_animation_player(instance)
		if source_player == null:
			instance.queue_free()
			continue
		for source_anim_name: String in source_player.get_animation_list():
			if source_anim_name.begins_with("king/"):
				continue
			var anim: Animation = source_player.get_animation(source_anim_name)
			if anim:
				var target_name: String = animation_map[glb_path]
				anim_library.add_animation(target_name, anim)
		instance.queue_free()

	for anim_name: String in anim_library.get_animation_list():
		anim_library.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR

	if anim_library.has_animation("earth_quake"):
		anim_library.get_animation("earth_quake").loop_mode = Animation.LOOP_NONE

	if anim_library.has_animation("berserk"):
		anim_library.get_animation("berserk").loop_mode = Animation.LOOP_NONE

	if anim_player.has_animation("king/idle"):
		anim_player.play("king/idle")


static func _remap_tracks_to_rig(root: Node3D, anim: Animation) -> void:
	var skeleton: Skeleton3D = null
	var ap: AnimationPlayer = find_animation_player(root)
	if ap == null:
		return
	for child in root.find_children("*", "Skeleton3D", true, false):
		skeleton = child as Skeleton3D
		break
	if skeleton == null:
		return
	var skeleton_path: String = String(root.get_path_to(skeleton))
	var track_count: int = anim.get_track_count()
	for i in track_count:
		var path: NodePath = anim.track_get_path(i)
		var parts: PackedStringArray = String(path).split(":", false)
		if parts.size() < 2:
			continue
		var bone_part: String = parts[1]
		# Bone naming is inconsistent between exported rigs: some GLBs bake the
		# mixamorig prefix in, some strip it, some rename Spine1->Spine01 etc.
		var resolved: String = _resolve_bone_name(skeleton, bone_part)
		anim.track_set_path(i, NodePath(skeleton_path + ":" + resolved))


static func _resolve_bone_name(skeleton: Skeleton3D, bone_part: String) -> String:
	if _skeleton_has_bone(skeleton, bone_part):
		return bone_part
	var bare: String = bone_part.trim_prefix("mixamorig")
	bare = bare.trim_prefix("_").trim_prefix(":")
	if bare == "Spine1":
		bare = "Spine01"
	elif bare == "Spine2":
		bare = "Spine02"
	elif bare == "Neck" or bare == "Spine3":
		bare = "neck"
	for candidate in [bare, "mixamorig_" + bare]:
		if _skeleton_has_bone(skeleton, candidate):
			return candidate
	return bone_part


static func _skeleton_has_bone(skeleton: Skeleton3D, name: String) -> bool:
	return skeleton.find_bone(name) >= 0


# The archer rig is the only one whose Hips bone keeps the mixamorig prefix after the
# remap; the default rigs strip it. Use that to apply the attack-only correction only
# where the player actually reported it.
static func _is_archer_rig(root: Node3D) -> bool:
	for child in root.find_children("*", "Skeleton3D", true, false):
		var skeleton := child as Skeleton3D
		if skeleton.find_bone("mixamorig_Hips") >= 0:
			return true
	return false


# Rotate every rotation key of the Hips track by a fixed yaw. This keeps the ranged
# attack pose aligned with the arrow while preserving the clip's own motion.
static func _bake_torso_yaw(anim: Animation, yaw_deg: float) -> void:
	if yaw_deg == 0.0:
		return
	var yaw := Quaternion(Vector3.UP, deg_to_rad(yaw_deg))
	for i in anim.get_track_count():
		if anim.track_get_type(i) != Animation.TYPE_ROTATION_3D:
			continue
		var track_path := String(anim.track_get_path(i))
		if not track_path.ends_with(":mixamorig_Hips") and not track_path.ends_with(":Hips"):
			continue
		for j in anim.track_get_key_count(i):
			var quat: Quaternion = anim.track_get_key_value(i, j)
			anim.track_set_key_value(i, j, yaw * quat)
		return


static func _copy_animation(root: Node3D, anim_library: AnimationLibrary, target_name: String, anim: Animation) -> void:
	_remap_tracks_to_rig(root, anim)
	var archer_attack: bool = target_name == "attack" and _is_archer_rig(root)
	var boma_attack: bool = String(root.get_meta("boss_rig", "")) == "boma" \
		and target_name in ["attack", "power_attack"]
	if archer_attack or boma_attack:
		_bake_torso_yaw(anim, RANGED_ATTACK_YAW_OFFSET_DEG)
	anim_library.add_animation(target_name, anim)


static func _merge_boss_animations(root: Node3D, paths: Dictionary) -> void:
	_merge_anim_set(root, "boss", paths)


static var _soldier_templates: Dictionary = {}


static func _prewarm(paths: Array) -> void:
	# Load on the main thread, one resource per frame. Do NOT use
	# ResourceLoader.load_threaded_request() here: Godot 4.7 has an Android regression where
	# a threaded PackedScene load intermittently never leaves THREAD_LOAD_IN_PROGRESS
	# (godotengine/godot#121124). Polling that status is exactly what this used to do, so an
	# unlucky cold start would hang the loading screen forever on the very first prewarm
	# (stuck at "Loading soldier models...") with no progress and no recovery. Synchronous
	# loading avoids the threaded loader path entirely; the prewarmed scenes are only a few
	# hundred KB each, so the wall-clock cost is comparable and the bar still advances.
	for path: String in paths:
		if not ResourceLoader.exists(path):
			continue
		if ResourceLoader.has_cached(path):
			continue
		ResourceLoader.load(path)
		await Engine.get_main_loop().process_frame


# idle/run/attack for both the default rig and the archer rig.
static func _archivable_sets(builder: Callable, archer_only: bool = false) -> Array:
	var paths: Array = []
	for archer in ([true] if archer_only else [false, true]):
		var set: Dictionary = builder.call(archer)
		for key: String in ["idle", "run", "attack"]:
			paths.append(set[key])
	return paths


static func prewarm_soldier_models() -> void:
	await _prewarm(_archivable_sets(soldier_animation_paths))


# Archers only show up from stage 30, so their 16 MB of GLBs stay out of the
# level-boot prewarm and are loaded on first use instead of stalling the run.
static func prewarm_archer_models() -> void:
	await _prewarm(_archivable_sets(soldier_animation_paths, true)
		+ _archivable_sets(enemy_animation_paths, true))
	# Warming the file cache is NOT enough. The cost is in _build_soldier_template, which
	# instantiates the GLBs and merges their animation sets; measured at ~1.25 s per archer
	# template on desktop, and far longer on a phone. Left to first use it lands on the
	# first archer spawned during a run and blocks the main thread, freezing the game for
	# seconds at exactly the moment the player is moving. Build the templates here instead,
	# behind the loading screen. They are cached in _soldier_templates, so later runs in the
	# same session pay nothing.
	load_soldier("archer")
	load_enemy("archer")


static func prewarm_enemy_models() -> void:
	await _prewarm(_archivable_sets(enemy_animation_paths))


static func prewarm_building_models() -> void:
	await _prewarm(BUILDING_MODEL_PATHS.values())


static func prewarm_king_models() -> void:
	await _prewarm([KING_IDLE_PATH, KING_DASH_PATH, KING_FLY_PATH, KING_ATTACK1_PATH, KING_ATTACK2_PATH, KING_ATTACK3_PATH, KING_EARTH_QUAKE_PATH, KING_BERSERK_PATH])


static func warmup_shaders(parent: Node) -> void:
	# Each factory produces one throwaway sample that exists just long enough to compile
	# its shader variants. The king has to be among them: it is instantiated later, at run
	# start, so without a sample here its skinned-mesh pipeline compiles on the first frame
	# the player moves -- the "lag the first time I move" report. Compiling it here moves
	# the stall to the loading screen where it belongs.
	#
	# The samples are warmed one at a time rather than all at once. Batching them kept the
	# king, a soldier, an enemy, a boss and all four 200k-678k-triangle buildings resident
	# simultaneously, and that transient peak is what pushes low-RAM phones over during the
	# loading screen. Warming sequentially compiles the same variants while only one
	# sample is resident at a time.
	var factories: Array[Callable] = [
		func() -> Node3D: return load_king(),
		func() -> Node3D: return load_soldier(),
		func() -> Node3D: return load_enemy("infantry", false),
		func() -> Node3D: return load_enemy("infantry", true),
	]
	for building_id: String in BUILDING_MODEL_PATHS:
		var bid: String = building_id
		factories.append(func() -> Node3D: return load_building_model(bid))
	var camera: Camera3D = parent.get_viewport().get_camera_3d()
	for factory in factories:
		var sample: Node3D = factory.call()
		if sample == null:
			continue
		parent.add_child(sample)
		if camera:
			sample.global_position = camera.global_position - camera.global_basis.z * 8.0
			sample.look_at(camera.global_position, Vector3.UP)
		await parent.get_tree().process_frame
		await parent.get_tree().process_frame
		# Compile the transparent material variant while the loading screen is still up.
		# Building.set_transparent() flips materials between TRANSPARENCY_DISABLED and
		# TRANSPARENCY_ALPHA, and that change invalidates the shader, forcing a recompile
		# that takes seconds on mobile. Buildings only become transparent the first time
		# they come between the camera and the king -- that is, on the player's first
		# movement -- so without this the game freezes there instead of on the loading
		# screen.
		_set_sample_transparency(sample, true)
		await parent.get_tree().process_frame
		await parent.get_tree().process_frame
		_set_sample_transparency(sample, false)
		await parent.get_tree().process_frame
		await parent.get_tree().process_frame
		# Force the king's animation player to touch the "fly" clip too. The first move
		# switches from idle to fly; compiling that clip happens on the frame of the switch
		# on some GPU/driver combinations.
		var anim_player: AnimationPlayer = find_animation_player(sample)
		if anim_player and anim_player.has_animation("king/fly"):
			anim_player.play("king/fly")
			await parent.get_tree().process_frame
			await parent.get_tree().process_frame
		sample.queue_free()
		await parent.get_tree().process_frame


static func warmup_animations(parent: Node, stage: int) -> void:
	var camera: Camera3D = parent.get_viewport().get_camera_3d()
	if camera == null:
		push_warning("ModelLoader: Cannot warm animation rendering without an active camera")
		return
	var factories: Array[Callable] = [
		func() -> Node3D: return load_king(),
		func() -> Node3D: return load_soldier("infantry"),
		func() -> Node3D: return load_soldier("archer"),
		func() -> Node3D: return load_enemy("infantry"),
		func() -> Node3D: return load_enemy("archer"),
	]
	var clip_sets: Array[Array] = [
		["king/idle", "king/fly", "king/dash", "king/attack_1", "king/attack_2",
			"king/attack_3", "king/earth_quake", "king/berserk"],
		["soldier/idle", "soldier/run", "soldier/attack", "soldier/dead"],
		["soldier/idle", "soldier/run", "soldier/attack", "soldier/dead"],
		["enemy/idle", "enemy/run", "enemy/attack", "enemy/dead"],
		["enemy/idle", "enemy/run", "enemy/attack", "enemy/dead"],
	]

	var rigs: Array[String] = []
	for boss_id: String in ProgressionData.boss_roster(stage):
		var rig: String = BossRegistry.model_rig(boss_id)
		if rigs.has(rig):
			continue
		rigs.append(rig)
		var boss_rig: String = rig
		factories.append(func() -> Node3D: return load_boss(boss_rig))
		var boss_clips: Array[String] = []
		for animation_name: String in boss_animation_paths(rig):
			boss_clips.append("boss/" + animation_name)
		clip_sets.append(boss_clips)

	for i in factories.size():
		await _warmup_animation_sample(parent, camera, factories[i], clip_sets[i])


static func _warmup_animation_sample(
	parent: Node,
	camera: Camera3D,
	factory: Callable,
	animation_names: Array
) -> void:
	var sample: Node3D = factory.call()
	if sample == null:
		return
	parent.add_child(sample)
	sample.global_position = camera.global_position - camera.global_basis.z * 8.0
	sample.look_at(camera.global_position, Vector3.UP)
	await parent.get_tree().process_frame

	var anim_player: AnimationPlayer = find_animation_player(sample)
	if anim_player:
		for animation_name: String in animation_names:
			if not anim_player.has_animation(animation_name):
				continue
			play_rig_animation(sample, anim_player, animation_name, 0.0, true)
			await parent.get_tree().process_frame
			await parent.get_tree().process_frame

	sample.queue_free()
	await parent.get_tree().process_frame


static func prewarm_boss_models(stage: int = 1) -> void:
	var rigs: Array[String] = []
	for boss_id: String in ProgressionData.boss_roster(stage):
		var rig: String = BossRegistry.model_rig(boss_id)
		if not rigs.has(rig):
			rigs.append(rig)
	var paths: Array = []
	for rig: String in rigs:
		for path: String in boss_animation_paths(rig).values():
			if not paths.has(path):
				paths.append(path)
	await _prewarm(paths)
	for rig: String in rigs:
		var model: Node3D = load_boss(rig)
		model.free()
		await Engine.get_main_loop().process_frame


static func load_soldier(type: String = "infantry") -> Node3D:
	var key: String = type if type == "archer" else "default"
	if not _soldier_templates.has(key):
		_soldier_templates[key] = _build_soldier_template(key == "archer")
	return _soldier_templates[key].duplicate()


static func _build_soldier_template(archer: bool = false) -> Node3D:
	var paths: Dictionary = soldier_animation_paths(archer)
	var model: Node3D
	if ResourceLoader.exists(paths["idle"]):
		model = load_model(paths["idle"])
		_merge_anim_set(model, "soldier", paths)
	else:
		model = _create_primitive_fallback()
	var height_scale: float = SOLDIER_ARCHER_HEIGHT_SCALE if archer \
		else SOLDIER_INFANTRY_HEIGHT_SCALE
	model.scale = Vector3.ONE * height_scale
	return model


# Flip every material on a model between opaque and alpha-transparent, purely to make
# the renderer build each shader variant once.
#
# The mesh surfaces are re-pointed at duplicates before being modified, exactly like
# Building._collect_mesh_materials does. Editing the shared surface material in place
# would mutate the cached template and leak transparency into every building loaded later.
static func _set_sample_transparency(root: Node3D, enabled: bool) -> void:
	var mode: int = BaseMaterial3D.TRANSPARENCY_ALPHA if enabled else BaseMaterial3D.TRANSPARENCY_DISABLED
	for node in root.find_children("*", "MeshInstance3D", true):
		var mi := node as MeshInstance3D
		if mi == null:
			continue
		var override_mat: Material = mi.material_override
		if override_mat is BaseMaterial3D:
			(override_mat as BaseMaterial3D).transparency = mode
		for i in range(mi.get_surface_override_material_count()):
			var surf_mat: Material = mi.get_surface_override_material(i)
			if surf_mat is BaseMaterial3D:
				(surf_mat as BaseMaterial3D).transparency = mode
		if mi.mesh:
			for i in range(mi.mesh.get_surface_count()):
				var mat: Material = mi.mesh.surface_get_material(i)
				if mat is BaseMaterial3D:
					var copy: BaseMaterial3D = (mat as BaseMaterial3D).duplicate()
					copy.transparency = mode
					mi.set_surface_override_material(i, copy)


static func _disable_shadows(root: Node3D) -> void:
	for child in root.find_children("*", "MeshInstance3D", true):
		var mi := child as MeshInstance3D
		if mi:
			mi.cast_shadow = GeometryInstance3D.ShadowCastingSetting.SHADOW_CASTING_SETTING_OFF


# Folds the idle/run/attack/dead GLBs of one rig into a single AnimationLibrary
# named `prefix`, regardless of what the source files called their animations.
static func _merge_anim_set(root: Node3D, prefix: String, paths: Dictionary) -> void:
	var anim_player: AnimationPlayer = find_animation_player(root)
	if anim_player == null:
		return

	var anim_library: AnimationLibrary
	if anim_player.has_animation_library(prefix):
		anim_library = anim_player.get_animation_library(prefix)
	else:
		anim_library = AnimationLibrary.new()
		anim_player.add_animation_library(prefix, anim_library)

	for anim_name: String in paths:
		var glb_path: String = paths[anim_name]
		if not ResourceLoader.exists(glb_path):
			continue
		var scene: PackedScene = load(glb_path)
		if scene == null:
			continue
		var instance: Node3D = scene.instantiate()
		var source_player: AnimationPlayer = find_animation_player(instance)
		if source_player == null:
			instance.queue_free()
			continue
		# Some rigs ship several clips in one file (Aswatama's idle.glb holds both
		# "Idle_10" and "Idle_102"). Prefer a clip whose own name mentions the
		# state we want, otherwise fall back to the first one.
		var picked := ""
		for source_anim_name: String in source_player.get_animation_list():
			if source_anim_name.begins_with(prefix + "/"):
				continue
			if source_anim_name.to_lower().contains(anim_name):
				picked = source_anim_name
				break
		if picked == "":
			var names: Array = source_player.get_animation_list()
			for source_anim_name: String in names:
				if not source_anim_name.begins_with(prefix + "/"):
					picked = source_anim_name
					break
		if picked != "":
			var anim: Animation = source_player.get_animation(picked)
			if anim:
				_copy_animation(root, anim_library, anim_name, anim)
		instance.queue_free()

	for anim_name: String in anim_library.get_animation_list():
		if anim_name in ["idle", "run"]:
			anim_library.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR

	anim_player.play(prefix + "/idle")


static func _apply_enemy_type(root: Node3D, type: String) -> void:
	var body_mesh: MeshInstance3D = _find_child_by_type(root, "MeshInstance3D")
	if body_mesh == null:
		return

	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.roughness = 0.8
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL

	match type:
		"infantry":
			mat.albedo_color = Color(0.7, 0.2, 0.2)
			_add_weapon(root, "sword")
		"archer":
			mat.albedo_color = Color(0.3, 0.5, 0.3)
			_add_weapon(root, "bow")

	body_mesh.material_override = mat

static func _create_enemy_primitive(type: String) -> Node3D:
	var root: Node3D = Node3D.new()

	var body: MeshInstance3D = MeshInstance3D.new()
	var body_mesh: CapsuleMesh = CapsuleMesh.new()
	body_mesh.radius = 0.25
	body_mesh.height = 0.8
	body.mesh = body_mesh
	body.position.y = 0.6
	root.add_child(body)

	var head: MeshInstance3D = MeshInstance3D.new()
	var head_mesh: SphereMesh = SphereMesh.new()
	head_mesh.radius = 0.2
	head.mesh = head_mesh
	head.position.y = 1.15
	root.add_child(head)

	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.roughness = 0.8
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL

	match type:
		"infantry":
			mat.albedo_color = Color(0.7, 0.2, 0.2)
			_add_weapon(root, "sword")
		"archer":
			mat.albedo_color = Color(0.3, 0.5, 0.3)
			_add_weapon(root, "bow")

	body.material_override = mat
	head.material_override = _make_material(Color(0.75, 0.6, 0.45))

	return root

static func _add_weapon(root: Node3D, weapon_type: String) -> void:
	var weapon: MeshInstance3D = MeshInstance3D.new()
	var box: BoxMesh = BoxMesh.new()

	match weapon_type:
		"sword":
			box.size = Vector3(0.05, 0.6, 0.05)
			weapon.mesh = box
			weapon.position = Vector3(0.35, 0.3, 0)
			weapon.material_override = _make_material(Color(0.7, 0.7, 0.8))
		"spear":
			box.size = Vector3(0.04, 0.8, 0.04)
			weapon.mesh = box
			weapon.position = Vector3(0.35, 0.4, 0)
			weapon.material_override = _make_material(Color(0.55, 0.35, 0.15))
		"bow":
			box.size = Vector3(0.05, 0.5, 0.05)
			weapon.mesh = box
			weapon.position = Vector3(0.35, 0.1, 0)
			weapon.material_override = _make_material(Color(0.55, 0.35, 0.15))

	root.add_child(weapon)

static func _add_boss_crown(root: Node3D) -> void:
	var crown: MeshInstance3D = MeshInstance3D.new()
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3(0.25, 0.12, 0.25)
	crown.mesh = box
	crown.material_override = _make_material(Color(0.95, 0.85, 0.20))
	crown.position = Vector3(0, 0.82, 0)
	root.add_child(crown)

static func _find_child_by_type(node: Node, type_name: String) -> Node:
	if node.is_class(type_name):
		return node
	for child in node.get_children():
		var result: Node = _find_child_by_type(child, type_name)
		if result:
			return result
	return null

static func _make_material(albedo: Color) -> StandardMaterial3D:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = albedo
	mat.roughness = 0.8
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	return mat

static func _setup_animations(root: Node3D) -> void:
	var anim_player: AnimationPlayer = find_animation_player(root)
	if anim_player == null:
		anim_player = AnimationPlayer.new()
		root.add_child(anim_player)
		anim_player.owner = root

static func find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var result: AnimationPlayer = find_animation_player(child)
		if result:
			return result
	return null

static func get_animation_names(root: Node3D) -> Array[String]:
	var anim_player: AnimationPlayer = find_animation_player(root)
	if anim_player == null:
		return []
	var names: Array[String] = []
	for anim_name in anim_player.get_animation_list():
		names.append(anim_name)
	return names

static func play_animation(root: Node3D, anim_name: String, blend: float = 0.1) -> bool:
	var anim_player: AnimationPlayer = find_animation_player(root)
	if anim_player == null:
		return false
	return play_rig_animation(root, anim_player, anim_name, blend, false)


## Animation clips may omit bones that do not move in that clip. Restore the rig to
## its imported rest pose before every state transition so those bones cannot retain
## rotations from the previous clip.
static func reset_rig_pose(root: Node3D) -> void:
	for child in root.find_children("*", "Skeleton3D", true, false):
		var skeleton := child as Skeleton3D
		if skeleton != null:
			skeleton.reset_bone_poses()


static func play_rig_animation(
	root: Node3D,
	anim_player: AnimationPlayer,
	anim_name: String,
	blend: float = 0.0,
	restart: bool = false
) -> bool:
	if anim_player == null or not anim_player.has_animation(anim_name):
		return false
	anim_player.active = true
	reset_rig_pose(root)
	anim_player.play(anim_name, blend)
	if restart:
		anim_player.seek(0.0, true)
	return true

static func _create_primitive_fallback() -> Node3D:
	var root_node: Node3D = Node3D.new()

	var body: MeshInstance3D = MeshInstance3D.new()
	var body_mesh: CapsuleMesh = CapsuleMesh.new()
	body_mesh.radius = 0.3
	body_mesh.height = 1.0
	body.mesh = body_mesh
	body.position.y = 0.8
	root_node.add_child(body)

	var head: MeshInstance3D = MeshInstance3D.new()
	var head_mesh: SphereMesh = SphereMesh.new()
	head_mesh.radius = 0.25
	head.mesh = head_mesh
	head.position.y = 1.55
	root_node.add_child(head)

	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.6, 0.4, 0.3)
	body.material_override = mat
	head.material_override = mat

	return root_node
