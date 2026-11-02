class_name BuildingUpgradeData extends RefCounted

const MAX_LEVEL: int = 6
const IDS: Array[String] = ["pendopo", "menara", "barak", "tambang_emas"]

const UPGRADE_COSTS := {
	"pendopo": [7000, 20000, 35000, 50000, 70000],
	"menara": [5000, 15000, 27000, 40000, 55000],
	"barak": [6500, 21000, 38000, 55000, 80000],
	"tambang_emas": [8500, 23000, 40000, 60000, 85000],
}

const NAME_KEYS := {
	"pendopo": "building_upgrade_pendopo",
	"menara": "building_upgrade_tower",
	"barak": "building_upgrade_barracks",
	"tambang_emas": "building_upgrade_gold_mine",
}

const ICON_PATHS := {
	"pendopo": "res://assets/buttons/buildings_icons/icon_pendopo.png",
	"menara": "res://assets/buttons/buildings_icons/icon_tower.png",
	"barak": "res://assets/buttons/buildings_icons/icon_barrack.png",
	"tambang_emas": "res://assets/buttons/buildings_icons/icon_gold_mine.png",
}


static func upgrade_cost(id: String, current_level: int) -> int:
	var costs: Array = UPGRADE_COSTS.get(id, [])
	var index: int = clampi(current_level, 1, MAX_LEVEL) - 1
	if costs.is_empty() or index >= costs.size():
		return 0
	return int(costs[index])


static func current_effect(id: String, level: int) -> float:
	var clamped_level := clampi(level, 1, MAX_LEVEL)
	match id:
		"pendopo":
			return ProgressionData.pendopo_hp(clamped_level)
		"menara":
			return ProgressionData.tower_damage(clamped_level)
		"barak":
			var barracks_data := BuildingData.get_building_data("barak")
			return barracks_training_time(
				float(barracks_data.get("training_speed", 10)), clamped_level
			)
		"tambang_emas":
			return ProgressionData.gold_mine_production(clamped_level)
	return 0.0


static func barracks_training_time(base_time: float, level: int) -> float:
	return maxf(1.0, base_time * pow(0.9, float(clampi(level, 1, MAX_LEVEL) - 1)))


static func effect_label_key(id: String) -> String:
	match id:
		"pendopo":
			return "building_effect_hp"
		"menara":
			return "building_effect_damage"
		"barak":
			return "building_effect_training_time"
		"tambang_emas":
			return "building_effect_gold_tick"
	return ""


static func effect_suffix(id: String) -> String:
	return "s" if id == "barak" else ""
