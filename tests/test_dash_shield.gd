extends SceneTree

## Bayu Bajra (dash level > 3) projects a translucent blue half-dome shield in
## front of the king for the whole dash, then fades it out. Levels 1-3 keep the
## plain trail.

var _fails: int = 0


func _initialize() -> void:
	_run()


func _check(name: String, ok: bool) -> void:
	if ok:
		print("OK  ", name)
	else:
		_fails += 1
		print("CHECK FAIL: " + name)


func _make_king(level: int) -> Node3D:
	var sm = root.get_node("/root/SaveManager")
	sm.skill_levels = {"dash": level, "earthquake": 1, "berserk": 1}
	var kc: Node3D = load("res://scenes/run/KingController.tscn").instantiate()
	kc.position = Vector3.ZERO
	kc.set_play_field(8)
	kc.setup_king({"hp": 9999.0, "attack": 10.0})
	root.add_child(kc)
	return kc


func _check_body(body: MeshInstance3D) -> void:
	if body == null or not (body.mesh is SphereMesh):
		_check("dome body is a sphere mesh", false)
		return
	var sphere := body.mesh as SphereMesh
	_check("dome is hemisphere", sphere.is_hemisphere)
	_check("dome is half-height (real bowl)",
		is_equal_approx(sphere.height, sphere.radius))
	_check("bowl wider than tall", (body.scale.x > body.scale.y))
	_check("bowl taller toward bottom", (body.scale.y > body.scale.z))
	var mat := body.material_override as StandardMaterial3D
	_check("dome translucent",
		mat != null and mat.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA)
	_check("dome blue", mat != null and mat.albedo_color.b > mat.albedo_color.r)
	_check("dome faint",
		mat != null and mat.albedo_color.a > 0.05 and mat.albedo_color.a < 0.4)
	_check("dome gradient texture", mat != null and mat.albedo_texture != null)
	_check("dome front-face only (no solid interior)",
		mat != null and mat.cull_mode == BaseMaterial3D.CULL_BACK)
	_check_gradient(mat)


func _check_gradient(mat: StandardMaterial3D) -> void:
	if mat == null or mat.albedo_texture == null:
		_check("gradient texture present", false)
		return
	var img: Image = mat.albedo_texture.get_image()
	if img == null:
		_check("gradient texture has image", false)
		return
	# The reference shows a bright rim with a see-through middle: the texture
	# must be darker/more transparent away from the edges than at them.
	var w := img.get_width()
	var h := img.get_height()
	var mid := img.get_pixel(w / 2, h / 2).a
	_check("gradient transparent middle", mid < 0.35)
	var edge_bright := false
	for x in w:
		if img.get_pixel(x, 0).a > 0.6 and img.get_pixel(x, h - 1).a > 0.6:
			edge_bright = true
			break
	_check("gradient bright rim", edge_bright)


func _run() -> void:
	await process_frame

	var dome_script: GDScript = load("res://scenes/effects/ShieldDome.gd")
	_check("shield script loads", dome_script != null)
	if dome_script != null:
		var dome: Node3D = dome_script.new()
		root.add_child(dome)
		await create_timer(0.15).timeout
		_check_body(dome.get_node_or_null("Dome") as MeshInstance3D)
		_check("rim removed", dome.get_node_or_null("Rim") == null)
		if dome.has_method("fade_out"):
			dome.call("fade_out")
			await create_timer(0.25).timeout
			_check("fade_out frees dome",
				not is_instance_valid(dome) or dome.is_queued_for_deletion())
		else:
			_check("fade_out frees dome", false)
			dome.queue_free()
			await process_frame

	var kc := _make_king(3)
	await process_frame
	kc.request_dash()
	await process_frame
	_check("lv3 dash no shield", kc.get_node_or_null("DashShield") == null)
	_check("lv3 dash trail present", kc.get_node_or_null("DashTrail") != null)
	kc.queue_free()
	await process_frame

	kc = _make_king(4)
	await process_frame
	kc.request_dash()
	await process_frame
	var shield: Node = kc.get_node_or_null("DashShield")
	_check("lv4 dash spawns shield", shield != null)
	if shield != null:
		_check("lv4 shield in front", (shield.position as Vector3).z > 0.0)
		await create_timer(0.15).timeout
		_check_body(shield.get_node_or_null("Dome") as MeshInstance3D)
	for i in 36:
		await physics_frame
	_check("lv4 shield gone after dash", kc.get_node_or_null("DashShield") == null)
	kc.queue_free()
	await process_frame

	if _fails == 0:
		print("DASH_SHIELD_PASS")
		quit(0)
	else:
		print("DASH_SHIELD_FAIL: %d" % _fails)
		quit(1)
