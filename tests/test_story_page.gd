extends SceneTree

var failures := 0


func _initialize() -> void:
	_run()


func _check(name: String, cond: bool) -> void:
	if cond:
		print("OK  ", name)
	else:
		push_error("FAIL " + name)
		failures += 1


func _run() -> void:
	await process_frame
	var scene := load("res://scenes/menu/StoryPage.tscn") as PackedScene
	_check("story page scene loads", scene != null)
	if scene == null:
		quit(1)
		return

	var page: Control = scene.instantiate()
	root.add_child(page)
	await process_frame
	await process_frame

	var tm = root.get_node("/root/TranslationManager")
	var image: TextureRect = page.get("_story_image")
	var prev: Button = page.get("_prev_btn")
	var next: Button = page.get("_next_btn")
	var close: Button = page.get("_close_btn")
	var content: ScrollContainer = page.get("_content_scroll")
	var content_box: VBoxContainer = page.get("_content_box")
	var label: Label = page.get("_page_label")

	_check("background exists", page.get_node_or_null("Background") is ColorRect)
	_check("image panel node", page.get_node_or_null("ImagePanel/StoryImage") != null)
	_check("prev button node", page.get_node_or_null("ImagePanel/PrevButton") != null)
	_check("story panel node", page.get_node_or_null("StoryPanel") != null)
	_check("close button node", page.get_node_or_null("StoryPanel/CloseButton") != null)
	_check("scroll node", page.get_node_or_null("StoryPanel/ContentScroll") != null)
	_check("page label node", page.get_node_or_null("StoryPanel/PageLabel") != null)
	_check("next button node", page.get_node_or_null("StoryPanel/NextButton") != null)

	_check("eight pages", page.get_script().get_script_constant_map()["STORY_KEYS"].size() == 8)
	_check("image rect geometry", image != null and image.position == Vector2(10, 10) and image.size == Vector2(620, 610))
	_check("image keeps aspect", image != null and image.expand_mode == TextureRect.EXPAND_IGNORE_SIZE and image.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED)
	_check("prev geometry", prev != null and prev.position == Vector2(10, 630) and prev.size == Vector2(220, 60))
	_check("next geometry", next != null and next.position == Vector2(400, 630) and next.size == Vector2(220, 60))
	_check("close geometry", close != null and close.position == Vector2(410, 10) and close.size == Vector2(220, 60))
	_check("content geometry", content != null and content.position == Vector2(10, 103) and content.size == Vector2(610, 517))
	_check("page label geometry", label != null and label.position == Vector2(300, 640) and label.size == Vector2(80, 40))
	_check("scrollable content", content != null and content.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED)
	_check("first page label", label != null and label.text == tm.t("page_indicator") % [1, 8])
	_check("prev hidden on first page", prev != null and not prev.visible)
	_check("first image loaded", image != null and image.texture != null and image.texture.resource_path.ends_with("/1.png"))
	_check("story text shown", content_box != null and content_box.get_child_count() == 1)
	if content_box != null and content_box.get_child_count() == 1:
		var story_text := content_box.get_child(0) as RichTextLabel
		_check(
			"first story page text",
			story_text != null
				and story_text.get_parsed_text().to_upper().begins_with("GATOTKACA")
				and story_text.get_parsed_text().substr("GATOTKACA".length())
					== tm.t("story_page_1").substr("Gatotkaca".length())
		)
	_check("next wired", next != null and next.pressed.get_connections().size() > 0)
	_check("prev wired", prev != null and prev.pressed.get_connections().size() > 0)
	_check("close wired", close != null and close.pressed.get_connections().size() > 0)
	_check("close reads localized label", close != null and close.text == tm.t("close").to_upper())

	next.pressed.emit()
	await process_frame
	_check("next advances", page.get("_current_page") == 1)
	_check("second image loaded", image.texture.resource_path.ends_with("/2.png"))
	_check("prev visible after advancing", prev.visible)
	_check("second page label", label.text == tm.t("page_indicator") % [2, 8])
	_check("page two has intro and four building rows", content_box.get_child_count() == 5)
	for building_id in ["Pendopo", "Tower", "GoldMine", "Barrack"]:
		var building_row := content_box.get_node_or_null("Building_%s" % building_id) as HBoxContainer
		var building_icon := building_row.get_node_or_null("Icon") as TextureRect if building_row != null else null
		_check(
			"page two %s icon loads" % building_id,
			building_icon != null and building_icon.texture != null
		)

	for page_index: int in [3, 4, 5, 6]:
		page.set("_current_page", page_index)
		page.call("_show_page")
		await process_frame
		var highlight: RichTextLabel = content_box.get_child(0) as RichTextLabel
		var expected_name: String = ["KALA PRACONA", "BISMA", "ASWATAMA", "KARNA"][page_index - 3]
		_check(
			"page %d starts with highlighted name" % (page_index + 1),
			highlight != null and highlight.get_parsed_text().begins_with(expected_name)
		)

	page.set("_current_page", 1)
	page.call("_show_page")
	await process_frame

	prev.pressed.emit()
	await process_frame
	_check("prev goes back", page.get("_current_page") == 0)
	_check("first image restored", image.texture.resource_path.ends_with("/1.png"))

	page.set("_current_page", 7)
	page.call("_show_page")
	await process_frame
	_check("last page label", label.text == tm.t("page_indicator") % [8, 8])
	_check("last page uses Finish", next.text == tm.t("finish").to_upper())
	_check("last image loaded", image.texture.resource_path.ends_with("/8.png"))
	var last_page_text := content_box.get_child(0) as Label
	_check(
		"last page text centered and enlarged",
		last_page_text != null
			and last_page_text.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER
			and last_page_text.vertical_alignment == VERTICAL_ALIGNMENT_CENTER
			and last_page_text.size_flags_vertical == Control.SIZE_EXPAND_FILL
			and last_page_text.get_theme_font_size("font_size") == 24
	)
	_check(
		"last page content fills scroll area",
		content_box.custom_minimum_size == Vector2(560, 517)
	)

	var original_lang: String = tm.current_language
	tm.set_language("id" if original_lang == "en" else "en")
	await process_frame
	_check("language refreshes finish label", next.text == tm.t("finish").to_upper())
	_check("language refreshes prev label", prev.text == tm.t("prev").to_upper())
	_check("language refreshes page label", label.text == tm.t("page_indicator") % [8, 8])
	tm.set_language(original_lang)
	await process_frame

	page.queue_free()
	await process_frame
	if failures > 0:
		push_error("Story page regression")
		quit(1)
	else:
		print("STORY_PAGE_PASS")
		quit(0)
