class_name ConsumableDatabase extends RefCounted

static var _cached: Array[Dictionary] = []
static var _index: Dictionary = {}


static func _load_all() -> void:
	if not _cached.is_empty():
		return
	var file: FileAccess = FileAccess.open("res://resources/consumables.json", FileAccess.READ)
	if not file:
		return
	var json: Array = JSON.parse_string(file.get_as_text()) as Array
	file.close()
	for entry in json:
		var dict: Dictionary = entry as Dictionary
		_cached.append(dict)
		_index[dict["id"]] = dict


static func get_item(id: String) -> Dictionary:
	_load_all()
	return _index.get(id, {}).duplicate(true) as Dictionary


static func get_all() -> Array[Dictionary]:
	_load_all()
	var result: Array[Dictionary] = []
	for item in _cached:
		result.append(item.duplicate(true))
	return result


static func get_rarity_color(rarity: String) -> Color:
	match rarity:
		"common": return Color(0.7, 0.7, 0.7)
		"uncommon": return Color(0.3, 0.8, 0.3)
		"rare": return Color(0.3, 0.5, 0.9)
		"epic": return Color(0.7, 0.3, 0.9)
		"legendary": return Color(0.95, 0.75, 0.1)
	return Color(0.7, 0.7, 0.7)
