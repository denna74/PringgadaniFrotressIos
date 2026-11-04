extends SceneTree

const PAGE_PATH := "res://scenes/hub/MarketPage.gd"

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

	var page: Control = load(PAGE_PATH).new()
	root.add_child(page)
	await process_frame

	var items: VBoxContainer = page.find_child("Items", true, false) as VBoxContainer
	_check("market category tabs exist",
		page.find_child("MarketTab_heal", true, false) != null
			and page.find_child("MarketTab_mana", true, false) != null
			and page.find_child("MarketTab_stamina", true, false) != null)
	_check("HP category shows three items",
		items != null and items.get_child_count() == 3
			and page.find_child("ItemRow_health_potion_small", true, false) != null)

	var first_card := page.find_child("ItemRow_health_potion_small", true, false) as Panel
	var icon := page.find_child("Icon", true, false) as TextureRect
	var name_label := page.find_child("NameLabel", true, false) as Label
	_check("market cards match blacksmith dimensions",
		first_card != null and first_card.size == Vector2(500, 120))
	_check("market icon matches blacksmith size",
		icon != null and icon.size == Vector2(96, 96))
	_check("market card text matches blacksmith font size",
		name_label != null and name_label.get_theme_font_size("font_size") == 21)
	_check("market pagination controls are absent",
		page.find_child("MarketPrev", true, false) == null
			and page.find_child("MarketNext", true, false) == null
			and page.find_child("MarketPageLabel", true, false) == null)

	var mana_tab := page.find_child("MarketTab_mana", true, false) as Button
	if mana_tab != null:
		mana_tab.pressed.emit()
	await process_frame
	_check("MP tab shows only mana items",
		items != null and items.get_child_count() == 3
			and page.find_child("ItemRow_mana_potion_small", true, false) != null
			and page.find_child("ItemRow_health_potion_small", true, false) == null)

	var stamina_tab := page.find_child("MarketTab_stamina", true, false) as Button
	if stamina_tab != null:
		stamina_tab.pressed.emit()
	await process_frame
	_check("stamina tab shows only stamina items",
		items != null and items.get_child_count() == 3
			and page.find_child("ItemRow_stamina_potion_small", true, false) != null
			and page.find_child("ItemRow_mana_potion_small", true, false) == null)

	var filtered_items: Array = page.get("_filtered_items")
	page._show_buy_confirm(filtered_items[0])
	await process_frame
	var overlay := page.get_window().get_node_or_null("BuyConfirmOverlay") as Control
	_check("buy confirmation opens", overlay != null)
	if overlay != null:
		var popup_panel := overlay.get_child(0) as Control
		_check("buy confirmation is centered",
			(popup_panel.position + popup_panel.size / 2.0).is_equal_approx(
				overlay.size / 2.0))
		overlay.queue_free()
		await process_frame

	page.queue_free()
	await process_frame
	if _fails == 0:
		print("MARKET_PAGE_PASS")
		quit(0)
	else:
		print("MARKET_PAGE_FAIL: %d" % _fails)
		quit(1)
