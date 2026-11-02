extends SceneTree

## Guard: every spawnable effect script under scenes/effects must be listed in
## GameplayWarmup.EFFECT_SCRIPTS, so a newly added effect cannot silently reintroduce the
## "lag only the first time" stall by skipping the loading-screen warmup.
## BuildEffects is a helper tool, not a self-spawning effect, so it is excluded.

const Warmup = preload("res://scripts/GameplayWarmup.gd")
const EFFECTS_DIR := "res://scenes/effects"
const NON_EFFECT_SCRIPTS: Array[String] = ["BuildEffects.gd"]


func _init() -> void:
	var dir := DirAccess.open(EFFECTS_DIR)
	if dir == null:
		printerr("GAMEPLAY_WARMUP_FAIL: cannot open %s" % EFFECTS_DIR)
		quit(1)
		return

	var missing: Array[String] = []
	for file: String in dir.get_files():
		if not file.ends_with(".gd"):
			continue
		if NON_EFFECT_SCRIPTS.has(file):
			continue
		var path: String = EFFECTS_DIR + "/" + file
		if not Warmup.EFFECT_SCRIPTS.has(path):
			missing.append(file)

	if missing.is_empty():
		print("GAMEPLAY_WARMUP_PASS")
		quit(0)
	else:
		printerr("GAMEPLAY_WARMUP_FAIL: effects missing from warmup: %s" % [missing])
		quit(1)
