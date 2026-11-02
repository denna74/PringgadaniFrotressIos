extends CanvasLayer

@onready var title_label: Label = $Title
@onready var status_label: Label = $StatusLabel
@onready var progress_bar: ProgressBar = $ProgressBar
@onready var logo_spin: AnimatedSprite2D = $LogoSpin

var _dot_timer: float = 0.0
var _dot_count: int = 0
var _base_text: String = ""

const DOT_FRAMES := [".", "..", "...", "...."]
const DOT_INTERVAL := 0.35
const LOGO_SPIN_FRAMES: Array[Texture2D] = [
	preload("res://assets/logo_spin_frames/logo_spin_000.png"),
	preload("res://assets/logo_spin_frames/logo_spin_001.png"),
	preload("res://assets/logo_spin_frames/logo_spin_002.png"),
	preload("res://assets/logo_spin_frames/logo_spin_003.png"),
	preload("res://assets/logo_spin_frames/logo_spin_004.png"),
	preload("res://assets/logo_spin_frames/logo_spin_005.png"),
	preload("res://assets/logo_spin_frames/logo_spin_006.png"),
	preload("res://assets/logo_spin_frames/logo_spin_007.png"),
	preload("res://assets/logo_spin_frames/logo_spin_008.png"),
	preload("res://assets/logo_spin_frames/logo_spin_009.png"),
	preload("res://assets/logo_spin_frames/logo_spin_010.png"),
	preload("res://assets/logo_spin_frames/logo_spin_011.png"),
	preload("res://assets/logo_spin_frames/logo_spin_012.png"),
	preload("res://assets/logo_spin_frames/logo_spin_013.png"),
	preload("res://assets/logo_spin_frames/logo_spin_014.png"),
	preload("res://assets/logo_spin_frames/logo_spin_015.png"),
	preload("res://assets/logo_spin_frames/logo_spin_016.png"),
	preload("res://assets/logo_spin_frames/logo_spin_017.png"),
	preload("res://assets/logo_spin_frames/logo_spin_018.png"),
	preload("res://assets/logo_spin_frames/logo_spin_019.png"),
	preload("res://assets/logo_spin_frames/logo_spin_020.png"),
	preload("res://assets/logo_spin_frames/logo_spin_021.png"),
	preload("res://assets/logo_spin_frames/logo_spin_022.png"),
	preload("res://assets/logo_spin_frames/logo_spin_023.png"),
	preload("res://assets/logo_spin_frames/logo_spin_024.png"),
	preload("res://assets/logo_spin_frames/logo_spin_025.png"),
	preload("res://assets/logo_spin_frames/logo_spin_026.png"),
	preload("res://assets/logo_spin_frames/logo_spin_027.png"),
	preload("res://assets/logo_spin_frames/logo_spin_028.png"),
	preload("res://assets/logo_spin_frames/logo_spin_029.png"),
	preload("res://assets/logo_spin_frames/logo_spin_030.png"),
	preload("res://assets/logo_spin_frames/logo_spin_031.png"),
	preload("res://assets/logo_spin_frames/logo_spin_032.png"),
	preload("res://assets/logo_spin_frames/logo_spin_033.png"),
	preload("res://assets/logo_spin_frames/logo_spin_034.png"),
	preload("res://assets/logo_spin_frames/logo_spin_035.png"),
	preload("res://assets/logo_spin_frames/logo_spin_036.png"),
	preload("res://assets/logo_spin_frames/logo_spin_037.png"),
	preload("res://assets/logo_spin_frames/logo_spin_038.png"),
	preload("res://assets/logo_spin_frames/logo_spin_039.png"),
	preload("res://assets/logo_spin_frames/logo_spin_040.png"),
	preload("res://assets/logo_spin_frames/logo_spin_041.png"),
	preload("res://assets/logo_spin_frames/logo_spin_042.png"),
	preload("res://assets/logo_spin_frames/logo_spin_043.png"),
	preload("res://assets/logo_spin_frames/logo_spin_044.png"),
	preload("res://assets/logo_spin_frames/logo_spin_045.png"),
	preload("res://assets/logo_spin_frames/logo_spin_046.png"),
	preload("res://assets/logo_spin_frames/logo_spin_047.png"),
]


func _ready() -> void:
	progress_bar.value = 0.0
	if logo_spin:
		var sf := SpriteFrames.new()
		sf.add_animation("spin")
		sf.set_animation_speed("spin", 24)
		sf.set_animation_loop("spin", true)
		for tex: Texture2D in LOGO_SPIN_FRAMES:
			sf.add_frame("spin", tex)
		logo_spin.sprite_frames = sf
		logo_spin.play("spin")
	if TranslationManager:
		_base_text = TranslationManager.t("loading_desc")
	else:
		_base_text = "Loading..."
	status_label.text = _base_text + DOT_FRAMES[0]
	if not TranslationManager.language_changed.is_connected(_on_language_changed):
		TranslationManager.language_changed.connect(_on_language_changed)


func _on_language_changed(_lang: String) -> void:
	_base_text = TranslationManager.t("loading_desc")
	_update_dots()


func _process(delta: float) -> void:
	_dot_timer += delta
	if _dot_timer >= DOT_INTERVAL:
		_dot_timer = 0.0
		_dot_count = (_dot_count + 1) % DOT_FRAMES.size()
		_update_dots()


func _update_dots() -> void:
	if _base_text == "":
		_base_text = "Loading..."
	status_label.text = _base_text + DOT_FRAMES[_dot_count]


func set_status(msg: String, progress: float) -> void:
	# Keep using the animated loading description as requested
	# but still allow progress updates
	progress_bar.value = progress * 100.0


func set_title(msg: String) -> void:
	title_label.text = msg


func complete() -> void:
	queue_free()
