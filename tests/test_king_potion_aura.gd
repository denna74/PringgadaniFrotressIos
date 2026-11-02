extends SceneTree


func _initialize() -> void:
	_run()


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


func _run() -> void:
	await process_frame
	var sm = root.get_node("/root/SaveManager")
	var backup: Dictionary = _backup_save()
	DirAccess.remove_absolute(sm.save_path)
	sm.load_game()
	sm.inventory.clear()

	var pass_all := true

	var kc: Node3D = load("res://scenes/run/KingController.tscn").instantiate()
	root.add_child(kc)
	kc.setup_king({"hp": 300.0, "attack": 25.0, "mana_max": 200.0, "stamina_max": 100.0})
	for i in 20:
		await process_frame

	var aura: Node = kc.get("_aura")
	if aura == null:
		push_error("FAIL: _aura not built")
		pass_all = false

	if not kc.has_method("play_potion_aura"):
		push_error("FAIL: KingController missing play_potion_aura")
		pass_all = false

	if aura != null:
		if not aura.has_method("play"):
			push_error("FAIL: aura missing play method")
			pass_all = false
		else:
			var expected := {
				"heal": "green",
				"mana": "blue",
				"stamina": "yellow",
			}
			var sprite: AnimatedSprite3D = aura.get_node("PotionAura")
			if sprite.visible:
				push_error("FAIL: potion aura is visible before a potion is used")
				pass_all = false
			if sprite.shaded or not sprite.no_depth_test or not sprite.double_sided:
				push_error("FAIL: potion aura sprite rendering flags are not configured for visibility")
				pass_all = false
			if not is_equal_approx(sprite.position.y, 0.96):
				push_error("FAIL: potion aura sprite is not positioned around the king")
				pass_all = false
			for effect: String in expected:
				kc.play_potion_aura(effect)
				await process_frame
				if sprite.animation != expected[effect]:
					push_error("FAIL: %s potion uses %s animation" % [effect, sprite.animation])
					pass_all = false
				if not sprite.visible:
					push_error("FAIL: %s potion animation is hidden while playing" % effect)
					pass_all = false
				var frames: SpriteFrames = sprite.sprite_frames
				if frames.get_frame_count(expected[effect]) != 21:
					push_error("FAIL: %s animation does not have 21 frames" % effect)
					pass_all = false
				var first_frame: Texture2D = frames.get_frame_texture(expected[effect], 0)
				if not first_frame.resource_path.ends_with("%s_00.png" % expected[effect]):
					push_error("FAIL: %s animation starts with the wrong color frame" % effect)
					pass_all = false

			kc.play_potion_aura("mana")
			await process_frame
			if not bool(aura.get("emitting")):
				push_error("FAIL: aura not emitting after play()")
				pass_all = false

			await create_timer(1.0).timeout
			if bool(aura.get("emitting")):
				push_error("FAIL: aura still emitting after one-shot lifetime")
				pass_all = false
			if sprite.visible:
				push_error("FAIL: potion aura remains visible after animation")
				pass_all = false

	if pass_all:
		sm.add_to_inventory("mana_potion_small", 1)
		var panel: Control = load("res://scenes/run/PotionsPanel.gd").new()
		root.add_child(panel)
		panel.setup(kc)
		await process_frame
		kc.spend_mana(30.0)
		panel._consume("mana_potion_small")
		await process_frame
		if not is_equal_approx(kc.mana, 195.0):
			push_error("FAIL: mana potion restore = %s expected 195" % kc.mana)
			pass_all = false
		if aura != null and not bool(aura.get("emitting")):
			push_error("FAIL: consume did not trigger aura")
			pass_all = false
		var sfx = root.get_node("/root/SFXManager")
		if not (sfx._streams as Dictionary).has("potion"):
			push_error("FAIL: SFXManager has no 'potion' stream")
			pass_all = false

	kc.queue_free()
	_restore_save(backup)
	if not pass_all:
		quit(1)
		return
	print("AURA_PASS")
	quit(0)