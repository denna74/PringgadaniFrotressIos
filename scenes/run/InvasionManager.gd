extends Node3D

signal wave_complete(victory: bool)
signal enemy_count_changed(spawned: int, total: int)

const SPAWN_INTERVAL := 4.0
const SPAWN_BATCH_SIZE := 3
const WAVE_DELAY := 3.0

var current_wave: int = 0
var total_waves: int = 3
var stage_number: int = 0
var stage_theme: String = ""
var king_level: int = 1
var garrison: PlayerGarrison = null
var defense_buildings: Array = []

var _terrain: Array = []
var _map_origin: Vector3 = Vector3.ZERO
var _map_size: int = 0
var _center_offset: float = 0.0
var _pendopo_tile: Vector2i = Vector2i.ZERO
var _pendopo_refs: Array[Node3D] = []
var _spawn_tiles: Array[Vector2i] = []
var _spawn_timer: Timer = null
var _wave_delay_timer: Timer = null
var _enemies_remaining: int = 0
var _enemies_spawned: int = 0
var _total_for_wave: int = 0
var _enemy_nodes: Array = []
var _boss_spawned: bool = false
var _wave_boss_id: String = ""
var _waiting_for_clear: bool = false
var _pendopo_world_pos: Vector3 = Vector3.ZERO
var _wave_ending: bool = false
var _king_ref: Node3D = null
var _pendopo_ref: Node3D = null
var _update_frame: int = 0
var _cam_ref: Camera3D = null

const ENEMY_ATTACK_RANGE: float = 2.0
const BOSS_MELEE_ATTACK_RANGE: float = 3.0
# How close an enemy has to get before it stops walking toward its mark. Parking
# spots are offset by this so a settled enemy is still inside its own reach.
const MOVE_STOP_TOLERANCE: float = 0.15
const ENEMY_ATTACK_COOLDOWN: float = 1.0
const ANIMATION_IMPACT_PROGRESS: float = 0.5
const BOSS_DASH_ANIMATION_FPS: float = 30.0
const BOSS_DASH_EFFECT_LEAD_FRAMES: float = 2.0

const ENEMY_SCRIPT: GDScript = preload("res://scenes/run/enemy_script.gd")
const BERSERK_AURA_SCRIPT: GDScript = preload("res://scenes/effects/BerserkAura.gd")
const DASH_TRAIL_SCRIPT: GDScript = preload("res://scenes/effects/DashTrail.gd")
const EARTHQUAKE_EFFECT_SCRIPT: GDScript = preload("res://scenes/effects/EarthquakeEffect.gd")
const ARC_SLASH_SCRIPT: GDScript = preload("res://scenes/effects/ArcSlash.gd")
const CIRCLE_WAVE_SCRIPT: GDScript = preload("res://scenes/effects/CircleWave.gd")

var _pending_spawns: Array = []


func _ready() -> void:
	_spawn_timer = Timer.new()
	_spawn_timer.wait_time = SPAWN_INTERVAL
	_spawn_timer.one_shot = false
	_spawn_timer.timeout.connect(_spawn_next_batch)
	add_child(_spawn_timer)

	_wave_delay_timer = Timer.new()
	_wave_delay_timer.wait_time = WAVE_DELAY
	_wave_delay_timer.one_shot = true
	_wave_delay_timer.timeout.connect(_on_wave_delay_done)
	add_child(_wave_delay_timer)


func setup(_garrison: PlayerGarrison, defenses: Array, terrain: Array, map_size: int) -> void:
	garrison = _garrison
	defense_buildings = defenses
	_terrain = terrain
	_map_size = map_size
	_center_offset = map_size * 0.5
	total_waves = ProgressionData.num_waves(stage_number)
	_pendopo_tile = _find_pendopo_tile()
	_pendopo_world_pos = Vector3(
		(_pendopo_tile.x - _center_offset) * 1.0,
		0.3,
		(_pendopo_tile.y - _center_offset) * 1.0
	)
	_spawn_tiles = _find_edge_spawn_tiles()


func set_king_ref(king: Node3D) -> void:
	_king_ref = king


func set_pendopo_refs(pendopos: Array) -> void:
	_pendopo_refs.clear()
	for p in pendopos:
		# A destroyed pendopo frees itself once its explosion is spawned, so the run's list
		# can hand us a reference that is already gone by the time this runs. The `is` test
		# itself throws on a freed instance, so validity has to be checked first.
		if p == null or not is_instance_valid(p):
			continue
		if p is Node3D:
			_pendopo_refs.append(p)


func get_alive_pendopo_count() -> int:
	var count := 0
	for p in _pendopo_refs:
		if is_instance_valid(p) and not _is_pendopo_destroyed(p):
			count += 1
	return count


func _is_pendopo_destroyed(pendopo: Node3D) -> bool:
	return pendopo.has_method("is_destroyed") and pendopo.is_destroyed()


# Index of the living pendopo nearest a world position, or -1 if none remain.
func _nearest_pendopo_index(from: Vector3) -> int:
	var best := -1
	var best_distance := INF
	for i in range(_pendopo_refs.size()):
		var p := _pendopo_refs[i]
		if not is_instance_valid(p) or _is_pendopo_destroyed(p):
			continue
		var d: float = from.distance_squared_to(p.position)
		if d < best_distance:
			best_distance = d
			best = i
	return best


func _pendopo_position_at(index: int) -> Vector3:
	if index < 0 or index >= _pendopo_refs.size():
		return _pendopo_world_pos
	return _pendopo_refs[index].position


# Kalapracona minibosses, the Boma mid boss and the stage finale all come from
# one schedule, so the wave only has to ask for its own boss.
func _boss_for_wave(wave_number: int) -> String:
	if stage_number <= 0:
		return ""
	for entry in ProgressionData.boss_schedule(stage_number, total_waves):
		if int(entry["wave"]) == wave_number:
			return str(entry["boss_id"])
	return ""


func start_wave_timer(wave_number: int) -> void:
	current_wave = wave_number
	var count: int = ProgressionData.enemies_per_wave(stage_number, wave_number)
	_wave_boss_id = _boss_for_wave(wave_number)
	_enemies_remaining = count
	_total_for_wave = count
	_enemies_spawned = 0
	_boss_spawned = _wave_boss_id == ""
	_waiting_for_clear = false
	_wave_ending = false
	_enemy_nodes.clear()
	_pending_spawns.clear()
	_spawn_timer.start()
	_emit_count()


func stop_wave_timer() -> void:
	_spawn_timer.stop()


func _spawn_next_batch() -> void:
	if _enemies_remaining <= 0:
		return

	var to_queue: Array = []
	var batch_size: int = mini(SPAWN_BATCH_SIZE, _enemies_remaining)
	if not _boss_spawned and _enemies_remaining <= SPAWN_BATCH_SIZE:
		to_queue.append(EnemySpawner.spawn_boss(
			current_wave, stage_number, king_level, _wave_boss_id))
		_boss_spawned = true
		batch_size -= 1

	if batch_size > 0:
		to_queue.append_array(EnemySpawner.spawn_batch(
			batch_size, current_wave, stage_number, [], king_level
		))

	for data in to_queue:
		var tile: Vector2i
		if _spawn_tiles.is_empty():
			tile = _pendopo_tile
		else:
			tile = _spawn_tiles[randi() % _spawn_tiles.size()]
		_pending_spawns.append({"data": data, "tile": tile})

	_enemies_remaining -= to_queue.size()
	_enemies_spawned += to_queue.size()

	if _enemies_remaining <= 0:
		_spawn_timer.stop()
		if _pending_spawns.is_empty():
			_waiting_for_clear = true


func _drain_pending_spawn() -> void:
	if _pending_spawns.is_empty():
		return
	var entry: Dictionary = _pending_spawns.pop_front()
	_spawn_single_enemy(entry["data"], entry["tile"])
	if _pending_spawns.is_empty() and _enemies_remaining <= 0:
		_waiting_for_clear = true


func _spawn_single_enemy(data: Dictionary, tile: Vector2i) -> void:
	var spawn_pos := Vector3(
		(tile.x - _center_offset) * 1.0,
		0.3,
		(tile.y - _center_offset) * 1.0
	)
	var enemy_node: Node3D = _create_enemy_node(data, spawn_pos)
	add_child(enemy_node)
	enemy_node.rotation = Vector3.ZERO
	var shadow_size := Vector2(1.5, 1.0) if data.get("is_boss", false) else Vector2(0.85, 0.55)
	ModelLoader.set_ground_shadow(
		enemy_node, stage_theme == "sky", shadow_size
	)
	if enemy_node.has_method("reset_for_spawn"):
		enemy_node.call("reset_for_spawn")
	if enemy_node.has_method("set_nav_target"):
		enemy_node.call("set_nav_target",
			_pendopo_position_at(_nearest_pendopo_index(spawn_pos)))
	SpatialIndex.register(enemy_node, "enemies")
	_enemy_nodes.append(enemy_node)
	var cb := _on_enemy_removed.bind(enemy_node)
	if not enemy_node.tree_exited.is_connected(cb):
		enemy_node.tree_exited.connect(cb)
	_emit_count()


func _create_enemy_node(data: Dictionary, pos: Vector3) -> Node3D:
	var is_boss: bool = data.get("is_boss", false)
	var enemy: Node3D
	if is_boss:
		enemy = ModelLoader.load_boss(str(data.get("model", "kurawa")))
		enemy.set_script(ENEMY_SCRIPT)
		enemy.add_to_group("enemies")
		UnitPool.attach_common_children(enemy)
	else:
		# Type must be known here: the pool hands out a rig matching the type, so an
		# archer never ends up wearing an infantry body.
		enemy = UnitPool.acquire_enemy(str(data.get("type", "infantry")))
	_configure_enemy(enemy, data, pos)
	return enemy


func _configure_enemy(enemy: Node3D, data: Dictionary, pos: Vector3) -> void:
	enemy.position = pos
	enemy.rotation = Vector3.ZERO
	var health: float = data.get("health", 100)
	var max_health: float = data.get("max_health", health)
	enemy.set_meta("current_health", health)
	enemy.set_meta("max_health", max_health)
	enemy.set_meta("enemy_dead", false)
	enemy.set_meta("enemy_data", data)
	enemy.set_meta("attack_cooldown", 0.0)
	enemy.set_meta("attack_anim_lock", 0.0)
	enemy.set_meta("pending_enemy_attack", {})
	enemy.set_meta("nav_stalled_time", 0.0)
	enemy.set_meta("nav_fallback_active", false)
	enemy.set_meta("anim_state", "idle")
	enemy.remove_meta("attack_offset")
	enemy.set_meta("footstep_timer", 0.0)
	# Pooled enemies come back with whatever boss state the previous user left behind.
	enemy.set_meta("boss_dash_cd", 0.0)
	enemy.set_meta("boss_quake_cd", 0.0)
	enemy.set_meta("boss_dash_timer", 0.0)
	enemy.set_meta("boss_dash_dir", Vector3.ZERO)
	enemy.set_meta("boss_dash_remaining", 0.0)
	enemy.set_meta("boss_dash_speed", 0.0)
	enemy.set_meta("boss_dash_effect_timer", 0.0)
	enemy.set_meta("boss_dash_effect_fired", false)
	enemy.set_meta("boss_quake_timer", 0.0)
	enemy.set_meta("boss_berserk_active", false)
	enemy.set_meta("boss_skill_lock", 0.0)
	enemy.set_meta("boss_power_attack_cd", 0.0)
	var stamina_max: float = float(data.get("stamina_max", 0.0))
	enemy.set_meta("boss_stamina_max", stamina_max)
	enemy.set_meta("boss_stamina", stamina_max)
	var mana_max: float = float(data.get("mana_max", 0.0))
	enemy.set_meta("boss_mana_max", mana_max)
	enemy.set_meta("boss_mana", mana_max)
	enemy.add_to_group("enemies")
	if enemy.has_method("_update_hp_bar"):
		enemy.call("_update_hp_bar")


func _find_edge_spawn_tiles() -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	for x in range(_map_size):
		for y in [0, _map_size - 1]:
			var pos := Vector2i(x, y)
			if MapGenerator.is_walkable(_terrain, pos):
				tiles.append(pos)
	for y in range(_map_size):
		for x in [0, _map_size - 1]:
			var pos := Vector2i(x, y)
			if MapGenerator.is_walkable(_terrain, pos):
				tiles.append(pos)
	return tiles


func _find_pendopo_tile() -> Vector2i:
	for child in get_parent().get_children():
		if child.has_method("get") and "building_id" in child and child.building_id == "pendopo":
			return Vector2i(floori(child.position.x + _center_offset), floori(child.position.z + _center_offset))
	return Vector2i(_map_size / 2, _map_size / 2)


func _on_enemy_removed(enemy: Node3D) -> void:
	_enemy_nodes.erase(enemy)
	_emit_count()
	if _waiting_for_clear:
		_check_wave_complete()


func _check_wave_complete() -> void:
	if _wave_ending:
		return
	if not _pending_spawns.is_empty():
		return
	var alive := 0
	for enemy in _enemy_nodes:
		if is_instance_valid(enemy) and enemy.is_inside_tree():
			alive += 1
	if alive == 0 and _enemies_remaining <= 0:
		_start_wave_end()


func _start_wave_end() -> void:
	if _wave_ending:
		return
	if not is_inside_tree():
		return
	_wave_ending = true
	_wave_delay_timer.start()


func _on_wave_delay_done() -> void:
	wave_complete.emit(true)


func _emit_count() -> void:
	var alive := 0
	for enemy in _enemy_nodes:
		if is_instance_valid(enemy) and enemy.is_inside_tree():
			alive += 1
	enemy_count_changed.emit(alive, _total_for_wave)


func _play_enemy_anim(enemy: Node3D, anim_name: String, blend: float) -> bool:
	var anim_player: AnimationPlayer = enemy.get_anim_player()
	if anim_player == null:
		return false
	if anim_player.has_animation(anim_name):
		return ModelLoader.play_rig_animation(
			enemy, anim_player, anim_name, blend, true
		)
	return false


func _physics_process(delta: float) -> void:
	_update_frame += 1
	_drain_pending_spawn()
	_move_enemies(delta)


func _move_enemies(delta: float) -> void:
	for enemy in _enemy_nodes.duplicate():
		if not is_instance_valid(enemy):
			continue
		if not enemy.is_inside_tree():
			continue
		if not enemy.is_alive():
			continue
		var enemy_data: Dictionary = enemy.get_meta("enemy_data", {})
		var speed: float = enemy_data.get("speed", 2.5)

		_tick_pending_enemy_attack(enemy, delta)
		_tick_pending_boss_earthquake(enemy, delta)

		# Boss cooldowns tick every frame, before any throttling check, so a dashed or
		# slammed boss cannot chain its special by being off-camera.
		_tick_boss_cooldowns(enemy, delta)
		var skill_lock: float = maxf(
			float(enemy.get_meta("boss_skill_lock", 0.0)) - delta, 0.0
		)
		enemy.set_meta("boss_skill_lock", skill_lock)
		var attack_lock: float = maxf(float(enemy.get_meta("attack_anim_lock", 0.0)) - delta, 0.0)
		enemy.set_meta("attack_anim_lock", attack_lock)
		var attack_cooldown: float = maxf(
			float(enemy.get_meta("attack_cooldown", 0.0)) - delta,
			0.0
		)
		enemy.set_meta("attack_cooldown", attack_cooldown)

		# A dashing boss is under script control, not the nav agent: steering it here
		# would fight the dash and pull it back toward the pendopo.
		if enemy.get_meta("boss_dash_timer", 0.0) > 0.0:
			_tick_boss_dash(enemy, delta)
			continue
		if skill_lock > 0.0:
			continue
		_try_boss_special(enemy, enemy_data)
		if enemy.get_meta("boss_dash_timer", 0.0) > 0.0:
			_tick_boss_dash(enemy, delta)
			continue
		if float(enemy.get_meta("boss_skill_lock", 0.0)) > 0.0:
			continue

		var nav: NavigationAgent3D = enemy.get_nav()
		if nav == null:
			continue

		# Each enemy walks to the nearest living pendopo, so waves split naturally
		# and fall back onto the survivors when one is destroyed.
		var target_index: int = _nearest_pendopo_index(enemy.position)
		var pendopo_pos: Vector3 = _pendopo_position_at(target_index)

		var nav_done: bool = nav.is_navigation_finished()
		if target_index < 0:
			nav_done = true
		var standoff: float = _enemy_standoff(enemy_data)
		var ranged: bool = standoff > ENEMY_ATTACK_RANGE
		var reach: float = standoff + (RANGED_REACH_SLACK if ranged else 0.0)
		var to_pendopo := Vector2(
			pendopo_pos.x - enemy.position.x,
			pendopo_pos.z - enemy.position.z
		)
		var next_path_position: Vector3 = enemy.position

		if not nav_done:
			enemy.set_nav_target(pendopo_pos)
			next_path_position = nav.get_next_path_position()
			if to_pendopo.length() <= standoff + 0.5:
				nav_done = true
				enemy.set_meta("nav_stalled_time", 0.0)
			elif enemy.position.distance_to(next_path_position) <= MOVE_STOP_TOLERANCE:
				enemy.set_meta(
					"nav_stalled_time",
					float(enemy.get_meta("nav_stalled_time", 0.0)) + delta
				)
			else:
				enemy.set_meta("nav_stalled_time", 0.0)
		else:
			enemy.set_meta("nav_stalled_time", 0.0)

		var target_pos: Vector3
		var nav_fallback_active: bool = enemy.get_meta("nav_fallback_active", false)
		if nav_done and ranged:
			if to_pendopo.length() <= reach:
				# Archers hold their position once they reach range.
				target_pos = enemy.position
			else:
				target_pos = _enemy_approach_position(
					enemy, pendopo_pos, ranged, standoff
				)
		elif nav_done:
			target_pos = _enemy_approach_position(
				enemy, pendopo_pos, ranged, standoff
			)
		elif nav_fallback_active:
			target_pos = _enemy_approach_position(
				enemy, pendopo_pos, ranged, standoff
			)
		else:
			target_pos = next_path_position
			if float(enemy.get_meta("nav_stalled_time", 0.0)) >= 0.5 \
					and to_pendopo.length() > standoff + 0.5:
				enemy.set_meta("nav_fallback_active", true)
				target_pos = _enemy_approach_position(enemy, pendopo_pos, ranged, standoff)

		var move_dir: Vector3 = (target_pos - enemy.position).normalized()
		var dist_to_target: float = enemy.position.distance_to(target_pos)
		var is_moving: bool = dist_to_target > MOVE_STOP_TOLERANCE

		var king_in_range: bool = false
		if _king_ref and is_instance_valid(_king_ref) and _king_ref.has_method("take_damage"):
			var dist_to_king: float = enemy.position.distance_to(_king_ref.position)
			if dist_to_king < reach:
				king_in_range = true

		var soldier_target: Node3D = SpatialIndex.get_nearest(enemy.position, reach, "troops")

		var has_combat_target: bool = soldier_target != null or king_in_range

		if not has_combat_target and is_moving and attack_lock <= 0.0:
			var step := minf(speed * delta, dist_to_target)
			enemy.position += move_dir * step
			SFXManager.play_footstep(enemy, delta)

		if not has_combat_target and move_dir.length() > 0.1 and is_moving and attack_lock <= 0.0:
			var target_yaw: float = atan2(move_dir.x, move_dir.z)
			enemy.rotation.y = lerp_angle(enemy.rotation.y, target_yaw, 10.0 * delta)

		var anim_state: String = enemy.get_meta("anim_state", "")
		var anim_prefix: String = "boss/" if enemy_data.get("is_boss", false) else "enemy/"

		if soldier_target != null:
			var soldier_face: Vector3 = (soldier_target.position - enemy.position).normalized()
			if soldier_face.length() > 0.01:
				var soldier_yaw: float = atan2(soldier_face.x, soldier_face.z)
				enemy.rotation.y = lerp_angle(enemy.rotation.y, soldier_yaw, 10.0 * delta)
			_try_enemy_attack(enemy, enemy_data, delta, soldier_target)
		elif king_in_range:
			var face_dir: Vector3 = (_king_ref.position - enemy.position).normalized()
			if face_dir.length() > 0.01:
				var attack_yaw: float = atan2(face_dir.x, face_dir.z)
				enemy.rotation.y = lerp_angle(enemy.rotation.y, attack_yaw, 10.0 * delta)
			_try_enemy_attack(enemy, enemy_data, delta)
		elif nav_done and not is_moving:
			var face_dir: Vector3 = (pendopo_pos - enemy.position).normalized()
			if face_dir.length() > 0.01:
				var attack_yaw: float = atan2(face_dir.x, face_dir.z)
				enemy.rotation.y = lerp_angle(enemy.rotation.y, attack_yaw, 10.0 * delta)
			_try_enemy_attack(enemy, enemy_data, delta)
		elif attack_lock > 0.0:
			# Committed to a swing. The target may have drifted out of reach, but
			# the pose stays on the attack so the swing, its SFX and its damage
			# land together instead of the walk clip cutting the swing off.
			if anim_state != "attack":
				if _play_enemy_anim(enemy, _attack_anim_for(enemy_data), 0.15):
					enemy.set_meta("anim_state", "attack")
		elif is_moving:
			if anim_state != "walk":
				if _play_enemy_anim(enemy, anim_prefix + "run", 0.2):
					enemy.set_meta("anim_state", "walk")
		else:
			if anim_state != "idle":
				if _play_enemy_anim(enemy, anim_prefix + "idle", 0.3):
					enemy.set_meta("anim_state", "idle")


func _enemy_approach_position(
	enemy: Node3D,
	pendopo_pos: Vector3,
	ranged: bool,
	standoff: float
) -> Vector3:
	if ranged:
		var direction := Vector3(
			enemy.position.x - pendopo_pos.x,
			0.0,
			enemy.position.z - pendopo_pos.z
		).normalized()
		if direction.length_squared() < 0.01:
			direction = Vector3.FORWARD
		var position := pendopo_pos + direction * maxf(
			0.5, standoff + RANGED_REACH_SLACK * 0.5
		)
		position.y = 0.3
		return position

	if not enemy.has_meta("attack_offset"):
		var angle: float = randf() * TAU
		var distance: float = maxf(
			0.5,
			standoff - MOVE_STOP_TOLERANCE - randf_range(0.0, 0.6)
		)
		enemy.set_meta("attack_offset", Vector3(
			cos(angle) * distance, 0.0, sin(angle) * distance
		))
	var position: Vector3 = pendopo_pos + enemy.get_meta("attack_offset") as Vector3
	position.y = 0.3
	return position


const ENEMY_ATTACK_HALF_WIDTH: float = 1.5
const ENEMY_RANGED_COOLDOWN: float = 2.2
# Archers stop navigating a hair outside their reach, so give the shot a margin.
const RANGED_REACH_SLACK: float = 0.75
const ARROW_SCRIPT: GDScript = preload("res://scenes/projectiles/arrow_projectile.gd")

# Enemy archers stop at the shared 10-tile arrow range instead of walking in.
func is_enemy_ranged(enemy: Node3D) -> bool:
	if enemy == null or not is_instance_valid(enemy):
		return false
	return _is_ranged_data(_enemy_data_of(enemy))


# Bosses carry their own ranged flag from the registry; archers are ranged by type.
func _is_ranged_data(enemy_data: Dictionary) -> bool:
	if enemy_data.get("is_boss", false):
		return enemy_data.get("ranged", false)
	return enemy_data.get("type", "infantry") == "archer"


func _enemy_data_of(enemy: Node3D) -> Dictionary:
	return enemy.get_meta("enemy_data", {}) if is_instance_valid(enemy) else {}


func _enemy_standoff(enemy_data: Dictionary) -> float:
	if _is_ranged_data(enemy_data):
		return ProgressionData.ARROW_RANGE
	if enemy_data.get("is_boss", false):
		return BOSS_MELEE_ATTACK_RANGE
	return ENEMY_ATTACK_RANGE


func _is_in_attack_cone(enemy: Node3D, target_pos: Vector3) -> bool:
	var to_target := target_pos - enemy.position
	var fwd := Vector3(sin(enemy.rotation.y), 0.0, cos(enemy.rotation.y))
	var right := Vector3(cos(enemy.rotation.y), 0.0, -sin(enemy.rotation.y))
	var forward_dist: float = to_target.dot(fwd)
	if forward_dist < 0.0:
		return false
	var lateral_dist: float = absf(to_target.dot(right))
	return lateral_dist <= ENEMY_ATTACK_HALF_WIDTH


func _try_enemy_attack(
	enemy: Node3D,
	enemy_data: Dictionary,
	_delta: float,
	soldier_target: Node3D = null
) -> void:
	if enemy.get_meta("pending_enemy_attack", {}).get("active", false):
		return
	var attack_cooldown: float = enemy.get_meta("attack_cooldown", 0.0)
	if attack_cooldown > 0.0:
		var attack_lock: float = float(enemy.get_meta("attack_anim_lock", 0.0))
		if attack_lock <= 0.0 and enemy.get_meta("anim_state", "") == "attack":
			if _play_enemy_anim(
				enemy,
				"boss/idle" if enemy_data.get("is_boss", false) else "enemy/idle",
				0.2
			):
				enemy.set_meta("anim_state", "idle")
		return

	var ranged: bool = _is_ranged_data(enemy_data)
	var standoff: float = _enemy_standoff(enemy_data)
	if ranged:
		standoff += RANGED_REACH_SLACK

	var attack_damage: float = enemy_data.get("attack", 8.0)
	if enemy.get_meta("boss_berserk_active", false):
		attack_damage *= 1.5
	var power_attack: bool = enemy_data.get("is_boss", false) \
		and str(enemy_data.get("special", "")) == "power_attack" \
		and float(enemy.get_meta("boss_power_attack_cd", 0.0)) <= 0.0 \
		and _has_boss_mana(enemy, BOMA_POWER_ATTACK_MANA_COST_RATIO)
	var arrow_style: String = str(enemy_data.get("arrow_style", ""))
	if enemy_data.get("is_boss", false) and str(enemy_data.get("boss_id", "")) == BossRegistry.BOMA:
		arrow_style = "boma_red" if power_attack else "normal"
	var attack_target: Node3D = null
	var target_kind: String = ""
	if soldier_target and is_instance_valid(soldier_target) and soldier_target.has_method("take_damage"):
		var dist_to_soldier: float = enemy.position.distance_to(soldier_target.position)
		if dist_to_soldier < standoff:
			if _is_in_attack_cone(enemy, soldier_target.position):
				attack_target = soldier_target
				target_kind = "soldier"

	if attack_target == null and _king_ref and is_instance_valid(_king_ref) \
			and _king_ref.has_method("take_damage"):
		var dist_to_king: float = enemy.position.distance_to(_king_ref.position)
		if dist_to_king < standoff and _is_in_attack_cone(enemy, _king_ref.position):
			attack_target = _king_ref
			target_kind = "king"

	if attack_target == null:
		var pendopo: Node3D = _pendopo_ref_in_reach(enemy, standoff)
		if pendopo != null and pendopo.has_method("take_damage"):
			attack_target = pendopo
			target_kind = "building"

	if power_attack and attack_target == null:
		power_attack = false
		arrow_style = "normal"
	var animation_name: String = _attack_anim_for(enemy_data, power_attack)
	var animation_length: float = _enemy_animation_length(
		enemy, animation_name, ENEMY_ATTACK_COOLDOWN
	)
	if not _play_enemy_anim(enemy, animation_name, 0.15):
		animation_length = ENEMY_ATTACK_COOLDOWN
	else:
		enemy.set_meta("anim_state", "attack")
	var cooldown: float = ENEMY_RANGED_COOLDOWN if ranged else ENEMY_ATTACK_COOLDOWN
	enemy.set_meta("attack_cooldown", cooldown)
	enemy.set_meta("attack_anim_lock", animation_length)
	enemy.set_meta("pending_enemy_attack", {
		"active": true,
		"timer": animation_length if power_attack \
			else _animation_impact_delay(
				animation_length,
				0.4 if str(enemy_data.get("boss_id", "")) == BossRegistry.KALAPRACONA else -1.0
			),
		"animation_name": animation_name,
		"target": attack_target,
		"target_kind": target_kind,
		"damage": attack_damage,
		"ranged": ranged,
		"arrow_style": arrow_style,
		"power_attack": power_attack,
		"standoff": standoff,
	})
	if not ranged:
		SFXManager.play_enemy_swing(enemy.position)


func _tick_pending_enemy_attack(enemy: Node3D, delta: float) -> void:
	var pending: Dictionary = enemy.get_meta("pending_enemy_attack", {})
	if not pending.get("active", false):
		return
	var timer: float = maxf(float(pending.get("timer", 0.0)) - delta, 0.0)
	pending["timer"] = timer
	if timer > 0.0:
		enemy.set_meta("pending_enemy_attack", pending)
		return
	enemy.set_meta("pending_enemy_attack", {})
	if not pending.get("ranged", false):
		_spawn_boss_attack_slash(
			enemy,
			enemy.get_meta("enemy_data", {}),
			str(pending.get("animation_name", ""))
		)

	var target: Node3D = pending.get("target")
	if target == null or not is_instance_valid(target) or not target.is_inside_tree() \
			or not target.has_method("take_damage"):
		return
	if target.has_method("is_alive") and not target.is_alive():
		return
	var current_distance: float = enemy.global_position.distance_to(target.global_position)
	if current_distance >= float(pending.get("standoff", ENEMY_ATTACK_RANGE)) \
			or not _is_in_attack_cone(enemy, target.global_position):
		return

	if pending.get("ranged", false):
		var is_power_attack: bool = pending.get("power_attack", false)
		if is_power_attack and not _spend_boss_mana(enemy, BOMA_POWER_ATTACK_MANA_COST_RATIO):
			return
		_fire_enemy_arrow(
			enemy,
			target,
			float(pending.get("damage", 0.0)),
			str(pending.get("arrow_style", "")),
			is_power_attack
		)
		if is_power_attack:
			enemy.set_meta("boss_power_attack_cd", BOSS_POWER_ATTACK_COOLDOWN)
		return

	target.take_damage(float(pending.get("damage", 0.0)))
	SFXManager.play_enemy_hit(str(pending.get("target_kind", "king")), enemy.position)


func _enemy_animation_length(enemy: Node3D, animation_name: String, fallback: float) -> float:
	var anim_player: AnimationPlayer = enemy.get_anim_player()
	if anim_player == null or not anim_player.has_animation(animation_name):
		return fallback
	return maxf(anim_player.get_animation(animation_name).length, 0.0)


func _animation_impact_delay(animation_length: float, progress: float = -1.0) -> float:
	var impact_progress: float = progress if progress >= 0.0 else ANIMATION_IMPACT_PROGRESS
	return maxf(animation_length * impact_progress, 0.0)


func _spawn_boss_attack_slash(
	enemy: Node3D,
	enemy_data: Dictionary,
	animation_name: String = ""
) -> void:
	if not enemy_data.get("is_boss", false):
		return
	var boss_id: String = str(enemy_data.get("boss_id", ""))
	if boss_id not in [BossRegistry.ASWATAMA, BossRegistry.KARNA]:
		return
	if boss_id == BossRegistry.KARNA and animation_name == "boss/attack_3":
		var wave := CIRCLE_WAVE_SCRIPT.new() as Node3D
		wave.name = "BossAttackCircleWave"
		wave.set("wave_color", Color(1.0, 0.12, 0.08, 0.9))
		wave.position = Vector3(0.0, 1.0, 1.4)
		enemy.add_child(wave)
		return
	var slash := ARC_SLASH_SCRIPT.new() as Node3D
	slash.name = "BossAttackArcSlash"
	slash.set("slash_color", Color(1.0, 0.12, 0.08, 0.9))
	slash.position = Vector3(0.0, 1.0, 1.4)
	enemy.add_child(slash)


func _dash_effect_delay(animation_length: float) -> float:
	return maxf(
		animation_length - BOSS_DASH_EFFECT_LEAD_FRAMES / BOSS_DASH_ANIMATION_FPS,
		0.0
	)


# ─── Boss specials ───
# Aswatama and Karna use their dash and earthquake clips. Karna also enters berserk
# below half health, adding its aura and increasing its attack damage.
#
# The dash plays when it is not yet in range and then closes the gap, which is what makes
# it feel like a charger rather than a walker. The earthquake is an area attack on a longer
# cooldown, because an area nuke on the melee cooldown would delete the player's garrison
# with no counterplay.
const BOSS_DASH_MIN_DISTANCE: float = 3.0
const BOSS_DASH_MAX_DISTANCE: float = 9.0
const BOSS_DASH_SPEED: float = 16.0
const BOSS_DASH_DURATION: float = 0.35
const BOSS_DASH_MAX_TRAVEL: float = 5.5
const BOSS_DASH_STOP_DISTANCE: float = 1.5
const BOSS_DASH_COOLDOWN: float = 4.0
const BOSS_DASH_STAMINA_COST: float = 25.0
const BOSS_STAMINA_REGEN: float = 12.0
const BOSS_EARTHQUAKE_COOLDOWN: float = 9.0
const BOSS_MANA_REGEN_RATIO: float = 0.025
const BOMA_POWER_ATTACK_MANA_COST_RATIO: float = 0.2
const KARNA_EARTHQUAKE_MANA_COST_RATIO: float = 0.25
const KARNA_BERSERK_MANA_COST_RATIO: float = 0.5
const BOSS_EARTHQUAKE_LOCK: float = 0.9
const BOSS_EARTHQUAKE_RADIUS: float = 5.0
const BOSS_EARTHQUAKE_MULT: float = 1.8
const BOSS_BERSERK_LOCK: float = 1.0
const BOSS_POWER_ATTACK_COOLDOWN: float = 7.0


func _try_boss_special(enemy: Node3D, enemy_data: Dictionary) -> bool:
	if not enemy_data.get("is_boss", false):
		return false
	var special: String = str(enemy_data.get("special", ""))
	var specials: Array = enemy_data.get("specials", [])
	var has_explicit_specials: bool = not specials.is_empty()
	var can_dash: bool = specials.has("dash") or (
		not has_explicit_specials and special == "dash"
	)
	var can_quake: bool = specials.has("earthquake") or (
		not has_explicit_specials and special == "earthquake"
	)
	var can_berserk: bool = specials.has("berserk")

	var max_health: float = float(enemy.get_meta("max_health", 0.0))
	var health: float = float(enemy.get_meta("current_health", max_health))
	if can_berserk and not enemy.get_meta("boss_berserk_active", false) \
			and max_health > 0.0 and health / max_health <= 0.5 \
			and _spend_boss_mana(enemy, KARNA_BERSERK_MANA_COST_RATIO):
		_activate_boss_berserk(enemy)
		return true

	if not can_dash and not can_quake:
		return false

	var dash_cd: float = enemy.get_meta("boss_dash_cd", 0.0)
	var quake_cd: float = enemy.get_meta("boss_quake_cd", 0.0)

	var target: Node3D = _special_target(enemy)
	if target == null:
		return false
	var dist: float = enemy.position.distance_to(target.position)

	if can_dash and dist >= BOSS_DASH_MIN_DISTANCE \
			and dist <= BOSS_DASH_MAX_DISTANCE and dash_cd <= 0.0 \
			and _spend_boss_stamina(enemy, BOSS_DASH_STAMINA_COST):
		var dash_length: float = _enemy_animation_length(
			enemy, "boss/dash", BOSS_DASH_DURATION
		)
		_play_enemy_anim(enemy, "boss/dash", 0.15)
		SFXManager.play_dash()
		enemy.set_meta("boss_dash_cd", BOSS_DASH_COOLDOWN)
		_start_boss_dash(enemy, target, dash_length)
		return true

	# Only slam when actually adjacent, so it reads as a punish for standing too close.
	if can_quake and dist < BOSS_EARTHQUAKE_RADIUS and quake_cd <= 0.0 \
			and _has_boss_mana(enemy, KARNA_EARTHQUAKE_MANA_COST_RATIO):
		var quake_length: float = _enemy_animation_length(
			enemy, "boss/earthquake", BOSS_EARTHQUAKE_LOCK
		)
		_play_enemy_anim(enemy, "boss/earthquake", 0.15)
		SFXManager.play_earth_quake_skill()
		_spend_boss_mana(enemy, KARNA_EARTHQUAKE_MANA_COST_RATIO)
		enemy.set_meta("boss_quake_cd", BOSS_EARTHQUAKE_COOLDOWN)
		enemy.set_meta("boss_skill_lock", quake_length)
		enemy.set_meta("attack_cooldown", quake_length + ENEMY_ATTACK_COOLDOWN)
		enemy.set_meta("boss_quake_timer", _animation_impact_delay(quake_length))
		return true
	return false


func _activate_boss_berserk(enemy: Node3D) -> void:
	enemy.set_meta("boss_berserk_active", true)
	enemy.set_meta("boss_skill_lock", BOSS_BERSERK_LOCK)
	_play_enemy_anim(enemy, "boss/berserk", 0.15)
	enemy.set_meta("anim_state", "attack")
	var aura := BERSERK_AURA_SCRIPT.new() as Node3D
	aura.name = "BossBerserkAura"
	enemy.add_child(aura)


# The nearest thing worth closing on, or null if the boss has nothing to chase.
func _special_target(enemy: Node3D) -> Node3D:
	var soldier: Node3D = SpatialIndex.get_nearest(enemy.position, BOSS_DASH_MAX_DISTANCE, "troops")
	if soldier != null and is_instance_valid(soldier):
		return soldier
	if _king_ref and is_instance_valid(_king_ref) and _king_ref.has_method("take_damage"):
		return _king_ref
	return _pendopo_ref_in_reach(enemy, BOSS_EARTHQUAKE_RADIUS + 1.0)


func _start_boss_dash(
	enemy: Node3D,
	target: Node3D,
	dash_length: float = 0.0
) -> void:
	var dir: Vector3 = target.global_position - enemy.global_position
	dir.y = 0.0
	if dir.length() < 0.001:
		return
	var dash_distance: float = minf(
		BOSS_DASH_MAX_TRAVEL,
		maxf(dir.length() - BOSS_DASH_STOP_DISTANCE, 0.0)
	)
	if dash_distance <= 0.0:
		return
	if dash_length <= 0.0:
		dash_length = _enemy_animation_length(
			enemy, "boss/dash", BOSS_DASH_DURATION
		)
	enemy.set_meta("boss_dash_dir", dir.normalized())
	enemy.set_meta("boss_dash_remaining", dash_distance)
	enemy.set_meta("boss_dash_timer", dash_length)
	enemy.set_meta("boss_dash_speed", dash_distance / maxf(dash_length, 0.001))
	enemy.set_meta("boss_dash_effect_timer", _dash_effect_delay(dash_length))
	enemy.set_meta("boss_dash_effect_fired", false)
	enemy.rotation.y = atan2(dir.x, dir.z)


func _spawn_boss_dash_effect(enemy: Node3D, direction: Vector3) -> void:
	var effect := DASH_TRAIL_SCRIPT.new() as Node3D
	effect.name = "BossDashTrail"
	effect.set("facing", atan2(direction.x, direction.z))
	var effect_parent: Node = get_parent() if get_parent() != null else self
	effect_parent.add_child(effect)
	effect.global_position = enemy.global_position


func _spend_boss_stamina(enemy: Node3D, cost: float) -> bool:
	var stamina: float = float(enemy.get_meta("boss_stamina", 0.0))
	if stamina < cost:
		return false
	enemy.set_meta("boss_stamina", stamina - cost)
	return true


func _has_boss_mana(enemy: Node3D, cost_ratio: float) -> bool:
	var mana_max: float = float(enemy.get_meta("boss_mana_max", 0.0))
	var mana: float = float(enemy.get_meta("boss_mana", 0.0))
	return mana_max > 0.0 and mana >= mana_max * cost_ratio


func _spend_boss_mana(enemy: Node3D, cost_ratio: float) -> bool:
	if not _has_boss_mana(enemy, cost_ratio):
		return false
	var mana_max: float = float(enemy.get_meta("boss_mana_max", 0.0))
	var mana: float = float(enemy.get_meta("boss_mana", mana_max))
	enemy.set_meta("boss_mana", mana - mana_max * cost_ratio)
	return true


func _tick_boss_cooldowns(enemy: Node3D, delta: float) -> void:
	if not enemy.get_meta("enemy_data", {}).get("is_boss", false):
		return
	var dash_cd: float = enemy.get_meta("boss_dash_cd", 0.0)
	if dash_cd > 0.0:
		enemy.set_meta("boss_dash_cd", dash_cd - delta)
	var quake_cd: float = enemy.get_meta("boss_quake_cd", 0.0)
	if quake_cd > 0.0:
		enemy.set_meta("boss_quake_cd", maxf(quake_cd - delta, 0.0))
	var power_cd: float = float(enemy.get_meta("boss_power_attack_cd", 0.0))
	if power_cd > 0.0:
		enemy.set_meta("boss_power_attack_cd", maxf(power_cd - delta, 0.0))
	var stamina_max: float = float(enemy.get_meta("boss_stamina_max", 0.0))
	if stamina_max > 0.0:
		var stamina: float = float(enemy.get_meta("boss_stamina", stamina_max))
		enemy.set_meta("boss_stamina", minf(stamina + BOSS_STAMINA_REGEN * delta, stamina_max))
	var mana_max: float = float(enemy.get_meta("boss_mana_max", 0.0))
	if mana_max > 0.0:
		var mana: float = float(enemy.get_meta("boss_mana", mana_max))
		enemy.set_meta(
			"boss_mana",
			minf(mana + mana_max * BOSS_MANA_REGEN_RATIO * delta, mana_max)
		)


func _tick_boss_dash(enemy: Node3D, delta: float) -> void:
	var timer: float = enemy.get_meta("boss_dash_timer", 0.0)
	if timer <= 0.0:
		return
	var dir: Vector3 = enemy.get_meta("boss_dash_dir", Vector3.ZERO)
	var remaining: float = float(enemy.get_meta("boss_dash_remaining", 0.0))
	if dir.length() > 0.01 and remaining > 0.0:
		var travel: float = minf(
			float(enemy.get_meta("boss_dash_speed", BOSS_DASH_SPEED)) * delta,
			remaining
		)
		enemy.position += dir * travel
		remaining -= travel
		enemy.set_meta("boss_dash_remaining", remaining)
	var effect_timer: float = maxf(
		float(enemy.get_meta("boss_dash_effect_timer", 0.0)) - delta,
		0.0
	)
	enemy.set_meta("boss_dash_effect_timer", effect_timer)
	if effect_timer <= 0.0 and not enemy.get_meta("boss_dash_effect_fired", false):
		_spawn_boss_dash_effect(enemy, dir)
		enemy.set_meta("boss_dash_effect_fired", true)
	timer = maxf(timer - delta, 0.0)
	enemy.set_meta("boss_dash_timer", timer)
	if timer <= 0.0 or remaining <= 0.0:
		enemy.set_meta("boss_dash_timer", 0.0)
		enemy.set_meta("boss_dash_remaining", 0.0)
		enemy.set_meta("boss_dash_speed", 0.0)
		enemy.set_meta("boss_dash_dir", Vector3.ZERO)
		# Hand the boss back to the normal locomotion states rather than leaving it stuck
		# on a clip that will never be re-entered.
		enemy.set_meta("anim_state", "")


func _tick_pending_boss_earthquake(enemy: Node3D, delta: float) -> void:
	var timer: float = float(enemy.get_meta("boss_quake_timer", 0.0))
	if timer <= 0.0:
		return
	timer = maxf(timer - delta, 0.0)
	enemy.set_meta("boss_quake_timer", timer)
	if timer <= 0.0:
		_resolve_boss_earthquake(enemy, enemy.get_meta("enemy_data", {}))


func _resolve_boss_earthquake(enemy: Node3D, enemy_data: Dictionary) -> void:
	var center: Vector3 = enemy.global_position
	var effect := EARTHQUAKE_EFFECT_SCRIPT.new() as Node3D
	effect.name = "BossEarthquakeEffect"
	var effect_parent: Node = get_parent() if get_parent() != null else self
	effect_parent.add_child(effect)
	effect.global_position = center + Vector3(0.0, 0.1, 0.0)
	var berserk_mult: float = 1.5 if enemy.get_meta("boss_berserk_active", false) else 1.0
	var damage: float = float(enemy_data.get("attack", 8.0)) \
		* BOSS_EARTHQUAKE_MULT * berserk_mult

	for soldier in get_tree().get_nodes_in_group("troops"):
		if not is_instance_valid(soldier) or not soldier.has_method("take_damage"):
			continue
		if center.distance_to(soldier.global_position) <= BOSS_EARTHQUAKE_RADIUS:
			soldier.take_damage(damage)
			SFXManager.play_enemy_hit("soldier", center)

	if _king_ref and is_instance_valid(_king_ref) and _king_ref.has_method("take_damage"):
		if _king_ref.position.distance_to(center) <= BOSS_EARTHQUAKE_RADIUS:
			_king_ref.take_damage(damage)
			SFXManager.play_enemy_hit("king", center)

	for pendopo in _pendopo_refs:
		if not is_instance_valid(pendopo) or _is_pendopo_destroyed(pendopo):
			continue
		if center.distance_to(pendopo.global_position) <= BOSS_EARTHQUAKE_RADIUS \
				and pendopo.has_method("take_damage"):
			pendopo.take_damage(damage)
			SFXManager.play_enemy_hit("building", center)


# A boss with attack variants cycles through those clips. Dash is a movement clip and
# never lands here; it is played by _try_boss_special() when the boss closes on a target.
func _attack_anim_for(enemy_data: Dictionary, power_attack: bool = false) -> String:
	var prefix: String = "boss/" if enemy_data.get("is_boss", false) else "enemy/"
	if prefix == "boss/" and power_attack:
		return prefix + "power_attack"
	var variants: Array = enemy_data.get("attack_variants", [])
	if prefix == "boss/" and not variants.is_empty():
		return prefix + str(variants[randi_range(0, variants.size() - 1)])
	return prefix + "attack"


func _fire_enemy_arrow(
	enemy: Node3D,
	target: Node3D,
	damage: float,
	style: String = "",
	power_aura: bool = false
) -> void:
	var arrow: Node3D = ARROW_SCRIPT.acquire()
	if arrow == null:
		return
	var arrow_parent: Node
	if get_parent() != null:
		arrow_parent = get_parent()
	elif enemy.get_parent() != null:
		arrow_parent = enemy.get_parent()
	else:
		arrow.queue_free()
		return
	# Add to the tree BEFORE setup(): setup() calls look_at_from_position(), and basing
	# that on a parentless node makes the arrow orient in the wrong frame once it gets
	# reparented under a transformed parent. That is what turned the arrow sideways.
	arrow_parent.add_child(arrow)
	var dir_h: Vector3 = target.global_position - enemy.global_position
	dir_h.y = 0.0
	var muzzle: Vector3 = ModelLoader.bow_hand_point(enemy)
	if dir_h.length() > 0.001:
		muzzle += dir_h.normalized() * 0.4
	arrow.setup(target, muzzle, damage, style, power_aura)
	SFXManager.play_arrow_shot(enemy.global_position)


# The living pendopo this enemy is actually standing in front of.
func _pendopo_ref_in_reach(enemy: Node3D, standoff: float = ENEMY_ATTACK_RANGE) -> Node3D:
	for p in _pendopo_refs:
		if not is_instance_valid(p) or _is_pendopo_destroyed(p):
			continue
		if not p.has_method("take_damage"):
			continue
		if enemy.position.distance_to(p.position) < standoff \
				and _is_in_attack_cone(enemy, p.position):
			return p
	return null


func _create_bar_texture() -> Texture2D:
	var img: Image = Image.create(1, 1, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	return ImageTexture.create_from_image(img)
