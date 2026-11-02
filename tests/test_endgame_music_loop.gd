extends SceneTree

var failures := 0


func _initialize() -> void:
	_run()


func _check(name: String, condition: bool) -> void:
	if condition:
		print("OK  ", name)
	else:
		push_error("FAIL " + name)
		failures += 1


func _run() -> void:
	await process_frame
	var music: Node = root.get_node("/root/MusicManager")
	for track in [music.Track.VICTORY, music.Track.DEFEAT]:
		music._load_stream(track)
		var stream: AudioStream = music.player.stream
		_check("end-game track loops", stream is AudioStreamMP3 and stream.loop)

	if failures > 0:
		quit(1)
		return
	print("ENDGAME_MUSIC_LOOP_PASS")
	quit(0)
