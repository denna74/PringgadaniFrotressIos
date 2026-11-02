extends SceneTree

var _fails: int = 0


func _initialize() -> void:
	_run()


func _fail(msg: String) -> void:
	_fails += 1
	print("CHECK FAIL: " + msg)


func _finish() -> void:
	if _fails == 0:
		print("VERIFY_PASS: transparent shader warmup")
		quit(0)
	else:
		print("VERIFY_FAIL: %d checks failed" % _fails)
		quit(1)


# A stand-in for a building mesh: one shared surface material, like the loaded models
# use before Building._collect_mesh_materials duplicates them.
func _mesh() -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	mi.mesh = box
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	box.surface_set_material(0, mat)
	return mi


func _shared_material(model: Node3D) -> Material:
	return (model.get_child(0) as MeshInstance3D).mesh.surface_get_material(0)


func _effective_material(model: Node3D) -> Material:
	return (model.get_child(0) as MeshInstance3D).get_surface_override_material(0)


func _run() -> void:
	await process_frame

	var model := Node3D.new()
	var mi := _mesh()
	model.add_child(mi)
	mi.owner = model
	var original: Material = _shared_material(model)

	ModelLoader._set_sample_transparency(model, true)
	var after_on := _effective_material(model)
	if after_on == null:
		_fail("no surface override was created when enabling transparency")
	elif (after_on as BaseMaterial3D).transparency != BaseMaterial3D.TRANSPARENCY_ALPHA:
		_fail("override material is not TRANSPARENCY_ALPHA, got %d" % (after_on as BaseMaterial3D).transparency)
	if _shared_material(model).transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
		_fail("shared template material was mutated; transparency would leak to other buildings")

	ModelLoader._set_sample_transparency(model, false)
	if (_effective_material(model) as BaseMaterial3D).transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
		_fail("override material did not return to TRANSPARENCY_DISABLED")
	if _shared_material(model).transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
		_fail("shared template material was mutated on the way back to opaque")
	if original == null:
		_fail("original material went missing")

	# A nested mesh must be reached too; real models are several nodes deep.
	var nested := Node3D.new()
	var inner := _mesh()
	var wrapper := Node3D.new()
	wrapper.add_child(inner)
	inner.owner = wrapper
	nested.add_child(wrapper)
	wrapper.owner = nested
	ModelLoader._set_sample_transparency(nested, true)
	if (inner.get_surface_override_material(0) as BaseMaterial3D).transparency != BaseMaterial3D.TRANSPARENCY_ALPHA:
		_fail("nested mesh material was not made transparent")

	# An existing override must be flipped in place rather than replaced, so the warmup
	# covers exactly the material the real building will use.
	var pre: StandardMaterial3D = StandardMaterial3D.new()
	pre.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	mi.material_override = pre
	ModelLoader._set_sample_transparency(model, true)
	if pre.transparency != BaseMaterial3D.TRANSPARENCY_ALPHA:
		_fail("material_override was not flipped; its shader variant stays cold")

	_finish()
