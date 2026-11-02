extends SceneTree

# A finished run freezes the tree, but the berserk aura must still finish its fade-out
# so the aura cannot linger forever underneath the victory/defeat popup. The aura picks
# up the finalized state by processing while paused.

var failures := 0


func _initialize() -> void:
	_run()


func _check(name: String, cond: bool) -> void:
	if cond:
		print("OK  ", name)
	else:
		push_error("FAIL " + name)
		failures += 1


func _finish(token: String) -> void:
	if failures > 0:
		push_error("%s regression (%d failures)" % [token, failures])
		quit(1)
		return
	print(token)
	quit(0)


func _run() -> void:
	await process_frame
	var gp = root.get_node("/root/GamePause")
	gp.clear()

	var aura = load("res://scenes/effects/BerserkAura.gd").new()
	root.add_child(aura)
	await process_frame

	var went: bool = false
	gp.acquire("finished")
	_check("tree frozen for the result", paused)
	aura.fade_out(0.5)
	for i in 300:
		await process_frame
		if aura == null or not is_instance_valid(aura):
			went = true
			break
	_check("aura fades out while frozen", went)
	_check("aura node is gone", aura == null or not is_instance_valid(aura))
	gp.clear()

	_finish("AURA_FADE_PAUSE_PASS")