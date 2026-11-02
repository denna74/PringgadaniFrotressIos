extends SceneTree

# Boss skill clips must reach their rigs, trigger only for the boss that declares them,
# respect cooldowns and survive neither enemy pooling nor model fallback.

var _fails: int = 0
var _inv: Node = null


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
	_check_attack_anim_excludes_dash()
	await _check_special_requires_boss()
	_check_karna_earthquake()
	_check_dash_only_in_range()
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
		_fail("Aswatama cannot play boss/earthquake")
	var karna: Node3D = ModelLoader.load_boss(BossRegistry.model_rig(BossRegistry.KARNA))
	var karna_player: AnimationPlayer = ModelLoader.find_animation_player(karna)
	for clip in ["attack_2", "attack_3", "dash", "earthquake", "berserk"]:
		if karna_player == null or not karna_player.has_animation("boss/" + clip):
			_fail("Karna cannot play boss/%s" % clip)


# "dash" is a movement clip, so it must never be chosen as an attack animation.
func _check_attack_anim_excludes_dash() -> void:
	var boss_dash: Dictionary = {"is_boss": true, "special": "dash"}
	if _inv._attack_anim_for(boss_dash) != "boss/attack":
		_fail("a dashing boss should still use boss/attack, got %s" % _inv._attack_anim_for(boss_dash))

	var boma: Dictionary = {"is_boss": true, "special": "power_attack"}
	if _inv._attack_anim_for(boma) != "boss/power_attack":
		_fail("Boma should attack out of its power attack, got %s" % _inv._attack_anim_for(boma))

	var infantry: Dictionary = {"is_boss": false, "special": ""}
	if _inv._attack_anim_for(infantry) != "enemy/attack":
		_fail("infantry attack anim wrong, got %s" % _inv._attack_anim_for(infantry))


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
	}
	var karna := _make_enemy(data, "karna")
	karna.set_meta("current_health", 40.0)
	karna.set_meta("max_health", 100.0)
	_inv._try_boss_special(karna, data)
	await process_frame
	if not karna.get_meta("boss_berserk_active", false):
		_fail("Karna did not activate berserk below half health")
	if karna.get_node_or_null("BossBerserkAura") == null:
		_fail("Karna did not show its berserk aura")
	var anim_player: AnimationPlayer = ModelLoader.find_animation_player(karna)
	if anim_player == null or anim_player.current_animation != "boss/berserk":
		_fail("Karna did not play its berserk animation")


func _check_karna_earthquake() -> void:
	var data: Dictionary = {
		"is_boss": true,
		"special": "dash",
		"specials": ["dash", "earthquake", "berserk"],
		"attack": 20.0,
	}
	var karna := _make_enemy(data, "karna")
	_inv._king_ref = _make_target(Vector3(2.0, 0.0, 0.0))
	_inv._try_boss_special(karna, data)
	if karna.get_meta("boss_quake_cd", 0.0) <= 0.0:
		_fail("Karna did not trigger earthquake inside close range")
	var anim_player: AnimationPlayer = ModelLoader.find_animation_player(karna)
	if anim_player == null or anim_player.current_animation != "boss/earthquake":
		_fail("Karna did not play its earthquake animation")
	if (_inv._king_ref as Damageable).hits != 1:
		_fail("Karna's earthquake did not damage the nearby king")


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
	for key in ["boss_dash_cd", "boss_quake_cd", "boss_dash_timer"]:
		if enemy.get_meta(key, 0.0) != 0.0:
			_fail("pooled enemy kept %s = %f" % [key, enemy.get_meta(key)])
	if enemy.get_meta("boss_dash_dir", Vector3.ZERO) != Vector3.ZERO:
		_fail("pooled enemy kept a stale dash direction")


var _BOSS_DATA: Dictionary = {"is_boss": true, "special": "dash"}


func _make_boss() -> Node3D:
	return _make_enemy(_BOSS_DATA, "aswatama")


# Real boss nodes, not bare Node3D stubs: _try_boss_special() plays a clip through
# get_anim_player(), and only the real rig carries boss/dash.
func _make_enemy(data: Dictionary, rig: String = "") -> Node3D:
	var enemy := Node3D.new()
	_inv.add_child(enemy)
	if rig != "":
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
