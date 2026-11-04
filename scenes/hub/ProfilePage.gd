class_name ProfilePage extends Control

const SLOT_SIZE := 132
const SLOT_GAP := 12

const STATUS_LABEL_X := 24.0
const STATUS_VALUE_X := 96.0
const STATUS_COLUMN_WIDTH := 190.0
const STATUS_ROW_HEIGHT := 26.0
const STATUS_AREA_HEIGHT := 26.0 * 3.0

const PICKER_WIDTH := 420
const PICKER_HEIGHT := 560
const PICKER_ITEMS_PER_PAGE := 5
const PICKER_ITEM_HEIGHT := 72

const POSITIVE_STAT_COLOR := Color(0.45, 0.9, 0.45)
const NEGATIVE_STAT_COLOR := Color(0.95, 0.35, 0.35)

var title_background_rect := Rect2(150.0, 0.0, 208.0, 80.0)

var _content: Control
var _title_label: Label
var _title_subtitle: Label
var _picker: Control
var _picker_slot: String
var _picker_choices: Array[Dictionary] = []
var _picker_page: int = 0
var _picker_list: VBoxContainer
var _picker_prev: Button
var _picker_next: Button
var _picker_page_label: Label


func _ready() -> void:
	_setup_ui()
	TranslationManager.language_changed.connect(_on_language_changed)


func _exit_tree() -> void:
	close_popups()


func _setup_ui() -> void:
	_content = Control.new()
	add_child(_content)
	_content.anchor_right = 1.0
	_content.anchor_bottom = 1.0
	_content.offset_left = 12.0
	_content.offset_top = 12.0
	_content.offset_right = -12.0
	_content.offset_bottom = -12.0

	_build_profile_content()


func _build_profile_content() -> void:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	_content.add_child(col)
	col.anchor_right = 1.0
	col.anchor_bottom = 1.0
	col.offset_top = 4.0

	var king_data: Dictionary = SaveManager.heroes.get("gatotkaca", {}) as Dictionary
	var level: int = int(king_data.get("level", 1))
	var stars: int = int(king_data.get("stars", 1))

	var title_banner := Control.new()
	title_banner.custom_minimum_size = Vector2(0, 80)
	title_banner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(title_banner)

	var title_background := TextureRect.new()
	title_background.name = "TitleBackground"
	title_background.texture = load("res://assets/sprites/backgrounds/title.png")
	title_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	title_background.stretch_mode = TextureRect.STRETCH_SCALE
	title_background.position = title_background_rect.position
	title_background.size = title_background_rect.size
	title_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_banner.add_child(title_background)

	var level_indicator_background := TextureRect.new()
	level_indicator_background.name = "LevelIndicatorBackground"
	level_indicator_background.texture = load("res://assets/sprites/backgrounds/level.png")
	level_indicator_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	level_indicator_background.stretch_mode = TextureRect.STRETCH_SCALE
	level_indicator_background.position = Vector2(2, -8)
	level_indicator_background.size = Vector2(115, 87)
	level_indicator_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_banner.add_child(level_indicator_background)

	var level_indicator := Label.new()
	level_indicator.name = "LevelIndicator"
	level_indicator.text = "Lv.%d" % level
	level_indicator.position = Vector2(28, 24)
	level_indicator.size = Vector2(60, 38)
	level_indicator.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_indicator.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	level_indicator.add_theme_font_size_override("font_size", 30)
	level_indicator.add_theme_color_override("font_color", Color.WHITE)
	level_indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_banner.add_child(level_indicator)

	_title_label = ButtonBuilder.create_title_label("GATOTKACA", 28)
	_title_label.name = "ProfileTitle"
	_title_label.position = Vector2(174, 22)
	_title_label.size = Vector2(160, 26)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 20)
	_title_label.add_theme_color_override("font_color", Color.BLACK)
	title_banner.add_child(_title_label)

	_title_subtitle = ButtonBuilder.create_body_label(
		TranslationManager.t("main_title_subtitle"), 16
	)
	_title_subtitle.name = "ProfileTitleSubtitle"
	_title_subtitle.position = Vector2(174, 42)
	_title_subtitle.size = Vector2(160, 19)
	_title_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_subtitle.add_theme_font_size_override("font_size", 16)
	title_banner.add_child(_title_subtitle)

	var xp_bar := ProgressBar.new()
	xp_bar.name = "KingXPBar"
	xp_bar.custom_minimum_size = Vector2(0, 10)
	var at_max_level: bool = level >= ProgressionData.MAX_KING_LEVEL
	var xp_to_next: int = ProgressionData.xp_to_next(level)
	var xp_now: int = int(king_data.get("xp", 0))
	xp_bar.max_value = maxf(xp_to_next, 1.0)
	xp_bar.value = 1.0 if at_max_level else xp_now
	xp_bar.show_percentage = false
	ButtonBuilder.style_progress_bar(xp_bar, Color(0.85, 0.65, 0.2), Color(0.45, 0.27, 0.12))
	col.add_child(xp_bar)

	var xp_label := ButtonBuilder.create_body_label(
		TranslationManager.t("xp_maximum")
		if at_max_level else "EXP: %d / %d" % [xp_now, xp_to_next],
		16
	)
	xp_label.name = "KingXPLabel"
	col.add_child(xp_label)

	col.add_child(ButtonBuilder.create_stat_label(TranslationManager.t("profile_accessories_title") + " :", 22))

	var head_row := Control.new()
	head_row.custom_minimum_size = Vector2(0, SLOT_SIZE)
	var head_slot_container := CenterContainer.new()
	head_slot_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	head_slot_container.offset_top = -5
	head_slot_container.offset_bottom = -5
	head_slot_container.add_child(_build_slot("head", TranslationManager.t("profile_head")))
	head_row.add_child(head_slot_container)
	col.add_child(head_row)

	var gear_row := Control.new()
	gear_row.custom_minimum_size = Vector2(0, SLOT_SIZE)
	var gear_slot_container := HBoxContainer.new()
	gear_slot_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	gear_slot_container.offset_top = -5
	gear_slot_container.offset_bottom = -5
	gear_slot_container.alignment = BoxContainer.ALIGNMENT_CENTER
	gear_slot_container.add_theme_constant_override("separation", SLOT_GAP)
	gear_slot_container.add_child(_build_slot("right_hand", TranslationManager.t("profile_right_hand")))
	gear_slot_container.add_child(_build_slot("body", TranslationManager.t("profile_body")))
	gear_slot_container.add_child(_build_slot("left_hand", TranslationManager.t("profile_left_hand")))
	gear_row.add_child(gear_slot_container)
	col.add_child(gear_row)

	var status_panel := PanelContainer.new()
	status_panel.name = "StatusPanel"
	var status_style := StyleBoxFlat.new()
	status_style.bg_color = Color(0, 0, 0, 0.4)
	status_style.set_corner_radius_all(6)
	status_style.set_content_margin_all(10)
	status_panel.add_theme_stylebox_override("panel", status_style)
	col.add_child(status_panel)

	var status_box := VBoxContainer.new()
	status_box.add_theme_constant_override("separation", 6)
	status_panel.add_child(status_box)

	status_box.add_child(_make_status_text("STATUS :", 22))

	var status_grid := Control.new()
	status_grid.custom_minimum_size = Vector2(0, STATUS_AREA_HEIGHT)
	status_box.add_child(status_grid)

	var base_stats: Dictionary = ProgressionData.king_stats(level, stars)
	base_stats.merge(ProgressionData.gatotkaca_stats(SaveManager.stage_number), true)
	var final_stats: Dictionary = EquipmentDatabase.apply_to_stats(base_stats, SaveManager.equipment)
	var hp_base: int = floori(float(base_stats["hp"]))
	var atk_base: int = floori(float(base_stats["attack"]))
	var mp_base: int = floori(float(base_stats["mana_max"]))
	var def_base: int = floori(float(base_stats["defense"]))
	var sta_base: int = floori(float(base_stats["stamina_max"]))
	_place_status(status_grid, "HP", hp_base, floori(float(final_stats["hp"])) - hp_base, 0)
	_place_status(status_grid, "ATK", atk_base, floori(float(final_stats["attack"])) - atk_base, 0, 1)
	_place_status(status_grid, "MP", mp_base, floori(float(final_stats["mana_max"])) - mp_base, 1)
	_place_status(status_grid, "DEF", def_base, floori(float(final_stats["defense"])) - def_base, 1, 1)
	_place_status(status_grid, "STA", sta_base, floori(float(final_stats["stamina_max"])) - sta_base, 2)


func _refresh() -> void:
	for child in _content.get_children():
		_content.remove_child(child)
		child.queue_free()
	_build_profile_content()


func _on_language_changed(_lang: String) -> void:
	_title_subtitle.text = TranslationManager.t("main_title_subtitle")


func _place_status(
	grid: Control, label: String, base_value: int, bonus: int, row: int, col: int = 0
) -> void:
	var y := float(row) * STATUS_ROW_HEIGHT
	var label_node := _make_status_text(label, 18)
	label_node.position = Vector2(float(col) * STATUS_COLUMN_WIDTH + STATUS_LABEL_X, y)
	grid.add_child(label_node)

	var base_text := str(base_value)
	var value_text := base_text
	var baseline_shift := 0.0
	if bonus != 0:
		var bonus_text := ("+" if bonus > 0 else "") + str(bonus)
		var bonus_color := POSITIVE_STAT_COLOR if bonus > 0 else NEGATIVE_STAT_COLOR
		value_text += "[color=#%s]%s[/color]" % [bonus_color.to_html(false), bonus_text]
		var font := label_node.get_theme_font("font")
		baseline_shift = (
			_status_line_ascent(base_text + bonus_text, font)
			- _status_line_ascent(base_text, font)
		)

	var value_node := RichTextLabel.new()
	value_node.name = "Stat_" + label
	value_node.position = Vector2(
		float(col) * STATUS_COLUMN_WIDTH + STATUS_VALUE_X, y - baseline_shift
	)
	value_node.bbcode_enabled = true
	value_node.fit_content = true
	value_node.scroll_active = false
	value_node.autowrap_mode = TextServer.AUTOWRAP_OFF
	value_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	value_node.add_theme_font_size_override("normal_font_size", 18)
	value_node.add_theme_color_override("default_color", Color(0.95, 0.85, 0.65, 1))
	value_node.text = value_text
	grid.add_child(value_node)


func _status_line_ascent(text: String, font: Font) -> float:
	var line := TextLine.new()
	line.add_string(text, font, 18)
	return line.get_line_ascent()


func _make_status_text(text: String, size: int) -> Label:
	var label := ButtonBuilder.create_stat_label(text, size)
	label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.65, 1))
	return label


func _build_slot(slot: String, label: String) -> Panel:
	var panel := ButtonBuilder.create_panel(SLOT_SIZE, SLOT_SIZE)
	panel.name = "Slot_" + slot
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	var slot_label := ButtonBuilder.create_stat_label(label, 18)
	slot_label.add_theme_color_override("font_color", Color.YELLOW)
	slot_label.position = Vector2(0, 5)
	slot_label.size = Vector2(SLOT_SIZE, 22)
	slot_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(slot_label)

	var sep := HSeparator.new()
	sep.position = Vector2(12, 24)
	sep.size = Vector2(SLOT_SIZE - 24, 4)
	panel.add_child(sep)

	var equipped_id: String = SaveManager.get_equipped(slot)
	var icon_texture: Texture2D = null
	if not equipped_id.is_empty():
		var item: Dictionary = EquipmentDatabase.get_item(equipped_id)
		if not item.is_empty():
			icon_texture = load(String(item.get("icon", ""))) as Texture2D

	var icon := TextureRect.new()
	icon.name = "ItemIcon"
	icon.position = Vector2((SLOT_SIZE - 56) / 2.0, 28)
	icon.size = Vector2(56, 56)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = icon_texture
	icon.visible = icon_texture != null
	panel.add_child(icon)

	var name_label := Label.new()
	name_label.name = "ItemName"
	name_label.text = TranslationManager.t("profile_empty").to_upper()
	name_label.visible = equipped_id.is_empty()
	name_label.position = Vector2(6, 82)
	name_label.size = Vector2(SLOT_SIZE - 12, 20)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.add_theme_color_override("font_color", Color(0.5, 0.45, 0.35))
	panel.add_child(name_label)

	var btn := ButtonBuilder.create_small_button(TranslationManager.t("profile_change"), 92, 28)
	btn.name = "ChangeButton"
	btn.add_theme_font_size_override("font_size", 16)
	btn.position = Vector2((SLOT_SIZE - 92) / 2.0, 100)
	btn.pressed.connect(_show_equip_picker.bind(slot, label))
	btn.pressed.connect(ClickPlayer.play_select_3)
	panel.add_child(btn)

	return panel


func _show_equip_picker(slot: String, slot_label: String) -> void:
	var window := get_window()
	if window == null:
		window = get_viewport()
	var old_picker := window.get_node_or_null("EquipPicker")
	if old_picker != null:
		old_picker.queue_free()

	var picker := Control.new()
	picker.name = "EquipPicker"
	picker.set_anchors_preset(Control.PRESET_FULL_RECT)
	picker.mouse_filter = Control.MOUSE_FILTER_STOP
	window.add_child(picker)
	_picker = picker
	_picker_slot = slot
	_picker_page = 0

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.8)
	picker.add_child(bg)

	var panel := ButtonBuilder.create_panel(PICKER_WIDTH, PICKER_HEIGHT)
	panel.name = "EquipPickerPanel"
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -PICKER_WIDTH / 2.0
	panel.offset_right = PICKER_WIDTH / 2.0
	panel.offset_top = -PICKER_HEIGHT / 2.0
	panel.offset_bottom = PICKER_HEIGHT / 2.0
	picker.add_child(panel)

	var title := ButtonBuilder.create_title_label(slot_label, 24)
	title.name = "PickerTitle"
	title.position = Vector2(14, 8)
	title.size = Vector2(280, 32)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	panel.add_child(title)

	var close := ButtonBuilder.create_small_button(TranslationManager.t("close"), 84, 30)
	close.name = "PickerClose"
	close.position = Vector2(PICKER_WIDTH - 98, 10)
	close.pressed.connect(_close_equip_picker)
	close.pressed.connect(ClickPlayer.play_select_4)
	panel.add_child(close)

	_picker_list = VBoxContainer.new()
	_picker_list.name = "PickerList"
	_picker_list.position = Vector2(14, 50)
	_picker_list.size = Vector2(PICKER_WIDTH - 28, 400)
	_picker_list.add_theme_constant_override("separation", 8)
	panel.add_child(_picker_list)

	_picker_choices.clear()
	for item: Dictionary in EquipmentDatabase.get_all():
		if not EquipmentDatabase.item_fits_slot(item, slot):
			continue
		if SaveManager.get_inventory_count(String(item["id"])) <= 0:
			continue
		_picker_choices.append(item)

	_picker_prev = ButtonBuilder.create_small_button(
		TranslationManager.t("prev"), 94, 30
	)
	_picker_prev.name = "PickerPrev"
	_picker_prev.position = Vector2(14, 462)
	_picker_prev.add_theme_font_size_override("font_size", 15)
	_picker_prev.pressed.connect(_change_picker_page.bind(-1))
	_picker_prev.pressed.connect(ClickPlayer.play_select_3)
	panel.add_child(_picker_prev)

	_picker_page_label = Label.new()
	_picker_page_label.name = "PickerPageLabel"
	_picker_page_label.position = Vector2(116, 462)
	_picker_page_label.size = Vector2(PICKER_WIDTH - 232, 30)
	_picker_page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_picker_page_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_picker_page_label.add_theme_font_size_override("font_size", 15)
	panel.add_child(_picker_page_label)

	_picker_next = ButtonBuilder.create_small_button(
		TranslationManager.t("next"), 94, 30
	)
	_picker_next.name = "PickerNext"
	_picker_next.position = Vector2(PICKER_WIDTH - 108, 462)
	_picker_next.add_theme_font_size_override("font_size", 15)
	_picker_next.pressed.connect(_change_picker_page.bind(1))
	_picker_next.pressed.connect(ClickPlayer.play_select_3)
	panel.add_child(_picker_next)

	var unequip := ButtonBuilder.create_small_button(
		TranslationManager.t("blacksmith_unequip"), PICKER_WIDTH - 28, 34
	)
	unequip.name = "PickerUnequip"
	unequip.position = Vector2(14, PICKER_HEIGHT - 46)
	unequip.disabled = SaveManager.get_equipped(slot).is_empty()
	unequip.pressed.connect(_unequip_from_picker.bind(slot))
	unequip.pressed.connect(ClickPlayer.play_select_3)
	panel.add_child(unequip)
	_show_picker_page()


func _change_picker_page(direction: int) -> void:
	var total_pages := ceili(float(_picker_choices.size()) / PICKER_ITEMS_PER_PAGE)
	_picker_page = clampi(_picker_page + direction, 0, maxi(total_pages - 1, 0))
	_show_picker_page()


func _show_picker_page() -> void:
	if _picker_list == null:
		return
	for child in _picker_list.get_children():
		_picker_list.remove_child(child)
		child.queue_free()

	if _picker_choices.is_empty():
		_picker_list.add_child(_make_status_text(
			TranslationManager.t("blacksmith_no_items"), 16
		))
		_picker_page_label.text = "1 / 1"
		_picker_prev.visible = false
		_picker_next.visible = false
		_picker_page_label.visible = false
		return

	var start := _picker_page * PICKER_ITEMS_PER_PAGE
	var end := mini(start + PICKER_ITEMS_PER_PAGE, _picker_choices.size())
	for index in range(start, end):
		_picker_list.add_child(_build_choice_button(
			_picker_slot, _picker_choices[index]
		))

	var total_pages := maxi(
		1, ceili(float(_picker_choices.size()) / PICKER_ITEMS_PER_PAGE)
	)
	var has_pages := total_pages > 1
	_picker_prev.visible = has_pages
	_picker_next.visible = has_pages
	_picker_page_label.visible = has_pages
	_picker_page_label.text = "%d / %d" % [_picker_page + 1, total_pages]
	_picker_prev.disabled = _picker_page <= 0
	_picker_next.disabled = _picker_page >= total_pages - 1


func _build_choice_button(slot: String, item: Dictionary) -> Button:
	var item_id := String(item["id"])
	var btn := ButtonBuilder.create_small_button("", PICKER_WIDTH - 32, PICKER_ITEM_HEIGHT)
	btn.name = "Choice_" + item_id
	btn.custom_minimum_size = Vector2(PICKER_WIDTH - 32, PICKER_ITEM_HEIGHT)

	var content := HBoxContainer.new()
	content.name = "ChoiceContent"
	content.position = Vector2(10, 5)
	content.size = Vector2(PICKER_WIDTH - 52, PICKER_ITEM_HEIGHT - 10)
	content.add_theme_constant_override("separation", 10)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(content)

	var icon := TextureRect.new()
	icon.name = "ItemIcon"
	icon.custom_minimum_size = Vector2(56, 56)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = load(String(item.get("icon", ""))) as Texture2D
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(icon)

	var info := VBoxContainer.new()
	info.name = "ItemInfo"
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	info.add_theme_constant_override("separation", 1)
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(info)

	var heading := HBoxContainer.new()
	heading.name = "ChoiceHeading"
	heading.add_theme_constant_override("separation", 6)
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_child(heading)

	var name_label := Label.new()
	name_label.name = "ItemName"
	name_label.text = TranslationManager.item_name(item)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override("font_size", 15)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	heading.add_child(name_label)

	if SaveManager.get_equipped(slot) == item_id:
		var equipped_label := Label.new()
		equipped_label.name = "EquippedLabel"
		equipped_label.text = "[%s]" % TranslationManager.t("blacksmith_equipped")
		equipped_label.add_theme_font_size_override("font_size", 15)
		equipped_label.add_theme_color_override("font_color", POSITIVE_STAT_COLOR)
		equipped_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		heading.add_child(equipped_label)

	var stats_label := Label.new()
	stats_label.name = "ItemEffects"
	stats_label.text = EquipmentDatabase.format_stats(item)
	stats_label.add_theme_font_size_override("font_size", 13)
	stats_label.add_theme_color_override("font_color", Color(0.9, 0.8, 0.55))
	stats_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_child(stats_label)

	btn.pressed.connect(_choose_item.bind(slot, item_id))
	btn.pressed.connect(ClickPlayer.play_select_3)
	return btn


func _choose_item(slot: String, item_id: String) -> void:
	if SaveManager.equip_item(slot, item_id):
		_close_equip_picker()
		_refresh()


func _unequip_from_picker(slot: String) -> void:
	if SaveManager.unequip_slot(slot):
		_close_equip_picker()
		_refresh()


func close_popups() -> void:
	_close_equip_picker()


func _close_equip_picker() -> void:
	var window := get_window()
	if window == null:
		window = get_viewport()
	var picker := window.get_node_or_null("EquipPicker")
	if picker != null:
		picker.queue_free()
	_picker = null
	_picker_list = null
	_picker_prev = null
	_picker_next = null
	_picker_page_label = null
