extends SceneTree


func _initialize() -> void:
	_run()


func _check_bar(name: String, bar: Sprite3D, ratio: float, full_scale: float) -> bool:
	var texture_width: float = float(bar.texture.get_width())
	var left_edge: float = (bar.offset.x - texture_width * 0.5) \
		* bar.pixel_size * bar.scale.x
	var expected_left_edge: float = -texture_width * 0.5 * bar.pixel_size * full_scale
	var valid: bool = is_equal_approx(bar.scale.x, full_scale * ratio) \
		and is_equal_approx(left_edge, expected_left_edge)
	if not valid:
		push_error(
			"%s HP bar scale/left edge %s/%s, expected %s/%s"
			% [name, bar.scale.x, left_edge, full_scale * ratio, expected_left_edge]
		)
	return valid


func _run() -> void:
	await process_frame
	var valid := true

	var unit_pool: GDScript = load("res://scripts/UnitPool.gd")
	var enemy: Node3D = unit_pool.call("acquire_enemy")
	root.add_child(enemy)
	enemy.set_meta("current_health", 40.0)
	enemy.set_meta("max_health", 100.0)
	enemy.call("_update_hp_bar")
	valid = _check_bar("Enemy", enemy.get_node("HPBar"), 0.4, 50.0) and valid

	var boss: Node3D = ModelLoader.load_boss("karna")
	boss.set_script(load("res://scenes/run/enemy_script.gd"))
	unit_pool.call("attach_common_children", boss)
	root.add_child(boss)
	boss.set_meta("current_health", 40.0)
	boss.set_meta("max_health", 100.0)
	boss.call("_update_hp_bar")
	valid = _check_bar("Boss", boss.get_node("HPBar"), 0.4, 50.0) and valid

	var soldier: Node3D = load("res://scenes/run/SoldierUnit.gd").new()
	root.add_child(soldier)
	await process_frame
	soldier.set("soldier_hp", float(soldier.get("soldier_max_hp")) * 0.4)
	soldier.call("_update_hp_bar")
	valid = _check_bar("Soldier", soldier.get_node("HPBar"), 0.4, 50.0) and valid

	var pendopo_script: GDScript = load("res://scenes/buildings/Pendopo.gd")
	var pendopo: Node3D = pendopo_script.new({"id": "pendopo"}, null)
	root.add_child(pendopo)
	await process_frame
	pendopo.set("pendopo_hp", float(pendopo.get("pendopo_max_hp")) * 0.4)
	pendopo.call("_update_hp_bar")
	valid = _check_bar("Pendopo", pendopo.get("_hp_bar_sprite"), 0.4, 60.0) and valid

	if valid:
		print("HP_BAR_ORIGIN_PASS")
		quit(0)
	else:
		quit(1)
