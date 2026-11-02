extends SceneTree

const BASE_ATTACK: float = 20.0
const BASE_DEFENSE: float = 20.0
const DRAIN_INTERVAL_FRAMES: int = 30
const DRAIN_TOTAL_FRAMES: int = 180
const DRAIN_TOTAL_EXPECTED: int = 6
const CAST_LOCK_FRAMES: int = 30
const DASH_COOLDOWN_FRAMES: int = 30
const AURA_DELAY_FRAMES: int = 24
const AURA_HEIGHT: float = 1.6
const AURA_PIXEL_SIZE: float = 0.026
const AURA_ALPHA: float = 0.4
# Where the aura sits while the character stands: BERSERK_AURA_HEIGHT (1.0) in
# KingController plus HEIGHT (1.6) in BerserkAura. The aura follows the body exactly,
# so idle breathing carries it up by up to 0.23; it never drops below standing height.
const AURA_STANDING_Y: float = 2.6
const AURA_HEIGHT_MIN_DROP: float = 0.05
const AURA_HEIGHT_MAX_RISE: float = 0.35
# How far the aura's height may stray from the bone's height at the same instant.
# Following the character means matching it, not merely moving: this rejects both an
# inverted and a scaled-up offset. A little slack is needed because the test samples
# slightly off the frame the aura syncs on.
const AURA_TRACK_TOLERANCE: float = 0.25

var _fails: int = 0


func _initialize() -> void:
	_run()


func _wait_physics(frames: int) -> void:
	for i in frames:
		await physics_frame


func _make_king() -> Node3D:
	var kc: Node3D = load("res://scenes/run/KingController.tscn").instantiate()
	kc.position = Vector3.ZERO
	kc.set_play_field(8)
	kc.setup_king({
		"hp": 9999.0,
		"attack": BASE_ATTACK,
		"defense": BASE_DEFENSE,
		"mana_max": 200.0,
	})
	root.add_child(kc)
	return kc


func _aura(kc: Node3D) -> Node:
	return kc.get_node_or_null("BerserkAura")


func _wait_aura_gone(kc: Node3D) -> bool:
	# Deactivation fades the aura out over BERSERK_AURA_FADE, so give it a bounded
	# window to finish before deciding it is still there.
	for i in 120:
		if _aura(kc) == null:
			return true
		await process_frame
	return _aura(kc) == null


func _run() -> void:
	await process_frame

	var probe := _make_king()
	await process_frame
	var missing := _missing_api(probe)
	probe.queue_free()
	await process_frame
	if not missing.is_empty():
		_fail("KingController is missing the berserk API: %s" % ", ".join(missing))
		_finish()
		return

	await _check_activate_applies_buffs()
	await _check_deactivate_restores_buffs()
	await _check_dash_is_free_while_berserk()
	await _check_mana_drains_one_per_half_second()
	await _check_mana_zero_auto_deactivates()
	await _check_deactivate_is_idempotent()
	await _check_reactivate_does_not_compound()
	await _check_deactivate_while_frozen()
	await _check_aura_animates_and_blinks()
	await _check_aura_spawn_delay()
	await _check_aura_fade_out()
	await _check_aura_follows_animated_height()
	await _check_berserk_audio_starts_and_stops()

	_finish()


func _missing_api(kc: Node3D) -> Array:
	var missing: Array = []
	for method: String in ["request_berserk", "set_berserk"]:
		if not kc.has_method(method):
			missing.append(method)
	for prop: String in ["berserk_active"]:
		if kc.get(prop) == null:
			missing.append(prop)
	return missing


func _check_aura_animates_and_blinks() -> void:
	var kc := _make_king()
	await process_frame

	kc.request_berserk()
	await _wait_physics(AURA_DELAY_FRAMES + 2)
	var aura := _aura(kc)
	if aura == null:
		_fail("aura: never spawned, cannot check animation")
		kc.queue_free()
		await process_frame
		return
	var sprite: Sprite3D = aura.get_node_or_null("AuraSprite")

	if bool(aura.call("is_blinking")):
		_fail("aura: blinking at full MP")

	# The aura advances on idle frames, so sample on idle frames too: sampling on
	# physics frames can alias past every 0.15s step and read a constant index.
	var frames_seen: Array = []
	var distinct: Array = []
	for i in 120:
		await process_frame
		var f = aura.call("frame_index")
		if frames_seen.is_empty() or frames_seen[frames_seen.size() - 1] != f:
			frames_seen.append(f)
		if not distinct.has(f):
			distinct.append(f)
	if frames_seen.size() < 2:
		_fail("aura: frame never advanced (stuck on %s)" % [frames_seen])
	elif distinct.size() != int(aura.call("frame_count")):
		_fail("aura: cycled %s of %s frames" % [distinct.size(), aura.call("frame_count")])

	# The blink flag is only re-evaluated on the 0.5s MP drain tick, so poll for it
	# rather than sampling once, and hold mana low so the drain cannot end berserk.
	var became_blinking := false
	# Level boot takes ~5.3 s of real work (model prewarm, map gen, navmesh).
	for i in 600:
		kc.mana = kc.mana_max * 0.05
		await process_frame
		if bool(aura.call("is_blinking")):
			became_blinking = true
			break
	if not became_blinking:
		_fail("aura: not blinking at 5%% MP (mana %f of %f)" % [kc.mana, kc.mana_max])

	var vis_seen: Array = []
	for i in 120:
		kc.mana = kc.mana_max * 0.05
		await process_frame
		if sprite == null:
			break
		var v: bool = sprite.visible
		if vis_seen.is_empty() or vis_seen[vis_seen.size() - 1] != v:
			vis_seen.append(v)
	if vis_seen.size() < 2:
		_fail("aura: low-MP blink never toggled the sprite (visibility stayed %s)" % [vis_seen])

	kc.set_berserk(false)
	if not await _wait_aura_gone(kc):
		_fail("aura: not freed on deactivate")

	kc.queue_free()
	await process_frame


func _check_berserk_audio_starts_and_stops() -> void:
	var sfx: Node = root.get_node("/root/SFXManager")
	if not sfx.has_method("start_berserk_loop") or not sfx.has_method("stop_berserk_loop"):
		_fail("audio: SFXManager is missing the berserk loop API")
		return

	var kc := _make_king()
	await process_frame

	kc.request_berserk()
	await _wait_physics(2)
	if sfx.is_berserk_loop_playing():
		_fail("audio: loop started during delay")
	await _wait_physics(AURA_DELAY_FRAMES + 10)
	if not sfx.is_berserk_loop_playing():
		_fail("audio: loop not playing after delay")

	kc.set_berserk(false)
	await process_frame
	if sfx.is_berserk_loop_playing():
		_fail("audio: loop still playing after deactivate")

	sfx._on_berserk_loop_finished()
	await process_frame
	if sfx.is_berserk_loop_playing():
		_fail("audio: a trailing `finished` restarted the loop after deactivate")

	kc.request_berserk()
	await _wait_physics(AURA_DELAY_FRAMES + 10)
	sfx._on_berserk_loop_finished()
	await process_frame
	if not sfx.is_berserk_loop_playing():
		_fail("audio: loop did not restart on `finished` while still active")

	kc.set_berserk(false)
	await process_frame
	kc.queue_free()
	await process_frame


func _check_aura_spawn_delay() -> void:
	# The aura is held back so it lands as the roar finishes, rather than popping
	# on the same frame the skill is pressed.
	var kc := _make_king()
	await process_frame

	kc.request_berserk()
	await _wait_physics(2)
	if _aura(kc) != null:
		_fail("delay: aura spawned %d physics frames in, want it held until %d" % [2, AURA_DELAY_FRAMES])

	# Still nothing a little before the delay expires.
	await _wait_physics(AURA_DELAY_FRAMES - 6)
	if _aura(kc) != null:
		_fail("delay: aura spawned early (before %d frames)" % AURA_DELAY_FRAMES)

	await _wait_physics(10)
	if _aura(kc) == null:
		_fail("delay: aura never spawned after %d frames" % AURA_DELAY_FRAMES)
	else:
		var sprite: Sprite3D = _aura(kc).get_node_or_null("AuraSprite")
		if sprite == null:
			_fail("delay: spawned aura has no AuraSprite")
		elif not is_equal_approx(sprite.position.y, AURA_HEIGHT):
			_fail("delay: aura height = %f, want %f" % [sprite.position.y, AURA_HEIGHT])
		elif not is_equal_approx(sprite.pixel_size, AURA_PIXEL_SIZE):
			_fail("delay: aura pixel_size = %f, want %f" % [sprite.pixel_size, AURA_PIXEL_SIZE])
		elif not is_equal_approx(sprite.modulate.a, AURA_ALPHA):
			_fail("delay: aura alpha = %f, want %f" % [sprite.modulate.a, AURA_ALPHA])

	# The delay must not survive a deactivation inside the window.
	kc.set_berserk(false)
	await _wait_physics(2)
	if _aura(kc) != null and not bool(_aura(kc).call("is_fading")):
		_fail("delay: aura survived deactivation")
	if not await _wait_aura_gone(kc):
		_fail("delay: aura still around well after a mid-delay deactivation")
	kc.request_berserk()
	await _wait_physics(4)
	kc.set_berserk(false)
	await _wait_physics(AURA_DELAY_FRAMES + 10)
	if _aura(kc) != null:
		_fail("delay: aura spawned after being toggled off mid-delay")

	kc.queue_free()
	await process_frame


func _check_aura_fade_out() -> void:
	var kc := _make_king()
	await process_frame

	kc.request_berserk()
	await _wait_physics(AURA_DELAY_FRAMES + 2)
	var aura := _aura(kc)
	if aura == null:
		_fail("fade: aura never spawned")
		kc.queue_free()
		await process_frame
		return

	kc.set_berserk(false)
	await _wait_physics(2)
	if _aura(kc) == null:
		_fail("fade: aura was removed instantly instead of fading")
		kc.queue_free()
		await process_frame
		return
	if not bool(_aura(kc).call("is_fading")):
		_fail("fade: aura is still alive but not reporting is_fading()")

	# The alpha has to come down gradually, not snap to gone. Sample every idle
	# frame (the aura fades in _process) rather than a fixed count, so this does not
	# depend on the headless frame rate.
	var sprite: Sprite3D = _aura(kc).get_node_or_null("AuraSprite")
	var start_alpha: float = sprite.modulate.a
	var saw_drop := false
	var saw_partial := false
	for i in 60:
		await process_frame
		if _aura(kc) == null or sprite == null:
			break
		var a: float = sprite.modulate.a
		if a < start_alpha:
			saw_drop = true
		if a > 0.0 and a < start_alpha:
			saw_partial = true
	if not saw_drop:
		_fail("fade: alpha never dropped below %f while fading" % start_alpha)
	elif not saw_partial:
		_fail("fade: alpha jumped straight from %f to gone with no partial value" % start_alpha)

	for i in 40:
		await process_frame
		if _aura(kc) == null:
			break
	if _aura(kc) != null:
		_fail("fade: aura was never freed after the fade")

	# Re-activating mid-fade must not leave two auras stacked on each other.
	kc.request_berserk()
	await _wait_physics(AURA_DELAY_FRAMES + 2)
	kc.set_berserk(false)
	await _wait_physics(3)
	kc.request_berserk()
	await _wait_physics(AURA_DELAY_FRAMES + 2)
	var stacked := 0
	for child in kc.get_children():
		if child.name == "BerserkAura":
			stacked += 1
	if stacked != 1:
		_fail("fade: %d aura nodes after re-activating mid-fade, want 1" % stacked)

	# Leave nothing running: an active berserk would keep the SFX loop alive and
	# bleed into the audio check that follows.
	kc.set_berserk(false)
	await _wait_aura_gone(kc)
	kc.queue_free()
	await process_frame


func _finish() -> void:
	if _fails == 0:
		print("VERIFY_PASS: berserk skill")
		quit(0)
	else:
		print("VERIFY_FAIL: %d checks failed" % _fails)
		quit(1)


func _check_activate_applies_buffs() -> void:
	var kc := _make_king()
	await process_frame

	var hp_before: float = kc.king_hp
	kc.take_damage(100.0)
	var base_taken: float = hp_before - kc.king_hp

	kc.request_berserk()
	await _wait_physics(AURA_DELAY_FRAMES + 2)

	if not bool(kc.get("berserk_active")):
		_fail("activate: berserk_active is false right after request_berserk()")
	if not is_equal_approx(float(kc.get("king_attack")), BASE_ATTACK * 1.5):
		_fail("activate: attack = %s want %f" % [kc.get("king_attack"), BASE_ATTACK * 1.5])
	if _aura(kc) == null:
		_fail("activate: BerserkAura node was not added")
	elif int(_aura(kc).call("frame_count")) != 4:
		_fail("activate: aura loaded %s frames, want 4" % _aura(kc).call("frame_count"))
	else:
		var sprite: Sprite3D = _aura(kc).get_node_or_null("AuraSprite")
		if sprite == null:
			_fail("activate: aura has no AuraSprite")
		elif sprite.texture == null:
			_fail("activate: aura sprite has no texture")
		elif sprite.billboard != BaseMaterial3D.BILLBOARD_ENABLED:
			_fail("activate: aura sprite is not billboarded")

	kc.king_hp = hp_before
	kc.take_damage(100.0)
	var berserk_taken: float = hp_before - kc.king_hp
	var want_taken: float = ProgressionData.armor_damage(100.0, BASE_DEFENSE * 1.5)
	if not is_equal_approx(berserk_taken, want_taken):
		_fail("activate: defense buff not applied, took %f want %f (unbuffed took %f)" % [
			berserk_taken, want_taken, base_taken
		])
	if berserk_taken >= base_taken:
		_fail("activate: defense did not reduce damage taken (%f vs unbuffed %f)" % [berserk_taken, base_taken])

	kc.queue_free()
	await process_frame


func _check_deactivate_restores_buffs() -> void:
	var kc := _make_king()
	await process_frame

	kc.request_berserk()
	await process_frame
	kc.set_berserk(false)
	await process_frame

	if bool(kc.get("berserk_active")):
		_fail("deactivate: berserk_active still true")
	if not is_equal_approx(float(kc.get("king_attack")), BASE_ATTACK):
		_fail("deactivate: attack = %s want %f" % [kc.get("king_attack"), BASE_ATTACK])
	if not is_equal_approx(float(kc.get("king_defense")), BASE_DEFENSE):
		_fail("deactivate: defense = %s want %f" % [kc.get("king_defense"), BASE_DEFENSE])
	if _aura(kc) != null:
		_fail("deactivate: BerserkAura node was not removed")

	kc.queue_free()
	await process_frame


func _check_dash_is_free_while_berserk() -> void:
	var kc := _make_king()
	await process_frame

	kc.stamina = 0.0
	kc.request_dash()
	await process_frame
	if float(kc.get("_dash_timer")) > 0.0:
		_fail("dash control: dash started at 0 stamina without berserk")
	await _wait_physics(CAST_LOCK_FRAMES + 5)

	kc.request_berserk()
	await process_frame
	await _wait_physics(CAST_LOCK_FRAMES + 5)

	kc.stamina = 0.0
	kc.request_dash()
	await process_frame

	if float(kc.get("_dash_timer")) <= 0.0:
		_fail("dash: berserk dash did not start at 0 stamina")
	if kc.stamina < 0.0:
		_fail("dash: berserk dash drove stamina negative (%f)" % kc.stamina)

	kc.set_berserk(false)
	await _wait_physics(DASH_COOLDOWN_FRAMES)
	kc.stamina = 0.0
	kc.request_dash()
	await process_frame
	if float(kc.get("_dash_timer")) > 0.0:
		_fail("dash: dash still free after berserk ended")

	kc.queue_free()
	await process_frame


func _check_mana_drains_one_per_half_second() -> void:
	var kc := _make_king()
	await process_frame

	kc.request_berserk()
	await process_frame
	var start_mana: float = kc.mana

	await _wait_physics(12)
	if not is_equal_approx(kc.mana, start_mana):
		_fail("drain: mana changed after 0.2s (got %f want %f) - drains more than once per 0.5s" % [
			kc.mana, start_mana
		])

	await _wait_physics(DRAIN_TOTAL_FRAMES - 12)
	var drained: float = start_mana - kc.mana
	if absf(drained - DRAIN_TOTAL_EXPECTED) > 1.0:
		_fail("drain: %.1fs drained %f MP, want ~%d MP (1 per 0.5s)" % [
			DRAIN_TOTAL_FRAMES / 60.0, drained, DRAIN_TOTAL_EXPECTED
		])

	if not bool(kc.get("berserk_active")):
		_fail("drain: berserk deactivated while mana was still %f" % kc.mana)

	kc.set_berserk(false)
	kc.queue_free()
	await process_frame


func _check_mana_zero_auto_deactivates() -> void:
	var kc := _make_king()
	await process_frame

	kc.mana = 0.5
	kc.request_berserk()
	await process_frame
	if bool(kc.get("berserk_active")):
		_fail("low mana: activated below the 1 MP minimum (mana = %f)" % kc.mana)
	kc.queue_free()
	await process_frame

	kc = _make_king()
	await process_frame
	kc.request_berserk()
	await process_frame
	kc.mana = 1.0
	await _wait_physics(DRAIN_INTERVAL_FRAMES + 5)

	if bool(kc.get("berserk_active")):
		_fail("auto-deactivate: still active after mana reached 0")
	if kc.mana < 0.0:
		_fail("auto-deactivate: mana went negative (%f)" % kc.mana)
	if not is_equal_approx(float(kc.get("king_attack")), BASE_ATTACK):
		_fail("auto-deactivate: attack = %s want %f" % [kc.get("king_attack"), BASE_ATTACK])
	if not await _wait_aura_gone(kc):
		_fail("auto-deactivate: BerserkAura node still present")

	kc.queue_free()
	await process_frame


func _check_deactivate_is_idempotent() -> void:
	var kc := _make_king()
	await process_frame

	kc.request_berserk()
	await process_frame
	kc.set_berserk(false)
	await process_frame
	kc.set_berserk(false)
	await process_frame

	if bool(kc.get("berserk_active")):
		_fail("idempotent: berserk_active true after double deactivate")
	if not is_equal_approx(float(kc.get("king_attack")), BASE_ATTACK):
		_fail("idempotent: attack = %s want %f" % [kc.get("king_attack"), BASE_ATTACK])
	if not is_equal_approx(float(kc.get("king_defense")), BASE_DEFENSE):
		_fail("idempotent: defense = %s want %f" % [kc.get("king_defense"), BASE_DEFENSE])

	kc.queue_free()
	await process_frame


func _check_reactivate_does_not_compound() -> void:
	var kc := _make_king()
	await process_frame

	for cycle in 3:
		kc.request_berserk()
		await process_frame
		if not is_equal_approx(float(kc.get("king_attack")), BASE_ATTACK * 1.5):
			_fail("cycle %d: attack = %s want %f (buff compounded)" % [
				cycle, kc.get("king_attack"), BASE_ATTACK * 1.5
			])
		kc.set_berserk(false)
		await process_frame
		if not is_equal_approx(float(kc.get("king_attack")), BASE_ATTACK):
			_fail("cycle %d: attack after off = %s want %f" % [cycle, kc.get("king_attack"), BASE_ATTACK])

	kc.queue_free()
	await process_frame


func _check_deactivate_while_frozen() -> void:
	var kc := _make_king()
	await process_frame

	kc.request_berserk()
	await process_frame
	kc.frozen = true
	kc.set_berserk(false)
	await process_frame

	if bool(kc.get("berserk_active")):
		_fail("frozen: berserk_active still true")
	if not is_equal_approx(float(kc.get("king_attack")), BASE_ATTACK):
		_fail("frozen: attack = %s want %f" % [kc.get("king_attack"), BASE_ATTACK])
	if _aura(kc) != null:
		_fail("frozen: BerserkAura node still present")

	kc.frozen = false
	kc.queue_free()
	await process_frame


func _check_aura_follows_animated_height() -> void:
	# The character is animated through a skeleton, and the Hips bone is what carries
	# his body up and down (earth_quake lifts then slams him, a 0.72 world unit
	# swing). The aura is parented to the controller, whose origin never moves, so
	# without an explicit link the aura stays behind at a fixed height.
	var kc := _make_king()
	await process_frame
	kc.mana = 200.0
	kc.request_berserk()
	for i in 30:
		await physics_frame
	var aura = _aura(kc)
	if aura == null:
		_fail("height: no aura spawned to test against")
		kc.queue_free()
		await process_frame
		return
	var sprite: Sprite3D = aura.get_node("AuraSprite")
	# The character is animated through a skeleton, so "following his height" means
	# matching the Hips bone. Comparing the aura against the bone at the same instants
	# catches an inverted or scaled offset, which a swing check alone cannot.
	var skel: Skeleton3D = kc.get("_model").find_child("Skeleton3D", true, false) as Skeleton3D
	var bone: int = skel.find_bone("Hips")

	# Settle on the standing height, which is what the aura offset is tuned against.
	# The aura and the bone are read on the same frame so the deltas line up.
	for i in 20:
		await process_frame
	var base_y: float = sprite.global_position.y
	var hips_y: float = (skel.global_transform * skel.get_bone_global_pose(bone)).origin.y
	# Pin the resting height in absolute terms. Comparing only to base_y would accept
	# any constant error, since a wrong-but-stable offset cancels itself out.
	if base_y < AURA_STANDING_Y - AURA_HEIGHT_MIN_DROP or base_y > AURA_STANDING_Y + AURA_HEIGHT_MAX_RISE:
		_fail("height: standing aura_y = %f, want %f in [%f, %f]" % [
			base_y, AURA_STANDING_Y, AURA_STANDING_Y - AURA_HEIGHT_MIN_DROP,
			AURA_STANDING_Y + AURA_HEIGHT_MAX_RISE])

	kc.request_earthquake()
	var lo: float = sprite.global_position.y
	var hi: float = sprite.global_position.y
	var max_dev: float = 0.0
	for i in 90:
		await process_frame
		lo = minf(lo, sprite.global_position.y)
		hi = maxf(hi, sprite.global_position.y)
		var hy: float = (skel.global_transform * skel.get_bone_global_pose(bone)).origin.y
		max_dev = maxf(max_dev, absf((sprite.global_position.y - base_y) - (hy - hips_y)))
	var swing: float = hi - lo
	if swing < 0.4:
		_fail("height: aura did not follow the animated character (swing %f over earth_quake, want >= 0.4)" % swing)
	if max_dev > AURA_TRACK_TOLERANCE:
		_fail("height: aura height strayed %f from the character's height, want <= %f" % [max_dev, AURA_TRACK_TOLERANCE])

	# Following must not accumulate. Idle breathing moves the aura within its band, so
	# the settled height is checked against that band rather than against one sample.
	for i in 60:
		await process_frame
	var settled: float = sprite.global_position.y
	if settled < AURA_STANDING_Y - AURA_HEIGHT_MIN_DROP or settled > AURA_STANDING_Y + AURA_HEIGHT_MAX_RISE:
		_fail("height: aura settled at %f after the animation, outside the standing band [%f, %f]" % [
			settled, AURA_STANDING_Y - AURA_HEIGHT_MIN_DROP, AURA_STANDING_Y + AURA_HEIGHT_MAX_RISE])

	kc.set_berserk(false)
	await _wait_aura_gone(kc)
	kc.queue_free()
	await process_frame


func _fail(msg: String) -> void:
	_fails += 1
	print("CHECK FAIL: " + msg)
