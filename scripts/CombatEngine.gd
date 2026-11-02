class_name CombatEngine extends RefCounted

static func resolve(
    player_troops: Dictionary,
    enemies: Array,
    defense_buildings: Array
) -> Dictionary:
    var total_player_damage := 0.0
    var total_enemy_damage := 0.0
    var player_casualties := {"infantry": 0, "archers": 0}
    var enemies_alive := 0

    for troop_type in player_troops:
        var troop: Dictionary = player_troops[troop_type]
        if troop.get("count", 0) <= 0:
            continue
        for enemy in enemies:
            var counter := _check_counter(troop_type, enemy.get("type", ""))
            var dmg := _calculate_troop_damage(
                troop, enemy, counter, troop["count"]
            )
            total_player_damage += dmg

    for db in defense_buildings:
        if db.has_method("get_defense_value"):
            var db_dmg: float = db.get_defense_value() * 0.1
            total_player_damage += db_dmg

    for enemy in enemies:
        var enemy_hp: float = enemy.get("health", 0)
        enemy_hp -= total_player_damage / max(enemies.size(), 1)
        enemy["health"] = enemy_hp
        var enemy_atk: float = enemy.get("attack", 0)
        total_enemy_damage += enemy_atk * 0.5

    for troop_type in player_troops:
        var troop: Dictionary = player_troops[troop_type]
        if troop.get("count", 0) <= 0:
            continue
        var troop_hp: float = maxf(troop.get("health", 50), 1.0)
        var casualties := floori(total_enemy_damage / (troop_hp * 10))
        player_casualties[troop_type] = mini(casualties, troop["count"])

    for enemy in enemies:
        if enemy.get("health", 0) > 0:
            enemies_alive += 1

    return {
        "player_damage_dealt": floori(total_player_damage),
        "enemy_damage_dealt": floori(total_enemy_damage),
        "player_casualties": player_casualties,
        "enemy_casualties": enemies.size() - enemies_alive,
        "enemies_remaining": enemies_alive,
        "victory": enemies_alive == 0,
    }


static func resolve_king_combat(
    king_stats: Dictionary,
    boss_stats: Dictionary
) -> Dictionary:
    var king_hp: float = king_stats.get("hp", 300)
    var king_atk: float = king_stats.get("attack", 25)
    var boss_hp: float = boss_stats.get("health", 500)
    var boss_atk: float = boss_stats.get("attack", 30)

    var rounds := 0
    while king_hp > 0 and boss_hp > 0 and rounds < 100:
        boss_hp -= king_atk
        if boss_hp > 0:
            king_hp -= boss_atk
        rounds += 1

    return {
        "victory": boss_hp <= 0,
        "king_hp_remaining": maxi(0, floori(king_hp)),
        "boss_hp_remaining": maxi(0, floori(boss_hp)),
        "rounds": rounds,
    }


static func _calculate_troop_damage(
    troop: Dictionary, enemy: Dictionary,
    counter: bool, num_troops: int
) -> float:
    var atk: float = troop.get("attack", 20)
    var leth: float = troop.get("lethality", 10)
    var enemy_def: float = enemy.get("defense", 5)
    var base_dmg: float = atk * leth / max(enemy_def, 1.0)
    var counter_bonus := 1.25 if counter else 0.75
    return base_dmg * counter_bonus * num_troops * 0.01


static func _check_counter(attacker: String, defender: String) -> bool:
    return false
