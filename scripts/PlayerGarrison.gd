class_name PlayerGarrison extends RefCounted

signal counts_changed

var infantry: int = 0
var archers: int = 0
var _reserved: Dictionary = {"infantry": 0, "archer": 0}


# buildings.json, EnemySpawner and the HUD all use the singular "archer", but this
# class historically used "archers" and silently dropped every singular key.
const ALIASES := {"archers": "archer", "archer": "archer",
                  "infantry": "infantry"}


func normalise(type: String) -> String:
    return ALIASES.get(type, "infantry")


func add_troops(type: String, count: int) -> void:
    match normalise(type):
        "infantry": infantry += count
        "archer": archers += count
    counts_changed.emit()


func has_troops(type: String, count: int) -> bool:
    match normalise(type):
        "infantry": return infantry >= count
        "archer": return archers >= count
    return false


func remove_troops(type: String, count: int) -> void:
    match normalise(type):
        "infantry": infantry = max(0, infantry - count)
        "archer": archers = max(0, archers - count)
    counts_changed.emit()


func reserve_troop(type: String, limit: int) -> bool:
    var troop_type: String = normalise(type)
    if _get_count(troop_type) >= limit:
        return false
    _reserved[troop_type] = get_reserved_count(troop_type) + 1
    counts_changed.emit()
    return true


func complete_troop_training(type: String) -> void:
    var troop_type: String = normalise(type)
    _reserved[troop_type] = maxi(0, get_reserved_count(troop_type) - 1)
    counts_changed.emit()


func cancel_troop_reservation(type: String) -> void:
    var troop_type: String = normalise(type)
    _reserved[troop_type] = maxi(0, get_reserved_count(troop_type) - 1)
    counts_changed.emit()


func get_reserved_count(type: String) -> int:
    return _reserved.get(normalise(type), 0)


func can_reserve_troop(type: String, limit: int) -> bool:
    return _get_count(type) < limit


func get_total() -> int:
    return infantry + archers


func get_distributed(formation: Dictionary) -> Dictionary:
    var result: Dictionary = {}
    var total := get_total()
    if total == 0:
        return {"infantry": 0, "archer": 0}
    for troop_type in formation:
        var ratio: float = formation[troop_type] as float
        var available := _get_count(troop_type)
        result[normalise(troop_type)] = mini(floori(total * ratio), available)
    return result


func _get_count(type: String) -> int:
    match normalise(type):
        "infantry": return infantry
        "archer": return archers
    return 0
