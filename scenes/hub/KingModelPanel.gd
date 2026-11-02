class_name KingModelPanel extends Control

## The hub's always-visible hero display. The king's standing rig is mounted in an
## offscreen SubViewport and shown through a SubViewportContainer, so the same model stays
## on screen in LevelTrack no matter which section is open -- the model no longer belongs
## to any one page. Only the Profile page's text/equipment lives in the content panel.

const MODEL_PATH := "res://assets/models/gatotkaca_stand.glb"
const MODEL_VIEW_SIZE := Vector2i(320, 640)

var _model_viewport: SubViewport


func _ready() -> void:
	var holder := SubViewportContainer.new()
	holder.name = "KingModelHolder"
	holder.stretch = true
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder)

	_model_viewport = build_model_viewport()
	holder.add_child(_model_viewport)

	# Force-render the model viewport while this panel is visible and stop it while hidden.
	# UPDATE_WHEN_VISIBLE is unreliable in exported builds: it gates rendering on
	# render_target_was_used(), which misfires there and leaves the container showing a
	# stale/uninitialized render target (blank or garbled model).
	# See godot#81173 / #80636 / #84110.
	visibility_changed.connect(_update_model_viewport)


func _update_model_viewport() -> void:
	if _model_viewport == null:
		return
	_model_viewport.render_target_update_mode = (
		SubViewport.UPDATE_ALWAYS if is_visible_in_tree() else SubViewport.UPDATE_DISABLED
	)


## The 3D hero display: a camera, a key light and the king's standing rig, posed and
## looping its idle, inside an offscreen SubViewport. Built once by the panel and kept
## alive for the whole hub, so the model is already uploaded and posed on the first frame.
static func build_model_viewport() -> SubViewport:
	var viewport := SubViewport.new()
	viewport.size = MODEL_VIEW_SIZE
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS

	var cam := Camera3D.new()
	cam.position = Vector3(-0.7, 1.8, 2.4)
	cam.look_at_from_position(cam.position, Vector3(0, 1.2, 0), Vector3(0, 1, 0))
	viewport.add_child(cam)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-20, 20, 0)
	viewport.add_child(light)

	var model := Node3D.new()
	model.rotation_degrees = Vector3(-15, 2, -5)
	model.scale = Vector3(1.85, 1.85, 1.85)
	model.position = Vector3(-0.15, -0.55, 0)
	viewport.add_child(model)

	var glb_res := load(MODEL_PATH)
	if glb_res != null:
		var inst := glb_res.instantiate() as Node3D
		model.add_child(inst)
		_play_idle(inst)

	return viewport


## Plays the rig's idle so the pose the player sees is stable from the first frame.
static func _play_idle(inst: Node3D) -> void:
	var ap: AnimationPlayer = inst.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if ap == null:
		for c in inst.get_children():
			if c is AnimationPlayer:
				ap = c
				break
	if ap == null:
		return
	var anims: Array = ap.get_animation_list()
	var name := ""
	if anims.size() > 0:
		name = anims[0]
		if ap.has_animation("Idle_8"):
			name = "Idle_8"
	elif ap.has_animation("Idle_8"):
		name = "Idle_8"
	if name.is_empty():
		return
	ap.play(name)
	var anim: Animation = ap.get_animation(name)
	if anim != null:
		anim.loop_mode = Animation.LOOP_LINEAR
