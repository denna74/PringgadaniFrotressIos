extends SceneTree


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var ok := true

	for path: String in [
		"res://scenes/hub/LevelTrack.gd",
		"res://scenes/hub/HermitagePage.gd",
		"res://scenes/hub/ProfilePage.gd",
		"res://scenes/hub/BlacksmithPage.gd",
		"res://scenes/hub/MarketPage.gd",
	]:
		var page: Control = load(path).new()
		root.add_child(page)
		await process_frame
		if page.get_child_count() == 0:
			push_error("%s produced no nodes" % path)
			ok = false
		page.queue_free()
		await process_frame

	await process_frame
	if not ok:
		quit(1)
		return
	print("HUB_PAGES_PASS")
	quit(0)