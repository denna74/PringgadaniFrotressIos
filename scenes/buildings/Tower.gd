extends Building

var attack_damage: float = 0.0
var attack_range: float = 0.0
var _attack_timer: float = 0.0
var _attack_cooldown: float = 1.0
var _target: Node3D = null
var _find_timer: float = 0.0

const TARGET_REFRESH_INTERVAL := 0.5


func _init(data: Dictionary, plot_ref: Area3D) -> void:
	super._init(data, plot_ref)


func can_open_overlay() -> bool:
	return false


func _ready() -> void:
	super._ready()
	_update_stats()


func _process(delta: float) -> void:
	super._process(delta)
	_find_timer -= delta
	var target_present := (
		_target != null and is_instance_valid(_target) and _target.is_inside_tree()
	)
	var should_find := _find_timer <= 0.0
	if target_present:
		should_find = should_find or not _is_valid_target(_target)
	if should_find:
		_find_target()
		_find_timer = TARGET_REFRESH_INTERVAL
	if _is_valid_target(_target):
		_attack_timer -= delta
		if _attack_timer <= 0:
			_attack()
			_attack_timer = _attack_cooldown


func _update_stats() -> void:
	attack_damage = ProgressionData.tower_damage(level)
	attack_range = ProgressionData.tower_range(level)


func _is_valid_target(target: Node3D) -> bool:
	if target == null or not is_instance_valid(target):
		return false
	if not target.is_inside_tree():
		return false
	if target.is_queued_for_deletion():
		return false
	if target.has_method("is_alive") and not target.is_alive():
		return false
	if global_position.distance_to(target.global_position) > attack_range + 0.01:
		return false
	return true


func _find_target() -> void:
	var enemies := SpatialIndex.get_nearby(global_position, attack_range, "enemies")
	var closest: Node3D = null
	var closest_dist := attack_range + 0.001
	for enemy in enemies:
		if not _is_valid_target(enemy):
			continue
		var dist := global_position.distance_to(enemy.global_position)
		if dist < closest_dist:
			closest = enemy
			closest_dist = dist
	_target = closest


func _attack() -> void:
	if not _is_valid_target(_target):
		_find_target()
		if not _is_valid_target(_target):
			return
	SFXManager.play_arrow_shot(global_position)
	var arrow := preload("res://scenes/projectiles/arrow_projectile.gd").acquire()
	var dir_h := (_target.global_position - global_position)
	dir_h.y = 0
	dir_h = dir_h.normalized()
	var window_pos := global_position + Vector3(0, 3, 0) + dir_h * 0.35
	arrow.setup(_target, window_pos, attack_damage)
	get_parent().add_child(arrow)
