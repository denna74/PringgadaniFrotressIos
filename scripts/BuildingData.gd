class_name BuildingData extends RefCounted

static var _cache: Array = []


static func _ensure_loaded() -> void:
    if _cache.is_empty():
        var file := FileAccess.open("res://resources/buildings.json", FileAccess.READ)
        if file:
            var json := JSON.new()
            var err := json.parse(file.get_as_text())
            if err == OK and json.data is Array:
                _cache = json.data as Array
            else:
                push_warning("BuildingData: Failed to parse buildings.json")


static func get_building_data(id: String) -> Dictionary:
    _ensure_loaded()
    for b in _cache:
        if b.get("id") == id:
            return b
    return {}


static func get_all_buildings() -> Array:
    _ensure_loaded()
    return _cache


static func get_building_cost(id: String, level: int) -> int:
    var data := get_building_data(id)
    var base_cost: int = data.get("base_cost_gold", 0)
    return ProgressionData.building_cost_gold(base_cost, level)


static func get_building_defense(id: String, level: int) -> float:
    var data := get_building_data(id)
    var btype: String = data.get("type", "")
    match btype:
        "tower":
            return ProgressionData.tower_damage(level)
    return 0.0
