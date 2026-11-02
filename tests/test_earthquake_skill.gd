extends SceneTree

var _fails: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame

	var kc: Node3D = load("res://scenes/run/KingController.tscn").instantiate()
	kc.position = Vector3(0, 0, 0)
	kc.set_play_field(8)
	kc.setup_king({"hp": 999.0, "attack": 10.0})
	kc.king_special_cooldown = 5.0
	kc.mana = 200.0
	root.add_child(kc)
	for i in 20:
		await process_frame

	var enemy_script := GDScript.new()
	enemy_script.source_code = """
extends Node3D
var hp: float = 500.0
func take_damage(amount: float) -> void:
	hp -= amount
"""
	enemy_script.reload()

	var inside := await _spawn_enemy(root, enemy_script, "Inside", Vector3(1.2, 0, 0.5))
	var border := await _spawn_enemy(root, enemy_script, "Border", Vector3(3.5, 0, 0))
	var outside := await _spawn_enemy(root, enemy_script, "Outside", Vector3(4.5, 0, 0))
	root.get_node("SpatialIndex").register(inside, "enemies")
	root.get_node("SpatialIndex").register(border, "enemies")
	root.get_node("SpatialIndex").register(outside, "enemies")
	await process_frame

	kc.request_earthquake()
	await process_frame
	for i in 10:
		await process_frame

	if not is_equal_approx(kc.mana, 160.0):
		_fail("mana after cast: got %f want 160" % kc.mana)
	if not is_equal_approx(inside.hp, 500.0 - 20.0):
		_fail("inside damage: got %f want 20" % (500.0 - inside.hp))
	if not is_equal_approx(border.hp, 500.0 - 20.0):
		_fail("border damage: got %f want 20" % (500.0 - border.hp))
	if not is_equal_approx(outside.hp, 500.0):
		_fail("outside took damage: got %f want 0" % (500.0 - outside.hp))

	if kc.position != Vector3(0, 0, 0):
		_fail("king moved during cast lock: %s" % kc.position)

	var mana_after_first: float = kc.mana
	var inside_hp_after_first: float = inside.hp
	kc.request_earthquake()
	await process_frame
	if not is_equal_approx(kc.mana, mana_after_first):
		_fail("cooldown gate spent mana again")
	if not is_equal_approx(inside.hp, inside_hp_after_first):
		_fail("cooldown gate dealt damage again")

	kc._special_timer = 0.0
	kc.mana = 39.0
	var inside_hp_before: float = inside.hp
	kc.request_earthquake()
	await process_frame
	if not is_equal_approx(kc.mana, 39.0):
		_fail("mana < cost still deducted mana")
	if not is_equal_approx(inside.hp, inside_hp_before):
		_fail("mana < cost still dealt damage")

	if _fails == 0:
		print("VERIFY_PASS: earthquake skill")
		quit(0)
	else:
		print("VERIFY_FAIL: %d checks failed" % _fails)
		quit(1)


func _spawn_enemy(tree: Node, enemy_script: GDScript, name_str: String, pos: Vector3) -> Node3D:
	var node: Node3D = Node3D.new()
	node.name = name_str
	node.set_script(enemy_script)
	node.position = pos
	tree.add_child(node)
	await process_frame
	return node


func _fail(msg: String) -> void:
	_fails += 1
	print("CHECK FAIL: " + msg)