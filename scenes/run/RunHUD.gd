extends CanvasLayer

signal attack_pressed
signal skill_pressed
signal dash_pressed
signal berserk_pressed
signal pause_requested
signal guard_pendopo_pressed
signal gather_soldiers_pressed

const SKILL_BUTTON_SIZE: float = 110.0
const EARTHQUAKE_BUTTON_POS: Vector2 = Vector2(906, 458)
const BERSERK_BUTTON_POS: Vector2 = Vector2(1016, 360)
const DASH_BUTTON_POS: Vector2 = Vector2(906, 594)
const ATTACK_BUTTON_POS: Vector2 = Vector2(1029, 478)
const ATTACK_BUTTON_SIZE: Vector2 = Vector2(235, 226)
const BERSERK_ACTIVE_COLOR: Color = Color(1.0, 0.45, 0.35, 1.0)
const BERSERK_ACTIVE_SCALE: float = 1.1
const LOW_THRESHOLD: float = 0.1
const PULSE_INTERVAL: float = 0.25
const PULSE_DIM: float = 0.3
const COUNTDOWN_WARNING_COLOR: Color = Color(1.0, 0.1, 0.1)
const COUNTDOWN_PULSE_SCALE: Vector2 = Vector2(1.35, 1.35)
const COUNTDOWN_PULSE_DURATION: float = 0.3
const COUNTDOWN_NORMAL_COLOR: Color = Color(0.25, 0.15, 0.08)

## Each top-bar readout is placed straight on the bar at its own position, so any one of
## them can be moved by editing just its own constant. The shared readouts sit on the same
## coordinates as the hub's top bar (LevelTrack's TOP_* constants) so the two bars match;
## the run-only wave readouts fill the gaps between them.
const TOP_LIVES_POSITION := Vector2(100, 20)
const TOP_LIVES_ICONS_POSITION := Vector2(165, 5)
const TOP_WAVE_POSITION := Vector2(320, 40)
const TOP_STAGE_POSITION := Vector2(550, 40)
const TOP_COUNTDOWN_POSITION := Vector2(700, 40)

## The pause button wears the hub's main menu button artwork, at the same spot and size.
const PAUSE_BUTTON_WIDTH := 170
const PAUSE_BUTTON_HEIGHT := 56
const TOP_PAUSE_POSITION := Vector2(1010, 20)

var _gold_label: Label
var _gold_caption: Label
var _pending_label: Label
var _wave_label: Label
var _stage_label: Label
var _lives_display: Control
var _lives_slot: HBoxContainer
var _countdown_label: Label
var _countdown_bold_font: FontVariation
var _stamina_label: Label
var _stamina_bar: ProgressBar
var _king_hp_label: Label
var _king_hp_bar: ProgressBar
var _king_hp_num: Label
var _stamina_num: Label
var _mana_label: Label
var _mana_bar: ProgressBar
var _mana_num: Label
var _king_lv_label: Label
var _king_xp_bar: ProgressBar
var _king_xp_num: Label
var _dpad: Control
var _atk_touch_index: int = -1
var _atk_tex: TextureRect
var _atk_btn: Control
var _skill_touch_index: int = -1
var _skill_tex: TextureRect
var _skill_btn: Control
var _skill_cooldown: TextureProgressBar
var _cooldown_disc: Texture2D
var _dash_touch_index: int = -1
var _dash_tex: TextureRect
var _dash_btn: Control
var _berserk_touch_index: int = -1
var _berserk_tex: TextureRect
var _berserk_btn: Control
var _berserk_active: bool = false
var _low_hp: bool = false
var _low_mana: bool = false
var _low_stamina: bool = false
var _pulse_timer: float = 0.0
var _pulse_on: bool = true
var _current_wave: int = 0
var _total_waves: int = 0
var _countdown_remaining: float = 0.0
var _countdown_displayed_value: int = -1
var _countdown_tween: Tween
var _minimap: Control
var _potions_panel: Control
var _pause_button: Button = null
var _soldier_commands: HBoxContainer
var _guard_pendopo_button: TextureButton
var _gather_soldiers_button: TextureButton
var _pause_allowed: bool = false
var _pause_blocked: bool = false
var stage_number: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_hud()
	SaveManager.gold_changed.connect(_on_gold_changed)
	EconomyManager.pending_changed.connect(_on_pending_changed)
	SaveManager.lives_changed.connect(_on_lives_changed)
	if not TranslationManager.language_changed.is_connected(_refresh_top_bar_labels):
		TranslationManager.language_changed.connect(_refresh_top_bar_labels)


func _build_hud() -> void:
	_build_top_bar()
	_build_soldier_command_buttons()
	_build_status_panel()
	_build_dpad()
	_build_attack_button()
	_build_skill_button()
	_build_berserk_button()
	_build_dash_button()
	_build_minimap()
	_build_potions_panel()


func _build_status_panel() -> void:
	var margin := 12
	var caption_w := 40
	var bar_w := 120
	var num_w := 80
	var row_h := 24
	var header_h := 30
	var h_sep := 6
	var v_sep := 10
	var grid_w := caption_w + h_sep + bar_w + h_sep + num_w
	var grid := GridContainer.new()
	grid.columns = 3
	grid.position = Vector2(margin, margin + header_h)
	grid.add_theme_constant_override("h_separation", h_sep)
	grid.add_theme_constant_override("v_separation", v_sep)

	_king_lv_label = Label.new()
	_king_lv_label.text = "LV 1"
	_king_lv_label.position = Vector2(0, 6)
	_king_lv_label.size = Vector2(grid_w + margin * 2, header_h)
	_king_lv_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_king_lv_label.add_theme_font_size_override("font_size", 14)
	_king_lv_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.3))

	grid.add_child(_make_stat_caption("EXP", Color(0.95, 0.85, 0.65)))
	_king_xp_bar = _make_stat_bar(Color(0.85, 0.65, 0.2), Color(0.22, 0.14, 0.06))
	grid.add_child(_king_xp_bar)
	_king_xp_num = _make_stat_num()
	_king_xp_num.text = "0 / 1"
	grid.add_child(_king_xp_num)

	_gold_caption = _make_stat_caption(
		TranslationManager.t("resource_gold"), Color(0.95, 0.85, 0.65)
	)
	grid.add_child(_gold_caption)
	_gold_label = _make_stat_value()
	_gold_label.text = "%d" % SaveManager.gold
	grid.add_child(_gold_label)
	grid.add_child(_make_stat_spacer())
	
	grid.add_child(_make_stat_caption(TranslationManager.t("mine"), Color(0.95, 0.85, 0.65)))
	_pending_label = _make_stat_value()
	_pending_label.text = "+0"
	grid.add_child(_pending_label)
	grid.add_child(_make_stat_spacer())

	_king_hp_label = _make_stat_caption("HP", Color(0.9, 0.3, 0.3))
	grid.add_child(_king_hp_label)
	_king_hp_bar = _make_stat_bar(Color(0.2, 0.8, 0.2), Color(0.2, 0.1, 0.08))
	grid.add_child(_king_hp_bar)
	_king_hp_num = _make_stat_num()
	grid.add_child(_king_hp_num)

	_mana_label = _make_stat_caption("MP", Color(0.4, 0.55, 1.0))
	grid.add_child(_mana_label)
	_mana_bar = _make_stat_bar(Color(0.45, 0.75, 1.0), Color(0.1, 0.12, 0.2))
	grid.add_child(_mana_bar)
	_mana_num = _make_stat_num()
	_mana_num.text = "200"
	grid.add_child(_mana_num)

	_stamina_label = _make_stat_caption("STA", Color(0.3, 0.9, 0.5))
	grid.add_child(_stamina_label)
	_stamina_bar = _make_stat_bar(Color(0.3, 0.9, 0.5), Color(0.1, 0.2, 0.14))
	grid.add_child(_stamina_bar)
	_stamina_num = _make_stat_num()
	_stamina_num.text = "100"
	grid.add_child(_stamina_num)

	var grid_h := 6 * row_h + 5 * v_sep
	var panel := Panel.new()
	panel.position = Vector2(8, 105)
	panel.size = Vector2(grid_w + margin * 2, margin + header_h + grid_h + margin)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.03, 0.01, 0.55)
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_color = Color(0.45, 0.28, 0.08, 1)
	style.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	panel.add_child(_king_lv_label)
	panel.add_child(grid)


func _make_stat_caption(text: String, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(40, 24)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", color)
	return label


func _make_stat_bar(fill: Color, track: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(130, 12)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.show_percentage = false
	ButtonBuilder.style_progress_bar(bar, fill, track, 2)
	return bar


func _make_stat_num() -> Label:
	var label := Label.new()
	label.custom_minimum_size = Vector2(85, 24)
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
	return label


func _make_stat_value() -> Label:
	var label := Label.new()
	label.custom_minimum_size = Vector2(85, 24)
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.3))
	return label


func _make_stat_spacer() -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(85, 4)
	return spacer


func setup_king_progress(level: int, xp: int, xp_to_next: int) -> void:
	var at_max_level: bool = level >= ProgressionData.MAX_KING_LEVEL
	if _king_lv_label:
		_king_lv_label.text = "LV %d" % level
	if _king_xp_bar:
		_king_xp_bar.max_value = maxf(xp_to_next, 1.0)
		_king_xp_bar.value = 1.0 if at_max_level else xp
	if _king_xp_num:
		_king_xp_num.text = (
			TranslationManager.t("xp_maximum")
			if at_max_level else "%d / %d" % [xp, xp_to_next]
		)


func _build_potions_panel() -> void:
	_potions_panel = load("res://scenes/run/PotionsPanel.gd").new()
	_potions_panel.name = "PotionsPanel"
	add_child(_potions_panel)


func setup_potions_panel(king: Node3D) -> void:
	if _potions_panel and _potions_panel.has_method("setup"):
		_potions_panel.setup(king)


func _build_minimap() -> void:
	_minimap = preload("res://scenes/run/Minimap.tscn").instantiate()
	_minimap.position = Vector2(1280 - 220 - 16, 105)
	_minimap.custom_minimum_size = Vector2(220, 220)
	add_child(_minimap)


func setup_minimap(terrain: Array, map_size: int) -> void:
	_minimap.setup(terrain, map_size)


func update_minimap(king_pos: Vector3, enemies: Array, troops: Array, buildings: Array, pendopo_poss: Array) -> void:
	_minimap.update_positions(king_pos, enemies, troops, buildings, pendopo_poss)


func _build_top_bar() -> void:
	var bg := TextureRect.new()
	bg.texture = load("res://assets/top_bar.png")
	bg.position = Vector2(0, 0)
	bg.size = Vector2(1280, 96)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(bg)

	# Order matches what a run actually asks you to watch: how many lives you have left,
	# where you are, which wave is up, and how long the next one takes to arrive.
	_lives_display = ButtonBuilder.create_lives_display(
		TranslationManager.t("hud_lives_prefix")
	)
	_lives_display.position = TOP_LIVES_POSITION
	bg.add_child(_lives_display)
	_lives_slot = ButtonBuilder.create_lives_icons(SaveManager.max_lives)
	_lives_slot.position = TOP_LIVES_ICONS_POSITION
	bg.add_child(_lives_slot)
	ButtonBuilder.update_lives_icons(_lives_slot, SaveManager.lives)

	_stage_label = Label.new()
	_stage_label.position = TOP_STAGE_POSITION
	_stage_label.add_theme_font_size_override("font_size", 24)
	_stage_label.add_theme_color_override("font_color", Color(0.25, 0.15, 0.08))
	_stage_label.text = TranslationManager.t("hud_stage") % stage_number
	add_child(_stage_label)

	_wave_label = Label.new()
	_wave_label.position = TOP_WAVE_POSITION
	_wave_label.add_theme_font_size_override("font_size", 24)
	_wave_label.add_theme_color_override("font_color", Color(0.25, 0.15, 0.08))
	_wave_label.text = TranslationManager.t("hud_wave") % [0, 0]
	add_child(_wave_label)

	_countdown_label = Label.new()
	_countdown_label.position = TOP_COUNTDOWN_POSITION
	_countdown_label.add_theme_font_size_override("font_size", 24)
	_countdown_label.add_theme_color_override("font_color", Color(0.25, 0.15, 0.08))
	_countdown_label.text = ""
	add_child(_countdown_label)
	_countdown_bold_font = FontVariation.new()
	_countdown_bold_font.base_font = _countdown_label.get_theme_font("font")
	_countdown_bold_font.variation_embolden = 0.6

	# The pause control sits where the hub's main menu button sits, wearing the same
	# long-button artwork, so both bars read as one strip. It is born disabled: the run
	# is not playable until _start_level finishes loading.
	_pause_button = Button.new()
	_pause_button.text = TranslationManager.t("pause")
	_pause_button.custom_minimum_size = Vector2(PAUSE_BUTTON_WIDTH, PAUSE_BUTTON_HEIGHT)

	var style := StyleBoxTexture.new()
	style.texture = load("res://assets/buttons/small_button.png")
	_pause_button.add_theme_stylebox_override("normal", style)
	_pause_button.add_theme_stylebox_override("focus", style)
	_pause_button.name = "PauseButton"
	_pause_button.add_theme_font_size_override("font_size", 36)
	_pause_button.position = TOP_PAUSE_POSITION
	_pause_button.disabled = true
	ButtonBuilder.make_hover_inert(_pause_button)
	_pause_button.pressed.connect(ClickPlayer.play_select_4)
	_pause_button.pressed.connect(func() -> void: pause_requested.emit())
	add_child(_pause_button)


func _on_lives_changed(_lives: int) -> void:
	ButtonBuilder.update_lives_icons(_lives_slot, SaveManager.lives)


func set_pause_enabled(enabled: bool) -> void:
	_pause_allowed = enabled
	_refresh_pause_button()


func _refresh_pause_button() -> void:
	if _pause_button == null:
		return
	var blocked: bool = (not _pause_allowed) or BuildingUIState.is_popup_open()
	if blocked == _pause_blocked:
		return
	_pause_blocked = blocked
	_pause_button.disabled = blocked


func _build_dpad() -> void:
	_dpad = preload("res://scenes/run/Dpad.tscn").instantiate()
	_dpad.position = Vector2(20, 420)
	_dpad.custom_minimum_size = Vector2(240, 240)
	_dpad.size = Vector2(240, 240)
	add_child(_dpad)


func _build_soldier_command_buttons() -> void:
	var commands := HBoxContainer.new()
	commands.name = "SoldierCommands"
	commands.position = Vector2(320, 590)
	commands.size = Vector2(SKILL_BUTTON_SIZE * 2.0 + 12.0, SKILL_BUTTON_SIZE)
	commands.add_theme_constant_override("separation", 40)
	commands.visible = false
	_soldier_commands = commands
	add_child(commands)

	_guard_pendopo_button = TextureButton.new()
	_guard_pendopo_button.name = "GuardPendopoButton"
	_guard_pendopo_button.ignore_texture_size = true
	_guard_pendopo_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	_guard_pendopo_button.custom_minimum_size = Vector2(SKILL_BUTTON_SIZE, SKILL_BUTTON_SIZE)
	_guard_pendopo_button.texture_normal = load("res://assets/buttons/pendopo.png")
	_guard_pendopo_button.pressed.connect(func() -> void: guard_pendopo_pressed.emit())
	_guard_pendopo_button.pressed.connect(ClickPlayer.play_select_3)
	commands.add_child(_guard_pendopo_button)

	_gather_soldiers_button = TextureButton.new()
	_gather_soldiers_button.name = "GatherSoldiersButton"
	_gather_soldiers_button.ignore_texture_size = true
	_gather_soldiers_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	_gather_soldiers_button.custom_minimum_size = Vector2(SKILL_BUTTON_SIZE, SKILL_BUTTON_SIZE)
	_gather_soldiers_button.texture_normal = load("res://assets/buttons/group.png")
	_gather_soldiers_button.pressed.connect(func() -> void: gather_soldiers_pressed.emit())
	_gather_soldiers_button.pressed.connect(ClickPlayer.play_select_3)
	commands.add_child(_gather_soldiers_button)


func set_soldier_commands_visible(has_living_soldiers: bool) -> void:
	if _soldier_commands != null:
		_soldier_commands.visible = has_living_soldiers


func _build_attack_button() -> void:
	var btn := Control.new()
	btn.position = ATTACK_BUTTON_POS
	btn.size = ATTACK_BUTTON_SIZE
	btn.pivot_offset = ATTACK_BUTTON_SIZE * 0.5
	add_child(btn)

	var tex := TextureRect.new()
	tex.texture = load("res://assets/buttons/attack.png")
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex.size = ATTACK_BUTTON_SIZE
	tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tex.self_modulate = Color(1, 1, 1, 0.6)
	_atk_tex = tex
	btn.add_child(tex)
	_atk_btn = btn

	btn.gui_input.connect(_on_atk_gui_input)


func _set_atk_pressed(pressed: bool) -> void:
	if pressed:
		_atk_btn.scale = Vector2(0.9, 0.9)
		_atk_tex.self_modulate = Color(1, 1, 1, 0.3)
	else:
		_atk_btn.scale = Vector2.ONE
		_atk_tex.self_modulate = Color(1, 1, 1, 0.6)


func _on_atk_gui_input(event: InputEvent) -> void:
	# Only ScreenTouch is acted on. emulate_touch_from_mouse is on in project.godot, so
	# a mouse click also arrives as a touch, and emulate_mouse_from_touch is on by
	# default, so a finger tap also arrives as a mouse button. Handling both made one
	# tap fire twice; picking the single touch source makes it fire exactly once.
	if not event is InputEventScreenTouch:
		return
	var st := event as InputEventScreenTouch
	if st.pressed:
		if _atk_touch_index == -1:
			_atk_touch_index = st.index
			_set_atk_pressed(true)
			attack_pressed.emit()
	elif st.index == _atk_touch_index:
		_atk_touch_index = -1
		_set_atk_pressed(false)


func _build_skill_button() -> void:
	_cooldown_disc = _create_cooldown_disc()
	var btn := Control.new()
	btn.position = EARTHQUAKE_BUTTON_POS
	btn.size = Vector2(SKILL_BUTTON_SIZE, SKILL_BUTTON_SIZE)
	btn.pivot_offset = Vector2(SKILL_BUTTON_SIZE, SKILL_BUTTON_SIZE) * 0.5
	add_child(btn)

	var tex := TextureRect.new()
	tex.texture = load(SkillData.icon_path("earthquake", SaveManager.get_skill_level("earthquake")))
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex.size = Vector2(SKILL_BUTTON_SIZE, SKILL_BUTTON_SIZE)
	tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tex.self_modulate = Color(1, 1, 1, 0.9)
	_skill_tex = tex
	btn.add_child(tex)

	var cd := TextureProgressBar.new()
	cd.name = "SkillCooldown"
	cd.position = tex.position
	cd.size = tex.size
	cd.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cd.texture_progress = _cooldown_disc
	cd.fill_mode = TextureProgressBar.FILL_CLOCKWISE
	cd.max_value = 100.0
	cd.value = 0.0
	cd.self_modulate = Color(0.1, 0.05, 0.05, 0.85)
	cd.visible = false
	_skill_cooldown = cd
	btn.add_child(cd)

	_skill_btn = btn
	btn.gui_input.connect(_on_skill_gui_input)


func _create_cooldown_disc() -> Texture2D:
	var size: int = int(SKILL_BUTTON_SIZE)
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := Vector2(size - 1, size - 1) * 0.5
	var radius := size * 0.5
	for y in size:
		for x in size:
			var d: float = Vector2(x, y).distance_to(center) / radius
			img.set_pixel(x, y, Color(1, 1, 1, 0.9) if d <= 1.0 else Color(0, 0, 0, 0))
	return ImageTexture.create_from_image(img)


func _set_skill_pressed(pressed: bool) -> void:
	if pressed:
		_skill_btn.scale = Vector2(0.9, 0.9)
		_skill_tex.self_modulate = Color(1, 1, 1, 0.4)
	else:
		_skill_btn.scale = Vector2.ONE
		_skill_tex.self_modulate = Color(1, 1, 1, 0.9)


func _on_skill_gui_input(event: InputEvent) -> void:
	# Only ScreenTouch is acted on. emulate_touch_from_mouse is on in project.godot, so
	# a mouse click also arrives as a touch, and emulate_mouse_from_touch is on by
	# default, so a finger tap also arrives as a mouse button. Handling both made one
	# tap fire twice; picking the single touch source makes it fire exactly once.
	if not event is InputEventScreenTouch:
		return
	var st := event as InputEventScreenTouch
	if st.pressed:
		if _skill_touch_index == -1:
			_skill_touch_index = st.index
			_set_skill_pressed(true)
			skill_pressed.emit()
	elif st.index == _skill_touch_index:
		_skill_touch_index = -1
		_set_skill_pressed(false)


func set_skill_receiver(target: Node, method: String) -> void:
	skill_pressed.connect(Callable(target, method))


func _build_dash_button() -> void:
	var btn := Control.new()
	btn.position = DASH_BUTTON_POS
	btn.size = Vector2(SKILL_BUTTON_SIZE, SKILL_BUTTON_SIZE)
	btn.pivot_offset = Vector2(SKILL_BUTTON_SIZE, SKILL_BUTTON_SIZE) * 0.5
	add_child(btn)

	var tex := TextureRect.new()
	tex.texture = load(SkillData.icon_path("dash", SaveManager.get_skill_level("dash")))
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex.size = Vector2(SKILL_BUTTON_SIZE, SKILL_BUTTON_SIZE)
	tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tex.self_modulate = Color(1, 1, 1, 0.9)
	_dash_tex = tex
	btn.add_child(tex)

	_dash_btn = btn
	btn.gui_input.connect(_on_dash_gui_input)


func _set_dash_pressed(pressed: bool) -> void:
	if pressed:
		_dash_btn.scale = Vector2(0.9, 0.9)
		_dash_tex.self_modulate = Color(1, 1, 1, 0.4)
	else:
		_dash_btn.scale = Vector2.ONE
		_dash_tex.self_modulate = Color(1, 1, 1, 0.9)


func _on_dash_gui_input(event: InputEvent) -> void:
	# Only ScreenTouch is acted on. emulate_touch_from_mouse is on in project.godot, so
	# a mouse click also arrives as a touch, and emulate_mouse_from_touch is on by
	# default, so a finger tap also arrives as a mouse button. Handling both made one
	# tap fire twice; picking the single touch source makes it fire exactly once.
	if not event is InputEventScreenTouch:
		return
	var st := event as InputEventScreenTouch
	if st.pressed:
		if _dash_touch_index == -1:
			_dash_touch_index = st.index
			_set_dash_pressed(true)
			dash_pressed.emit()
	elif st.index == _dash_touch_index:
		_dash_touch_index = -1
		_set_dash_pressed(false)


func set_dash_receiver(target: Node, method: String) -> void:
	dash_pressed.connect(Callable(target, method))


func _build_berserk_button() -> void:
	var btn := Control.new()
	btn.position = BERSERK_BUTTON_POS
	btn.size = Vector2(SKILL_BUTTON_SIZE, SKILL_BUTTON_SIZE)
	btn.pivot_offset = Vector2(SKILL_BUTTON_SIZE, SKILL_BUTTON_SIZE) * 0.5
	add_child(btn)

	var tex := TextureRect.new()
	tex.texture = load(SkillData.icon_path("berserk", SaveManager.get_skill_level("berserk")))
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex.size = Vector2(SKILL_BUTTON_SIZE, SKILL_BUTTON_SIZE)
	tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tex.self_modulate = Color(1, 1, 1, 0.9)
	_berserk_tex = tex
	btn.add_child(tex)

	_berserk_btn = btn
	btn.gui_input.connect(_on_berserk_gui_input)


func _set_berserk_pressed(pressed: bool) -> void:
	if _berserk_btn == null:
		return
	if pressed:
		_berserk_btn.scale = Vector2.ONE * (1.0 if _berserk_active else 0.9)
		_berserk_tex.self_modulate = BERSERK_ACTIVE_COLOR.lerp(Color(0.5, 0.2, 0.15, 1.0), 0.5) if _berserk_active else Color(1, 1, 1, 0.4)
	else:
		_apply_berserk_style()


func _on_berserk_gui_input(event: InputEvent) -> void:
	# Only ScreenTouch is acted on. emulate_touch_from_mouse is on in project.godot, so
	# a mouse click also arrives as a touch, and emulate_mouse_from_touch is on by
	# default, so a finger tap also arrives as a mouse button. Handling both made one
	# tap fire twice; picking the single touch source makes it fire exactly once.
	if not event is InputEventScreenTouch:
		return
	var st := event as InputEventScreenTouch
	if st.pressed:
		if _berserk_touch_index == -1:
			_berserk_touch_index = st.index
			_set_berserk_pressed(true)
			berserk_pressed.emit()
	elif st.index == _berserk_touch_index:
		_berserk_touch_index = -1
		_set_berserk_pressed(false)


func set_berserk_receiver(target: Node, method: String) -> void:
	berserk_pressed.connect(Callable(target, method))


func set_berserk_active(active: bool) -> void:
	if _berserk_active == active:
		return
	_berserk_active = active
	_apply_berserk_style()
	_refresh_dash_dim()


func _apply_berserk_style() -> void:
	if _berserk_btn == null:
		return
	_berserk_btn.scale = Vector2.ONE * (BERSERK_ACTIVE_SCALE if _berserk_active else 1.0)
	if _berserk_tex == null:
		return
	_berserk_tex.self_modulate = BERSERK_ACTIVE_COLOR if _berserk_active else Color(1, 1, 1, 0.9)


func update_skill_cooldown(fraction_remaining: float) -> void:
	if _skill_cooldown == null:
		return
	var remaining := clampf(fraction_remaining, 0.0, 1.0)
	_skill_cooldown.visible = remaining > 0.0
	_skill_cooldown.value = remaining * 100.0


func set_dpad_receiver(target: Node, method: String) -> void:
	_dpad.move_direction.connect(Callable(target, method))


func set_attack_receiver(target: Node, method: String) -> void:
	attack_pressed.connect(Callable(target, method))


func update_stage_label() -> void:
	if _stage_label:
		_stage_label.text = TranslationManager.t("hud_stage") % stage_number


func update_countdown(remaining: float) -> void:
	_countdown_remaining = remaining
	if _countdown_label:
		if remaining < 0:
			_reset_countdown_animation()
			_countdown_displayed_value = -1
			_countdown_label.add_theme_color_override("font_color", COUNTDOWN_WARNING_COLOR)
			_countdown_label.add_theme_font_override("font", _countdown_bold_font)
			_countdown_label.text = TranslationManager.t("beat_them")
		elif remaining > 0:
			_countdown_label.remove_theme_font_override("font")
			var countdown_value := ceili(remaining)
			if countdown_value != _countdown_displayed_value:
				_countdown_displayed_value = countdown_value
				_reset_countdown_animation()
				if countdown_value <= 5:
					_countdown_label.add_theme_color_override("font_color", COUNTDOWN_WARNING_COLOR)
					_countdown_label.pivot_offset = _countdown_label.get_combined_minimum_size() / 2.0
					_countdown_label.scale = COUNTDOWN_PULSE_SCALE
					_countdown_tween = create_tween()
					_countdown_tween.tween_property(
						_countdown_label,
						"scale",
						Vector2.ONE,
						COUNTDOWN_PULSE_DURATION
					)
				else:
					_countdown_label.add_theme_color_override("font_color", COUNTDOWN_NORMAL_COLOR)
			_countdown_label.text = "%s: %d" % [TranslationManager.t("wave_in"), countdown_value]
		else:
			_reset_countdown_animation()
			_countdown_displayed_value = -1
			_countdown_label.add_theme_color_override("font_color", COUNTDOWN_NORMAL_COLOR)
			_countdown_label.remove_theme_font_override("font")
			_countdown_label.text = ""


func _reset_countdown_animation() -> void:
	if _countdown_tween != null and _countdown_tween.is_running():
		_countdown_tween.kill()
	_countdown_tween = null
	if _countdown_label != null:
		_countdown_label.scale = Vector2.ONE


func update_wave(current: int, total: int) -> void:
	_current_wave = current
	_total_waves = total
	if _wave_label:
		_wave_label.text = TranslationManager.t("hud_wave") % [current, total]


func _refresh_top_bar_labels(_lang: String) -> void:
	if _lives_display != null:
		var prefix := _lives_display.get_node_or_null("LivesPrefix") as Label
		if prefix != null:
			prefix.text = TranslationManager.t("hud_lives_prefix")
	if _gold_caption != null:
		_gold_caption.text = TranslationManager.t("resource_gold")
	update_stage_label()
	update_wave(_current_wave, _total_waves)
	update_countdown(_countdown_remaining)


# Absolute values, not a percentage. A percentage-only bar read "100" at every level,
# so a stamina pool that grew with the king looked identical to one that never did.
func update_stamina(current: float, maximum: float) -> void:
	if _stamina_bar:
		_stamina_bar.max_value = maxf(maximum, 1.0)
		_stamina_bar.value = current
		if _stamina_num:
			_stamina_num.text = "%d/%d" % [ceili(current), ceili(maximum)]
		var ratio: float = current / maxf(maximum, 1.0)
		if ratio <= 0.2:
			_tint_bar(_stamina_bar, Color(1.0, 0.3, 0.3))
		else:
			_tint_bar(_stamina_bar, Color(1.0, 1.0, 1.0))
		_low_stamina = _apply_low(_stamina_bar, ratio)
	_refresh_dash_dim()


func _tint_bar(bar: ProgressBar, color: Color) -> void:
	if bar == null:
		return
	bar.modulate = Color(color.r, color.g, color.b, bar.modulate.a)


func _apply_low(bar: ProgressBar, percent: float) -> bool:
	var low := percent <= LOW_THRESHOLD
	if bar != null and not low:
		bar.modulate.a = 1.0
	return low


func _process(delta: float) -> void:
	_refresh_pause_button()
	_pulse_timer += delta
	if _pulse_timer < PULSE_INTERVAL:
		return
	_pulse_timer = 0.0
	_pulse_on = not _pulse_on
	var alpha := 1.0 if _pulse_on else PULSE_DIM
	if _low_hp and _king_hp_bar:
		_king_hp_bar.modulate.a = alpha
	if _low_mana and _mana_bar:
		_mana_bar.modulate.a = alpha
	if _low_stamina and _stamina_bar:
		_stamina_bar.modulate.a = alpha


func _refresh_dash_dim() -> void:
	if _dash_tex == null:
		return
	if _berserk_active:
		_dash_tex.self_modulate = Color(1, 1, 1, 0.9)
		return
	var stamina_pct := 0.0
	if _stamina_bar != null and _stamina_bar.max_value > 0.0:
		stamina_pct = _stamina_bar.value / _stamina_bar.max_value
	if stamina_pct <= 0.2:
		_dash_tex.self_modulate = Color(1, 1, 1, 0.35)
	else:
		_dash_tex.self_modulate = Color(1, 1, 1, 0.9)


func update_mana(current: float, maximum: float) -> void:
	if _mana_bar:
		_mana_bar.max_value = maxf(maximum, 1.0)
		_mana_bar.value = current
		if _mana_num:
			_mana_num.text = "%d/%d" % [ceili(current), ceili(maximum)]
		var ratio: float = current / maxf(maximum, 1.0)
		if ratio <= 0.2:
			_tint_bar(_mana_bar, Color(0.5, 0.6, 1.0))
		else:
			_tint_bar(_mana_bar, Color(1.0, 1.0, 1.0))
		_low_mana = _apply_low(_mana_bar, ratio)


func restore_stamina_flash() -> void:
	if _stamina_bar:
		_stamina_bar.modulate = Color(0.3, 1.0, 0.3)
		var tween := create_tween()
		tween.tween_property(_stamina_bar, "modulate", Color(1.0, 1.0, 1.0), 0.4)


func _on_gold_changed(new_gold: int) -> void:
	if _gold_label:
		_gold_label.text = "%d" % new_gold


func _on_pending_changed(pending: int) -> void:
	if _pending_label:
		_pending_label.text = "+%d" % pending


func update_king_hp(current: float, maximum: float) -> void:
	if _king_hp_bar:
		_king_hp_bar.max_value = maximum
		_king_hp_bar.value = current
		if _king_hp_num:
			_king_hp_num.text = "%d/%d" % [ceili(current), ceili(maximum)]
		var ratio: float = current / max(maximum, 1.0)
		if ratio > 0.5:
			_tint_bar(_king_hp_bar, Color(0.2, 0.8, 0.2))
		elif ratio > 0.25:
			_tint_bar(_king_hp_bar, Color(0.8, 0.8, 0.2))
		else:
			_tint_bar(_king_hp_bar, Color(0.8, 0.2, 0.2))
		_low_hp = _apply_low(_king_hp_bar, ratio)
