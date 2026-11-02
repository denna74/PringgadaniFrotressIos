extends Control


var victory: bool = false
var summary: Dictionary = {}

signal closed


func _ready() -> void:
	_setup_ui()


func _setup_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.8)
	bg.anchors_preset = Control.PRESET_FULL_RECT
	add_child(bg)

	var panel := ButtonBuilder.create_panel(480, 360)
	panel.anchors_preset = Control.PRESET_CENTER
	panel.position = Vector2(-240, -180)
	add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.position = Vector2(16, 16)
	vbox.size = Vector2(448, 328)
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	var header := "VICTORY" if victory else "DEFEAT"
	var h_color := Color(0.85, 0.7, 0.15) if victory else Color(0.7, 0.2, 0.15)
	var title := ButtonBuilder.create_title_label(header, 28)
	title.add_theme_color_override("font_color", h_color)
	vbox.add_child(title)

	vbox.add_child(HSeparator.new())

	vbox.add_child(ButtonBuilder.create_stat_label(
		"Waves survived: %d / %d" % [summary.get("waves_survived", 0), summary.get("total_waves", 0)], 16
	))
	vbox.add_child(ButtonBuilder.create_stat_label(
		"Total enemies slain: %d" % summary.get("total_enemy_casualties", 0), 16
	))

	if victory:
		vbox.add_child(ButtonBuilder.create_stat_label(
			"Reward: +%d gold" % summary.get("gold_reward", 0), 16
		))
	else:
		var lives_left: int = SaveManager.lives
		vbox.add_child(ButtonBuilder.create_stat_label(
			"-1 Life  (%d / %d remaining)" % [lives_left, SaveManager.max_lives], 16
		))

	var btn := ButtonBuilder.create_menu_button("Return to Level Track", 280, 46)
	btn.pressed.connect(_on_closed)
	vbox.add_child(btn)


func _on_closed() -> void:
	closed.emit()
	queue_free()
