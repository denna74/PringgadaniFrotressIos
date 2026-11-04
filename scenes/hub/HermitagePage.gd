extends Control

## The Hermitage: spend gold to raise the king's three skills. Each row shows the skill
## icon for the current tier (levels 1-3 vs 4-6 use different art and names), a six-step
## level track whose last three slots carry the tier-2 art, the current-to-next effect,
## and an upgrade button (or MAX at the cap). The page fills the hub's content panel, so
## every width is kept inside it.

const ROW_WIDTH := 430
const ROW_HEIGHT := 185
const ICON_SIZE := 72
const TRACK_ICON_SIZE := 44
const ICON_DIM_ALPHA := 0.35
const POPUP_W := 420
const POPUP_H := 200
const BUTTON_W := 170
const BUTTON_H := 48


var _list: VBoxContainer = null
var _tracks: Dictionary = {}
var _upgrade_buttons: Dictionary = {}
var _gold_changed_cb: Callable
var _skill_changed_cb: Callable


func _ready() -> void:
	_setup_ui()
	_build_rows()
	_gold_changed_cb = _on_state_changed
	_skill_changed_cb = _on_skill_changed
	SaveManager.gold_changed.connect(_gold_changed_cb)
	SaveManager.skill_level_changed.connect(_skill_changed_cb)


func _exit_tree() -> void:
	if _gold_changed_cb.is_valid() and is_instance_valid(SaveManager):
		if SaveManager.gold_changed.is_connected(_gold_changed_cb):
			SaveManager.gold_changed.disconnect(_gold_changed_cb)
	if _skill_changed_cb.is_valid() and is_instance_valid(SaveManager):
		if SaveManager.skill_level_changed.is_connected(_skill_changed_cb):
			SaveManager.skill_level_changed.disconnect(_skill_changed_cb)
	_free_window_popup()


func _setup_ui() -> void:
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(50, 36)
	scroll.size = Vector2(532, 604)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	_list = VBoxContainer.new()
	_list.name = "SkillList"
	_list.add_theme_constant_override("separation", 12)
	scroll.add_child(_list)


func _build_rows() -> void:
	for child in _list.get_children():
		child.queue_free()
	_tracks.clear()
	_upgrade_buttons.clear()
	for id: String in SkillData.IDS:
		_list.add_child(_build_row(id))


func _build_row(id: String) -> Panel:
	var panel := ButtonBuilder.create_panel(ROW_WIDTH, ROW_HEIGHT)
	panel.name = "Card_" + id
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	var hbox := HBoxContainer.new()
	hbox.position = Vector2(22, 14)
	hbox.size = Vector2(ROW_WIDTH - 32, ROW_HEIGHT - 26)
	hbox.add_theme_constant_override("separation", 10)
	panel.add_child(hbox)

	var level: int = SaveManager.get_skill_level(id)

	var icon := TextureRect.new()
	icon.texture = load(SkillData.icon_path(id, level))
	icon.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hbox.add_child(icon)

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND
	col.add_theme_constant_override("separation", 6)
	hbox.add_child(col)

	var name_lbl := Label.new()
	name_lbl.text = "%s   %s" % [
		TranslationManager.t(SkillData.display_name_key(id, level)),
		TranslationManager.t("skill_level").replace("{n}", "%d") % SkillData.display_level(level),
	]
	name_lbl.add_theme_font_size_override("font_size", 20)
	name_lbl.add_theme_color_override("font_color", Color(0.95, 0.85, 0.65))
	col.add_child(name_lbl)

	var track := _build_track(id)
	col.add_child(track)
	_tracks[id] = track

	var effect := ButtonBuilder.create_body_label(_effect_text(id), 14)
	effect.add_theme_color_override("font_color", Color.CHARTREUSE)
	effect.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(effect)

	var upgrade := _build_upgrade(id)
	if upgrade is Button:
		upgrade.name = "Upgrade_" + id
		_upgrade_buttons[id] = upgrade
	else:
		upgrade.name = "Max_" + id
	col.add_child(upgrade)

	return panel


func _build_track(id: String) -> HBoxContainer:
	var track := HBoxContainer.new()
	track.name = "Track_" + id
	track.add_theme_constant_override("separation", 6)
	var level: int = SaveManager.get_skill_level(id)
	for i in SkillData.MAX_LEVEL:
		var slot := TextureRect.new()
		slot.texture = load(SkillData.icon_path(id, i + 1))
		slot.custom_minimum_size = Vector2(TRACK_ICON_SIZE, TRACK_ICON_SIZE)
		slot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		slot.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		slot.modulate = Color.WHITE if i < level else Color(1, 1, 1, ICON_DIM_ALPHA)
		# Mark the highest owned step with a gold ring. A tint can't be used: it multiplies
		# the artwork, and the dash art is blue, so a gold tint turns it green. A border
		# marks the step without recolouring the art.
		if i == level - 1:
			slot.add_child(_build_current_marker())
		track.add_child(slot)
	return track


## A border-only panel that rings the highest owned level, leaving the icon's own colours.
func _build_current_marker() -> Panel:
	var ring := Panel.new()
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.border_color = Color(1.0, 0.85, 0.35)
	style.set_border_width_all(2)
	style.set_corner_radius_all(3)
	ring.add_theme_stylebox_override("panel", style)
	return ring


func _build_upgrade(id: String) -> Control:
	var level: int = SaveManager.get_skill_level(id)
	if level >= SkillData.MAX_LEVEL:
		return ButtonBuilder.create_body_label(TranslationManager.t("skill_max"), 16)
	var cost: int = SkillData.upgrade_cost(id, level)
	var btn := ButtonBuilder.create_small_button(
		"%s %dg" % [TranslationManager.t("skill_upgrade"), cost], 200, 34
	)
	btn.disabled = SaveManager.gold < cost
	btn.pressed.connect(_show_upgrade_confirm.bind(id))
	btn.pressed.connect(ClickPlayer.play_select_3)
	return btn


func _show_upgrade_confirm(id: String) -> void:
	if get_node_or_null("UpgradeConfirmOverlay") != null:
		return

	var level: int = SaveManager.get_skill_level(id)
	if level >= SkillData.MAX_LEVEL:
		return
	var cost: int = SkillData.upgrade_cost(id, level)

	# The page sits inside the hub's content panel, so the dim overlay is attached to
	# the window and the panel is centred on the screen, matching the market popup.
	var window := get_window()
	if window == null:
		window = get_viewport()
	var overlay := ColorRect.new()
	overlay.name = "UpgradeConfirmOverlay"
	overlay.color = Color(0, 0, 0, 0.6)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	window.add_child(overlay)

	var panel := ButtonBuilder.create_panel(POPUP_W, POPUP_H)
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -POPUP_W / 2.0
	panel.offset_right = POPUP_W / 2.0
	panel.offset_top = -POPUP_H / 2.0
	panel.offset_bottom = POPUP_H / 2.0
	overlay.add_child(panel)

	var title := ButtonBuilder.create_title_label(
		TranslationManager.t("skill_upgrade_confirm").replace(
			"{name}", TranslationManager.t(SkillData.display_name_key(id, level))), 22)
	title.position = Vector2(20, 24)
	title.size = Vector2(POPUP_W - 40, 56)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	panel.add_child(title)

	var btn_y := POPUP_H - 76.0
	var gap := 20.0
	var total_w := BUTTON_W * 2 + gap
	var left_x := (POPUP_W - total_w) / 2.0

	var cancel_btn := ButtonBuilder.create_menu_button(
		TranslationManager.t("cancel"), BUTTON_W, BUTTON_H)
	cancel_btn.position = Vector2(left_x, btn_y)
	cancel_btn.pressed.connect(overlay.queue_free)
	cancel_btn.pressed.connect(ClickPlayer.play_select_4)
	panel.add_child(cancel_btn)

	var ok_btn := ButtonBuilder.create_menu_button(
		"%s %dg" % [TranslationManager.t("ok"), cost], BUTTON_W, BUTTON_H)
	ok_btn.position = Vector2(left_x + BUTTON_W + gap, btn_y)
	ok_btn.disabled = SaveManager.gold < cost
	ok_btn.pressed.connect(func() -> void:
		SaveManager.upgrade_skill(id))
	ok_btn.pressed.connect(ClickPlayer.play_select_3)
	ok_btn.pressed.connect(overlay.queue_free)
	panel.add_child(ok_btn)


func _effect_text(id: String) -> String:
	var level: int = SaveManager.get_skill_level(id)
	var at_max: bool = level >= SkillData.MAX_LEVEL
	match id:
		"dash":
			return _stat(TranslationManager.t("skill_dmg"), SkillData.dash_damage_mult, level, at_max, "x") \
				+ "   " + _stat(TranslationManager.t("skill_speed"), SkillData.dash_speed_mult, level, at_max, "x")
		"earthquake":
			return _stat(TranslationManager.t("skill_dmg"), SkillData.quake_damage_mult, level, at_max, "x") \
				+ "   " + _stat(TranslationManager.t("skill_mp_cost"), SkillData.quake_mp_cost, level, at_max, "")
		"berserk":
			return _stat(TranslationManager.t("skill_atk"), SkillData.berserk_attack_mult, level, at_max, "x") \
				+ "   " + _stat(TranslationManager.t("skill_def"), SkillData.berserk_defense_mult, level, at_max, "x") \
				+ "   " + _stat(TranslationManager.t("skill_drain"), SkillData.berserk_drain_per_sec, level, at_max, "/s")
	return ""


## A getter passed as a Callable so every row formats the same way.
func _stat(label: String, getter: Callable, level: int, at_max: bool, suffix: String) -> String:
	var current := "%s %s%s" % [label, _fmt(float(getter.call(level))), suffix]
	if at_max:
		return current
	return "%s > %s%s" % [current, _fmt(float(getter.call(level + 1))), suffix]


func _fmt(value: float) -> String:
	if is_equal_approx(value, floorf(value)):
		return str(int(value))
	return "%.2f" % value


func _on_state_changed(_value: int = 0) -> void:
	for id: String in _upgrade_buttons:
		var cost: int = SkillData.upgrade_cost(id, SaveManager.get_skill_level(id))
		(_upgrade_buttons[id] as Button).disabled = SaveManager.gold < cost


func _on_skill_changed(_id: String, _level: int) -> void:
	_build_rows()


# Called by the hub when another section is opened, so the confirm popup never lingers.
# The overlay is attached to the window, not this page, so it is not a child here.
func close_popups() -> void:
	_free_window_popup()


func _free_window_popup() -> void:
	var window := get_window()
	if window == null:
		window = get_viewport()
	var overlay := window.get_node_or_null("UpgradeConfirmOverlay")
	if overlay != null:
		overlay.queue_free()
