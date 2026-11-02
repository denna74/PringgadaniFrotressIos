class_name EnemySpawner extends RefCounted

const TYPES: Array[String] = ["infantry", "archer"]
const ENEMY_ARCHER_STAGE: int = 30
const NAMES: Array[String] = ["Prajurit Kurawa", "Prajurit Alengka", "Buta"]
const COLORS: Array[Color] = [
	Color(0.7, 0.2, 0.2), Color(0.5, 0.3, 0.6), Color(0.3, 0.5, 0.3)
]
const BOSS_COLOR := Color(0.9, 0.2, 0.2)
const BOSS_SPEED: float = 1.5
const GRUNT_SPEED: float = 1.9


static func spawn_wave(
	wave_number: int,
	total_waves: int,
	stage_number: int,
	spawn_positions: Array,
	king_level: int = 1
) -> Array:
	var count: int = ProgressionData.enemies_per_wave(stage_number, wave_number)
	var is_final: bool = wave_number == total_waves

	var enemies: Array = []
	for i in range(count):
		var boss_slot: bool = is_final and i == count - 1
		enemies.append(_build_enemy_data(
			stage_number, king_level, wave_number, boss_slot
		))
	return enemies


static func spawn_batch(
	count: int,
	wave_number: int,
	stage_number: int,
	spawn_positions: Array,
	king_level: int = 1
) -> Array:
	var enemies: Array = []
	for i in range(count):
		enemies.append(_build_enemy_data(
			stage_number, king_level, wave_number, false
		))
	return enemies


static func spawn_boss(wave_number: int, stage_number: int, king_level: int = 1,
		boss_id: String = BossRegistry.KALAPRACONA) -> Dictionary:
	var data: Dictionary = _build_enemy_data(stage_number, king_level, wave_number, true)
	var boss: Dictionary = BossRegistry.get_boss(boss_id)
	if boss.is_empty():
		boss = BossRegistry.get_boss(BossRegistry.KALAPRACONA)
		boss_id = BossRegistry.KALAPRACONA
	var stats: Dictionary = ProgressionData.boss_stats(boss_id, stage_number)

	data["boss_id"] = boss_id
	data["name"] = str(boss.get("name_en", boss_id))
	data["model"] = str(boss.get("model", "kurawa"))
	data["ranged"] = boss.get("ranged", false)
	data["arrow_style"] = str(boss.get("arrow_style", ""))
	data["special"] = str(boss.get("special", "none"))
	data["specials"] = boss.get("specials", [])
	data["attack_variants"] = boss.get("attack_variants", [])
	data["boss_color"] = boss.get("color", Color.WHITE)
	data["health"] = stats["hp"]
	data["max_health"] = stats["hp"]
	data["attack"] = stats["attack"]
	data["defense"] = stats["defense"]
	data["speed"] = float(boss.get("speed", 2.2))
	return data


# Archers unlock at stage 30; before that the roster is just melee.
static func available_types(stage_number: int) -> Array[String]:
	if ProgressionData.effective_stage(stage_number) >= ENEMY_ARCHER_STAGE:
		return TYPES.duplicate()
	return ["infantry"]


static func _build_enemy_data(
	stage_number: int,
	_king_level: int,
	_wave_number: int,
	is_boss: bool
) -> Dictionary:
	var roster: Array[String] = available_types(stage_number)
	var t_idx: int = randi() % roster.size()
	var unit_type: String = roster[t_idx]
	var stats: Dictionary = ProgressionData.enemy_unit_stats(unit_type, stage_number)
	return {
		"type": unit_type,
		"attack": stats["attack"],
		"defense": stats["defense"],
		"health": stats["hp"],
		"max_health": stats["hp"],
		"name": ("%s Boss" % NAMES[t_idx]) if is_boss else NAMES[t_idx],
		"is_boss": is_boss,
		"color": BOSS_COLOR if is_boss else COLORS[t_idx],
		"speed": BOSS_SPEED if is_boss else GRUNT_SPEED,
	}
