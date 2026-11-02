class_name SkillData extends RefCounted

## Single source of truth for the three king skills: their six-level curves and the
## gold cost of each upgrade. Level 1 is the original tuned value, so an un-upgraded
## king behaves exactly as before.

const MAX_LEVEL: int = 6
const IDS := ["dash", "earthquake", "berserk"]

const DASH_DAMAGE := [0.30, 0.38, 0.46, 0.54, 0.62, 0.70]
const DASH_SPEED := [3.5, 3.7, 3.9, 4.1, 4.3, 4.5]
const QUAKE_DAMAGE := [2.0, 2.4, 2.8, 3.2, 3.6, 4.0]
const QUAKE_MP := [40, 37, 34, 31, 28, 25]
const BERSERK_ATTACK := [1.50, 1.60, 1.70, 1.80, 1.90, 2.00]
const BERSERK_DEFENSE := [1.50, 1.55, 1.60, 1.65, 1.70, 1.75]
const BERSERK_DRAIN := [2.0, 2.0, 2.0, 2.0, 2.0, 2.0]

## Gold to go from level N to N+1, indexed by N-1 (five entries per skill).
const UPGRADE_COSTS := {
	"dash": [3000, 6000, 10000, 14000, 20000],
	"earthquake": [5000, 8000, 12000, 16000, 22000],
	"berserk": [6000, 10000, 14000, 18000, 24000],
}

const NAME_KEYS := {
	"dash": ["skill_dash_t1", "skill_dash_t2"],
	"earthquake": ["skill_earthquake_t1", "skill_earthquake_t2"],
	"berserk": ["skill_berserk_t1", "skill_berserk_t2"],
}

const ICON_PATHS := {
	"dash": ["res://assets/buttons/dash.png", "res://assets/buttons/dash_2.png"],
	"earthquake": [
		"res://assets/buttons/skill_earth_quake.png",
		"res://assets/buttons/earthquake_2.png",
	],
	"berserk": ["res://assets/buttons/berserk.png", "res://assets/buttons/berserk_2.png"],
}


static func _clamped(level: int) -> int:
	return clampi(level, 1, MAX_LEVEL)


static func _at(table: Array, level: int) -> float:
	return float(table[_clamped(level) - 1])


static func dash_damage_mult(level: int) -> float:
	return _at(DASH_DAMAGE, level)


static func dash_speed_mult(level: int) -> float:
	return _at(DASH_SPEED, level)


static func quake_damage_mult(level: int) -> float:
	return _at(QUAKE_DAMAGE, level)


static func quake_mp_cost(level: int) -> float:
	return _at(QUAKE_MP, level)


static func berserk_attack_mult(level: int) -> float:
	return _at(BERSERK_ATTACK, level)


static func berserk_defense_mult(level: int) -> float:
	return _at(BERSERK_DEFENSE, level)


static func berserk_drain_per_sec(level: int) -> float:
	return _at(BERSERK_DRAIN, level)


static func upgrade_cost(id: String, current_level: int) -> int:
	if not UPGRADE_COSTS.has(id):
		return 0
	var level: int = _clamped(current_level)
	if level >= MAX_LEVEL:
		return 0
	return int(UPGRADE_COSTS[id][level - 1])


static func tier_index(level: int) -> int:
	return 0 if _clamped(level) <= 3 else 1


static func display_level(level: int) -> int:
	return ((_clamped(level) - 1) % 3) + 1


static func display_name_key(id: String, level: int = 1) -> String:
	var keys: Array = NAME_KEYS.get(id, [])
	if keys.is_empty():
		return ""
	return str(keys[tier_index(level)])


static func icon_path(id: String, level: int = 1) -> String:
	var paths: Array = ICON_PATHS.get(id, [])
	if paths.is_empty():
		return ""
	return str(paths[tier_index(level)])
