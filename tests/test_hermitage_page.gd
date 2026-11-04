extends SceneTree

var _fails: int = 0


func _initialize() -> void:
	_run()


func _check(name: String, ok: bool) -> void:
	if ok:
		print("OK  ", name)
	else:
		_fails += 1
		print("CHECK FAIL: " + name)


func _run() -> void:
	await process_frame
	var sm = root.get_node("/root/SaveManager")
	sm.gold = 100000
	sm.skill_levels = {"dash": 1, "earthquake": 1, "berserk": 1}

	var page: Control = load("res://scenes/hub/HermitagePage.gd").new()
	root.add_child(page)
	page.size = Vector2(840, 580)
	await process_frame
	await process_frame

	var tracks: Dictionary = page.get("_tracks")
	_check("three skill tracks", tracks.size() == 3)
	for id: String in ["dash", "earthquake", "berserk"]:
		var track = tracks.get(id)
		_check("track %s has 6 icons" % id, track != null and track.get_child_count() == 6)

	# Level 1: first icon lit, the rest dim.
	var dash_track: HBoxContainer = tracks["dash"]
	_check("icon 0 lit", (dash_track.get_child(0) as TextureRect).modulate.a > 0.9)
	_check("icon 1 dim", (dash_track.get_child(1) as TextureRect).modulate.a < 0.5)

	# The highest owned level is marked, but the art keeps its own colours: a tint would
	# multiply the blue dash art and turn it green.
	var top_slot: TextureRect = dash_track.get_child(0)
	_check("owned icon not hue-tinted", top_slot.self_modulate == Color.WHITE)
	_check("highest owned level marked", top_slot.get_child_count() == 1)
	_check("unowned level not marked", (dash_track.get_child(1) as TextureRect).get_child_count() == 0)

	# The art is much larger than the slots it is drawn into. A TextureRect keeps its
	# texture's size as its minimum unless it ignores the texture size, which would
	# stretch every row past the page and push it off screen.
	var col: VBoxContainer = dash_track.get_parent()
	var row_hbox: HBoxContainer = col.get_parent()
	var row_icon: TextureRect = row_hbox.get_child(0)
	_check("row icon ignores texture size", row_icon.get_combined_minimum_size().x <= 100)
	_check("track icon ignores texture size", dash_track.get_combined_minimum_size().x <= 6 * 40 + 40)

	_check("upgrade button present", page.get("_upgrade_buttons").get("dash") != null)

	# Poor: the button is disabled.
	sm.gold = 0
	page._on_state_changed(0)
	await process_frame
	_check("button disabled when poor", (page.get("_upgrade_buttons")["dash"] as Button).disabled)

	# Rich: pressing upgrades and the track grows.
	sm.gold = 100000
	page._on_state_changed(0)
	await process_frame
	var before: int = sm.get_skill_level("dash")
	var cost: int = SkillData.upgrade_cost("dash", before)
	(page.get("_upgrade_buttons")["dash"] as Button).pressed.emit()
	await process_frame
	await process_frame
	var w := page.get_window()
	if w == null:
		w = root
	var ov := w.get_node_or_null("UpgradeConfirmOverlay")
	if ov != null and is_instance_valid(ov):
		var overlay_control := ov as Control
		var panel := overlay_control.get_child(0) as Control
		_check("upgrade confirmation is centered",
			(panel.position + panel.size / 2.0).is_equal_approx(overlay_control.size / 2.0))
		if panel != null:
			for ch in panel.get_children():
				if ch is Button and ch.text.find("OK") >= 0:
					ch.pressed.emit()
					break
	await process_frame
	await process_frame
	_check("level incremented", sm.get_skill_level("dash") == before + 1)
	_check("gold deducted", sm.gold == 100000 - cost)
	var grown: HBoxContainer = page.get("_tracks")["dash"]
	_check("icon 1 lit after upgrade", (grown.get_child(1) as TextureRect).modulate.a > 0.9)

	# At max: no upgrade button.
	sm.skill_levels["dash"] = SkillData.MAX_LEVEL
	page._on_skill_changed("dash", SkillData.MAX_LEVEL)
	await process_frame
	_check("no button at max", page.get("_upgrade_buttons").get("dash") == null)

	page.queue_free()
	await process_frame

	if _fails == 0:
		print("HERMITAGE_PAGE_PASS")
		quit(0)
	else:
		print("HERMITAGE_PAGE_FAIL: %d" % _fails)
		quit(1)
