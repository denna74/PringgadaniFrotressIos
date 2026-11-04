extends SceneTree

var _fails: int = 0


func _initialize() -> void:
	_run()


func _check(name: String, ok: bool) -> void:
	if ok:
		print("OK  ", name)
	else:
		_fails += 1
		push_error("FAIL " + name)


func _run() -> void:
	await process_frame
	var save = root.get_node("/root/SaveManager")
	save.gold = 100000
	save.building_upgrade_levels = {
		"pendopo": 1, "menara": 1, "barak": 1, "tambang_emas": 1
	}
	var page: Control = load("res://scenes/hub/ArchitecturePage.gd").new()
	root.add_child(page)
	page.size = Vector2(840, 580)
	await process_frame
	await process_frame

	var tracks: Dictionary = page.get("_tracks")
	_check("first page shows two building upgrade tracks", tracks.size() == 2)
	_check("first page has two building cards",
		page.get_node("BuildingList").get_child_count() == 2)
	_check("first page indicator is correct",
		(page.get_node("Pagination/ArchitecturePageLabel") as Label).text == "1 / 2")
	_check("previous button is disabled on first page",
		(page.get_node("Pagination/ArchitecturePrev") as Button).disabled)
	_check("architecture pagination buttons are larger",
		(page.get_node("Pagination/ArchitecturePrev") as Button).size == Vector2(140, 46))
	_check("next button is enabled on first page",
		not (page.get_node("Pagination/ArchitectureNext") as Button).disabled)
	for id: String in BuildingUpgradeData.IDS:
		_check("%s icon file exists" % id,
			ResourceLoader.exists(BuildingUpgradeData.ICON_PATHS[id]))
	_check("first page upgrade control shown", page.get("_upgrade_buttons").has("pendopo"))
	var tower_card := page.find_child("Card_menara", true, false)
	var tower_details := tower_card.find_child("DetailsLabel", true, false) as Label
	_check("tower range is displayed",
		tower_details != null and tower_details.text.contains("10"))
	_check("additional tower information is green",
		tower_details != null
			and tower_details.get_theme_color("font_color").is_equal_approx(Color.CHARTREUSE))
	var tower_effect := tower_card.find_child("EffectLabel", true, false) as Label
	_check("tower attack values are displayed",
		tower_effect != null and tower_effect.text.contains("25")
			and not tower_effect.text.contains("30"))

	page._on_next_page()
	await process_frame
	var second_page_tracks: Dictionary = page.get("_tracks")
	_check("second page shows remaining two buildings", second_page_tracks.size() == 2)
	_check("second page starts with barracks",
		page.get_node("BuildingList").get_child(0).name == "Card_barak")
	_check("second page ends with gold mine",
		page.get_node("BuildingList").get_child(1).name == "Card_tambang_emas")
	_check("second page indicator is correct",
		(page.get_node("Pagination/ArchitecturePageLabel") as Label).text == "2 / 2")
	_check("next button is disabled on last page",
		(page.get_node("Pagination/ArchitectureNext") as Button).disabled)
	_check("second page upgrade control shown",
		page.get("_upgrade_buttons").has("tambang_emas"))
	var barracks_details := page.find_child("Card_barak", true, false).find_child(
		"DetailsLabel", true, false
	) as Label
	_check("barracks displays infantry HP ATK DEF",
		barracks_details != null and barracks_details.text.contains("HP 400  ATK 40  DEF 10"))
	_check("barracks displays archer HP ATK DEF",
		barracks_details != null and barracks_details.text.contains("HP 300  ATK 45  DEF 5"))

	page._on_prev_page()
	await process_frame
	_check("previous button returns to first page",
		(page.get_node("Pagination/ArchitecturePageLabel") as Label).text == "1 / 2")

	var level_before: int = save.get_building_upgrade_level("pendopo")
	page._show_upgrade_confirm("pendopo")
	await process_frame
	var overlay := page.get_window().get_node_or_null("BuildingUpgradeConfirmOverlay")
	if overlay != null:
		var overlay_control := overlay as Control
		var panel := overlay_control.get_child(0) as Control
		_check("upgrade confirmation is centered",
			(panel.position + panel.size / 2.0).is_equal_approx(overlay_control.size / 2.0))
		var next_status := panel.find_child("NextLevelStatus", true, false) as Label
		_check("upgrade confirmation shows only the next level status",
			next_status != null and next_status.text.contains("1500")
				and not next_status.text.contains("1000"))
		var ok_btn := panel.get_child(panel.get_child_count() - 1) as Button
		if ok_btn != null:
			ok_btn.pressed.emit()
	await process_frame
	await process_frame
	_check("confirm advances building progression",
		save.get_building_upgrade_level("pendopo") == level_before + 1)
	_check("confirm popup is removed", page.get_window().get_node_or_null(
		"BuildingUpgradeConfirmOverlay") == null)

	page.queue_free()
	await process_frame
	if _fails == 0:
		print("ARCHITECTURE_PAGE_PASS")
		quit(0)
	else:
		print("ARCHITECTURE_PAGE_FAIL: %d" % _fails)
		quit(1)
