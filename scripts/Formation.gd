class_name Formation extends RefCounted


const DEFAULT_FORMATION: Dictionary = {
    "infantry": 0.7,
    "archers": 0.3,
}


static func get_default() -> Dictionary:
    return DEFAULT_FORMATION.duplicate()


static func distribute_troops(total_count: int, formation: Dictionary) -> Dictionary:
    var result: Dictionary = {}
    for troop_type in formation:
        result[troop_type] = floori(total_count * formation[troop_type])
    return result


static func get_counter_advantage(attacker: String, defender: String) -> bool:
    return false
