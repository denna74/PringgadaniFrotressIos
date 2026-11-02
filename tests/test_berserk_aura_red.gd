extends SceneTree

## The berserk aura swaps to the red frame set once the skill reaches the
## Kudalikombang tier (levels 4-6); levels 1-3 keep the original frames.

const AURA_DELAY_FRAMES: int = 24
const BASE_ATTACK: float = 40.0
const BASE_DEFENSE: float = 10.0

var _fails: int = 0


func _initialize() -> void:
	_run()


func _check(name: String, ok: bool) -> void:
	if ok:
		print("OK  ", name)
	else:
		_fails += 1
		print("CHECK FAIL: " + name)


func _wait_physics(frames: int) -> void:
	for i in frames:
		await physics_frame


func _make_king() -> Node3D:
	var kc: Node3D = load("res://scenes/run/KingController.tscn").instantiate()
	kc.position = Vector3.ZERO
	kc.set_play_field(8)
	kc.setup_king({
		"hp": 9999.0,
		"attack": BASE_ATTACK,
		"defense": BASE_DEFENSE,
		"mana_max": 200.0,
	})
	root.add_child(kc)
	return kc


func _aura(kc: Node3D) -> Node:
	return kc.get_node_or_null("BerserkAura")


func _frame_paths(aura: Node) -> PackedStringArray:
	var out := PackedStringArray()
	var frames: Array = aura.get("_frames")
	for tex in frames:
		out.append((tex as Texture2D).resource_path)
	return out


func _any_red(paths: PackedStringArray) -> bool:
	for p in paths:
		if p.ends_with("_red.png"):
			return true
	return false


func _all_suffixed(paths: PackedStringArray, suffix: String) -> bool:
	for p in paths:
		if not p.ends_with(suffix):
			return false
	return true


func _check_aura_at_level(level: int, expect_red: bool) -> void:
	var sm = root.get_node("/root/SaveManager")
	sm.skill_levels = {"dash": 1, "earthquake": 1, "berserk": level}
	var kc := _make_king()
	await process_frame
	kc.request_berserk()
	await _wait_physics(AURA_DELAY_FRAMES + 2)
	var aura := _aura(kc)
	if aura == null:
		_check("lv%d aura spawned" % level, false)
	else:
		var paths := _frame_paths(aura)
		if expect_red:
			_check("lv%d aura red frames" % level,
				paths.size() == 4 and _all_suffixed(paths, "_red.png"))
		else:
			_check("lv%d aura normal frames" % level,
				paths.size() == 4 and not _any_red(paths))
	kc.queue_free()
	await process_frame


func _run() -> void:
	await process_frame

	var script: GDScript = load("res://scenes/effects/BerserkAura.gd")

	var plain: Node3D = script.new()
	root.add_child(plain)
	await process_frame
	var plain_paths := _frame_paths(plain)
	_check("default aura normal frames",
		plain_paths.size() == 4 and not _any_red(plain_paths))
	plain.queue_free()
	await process_frame

	var red: Node3D = script.new()
	red.set("use_red", true)
	root.add_child(red)
	await process_frame
	var red_paths := _frame_paths(red)
	_check("use_red aura red frames",
		red_paths.size() == 4 and _all_suffixed(red_paths, "_red.png"))
	red.queue_free()
	await process_frame

	await _check_aura_at_level(1, false)
	await _check_aura_at_level(3, false)
	await _check_aura_at_level(4, true)
	await _check_aura_at_level(5, true)
	await _check_aura_at_level(6, true)

	if _fails == 0:
		print("BERSERK_AURA_RED_PASS")
		quit(0)
	else:
		print("BERSERK_AURA_RED_FAIL: %d" % _fails)
		quit(1)
