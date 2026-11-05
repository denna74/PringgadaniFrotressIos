extends Control

const ROW_WIDTH := 430
const ROW_HEIGHT := 200
const ITEMS_PER_PAGE := 2
const PAGINATION_Y := 570
const PAGINATION_BUTTON_SIZE := Vector2(140, 46)
const ICON_SIZE := 72
const TRACK_ICON_SIZE := 40
const ICON_DIM_ALPHA := 0.35
const POPUP_W := 420
const POPUP_H := 280
const BUTTON_W := 170
const BUTTON_H := 48

var _list: VBoxContainer = null
var _tracks: Dictionary = {}
var _upgrade_buttons: Dictionary = {}
var _current_page: int = 0
var _prev_btn: Button = null
var _next_btn: Button = null
var _page_label: Label = null
var _gold_changed_cb: Callable
var _building_changed_cb: Callable


func _ready() -> void:
	_setup_ui()
	_build_rows()
	_gold_changed_cb = _on_state_changed
	_building_changed_cb = _on_building_changed
	SaveManager.gold_changed.connect(_gold_changed_cb)
	SaveManager.building_upgrade_level_changed.connect(_building_changed_cb)


func _exit_tree() -> void:
	if _gold_changed_cb.is_valid() and is_instance_valid(SaveManager):
		if SaveManager.gold_changed.is_connected(_gold_changed_cb):
			SaveManager.gold_changed.disconnect(_gold_changed_cb)
	if _building_changed_cb.is_valid() and is_instance_valid(SaveManager):
		if SaveManager.building_upgrade_level_changed.is_connected(_building_changed_cb):
			SaveManager.building_upgrade_level_changed.disconnect(_building_changed_cb)
	_free_window_popup()


func _setup_ui() -> void:
	_list = VBoxContainer.new()
	_list.name = "BuildingList"
	_list.position = Vector2(20, 36)
	_list.size = Vector2(532, ROW_HEIGHT * ITEMS_PER_PAGE + 12)
	_list.add_theme_constant_override("separation", 12)
	add_child(_list)

	var pagination := HBoxContainer.new()
	pagination.name = "Pagination"	
	pagination.position = Vector2(20, PAGINATION_Y)
	pagination.size = Vector2(532, PAGINATION_BUTTON_SIZE.y)
	pagination.alignment = BoxContainer.ALIGNMENT_CENTER
	pagination.add_theme_constant_override("separation", 16)
	add_child(pagination)

	_prev_btn = ButtonBuilder.create_small_button(
		TranslationManager.t("prev"),
		int(PAGINATION_BUTTON_SIZE.x),
		int(PAGINATION_BUTTON_SIZE.y)
	)
	_prev_btn.name = "ArchitecturePrev"
	_prev_btn.add_theme_font_size_override("font_size", 20)
	_prev_btn.pressed.connect(_on_prev_page)
	_prev_btn.pressed.connect(ClickPlayer.play_select_3)
	pagination.add_child(_prev_btn)

	_page_label = Label.new()
	_page_label.name = "ArchitecturePageLabel"
	_page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_page_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_page_label.custom_minimum_size = Vector2(80, PAGINATION_BUTTON_SIZE.y)
	_page_label.add_theme_font_size_override("font_size", 16)
	_page_label.add_theme_color_override("font_color", Color(0.9, 0.8, 0.55))
	pagination.add_child(_page_label)

	_next_btn = ButtonBuilder.create_small_button(
		TranslationManager.t("next"),
		int(PAGINATION_BUTTON_SIZE.x),
		int(PAGINATION_BUTTON_SIZE.y)
	)
	_next_btn.name = "ArchitectureNext"
	_next_btn.add_theme_font_size_override("font_size", 20)
	_next_btn.pressed.connect(_on_next_page)
	_next_btn.pressed.connect(ClickPlayer.play_select_3)
	pagination.add_child(_next_btn)


func _build_rows() -> void:
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	_tracks.clear()
	_upgrade_buttons.clear()
	var start := _current_page * ITEMS_PER_PAGE
	var end := mini(start + ITEMS_PER_PAGE, BuildingUpgradeData.IDS.size())
	for i in range(start, end):
		_list.add_child(_build_row(BuildingUpgradeData.IDS[i]))
	_update_pagination()


func _update_pagination() -> void:
	var total_pages := maxi(
		1, ceili(float(BuildingUpgradeData.IDS.size()) / float(ITEMS_PER_PAGE))
	)
	_page_label.text = "%d / %d" % [_current_page + 1, total_pages]
	_prev_btn.disabled = _current_page <= 0
	_next_btn.disabled = _current_page >= total_pages - 1


func _on_prev_page() -> void:
	if _current_page <= 0:
		return
	_current_page -= 1
	_build_rows()


func _on_next_page() -> void:
	var total_pages := maxi(
		1, ceili(float(BuildingUpgradeData.IDS.size()) / float(ITEMS_PER_PAGE))
	)
	if _current_page >= total_pages - 1:
		return
	_current_page += 1
	_build_rows()


func _build_row(id: String) -> Panel:
	var panel := ButtonBuilder.create_panel(ROW_WIDTH, ROW_HEIGHT)
	panel.name = "Card_" + id
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	var hbox := HBoxContainer.new()
	hbox.position = Vector2(14, 14)
	hbox.size = Vector2(ROW_WIDTH - 28, ROW_HEIGHT - 26)
	hbox.add_theme_constant_override("separation", 8)
	panel.add_child(hbox)

	var level: int = SaveManager.get_building_upgrade_level(id)
	var icon := TextureRect.new()
	icon.texture = load(BuildingUpgradeData.ICON_PATHS[id])
	icon.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hbox.add_child(icon)

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND
	col.add_theme_constant_override("separation", 5)
	hbox.add_child(col)

	var name_lbl := Label.new()
	name_lbl.text = "%s   %s" % [
		TranslationManager.t(BuildingUpgradeData.NAME_KEYS[id]),
		TranslationManager.t("skill_level").replace("{n}", "%d") % level,
	]
	name_lbl.add_theme_font_size_override("font_size", 20)
	name_lbl.add_theme_color_override("font_color", Color(0.95, 0.85, 0.65))
	col.add_child(name_lbl)

	var track := _build_track(id)
	col.add_child(track)
	_tracks[id] = track

	var effect := ButtonBuilder.create_body_label(_effect_text(id), 16)
	effect.name = "EffectLabel"
	effect.add_theme_color_override("font_color", Color.CHARTREUSE)
	effect.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(effect)

	var details := ButtonBuilder.create_body_label(_details_text(id, level), 16)
	details.name = "DetailsLabel"
	details.add_theme_color_override("font_color", Color.CHARTREUSE)
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(details)

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
	track.add_theme_constant_override("separation", 3)
	var level: int = SaveManager.get_building_upgrade_level(id)
	for i in BuildingUpgradeData.MAX_LEVEL:
		var slot := TextureRect.new()
		slot.texture = load(BuildingUpgradeData.ICON_PATHS[id])
		slot.custom_minimum_size = Vector2(TRACK_ICON_SIZE, TRACK_ICON_SIZE)
		slot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		slot.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		slot.modulate = Color.WHITE if i < level else Color(1, 1, 1, ICON_DIM_ALPHA)
		if i == level - 1:
			slot.add_child(_build_current_marker())
		track.add_child(slot)
	return track


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
	var level: int = SaveManager.get_building_upgrade_level(id)
	if level >= BuildingUpgradeData.MAX_LEVEL:
		return ButtonBuilder.create_body_label(TranslationManager.t("skill_max"), 16)
	var cost: int = BuildingUpgradeData.upgrade_cost(id, level)
	var btn := ButtonBuilder.create_small_button(
		"%s %dg" % [TranslationManager.t("skill_upgrade"), cost], 200, 34
	)
	btn.disabled = SaveManager.gold < cost
	btn.pressed.connect(_show_upgrade_confirm.bind(id))
	btn.pressed.connect(ClickPlayer.play_select_3)
	return btn


func _show_upgrade_confirm(id: String) -> void:
	if get_node_or_null("BuildingUpgradeConfirmOverlay") != null:
		return
	var level: int = SaveManager.get_building_upgrade_level(id)
	if level >= BuildingUpgradeData.MAX_LEVEL:
		return
	var cost: int = BuildingUpgradeData.upgrade_cost(id, level)
	var window := get_window()
	if window == null:
		window = get_viewport()
	var overlay := ColorRect.new()
	overlay.name = "BuildingUpgradeConfirmOverlay"
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
		TranslationManager.t("building_upgrade_confirm").replace(
			"{name}", TranslationManager.t(BuildingUpgradeData.NAME_KEYS[id])
		), 22
	)
	title.position = Vector2(20, 12)
	title.size = Vector2(POPUP_W - 40, 50)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	panel.add_child(title)

	var next_status := ButtonBuilder.create_body_label(
		"%s\n%s" % [
			TranslationManager.t("building_effect_next"),
			_next_effect_text(id, level + 1),
		],
		16
	)
	next_status.name = "NextLevelStatus"
	next_status.position = Vector2(24, 70)
	next_status.size = Vector2(POPUP_W - 48, 132)
	next_status.add_theme_color_override("font_color", Color.CHARTREUSE)
	next_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(next_status)

	var left_x := (POPUP_W - BUTTON_W * 2 - 20.0) / 2.0
	var btn_y := POPUP_H - 76.0
	var cancel_btn := ButtonBuilder.create_menu_button(
		TranslationManager.t("cancel"), BUTTON_W, BUTTON_H
	)
	cancel_btn.position = Vector2(left_x, btn_y)
	cancel_btn.pressed.connect(overlay.queue_free)
	cancel_btn.pressed.connect(ClickPlayer.play_select_4)
	panel.add_child(cancel_btn)

	var ok_btn := ButtonBuilder.create_menu_button(
		"%s %dg" % [TranslationManager.t("ok"), cost], BUTTON_W, BUTTON_H
	)
	ok_btn.position = Vector2(left_x + BUTTON_W + 20.0, btn_y)
	ok_btn.disabled = SaveManager.gold < cost
	ok_btn.pressed.connect(func() -> void: SaveManager.upgrade_building(id))
	ok_btn.pressed.connect(ClickPlayer.play_select_3)
	ok_btn.pressed.connect(overlay.queue_free)
	panel.add_child(ok_btn)


func _effect_text(id: String) -> String:
	var level: int = SaveManager.get_building_upgrade_level(id)
	var label := TranslationManager.t(BuildingUpgradeData.effect_label_key(id))
	return _effect_text_for_level(id, level, label)


func _next_effect_text(id: String, level: int) -> String:
	var label := TranslationManager.t(BuildingUpgradeData.effect_label_key(id))
	var status := _effect_text_for_level(id, level, label)
	var details := _details_text(id, level)
	if not details.is_empty():
		return "%s\n%s" % [status, details]
	return status


func _effect_text_for_level(id: String, level: int, label: String) -> String:
	var current := _fmt(BuildingUpgradeData.current_effect(id, level))
	if id == "pendopo":
		var heal_label := TranslationManager.t("building_effect_heal")
		var current_heal := _fmt(ProgressionData.pendopo_heal(level))
		return "%s: %s, %s: +%s/s" % [label, current, heal_label, current_heal]
	var suffix := BuildingUpgradeData.effect_suffix(id)
	return "%s: %s%s" % [label, current, suffix]


func _details_text(id: String, level: int) -> String:
	match id:
		"pendopo":
			return "%s: +%s/s" % [
				TranslationManager.t("building_effect_heal"),
				_fmt(ProgressionData.pendopo_heal(level)),
			]
		"menara":
			return "%s: %s" % [
				TranslationManager.t("building_effect_range"),
				_fmt(ProgressionData.tower_range(level)),
			]
		"barak":
			var lines: PackedStringArray = []
			for troop_type in ["infantry", "archer"]:
				var stats: Dictionary = ProgressionData.troop_stats(troop_type, level)
				lines.append("%s  HP %s  ATK %s  DEF %s" % [
					TranslationManager.t("troop_%s" % troop_type),
					_fmt(float(stats["hp"])),
					_fmt(float(stats["attack"])),
					_fmt(float(stats["defense"])),
				])
			return "\n".join(lines)
	return ""


func _fmt(value: float) -> String:
	if is_equal_approx(value, floorf(value)):
		return str(int(value))
	return "%.2f" % value


func _on_state_changed(_value: int = 0) -> void:
	for id: String in _upgrade_buttons:
		var cost := BuildingUpgradeData.upgrade_cost(
			id, SaveManager.get_building_upgrade_level(id)
		)
		(_upgrade_buttons[id] as Button).disabled = SaveManager.gold < cost


func _on_building_changed(_id: String, _level: int) -> void:
	_build_rows()


func close_popups() -> void:
	_free_window_popup()


func _free_window_popup() -> void:
	var window := get_window()
	if window == null:
		window = get_viewport()
	var overlay := window.get_node_or_null("BuildingUpgradeConfirmOverlay")
	if overlay != null:
		overlay.queue_free()
