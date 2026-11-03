extends SceneTree


func _initialize() -> void:
	_run()


func _find_labels(node: Node, needle: String) -> Array:
	var out: Array = []
	for child in node.get_children():
		if child is Label and (child as Label).text.contains(needle):
			out.append(child)
		out.append_array(_find_labels(child, needle))
	return out


func _run() -> void:
	await process_frame

	var kc: Node3D = load("res://scenes/run/KingController.tscn").instantiate()
	root.add_child(kc)
	kc.setup_king({"hp": 300.0, "attack": 25.0, "mana_max": 200.0, "stamina_max": 100.0})
	await process_frame

	var pass_all := true

	if kc.get("mana_max") == null or not kc.has_method("spend_mana") or not kc.has_method("restore_mana") or not kc.has_method("restore_hp"):
		push_error("KingController mana API not implemented")
		pass_all = false
	else:
		if not is_equal_approx(kc.mana_max, 200.0):
			push_error("mana_max = %s expected 200" % kc.mana_max)
			pass_all = false
		if not is_equal_approx(kc.mana, 200.0):
			push_error("initial mana = %s expected 200" % kc.mana)
			pass_all = false

		var emitted: Array = []
		kc.mana_changed.connect(func(c: float, m: float) -> void: emitted.append(c / maxf(m, 1.0)))

		if not kc.spend_mana(50.0):
			push_error("spend_mana(50) returned false")
			pass_all = false
		if not is_equal_approx(kc.mana, 150.0):
			push_error("mana after spend_mana(50) = %s expected 150" % kc.mana)
			pass_all = false

		if kc.spend_mana(200.0):
			push_error("spend_mana(200) should fail when mana=150")
			pass_all = false
		if not is_equal_approx(kc.mana, 150.0):
			push_error("failed spend_mana changed mana")
			pass_all = false

		kc.restore_mana(200.0)
		if not is_equal_approx(kc.mana, kc.mana_max):
			push_error("restore_mana did not clamp at max")
			pass_all = false

		kc.take_damage(50.0)
		kc.restore_hp(100.0)
		if not is_equal_approx(kc.king_hp, kc.king_max_hp):
			push_error("restore_hp did not clamp at max")
			pass_all = false

		kc.take_damage(50.0)
		kc.restore_hp(20.0)
		if not is_equal_approx(kc.king_hp, kc.king_max_hp - 30.0):
			push_error("restore_hp amount wrong")
			pass_all = false

		kc.stamina = 50.0
		kc.restore_stamina(0.5)
		if not is_equal_approx(kc.stamina, kc.stamina_max):
			push_error("restore_stamina percent restore failed")
			pass_all = false

		var expected_emits: Array = [150.0 / 200.0, 1.0]
		if emitted.size() != expected_emits.size():
			push_error("mana_changed emitted %d times, expected %d (failed spend must not emit)" % [emitted.size(), expected_emits.size()])
			pass_all = false
		else:
			for i in range(emitted.size()):
				if not is_equal_approx(emitted[i], expected_emits[i]):
					push_error("mana_changed emit[%d] = %s expected %s" % [i, emitted[i], expected_emits[i]])
					pass_all = false

		kc.stamina = 50.0
		kc.request_dash()
		if not is_equal_approx(kc.stamina, 30.0):
			push_error("dash did not spend its stamina cost")
			pass_all = false

		kc.mana = 100.0
		if not kc.spend_mana(50.0) or not is_equal_approx(kc.mana, 50.0):
			push_error("spend_mana did not deduct the requested MP")
			pass_all = false
		if kc.spend_mana(500.0) or not is_equal_approx(kc.mana, 50.0):
			push_error("failed spend_mana changed MP")
			pass_all = false
		kc.mana = 100.0
		kc.berserk_active = true
		kc._tick_berserk_drain(2.0)
		if not kc.mana < 100.0:
			push_error("Berserk did not drain MP")
			pass_all = false

	var page: Control = load("res://scenes/hub/ProfilePage.gd").new()
	root.add_child(page)
	await process_frame
	var mp_labels: Array = _find_labels(page, "MP")
	if mp_labels.is_empty():
		push_error("ProfilePage does not show an MP stat row")
		pass_all = false

	kc.queue_free()
	if not pass_all:
		quit(1)
		return
	print("MANA_PASS")
	quit(0)