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
	var track: Control = load("res://scenes/hub/LevelTrack.gd").new()
	root.add_child(track)
	await process_frame
	await process_frame

	var sections: Array = track.SECTIONS
	_check("hermitage in sections", sections.has("hermitage"))
	_check("profile right after gameplay",
		sections.find("profile") == sections.find("gameplay") + 1)
	_check("hermitage after profile",
		sections.find("hermitage") == sections.find("profile") + 1)
	_check("hermitage before blacksmith",
		sections.find("hermitage") < sections.find("blacksmith"))

	var buttons: Dictionary = track.get("_menu_buttons")
	_check("five section buttons", buttons.size() == 5)
	_check("hermitage button exists", buttons.has("hermitage"))

	(buttons["hermitage"] as Button).pressed.emit()
	await process_frame
	var page = track.get("_pages").get("hermitage")
	_check("hermitage page created", page != null)
	_check("page is HermitagePage",
		page != null and page.get_script().resource_path.ends_with("HermitagePage.gd"))

	track.queue_free()
	await process_frame

	if _fails == 0:
		print("HUB_HERMITAGE_MENU_PASS")
		quit(0)
	else:
		print("HUB_HERMITAGE_MENU_FAIL: %d" % _fails)
		quit(1)
