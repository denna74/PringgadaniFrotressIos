extends Node

## Graphics quality is fixed at HIGH.
##
## A render-resolution preset (LOW / MEDIUM / HIGH) used to live here, with a matching
## toggle in the Settings dialog. Both were removed: the game runs on the Compatibility
## (OpenGL) renderer, where `Viewport.scaling_3d_scale` is ignored, so the presets only
## ever did anything on desktop while looking like they helped on the phone. The game now
## always renders at full 3D resolution.


func _ready() -> void:
	var vp := get_viewport()
	if vp:
		vp.scaling_3d_scale = 1.0
