extends SceneTree

const SKILL_BUTTON_SIZE: float = 110.0
const ATTACK_BUTTON_SIZE: Vector2 = Vector2(235, 226)
const EARTHQUAKE_BUTTON_POS: Vector2 = Vector2(906, 458)
const BERSERK_BUTTON_POS: Vector2 = Vector2(1016, 360)
const DASH_BUTTON_POS: Vector2 = Vector2(906, 594)
const ATTACK_BUTTON_POS: Vector2 = Vector2(1029, 478)
const DIMMED_ALPHA: float = 0.35
const PULSE_DIM: float = 0.3

var _fails: int = 0


func _initialize() -> void:
	_run()


func _fail(msg: String) -> void:
	_fails += 1
	print("CHECK FAIL: " + msg)


func _run() -> void:
	await process_frame
	var hud := CanvasLayer.new()
	hud.set_script(load("res://scenes/run/RunHUD.gd"))
	root.add_child(hud)
	await process_frame

	var atk_btn: Control = hud.get("_atk_btn")
	var skill_btn: Control = hud.get("_skill_btn")
	var berserk_btn: Control = hud.get("_berserk_btn")
	var dash_btn: Control = hud.get("_dash_btn")
	var berserk_tex: TextureRect = hud.get("_berserk_tex")
	var dash_tex: TextureRect = hud.get("_dash_tex")
	var skill_tex: TextureRect = hud.get("_skill_tex")
	var skill_cooldown: TextureProgressBar = hud.get("_skill_cooldown")
	var atk_tex: TextureRect = hud.get("_atk_tex")
	var mana_bar: ProgressBar = hud.get("_mana_bar")
	var hp_bar: ProgressBar = hud.get("_king_hp_bar")
	var stamina_bar: ProgressBar = hud.get("_stamina_bar")

	if berserk_btn == null or berserk_tex == null:
		_fail("HUD has no berserk button")
		_finish()
		return

	if berserk_tex.texture == null:
		_fail("berserk button texture failed to load")
	if skill_tex == null or skill_tex.texture == null:
		_fail("earthquake button texture failed to load")
	if dash_tex == null or dash_tex.texture == null:
		_fail("dash button texture failed to load")

	_check_button("earthquake", skill_btn, EARTHQUAKE_BUTTON_POS, Vector2(SKILL_BUTTON_SIZE, SKILL_BUTTON_SIZE))
	_check_button("berserk", berserk_btn, BERSERK_BUTTON_POS, Vector2(SKILL_BUTTON_SIZE, SKILL_BUTTON_SIZE))
	_check_button("dash", dash_btn, DASH_BUTTON_POS, Vector2(SKILL_BUTTON_SIZE, SKILL_BUTTON_SIZE))
	_check_button("attack", atk_btn, ATTACK_BUTTON_POS, ATTACK_BUTTON_SIZE)

	_check_no_overlap("earthquake", skill_btn, berserk_btn)
	_check_no_overlap("berserk", berserk_btn, dash_btn)
	_check_no_overlap("earthquake/dash column vs minimap", skill_btn, hud.get("_minimap"))
	# The attack button is the one the small buttons surround, so nothing may sit
	# inside it. The pair checks below are the only thing guarding that.
	_check_no_overlap("attack vs earthquake", atk_btn, skill_btn)
	_check_no_overlap("attack vs berserk", atk_btn, berserk_btn)
	_check_no_overlap("attack vs dash", atk_btn, dash_btn)

	# A button's visible art is its texture, so a texture that does not fill its
	# button means resizing the button silently does nothing. The attack texture was
	# hardcoded to 150x150 while its button followed ATTACK_BUTTON_SIZE, which is
	# exactly this bug.
	_check_tex_fills("attack", atk_btn, atk_tex)
	_check_tex_fills("earthquake", skill_btn, skill_tex)
	_check_cooldown_matches_skill(skill_tex, skill_cooldown)
	_check_tex_fills("berserk", berserk_btn, berserk_tex)
	_check_tex_fills("dash", dash_btn, dash_tex)

	await _check_berserk_tint(hud, berserk_tex)
	await _check_dash_dim(hud, dash_tex)
	await _check_low_pulse(hud, hp_bar, mana_bar, stamina_bar)

	hud.queue_free()
	await process_frame
	_finish()


func _check_button(label: String, btn: Control, expected_pos: Vector2, expected_size: Vector2) -> void:
	if btn == null:
		_fail("%s button is missing" % label)
		return
	if btn.position != expected_pos:
		_fail("%s button at %s, want %s" % [label, btn.position, expected_pos])
	if not is_equal_approx(btn.size.x, expected_size.x) or not is_equal_approx(btn.size.y, expected_size.y):
		_fail("%s button is %s, want %s" % [label, btn.size, expected_size])


func _check_tex_fills(label: String, btn: Control, tex: TextureRect) -> void:
	if btn == null or tex == null:
		_fail("%s has no button/texture to compare" % label)
		return
	if not btn.size.is_equal_approx(tex.size):
		_fail("%s texture is %s but its button is %s, so resizing the button would not resize the art"
			% [label, tex.size, btn.size])
	if tex.position != Vector2.ZERO:
		_fail("%s texture is offset by %s, want top-left aligned" % [label, tex.position])


func _check_cooldown_matches_skill(skill_tex: TextureRect, cooldown: TextureProgressBar) -> void:
	if skill_tex == null or cooldown == null:
		_fail("earthquake cooldown or button texture is missing")
		return
	if not cooldown.size.is_equal_approx(skill_tex.size) or cooldown.position != skill_tex.position:
		_fail("earthquake cooldown bounds %s at %s do not match button texture %s at %s"
			% [cooldown.size, cooldown.position, skill_tex.size, skill_tex.position])


func _check_no_overlap(label: String, a: Control, b: Control) -> void:
	if a == null or b == null:
		return
	if a.get_global_rect().intersects(b.get_global_rect()):
		_fail("%s overlap: %s %s vs %s %s" % [
			label, a.name, a.get_global_rect(), b.name, b.get_global_rect()
		])


func _check_berserk_tint(hud: CanvasLayer, tex: TextureRect) -> void:
	var idle := tex.self_modulate
	hud.set_berserk_active(true)
	await process_frame
	var active := tex.self_modulate
	if active.g >= idle.g:
		_fail("berserk button not tinted red when active: %s (idle was %s)" % [active, idle])
	if not is_equal_approx(active.a, 1.0):
		_fail("berserk button not fully opaque when active: alpha %f" % active.a)
	var pressed_scale: Vector2 = hud.get("_berserk_btn").scale
	if pressed_scale.x <= 1.0:
		_fail("berserk button not enlarged when active: %s" % pressed_scale)

	hud.set_berserk_active(false)
	await process_frame
	if tex.self_modulate != idle:
		_fail("berserk button did not return to idle tint: %s want %s" % [tex.self_modulate, idle])


func _check_dash_dim(hud: CanvasLayer, dash_tex: TextureRect) -> void:
	hud.set_berserk_active(false)
	hud.update_stamina(0.0, 100.0)
	await process_frame
	if not is_equal_approx(dash_tex.self_modulate.a, DIMMED_ALPHA):
		_fail("dash button not dimmed at 0 stamina without berserk: alpha %f" % dash_tex.self_modulate.a)

	hud.set_berserk_active(true)
	await process_frame
	if is_equal_approx(dash_tex.self_modulate.a, DIMMED_ALPHA):
		_fail("dash button still dimmed at 0 stamina while berserk is active")

	hud.set_berserk_active(false)
	hud.update_stamina(100.0, 100.0)
	await process_frame


func _check_low_pulse(hud: CanvasLayer, hp_bar: ProgressBar, mana_bar: ProgressBar, stamina_bar: ProgressBar) -> void:
	hud.update_king_hp(5.0, 100.0)
	hud.update_mana(5.0, 100.0)
	hud.update_stamina(5.0, 100.0)
	await process_frame

	var dimmed := await _wait_for_dim(hud, mana_bar)
	if not dimmed:
		_fail("low MP bar never dimmed (alpha stayed %f)" % mana_bar.modulate.a)
	elif not is_equal_approx(mana_bar.modulate.a, PULSE_DIM):
		_fail("low MP bar dimmed to %f, want %f" % [mana_bar.modulate.a, PULSE_DIM])

	if not await _wait_for_dim(hud, hp_bar):
		_fail("low HP bar never dimmed (alpha stayed %f)" % hp_bar.modulate.a)

	if not await _wait_for_dim(hud, stamina_bar):
		_fail("low stamina bar never dimmed (alpha stayed %f)" % stamina_bar.modulate.a)

	hud.update_mana(50.0, 100.0)
	hud.update_king_hp(50.0, 100.0)
	hud.update_stamina(50.0, 100.0)
	await process_frame
	for pair: Array in [["MP", mana_bar], ["HP", hp_bar], ["STA", stamina_bar]]:
		if pair[1] != null and not is_equal_approx(pair[1].modulate.a, 1.0):
			_fail("%s bar stayed dimmed after recovering: alpha %f" % [pair[0], pair[1].modulate.a])


func _wait_for_dim(hud: CanvasLayer, bar: ProgressBar) -> bool:
	for i in 120:
		await process_frame
		if bar != null and is_equal_approx(bar.modulate.a, PULSE_DIM):
			return true
	return false


func _finish() -> void:
	if _fails == 0:
		print("VERIFY_PASS: berserk hud")
		quit(0)
	else:
		print("VERIFY_FAIL: %d checks failed" % _fails)
		quit(1)
