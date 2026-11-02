extends Control

const STORY_SCENE_PATH := "res://scenes/menu/StoryPage.tscn"

@export var background_rect := Rect2(Vector2.ZERO, Vector2(1280, 720))

var _story_btn: Button
var _play_btn: Button
var _exit_btn: Button
var _settings_btn: Button
var _settings_popup: Control
var _bg_rect: TextureRect


func _ready() -> void:
	_setup_background()
	_setup_logo()
	_setup_buttons()
	_setup_exit_button()
	MusicManager.play_fade(MusicManager.Track.MAIN_MENU, 1.0)


func _setup_background() -> void:
	var stream := VideoStreamTheora.new()
	stream.file = "res://assets/bg/background.ogv"

	var player := VideoStreamPlayer.new()
	player.stream = stream
	player.autoplay = true
	player.loop = true
	player.expand = true
	# The player's frame texture is shown by _bg_rect; leaving the player visible too
	# would draw the same full-screen video a second time every frame.
	player.visible = false
	player.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(player)

	_bg_rect = TextureRect.new()
	_bg_rect.texture = player.get_video_texture()
	# The clip is 832x448; without an expand/stretch mode the TextureRect draws it at
	# its native size in the corner instead of filling the 1280x720 screen.
	_bg_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bg_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_bg_rect.position = background_rect.position
	_bg_rect.size = background_rect.size
	add_child(_bg_rect)
	move_child(_bg_rect, 0)


func _setup_logo() -> void:
	var logo := TextureRect.new()
	logo.texture = load("res://assets/pringgadani_fortress_logo.png")
	logo.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.anchors_preset = Control.PRESET_CENTER_TOP
	logo.anchor_left = 0.5
	logo.anchor_right = 0.5
	logo.offset_left = -180
	logo.offset_right = 180
	logo.offset_top = 110
	logo.offset_bottom = 490
	add_child(logo)


func _setup_buttons() -> void:
	var hbox := HBoxContainer.new()
	var font_size = 42
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 50)
	hbox.anchors_preset = Control.PRESET_CENTER_BOTTOM
	hbox.anchor_left = 0.5
	hbox.anchor_right = 0.5
	hbox.anchor_top = 1.0
	hbox.anchor_bottom = 1.0
	hbox.offset_left = -460
	hbox.offset_right = 300
	hbox.offset_top = -200
	hbox.offset_bottom = -100
	add_child(hbox)

	
	_story_btn = _create_button(
		TranslationManager.t("story"), Color(0.2, 0.4, 0.8), load("res://assets/buttons/main_btn_story.png"))
	_story_btn.pressed.connect(_on_story_pressed)
	_story_btn.add_theme_font_size_override("font_size", font_size)
	hbox.add_child(_story_btn)

	_play_btn = _create_button(TranslationManager.t("play"), Color(0.126, 0.423, 0.19, 1.0), load("res://assets/buttons/main_btn_play.png"))
	_play_btn.pressed.connect(_on_play_pressed)
	_play_btn.add_theme_font_size_override("font_size", font_size)
	hbox.add_child(_play_btn)
	_start_breathing(_play_btn)

	_settings_btn = _create_button(TranslationManager.t("settings"), Color.DARK_MAGENTA, load("res://assets/buttons/main_btn_settings.png"))
	_settings_btn.pressed.connect(_on_settings_pressed)
	_settings_btn.add_theme_font_size_override("font_size", font_size)
	hbox.add_child(_settings_btn)

	TranslationManager.language_changed.connect(_on_language_changed)


func _start_breathing(btn: Button) -> void:
	btn.pivot_offset = btn.custom_minimum_size / 2
	btn.resized.connect(func() -> void: btn.pivot_offset = btn.size / 2)
	var tween := create_tween().set_loops()
	tween.tween_property(btn, "scale", Vector2(1.05, 1.05), 0.9) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(btn, "scale", Vector2.ONE, 0.9) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _setup_exit_button() -> void:
	_exit_btn = Button.new()
	_exit_btn.text = TranslationManager.t("exit")
	_exit_btn.position = Vector2(860, 30)
	_exit_btn.custom_minimum_size = Vector2(280, 76)
	_exit_btn.pressed.connect(_on_exit_pressed)
	_exit_btn.pressed.connect(ClickPlayer.play_select_1)

	var style := StyleBoxTexture.new()
	style.texture = load("res://assets/buttons/small_button.png")
	style.content_margin_left = 40
	_exit_btn.add_theme_stylebox_override("normal", style)
	_exit_btn.add_theme_stylebox_override("focus", style)

	var pressed_style := style.duplicate()
	pressed_style.modulate_color = Color(0.8, 0.8, 0.8)
	_exit_btn.add_theme_stylebox_override("pressed", pressed_style)

	_exit_btn.add_theme_font_size_override("font_size", 36)
	_exit_btn.add_theme_color_override("font_color", Color(0.8, 0.2, 0.35))
	ButtonBuilder.make_hover_inert(_exit_btn)
	_exit_btn.add_child(_build_gear_icon())
	add_child(_exit_btn)


## The gear rides inside the button as a child so the settings label stays centred, the
## same way the hub's section buttons carry an icon.
func _build_gear_icon() -> TextureRect:
	var icon := TextureRect.new()
	# expand_mode must be relaxed before the texture lands, otherwise the control
	# clamps its size up to the texture's 85px and later overrides can't shrink it.
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = load("res://assets/buttons/wood_door.png")
	icon.size = Vector2(56, 56)
	icon.position = Vector2(37, 7)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon


func _create_button(text: String, color: Color, texture: Resource) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(280, 130)
	btn.add_theme_font_size_override("font_size", 18)
	btn.add_theme_color_override("font_color", color)
	btn.add_theme_color_override("font_pressed_color", color.darkened(0.2))

	var style := StyleBoxTexture.new()
	style.texture = texture
	style.content_margin_top = 20
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("focus", style)

	var pressed_style := style.duplicate()
	pressed_style.modulate_color = Color(0.8, 0.8, 0.8)
	btn.add_theme_stylebox_override("pressed", pressed_style)

	ButtonBuilder.make_hover_inert(btn)

	return btn


func _on_story_pressed() -> void:
	ClickPlayer.play_select_1()
	SceneManager.go_to_scene(STORY_SCENE_PATH)


func _on_play_pressed() -> void:
	ClickPlayer.play_select_1()
	SceneManager.go_to_scene("res://scenes/hub/LevelTrack.tscn")


func _on_exit_pressed() -> void:
	ClickPlayer.play_select_1()
	get_tree().quit()


func _on_settings_pressed() -> void:
	ClickPlayer.play_select_1()
	if is_instance_valid(_settings_popup):
		return
	_settings_popup = load("res://scenes/menu/SettingsPopup.gd").new()
	add_child(_settings_popup)


func _on_language_changed(_lang: String) -> void:
	_settings_btn.text = TranslationManager.t("settings")
	_story_btn.text = TranslationManager.t("story")
	_play_btn.text = TranslationManager.t("play")
	_exit_btn.text = TranslationManager.t("exit")
