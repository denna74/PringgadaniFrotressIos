extends SceneTree


func _initialize() -> void:
	var model: Node3D = ModelLoader.load_soldier()
	if model == null:
		print("FAIL: load_soldier returned null")
		quit(1)
		return
	var anim_player: AnimationPlayer = ModelLoader.find_animation_player(model)
	if anim_player == null:
		print("FAIL: no animation player")
		quit(1)
		return
	var ok := true
	for required in ["soldier/idle", "soldier/run", "soldier/attack"]:
		if not anim_player.has_animation(required):
			ok = false
			print("FAIL: missing ", required)
	if ok:
		print("VERIFY_PASS")
		quit(0)
	else:
		quit(1)
