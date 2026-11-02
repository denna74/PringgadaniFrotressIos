extends SceneTree


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame

	var kc: Node3D = load("res://scenes/run/KingController.tscn").instantiate()
	kc.position = Vector3(0, 0, 0)
	kc._facing = 0.0
	root.add_child(kc)
	for i in 20:
		await process_frame

	var enemy_script := GDScript.new()
	enemy_script.source_code = """
extends Node3D
var hp: float = 50.0
func take_damage(amount: float) -> void:
	hp -= amount
"""
	enemy_script.reload()

	var inside: Node3D = Node3D.new()
	inside.name = "Inside"
	inside.set_script(enemy_script)
	inside.position = Vector3(0, 0, 1.5)
	root.add_child(inside)
	await process_frame
	root.get_node("SpatialIndex").register(inside, "enemies")

	var inside2: Node3D = Node3D.new()
	inside2.name = "Inside2"
	inside2.set_script(enemy_script)
	inside2.position = Vector3(0, 0, 1.0)
	root.add_child(inside2)
	await process_frame
	root.get_node("SpatialIndex").register(inside2, "enemies")

	var outside_lateral: Node3D = Node3D.new()
	outside_lateral.name = "OutsideLateral"
	outside_lateral.set_script(enemy_script)
	outside_lateral.position = Vector3(3.0, 0, 0)
	root.add_child(outside_lateral)
	await process_frame
	root.get_node("SpatialIndex").register(outside_lateral, "enemies")

	var outside_range: Node3D = Node3D.new()
	outside_range.name = "OutsideRange"
	outside_range.set_script(enemy_script)
	outside_range.position = Vector3(0, 0, 5.0)
	root.add_child(outside_range)
	await process_frame
	root.get_node("SpatialIndex").register(outside_range, "enemies")

	kc._combo_step = 2
	kc.attack()
	await process_frame

	var ring: MeshInstance3D = kc.get("_punch_ring")
	if ring == null:
		print("FAIL: no punch ring after attack()")
		quit(1)
		return

	var initial_scale: float = ring.scale.x
	var max_scale: float = initial_scale
	for i in 30:
		await process_frame
		max_scale = maxf(max_scale, ring.scale.x)

	var scale_grew: bool = max_scale > initial_scale
	var inside_hp: float = inside.get("hp")
	var inside2_hp: float = inside2.get("hp")
	var lateral_hp: float = outside_lateral.get("hp")
	var range_hp: float = outside_range.get("hp")
	var attack: float = kc.get("king_attack")

	print("scale_grew=", scale_grew, " max_scale=", max_scale)
	print("inside_hp=", inside_hp, " inside2_hp=", inside2_hp, " expected=", 50.0 - attack)
	print("lateral_hp=", lateral_hp, " range_hp=", range_hp)

	if not scale_grew:
		print("FAIL: ring did not expand")
		quit(1)
		return
	if not is_equal_approx(inside_hp, 50.0 - attack):
		print("FAIL: enemy inside cone did not take king_attack damage")
		quit(1)
		return
	if not is_equal_approx(inside2_hp, 50.0 - attack):
		print("FAIL: second enemy inside cone did not take king_attack damage")
		quit(1)
		return
	if not is_equal_approx(lateral_hp, 50.0):
		print("FAIL: lateral enemy outside cone was damaged")
		quit(1)
		return
	if not is_equal_approx(range_hp, 50.0):
		print("FAIL: enemy outside range was damaged")
		quit(1)
		return

	print("VERIFY_PASS")
	quit(0)
