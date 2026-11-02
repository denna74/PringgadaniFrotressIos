extends Node3D

const FRAME_PATHS: Array[String] = [
	"res://assets/sprites/berserk/berserk_effect_1.png",
	"res://assets/sprites/berserk/berserk_effect_2.png",
	"res://assets/sprites/berserk/berserk_effect_3.png",
	"res://assets/sprites/berserk/berserk_effect_4.png",
]
const RED_FRAME_PATHS: Array[String] = [
	"res://assets/sprites/berserk/berserk_effect_1_red.png",
	"res://assets/sprites/berserk/berserk_effect_2_red.png",
	"res://assets/sprites/berserk/berserk_effect_3_red.png",
	"res://assets/sprites/berserk/berserk_effect_4_red.png",
]
const FRAME_TIME: float = 0.15
const BLINK_TIME: float = 0.15
const PIXEL_SIZE: float = 0.026
const HEIGHT: float = 1.6
const ALPHA: float = 0.4
const FADE_OUT_TIME: float = 0.15

var _frames: Array[Texture2D] = []
var _sprite: Sprite3D = null
var _frame: int = 0
var _frame_timer: float = 0.0
var _blink_timer: float = 0.0
var _blinking: bool = false
var _fade_total: float = 0.0
var _fade_remaining: float = 0.0
var use_red: bool = false


func _ready() -> void:
	# A finished run freezes the tree, but the fade must still complete or the aura
	# lingers forever beneath the victory/defeat popup.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_frames()
	_build_sprite()


func _load_frames() -> void:
	var paths: Array[String] = RED_FRAME_PATHS if use_red else FRAME_PATHS
	for path: String in paths:
		if not ResourceLoader.exists(path):
			continue
		var texture: Texture2D = load(path)
		if texture != null:
			_frames.append(texture)


func _build_sprite() -> void:
	_sprite = Sprite3D.new()
	_sprite.name = "AuraSprite"
	_sprite.pixel_size = PIXEL_SIZE
	_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_sprite.shaded = false
	_sprite.double_sided = true
	_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_sprite.position = Vector3(0, HEIGHT, 0)
	_sprite.modulate = Color(1.0, 1.0, 1.0, ALPHA)
	if not _frames.is_empty():
		_sprite.texture = _frames[0]
	add_child(_sprite)


func set_blinking(blinking: bool) -> void:
	if blinking == _blinking:
		return
	_blinking = blinking
	_blink_timer = 0.0
	if _sprite != null and not blinking:
		_sprite.visible = true


func is_blinking() -> bool:
	return _blinking


func fade_out(duration: float) -> void:
	if duration <= 0.0:
		queue_free()
		return
	_fade_total = duration
	_fade_remaining = duration


func is_fading() -> bool:
	return _fade_remaining > 0.0


func frame_index() -> int:
	return _frame


func frame_count() -> int:
	return _frames.size()


func _process(delta: float) -> void:
	_update_fade(delta)
	_advance_frames(delta)
	_update_blink(delta)


func _update_fade(delta: float) -> void:
	if _fade_remaining <= 0.0:
		return
	_fade_remaining = maxf(0.0, _fade_remaining - delta)
	if _sprite != null and _fade_total > 0.0:
		var progress: float = 1.0 - (_fade_remaining / _fade_total)
		_sprite.modulate.a = ALPHA * (1.0 - progress)
	if _fade_remaining <= 0.0:
		queue_free()


func _advance_frames(delta: float) -> void:
	if _sprite == null or _frames.size() < 2:
		return
	_frame_timer += delta
	if _frame_timer < FRAME_TIME:
		return
	_frame_timer = 0.0
	_frame = (_frame + 1) % _frames.size()
	_sprite.texture = _frames[_frame]


func _update_blink(delta: float) -> void:
	if _sprite == null or not _blinking:
		return
	_blink_timer += delta
	if _blink_timer < BLINK_TIME:
		return
	_blink_timer = 0.0
	_sprite.visible = not _sprite.visible
