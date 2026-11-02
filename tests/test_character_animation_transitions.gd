extends SceneTree

var _fails: int = 0


func _initialize() -> void:
	_run()


func _check(name: String, ok: bool) -> void:
	if ok:
		print("OK  ", name)
	else:
		_fails += 1
		push_error("FAIL " + name)


func _run() -> void:
	await process_frame
	await _check_rig("friendly infantry", ModelLoader.load_soldier("infantry"), "soldier")
	await _check_rig("friendly archer", ModelLoader.load_soldier("archer"), "soldier")
	await _check_rig("enemy infantry", ModelLoader.load_enemy("infantry"), "enemy")
	await _check_rig("enemy archer", ModelLoader.load_enemy("archer"), "enemy")
	await _check_rig("Gatotkaca", ModelLoader.load_king(), "king")
	for rig: String in ["kurawa", "boma", "aswatama", "karna"]:
		await _check_rig("boss " + rig, ModelLoader.load_boss(rig), "boss")

	if _fails == 0:
		print("CHARACTER_ANIMATION_TRANSITIONS_PASS")
		quit(0)
	else:
		print("CHARACTER_ANIMATION_TRANSITIONS_FAIL: %d" % _fails)
		quit(1)


func _check_rig(label: String, model: Node3D, prefix: String) -> void:
	if model == null:
		_check("%s model loads" % label, false)
		return
	root.add_child(model)
	await process_frame

	var player := ModelLoader.find_animation_player(model)
	var skeleton := model.find_child("Skeleton3D", true, false) as Skeleton3D
	_check("%s has animation player and skeleton" % label,
		player != null and skeleton != null)
	if player == null or skeleton == null:
		model.queue_free()
		return

	var clips: Array[String] = []
	for animation_name: StringName in player.get_animation_list():
		var clip := String(animation_name)
		if clip.begins_with(prefix + "/") and not clip.ends_with("/RESET"):
			clips.append(clip)
	clips.sort()
	_check("%s has multiple animation states" % label, clips.size() > 1)
	if clips.size() > 1:
		for target: String in clips:
			var baseline_previous: String = clips[0]
			if baseline_previous == target:
				baseline_previous = clips[1]
			var expected_pose := _play_and_capture(
				model, player, skeleton, baseline_previous, target
			)
			var transitions_match := true
			for previous: String in clips:
				if previous == target or previous == baseline_previous:
					continue
				var actual_pose := _play_and_capture(
					model, player, skeleton, previous, target
				)
				if not _poses_equal(expected_pose, actual_pose):
					transitions_match = false
					print("      transition from ", previous, " changed ", target, " pose")
					break
			_check("%s %s pose is independent of previous clips" % [label, target],
				transitions_match)

	model.queue_free()
	await process_frame


func _play_and_capture(
	model: Node3D,
	player: AnimationPlayer,
	skeleton: Skeleton3D,
	previous: String,
	target: String
) -> Array:
	ModelLoader.play_rig_animation(model, player, previous, 0.0, true)
	player.advance(0.2)
	ModelLoader.play_rig_animation(model, player, target, 0.0, true)
	player.advance(0.15)
	var pose: Array = []
	for i in skeleton.get_bone_count():
		pose.append([
			skeleton.get_bone_pose_rotation(i),
			skeleton.get_bone_pose_position(i),
			skeleton.get_bone_pose_scale(i),
		])
	return pose


func _poses_equal(first: Array, second: Array) -> bool:
	if first.size() != second.size():
		return false
	for i in first.size():
		var a: Array = first[i]
		var b: Array = second[i]
		if not (a[0] as Quaternion).is_equal_approx(b[0]) \
				or not (a[1] as Vector3).is_equal_approx(b[1]) \
				or not (a[2] as Vector3).is_equal_approx(b[2]):
			return false
	return true
