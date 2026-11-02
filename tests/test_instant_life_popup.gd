extends SceneTree

# Pins the Instant Life popup: structure, the SDK-not-ready status path, the
# failure path re-enabling the Watch button, the earned path granting exactly
# one life (never above max) and closing, and the cancel path.

var failures := 0


func _initialize() -> void:
	_run()


func _check(name: String, cond: bool) -> void:
	if cond:
		print("OK  ", name)
	else:
		push_error("FAIL " + name)
		failures += 1


func _find_button(parent: Node, text: String) -> Button:
	for child in parent.get_children():
		if child is Button and (child as Button).text == text:
			return child
	return null


func _run() -> void:
	await process_frame
	var track: Control = load("res://scenes/hub/LevelTrack.tscn").instantiate()
	root.add_child(track)
	await process_frame

	var tm = root.get_node("/root/TranslationManager")
	var sm = root.get_node("/root/SaveManager")
	var ads = root.get_node("/root/AdsManager")

	# Structure
	track._show_life_popup()
	await process_frame
	var overlay := track.get_node_or_null("LifePopupOverlay") as ColorRect
	_check("overlay present", overlay != null)
	if overlay == null:
		quit(1)
		return
	var panel := overlay.get_child(0) as Control
	_check("panel present", panel != null)
	var watch_btn := _find_button(panel, tm.t("instant_life_watch"))
	var cancel_btn := _find_button(panel, tm.t("cancel"))
	_check("watch button present", watch_btn != null)
	_check("cancel button present", cancel_btn != null)
	var status := panel.get_node_or_null("AdStatus") as Label
	_check("status label present", status != null)

	# Double-open guard
	track._show_life_popup()
	await process_frame
	var overlays := 0
	for child in track.get_children():
		if child.name == "LifePopupOverlay":
			overlays += 1
	_check("second open is a no-op", overlays == 1)
	overlay.queue_free()
	await process_frame

	# SDK-not-ready path: status shows loading, flow pends, no crash
	sm.lives = clampi(sm.lives, 0, sm.max_lives - 1)
	track._show_life_popup()
	await process_frame
	overlay = track.get_node_or_null("LifePopupOverlay") as ColorRect
	panel = overlay.get_child(0) as Control
	watch_btn = _find_button(panel, tm.t("instant_life_watch"))
	status = panel.get_node_or_null("AdStatus") as Label
	track._on_watch_life_ad_pressed(watch_btn, status, overlay, panel)
	_check("status shows loading when SDK not ready",
		status.text == tm.t("life_ad_loading"))
	_check("pending flow armed", ads._flow_pending)

	# Init failure path: status shows failed, watch re-enabled
	watch_btn.disabled = true
	ads._on_init_failed("TEST_ERROR", "init failed")
	_check("status shows failed after init failure",
		status.text == tm.t("life_ad_failed"))
	_check("watch re-enabled after failure", not watch_btn.disabled)

	# Earned path: re-arm one-shot handlers, then emit earned
	var lives_before: int = sm.lives
	track._on_watch_life_ad_pressed(watch_btn, status, overlay, panel)
	ads.life_reward_earned.emit()
	await process_frame
	_check("exactly one life granted", sm.lives == lives_before + 1)
	_check("never above max", sm.lives <= sm.max_lives)
	_check("popup closed after earn",
		track.get_node_or_null("LifePopupOverlay") == null)

	# Earned at full lives grants nothing extra
	sm.lives = sm.max_lives
	track._show_life_popup()
	await process_frame
	overlay = track.get_node_or_null("LifePopupOverlay") as ColorRect
	panel = overlay.get_child(0) as Control
	watch_btn = _find_button(panel, tm.t("instant_life_watch"))
	status = panel.get_node_or_null("AdStatus") as Label
	track._on_watch_life_ad_pressed(watch_btn, status, overlay, panel)
	ads.life_reward_earned.emit()
	await process_frame
	_check("no life granted at max", sm.lives == sm.max_lives)

	# Cancel path
	track._show_life_popup()
	await process_frame
	overlay = track.get_node_or_null("LifePopupOverlay") as ColorRect
	panel = overlay.get_child(0) as Control
	cancel_btn = _find_button(panel, tm.t("cancel"))
	cancel_btn.pressed.emit()
	await process_frame
	_check("popup closed after cancel",
		track.get_node_or_null("LifePopupOverlay") == null)

	# Button wiring: the top-bar button opens the popup
	var life_btn := track.get_node("TopBar/InstantLifeBtn") as TextureButton
	life_btn.pressed.emit()
	await process_frame
	_check("top bar button opens popup",
		track.get_node_or_null("LifePopupOverlay") != null)

	sm.lives = sm.max_lives
	sm.save_game()
	track.queue_free()
	await process_frame
	if failures > 0:
		push_error("instant life popup regression")
		quit(1)
	else:
		print("INSTANT_LIFE_POPUP_PASS")
		quit(0)
