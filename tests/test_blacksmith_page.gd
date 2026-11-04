extends SceneTree

const PAGE_PATH := "res://scenes/hub/BlacksmithPage.gd"

var _fails: int = 0


func _initialize() -> void:
	_run()


func _check(name: String, ok: bool) -> void:
	if ok:
		print("OK  ", name)
	else:
		_fails += 1
		print("CHECK FAIL: " + name)


func _cards(page: Node) -> Array[Node]:
	var found: Array[Node] = page.find_children("ItemCard_*", "Panel", true, false)
	return found


func _run() -> void:
	await process_frame

	var sm = root.get_node("/root/SaveManager")
	var tm = root.get_node("/root/TranslationManager")
	sm.gold = 5000
	sm.inventory = []
	sm.equipment = {"head": "", "body": "", "right_hand": "", "left_hand": ""}
	sm.gold_changed.emit(sm.gold)

	var page: Control = load(PAGE_PATH).new()
	root.add_child(page)
	await process_frame

	_check("head tab exists", page.find_child("Tab_head", true, false) != null)
	_check("hand tab exists", page.find_child("Tab_hand", true, false) != null)
	_check("body tab exists", page.find_child("Tab_body", true, false) != null)
	_check("old weapon tab is gone", page.find_child("Tab_weapon", true, false) == null)
	_check("old shield tab is gone", page.find_child("Tab_shield", true, false) == null)
	_check("head is the default tab", _cards(page).size() == 4)
	var head_tab: Button = page.find_child("Tab_head", true, false) as Button
	var hand_tab: Button = page.find_child("Tab_hand", true, false) as Button
	_check(
		"selected category tab has a distinct style",
		head_tab != null and hand_tab != null
			and (head_tab.get_theme_stylebox("normal") as StyleBoxFlat).bg_color
				!= (hand_tab.get_theme_stylebox("normal") as StyleBoxFlat).bg_color
	)

	var head_card: Node = page.find_child("ItemCard_sumping_gajah_ngulun", true, false)
	_check("head card exists", head_card != null)
	_check(
		"equipment card is compact",
		head_card != null and is_equal_approx(head_card.size.y, 120.0)
	)
	_check(
		"equipment card has no description",
		head_card != null and head_card.find_child("DescLabel", true, false) == null
	)
	_check("head card has an icon", head_card != null and head_card.find_child("Icon", true, false) != null)
	_check("head card has a buy button", head_card != null and head_card.find_child("BuyButton", true, false) != null)
	_check("unowned card has no owned label", head_card != null and head_card.find_child("OwnedLabel", true, false) == null)
	var initial_buy_button: Button = page.find_child("BuyButton", true, false) as Button
	_check(
		"buy button uses translated market text",
		initial_buy_button != null
			and initial_buy_button.text == tm.t("market_buy").replace("{p}", "5000")
	)
	if head_card != null:
		var name_label: Label = head_card.find_child("NameLabel", true, false) as Label
		var buy_button: Button = head_card.find_child("BuyButton", true, false) as Button
		_check(
			"buy button aligns with the equipment name",
			name_label != null and buy_button != null
				and absf(name_label.global_position.y - buy_button.global_position.y) < 2.0
		)

	if hand_tab != null:
		hand_tab.pressed.emit()
	await process_frame
	_check("hand tab shows 4 items on first page", _cards(page).size() == 4)
	_check("hand card exists", page.find_child("ItemCard_cincin_setyaningampal", true, false) != null)
	_check(
		"selected category style follows the active filter",
		hand_tab != null and head_tab != null
			and (hand_tab.get_theme_stylebox("normal") as StyleBoxFlat).bg_color
				!= (head_tab.get_theme_stylebox("normal") as StyleBoxFlat).bg_color
	)

	var body_tab: Button = page.find_child("Tab_body", true, false)
	if body_tab != null:
		body_tab.pressed.emit()
	await process_frame
	_check("body tab shows 4 items on first page", _cards(page).size() == 4)
	_check("body card exists", page.find_child("ItemCard_sabuk_cinde_puspita", true, false) != null)

	if head_tab != null:
		head_tab.pressed.emit()
	await process_frame

	var buy_btn: Button = page.find_child("BuyButton", true, false)
	_check("first head item is affordable at 5000", buy_btn != null and not buy_btn.disabled)
	var prev_btn := page.find_child("BlacksmithPrev", true, false) as Button
	_check("blacksmith pagination buttons are larger",
		prev_btn != null and prev_btn.size == Vector2(140, 46))
	if buy_btn != null:
		buy_btn.pressed.emit()
		await process_frame

	var overlay: Node = page.get_window().get_node_or_null("BuyConfirmOverlay")
	_check("buy button opens confirmation", overlay != null)
	if overlay != null:
		var overlay_control := overlay as Control
		var popup_panel := overlay_control.get_child(0) as Control
		_check("buy confirmation is centered",
			(popup_panel.position + popup_panel.size / 2.0).is_equal_approx(
				overlay_control.size / 2.0))
	_check(
		"confirmation shows item name",
		overlay != null and overlay.find_child("ConfirmationTitle", true, false) != null
	)
	_check(
		"purchase waits for confirmation",
		sm.gold == 5000 and sm.get_inventory_count("sumping_gajah_ngulun") == 0
	)
	if overlay != null:
		var cancel_btn: Button = overlay.find_child("CancelBuyButton", true, false) as Button
		if cancel_btn != null:
			cancel_btn.pressed.emit()
		await process_frame
	_check(
		"cancel closes confirmation without purchase",
		sm.gold == 5000 and sm.get_inventory_count("sumping_gajah_ngulun") == 0
	)

	buy_btn = page.find_child("BuyButton", true, false) as Button
	if buy_btn != null:
		buy_btn.pressed.emit()
		await process_frame
	overlay = page.get_window().get_node_or_null("BuyConfirmOverlay")
	if overlay != null:
		var confirm_btn: Button = overlay.find_child("ConfirmBuyButton", true, false) as Button
		if confirm_btn != null:
			confirm_btn.pressed.emit()
		await process_frame

	_check("purchase spent exactly 5000", sm.gold == 0)
	_check("purchase added item", sm.get_inventory_count("sumping_gajah_ngulun") == 1)
	var owned_card: Node = page.find_child("ItemCard_sumping_gajah_ngulun", true, false)
	_check("owned card hides buy button", owned_card != null and owned_card.find_child("BuyButton", true, false) == null)
	_check("owned card shows owned label",
		owned_card != null and owned_card.find_child("OwnedLabel", true, false) != null)

	# Equip via blacksmith no longer uses the card button; use save manager directly
	if owned_card != null:
		sm.equip_item("head", "sumping_gajah_ngulun")
		page._refresh()
		await process_frame
	_check("equip button equips head", sm.get_equipped("head") == "sumping_gajah_ngulun")
	page._refresh()
	await process_frame
	owned_card = page.find_child("ItemCard_sumping_gajah_ngulun", true, false)
	var owned_label := owned_card.find_child("OwnedLabel", true, false) as Label
	_check("equipped equipment still only shows owned",
		owned_label != null and owned_label.text == tm.t("blacksmith_owned")
			and owned_card.find_child("EquippedLabel", true, false) == null)

	page.queue_free()
	await process_frame

	if _fails == 0:
		print("BLACKSMITH_PAGE_PASS")
		quit(0)
	else:
		print("BLACKSMITH_PAGE_FAIL: %d" % _fails)
		quit(1)
