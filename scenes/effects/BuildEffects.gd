extends Node3D

var last_written: Dictionary = {}


func shake_tiles(center_origin: Vector3, radius: int = 1, duration: float = 0.9) -> Tween:
	var entries: Array[Dictionary] = TerrainBuilder.get_tile_entries_near(center_origin, radius)
	if entries.is_empty():
		return null
	var phase := randf() * TAU
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_method(func(t: float) -> void:
		var decay := 1.0 - t
		for i in entries.size():
			var entry: Dictionary = entries[i]
			var base: Transform3D = entry["base"]
			var amp: float = entry["strength"] * decay
			var new_transform := Transform3D(
				base.basis,
				Vector3(
					base.origin.x + sin(t * 26.0 + phase * 0.5 + i * 2.3) * amp * 0.35,
					base.origin.y + sin(t * 34.0 + phase + i * 1.7) * amp,
					base.origin.z + cos(t * 22.0 + phase * 0.7 + i * 3.1) * amp * 0.35
				)
			)
			var mmi: MultiMeshInstance3D = entry["mmi"]
			mmi.multimesh.set_instance_transform(entry["index"], new_transform)
			last_written["%d:%d" % [mmi.get_instance_id(), entry["index"]]] = new_transform
	, 0.0, 1.0, duration)
	return tween