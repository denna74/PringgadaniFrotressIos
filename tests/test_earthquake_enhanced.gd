extends SceneTree

## Narantaka (earthquake level > 3) swaps the shockwave for a bigger red
## building-destroy style burst; levels 1-3 keep the original orange ring.

const DEFAULT_FIRE_AMOUNT: int = 70
const ENHANCED_FIRE_AMOUNT: int = 80

var _fails: int = 0


func _initialize() -> void:
	_run()


func _check(name: String, ok: bool) -> void:
	if ok:
		print("OK  ", name)
	else:
		_fails += 1
		print("CHECK FAIL: " + name)


func _fire(effect: Node) -> CPUParticles3D:
	return effect.get_node_or_null("FireParticles") as CPUParticles3D


func _ring_material(effect: Node) -> StandardMaterial3D:
	var ring: MeshInstance3D = effect.get("_ring")
	if ring == null:
		return null
	return ring.material_override as StandardMaterial3D


func _make_king(level: int) -> Node3D:
	var sm = root.get_node("/root/SaveManager")
	sm.skill_levels = {"dash": 1, "earthquake": level, "berserk": 1}
	var kc: Node3D = load("res://scenes/run/KingController.tscn").instantiate()
	kc.position = Vector3.ZERO
	kc.set_play_field(8)
	kc.setup_king({"hp": 9999.0, "attack": 10.0, "mana_max": 200.0})
	kc.mana = 200.0
	root.add_child(kc)
	for i in 20:
		await process_frame
	return kc


func _run() -> void:
	await process_frame

	var eq_script: GDScript = load("res://scenes/effects/EarthquakeEffect.gd")

	var plain: Node3D = eq_script.new()
	root.add_child(plain)
	await process_frame
	var fire1 := _fire(plain)
	_check("default fire amount 70",
		fire1 != null and fire1.amount == DEFAULT_FIRE_AMOUNT)
	var mat1 := _ring_material(plain)
	_check("default ring no energy boost",
		mat1 != null and is_equal_approx(mat1.emission_energy_multiplier, 1.0))
	plain.queue_free()
	await process_frame

	var enhanced: Node3D = eq_script.new()
	enhanced.set("enhanced", true)
	root.add_child(enhanced)
	await process_frame
	var fire2 := _fire(enhanced)
	_check("enhanced fire amount 80",
		fire2 != null and fire2.amount == ENHANCED_FIRE_AMOUNT)
	_check("enhanced fire explosive",
		fire2 != null and fire2.explosiveness > 0.9)
	if fire2 != null and fire2.color_ramp != null and fire2.color_ramp.colors.size() > 0:
		var c0: Color = fire2.color_ramp.colors[0]
		_check("enhanced fire ramp yellow", c0.r > 0.9 and c0.g > 0.6 and c0.b < 0.6)
	else:
		_check("enhanced fire ramp yellow", false)
	var fire_mat: StandardMaterial3D = null
	if fire2 != null and fire2.mesh != null:
		fire_mat = fire2.mesh.material as StandardMaterial3D
	_check("enhanced fire uses vertex color",
		fire_mat != null and fire_mat.vertex_color_use_as_albedo)
	var mat2 := _ring_material(enhanced)
	if mat2 != null:
		_check("enhanced ring energy boost", mat2.emission_energy_multiplier > 1.5)
		_check("enhanced ring redder",
			mat2.albedo_color.r > 0.9 and mat2.albedo_color.g < 0.35)
	else:
		_check("enhanced ring energy boost", false)
		_check("enhanced ring redder", false)
	enhanced.queue_free()
	await process_frame

	var kc: Node3D = await _make_king(3)
	kc.request_earthquake()
	await process_frame
	var eq3: Node = kc.get_node_or_null("EarthquakeEffect")
	_check("lv3 cast spawns effect", eq3 != null)
	if eq3 != null:
		var f3 := _fire(eq3)
		_check("lv3 effect is default",
			f3 != null and f3.amount == DEFAULT_FIRE_AMOUNT)
	kc.queue_free()
	await process_frame

	kc = await _make_king(4)
	kc.request_earthquake()
	await process_frame
	var eq4: Node = kc.get_node_or_null("EarthquakeEffect")
	_check("lv4 cast spawns effect", eq4 != null)
	if eq4 != null:
		var f4 := _fire(eq4)
		_check("lv4 effect is enhanced",
			f4 != null and f4.amount == ENHANCED_FIRE_AMOUNT)
	kc.queue_free()
	await process_frame

	if _fails == 0:
		print("EARTHQUAKE_ENHANCED_PASS")
		quit(0)
	else:
		print("EARTHQUAKE_ENHANCED_FAIL: %d" % _fails)
		quit(1)
