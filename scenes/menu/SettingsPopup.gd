extends Control

## Settings dialog opened from the main menu's gear button. It owns three settings --
## language, background music and sound effects -- applied live so the player hears the
## change as they drag. Cancel rewinds everything to the values the popup opened with;
## Save simply keeps them. Both close the popup.

signal saved
signal cancelled

const PANEL_SIZE := Vector2(560, 472)
const BUTTON_SIZE := Vector2(180, 56)
const ROW_BUTTON_SIZE := Vector2(200, 52)
const PCT_WIDTH := 64
const LABEL_COLOR := Color.GOLD
const SLIDER_TRACK_COLOR := Color(0.35, 0.35, 0.35)
const SLIDER_FILL_COLOR := Color(0.42, 0.50, 0.16)
const SOUND_POINTER := preload("res://assets/buttons/sound_pointer.png")

var _title: Label
var _language_label: Label
var _language_btn: Button
var _bgm_label: Label
var _bgm_slider: HSlider
var _bgm_pct: Label
var _sfx_label: Label
var _sfx_slider: HSlider
var _sfx_pct: Label
var _save_btn: Button
var _cancel_btn: Button

var _snapshot_lang: String
var _snapshot_bgm: int
var _snapshot_sfx: int


func _ready() -> void:
	_snapshot_lang = TranslationManager.current_language
	_snapshot_bgm = MusicManager.bgm_level
	_snapshot_sfx = SFXManager.sfx_level
	_build_ui()
	TranslationManager.language_changed.connect(_on_language_changed)
	_update_texts()


func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.5)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var panel := ButtonBuilder.create_panel(int(PANEL_SIZE.x), int(PANEL_SIZE.y))
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -PANEL_SIZE.x / 2.0
	panel.offset_top = -PANEL_SIZE.y / 2.0
	panel.offset_right = PANEL_SIZE.x / 2.0
	panel.offset_bottom = PANEL_SIZE.y / 2.0
	add_child(panel)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_right", 30)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	margin.add_child(vbox)

	_title = ButtonBuilder.create_title_label("", 30)
	vbox.add_child(_title)

	var language_row := HBoxContainer.new()
	language_row.add_theme_constant_override("separation", 12)
	vbox.add_child(language_row)
	_language_label = ButtonBuilder.create_stat_label("", 20)
	_language_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_language_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_language_label.add_theme_color_override("font_color", LABEL_COLOR)
	language_row.add_child(_language_label)
	_language_btn = ButtonBuilder.create_small_button("", int(ROW_BUTTON_SIZE.x), int(ROW_BUTTON_SIZE.y))
	_language_btn.add_theme_font_size_override("font_size", 18)
	_language_btn.pressed.connect(_on_language_pressed)
	_language_btn.pressed.connect(ClickPlayer.play_select_1)
	language_row.add_child(_language_btn)

	_bgm_label = ButtonBuilder.create_stat_label("", 20)
	_bgm_label.add_theme_color_override("font_color", LABEL_COLOR)
	vbox.add_child(_bgm_label)
	var bgm := _build_slider_row(vbox)
	_bgm_slider = bgm[0]
	_bgm_pct = bgm[1]
	_bgm_pct.add_theme_color_override("font_color", LABEL_COLOR)
	_bgm_slider.value = _snapshot_bgm
	_bgm_slider.value_changed.connect(_on_bgm_changed)

	_sfx_label = ButtonBuilder.create_stat_label("", 20)
	_sfx_label.add_theme_color_override("font_color", LABEL_COLOR)
	vbox.add_child(_sfx_label)
	var sfx := _build_slider_row(vbox)
	_sfx_slider = sfx[0]
	_sfx_pct = sfx[1]
	_sfx_pct.add_theme_color_override("font_color", LABEL_COLOR)
	_sfx_slider.value = _snapshot_sfx
	_sfx_slider.value_changed.connect(_on_sfx_changed)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	vbox.add_child(spacer)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 46)
	vbox.add_child(buttons)
	_cancel_btn = ButtonBuilder.create_small_button("", int(BUTTON_SIZE.x), int(BUTTON_SIZE.y))
	_cancel_btn.add_theme_font_size_override("font_size", 20)
	_cancel_btn.pressed.connect(_on_cancel_pressed)
	_cancel_btn.pressed.connect(ClickPlayer.play_select_1)
	buttons.add_child(_cancel_btn)
	_save_btn = ButtonBuilder.create_small_button("", int(BUTTON_SIZE.x), int(BUTTON_SIZE.y))
	_save_btn.add_theme_font_size_override("font_size", 20)
	_save_btn.pressed.connect(_on_save_pressed)
	_save_btn.pressed.connect(ClickPlayer.play_select_1)
	buttons.add_child(_save_btn)

	_refresh_pct()


## One slider with its percentage read-out beside it, added straight to `parent`.
## Returns [slider, pct_label].
func _build_slider_row(parent: Container) -> Array:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)
	var slider := HSlider.new()
	slider.custom_minimum_size = Vector2(0, 40)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.min_value = 0
	slider.max_value = MusicManager.MAX_LEVEL
	slider.step = 1
	slider.tick_count = MusicManager.MAX_LEVEL + 1
	slider.ticks_on_borders = false
	slider.add_theme_icon_override("grabber", SOUND_POINTER)
	slider.add_theme_icon_override("grabber_highlight", SOUND_POINTER)
	var track := StyleBoxFlat.new()
	track.bg_color = SLIDER_TRACK_COLOR
	track.content_margin_top = 4
	track.content_margin_bottom = 4
	track.corner_radius_top_left = 4
	track.corner_radius_top_right = 4
	track.corner_radius_bottom_left = 4
	track.corner_radius_bottom_right = 4
	slider.add_theme_stylebox_override("slider", track)
	var fill := track.duplicate() as StyleBoxFlat
	fill.bg_color = SLIDER_FILL_COLOR
	slider.add_theme_stylebox_override("grabber_area", fill)
	slider.add_theme_stylebox_override("grabber_area_highlight", fill)
	row.add_child(slider)
	var pct := ButtonBuilder.create_stat_label("", 20)
	pct.custom_minimum_size = Vector2(PCT_WIDTH, 0)
	pct.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(pct)
	return [slider, pct]


func _update_texts() -> void:
	_title.text = TranslationManager.t("settings")
	_language_label.text = TranslationManager.t("language_label")
	_bgm_label.text = TranslationManager.t("background_music")
	_sfx_label.text = TranslationManager.t("sound_effect")
	_save_btn.text = TranslationManager.t("save")
	_cancel_btn.text = TranslationManager.t("cancel")
	_language_btn.text = TranslationManager.get_language_label()


func _refresh_pct() -> void:
	var step := int(MusicManager.MAX_LEVEL)
	_bgm_pct.text = "%d%%" % int(_bgm_slider.value / step * 100)
	_sfx_pct.text = "%d%%" % int(_sfx_slider.value / step * 100)


func _on_language_pressed() -> void:
	TranslationManager.switch_language()


func _on_language_changed(_lang: String) -> void:
	_language_btn.text = TranslationManager.get_language_label()


func _on_bgm_changed(value: float) -> void:
	MusicManager.set_bgm_level(int(value))
	_refresh_pct()


func _on_sfx_changed(value: float) -> void:
	SFXManager.set_sfx_level(int(value))
	ClickPlayer.play_select_1()
	_refresh_pct()


func _on_cancel_pressed() -> void:
	TranslationManager.set_language(_snapshot_lang)
	MusicManager.set_bgm_level(_snapshot_bgm)
	SFXManager.set_sfx_level(_snapshot_sfx)
	cancelled.emit()
	queue_free()


func _on_save_pressed() -> void:
	saved.emit()
	queue_free()
