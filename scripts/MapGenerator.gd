class_name MapGenerator extends RefCounted


const TILE_GRASS := 0
const TILE_PATH := 1
const TILE_OBSTACLE := 2
const TILE_RESOURCE := 3
const TILE_SPAWN := 4

const TILE_SIZE := 32

const OBSTACLE_CLEARANCE_SQ: float = 16.0
const RESOURCE_CLEARANCE_SQ: float = 25.0

# Two 3x3 buildings need their plot centres 4 tiles apart, so no two plots may ever
# land closer than this.
const MIN_PLOT_SPACING_SQ: float = 16.0

# Buildable plots scatter loosely around each pendopo: close enough that a
# building is always within walking distance of the base it defends, irregular
# enough that a cluster never reads as a circle drawn around the pendopo.
#
# Both radii are derived from the arena size in _scatter_limits. Buildings are 3x3,
# so a base and a plot need 4 tiles of centre-to-centre gap to avoid touching; a
# 4.5 centre-to-centre gap left ~1.5 tiles of visible ground and read as contact.
const PENDOPO_SCATTER_MIN_RATIO: float = 0.5
const PENDOPO_SCATTER_ATTEMPTS: int = 40

# How many times a base discards its whole partial cluster and starts over. Independent
# restarts, so this converges on the layouts that fit; see _scatter_plots.
const PENDOPO_SCATTER_RESTARTS: int = 24

# Half the width of a 3x3 building, in tiles. A plot this far out from the base
# centre already overlaps the base itself.
const PENDOPO_HALF_WIDTH: float = 1.5

# Bases sit on whole tiles, so the separation two ring positions should have is never
# reached exactly -- rounding each one can pull the pair up to sqrt(2) closer. Held
# back from the scatter solve so clusters cannot overlap on the unlucky phases.
const PENDOPO_ROUNDING_SLACK: float = 1.5

# Roads from the hub out to the map edges, independent of arena size.
const MAX_EDGE_PATHS: int = 6


static func generate(stage: int) -> Dictionary:
	randomize()

	var map_size: int = ProgressionData.map_size(stage)
	var center := Vector2i(map_size / 2, map_size / 2)

	var terrain := _generate_terrain(map_size)
	var pendopo_plots := _place_pendopo_sites(center, ProgressionData.pendopo_count(stage), map_size)
	var plots := _place_clustered_plots(terrain, pendopo_plots, map_size, pendopo_plots.size())
	_place_obstacles(terrain, plots, map_size, stage)
	_place_resource_nodes(terrain, plots, map_size)
	var spawn_zones := _generate_spawn_zones(map_size)
	var resource_nodes := _collect_resource_positions(terrain)

	_generate_paths(terrain, plots, pendopo_plots, map_size)
	_absorb_adjacent_to_path(terrain, map_size)
	_fill_path_holes(terrain, map_size)
	_absorb_adjacent_to_path(terrain, map_size)

	var paths := _collect_path_positions(terrain)

	return {
		"terrain": terrain,
		"plots": plots,
		"pendopo_plots": pendopo_plots,
		"spawn_zones": spawn_zones,
		"resource_nodes": resource_nodes,
		"paths": paths,
		"map_size": map_size,
	}


static func _generate_terrain(map_size: int) -> Array:
	var terrain: Array = []
	for y in range(map_size):
		var row: Array = []
		for x in range(map_size):
			row.append(TILE_GRASS)
		terrain.append(row)
	return terrain


# Picks where the pendopos stand, before any plots exist.
#
# A lone pendopo anchors the exact centre: the king, the edge roads and the camera
# all key off it. With two or more there is deliberately no centre pendopo — the
# bases sit evenly around the middle instead, so a multi-pendopo arena never ends
# up with one base stranded in the hub while the others sit out on the rim.
static func _place_pendopo_sites(center: Vector2i, count: int, map_size: int) -> Array[Vector2i]:
	var sites: Array[Vector2i] = []
	if count <= 0:
		return sites
	if count == 1:
		sites.append(center)
		return sites

	var spread: float = _pendopo_spread(map_size, count)
	var phase: float = randf() * TAU
	for i in range(count):
		var angle: float = phase + TAU * float(i) / float(count)
		sites.append(center + Vector2i(roundi(cos(angle) * spread), roundi(sin(angle) * spread)))
	return sites


# Ring radius for the bases, and the plot scatter that goes with it, arranged together
# so neither starves the other.
#
#   spread + scatter + half-width <= half-map    the outermost plot stays on the map
#   spread * chord       >=  scatter * 2          neighbouring clusters don't overlap
#
# The second bound is the one that binds, so the scatter is solved from it: substituting
# the first into the second and solving for `scatter` gives the widest scatter the map
# can afford, and `spread` then takes whatever is left. Neither number is chosen by
# hand, and a bigger arena widens both.
#
# `chord` is the distance between neighbouring bases on the ring, and it depends on how
# many there are: two bases are diametrically opposite (2 * spread), three sit 120
# degrees apart (spread * sqrt(3)). Using the three-pendopo chord for every count is
# wrong for two -- it demands more separation than two bases on a 42x42 arena can
# give, and the solve silently lands the clusters on top of each other.
#
# Each base also sits on a whole tile, so the ideal separation is never reached exactly:
# rounding both sites can pull them up to sqrt(2) closer. That term is subtracted
# before solving, otherwise the round trip lands the clusters inside each other on the
# unlucky phases.
static func _pendopo_spread(map_size: int, count: int) -> float:
	var half: float = float(map_size) / 2.0 - PENDOPO_HALF_WIDTH
	return maxf(half - _scatter_max(map_size, count), 0.0)


# Distance between neighbouring bases on the ring of `count` around the centre.
static func _base_chord(count: int) -> float:
	if count <= 2:
		return 2.0
	return sqrt(3.0)


# Widest plot scatter this arena supports, from the cluster-vs-cluster bound above.
# Solved for scatter rather than picked, so it tracks the arena size on its own.
static func _scatter_max(map_size: int, count: int) -> float:
	var half: float = float(map_size) / 2.0 - PENDOPO_HALF_WIDTH
	# A lone base has no neighbouring cluster to stay clear of, so the bound below
	# does not apply to it. Solving it anyway capped a 32x32 single-pendopo arena at
	# 6.9 tiles instead of the 14.5 it actually has, which packed all seven plots
	# into a 14x14 blob in the middle of the map -- the crowding the player sees on
	# low stages. With nothing to separate from, the whole half-map is available.
	if count <= 1:
		return half
	# chord * (half - scatter) >= 2 * scatter - slack
	#   => scatter * (chord + 2) <= chord * half - slack
	#
	# The slack is subtracted, not added: it is margin held back from the solve so the
	# rounded positions still clear each other. Adding it would widen the scatter and
	# make the overlap worse.
	var chord: float = _base_chord(count)
	var allowed: float = (chord * half - PENDOPO_ROUNDING_SLACK) / (chord + 2.0)
	return clampf(allowed, PENDOPO_HALF_WIDTH * 2.0, half)


static func _scatter_min(map_size: int, count: int) -> float:
	return maxf(_scatter_max(map_size, count) * PENDOPO_SCATTER_MIN_RATIO, PENDOPO_HALF_WIDTH * 2.0)


# Every pendopo claims one plot for itself plus a loose scatter of buildable plots,
# so the total is fixed by the pendopo count and never by the stage number.
static func _place_clustered_plots(terrain: Array, sites: Array[Vector2i], map_size: int, count: int) -> Array[Vector2i]:
	var plots: Array[Vector2i] = []
	for site in sites:
		plots.append(site)
		plots.append_array(_scatter_plots(site, plots, map_size, count))

	for pos in plots:
		terrain[pos.y][pos.x] = TILE_PATH

	return plots


# Random angle and random radius, rejecting any position that would crowd a plot
# already taken. Rejection is what keeps the layout organic: an even ring would need
# a fixed radius, and any fixed radius reads as a circle.
static func _scatter_plots(site: Vector2i, taken: Array[Vector2i], map_size: int, count: int) -> Array[Vector2i]:
	# Whole-cluster retry, not per-plot retry. A 32x32 arena leaves only ~5.9 tiles of
	# scatter, and six 3x3 plots at 4-tile spacing barely fit that disc -- the layout
	# is tight enough that grinding more single-plot attempts still fails a quarter of
	# the time (measured: 25% at 400 attempts). Restarting the whole cluster instead
	# samples an independent layout each time, which converges because the packing
	# does exist, and costs nothing when it lands first try.
	var wanted: int = ProgressionData.BUILDABLE_PER_PENDOPO
	var best: Array[Vector2i] = []
	# A tight arena needs the looser spacing pass to converge at all, so both passes
	# share one loop and the first one that completes wins. Never hand back a short
	# cluster: a base with 4 of its 6 plots would leave dead ground the player cannot
	# build on, and the plot count is a balance number the rest of the game reads.
	for relax in [1.0, 0.75]:
		for restart in PENDOPO_SCATTER_RESTARTS:
			var out: Array[Vector2i] = []
			var complete: bool = true
			for i in wanted:
				var pos := _try_scatter_one(site, taken, out, map_size, count, relax)
				if pos == Vector2i(-1, -1):
					complete = false
					break
				out.append(pos)
			if out.size() > best.size():
				best = out
			if complete:
				return out
		if best.size() == wanted:
			return best
	return best


# One candidate plot for `site`, or an invalid position if none of the attempts fit.
static func _try_scatter_one(
	site: Vector2i, taken: Array[Vector2i], out: Array[Vector2i], map_size: int, count: int, relax: float = 1.0
) -> Vector2i:
	var far: float = _scatter_max(map_size, count)
	# Sample the whole solved band rather than a sub-band: on a tight arena the outer
	# edge is the only place a sixth plot fits, and excluding it starves the cluster.
	var near: float = _scatter_min(map_size, count) * relax
	for attempt in PENDOPO_SCATTER_ATTEMPTS:
		var angle: float = randf() * TAU
		# sqrt biases samples outward, so the band gets roughly even area coverage
		# instead of piling up near the base.
		var radius: float = near + (far - near) * sqrt(randf())
		var pos: Vector2i = site + Vector2i(
			roundi(cos(angle) * radius),
			roundi(sin(angle) * radius)
		)
		if _clear_of(pos, taken) and _clear_of(pos, out, relax):
			return pos
	return Vector2i(-1, -1)


static func _clear_of(pos: Vector2i, others: Array[Vector2i], relax: float = 1.0) -> bool:
	for other in others:
		if other.distance_squared_to(pos) < MIN_PLOT_SPACING_SQ * relax:
			return false
	return true


static func _place_obstacles(terrain: Array, plots: Array[Vector2i], map_size: int, stage: int) -> void:
	var obstacle_density := 0.04 + stage * 0.003
	var num_obstacles := floori(map_size * map_size * obstacle_density)
	var blocked := _plot_block_set(plots, OBSTACLE_CLEARANCE_SQ)

	for i in range(num_obstacles):
		var x := randi_range(1, map_size - 2)
		var y := randi_range(1, map_size - 2)
		if not blocked.has(Vector2i(x, y)) and terrain[y][x] == TILE_GRASS:
			terrain[y][x] = TILE_OBSTACLE


static func _place_resource_nodes(terrain: Array, plots: Array[Vector2i], map_size: int) -> void:
	var num_resources := floori(map_size * 0.5) + 2
	var blocked := _plot_block_set(plots, RESOURCE_CLEARANCE_SQ)

	for i in range(num_resources):
		var x := randi_range(2, map_size - 3)
		var y := randi_range(2, map_size - 3)
		if not blocked.has(Vector2i(x, y)) and terrain[y][x] == TILE_GRASS:
			terrain[y][x] = TILE_RESOURCE


# Pre-computing the exclusion zone turns a per-candidate O(plots) scan into an
# O(1) lookup; at stage 250 that is ~170k candidates against 178 plots.
static func _plot_block_set(plots: Array[Vector2i], clearance_sq: float) -> Dictionary:
	var blocked: Dictionary = {}
	var r: int = int(ceil(sqrt(clearance_sq)))
	for p in plots:
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if float(dx * dx + dy * dy) < clearance_sq:
					blocked[p + Vector2i(dx, dy)] = true
	return blocked


static func _generate_paths(terrain: Array, plots: Array[Vector2i], pendopo_plots: Array[Vector2i], map_size: int) -> void:
	if pendopo_plots.is_empty():
		return

	# A short spur from each base to each of its own scattered plots, so buildings
	# are always reachable without walking across the arena.
	var reach: float = float(map_size)
	for site in pendopo_plots:
		for plot in plots:
			if plot != site and (plot as Vector2i).distance_to(site) <= reach:
				_draw_curving_route(terrain, site, plot)

	var hub := Vector2i(map_size / 2, map_size / 2)

	# Trunk road: the bases link to each other, then to the middle, and the middle
	# links out to the map edges the enemies spawn from.
	for i in range(1, pendopo_plots.size()):
		_draw_curving_route(terrain, pendopo_plots[i - 1], pendopo_plots[i])
	for site in pendopo_plots:
		_draw_curving_route(terrain, hub, site)

	_draw_edge_paths(terrain, hub, map_size)


static func _draw_edge_paths(terrain: Array, center: Vector2i, map_size: int) -> void:
	var candidates: Array[Vector2i] = []
	for i in range(2, map_size - 2, 3):
		candidates.append(Vector2i(i, 0))
		candidates.append(Vector2i(i, map_size - 1))
		candidates.append(Vector2i(0, i))
		candidates.append(Vector2i(map_size - 1, i))
	candidates.shuffle()
	# Deliberately a flat cap, not a function of map_size. Each road spans half the
	# arena and every path tile becomes its own NavigationBuilder collider node, so
	# scaling this with the map turned 20 roads on a 32x32 arena into 41 roads of
	# 196 tiles each on a 392x392 one -- ~23k collider nodes, and a threaded navmesh
	# bake over all of them that the engine has to join before the window closes.
	for i in range(mini(MAX_EDGE_PATHS, candidates.size())):
		_draw_curving_route(terrain, center, candidates[i])


static func _fill_path_holes(terrain: Array, map_size: int) -> void:
	var changed := true
	while changed:
		changed = false
		var to_fill: Array[Vector2i] = []
		for y in range(1, map_size - 1):
			for x in range(1, map_size - 1):
				if terrain[y][x] != TILE_GRASS:
					continue
				var cardinals := 0
				if terrain[y - 1][x] == TILE_PATH:
					cardinals += 1
				if terrain[y + 1][x] == TILE_PATH:
					cardinals += 1
				if terrain[y][x - 1] == TILE_PATH:
					cardinals += 1
				if terrain[y][x + 1] == TILE_PATH:
					cardinals += 1
				if cardinals >= 3:
					to_fill.append(Vector2i(x, y))
		for pos in to_fill:
			terrain[pos.y][pos.x] = TILE_PATH
			changed = true


static func _absorb_adjacent_to_path(terrain: Array, map_size: int) -> void:
	var to_convert: Array[Vector2i] = []
	for y in range(map_size):
		for x in range(map_size):
			var t: int = terrain[y][x]
			if t == TILE_OBSTACLE or t == TILE_RESOURCE or t == TILE_SPAWN:
				if y > 0 and terrain[y - 1][x] == TILE_PATH:
					to_convert.append(Vector2i(x, y))
				elif y < map_size - 1 and terrain[y + 1][x] == TILE_PATH:
					to_convert.append(Vector2i(x, y))
				elif x > 0 and terrain[y][x - 1] == TILE_PATH:
					to_convert.append(Vector2i(x, y))
				elif x < map_size - 1 and terrain[y][x + 1] == TILE_PATH:
					to_convert.append(Vector2i(x, y))
	for pos in to_convert:
		terrain[pos.y][pos.x] = TILE_PATH


static func _draw_curving_route(terrain: Array, from: Vector2i, to: Vector2i) -> void:
	var dist := from.distance_to(to)
	if dist < 6.0:
		_draw_line(terrain, from, to)
		return

	var num_knots := clampi(floori(dist / 6.0), 1, 3)
	var seg_len := 1.0 / (num_knots + 1.0)
	var max_jitter := maxi(2, floori(dist * 0.15))
	var half_jitter := maxi(1, max_jitter / 2)
	var dx := to.x - from.x
	var dy := to.y - from.y

	var points: Array[Vector2i] = [from]
	var prev := from
	for j in range(1, num_knots + 1):
		var t := j * seg_len
		var along_x := roundi(from.x + dx * t)
		var along_y := roundi(from.y + dy * t)
		var perp_x := -dy
		var perp_y := dx
		var perp_len := maxi(1, roundi(sqrt(float(perp_x * perp_x + perp_y * perp_y))))
		var offset := randi_range(-half_jitter, max_jitter)
		var max_x: int = terrain[0].size() - 1
		var max_y: int = terrain.size() - 1
		var knot := Vector2i(
			clampi(along_x + perp_x * offset / perp_len, 1, max_x - 1),
			clampi(along_y + perp_y * offset / perp_len, 1, max_y - 1)
		)
		points.append(knot)
		prev = knot

	points.append(to)

	for i in range(points.size() - 1):
		_draw_line(terrain, points[i], points[i + 1])


static func _draw_line(terrain: Array, from: Vector2i, to: Vector2i) -> void:
	var x0 := from.x
	var y0 := from.y
	var x1 := to.x
	var y1 := to.y
	var dx := absi(x1 - x0)
	var dy := -absi(y1 - y0)
	var sx := 1 if x0 < x1 else -1
	var sy := 1 if y0 < y1 else -1
	var err := dx + dy

	while true:
		_paint_path_tile(terrain, x0, y0)
		if x0 == x1 and y0 == y1:
			break
		var e2 := 2 * err
		if e2 >= dy:
			err += dy
			x0 += sx
		if e2 <= dx:
			err += dx
			y0 += sy


static func _paint_path_tile(terrain: Array, x: int, y: int) -> void:
	if x < 0 or x >= terrain[0].size() or y < 0 or y >= terrain.size():
		return
	if terrain[y][x] == TILE_GRASS:
		terrain[y][x] = TILE_PATH
	var neighbor_offsets: Array[Vector2i] = [
		Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	]
	for offset in neighbor_offsets:
		var nx := x + offset.x
		var ny := y + offset.y
		if nx >= 0 and nx < terrain[0].size() and ny >= 0 and ny < terrain.size():
			if terrain[ny][nx] == TILE_GRASS:
				terrain[ny][nx] = TILE_PATH


static func _generate_spawn_zones(map_size: int) -> Array[Vector2i]:
	var zones: Array[Vector2i] = []
	var margin := 2
	for x in range(margin, map_size - margin, 3):
		zones.append(Vector2i(x, margin))
		zones.append(Vector2i(x, map_size - 1 - margin))
	for y in range(margin, map_size - margin, 3):
		zones.append(Vector2i(margin, y))
		zones.append(Vector2i(map_size - 1 - margin, y))
	return zones


static func _collect_path_positions(terrain: Array) -> Array[Vector2i]:
	var nodes: Array[Vector2i] = []
	for y in range(terrain.size()):
		var row: Array = terrain[y] as Array
		for x in range(row.size()):
			if row[x] == TILE_PATH:
				nodes.append(Vector2i(x, y))
	return nodes


static func _collect_resource_positions(terrain: Array) -> Array[Vector2i]:
	var nodes: Array[Vector2i] = []
	for y in range(terrain.size()):
		for x in range(terrain[y].size()):
			if terrain[y][x] == TILE_RESOURCE:
				nodes.append(Vector2i(x, y))
	return nodes


static func create_tile_map(tile_size: int = TILE_SIZE) -> TileMapLayer:
	var tilemap := TileMapLayer.new()
	var tileset := TileSet.new()
	var source := TileSetAtlasSource.new()

	var img := Image.create(tile_size * 5, tile_size, false, Image.FORMAT_RGBA8)

	var grass_color := Color(0.29, 0.49, 0.25)
	var path_color := Color(0.55, 0.45, 0.33)
	var obstacle_color := Color(0.29, 0.29, 0.29)
	var resource_color := Color(0.72, 0.53, 0.04)
	var spawn_color := Color(0.55, 0.0, 0.0)

	_fill_tile(img, 0, grass_color)
	_fill_tile(img, 1, path_color)
	_fill_tile(img, 2, obstacle_color)
	_fill_tile(img, 3, resource_color)
	_fill_tile(img, 4, spawn_color)

	var texture := ImageTexture.create_from_image(img)
	source.texture = texture
	source.texture_region_size = Vector2i(tile_size, tile_size)
	tileset.add_source(source, 0)

	tilemap.tile_set = tileset
	return tilemap


static func _fill_tile(image: Image, tile_index: int, color: Color) -> void:
	for y in range(TILE_SIZE):
		for x in range(TILE_SIZE):
			var px := tile_index * TILE_SIZE + x
			image.set_pixel(px, y, color)


static func apply_terrain(tilemap: TileMapLayer, terrain: Array) -> void:
	for y in range(terrain.size()):
		var row = terrain[y] as Array
		for x in range(row.size()):
			var tile: int = row[x] as int
			tilemap.set_cell(Vector2i(x, y), 0, Vector2i(tile, 0))


static func is_walkable(terrain: Array, tile: Vector2i) -> bool:
	if tile.y < 0 or tile.y >= terrain.size():
		return false
	var row: Array = terrain[tile.y] as Array
	if tile.x < 0 or tile.x >= row.size():
		return false
	return row[tile.x] == TILE_PATH


static func get_tile_world_position(tile: Vector2i, tile_size: int = TILE_SIZE) -> Vector2:
	return Vector2(tile.x * tile_size, tile.y * tile_size)


static func world_to_tile(world_pos: Vector2, tile_size: int = TILE_SIZE) -> Vector2i:
	return Vector2i(floori(world_pos.x / tile_size), floori(world_pos.y / tile_size))
