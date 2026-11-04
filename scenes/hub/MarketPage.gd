extends Control

const PANEL_WIDTH := 512
const ITEMS_PER_CATEGORY := 3
const TAB_POSITION := Vector2(25,70)
const TAB_SIZE := Vector2(508, 35)
const TAB_WIDTH := 156
const TAB_GAP := 20
const ITEMS_POSITION := Vector2(20, 144)
const CARD_WIDTH := 500
const CARD_HEIGHT := 120
const CARD_GAP := 8
const ICON_SIZE := 96
const CARD_INFO_POSITION := Vector2(116, 8)
const CARD_INFO_SIZE := Vector2(CARD_WIDTH - 132, CARD_HEIGHT - 16)
const POPUP_W := 420
const POPUP_H := 260

var _items_container: VBoxContainer = null
var _filter: String = "heal"
var _tabs: Dictionary = {}
var _filtered_items: Array[Dictionary] = []


func _ready() -> void:
	_setup_ui()
	_build_items()
	SaveManager.gold_changed.connect(_refresh)


func _setup_ui() -> void:
	var tabs := HBoxContainer.new()
	tabs.name = "CategoryTabs"
	tabs.position = TAB_POSITION
	tabs.size = TAB_SIZE
	tabs.add_theme_constant_override("separation", TAB_GAP)
	add_child(tabs)

	var tab_data := [
		["heal", "market_tab_hp"],
		["mana", "market_tab_mp"],
		["stamina", "market_tab_stamina"],
	]
	for entry: Array in tab_data:
		var tab := ButtonBuilder.create_small_button(
			TranslationManager.t(entry[1]), TAB_WIDTH, int(TAB_SIZE.y))
		tab.name = "MarketTab_" + entry[0]
		tab.add_theme_font_size_override("font_size", 22)
		tab.pressed.connect(_set_filter.bind(entry[0]))
		tab.pressed.connect(ClickPlayer.play_select_3)
		_tabs[entry[0]] = tab
		tabs.add_child(tab)
	_update_tab_styles()

	_items_container = VBoxContainer.new()
	_items_container.name = "Items"
	_items_container.position = ITEMS_POSITION
	_items_container.size = Vector2(
		PANEL_WIDTH, CARD_HEIGHT * ITEMS_PER_CATEGORY + CARD_GAP * (ITEMS_PER_CATEGORY - 1))
	_items_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_items_container.add_theme_constant_override("separation", CARD_GAP)
	add_child(_items_container)


func _set_filter(filter_name: String) -> void:
	_filter = filter_name
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


func _build_items() -> void:
	_filtered_items.clear()
	for item in ConsumableDatabase.get_all():
		if String(item.get("effect", "")) == _filter:
			_filtered_items.append(item)
	_show_current_page()


func _show_current_page() -> void:
	for child in _items_container.get_children():
		_items_container.remove_child(child)
		child.queue_free()

	for item in _filtered_items:
		_items_container.add_child(_build_item_row(item))


func _build_item_row(item: Dictionary) -> Panel:
	var panel := ButtonBuilder.create_panel(CARD_WIDTH, CARD_HEIGHT)
	panel.name = "ItemRow_" + String(item["id"])
	panel.custom_minimum_size = Vector2(CARD_WIDTH, CARD_HEIGHT)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	var icon_path: String = item.get("icon", "")
	if not icon_path.is_empty():
		var icon := TextureRect.new()
		icon.name = "Icon"
		icon.position = Vector2(10, 10)
		icon.size = Vector2(ICON_SIZE, ICON_SIZE)
		icon.texture = load(icon_path)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(icon)

	var info := VBoxContainer.new()
	info.position = CARD_INFO_POSITION
	info.size = CARD_INFO_SIZE
	info.add_theme_constant_override("separation", 3)
	panel.add_child(info)

	var header := HBoxContainer.new()
	header.name = "CardHeader"
	header.add_theme_constant_override("separation", 6)
	info.add_child(header)

	var color := ConsumableDatabase.get_rarity_color(item.get("rarity", "common"))
	var name_lbl := Label.new()
	name_lbl.name = "NameLabel"
	name_lbl.text = TranslationManager.item_name(item)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.size_flags_vertical = Control.SIZE_FILL
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 21)
	name_lbl.add_theme_color_override("font_color", color)
	header.add_child(name_lbl)

	var price: int = item.get("price", 0)
	var can_buy: bool = SaveManager.gold >= price
	var buy_btn := ButtonBuilder.create_small_button(
		TranslationManager.t("market_buy").replace("{p}", str(price)), 120, 30)
	buy_btn.name = "BuyButton"
	buy_btn.add_theme_font_size_override("font_size", 16)
	buy_btn.disabled = not can_buy
	if can_buy:
		buy_btn.pressed.connect(_show_buy_confirm.bind(item))
		buy_btn.pressed.connect(ClickPlayer.play_select_3)
	header.add_child(buy_btn)

	var effect_lbl := Label.new()
	effect_lbl.name = "EffectLabel"
	effect_lbl.text = _effect_text(item)
	effect_lbl.add_theme_font_size_override("font_size", 21)
	effect_lbl.add_theme_color_override("font_color", Color(0.55, 0.8, 0.55))
	info.add_child(effect_lbl)

	var owned_lbl := Label.new()
	owned_lbl.name = "OwnedLabel"
	owned_lbl.text = TranslationManager.t("market_owned").replace(
		"{n}", str(SaveManager.get_inventory_count(item["id"])))
	owned_lbl.add_theme_font_size_override("font_size", 21)
	owned_lbl.add_theme_color_override("font_color", Color(0.7, 0.75, 0.55))
	info.add_child(owned_lbl)

	return panel


func _effect_text(item: Dictionary) -> String:
	var value: int = int(item.get("value", 0))
	match str(item.get("effect", "")):
		"heal":
			return TranslationManager.t("market_effect_hp").replace("{v}", str(value))
		"mana":
			return TranslationManager.t("market_effect_mp").replace("{v}", str(value))
		"stamina":
			return TranslationManager.t("market_effect_sta").replace("{v}", str(value))
		_:
			return ""


func _show_buy_confirm(item: Dictionary) -> void:
	if get_node_or_null("BuyConfirmOverlay") != null:
		return

	var unit_price: int = item.get("price", 0)

	# The market page lives inside the hub's content panel, so a full-rect overlay
	# would only dim that panel. Attach the overlay to the window instead and
	# centre the popup on the screen.
	var window := get_window()
	if window == null:
		window = get_viewport()
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
	title.position = Vector2(20, 18)
	title.size = Vector2(POPUP_W - 40, 56)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	panel.add_child(title)

	var qty := [1]

	var qty_lbl := ButtonBuilder.create_stat_label("1", 26)
	qty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	qty_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	qty_lbl.position = Vector2(POPUP_W / 2.0 - 50, 84)
	qty_lbl.size = Vector2(100, 40)
	qty_lbl.add_theme_color_override("font_color", Color(0.95, 0.85, 0.65, 1))
	panel.add_child(qty_lbl)

	var total_lbl := ButtonBuilder.create_body_label("", 16)
	total_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	total_lbl.position = Vector2(20, 130)
	total_lbl.size = Vector2(POPUP_W - 40, 24)
	total_lbl.add_theme_color_override("font_color", Color(0.85, 0.8, 0.7, 1))
	panel.add_child(total_lbl)

	var minus_btn := ButtonBuilder.create_small_button("-", 60, 40)
	minus_btn.add_theme_font_size_override("font_size", 22)
	minus_btn.position = Vector2(POPUP_W / 2.0 - 110, 84)
	panel.add_child(minus_btn)

	var plus_btn := ButtonBuilder.create_small_button("+", 60, 40)
	plus_btn.add_theme_font_size_override("font_size", 22)
	plus_btn.position = Vector2(POPUP_W / 2.0 + 50, 84)
	panel.add_child(plus_btn)

	var ok_btn := ButtonBuilder.create_menu_button(
		TranslationManager.t("ok"), 170, 48)
	ok_btn.position = Vector2(POPUP_W - 190, POPUP_H - 64)
	panel.add_child(ok_btn)

	var cancel_btn := ButtonBuilder.create_menu_button(
		TranslationManager.t("cancel"), 170, 48)
	cancel_btn.position = Vector2(20, POPUP_H - 64)
	cancel_btn.pressed.connect(overlay.queue_free)
	cancel_btn.pressed.connect(ClickPlayer.play_select_4)
	panel.add_child(cancel_btn)

	var refresh := func() -> void:
		qty_lbl.text = str(qty[0])
		total_lbl.text = TranslationManager.t("market_total").replace(
			"{p}", str(unit_price * qty[0]))
		minus_btn.disabled = qty[0] <= 1
		ok_btn.disabled = unit_price * qty[0] > SaveManager.gold

	minus_btn.pressed.connect(func() -> void:
		qty[0] = maxi(1, qty[0] - 1)
		refresh.call())
	minus_btn.pressed.connect(ClickPlayer.play_select_3)
	plus_btn.pressed.connect(func() -> void:
		qty[0] += 1
		refresh.call())
	plus_btn.pressed.connect(ClickPlayer.play_select_3)
	ok_btn.pressed.connect(func() -> void:
		_buy_item(str(item["id"]), unit_price, qty[0]))
	ok_btn.pressed.connect(ClickPlayer.play_select_3)
	ok_btn.pressed.connect(overlay.queue_free)

	refresh.call()


func _buy_item(item_id: String, unit_price: int, quantity: int) -> void:
	if SaveManager.spend_gold(unit_price * quantity):
		SaveManager.add_to_inventory(item_id, quantity)
		_refresh()


func _refresh(_value: int = 0) -> void:
	_build_items()


# Called by the hub when another section is opened, so a buy popup never lingers.
# The overlay is attached to the window, not this page, so it cannot be found by
# walking this node's children.
func close_popups() -> void:
	var window := get_window()
	if window == null:
		window = get_viewport()
	var overlay := window.get_node_or_null("BuyConfirmOverlay")
	if overlay != null:
		overlay.queue_free()
