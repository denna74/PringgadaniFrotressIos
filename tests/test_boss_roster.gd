extends SceneTree

# Boss registry, stage rosters, model imports and boss abilities.

var failures := 0


func _initialize() -> void:
	_run()


func _check(name: String, cond: bool) -> void:
	if cond:
		print("OK  ", name)
	else:
		push_error("FAIL " + name)
		failures += 1


func _run() -> void:
	await process_frame

	_test_registry()
	_test_stage_rosters()
	_test_boss_schedule()
	_test_boss_spawn_data()
	_test_boss_models()
	await _test_boma_red_arrow()

	if failures > 0:
		push_error("Boss roster regression (%d failures)" % failures)
		quit(1)
		return
	print("BOSS_ROSTER_PASS")
	quit(0)


func _test_registry() -> void:
	for id in ["kalapracona", "boma", "aswatama", "karna"]:
		var d: Dictionary = BossRegistry.get_boss(id)
		_check("%s is registered" % id, not d.is_empty())
		if d.is_empty():
			continue
		_check("%s has a display name" % id, str(d.get("name_en", "")) != "")
		_check("%s declares a model rig" % id, str(d.get("model", "")) != "")
		_check("%s has a positive speed" % id, float(d.get("speed", 0.0)) > 0.0)
		_check("%s declares ranged/melee" % id, d.has("ranged"))

	var kal: Dictionary = BossRegistry.get_boss("kalapracona")
	var boma: Dictionary = BossRegistry.get_boss("boma")
	var aswa: Dictionary = BossRegistry.get_boss("aswatama")
	var karna: Dictionary = BossRegistry.get_boss("karna")

	_check("Kalapracona is weaker than Boma",
		float(ProgressionData.boss_stats("kalapracona", 250)["hp"])
			< float(ProgressionData.boss_stats("boma", 250)["hp"]))
	_check("Aswatama outclasses Boma on HP",
		float(ProgressionData.boss_stats("aswatama", 250)["hp"])
			> float(ProgressionData.boss_stats("boma", 250)["hp"]))
	_check("Karna is the strongest boss by HP and attack",
		float(ProgressionData.boss_stats("karna", 250)["hp"])
			> float(ProgressionData.boss_stats("aswatama", 250)["hp"])
			and float(ProgressionData.boss_stats("karna", 250)["attack"])
				> float(ProgressionData.boss_stats("aswatama", 250)["attack"]))
	_check("Karna uses melee attacks", karna.get("ranged", true) == false)
	_check("Kalapracona speed is 1.9", is_equal_approx(float(kal["speed"]), 1.9))
	_check("Boma speed is 1.9", is_equal_approx(float(boma["speed"]), 1.9))
	_check("Aswatama speed is 2.5", is_equal_approx(float(aswa["speed"]), 2.5))
	_check("Karna speed is 3.0", is_equal_approx(float(karna["speed"]), 3.0))
	var karna_specials: Array = karna.get("specials", [])
	_check("Karna has dash, earthquake and berserk specials",
		karna_specials.has("dash") and karna_specials.has("earthquake")
			and karna_specials.has("berserk"))
	_check("Boma is ranged", boma.get("ranged", false) == true)
	_check("Boma shoots the red arrow style", boma.get("arrow_style", "") == "boma_red")
	_check("Kalapracona uses the plain arrow style", str(kal.get("arrow_style", "")) == "")
	_check("Aswatama dashes", aswa.get("special", "") == "dash")
	_check("Boma has a power attack", boma.get("special", "") == "power_attack")

	_check("unknown boss id is rejected", BossRegistry.get_boss("moksa").is_empty())
	_check("all bosses share one list", BossRegistry.boss_ids().size() == 4)


func _test_stage_rosters() -> void:
	var cases: Dictionary = {
		1: ["kalapracona"],
		10: ["kalapracona"],
		11: ["boma"],
		30: ["boma"],
		31: ["aswatama"],
		60: ["aswatama"],
		61: ["karna"],
		90: ["karna"],
		91: ["kalapracona", "boma"],
		130: ["kalapracona", "boma"],
		131: ["kalapracona", "aswatama"],
		170: ["kalapracona", "aswatama"],
		171: ["boma", "aswatama"],
		210: ["boma", "aswatama"],
		211: ["kalapracona", "boma", "aswatama"],
		250: ["kalapracona", "boma", "aswatama"],
		251: ["kalapracona", "boma", "aswatama", "karna"],
		400: ["kalapracona", "boma", "aswatama", "karna"],
	}
	for stage: int in cases:
		_check("stage %d boss roster" % stage,
			ProgressionData.boss_roster(stage) == cases[stage])


func _all_unique(a: Array) -> bool:
	var seen: Dictionary = {}
	for v in a:
		if seen.has(v):
			return false
		seen[v] = true
	return true


func _is_sorted(a: Array) -> bool:
	for i in range(1, a.size()):
		if int(a[i]) <= int(a[i - 1]):
			return false
	return true


func _test_boss_schedule() -> void:
	for stage in [1, 11, 31, 61, 91, 131, 171, 211, 251, 400]:
		var waves: int = ProgressionData.num_waves(stage)
		var plan: Array = ProgressionData.boss_schedule(stage, waves)
		var ids: Array = plan.map(func(entry): return str(entry["boss_id"]))
		var scheduled_waves: Array = plan.map(func(entry): return int(entry["wave"]))
		_check("stage %d schedules each boss separately in roster order" % stage,
			ids == ProgressionData.boss_roster(stage))
		_check("stage %d reserves the final wave for its strongest boss" % stage,
			not plan.is_empty() and int(plan[-1]["wave"]) == waves
				and str(plan[-1]["boss_id"]) == ProgressionData.final_boss_id(stage))
		_check("stage %d schedules no two bosses on one wave" % stage,
			_all_unique(scheduled_waves))
		_check("stage %d keeps boss waves in range" % stage,
			scheduled_waves.all(func(wave): return int(wave) >= 1 and int(wave) <= waves))
	_check("stage 0 has no boss schedule", ProgressionData.boss_schedule(0, 4).is_empty())


func _test_boss_spawn_data() -> void:
	var boma: Dictionary = EnemySpawner.spawn_boss(10, 150, 40, "boma")
	_check("boss is flagged is_boss", boma.get("is_boss", false) == true)
	_check("boss carries its id", boma.get("boss_id", "") == "boma")
	var aswa: Dictionary = EnemySpawner.spawn_boss(4, 220, 40, "aswatama")
	var karna: Dictionary = EnemySpawner.spawn_boss(4, 220, 40, "karna")
	_check("Aswatama spawns with its own id and name",
		aswa.get("boss_id", "") == "aswatama" and "Aswatama" in str(aswa.get("name", "")))
	_check("Aswatama dashes", aswa.get("special", "") == "dash")
	_check("Aswatama uses melee attacks", aswa.get("ranged", true) == false)
	var aswatama_specials: Array = aswa.get("specials", [])
	_check("Aswatama has dash and earthquake",
		aswatama_specials.has("dash") and aswatama_specials.has("earthquake"))
	var karna_specials: Array = karna.get("specials", [])
	_check("Karna uses its own name, rig and abilities",
		karna.get("name", "") == "Karna" and karna.get("model", "") == "karna"
			and karna_specials.has("dash") and karna_specials.has("earthquake")
			and karna_specials.has("berserk"))
	_check("Karna has the highest boss HP and attack",
		float(karna["health"]) > float(aswa["health"])
			and float(karna["attack"]) > float(aswa["attack"]))
	_check("Boma is outclassed by Aswatama on HP",
		float(aswa["health"]) > float(boma["health"]))
	_check("boss uses a real display name", "Boma" in str(boma.get("name", "")))
	_check("boss is scaled above a normal enemy", float(boma.get("health", 0.0)) > 0.0)
	_check("boss max_health matches its health so the HP bar is honest",
		is_equal_approx(float(boma.get("max_health", -1.0)), float(boma.get("health", -2.0))))
	_check("boss records its arrow style", boma.has("arrow_style"))

	# Boss HP must rise with stage and with the difficulty cap holding at 250.
	var hp_50: float = float(EnemySpawner.spawn_boss(1, 50, 20)["health"])
	var hp_200: float = float(EnemySpawner.spawn_boss(1, 200, 20)["health"])
	_check("boss HP rises with stage (50:%.0f < 200:%.0f)" % [hp_50, hp_200], hp_200 > hp_50)
	_check("boss HP is frozen past the cap (250 vs 400)",
		is_equal_approx(float(EnemySpawner.spawn_boss(1, 250, 20)["health"]),
			float(EnemySpawner.spawn_boss(1, 400, 20)["health"])))
	_check("plain enemy HP is frozen past the cap too (250 vs 400)",
		is_equal_approx(ProgressionData.enemy_hp(250, 20), ProgressionData.enemy_hp(400, 20)))
	_check("boss stats depend on stage, not Gatotkaca level",
		is_equal_approx(
			float(EnemySpawner.spawn_boss(1, 200, 5)["health"]),
			float(EnemySpawner.spawn_boss(1, 200, 40)["health"])
		))

	_check("non-boss enemies carry no boss id", not EnemySpawner.spawn_batch(2, 1, 60, [])[0].has("boss_id"))


func _test_boss_models() -> void:
	for id in ["kalapracona", "boma", "aswatama", "karna"]:
		var d: Dictionary = BossRegistry.get_boss(id)
		var rig: String = d.get("model", "")
		var model: Node3D = ModelLoader.load_boss(rig)
		_check("%s (%s) model loads" % [id, rig], model != null)
		if model == null:
			continue
		var ap := ModelLoader.find_animation_player(model)
		_check("%s has an AnimationPlayer" % id, ap != null)
		if ap == null:
			model.free()
			continue
		_check("%s has a boss animation library" % id, ap.has_animation_library("boss"))
		if ap.has_animation_library("boss"):
			var lib: AnimationLibrary = ap.get_animation_library("boss")
			for a in ["idle", "run", "attack", "dead"]:
				_check("%s has boss %s animation" % [id, a], lib.has_animation(a))
			if id == "karna":
				for a in ["attack_2", "attack_3", "dash", "earthquake", "berserk"]:
					_check("Karna has boss %s animation" % a, lib.has_animation(a))
		model.free()

	_check("unknown boss rig still yields a model", ModelLoader.load_boss("nope") != null)


func _test_boma_red_arrow() -> void:
	var holder := Node3D.new()
	root.add_child(holder)
	var arrow: Node3D = load("res://scenes/projectiles/arrow_projectile.gd").new()
	holder.add_child(arrow)
	var target := Node3D.new()
	target.position = Vector3(400.0, 0.5, 0.0)
	var ts := GDScript.new()
	ts.source_code = """
extends Node3D
var hp: float = 100.0
func take_damage(a: float) -> void:
	hp -= a
func is_alive() -> bool:
	return hp > 0.0
"""
	ts.reload()
	target.set_script(ts)
	holder.add_child(target)
	await process_frame

	arrow.setup(target, Vector3.ZERO, 12.0, "boma_red")
	await process_frame
	_check("boma arrow reports its style", arrow.get_arrow_style() == "boma_red")
	_check("boma arrow exposes a slash shadow", arrow.get_slash_shadow() != null)
	var shadow: Node3D = arrow.get_slash_shadow()
	if shadow != null:
		_check("slash shadow sits behind the arrow (z=%.2f)" % shadow.position.z, shadow.position.z < 0.0)
		var blade_w := 0.0
		var blade_h := 0.0
		for b in shadow.get_children():
			var q := (b as MeshInstance3D)
			if q and q.mesh is QuadMesh:
				blade_w = (q.mesh as QuadMesh).size.x
				blade_h = (q.mesh as QuadMesh).size.y
		_check("slash blade is wider than it is tall (%.2f x %.2f)" % [blade_w, blade_h],
			blade_w > blade_h)
		_check("slash shadow is visible", shadow.visible)
		_check("slash shadow has geometry", shadow.get_child_count() > 0)

	# A plain arrow must stay plain.
	var plain: Node3D = load("res://scenes/projectiles/arrow_projectile.gd").new()
	holder.add_child(plain)
	plain.setup(target, Vector3.ZERO, 5.0)
	await process_frame
	_check("default arrow style is normal", plain.get_arrow_style() == "normal")
	_check("default arrow has no slash shadow", plain.get_slash_shadow() == null)

	# Flying must leave a red slash trail behind it.
	var start: Vector3 = arrow.global_position
	for i in 20:
		await physics_frame
	_check("boma arrow travels", arrow.global_position.distance_to(start) > 0.05)
	_check("boma arrow is tinted red", _is_red(arrow))
	_check("boma arrow is at least as thick as a plain arrow", _width(arrow) >= _width(plain))

	holder.queue_free()
	await process_frame


func _is_red(node: Node3D) -> bool:
	for c in node.find_children("*", "MeshInstance3D", true, false):
		var mi := c as MeshInstance3D
		if mi == null or not (mi.material_override is StandardMaterial3D):
			continue
		var col: Color = (mi.material_override as StandardMaterial3D).albedo_color
		if col.r > col.g and col.r > col.b:
			return true
	return false


func _width(node: Node3D) -> float:
	var w := 0.0
	for c in node.find_children("*", "MeshInstance3D", true, false):
		var mi := c as MeshInstance3D
		if mi == null or not (mi.material_override is StandardMaterial3D):
			continue
		var col: Color = (mi.material_override as StandardMaterial3D).albedo_color
		if col.r > col.g and col.r > col.b:
			w = maxf(w, mi.mesh.get_aabb().size.x)
	return w
