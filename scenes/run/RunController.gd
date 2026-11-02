extends Node3D

const TILE_SIZE := 32
const CAMERA_OFFSET := Vector3(0, 20, 20)

# Camera follow rate. Left at the original tuned value.
const CAMERA_FOLLOW_RATE: float = 8.0

const PausePopupScript: GDScript = preload("res://scenes/run/PausePopup.gd")

var stage_number: int = 0
var stage_theme: String = ""
var current_wave: int = 0
var total_waves: int = 3
var map_data: Dictionary = {}
var garrison: PlayerGarrison = null
var tilemap: TileMapLayer = null
var plot_nodes: Array[Node3D] = []
var pendopo_nodes: Array[Node3D] = []
var spawn_zones: Array[Vector2i] = []

var _objective: ObjectiveState = ObjectiveState.new()

var _production_timer: Timer = null
var _king_controller: Node3D = null
var _terrain: Array = []
var _map_size: int = 0

var _wave_timer: Timer = null
var _wave_countdown: float = 999.0
var _wave_active: bool = false
var _level_completed: bool = true
var _loss_applied: bool = false
var _playing: bool = false
var _paused: bool = false
var _pause_popup: Control = null
var _occlusion_frame: int = 0

var _soldier_units: Array = []
var _soldier_slots: int = 0

var camera: Camera3D
@onready var hud_ui: CanvasLayer = $RunHUD
@onready var invasion_manager: Node3D = $InvasionManager


func _ready() -> void:
	_setup_camera_node()
	stage_number = SceneManager.get_param("stage_number", SaveManager.stage_number)
	stage_theme = TileTheme.theme_for_stage(stage_number)
	hud_ui.stage_number = stage_number
	hud_ui.update_stage_label()
	invasion_manager.stage_number = stage_number
	invasion_manager.stage_theme = stage_theme
	var gk_save: Dictionary = SaveManager.heroes.get("gatotkaca", {}) as Dictionary
	invasion_manager.king_level = gk_save.get("level", 1)
	_start_level.call_deferred()


func _setup_camera_node() -> void:
	camera = Camera3D.new()
	camera.name = "Camera3D"
	camera.fov = 35
	camera.position = CAMERA_OFFSET
	camera.rotation_degrees = Vector3(-45, -45, 0)
	add_child(camera)
	camera.make_current()


func _process(delta: float) -> void:
	if _king_controller and is_instance_valid(_king_controller):
		_update_camera(delta)
	_occlusion_frame += 1
	var entity_count := SpatialIndex.get_entity_count()
	var occlusion_interval := 6 if entity_count < 30 else 12 if entity_count < 60 else 24
	if _occlusion_frame % occlusion_interval == 0:
		_update_building_occlusion()
	if _occlusion_frame % 3 == 0:
		_update_minimap()


func _physics_process(delta: float) -> void:
	SpatialIndex.update()
	if _king_controller and is_instance_valid(_king_controller):
		var map_size: int = map_data["map_size"] as int
		var half := map_size * 0.5
		_king_controller.position.x = clampf(_king_controller.position.x, -half + 0.25, half - 0.25)
		_king_controller.position.z = clampf(_king_controller.position.z, -half + 0.25, half - 0.25)
		if _king_controller.has_method("get_earthquake_cooldown_fraction"):
			hud_ui.update_skill_cooldown(_king_controller.get_earthquake_cooldown_fraction())

	if not _level_completed and not _wave_active and current_wave < total_waves:
		_wave_countdown -= delta
		if _wave_countdown <= 0:
			_start_next_wave()
	hud_ui.update_countdown(_wave_countdown if not _wave_active else -1.0)


func _update_camera(delta: float) -> void:
	if not _king_controller:
		return
	var target_pos: Vector3 = _king_controller.position + CAMERA_OFFSET
	camera.position = camera.position.lerp(target_pos, CAMERA_FOLLOW_RATE * delta)
	camera.look_at(_king_controller.position)


func _update_building_occlusion() -> void:
	var cam_pos: Vector3 = camera.global_position
	var cam_fwd: Vector3 = -camera.global_transform.basis.z

	var characters: Array[Node3D] = []
	if _king_controller and is_instance_valid(_king_controller):
		characters.append(_king_controller)
	for enemy in SpatialIndex.get_nearby(cam_pos, 50.0, "enemies"):
		if enemy is Node3D:
			characters.append(enemy)
	for troop in SpatialIndex.get_nearby(cam_pos, 50.0, "troops"):
		if troop is Node3D:
			characters.append(troop)

	for plot in plot_nodes:
		var bld = plot.get("current_building")
		if bld == null or not is_instance_valid(bld) or not bld.has_method("set_transparent"):
			continue
		# A destroyed fort is being taken off the map, so it should not be faded for the
		# camera either.
		if not _is_pendopo_alive(bld):
			bld.set_transparent(false)
			continue
		var bld_pos: Vector3 = bld.global_position + Vector3(0, 1.5, 0)
		var to_bld: Vector3 = bld_pos - cam_pos
		var bld_dist: float = to_bld.length()
		if bld_dist < 0.1:
			bld.set_transparent(false)
			continue
		var dot: float = to_bld.dot(cam_fwd)
		if dot < 0.0:
			bld.set_transparent(false)
			continue
		var proj: Vector3 = cam_fwd * dot
		var lateral: Vector3 = to_bld - proj
		var bld_lateral_dist: float = lateral.length()

		var blocked: bool = false
		for char in characters:
			if not is_instance_valid(char) or not char.is_inside_tree():
				continue
			var char_pos: Vector3 = char.global_position
			var to_char: Vector3 = char_pos - cam_pos
			var char_dist: float = to_char.length()
			if char_dist < 0.1:
				continue
			var depth_behind: float = char_dist - bld_dist
			if depth_behind < -2.0 or depth_behind > 6.0:
				continue
			var char_dot: float = to_char.dot(cam_fwd)
			if char_dot < 0.0:
				continue
			var char_proj: Vector3 = cam_fwd * char_dot
			var char_lateral: Vector3 = to_char - char_proj
			if char_lateral.distance_to(lateral) < 2.5:
				blocked = true
				break
		bld.set_transparent(blocked)


func _connect_hud_signals() -> void:
	hud_ui.set_dpad_receiver(_king_controller, "set_movement_dir")
	hud_ui.set_attack_receiver(_king_controller, "request_attack")
	hud_ui.set_skill_receiver(_king_controller, "request_earthquake")
	hud_ui.set_dash_receiver(_king_controller, "request_dash")
	hud_ui.set_berserk_receiver(_king_controller, "request_berserk")
	hud_ui.setup_potions_panel(_king_controller)
	hud_ui.pause_requested.connect(_on_pause_pressed)
	hud_ui.guard_pendopo_pressed.connect(_guard_soldiers_at_nearest_pendopo)
	hud_ui.gather_soldiers_pressed.connect(_gather_soldiers)


func _start_level() -> void:
	var loading: CanvasLayer = load("res://scenes/run/LoadingScreen.tscn").instantiate()
	add_child(loading)
	loading.set_title(TranslationManager.t("hud_stage") % stage_number)
	
	await get_tree().process_frame

	loading.set_status("Generating map...", 0.05)
	await get_tree().process_frame
	total_waves = ProgressionData.num_waves(stage_number)
	current_wave = 0
	map_data = MapGenerator.generate(stage_number)

	loading.set_status("Building terrain...", 0.12)
	await get_tree().process_frame
	_build_map(map_data)
	hud_ui.setup_minimap(_terrain, _map_size)

	loading.set_status("Loading soldier models...", 0.30)
	await ModelLoader.prewarm_soldier_models()

	loading.set_status("Loading enemy models...", 0.42)
	await ModelLoader.prewarm_enemy_models()
	await ModelLoader.prewarm_boss_models(stage_number)

	loading.set_status("Loading building models...", 0.54)
	await ModelLoader.prewarm_building_models()

	loading.set_status("Loading king model...", 0.62)
	await ModelLoader.prewarm_king_models()

	loading.set_status("Preparing archer models...", 0.67)
	await ModelLoader.prewarm_archer_models()

	loading.set_status("Creating plots...", 0.70)
	await get_tree().process_frame
	_create_plots(map_data["plots"], map_data["pendopo_plots"])

	loading.set_status("Configuring king...", 0.76)
	await get_tree().process_frame
	_setup_camera()

	loading.set_status("Warming up graphics...", 0.81)
	await ModelLoader.warmup_shaders(self)
	loading.set_status("Warming up animations...", 0.84)
	await ModelLoader.warmup_animations(self, stage_number)
	# Effect materials and popup fonts are otherwise compiled/rasterised on first use during
	# gameplay (first attack, first dash, first build popup) -- the "lag only the first time".
	await GameplayWarmup.warm_effects(camera)
	await GameplayWarmup.warm_popup_fonts(self)
	if not plot_nodes.is_empty():
		loading.set_status("Preparing build menu...", 0.86)
		await GameplayWarmup.warm_build_popup(plot_nodes[0])

	loading.set_status("Preparing troops...", 0.88)
	await get_tree().process_frame
	await UnitPool.prewarm_soldiers(8)
	UnitPool.prewarm_enemies(16)

	loading.set_status("Preparing audio...", 0.95)
	MusicManager.preload_all()
	await get_tree().process_frame

	garrison = PlayerGarrison.new()
	EconomyManager.begin_run()
	_start_production()
	_update_hud()

	loading.set_status("Ready!", 1.0)
	await get_tree().process_frame

	_wave_countdown = ProgressionData.wave_prep_time(stage_number)
	_wave_active = false
	_level_completed = false
	_loss_applied = false

	_connect_hud_signals()

	loading.complete()
	MusicManager.play_fade(MusicManager.Track.BUILD, 1.0)

	_playing = true
	hud_ui.set_pause_enabled(true)


func _start_production() -> void:
	if _production_timer:
		_production_timer.queue_free()
	_production_timer = Timer.new()
	_production_timer.wait_time = 2.0
	_production_timer.timeout.connect(_on_production_tick)
	_production_timer.one_shot = false
	_production_timer.autostart = true
	add_child(_production_timer)


func _on_production_tick() -> void:
	for plot in plot_nodes:
		var bld = plot.get("current_building")
		if bld == null:
			continue
		if bld.has_method("get_gold_production"):
			var gold: int = bld.get_gold_production()
			if gold > 0:
				EconomyManager.add_pending(gold)


func _build_map(data: Dictionary) -> void:
	_terrain = data["terrain"]
	_map_size = data["map_size"] as int
	spawn_zones = data["spawn_zones"] as Array[Vector2i]

	var center_offset: float = _map_size * 0.5
	TerrainBuilder.build_terrain(_terrain, self, center_offset, stage_theme)
	NavigationBuilder.build_navigation(_terrain, self, center_offset)

	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0, 0, 0)
	env.environment.ambient_light_color = Color(0.6, 0.6, 0.7)
	env.environment.ambient_light_energy = 0.8
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	add_child(env)

	var light := DirectionalLight3D.new()
	light.position = Vector3(10, 20, 10)
	light.light_energy = 1.2
	light.shadow_enabled = true
	add_child(light)
	light.look_at(Vector3.ZERO)


func _create_plots(plots: Array, pendopo_tiles: Array) -> void:
	# Pendopo plots are spread across the arena; the rest are player-buildable.
	var center_offset: float = _map_size * 0.5

	for i in range(plots.size()):
		var pos: Vector2i = plots[i] as Vector2i
		var plot: Node3D = load("res://scenes/run/BuildingPlot.tscn").instantiate()
		plot.plot_position = pos
		plot.stage_number = stage_number
		plot.stage_theme = stage_theme
		plot.position = Vector3((pos.x - center_offset) * 1.0, 0, (pos.y - center_offset) * 1.0)

		var is_pendopo_plot: bool = pendopo_tiles.has(pos)
		if is_pendopo_plot:
			var coll := plot.get_node("CollisionShape3D")
			if coll:
				coll.disabled = true

		add_child(plot)
		plot_nodes.append(plot)
		plot.building_placed.connect(_on_building_placed)

		if is_pendopo_plot:
			_place_pendopo(plot, pos)


func _on_building_placed(building: Node3D) -> void:
	if building is Barak:
		building.setup(garrison)
		building.troop_trained.connect(_on_troop_trained.bind(building))


func _on_troop_trained(troop_type: String, barak: Node3D) -> void:
	if _king_controller == null or not is_instance_valid(_king_controller):
		return
	var soldier: SoldierUnit = UnitPool.acquire_soldier()
	soldier.troop_type = troop_type
	soldier.barracks_level = SaveManager.get_building_upgrade_level("barak")
	soldier.formation_slot = _soldier_slots
	_soldier_slots += 1
	soldier.position = _find_troop_spawn_point(barak)
	soldier.setup_king_ref(_king_controller)
	add_child(soldier)
	soldier.configure()
	ModelLoader.set_ground_shadow(soldier, stage_theme == "sky", Vector2(0.65, 0.42))
	if soldier.death_callback.is_valid() and soldier.died.is_connected(soldier.death_callback):
		soldier.died.disconnect(soldier.death_callback)
	soldier.death_callback = Callable(self, "_on_soldier_died").bind(troop_type)
	soldier.died.connect(soldier.death_callback)
	_soldier_units.append(soldier)
	_refresh_soldier_command_visibility()


func _on_soldier_died(soldier: Node3D, troop_type: String) -> void:
	if _soldier_units.has(soldier):
		_soldier_units.erase(soldier)
		if garrison != null:
			garrison.remove_troops(troop_type, 1)
		_refresh_soldier_command_visibility()


func _refresh_soldier_command_visibility() -> void:
	if hud_ui != null and is_instance_valid(hud_ui):
		hud_ui.set_soldier_commands_visible(not _soldier_units.is_empty())


func _guard_soldiers_at_nearest_pendopo() -> void:
	var living_pendopos: Array[Node3D] = []
	for pendopo in pendopo_nodes:
		if _is_pendopo_alive(pendopo):
			living_pendopos.append(pendopo)
	for soldier in _soldier_units:
		if soldier == null or not is_instance_valid(soldier):
			continue
		if living_pendopos.is_empty():
			soldier.set_follow_target(_king_controller)
			continue
		var nearest: Node3D = living_pendopos[0]
		var nearest_distance: float = soldier.global_position.distance_squared_to(
			nearest.global_position
		)
		for i in range(1, living_pendopos.size()):
			var pendopo: Node3D = living_pendopos[i]
			var distance: float = soldier.global_position.distance_squared_to(
				pendopo.global_position
			)
			if distance < nearest_distance:
				nearest = pendopo
				nearest_distance = distance
		soldier.set_follow_target(nearest)


func _gather_soldiers() -> void:
	for soldier in _soldier_units:
		if soldier != null and is_instance_valid(soldier):
			soldier.set_follow_target()


func _find_troop_spawn_point(barak: Node3D) -> Vector3:
	var center_offset: float = _map_size * 0.5
	var barak_tile := _barak_tile(barak, center_offset)
	for radius in range(1, 5):
		var candidates: Array[Vector2i] = []
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if maxi(absi(dx), absi(dy)) != radius:
					continue
				var tile := barak_tile + Vector2i(dx, dy)
				if _is_valid_spawn_tile(tile):
					candidates.append(tile)
		if not candidates.is_empty():
			candidates.shuffle()
			var chosen: Vector2i = candidates[0]
			return Vector3(chosen.x - center_offset, 0.2, chosen.y - center_offset)
	var fallback := _nearest_valid_spawn_tile(barak_tile, barak)
	if fallback.x >= 0:
		return Vector3(fallback.x - center_offset, 0.2, fallback.y - center_offset)
	push_warning("RunController: No unoccupied walkable tile found for barracks troop spawn")
	return barak.position


func _nearest_valid_spawn_tile(origin: Vector2i, barak: Node3D) -> Vector2i:
	var nearest := Vector2i(-1, -1)
	var nearest_distance_sq := INF
	for y in range(_terrain.size()):
		for x in range((_terrain[y] as Array).size()):
			var tile := Vector2i(x, y)
			if not _is_valid_spawn_tile(tile):
				continue
			var distance_sq := origin.distance_squared_to(tile)
			if distance_sq < nearest_distance_sq:
				nearest = tile
				nearest_distance_sq = distance_sq
	return nearest


func _barak_tile(barak: Node3D, center_offset: float) -> Vector2i:
	var plot = barak.get("plot")
	if plot != null and "plot_position" in plot:
		return plot.plot_position
	return Vector2i(roundi(barak.position.x + center_offset), roundi(barak.position.z + center_offset))


func _is_valid_spawn_tile(tile: Vector2i) -> bool:
	if not MapGenerator.is_walkable(_terrain, tile):
		return false
	for plot in plot_nodes:
		if not plot.occupied:
			continue
		var offset: Vector2i = tile - plot.plot_position
		if absi(offset.x) <= 1 and absi(offset.y) <= 1:
			return false
	return true


func _place_pendopo(plot: Node3D, pos: Vector2i) -> void:
	var data: Dictionary = BuildingData.get_building_data("pendopo")
	var building: Node3D = load("res://scenes/buildings/Pendopo.gd").new(data, plot)
	building.level = SaveManager.get_building_upgrade_level("pendopo")
	building.setup(ProgressionData.pendopo_hp(building.level))
	building.position = plot.position + Vector3(0, 0.2, 0)
	add_child(building)

	var plot_script: Node3D = plot as Node3D
	plot_script.place_building(building)

	building.pendopo_destroyed.connect(_on_pendopo_destroyed)
	pendopo_nodes.append(building)

	if pendopo_nodes.size() == 1:
		# Gatotkaca starts at the first (centre) pendopo.
		_place_king(building.position)

	_wire_heal_ring(building)
	_sync_objective_state()


func _sync_objective_state() -> void:
	_objective.configure(pendopo_nodes.size())
	_king_controller.pendopo_positions = get_pendopo_positions()
	_king_controller.pendopo_heal_rates = get_pendopo_heal_rates()
	invasion_manager.set_pendopo_refs(pendopo_nodes)
	_sync_heal_ring_bindings()


# Idempotent, so it runs on every sync rather than only at placement: a fort that has just
# fallen is unbound here, and one added later is bound, without either path needing to know
# about the other.
func _sync_heal_ring_bindings() -> void:
	for p in pendopo_nodes:
		if p == null or not is_instance_valid(p):
			continue
		if _is_pendopo_alive(p):
			_wire_heal_ring(p)
		else:
			_unwire_heal_ring(p)


func _on_pendopo_destroyed() -> void:
	_objective.on_pendopo_destroyed()
	# Release the fallen fort's ring binding before anything else, so the king can never
	# re-trigger a node that is about to be freed.
	_unwire_heal_ring(_last_destroyed_pendopo())
	# Enemies must stop walking to a ruin.
	invasion_manager.set_pendopo_refs(pendopo_nodes)
	# Refresh the king's heal targets and the minimap markers: without this the corpse stays
	# in both lists, because get_pendopo_positions() filters on is_destroyed() and nothing
	# re-read it on destruction.
	_sync_objective_state()
	if _objective.is_lost():
		_level_failed()


# The destroyed fort is still in pendopo_nodes (it frees itself after the explosion is
# spawned), so it is found by state rather than passed through the signal.
func _last_destroyed_pendopo():
	for p in pendopo_nodes:
		if p == null or not is_instance_valid(p):
			continue
		if p.has_method("is_destroyed") and p.is_destroyed():
			return p
	return null


func _king_stats_for(level: int, stars: int, stage: int) -> Dictionary:
	var stats: Dictionary = ProgressionData.king_stats(level, stars)
	stats.merge(ProgressionData.gatotkaca_stats(stage), true)
	return EquipmentDatabase.apply_to_stats(stats, SaveManager.equipment)


func _place_king(center_pos: Vector3) -> void:
	_king_controller = load("res://scenes/run/KingController.tscn").instantiate()
	_king_controller.position = center_pos + Vector3(0, 0, 2.5)

	var gk_save: Dictionary = SaveManager.heroes.get("gatotkaca", {}) as Dictionary
	var gk_level: int = gk_save.get("level", 1)
	var gk_stars: int = gk_save.get("stars", 1)
	var king_stats: Dictionary = _king_stats_for(gk_level, gk_stars, stage_number)
	_king_controller.setup_king(king_stats)
	hud_ui.setup_king_progress(gk_level, gk_save.get("xp", 0), ProgressionData.xp_to_next(gk_level))
	_king_controller.set_play_field(map_data["map_size"] as int)
	_king_controller.king_died.connect(_on_king_died)
	_king_controller.stamina_changed.connect(hud_ui.update_stamina)
	_king_controller.mana_changed.connect(hud_ui.update_mana)
	_king_controller.hp_changed.connect(hud_ui.update_king_hp)
	_king_controller.berserk_changed.connect(hud_ui.set_berserk_active)
	add_child(_king_controller)
	ModelLoader.set_ground_shadow(_king_controller, stage_theme == "sky", Vector2(1.15, 0.8))
	hud_ui.update_mana(_king_controller.mana, _king_controller.mana_max)
	hud_ui.update_stamina(_king_controller.stamina, _king_controller.stamina_max)
	hud_ui.update_king_hp(_king_controller.king_hp, _king_controller.king_max_hp)


func _setup_camera() -> void:
	var map_size: int = map_data["map_size"] as int
	var half := map_size * 0.5

	if _king_controller:
		var target := _king_controller.position + CAMERA_OFFSET
		camera.position = target
		camera.look_at(_king_controller.position)
	else:
		camera.position = Vector3(0, 15, half)
		camera.look_at(Vector3.ZERO)


func _start_next_wave() -> void:
	if _wave_active:
		return
	current_wave += 1
	_wave_active = true
	MusicManager.play_fade(MusicManager.Track.BATTLE, 0.5)
	hud_ui.update_countdown(0)
	hud_ui.update_wave(current_wave, total_waves)
	invasion_manager.setup(garrison, _get_defense_buildings(), _terrain, _map_size)
	invasion_manager.set_king_ref(_king_controller)
	invasion_manager.set_pendopo_refs(pendopo_nodes)
	if not invasion_manager.wave_complete.is_connected(_on_wave_complete):
		invasion_manager.wave_complete.connect(_on_wave_complete)
	invasion_manager.start_wave_timer(current_wave)


func _get_defense_buildings() -> Array:
	var defenses: Array = []
	for plot in plot_nodes:
		var bld = plot.get("current_building")
		if bld != null and bld.has_method("is_defense_type") and bld.is_defense_type():
			defenses.append(bld)
	return defenses


func _on_wave_complete(victory: bool) -> void:
	if invasion_manager.wave_complete.is_connected(_on_wave_complete):
		invasion_manager.wave_complete.disconnect(_on_wave_complete)

	_wave_active = false
	if current_wave >= total_waves:
		_level_complete()
	else:
		_wave_countdown = ProgressionData.wave_prep_time(stage_number)
		MusicManager.play_fade(MusicManager.Track.BUILD, 1.0)


func _level_complete() -> void:
	_close_all_building_popups()
	_playing = false
	hud_ui.set_pause_enabled(false)
	GamePause.acquire("finished")
	_level_completed = true
	_stop_berserk()
	_king_controller.frozen = true
	invasion_manager.stop_wave_timer()
	MusicManager.play_fade(MusicManager.Track.VICTORY, 0.5)
	var earned_stars: int = _award_stage_stars()
	var gold_reward := ProgressionData.stage_reward_gold(stage_number)
	var mine: int = EconomyManager.get_pending()
	SaveManager.add_gold(mine + gold_reward)
	SaveManager.complete_stage(stage_number)
	if stage_number >= SaveManager.stage_number:
		SaveManager.increment_stage()
	var xp_result: Dictionary = SaveManager.add_king_xp(ProgressionData.win_xp(stage_number))
	var xp_gained: int = xp_result.get("xp_gained", 0)
	var new_level: int = xp_result.get("level", 1)
	var total_xp: int = xp_result.get("xp", 0)
	var xp_to_next: int = xp_result.get("xp_to_next", 1)
	var levels_gained: int = xp_result.get("levels_gained", 0)
	# Apply the new level's stats straight away, the same way HP does. Without this the
	# pools you just earned stayed at the old values for the rest of the session and only
	# grew on the next run, which read as "levelling up does nothing".
	if levels_gained > 0 and _king_controller != null:
		var gk: Dictionary = SaveManager.heroes.get("gatotkaca", {}) as Dictionary
		_king_controller.apply_level_up(
			_king_stats_for(new_level, gk.get("stars", 1), stage_number)
		)
		hud_ui.setup_king_progress(
			new_level, gk.get("xp", 0), ProgressionData.xp_to_next(new_level)
		)
	SaveManager.save_game()
	EconomyManager.end_run()
	_show_victory_notification(
		gold_reward, mine, xp_gained, levels_gained, new_level, total_xp, xp_to_next,
		earned_stars,
	)


## Rates the run as it ended and files the rating against the stage, keeping the best
## one the stage has ever earned. Returns what this run scored, which can sit below the
## stage's standing record -- that is what the victory panel reports.
##
## Called once the king is frozen, and nothing below touches his health, so the reading
## is the health the run actually finished on.
func _award_stage_stars() -> int:
	var earned: int = ProgressionData.stage_stars(
		_objective.alive_count(),
		_objective.total_count(),
		_king_controller.king_hp,
		_king_controller.king_max_hp,
	)
	SaveManager.record_stage_stars(stage_number, earned)
	return earned


func _level_failed() -> void:
	if _loss_applied:
		# A king that dies in the split second before the defeat notification lands
		# (or a second death signal firing) must not charge a second life or re-play
		# the defeat sequence: the run ends once.
		return
	_loss_applied = true
	_close_all_building_popups()
	_level_completed = true
	_stop_berserk()
	_king_controller.frozen = true
	invasion_manager.stop_wave_timer()
	MusicManager.play_fade(MusicManager.Track.DEFEAT, 0.5)
	_playing = false
	hud_ui.set_pause_enabled(false)
	GamePause.acquire("finished")
	_apply_run_loss()
	_show_defeat_notification()


func _stop_berserk() -> void:
	if _king_controller == null or not is_instance_valid(_king_controller):
		return
	if _king_controller.has_method("set_berserk"):
		_king_controller.set_berserk(false)


func set_paused(value: bool) -> void:
	if value == _paused:
		return
	_paused = value
	if _paused:
		_show_pause_popup()
	else:
		_hide_pause_popup()


func _show_pause_popup() -> void:
	if _pause_popup != null:
		return
	_pause_popup = PausePopupScript.new()
	_pause_popup.name = "PausePopup"
	_pause_popup.continue_requested.connect(_on_pause_continue)
	_pause_popup.exit_requested.connect(_on_pause_exit)
	hud_ui.add_child(_pause_popup)
	if hud_ui.has_method("set_pause_enabled"):
		hud_ui.set_pause_enabled(false)
	BuildingUIState.note_popup_opened()


func _hide_pause_popup() -> void:
	var had_popup: bool = _pause_popup != null
	if had_popup and is_instance_valid(_pause_popup):
		_pause_popup.queue_free()
	_pause_popup = null
	if had_popup:
		BuildingUIState.note_popup_closed()
	if hud_ui != null and hud_ui.has_method("set_pause_enabled"):
		hud_ui.set_pause_enabled(_playing)


func _on_pause_pressed() -> void:
	if not _playing or _paused:
		return
	if BuildingUIState.is_popup_open():
		return
	set_paused(true)


func _on_pause_continue() -> void:
	set_paused(false)


# Every way a run can end in loss funnels here so the cost can never diverge:
# one life, and the run's mined gold is dropped with no payout.
func _apply_run_loss() -> void:
	_playing = false
	set_paused(false)
	SaveManager.lose_life()
	EconomyManager.end_run()


func _on_pause_exit() -> void:
	if not _playing:
		return
	_apply_run_loss()
	SceneManager.go_to_scene("res://scenes/hub/LevelTrack.tscn")


func _on_close_requested() -> void:
	if not _playing:
		return
	_apply_run_loss()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_on_close_requested()
		get_tree().quit()
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_on_pause_pressed()


func _on_king_died() -> void:
	_objective.on_king_died()
	_level_failed()


func _close_all_building_popups() -> void:
	for plot in plot_nodes:
		if plot == null:
			continue
		if plot.has_method("_close_popup"):
			plot._close_popup()
		var bld = plot.get("current_building")
		if bld != null and bld.has_method("has_overlay_open") and bld.has_overlay_open():
			bld.hide_overlay()


func _get_pendopo_node() -> Node3D:
	for plot in plot_nodes:
		var bld = plot.get("current_building")
		if bld != null and bld.get("building_id") == "pendopo":
			return bld
	return null


# Only living pendopos. This list feeds Gatotkaca's heal targets and the minimap's gold
# dots, so a destroyed fort must drop out of it: otherwise the king heals himself on rubble
# and the objective marker keeps pointing at a corpse.
func get_pendopo_positions() -> Array[Vector3]:
	var positions: Array[Vector3] = []
	for p in pendopo_nodes:
		if _is_pendopo_alive(p):
			positions.append(p.position)
	return positions


func get_pendopo_heal_rates() -> Array[float]:
	var rates: Array[float] = []
	for p in pendopo_nodes:
		if _is_pendopo_alive(p):
			rates.append(ProgressionData.pendopo_heal(p.level))
	return rates


# Deliberately untyped: a destroyed pendopo frees itself, so pendopo_nodes can hold an
# already-freed reference by the time this is called, and a typed parameter rejects a freed
# object before the is_instance_valid() guard can run.
func _is_pendopo_alive(pendopo) -> bool:
	if pendopo == null or not is_instance_valid(pendopo):
		return false
	return not (pendopo.has_method("is_destroyed") and pendopo.is_destroyed())


func _heal_ring_is_wired(pendopo) -> bool:
	if pendopo == null or not is_instance_valid(pendopo):
		return false
	return _king_controller.healing_changed.is_connected(pendopo.begin_heal_effect)


# The ring follows the king between pendopos, so every pendopo needs the binding -- it used
# to be connected to whichever was placed first only, which showed the ring on the wrong
# fort from stage 50 on and left it glowing over a destroyed one.
func _wire_heal_ring(pendopo) -> void:
	if pendopo == null or not is_instance_valid(pendopo):
		return
	if _heal_ring_is_wired(pendopo):
		return
	_king_controller.healing_changed.connect(pendopo.begin_heal_effect)


func _unwire_heal_ring(pendopo) -> void:
	if pendopo == null or not is_instance_valid(pendopo):
		return
	if _heal_ring_is_wired(pendopo):
		_king_controller.healing_changed.disconnect(pendopo.begin_heal_effect)


func _get_pendopo_position() -> Vector3:
	var node := _get_pendopo_node()
	return node.position if node else Vector3.ZERO


func _update_minimap() -> void:
	if _map_size <= 0:
		return
	var king_pos: Vector3 = Vector3.ZERO
	if _king_controller and is_instance_valid(_king_controller):
		king_pos = _king_controller.global_position
	var building_nodes: Array = []
	for plot in plot_nodes:
		var bld = plot.get("current_building")
		if bld != null:
			building_nodes.append(bld)
	# Radius is the arena's own diagonal, not a flat 100. SpatialIndex walks a square of
	# cells around the query point, so a radius wider than the map made every minimap tick
	# scan the entire arena (2601 cells on a 96x96 map, ~52k lookups/sec) just to place
	# 2.5px dots. The diagonal already covers every unit the minimap can show.
	var reach: float = float(_map_size) * 0.75
	hud_ui.update_minimap(
		king_pos,
		SpatialIndex.get_nearby(king_pos, reach, "enemies"),
		_soldier_units,
		building_nodes,
		get_pendopo_positions()
	)


func _update_hud() -> void:
	hud_ui.update_wave(current_wave, total_waves)


func _show_victory_notification(
	reward: int, mine: int, xp_gained: int, levels_gained: int,
	new_level: int, total_xp: int, xp_to_next: int, earned_stars: int = 0,
) -> void:
	var overlay := _make_modal_overlay(hud_ui)
	overlay.name = "VictoryOverlay"

	var bg := ColorRect.new()
	bg.size = Vector2(600, 550)
	bg.position = Vector2(340, 85)
	bg.color = Color(0.08, 0.04, 0.02, 0.95)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(bg)

	var title := _create_result_centered_label(
		TranslationManager.t("result_stage_complete"), 125, 30, Color(0.9, 0.8, 0.3)
	)
	overlay.add_child(title)

	# The rating is a row of star icons in the info block, one per earned star. Sized
	# small enough that three of them clear the reward line below the row; the source
	# art is near-square, so the icons stay centered rather than stretched.
	var star_tex := load("res://assets/sprites/hud/star.png")
	var icon_size := 40
	var icon_gap := 12
	var row_w: int = earned_stars * icon_size + (earned_stars - 1) * icon_gap
	var star_x: float = 340 + (600 - row_w) / 2.0
	for i in earned_stars:
		var icon := TextureRect.new()
		icon.texture = star_tex
		# expand_mode has to come first: while it still is KEEP_SIZE the texture's own
		# size is the minimum, so assigning 28px here would silently stay at 100px.
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.position = Vector2(star_x + i * (icon_size + icon_gap), 180)
		icon.size = Vector2(icon_size, icon_size)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		overlay.add_child(icon)

	var y := 235
	var reward_label := _create_result_centered_label(
		TranslationManager.t("result_reward") % reward, y, 22, Color(0.9, 0.85, 0.7)
	)
	overlay.add_child(reward_label)
	y += 34

	if mine > 0:
		var mine_label := _create_result_centered_label(
			TranslationManager.t("result_mine") % mine, y, 22, Color(0.9, 0.85, 0.7)
		)
		overlay.add_child(mine_label)
		y += 34

	var total_label := _create_result_centered_label(
		TranslationManager.t("result_total") % (reward + mine), y, 22, Color(0.95, 0.9, 0.8)
	)
	overlay.add_child(total_label)
	y += 36

	var xp_label := _create_result_centered_label(
		TranslationManager.t("result_xp") % [
			xp_gained,
			(
				TranslationManager.t("xp_maximum")
				if new_level >= ProgressionData.MAX_KING_LEVEL
				else "%d / %d" % [total_xp, xp_to_next]
			),
		],
		y, 20, Color(0.7, 0.75, 0.9)
	)
	xp_label.name = "VictoryXpLabel"
	overlay.add_child(xp_label)
	y += 32

	var xp_bar := ProgressBar.new()
	xp_bar.name = "VictoryXpBar"
	xp_bar.position = Vector2(430, y)
	xp_bar.size = Vector2(420, 16)
	var at_max_level: bool = new_level >= ProgressionData.MAX_KING_LEVEL
	xp_bar.max_value = maxf(xp_to_next, 1.0)
	xp_bar.value = (
		1.0 if at_max_level else maxi(total_xp - xp_gained, 0)
	)
	xp_bar.show_percentage = false
	ButtonBuilder.style_progress_bar(xp_bar, Color(0.85, 0.65, 0.2), Color(0.22, 0.14, 0.06))
	overlay.add_child(xp_bar)
	y += 28

	if levels_gained > 0:
		var lvup_lbl := _create_result_centered_label(
			TranslationManager.t("result_level_up") % new_level, y, 24, Color(0.95, 0.85, 0.3)
		)
		overlay.add_child(lvup_lbl)
		y += 36
		var lvup_tween := overlay.create_tween()
		lvup_tween.tween_property(lvup_lbl, "scale", Vector2(1.25, 1.25), 0.3) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		lvup_tween.tween_property(lvup_lbl, "scale", Vector2(1.0, 1.0), 0.3)

	if not at_max_level:
		var bar_tween := overlay.create_tween()
		bar_tween.tween_property(xp_bar, "value", float(total_xp), 1.2).set_delay(0.4)

	_create_result_buttons(overlay, y + 22, [
		{"text": TranslationManager.t("result_retry"), "action": _retry_current_stage, "sound": ClickPlayer.play_select_3},
		{"text": TranslationManager.t("result_quit"), "action": _quit_to_level_track, "sound": ClickPlayer.play_select_4},
		{"text": TranslationManager.t("result_next_stage"), "action": _start_next_stage, "sound": ClickPlayer.play_start}
	])


func _make_modal_overlay(parent: Node) -> Control:
	var overlay := Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(overlay)
	return overlay


func _create_result_centered_label(text: String, y: int, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.position = Vector2(340, y)
	label.size = Vector2(600, 36)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", font_size)
	return label


func _create_result_buttons(overlay: Control, y: int, actions: Array) -> void:
	const BUTTON_WIDTH := 180
	const BUTTON_HEIGHT := 56
	const BUTTON_GAP := 12
	var row_width: int = actions.size() * BUTTON_WIDTH + maxi(0, actions.size() - 1) * BUTTON_GAP
	var x: float = (1280.0 - float(row_width)) / 2.0
	for action in actions:
		var button := ButtonBuilder.create_small_button(
			str(action["text"]), BUTTON_WIDTH, BUTTON_HEIGHT
		)
		button.add_theme_font_size_override("font_size", 20)
		button.position = Vector2(x, y)
		button.pressed.connect(action["sound"])
		button.pressed.connect(action["action"])
		overlay.add_child(button)
		x += BUTTON_WIDTH + BUTTON_GAP


func _retry_current_stage() -> void:
	UnitPool.clear_enemy_pool()
	SceneManager.go_to_scene(
		"res://scenes/run/RunController.tscn", {"stage_number": stage_number}
	)


func _quit_to_level_track() -> void:
	SceneManager.go_to_scene("res://scenes/hub/LevelTrack.tscn")


func _start_next_stage() -> void:
	SceneManager.go_to_scene(
		"res://scenes/run/RunController.tscn", {"stage_number": SaveManager.stage_number}
	)


func _show_defeat_notification() -> void:
	var overlay := _make_modal_overlay(hud_ui)
	overlay.name = "DefeatOverlay"

	var bg := ColorRect.new()
	bg.size = Vector2(600, 350)
	bg.position = Vector2(340, 185)
	bg.color = Color(0.08, 0.04, 0.02, 0.95)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(bg)

	var title := _create_result_centered_label(
		TranslationManager.t("result_stage_failed"), 220, 30, Color(0.8, 0.2, 0.2)
	)
	overlay.add_child(title)

	var lives_label := _create_result_centered_label(
		TranslationManager.t("result_lives") % [SaveManager.lives, SaveManager.max_lives],
		285, 22, Color(0.9, 0.85, 0.7)
	)
	overlay.add_child(lives_label)

	var refill_label := _create_result_centered_label(
		TranslationManager.t("result_next_life") % _format_refill(SaveManager.get_lives_refill_seconds()),
		330, 18, Color(0.75, 0.72, 0.65)
	)
	overlay.add_child(refill_label)
	# The run is frozen on this screen, but SaveManager's refill clock keeps ticking, so
	# the countdown stays live; it flips to "Life restored!" when a life comes back.
	var handler := _on_defeat_refill_tick.bind(refill_label)
	SaveManager.lives_refill_tick.connect(handler)
	overlay.tree_exited.connect(func() -> void:
		if SaveManager.lives_refill_tick.is_connected(handler):
			SaveManager.lives_refill_tick.disconnect(handler)
	)

	var actions: Array = []
	if SaveManager.lives > 0:
		actions.append({
			"text": TranslationManager.t("result_retry"),
			"action": _retry_current_stage,
			"sound": ClickPlayer.play_select_3,
		})
	actions.append({
		"text": TranslationManager.t("result_quit"),
		"action": _quit_to_level_track,
		"sound": ClickPlayer.play_select_4,
	})
	_create_result_buttons(overlay, 390, actions)


func _format_refill(seconds_left: int) -> String:
	var minutes: int = floori(seconds_left / 60)
	var seconds: int = seconds_left % 60
	return "%d:%02d" % [minutes, seconds]


func _on_defeat_refill_tick(seconds_left: int, refill_label: Label) -> void:
	if not is_instance_valid(refill_label):
		return
	if SaveManager.lives >= SaveManager.max_lives:
		refill_label.text = TranslationManager.t("result_life_restored")
	else:
		refill_label.text = TranslationManager.t("result_next_life") % _format_refill(seconds_left)
