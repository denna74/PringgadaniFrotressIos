extends SceneTree

# Boss skill clips must reach their rigs, trigger only for the boss that declares them,
# respect cooldowns and survive neither enemy pooling nor model fallback.

var _fails: int = 0
var _inv: Node = null
const ARROW_SCRIPT: GDScript = preload("res://scenes/projectiles/arrow_projectile.gd")


func _initialize() -> void:
	_run()


func _fail(msg: String) -> void:
	_fails += 1
	print("CHECK FAIL: " + msg)


func _run() -> void:
	await process_frame

	_inv = load("res://scenes/run/InvasionManager.gd").new()
	root.add_child(_inv)

	_check_boss_rigs_keep_their_clips()
	_check_boma_attack_pose_facing()
	_check_karna_attack1_facing()
	_check_boss_attack_slash_appearance()
	_check_attack_anim_excludes_dash()
	_check_boss_stamina_curves()
	_check_kalapracona_attack_timing()
	_check_melee_attack_timing()
	_check_freed_pending_attack_target()
	await _check_boma_projectiles()
	await _check_special_requires_boss()
	await _check_aswatama_earthquake()
	await _check_karna_earthquake()
	_check_dash_only_in_range()
	_check_dash_movement()
	_check_boma_dash()
	_check_ai_triggers_dash()
	_check_cooldowns_gate_special()
	_check_pooled_state_is_reset()

	if _inv != null:
		_inv.free()
	if _fails == 0:
		print("VERIFY_PASS: boss specials")
		quit(0)
	else:
		print("VERIFY_FAIL: %d checks failed" % _fails)
		quit(1)


# Regression guard for the inverted cache lookup in ModelLoader.load_boss(): asking for a
# rig that had never been built resolved to "kurawa", so every non-kurawa boss spawned as
# the miniboss rig and lost its own skill clips.
func _check_boss_rigs_keep_their_clips() -> void:
	for rig in ["kurawa", "boma", "aswatama", "karna"]:
		var paths: Dictionary = ModelLoader.boss_animation_paths(rig)
		for key in paths:
			var clip_path: String = str(paths[key])
			if not ResourceLoader.exists(clip_path):
				_fail("%s: %s clip missing on disk: %s" % [rig, key, clip_path])

		var model: Node3D = ModelLoader.load_boss(rig)
		var anim_player: AnimationPlayer = ModelLoader.find_animation_player(model)
		if anim_player == null:
			_fail("%s boss model has no AnimationPlayer" % rig)
			continue
		for key: String in paths:
			if not anim_player.has_animation("boss/" + key):
				_fail("%s boss model is missing the boss/%s clip" % [rig, key])

	# Every boss declared in the registry must round-trip to its own rig. Without this,
	# Aswatama and Boma both silently render as the kurawa miniboss.
	for boss_id: String in BossRegistry.boss_ids():
		var rig: String = BossRegistry.model_rig(boss_id)
		var model: Node3D = ModelLoader.load_boss(rig)
		var anim_player: AnimationPlayer = ModelLoader.find_animation_player(model)
		if anim_player == null:
			continue
		if not anim_player.has_animation("boss/idle"):
			_fail("boss %s (rig %s) did not build its own model" % [boss_id, rig])

	var karna_data: Dictionary = EnemySpawner.spawn_boss(1, 251, 30, BossRegistry.KARNA)
	var attack_anim: String = _inv._attack_anim_for(karna_data)
	if attack_anim not in ["boss/attack", "boss/attack_2", "boss/attack_3"]:
		_fail("Karna selected an unavailable attack animation: %s" % attack_anim)

	# These bosses must retain their own skill clips, rather than silently falling back
	# to the Kurawa miniboss rig.
	var aswatama: Node3D = ModelLoader.load_boss(BossRegistry.model_rig(BossRegistry.ASWATAMA))
	var aswatama_player: AnimationPlayer = ModelLoader.find_animation_player(aswatama)
	if aswatama_player == null or not aswatama_player.has_animation("boss/earthquake"):
		_fail("Aswatama cannot play its earthquake rig animation")
	elif aswatama_player.get_animation("boss/earthquake").length < 3.1 \
			or aswatama_player.get_animation("boss/earthquake").length >= 3.2:
		_fail(
			"Aswatama earthquake should be trimmed to about half its original length, got %.3fs"
			% aswatama_player.get_animation("boss/earthquake").length
		)
	var karna: Node3D = ModelLoader.load_boss(BossRegistry.model_rig(BossRegistry.KARNA))
	var karna_player: AnimationPlayer = ModelLoader.find_animation_player(karna)
	for clip in ["attack_2", "attack_3", "dash", "earthquake", "berserk"]:
		if karna_player == null or not karna_player.has_animation("boss/" + clip):
			_fail("Karna cannot play boss/%s" % clip)
	if karna_player != null and karna_player.has_animation("boss/attack_3"):
		var attack_3_length: float = karna_player.get_animation("boss/attack_3").length
		if attack_3_length < 1.55 or attack_3_length >= 1.6:
			_fail(
				"Karna attack_3 should be trimmed to about half its original length, got %.3fs"
				% attack_3_length
			)


# "dash" is a movement clip, so it must never be chosen as an attack animation.
func _check_attack_anim_excludes_dash() -> void:
	var boss_dash: Dictionary = {"is_boss": true, "special": "dash"}
	if _inv._attack_anim_for(boss_dash) != "boss/attack":
		_fail("a dashing boss should still use boss/attack, got %s" % _inv._attack_anim_for(boss_dash))

	var boma: Dictionary = {"is_boss": true, "special": "power_attack"}
	if _inv._attack_anim_for(boma) != "boss/attack":
		_fail("Boma should use its ordinary attack pose by default")
	if _inv._attack_anim_for(boma, true) != "boss/power_attack":
		_fail("Boma power attack should use its dedicated pose")

	var infantry: Dictionary = {"is_boss": false, "special": ""}
	if _inv._attack_anim_for(infantry) != "enemy/attack":
		_fail("infantry attack anim wrong, got %s" % _inv._attack_anim_for(infantry))


func _check_boss_attack_slash_appearance() -> void:
	for boss_id: String in [BossRegistry.ASWATAMA, BossRegistry.KARNA]:
		var data: Dictionary = EnemySpawner.spawn_boss(1, 1, 1, boss_id)
		var enemy := _make_enemy(data, BossRegistry.model_rig(boss_id))
		enemy.global_rotation.y = PI / 2.0
		_inv._spawn_boss_attack_slash(enemy, data, "boss/attack")
		var slash := enemy.get_node_or_null("BossAttackArcSlash")
		if slash == null:
			_fail("%s did not spawn its attack crescent" % boss_id)
			continue
		if slash.get("slash_color") != Color(1.0, 0.12, 0.08, 0.9):
			_fail("%s attack crescent is not red" % boss_id)
		var attacker_forward := Vector3(
			sin(enemy.global_rotation.y), 0.0, cos(enemy.global_rotation.y)
		)
		var slash_forward := Vector3(
			sin(slash.global_rotation.y), 0.0, cos(slash.global_rotation.y)
		)
		if slash_forward.dot(attacker_forward) < 0.99:
			_fail("%s crescent does not face straight forward from the attacker" % boss_id)
		if (slash.global_position - enemy.global_position).dot(attacker_forward) <= 0.0:
			_fail("%s crescent did not spawn in front of the attacker" % boss_id)
		await process_frame
		var quad := slash.get("_quad") as MeshInstance3D
		if quad == null:
			_fail("%s attack crescent did not build its mesh" % boss_id)
		slash.queue_free()

	var karna_data: Dictionary = EnemySpawner.spawn_boss(1, 1, 1, BossRegistry.KARNA)
	var karna := _make_enemy(karna_data, "karna")
	_inv._spawn_boss_attack_slash(karna, karna_data, "boss/attack_3")
	if karna.get_node_or_null("BossAttackArcSlash") != null:
		_fail("Karna attack_3 should replace the crescent with a circle wave")
	var circle_wave := karna.get_node_or_null("BossAttackCircleWave")
	if circle_wave == null:
		_fail("Karna attack_3 did not spawn its circle wave")
	else:
		if circle_wave.get("wave_color") != Color(1.0, 0.12, 0.08, 0.9):
			_fail("Karna attack_3 circle wave is not red")
		await process_frame
		var wave_ring := circle_wave.get("_ring") as MeshInstance3D
		if wave_ring == null or wave_ring.mesh == null:
			_fail("Karna attack_3 circle wave did not build its ring mesh")
		circle_wave.queue_free()

	var kalapracona_data: Dictionary = EnemySpawner.spawn_boss(
		1, 1, 1, BossRegistry.KALAPRACONA
	)
	var kalapracona := _make_enemy(kalapracona_data, "kurawa")
	_inv._spawn_boss_attack_slash(kalapracona, kalapracona_data)
	if kalapracona.get_node_or_null("BossAttackArcSlash") != null:
		_fail("Kalapracona should not spawn a crescent on its attack")


func _check_boss_stamina_curves() -> void:
	for id in [BossRegistry.BOMA, BossRegistry.ASWATAMA, BossRegistry.KARNA]:
		var start: float = 45.0 if id == BossRegistry.BOMA else (
			50.0 if id == BossRegistry.ASWATAMA else 75.0
		)
		var finish: float = 180.0 if id == BossRegistry.BOMA else (
			200.0 if id == BossRegistry.ASWATAMA else 250.0
		)
		var data_start: Dictionary = EnemySpawner.spawn_boss(1, 1, 1, id)
		var data_finish: Dictionary = EnemySpawner.spawn_boss(1, 250, 1, id)
		if not is_equal_approx(float(data_start["stamina_max"]), start):
			_fail("%s stage 1 stamina was %s, expected %s" % [id, data_start["stamina_max"], start])
		if not is_equal_approx(float(data_finish["stamina_max"]), finish):
			_fail("%s stage 250 stamina was %s, expected %s" % [id, data_finish["stamina_max"], finish])
	var boma_start: Dictionary = EnemySpawner.spawn_boss(1, 1, 1, BossRegistry.BOMA)
	var boma_finish: Dictionary = EnemySpawner.spawn_boss(1, 250, 1, BossRegistry.BOMA)
	if not is_equal_approx(float(boma_start["mana_max"]), 32.0) \
			or not is_equal_approx(float(boma_finish["mana_max"]), 330.0):
		_fail("Boma MP should scale from 32 at stage 1 to 330 at stage 250")
	var karna_start: Dictionary = EnemySpawner.spawn_boss(1, 1, 1, BossRegistry.KARNA)
	var karna_finish: Dictionary = EnemySpawner.spawn_boss(1, 250, 1, BossRegistry.KARNA)
	if not is_equal_approx(float(karna_start["mana_max"]), 35.0) \
			or not is_equal_approx(float(karna_finish["mana_max"]), 350.0):
		_fail("Karna MP should scale from 35 at stage 1 to 350 at stage 250")
	var aswatama_start: Dictionary = EnemySpawner.spawn_boss(1, 1, 1, BossRegistry.ASWATAMA)
	var aswatama_finish: Dictionary = EnemySpawner.spawn_boss(1, 250, 1, BossRegistry.ASWATAMA)
	if not is_equal_approx(float(aswatama_start["mana_max"]), 30.0) \
			or not is_equal_approx(float(aswatama_finish["mana_max"]), 310.0):
		_fail("Aswatama MP should scale from 30 at stage 1 to 310 at stage 250")


func _check_boma_projectiles() -> void:
	var target := _make_target(Vector3(0.0, 0.0, 8.0))
	var data: Dictionary = {
		"is_boss": true,
		"boss_id": BossRegistry.BOMA,
		"special": "power_attack",
		"arrow_style": "boma_red",
		"ranged": true,
		"attack": 10.0,
		"mana_max": 25.0,
	}
	var enemy := _make_enemy(data, "boma")
	enemy.set_meta("boss_power_attack_cd", 1.0)
	_inv._king_ref = target
	_inv._try_enemy_attack(enemy, data, 0.016)
	if _last_arrow() != null:
		_fail("Boma's ordinary shot fired before its attack animation reached impact")
	var normal_hit_delay: float = float(
		enemy.get_meta("pending_enemy_attack", {}).get("timer", 0.0)
	)
	var normal_animation_length: float = _inv._enemy_animation_length(enemy, "boss/attack", 0.0)
	if not is_equal_approx(
		normal_hit_delay,
		_inv._animation_impact_delay(normal_animation_length)
	):
		_fail("Boma's ordinary shot is not timed to 50% of the attack animation")
	_inv._tick_pending_enemy_attack(enemy, normal_hit_delay)
	var normal: Node3D = _last_arrow()
	if normal == null:
		_fail("Boma's ordinary attack did not create an arrow at its impact frame")
		return
	if normal.call("get_arrow_style") != "normal" or normal.call("has_power_aura"):
		_fail("Boma's ordinary shot should be a normal arrow without an aura")
	if not is_equal_approx(float(enemy.get_meta("boss_mana")), 25.0):
		_fail("Boma's ordinary arrow should not spend MP")
	normal.call("_release")
	await process_frame

	var test_camera := Camera3D.new()
	root.add_child(test_camera)
	test_camera.current = true
	enemy.set_meta("attack_cooldown", 0.0)
	enemy.set_meta("boss_power_attack_cd", 0.0)
	_inv._try_enemy_attack(enemy, data, 0.016)
	if _last_arrow() != null:
		_fail("Boma's power shot fired before its attack animation reached impact")
	var power_hit_delay: float = float(
		enemy.get_meta("pending_enemy_attack", {}).get("timer", 0.0)
	)
	var power_animation_length: float = _inv._enemy_animation_length(
		enemy, "boss/power_attack", 0.0
	)
	if not is_equal_approx(
		power_hit_delay,
		power_animation_length
	):
		_fail("Boma's power shot is not timed to the end of its attack animation")
	_inv._tick_pending_enemy_attack(enemy, power_hit_delay)
	var powered: Node3D = _last_arrow()
	if powered == null:
		_fail("Boma's power attack did not create an arrow")
		return
	if powered.call("get_arrow_style") != "boma_red":
		_fail("Boma's power shot should use a red arrow")
	if not powered.call("has_power_aura"):
		_fail("Boma's power shot has no aura trail")
	if not _is_sfx_playing("power_attack"):
		_fail("Boma's power arrow did not play its launch SFX")
	if not is_equal_approx(float(enemy.get_meta("boss_mana")), 20.0):
		_fail("Boma's power arrow should spend 20% of its MP")
	if powered.has_method("get_arrow_style") \
			and powered.get_parent() == null:
		_fail("Boma's power arrow should remain in the gameplay tree while flying")
	powered.call("_release")
	test_camera.free()


func _check_melee_attack_timing() -> void:
	var data: Dictionary = {
		"is_boss": false,
		"type": "infantry",
		"attack": 12.0,
	}
	var enemy := _make_enemy(data, "enemy_infantry")
	var target := _make_target(Vector3(0.0, 0.0, 1.5))
	_inv._king_ref = target
	_inv._try_enemy_attack(enemy, data, 0.016)
	if target.hits != 0:
		_fail("melee enemy dealt damage before its attack animation impact frame")
	var animation_length: float = _inv._enemy_animation_length(enemy, "enemy/attack", 0.0)
	var expected_delay: float = animation_length * 0.5
	var actual_delay: float = float(
		enemy.get_meta("pending_enemy_attack", {}).get("timer", 0.0)
	)
	if not is_equal_approx(actual_delay, expected_delay):
		_fail("melee enemy damage is not timed to 50% of the attack animation")
	_inv._tick_pending_enemy_attack(enemy, actual_delay)
	if target.hits != 1:
		_fail("melee enemy did not deal damage on its impact frame")
	target.free()

	var dodging_enemy := _make_enemy(data, "enemy_infantry")
	var dodging_target := _make_target(Vector3(0.0, 0.0, 1.5))
	_inv._king_ref = dodging_target
	_inv._try_enemy_attack(dodging_enemy, data, 0.016)
	var dodge_delay: float = float(
		dodging_enemy.get_meta("pending_enemy_attack", {}).get("timer", 0.0)
	)
	dodging_target.position = Vector3(0.0, 0.0, 5.0)
	_inv._tick_pending_enemy_attack(dodging_enemy, dodge_delay)
	if dodging_target.hits != 0:
		_fail("Gatotkaca still took a melee hit after dashing out of range")


func _check_kalapracona_attack_timing() -> void:
	var data: Dictionary = EnemySpawner.spawn_boss(1, 1, 1, BossRegistry.KALAPRACONA)
	var enemy := _make_enemy(data, "kurawa")
	var target := _make_target(Vector3(0.0, 0.0, 2.5))
	_inv._king_ref = target
	if not is_equal_approx(_inv._enemy_standoff(data), 3.0):
		_fail("Kalapracona's melee reach is not 3 units")
	_inv._try_enemy_attack(enemy, data, 0.016)
	var pending: Dictionary = enemy.get_meta("pending_enemy_attack", {})
	if not is_equal_approx(float(pending.get("standoff", 0.0)), 3.0):
		_fail("Kalapracona's attack does not use a 3-unit hit reach")
	var attack_length: float = _inv._enemy_animation_length(enemy, "boss/attack", 0.0)
	var hit_delay: float = float(
		enemy.get_meta("pending_enemy_attack", {}).get("timer", 0.0)
	)
	if not is_equal_approx(hit_delay, attack_length * 0.4):
		_fail("Kalapracona's hit is not timed to 40% of its attack animation")
	_inv._tick_pending_enemy_attack(enemy, hit_delay)
	if target.hits != 1:
		_fail("Kalapracona did not hit at its 40% attack timing")
	target.free()
	if not is_equal_approx(_inv._enemy_standoff({"is_boss": false}), 2.0):
		_fail("regular infantry melee range changed when extending boss reach")


func _check_freed_pending_attack_target() -> void:
	var data: Dictionary = {"is_boss": false, "type": "infantry", "attack": 12.0}
	var enemy := _make_enemy(data, "enemy_infantry")
	var target := _make_target(Vector3(0.0, 0.0, 1.5))
	_inv._king_ref = target
	_inv._try_enemy_attack(enemy, data, 0.016)
	var hit_delay: float = float(
		enemy.get_meta("pending_enemy_attack", {}).get("timer", 0.0)
	)
	target.free()
	_inv._tick_pending_enemy_attack(enemy, hit_delay)
	_inv._king_ref = null


func _last_arrow() -> Node3D:
	var found: Node3D = null
	for child in root.find_children("*", "Node3D", true, false):
		if child is Node3D and child.get_script() == ARROW_SCRIPT and child.visible:
			found = child
	return found


func _check_boma_attack_pose_facing() -> void:
	var root_node := Node3D.new()
	root_node.set_meta("boss_rig", "boma")
	var library := AnimationLibrary.new()
	var attack := Animation.new()
	var track: int = attack.add_track(Animation.TYPE_ROTATION_3D)
	attack.track_set_path(track, NodePath("Skeleton3D:Hips"))
	attack.rotation_track_insert_key(track, 0.0, Quaternion.IDENTITY)
	ModelLoader._copy_animation(root_node, library, "power_attack", attack)
	var corrected: Quaternion = library.get_animation("power_attack").track_get_key_value(0, 0)
	if not is_equal_approx(corrected.get_euler().y, deg_to_rad(-90.0)):
		_fail("Boma's power attack pose was not turned toward its arrow")
	root_node.free()


func _check_karna_attack1_facing() -> void:
	var model: Node3D = ModelLoader.load_boss(BossRegistry.model_rig(BossRegistry.KARNA))
	root.add_child(model)
	var anim_player: AnimationPlayer = ModelLoader.find_animation_player(model)
	if anim_player == null or not anim_player.has_animation("boss/attack"):
		_fail("Karna's attack_1 animation is unavailable for facing validation")
	else:
		anim_player.play("boss/attack")
		anim_player.seek(0.0, true)
		if not is_equal_approx(model.rotation.y, deg_to_rad(-90.0)):
			_fail(
				"Karna's attack_1 did not rotate the full character root 90 degrees left "
				+ "(rotation.y = %.3f)" % model.rotation.y
			)
	model.queue_free()


func _check_special_requires_boss() -> void:
	var enemy := _make_enemy({"is_boss": false, "special": "dash"})
	_inv._try_boss_special(enemy, {"is_boss": false, "special": "dash"})
	if enemy.get_meta("boss_dash_timer", 0.0) != 0.0:
		_fail("a non-boss triggered the boss dash special")

	var no_special := _make_enemy({"is_boss": true, "special": ""})
	_inv._try_boss_special(no_special, {"is_boss": true, "special": ""})
	if no_special.get_meta("boss_dash_timer", 0.0) != 0.0:
		_fail("a boss without a special triggered the dash")

	await _check_karna_berserk()


func _check_karna_berserk() -> void:
	var data: Dictionary = {
		"is_boss": true,
		"special": "dash",
		"specials": ["dash", "earthquake", "berserk"],
		"stamina_max": 75.0,
		"mana_max": 35.0,
	}
	var karna := _make_enemy(data, "karna")
	karna.set_meta("current_health", 40.0)
	karna.set_meta("max_health", 100.0)
	_inv._try_boss_special(karna, data)
	await process_frame
	if not karna.get_meta("boss_berserk_active", false):
		_fail("Karna did not activate berserk below half health")
	if not is_equal_approx(float(karna.get_meta("boss_mana")), 17.5):
		_fail("Karna's berserk did not spend 50% of its MP")
	if karna.get_node_or_null("BossBerserkAura") == null:
		_fail("Karna did not show its berserk aura")
	else:
		var aura: Node = karna.get_node("BossBerserkAura")
		var frames: Array = aura.get("_frames")
		if frames.size() != 4:
			_fail("Karna's berserk aura did not load four frames")
		else:
			for texture: Texture2D in frames:
				if not texture.resource_path.ends_with("_red.png"):
					_fail("Karna's berserk aura should use red frames")
					break
	var anim_player: AnimationPlayer = ModelLoader.find_animation_player(karna)
	if anim_player == null or anim_player.current_animation != "boss/berserk":
		_fail("Karna did not play its berserk animation")


func _check_karna_earthquake() -> void:
	var data: Dictionary = {
		"is_boss": true,
		"special": "dash",
		"specials": ["dash", "earthquake", "berserk"],
		"attack": 20.0,
		"stamina_max": 75.0,
		"mana_max": 35.0,
	}
	var karna := _make_enemy(data, "karna")
	_inv._king_ref = _make_target(Vector3(2.0, 0.0, 0.0))
	_stop_sfx_playback()
	_inv._try_boss_special(karna, data)
	if karna.get_meta("boss_quake_cd", 0.0) <= 0.0:
		_fail("Karna did not trigger earthquake inside close range")
	var anim_player: AnimationPlayer = ModelLoader.find_animation_player(karna)
	if anim_player == null or anim_player.current_animation != "boss/earthquake":
		_fail("Karna did not play its earthquake rig animation")
	if (_inv._king_ref as Damageable).hits != 0:
		_fail("Karna's earthquake dealt damage before its animation impact frame")
	if root.get_node_or_null("BossEarthquakeEffect") != null:
		_fail("Karna's earthquake effect started before its animation impact frame")
	var quake_hit_delay: float = float(karna.get_meta("boss_quake_timer", 0.0))
	var quake_length: float = _inv._enemy_animation_length(karna, "boss/earthquake", 0.0)
	if not is_equal_approx(quake_hit_delay, _inv._animation_impact_delay(quake_length)):
		_fail("Karna's earthquake is not timed to 50% of its animation")
	if float(karna.get_meta("attack_cooldown", 0.0)) < quake_length + 0.99:
		_fail("Karna followed earthquake with a melee attack without a recovery delay")
	if _is_sfx_playing("earth_quake_skill"):
		_fail("Karna's earthquake SFX started before the ground effect")
	_inv._tick_pending_boss_earthquake(karna, quake_hit_delay)
	if not _is_sfx_playing("earth_quake_skill"):
		_fail("Karna's earthquake SFX did not start with the ground effect")
	if (_inv._king_ref as Damageable).hits != 1:
		_fail("Karna's earthquake did not damage the nearby king")
	if not is_equal_approx(float(karna.get_meta("boss_mana")), 26.25):
		_fail("Karna's earthquake did not spend 25% of its MP")
	await process_frame
	var effect := root.get_node_or_null("BossEarthquakeEffect")
	if effect == null or effect.get("enhanced"):
		_fail("Karna's earthquake did not use the standard Rengkah Bumi ground effect")
	if effect != null:
		effect.free()


func _check_aswatama_earthquake() -> void:
	var data: Dictionary = {
		"is_boss": true,
		"special": "dash",
		"specials": ["dash", "earthquake"],
		"stamina_max": 50.0,
		"mana_max": 30.0,
		"attack": 20.0,
	}
	var aswatama := _make_enemy(data, "aswatama")
	_inv._king_ref = _make_target(Vector3(2.0, 0.0, 0.0))
	_stop_sfx_playback()
	_inv._try_boss_special(aswatama, data)
	if aswatama.get_meta("boss_quake_cd", 0.0) <= 0.0:
		_fail("Aswatama did not trigger earthquake inside close range")
	if not is_equal_approx(float(aswatama.get_meta("boss_mana")), 22.5):
		_fail("Aswatama's earthquake did not spend 25% of its MP")
	if _is_sfx_playing("earth_quake_skill"):
		_fail("Aswatama's earthquake SFX started before the ground effect")
	var anim_player: AnimationPlayer = ModelLoader.find_animation_player(aswatama)
	if anim_player == null or anim_player.current_animation != "boss/earthquake":
		_fail("Aswatama did not play its earthquake rig animation")
	if (_inv._king_ref as Damageable).hits != 0:
		_fail("Aswatama's earthquake dealt damage before its animation impact frame")
	var quake_hit_delay: float = float(aswatama.get_meta("boss_quake_timer", 0.0))
	var quake_length: float = _inv._enemy_animation_length(
		aswatama, "boss/earthquake", 0.0
	)
	if not is_equal_approx(quake_hit_delay, _inv._animation_impact_delay(quake_length)):
		_fail("Aswatama's earthquake is not timed to 50% of its animation")
	_inv._tick_pending_boss_earthquake(aswatama, quake_hit_delay)
	if not _is_sfx_playing("earth_quake_skill"):
		_fail("Aswatama's earthquake SFX did not start with the ground effect")
	var effect := root.get_node_or_null("BossEarthquakeEffect")
	if effect == null or effect.get("enhanced"):
		_fail("Aswatama's earthquake did not use the standard Rengkah Bumi ground effect")
	else:
		effect.free()


# The dash must close a gap, not fire from across the arena.
func _check_dash_only_in_range() -> void:
	var far_enemy := _make_boss()
	_inv._king_ref = _make_target(far_enemy.position + Vector3(20.0, 0.0, 0.0))
	_inv._try_boss_special(far_enemy, _BOSS_DATA)
	if far_enemy.get_meta("boss_dash_timer", 0.0) != 0.0:
		_fail("boss dashed at a target 20 units away; it must stay in dash range")

	var close_enemy := _make_boss()
	_inv._king_ref = _make_target(close_enemy.position + Vector3(6.0, 0.0, 0.0))
	_inv._try_boss_special(close_enemy, _BOSS_DATA)
	if close_enemy.get_meta("boss_dash_timer", 0.0) <= 0.0:
		_fail("boss did not dash at a target 6 units away")
	if close_enemy.get_meta("boss_dash_cd", 0.0) <= 0.0:
		_fail("dashing did not set boss_dash_cd")
	if float(close_enemy.get_meta("boss_stamina", 0.0)) >= 50.0:
		_fail("dashing did not consume boss stamina")
	if not _is_sfx_playing("dash"):
		_fail("boss dash did not play the Gatotkaca dash SFX")


func _is_sfx_playing(stream_name: String) -> bool:
	var sfx_manager: Node = root.get_node_or_null("SFXManager")
	if sfx_manager == null:
		return false
	var streams: Dictionary = sfx_manager.get("_streams")
	var stream: AudioStream = streams.get(stream_name)
	if stream == null:
		return false
	var players: Array = sfx_manager.get("_players")
	for player: AudioStreamPlayer in players:
		if player.playing and player.stream == stream:
			return true
	return false


func _stop_sfx_playback() -> void:
	var sfx_manager: Node = root.get_node_or_null("SFXManager")
	if sfx_manager == null:
		return
	for player: AudioStreamPlayer in sfx_manager.get("_players"):
		player.stop()


func _check_dash_movement() -> void:
	var boss_data: Dictionary = EnemySpawner.spawn_boss(1, 100, 1, BossRegistry.ASWATAMA)
	for rig in ["aswatama", "karna"]:
		var enemy := _make_enemy(boss_data, rig)
		enemy.position = Vector3.ZERO
		var target := _make_target(Vector3(6.0, 0.0, 0.0))
		_inv._start_boss_dash(enemy, target)
		var dash_length: float = _inv._enemy_animation_length(enemy, "boss/dash", 0.0)
		var effect_delay: float = _inv._dash_effect_delay(dash_length)
		_inv._tick_boss_dash(enemy, effect_delay - 0.05)
		if root.get_node_or_null("BossDashTrail") != null:
			_fail("%s dash effect began before the final two animation frames" % rig)
		_inv._tick_boss_dash(enemy, 0.05)
		if root.get_node_or_null("BossDashTrail") == null:
			_fail("%s dash effect did not begin on the final two animation frames" % rig)
		_inv._tick_boss_dash(enemy, dash_length - effect_delay + 0.01)
		var traveled: float = enemy.position.length()
		if traveled < 4.0:
			_fail("%s dash moved only %.2f units; expected a clear burst" % [rig, traveled])
		if enemy.get_meta("boss_dash_timer", 0.0) > 0.0:
			_fail("%s dash remained active after its travel completed" % rig)
		var trail := root.get_node_or_null("BossDashTrail")
		if trail != null:
			trail.free()
		target.free()

	var near_enemy := _make_boss()
	near_enemy.position = Vector3.ZERO
	var near_target := _make_target(Vector3(3.0, 0.0, 0.0))
	_inv._start_boss_dash(near_enemy, near_target)
	_inv._tick_boss_dash(near_enemy, 0.35)
	if near_enemy.position.distance_to(near_target.position) < 1.4:
		_fail("dash overshot a nearby target")
	near_target.free()


func _check_boma_dash() -> void:
	var data: Dictionary = EnemySpawner.spawn_boss(1, 100, 1, BossRegistry.BOMA)
	var enemy := _make_enemy(data, "boma")
	_inv._king_ref = _make_target(Vector3(6.0, 0.0, 0.0))
	_inv._try_boss_special(enemy, data)
	if float(enemy.get_meta("boss_dash_timer", 0.0)) <= 0.0:
		_fail("Boma did not trigger its dash special")
	var anim_player: AnimationPlayer = ModelLoader.find_animation_player(enemy)
	if anim_player == null or anim_player.current_animation != "boss/dash":
		_fail("Boma did not play its dash animation")


func _check_ai_triggers_dash() -> void:
	var enemy := _make_boss()
	enemy.position = Vector3.ZERO
	_inv._king_ref = _make_target(Vector3(6.0, 0.0, 0.0))
	_inv._enemy_nodes.append(enemy)
	_inv._move_enemies(0.016)
	if enemy.get_meta("boss_dash_timer", 0.0) <= 0.0:
		_fail("per-frame enemy AI did not trigger an in-range dash")
	_inv._enemy_nodes.erase(enemy)


func _check_cooldowns_gate_special() -> void:
	var enemy := _make_boss()
	_inv._king_ref = _make_target(enemy.position + Vector3(6.0, 0.0, 0.0))
	_inv._try_boss_special(enemy, _BOSS_DATA)
	enemy.set_meta("boss_dash_timer", 0.0)
	if enemy.get_meta("boss_dash_cd", 0.0) <= 0.0:
		_fail("dashing did not set boss_dash_cd")
	_inv._try_boss_special(enemy, _BOSS_DATA)
	if enemy.get_meta("boss_dash_timer", 0.0) != 0.0:
		_fail("boss dashed again while boss_dash_cd was still running")

	# Cooldowns must decay, or the special would fire exactly once per run.
	for i in 60:
		_inv._tick_boss_cooldowns(enemy, 0.1)
	if enemy.get_meta("boss_dash_cd", 0.0) > 0.0:
		_fail("boss_dash_cd never decayed")
	if enemy.get_meta("boss_quake_cd", 0.0) > 0.0:
		_fail("boss_quake_cd never decayed")

	# A non-boss must not get boss cooldown ticking at all.
	var plain := _make_enemy({"is_boss": false, "special": ""})
	plain.set_meta("boss_dash_cd", 3.0)
	_inv._tick_boss_cooldowns(plain, 0.1)
	if plain.get_meta("boss_dash_cd", 0.0) != 3.0:
		_fail("a non-boss had its boss cooldowns ticked down")


# Enemies come out of a pool, so leftover dash state must not carry to the next spawn.
func _check_pooled_state_is_reset() -> void:
	var enemy := _make_boss()
	enemy.set_meta("boss_dash_cd", 5.0)
	enemy.set_meta("boss_quake_cd", 7.0)
	enemy.set_meta("boss_dash_timer", 0.3)
	enemy.set_meta("boss_dash_dir", Vector3(1, 0, 0))
	_inv._configure_enemy(enemy, _BOSS_DATA, Vector3.ZERO)
	for key in ["boss_dash_cd", "boss_quake_cd", "boss_dash_timer", "boss_dash_remaining"]:
		if enemy.get_meta(key, 0.0) != 0.0:
			_fail("pooled enemy kept %s = %f" % [key, enemy.get_meta(key)])
	if enemy.get_meta("boss_dash_dir", Vector3.ZERO) != Vector3.ZERO:
		_fail("pooled enemy kept a stale dash direction")


var _BOSS_DATA: Dictionary = {"is_boss": true, "special": "dash", "stamina_max": 50.0}


func _make_boss() -> Node3D:
	return _make_enemy(_BOSS_DATA, "aswatama")


# Real boss nodes, not bare Node3D stubs: _try_boss_special() plays a clip through
# get_anim_player(), and only the real rig carries boss/dash.
func _make_enemy(data: Dictionary, rig: String = "") -> Node3D:
	var enemy := Node3D.new()
	_inv.add_child(enemy)
	if rig == "enemy_infantry":
		var model: Node3D = ModelLoader.load_enemy("infantry")
		for child in enemy.get_children():
			child.free()
		for model_child in model.get_children():
			enemy.add_child(model_child.duplicate())
		model.free()
	elif rig != "":
		var boss_model: Node3D = ModelLoader.load_boss(rig)
		for child in enemy.get_children():
			child.free()
		for model_child in boss_model.get_children():
			enemy.add_child(model_child.duplicate())
		boss_model.free()
	enemy.set_script(load("res://scenes/run/enemy_script.gd"))
	enemy.set_meta("enemy_data", data)
	enemy.set_meta("boss_dash_cd", 0.0)
	enemy.set_meta("boss_quake_cd", 0.0)
	enemy.set_meta("boss_dash_timer", 0.0)
	enemy.set_meta("boss_dash_dir", Vector3.ZERO)
	var stamina_max: float = float(data.get("stamina_max", 50.0))
	enemy.set_meta("boss_stamina_max", stamina_max)
	enemy.set_meta("boss_stamina", stamina_max)
	var mana_max: float = float(data.get("mana_max", 0.0))
	enemy.set_meta("boss_mana_max", mana_max)
	enemy.set_meta("boss_mana", mana_max)
	enemy.set_meta("boss_skill_lock", 0.0)
	enemy.set_meta("boss_power_attack_cd", 0.0)
	enemy.set_meta("anim_state", "idle")
	return enemy


func _make_target(pos: Vector3) -> Node3D:
	var target := Damageable.new()
	target.position = pos
	root.add_child(target)
	return target


# The special paths gate on has_method("take_damage"), so the stand-in must really
# implement it -- a bare Node3D would be skipped and the dash would never start.
class Damageable extends Node3D:
	var hits: int = 0

	func take_damage(amount: float) -> void:
		hits += 1
