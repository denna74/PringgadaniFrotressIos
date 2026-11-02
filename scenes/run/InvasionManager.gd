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
# How close an enemy has to get before it stops walking toward its mark. Parking
# spots are offset by this so a settled enemy is still inside its own reach.
const MOVE_STOP_TOLERANCE: float = 0.15
const ENEMY_ATTACK_COOLDOWN: float = 1.0
# How long a swing owns the enemy once it starts. Damage and SFX fire on the
# cooldown, but the pose was being re-decided every frame from "is a target in
# reach", so a target drifting out of range let walk/idle overwrite the swing a
# frame after it began -- damage and sound with the enemy visibly walking.
const ATTACK_ANIM_LOCK: float = 0.45

const ENEMY_SCRIPT: GDScript = preload("res://scenes/run/enemy_script.gd")
const BERSERK_AURA_SCRIPT: GDScript = preload("res://scenes/effects/BerserkAura.gd")

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
	enemy.set_meta("boss_berserk_active", false)
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

		# Boss cooldowns tick every frame, before any throttling check, so a dashed or
		# slammed boss cannot chain its special by being off-camera.
		_tick_boss_cooldowns(enemy, delta)
		var attack_lock: float = maxf(float(enemy.get_meta("attack_anim_lock", 0.0)) - delta, 0.0)
		enemy.set_meta("attack_anim_lock", attack_lock)

		# A dashing boss is under script control, not the nav agent: steering it here
		# would fight the dash and pull it back toward the pendopo.
		if enemy.get_meta("boss_dash_timer", 0.0) > 0.0:
			_tick_boss_dash(enemy, delta)
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
			if anim_state != "attack":
				if _play_enemy_anim(enemy, _attack_anim_for(enemy_data), 0.2):
					enemy.set_meta("anim_state", "attack")
			_try_enemy_attack(enemy, enemy_data, delta, soldier_target)
		elif king_in_range:
			var face_dir: Vector3 = (_king_ref.position - enemy.position).normalized()
			if face_dir.length() > 0.01:
				var attack_yaw: float = atan2(face_dir.x, face_dir.z)
				enemy.rotation.y = lerp_angle(enemy.rotation.y, attack_yaw, 10.0 * delta)
			if anim_state != "attack":
				if _play_enemy_anim(enemy, _attack_anim_for(enemy_data), 0.2):
					enemy.set_meta("anim_state", "attack")
			_try_enemy_attack(enemy, enemy_data, delta)
		elif nav_done and not is_moving:
			var face_dir: Vector3 = (pendopo_pos - enemy.position).normalized()
			if face_dir.length() > 0.01:
				var attack_yaw: float = atan2(face_dir.x, face_dir.z)
				enemy.rotation.y = lerp_angle(enemy.rotation.y, attack_yaw, 10.0 * delta)
			if anim_state != "attack":
				if _play_enemy_anim(enemy, _attack_anim_for(enemy_data), 0.2):
					enemy.set_meta("anim_state", "attack")
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
	return ProgressionData.ARROW_RANGE if _is_ranged_data(enemy_data) else ENEMY_ATTACK_RANGE


func _is_in_attack_cone(enemy: Node3D, target_pos: Vector3) -> bool:
	var to_target := target_pos - enemy.position
	var fwd := Vector3(sin(enemy.rotation.y), 0.0, cos(enemy.rotation.y))
	var right := Vector3(cos(enemy.rotation.y), 0.0, -sin(enemy.rotation.y))
	var forward_dist: float = to_target.dot(fwd)
	if forward_dist < 0.0:
		return false
	var lateral_dist: float = absf(to_target.dot(right))
	return lateral_dist <= ENEMY_ATTACK_HALF_WIDTH


func _try_enemy_attack(enemy: Node3D, enemy_data: Dictionary, delta: float, soldier_target: Node3D = null) -> void:
	var attack_cooldown: float = enemy.get_meta("attack_cooldown", 0.0)
	attack_cooldown -= delta
	if attack_cooldown > 0.0:
		enemy.set_meta("attack_cooldown", attack_cooldown)
		return

	var ranged: bool = _is_ranged_data(enemy_data)
	var standoff: float = _enemy_standoff(enemy_data)
	if ranged:
		standoff += RANGED_REACH_SLACK

	if not ranged:
		SFXManager.play_enemy_swing(enemy.position)

	var attack_damage: float = enemy_data.get("attack", 8.0)
	if enemy.get_meta("boss_berserk_active", false):
		attack_damage *= 1.5
	var attacked: bool = false

	if soldier_target and is_instance_valid(soldier_target) and soldier_target.has_method("take_damage"):
		var dist_to_soldier: float = enemy.position.distance_to(soldier_target.position)
		if dist_to_soldier < standoff:
			if _is_in_attack_cone(enemy, soldier_target.position):
				if ranged:
					_fire_enemy_arrow(enemy, soldier_target, attack_damage)
				else:
					soldier_target.take_damage(attack_damage)
					SFXManager.play_enemy_hit("soldier", enemy.position)
				attacked = true

	if not attacked and _king_ref and is_instance_valid(_king_ref) and _king_ref.has_method("take_damage"):
		var dist_to_king: float = enemy.position.distance_to(_king_ref.position)
		if dist_to_king < standoff and _is_in_attack_cone(enemy, _king_ref.position):
			if ranged:
				_fire_enemy_arrow(enemy, _king_ref, attack_damage)
			else:
				_king_ref.take_damage(attack_damage)
				SFXManager.play_enemy_hit("king", enemy.position)
			attacked = true

	if not attacked:
		var pendopo: Node3D = _pendopo_ref_in_reach(enemy, standoff)
		if pendopo != null and pendopo.has_method("take_damage"):
			if ranged:
				_fire_enemy_arrow(enemy, pendopo, attack_damage)
			else:
				pendopo.take_damage(attack_damage)
				SFXManager.play_enemy_hit("building", enemy.position)
	enemy.set_meta("attack_cooldown", ENEMY_RANGED_COOLDOWN if ranged else ENEMY_ATTACK_COOLDOWN)
	if _play_enemy_anim(enemy, _attack_anim_for(enemy_data), 0.15):
		enemy.set_meta("anim_state", "attack")
	# Hold the swing so walk/idle cannot steal the pose on the next frame, which
	# is what made damage and SFX play while the enemy appeared to just walk.
	enemy.set_meta("attack_anim_lock", ATTACK_ANIM_LOCK)
	_try_boss_special(enemy, enemy_data)


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
const BOSS_DASH_SPEED_MULT: float = 3.2
const BOSS_DASH_DURATION: float = 0.35
const BOSS_DASH_COOLDOWN: float = 4.0
const BOSS_EARTHQUAKE_COOLDOWN: float = 9.0
const BOSS_EARTHQUAKE_RADIUS: float = 5.0
const BOSS_EARTHQUAKE_MULT: float = 1.8


func _try_boss_special(enemy: Node3D, enemy_data: Dictionary) -> void:
	if not enemy_data.get("is_boss", false):
		return
	var special: String = str(enemy_data.get("special", ""))
	var specials: Array = enemy_data.get("specials", [])
	var has_explicit_specials: bool = not specials.is_empty()
	var can_dash: bool = specials.has("dash") or (
		not has_explicit_specials and special == "dash"
	)
	var can_quake: bool = specials.has("earthquake") or (
		not has_explicit_specials and special == "dash"
	)
	var can_berserk: bool = specials.has("berserk")

	var max_health: float = float(enemy.get_meta("max_health", 0.0))
	var health: float = float(enemy.get_meta("current_health", max_health))
	if can_berserk and not enemy.get_meta("boss_berserk_active", false) \
			and max_health > 0.0 and health / max_health <= 0.5:
		_activate_boss_berserk(enemy)
		return

	if not can_dash and not can_quake:
		return

	var dash_cd: float = enemy.get_meta("boss_dash_cd", 0.0)
	var quake_cd: float = enemy.get_meta("boss_quake_cd", 0.0)

	var target: Node3D = _special_target(enemy)
	if target == null:
		return
	var dist: float = enemy.position.distance_to(target.position)

	if can_dash and dist >= BOSS_DASH_MIN_DISTANCE \
			and dist <= BOSS_DASH_MAX_DISTANCE and dash_cd <= 0.0:
		if _play_enemy_anim(enemy, "boss/dash", 0.15):
			enemy.set_meta("boss_dash_cd", BOSS_DASH_COOLDOWN)
			_start_boss_dash(enemy, target)
		return

	# Only slam when actually adjacent, so it reads as a punish for standing too close.
	if can_quake and dist < BOSS_EARTHQUAKE_RADIUS and quake_cd <= 0.0:
		if _play_enemy_anim(enemy, "boss/earthquake", 0.15):
			enemy.set_meta("boss_quake_cd", BOSS_EARTHQUAKE_COOLDOWN)
			_resolve_boss_earthquake(enemy, enemy_data)


func _activate_boss_berserk(enemy: Node3D) -> void:
	enemy.set_meta("boss_berserk_active", true)
	if _play_enemy_anim(enemy, "boss/berserk", 0.15):
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


func _start_boss_dash(enemy: Node3D, target: Node3D) -> void:
	var dir: Vector3 = target.global_position - enemy.global_position
	dir.y = 0.0
	if dir.length() < 0.001:
		return
	enemy.set_meta("boss_dash_dir", dir.normalized())
	enemy.set_meta("boss_dash_timer", BOSS_DASH_DURATION)


func _tick_boss_cooldowns(enemy: Node3D, delta: float) -> void:
	if not enemy.get_meta("enemy_data", {}).get("is_boss", false):
		return
	var dash_cd: float = enemy.get_meta("boss_dash_cd", 0.0)
	if dash_cd > 0.0:
		enemy.set_meta("boss_dash_cd", dash_cd - delta)
	var quake_cd: float = enemy.get_meta("boss_quake_cd", 0.0)
	if quake_cd > 0.0:
		enemy.set_meta("boss_quake_cd", quake_cd - delta)


func _tick_boss_dash(enemy: Node3D, delta: float) -> void:
	var timer: float = enemy.get_meta("boss_dash_timer", 0.0)
	if timer <= 0.0:
		return
	timer -= delta
	enemy.set_meta("boss_dash_timer", timer)
	var dir: Vector3 = enemy.get_meta("boss_dash_dir", Vector3.ZERO)
	if dir.length() > 0.01 and timer > 0.0:
		enemy.position += dir * BOSS_DASH_SPEED_MULT * delta
	if timer <= 0.0:
		enemy.set_meta("boss_dash_dir", Vector3.ZERO)
		# Hand the boss back to the normal locomotion states rather than leaving it stuck
		# on a clip that will never be re-entered.
		enemy.set_meta("anim_state", "")


func _resolve_boss_earthquake(enemy: Node3D, enemy_data: Dictionary) -> void:
	var center: Vector3 = enemy.global_position
	var berserk_mult: float = 1.5 if enemy.get_meta("boss_berserk_active", false) else 1.0
	var damage: float = float(enemy_data.get("attack", 8.0)) \
		* BOSS_EARTHQUAKE_MULT * berserk_mult

	var soldier: Node3D = SpatialIndex.get_nearest(center, BOSS_EARTHQUAKE_RADIUS, "troops")
	if soldier != null and is_instance_valid(soldier) and soldier.has_method("take_damage"):
		if enemy.position.distance_to(soldier.position) <= BOSS_EARTHQUAKE_RADIUS:
			soldier.take_damage(damage)
			SFXManager.play_enemy_hit("soldier", center)

	if _king_ref and is_instance_valid(_king_ref) and _king_ref.has_method("take_damage"):
		if _king_ref.position.distance_to(center) <= BOSS_EARTHQUAKE_RADIUS:
			_king_ref.take_damage(damage)
			SFXManager.play_enemy_hit("king", center)

	var pendopo: Node3D = _pendopo_ref_in_reach(enemy, BOSS_EARTHQUAKE_RADIUS)
	if pendopo != null and pendopo.has_method("take_damage"):
		pendopo.take_damage(damage)
		SFXManager.play_enemy_hit("building", center)


# A boss with a named special uses that clip when it attacks, so Boma's red
# arrow is fired out of its power attack rather than a generic swing.
#
# A boss with attack variants cycles through those clips. Dash is a movement clip and
# never lands here; it is played by _try_boss_special() when the boss closes on a target.
func _attack_anim_for(enemy_data: Dictionary) -> String:
	var prefix: String = "boss/" if enemy_data.get("is_boss", false) else "enemy/"
	var special: String = str(enemy_data.get("special", ""))
	if prefix == "boss/" and special == "power_attack":
		return prefix + special
	var variants: Array = enemy_data.get("attack_variants", [])
	if prefix == "boss/" and not variants.is_empty():
		return prefix + str(variants[randi_range(0, variants.size() - 1)])
	return prefix + "attack"


func _fire_enemy_arrow(enemy: Node3D, target: Node3D, damage: float) -> void:
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
	arrow.setup(target, muzzle, damage, str(enemy.get_meta("enemy_data", {}).get("arrow_style", "")))
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
