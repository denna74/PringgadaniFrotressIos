extends SceneTree

# Graphics quality is fixed at HIGH. The render-resolution presets (and their Settings
# toggle) were removed, so the only behaviour left to pin is that the autoload exists and
# forces the root viewport to full 3D resolution.

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

	var gm = root.get_node_or_null("/root/GraphicsManager")
	_check("GraphicsManager autoload exists", gm != null)
	_check("graphics renders at full resolution (1.0)", is_equal_approx(root.scaling_3d_scale, 1.0))

	if failures > 0:
		push_error("GraphicsManager regression (%d failures)" % failures)
		quit(1)
		return
	print("GRAPHICS_MANAGER_PASS")
	quit(0)
