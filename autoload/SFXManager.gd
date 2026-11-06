extends Node

const POOL_SIZE := 8
const FOOTSTEP_INTERVAL := 0.4
const MAX_SFX_DISTANCE := 60.0
const HIT_DELAY := 0.1

const SETTINGS_FILE := "user://settings.cfg"
const MAX_LEVEL := 4

var sfx_level: int = MAX_LEVEL

var _players: Array[AudioStreamPlayer] = []
var _streams: Dictionary = {}
var _berserk_player: AudioStreamPlayer = null
var _berserk_loop_wanted: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = &"SFX"
		add_child(p)
		_players.append(p)
	_berserk_player = AudioStreamPlayer.new()
	_berserk_player.name = "BerserkLoopPlayer"
	_berserk_player.bus = &"SFX"
	_berserk_player.finished.connect(_on_berserk_loop_finished)
	add_child(_berserk_player)
	load_sfx_setting()
	_apply_sfx_level()
	_streams["footstep_1"] = load("res://assets/sfx/footstep_1.mp3")
	_streams["footstep_2"] = load("res://assets/sfx/footstep_2.mp3")
	_streams["sword"] = load("res://assets/sfx/sword.mp3")
	_streams["sword_building_hit"] = load("res://assets/sfx/sword_building_hit.mp3")
	_streams["sword_user_hit"] = load("res://assets/sfx/sword_user_hit.mp3")
	_streams["punch"] = load("res://assets/sfx/punch.mp3")
	_streams["punch_impact"] = load("res://assets/sfx/punch_impact.mp3")
	_streams["arrow_shot"] = load("res://assets/sfx/arrow_shot.mp3")
	_streams["power_attack"] = load("res://assets/sfx/power_attack.mp3")
	_streams["earth_quack"] = load("res://assets/sfx/earth_quack.mp3")
	_streams["heal_pendopo"] = load("res://assets/sfx/heal_pendopo.mp3")
	_streams["potion"] = load("res://assets/sfx/potion.mp3")
	_streams["earth_quake_skill"] = load("res://assets/sfx/earth_quake_skill.mp3")
	_streams["dash"] = load("res://assets/sfx/dash.mp3")
	_streams["berserk"] = load("res://assets/sfx/balm_effect.wav")


## Every pooled player sits on the SFX bus, so one slider scales all gameplay audio at
## once. Muting at zero keeps the players running, only silent.
func _apply_sfx_level() -> void:
	var idx := AudioServer.get_bus_index("SFX")
	if idx < 0:
		return
	AudioServer.set_bus_mute(idx, sfx_level <= 0)
	AudioServer.set_bus_volume_db(idx, linear_to_db(float(sfx_level) / float(MAX_LEVEL)))


func load_sfx_setting() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_FILE) == OK:
		sfx_level = clampi(config.get_value("settings", "sfx_level", MAX_LEVEL), 0, MAX_LEVEL)


func set_sfx_level(level: int) -> void:
	level = clampi(level, 0, MAX_LEVEL)
	if sfx_level == level:
		return
	sfx_level = level
	_apply_sfx_level()
	var config := ConfigFile.new()
	config.load(SETTINGS_FILE)
	config.set_value("settings", "sfx_level", sfx_level)
	config.save(SETTINGS_FILE)


func play_footstep(enemy: Node3D, delta: float) -> void:
	var timer: float = enemy.get_meta("footstep_timer", 0.0)
	var index: int = enemy.get_meta("footstep_index", 0)
	timer += delta
	if timer < FOOTSTEP_INTERVAL:
		enemy.set_meta("footstep_timer", timer)
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		enemy.set_meta("footstep_timer", timer)
		return
	var dist := cam.global_position.distance_to(enemy.position)
	if dist > MAX_SFX_DISTANCE:
		enemy.set_meta("footstep_timer", timer)
		return
	enemy.set_meta("footstep_timer", 0.0)
	index = 1 - index
	enemy.set_meta("footstep_index", index)
	var key := "footstep_1" if index == 0 else "footstep_2"
	_play_with_volume(key, _footstep_volume(dist))


func play_enemy_swing(pos: Vector3) -> void:
	_play_positional("sword", pos)


func play_enemy_hit(type: String, pos: Vector3) -> void:
	var key := "sword_building_hit" if type == "building" else "sword_user_hit"
	await get_tree().create_timer(HIT_DELAY).timeout
	_play_positional(key, pos)


func play_king_swing() -> void:
	_play("punch")


func play_arrow_shot(pos: Vector3) -> void:
	_play_positional("arrow_shot", pos, 10.0)


func play_power_attack(pos: Vector3) -> void:
	_play_positional("power_attack", pos)


func play_build_quake() -> void:
	_play("earth_quack")


func play_king_hit() -> void:
	_play("punch_impact")


func play_earth_quake_skill() -> void:
	_play("earth_quake_skill")


func play_heal_pendopo() -> void:
	_play("heal_pendopo")


# A fort coming down: the stone-impact hit layered over the ground rumble. There is no
# dedicated explosion asset, so these are the two closest sounds already in the bank.
func play_pendopo_destroyed() -> void:
	_play("earth_quack")
	_play("sword_building_hit")


func play_potion() -> void:
	_play("potion")


func play_dash() -> void:
	_play("dash")


func start_berserk_loop() -> void:
	_berserk_loop_wanted = true
	if _berserk_player == null:
		return
	var stream: AudioStream = _streams.get("berserk")
	if stream == null:
		return
	if _berserk_player.playing:
		return
	_berserk_player.stream = stream
	_berserk_player.play()


func stop_berserk_loop() -> void:
	_berserk_loop_wanted = false
	if _berserk_player == null:
		return
	_berserk_player.stop()


func is_berserk_loop_playing() -> bool:
	return _berserk_player != null and _berserk_player.playing


func _on_berserk_loop_finished() -> void:
	if not _berserk_loop_wanted:
		return
	if _berserk_player != null and _berserk_player.stream != null:
		_berserk_player.play()


func _play_positional(key: String, pos: Vector3, volume_offset: float = 0.0) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var dist := cam.global_position.distance_to(pos)
	var volume := _distance_volume(dist) + volume_offset
	_play_with_volume(key, volume)


func _play(key: String) -> void:
	_play_with_volume(key, 0.0)


func _play_with_volume(key: String, volume_db: float) -> void:
	var stream: AudioStream = _streams.get(key)
	if stream == null:
		return
	var player := _get_free_player()
	player.stream = stream
	player.volume_db = volume_db
	player.play()


func _get_free_player() -> AudioStreamPlayer:
	for p in _players:
		if not p.playing:
			return p
	return _players[0]


func _distance_volume(dist: float) -> float:
	var t := clampf(dist / MAX_SFX_DISTANCE, 0.0, 1.0)
	return lerpf(0.0, -30.0, t)


func _footstep_volume(dist: float) -> float:
	var t := clampf(dist / MAX_SFX_DISTANCE, 0.0, 1.0)
	return lerpf(0.0, -10.0, t)
