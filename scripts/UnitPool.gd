class_name UnitPool extends RefCounted


const SOLDIER_SCRIPT: GDScript = preload("res://scenes/run/SoldierUnit.gd")
const ENEMY_SCRIPT: GDScript = preload("res://scenes/run/enemy_script.gd")

const MAX_SOLDIERS := 24
const MAX_ENEMIES := 16

static var _soldier_pool: Array[SoldierUnit] = []
# Enemies are pooled PER TYPE. Archer and infantry are different rigs with
# different skeletons, and a node handed back for a type it was not built as keeps
# its old mesh -- so an archer would walk around on an infantry body, shooting
# arrows at you while looking like a plain soldier.
static var _enemy_pool: Dictionary = {}
static var _bar_texture: ImageTexture = null


static func acquire_soldier() -> SoldierUnit:
	while not _soldier_pool.is_empty():
		var unit: SoldierUnit = _soldier_pool.pop_back()
		if is_instance_valid(unit):
			return unit
	return SOLDIER_SCRIPT.new()


static func release_soldier(unit: SoldierUnit) -> void:
	if unit == null or not is_instance_valid(unit):
		return
	if not unit.is_inside_tree():
		return
	var parent := unit.get_parent()
	if parent:
		parent.remove_child(unit)
	if _soldier_pool.size() < MAX_SOLDIERS:
		_soldier_pool.append(unit)
	else:
		unit.queue_free()


static func acquire_enemy(type: String = "infantry") -> Node3D:
	var key: String = type if type == "archer" else "infantry"
	var bucket: Array = _enemy_pool.get(key, [])
	while not bucket.is_empty():
		var enemy: Node3D = bucket.pop_back()
		if is_instance_valid(enemy):
			if enemy.has_method("reset_for_pool"):
				enemy.reset_for_pool()
			return enemy
	_enemy_pool[key] = bucket
	return _build_enemy_node(key)


static func release_enemy(enemy: Node3D) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	if not enemy.is_inside_tree():
		return
	if not enemy.get_meta("pooled", false):
		enemy.queue_free()
		return
	# Return it to the bucket for the type it was configured as, so it can only
	# ever be handed back out as that same type.
	var key: String = "archer" if enemy.get_meta("enemy_data", {}).get("type", "infantry") == "archer" else "infantry"
	var parent := enemy.get_parent()
	if parent:
		parent.remove_child(enemy)
	var bucket: Array = _enemy_pool.get(key, [])
	if bucket.size() < MAX_ENEMIES:
		bucket.append(enemy)
		_enemy_pool[key] = bucket
	else:
		enemy.queue_free()


static func clear_enemy_pool() -> void:
	for bucket in _enemy_pool.values():
		for enemy in bucket:
			if is_instance_valid(enemy):
				enemy.queue_free()
	_enemy_pool.clear()


static func prewarm_enemies(count: int) -> void:
	# Both types, so the first archer wave does not pay for a cold model load.
	for key in ["infantry", "archer"]:
		var bucket: Array = _enemy_pool.get(key, [])
		for i in range(count):
			if bucket.size() >= MAX_ENEMIES:
				break
			bucket.append(_build_enemy_node(key))
		_enemy_pool[key] = bucket


static func prewarm_soldiers(count: int) -> void:
	var holder := Node3D.new()
	holder.name = "SoldierPrewarmHolder"
	if Engine.get_main_loop() != null:
		var tree: SceneTree = Engine.get_main_loop() as SceneTree
		if tree:
			tree.root.add_child(holder)
	for i in range(count):
		if _soldier_pool.size() >= MAX_SOLDIERS:
			break
		var soldier := SOLDIER_SCRIPT.new()
		holder.add_child(soldier)
		await engine_frames(1)
		if not is_instance_valid(soldier) or not soldier.is_inside_tree():
			continue
		holder.remove_child(soldier)
		_soldier_pool.append(soldier)
	if is_instance_valid(holder):
		holder.queue_free()


static func engine_frames(frames: int) -> void:
	for i in frames:
		await Engine.get_main_loop().process_frame


static func _build_enemy_node(type: String = "infantry") -> Node3D:
	var enemy: Node3D = ModelLoader.load_enemy(type, false)
	enemy.set_script(ENEMY_SCRIPT)
	enemy.set_meta("pooled", true)
	enemy.add_to_group("enemies")
	attach_common_children(enemy)
	return enemy


static func attach_common_children(enemy: Node3D) -> void:
	var nav := NavigationAgent3D.new()
	nav.target_desired_distance = 0.5
	nav.path_desired_distance = 0.5
	nav.name = "NavigationAgent3D"
	enemy.add_child(nav)

	var tex := _get_bar_texture()
	var hp_bg := Sprite3D.new()
	hp_bg.pixel_size = 0.01
	hp_bg.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	hp_bg.no_depth_test = true
	hp_bg.render_priority = 5
	hp_bg.texture = tex
	hp_bg.scale = Vector3(50, 5, 1)
	hp_bg.position.y = 2.0
	hp_bg.modulate = Color(0.3, 0.1, 0.1)
	enemy.add_child(hp_bg)

	var hp_bar := Sprite3D.new()
	hp_bar.name = "HPBar"
	hp_bar.pixel_size = 0.01
	hp_bar.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	hp_bar.no_depth_test = true
	hp_bar.render_priority = 10
	hp_bar.texture = tex
	hp_bar.scale = Vector3(50, 5, 1)
	hp_bar.position = Vector3(0, 2.0, 0.001)
	hp_bar.modulate = Color(0.2, 0.8, 0.2)
	enemy.add_child(hp_bar)


static func _get_bar_texture() -> ImageTexture:
	if _bar_texture == null:
		var img := Image.create(1, 1, false, Image.FORMAT_RGBA8)
		img.fill(Color.WHITE)
		_bar_texture = ImageTexture.create_from_image(img)
	return _bar_texture