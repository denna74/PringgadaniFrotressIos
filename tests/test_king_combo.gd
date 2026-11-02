extends SceneTree


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame

	var kc: Node3D = load("res://scenes/run/KingController.tscn").instantiate()
	kc.position = Vector3(0, 0, 0)
	root.add_child(kc)
	for i in 20:
		await process_frame

	var ap: AnimationPlayer = kc.get("_anim_player")
	if ap == null:
		print("FAIL: no animation player on king")
		quit(1)
		return

	kc.attack()
	await process_frame
	if ap.current_animation != "king/attack_1":
		print("FAIL: first attack expected king/attack_1, got ", ap.current_animation, " step=", kc.get("_combo_step"))
		quit(1)
		return

	kc.attack()
	await process_frame
	if ap.current_animation != "king/attack_2":
		print("FAIL: second attack expected king/attack_2, got ", ap.current_animation, " step=", kc.get("_combo_step"))
		quit(1)
		return

	kc.attack()
	await process_frame
	if ap.current_animation != "king/attack_3":
		print("FAIL: third attack expected king/attack_3, got ", ap.current_animation, " step=", kc.get("_combo_step"))
		quit(1)
		return

	kc.attack()
	await process_frame
	if ap.current_animation != "king/attack_1":
		print("FAIL: fourth attack expected king/attack_1 (wrap), got ", ap.current_animation, " step=", kc.get("_combo_step"))
		quit(1)
		return

	kc.attack()
	await process_frame
	if ap.current_animation != "king/attack_2":
		print("FAIL: fifth attack expected king/attack_2, got ", ap.current_animation, " step=", kc.get("_combo_step"))
		quit(1)
		return

	for i in 65:
		await physics_frame

	if kc.get("_combo_step") != 0:
		print("FAIL: combo did not reset to 0 after window, step=", kc.get("_combo_step"))
		quit(1)
		return

	kc.attack()
	await process_frame
	if ap.current_animation != "king/attack_1":
		print("FAIL: attack after delay expected king/attack_1, got ", ap.current_animation, " step=", kc.get("_combo_step"))
		quit(1)
		return

	print("KING_COMBO_PASS")
	quit(0)