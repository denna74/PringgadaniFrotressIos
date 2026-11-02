class_name Building extends Node3D


var building_id: String = ""
var building_data: Dictionary = {}
var level: int = 1
var plot: Area3D = null

var _model: Node3D = null
var _overlay: Control = null
var _overlay_layer: CanvasLayer = null
var _mesh_mats: Array[BaseMaterial3D] = []
var _is_transparent: bool = false

const RISE_START_Y := -4.0
const RISE_DURATION := 0.9


func _init(data: Dictionary, plot_ref: Area3D) -> void:
	building_data = data
	building_id = data.get("id", "")
	plot = plot_ref


func _ready() -> void:
	var grid_w: int = building_data.get("grid_size", {}).get("w", 1)
	var grid_h: int = building_data.get("grid_size", {}).get("h", 1)
	_model = BuildingFactory.create_building(building_id, level, Vector2i(grid_w, grid_h))
	add_child(_model)
	_collect_mesh_materials(_model)
	_build_overlay()
	if _overlay:
		_overlay.visible = false


func _process(_delta: float) -> void:
	if _overlay == null or not _overlay.visible:
		return
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	_overlay.position = viewport_size / 2 - _overlay.size / 2


func get_gold_production() -> int:
	if building_id == "tambang_emas":
		return ProgressionData.gold_mine_production(level)
	var base_rate: int = building_data.get("gold_per_day", 0)
	if base_rate == 0:
		return 0
	return ProgressionData.building_gold_production(base_rate, level)


func get_defense_value() -> float:
	return BuildingData.get_building_defense(building_id, level)


func get_type() -> String:
	return building_data.get("type", "")


func is_defense_type() -> bool:
	return get_type() in ["wall", "tower", "barricade"]


func show_overlay() -> void:
	if not can_open_overlay():
		return
	if _overlay:
		if not _overlay.visible:
			BuildingUIState.note_popup_opened()
		var viewport_size: Vector2 = get_viewport().get_visible_rect().size
		_overlay.position = viewport_size / 2 - _overlay.size / 2
		_refresh_overlay()
		_overlay.visible = true


func hide_overlay() -> void:
	if _overlay and _overlay.visible:
		_overlay.visible = false
		BuildingUIState.note_popup_closed()


func has_overlay_open() -> bool:
	return _overlay != null and _overlay.visible


func can_open_overlay() -> bool:
	return true


func toggle_overlay() -> void:
	if not can_open_overlay():
		return
	if _overlay and _overlay.visible:
		hide_overlay()
	else:
		show_overlay()


func set_transparent(transparent: bool) -> void:
	if _is_transparent == transparent:
		return
	_is_transparent = transparent
	var alpha: float = 0.3 if transparent else 1.0
	for mat in _mesh_mats:
		if mat:
			mat.albedo_color.a = alpha
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if transparent else BaseMaterial3D.TRANSPARENCY_DISABLED


func animate_construction(duration: float = RISE_DURATION) -> void:
	var target_y: float = 0.2
	if plot:
		target_y = plot.position.y + 0.2
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position:y", target_y, duration)


func _ensure_overlay_layer() -> void:
	if _overlay_layer == null:
		_overlay_layer = CanvasLayer.new()
		_overlay_layer.layer = 10
		_overlay_layer.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(_overlay_layer)


func _build_overlay() -> void:
	_ensure_overlay_layer()
	_overlay = Control.new()
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.size = Vector2(380, 240)
	_overlay_layer.add_child(_overlay)

	var bg := ColorRect.new()
	bg.size = _overlay.size
	bg.color = Color(0.1, 0.05, 0.03, 0.92)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(bg)

	var info := Label.new()
	info.name = "InfoLabel"
	info.position = Vector2(20, 16)
	info.size = Vector2(340, 108)
	info.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
	info.add_theme_font_size_override("font_size", 20)
	_overlay.add_child(info)

	_build_close_button()


func _build_close_button() -> void:
	if _overlay == null:
		return
	var close_btn := Button.new()
	close_btn.name = "CloseBtn"
	close_btn.position = Vector2(20, _overlay.size.y - 64)
	close_btn.size = Vector2(_overlay.size.x - 40, 48)
	close_btn.text = TranslationManager.t("close")
	close_btn.add_theme_font_size_override("font_size", 20)
	close_btn.pressed.connect(hide_overlay)
	ButtonBuilder.make_hover_inert(close_btn)
	_overlay.add_child(close_btn)


func _refresh_overlay() -> void:
	if not is_inside_tree() or _overlay == null:
		return
	var info: Label = _overlay.get_node("InfoLabel")
	var prod := get_gold_production()
	var prod_text := ""
	if prod > 0:
		prod_text = "%s: +%d / 2s" % [TranslationManager.t("resource_gold"), prod]

	var def := get_defense_value()
	var def_text := ""
	if def > 0:
		def_text = TranslationManager.t("building_damage") % def

	var details: Array[String] = []
	for line: String in [prod_text, def_text, _hp_text()]:
		if not line.is_empty():
			details.append(line)
	info.text = "%s\n%s" % [
		TranslationManager.item_name(building_data),
		TranslationManager.t("building_level") % level,
	]
	if not details.is_empty():
		info.text += "\n" + "\n".join(details)


func _hp_text() -> String:
	if building_id == "pendopo":
		return TranslationManager.t("building_hp") % roundi(ProgressionData.pendopo_hp(level))
	return ""


func _collect_mesh_materials(node: Node3D) -> void:
	for child in node.get_children():
		if child is MeshInstance3D:
			var override_mat: Material = child.material_override
			if override_mat is BaseMaterial3D:
				_mesh_mats.append(override_mat)
			for i in range(child.get_surface_override_material_count()):
				var surf_mat: Material = child.get_surface_override_material(i)
				if surf_mat is BaseMaterial3D:
					_mesh_mats.append(surf_mat)
			if child.mesh:
				for i in range(child.mesh.get_surface_count()):
					var shared_mat: Material = child.mesh.surface_get_material(i)
					if shared_mat is BaseMaterial3D:
						var mat: BaseMaterial3D = (shared_mat as BaseMaterial3D).duplicate()
						child.set_surface_override_material(i, mat)
						_mesh_mats.append(mat)
		elif child is Node3D:
			_collect_mesh_materials(child)
