extends SceneTree

## Mechanism test for the metal impact spark: every damage landing on a unit spawns a
## short-lived, pooled spark at the strike point, bounded per frame. Buildings must stay
## excluded (see the source guard at the bottom). Layout/positions are deliberately not
## asserted -- only the mechanism (spawned where, how many, released when, who does not).

# Loaded at runtime: these scripts reference autoloads, which are not registered while a
# `-s` main script is still compiling its preloads.
const IMPACT_SPARK = preload("res://scenes/effects/MetalSpark.gd")
const ENEMY_SCRIPT_PATH := "res://scenes/run/enemy_script.gd"
const SOLDIER_SCRIPT_PATH := "res://scenes/run/SoldierUnit.gd"


func _initialize() -> void:
	_run()


func _count_sparks(parent: Node) -> int:
	var n := 0
	for child in parent.get_children():
		if child.get_script() == IMPACT_SPARK:
			n += 1
	return n


func _first_spark(parent: Node) -> Node3D:
	for child in parent.get_children():
		if child.get_script() == IMPACT_SPARK:
			return child
	return null


func _run() -> void:
	await process_frame

	var failures: Array[String] = []

	# --- 1. enemy receiver: a real enemy takes a hit -> one spark at the strike point ---
	var arena_a := Node3D.new()
	arena_a.name = "ArenaA"
	root.add_child(arena_a)
	await process_frame

	var enemy := Node3D.new()
	enemy.name = "Enemy"
	enemy.set_script(load(ENEMY_SCRIPT_PATH))
	enemy.set_meta("current_health", 50.0)
	enemy.set_meta("max_health", 50.0)
	enemy.set_meta("enemy_dead", false)
	enemy.position = Vector3(2.0, 0.0, 3.0)
	arena_a.add_child(enemy)
	await process_frame

	enemy.take_damage(5.0)
	await process_frame
	if _count_sparks(arena_a) != 1:
		failures.append("enemy hit did not spawn exactly one spark (got %d)" % _count_sparks(arena_a))
	else:
		var spark := _first_spark(arena_a)
		var expected := enemy.global_position + Vector3(0.0, IMPACT_SPARK.HIT_HEIGHT, 0.0)
		if spark.global_position.distance_to(expected) > 0.01:
			failures.append("spark not at strike point")

	# --- 2. a dead enemy re-hit must not spawn another ---
	enemy.set_meta("enemy_dead", true)
	enemy.take_damage(5.0)
	await process_frame
	if _count_sparks(arena_a) != 1:
		failures.append("dead enemy re-hit spawned a spark")

	# --- 3. per-frame cap: many strikes in one frame stay bounded ---
	var arena_b := Node3D.new()
	arena_b.name = "ArenaB"
	root.add_child(arena_b)
	var victim_b := Node3D.new()
	victim_b.name = "Victim"
	victim_b.position = Vector3(1.0, 0.0, 1.0)
	arena_b.add_child(victim_b)
	await physics_frame
	for i in 10:
		IMPACT_SPARK.spawn(victim_b)
	if _count_sparks(arena_b) != IMPACT_SPARK.MAX_SPARKS_PER_FRAME:
		failures.append("per-frame cap not enforced (got %d, want %d)"
			% [_count_sparks(arena_b), IMPACT_SPARK.MAX_SPARKS_PER_FRAME])

	# --- 4. sparks are released (left the tree) after their lifetime ---
	await create_timer(IMPACT_SPARK.SPARK_LIFETIME + 0.4).timeout
	if _count_sparks(arena_a) != 0:
		failures.append("spark was not released after its lifetime")
	if _count_sparks(arena_b) != 0:
		failures.append("capped sparks were not released after their lifetime")

	# --- 5. king receiver: the king taking a hit spawns one spark under its parent ---
	var arena_c := Node3D.new()
	arena_c.name = "ArenaC"
	root.add_child(arena_c)
	var kc: Node3D = load("res://scenes/run/KingController.tscn").instantiate()
	arena_c.add_child(kc)
	await process_frame
	await physics_frame
	kc.take_damage(10.0)
	await process_frame
	if _count_sparks(arena_c) != 1:
		failures.append("king hit did not spawn exactly one spark (got %d)" % _count_sparks(arena_c))

	# --- 6. soldier receiver: a real soldier taking a hit spawns one spark ---
	var arena_d := Node3D.new()
	arena_d.name = "ArenaD"
	root.add_child(arena_d)
	await process_frame
	var soldier: Node3D = Node3D.new()
	soldier.name = "Soldier"
	soldier.set_script(load(SOLDIER_SCRIPT_PATH))
	arena_d.add_child(soldier)
	await process_frame
	await physics_frame
	soldier.take_damage(5.0)
	await process_frame
	if _count_sparks(arena_d) != 1:
		failures.append("soldier hit did not spawn exactly one spark (got %d)" % _count_sparks(arena_d))

	# --- 7. buildings stay excluded: no building receiver may reference the spark ---
	for path in ["res://scenes/buildings/Pendopo.gd", "res://scenes/buildings/Building.gd"]:
		var src := FileAccess.get_file_as_string(path)
		if src.contains("MetalSpark") or src.contains("IMPACT_SPARK"):
			failures.append("%s references the impact spark (buildings must be excluded)" % path)

	if failures.is_empty():
		print("IMPACT_SPARKS_PASS")
		quit(0)
	else:
		for f in failures:
			printerr("IMPACT_SPARKS_FAIL: " + f)
		quit(1)
