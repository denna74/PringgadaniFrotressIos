extends SceneTree

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

	_test_plot_capacity()
	_test_buildable_per_pendopo()
	_test_cluster_is_not_a_ring()
	_test_plot_spacing()
	_test_low_stage_plots_not_crowded()
	_test_generation_speed()
	_test_spawn_zones_exist()

	if failures > 0:
		push_error("Arena scaling regression (%d failures)" % failures)
		quit(1)
		return
	print("ARENA_SCALING_PASS")
	quit(0)


func _test_plot_capacity() -> void:
	print("-- plot capacity --")
	# The generator must be able to place every plot the progression asks for.
	# MapGenerator used a fixed 20-entry offset table, capping arenas at 21 plots.
	for s in [1, 30, 50, 100, 150, 200, 250]:
		var wanted: int = ProgressionData.building_plots(s)
		var data: Dictionary = MapGenerator.generate(s)
		var got: int = (data.get("plots", []) as Array).size()
		_check(
			"S%d placed %d of %d wanted plots" % [s, got, wanted],
			got == wanted
		)
	# Beyond the cap the count must stay frozen, not keep climbing.
	_check(
		"S400 plot count identical to S250",
		(MapGenerator.generate(400).get("plots", []) as Array).size()
			== (MapGenerator.generate(250).get("plots", []) as Array).size()
	)


func _test_buildable_per_pendopo() -> void:
	print("-- 6 buildable plots scatter near each pendopo --")
	# The user's rule: buildable plots cluster around each pendopo, and the total
	# never scales with the stage number. Guards against a stage-based ramp being
	# reintroduced and re-flooding the arena with unused placeholders.
	for s in [1, 49, 50, 100, 149, 150, 200, 250, 400]:
		var pendopos: int = ProgressionData.pendopo_count(s)
		_check(
			"S%d plot total = 7 x %d pendopos" % [s, pendopos],
			ProgressionData.building_plots(s) == (ProgressionData.BUILDABLE_PER_PENDOPO + 1) * pendopos
		)

	# Every pendopo must actually get its own loose scatter of buildable plots, and
	# that scatter must stay inside the scatter band so buildings never end up
	# marooned far from the base they defend.
	for s in [1, 50, 150, 250]:
		var reach: float = _max_reach(s)
		var data: Dictionary = MapGenerator.generate(s)
		var sites: Array = data.get("pendopo_plots", []) as Array
		var plots: Array = data.get("plots", []) as Array
		_check("S%d pendopo count matches" % s, sites.size() == ProgressionData.pendopo_count(s))
		var all_rings := true
		for site in sites:
			var ring := 0
			for p in plots:
				if p == site or (p as Vector2i).distance_to(site as Vector2i) > reach:
					continue
				# A plot inside this base's band may still belong to a neighbouring base:
				# on a 96x96 arena the bases sit ~43 tiles apart with a scatter band of
				# ~22, so the two bands meet in the middle. Count a plot only if this
				# base is the closest one to it.
				var nearest: Vector2i = site
				var nearest_dist: float = (p as Vector2i).distance_to(site as Vector2i)
				for other in sites:
					if other == site:
						continue
					var d: float = (p as Vector2i).distance_to(other as Vector2i)
					if d < nearest_dist:
						nearest = other
						nearest_dist = d
				if nearest == site:
					ring += 1
			if ring != ProgressionData.BUILDABLE_PER_PENDOPO:
				all_rings = false
		_check(
			"S%d every pendopo owns exactly %d buildable plots" % [s, ProgressionData.BUILDABLE_PER_PENDOPO],
			all_rings
		)


# The scatter band is solved from the arena size, not a constant, so the widest
# distance a plot may sit from its base differs per stage.
func _max_reach(stage: int) -> float:
	return MapGenerator._scatter_max(ProgressionData.map_size(stage), ProgressionData.pendopo_count(stage)) + 1.0


func _test_cluster_is_not_a_ring() -> void:
	print("-- buildable clusters are not drawn as a circle --")
	# The user disliked the plots forming a perfect ring around each pendopo. A
	# fixed-radius ring has a tiny closed set of distances (measured: 3 distinct
	# values, 4.47..5.0 for radius 5), whereas a random scatter fans out across the
	# whole band. Sampling many generations makes this stable -- a per-cluster
	# check is not, since random scatter occasionally lands near-even.
	for s in [1, 50, 150, 250]:
		var reach: float = _max_reach(s)
		var seen: Dictionary = {}
		var lo := INF
		var hi := -INF
		for trial in 40:
			var data: Dictionary = MapGenerator.generate(s)
			for site in data.get("pendopo_plots", []) as Array:
				for p in data.get("plots", []) as Array:
					if p == site:
						continue
					var dist: float = (p as Vector2i).distance_to(site as Vector2i)
					if dist > reach:
						continue
					seen[snappedf(dist, 0.01)] = true
					lo = minf(lo, dist)
					hi = maxf(hi, dist)
		_check(
			"S%d cluster radii fan out (%d distinct, %.2f..%.2f) not a ring" % [s, seen.size(), lo, hi],
			seen.size() > 12
		)


func _test_plot_spacing() -> void:
	print("-- plot spacing --")
	# Plots must not overlap, or buildings will z-fight and block each other.
	# Low stages belong here too: the 32x32 single-pendopo arena used to be skipped
	# entirely, which is how its crowding went unnoticed.
	for s in [1, 10, 49, 50, 150, 250]:
		var plots: Array = MapGenerator.generate(s).get("plots", [])
		var worst: float = INF
		for i in range(plots.size()):
			for j in range(i + 1, plots.size()):
				var d: float = (plots[i] as Vector2i).distance_to(plots[j] as Vector2i)
				worst = minf(worst, d)
		_check("S%d minimum plot spacing %.2f >= 4 tiles" % [s, worst], worst >= 4.0)
		# Every plot must sit on the map.
		var size: int = ProgressionData.map_size(s)
		var on_map := true
		for p in plots:
			if (p as Vector2i).x < 0 or (p as Vector2i).x >= size or (p as Vector2i).y < 0 or (p as Vector2i).y >= size:
				on_map = false
		_check("S%d all plots inside %dx%d map" % [s, size, size], on_map)


func _test_low_stage_plots_not_crowded() -> void:
	print("-- low stage plots are not crowded --")
	# Two 3x3 buildings at exactly 4 tiles apart have a single tile of ground between
	# them and read as touching, so 4.0 is the crowding floor, not the target. The
	# generator used to solve the lone-base arena against a neighbour-separation
	# bound that does not apply when there is no neighbour, capping the scatter at
	# 6.9 of an available 14.5 tiles and packing every plot to the 4.0 floor.
	#
	# Averaged over many generations, because random scatter occasionally lands
	# near-even and a per-map check would be flaky.
	const TOUCHING_FLOOR := 4.5
	const MIN_FOOTPRINT := 0.6
	for s in [1, 10, 49]:
		var size: int = ProgressionData.map_size(s)
		var spacing_sum := 0.0
		var footprint_sum := 0.0
		var trials := 40
		for trial in trials:
			var plots: Array = MapGenerator.generate(s).get("plots", [])
			var worst := INF
			var lo := Vector2i(9999, 9999)
			var hi := Vector2i(-9999, -9999)
			for i in plots.size():
				lo.x = mini(lo.x, (plots[i] as Vector2i).x)
				lo.y = mini(lo.y, (plots[i] as Vector2i).y)
				hi.x = maxi(hi.x, (plots[i] as Vector2i).x)
				hi.y = maxi(hi.y, (plots[i] as Vector2i).y)
				for j in range(i + 1, plots.size()):
					worst = minf(worst, (plots[i] as Vector2i).distance_to(plots[j] as Vector2i))
			spacing_sum += worst
			footprint_sum += float(maxi(hi.x - lo.x, hi.y - lo.y))
		var avg_spacing: float = spacing_sum / float(trials)
		var avg_footprint: float = footprint_sum / float(trials) / float(size)
		_check(
			"S%d avg tightest spacing %.2f >= %.1f (not pressed against buildings)" % [s, avg_spacing, TOUCHING_FLOOR],
			avg_spacing >= TOUCHING_FLOOR
		)
		_check(
			"S%d plots use %.0f%% of the arena (>= %.0f%%), not a central blob" % [s, avg_footprint * 100.0, MIN_FOOTPRINT * 100.0],
			avg_footprint >= MIN_FOOTPRINT
		)


func _test_generation_speed() -> void:
	print("-- generation speed --")
	# A 464x464 stage-250 map is the worst case; _fill_path_holes loops O(n^2).
	var start := Time.get_ticks_msec()
	MapGenerator.generate(250)
	var elapsed := Time.get_ticks_msec() - start
	_check("stage 250 generation under 4000ms (took %dms)" % elapsed, elapsed < 4000)


func _test_spawn_zones_exist() -> void:
	print("-- spawn zones --")
	for s in [1, 150, 250]:
		var zones: Array = MapGenerator.generate(s).get("spawn_zones", [])
		_check("S%d has spawn zones (%d)" % [s, zones.size()], zones.size() > 0)
