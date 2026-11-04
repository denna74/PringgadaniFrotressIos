extends Control


const SECTIONS := ["gameplay", "profile", "hermitage", "undagi", "blacksmith", "market"]

## Godot core only decodes Ogg Theora, so the source MP4 ships transcoded to .ogv.
const BACKGROUND_VIDEO := "res://assets/bg/grassland_bg.ogv"

## The stage track is drawn from artwork rather than styled boxes. The node is sized to
## the star art's own aspect (553x467), so it fills without letterboxing, and small
## enough that roughly four stages are visible at once.
const STAGE_NODE_SIZE := Vector2(160, 135)

## The top unlocked stage is drawn a third larger than the rest, so the track reads at a
## glance as "you are here". It keeps the same artwork aspect, so only the frame grows.
const STAGE_CURRENT_NODE_SIZE := Vector2(208, 176)

## Vertical space between nodes. The art already carries its own edge, so they sit
## close enough to read as one track rather than a stack of separate cards.
const STAGE_NODE_GAP := 4

## The number is centred in the node and then dropped a little, which sits better against
## the artwork than dead centre.
const STAGE_TITLE_DROP := 10.0

## Section buttons wear the long button artwork. Its aspect (559x139) is held so the
## texture is not stretched, and the height leaves room for the card above them.
const MENU_BUTTON_WIDTH := 300
const MENU_BUTTON_HEIGHT := 72

## The section buttons sit on a carved dialog box instead of a flat panel. Its size holds
## close to the art's own 389x572, nudged a touch wider, so the ornate edges barely stretch.
const MENU_FRAME_ART := "res://assets/menu_dialog_box.png"
const MENU_FRAME_POSITION := Vector2(16, 92)
const MENU_FRAME_SIZE := Vector2(404, 630)

## The button column is centred across the frame; the top offset centres the run of
## buttons vertically so the carved edge stays clear above and below.
const MENU_COLUMN_OFFSET := Vector2(0, 75)
const MENU_BUTTON_SEPARATION := 10

## Section id -> string table key. Every hub button label goes through these, so the hub
## shows one language at a time instead of "English / Indonesian" on a single button.
const MENU_LABEL_KEYS := {
	"gameplay": "hub_gameplay",
	"profile": "hub_profile",
	"hermitage": "hub_hermitage",
	"undagi": "hub_undagi",
	"blacksmith": "hub_blacksmith",
	"market": "hub_market",
}

const MENU_ICON_PATHS := {
	"gameplay": "res://assets/buttons/icon_gameplay.png",
	"profile": "res://assets/buttons/icon_profile.png",
	"hermitage": "res://assets/buttons/icon_hermitage.png",
	"undagi": "res://assets/buttons/icon_architect.png",
	"blacksmith": "res://assets/buttons/icon_blacksmith.png",
	"market": "res://assets/buttons/icon_market.png",
}

## The menu art is ~273px square, so it is capped to sit on the 72px button. It is nudged
## in from the button's left edge by this much so it clears the artwork's border.
const MENU_ICON_SIZE := 58
const MENU_ICON_LEFT := 15

## The top bar reads "icon + value" for gold. The icon is square, so one size
## keeps the pair snug against the busy backdrop.
const GOLD_ICON_PATH := "res://assets/buttons/gold_icon.png"
const TOP_ICON_SIZE := 26
const TOP_ICON_GAP := 6

## The main menu button wears the long button artwork too. Its aspect (559x139) sets the
## height for the 150px width so the texture is not squashed.
const MAIN_MENU_BUTTON_WIDTH := 170
const MAIN_MENU_BUTTON_HEIGHT := 56

## Each top-bar readout is placed directly on the bar at its own position instead of being
## chained together inside a shared row, so any one of them can be moved on its own by
## editing just its constant.
const TOP_ROW_HEIGHT := 30.0
const TOP_LIVES_POSITION := Vector2(90, 20)
const TOP_LIVES_ICONS_POSITION := Vector2(165, 5)
const TOP_GOLD_POSITION := Vector2(775, 33)

## Instant buttons wear the supplied 216x71 artwork. Each size holds that
## aspect and fits the gap it lives in: the life button sits between the
## lives icons and the gold row; the gold button sits between the gold row
## and the stage row.
const INSTANT_GOLD_BTN_PATH := "res://assets/buttons/instant_gold_btn.png"
const INSTANT_LIFE_BTN_PATH := "res://assets/buttons/instant_life_btn.png"
const TOP_INSTANT_LIFE_POS := Vector2(300, 10)
const TOP_INSTANT_LIFE_SIZE := Vector2(190, 76)
const TOP_INSTANT_GOLD_POS := Vector2(530, 10)
const TOP_INSTANT_GOLD_SIZE := Vector2(190, 76)

const GOLD_OPTION_ART_PATHS := [
	"res://assets/buttons/instant_gold_1.png",
	"res://assets/buttons/instant_gold_2.png",
	"res://assets/buttons/instant_gold_3.png",
]
const GOLD_OPTION_ART_SIZE := Vector2(500, 190)
## Move this rectangle in the artwork's pixel coordinates to reposition each option's text.
const GOLD_OPTION_LABEL_RECT := Rect2(150, 20, 330, 150)
const GOLD_OPTION_LABEL_FONT := 18

## The button art carries its icon at base-coords x46..76 of the 216x71
## canvas; the label fills the brown banner to its right.
##
## === EDIT THESE FOUR NUMBERS TO MOVE/RESIZE THE INSTANT BUTTON LABELS ===
## They are in the ART's own pixels (the 216x71 button image). The label is
## placed where these pixels map to on the button, so it scales with the button.
##   LABEL_LEFT  = distance from the button's LEFT edge to the label's left edge
##   LABEL_TOP   = distance from the button's TOP edge to the label's top edge
##   LABEL_RIGHT = distance from the button's LEFT edge to the label's right edge
##                 (must be narrower than the full text so it wraps to 2 lines,
##                  but wider than the longest single word)
##   LABEL_BOTTOM= distance from the button's TOP edge to the label's bottom edge
const BTN_LABEL_LEFT_PX := 80.0
const BTN_LABEL_TOP_PX := 9.0
const BTN_LABEL_RIGHT_PX := 170.0
const BTN_LABEL_BOTTOM_PX := 63.0
const BTN_LABEL_WIDTH_PX := 216.0
const BTN_LABEL_HEIGHT_PX := 71.0
const INSTANT_LIFE_FONT := 18
const INSTANT_GOLD_FONT := 18
const LIFE_POPUP_SIZE := Vector2(460, 300)
const GOLD_POPUP_SIZE := Vector2(460, 520)
const GOLD_OPTION_SIZE := Vector2(300, 100)
const GOLD_OPTION_Y_START := 64
const GOLD_OPTION_Y_STEP := 125
const GOLD_OPTION_SKUS := ["instant_gold_1", "instant_gold_2", "instant_gold_3"]
const GOLD_OPTION_PRICES := ["$1", "$2", "$3"]

const PANE_POSITION := Vector2(420, 62)
const PANE_SIZE := Vector2(840, 640)

## The pane is split in two: the king's model sits on the left in its own always-visible
## panel, at the exact spot the Profile page used to draw it, and the selected section
## fills the content panel beside it. Both positions are the Profile page's old model and
## right-column coordinates, so the hub opens on the same layout it always had.
const KING_PANEL_POSITION := Vector2(22, 18)
const KING_PANEL_SIZE := Vector2(320, 640)
const CONTENT_PANEL_POSITION := Vector2(320, 18)
const CONTENT_PANEL_SIZE := Vector2(532, 640)

@export var profile_title_background_rect := Rect2(130.0, 0.0, 248.0, 80.0)

## Tints on the section buttons' artwork: the open section reads warm and bright, the
## rest sit back.
const ACTIVE_TINT := Color(1.25, 1.15, 0.9)
const INACTIVE_TINT := Color(0.7, 0.66, 0.6)

## Label colours. The open section's label turns black so it reads as selected against
## the brightened button artwork.
const ACTIVE_TEXT := Color.BLACK
const INACTIVE_TEXT := Color(0.95, 0.85, 0.65, 1)
const STAGE_ART_DIR := "res://assets/buttons/"
const STAGE_INCOMPLETE_ART := STAGE_ART_DIR + "stage_incomplete.png"
const STAGE_LOCKED_ART := STAGE_ART_DIR + "stage_locked.png"

## The locked art is already grey; this only fades it back so it reads as out of reach.
const LOCKED_NODE_ALPHA := 0.55


var _lives_display: Control = null
var _lives_slot: HBoxContainer = null
var _no_lives_sub: Label = null
var _gold_lbl: Label
var _main_menu_btn: Button
var _instant_life_btn: TextureButton
var _instant_gold_btn: TextureButton
var _gold_popup_overlay: ColorRect = null
var _gold_popup_options: Array[Button] = []
var _pane: Control
var _king_panel: KingModelPanel
var _page_layer: Control
var _stage_scroll: ScrollContainer
var _stage_container: VBoxContainer
var _menu_buttons: Dictionary = {}
var _pages: Dictionary = {}


func _ready() -> void:
	MusicManager.play_fade(MusicManager.Track.MAIN_MENU, 1.0)
	_setup_background()
	_setup_top_bar()
	_setup_left_menu()
	_setup_pane()
	_show_section("gameplay")
	# The language can be flipped from the main menu, so relabel rather than rebuild.
	if not TranslationManager.language_changed.is_connected(_refresh_button_labels):
		TranslationManager.language_changed.connect(_refresh_button_labels)


func _refresh_button_labels(_lang: String) -> void:
	for id: String in MENU_LABEL_KEYS:
		var btn := _menu_buttons.get(id) as Button
		if btn != null:
			btn.text = TranslationManager.t(MENU_LABEL_KEYS[id])
	if _lives_display != null:
		var prefix := _lives_display.get_node_or_null("LivesPrefix") as Label
		if prefix != null:
			prefix.text = TranslationManager.t("hud_lives_prefix")
	if _gold_lbl != null:
		_gold_lbl.text = "%s %d" % [TranslationManager.t("resource_gold"), SaveManager.gold]
	if _instant_life_btn != null:
		var life_lbl := _instant_life_btn.get_node_or_null("BtnLabel") as Label
		if life_lbl != null:
			life_lbl.text = TranslationManager.t("instant_life_label")
	if _instant_gold_btn != null:
		var gold_lbl := _instant_gold_btn.get_node_or_null("BtnLabel") as Label
		if gold_lbl != null:
			gold_lbl.text = TranslationManager.t("instant_gold_label")
	if _main_menu_btn != null:
		_main_menu_btn.text = TranslationManager.t("hub_main_menu")
	_refresh_no_lives_popup()


func _setup_background() -> void:
	# The player runs the loop but stays hidden: its frame texture is fed to a
	# TextureRect so the art can keep its aspect while covering the screen. The player's
	# own stretch mode would squash it, and playback keeps ticking while hidden.
	var stream := VideoStreamTheora.new()
	stream.file = BACKGROUND_VIDEO

	var player := VideoStreamPlayer.new()
	player.name = "BackgroundVideo"
	player.stream = stream
	player.autoplay = true
	player.loop = true
	player.mouse_filter = Control.MOUSE_FILTER_IGNORE
	player.visible = false
	add_child(player)

	var bg := TextureRect.new()
	bg.name = "Background"
	bg.texture = player.get_video_texture()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	move_child(bg, 0)

func _setup_top_bar() -> void:
	var topbar_bg := TextureRect.new()
	topbar_bg.name = "TopBar"
	topbar_bg.texture = load("res://assets/top_bar.png")
	topbar_bg.position = Vector2(0, 0)
	topbar_bg.size = Vector2(1280, 96)
	topbar_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	topbar_bg.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(topbar_bg)

	# One slot per life up front; _rebuild_lives only swaps what plays inside them, so
	# losing a life does not churn the tree. The caption follows the language setting,
	# so it is built from the string table rather than hardcoded. The strip hangs off the
	# bar itself, on its own constant, like the main menu button beside it.
	_lives_display = ButtonBuilder.create_lives_display(
		TranslationManager.t("hud_lives_prefix")
	)
	_place_top_row(topbar_bg, _lives_display, TOP_LIVES_POSITION)
	_lives_slot = ButtonBuilder.create_lives_icons(SaveManager.max_lives)
	_lives_slot.position = TOP_LIVES_ICONS_POSITION
	topbar_bg.add_child(_lives_slot)

	var gold_row := _build_top_row(GOLD_ICON_PATH)
	gold_row.name = "GoldRow"
	_gold_lbl = ButtonBuilder.create_stat_label(
		"%s %d" % [TranslationManager.t("resource_gold"), SaveManager.gold], 24
	)
	_gold_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	gold_row.add_child(_gold_lbl)
	_place_top_row(topbar_bg, gold_row, TOP_GOLD_POSITION)

	_rebuild_lives()
	SaveManager.gold_changed.connect(_on_gold_changed)
	SaveManager.lives_changed.connect(_on_lives_changed)
	# The autoload ticks once a second while a life is missing, so the hub countdown
	# stays live instead of freezing at the value it was built with.
	if not SaveManager.lives_refill_tick.is_connected(_on_refill_tick):
		SaveManager.lives_refill_tick.connect(_on_refill_tick)

	_main_menu_btn = ButtonBuilder.create_small_button(
		TranslationManager.t("hub_main_menu"), MAIN_MENU_BUTTON_WIDTH, MAIN_MENU_BUTTON_HEIGHT
	)
	_apply_long_button_art(_main_menu_btn)
	_main_menu_btn.add_theme_font_size_override("font_size", 20)
	_main_menu_btn.position = Vector2(
		1010, 20
	)
	_main_menu_btn.pressed.connect(ClickPlayer.play_select_3)
	_main_menu_btn.pressed.connect(func() -> void:
		SceneManager.go_to_scene("res://scenes/menu/MainMenu.tscn")
	)
	topbar_bg.add_child(_main_menu_btn)

	_setup_instant_buttons(topbar_bg)


## The instant buttons hang off the bar itself, each on its own constant like
## the other readouts, and update from the same save/language signals.
func _setup_instant_buttons(topbar: Control) -> void:
	_instant_life_btn = _build_instant_btn(
		"InstantLifeBtn", INSTANT_LIFE_BTN_PATH,
		TOP_INSTANT_LIFE_POS, TOP_INSTANT_LIFE_SIZE,
		"instant_life_label", INSTANT_LIFE_FONT
	)
	topbar.add_child(_instant_life_btn)
	_update_instant_life_btn_state()
	_instant_life_btn.pressed.connect(_show_life_popup)

	_instant_gold_btn = _build_instant_btn(
		"InstantGoldBtn", INSTANT_GOLD_BTN_PATH,
		TOP_INSTANT_GOLD_POS, TOP_INSTANT_GOLD_SIZE,
		"instant_gold_label", INSTANT_GOLD_FONT
	)
	topbar.add_child(_instant_gold_btn)
	_instant_gold_btn.pressed.connect(_show_gold_popup)
	if not IAPManager.billing_ready.is_connected(_on_gold_billing_ready):
		IAPManager.billing_ready.connect(_on_gold_billing_ready)
	if not IAPManager.purchases_restored.is_connected(_on_gold_purchases_restored):
		IAPManager.purchases_restored.connect(_on_gold_purchases_restored)
		# Reconcile anything Play already holds before the first popup opens.
		_on_gold_purchases_restored()


func _build_instant_btn(
	btn_name: String, path: String, pos: Vector2, sz: Vector2,
	label_key: String, font_size: int
) -> TextureButton:
	var btn := TextureButton.new()
	btn.name = btn_name
	btn.texture_normal = load(path)
	btn.ignore_texture_size = true
	# The size constants hold the art's own aspect, so scale-stretch fills the
	# button exactly and the label's anchor fractions land on the artwork.
	btn.stretch_mode = TextureButton.STRETCH_SCALE
	btn.position = pos
	btn.size = sz

	var label := Label.new()
	label.name = "BtnLabel"
	label.anchor_left = BTN_LABEL_LEFT_PX / BTN_LABEL_WIDTH_PX
	label.anchor_top = BTN_LABEL_TOP_PX / BTN_LABEL_HEIGHT_PX
	label.anchor_right = BTN_LABEL_RIGHT_PX / BTN_LABEL_WIDTH_PX
	label.anchor_bottom = BTN_LABEL_BOTTOM_PX / BTN_LABEL_HEIGHT_PX
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# Two-line wrap so the label always stacks ("Instant" / "life") inside the
	# banner box set by the BTN_LABEL_*_PX constants above.
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.max_lines_visible = 2
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.65, 1))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = TranslationManager.t(label_key)
	btn.add_child(label)

	btn.pressed.connect(ClickPlayer.play_select_3)
	return btn


## A held-out life button reads as unavailable: greyed and unpressable, the
## consistent sizing and treatment across the hub.
func _update_instant_life_btn_state() -> void:
	if _instant_life_btn == null:
		return
	var is_full: bool = SaveManager.lives >= SaveManager.max_lives
	_instant_life_btn.disabled = is_full
	_instant_life_btn.modulate = Color(0.5, 0.5, 0.5, 0.7) if is_full else Color.WHITE


func _show_life_popup() -> void:
	var window := get_window()
	if window == null:
		window = get_viewport()
	if window.get_node_or_null("LifePopupOverlay") != null:
		return
	# Replace whatever popup is already open rather than stacking on top of it.
	_close_all_popups()

	var overlay := ColorRect.new()
	overlay.name = "LifePopupOverlay"
	overlay.color = Color(0, 0, 0, 0.6)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	window.add_child(overlay)

	var panel := ButtonBuilder.create_panel(
		int(LIFE_POPUP_SIZE.x), int(LIFE_POPUP_SIZE.y))
	_center_popup_panel(panel, LIFE_POPUP_SIZE)
	overlay.add_child(panel)

	var title := ButtonBuilder.create_title_label(
		TranslationManager.t("instant_life_title"), 24)
	title.position = Vector2(20, 18)
	title.size = Vector2(420, 32)
	panel.add_child(title)

	var desc := ButtonBuilder.create_body_label(
		TranslationManager.t("instant_life_desc"), 16)
	desc.position = Vector2(20, 60)
	desc.size = Vector2(420, 40)
	desc.add_theme_color_override("font_color", Color(0.85, 0.8, 0.7, 1))
	panel.add_child(desc)

	var status := Label.new()
	status.name = "AdStatus"
	status.position = Vector2(20, 110)
	status.size = Vector2(420, 24)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.add_theme_color_override("font_color", Color(1, 0.85, 0, 1))
	status.add_theme_font_size_override("font_size", 14)
	panel.add_child(status)

	var watch_btn := ButtonBuilder.create_menu_button(
		TranslationManager.t("instant_life_watch"), 220, 56)
	watch_btn.position = Vector2((LIFE_POPUP_SIZE.x - 220) / 2.0, 150)
	watch_btn.pressed.connect(
		_on_watch_life_ad_pressed.bind(watch_btn, status, overlay, panel))
	watch_btn.pressed.connect(ClickPlayer.play_select_3)
	panel.add_child(watch_btn)

	var cancel_btn := ButtonBuilder.create_menu_button(
		TranslationManager.t("cancel"), 220, 48)
	cancel_btn.position = Vector2((LIFE_POPUP_SIZE.x - 220) / 2.0, 228)
	cancel_btn.pressed.connect(_close_life_popup.bind(overlay, panel))
	cancel_btn.pressed.connect(ClickPlayer.play_select_4)
	panel.add_child(cancel_btn)


func _close_life_popup(overlay: ColorRect, popup: Control) -> void:
	if is_instance_valid(popup):
		popup.queue_free()
	if is_instance_valid(overlay):
		overlay.queue_free()


func _on_watch_life_ad_pressed(
	watch_btn: Button, status: Label, overlay: ColorRect, popup: Control
) -> void:
	AdsManager.life_reward_earned.connect(
		_on_life_reward_earned.bind(overlay, popup), CONNECT_ONE_SHOT)
	AdsManager.life_reward_failed.connect(
		_on_life_reward_failed.bind(watch_btn, status), CONNECT_ONE_SHOT)
	var result: int = AdsManager.start_life_reward_flow(status)
	match result:
		AdsManager.StartResult.SDK_READY:
			if AdsManager.is_flow_active():
				watch_btn.disabled = true
				watch_btn.modulate = Color(0.5, 0.5, 0.5, 0.7)
		AdsManager.StartResult.SDK_NOT_READY:
			# Keep the button usable. AdsManager auto-starts the flow when the
			# SDK initializes, and fails the pending flow if init fails — the
			# failed handler re-enables the button either way.
			status.text = TranslationManager.t("life_ad_loading")
		AdsManager.StartResult.FLOW_ALREADY_ACTIVE:
			pass


## The reward lands even if the player cancelled the popup mid-flow (the ad
## keeps running headlessly), so the life is granted unconditionally and the
## popup is only closed when it is still on screen.
func _on_life_reward_earned(overlay: ColorRect, popup: Control) -> void:
	SaveManager.refill_life()
	if is_instance_valid(overlay) and is_instance_valid(popup):
		_close_life_popup(overlay, popup)


func _on_life_reward_failed(watch_btn: Button, status: Label) -> void:
	if is_instance_valid(status):
		status.text = TranslationManager.t("life_ad_failed")
	if is_instance_valid(watch_btn):
		watch_btn.disabled = false
		watch_btn.modulate = Color.WHITE


func _show_gold_popup() -> void:
	var window := get_window()
	if window == null:
		window = get_viewport()
	if window.get_node_or_null("GoldPopupOverlay") != null:
		return
	# Replace whatever popup is already open rather than stacking on top of it.
	_close_all_popups()

	_gold_popup_overlay = ColorRect.new()
	_gold_popup_overlay.name = "GoldPopupOverlay"
	_gold_popup_overlay.color = Color(0, 0, 0, 0.6)
	_gold_popup_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_gold_popup_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	window.add_child(_gold_popup_overlay)

	var panel := ButtonBuilder.create_panel(
		int(GOLD_POPUP_SIZE.x), int(GOLD_POPUP_SIZE.y))
	_center_popup_panel(panel, GOLD_POPUP_SIZE)
	_gold_popup_overlay.add_child(panel)

	var title := ButtonBuilder.create_title_label(
		TranslationManager.t("instant_gold_title"), 24)
	title.position = Vector2(20, 18)
	title.size = Vector2(420, 32)
	panel.add_child(title)

	var status := Label.new()
	status.name = "IapStatus"
	status.position = Vector2(20, 545)
	status.size = Vector2(420, 24)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.add_theme_color_override("font_color", Color(1, 0.85, 0, 1))
	status.add_theme_font_size_override("font_size", 14)
	panel.add_child(status)

	_gold_popup_options.clear()
	for i in GOLD_OPTION_SKUS.size():
		var sku: String = IAPConfig.get_sku(GOLD_OPTION_SKUS[i])
		var reward: int = IAPConfig.get_gold_reward(sku)
		var price := IAPManager.get_formatted_price(sku)
		if price.is_empty():
			price = GOLD_OPTION_PRICES[i]
		var btn := Button.new()
		btn.name = "GoldOption%d" % i
		btn.text = ""
		btn.size = GOLD_OPTION_SIZE
		btn.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
		btn.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
		btn.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
		btn.add_theme_stylebox_override("disabled", StyleBoxEmpty.new())
		btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		btn.position = Vector2(
			(GOLD_POPUP_SIZE.x - GOLD_OPTION_SIZE.x) / 2.0,
			GOLD_OPTION_Y_START + i * GOLD_OPTION_Y_STEP
		)

		var art := TextureRect.new()
		art.name = "BtnArt"
		art.texture = load(GOLD_OPTION_ART_PATHS[i])
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_SCALE
		art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(art)

		var label := Label.new()
		label.name = "BtnLabel"
		label.anchor_left = GOLD_OPTION_LABEL_RECT.position.x / GOLD_OPTION_ART_SIZE.x
		label.anchor_top = GOLD_OPTION_LABEL_RECT.position.y / GOLD_OPTION_ART_SIZE.y
		label.anchor_right = GOLD_OPTION_LABEL_RECT.end.x / GOLD_OPTION_ART_SIZE.x
		label.anchor_bottom = GOLD_OPTION_LABEL_RECT.end.y / GOLD_OPTION_ART_SIZE.y
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.max_lines_visible = 2
		label.add_theme_font_size_override("font_size", GOLD_OPTION_LABEL_FONT)
		label.add_theme_color_override("font_color", Color(0.20, 0.12, 0.06, 1))
		label.text = "%s %d — %s" % [
			TranslationManager.t("resource_gold"), reward, price]
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(label)

		btn.disabled = not IAPManager.is_products_ready()
		btn.pressed.connect(
			_on_gold_option_pressed.bind(GOLD_OPTION_SKUS[i], btn, status))
		btn.pressed.connect(ClickPlayer.play_select_3)
		panel.add_child(btn)
		_gold_popup_options.append(btn)

	var cancel_btn := ButtonBuilder.create_menu_button(
		TranslationManager.t("cancel"), 170, 48)
	cancel_btn.name = "CancelBtn"
	cancel_btn.position = Vector2(
		(GOLD_POPUP_SIZE.x - 170) / 2.0, GOLD_POPUP_SIZE.y - 64.0)
	cancel_btn.pressed.connect(_hide_gold_popup)
	cancel_btn.pressed.connect(ClickPlayer.play_select_4)
	panel.add_child(cancel_btn)


func _hide_gold_popup() -> void:
	_gold_popup_options.clear()
	if _gold_popup_overlay != null and is_instance_valid(_gold_popup_overlay):
		_gold_popup_overlay.queue_free()
	_gold_popup_overlay = null


func _center_popup_panel(panel: Control, panel_size: Vector2) -> void:
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -panel_size.x / 2.0
	panel.offset_right = panel_size.x / 2.0
	panel.offset_top = -panel_size.y / 2.0
	panel.offset_bottom = panel_size.y / 2.0


func _on_gold_option_pressed(sku_key: String, btn: Button, status: Label) -> void:
	btn.disabled = true
	var sku := IAPConfig.get_sku(sku_key)
	var result: int = IAPManager.purchase(sku)
	match result:
		IAPManager.PurchaseResult.OK:
			status.text = TranslationManager.t("iap_purchasing")
		IAPManager.PurchaseResult.NOT_INITIALIZED:
			status.text = TranslationManager.t("iap_not_ready")
			btn.disabled = false
			return
		_:
			status.text = TranslationManager.t("iap_unavailable")
			btn.disabled = false
			return
	IAPManager.purchase_successful.connect(
		_on_gold_purchase_success.bind(sku_key, status), CONNECT_ONE_SHOT)
	IAPManager.purchase_failed.connect(
		_on_gold_purchase_failed.bind(btn, status), CONNECT_ONE_SHOT)


func _on_gold_purchase_success(
	sku: String, token: String, expected_sku_key: String, status: Label
) -> void:
	if sku != IAPConfig.get_sku(expected_sku_key):
		return
	var reward := IAPConfig.get_gold_reward(sku)
	if reward <= 0:
		return
	SaveManager.add_gold(reward)
	SaveManager.mark_purchase_processed(token, sku)
	IAPManager.finalize_purchase(token, sku)
	if is_instance_valid(status):
		status.text = ""
	_hide_gold_popup()


func _on_gold_purchase_failed(_sku: String, btn: Button, status: Label) -> void:
	if is_instance_valid(status):
		status.text = TranslationManager.t("iap_purchase_failed")
	if is_instance_valid(btn):
		btn.disabled = false


## Play may hand back a purchase that completed while the app was away.
## Tokens already recorded in SaveManager are only finalized (consumed),
## never granted again.
func _on_gold_purchases_restored() -> void:
	for item in IAPManager.get_pending_restorations():
		var sku: String = item["sku"]
		var token: String = item["token"]
		if SaveManager.is_purchase_processed(token):
			IAPManager.finalize_purchase(token, sku)
			continue
		var reward := IAPConfig.get_gold_reward(sku)
		if reward <= 0:
			continue
		SaveManager.add_gold(reward)
		SaveManager.mark_purchase_processed(token, sku)
		IAPManager.finalize_purchase(token, sku)


func _on_gold_billing_ready() -> void:
	if _gold_popup_overlay == null or not is_instance_valid(_gold_popup_overlay):
		return
	for btn in _gold_popup_options:
		if is_instance_valid(btn):
			btn.disabled = false


func _on_gold_changed(value: int) -> void:
	_gold_lbl.text = "%s %d" % [TranslationManager.t("resource_gold"), value]


func _on_lives_changed(_value: int) -> void:
	_rebuild_lives()
	_update_instant_life_btn_state()


func _format_refill(seconds_left: int) -> String:
	var minutes: int = floori(seconds_left / 60)
	var seconds: int = seconds_left % 60
	return "%d:%02d" % [minutes, seconds]


func _rebuild_lives() -> void:
	if _lives_slot == null:
		return

	ButtonBuilder.update_lives_icons(_lives_slot, SaveManager.lives)


func _on_refill_tick(seconds_left: int) -> void:
	if is_instance_valid(_no_lives_sub):
		if SaveManager.lives > 0:
			_no_lives_sub.text = TranslationManager.t("no_lives_refilled")
		else:
			_no_lives_sub.text = _format_no_lives_refill(seconds_left)


func _format_no_lives_refill(seconds_left: int) -> String:
	return TranslationManager.t("no_lives_refill") % _format_refill(seconds_left)


func _refresh_no_lives_popup() -> void:
	var window := get_window()
	if window == null:
		window = get_viewport()
	var overlay := window.get_node_or_null("NoLivesOverlay")
	if overlay == null:
		return
	var title := overlay.get_node_or_null("NoLivesPanel/NoLivesTitle") as Label
	if title != null:
		title.text = TranslationManager.t("no_lives_title")
	var close_btn := overlay.get_node_or_null("NoLivesPanel/NoLivesCloseButton") as Button
	if close_btn != null:
		close_btn.text = TranslationManager.t("close")
	if is_instance_valid(_no_lives_sub):
		_no_lives_sub.text = (
			TranslationManager.t("no_lives_refilled")
			if SaveManager.lives > 0
			else _format_no_lives_refill(SaveManager.get_lives_refill_seconds())
		)


func _setup_left_menu() -> void:
	# The menu backs itself with the carved dialog box so the section buttons read as one
	# fixture of the fort rather than floating over the video.
	var frame := TextureRect.new()
	frame.name = "MenuFrame"
	frame.texture = load(MENU_FRAME_ART)
	frame.position = MENU_FRAME_POSITION
	frame.size = MENU_FRAME_SIZE
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_SCALE
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame)

	var vbox := VBoxContainer.new()
	vbox.position = MENU_COLUMN_OFFSET
	vbox.size = Vector2(MENU_FRAME_SIZE.x, 6 * MENU_BUTTON_HEIGHT + 5 * MENU_BUTTON_SEPARATION)
	vbox.add_theme_constant_override("separation", MENU_BUTTON_SEPARATION)
	frame.add_child(vbox)

	for entry: Array in [
		["gameplay", "hub_gameplay"],
		["profile", "hub_profile"],
		["hermitage", "hub_hermitage"],
		["undagi", "hub_undagi"],
		["blacksmith", "hub_blacksmith"],
		["market", "hub_market"],
	]:
		var id: String = entry[0]
		var btn := ButtonBuilder.create_menu_button(
			TranslationManager.t(entry[1]), MENU_BUTTON_WIDTH, MENU_BUTTON_HEIGHT
		)
		_apply_long_button_art(btn)
		btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		btn.pressed.connect(_show_section.bind(id))
		btn.pressed.connect(ClickPlayer.play_select_3)
		btn.add_child(_build_menu_icon(id))
		vbox.add_child(btn)
		_menu_buttons[id] = btn


## The section icon sits inside the button, nudged in from the left edge. The label stays
## centred across the whole button, so the icon reads as an addition beside it.
func _build_menu_icon(id: String) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = load(MENU_ICON_PATHS.get(id, ""))
	icon.custom_minimum_size = Vector2(MENU_ICON_SIZE, MENU_ICON_SIZE)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.position = Vector2(MENU_ICON_LEFT, (MENU_BUTTON_HEIGHT - MENU_ICON_SIZE) / 2.0)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon


## Places one top-bar readout straight on the bar at its own position, so the readouts are
## no longer chained together by a shared row and each can be moved independently.
func _place_top_row(parent: Control, node: Control, pos: Vector2) -> void:
	parent.add_child(node)
	node.position = pos
	node.size = Vector2(node.get_combined_minimum_size().x, TOP_ROW_HEIGHT)


## A top bar value sits behind its icon, so the pair reads as one readout. The row keeps
## them snug and centres both against the bar's height.
func _build_top_row(icon_path: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", TOP_ICON_GAP)
	row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_build_top_icon(icon_path))
	return row


## A top bar icon reads as a prefix to the value beside it. Square artwork is capped to
## the bar's text height and kept off the pointer so it never eats a tap.
func _build_top_icon(path: String) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = load(path)
	icon.custom_minimum_size = Vector2(TOP_ICON_SIZE, TOP_ICON_SIZE)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon


## The section buttons wear the long button artwork instead of a flat stylebox.
func _apply_long_button_art(btn: Button) -> void:
	ButtonBuilder.apply_long_button_art(btn)


func _setup_pane() -> void:
	_pane = Control.new()
	_pane.position = PANE_POSITION
	_pane.size = PANE_SIZE
	_pane.clip_contents = true
	add_child(_pane)

	# The king's model is a fixture of the hub, not part of any one section, so it sits in
	# its own panel that _show_section never hides.
	_king_panel = KingModelPanel.new()
	_king_panel.name = "KingPanel"
	_king_panel.position = KING_PANEL_POSITION
	_king_panel.size = KING_PANEL_SIZE
	_pane.add_child(_king_panel)

	# The selected section draws into this layer. Keeping it separate from the king panel
	# means switching sections hides the pages without touching the model.
	_page_layer = Control.new()
	_page_layer.name = "PageLayer"
	_page_layer.position = CONTENT_PANEL_POSITION
	_page_layer.size = CONTENT_PANEL_SIZE
	_page_layer.clip_contents = true
	_pane.add_child(_page_layer)

	_stage_scroll = ScrollContainer.new()
	_stage_scroll.position = Vector2.ZERO
	_stage_scroll.size = CONTENT_PANEL_SIZE
	_stage_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_stage_scroll.get_v_scroll_bar().hide()
	_page_layer.add_child(_stage_scroll)

	_stage_container = VBoxContainer.new()
	_stage_container.custom_minimum_size = Vector2(CONTENT_PANEL_SIZE.x, 0)
	_stage_container.size_flags_horizontal = Control.SIZE_EXPAND
	_stage_container.add_theme_constant_override("separation", STAGE_NODE_GAP)
	_stage_scroll.add_child(_stage_container)

	var current_stage: int = SaveManager.stage_number
	for stg in range(current_stage + 2, 0, -1):
		_stage_container.add_child(_make_stage_button(stg))


func _make_stage_button(stg: int) -> Button:
	var current_stage: int = SaveManager.stage_number
	var is_completed := stg < current_stage
	var is_current := stg == current_stage
	var is_locked := stg > current_stage

	var node_size: Vector2 = STAGE_CURRENT_NODE_SIZE if is_current else STAGE_NODE_SIZE

	var btn := Button.new()
	btn.name = "Stage%d" % stg
	btn.custom_minimum_size = node_size
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	# The artwork carries the state, so the button itself is flat and only adds a
	# press tint. Overriding normal and disabled with empty boxes keeps the theme from
	# painting its own panels on top of the art.
	btn.flat = true
	btn.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	btn.add_theme_stylebox_override("disabled", StyleBoxEmpty.new())
	btn.add_theme_stylebox_override("pressed", _make_node_tint(0.22))
	ButtonBuilder.make_hover_inert(btn)

	var art := TextureRect.new()
	art.name = "StageArt"
	art.texture = load(_stage_art_path(stg, is_completed, is_locked))
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if is_locked:
		art.modulate = Color(1, 1, 1, LOCKED_NODE_ALPHA)
	btn.add_child(art)

	# A child draws over the button's own text, so the label sits on the art as a
	# sibling added after it rather than as btn.text underneath. The artwork already
	# identifies the node, so it carries the bare number and nothing else.
	var title := ButtonBuilder.create_stat_label(str(stg), 20)
	title.name = "StageTitle"
	title.size = Vector2(node_size.x, 28)
	title.position = Vector2(0, (node_size.y - title.size.y) / 2.0 + STAGE_TITLE_DROP)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.add_theme_color_override(
		"font_color", Color(0.6, 0.55, 0.45) if is_locked else Color(0.95, 0.9, 0.75)
	)
	btn.add_child(title)

	# Only a locked stage is unpressable. A stage with no lives must still accept the
	# tap so _on_stage_selected can raise the OUT OF LIVES popup -- a disabled button
	# emits no `pressed` and would make that popup unreachable.
	btn.disabled = is_locked
	if not is_locked:
		btn.pressed.connect(_on_stage_selected.bind(stg))
		btn.pressed.connect(ClickPlayer.play_select_3)

	if is_current:
		btn.pivot_offset = node_size / 2.0
		var tween := create_tween()
		tween.set_loops()
		tween.tween_property(btn, "scale", Vector2(1.05, 1.05), 0.9).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.9).set_ease(Tween.EASE_IN_OUT)

	return btn


func _make_node_tint(alpha: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, alpha)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	return style


## The artwork for one stage node: its rating once cleared, the unplayed art for the
## top unlocked stage, and the same art greyed and faded for everything past it.
func _stage_art_path(stg: int, is_completed: bool, is_locked: bool) -> String:
	if is_locked:
		return STAGE_LOCKED_ART
	if not is_completed:
		return STAGE_INCOMPLETE_ART
	# A stage cleared before ratings existed has no record to read. One star is the
	# floor for a clear; the unplayed art would say the stage had never been finished.
	var rating: int = clampi(SaveManager.get_stage_stars(stg), 1, SaveManager.MAX_STAGE_STARS)
	return "%sstage_%d_star.png" % [STAGE_ART_DIR, rating]


func _on_stage_selected(stg: int) -> void:
	if SaveManager.lives <= 0:
		_show_no_lives()
		return
	_show_stage_confirm(stg)


func _show_stage_confirm(stg: int) -> void:
	var window := get_window()
	if window == null:
		window = get_viewport()
	if window.get_node_or_null("ConfirmOverlay") != null:
		return

	var overlay := ColorRect.new()
	overlay.name = "ConfirmOverlay"
	overlay.color = Color(0, 0, 0, 0.6)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	window.add_child(overlay)

	var panel := ButtonBuilder.create_panel(420, 200)
	panel.name = "ConfirmPanel"
	_center_popup_panel(panel, Vector2(420, 200))
	overlay.add_child(panel)

	var title := ButtonBuilder.create_title_label(
		TranslationManager.t("play_stage_confirm") % stg, 24
	)
	title.name = "ConfirmTitle"
	title.position = Vector2(20, 22)
	title.size = Vector2(380, 32)
	panel.add_child(title)

	var play_btn := ButtonBuilder.create_menu_button(TranslationManager.t("play"), 170, 48)
	play_btn.name = "ConfirmPlayButton"
	play_btn.position = Vector2(212, 120)
	play_btn.pressed.connect(ClickPlayer.play_start)
	play_btn.pressed.connect(func():
		overlay.queue_free()
		SceneManager.go_to_scene("res://scenes/run/RunController.tscn", {"stage_number": stg})
	)
	panel.add_child(play_btn)

	var cancel_btn := ButtonBuilder.create_menu_button(TranslationManager.t("cancel"), 170, 48)
	cancel_btn.name = "ConfirmCancelButton"
	cancel_btn.position = Vector2(38, 120)
	cancel_btn.pressed.connect(overlay.queue_free)
	cancel_btn.pressed.connect(ClickPlayer.play_select_4)
	panel.add_child(cancel_btn)


func _show_section(id: String) -> void:
	if not SECTIONS.has(id):
		return

	# Opening another section dismisses any popup that was on screen, so a
	# buy/life/gold/confirm overlay never survives a menu switch.
	_close_all_popups()

	# Hide every section, but leave the king panel alone -- it is always on screen.
	for child in _page_layer.get_children():
		(child as Control).visible = false

	if id == "gameplay":
		_stage_scroll.visible = true
	else:
		var page: Control = _pages.get(id)
		if page == null:
			page = _create_page(id)
			_pages[id] = page
		page.visible = true

	_set_menu_active(id)


func _close_all_popups() -> void:
	for overlay_name: String in [
		"LifePopupOverlay", "GoldPopupOverlay", "ConfirmOverlay", "NoLivesOverlay"
	]:
		var window := get_window()
		if window == null:
			window = get_viewport()
		var overlay := window.get_node_or_null(overlay_name)
		if overlay != null:
			overlay.queue_free()
	_hide_gold_popup()
	for page: Control in _pages.values():
		if page.has_method("close_popups"):
			page.call("close_popups")
	# The market's buy popup lives on the window, not under this node.
	_free_window_popup()


# The buy popup is parented to the window so it dims the whole screen; that also
# means it would outlive this hub scene, so tear it down explicitly on exit.
func _exit_tree() -> void:
	_free_window_popup()


func _free_window_popup() -> void:
	var window := get_window()
	if window == null:
		window = get_viewport()
	for overlay_name: String in [
		"BuyConfirmOverlay", "UpgradeConfirmOverlay", "BuildingUpgradeConfirmOverlay",
		"EquipPicker", "LifePopupOverlay", "GoldPopupOverlay", "ConfirmOverlay",
		"NoLivesOverlay"
	]:
		var overlay := window.get_node_or_null(overlay_name)
		if overlay != null:
			overlay.queue_free()


func _create_page(id: String) -> Control:
	var page: Control = null
	match id:
		"profile":
			page = load("res://scenes/hub/ProfilePage.gd").new()
			page.set("title_background_rect", profile_title_background_rect)
		"hermitage":
			page = load("res://scenes/hub/HermitagePage.gd").new()
		"undagi":
			page = load("res://scenes/hub/ArchitecturePage.gd").new()
		"blacksmith":
			page = load("res://scenes/hub/BlacksmithPage.gd").new()
		"market":
			page = load("res://scenes/hub/MarketPage.gd").new()
	page.position = Vector2.ZERO
	page.size = CONTENT_PANEL_SIZE
	_page_layer.add_child(page)
	return page


func _set_menu_active(id: String) -> void:
	for key in _menu_buttons:
		var btn: Button = _menu_buttons[key]
		var is_open: bool = key == id
		# A StyleBoxTexture has no bg_color to recolour, so the highlight rides on the
		# texture's modulate_color instead: warm for the open section, dimmed otherwise.
		var style := btn.get_theme_stylebox("normal") as StyleBoxTexture
		if style != null:
			style.modulate_color = ACTIVE_TINT if is_open else INACTIVE_TINT
		# The open section's label reads black against its brightened artwork; the rest
		# stay cream.
		btn.add_theme_color_override("font_color", ACTIVE_TEXT if is_open else INACTIVE_TEXT)
		# Recolouring the label means the mirrored hover colour has to follow it.
		ButtonBuilder.make_hover_inert(btn)


func _show_no_lives() -> void:
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.6)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.name = "NoLivesOverlay"
	var window := get_window()
	if window == null:
		window = get_viewport()
	window.add_child(overlay)

	var panel_size := Vector2(440, 260)
	var panel := ButtonBuilder.create_panel(int(panel_size.x), int(panel_size.y))
	panel.name = "NoLivesPanel"
	_center_popup_panel(panel, panel_size)
	overlay.add_child(panel)

	var label := ButtonBuilder.create_title_label(TranslationManager.t("no_lives_title"), 30)
	label.name = "NoLivesTitle"
	label.position = Vector2(20, 34)
	label.size = Vector2(400, 42)
	panel.add_child(label)

	var sub := ButtonBuilder.create_body_label(
		_format_no_lives_refill(SaveManager.get_lives_refill_seconds()), 18
	)
	sub.name = "NoLivesRefill"
	sub.position = Vector2(20, 94)
	sub.size = Vector2(400, 32)
	sub.add_theme_color_override("font_color", Color(0.9, 0.82, 0.68, 1))
	panel.add_child(sub)
	# The overlay counts down while it is open; a granted life flips the caption so the
	# player knows they can play again. Nulled when the overlay closes.
	_no_lives_sub = sub
	overlay.tree_exited.connect(func() -> void: _no_lives_sub = null)

	var close_btn := ButtonBuilder.create_menu_button("Close", 220, 48)
	close_btn.name = "NoLivesCloseButton"
	close_btn.text = TranslationManager.t("close")
	close_btn.position = Vector2(110, 166)
	close_btn.size = Vector2(220, 48)
	close_btn.pressed.connect(overlay.queue_free)
	close_btn.pressed.connect(ClickPlayer.play_select_4)
	panel.add_child(close_btn)
