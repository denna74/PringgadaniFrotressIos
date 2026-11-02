extends SceneTree

## Tiered skill names and icons: lv1-3 use the tier-1 name/art, lv4-6 use the
## tier-2 name/art, and the displayed level restarts at 1 for the second tier.
## The HUD's fixed button geometry must not move when a tier-2 art is shown.

const SKILL_BUTTON_SIZE: float = 110.0
const EARTHQUAKE_BUTTON_POS: Vector2 = Vector2(906, 458)
const BERSERK_BUTTON_POS: Vector2 = Vector2(1016, 360)
const DASH_BUTTON_POS: Vector2 = Vector2(906, 594)

var _fails: int = 0


func _initialize() -> void:
	_run()


func _check(name: String, ok: bool) -> void:
	if ok:
		print("OK  ", name)
	else:
		_fails += 1
		print("CHECK FAIL: " + name)


func _tex_path(tex: TextureRect) -> String:
	if tex == null or tex.texture == null:
		return ""
	return tex.texture.resource_path


func _run() -> void:
	await process_frame
	await _check_hermitage()
	await _check_hud()
	await _check_strings()

	if _fails == 0:
		print("SKILL_TIER_UI_PASS")
		quit(0)
	else:
		print("SKILL_TIER_UI_FAIL: %d" % _fails)
		quit(1)


func _check_hermitage() -> void:
	root.get_node("/root/TranslationManager").set_language("en")
	var sm = root.get_node("/root/SaveManager")
	sm.gold = 100000
	sm.skill_levels = {"dash": 4, "earthquake": 2, "berserk": 6}

	var page: Control = load("res://scenes/hub/HermitagePage.gd").new()
	root.add_child(page)
	page.size = Vector2(840, 580)
	await process_frame
	await process_frame

	var tracks: Dictionary = page.get("_tracks")

	# Row label: tier-2 name with the level restarting at 1 for lv4.
	var dash_track: HBoxContainer = tracks["dash"]
	var col: VBoxContainer = dash_track.get_parent()
	var name_lbl: Label = col.get_child(0)
	_check("dash lv4 label", name_lbl.text == "Bayu Bajra   Lv 1")

	# lv2 keeps the tier-1 name.
	var quake_track: HBoxContainer = tracks["earthquake"]
	var quake_col: VBoxContainer = quake_track.get_parent()
	_check("quake lv2 label", (quake_col.get_child(0) as Label).text == "Rengkah Bumi   Lv 2")

	# lv6 is the third step of the second tier.
	var berserk_track: HBoxContainer = tracks["berserk"]
	var berserk_col: VBoxContainer = berserk_track.get_parent()
	_check("berserk lv6 label", (berserk_col.get_child(0) as Label).text == "Kudalikombang   Lv 3")

	# Row icon follows the current level's tier art.
	var row_hbox: HBoxContainer = col.get_parent()
	_check("dash row icon tier2", _tex_path(row_hbox.get_child(0) as TextureRect)
		.ends_with("dash_2.png"))

	# Track slots 1-3 keep tier-1 art, slots 4-6 show tier-2 art.
	_check("dash track slot 1 tier1", _tex_path(dash_track.get_child(0) as TextureRect)
		.ends_with("dash.png"))
	_check("dash track slot 3 tier1", _tex_path(dash_track.get_child(2) as TextureRect)
		.ends_with("dash.png"))
	_check("dash track slot 4 tier2", _tex_path(dash_track.get_child(3) as TextureRect)
		.ends_with("dash_2.png"))
	_check("dash track slot 6 tier2", _tex_path(dash_track.get_child(5) as TextureRect)
		.ends_with("dash_2.png"))
	_check("quake track slot 5 tier2", _tex_path(quake_track.get_child(4) as TextureRect)
		.ends_with("earthquake_2.png"))
	_check("berserk track slot 1 tier1", _tex_path(berserk_track.get_child(0) as TextureRect)
		.ends_with("berserk.png"))

	page.queue_free()
	await process_frame


func _check_hud() -> void:
	var sm = root.get_node("/root/SaveManager")
	sm.skill_levels = {"dash": 6, "earthquake": 4, "berserk": 1}

	var hud := CanvasLayer.new()
	hud.set_script(load("res://scenes/run/RunHUD.gd"))
	root.add_child(hud)
	await process_frame

	var dash_tex: TextureRect = hud.get("_dash_tex")
	var skill_tex: TextureRect = hud.get("_skill_tex")
	var berserk_tex: TextureRect = hud.get("_berserk_tex")
	var dash_btn: Control = hud.get("_dash_btn")
	var skill_btn: Control = hud.get("_skill_btn")
	var berserk_btn: Control = hud.get("_berserk_btn")

	_check("hud dash lv6 tier2", _tex_path(dash_tex).ends_with("dash_2.png"))
	_check("hud quake lv4 tier2", _tex_path(skill_tex).ends_with("earthquake_2.png"))
	_check("hud berserk lv1 tier1", _tex_path(berserk_tex).ends_with("berserk.png"))

	# Tier-2 art must not disturb the fixed HUD geometry: the texture rects keep
	# their explicit size and ignore the texture's own size, and the buttons stay
	# at their designed positions.
	var size := Vector2(SKILL_BUTTON_SIZE, SKILL_BUTTON_SIZE)
	_check("dash tex keeps size", dash_tex.size == size)
	_check("quake tex keeps size", skill_tex.size == size)
	_check("berserk tex keeps size", berserk_tex.size == size)
	_check("dash tex ignores texture size",
		dash_tex.expand_mode == TextureRect.EXPAND_IGNORE_SIZE)
	_check("quake tex ignores texture size",
		skill_tex.expand_mode == TextureRect.EXPAND_IGNORE_SIZE)
	_check("berserk tex ignores texture size",
		berserk_tex.expand_mode == TextureRect.EXPAND_IGNORE_SIZE)
	_check("dash button stays put", dash_btn.position == DASH_BUTTON_POS and dash_btn.size == size)
	_check("quake button stays put",
		skill_btn.position == EARTHQUAKE_BUTTON_POS and skill_btn.size == size)
	_check("berserk button stays put",
		berserk_btn.position == BERSERK_BUTTON_POS and berserk_btn.size == size)

	hud.queue_free()
	await process_frame


func _check_strings() -> void:
	var tm = root.get_node("/root/TranslationManager")
	_check("en dash t1", tm.t("skill_dash_t1") == "Kilat Tatit")
	_check("en dash t2", tm.t("skill_dash_t2") == "Bayu Bajra")
	_check("en quake t1", tm.t("skill_earthquake_t1") == "Rengkah Bumi")
	_check("en quake t2", tm.t("skill_earthquake_t2") == "Narantaka")
	_check("en berserk t1", tm.t("skill_berserk_t1") == "Kateguhaning")
	_check("en berserk t2", tm.t("skill_berserk_t2") == "Kudalikombang")
