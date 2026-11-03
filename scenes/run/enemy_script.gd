extends Node3D

const IMPACT_SPARK: GDScript = preload("res://scenes/effects/MetalSpark.gd")

var _cached_nav: NavigationAgent3D = null
var _cached_anim: AnimationPlayer = null
var _last_nav_target: Vector3 = Vector3(INF, INF, INF)


func take_damage(amount: float) -> void:
	if not is_alive():
		return
	var hp: float = get_meta("current_health", 0)
	var enemy_data: Dictionary = get_meta("enemy_data", {})
	var defense: float = float(enemy_data.get("defense", 0.0))
	hp -= ProgressionData.armor_damage(amount, defense)
	set_meta("current_health", hp)
	_update_hp_bar()
	IMPACT_SPARK.spawn(self)
	if hp <= 0:
		_play_dead_then_release()


func _exit_tree() -> void:
	SpatialIndex.unregister(self)


func _update_hp_bar() -> void:
	var hp: float = get_meta("current_health", 0)
	var max_hp: float = get_meta("max_health", 1)
	var ratio: float = clampf(hp / max(max_hp, 1.0), 0.0, 1.0)
	var bar: Sprite3D = get_node_or_null("HPBar")
	if bar:
		bar.scale.x = 50 * ratio
		bar.offset.x = -0.5 * bar.texture.get_width() * (1.0 - ratio) / ratio \
			if ratio > 0.0 else 0.0
		if ratio > 0.5:
			bar.modulate = Color(0.2, 0.8, 0.2)
		elif ratio > 0.25:
			bar.modulate = Color(0.8, 0.8, 0.2)
		else:
			bar.modulate = Color(0.8, 0.2, 0.2)


func get_health() -> float:
	return get_meta("current_health", 0)


func is_alive() -> bool:
	return not get_meta("enemy_dead", false)


func get_nav() -> NavigationAgent3D:
	if _cached_nav == null or not is_instance_valid(_cached_nav):
		_cached_nav = get_node_or_null("NavigationAgent3D")
	return _cached_nav


func get_anim_player() -> AnimationPlayer:
	if _cached_anim == null or not is_instance_valid(_cached_anim):
		_cached_anim = ModelLoader.find_animation_player(self)
	return _cached_anim


# NavigationAgent3D re-paths from scratch every time target_position is written, and
# _move_enemies used to write it every physics frame for every enemy even though an enemy
# walks to one fixed pendopo the whole way. Remembering the last target turns that into one
# path per target change. The nav mesh is baked once per run and never rebuilt, so an
# unchanged target never needs re-issuing.
func set_nav_target(pos: Vector3) -> void:
	if _last_nav_target.is_equal_approx(pos):
		return
	_last_nav_target = pos
	var nav: NavigationAgent3D = get_nav()
	if nav:
		nav.target_position = pos
func _play_dead_then_release() -> void:
	set_meta("enemy_dead", true)
	SpatialIndex.unregister(self)
	var anim_player: AnimationPlayer = get_anim_player()
	if anim_player:
		anim_player.active = true
	var dead_name: String = "enemy/dead"
	if anim_player and anim_player.has_animation_library("boss"):
		dead_name = "boss/dead"
	if ModelLoader.play_rig_animation(self, anim_player, dead_name, 0.0, true):
		var released := false
		var do_release := func(_anim_name: StringName = "") -> void:
			if released:
				return
			released = true
			if get_meta("pooled", false):
				UnitPool.release_enemy(self)
			elif is_instance_valid(self):
				self.queue_free()
		var finished: Signal = anim_player.animation_finished
		var safety: SceneTreeTimer = get_tree().create_timer(4.0)
		finished.connect(do_release)
		safety.timeout.connect(do_release)
		await finished
		finished.disconnect(do_release)
		if safety.timeout.is_connected(do_release):
			safety.timeout.disconnect(do_release)
		do_release.call()
	else:
		if get_meta("pooled", false):
			UnitPool.release_enemy(self)
		elif is_instance_valid(self):
			self.queue_free()

func reset_for_pool() -> void:
	_cached_nav = null
	_cached_anim = null
	_last_nav_target = Vector3(INF, INF, INF)
	position = Vector3.ZERO
	rotation = Vector3.ZERO
	set_meta("enemy_dead", false)
	set_meta("attack_cooldown", 0.0)
	set_meta("attack_anim_lock", 0.0)
	set_meta("anim_state", "idle")
	var nav: NavigationAgent3D = get_nav()
	if nav:
		nav.process_mode = Node.PROCESS_MODE_INHERIT
	var anim_player: AnimationPlayer = get_anim_player()
	if anim_player:
		anim_player.stop()
		var idle_name: String = "enemy/idle"
		if anim_player.has_animation_library("boss"):
			idle_name = "boss/idle"
		ModelLoader.play_rig_animation(self, anim_player, idle_name, 0.0, true)
	var bar: Sprite3D = get_node_or_null("HPBar")
	if bar:
		bar.scale.x = 50.0
		bar.offset.x = 0.0
		bar.modulate = Color(0.2, 0.8, 0.2)


func reset_for_spawn() -> void:
	set_meta("enemy_dead", false)
	set_meta("anim_state", "idle")
	var anim_player: AnimationPlayer = get_anim_player()
	if anim_player == null:
		return
	anim_player.stop()
	var idle_name: String = "enemy/idle"
	if anim_player.has_animation_library("boss"):
		idle_name = "boss/idle"
	ModelLoader.play_rig_animation(self, anim_player, idle_name, 0.0, true)
