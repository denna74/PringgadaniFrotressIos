extends Node3D

signal king_died
signal boss_defeated
signal stamina_changed(current: float, maximum: float)
signal mana_changed(current: float, maximum: float)
signal hp_changed(current: float, maximum: float)
signal healing_changed(active: bool)
signal berserk_changed(active: bool)

var king_speed_full: float = 200.0
var king_hp: float = 300.0
var king_max_hp: float = 300.0
var king_attack: float = 25.0
var king_defense: float = 0.0
var king_attack_cooldown: float = 0.4
var king_special_cooldown: float = 5.0

var stamina: float = 100.0
var stamina_max: float = 100.0

var mana: float = 200.0
var mana_max: float = 200.0

var _attack_timer: float = 0.0
var _special_timer: float = 0.0
var _cast_lock: float = 0.0
var _combo_step: int = 0
var _combo_reset_timer: float = 0.0
var _map_size: int = 0
var _center_offset: float = 0.0
var _velocity: Vector2 = Vector2.ZERO
var _move_dir: Vector2 = Vector2.ZERO
var _moving: bool = false
var _anim_time: float = 0.0
var _attack_anim: float = 0.0
var _facing: float = 0.0
var _dash_timer: float = 0.0
var _dash_cooldown_timer: float = 0.0
var _dash_speed: float = 0.0
var _dash_dir: Vector3 = Vector3.FORWARD
var _dash_hits: Dictionary = {}
var _dash_shield: Node3D = null

var _punch_ring: MeshInstance3D = null
var _ring_timer: float = 0.0
var _ring_delay: float = 0.0
var _aura: Node3D = null

var dpad_dir: Vector2 = Vector2.ZERO

var _model: Node3D = null
var _anim_player: AnimationPlayer = null
var frozen: bool = false
var pendopo_pos: Vector3 = Vector3.ZERO
var pendopo_positions: Array[Vector3] = []
var pendopo_heal_rates: Array[float] = []
var healing_active: bool = false
var _was_healing: bool = false
var _last_stamina_percent: float = -1.0
const PENDOPO_HEAL_RATE: float = 20.0
const PENDOPO_HEAL_RADIUS: float = 1.5
const IMPACT_SPARK: GDScript = preload("res://scenes/effects/MetalSpark.gd")
const PUNCH_RING_DURATION: float = 0.15
const PUNCH_RING_DELAY: float = 0.12
const PUNCH_RING_RADIUS: float = 2.5
const PUNCH_RING_FORWARD: float = 1.4
const PUNCH_RING_HEIGHT: float = 1.0
const DASH_SHIELD_FORWARD: float = 1.1
const DASH_SHIELD_HEIGHT: float = 1.35
const PUNCH_RING_COLOR: Color = Color(0.2, 0.6, 1.0, 0.8)
const COMBO_WINDOW: float = 0.9
const COMBO_ANIMS: Array[String] = ["attack_1", "attack_2", "attack_3"]
const KING_AURA_PATH: String = "res://scenes/effects/king_aura.gd"
const KING_AURA_HEIGHT: float = 0.1
const EARTHQUAKE_GRID_HALF: int = 3
const EARTHQUAKE_ANIM_START: float = 11.0 / 30.0
const EARTHQUAKE_CAST_LOCK: float = 0.9
const EARTHQUAKE_RADIUS: float = 5.1
const EARTHQUAKE_EFFECT_PATH: String = "res://scenes/effects/EarthquakeEffect.gd"
const EARTHQUAKE_EFFECT_HEIGHT: float = 0.1
const ARC_SLASH_PATH: String = "res://scenes/effects/ArcSlash.gd"
const SHIELD_DOME_PATH: String = "res://scenes/effects/ShieldDome.gd"
const DASH_STAMINA_COST: float = 20.0

# Exponential approach rates for the king's horizontal velocity, in units of 1/second.
# These are movement feel and are intentionally left at the original tuned values.
const MOVE_ACCEL: float = 10.0
const STOP_DECEL: float = 6.0
const DASH_COOLDOWN: float = 0.25
const DASH_DURATION: float = 0.3
const DASH_DAMAGE_RADIUS: float = 2.4
const DASH_HIT_LATERAL: float = 1.2
const DASH_TRAIL_PATH: String = "res://scenes/effects/DashTrail.gd"
const BERSERK_DRAIN_INTERVAL: float = 0.5
const BERSERK_MIN_MP: float = 1.0
const BERSERK_CAST_LOCK: float = 0.5
const BERSERK_AURA_PATH: String = "res://scenes/effects/BerserkAura.gd"
const BERSERK_AURA_HEIGHT: float = 1.0
const BERSERK_AURA_DELAY: float = 0.4
const BERSERK_AURA_FADE: float = 0.15
const BERSERK_LOW_MP_RATIO: float = 0.1

var berserk_active: bool = false
var _base_attack: float = 25.0
var _base_defense: float = 0.0
var _berserk_drain_timer: float = 0.0
var _berserk_aura_timer: float = 0.0
var _berserk_aura: Node3D = null
# The character's body height is driven by the Hips bone, not by this node's
# transform, so the aura needs the bone's vertical displacement to stay glued on.
var _hips_skeleton: Skeleton3D = null
var _hips_bone: int = -1
var _berserk_aura_height_ref: float = 0.0
var _current_anim: String = ""

# Hoisted out of _play_king_animation. That function runs from _handle_movement every
# frame, and building this Dictionary per call meant allocating and discarding 9 entries
# 60 times a second purely to look up a name that never changes.
const _ANIM_MAP := {
	"idle": "king/idle",
	"fly": "king/fly",
	"walk": "king/dash",
	"dash": "king/dash",
	"attack": "king/attack_1",
	"attack_1": "king/attack_1",
	"attack_2": "king/attack_2",
	"attack_3": "king/attack_3",
	"earth_quake": "king/earth_quake",
	"berserk": "king/berserk",
}


func set_movement_dir(dir: Vector2) -> void:
	dpad_dir = dir


func setup_king(stats: Dictionary) -> void:
	king_hp = stats.get("hp", 300)
	king_max_hp = king_hp
	king_attack = stats.get("attack", 25)
	king_defense = stats.get("defense", 0.0)
	_base_attack = king_attack
	_base_defense = king_defense
	king_speed_full = ProgressionData.king_speed()
	king_attack_cooldown = ProgressionData.king_attack_cooldown()
	king_special_cooldown = ProgressionData.king_special_cooldown()
	# No level-blind fallback: a missing key used to fall back to a hardcoded pool and
	# silently pin the king to level-1 values. Clamp to the level-1 pool instead, which
	# is the same number but cannot be mistaken for a scaled maximum.
	stamina_max = maxf(stats.get("stamina_max", 0.0), 0.0)
	if stamina_max <= 0.0:
		stamina_max = ProgressionData.king_stamina_max()
	stamina = stamina_max
	mana_max = maxf(stats.get("mana_max", 0.0), 0.0)
	if mana_max <= 0.0:
		mana_max = ProgressionData.king_mana_max()
	mana = mana_max
	mana_changed.emit(mana, mana_max)
	stamina_changed.emit(stamina, stamina_max)


# Re-apply the king's stats after a level-up without rebuilding the node. HP tops up to
# the new maximum for the amount gained, and the pools refill, so a level gained mid-run
# reads as a real gain rather than arriving on the next run.
func apply_level_up(stats: Dictionary) -> void:
	var new_max_hp: float = stats.get("hp", king_max_hp)
	if new_max_hp > king_max_hp:
		king_hp += new_max_hp - king_max_hp
	king_max_hp = new_max_hp
	_base_attack = stats.get("attack", _base_attack)
	_base_defense = stats.get("defense", _base_defense)
	stamina_max = maxf(stats.get("stamina_max", stamina_max), stamina_max)
	stamina = stamina_max
	mana_max = maxf(stats.get("mana_max", mana_max), mana_max)
	mana = mana_max
	hp_changed.emit(king_hp, king_max_hp)
	stamina_changed.emit(stamina, stamina_max)
	mana_changed.emit(mana, mana_max)


func _process(_delta: float) -> void:
	# The skeleton pose is evaluated on idle frames, so the aura follows on the same
	# cadence; syncing from _physics_process lagged the peak of the quake slam.
	_sync_berserk_aura_height()


func _physics_process(delta: float) -> void:
	_tick_berserk_aura_delay(delta)
	if frozen:
		return
	if _cast_lock > 0.0:
		_cast_lock -= delta
	_handle_movement(delta)
	_handle_attack(delta)
	_tick_berserk_drain(delta)
	var pct := get_stamina_percent()
	if not is_equal_approx(pct, _last_stamina_percent):
		stamina_changed.emit(stamina, stamina_max)
		_last_stamina_percent = pct

	if _moving:
		_anim_time += delta * 8.0
	else:
		_anim_time = 0.0

	if _attack_anim > 0:
		_attack_anim -= delta

	_update_punch_ring(delta)

	_update_pendopo_healing(delta)


func _heal_targets() -> Array[Vector3]:
	if not pendopo_positions.is_empty():
		return pendopo_positions
	return [pendopo_pos]


func _update_pendopo_healing(delta: float) -> void:
	var healing := false
	var targets := _heal_targets()
	if king_hp < king_max_hp:
		for i in targets.size():
			var target: Vector3 = targets[i]
			var dist_x := absf(position.x - target.x)
			var dist_z := absf(position.z - target.z)
			if dist_x <= PENDOPO_HEAL_RADIUS and dist_z <= PENDOPO_HEAL_RADIUS:
				var heal_rate := PENDOPO_HEAL_RATE
				if i < pendopo_heal_rates.size():
					heal_rate = pendopo_heal_rates[i]
				king_hp = minf(king_hp + heal_rate * delta, king_max_hp)
				hp_changed.emit(king_hp, king_max_hp)
				healing = true
				break
	if healing != _was_healing:
		_was_healing = healing
		healing_active = healing
		healing_changed.emit(healing)
		if healing:
			SFXManager.play_heal_pendopo()


func _handle_movement(delta: float) -> void:
	if _cast_lock > 0.0:
		return
	if _dash_timer > 0.0:
		_dash_timer -= delta
		position += _dash_dir * _dash_speed * delta
		_dash_strike_enemies()
		if _dash_timer <= 0.0:
			_end_dash_shield()
		return

	if dpad_dir.length() > 0:
		_move_dir = dpad_dir
		_moving = true
	else:
		_move_dir = Vector2.ZERO
		_moving = false

	var accel := MOVE_ACCEL if _moving else STOP_DECEL
	_velocity = _velocity.lerp(_move_dir, accel * delta)
	if _moving:
		if _attack_anim <= 0:
			_play_king_animation("fly")
	else:
		if _attack_anim <= 0:
			_play_king_animation("idle")

	stamina = minf(stamina_max, stamina + ProgressionData.king_stamina_regen() * delta)

	if _attack_anim <= 0:
		var direction := Vector3(_velocity.x, 0, _velocity.y)
		position += direction * king_speed_full * delta

	if _velocity.length() > 0.1:
		var target_yaw: float = atan2(_velocity.x, _velocity.y)
		_facing = target_yaw
		_model.rotation.y = lerp_angle(_model.rotation.y, target_yaw, 10.0 * delta)


func request_dash() -> void:
	if frozen:
		return
	if _cast_lock > 0.0:
		return
	if _dash_timer > 0.0 or _dash_cooldown_timer > 0.0:
		return
	if not berserk_active:
		if stamina < DASH_STAMINA_COST:
			return
		stamina -= DASH_STAMINA_COST
		stamina_changed.emit(stamina, stamina_max)
	_dash_cooldown_timer = DASH_COOLDOWN
	_dash_dir = Vector3(sin(_facing), 0.0, cos(_facing))
	_dash_speed = king_speed_full * SkillData.dash_speed_mult(SaveManager.get_skill_level("dash"))
	_dash_hits.clear()
	_dash_timer = DASH_DURATION
	_play_king_animation("dash", true)
	SFXManager.play_dash()
	_spawn_dash_trail()
	_spawn_dash_shield()


func _spawn_dash_trail() -> void:
	var script: GDScript = load(DASH_TRAIL_PATH)
	if script == null:
		return
	var trail: Node3D = script.new()
	trail.name = "DashTrail"
	trail.set("facing", _facing)
	add_child(trail)


func _spawn_dash_shield() -> void:
	if SaveManager.get_skill_level("dash") <= 3:
		return
	var script: GDScript = load(SHIELD_DOME_PATH)
	if script == null:
		return
	var shield: Node3D = script.new()
	shield.name = "DashShield"
	var fwd := Vector3(sin(_facing), 0.0, cos(_facing))
	shield.position = fwd * DASH_SHIELD_FORWARD + Vector3(0, DASH_SHIELD_HEIGHT, 0)
	shield.rotation.y = _facing
	_dash_shield = shield
	add_child(shield)


func _end_dash_shield() -> void:
	if _dash_shield != null and is_instance_valid(_dash_shield):
		_dash_shield.call("fade_out")
	_dash_shield = null


func _dash_strike_enemies() -> void:
	var hit_any := false
	for enemy in SpatialIndex.get_nearby(global_position, DASH_DAMAGE_RADIUS, "enemies"):
		if not is_instance_valid(enemy):
			continue
		var enemy_id: int = enemy.get_instance_id()
		if _dash_hits.has(enemy_id):
			continue
		if enemy.has_method("is_alive") and not enemy.is_alive():
			continue
		if not _is_within_dash_band(enemy.global_position):
			continue
		if enemy.has_method("take_damage"):
			enemy.take_damage(king_attack * SkillData.dash_damage_mult(SaveManager.get_skill_level("dash")))
			_dash_hits[enemy_id] = true
			hit_any = true
	if hit_any:
		SFXManager.play_king_hit()


func _is_within_dash_band(target_pos: Vector3) -> bool:
	var to_target := target_pos - global_position
	var forward_dist: float = to_target.dot(_dash_dir)
	if forward_dist < -0.8:
		return false
	var right := Vector3(cos(_facing), 0.0, -sin(_facing))
	var lateral_dist: float = absf(to_target.dot(right))
	return lateral_dist <= DASH_HIT_LATERAL


func request_attack() -> void:
	if _cast_lock > 0.0:
		return
	if _attack_timer <= 0:
		attack()
		_attack_timer = king_attack_cooldown


func request_berserk() -> void:
	if berserk_active:
		set_berserk(false)
		return
	if frozen or mana < BERSERK_MIN_MP:
		return
	set_berserk(true)


func set_berserk(active: bool) -> void:
	if active == berserk_active:
		return
	berserk_active = active
	if active:
		_berserk_drain_timer = 0.0
		_berserk_aura_timer = BERSERK_AURA_DELAY
		var berserk_level: int = SaveManager.get_skill_level("berserk")
		king_attack = _base_attack * SkillData.berserk_attack_mult(berserk_level)
		king_defense = _base_defense * SkillData.berserk_defense_mult(berserk_level)
		_attack_anim = BERSERK_CAST_LOCK
		_cast_lock = BERSERK_CAST_LOCK
		_play_king_animation("berserk", true)
	else:
		king_attack = _base_attack
		king_defense = _base_defense
		_berserk_drain_timer = 0.0
		_berserk_aura_timer = 0.0
		_fade_berserk_aura()
		SFXManager.stop_berserk_loop()
	berserk_changed.emit(active)


func is_berserk_low_mana() -> bool:
	return berserk_active and mana < mana_max * BERSERK_LOW_MP_RATIO


func _tick_berserk_drain(delta: float) -> void:
	if not berserk_active:
		return
	_berserk_drain_timer += delta
	if _berserk_drain_timer < BERSERK_DRAIN_INTERVAL:
		_set_berserk_blink()
		return
	_berserk_drain_timer -= BERSERK_DRAIN_INTERVAL
	var drain: float = SkillData.berserk_drain_per_sec(SaveManager.get_skill_level("berserk")) * BERSERK_DRAIN_INTERVAL
	mana = maxf(0.0, mana - drain)
	mana_changed.emit(mana, mana_max)
	if mana <= 0.0:
		set_berserk(false)
		return
	_set_berserk_blink()


func _set_berserk_blink() -> void:
	if _berserk_aura == null or not is_instance_valid(_berserk_aura):
		return
	if not _berserk_aura.has_method("set_blinking"):
		return
	_berserk_aura.set_blinking(is_berserk_low_mana())


func _tick_berserk_aura_delay(delta: float) -> void:
	if not berserk_active or _berserk_aura_timer <= 0.0:
		return
	_berserk_aura_timer -= delta
	if _berserk_aura_timer <= 0.0:
		_spawn_berserk_aura()
		SFXManager.start_berserk_loop()
		_set_berserk_blink()


func _spawn_berserk_aura() -> void:
	_remove_berserk_aura()
	var script: GDScript = load(BERSERK_AURA_PATH)
	if script == null:
		return
	_cache_hips_bone()
	_berserk_aura = script.new()
	_berserk_aura.name = "BerserkAura"
	_berserk_aura.use_blue = SaveManager.get_skill_level("berserk") >= 4
	_berserk_aura.position = Vector3(0, BERSERK_AURA_HEIGHT, 0)
	# Anchor the aura to the pose the character is standing in right now, so
	# BERSERK_AURA_HEIGHT keeps meaning "height above the standing character".
	_berserk_aura_height_ref = _hips_world_y()
	add_child(_berserk_aura)
	_sync_berserk_aura_height()


func _cache_hips_bone() -> void:
	_hips_skeleton = null
	_hips_bone = -1
	if _model == null or not is_instance_valid(_model):
		return
	_hips_skeleton = _model.find_child("Skeleton3D", true, false) as Skeleton3D
	if _hips_skeleton == null:
		return
	_hips_bone = _hips_skeleton.find_bone("Hips")


func _hips_world_y() -> float:
	if _hips_skeleton == null or not is_instance_valid(_hips_skeleton) or _hips_bone < 0:
		return 0.0
	var pose: Transform3D = _hips_skeleton.get_bone_global_pose(_hips_bone)
	return (_hips_skeleton.global_transform * pose).origin.y


func _sync_berserk_aura_height() -> void:
	if _berserk_aura == null or not is_instance_valid(_berserk_aura):
		return
	# No skeleton means no way to know how tall the character currently is, so hold
	# the authored height rather than snapping the aura somewhere arbitrary.
	var offset: float = 0.0
	if _hips_skeleton != null and is_instance_valid(_hips_skeleton) and _hips_bone >= 0:
		offset = _hips_world_y() - _berserk_aura_height_ref
	_berserk_aura.position.y = BERSERK_AURA_HEIGHT + offset


func _fade_berserk_aura() -> void:
	if _berserk_aura == null or not is_instance_valid(_berserk_aura):
		_berserk_aura = null
		return
	if _berserk_aura.has_method("fade_out"):
		# The reference is kept while fading so _spawn_berserk_aura can still
		# hard-clear this node if berserk is re-activated mid-fade.
		_berserk_aura.fade_out(BERSERK_AURA_FADE)
		return
	_remove_berserk_aura()


func _remove_berserk_aura() -> void:
	if _berserk_aura != null and is_instance_valid(_berserk_aura):
		_berserk_aura.queue_free()
	_berserk_aura = null


func request_earthquake() -> void:
	if _special_timer > 0.0:
		return
	if not spend_mana(SkillData.quake_mp_cost(SaveManager.get_skill_level("earthquake"))):
		return
	_special_timer = king_special_cooldown
	cast_earthquake()


func cast_earthquake() -> void:
	_attack_anim = 0.5
	_cast_lock = EARTHQUAKE_CAST_LOCK
	_play_king_animation("earth_quake", true)
	if _anim_player:
		_anim_player.seek(EARTHQUAKE_ANIM_START, true)
	SFXManager.play_earth_quake_skill()
	_spawn_earthquake_effect()
	var king_tile := _world_to_tile(global_position)
	for enemy in SpatialIndex.get_nearby(global_position, EARTHQUAKE_RADIUS, "enemies"):
		if not is_instance_valid(enemy):
			continue
		if not enemy.has_method("take_damage"):
			continue
		var enemy_tile := _world_to_tile(enemy.global_position)
		if absi(enemy_tile.x - king_tile.x) <= EARTHQUAKE_GRID_HALF and absi(enemy_tile.y - king_tile.y) <= EARTHQUAKE_GRID_HALF:
			enemy.take_damage(king_attack * SkillData.quake_damage_mult(SaveManager.get_skill_level("earthquake")))


func _world_to_tile(pos: Vector3) -> Vector2i:
	return Vector2i(floori(pos.x + _center_offset), floori(pos.z + _center_offset))


func get_earthquake_cooldown_fraction() -> float:
	return maxf(_special_timer, 0.0) / maxf(king_special_cooldown, 1.0)


func set_play_field(map_size: int) -> void:
	_map_size = map_size
	_center_offset = map_size * 0.5


func _spawn_earthquake_effect() -> void:
	var script: GDScript = load(EARTHQUAKE_EFFECT_PATH)
	if script == null:
		return
	var effect: Node3D = script.new()
	effect.name = "EarthquakeEffect"
	if SaveManager.get_skill_level("earthquake") > 3:
		effect.set("enhanced", true)
	effect.position = Vector3(0, EARTHQUAKE_EFFECT_HEIGHT, 0)
	add_child(effect)


func _spawn_arc_slash(mirror: bool) -> void:
	var script: GDScript = load(ARC_SLASH_PATH)
	if script == null:
		return
	var slash: Node3D = script.new()
	slash.name = "ArcSlash"
	slash.set("mirror", mirror)
	var fwd := Vector3(sin(_facing), 0.0, cos(_facing))
	slash.position = fwd * PUNCH_RING_FORWARD + Vector3(0, PUNCH_RING_HEIGHT, 0)
	slash.rotation.y = _facing
	add_child(slash)


func _handle_attack(delta: float) -> void:
	_attack_timer -= delta
	_special_timer -= delta
	if _dash_cooldown_timer > 0.0:
		_dash_cooldown_timer -= delta
	if _combo_reset_timer > 0.0:
		_combo_reset_timer -= delta
		if _combo_reset_timer <= 0.0:
			_combo_step = 0


const ATTACK_HALF_WIDTH: float = 1.5


func _is_in_attack_cone(target_pos: Vector3) -> bool:
	var to_target := target_pos - global_position
	var fwd := Vector3(sin(_facing), 0.0, cos(_facing))
	var right := Vector3(cos(_facing), 0.0, -sin(_facing))
	var forward_dist: float = to_target.dot(fwd)
	if forward_dist < 0.0:
		return false
	var lateral_dist: float = absf(to_target.dot(right))
	return lateral_dist <= ATTACK_HALF_WIDTH


const CONE_RADIUS: float = 3.0
const CONE_WIDTH: float = 1.5


func _ensure_punch_ring() -> void:
	if _punch_ring != null:
		return
	_punch_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = PUNCH_RING_RADIUS * 0.9
	torus.outer_radius = PUNCH_RING_RADIUS
	torus.rings = 32
	torus.ring_segments = 12
	_punch_ring.mesh = torus
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(PUNCH_RING_COLOR.r, PUNCH_RING_COLOR.g, PUNCH_RING_COLOR.b, 0.0)
	mat.emission_enabled = true
	mat.emission = Color(PUNCH_RING_COLOR.r, PUNCH_RING_COLOR.g, PUNCH_RING_COLOR.b)
	_punch_ring.material_override = mat
	_punch_ring.visible = false
	add_child(_punch_ring)


func _update_punch_ring(delta: float) -> void:
	if _punch_ring == null:
		return
	if _ring_delay > 0.0:
		_ring_delay -= delta
		return
	if _ring_timer > 0.0:
		_ring_timer -= delta
		var t := clampf(1.0 - _ring_timer / PUNCH_RING_DURATION, 0.0, 1.0)
		_punch_ring.scale = Vector3.ONE * lerpf(0.2, 1.0, t)
		_punch_ring.visible = t < 1.0
		var mat := _punch_ring.material_override as StandardMaterial3D
		mat.albedo_color.a = 1.0 - t
	else:
		_punch_ring.visible = false


func attack() -> void:
	var step := _combo_step
	_attack_anim = 0.4
	_play_king_animation(COMBO_ANIMS[step], true)
	_combo_step = (_combo_step + 1) % COMBO_ANIMS.size()
	_combo_reset_timer = COMBO_WINDOW
	if step == 2:
		_ensure_punch_ring()
		if _punch_ring:
			var fwd := Vector3(sin(_facing), 0.0, cos(_facing))
			_punch_ring.position = fwd * PUNCH_RING_FORWARD + Vector3(0, PUNCH_RING_HEIGHT, 0)
			_punch_ring.rotation = Vector3(PI / 2.0, _facing, 0.0)
			_punch_ring.scale = Vector3.ONE * 0.2
			_punch_ring.visible = false
			_ring_delay = PUNCH_RING_DELAY
			_ring_timer = PUNCH_RING_DURATION
	else:
		_spawn_arc_slash(step == 0)
	var hit_any := false
	for enemy in SpatialIndex.get_nearby(global_position, CONE_RADIUS, "enemies"):
		if not is_instance_valid(enemy):
			continue
		if not _is_in_attack_cone(enemy.global_position):
			continue
		if enemy.has_method("is_alive") and not enemy.is_alive():
			continue
		if enemy.has_method("take_damage"):
			enemy.take_damage(king_attack)
			hit_any = true
	if hit_any:
		SFXManager.play_king_hit()
	else:
		SFXManager.play_king_swing()


func take_damage(amount: float) -> void:
	if amount > 0.0:
		IMPACT_SPARK.spawn(self)
	king_hp -= ProgressionData.armor_damage(amount, king_defense)
	hp_changed.emit(king_hp, king_max_hp)
	if king_hp <= 0:
		king_hp = 0
		king_died.emit()


func restore_stamina(percent: float) -> void:
	stamina = minf(stamina_max, stamina + stamina_max * percent)


func play_potion_aura(effect: String) -> void:
	_ensure_aura()
	if _aura != null and _aura.has_method("play"):
		_aura.play(effect)


func _ensure_aura() -> void:
	if _aura != null:
		return
	var aura_script: GDScript = load(KING_AURA_PATH)
	if aura_script == null:
		return
	_aura = aura_script.new()
	_aura.name = "KingAura"
	_aura.position = Vector3(0, KING_AURA_HEIGHT, 0)
	add_child(_aura)


func restore_hp(amount: float) -> void:
	king_hp = minf(king_max_hp, king_hp + amount)
	hp_changed.emit(king_hp, king_max_hp)


func restore_mana(amount: float) -> void:
	mana = minf(mana_max, mana + amount)
	mana_changed.emit(mana, mana_max)


func spend_mana(amount: float) -> bool:
	if mana < amount:
		return false
	mana -= amount
	mana_changed.emit(mana, mana_max)
	return true


func get_mana_percent() -> float:
	return mana / maxf(mana_max, 1.0)


func get_stamina_percent() -> float:
	return stamina / maxf(stamina_max, 1.0)


func _load_model() -> void:
	_model = ModelLoader.load_king()
	add_child(_model)

	_anim_player = ModelLoader.find_animation_player(_model)
	_play_king_animation("idle")


func _play_king_animation(anim_name: String, force: bool = false) -> void:
	if not _model or not _anim_player:
		return
	# Already playing this clip: return. Re-issuing play() for the current animation
	# restarts it, so calling this every frame fought the animation it was supposed to
	# hold, and the state has to be tracked to avoid that.
	# One-shot clips (earthquake, berserk, a repeated combo step) pass force to replay
	# from the top, which is what they did before this guard existed.
	if not force and anim_name == _current_anim:
		return

	var mapped_name: String = _ANIM_MAP.get(anim_name, anim_name)
	if not _anim_player.has_animation(mapped_name):
		return
	if not ModelLoader.play_rig_animation(_model, _anim_player, mapped_name):
		return
	_current_anim = anim_name


func _ready() -> void:
	add_to_group("king")
	_load_model()
	_ensure_punch_ring()
	_ensure_aura()
	hp_changed.emit(king_hp, king_max_hp)
