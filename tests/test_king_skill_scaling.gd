extends SceneTree

const BASE_ATTACK: float = 20.0
const BASE_DEFENSE: float = 20.0

var _fails: int = 0
var _sm: Node = null


func _initialize() -> void:
	_run()


func _check(name: String, ok: bool) -> void:
	if ok:
		print("OK  ", name)
	else:
		_fails += 1
		print("CHECK FAIL: " + name)


func _make_king() -> Node3D:
	var kc: Node3D = load("res://scenes/run/KingController.tscn").instantiate()
	kc.position = Vector3.ZERO
	kc.set_play_field(8)
	kc.setup_king({
		"hp": 999999.0,
		"attack": BASE_ATTACK,
		"defense": BASE_DEFENSE,
		"mana_max": 200.0,
	})
	root.add_child(kc)
	return kc


func _spawn_enemy(pos: Vector3) -> Node3D:
	var script := GDScript.new()
	script.source_code = """
extends Node3D
var hp: float = 500.0
func take_damage(amount: float) -> void:
	hp -= amount
"""
	script.reload()
	var node: Node3D = Node3D.new()
	node.set_script(script)
	node.position = pos
	root.add_child(node)
	root.get_node("SpatialIndex").register(node, "enemies")
	return node


func _run() -> void:
	await process_frame
	_sm = root.get_node("/root/SaveManager")
	var kc := _make_king()
	for i in 10:
		await process_frame

	# Dash speed: level 1 vs 6.
	_sm.skill_levels = {"dash": 1, "earthquake": 1, "berserk": 1}
	kc.stamina = 100.0
	kc._dash_timer = 0.0
	kc._dash_cooldown_timer = 0.0
	kc._cast_lock = 0.0
	kc.request_dash()
	_check("dash speed L1 = 3.5x", is_equal_approx(float(kc.get("_dash_speed")), kc.king_speed_full * 3.5))
	_sm.skill_levels["dash"] = 6
	kc._dash_timer = 0.0
	kc._dash_cooldown_timer = 0.0
	kc._cast_lock = 0.0
	kc.stamina = 100.0
	kc.request_dash()
	_check("dash speed L6 = 4.5x", is_equal_approx(float(kc.get("_dash_speed")), kc.king_speed_full * 4.5))

	# Dash strike damage uses the level curve.
	kc._dash_timer = 0.0
	kc.king_attack = 100.0
	kc._dash_dir = Vector3(1, 0, 0)
	kc._facing = 0.0
	var target := _spawn_enemy(Vector3(1.0, 0, 0.5))
	await process_frame
	_sm.skill_levels["dash"] = 6
	kc._dash_hits.clear()
	kc._dash_strike_enemies()
	_check("dash damage L6 = atk*0.70", is_equal_approx(target.hp, 500.0 - 100.0 * 0.70))
	target.queue_free()

	# Quake MP cost and damage.
	_sm.skill_levels["earthquake"] = 1
	kc._special_timer = 0.0
	kc.mana = 200.0
	kc.request_earthquake()
	_check("quake mp L1 leaves 160", is_equal_approx(kc.mana, 160.0))
	_sm.skill_levels["earthquake"] = 6
	kc._special_timer = 0.0
	kc.mana = 200.0
	kc.request_earthquake()
	_check("quake mp L6 leaves 175", is_equal_approx(kc.mana, 175.0))

	kc.king_attack = 100.0
	var quake_target := _spawn_enemy(Vector3(0.5, 0, 0.5))
	await process_frame
	_sm.skill_levels["earthquake"] = 1
	kc._special_timer = 0.0
	kc.mana = 200.0
	kc.request_earthquake()
	await process_frame
	_check("quake damage L1 = atk*2.0", is_equal_approx(quake_target.hp, 500.0 - 100.0 * 2.0))
	quake_target.queue_free()

	# Berserk multipliers.
	kc._base_attack = BASE_ATTACK
	kc._base_defense = BASE_DEFENSE
	kc.king_attack = BASE_ATTACK
	kc.king_defense = BASE_DEFENSE
	_sm.skill_levels["berserk"] = 1
	kc.set_berserk(true)
	_check("berserk atk L1 = 1.5x", is_equal_approx(kc.king_attack, BASE_ATTACK * 1.5))
	_check("berserk def L1 = 1.5x", is_equal_approx(kc.king_defense, BASE_DEFENSE * 1.5))
	kc.set_berserk(false)
	_sm.skill_levels["berserk"] = 6
	kc.set_berserk(true)
	_check("berserk atk L6 = 2.0x", is_equal_approx(kc.king_attack, BASE_ATTACK * 2.0))
	_check("berserk def L6 = 1.75x", is_equal_approx(kc.king_defense, BASE_DEFENSE * 1.75))

	# Drain cadence follows the level.
	kc.mana = 200.0
	_sm.skill_levels["berserk"] = 1
	kc._tick_berserk_drain(kc.BERSERK_DRAIN_INTERVAL)
	_check("drain L1 = 1.0 per interval", is_equal_approx(kc.mana, 199.0))
	_sm.skill_levels["berserk"] = 6
	kc.mana = 200.0
	kc._tick_berserk_drain(kc.BERSERK_DRAIN_INTERVAL)
	_check("drain L6 = 0.75 per interval", is_equal_approx(kc.mana, 199.25))

	if _fails == 0:
		print("KING_SKILL_SCALING_PASS")
		quit(0)
	else:
		print("KING_SKILL_SCALING_FAIL: %d" % _fails)
		quit(1)
