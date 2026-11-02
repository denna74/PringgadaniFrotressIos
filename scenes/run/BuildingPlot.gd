extends Area3D

signal building_placed(building: Node3D)

const BUILDING_SCRIPTS: Dictionary = {
	"pendopo": "res://scenes/buildings/Pendopo.gd",
	"tambang_emas": "res://scenes/buildings/TambangEmas.gd",
	"menara": "res://scenes/buildings/Tower.gd",
	"barak": "res://scenes/buildings/Barak.gd",
}

var occupied: bool = false
var current_building: Node3D = null
var plot_position: Vector2i
var stage_number: int = 0
var stage_theme: String = ""

var _highlight: MeshInstance3D = null
var _flag: Node3D = null
var _popup: Control = null
var _popup_layer: CanvasLayer = null
var _suppress_press := false

const TOUCH_AREA_SIZE := 1.5
const HIGHLIGHT_SIZE := 1.5
# The original build_flag.glb is 71k triangles for a small marker, and one is instanced on
# every building plot. The decimated build_flag_lite.glb keeps the same material but is
# 6k triangles, which is plenty at gameplay scale.
const FLAG_MODEL_PATH := "res://assets/models/3D_tiles/build_flag_lite.glb"


func _ready() -> void:
	_setup_visual()
	_setup_collision()
	input_event.connect(_on_input_event)


func _setup_visual() -> void:
	var theme: String = (
		stage_theme if not stage_theme.is_empty() else TileTheme.theme_for_stage(stage_number)
	)
	var tile_mesh := TerrainBuilder._get_mesh("dirt_center")
	var tile_mat := TerrainBuilder._get_material("dirt_center", theme)

	if tile_mesh:
		var tile_inst := MeshInstance3D.new()
		tile_inst.mesh = tile_mesh
		if tile_mat and tile_mat is BaseMaterial3D:
			var mat_clone: StandardMaterial3D = tile_mat.duplicate()
			mat_clone.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			tile_inst.material_override = mat_clone
		add_child(tile_inst)

	var flag_scene: PackedScene = load(FLAG_MODEL_PATH)
	if flag_scene:
		_flag = flag_scene.instantiate()
		_flag.position = Vector3(0, 0.95, 0)
		_flag.scale = Vector3(1, 1, 1)
		add_child(_flag)
		_make_flag_unshaded(_flag)

	_highlight = MeshInstance3D.new()
	var hl_box := BoxMesh.new()
	hl_box.size = Vector3(HIGHLIGHT_SIZE, 0.14, HIGHLIGHT_SIZE)
	var hl_mat := StandardMaterial3D.new()
	hl_mat.albedo_color = Color(0.5, 1.0, 0.5, 0.35)
	hl_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	hl_mat.no_depth_test = true
	hl_box.material = hl_mat
	_highlight.mesh = hl_box
	_highlight.position = Vector3(0, 0.25, 0)
	_highlight.visible = false
	add_child(_highlight)


# The flag GLB ships a fully metallic (metallic=1.0) material. In the run scene the
# environment is BG_COLOR with no sky, so a metal has nothing to reflect and (with
# no diffuse) renders black/dark instead of the white flag graphic. The editor's
# scene preview adds sky IBL, which is why it only shows up there. Unshading the
# material keeps its albedo texture and makes the marker read as a bright white
# flag on every platform and lighting setup.
func _make_flag_unshaded(flag: Node3D) -> void:
	for node in flag.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		var mat: Material = mi.mesh.surface_get_material(0)
		if mat == null or not (mat is StandardMaterial3D):
			continue
		var flat := (mat as StandardMaterial3D).duplicate()
		flat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		flat.albedo_color = Color(1, 1, 1)
		mi.material_override = flat


func _setup_collision() -> void:
	var shape := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if shape == null:
		shape = CollisionShape3D.new()
		shape.name = "CollisionShape3D"
		add_child(shape)
	var box := BoxShape3D.new()
	box.size = Vector3(TOUCH_AREA_SIZE, 1.5, TOUCH_AREA_SIZE)
	shape.shape = box
	shape.position = Vector3(0, 0.75, 0)


func is_available() -> bool:
	return not occupied


func place_building(building_node: Node3D) -> void:
	occupied = true
	current_building = building_node
	if _flag:
		_flag.visible = false
	building_placed.emit(building_node)


func remove_building() -> void:
	occupied = false
	current_building = null
	if _flag:
		_flag.visible = true


func _on_input_event(_camera: Node3D, _event: InputEvent, _click_position: Vector3, _click_normal: Vector3, _shape_idx: int) -> void:
	if not (_event is InputEventMouseButton and _event.pressed and _event.button_index == MOUSE_BUTTON_LEFT):
		return
	if _suppress_press:
		return
	if BuildingUIState.is_popup_open():
		if _popup != null:
			_close_popup()
			return
		if occupied and current_building != null and current_building.has_method("can_open_overlay") and current_building.can_open_overlay() and current_building.has_method("has_overlay_open") and current_building.has_overlay_open():
			current_building.toggle_overlay()
			return
		return
	if not occupied and _highlight:
		_highlight.visible = true
		var tween := create_tween()
		tween.tween_property(_highlight, "visible", false, 0.3)
	if occupied and current_building != null:
		if current_building.has_method("can_open_overlay") and current_building.can_open_overlay() and current_building.has_method("toggle_overlay"):
			current_building.toggle_overlay()
		return
	_show_build_popup()


func _show_build_popup(track_popup_state: bool = true) -> void:
	if _popup != null or _popup_layer != null:
		_close_popup()

	_popup_layer = _make_popup_layer()

	_popup = Control.new()
	_popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_popup_layer.add_child(_popup)

	_popup.size = Vector2(360, 500)
	_popup.position = get_viewport().get_visible_rect().size / 2 - _popup.size / 2

	var bg := ColorRect.new()
	bg.size = _popup.size
	bg.color = Color(0.08, 0.04, 0.02, 0.95)
	bg.position = Vector2(0, 0)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_popup.add_child(bg)

	var title := Label.new()
	title.name = "PopupTitle"
	title.text = TranslationManager.t("build_menu_title")
	title.position = Vector2(20, 12)
	title.add_theme_color_override("font_color", Color(0.9, 0.8, 0.3))
	title.add_theme_font_size_override("font_size", 26)
	_popup.add_child(title)

	var available: Array = BuildingData.get_all_buildings()
	var y_offset := 56

	for data in available:
		var id: String = data.get("id", "")
		if id == "pendopo":
			continue

		var cost_gold: int = data.get("base_cost_gold", 0)
		var affordable: bool = EconomyManager.can_afford(cost_gold)

		var card := ColorRect.new()
		card.size = Vector2(320, 78)
		card.position = Vector2(20, y_offset)
		card.color = Color(0.2, 0.15, 0.08, 0.9)
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_popup.add_child(card)

		var clr: Color = Color(0.9, 0.85, 0.7) if affordable else Color(0.5, 0.45, 0.35)

		var name_lbl := Label.new()
		name_lbl.name = "BuildingName_%s" % id
		name_lbl.text = TranslationManager.item_name(data)
		name_lbl.position = Vector2(34, y_offset + 4)
		name_lbl.add_theme_color_override("font_color", clr)
		name_lbl.add_theme_font_size_override("font_size", 20)
		_popup.add_child(name_lbl)

		var cost_lbl := Label.new()
		cost_lbl.text = "%dg" % cost_gold
		cost_lbl.position = Vector2(34, y_offset + 30)
		cost_lbl.add_theme_color_override("font_color", Color(0.9, 0.8, 0.3))
		cost_lbl.add_theme_font_size_override("font_size", 18)
		_popup.add_child(cost_lbl)

		if not affordable:
			var na_lbl := Label.new()
			na_lbl.text = TranslationManager.t("build_not_enough_gold")
			na_lbl.position = Vector2(170, y_offset + 30)
			na_lbl.add_theme_color_override("font_color", Color(0.7, 0.2, 0.15))
			na_lbl.add_theme_font_size_override("font_size", 16)
			_popup.add_child(na_lbl)

		card.mouse_filter = Control.MOUSE_FILTER_STOP
		var capture_data = data
		card.gui_input.connect(_on_card_tap.bind(capture_data))
		y_offset += 86

	var close_btn := ButtonBuilder.create_small_button(TranslationManager.t("close"), 180, 48)
	close_btn.position = Vector2(90, 438)
	close_btn.add_theme_font_size_override("font_size", 20)
	close_btn.pressed.connect(_close_popup)
	close_btn.pressed.connect(ClickPlayer.play_select_4)
	_popup.add_child(close_btn)

	if track_popup_state:
		BuildingUIState.note_popup_opened()


func _on_card_tap(event: InputEvent, data: Dictionary) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var cost_gold: int = data.get("base_cost_gold", 0)
		if not EconomyManager.spend(cost_gold):
			return
		_place_building_from_data(data)


func _place_building_from_data(data: Dictionary) -> void:
	var id: String = data.get("id", "")
	var path: String = BUILDING_SCRIPTS.get(id, "")
	if path.is_empty():
		return
	var BuildingClass = load(path)
	if BuildingClass == null:
		push_warning("BuildingPlot: Missing script for '%s'" % id)
		return
	var building: Node3D = BuildingClass.new(data, self)
	building.level = SaveManager.get_building_upgrade_level(id)
	building.position = position + Vector3(0, Building.RISE_START_Y, 0)
	get_parent().add_child(building)
	building.animate_construction()
	BuildEffects.shake_tiles(Vector3(position.x, 0.0, position.z))
	SFXManager.play_build_quake()
	place_building(building)

	_suppress_press = true
	get_tree().create_timer(0.25).timeout.connect(func() -> void:
		if is_instance_valid(self):
			_suppress_press = false
	)

	_close_popup()


func _close_popup(track_popup_state: bool = true) -> void:
	var was_open := _popup != null or _popup_layer != null
	if _popup:
		_popup.queue_free()
		_popup = null
	if _popup_layer:
		_popup_layer.queue_free()
		_popup_layer = null
	if was_open and track_popup_state:
		BuildingUIState.note_popup_closed()


func _make_popup_layer() -> CanvasLayer:
	var layer := CanvasLayer.new()
	layer.layer = 10
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	return layer
