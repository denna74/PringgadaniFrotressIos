extends Control

# A mobile-run pause sheet. It is a Control rather than a CanvasLayer because it is
# parented to RunHUD, which is itself always-processed; the full-rect STOP backdrop
# is what keeps the frozen game and HUD from receiving taps behind it.

signal continue_requested
signal exit_requested

const PANEL_SIZE := Vector2(500, 300)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()


func _build() -> void:
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.65)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var panel := ButtonBuilder.create_panel(int(PANEL_SIZE.x), int(PANEL_SIZE.y))
	panel.name = "PausePanel"
	panel.position = (get_viewport_rect().size - PANEL_SIZE) / 2.0
	add_child(panel)

	var title := ButtonBuilder.create_title_label(TranslationManager.t("pause"), 30)
	title.position = Vector2(0, 26)
	title.size = Vector2(PANEL_SIZE.x, 42)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(title)

	var cont := ButtonBuilder.create_small_button(TranslationManager.t("continue"), 280, 60)
	cont.name = "ContinueButton"
	cont.position = Vector2(110, 96)
	cont.add_theme_font_size_override("font_size", 22)
	cont.pressed.connect(ClickPlayer.play_select_3)
	cont.pressed.connect(func() -> void: continue_requested.emit())
	panel.add_child(cont)

	var exit_btn := ButtonBuilder.create_small_button(TranslationManager.t("exit"), 280, 60)
	exit_btn.name = "ExitButton"
	exit_btn.position = Vector2(110, 178)
	exit_btn.add_theme_font_size_override("font_size", 22)
	exit_btn.pressed.connect(ClickPlayer.play_select_4)
	exit_btn.pressed.connect(func() -> void: exit_requested.emit())
	panel.add_child(exit_btn)