extends SceneTree

# Pins the Instant Gold popup: structure, three reward tiers at the agreed
# ladder with fallback prices, disabled options while products are loading,
# the unavailable-purchase status path, billing_ready re-enabling options,
# the success path granting gold exactly once, and the reconcile path never
# double-granting a processed token.

var failures := 0


func _initialize() -> void:
	_run()


func _check(name: String, cond: bool) -> void:
	if cond:
		print("OK  ", name)
	else:
		push_error("FAIL " + name)
		failures += 1


func _run() -> void:
	await process_frame
	var track: Control = load("res://scenes/hub/LevelTrack.tscn").instantiate()
	root.add_child(track)
	await process_frame

	var tm = root.get_node("/root/TranslationManager")
	var sm = root.get_node("/root/SaveManager")
	var iap = root.get_node("/root/IAPManager")
	var iap_config = load("res://autoload/IAPConfig.gd")

	track._show_gold_popup()
	await process_frame
	var overlay := track.get_node_or_null("GoldPopupOverlay") as ColorRect
	_check("overlay present", overlay != null)
	if overlay == null:
		quit(1)
		return
	var panel := overlay.get_child(0) as Control
	var opt0 := panel.get_node_or_null("GoldOption0") as Button
	var opt1 := panel.get_node_or_null("GoldOption1") as Button
	var opt2 := panel.get_node_or_null("GoldOption2") as Button
	_check("three options present", opt0 != null and opt1 != null and opt2 != null)
	var label0 := opt0.get_node_or_null("BtnLabel") as Label
	var label1 := opt1.get_node_or_null("BtnLabel") as Label
	var label2 := opt2.get_node_or_null("BtnLabel") as Label
	_check("three option images loaded",
		(opt0.get_node("BtnArt") as TextureRect).texture != null
		and (opt1.get_node("BtnArt") as TextureRect).texture != null
		and (opt2.get_node("BtnArt") as TextureRect).texture != null)
	_check("option 1 shows 30000 gold and $1 fallback",
		label0 != null and "30000" in label0.text and "$1" in label0.text)
	_check("option 2 shows 80000 gold and $2 fallback",
		label1 != null and "80000" in label1.text and "$2" in label1.text)
	_check("option 3 shows 120000 gold and $3 fallback",
		label2 != null and "120000" in label2.text and "$3" in label2.text)
	_check("options disabled while products not ready",
		opt0.disabled and opt1.disabled and opt2.disabled)

	# billing_ready re-enables options while popup is open
	iap.billing_ready.emit()
	_check("billing_ready re-enables options",
		not opt0.disabled and not opt1.disabled and not opt2.disabled)

	# Purchasing while billing is absent headless -> unavailable status
	var status := panel.get_node_or_null("IapStatus") as Label
	track._on_gold_option_pressed("instant_gold_1", opt0, status)
	_check("unavailable status shown", status.text == tm.t("iap_unavailable"))
	_check("option re-enabled after unavailable", not opt0.disabled)

	# Success path grants exactly once and closes
	var gold_before: int = sm.gold
	var status2 := Label.new()
	track._on_gold_purchase_success(
		iap_config.get_sku("instant_gold_2"), "tok_gold_test", "instant_gold_2", status2)
	await process_frame
	_check("gold granted", sm.gold == gold_before + 80000)
	_check("token marked", sm.is_purchase_processed("tok_gold_test"))
	_check("popup closed after success",
		track.get_node_or_null("GoldPopupOverlay") == null)

	# Reconcile: unprocessed pending token grants
	track._show_gold_popup()
	await process_frame
	iap._pending_restorations.append({
		"sku": iap_config.get_sku("instant_gold_1"), "token": "tok_restore"})
	iap.purchases_restored.emit()
	_check("restore grants unprocessed token", sm.gold == gold_before + 80000 + 30000)
	_check("restore token marked", sm.is_purchase_processed("tok_restore"))

	# Reconcile: already-processed token never double-grants
	var gold_mid: int = sm.gold
	iap._pending_restorations.append({
		"sku": iap_config.get_sku("instant_gold_2"), "token": "tok_gold_test"})
	iap.purchases_restored.emit()
	_check("processed token not double-granted", sm.gold == gold_mid)

	# Wrong sku in success callback grants nothing
	var gold_wrong: int = sm.gold
	track._on_gold_purchase_success(
		iap_config.get_sku("instant_gold_1"), "tok_wrong", "instant_gold_2", status2)
	_check("mismatched sku grants nothing", sm.gold == gold_wrong)

	# Cancel path
	track._show_gold_popup()
	await process_frame
	overlay = track.get_node_or_null("GoldPopupOverlay") as ColorRect
	panel = overlay.get_child(0) as Control
	var cancel_btn := panel.get_node_or_null("CancelBtn") as Button
	_check("cancel button present", cancel_btn != null)
	if cancel_btn != null:
		cancel_btn.pressed.emit()
		await process_frame
	_check("popup closed after cancel",
		track.get_node_or_null("GoldPopupOverlay") == null)

	# Button wiring
	var gold_btn := track.get_node("TopBar/InstantGoldBtn") as TextureButton
	gold_btn.pressed.emit()
	await process_frame
	_check("top bar button opens popup",
		track.get_node_or_null("GoldPopupOverlay") != null)

	# Cleanup test residue
	sm.processed_purchases.erase("tok_gold_test")
	sm.processed_purchases.erase("tok_restore")
	sm.gold = gold_before
	sm.save_game()
	track.queue_free()
	await process_frame
	if failures > 0:
		push_error("instant gold popup regression")
		quit(1)
	else:
		print("INSTANT_GOLD_POPUP_PASS")
		quit(0)
