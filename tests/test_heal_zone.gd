extends SceneTree


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame

	var data: Dictionary = BuildingData.get_building_data("pendopo")
	var pendopo: Node3D = load("res://scenes/buildings/Pendopo.gd").new(data, null)
	pendopo.position = Vector3(0, 0, 0)
	root.add_child(pendopo)
	await process_frame

	if not pendopo.has_node("HealZone"):
		print("FAIL: Pendopo has no HealZone child")
		quit(1)
		return

	var kc: Node3D = load("res://scenes/run/KingController.tscn").instantiate()
	kc.position = Vector3(0, 0, 0)
	kc.setup_king({"hp": 300, "attack": 25})
	kc.pendopo_pos = Vector3(0, 0, 0)
	kc.healing_changed.connect(pendopo.begin_heal_effect)
	root.add_child(kc)
	await process_frame
	await process_frame

	var heal_zone: Node3D = pendopo.get_node("HealZone")
	var animation: AnimatedSprite3D = heal_zone.get_node("Animation")

	if kc.healing_active or animation.visible or animation.modulate.a > 0.001:
		print("FAIL: heal zone active while at full HP")
		quit(1)
		return
	if animation.sprite_frames.get_frame_count("heal") != 114:
		print("FAIL: healing GIF frames were not loaded")
		quit(1)

	kc.take_damage(50)
	var damaged_hp: float = kc.king_hp
	for i in 90:
		await process_frame

	print("healing_active=", kc.healing_active, " hp=", kc.king_hp, " animation_alpha=", animation.modulate.a)
	if not kc.healing_active:
		print("FAIL: heal zone did not activate when injured inside radius")
		quit(1)
		return
	if kc.king_hp <= damaged_hp:
		print("FAIL: king did not heal inside radius")
		quit(1)
		return
	if not animation.visible or not animation.is_playing() or animation.modulate.a < 0.45:
		print("FAIL: healing animation did not fade in and play")
		quit(1)
		return
	if animation.modulate.a >= 1.0:
		print("FAIL: healing animation did not remain translucent")
		quit(1)
		return

	var peak_alpha := animation.modulate.a
	kc.king_hp = kc.king_max_hp
	for i in 12:
		await process_frame

	if kc.healing_active:
		print("FAIL: healing remained active after reaching full HP")
		quit(1)
		return
	if animation.modulate.a >= peak_alpha:
		print("FAIL: healing animation did not begin fading out")
		quit(1)
		return

	for i in 120:
		await process_frame

	print("after_full active=", kc.healing_active, " animation_alpha=", animation.modulate.a)
	if kc.healing_active:
		print("FAIL: heal zone still active after reaching full HP")
		quit(1)
		return
	if animation.visible or animation.modulate.a > 0.001:
		print("FAIL: healing animation did not finish fading out")
		quit(1)
		return
	if animation.is_playing():
		print("FAIL: healing animation is still playing after fade-out")
		quit(1)
		return

	kc.take_damage(30)
	for i in 30:
		await process_frame

	if not kc.healing_active:
		print("FAIL: heal zone did not reactivate when injured again")
		quit(1)
		return

	kc.position = Vector3(6, 0, 6)
	for i in 30:
		await process_frame

	print("after_outside active=", kc.healing_active, " animation_alpha=", animation.modulate.a)
	if kc.healing_active:
		print("FAIL: heal zone active outside radius")
		quit(1)
		return

	print("VERIFY_PASS")
	quit(0)