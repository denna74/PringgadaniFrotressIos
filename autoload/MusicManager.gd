extends Node

enum Track { MAIN_MENU, BUILD, BATTLE, VICTORY, DEFEAT }

const SETTINGS_FILE := "user://settings.cfg"
const MAX_LEVEL := 4

var player: AudioStreamPlayer
var current_track: Track = Track.BUILD
var bgm_level: int = MAX_LEVEL
var _tween: Tween = null
var _streams: Dictionary = {}

var _track_paths := {
	Track.MAIN_MENU: "res://assets/bgm/main_menu.mp3",
	Track.BUILD: "res://assets/bgm/build.mp3",
	Track.BATTLE: "res://assets/bgm/battle.mp3",
	Track.VICTORY: "res://assets/bgm/victory.mp3",
	Track.DEFEAT: "res://assets/bgm/failed.mp3",
}

var _looping := {
	Track.MAIN_MENU: true,
	Track.BUILD: true,
	Track.BATTLE: true,
	Track.VICTORY: true,
	Track.DEFEAT: true,
}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	player = AudioStreamPlayer.new()
	# Music must not duck or stop when a popup freezes the run.
	player.process_mode = PROCESS_MODE_ALWAYS
	player.bus = &"Music"
	add_child(player)
	load_bgm_setting()
	_apply_bgm_level()


## The volume slider rides on the Music bus, not the player, so the fade tween keeps
## owning player.volume_db and the level multiplies the result underneath it.
func _apply_bgm_level() -> void:
	var idx := AudioServer.get_bus_index("Music")
	if idx < 0:
		return
	AudioServer.set_bus_mute(idx, bgm_level <= 0)
	AudioServer.set_bus_volume_db(idx, linear_to_db(float(bgm_level) / float(MAX_LEVEL)))


func load_bgm_setting() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_FILE) == OK:
		bgm_level = clampi(config.get_value("settings", "bgm_level", MAX_LEVEL), 0, MAX_LEVEL)


func set_bgm_level(level: int) -> void:
	level = clampi(level, 0, MAX_LEVEL)
	if bgm_level == level:
		return
	bgm_level = level
	_apply_bgm_level()
	var config := ConfigFile.new()
	config.load(SETTINGS_FILE)
	config.set_value("settings", "bgm_level", bgm_level)
	config.save(SETTINGS_FILE)


func play_fade(track: Track, duration: float = 1.0) -> void:
	if track == current_track and player.playing:
		return
	_cancel_tween()
	current_track = track
	if player.playing:
		_fade_out_then_in(track, duration)
	else:
		_fade_in(track, duration)


func stop_fade(duration: float = 1.0) -> void:
	_cancel_tween()
	if not player.playing:
		return
	_tween = create_tween()
	_tween.tween_property(player, "volume_db", -40.0, duration)
	_tween.tween_callback(player.stop)


func play_once(track: Track, duration: float = 0.5) -> void:
	_cancel_tween()
	current_track = track
	_load_stream(track)
	player.volume_db = -40.0
	player.play()
	_tween = create_tween()
	_tween.tween_property(player, "volume_db", 0.0, duration)


func _fade_in(track: Track, duration: float) -> void:
	_load_stream(track)
	player.volume_db = -40.0
	player.play()
	_tween = create_tween()
	_tween.tween_property(player, "volume_db", 0.0, duration)


func _fade_out_then_in(track: Track, duration: float) -> void:
	_tween = create_tween()
	_tween.tween_property(player, "volume_db", -40.0, duration * 0.5)
	_tween.tween_callback(func() -> void:
		_load_stream(track)
		player.volume_db = -40.0
		player.play()
		_tween = create_tween()
		_tween.tween_property(player, "volume_db", 0.0, duration * 0.5)
	)


func preload_all() -> void:
	for track in _track_paths:
		_get_stream(track)


func _load_stream(track: Track) -> void:
	var stream: AudioStream = _get_stream(track)
	if stream:
		player.stream = stream
		if stream is AudioStreamMP3:
			stream.loop = _looping.get(track, false)


func _get_stream(track: Track) -> AudioStream:
	if _streams.has(track):
		return _streams[track] as AudioStream
	var path: String = _track_paths.get(track, "")
	if path.is_empty():
		return null
	var stream: AudioStream = ResourceLoader.load(path) as AudioStream
	if stream:
		_streams[track] = stream
	return stream


func _cancel_tween() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
		_tween = null
