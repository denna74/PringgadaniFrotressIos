class_name Barak extends Building

signal troop_trained(troop_type: String)

const TROOP_TYPES: Array[String] = ["infantry", "archer"]
const MAX_TROOPS_PER_TYPE := 9

var garrison: PlayerGarrison = null
var _training_timer: Timer = null
var _training_queue: Array[String] = []
var _troop_buttons: Dictionary = {}
var _overlay_dim: ColorRect = null


func setup(_garrison: PlayerGarrison) -> void:
	garrison = _garrison
	if garrison != null and not garrison.counts_changed.is_connected(_refresh_overlay):
		garrison.counts_changed.connect(_refresh_overlay)
	if not SaveManager.gold_changed.is_connected(_on_gold_changed):
		SaveManager.gold_changed.connect(_on_gold_changed)
	_refresh_overlay()


func available_troop_types() -> Array[String]:
	return TROOP_TYPES.duplicate()


func get_troop_type() -> String:
	return building_data.get("troop_type", "infantry")


func set_troop_type(troop_type: String) -> void:
	if not TROOP_TYPES.has(troop_type):
		return
	building_data["troop_type"] = troop_type
	_refresh_overlay()


func get_training_cost() -> int:
	var mod: int = {"infantry": 1, "archer": 2}.get(get_troop_type(), 1)
	return 5 + mod


func get_training_cost_for(troop_type: String) -> int:
	var mod: int = {"infantry": 1, "archer": 2}.get(troop_type, 1)
	return 5 + mod


func _ready() -> void:
	super._ready()
	_training_timer = Timer.new()
	add_child(_training_timer)
	_training_timer.timeout.connect(_on_training_complete)
	_training_timer.one_shot = false
	_update_timer_speed()


func _exit_tree() -> void:
	if garrison != null:
		for troop_type: String in _training_queue:
			garrison.cancel_troop_reservation(troop_type)
			garrison.remove_troops(troop_type, 1)
	_training_queue.clear()


func _build_overlay() -> void:
	_ensure_overlay_layer()
	_overlay_dim = ColorRect.new()
	_overlay_dim.name = "OverlayDim"
	_overlay_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay_dim.color = Color(0, 0, 0, 0.6)
	_overlay_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay_dim.visible = false
	_overlay_layer.add_child(_overlay_dim)

	_overlay = ButtonBuilder.create_panel(480, 400)
	_overlay.name = "BarracksPanel"
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.visible = false
	_overlay.size = Vector2(480, 400)
	_overlay_layer.add_child(_overlay)

	var title := ButtonBuilder.create_title_label(TranslationManager.t("barracks_on_duty"), 26)
	title.name = "OnDutyTitle"
	title.position = Vector2(20, 24)
	title.size = Vector2(440, 42)
	title.add_theme_color_override("font_color", Color(0.95, 0.85, 0.65))
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_overlay.add_child(title)

	var infantry_label := ButtonBuilder.create_stat_label("", 20)
	infantry_label.name = "InfantryCount"
	infantry_label.position = Vector2(30, 82)
	infantry_label.size = Vector2(420, 32)
	infantry_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	infantry_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
	_overlay.add_child(infantry_label)

	var archer_label := ButtonBuilder.create_stat_label("", 20)
	archer_label.name = "ArcherCount"
	archer_label.position = Vector2(30, 120)
	archer_label.size = Vector2(420, 32)
	archer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	archer_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
	_overlay.add_child(archer_label)

	var prompt := ButtonBuilder.create_body_label(TranslationManager.t("barracks_add_prompt"), 18)
	prompt.name = "AddPrompt"
	prompt.position = Vector2(24, 178)
	prompt.size = Vector2(432, 36)
	prompt.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
	prompt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_overlay.add_child(prompt)

	for i in TROOP_TYPES.size():
		var troop_type: String = TROOP_TYPES[i]
		var btn := ButtonBuilder.create_small_button(
			TranslationManager.t("barracks_add_%s" % troop_type), 200, 56
		)
		btn.name = "Add%sBtn" % troop_type.capitalize()
		btn.position = Vector2(32 + i * 216, 228)
		btn.add_theme_font_size_override("font_size", 18)
		btn.pressed.connect(ClickPlayer.play_select_3)
		btn.pressed.connect(_on_train_pressed.bind(troop_type))
		_overlay.add_child(btn)
		_troop_buttons[troop_type] = btn

		var cost_label := ButtonBuilder.create_stat_label("", 16)
		cost_label.name = "Cost%sLabel" % troop_type.capitalize()
		cost_label.position = Vector2(32 + i * 216, 288)
		cost_label.size = Vector2(200, 28)
		cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cost_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
		_overlay.add_child(cost_label)

	var close_btn := ButtonBuilder.create_small_button(
		TranslationManager.t("close"), 200, 52
	)
	close_btn.name = "CloseBtn"
	close_btn.position = Vector2(140, 330)
	close_btn.add_theme_font_size_override("font_size", 20)
	close_btn.pressed.connect(hide_overlay)
	close_btn.pressed.connect(ClickPlayer.play_select_4)
	_overlay.add_child(close_btn)


func show_overlay() -> void:
	super.show_overlay()
	if _overlay_dim != null:
		_overlay_dim.visible = _overlay != null and _overlay.visible


func hide_overlay() -> void:
	super.hide_overlay()
	if _overlay_dim != null:
		_overlay_dim.visible = false


func _on_train_pressed(troop_type: String = "") -> void:
	var selected_type: String = troop_type if TROOP_TYPES.has(troop_type) else get_troop_type()
	var cost: int = get_training_cost_for(selected_type)
	if (
		garrison != null
		and garrison.can_reserve_troop(selected_type, MAX_TROOPS_PER_TYPE)
		and EconomyManager.can_afford(cost)
	):
		if not garrison.reserve_troop(selected_type, MAX_TROOPS_PER_TYPE):
			return
		if not EconomyManager.spend(cost):
			garrison.cancel_troop_reservation(selected_type)
			return
		garrison.add_troops(selected_type, 1)
		_training_queue.append(selected_type)
		if _training_timer.is_stopped():
			_training_timer.start()


func _on_training_complete() -> void:
	if not _training_queue.is_empty() and garrison != null:
		var troop_type: String = _training_queue.pop_front()
		garrison.complete_troop_training(troop_type)
		troop_trained.emit(troop_type)
		_refresh_overlay()
	if _training_queue.is_empty():
		_training_timer.stop()


func _update_timer_speed() -> void:
	var speed: int = building_data.get("training_speed", 10)
	_training_timer.wait_time = BuildingUpgradeData.barracks_training_time(
		float(speed), level
	)


func _refresh_overlay() -> void:
	if not is_inside_tree() or _overlay == null:
		return
	var infantry_count: int = garrison._get_count("infantry") if garrison != null else 0
	var archer_count: int = garrison._get_count("archer") if garrison != null else 0
	_overlay.get_node("InfantryCount").text = (
		TranslationManager.t("barracks_infantry_count").format({"count": infantry_count})
	)
	_overlay.get_node("ArcherCount").text = (
		TranslationManager.t("barracks_archer_count").format({"count": archer_count})
	)
	_overlay.get_node("AddPrompt").text = TranslationManager.t("barracks_add_prompt")
	_overlay.get_node("CloseBtn").text = TranslationManager.t("close")
	for troop_type: String in TROOP_TYPES:
		var btn: Button = _troop_buttons[troop_type]
		btn.text = TranslationManager.t("barracks_add_%s" % troop_type)
		btn.disabled = (
			garrison == null
			or not garrison.can_reserve_troop(troop_type, MAX_TROOPS_PER_TYPE)
			or not EconomyManager.can_afford(get_training_cost_for(troop_type))
		)
		_overlay.get_node("Cost%sLabel" % troop_type.capitalize()).text = (
			TranslationManager.t("barracks_cost").format({
				"cost": get_training_cost_for(troop_type),
			})
		)


func _on_gold_changed(_gold: int) -> void:
	_refresh_overlay()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _overlay and _overlay.visible:
			var mouse_pos := get_viewport().get_mouse_position()
			var overlay_rect := Rect2(_overlay.global_position, _overlay.size)
			if not overlay_rect.has_point(mouse_pos):
				hide_overlay()
				get_viewport().set_input_as_handled()
