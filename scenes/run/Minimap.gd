extends Control

const TILE_GRASS := 0
const TILE_PATH := 1
const TILE_OBSTACLE := 2
const TILE_RESOURCE := 3
const TILE_SPAWN := 4

var _terrain_tex: ImageTexture = null
var _map_size: int = 0
var _king_pos: Vector2 = Vector2.ZERO
var _pendopo_positions: Array = []
var _enemy_positions: Array = []
var _troop_positions: Array = []
var _building_positions: Array = []


func _ready() -> void:
	size = Vector2(220, 220)
	custom_minimum_size = Vector2(220, 220)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func setup(terrain: Array, map_size: int) -> void:
	_map_size = map_size
	_bake_terrain(terrain)
	queue_redraw()


func update_positions(
	king_pos: Vector3,
	enemies: Array,
	troops: Array,
	buildings: Array,
	pendopo_poss: Array
) -> void:
	if _map_size <= 0:
		return
	_king_pos = _to_pixel(king_pos)
	_pendopo_positions = _map_array(pendopo_poss)
	_enemy_positions = _map_array(enemies)
	_troop_positions = _map_array(troops)
	_building_positions = _map_array(buildings)
	queue_redraw()


func _map_array(nodes: Array) -> Array:
	var result: Array = []
	for node in nodes:
		if node is Node3D:
			result.append(_to_pixel(node.global_position))
		elif node is Vector3:
			result.append(_to_pixel(node))
	return result


func _to_pixel(world: Vector3) -> Vector2:
	var center: float = _map_size * 0.5
	var tile_x: float = world.x + center
	var tile_z: float = world.z + center
	var pixel := Vector2(tile_x, tile_z) / _map_size * size
	return pixel.clamp(Vector2.ZERO, size)


func _bake_terrain(terrain: Array) -> void:
	var img := Image.create(_map_size, _map_size, false, Image.FORMAT_RGBA8)
	for y in range(_map_size):
		for x in range(_map_size):
			img.set_pixel(x, y, _tile_color(terrain[y][x]))
	_terrain_tex = ImageTexture.create_from_image(img)


func _tile_color(tile: int) -> Color:
	match tile:
		TILE_PATH:
			return Color(0.75, 0.6, 0.4, 0.7)
		TILE_OBSTACLE:
			return Color(0.25, 0.2, 0.12, 0.8)
		TILE_RESOURCE:
			return Color(0.85, 0.7, 0.25, 0.8)
		TILE_SPAWN:
			return Color(0.7, 0.35, 0.3, 0.75)
		_:
			return Color(0, 0, 0, 0)


func _draw() -> void:
	var s := size
	if s.x <= 0 or s.y <= 0:
		s = Vector2(220, 220)

	draw_rect(Rect2(Vector2.ZERO, s), Color(0.08, 0.06, 0.03, 0.55))
	if _terrain_tex:
		draw_texture_rect(_terrain_tex, Rect2(Vector2.ZERO, s), false)
	draw_rect(Rect2(Vector2.ZERO, s), Color(0.5, 0.5, 0.5), false, 1.0)

	for pos in _building_positions:
		draw_circle(pos, 2.0, Color(0.9, 0.7, 0.35))
	for pos in _pendopo_positions:
		draw_circle(pos, 3.5, Color(1.0, 0.8, 0.0))
	for pos in _enemy_positions:
		draw_circle(pos, 2.5, Color(0.9, 0.25, 0.2))
	for pos in _troop_positions:
		draw_circle(pos, 2.5, Color(0.3, 0.95, 0.4))
	if _king_pos.length() > 0:
		draw_circle(_king_pos, 4.0, Color(0.3, 0.95, 0.4))
