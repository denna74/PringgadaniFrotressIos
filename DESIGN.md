# PringgadaniFortress — Game Design & Implementation Plan

## Concept

A single-player 3D city-builder roguelite with Indonesian wayang mythology theme.
You play as **Gatotkaca**, king of the mythical flying fortress Pringgadani.
Each run builds the fortress from scratch on a procedurally generated map, defends against
escalating enemy waves, then resets — with persistent king progression between runs.

---

## Table of Contents

1. [Tech Stack & Conventions](#1-tech-stack--conventions)
2. [Project Structure](#2-project-structure)
3. [Game Loop](#3-game-loop)
4. [Data Layer: Formulas & Scaling](#4-data-layer-formulas--scaling)
5. [Data Files: JSON Schemas](#5-data-files-json-schemas)
6. [Autoloads (Singletons)](#6-autoloads-singletons)
7. [Scene Architecture](#7-scene-architecture)
8. [Phase 0: Project Scaffold (First Task)](#8-phase-0-project-scaffold-first-task)
9. [Full Build Order](#9-full-build-order)
10. [RondaPatrol Patterns to Reuse](#10-rondapatrol-patterns-to-reuse)

---

## 1. Tech Stack & Conventions

| Aspect | Decision |
|--------|----------|
| **Engine** | Godot 4.x |
| **Language** | GDScript (100%) |
| **Resolution** | 1280×720, `canvas_items` stretch mode |
| **Target** | Desktop first (Android later) |
| **Theme** | Wayang/Mahabharata — Gamelan-inspired BGM, batik UI motifs |
| **Naming** | `PascalCase.tscn`, `snake_case.gd` |
| **Pattern** | Programmatic node construction (like RondaPatrol — `.tscn` files are just script-attach points) |

---

## 2. Project Structure

```
PringgadaniFortress/
  project.godot
  export_presets.cfg

  autoload/
    SaveManager.gd              -- JSON save/load
    SceneManager.gd             -- Scene transitions
    EconomyManager.gd           -- Resource tracking + offline calc
    MusicManager.gd             -- BGM player
    ClickPlayer.gd              -- UI click SFX

  scripts/                      -- Static data classes (RefCounted)
    ProgressionData.gd          -- All scaling formulas
    BuildingData.gd             -- Building definitions
    CombatEngine.gd             -- Damage formulas
    MapGenerator.gd             -- Procedural map generation
    Formation.gd                -- Troop formation templates
    ButtonBuilder.gd            -- Bitmap font button builder

  scenes/
    hub/
      MainMenu.tscn,.gd         -- Title screen + start run
      LevelTrack.tscn,.gd       -- Stage hub with king box, blacksmith, market
      ProfilePage.gd            -- Gatotkaca profile (stats, equipment)
      BlacksmithPage.gd         -- Forge / equipment crafting
      MarketPage.gd             -- Buy & sell goods
      CatalogOverlay.tscn,.gd   -- Generic catalog viewer

    run/
      RunController.tscn,.gd    -- Run lifecycle manager
      BuildingPlot.tscn,.gd     -- Buildable plot on the map
      InvasionManager.tscn,.gd  -- Wave spawning & resolution
      RunHUD.tscn,.gd           -- In-run HUD (resources, wave counter)
      RunComplete.tscn,.gd      -- Victory/defeat + rewards screen

    buildings/
      Building.gd               -- Base building class
      Pendopo.gd                -- Town Center
      ResourceNode.gd           -- Farm, Sawmill, Quarry, Mine
      Barak.gd                  -- Barracks: trains infantry/archers
      Pasraman.gd               -- Academy / research

    combat/
      BattleResolution.tscn,.gd -- Auto-resolve results screen
      WaveReport.tscn,.gd       -- Per-wave summary

  resources/
    buildings.json
    strings_en.json
    strings_id.json

  assets/
    models/                     # 3D .glb models (characters, buildings)
      king/
      enemies/
      bosses/
      soldiers/
      buildings/
    sprites/                    # textures, UI art, billboard sprites
      buildings/
      heroes/
      enemies/
      ui/
      tilesets/
      effects/
    fonts/
    sfx/
    bgm/

  addons/
```

---

## 3. Game Loop

```
HUB (Main Menu)
  │
  ├── GATOTKACA — king profile, equipment, XP
  ├── BLACKSMITH — forge equipment
  ├── MARKET — buy & sell goods
  └── STAGE SELECT
        │
        └── [NEW EXPEDITION]
              │
              ▼
        RUN START
          │
          ├── MapGenerator generates procedural fortress map
          │     based on run_number
          │
          ├── BUILD PHASE (no time limit)
          │     Player places buildings on plots
          │     Trains troops at military buildings
          │     Clicks "READY" when done
          │
          ├── INVASION PHASE
          │     Multiple waves of enemies approach
          │     Each wave auto-resolved via CombatEngine
          │     Player sees battle report per wave
          │     Can repair buildings between waves (pay resources)
          │
          ├── BOSS WAVE (final wave)
          │     Stronger enemy with unique modifiers
          │
          ├── RUN END
          │     Victory: Pendopo survived all waves → full rewards
          │     Defeat:  Pendopo destroyed → partial rewards
          │
          └── REWARDS → added to persistent save
                run_number += 1
                return to HUB
```

---

## 4. Data Layer: Formulas & Scaling

### 4.1 `ProgressionData.gd` — Static class (like RondaPatrol's `LevelData.gd`)

```gdscript
class_name ProgressionData extends RefCounted

# ─── Map Generation ───
static func map_size(run: int) -> int:
    return 16 + floori(run / 10) * 2

static func building_plots(run: int) -> int:
    return 6 + floori(run / 5)

static func resource_abundance(run: int) -> float:
    return 1.0 + run * 0.02

# ─── Combat ───
static func enemy_hp_base(run: int) -> float:
    return 100.0 * (1.0 + run * 0.1)

static func enemy_attack_base(run: int) -> float:
    return 10.0 * (1.0 + run * 0.08)

static func enemy_defense_base(run: int) -> float:
    return 5.0 * (1.0 + run * 0.06)

static func num_waves(run: int) -> int:
    return 3 + floori(run / 15)

# ─── Economy ───
static func building_cost(base_cost: float, level: int) -> float:
    return base_cost * pow(1.15, level - 1)

static func building_production(base_rate: float, level: int) -> float:
    return base_rate * (1.0 + (level - 1) * 0.2)

static func run_reward_gold(run: int) -> int:
    return 50 + floori(run * 0.15 * 50)

# ─── Offline Earnings ───
static func offline_multiplier(hours_away: float) -> float:
    return min(1.0, hours_away / 2.0)

# ─── Damage Formula ───
static func calculate_damage(
    attack: float, lethality: float, enemy_defense: float,
    counters: bool, num_troops: int
) -> float:
    var base = attack * lethality / max(enemy_defense, 1.0)
    var counter_bonus = 1.25 if counters else 0.75
    return base * counter_bonus * num_troops * 0.01

# ─── Campaign Tier ───
static func campaign_tier(run: int) -> String:
    if run <= 10:   return "founding"
    if run <= 30:   return "kurawa_threat"
    if run <= 60:   return "astina_campaign"
    if run <= 100:  return "destiny"
    return "endless"

static func campaign_title(run: int) -> String:
    var titles = {
        "founding":      "Founding of Pringgadani",
        "kurawa_threat": "The Kurawa Threat",
        "astina_campaign": "Astina Campaign",
        "destiny":       "Revelation of Destiny",
        "endless":       "Endless Legends",
    }
    return titles.get(campaign_tier(run), "Unknown")
```

### 4.2 Ranged Combat

Every arrow attacker — Menara towers, allied archers, enemy archers, and the
Boma boss — shares **one** range constant:

```gdscript
const ARROW_RANGE: float = 10.0   # 10 tiles; in 3D, 1 tile == 1 world unit
```

It is deliberately **not** level-scaled. The original
`tower_range(level) = 150.0 + level * 10.0` made a level-1 tower cover the entire
arena; range is now fixed and only damage grows with level. Arrows are
projectiles (`arrow_projectile.gd`) that home on the target, so a ranged unit
deals damage over the stand-off gap instead of needing to touch.

Per-troop stats come from one table so soldiers, the barracks and the tests can
never disagree:

```gdscript
static func troop_stats(troop_type: String) -> Dictionary
```

| Troop | HP | Attack | Range | Cooldown | Speed | Ranged |
|-------|----|--------|-------|----------|-------|--------|
| Infantry | 60 | 12 | 1.6 | 0.9 s | 2.0 | no |
| Archer | 45 | 14 | 10.0 | 1.6 s | 2.0 | yes |

Detection radius must be >= the weapon range, otherwise an archer can never
acquire a target. Archers unlock on the enemy roster at **stage 30**; before
that the roster is infantry only.

### 4.3 Boss Roster

Bosses live in `scripts/BossRegistry.gd`; the stage schedule lives in
`ProgressionData.boss_schedule(stage, total_waves)`. `InvasionManager` only asks
"which boss rides this wave?", so adding a boss is a data change.

| Boss | Role | HP x | Atk x | Speed | Ranged | Special |
|------|------|------|-------|-------|--------|---------|
| Kalapracona | miniboss (Kurawa rig) | 1.5 | 1.25 | 1.9 | no | none |
| Boma Narakasura | elite | 2.0 | 1.4 | 1.9 | yes | `power_attack` |
| Aswatama | final | 2.4 | 1.5 | 2.5 | yes | `dash` |

**Kalapracona cadence scales with stage difficulty.** It debuts at stage 50 and
gains one extra appearance per 50 stages, capped at 4:

    appearances(stage) = 0                              if stage < 50
                       = clamp(1 + (stage-50)/50, 1, 4) otherwise

`kalapracona_waves()` spreads those appearances evenly across the non-final
waves; the last wave is always reserved for the stage finale. So stage 50 fields
1 miniboss, stage 150 fields 3, and stage 250 fields 4.

**Final boss by stage band:** Kalapracona below stage 100, Boma from 100, and
Aswatama from 200. From stage 200 a second boss (Boma) also rides the middle of
the run at 60% of the waves. A stage-250 run therefore fields 4 Kalapracona
minibosses + 1 Boma mid boss + 1 Aswatama finale.

Boss multipliers are applied in `EnemySpawner.spawn_boss()`, which also sets
`max_health` alongside `health` so the HP bar stays honest. Stage scaling is
frozen at stage 250 (`ProgressionData.effective_stage()`), including the
under-level penalty, so nothing keeps growing past the cap.

**Boma's red arrow.** `arrow_projectile.gd` takes a style. The `boma_red` style
tints the arrow red and attaches a `SlashShadow` node behind it: two wide,
angled, additive red quads, so the shot reads as a red slash streak rather than
a thin projectile. Ranged bosses fire at the same shared 10-tile standoff as
archers, and Boma looses the shot out of its `boss/power_attack` clip.

### 4.4 Building Cost Reference

| Building | Base Cost (Gold/Wood/Stone/Iron) | Base Production | Unlock Run |
|----------|----------------------------------|-----------------|------------|
| Pendopo (TC) | 0/50/30/0 | Level gating | 1 |
| Farm | 30/20/0/0 | +5 food/s | 1 |
| Sawmill | 30/0/20/0 | +5 wood/s | 1 |
| Quarry | 40/10/0/0 | +5 stone/s | 1 |
| Iron Mine | 50/20/10/0 | +3 iron/s | 5 |
| Barracks (Barak) | 60/40/20/0 | Trains any of the three troop types | 1 |
| Academy | 100/60/40/0 | Research | 10 |

The original concept had three separate barracks (Barak / Pemanah / Kandang
Kuda). Shipped as **one** barracks with an in-panel troop selector
(`Barak.set_troop_type()`), because separate buildings would need their own
models and the current GLB set only has `barak_lite.glb`. Splitting them later
is a data-only change.

Each level: cost × 1.15, production × 1.20

---

## 5. Data Files: JSON Schemas

### 5.1 `buildings.json`

```json
[
  {
    "id": "pendopo",
    "name_en": "Pendopo (Town Center)",
    "name_id": "Pendopo (Pusat Kota)",
    "type": "town_center",
    "max_level": 30,
    "base_cost": { "gold": 0, "wood": 50, "stone": 30, "iron": 0 },
    "cost_scale": 1.15,
    "production": {},
    "production_scale": 1.0,
    "description_en": "The heart of your fortress. Upgrade to unlock new buildings.",
    "description_id": "Jantung bentengmu. Tingkatkan untuk membuka bangunan baru.",
    "unlock_run": 1,
    "grid_size": { "w": 3, "h": 3 }
  },
  {
    "id": "farm",
    "name_en": "Farm (Lumbung)",
    "name_id": "Lumbung",
    "type": "resource",
    "max_level": 20,
    "base_cost": { "gold": 30, "wood": 20, "stone": 0, "iron": 0 },
    "cost_scale": 1.15,
    "production": { "food": 5 },
    "production_scale": 1.2,
    "description_en": "Produces food for your troops.",
    "description_id": "Menghasilkan makanan untuk pasukanmu.",
    "unlock_run": 1,
    "grid_size": { "w": 2, "h": 2 }
  },
  {
    "id": "sawmill",
    "name_en": "Sawmill (Penggergajian)",
    "name_id": "Penggergajian",
    "type": "resource",
    "max_level": 20,
    "base_cost": { "gold": 30, "wood": 0, "stone": 20, "iron": 0 },
    "cost_scale": 1.15,
    "production": { "wood": 5 },
    "production_scale": 1.2,
    "description_en": "Produces wood for construction.",
    "description_id": "Menghasilkan kayu untuk pembangunan.",
    "unlock_run": 1,
    "grid_size": { "w": 2, "h": 2 }
  },
  {
    "id": "quarry",
    "name_en": "Quarry (Tambang Batu)",
    "name_id": "Tambang Batu",
    "type": "resource",
    "max_level": 20,
    "base_cost": { "gold": 40, "wood": 10, "stone": 0, "iron": 0 },
    "cost_scale": 1.15,
    "production": { "stone": 5 },
    "production_scale": 1.2,
    "description_en": "Produces stone for advanced buildings.",
    "description_id": "Menghasilkan batu untuk bangunan tingkat lanjut.",
    "unlock_run": 1,
    "grid_size": { "w": 2, "h": 2 }
  },
  {
    "id": "iron_mine",
    "name_en": "Iron Mine (Tambang Besi)",
    "name_id": "Tambang Besi",
    "type": "resource",
    "max_level": 20,
    "base_cost": { "gold": 50, "wood": 20, "stone": 10, "iron": 0 },
    "cost_scale": 1.15,
    "production": { "iron": 3 },
    "production_scale": 1.2,
    "description_en": "Produces iron for military equipment.",
    "description_id": "Menghasilkan besi untuk perlengkapan militer.",
    "unlock_run": 5,
    "grid_size": { "w": 2, "h": 2 }
  },
  {
    "id": "barracks",
    "name_en": "Barracks (Barak)",
    "name_id": "Barak",
    "type": "military",
    "max_level": 15,
    "base_cost": { "gold": 60, "wood": 40, "stone": 20, "iron": 0 },
    "cost_scale": 1.15,
    "troop_type": "infantry",
    "troop_types": ["infantry", "archer"],
    "training_speed": 10,
  {
    "id": "academy",
    "name_en": "Academy (Pasraman)",
    "name_id": "Pasraman",
    "type": "research",
    "max_level": 15,
    "base_cost": { "gold": 100, "wood": 60, "stone": 40, "iron": 0 },
    "cost_scale": 1.15,
    "description_en": "Research technologies to improve economy and combat.",
    "description_id": "Teliti teknologi untuk meningkatkan ekonomi dan pertempuran.",
    "unlock_run": 10,
    "grid_size": { "w": 2, "h": 2 }
  }
]
```

> **Removed:** `heroes.json` and the collectible-hero system (roster, detail, deploy) were cut.
> The king (Gatotkaca) is the only hero; his level/stars/XP persist in `SaveManager.heroes["gatotkaca"]`.

### 5.2 `strings_en.json`

```json
{
  "app_name": "Pringgadani Fortress",
  "menu_new_expedition": "New Expedition",
  "menu_pusaka": "Pusaka Heirlooms",
  "menu_bestiary": "Bestiary",
  "menu_achievements": "Achievements",
  "run_build_phase": "Build Phase",
  "run_invasion_phase": "Invasion Phase",
  "run_wave": "Wave {n}",
  "run_boss_wave": "BOSS WAVE",
  "run_victory": "Victory!",
  "run_defeat": "Fortress Fallen",
  "build_place": "Place",
  "build_upgrade": "Upgrade",
  "build_destroy": "Destroy",
  "resource_gold": "Gold",
  "resource_food": "Food",
  "resource_wood": "Wood",
  "resource_stone": "Stone",
  "resource_iron": "Iron",
  "troop_infantry": "Infantry",
  "troop_archer": "Archers",
  "stat_attack": "Attack",
  "stat_defense": "Defense",
  "stat_health": "Health",
  "stat_lethality": "Lethality",
  "catalog_locked": "???",
  "offline_earnings": "While you were away...",
  "confirm": "Confirm",
  "cancel": "Cancel"
}
```

---

## 6. Autoloads (Singletons)

### 6.1 `SaveManager.gd`

- File: `user://pringgadani.save` (JSON)
- Saves on: run complete, equipment change, window close
- Data schema:
  ```json
  {
    "stage_number": 23,
    "gold": 4500,
    "heroes": {
      "gatotkaca": { "level": 5, "stars": 3, "xp": 1200 }
    },
    "stage_stars": { "22": 2, "23": 1 },
    "pusaka_collected": ["kotang_antrakusuma"],
    "achievements": ["first_victory", "wave_10"],
    "bestiary_kills": { "raksasa_kecil": 15, "kurawa_prajurit": 7 },
    "total_runs_completed": 20,
    "total_victories": 18,
    "last_login": 1712345678
  }
  ```
- Signals: `gold_changed`, `stage_number_changed`, `lives_changed`
- `func add_king_xp(amount: int) -> Dictionary`
- `func get_stage_stars(stage: int) -> int` / `func record_stage_stars(stage: int, stars: int) -> int`

> **Two different star fields.** `heroes.gatotkaca.stars` is the king's own rank and is
> stuck at 1; it scales his stats. `stage_stars[stage]` is how well a stage was cleared —
> 3 for every pendopo standing with the king above half health, 2 for every pendopo
> standing but the king at or below half, 1 if any pendopo fell. A defeat records
> nothing, and the rating only ever goes up, so replaying a stage can improve its node
> but never spoil one.

### 6.2 `SceneManager.gd`

- Deferred transitions, one-shot param dictionary
- `func go_to_scene(path: String, params: Dictionary = {})`
- `func get_param(key: String, default = null)`

### 6.3 `EconomyManager.gd`

- Tracks run resources: gold, food, wood, stone, iron
- Signals: `resource_changed(resource_type, new_value)`
- Production ticks in `_process(delta)`

### 6.4 `MusicManager.gd`

- Two tracks: `bgm_hub`, `bgm_invasion` with crossfade

### 6.5 `ClickPlayer.gd`

- One-shot AudioStreamPlayer for UI clicks

---

## 7. Scene Architecture

### 7.1 Hub Screen

```
MainMenu.tscn (Control)
├── Background (TextureRect)
├── Title Label — "Pringgadani Fortress"
├── Buttons: NEW EXPEDITION, HEROES, PUSAKA, BESTIARY, ACHIEVEMENTS, PURIFICATIONS
└── Stats Panel — run number, campaign title, gold, next unlock hint
```

### 7.2 Run Scene

```
RunController.tscn (Node3D)
├── WorldEnvironment
├── DirectionalLight3D
├── TerrainBuilder (builds the ground mesh from MapGenerator terrain)
├── BuildingPlot[] (Node3D + CollisionShape3D)
├── Buildings (Node3D)
├── KingController (Node3D)
├── InvasionManager (Node3D)
└── RunHUD (CanvasLayer)
    ├── TopBar — resource labels + wave counter
    ├── BuildPanel — building buttons + [READY]
    └── BuildingContextPanel — upgrade UI
```

### 7.3 Building Base Class

```gdscript
class_name Building extends Node3D

var building_id: String
var building_data: Dictionary
var level: int = 1
var plot: BuildingPlot

func _init(data: Dictionary, plot_ref: BuildingPlot) -> void:
    building_data = data
    building_id = data["id"]
    plot = plot_ref

func get_upgrade_cost() -> Dictionary:
    var base = building_data["base_cost"]
    var scaled = {}
    for resource in base:
        scaled[resource] = ProgressionData.building_cost(base[resource], level + 1)
    return scaled

func get_production() -> Dictionary:
    if building_data.get("production") == null: return {}
    var scaled = {}
    for resource in building_data["production"]:
        scaled[resource] = ProgressionData.building_production(
            building_data["production"][resource], level
        )
    return scaled
```

### 7.4 MapGenerator

```gdscript
class_name MapGenerator extends RefCounted

static func generate(run_number: int) -> Dictionary:
    var seed_value = run_number * 12345 + 67890
    seed(seed_value)

    var map_size = ProgressionData.map_size(run_number)
    var num_plots = ProgressionData.building_plots(run_number)
    var center = Vector2i(map_size / 2, map_size / 2)
    var plots = [center]

    var directions = [
        Vector2i(0, -3), Vector2i(3, -3), Vector2i(3, 0), Vector2i(3, 3),
        Vector2i(0, 3), Vector2i(-3, 3), Vector2i(-3, 0), Vector2i(-3, -3),
        Vector2i(6, 0), Vector2i(0, 6), Vector2i(-6, 0), Vector2i(0, -6),
        Vector2i(6, 3), Vector2i(6, -3), Vector2i(-6, 3), Vector2i(-6, -3),
        Vector2i(3, 6), Vector2i(-3, 6), Vector2i(3, -6), Vector2i(-3, -6),
    ]
    directions.shuffle()
    for i in range(min(num_plots - 1, directions.size())):
        plots.append(center + directions[i])

    return {
        "terrain": _generate_terrain(map_size),
        "plots": plots,
        "spawn_zones": _generate_spawn_zones(map_size),
        "obstacles": _place_obstacles(terrain, plots, map_size),
        "map_size": map_size,
    }
```

### 7.5 CombatEngine

```gdscript
class_name CombatEngine extends RefCounted

static func resolve(
    player_troops: Dictionary,
    enemies: Array,
    formation: Dictionary
) -> Dictionary:
    var total_player_damage = 0.0
    var total_enemy_damage = 0.0
    var player_casualties = { "infantry": 0, "archer": 0 }
    var enemies_alive = 0

    for troop_type in formation:
        var troop = player_troops[troop_type]
        if troop["count"] <= 0: continue
        for enemy in enemies:
            var counter = _check_counter(troop_type, enemy.type)
            var dmg = ProgressionData.calculate_damage(
                troop.attack, troop.lethality, enemy.defense, counter, troop.count
            )
            total_player_damage += dmg
            enemy.health -= dmg
            var enemy_dmg = max(1, enemy.attack * 50 / max(troop.defense, 1))
            total_enemy_damage += enemy_dmg
            player_casualties[troop_type] += floori(enemy_dmg / (troop.health * 10))

    for enemy in enemies:
        if enemy.health > 0: enemies_alive += 1

    return {
        "player_damage_dealt": floori(total_player_damage),
        "enemy_damage_dealt": floori(total_enemy_damage),
        "player_casualties": player_casualties,
        "enemy_casualties": enemies.size() - enemies_alive,
        "enemies_remaining": enemies_alive,
        "victory": enemies_alive == 0,
    }

static func _check_counter(attacker: String, defender: String) -> bool:
    return false
```

---

## 8. Phase 0: Project Scaffold (First Task)

When ready, run:

```
"Implement PringgadaniFortress Phase 0: Project scaffold

Create:
1. project.godot with: name='PringgadaniFortress', 1280x720, canvas_items stretch,
   main scene = scenes/hub/MainMenu.tscn
2. export_presets.cfg (Linux/X11 desktop)
3. AGENTS.md
4. Autoload stubs: SaveManager.gd, SceneManager.gd, EconomyManager.gd, MusicManager.gd, ClickPlayer.gd
5. Directory structure with all subdirs
6. resources/strings_en.json, resources/strings_id.json
7. All scene .tscn files with root node + script attached (hub/, run/, combat/ stubs)
8. Script stubs: scripts/ProgressionData.gd, BuildingData.gd, CombatEngine.gd

File paths: /home/think13/Projects/GAMES/GODOT/PringgadaniFortress/"
```

---

## 9. Full Build Order

| # | Phase | Deliverables | Est. |
|---|-------|-------------|------|
| 0 | **Project scaffold** | project.godot, autoload stubs, dirs, data files, scene stubs | 1x |
| 1 | **Data layer** | Full ProgressionData, BuildingData, CombatEngine, JSON files | 1x |
| 2 | **Hub** | MainMenu, LevelTrack, ProfilePage, Blacksmith, Market, CatalogOverlay | 1-2x |
| 3 | **Map generator** | MapGenerator.gd with terrain gen, plot placement, spawn zones | 1-2x |
| 4 | **Building system** | Building, Pendopo, ResourceNode, military buildings, BuildingPlot, BuildingUI | 2x |
| 5 | **Economy + offline** | EconomyManager with production ticks, offline earnings, RunHUD resources | 1x |
| 6 | **Run controller** | RunController, build/invasion phases, wave spawn, victory/defeat | 2x |
| 7 | **Combat resolution** | BattleResolution, WaveReport, InvasionManager | 1x |
| 8 | **Save system** | Full SaveManager JSON, serialization, offline calc | 1x |
| 9 | **Polish** | VFX, BGM, SFX, button builder, menu transitions | 1-2x |

---

## 10. RondaPatrol Patterns to Reuse

| Pattern | Where to Apply |
|---------|---------------|
| Programmatic node construction | All gameplay objects in `_init()` / `_ready()` |
| Static data classes (RefCounted) | ProgressionData, BuildingData, CombatEngine |
| Signal-driven economy | EconomyManager.resource_changed → HUD updates |
| JSON data files | buildings.json loaded in data classes |
| SaveManager | Single JSON file, auto-save on close, offline tracking |
| SceneManager | Deferred transitions with one-shot params |
| ButtonBuilder | Bitmap font buttons |
| MusicManager | Two-track BGM with crossfade |
| ClickPlayer | One-shot UI click SFX |
| Popup overlay pattern | Create/destroy overlay Panel dynamically |
