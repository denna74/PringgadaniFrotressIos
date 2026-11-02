class_name ButtonBuilder extends RefCounted

const LONG_BUTTON_ART := "res://assets/buttons/long_button.png"
const SMALL_BUTTON_TEXT_COLOR := Color(1.0, 0.85, 0.2, 1.0)


## The long-button artwork is worn by the hub's menu buttons and main menu button as well as
## the run's pause button, so it lives here instead of being pasted into each scene. The
## button keeps whatever label colour it was built with, so call make_hover_inert again after
## changing font_color.
static func apply_long_button_art(btn: Button) -> void:
	var style := StyleBoxTexture.new()
	style.texture = load(LONG_BUTTON_ART)
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("focus", style)
	var pressed := style.duplicate() as StyleBoxTexture
	pressed.modulate_color = Color(0.8, 0.8, 0.8)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_font_size_override("font_size", 21)
	make_hover_inert(btn)


static func create_menu_button(text: String, width: int = 320, height: int = 50) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(width, height)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.22, 0.12, 0.06, 0.9)
	normal.border_width_top = 2
	normal.border_width_bottom = 2
	normal.border_width_left = 2
	normal.border_width_right = 2
	normal.border_color = Color(0.55, 0.35, 0.12, 1)
	normal.corner_radius_top_left = 4
	normal.corner_radius_top_right = 4
	normal.corner_radius_bottom_left = 4
	normal.corner_radius_bottom_right = 4

	var pressed := StyleBoxFlat.new()
	pressed.bg_color = Color(0.35, 0.20, 0.10, 0.95)
	pressed.border_width_top = 2
	pressed.border_width_bottom = 2
	pressed.border_width_left = 2
	pressed.border_width_right = 2
	pressed.border_color = Color(0.75, 0.50, 0.20, 1)
	pressed.corner_radius_top_left = 4
	pressed.corner_radius_top_right = 4
	pressed.corner_radius_bottom_left = 4
	pressed.corner_radius_bottom_right = 4

	# No hover styling: this is a touch UI and a resting pointer never happens.
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("pressed", pressed)

	btn.add_theme_font_size_override("font_size", 18)
	btn.add_theme_color_override("font_color", Color(0.95, 0.85, 0.65, 1))
	make_hover_inert(btn)

	return btn


## Keep a resting pointer from repainting the button.
##
## Button does not draw its normal box while hovered -- it swaps in the hover box. So
## "do nothing on hover" means handing hover the very same stylebox it was already
## showing. An empty hover box is wrong: Button would paint nothing and the artwork
## would vanish. The same rule covers the label, which a theme cannot express, since a
## theme only knows one global hover colour and not "this button's own font_color".
##
## Call this again after changing a button's normal stylebox or its font_color.
static func make_hover_inert(btn: Button) -> void:
	btn.add_theme_stylebox_override("hover", btn.get_theme_stylebox("normal"))
	btn.add_theme_color_override("font_hover_color", btn.get_theme_color("font_color"))


static func create_small_button(text: String, width: int = 160, height: int = 36) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(width, height)

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.3, 0.18, 0.08, 0.9)
	normal.border_width_top = 1
	normal.border_width_bottom = 1
	normal.border_width_left = 1
	normal.border_width_right = 1
	normal.border_color = Color(0.5, 0.3, 0.1, 1)
	normal.corner_radius_top_left = 3
	normal.corner_radius_top_right = 3
	normal.corner_radius_bottom_left = 3
	normal.corner_radius_bottom_right = 3

	var pressed := StyleBoxFlat.new()
	pressed.bg_color = Color(0.45, 0.28, 0.15, 0.95)
	pressed.border_color = Color(0.7, 0.45, 0.15, 1)
	pressed.corner_radius_top_left = 3
	pressed.corner_radius_top_right = 3
	pressed.corner_radius_bottom_left = 3
	pressed.corner_radius_bottom_right = 3

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_font_size_override("font_size", 14)
	btn.add_theme_color_override("font_color", SMALL_BUTTON_TEXT_COLOR)
	btn.add_theme_color_override("font_pressed_color", SMALL_BUTTON_TEXT_COLOR)
	btn.add_theme_color_override("font_disabled_color", SMALL_BUTTON_TEXT_COLOR)
	make_hover_inert(btn)

	return btn


static func create_back_button() -> Button:
	return create_small_button("< Back", 100, 32)


static func create_panel(width: int = 400, height: int = 500) -> Panel:
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(width, height)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.06, 0.03, 0.92)
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_color = Color(0.45, 0.28, 0.08, 1)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6

	panel.add_theme_stylebox_override("panel", style)
	return panel


static func create_title_label(text: String, size: int = 28) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color.GOLDENROD)
	return label


static func create_body_label(text: String, size: int = 14) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color(0.29, 0.237, 0.008, 1.0))
	return label


static func create_stat_label(text: String, size: int = 16) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color(0.25, 0.15, 0.08, 1))
	return label


static func style_progress_bar(bar: ProgressBar, fill: Color, track: Color, radius: int = 3) -> void:
	if bar == null:
		return
	var track_style := StyleBoxFlat.new()
	track_style.bg_color = track
	track_style.set_corner_radius_all(radius)
	bar.add_theme_stylebox_override("background", track_style)
	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = fill
	fill_style.set_corner_radius_all(radius)
	bar.add_theme_stylebox_override("fill", fill_style)


## Lives are drawn as icons, one slot per life: an animated blue flame while the life is
## held, and the skull once it has been spent. Both bars show lives -- the hub and the
## run HUD -- so the strip is built here rather than twice, in two places that drift.
const LIVES_ART_DIR := "res://assets/sprites/hud/"
const LIFE_FIRE_DIR := LIVES_ART_DIR + "life_fire/"
const LIFE_FIRE_FRAMES := 19
const LIFE_FIRE_FPS := 10.0
const LIFE_SKULL_ART := LIVES_ART_DIR + "head-skull.png"
const LIFE_ICON_SIZE := 60
const LIFE_ICON_GAP := -25

## The flame comes from a 19 frame gif, which Godot cannot import, so it ships as PNG
## frames. Every held slot plays the same animation, so they share one texture.
static var _life_fire: AnimatedTexture = null
static var _life_skull: Texture2D = null


## The lives caption both bars show, as a caption only: the icon strip is placed by each
## bar on its own, with its own position constant, the way the bar's other readouts are.
## The caption arrives as text because the run HUD is untranslated while the hub swaps it
## with the language setting, so this stays a dumb layout with no translation knowledge.
static func create_lives_display(prefix_text: String) -> Control:
	var display := Control.new()
	display.name = "LivesDisplay"
	display.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var prefix := Label.new()
	prefix.name = "LivesPrefix"
	prefix.text = prefix_text
	prefix.add_theme_font_size_override("font_size", 24)
	prefix.add_theme_color_override("font_color", Color(0.25, 0.15, 0.08, 1))
	prefix.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	display.add_child(prefix)
	# The caption fills the display, so it centres against the same row height the icon
	# strip uses -- the two still line up even though each bar places the strip itself.
	prefix.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	display.custom_minimum_size = Vector2(
		prefix.get_combined_minimum_size().x, float(LIFE_ICON_SIZE)
	)
	return display


## One icon per life, named so callers and tests can find the strip without poking at
## texture state. Slots start empty; call update_lives_icons to fill them.
static func create_lives_icons(max_lives: int) -> HBoxContainer:
	var slot := HBoxContainer.new()
	slot.name = "LivesIcons"
	slot.add_theme_constant_override("separation", LIFE_ICON_GAP)
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in max_lives:
		var icon := TextureRect.new()
		icon.name = "Life%d" % i
		icon.custom_minimum_size = Vector2(LIFE_ICON_SIZE, LIFE_ICON_SIZE)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(icon)
	return slot


## Swap what plays in each slot: flame while held, skull once spent. Slots are created
## once, so losing a life never churns the tree.
static func update_lives_icons(slot: Container, lives: int) -> void:
	if slot == null:
		return
	var i := 0
	for icon in slot.get_children():
		if icon is TextureRect:
			(icon as TextureRect).texture = life_fire_tex() if i < lives else life_skull_tex()
		i += 1


## The blue flame, assembled once from the gif's exported frames.
##
## AnimatedTexture in this Godot has no fps and no loop: each frame carries its own
## duration, and it repeats until one_shot says otherwise. So 10fps means 0.1s a frame.
static func life_fire_tex() -> AnimatedTexture:
	if _life_fire != null:
		return _life_fire

	var anim := AnimatedTexture.new()
	anim.frames = LIFE_FIRE_FRAMES
	var frame_secs := 1.0 / LIFE_FIRE_FPS
	for i in LIFE_FIRE_FRAMES:
		anim.set_frame_duration(i, frame_secs)
		anim.set_frame_texture(i, load("%sfire_%02d.png" % [LIFE_FIRE_DIR, i + 1]))
	_life_fire = anim
	return _life_fire


## The spent-life skull, loaded once and shared by every spent slot.
static func life_skull_tex() -> Texture2D:
	if _life_skull == null:
		_life_skull = load(LIFE_SKULL_ART)
	return _life_skull
