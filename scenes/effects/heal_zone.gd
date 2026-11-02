extends Node3D

const FADE_IN_DURATION: float = 0.6
const FADE_OUT_DURATION: float = 0.5
const FRAME_COUNT: int = 114
const FRAME_RATE: float = 1000.0 / 30.0
const FRAME_PATH: String = "res://assets/sprites/pendopo_heal/pendopo_heal_%03d.png"
const HEAL_ANIMATION: String = "heal"

@export var animation_offset: Vector3 = Vector3(0.0, 4.0, 0.0)
@export_range(0.001, 0.05, 0.001) var animation_pixel_size: float = 0.018
@export_range(0.0, 1.0, 0.05) var animation_opacity: float = 0.4

var _animation: AnimatedSprite3D = null
var _active: bool = false
var _fade_tween: Tween = null


func _ready() -> void:
	_build_animation()


func set_healing_active(active: bool) -> void:
	if active == _active or _animation == null:
		return
	_active = active
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = create_tween()
	if active:
		_animation.visible = true
		_animation.frame = 0
		_animation.play(HEAL_ANIMATION)
		_fade_tween.tween_property(_animation, "modulate:a", animation_opacity, FADE_IN_DURATION)
	else:
		_fade_tween.tween_property(_animation, "modulate:a", 0.0, FADE_OUT_DURATION)
		_fade_tween.tween_callback(_finish_fade_out)


func is_healing_active() -> bool:
	return _active


func _build_animation() -> void:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	frames.add_animation(HEAL_ANIMATION)
	frames.set_animation_speed(HEAL_ANIMATION, FRAME_RATE)
	frames.set_animation_loop(HEAL_ANIMATION, true)
	for frame_index in FRAME_COUNT:
		var path := FRAME_PATH % frame_index
		var texture: Texture2D = load(path)
		if texture == null:
			push_error("Missing Pendopo healing animation frame: %s" % path)
			return
		frames.add_frame(HEAL_ANIMATION, texture)

	_animation = AnimatedSprite3D.new()
	_animation.name = "Animation"
	_animation.sprite_frames = frames
	_animation.animation = HEAL_ANIMATION
	_animation.pixel_size = animation_pixel_size
	_animation.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_animation.position = animation_offset
	_animation.shaded = false
	_animation.double_sided = true
	_animation.no_depth_test = true
	_animation.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	_animation.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_animation.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_animation.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_animation.visible = false
	add_child(_animation)


func _finish_fade_out() -> void:
	if _active:
		return
	_animation.stop()
	_animation.visible = false
