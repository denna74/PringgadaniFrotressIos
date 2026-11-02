extends Node


const SELECT_1 := preload("res://assets/sfx/select_1.mp3")
const SELECT_3 := preload("res://assets/sfx/select_3.mp3")
const SELECT_4 := preload("res://assets/sfx/select_4.mp3")
const START := preload("res://assets/sfx/start.mp3")

var player: AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	player = AudioStreamPlayer.new()
	player.bus = &"SFX"
	add_child(player)


func play_select_1() -> void:
	_play(SELECT_1)


func play_select_3() -> void:
	_play(SELECT_3)


func play_select_4() -> void:
	_play(SELECT_4)


func play_start() -> void:
	_play(START)


func play() -> void:
	play_select_3()


func _play(stream: AudioStream) -> void:
	player.stop()
	player.stream = stream
	player.play()