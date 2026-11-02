extends SceneTree

# Regression: an enemy dealt damage and played its swing SFX while appearing to
# just walk. The pose was re-decided every frame from "is a target in reach",
# while damage was gated by the attack cooldown. Every call site set the attack
# pose before the strike, so the strike frame always looked right -- but the
# frame after, the drifting target let walk/idle steal the pose and the swing
# was cut off before it could be seen.
#
# The invariant: a landed swing stays on the attack pose long enough to read as
# one event with its sound and its damage. Asserted against frame timing only,
# so it holds regardless of how the lock is implemented.

const MAP_SIZE := 60
const MAX_FRAMES := 3000
const GROUND_Y := 0.3
# A swing the player can actually perceive. Damage and SFX land on frame 0.
const MIN_HOLD_SECONDS := 0.3
const HOLD_FRAMES := 18


func _initialize() -> void:
	_run()


func _inv_script() -> GDScript:
	return load("res://scenes/run/InvasionManager.gd")


func _run() -> void:
	await process_frame

	var holder := Node3D.new()
	root.add_child(holder)
	var terrain: Array = []
	for y in range(MAP_SIZE):
		var row: Array = []
		for x in range(MAP_SIZE):
			row.append(1)
		terrain.append(row)
	NavigationBuilder.build_navigation(terrain, holder, MAP_SIZE * 0.5, false)
	for i in 10:
		await process_frame

	var idx: Node = root.get_node("SpatialIndex")

	var pendopo := _make_pendopo(Vector3(20.0, GROUND_Y, 0.0))
	var inv: Node3D = _inv_script().new()
	inv.name = "InvasionManager"
	root.add_child(inv)
	inv.setup(null, [], terrain, 60.0)
	inv.set_king_ref(null)
	inv.set_pendopo_refs([pendopo])

	var grunt := _spawn(inv, Vector3(0.0, GROUND_Y, 0.0))

	# A soldier that steps in and out of the enemy's reach, which is what made
	# the enemy flicker between attack and walk in the reported bug.
	var soldier := _make_soldier(Vector3(18.0, GROUND_Y, 0.0))
	idx.register(soldier, "troops")

	var full_cd: float = _inv_script().get_script_constant_map()["ENEMY_ATTACK_COOLDOWN"]
	var swings := 0
	var strike_desyncs: Array = []
	var cut_desyncs: Array = []
	var in_reach_flips := 0
	var prev_in_reach := false
	var since_strike := HOLD_FRAMES + 1
	var frames := 0

	while frames < MAX_FRAMES and swings < 15:
		await physics_frame
		frames += 1
		var t: float = float(frames) / 60.0
		soldier.position = Vector3(18.0 + sin(t * 5.5) * 1.6, GROUND_Y, cos(t * 5.5) * 1.6)

		var cd: float = float(grunt.get_meta("attack_cooldown", 0.0))
		var state: String = grunt.get_meta("anim_state", "")

		# The target leaving and regaining reach is what used to break the pose.
		var in_reach: bool = soldier.position.distance_to(grunt.position) <= 2.0
		if in_reach != prev_in_reach:
			in_reach_flips += 1
			prev_in_reach = in_reach

		since_strike += 1
		if cd >= full_cd - 0.001:
			# An enemy that just swung has its cooldown reset to the full value.
			swings += 1
			since_strike = 0
			if state != "attack":
				strike_desyncs.append(
					"frame %d: swing landed with anim_state=%s" % [frames, state]
				)
		elif since_strike <= HOLD_FRAMES and state != "attack":
			cut_desyncs.append(
				"frame %d: swing cut %d frames in (anim_state=%s)"
				% [frames, since_strike, state]
			)

	var hp: float = float(soldier.get("hp"))
	print(
		"swings=", swings, " reach_flips=", in_reach_flips,
		" soldier_hp=", hp,
		" strike_desyncs=", strike_desyncs.size(),
		" cut_desyncs=", cut_desyncs.size()
	)

	# The scenario only means something if the target really did flicker.
	if in_reach_flips < 6:
		print("FAIL: target never drifted in and out of reach (", in_reach_flips, ")")
		quit(1)
		return
	if swings < 5:
		print("FAIL: too few swings observed (", swings, ")")
		quit(1)
		return
	if hp >= 1000.0:
		print("FAIL: soldier was never hit, combat did not happen (hp=", hp, ")")
		quit(1)
		return
	if strike_desyncs.size() > 0:
		for d in strike_desyncs.slice(0, 8):
			print("  ", d)
		print("FAIL: ", strike_desyncs.size(), " swings landed without the attack pose")
		quit(1)
		return
	if cut_desyncs.size() > 0:
		for d in cut_desyncs.slice(0, 8):
			print("  ", d)
		print(
			"FAIL: ", cut_desyncs.size(),
			" swings were cut short of ", MIN_HOLD_SECONDS, "s (damage and SFX read as walking)"
		)
		quit(1)
		return

	print("ENEMY_ATTACK_CONSISTENCY_PASS")
	quit(0)


func _make_pendopo(pos: Vector3) -> Node3D:
	var p := Node3D.new()
	p.position = pos
	var ps := GDScript.new()
	ps.source_code = """
extends Node3D
var building_id: String = "pendopo"
var hp: float = 100000.0
func take_damage(amount: float) -> void:
	hp -= amount
"""
	ps.reload()
	p.set_script(ps)
	root.add_child(p)
	return p


func _make_soldier(pos: Vector3) -> Node3D:
	var s := Node3D.new()
	s.position = pos
	var ss := GDScript.new()
	ss.source_code = """
extends Node3D
var hp: float = 1000.0
var max_hp: float = 1000.0
var building_id: String = ""
func take_damage(amount: float) -> void:
	hp -= amount
func is_dead() -> bool:
	return hp <= 0.0
"""
	ss.reload()
	s.set_script(ss)
	s.add_to_group("troops")
	root.add_child(s)
	return s


func _spawn(inv: Node3D, pos: Vector3) -> Node3D:
	var data: Dictionary = {
		"type": "infantry", "attack": 6.0, "defense": 1.0, "health": 4000.0,
		"max_health": 4000.0, "name": "infantry", "is_boss": false,
		"color": Color.RED, "speed": 2.5,
	}
	var e: Node3D = inv._create_enemy_node(data, pos)
	inv.add_child(e)
	inv._enemy_nodes.append(e)
	return e
