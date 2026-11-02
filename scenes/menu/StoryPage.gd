extends Control


const STORY_KEYS := [
	"story_page_1", "story_page_2", "story_page_3", "story_page_4",
	"story_page_5", "story_page_6", "story_page_7", "story_page_8",
]

const STORY_HIGHLIGHT_NAMES := {
	0: "GATOTKACA",
	3: "KALA PRACONA",
	4: "BISMA",
	5: "ASWATAMA",
	6: "KARNA",
}

const STORY_IMAGE_PATHS := [
	"res://assets/sprites/story_pages/1.png",
	"res://assets/sprites/story_pages/2.png",
	"res://assets/sprites/story_pages/3.png",
	"res://assets/sprites/story_pages/4.png",
	"res://assets/sprites/story_pages/5.png",
	"res://assets/sprites/story_pages/6.png",
	"res://assets/sprites/story_pages/7.png",
	"res://assets/sprites/story_pages/8.png",
]

const STORY_BUILDINGS := [
	{"id": "pendopo", "icon": "res://assets/buttons/buildings_icons/icon_pendopo.png"},
	{"id": "tower", "icon": "res://assets/buttons/buildings_icons/icon_tower.png"},
	{"id": "gold_mine", "icon": "res://assets/buttons/buildings_icons/icon_gold_mine.png"},
	{"id": "barrack", "icon": "res://assets/buttons/buildings_icons/icon_barrack.png"},
]

const IMAGE_PANEL_SIZE := Vector2(640, 720)
const IMAGE_POS := Vector2(10, 10)
const IMAGE_SIZE := Vector2(620, 610)
const STORY_PANEL_X := 640.0
const BUTTON_SIZE := Vector2(220, 60)
const PREV_POS := Vector2(10, 630)
const NEXT_POS := Vector2(400, 630)
const CLOSE_POS := Vector2(410, 10)
const CONTENT_POS := Vector2(10, 103)
const CONTENT_SIZE := Vector2(610, 517)
const CONTENT_WIDTH := 560.0
const PAGE_LABEL_POS := Vector2(300, 640)
const PAGE_LABEL_SIZE := Vector2(80, 40)
const BUTTON_TEXT_COLOR := Color(0.95, 0.85, 0.65, 1)
const MAIN_MENU_PATH := "res://scenes/menu/MainMenu.tscn"


var _current_page: int = 0
var _story_image: TextureRect
var _content_scroll: ScrollContainer
var _content_box: VBoxContainer
var _page_label: Label
var _prev_btn: Button
var _next_btn: Button
var _close_btn: Button
var _leaving: bool = false


func _ready() -> void:
	MusicManager.play_fade(MusicManager.Track.MAIN_MENU, 1.0)
	_build_background()
	_build_image_panel()
	_build_story_panel()
	_show_page()
	TranslationManager.language_changed.connect(_on_language_changed)


func _build_background() -> void:
	var bg := ColorRect.new()
	bg.name = "Background"
	bg.color = Color.BLACK
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)


func _build_image_panel() -> void:
	var panel := Control.new()
	panel.name = "ImagePanel"
	panel.position = Vector2.ZERO
	panel.size = IMAGE_PANEL_SIZE
	add_child(panel)

	_story_image = TextureRect.new()
	_story_image.name = "StoryImage"
	_story_image.position = IMAGE_POS
	_story_image.size = IMAGE_SIZE
	_story_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_story_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_story_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(_story_image)

	_prev_btn = _make_button("PrevButton", "prev", PREV_POS)
	_prev_btn.pressed.connect(_on_prev_pressed)
	panel.add_child(_prev_btn)


func _build_story_panel() -> void:
	var panel := Control.new()
	panel.name = "StoryPanel"
	panel.position = Vector2(STORY_PANEL_X, 0)
	panel.size = IMAGE_PANEL_SIZE
	add_child(panel)

	_close_btn = _make_button("CloseButton", "close", CLOSE_POS, true)
	_close_btn.pressed.connect(_on_close_pressed)
	panel.add_child(_close_btn)

	_content_scroll = ScrollContainer.new()
	_content_scroll.name = "ContentScroll"
	_content_scroll.position = CONTENT_POS
	_content_scroll.size = CONTENT_SIZE
	_content_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_content_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	panel.add_child(_content_scroll)

	_content_box = VBoxContainer.new()
	_content_box.name = "ContentContainer"
	_content_box.custom_minimum_size = Vector2(CONTENT_WIDTH, 0)
	_content_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_box.add_theme_constant_override("separation", 8)
	_content_scroll.add_child(_content_box)

	_page_label = Label.new()
	_page_label.name = "PageLabel"
	_page_label.position = PAGE_LABEL_POS
	_page_label.size = PAGE_LABEL_SIZE
	_page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_page_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_page_label.add_theme_color_override("font_color", Color.WHITE)
	_page_label.add_theme_font_size_override("font_size", 18)
	panel.add_child(_page_label)

	_next_btn = _make_button("NextButton", "next", NEXT_POS)
	_next_btn.pressed.connect(_on_next_pressed)
	panel.add_child(_next_btn)


func _make_button(
	node_name: String, label_key: String, pos: Vector2, is_cancel: bool = false
) -> Button:
	var btn := Button.new()
	btn.name = node_name
	btn.text = TranslationManager.t(label_key).to_upper()
	btn.position = pos
	btn.size = BUTTON_SIZE
	btn.add_theme_color_override("font_color", BUTTON_TEXT_COLOR)
	ButtonBuilder.apply_long_button_art(btn)
	ButtonBuilder.make_hover_inert(btn)
	if is_cancel:
		btn.pressed.connect(ClickPlayer.play_select_4)
	else:
		btn.pressed.connect(ClickPlayer.play_select_3)
	return btn


func _show_page() -> void:
	_current_page = clampi(_current_page, 0, STORY_KEYS.size() - 1)
	_story_image.texture = load(STORY_IMAGE_PATHS[_current_page]) as Texture2D
	_render_content()

	_prev_btn.visible = _current_page > 0
	_prev_btn.text = TranslationManager.t("prev").to_upper()
	_close_btn.text = TranslationManager.t("close").to_upper()

	var last := _current_page == STORY_KEYS.size() - 1
	_next_btn.text = TranslationManager.t("finish" if last else "next").to_upper()
	_page_label.text = TranslationManager.t("page_indicator") % [
		_current_page + 1, STORY_KEYS.size()
	]
	_content_scroll.scroll_vertical = 0


func _render_content() -> void:
	for child in _content_box.get_children():
		_content_box.remove_child(child)
		child.queue_free()

	var text := TranslationManager.t(STORY_KEYS[_current_page])
	if text.is_empty():
		text = TranslationManager.t("story_text_placeholder")

	var is_last_page := _current_page == STORY_KEYS.size() - 1
	_content_box.custom_minimum_size = Vector2(
		CONTENT_WIDTH, CONTENT_SIZE.y if is_last_page else 0
	)

	if _current_page == 1:
		_add_story_text(text, "StoryText")
		for building: Dictionary in STORY_BUILDINGS:
			_add_building_row(building)
		return

	_add_story_text(text, "StoryText")


func _add_story_text(text: String, node_name: String) -> void:
	var highlight_name: String = STORY_HIGHLIGHT_NAMES.get(_current_page, "")
	if not highlight_name.is_empty() and text.to_upper().begins_with(highlight_name):
		var rich_label := RichTextLabel.new()
		rich_label.name = node_name
		rich_label.fit_content = true
		rich_label.bbcode_enabled = false
		rich_label.scroll_active = false
		rich_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		rich_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rich_label.custom_minimum_size = Vector2(CONTENT_WIDTH, 0)
		rich_label.add_theme_color_override("default_color", Color.WHITE)
		rich_label.push_color(Color.YELLOW)
		rich_label.push_bold()
		rich_label.add_text(highlight_name)
		rich_label.pop()
		rich_label.pop()
		rich_label.add_text(text.substr(highlight_name.length()))
		var is_last_page := _current_page == STORY_KEYS.size() - 1
		rich_label.add_theme_font_size_override("normal_font_size", 24 if is_last_page else 20)
		if is_last_page:
			rich_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			rich_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			rich_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_content_box.add_child(rich_label)
		return

	var label := Label.new()
	label.name = node_name
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.custom_minimum_size = Vector2(CONTENT_WIDTH, 0)
	label.add_theme_color_override("font_color", Color.WHITE)
	var is_last_page := _current_page == STORY_KEYS.size() - 1
	label.add_theme_font_size_override("font_size", 24 if is_last_page else 20)
	if is_last_page:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content_box.add_child(label)


func _add_building_row(building: Dictionary) -> void:
	var building_id: String = building["id"]
	var row := HBoxContainer.new()
	row.name = "Building_%s" % building_id.to_pascal_case()
	row.custom_minimum_size.y = 76
	row.add_theme_constant_override("separation", 12)
	_content_box.add_child(row)

	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.custom_minimum_size = Vector2(64, 68)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = load(building["icon"]) as Texture2D
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)

	var text_box := VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.add_theme_constant_override("separation", 2)
	row.add_child(text_box)

	var title := Label.new()
	title.text = TranslationManager.t("story_building_%s_title" % building_id)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_color_override("font_color", Color.WHITE)
	title.add_theme_font_size_override("font_size", 18)
	text_box.add_child(title)

	var description := Label.new()
	description.text = TranslationManager.t("story_building_%s_description" % building_id)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	description.add_theme_color_override("font_color", Color.WHITE)
	description.add_theme_font_size_override("font_size", 16)
	text_box.add_child(description)


func _on_language_changed(_lang: String) -> void:
	_show_page()


func _on_prev_pressed() -> void:
	if _current_page > 0:
		_current_page -= 1
		_show_page()


func _on_next_pressed() -> void:
	if _current_page >= STORY_KEYS.size() - 1:
		_on_close_pressed()
	else:
		_current_page += 1
		_show_page()


func _on_close_pressed() -> void:
	if _leaving:
		return
	_leaving = true
	SceneManager.go_to_scene(MAIN_MENU_PATH)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_on_close_pressed()
