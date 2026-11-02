extends SceneTree

# A paused tree only keeps running the nodes explicitly marked ALWAYS. The modal
# popups (build, upgrade, pause, result) must stay alive so the player can dismiss
# them, and the result overlays must cover the viewport so the frozen HUD cannot be
# tapped underneath.

var failures := 0


func _initialize() -> void:
	_run()


func _check(name: String, cond: bool) -> void:
	if cond:
		print("OK  ", name)
	else:
		push_error("FAIL " + name)
		failures += 1


func _finish(token: String) -> void:
	if failures > 0:
		push_error("%s regression (%d failures)" % [token, failures])
		quit(1)
		return
	print(token)
	quit(0)


func _run() -> void:
	await process_frame
	var gp = root.get_node("/root/GamePause")
	_check(
		"GamePause always processes",
		gp != null and gp.process_mode == Node.PROCESS_MODE_ALWAYS
	)

	for name in ["MusicManager", "SFXManager", "ClickPlayer"]:
		var node = root.get_node_or_null("/root/" + name)
		_check(
			"%s always processes" % name,
			node != null and node.process_mode == Node.PROCESS_MODE_ALWAYS
		)

	# RunHUD must keep its pause button live while the tree is frozen.
	var hud = load("res://scenes/run/RunHUD.tscn").instantiate()
	root.add_child(hud)
	await process_frame
	_check("RunHUD always processes", hud.process_mode == Node.PROCESS_MODE_ALWAYS)
	hud.queue_free()
	await process_frame

	# Build/upgrade popup layers live under the pausable run scene.
	var plot = load("res://scenes/run/BuildingPlot.gd").new()
	var layer = plot._make_popup_layer()
	_check(
		"build popup layer always processes",
		layer != null and layer.process_mode == Node.PROCESS_MODE_ALWAYS
	)
	plot.free()

	var bld = load("res://scenes/buildings/Building.gd").new({}, null)
	bld._ensure_overlay_layer()
	_check(
		"building overlay layer always processes",
		bld._overlay_layer.process_mode == Node.PROCESS_MODE_ALWAYS
	)
	bld.free()

	# Result overlays must cover the whole viewport and eat input.
	var rc = load("res://scenes/run/RunController.gd").new()
	var host := Control.new()
	root.add_child(host)
	var overlay = rc._make_modal_overlay(host)
	_check("result overlay eats input", overlay.mouse_filter == Control.MOUSE_FILTER_STOP)
	_check(
		"result overlay covers the viewport",
		is_equal_approx(overlay.anchor_right, 1.0) and is_equal_approx(overlay.anchor_bottom, 1.0)
	)
	rc.free()
	host.queue_free()
	await process_frame

	_finish("PAUSE_FREEZE_PASS")