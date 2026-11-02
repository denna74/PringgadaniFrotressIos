extends Control

@onready var _splash_image := $SplashImage

func _ready():
	_splash_image.modulate = Color(1, 1, 1, 0)

	var tween = create_tween()
	tween.tween_property(_splash_image, "modulate:a", 1.0, 0.4)
	tween.tween_interval(1.0)
	tween.tween_property(_splash_image, "modulate:a", 0.0, 0.4)
	tween.tween_callback(_finish)

func _finish():
	SceneManager.go_to_scene("res://scenes/menu/MainMenu.tscn")
