extends SceneTree

# With no lives left, tapping a stage node must reach the OUT OF LIVES popup rather
# than doing nothing. The node used to be disabled whenever lives hit zero, and a
# disabled Button never emits `pressed`, so the popup was unreachable exactly when the
# player needed it. The 1-hour refill made "no lives" a normal state, exposing this.

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
	var sm = root.get_node("/root/SaveManager")
	var tm = root.get_node("/root/TranslationManager")
	var language_backup: String = tm.current_language
	var save_backup := _backup_save()
	var lives_backup: int = sm.lives
	var loss_backup: int = sm.last_life_loss_time
	var current: int = sm.stage_number

	sm.lives = 0
	sm.last_life_loss_time = int(Time.get_unix_time_from_system())
	sm.lives_changed.emit(sm.lives)

	var track: Control = load("res://scenes/hub/LevelTrack.tscn").instantiate()
	root.add_child(track)
	await process_frame
	await process_frame

	var cur_btn := _find_by_name(track, "Stage%d" % current) as Button
	_check("the current stage node is built", cur_btn != null)
	_check("a stage node stays tappable with no lives", cur_btn != null and not cur_btn.disabled)

	var locked_btn := _find_by_name(track, "Stage%d" % (current + 1)) as Button
	_check("a locked stage node stays disabled", locked_btn != null and locked_btn.disabled)

	# The real tap path: pressing the node routes to the OUT OF LIVES popup.
	if cur_btn != null:
		cur_btn.pressed.emit()
		await process_frame
		var overlay := _find_by_name(track, "NoLivesOverlay") as Control
		_check("tapping with no lives shows OUT OF LIVES", overlay != null)
		if overlay != null:
			var panel := _find_by_name(overlay, "NoLivesPanel") as Panel
			_check("out-of-lives popup is centered",
				(panel.get_global_rect().get_center() - overlay.size / 2.0).length() < 0.5)
			var title := _find_by_name(overlay, "NoLivesTitle") as Label
			var refill := _find_by_name(overlay, "NoLivesRefill") as Label
			var panel_style := panel.get_theme_stylebox("panel") as StyleBoxFlat if panel != null else null
			var close_btn := _find_by_name(overlay, "NoLivesCloseButton") as Button
			_check("out-of-lives popup has an opaque panel",
				panel_style != null and panel_style.bg_color.a >= 0.9)
			_check("out-of-lives title is translated",
				title != null and title.text == tm.t("no_lives_title"))
			_check("refill text is translated",
				refill != null and refill.text == tm.t("no_lives_refill") % "60:00")
			_check("close button is translated",
				close_btn != null and close_btn.text == tm.t("close"))
			_check("out-of-lives title is larger than the refill text",
				title != null and refill != null
				and title.get_theme_font_size("font_size") > refill.get_theme_font_size("font_size"))
			tm.set_language("id" if language_backup == "en" else "en")
			_check("open popup updates when language changes",
				title != null and title.text == tm.t("no_lives_title")
				and refill != null
				and refill.text == tm.t("no_lives_refill") % "60:00"
				and close_btn != null and close_btn.text == tm.t("close"))
			tm.set_language(language_backup)

	track.queue_free()
	await process_frame

	sm.lives = lives_backup
	sm.last_life_loss_time = loss_backup
	sm.lives_changed.emit(sm.lives)
	_restore_save(save_backup)
	tm.set_language(language_backup)

	if failures > 0:
		push_error("No-lives popup regression (%d failures)" % failures)
		quit(1)
		return
	print("NO_LIVES_POPUP_PASS")
	quit(0)


func _find_by_name(node: Node, want: String) -> Node:
	if node.name == want:
		return node
	for child in node.get_children():
		var hit := _find_by_name(child, want)
		if hit != null:
			return hit
	return null


func _backup_save() -> Dictionary:
	var sm = root.get_node("/root/SaveManager")
	if not FileAccess.file_exists(sm.save_path):
		return {"exists": false}
	var f := FileAccess.open(sm.save_path, FileAccess.READ)
	var text: String = f.get_as_text()
	f.close()
	return {"exists": true, "data": text}


func _restore_save(backup: Dictionary) -> void:
	var sm = root.get_node("/root/SaveManager")
	if backup.get("exists", false):
		var f := FileAccess.open(sm.save_path, FileAccess.WRITE)
		f.store_string(backup["data"])
		f.close()
	else:
		DirAccess.remove_absolute(sm.save_path)
	sm.load_game()