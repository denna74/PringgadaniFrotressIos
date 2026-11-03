class_name SoldierUnit extends Node3D

signal died(soldier: Node3D)

var troop_type: String = "infantry"
var barracks_level: int = 1
var formation_slot: int = 0
var death_callback: Callable

var soldier_hp: float = 60.0
var soldier_max_hp: float = 60.0
var attack_damage: float = 12.0
var soldier_defense: float = 0.0
var _is_dying: bool = false
var attack_range: float = 1.6
var attack_cooldown: float = 0.9
var detection_radius: float = 5.0
var move_speed: float = 2.5
var follow_radius: float = 1.5
var leash_distance: float = 25.0

const SEPARATION_RADIUS := 0.7
const SEPARATION_FORCE := 0.5
const THROTTLE_CLOSE: float = 15.0
const THROTTLE_FAR: float = 30.0
const NAV_RETRY_INTERVAL: float = 0.5

var _model: Node3D = null
var _anim_player: AnimationPlayer = null
var _king: Node3D = null
var _formation_target: Node3D = null
var _target: Node3D = null
var _attack_timer: float = 0.0
var _attack_anim_timer: float = 0.0
var _throttled_delta: float = 0.0
var _current_anim: String = ""
var _hp_bar: Sprite3D = null
var _bar_texture: Texture2D = null
var _nav: NavigationAgent3D = null
var _last_nav_target: Vector3 = Vector3(INF, INF, INF)
var _nav_retry_timer: float = 0.0
var _update_frame: int = 0
var _cam_ref: Camera3D = null
var _ranged: bool = false
var _model_type: String = ""
const ARROW_SCRIPT: GDScript = preload("res://scenes/projectiles/arrow_projectile.gd")
const IMPACT_SPARK: GDScript = preload("res://scenes/effects/MetalSpark.gd")


func setup_king_ref(king: Node3D) -> void:
	_king = king


func set_follow_target(target: Node3D = null) -> void:
	_formation_target = target
	_target = null
	_last_nav_target = Vector3(INF, INF, INF)
	_nav_retry_timer = 0.0


func is_ranged() -> bool:
	return _ranged


func get_nav() -> NavigationAgent3D:
	return _nav


func current_anim() -> String:
	return _current_anim


func _ready() -> void:
	add_to_group("troops")
	if _bar_texture == null:
		_bar_texture = _get_shared_bar_texture()
	_ensure_model()
	_build_hp_bar()
	if _nav == null:
		_nav = NavigationAgent3D.new()
		_nav.name = "NavigationAgent3D"
		_nav.target_desired_distance = 0.6
		_nav.path_desired_distance = 0.5
		add_child(_nav)
	_set_anim("idle")
	SpatialIndex.register(self, "troops")


# UnitPool recycles a node that already carries a model, so the mesh has to be
# rebuilt whenever the unit comes back as a different troop type.
func _ensure_model() -> void:
	if _model != null and _model_type == troop_type:
		return
	if _model != null and is_instance_valid(_model):
		remove_child(_model)
		_model.queue_free()
	_model = ModelLoader.load_soldier(troop_type)
	_model_type = troop_type
	add_child(_model)
	_anim_player = ModelLoader.find_animation_player(_model)


func _exit_tree() -> void:
	SpatialIndex.unregister(self)


func configure() -> void:
	# Pooled soldiers are reused, so a unit that was infantry can come back as an
	# archer: every stat has to be re-derived, not just the health.
	var stats: Dictionary = ProgressionData.troop_stats(troop_type, barracks_level)
	soldier_max_hp = stats["hp"]
	attack_damage = stats["attack"]
	soldier_defense = stats["defense"]
	attack_range = stats["range"]
	attack_cooldown = stats["cooldown"]
	move_speed = stats["speed"]
	detection_radius = stats["detection"]
	_ranged = stats["ranged"]
	_ensure_model()
	_is_dying = false
	soldier_hp = soldier_max_hp
	_attack_timer = 0.0
	_attack_anim_timer = 0.0
	_throttled_delta = 0.0
	_current_anim = ""
	_last_nav_target = Vector3(INF, INF, INF)
	_nav_retry_timer = 0.0
	if _nav != null and is_inside_tree():
		_nav.process_mode = Node.PROCESS_MODE_INHERIT
		var world := get_world_3d()
		if world != null:
			# A pooled agent may still hold the previous run's navigation map/path.
			_nav.set_navigation_map(world.get_navigation_map())
		_nav.target_position = global_position
		_last_nav_target = global_position
	if _anim_player != null:
		_anim_player.active = true
		_anim_player.stop()
		ModelLoader.reset_rig_pose(_model)
	_target = null
	_formation_target = null
	_update_frame = 0
	_cam_ref = null
	add_to_group("troops")
	if _hp_bar:
		_hp_bar.scale.x = 50.0
	_update_hp_bar()
	if is_inside_tree() and not SpatialIndex.is_registered(self):
		SpatialIndex.register(self, "troops")
	if is_inside_tree():
		_set_anim("idle")


func _physics_process(delta: float) -> void:
	if _is_dying:
		return
	_update_frame += 1
	_throttled_delta += delta
	if _should_throttle():
		return
	var update_delta := _throttled_delta
	_throttled_delta = 0.0
	if _king == null or not is_instance_valid(_king):
		_king = get_tree().get_first_node_in_group("king")
		if _king == null:
			return
	_attack_timer = maxf(_attack_timer - update_delta, 0.0)
	_update_target()
	if _target != null and is_instance_valid(_target):
		_combat(_target, update_delta)
	else:
		_follow_king(update_delta)
	_apply_separation()


func _should_throttle() -> bool:
	if _cam_ref == null or not is_instance_valid(_cam_ref):
		_cam_ref = get_viewport().get_camera_3d()
		if _cam_ref == null:
			return false
	var dist := global_position.distance_to(_cam_ref.global_position)
	if dist > THROTTLE_FAR:
		return _update_frame % 4 != 0
	if dist > THROTTLE_CLOSE:
		return _update_frame % 2 != 0
	return false


func _update_target() -> void:
	if _target != null and is_instance_valid(_target) and _target.is_inside_tree() and not _target.is_queued_for_deletion():
		if _target.has_method("is_alive") and not _target.is_alive():
			_target = null
		else:
			var d := global_position.distance_to(_target.global_position)
			if d <= detection_radius + 3.0:
				return
	_target = _find_nearest_enemy()


func _find_nearest_enemy() -> Node3D:
	var closest: Node3D = null
	var closest_dist := detection_radius
	var king_pos := _king.global_position
	for enemy in SpatialIndex.get_nearby(global_position, detection_radius, "enemies"):
		var d1 := global_position.distance_to(enemy.global_position)
		var d := d1
		if _formation_target == null or _formation_target == _king:
			var d2 := king_pos.distance_to(enemy.global_position)
			d = minf(d1, d2)
		if d < closest_dist:
			closest = enemy
			closest_dist = d
	return closest


func _find_nearest_troop() -> Node3D:
	var closest: Node3D = null
	var closest_dist_sq := SEPARATION_RADIUS * SEPARATION_RADIUS
	for troop in SpatialIndex.get_nearby(global_position, SEPARATION_RADIUS, "troops"):
		if troop == self or not is_instance_valid(troop):
			continue
		var to_other: Vector3 = global_position - troop.global_position
		var dist_sq: float = to_other.length_squared()
		if dist_sq < closest_dist_sq and dist_sq > 0.0001:
			closest = troop
			closest_dist_sq = dist_sq
	return closest


func _combat(target: Node3D, delta: float) -> void:
	var to_target: Vector3 = target.global_position - global_position
	var dist := to_target.length()
	var yaw := atan2(to_target.x, to_target.z)
	rotation.y = lerp_angle(rotation.y, yaw, 10.0 * delta)
	if dist > attack_range:
		var dir: Vector3 = _move_toward(target.global_position, delta)
		var remaining := Vector2(
			target.global_position.x - global_position.x,
			target.global_position.z - global_position.z
		).length()
		if remaining > attack_range and _nav.is_navigation_finished():
			dir = _close_combat_gap(target.global_position - global_position, delta)
		_set_anim("run" if dir.length() > 0.01 else "idle")
	else:
		if _attack_anim_timer > 0.0:
			_attack_anim_timer -= delta
			_set_anim("attack")
		else:
			_set_anim("idle")
		if _attack_timer <= 0.0:
			_attack_timer = attack_cooldown
			_attack_anim_timer = 0.5
			if target.has_method("is_alive") and not target.is_alive():
				_target = null
				return
			if _ranged:
				_fire_arrow(target)
			elif target.has_method("take_damage"):
				target.take_damage(attack_damage)
				SFXManager.play_enemy_swing(position)


func _fire_arrow(target: Node3D) -> void:
	var arrow: Node3D = ARROW_SCRIPT.acquire()
	if arrow == null:
		return
	if get_parent() == null:
		arrow.queue_free()
		return
	# Add to the tree BEFORE setup(): setup() calls look_at_from_position(), and basing
	# that on a parentless node makes the arrow orient in the wrong frame once it gets
	# reparented under a transformed parent. That is what turned the arrow sideways.
	get_parent().add_child(arrow)
	# Muzzle sits at the bow hand, so arrows leave from where the bow actually is
	# instead of from the body centreline.
	var dir_h: Vector3 = target.global_position - global_position
	dir_h.y = 0.0
	var muzzle: Vector3 = ModelLoader.bow_hand_point(self)
	if dir_h.length() > 0.001:
		muzzle += dir_h.normalized() * 0.4
	arrow.setup(target, muzzle, attack_damage)
	SFXManager.play_arrow_shot(global_position)


func _follow_king(delta: float) -> void:
	var commander := _king
	if _formation_target != null:
		if is_instance_valid(_formation_target) and not _formation_target.is_queued_for_deletion():
			commander = _formation_target
		else:
			_formation_target = null
	var angle: float = formation_slot * 0.8
	var desired: Vector3 = commander.global_position + Vector3(cos(angle) * follow_radius, 0.0, sin(angle) * follow_radius)
	if global_position.distance_to(commander.global_position) > leash_distance:
		global_position = desired
		return
	var dir: Vector3 = _move_toward(desired, delta)
	if dir.length() > 0.01:
		var yaw := atan2(dir.x, dir.z)
		rotation.y = lerp_angle(rotation.y, yaw, 10.0 * delta)
		_set_anim("run")
	else:
		_set_anim("idle")


func _move_toward(target: Vector3, delta: float) -> Vector3:
	if _nav == null:
		return Vector3.ZERO
	_nav_retry_timer = maxf(_nav_retry_timer - delta, 0.0)
	# Re-issuing the same target re-paths the agent from scratch, so only write it when it
	# actually changes (a stationary king, or a stationary combat target).
	var target_changed := _last_nav_target.distance_squared_to(target) > 0.25
	var target_is_far := Vector2(
		target.x - global_position.x,
		target.z - global_position.z
	).length() > _nav.target_desired_distance + 0.25
	if target_changed or (_nav.is_navigation_finished() and target_is_far and _nav_retry_timer <= 0.0):
		_last_nav_target = target
		_nav.target_position = target
		_nav_retry_timer = NAV_RETRY_INTERVAL
	if _nav.is_navigation_finished():
		return Vector3.ZERO
	var next_position: Vector3 = _nav.get_next_path_position()
	var dir := Vector3(next_position.x - global_position.x, 0.0, next_position.z - global_position.z)
	if dir.length() < 0.01:
		if target_is_far and _nav_retry_timer <= 0.0:
			# A stale or unsynchronized map can leave the agent unfinished while its
			# next waypoint is still its current position. Re-path instead of idling here.
			_nav.target_position = target
			_last_nav_target = target
			_nav_retry_timer = NAV_RETRY_INTERVAL
		return Vector3.ZERO
	dir = dir.normalized()
	position += dir * move_speed * delta
	return dir


func _close_combat_gap(to_target: Vector3, delta: float) -> Vector3:
	var horizontal := Vector3(to_target.x, 0.0, to_target.z)
	var distance := horizontal.length()
	var remaining := distance - attack_range
	if remaining <= 0.0:
		return Vector3.ZERO
	var direction := horizontal / distance
	position += direction * minf(move_speed * delta, remaining)
	return direction


func _apply_separation() -> void:
	for troop in SpatialIndex.get_nearby(global_position, SEPARATION_RADIUS, "troops"):
		if troop == self or not is_instance_valid(troop):
			continue
		var to_other: Vector3 = global_position - troop.global_position
		var dist: float = to_other.length()
		if dist >= SEPARATION_RADIUS or dist < 0.001:
			continue
		position += to_other / dist * (SEPARATION_RADIUS - dist) * SEPARATION_FORCE


func take_damage(amount: float) -> void:
	if _is_dying:
		return
	soldier_hp -= ProgressionData.armor_damage(amount, soldier_defense)
	_update_hp_bar()
	IMPACT_SPARK.spawn(self)
	if soldier_hp <= 0:
		soldier_hp = 0.0
		_is_dying = true
		await _play_dead_then_emit()


func _set_anim(anim_name: String) -> void:
	if _is_dying:
		return
	if anim_name == _current_anim:
		return
	if _anim_player == null:
		return
	var mapped := {
		"idle": "soldier/idle",
		"run": "soldier/run",
		"attack": "soldier/attack",
	}.get(anim_name, "soldier/idle")
	if ModelLoader.play_rig_animation(_model, _anim_player, mapped):
		_current_anim = anim_name


func _build_hp_bar() -> void:
	var bg := Sprite3D.new()
	bg.pixel_size = 0.01
	bg.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	bg.no_depth_test = true
	bg.render_priority = 5
	bg.texture = _bar_texture
	bg.scale = Vector3(50, 5, 1)
	bg.position.y = 2.0
	bg.modulate = Color(0.3, 0.1, 0.1)
	add_child(bg)

	_hp_bar = Sprite3D.new()
	_hp_bar.name = "HPBar"
	_hp_bar.pixel_size = 0.01
	_hp_bar.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_hp_bar.no_depth_test = true
	_hp_bar.render_priority = 10
	_hp_bar.texture = _bar_texture
	_hp_bar.scale = Vector3(50, 5, 1)
	_hp_bar.position = Vector3(0, 2.0, 0.001)
	_hp_bar.modulate = Color(0.2, 0.8, 0.2)
	add_child(_hp_bar)


func _update_hp_bar() -> void:
	if _hp_bar == null:
		return
	var ratio: float = clampf(soldier_hp / maxf(soldier_max_hp, 1.0), 0.0, 1.0)
	_hp_bar.scale.x = 50 * ratio
	_hp_bar.offset.x = -0.5 * _hp_bar.texture.get_width() * (1.0 - ratio) / ratio \
		if ratio > 0.0 else 0.0
	if ratio > 0.5:
		_hp_bar.modulate = Color(0.2, 0.8, 0.2)
	elif ratio > 0.25:
		_hp_bar.modulate = Color(0.8, 0.8, 0.2)
	else:
		_hp_bar.modulate = Color(0.8, 0.2, 0.2)


var _shared_bar_texture: Texture2D = null


func _get_shared_bar_texture() -> Texture2D:
	if _shared_bar_texture == null:
		var img: Image = Image.create(1, 1, false, Image.FORMAT_RGBA8)
		img.fill(Color.WHITE)
		_shared_bar_texture = ImageTexture.create_from_image(img)
	return _shared_bar_texture


func _play_dead_then_emit() -> void:
	var anim_player: AnimationPlayer = ModelLoader.find_animation_player(self)
	if ModelLoader.play_rig_animation(self, anim_player, "soldier/dead"):
		var released := false
		var do_finish := func(_anim_name: StringName = "") -> void:
			if released:
				return
			released = true
			died.emit(self)
			UnitPool.release_soldier(self)
		var finished: Signal = anim_player.animation_finished
		finished.connect(do_finish)
		var safety: SceneTreeTimer = get_tree().create_timer(4.0)
		safety.timeout.connect(do_finish)
		await finished
		finished.disconnect(do_finish)
		if safety.timeout.is_connected(do_finish):
			safety.timeout.disconnect(do_finish)
		do_finish.call()
	else:
		died.emit(self)
		UnitPool.release_soldier(self)
