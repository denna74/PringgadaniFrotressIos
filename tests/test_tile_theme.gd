extends SceneTree


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame

	var ok := true

	var cases: Dictionary = {
		1: "garden",
		10: "garden",
		11: "ocean",
		30: "ocean",
		31: "lava",
		60: "lava",
		61: "sky",
		90: "sky",
	}
	for stage: int in cases:
		var theme: String = TileTheme.theme_for_stage(stage)
		if theme != cases[stage]:
			push_error("theme_for_stage(%d) should be '%s', got '%s'" % [stage, cases[stage], theme])
			ok = false

	var random_themes: Array[String] = ["garden", "ocean", "lava", "sky"]
	for stage in [91, 150, 251]:
		if not random_themes.has(TileTheme.theme_for_stage(stage)):
			push_error("theme_for_stage(%d) returned a theme outside the random set" % stage)
			ok = false

	var path: String = TileTheme.texture_path("lava", "dirt_center")
	if not path.ends_with("themes/lava/dirt_center.png"):
		push_error("texture_path wrong: ", path)
		ok = false

	var sky_grass_path: String = TileTheme.texture_path("sky", "grass_center_1")
	if sky_grass_path != "res://assets/models/3D_tiles/themes/sky/cloud_center_1.png":
		push_error("sky grass texture path wrong: ", sky_grass_path)
		ok = false
	if not ResourceLoader.exists(sky_grass_path):
		push_error("sky grass texture does not exist: ", sky_grass_path)
		ok = false

	var sky_grass_material: Material = TerrainBuilder._get_material("grass_center_1", "sky")
	if sky_grass_material is StandardMaterial3D:
		var sky_material := sky_grass_material as StandardMaterial3D
		if sky_material.albedo_color != Color.WHITE:
			push_error("sky grass material should use a white albedo tint")
			ok = false
		if sky_material.shading_mode != BaseMaterial3D.SHADING_MODE_UNSHADED:
			push_error("sky grass must keep its exact unshaded texture appearance")
			ok = false
	else:
		push_error("sky grass material should be StandardMaterial3D")
		ok = false

	var sky_dirt_material: Material = TerrainBuilder._get_material("dirt_center", "sky")
	if sky_dirt_material is StandardMaterial3D:
		var sky_dirt := sky_dirt_material as StandardMaterial3D
		if sky_dirt.shading_mode != BaseMaterial3D.SHADING_MODE_UNSHADED:
			push_error("all sky theme materials must keep their unshaded texture appearance")
			ok = false
	else:
		push_error("sky dirt material should be StandardMaterial3D")
		ok = false

	var shadow_owner := Node3D.new()
	shadow_owner.position.y = 0.2
	root.add_child(shadow_owner)
	ModelLoader.set_ground_shadow(shadow_owner, true, Vector2(0.8, 0.5))
	var ground_shadow := shadow_owner.get_node_or_null("CharacterGroundShadow") as MeshInstance3D
	if ground_shadow == null:
		push_error("sky characters should have an independent ground shadow")
		ok = false
	else:
		if not ground_shadow.visible:
			push_error("sky character ground shadow should be visible")
			ok = false
		if not is_equal_approx(ground_shadow.position.y, -0.175):
			push_error("ground shadow should stay on the terrain surface")
			ok = false
		if not (ground_shadow.material_override is ShaderMaterial):
			push_error("ground shadow should use a separate unlit overlay material")
			ok = false
	ModelLoader.set_ground_shadow(shadow_owner, false, Vector2(0.8, 0.5))
	if ground_shadow != null and ground_shadow.visible:
		push_error("character ground shadow should be hideable outside sky maps")
		ok = false
	shadow_owner.free()

	var default_theme: String = TileTheme.DEFAULT_THEME
	if default_theme != "garden":
		push_error("DEFAULT_THEME should be garden, got ", default_theme)
		ok = false

	if ok:
		print("TILE_THEME_PASS")
		quit(0)
	else:
		push_error("TileTheme regression")
		quit(1)
