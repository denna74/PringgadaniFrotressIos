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


func _stat_label(page: Node, stat: String) -> RichTextLabel:
	return page.find_child("Stat_" + stat, true, false) as RichTextLabel


func _stat_text(page: Node, stat: String) -> String:
	var label := _stat_label(page, stat)
	return label.get_parsed_text() if label != null else "<missing>"


func _stat_bbcode(page: Node, stat: String) -> String:
	var label := _stat_label(page, stat)
	return label.text if label != null else ""


func _run() -> void:
	await process_frame

	var sm = root.get_node("/root/SaveManager")
	var tm = root.get_node("/root/TranslationManager")
	sm.heroes = {"gatotkaca": {"level": 1, "stars": 1, "xp": 0}}
	sm.inventory = [
		{"id": "sumping_gajah_ngulun", "quantity": 1},
		{"id": "garuda_mungkur", "quantity": 1},
		{"id": "cincin_setyaningampal", "quantity": 1},
		{"id": "cincin_mangkurawan", "quantity": 1},
		{"id": "sabuk_cinde_puspita", "quantity": 1},
	]
	sm.equipment = {"head": "", "body": "", "right_hand": "", "left_hand": ""}
	sm.equip_item("head", "sumping_gajah_ngulun")
	sm.equip_item("right_hand", "cincin_setyaningampal")
	sm.equip_item("left_hand", "cincin_mangkurawan")
	sm.equip_item("body", "sabuk_cinde_puspita")

	var page: Control = load("res://scenes/hub/ProfilePage.gd").new()
	page.set("title_background_rect", Rect2(150.0, 4.0, 200.0, 96.0))
	page.size = Vector2(532, 610)
	root.add_child(page)
	await process_frame
	await process_frame

	var title_background: TextureRect = (
		page.find_child("TitleBackground", true, false) as TextureRect
	)
	var title_banner := title_background.get_parent() as Control if title_background != null else null
	var title_subtitle: Label = (
		page.find_child("ProfileTitleSubtitle", true, false) as Label
	)
	var profile_title: Label = page.find_child("ProfileTitle", true, false) as Label
	var level_indicator_background: TextureRect = (
		page.find_child("LevelIndicatorBackground", true, false) as TextureRect
	)
	var level_indicator: Label = page.find_child("LevelIndicator", true, false) as Label
	var status_panel: Control = page.find_child("StatusPanel", true, false) as Control
	_check(
		"profile level indicator uses level artwork",
		level_indicator_background != null
			and level_indicator_background.texture != null
			and level_indicator_background.texture.resource_path
				== "res://assets/sprites/backgrounds/level.png"
	)
	_check(
		"profile level indicator artwork is sized to fit",
		level_indicator_background != null
			and level_indicator_background.size == Vector2(115, 87)
	)
	_check(
		"profile level indicator shows the current level",
		level_indicator != null and level_indicator.text == "Lv.1"
	)
	_check(
		"profile level indicator is left of the title",
		level_indicator != null
			and profile_title != null
			and level_indicator.global_position.x < profile_title.global_position.x
	)
	_check(
		"profile title background uses the supplied artwork",
		title_background != null
			and title_background.texture != null
			and title_background.texture.resource_path == "res://assets/sprites/backgrounds/title.png"
			and title_background.stretch_mode == TextureRect.STRETCH_SCALE
			and title_background.position == Vector2(150, 4)
			and title_background.size == Vector2(200, 96)
			and title_banner != null
			and title_banner.custom_minimum_size.y == 80.0
	)
	_check(
		"profile title subtitle is translated",
		title_subtitle != null and title_subtitle.text == tm.t("main_title_subtitle")
	)
	_check(
		"profile title is lowered and black",
		profile_title != null
			and profile_title.position.y == 22.0
			and profile_title.get_theme_color("font_color") == Color.BLACK
	)
	var original_language: String = tm.current_language
	tm.set_language("id" if original_language == "en" else "en")
	_check(
		"profile title updates when language changes",
		title_subtitle != null and title_subtitle.text == tm.t("main_title_subtitle")
	)
	tm.set_language(original_language)
	_check(
		"profile status panel remains on screen",
		status_panel != null
			and status_panel.global_position.y + status_panel.size.y
			<= page.global_position.y + page.size.y
	)

	for slot: String in ["head", "body", "right_hand", "left_hand"]:
		_check("slot %s exists" % slot, page.find_child("Slot_" + slot, true, false) != null)
	_check("old accessory slot is gone", page.find_child("Slot_accessory", true, false) == null)

	for slot: String in ["head", "body", "right_hand", "left_hand"]:
		var panel: Node = page.find_child("Slot_" + slot, true, false)
		var name_label: Label = panel.find_child("ItemName", true, false) if panel != null else null
		_check(
			"slot %s hides the equipped item name" % slot,
			name_label != null and not name_label.visible
		)

	_check("ATK shows stage-based base plus bonus", _stat_text(page, "ATK") == "100+20")
	_check("DEF shows stage-based base plus bonus", _stat_text(page, "DEF") == "20+15")
	_check("HP shows stage-based base plus bonus", _stat_text(page, "HP") == "600+160")
	_check("MP shows base plus bonus", _stat_text(page, "MP") == "210+40")
	_check("STA shows base plus bonus", _stat_text(page, "STA") == "104+12")
	var green_hex: String = page.POSITIVE_STAT_COLOR.to_html(false)
	_check("positive bonuses are green", _stat_bbcode(page, "HP").contains("[color=#%s]" % green_hex))

	page._show_equip_picker("head", tm.t("profile_head"))
	await process_frame
	var picker: Node = page.find_child("EquipPicker", true, false)
	_check("picker opens", picker != null)
	var picker_panel: Control = page.find_child("EquipPickerPanel", true, false) as Control
	_check("picker fits the content panel", picker_panel != null and picker_panel.size == Vector2(420, 560))

	_check("picker lists equipped item", page.find_child("Choice_sumping_gajah_ngulun", true, false) != null)
	var equipped_choice := page.find_child("Choice_sumping_gajah_ngulun", true, false) as Button
	var equipped_label := equipped_choice.find_child("EquippedLabel", true, false) as Label
	var effect_label := equipped_choice.find_child("ItemEffects", true, false) as Label
	var item_name_label := equipped_choice.find_child("ItemName", true, false) as Label
	var item_icon := equipped_choice.find_child("ItemIcon", true, false) as TextureRect
	_check("equipped status in picker is green",
		equipped_label != null
			and equipped_label.get_theme_color("font_color").is_equal_approx(
				page.POSITIVE_STAT_COLOR
			))
	_check("equipment effects appear below the item name",
		effect_label != null and item_name_label != null
			and effect_label.global_position.y > item_name_label.global_position.y)
	_check("equipment image is shown left of name and effects",
		item_icon != null and item_icon.texture != null
			and item_icon.global_position.x < item_name_label.global_position.x
			and item_icon.global_position.x < effect_label.global_position.x)
	_check("equipment picker has no scroll container",
		page.find_child("ScrollContainer", true, false) == null)
	var garuda_choice: Button = page.find_child("Choice_garuda_mungkur", true, false) as Button
	_check("picker lists other owned head items", garuda_choice != null)
	_check("picker hides unowned items", page.find_child("Choice_kuluk_kanigara", true, false) == null)
	if garuda_choice != null:
		garuda_choice.pressed.emit()
		await process_frame
	_check("picker equips the chosen item", sm.get_equipped("head") == "garuda_mungkur")
	_check("picker closes after choosing", page.find_child("EquipPicker", true, false) == null)

	page._show_equip_picker("head", tm.t("profile_head"))
	await process_frame
	var unequip_btn: Button = page.find_child("PickerUnequip", true, false) as Button
	_check("picker offers unequip", unequip_btn != null)
	if unequip_btn != null:
		unequip_btn.pressed.emit()
		await process_frame
	_check("picker unequips the slot", sm.get_equipped("head").is_empty())
	var empty_name: Label = page.find_child("Slot_head", true, false).find_child("ItemName", true, false)
	_check(
		"empty slot shows EMPTY",
		empty_name != null
			and empty_name.visible
			and empty_name.text == tm.t("profile_empty").to_upper()
	)

	for item: Dictionary in EquipmentDatabase.get_all():
		if EquipmentDatabase.item_fits_slot(item, "head"):
			sm.add_to_inventory(String(item["id"]))
	page._show_equip_picker("head", tm.t("profile_head"))
	await process_frame
	var picker_next := page.find_child("PickerNext", true, false) as Button
	var picker_page_label := page.find_child("PickerPageLabel", true, false) as Label
	_check("picker pagination appears when owned list exceeds the box",
		picker_next != null and picker_next.visible
			and picker_page_label != null and picker_page_label.text != "1 / 1")
	var picker_list := page.find_child("PickerList", true, false) as VBoxContainer
	_check("first picker page is capped at five items",
		picker_list != null and picker_list.get_child_count() == page.PICKER_ITEMS_PER_PAGE)
	if picker_next != null:
		picker_next.pressed.emit()
		await process_frame
	_check("picker advances to the next page",
		picker_page_label != null and picker_page_label.text.begins_with("2 / "))
	_check("second picker page stays within five items",
		picker_list != null and picker_list.get_child_count() <= page.PICKER_ITEMS_PER_PAGE)
	page.find_child("EquipPicker", true, false).queue_free()
	await process_frame

	sm.equipment = {"head": "", "body": "", "right_hand": "", "left_hand": ""}
	page._refresh()
	await process_frame
	_check("without equipment the stage-based HP is shown", _stat_text(page, "HP") == "600")
	_check("without equipment no bonus is appended", not _stat_bbcode(page, "HP").contains("[color"))

	sm.heroes["gatotkaca"] = {"level": 99, "stars": 1, "xp": 250}
	page._refresh()
	await process_frame
	var capped_xp_bar := page.find_child("KingXPBar", true, false) as ProgressBar
	var capped_xp_label := page.find_child("KingXPLabel", true, false) as Label
	_check(
		"profile XP bar is full at max level",
		capped_xp_bar != null and capped_xp_bar.value == capped_xp_bar.max_value
	)
	_check(
		"profile XP readout shows maximum at max level",
		capped_xp_label != null and capped_xp_label.text == tm.t("xp_maximum")
	)

	var probe := Control.new()
	page.add_child(probe)
	page._place_status(probe, "TEST", 100, -5, 0)
	await process_frame
	var red_hex: String = page.NEGATIVE_STAT_COLOR.to_html(false)
	_check("negative bonuses keep their minus sign", _stat_text(probe, "TEST") == "100-5")
	_check("negative bonuses are red", _stat_bbcode(probe, "TEST").contains("[color=#%s]" % red_hex))
	probe.queue_free()

	page.queue_free()
	await process_frame

	if _fails == 0:
		print("PROFILE_EQUIPMENT_PASS")
		quit(0)
	else:
		print("PROFILE_EQUIPMENT_FAIL: %d" % _fails)
		quit(1)
