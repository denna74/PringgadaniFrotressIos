extends SceneTree

# Mobile perf guard for the heaviest world geometry. Building models used to be
# 200k-678k triangles each; they now ship as decimated *_mobile.glb versions. This test
# keeps them decimated, checks shadow settings and LOD bias, and keeps the plot flag cheap.

const FLAG_GLB: String = "res://assets/models/3D_tiles/build_flag_lite.glb"
const FLAG_TRI_BUDGET: int = 12000
const BUILDING_TRI_BUDGET: int = 60000

func _initialize() -> void:
	_run()


func _run() -> void:
	var failures := 0
	for id in ["pendopo", "barak", "tambang_emas", "menara"]:
		var model: Node3D = ModelLoader.load_building_model(id)
		if model == null:
			print("FAIL: load_building_model returned null for ", id)
			failures += 1
			continue
		var no_shadow := 0
		var bad_bias := 0
		var tris := 0
		for node in model.find_children("*", "MeshInstance3D", true):
			var mi := node as MeshInstance3D
			if mi.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
				no_shadow += 1
			if not is_equal_approx(mi.lod_bias, ModelLoader.BUILDING_LOD_BIAS):
				bad_bias += 1
			if mi.mesh:
				tris += mi.mesh.get_faces().size() / 3
		if no_shadow > 0:
			print("FAIL: %s has %d shadow-casting-disabled meshes" % [id, no_shadow])
			failures += 1
		if bad_bias > 0:
			print("FAIL: %s has %d meshes without the building LOD bias" % [id, bad_bias])
			failures += 1
		if tris > BUILDING_TRI_BUDGET:
			print("FAIL: %s is %d triangles (budget %d)" % [id, tris, BUILDING_TRI_BUDGET])
			failures += 1
		if no_shadow == 0 and bad_bias == 0 and tris <= BUILDING_TRI_BUDGET:
			print("OK   building %s shadows=on tris=%d" % [id, tris])

	var flag_tris := _flag_triangles()
	if flag_tris < 0:
		print("FAIL: could not load plot flag '%s'" % FLAG_GLB)
		failures += 1
	elif flag_tris > FLAG_TRI_BUDGET:
		print("FAIL: plot flag '%s' has %d triangles (budget %d)" % [FLAG_GLB, flag_tris, FLAG_TRI_BUDGET])
		failures += 1
	else:
		print("OK   plot flag triangles=", flag_tris)

	if failures > 0:
		push_error("BUILDING_PERF regression (%d failures)" % failures)
		quit(1)
		return
	print("BUILDING_PERF_PASS")
	quit(0)


func _flag_triangles() -> int:
	if not ResourceLoader.exists(FLAG_GLB):
		return -1
	var scene: PackedScene = load(FLAG_GLB)
	if scene == null:
		return -1
	var inst: Node3D = scene.instantiate()
	var total := 0
	for child in inst.find_children("*", "MeshInstance3D", true):
		var mesh: Mesh = (child as MeshInstance3D).mesh
		if mesh:
			total += mesh.get_faces().size() / 3
	inst.queue_free()
	return total
