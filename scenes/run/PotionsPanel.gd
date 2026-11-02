extends Control


var _king: Node3D = null
var _btn: Control = null
var _popup: Control = null
var _popup_open: bool = false
var _blocked: bool = false
var _potions_touch_index: int = -1
var _cells: Dictionary = {}

const BUTTON_POS := Vector2(1154, 360)
const BUTTON_SIZE := Vector2(110, 110)
const POPUP_SIZE := Vector2(1280, 720)
const PANEL_SIZE := Vector2(550, 620)


func setup(king: Node3D) -> void:
	_king = king


func _ready() -> void:
	_build_potions_button()


func _process(_delta: float) -> void:
	var blocked := BuildingUIState.is_popup_open() and not _popup_open
	if blocked != _blocked:
		_blocked = blocked
		if _btn:
			_btn.modulate = Color(1, 1, 1, 0.3) if blocked else Color.WHITE


func _build_potions_button() -> void:
	var btn := Control.new()
	btn.position = BUTTON_POS
	btn.size = BUTTON_SIZE
	btn.pivot_offset = BUTTON_SIZE / 2.0
	add_child(btn)
	_btn = btn

	var tex := TextureRect.new()
	tex.texture = load("res://assets/buttons/potions.png")
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex.size = BUTTON_SIZE
	tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tex.self_modulate = Color(1, 1, 1, 0.6)
	btn.add_child(tex)

	btn.gui_input.connect(_on_potions_gui_input)


func _on_potions_gui_input(event: InputEvent) -> void:
	# Only ScreenTouch is acted on; see the note on the RunHUD tap handlers. The release
	# still has to clear the index, otherwise the button would fire only once.
	if not event is InputEventScreenTouch:
		return
	var st := event as InputEventScreenTouch
	if st.pressed:
		if _potions_touch_index == -1:
			_potions_touch_index = st.index
			_on_potions_pressed()
	elif st.index == _potions_touch_index:
		_potions_touch_index = -1


func _on_potions_pressed() -> void:
	if BuildingUIState.is_popup_open():
		return
	ClickPlayer.play_select_3()
	_open_popup()


func _open_popup() -> void:
	if _popup != null or _popup_open:
		return
	if BuildingUIState.is_popup_open():
		return
	if GamePause.is_paused():
		return
	_popup = Control.new()
	_popup.name = "PotionsPopup"
	_popup.position = Vector2.ZERO
	_popup.size = POPUP_SIZE
	_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	_popup.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_popup)

	var dim := ColorRect.new()
	dim.anchors_preset = Control.PRESET_FULL_RECT
	dim.color = Color(0, 0, 0, 0.6)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_popup.add_child(dim)

	var panel := ButtonBuilder.create_panel(int(PANEL_SIZE.x), int(PANEL_SIZE.y))
	panel.name = "PotionPanel"
	panel.position = (POPUP_SIZE - PANEL_SIZE) / 2.0
	_popup.add_child(panel)

	var title := ButtonBuilder.create_title_label(TranslationManager.t("potions_title"), 30)
	title.name = "PopupTitle"
	title.position = Vector2(0, 20)
	title.size = Vector2(PANEL_SIZE.x, 42)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(title)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.position = Vector2(30, 78)
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	panel.add_child(grid)

	_cells = {}
	for item in ConsumableDatabase.get_all():
		var cell: Dictionary = _build_cell(item)
		grid.add_child(cell.get("cell") as Control)
		_cells[item.get("id", "")] = cell

	var cancel := ButtonBuilder.create_small_button(TranslationManager.t("cancel"), 200, 52)
	cancel.name = "CancelButton"
	cancel.position = Vector2((PANEL_SIZE.x - 200) / 2.0, 550)
	cancel.add_theme_font_size_override("font_size", 20)
	cancel.pressed.connect(_close_popup)
	cancel.pressed.connect(ClickPlayer.play_select_4)
	panel.add_child(cancel)

	_popup_open = true
	BuildingUIState.note_popup_opened()
	_refresh_cells()


func _build_cell(item: Dictionary) -> Dictionary:
	var cell := VBoxContainer.new()
	cell.custom_minimum_size = Vector2(156, 142)
	cell.add_theme_constant_override("separation", 2)

	var btn := Button.new()
	btn.tooltip_text = TranslationManager.item_name(item)
	btn.flat = true
	btn.custom_minimum_size = Vector2(148, 108)
	ButtonBuilder.make_hover_inert(btn)
	var icon_path: String = item.get("use_icon", "")
	if not icon_path.is_empty():
		var icon: Texture2D = load(icon_path)
		if icon:
			btn.icon = icon
			btn.expand_icon = true

	var stock := Label.new()
	stock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stock.add_theme_font_size_override("font_size", 20)
	stock.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))

	cell.add_child(btn)
	cell.add_child(stock)

	var item_id: String = item.get("id", "")
	btn.pressed.connect(_consume.bind(item_id))

	return {"cell": cell, "button": btn, "stock": stock}


func _refresh_cells() -> void:
	for item_id in _cells:
		var entry: Dictionary = _cells[item_id] as Dictionary
		var btn: Button = entry["button"] as Button
		var stock: Label = entry["stock"] as Label
		var count: int = SaveManager.get_inventory_count(item_id)
		stock.text = "x%d" % count
		btn.disabled = count <= 0
		btn.modulate = Color(1, 1, 1, 0.25) if count <= 0 else Color.WHITE


func _consume(item_id: String) -> void:
	if _king == null:
		return
	var item: Dictionary = ConsumableDatabase.get_item(item_id)
	if item.is_empty():
		return
	if not SaveManager.remove_from_inventory(item_id, 1):
		return
	ClickPlayer.play_select_3()
	_close_popup()
	await get_tree().process_frame
	if not is_instance_valid(_king):
		return
	var effect: String = item.get("effect", "")
	var value: float = item.get("value", 0.0)
	if effect == "heal" and _king.has_method("restore_hp"):
		_king.restore_hp(value)
	elif effect == "mana" and _king.has_method("restore_mana"):
		_king.restore_mana(value)
	elif effect == "stamina" and _king.has_method("restore_stamina"):
		_king.restore_stamina(value / 100.0)
	if _king.has_method("play_potion_aura"):
		_king.play_potion_aura(effect)
	SFXManager.play_potion()


func _close_popup() -> void:
	if not _popup_open:
		return
	_popup.queue_free()
	_popup = null
	_popup_open = false
	BuildingUIState.note_popup_closed()
