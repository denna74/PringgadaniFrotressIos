# PringgadaniFortress — Agent Instructions

## Project Conventions

- **Language:** GDScript with typed variables where possible
- **Resolution:** 1280x720, `canvas_items` stretch
- **Pattern:** Programmatic node construction (`.tscn` files are script-attach points only)
- **Static data classes:** `extends RefCounted` with `class_name`
- **Signals:** Use signals for reactive UI updates (economy, state changes)
- **JSON data:** Building definitions in `resources/*.json`
- **Autoloads:** SaveManager, SceneManager, EconomyManager, MusicManager, ClickPlayer

## Scene Types

| Suffix | Type | When to use |
|--------|------|-------------|
| Control | UI panels, menus, HUD | All UI elements |
| Node2D | Gameplay objects, run controller | Map, buildings, run lifecycle |
| Area2D | Interactive zones | Building plots, spawn zones |
| RefCounted | Data-only classes | Formulas, combat engine, database lookups |

## Node Naming

- Nodes: PascalCase (e.g., `BuildingPanel`, `TopBar`)
- Scripts: snake_case.gd (e.g., `save_manager.gd`)
- Scenes: PascalCase.tscn (e.g., `MainMenu.tscn`)
- IDs: snake_case (e.g., `building_id`, `item_id`)

## Resource Paths

- All resource paths use `res://` prefix
- Sprites in `res://assets/sprites/<category>/`
- Data in `res://resources/*.json`
