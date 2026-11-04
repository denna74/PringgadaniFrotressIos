extends Control

const PANEL_WIDTH := 512
const CARD_WIDTH := 500
const CARD_HEIGHT := 120
const ICON_SIZE := 96
const TAB_HEIGHT := 35
const ITEMS_PER_PAGE := 4
const CARDS_Y := 64
const PAGINATION_Y := 575
const PAGINATION_BUTTON_SIZE := Vector2(140, 46)
const POPUP_W := 420
const POPUP_H := 240

var _cards_container: VBoxContainer = null
var _filter: String = "head"
var _tabs: Dictionary = {}
var _filtered_items: Array[Dictionary] = []
var _current_page: int = 0
var _prev_btn: Button
var _next_btn: Button
var _page_label: Label


func _ready() -> void:
	_setup_ui()
	_build_items()
	SaveManager.gold_changed.connect(_refresh)


func _setup_ui() -> void:
	var tabs := HBoxContainer.new()
	tabs.position = Vector2(30, 20)
	tabs.size = Vector2(PANEL_WIDTH, TAB_HEIGHT)
	tabs.add_theme_constant_override("separation", 20)
	add_child(tabs)

	var tab_data := [
		["head", "blacksmith_tab_head"],
		["hand", "blacksmith_tab_hand"],
		["body", "blacksmith_tab_body"],
	]
	for entry: Array in tab_data:
		var tab := ButtonBuilder.create_small_button(
			TranslationManager.t(entry[1]), 156, TAB_HEIGHT
		)
		tab.add_theme_color_override("font_color", Color.YELLOW)
		tab.add_theme_font_size_override("font_size", 22)
		tab.name = "Tab_" + entry[0]
		tab.pressed.connect(_set_filter.bind(entry[0]))
		tab.pressed.connect(ClickPlayer.play_select_3)
		_tabs[entry[0]] = tab
		tabs.add_child(tab)
	_update_tab_styles()

	_cards_container = VBoxContainer.new()
	_cards_container.position = Vector2(20, CARDS_Y)
	_cards_container.size = Vector2(PANEL_WIDTH, CARD_HEIGHT * ITEMS_PER_PAGE + 12 * (ITEMS_PER_PAGE - 1))
	_cards_container.add_theme_constant_override("separation", 8)
	_cards_container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	add_child(_cards_container)

	var pagination := HBoxContainer.new()
	pagination.position = Vector2(20, PAGINATION_Y)
	pagination.size = Vector2(PANEL_WIDTH, PAGINATION_BUTTON_SIZE.y)
	pagination.alignment = BoxContainer.ALIGNMENT_CENTER
	pagination.add_theme_constant_override("separation", 14)
	add_child(pagination)

	_prev_btn = ButtonBuilder.create_small_button(TranslationManager.t("prev"), int(PAGINATION_BUTTON_SIZE.x), int(PAGINATION_BUTTON_SIZE.y))
	_prev_btn.name = "BlacksmithPrev"
	_prev_btn.add_theme_font_size_override("font_size", 20)
	_prev_btn.pressed.connect(_on_prev_page)
	_prev_btn.pressed.connect(ClickPlayer.play_select_3)
	pagination.add_child(_prev_btn)

	_page_label = Label.new()
	_page_label.name = "BlacksmithPageLabel"
	_page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_page_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_page_label.custom_minimum_size = Vector2(80, PAGINATION_BUTTON_SIZE.y)
	_page_label.add_theme_font_size_override("font_size", 16)
	_page_label.add_theme_color_override("font_color", Color(0.9, 0.8, 0.55))
	pagination.add_child(_page_label)

	_next_btn = ButtonBuilder.create_small_button(TranslationManager.t("next"), int(PAGINATION_BUTTON_SIZE.x), int(PAGINATION_BUTTON_SIZE.y))
	_next_btn.name = "BlacksmithNext"
	_next_btn.add_theme_font_size_override("font_size", 20)
	_next_btn.pressed.connect(_on_next_page)
	_next_btn.pressed.connect(ClickPlayer.play_select_3)
	pagination.add_child(_next_btn)


func _set_filter(filter_name: String) -> void:
	_filter = filter_name
	_current_page = 0
	_update_tab_styles()
	_build_items()


func _update_tab_styles() -> void:
	for filter_name: String in _tabs:
		var tab: Button = _tabs[filter_name]
		var selected: bool = filter_name == _filter
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.58, 0.34, 0.1, 0.98) if selected else Color(0.3, 0.18, 0.08, 0.9)
		style.border_width_top = 2 if selected else 1
		style.border_width_bottom = 2 if selected else 1
		style.border_width_left = 2 if selected else 1
		style.border_width_right = 2 if selected else 1
		style.border_color = Color(1.0, 0.76, 0.28, 1.0) if selected else Color(0.5, 0.3, 0.1, 1.0)
		style.corner_radius_top_left = 3
		style.corner_radius_top_right = 3
		style.corner_radius_bottom_left = 3
		style.corner_radius_bottom_right = 3
		tab.add_theme_stylebox_override("normal", style)
		tab.add_theme_stylebox_override("hover", style)
		tab.add_theme_stylebox_override("pressed", style)


func _get_total_pages() -> int:
	if _filtered_items.is_empty():
		return 1
	return int(ceil(float(_filtered_items.size()) / float(ITEMS_PER_PAGE)))


func _on_prev_page() -> void:
	if _current_page > 0:
		_current_page -= 1
		_show_current_page()


func _on_next_page() -> void:
	var total := _get_total_pages()
	if _current_page < total - 1:
		_current_page += 1
		_show_current_page()


func _build_items() -> void:
	_filtered_items = EquipmentDatabase.get_by_type(_filter)
	_current_page = clampi(_current_page, 0, max(0, _get_total_pages() - 1))
	_show_current_page()


func _show_current_page() -> void:
	for child in _cards_container.get_children():
		_cards_container.remove_child(child)
		child.queue_free()

	var start := _current_page * ITEMS_PER_PAGE
	var end := min(start + ITEMS_PER_PAGE, _filtered_items.size())
	for i in range(start, end):
		var item: Dictionary = _filtered_items[i]
		_cards_container.add_child(_build_item_card(item))

	var total := _get_total_pages()
	if _page_label != null:
		_page_label.text = "%d / %d" % [_current_page + 1, total]
	if _prev_btn != null:
		_prev_btn.disabled = _current_page <= 0
	if _next_btn != null:
		_next_btn.disabled = _current_page >= total - 1


func _build_item_card(item: Dictionary) -> Panel:
	var panel := ButtonBuilder.create_panel(CARD_WIDTH, CARD_HEIGHT)
	panel.name = "ItemCard_" + String(item["id"])
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.position = Vector2(10, 10)
	icon.size = Vector2(ICON_SIZE, ICON_SIZE)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = load(String(item.get("icon", ""))) as Texture2D
	panel.add_child(icon)

	var info := VBoxContainer.new()
	info.position = Vector2(116, 8)
	info.size = Vector2(CARD_WIDTH - 132, CARD_HEIGHT - 16)
	info.add_theme_constant_override("separation", 3)
	panel.add_child(info)

	var color := EquipmentDatabase.get_rarity_color(item.get("rarity", "common"))
	var owned: bool = SaveManager.get_inventory_count(String(item["id"])) > 0

	var header := HBoxContainer.new()
	header.name = "CardHeader"
	header.add_theme_constant_override("separation", 6)
	info.add_child(header)

	var name_label := _make_label(TranslationManager.item_name(item), 21, color)
	name_label.name = "NameLabel"
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.size_flags_vertical = Control.SIZE_FILL
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(name_label)

	if owned:
		var owned_label := _make_label(
			TranslationManager.t("blacksmith_owned"), 21, Color(0.55, 0.85, 0.45)
		)
		owned_label.name = "OwnedLabel"
		owned_label.size_flags_vertical = Control.SIZE_FILL
		owned_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		header.add_child(owned_label)
	else:
		var price: int = int(item.get("price", 0))
		var can_buy: bool = SaveManager.gold >= price
		var buy_btn := ButtonBuilder.create_small_button(
			TranslationManager.t("market_buy").replace("{p}", str(price)), 120, 30)
		buy_btn.add_theme_font_size_override("font_size", 16)
		buy_btn.name = "BuyButton"
		buy_btn.disabled = not can_buy
		if can_buy:
			buy_btn.pressed.connect(_show_buy_confirm.bind(item))
			buy_btn.pressed.connect(ClickPlayer.play_select_3)
		header.add_child(buy_btn)

	var rarity: String = String(item.get("rarity", "common")).capitalize()
	var type_label := _make_label(
		"%s" % [rarity], 21, Color(0.72, 0.6, 0.4)
	)
	info.add_child(type_label)

	var stats_label := _make_label(EquipmentDatabase.format_stats(item), 21, Color(0.9, 0.8, 0.55))
	stats_label.name = "StatsLabel"
	info.add_child(stats_label)

	return panel


func _make_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _slot_text(item: Dictionary) -> String:
	match String(item.get("type", "")):
		"head":
			return TranslationManager.t("blacksmith_tab_head")
		"body":
			return TranslationManager.t("blacksmith_tab_body")
		"hand":
			return TranslationManager.t("profile_hand")
	return String(item.get("type", "")).capitalize()


func _equipped_slot(item_id: String) -> String:
	for slot: String in SaveManager.EQUIPMENT_SLOTS:
		if SaveManager.get_equipped(slot) == item_id:
			return slot
	return ""


func _toggle_equip(item: Dictionary) -> void:
	var item_id := String(item["id"])
	var equipped_in := _equipped_slot(item_id)
	if not equipped_in.is_empty():
		SaveManager.unequip_slot(equipped_in)
		_refresh()
		return

	var slot := ""
	match String(item.get("type", "")):
		"head":
			slot = "head"
		"body":
			slot = "body"
		"hand":
			if SaveManager.get_equipped("right_hand").is_empty():
				slot = "right_hand"
			elif SaveManager.get_equipped("left_hand").is_empty():
				slot = "left_hand"
			else:
				slot = "right_hand"
	if not slot.is_empty():
		SaveManager.equip_item(slot, item_id)
		_refresh()


func _buy_item(item_id: String, price: int) -> void:
	if SaveManager.spend_gold(price):
		SaveManager.add_to_inventory(item_id)
		_refresh()


func _show_buy_confirm(item: Dictionary) -> void:
	var window := get_window()
	if window == null:
		window = get_viewport()
	if window.get_node_or_null("BuyConfirmOverlay") != null:
		return

	var overlay := ColorRect.new()
	overlay.name = "BuyConfirmOverlay"
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
		TranslationManager.t("market_buy_confirm").replace(
			"{name}", TranslationManager.item_name(item)), 22)
	title.name = "ConfirmationTitle"
	title.position = Vector2(20, 18)
	title.size = Vector2(POPUP_W - 40, 76)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	panel.add_child(title)

	var confirm_btn := ButtonBuilder.create_menu_button(
		"%s %dG" % [TranslationManager.t("ok"), item.get("price", 0)]
		, 170, 48
	)
	confirm_btn.name = "ConfirmBuyButton"
	confirm_btn.position = Vector2(POPUP_W - 190, POPUP_H - 64)
	confirm_btn.pressed.connect(_buy_item.bind(
		String(item["id"]), int(item.get("price", 0))))
	confirm_btn.pressed.connect(ClickPlayer.play_select_3)
	confirm_btn.pressed.connect(overlay.queue_free)
	panel.add_child(confirm_btn)

	var cancel_btn := ButtonBuilder.create_menu_button(
		TranslationManager.t("cancel"), 170, 48)
	cancel_btn.name = "CancelBuyButton"
	cancel_btn.position = Vector2(20, POPUP_H - 64)
	cancel_btn.pressed.connect(overlay.queue_free)
	cancel_btn.pressed.connect(ClickPlayer.play_select_4)
	panel.add_child(cancel_btn)


func _refresh(_value: int = 0) -> void:
	_build_items()


func close_popups() -> void:
	var window := get_window()
	if window == null:
		window = get_viewport()
	var overlay := window.get_node_or_null("BuyConfirmOverlay")
	if overlay != null:
		overlay.queue_free()
