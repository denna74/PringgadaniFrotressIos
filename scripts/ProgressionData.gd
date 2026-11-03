class_name ProgressionData extends RefCounted

# ─── Building Economy ───
static func building_cost_gold(base_cost: int, level: int) -> int:
	return floori(base_cost * pow(1.15, level - 1))

static func building_gold_production(base_rate: int, level: int) -> int:
	return floori(base_rate * pow(1.2, level - 1))


static func gold_mine_production(level: int) -> int:
	var production: Array[int] = [5, 10, 17, 25, 35, 50]
	return production[clampi(level, 1, production.size()) - 1]

# ─── Ranged Combat ───
# Every arrow attacker (tower, archer, boss) shoots the same distance: 10 tiles.
# In 3D, 1 tile == 1 world unit, so this is 10.0 world units. Deliberately NOT
# level-scaled — the old 150.0 + level * 10.0 made towers cover the whole arena.
const ARROW_RANGE: float = 10.0

# ─── Defense Buildings ───
static func wall_hp(level: int) -> float:
	return 200.0 + level * 50.0

static func tower_damage(level: int) -> float:
	var damage: Array[float] = [25.0, 30.0, 40.0, 50.0, 65.0, 80.0]
	return damage[clampi(level, 1, damage.size()) - 1]

static func tower_range(_level: int) -> float:
	return ARROW_RANGE

static func barricade_slow(level: int) -> float:
	return clampf(0.3 + level * 0.05, 0.0, 0.9)

# ─── Pendopo ───
static func pendopo_hp(level: int) -> float:
	var hp: Array[float] = [1000.0, 1500.0, 2700.0, 5500.0, 7500.0, 10000.0]
	return hp[clampi(level, 1, hp.size()) - 1]


static func pendopo_heal(level: int) -> float:
	var heal: Array[float] = [20.0, 25.0, 40.0, 55.0, 75.0, 100.0]
	return heal[clampi(level, 1, heal.size()) - 1]

# ─── King Combat ───
static func king_speed() -> float:
	return 6.0

static func king_attack_cooldown() -> float:
	return 0.4

static func king_special_cooldown() -> float:
	return 5.0

# Derived from king_stats so a level-blind constant can never be used in its place.
# These used to be `return 100.0` / `return 200.0` with no level input, which meant
# any caller that missed the level silently pinned the king to level-1 pools.
static func king_stamina_max(level: int = 1, stars: int = 1) -> float:
	return king_stats(level, stars)["stamina_max"]

static func king_stamina_drain() -> float:
	return 8.0

static func king_stamina_regen() -> float:
	return 2.0

static func king_stamina_attack_cost() -> float:
	return 10.0

static func king_stamina_special_cost() -> float:
	return 25.0

static func king_mana_max(level: int = 1, stars: int = 1) -> float:
	return king_stats(level, stars)["mana_max"]

# ─── Difficulty Tuning ───
const MAX_KING_LEVEL: int = 99
const DIFFICULTY_CAP_STAGE: int = 250

const XP_CURVE_START_XP: int = 200
const XP_CURVE_END_XP: int = 69000
const XP_CURVE_END_LEVEL: int = 98

const UNDERLEVEL_SLOPE: float = 0.03
const UNDERLEVEL_MAX_MULT: float = 4.0

const ENEMY_BUDGET_BASE: int = 24
const ENEMY_BUDGET_CAP: int = 170
const WAVES_MIN: int = 4
const WAVES_MAX: int = 9
# First stage of each wave-count band; index 0 is WAVES_MIN. Bands are uneven on
# purpose -- 1-20 holds flat at 4, then the count steps up slowly -- which a
# stage/divisor ramp cannot express. 250 is the difficulty cap, so the 9-wave
# band starts there and everything past it reports 9.
const WAVE_BAND_START: Array[int] = [1, 21, 51, 81, 151, 250]

# Difficulty stops growing past the cap stage; arenas do not.
static func effective_stage(stage: int) -> int:
	return clampi(stage, 1, DIFFICULTY_CAP_STAGE)

# ─── Boss Schedule ───
# Each pendopo is ringed by this many buildable plots. Progression comes from
# levelling buildings, not from spreading them out, so build space stays tight
# around each pendopo instead of scattering unused placeholders across the arena.
const BUILDABLE_PER_PENDOPO: int = 6

# Bosses are ordered from weakest to strongest. Stages above the difficulty cap
# still advance the roster.
static func boss_roster(stage: int) -> Array[String]:
	if stage <= 10:
		return [BossRegistry.KALAPRACONA]
	if stage <= 30:
		return [BossRegistry.BOMA]
	if stage <= 60:
		return [BossRegistry.ASWATAMA]
	if stage <= 90:
		return [BossRegistry.KARNA]
	if stage <= 130:
		return [BossRegistry.KALAPRACONA, BossRegistry.BOMA]
	if stage <= 170:
		return [BossRegistry.KALAPRACONA, BossRegistry.ASWATAMA]
	if stage <= 210:
		return [BossRegistry.BOMA, BossRegistry.ASWATAMA]
	if stage <= DIFFICULTY_CAP_STAGE:
		return [BossRegistry.KALAPRACONA, BossRegistry.BOMA, BossRegistry.ASWATAMA]
	return [
		BossRegistry.KALAPRACONA,
		BossRegistry.BOMA,
		BossRegistry.ASWATAMA,
		BossRegistry.KARNA,
	]


static func final_boss_id(stage: int) -> String:
	var roster := boss_roster(stage)
	return roster.back() if not roster.is_empty() else ""


# Every boss appears on its own wave; the strongest is reserved for the finale.
static func boss_schedule(stage: int, total_waves: int) -> Array:
	if stage <= 0 or total_waves <= 0:
		return []
	var roster := boss_roster(stage)
	if roster.is_empty():
		return []

	var final_boss: String = roster.pop_back()
	var earlier_count: int = mini(roster.size(), total_waves - 1)
	var earlier_slots: int = total_waves - 1
	var plan: Array = []
	for i in range(earlier_count):
		var wave: int
		if earlier_count == 1:
			wave = ceili(float(earlier_slots) / 2.0)
		else:
			wave = 1 + roundi(
				float(i * (earlier_slots - 1)) / float(earlier_count - 1)
			)
		plan.append({"wave": wave, "boss_id": roster[i]})
	plan.append({"wave": total_waves, "boss_id": final_boss})
	plan.sort_custom(func(a, b): return int(a["wave"]) < int(b["wave"]))
	return plan


# ─── Enemy Scaling ───
static func _stage_stat(start: float, finish: float, stage: int) -> float:
	var clamped_stage: int = effective_stage(stage)
	var progress: float = float(clamped_stage - 1) / float(DIFFICULTY_CAP_STAGE - 1)
	return lerpf(start, finish, progress)


static func enemy_unit_stats(unit_type: String, stage: int) -> Dictionary:
	var stats: Dictionary
	match unit_type:
		"archer":
			stats = {
				"hp": _stage_stat(300.0, 1600.0, stage),
				"attack": _stage_stat(45.0, 120.0, stage),
				"defense": _stage_stat(5.0, 20.0, stage),
			}
		_:
			stats = {
				"hp": _stage_stat(400.0, 2000.0, stage),
				"attack": _stage_stat(30.0, 100.0, stage),
				"defense": _stage_stat(10.0, 30.0, stage),
			}
	return stats


static func enemy_hp(stage: int, _king_level: int = 1) -> float:
	return enemy_unit_stats("infantry", stage)["hp"]


static func enemy_attack(stage: int, _king_level: int = 1) -> float:
	return enemy_unit_stats("infantry", stage)["attack"]


static func enemy_defense(stage: int, _king_level: int = 1) -> float:
	return enemy_unit_stats("infantry", stage)["defense"]


static func boss_stats(boss_id: String, stage: int) -> Dictionary:
	var endpoints: Dictionary = {
		BossRegistry.KALAPRACONA: {
			"hp": [500.0, 3600.0],
			"attack": [80.0, 240.0],
			"defense": [12.0, 36.0],
		},
		BossRegistry.BOMA: {
			"hp": [520.0, 4000.0],
			"attack": [90.0, 300.0],
			"defense": [16.0, 42.0],
			"mana": [25.0, 200.0],
		},
		BossRegistry.ASWATAMA: {
			"hp": [600.0, 4500.0],
			"attack": [100.0, 360.0],
			"defense": [20.0, 50.0],
			"mana": [30.0, 310.0],
			"stamina": [50.0, 200.0],
		},
		BossRegistry.KARNA: {
			"hp": [800.0, 8500.0],
			"attack": [120.0, 400.0],
			"defense": [30.0, 80.0],
			"mana": [35.0, 350.0],
			"stamina": [75.0, 250.0],
		},
	}
	var selected: Dictionary = endpoints.get(
		boss_id, endpoints[BossRegistry.KALAPRACONA]
	)
	return {
		"hp": _stage_stat(selected["hp"][0], selected["hp"][1], stage),
		"attack": _stage_stat(selected["attack"][0], selected["attack"][1], stage),
		"defense": _stage_stat(selected["defense"][0], selected["defense"][1], stage),
		"stamina_max": _stage_stat(
			selected.get("stamina", [0.0, 0.0])[0],
			selected.get("stamina", [0.0, 0.0])[1],
			stage
		),
		"mana_max": _stage_stat(
			selected.get("mana", [0.0, 0.0])[0],
			selected.get("mana", [0.0, 0.0])[1],
			stage
		),
	}


static func gatotkaca_stats(stage: int) -> Dictionary:
	return {
		"hp": _stage_stat(600.0, 7500.0, stage),
		"attack": _stage_stat(100.0, 700.0, stage),
		"defense": _stage_stat(20.0, 60.0, stage),
	}

# Continuous penalty for playing under-levelled. Never a bonus for over-levelling,
# and deliberately free of any stage threshold so difficulty never steps.
static func underlevel_multiplier(stage: int, king_level: int) -> float:
	var deficit: int = maxi(0, expected_level(stage) - king_level)
	return minf(1.0 + UNDERLEVEL_SLOPE * float(deficit), UNDERLEVEL_MAX_MULT)

# The level a player naturally holds on reaching a stage, given win_xp and xp_to_next.
static func expected_level(stage: int) -> int:
	var available: int = win_xp_from(1, effective_stage(stage))
	var level: int = 1
	while level < MAX_KING_LEVEL and _cumulative_xp_to(level + 1) <= available:
		level += 1
	return level

static func _cumulative_xp_to(level: int) -> int:
	var total: int = 0
	for l in range(1, level):
		total += xp_to_next(l)
	return total

# Sum of win_xp across an inclusive stage range (uncapped, for expected_level only).
static func win_xp_from(first_stage: int, last_stage: int) -> int:
	var steps: int = maxi(1, last_stage - first_stage + 1)
	return (first_stage + last_stage) * steps / 2 * 50

# ─── Waves ───
static func num_waves(stage: int) -> int:
	var s: int = effective_stage(stage)
	for i in range(WAVE_BAND_START.size() - 1, -1, -1):
		if s >= WAVE_BAND_START[i]:
			return mini(WAVES_MIN + i, WAVES_MAX)
	return WAVES_MIN

static func enemy_budget(stage: int) -> int:
	var s: int = effective_stage(stage)
	var stage_budget_increase: int = floori(
		float(ENEMY_BUDGET_CAP - ENEMY_BUDGET_BASE)
			* float(s - 1)
			/ float(DIFFICULTY_CAP_STAGE - 1)
	)
	return ENEMY_BUDGET_BASE + stage_budget_increase

static func enemies_per_wave(stage: int, wave: int) -> int:
	var waves: int = num_waves(stage)
	var per_wave: int = int(ceil(float(enemy_budget(stage)) / float(waves)))
	if wave == waves:
		per_wave += 1
	return maxi(1, per_wave)

# ─── Prep Time ───
# Breather between waves. Scales with pendopo count rather than the raw stage
# number: more forts means more to repair and re-garrison, so the extra time is
# earned by the arena growing instead of being a hidden stage-number threshold.
const PREP_TIME_BASE: float = 15.0
const PREP_TIME_PER_PENDOPO: float = 5.0

static func wave_prep_time(stage: int) -> float:
	return PREP_TIME_BASE + PREP_TIME_PER_PENDOPO * float(pendopo_count(stage) - 1)

# ─── Arena ───
# Arena size per pendopo count.
const ARENA_SIZES: Array[int] = [32, 64, 96]

static func pendopo_count(stage: int) -> int:
	if stage >= 150: return 3
	if stage >= 50: return 2
	return 1

static func map_size(stage: int) -> int:
	return ARENA_SIZES[pendopo_count(stage) - 1]

static func building_plots(stage: int) -> int:
	return (BUILDABLE_PER_PENDOPO + 1) * pendopo_count(stage)

# ─── Economy ───
static func stage_reward_gold(stage: int) -> int:
	return 100 + floori(stage * 20)

static func stage_gold_per_building(stage: int) -> int:
	return 5 + floori(stage / 3)

# ─── Troop Training ───
static func troop_training_cost(troop_type: String, level: int) -> int:
	var base := 10
	match troop_type:
		"infantry": base = 10
		"archer": base = 15
	return base + level * 2

static func troop_stats(troop_type: String, barracks_level: int = 1) -> Dictionary:
	var clamped_level: int = clampi(barracks_level, 1, BuildingUpgradeData.MAX_LEVEL)
	var progress: float = float(clamped_level - 1) / float(maxi(BuildingUpgradeData.MAX_LEVEL - 1, 1))
	if troop_type != "archer":
		troop_type = "infantry"
	var base_stats := {
		"infantry": {
			"hp": 400.0,
			"attack": 40.0,
			"defense": 10.0,
		},
		"archer": {
			"hp": 300.0,
			"attack": 45.0,
			"defense": 5.0,
		},
	}
	var max_stats := {
		"infantry": {
			"hp": 2000.0,
			"attack": 100.0,
			"defense": 30.0,
		},
		"archer": {
			"hp": 1600.0,
			"attack": 120.0,
			"defense": 20.0,
		},
	}
	var start: Dictionary = base_stats[troop_type]
	var goal: Dictionary = max_stats[troop_type]
	var current: Dictionary = {}
	for key in ["hp", "attack", "defense"]:
		current[key] = lerpf(float(start.get(key, 0.0)), float(goal.get(key, 0.0)), progress)

	match troop_type:
		"archer":
			return {
				"hp": current["hp"],
				"attack": current["attack"],
				"defense": current["defense"],
				"range": ARROW_RANGE,
				"cooldown": 1.6,
				"speed": 2.0,
				# Detection must outrange the weapon or an archer can never acquire.
				"detection": ARROW_RANGE + 2.0,
				"ranged": true,
			}
		_:
			return {
				"hp": current["hp"],
				"attack": current["attack"],
				"defense": current["defense"],
				"range": 1.6,
				"cooldown": 0.9,
				"speed": 2.0,
				"detection": 5.0,
				"ranged": false,
			}

# ─── King Progression ───
static func xp_to_next(level: int) -> int:
	if level < 1 or level >= MAX_KING_LEVEL:
		return 0
	var level_progress: float = (
		float(level * level - 1)
		/ float(XP_CURVE_END_LEVEL * XP_CURVE_END_LEVEL - 1)
	)
	return roundi(
		float(XP_CURVE_START_XP)
		+ float(XP_CURVE_END_XP - XP_CURVE_START_XP) * level_progress
	)

static func win_xp(stage: int) -> int:
	return 50 * mini(stage, DIFFICULTY_CAP_STAGE)

## Rates a cleared stage out of three.
##
## 3 -- every pendopo still standing and the king above half health.
## 2 -- every pendopo still standing, but the king at or below half health.
## 1 -- at least one pendopo fell, whatever the king's health was.
##
## A fort that fell outweighs how healthy the king is, so the pendopo check comes
## first. A stage with no known pendopo cannot claim a clean sweep. Exactly half
## health is a 2: the third star has to be earned by staying above it.
static func stage_stars(
	pendopo_alive: int, pendopo_total: int, king_hp: float, king_max_hp: float
) -> int:
	if pendopo_total <= 0 or pendopo_alive < pendopo_total:
		return 1
	if king_max_hp <= 0.0:
		return 2
	return 3 if king_hp / king_max_hp > 0.5 else 2

static func king_stats(level: int, stars: int) -> Dictionary:
	var star_mult: float = 1.0 + 0.08 * float(stars - 1)
	return {
		"hp": (300.0 + level * 30.0) * star_mult,
		"attack": (25.0 + level * 3.0) * star_mult,
		"defense": (10.0 + level * 2.0) * star_mult,
		"stamina_max": (100.0 + level * 4.0) * star_mult,
		"mana_max": (200.0 + level * 10.0) * star_mult,
	}

static func armor_damage(amount: float, defense: float) -> float:
	return maxf(1.0, amount * 100.0 / (100.0 + maxf(0.0, defense)))

# ─── Campaign ───
# Campaign tiers follow the stage boss roster. Enemy difficulty is capped, but
# the all-kings roster begins after stage 250.
static func campaign_tier(stage: int) -> String:
	if stage <= 10: return "kalapracona_campaign"
	if stage <= 30: return "boma_campaign"
	if stage <= 60: return "aswatama_campaign"
	if stage <= 90: return "karna_campaign"
	if stage <= 130: return "kalapracona_boma_campaign"
	if stage <= 170: return "kalapracona_aswatama_campaign"
	if stage <= 210: return "boma_aswatama_campaign"
	if stage <= DIFFICULTY_CAP_STAGE: return "three_kings_campaign"
	return "all_kings_campaign"

const _CAMPAIGN_TITLES := {
	"kalapracona_campaign": "Kalapracona's Challenge",
	"boma_campaign": "Boma Narakasura's Challenge",
	"aswatama_campaign": "Aswatama's Challenge",
	"karna_campaign": "Karna's Challenge",
	"kalapracona_boma_campaign": "Kalapracona and Boma",
	"kalapracona_aswatama_campaign": "Kalapracona and Aswatama",
	"boma_aswatama_campaign": "Boma and Aswatama",
	"three_kings_campaign": "Three Kings",
	"all_kings_campaign": "All Kings",
}

static func campaign_title(stage: int) -> String:
	return _CAMPAIGN_TITLES.get(campaign_tier(stage), "Unknown")
