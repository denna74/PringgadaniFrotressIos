extends Building

signal pendopo_destroyed

var pendopo_hp: float = 500.0
var pendopo_max_hp: float = 500.0
var _destroyed: bool = false

var _hp_bg_sprite: Sprite3D = null
var _hp_bar_sprite: Sprite3D = null
var _last_hp_ratio: float = -1.0
var _heal_zone: Node3D = null

const HEAL_ZONE_PATH: String = "res://scenes/effects/HealZone.tscn"
const EXPLOSION_PATH: String = "res://scenes/effects/PendopoExplosion.gd"


func setup(max_hp: float) -> void:
	pendopo_max_hp = max_hp
	pendopo_hp = pendopo_max_hp


func _ready() -> void:
	super._ready()

	var bar_y: float = 6.0

	_hp_bg_sprite = Sprite3D.new()
	_hp_bg_sprite.pixel_size = 0.01
	_hp_bg_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_hp_bg_sprite.texture = _create_bar_texture()
	_hp_bg_sprite.scale = Vector3(60, 5, 1)
	_hp_bg_sprite.position.y = bar_y
	_hp_bg_sprite.modulate = Color(0.3, 0.1, 0.1)
	add_child(_hp_bg_sprite)

	_hp_bar_sprite = Sprite3D.new()
	_hp_bar_sprite.pixel_size = 0.01
	_hp_bar_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_hp_bar_sprite.texture = _create_bar_texture()
	_hp_bar_sprite.scale = Vector3(60, 5, 1)
	_hp_bar_sprite.position = Vector3(0, bar_y, 0.001)
	_hp_bar_sprite.modulate = Color(0.2, 0.8, 0.2)
	add_child(_hp_bar_sprite)

	_build_heal_zone()


func _build_heal_zone() -> void:
	_heal_zone = load(HEAL_ZONE_PATH).instantiate()
	_heal_zone.name = "HealZone"
	add_child(_heal_zone)


func begin_heal_effect(active: bool) -> void:
	if _heal_zone != null and _heal_zone.has_method("set_healing_active"):
		_heal_zone.set_healing_active(active)


func _create_bar_texture() -> Texture2D:
	var img: Image = Image.create(1, 1, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	return ImageTexture.create_from_image(img)


func _process(_delta: float) -> void:
	_update_hp_bar()


func _update_hp_bar() -> void:
	if not _hp_bar_sprite:
		return
	var hp_ratio: float = clampf(pendopo_hp / maxf(pendopo_max_hp, 1.0), 0.0, 1.0)
	if is_equal_approx(hp_ratio, _last_hp_ratio):
		return
	_last_hp_ratio = hp_ratio
	_hp_bar_sprite.scale.x = 60 * hp_ratio
	_hp_bar_sprite.offset.x = -0.5 * _hp_bar_sprite.texture.get_width() \
		* (1.0 - hp_ratio) / hp_ratio if hp_ratio > 0.0 else 0.0
	if hp_ratio > 0.5:
		_hp_bar_sprite.modulate = Color(0.2, 0.8, 0.2)
	elif hp_ratio > 0.25:
		_hp_bar_sprite.modulate = Color(0.8, 0.8, 0.2)
	else:
		_hp_bar_sprite.modulate = Color(0.8, 0.2, 0.2)


func take_damage(amount: float) -> void:
	if _destroyed:
		return
	pendopo_hp -= amount
	if pendopo_hp <= 0:
		pendopo_hp = 0
		_destroyed = true
		_begin_destruction()
		pendopo_destroyed.emit()


# The fort falls apart and leaves the game. The explosion is spawned as a sibling so it
# outlives this node: it duplicates the model to sink and fade, and _process has to stop
# so the HP bar stops redrawing at zero.
func _begin_destruction() -> void:
	set_process(false)
	_hide_hp_bar()
	# The heal zone is built unconditionally in _ready(), so it would otherwise keep
	# glowing green on top of the rubble.
	begin_heal_effect(false)
	hide_overlay()
	if _model != null:
		_model.visible = false

	var parent: Node = get_parent()
	if parent == null:
		queue_free()
		return

	var script: GDScript = load(EXPLOSION_PATH)
	if script == null:
		queue_free()
		return
	var explosion: Node3D = script.new()
	explosion.name = "PendopoExplosion"
	# Add to the tree first: assigning global_position on a detached node reads a
	# get_global_transform() that is not defined yet and lands in the parent's local
	# space instead of world space.
	parent.add_child(explosion)
	explosion.global_position = global_position
	explosion.build_collapse(self)
	SFXManager.play_pendopo_destroyed()
	queue_free()


func _hide_hp_bar() -> void:
	if _hp_bar_sprite:
		_hp_bar_sprite.visible = false
	if _hp_bg_sprite:
		_hp_bg_sprite.visible = false


func is_destroyed() -> bool:
	return _destroyed


func get_hp_percent() -> float:
	return pendopo_hp / maxf(pendopo_max_hp, 1.0)
