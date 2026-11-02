extends Node3D

const FRAME_COUNT: int = 21
const FRAME_RATE: float = 30.0
const PIXEL_SIZE: float = 0.015
const FRAME_PATH: String = "res://assets/sprites/potion_aura/%s_%02d.png"
const ANIMATIONS: Dictionary = {
	"heal": "green",
	"mana": "blue",
	"stamina": "yellow",
}

var _sprite: AnimatedSprite3D = null


var emitting: bool:
	get:
		return _sprite != null and _sprite.is_playing()


func _ready() -> void:
	_build_animation()


func play(effect: String) -> void:
	if _sprite == null or not ANIMATIONS.has(effect):
		return
	var animation_name: String = ANIMATIONS[effect]
	_sprite.stop()
	_sprite.animation = animation_name
	_sprite.frame = 0
	_sprite.visible = true
	_sprite.play()


func _build_animation() -> void:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	for effect: String in ANIMATIONS:
		var animation_name: String = ANIMATIONS[effect]
		frames.add_animation(animation_name)
		frames.set_animation_speed(animation_name, FRAME_RATE)
		frames.set_animation_loop(animation_name, false)
		for frame_index in FRAME_COUNT:
			var path := FRAME_PATH % [animation_name, frame_index]
			var texture: Texture2D = load(path)
			if texture == null:
				push_error("Missing potion aura animation frame: %s" % path)
				return
			frames.add_frame(animation_name, texture)

	_sprite = AnimatedSprite3D.new()
	_sprite.name = "PotionAura"
	_sprite.sprite_frames = frames
	_sprite.pixel_size = PIXEL_SIZE
	_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_sprite.position.y = 0.96
	_sprite.shaded = false
	_sprite.double_sided = true
	_sprite.no_depth_test = true
	_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_sprite.visible = false
	_sprite.animation_finished.connect(_on_animation_finished)
	add_child(_sprite)


func _on_animation_finished() -> void:
	_sprite.visible = false
