class_name EquipmentDatabase extends RefCounted

const EQUIPMENT_SLOTS := ["head", "body", "right_hand", "left_hand"]

static var _cached: Array[Dictionary] = []
static var _index: Dictionary = {}


static func _load_all() -> void:
	if not _cached.is_empty():
		return
	var file: FileAccess = FileAccess.open("res://resources/equipment.json", FileAccess.READ)
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


static func get_by_type(item_type: String) -> Array[Dictionary]:
	_load_all()
	var result: Array[Dictionary] = []
	for item in _cached:
		if item.get("type", "") == item_type or item.get("hand", "") == item_type:
			result.append(item.duplicate(true))
	return result


static func get_unlocked_at_stage(stage: int) -> Array[Dictionary]:
	_load_all()
	var result: Array[Dictionary] = []
	for item in _cached:
		if item.get("unlock_stage", 1) <= stage:
			result.append(item.duplicate(true))
	return result


static func item_fits_slot(item: Dictionary, slot: String) -> bool:
	match slot:
		"head":
			return item.get("type", "") == "head"
		"body":
			return item.get("type", "") == "body"
		"right_hand", "left_hand":
			return item.get("type", "") == "hand"
	return false


static func can_equip(item_id: String, slot: String) -> bool:
	var item: Dictionary = get_item(item_id)
	return not item.is_empty() and item_fits_slot(item, slot)


static func get_bonuses(equipped: Dictionary) -> Dictionary:
	var bonuses: Dictionary = {
		"attack": 0.0,
		"defense": 0.0,
		"hp": 0.0,
		"mana_max": 0.0,
		"stamina_max": 0.0,
	}
	for slot: String in EQUIPMENT_SLOTS:
		var item_id: String = equipped.get(slot, "")
		if item_id.is_empty():
			continue
		var item: Dictionary = get_item(item_id)
		if item.is_empty():
			continue
		bonuses["attack"] += float(item.get("atk_bonus", 0))
		bonuses["defense"] += float(item.get("def_bonus", 0))
		bonuses["hp"] += float(item.get("hp_bonus", 0))
		bonuses["mana_max"] += float(item.get("mana_bonus", 0))
		bonuses["stamina_max"] += float(item.get("stamina_bonus", 0))
	return bonuses


static func apply_to_stats(base_stats: Dictionary, equipped: Dictionary) -> Dictionary:
	var result: Dictionary = base_stats.duplicate(true)
	var bonuses: Dictionary = get_bonuses(equipped)
	for key: String in bonuses:
		result[key] = float(result.get(key, 0.0)) + float(bonuses[key])
	return result


static func format_stats(item: Dictionary) -> String:
	var parts: Array[String] = []
	var atk: int = int(item.get("atk_bonus", 0))
	var defense: int = int(item.get("def_bonus", 0))
	var hp: int = int(item.get("hp_bonus", 0))
	var mana: int = int(item.get("mana_bonus", 0))
	var stamina: int = int(item.get("stamina_bonus", 0))
	if atk != 0:
		parts.append("ATK+%d" % atk)
	if defense != 0:
		parts.append("DEF+%d" % defense)
	if hp != 0:
		parts.append("HP+%d" % hp)
	if mana != 0:
		parts.append("MP+%d" % mana)
	if stamina != 0:
		parts.append("STA+%d" % stamina)
	return "  ".join(parts)


static func get_rarity_color(rarity: String) -> Color:
	match rarity:
		"common": return Color(0.7, 0.7, 0.7)
		"uncommon": return Color(0.3, 0.8, 0.3)
		"rare": return Color(0.3, 0.5, 0.9)
		"epic": return Color(0.7, 0.3, 0.9)
		"legendary": return Color(0.95, 0.75, 0.1)
	return Color(0.7, 0.7, 0.7)
