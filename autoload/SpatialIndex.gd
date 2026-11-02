extends Node

const CELL_SIZE: float = 4.0

var _cells: Dictionary = {}
var _unit_cells: Dictionary = {}  # unit -> Vector2i (last known cell)


func _cell_key(pos: Vector3) -> Vector2i:
	return Vector2i(floori(pos.x / CELL_SIZE), floori(pos.z / CELL_SIZE))


func register(unit: Node3D, group: String) -> void:
	if not is_instance_valid(unit):
		return
	var key := _cell_key(unit.global_position)
	if not _cells.has(key):
		_cells[key] = []
	_cells[key].append(unit)
	_unit_cells[unit] = key
	unit.set_meta("spatial_group", group)


func unregister(unit: Node3D) -> void:
	if _unit_cells.has(unit):
		var old_key: Vector2i = _unit_cells[unit]
		if _cells.has(old_key):
			_cells[old_key].erase(unit)
			if _cells[old_key].is_empty():
				_cells.erase(old_key)
		_unit_cells.erase(unit)


func is_registered(unit: Node3D) -> bool:
	return _unit_cells.has(unit)


func update() -> void:
	var to_move: Array = []
	# Iterate the dictionary directly rather than `_unit_cells.keys()`, which would copy
	# every key into a fresh array on each physics frame.
	for unit in _unit_cells:
		if not is_instance_valid(unit):
			to_move.append(unit)
			continue
		var new_key := _cell_key(unit.global_position)
		var old_key: Vector2i = _unit_cells[unit]
		if new_key != old_key:
			to_move.append(unit)
	if not to_move.is_empty():
		for unit in to_move:
			if not is_instance_valid(unit):
				if _unit_cells.has(unit):
					var old_key: Vector2i = _unit_cells[unit]
					if _cells.has(old_key):
						_cells[old_key].erase(unit)
						if _cells[old_key].is_empty():
							_cells.erase(old_key)
					_unit_cells.erase(unit)
				continue
			var new_key := _cell_key(unit.global_position)
			var old_key: Vector2i = _unit_cells[unit]
			if old_key != new_key:
				if _cells.has(old_key):
					_cells[old_key].erase(unit)
					if _cells[old_key].is_empty():
						_cells.erase(old_key)
				if not _cells.has(new_key):
					_cells[new_key] = []
				_cells[new_key].append(unit)
				_unit_cells[unit] = new_key


func get_nearby(pos: Vector3, radius: float, group: String) -> Array:
	var result: Array = []
	var cell_radius := ceili(radius / CELL_SIZE)
	var center := _cell_key(pos)
	var radius_sq := radius * radius
	for dx in range(-cell_radius, cell_radius + 1):
		for dz in range(-cell_radius, cell_radius + 1):
			var key := Vector2i(center.x + dx, center.y + dz)
			if not _cells.has(key):
				continue
			for unit in _cells[key]:
				if not is_instance_valid(unit):
					continue
				if unit.get_meta("spatial_group", "") != group:
					continue
				var diff := Vector3(unit.global_position.x - pos.x, 0.0, unit.global_position.z - pos.z)
				if diff.length_squared() <= radius_sq:
					result.append(unit)
	return result


func clear() -> void:
	_cells.clear()
	_unit_cells.clear()


func get_entity_count() -> int:
	return _unit_cells.size()


func get_nearest(pos: Vector3, radius: float, group: String) -> Node3D:
	var closest: Node3D = null
	var closest_dist_sq := radius * radius
	var cell_radius := ceili(radius / CELL_SIZE)
	var center := _cell_key(pos)
	for dx in range(-cell_radius, cell_radius + 1):
		for dz in range(-cell_radius, cell_radius + 1):
			var key := Vector2i(center.x + dx, center.y + dz)
			if not _cells.has(key):
				continue
			for unit in _cells[key]:
				if not is_instance_valid(unit):
					continue
				if unit.get_meta("spatial_group", "") != group:
					continue
				var diff := Vector3(unit.global_position.x - pos.x, 0.0, unit.global_position.z - pos.z)
				var dist_sq := diff.length_squared()
				if dist_sq <= closest_dist_sq:
					closest = unit
					closest_dist_sq = dist_sq
	return closest
