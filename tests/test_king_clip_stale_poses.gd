extends SceneTree

# The king's clips are merged from separate GLBs at load time (ModelLoader.
# _merge_king_animations), and their imports set animation/remove_immutable_tracks=true,
# which strips every track whose value never changes inside that clip. An untracked bone
# is NOT reset when the clip plays -- it keeps the pose the *previous* clip left it in.
# So the same clip lands on different poses depending on what played before it, and the
# body renders contorted (the "bent king": e.g. Spine 20 degrees off, a limb stretched to
# the predecessor's bone offset) after certain transitions -- attack while moving away
# swaps attack <-> fly continuously.
#
# Two invariants must hold or the rig visibly breaks:
#   1. uniform coverage -- every merged clip drives every bone any clip drives
#   2. idempotency -- a clip reaches the same pose regardless of its predecessor

var failures := 0


func _initialize() -> void:
	_run()


func _check(name: String, cond: bool) -> void:
	if cond:
		print("OK  ", name)
	else:
		push_error("FAIL " + name)
		failures += 1


func _run() -> void:
	await process_frame
	var model: Node3D = ModelLoader.load_king()
	root.add_child(model)
	await process_frame

	var player: AnimationPlayer = ModelLoader.find_animation_player(model)
	var skeleton := model.find_child("Skeleton3D", true, false) as Skeleton3D
	var bone_count := skeleton.get_bone_count()

	var clips: Array[String] = []
	for n in player.get_animation_list():
		if String(n).begins_with("king/"):
			clips.append(String(n))
	clips.sort()

	if clips.size() < 5:
		push_error("king clip discovery broken: found %d clips" % clips.size())
		quit(1)
		return

	_check_uniform_coverage(player, clips, skeleton)
	_check_idempotency(player, skeleton, bone_count)

	model.queue_free()
	await process_frame

	if failures > 0:
		push_error("King clip pose regression (%d failures)" % failures)
		quit(1)
		return
	print("KING_CLIP_POSES_PASS (%d clips)" % clips.size())
	quit(0)


func _check_uniform_coverage(player: AnimationPlayer, clips: Array[String],
		skeleton: Skeleton3D) -> void:
	var union: Dictionary = {}
	for c in clips:
		var anim := player.get_animation(c)
		for i in anim.get_track_count():
			var b := _bone_of(anim.track_get_path(i))
			if b != "":
				union[b] = true

	var missing: Array[String] = []
	for bone_name: String in union:
		if skeleton.find_bone(bone_name) < 0:
			continue
		for c in clips:
			if not _has_rotation_track(player.get_animation(c), bone_name):
				missing.append("%s missing in %s" % [bone_name, c])

	if missing.is_empty():
		_check("every clip drives every bone (%d bones)" % union.size(), true)
		return
	missing.sort()
	_check("every clip drives every bone", false)
	for i in mini(missing.size(), 8):
		push_error("coverage: " + missing[i])
	if missing.size() > 8:
		push_error("coverage: ... and %d more" % (missing.size() - 8))


# Same clip, same time, two different predecessors must land on the same pose.
func _check_idempotency(player: AnimationPlayer, skeleton: Skeleton3D,
		bone_count: int) -> void:
	var cases: Array = [
		["king/fly", "king/attack_1", 0.10],
		["king/fly", "king/attack_2", 0.10],
		["king/fly", "king/attack_3", 0.10],
		["king/attack_1", "king/fly", 0.15],
		["king/idle", "king/attack_2", 0.10],
		["king/attack_3", "king/attack_1", 0.10],
	]
	var checked := 0
	var drifted: Array[String] = []
	for entry: Array in cases:
		var predecessor: String = entry[0]
		var target: String = entry[1]
		var t: float = entry[2]

		var after_a := _pose_after(player, skeleton, bone_count, predecessor, target, t)
		var after_b := _pose_after(player, skeleton, bone_count, "king/idle", target, t)
		checked += 1
		for i in bone_count:
			var pa: Array = after_a[i]
			var pb: Array = after_b[i]
			if not (pa[0] as Quaternion).is_equal_approx(pb[0]) \
					or not (pa[1] as Vector3).is_equal_approx(pb[1]):
				drifted.append("%s after %s: bone %s differs" % [
					target, predecessor, skeleton.get_bone_name(i),
				])

	_check("%d transitions reach the same pose" % checked, drifted.is_empty())
	for line in drifted:
		push_error("pose drift: " + line)


func _pose_after(player: AnimationPlayer, skeleton: Skeleton3D, bone_count: int,
		predecessor: String, target: String, t: float) -> Array:
	player.play(predecessor)
	player.advance(0.30)
	player.play(target)
	player.advance(t)
	var out: Array = []
	for i in bone_count:
		out.append([
			skeleton.get_bone_pose_rotation(i),
			skeleton.get_bone_pose_position(i),
		])
	return out


func _has_rotation_track(anim: Animation, bname: String) -> bool:
	for i in anim.get_track_count():
		if _bone_of(anim.track_get_path(i)) == bname \
				and anim.track_get_type(i) == Animation.TYPE_ROTATION_3D:
			return true
	return false


func _bone_of(path: NodePath) -> String:
	var s := String(path)
	var i := s.rfind(":")
	if i < 0:
		return ""
	var b := s.substr(i + 1)
	var br := b.find("[")
	if br >= 0:
		b = b.substr(0, br)
	return b
