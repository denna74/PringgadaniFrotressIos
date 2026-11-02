extends Control


var _catalog_type: String = ""
var _catalog_title: String = ""
var _items: Array[Dictionary] = []


func setup(type: String, title: String) -> void:
    _catalog_type = type
    _catalog_title = title
    _load_items()
    if is_inside_tree():
        _build_ui()


func _ready() -> void:
    _setup_background()
    if _catalog_type != "":
        _build_ui()


func _setup_background() -> void:
    var bg := ColorRect.new()
    bg.color = Color(0.05, 0.02, 0.01, 0.9)
    bg.anchors_preset = Control.PRESET_FULL_RECT
    add_child(bg)


func _build_ui() -> void:
    for child in get_children():
        if child != get_child(0):
            child.queue_free()
    await get_tree().process_frame

    var top := HBoxContainer.new()
    top.position = Vector2(10, 10)
    top.size = Vector2(1260, 40)
    add_child(top)

    var back := ButtonBuilder.create_back_button()
    back.pressed.connect(_on_back)
    top.add_child(back)

    var spacer := Control.new()
    spacer.custom_minimum_size = Vector2(20, 0)
    top.add_child(spacer)

    top.add_child(ButtonBuilder.create_title_label(_catalog_title, 24))

    if _items.is_empty():
        var empty := ButtonBuilder.create_body_label("Nothing collected yet.", 16)
        empty.position = Vector2(0, 300)
        empty.size = Vector2(1280, 30)
        add_child(empty)
        return

    var grid := GridContainer.new()
    grid.columns = 5
    grid.position = Vector2(40, 60)
    grid.size = Vector2(1200, 640)
    grid.add_theme_constant_override("h_separation", 16)
    grid.add_theme_constant_override("v_separation", 12)
    add_child(grid)

    for item in _items:
        grid.add_child(_build_item_card(item))


func _load_items() -> void:
    match _catalog_type:
        "pusaka":
            _load_pusaka()
        "bestiary":
            _load_bestiary()
        "achievements":
            _load_achievements()


func _load_pusaka() -> void:
    var all_pusaka: Array[Dictionary] = [
        {"id": "kotang_antrakusuma", "name": "Kotang Antrakusuma", "desc": "Gatotkaca's invulnerable vest."},
        {"id": "gandewa", "name": "Gandewa", "desc": "Arjuna's divine bow."},
        {"id": "cundamanik", "name": "Cundamanik", "desc": "Wisanggeni's fiery heirloom."},
        {"id": "gada_rujakpolo", "name": "Gada Rujakpolo", "desc": "Bima's mighty mace."},
        {"id": "kalimasada", "name": "Jimat Kalimasada", "desc": "The Pandawa's sacred talisman."},
    ]
    for p in all_pusaka:
        p["collected"] = p["id"] in SaveManager.pusaka_collected
        _items.append(p)


func _load_bestiary() -> void:
    var all_enemies: Array[Dictionary] = [
        {"id": "raksasa_kecil", "name": "Raksasa Kecil", "desc": "A small, brutish giant."},
        {"id": "kurawa_prajurit", "name": "Kurawa Prajurit", "desc": "A soldier of the Kurawa army."},
        {"id": "kurawa_pemanah", "name": "Kurawa Pemanah", "desc": "Kurawa archer unit."},
        {"id": "raksasa_besar", "name": "Raksasa Besar", "desc": "A massive, powerful giant."},
        {"id": "senapati", "name": "Senapati", "desc": "A Kurawa general."},
    ]
    for e in all_enemies:
        e["collected"] = SaveManager.bestiary_kills.has(e["id"]) and SaveManager.bestiary_kills[e["id"]] > 0
        var kills: int = SaveManager.bestiary_kills.get(e["id"], 0)
        e["desc"] = "%s (Defeated: %d)" % [e["desc"], kills]
        _items.append(e)


func _load_achievements() -> void:
    var all_achieve: Array[Dictionary] = [
        {"id": "first_victory", "name": "First Victory", "desc": "Win your first expedition."},
        {"id": "wave_10", "name": "Wave Breaker", "desc": "Survive 10 waves in a single run."},
        {"id": "pusaka_2", "name": "Heirloom Seeker", "desc": "Collect 2 pusaka items."},
        {"id": "run_50", "name": "Centurion", "desc": "Reach Run 50."},
    ]
    for a in all_achieve:
        a["collected"] = a["id"] in SaveManager.achievements
        _items.append(a)


func _build_item_card(item: Dictionary) -> Panel:
    var panel := ButtonBuilder.create_panel(210, 140)
    panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

    var vbox := VBoxContainer.new()
    vbox.position = Vector2(6, 6)
    vbox.size = Vector2(198, 128)
    vbox.add_theme_constant_override("separation", 4)
    panel.add_child(vbox)

    var icon := ColorRect.new()
    icon.custom_minimum_size = Vector2(60, 60)
    icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    if item.get("collected", false):
        icon.color = Color(0.3, 0.18, 0.06, 0.8)
    else:
        icon.color = Color(0.08, 0.04, 0.02, 0.8)
    vbox.add_child(icon)

    var name_str: String = item.get("name", "???")
    if not item.get("collected", false):
        name_str = "??? (Locked)"
    vbox.add_child(ButtonBuilder.create_stat_label(name_str, 14))
    vbox.add_child(ButtonBuilder.create_body_label(item.get("desc", ""), 11))

    return panel


func _on_back() -> void:
    queue_free()
