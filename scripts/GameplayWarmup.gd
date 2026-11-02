class_name GameplayWarmup extends RefCounted

## First-use stalls on a weak mobile GPU are the engine doing its homework late: the
## Compatibility (OpenGL) renderer compiles a shader program the first time a material is
## actually drawn, and the text server rasterises a glyph into the font atlas the first time
## it is drawn. ModelLoader.warmup_shaders() covers the shaded model materials only, so the
## effect materials (unshaded + alpha + additive + billboard + emission + no_depth_test +
## cull_disabled) and the popup fonts used to compile/rasterise on the very first attack,
## dash, quake or popup -- the "lag only the first time" report.
##
## This runs during the loading screen so the stall lands where nobody can see it. Each
## effect is instantiated once in front of the camera and drawn for two frames, which forces
## its material shaders to compile and its effect textures to load.

const EFFECT_SCRIPTS: Array[String] = [
	"res://scenes/effects/ArcSlash.gd",
	"res://scenes/effects/DashTrail.gd",
	"res://scenes/effects/ShieldDome.gd",
	"res://scenes/effects/EarthquakeEffect.gd",
	"res://scenes/effects/PendopoExplosion.gd",
	"res://scenes/effects/king_aura.gd",
	"res://scenes/effects/BerserkAura.gd",
	"res://scenes/effects/heal_zone.gd",
	"res://scenes/effects/MetalSpark.gd",
]

# Local offset in front of the camera, so the sample is always inside the view frustum no
# matter where the map's camera happens to be. Scaled down to a sub-pixel speck so nothing
# flashes on screen; the draw call still compiles the shader (same trick warmup_shaders uses).
const WARMUP_DISTANCE: float = 6.0
const WARMUP_SCALE: float = 0.001

# The font sizes used by the build menu, building overlay, and shared buttons/labels.
const POPUP_FONT_SIZES: Array[int] = [9, 10, 11, 12, 14, 16, 18, 20, 26]
# Full alphabet (building names come from JSON) plus the digits and punctuation the popups
# format with ("Level %d / %d", "Defense: %.0f", "Upgrade: %dg", "+%d/day").
const POPUP_SAMPLE_TEXT := "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789 /:%.+dg"


static func warm_effects(camera: Camera3D) -> void:
	if camera == null or not is_instance_valid(camera):
		return
	var samples: Array[Node] = []
	for path: String in EFFECT_SCRIPTS:
		if not ResourceLoader.exists(path):
			continue
		var script: GDScript = load(path)
		if script == null:
			continue
		samples.append(script.new())
	for sample in samples:
		camera.add_child(sample)
		if sample is Node3D:
			var node: Node3D = sample as Node3D
			node.position = Vector3(0.0, 0.0, -WARMUP_DISTANCE)
			node.scale = Vector3.ONE * WARMUP_SCALE
	await camera.get_tree().process_frame
	await camera.get_tree().process_frame
	for sample in samples:
		if is_instance_valid(sample):
			sample.queue_free()
	await camera.get_tree().process_frame


static func warm_popup_fonts(parent: Node) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	# A layer below the loading screen's own (opaque) background, so the sample text is drawn
	# -- glyphs rasterise -- but stays out of sight.
	var layer := CanvasLayer.new()
	layer.layer = -10
	parent.add_child(layer)

	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(holder)

	var y := 0.0
	for size: int in POPUP_FONT_SIZES:
		var label := Label.new()
		label.text = POPUP_SAMPLE_TEXT
		label.position = Vector2(0.0, y)
		label.add_theme_font_size_override("font_size", size)
		holder.add_child(label)
		y += float(size) + 6.0

	var button := ButtonBuilder.create_small_button("Close", 100, 32)
	button.position = Vector2(0.0, y)
	button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.focus_mode = Control.FOCUS_NONE
	holder.add_child(button)

	await parent.get_tree().process_frame
	await parent.get_tree().process_frame
	layer.queue_free()
	await parent.get_tree().process_frame


static func warm_build_popup(plot: Node) -> void:
	if plot == null or not is_instance_valid(plot):
		return
	if not plot.has_method("_show_build_popup") or not plot.has_method("_close_popup"):
		return
	if plot.get("_popup") != null or plot.get("_popup_layer") != null:
		return

	# Use the real build menu so its translated labels, custom font sizes, buttons, and
	# styles are laid out and rendered before the first gameplay tap.
	plot.call("_show_build_popup", false)
	await plot.get_tree().process_frame
	await plot.get_tree().process_frame
	plot.call("_close_popup", false)
	await plot.get_tree().process_frame
