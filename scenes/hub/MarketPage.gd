extends Control

## The Market fills the hub's content panel: a single-column list of consumable
## rows. Compact rows keep all consumables visible without scrolling, unlike the
## old two-column grid of tall cards.

const ROW_HEIGHT := 60
const ROW_GAP := 6
const ROW_WIDTH := 400 
const ICON_SIZE := 40
const LIST_TOP_OFFSET := 25.0
const POPUP_W := 420
const POPUP_H := 260

var _list: VBoxContainer = null


func _ready() -> void:
	_setup_ui()
	_build_items()
	SaveManager.gold_changed.connect(_refresh)


func _setup_ui() -> void:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	var wrap := MarginContainer.new()
	wrap.add_theme_constant_override("margin_top", int(LIST_TOP_OFFSET))
	wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(wrap)

	_list = VBoxContainer.new()
	_list.name = "List"
	_list.alignment = BoxContainer.ALIGNMENT_CENTER
	_list.add_theme_constant_override("separation", ROW_GAP)
	wrap.add_child(_list)


func _build_items() -> void:
	for child in _list.get_children():
		child.queue_free()

	for item in ConsumableDatabase.get_all():
		_list.add_child(_build_item_row(item))


func _build_item_row(item: Dictionary) -> Panel:
	var panel := ButtonBuilder.create_panel(ROW_WIDTH, ROW_HEIGHT)
	panel.custom_minimum_size = Vector2(ROW_WIDTH, ROW_HEIGHT)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	margin.add_child(hbox)

	var icon_path: String = item.get("icon", "")
	if not icon_path.is_empty():
		var icon := TextureRect.new()
		icon.texture = load(icon_path)
		icon.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hbox.add_child(icon)

	var name_box := VBoxContainer.new()
	name_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_box.add_theme_constant_override("separation", 0)
	hbox.add_child(name_box)

	var color := ConsumableDatabase.get_rarity_color(item.get("rarity", "common"))
	var name_lbl := Label.new()
	name_lbl.text = TranslationManager.item_name(item)
	name_lbl.add_theme_font_size_override("font_size", 18)
	name_lbl.add_theme_color_override("font_color", color)
	name_box.add_child(name_lbl)

	var effect_lbl := Label.new()
	effect_lbl.text = _effect_text(item)
	effect_lbl.add_theme_font_size_override("font_size", 14)
	effect_lbl.add_theme_color_override("font_color", Color(0.55, 0.8, 0.55))
	name_box.add_child(effect_lbl)

	var buy_box := VBoxContainer.new()
	buy_box.alignment = BoxContainer.ALIGNMENT_CENTER
	buy_box.add_theme_constant_override("separation", 2)
	hbox.add_child(buy_box)

	var owned_lbl := Label.new()
	owned_lbl.text = TranslationManager.t("market_owned").replace(
		"{n}", str(SaveManager.get_inventory_count(item["id"])))
	owned_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	owned_lbl.add_theme_font_size_override("font_size", 13)
	owned_lbl.add_theme_color_override("font_color", Color(0.7, 0.75, 0.55))
	buy_box.add_child(owned_lbl)

	var price: int = item.get("price", 0)
	var can_buy: bool = SaveManager.gold >= price
	var buy_btn := ButtonBuilder.create_small_button(
		TranslationManager.t("market_buy").replace("{p}", str(price)), 110, 30)
	buy_btn.add_theme_font_size_override("font_size", 16)
	buy_btn.disabled = not can_buy
	if can_buy:
		buy_btn.pressed.connect(_show_buy_confirm.bind(item))
		buy_btn.pressed.connect(ClickPlayer.play_select_3)
	buy_box.add_child(buy_btn)

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

	var screen: Vector2 = window.size
	var panel := ButtonBuilder.create_panel(POPUP_W, POPUP_H)
	panel.position = Vector2(
		(screen.x - POPUP_W) / 2.0, (screen.y - POPUP_H) / 2.0)
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
