extends SceneTree


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var holder := Node3D.new()
	root.add_child(holder)
	var terrain: Array = []
	for y in range(12):
		var row: Array = []
		for x in range(12):
			row.append(1)
		terrain.append(row)
	NavigationBuilder.build_navigation(terrain, holder, 0.0, false)
	for i in 10:
		await process_frame

	var king := Node3D.new()
	king.name = "King"
	king.add_to_group("king")
	king.position = Vector3(0, 0, 0)
	root.add_child(king)

	var enemy := Node3D.new()
	enemy.name = "Enemy"
	enemy.add_to_group("enemies")
	enemy.position = Vector3(2.0, 0, 0)
	var es := GDScript.new()
	es.source_code = """
extends Node3D
var hp: float = 100.0
func take_damage(amount: float) -> void:
	hp -= amount
func get_health() -> float:
	return hp
"""
	es.reload()
	enemy.set_script(es)
	root.add_child(enemy)
	await process_frame
	root.get_node("SpatialIndex").register(enemy, "enemies")

	var soldier: Node3D = load("res://scenes/run/SoldierUnit.gd").new()
	soldier.move_speed = 50.0
	soldier.position = Vector3(0, 0, 0)
	root.add_child(soldier)

	for i in 120:
		await process_frame
		if float(enemy.get("hp")) < 100.0:
			break

	var final_hp: float = enemy.get("hp")
	print("ENEMY_HP: ", final_hp)
	if final_hp >= 100.0:
		print("FAIL: enemy hp did not drop")
		quit(1)
		return

	var sap: AnimationPlayer = ModelLoader.find_animation_player(soldier)
	soldier.take_damage(999.0)
	await process_frame
	sap.animation_finished.emit("soldier/dead")
	await process_frame
	if is_instance_valid(soldier) and soldier.is_inside_tree():
		print("FAIL: dead soldier still active")
		quit(1)
		return

	print("VERIFY_PASS")
	quit(0)
