extends Control


var wave_number: int = 0
var result: Dictionary = {}
var enemies_input: Array = []
var is_final_wave: bool = false
var wave_victory: bool = false

var _reveal_index: int = 0
var _elements: Array[CanvasItem] = []
var _reveal_timer: Timer = null

signal continue_pressed
signal closed


func _ready() -> void:
	wave_victory = result.get("victory", false)
	_setup_ui()


func _setup_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0)
	bg.anchors_preset = Control.PRESET_FULL_RECT
	add_child(bg)
	var fade := create_tween()
	fade.tween_property(bg, "color", Color(0, 0, 0, 0.75), 0.25)

	var title := ButtonBuilder.create_title_label("WAVE %d" % wave_number, 30)
	title.position = Vector2(540, 100)
	title.modulate.a = 0.0
	add_child(title)
	_elements.append(title)

	var types_text := _enemy_breakdown_text()
	var enemy_lbl := ButtonBuilder.create_body_label(types_text, 15)
	enemy_lbl.position = Vector2(440, 160)
	enemy_lbl.modulate.a = 0.0
	add_child(enemy_lbl)
	_elements.append(enemy_lbl)

	var stats := result
	var lines: PackedStringArray = []
	lines.append("Damage dealt: %d" % stats.get("player_damage_dealt", 0))
	lines.append("Enemies slain: %d / %d" % [
		stats.get("enemy_casualties", 0),
		stats.get("enemy_casualties", 0) + stats.get("enemies_remaining", 0)
	])
	var stats_lbl := ButtonBuilder.create_body_label("\n".join(lines), 15)
	stats_lbl.position = Vector2(440, 210)
	stats_lbl.modulate.a = 0.0
	add_child(stats_lbl)
	_elements.append(stats_lbl)

	var cas: Dictionary = stats.get("player_casualties", {})
	var cas_text := "Casualties:\nInfantry: %d | Archers: %d" % [
		cas.get("infantry", 0), cas.get("archers", 0)
	]
	var cas_lbl := ButtonBuilder.create_body_label(cas_text, 14)
	cas_lbl.position = Vector2(440, 270)
	cas_lbl.modulate.a = 0.0
	add_child(cas_lbl)
	_elements.append(cas_lbl)

	_reveal_timer = Timer.new()
	_reveal_timer.one_shot = false
	_reveal_timer.wait_time = 0.4
	_reveal_timer.timeout.connect(_reveal_next)
	add_child(_reveal_timer)
	_reveal_timer.start()


func _reveal_next() -> void:
	if _reveal_index < _elements.size():
		var tween := create_tween()
		tween.tween_property(_elements[_reveal_index], "modulate:a", 1.0, 0.3)
		_reveal_index += 1
	else:
		_reveal_timer.stop()
		_show_result()


func _show_result() -> void:
	if wave_victory:
		var btn := ButtonBuilder.create_menu_button("Continue", 240, 46)
		btn.position = Vector2(520, 500)
		add_child(btn)
		btn.pressed.connect(_on_continue)
	else:
		var defeat_lbl := ButtonBuilder.create_title_label("RUN LOST", 28)
		defeat_lbl.add_theme_color_override("font_color", Color(0.7, 0.15, 0.1))
		defeat_lbl.position = Vector2(540, 430)
		add_child(defeat_lbl)
		var tween: Tween = create_tween()
		tween.set_delay(1.5)
		tween.tween_callback(_on_closed)


func _on_continue() -> void:
	continue_pressed.emit()
	queue_free()


func _on_closed() -> void:
	closed.emit()
	queue_free()


func _enemy_breakdown_text() -> String:
	var counts: Dictionary = result.get("enemy_type_counts", {})
	var parts: PackedStringArray = []
	for type_name in counts:
		parts.append("%s x%d" % [type_name.capitalize(), counts[type_name]])
	return "Enemy Forces: " + ", ".join(parts)
