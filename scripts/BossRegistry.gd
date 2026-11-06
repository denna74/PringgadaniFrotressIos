class_name BossRegistry extends RefCounted

# Boss identity, rig and behavior metadata live here. Stage-scaled combat stats
# are defined alongside the other character curves in ProgressionData.

const KALAPRACONA: String = "kalapracona"
const BOMA: String = "boma"
const ASWATAMA: String = "aswatama"
const KARNA: String = "karna"

const BOSSES: Dictionary = {
	KALAPRACONA: {
		"name_en": "Kalapracona",
		"name_id": "Kalapracona",
		# Keep the weakest boss first in multi-boss stage schedules.
		"model": "kurawa",
		"speed": 1.9,
		"scale": 1.2,
		"color": Color(0.75, 0.25, 0.55),
		"ranged": false,
		"arrow_style": "",
		"special": "none",
		"role": "miniboss",
	},
	BOMA: {
		"name_en": "Boma Narakasura",
		"name_id": "Boma Narakasura",
		"model": "boma",
		"speed": 1.9,
		"scale": 1.4,
		"color": Color(0.85, 0.2, 0.2),
		"ranged": true,
		# Boma's signature: a red arrow dragging a red slash shadow behind it.
		"arrow_style": "boma_red",
		"special": "power_attack",
		"specials": ["dash"],
		"role": "elite",
	},
	ASWATAMA: {
		"name_en": "Aswatama",
		"name_id": "Aswatama",
		"model": "aswatama",
		"speed": 2.5,
		"scale": 1.4,
		"color": Color(0.35, 0.45, 0.9),
		"ranged": false,
		"arrow_style": "",
		"special": "dash",
		"specials": ["dash", "earthquake"],
		"role": "final",
	},
	KARNA: {
		"name_en": "Karna",
		"name_id": "Karna",
		"model": "karna",
		"speed": 3.0,
		"scale": 1.55,
		"color": Color(0.9, 0.18, 0.12),
		"ranged": false,
		"arrow_style": "",
		"special": "dash",
		"specials": ["dash", "earthquake", "berserk"],
		"attack_variants": ["attack", "attack_2", "attack_3"],
		"role": "final",
	},
}


static func boss_ids() -> Array:
	return BOSSES.keys()


static func has_boss(boss_id: String) -> bool:
	return BOSSES.has(boss_id)


static func get_boss(boss_id: String) -> Dictionary:
	return BOSSES.get(boss_id, {})


static func display_name(boss_id: String) -> String:
	return str(get_boss(boss_id).get("name_en", boss_id))


static func model_rig(boss_id: String) -> String:
	return str(get_boss(boss_id).get("model", "kurawa"))
