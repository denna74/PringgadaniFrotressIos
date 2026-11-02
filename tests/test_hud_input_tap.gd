extends SceneTree

# A single physical tap is reported more than once: a finger produces an
# InputEventScreenTouch plus an emulated InputEventMouseButton, and a mouse click
# produces an InputEventMouseButton plus an emulated InputEventScreenTouch. Both
# emulate settings are on (emulate_touch_from_mouse explicitly in project.godot,
# emulate_mouse_from_touch by default).
#
# The HUD tap buttons therefore act on InputEventScreenTouch only. That is sound
# because emulate_touch_from_mouse guarantees a mouse click also arrives as a touch,
# so exactly one source of truth exists per tap.
#
# These tests deliberately deliver the emulated partner on a LATER frame. An earlier
# version of this test delivered every event within one frame, which made a
# frame-based de-duplication look sufficient; in the real game the duplicate crosses a
# frame boundary and that approach let Berserk activate and immediately deactivate.

# [is_touch, is_pressed, frames_to_wait_before]
const SEQ_SAME_FRAME := [[true, true, 0], [false, true, 0], [true, false, 0], [false, false, 0]]
const SEQ_MOUSE_NEXT_FRAME := [[true, true, 0], [false, true, 1], [true, false, 1], [false, false, 1]]
const SEQ_MOUSE_AFTER_RELEASE := [[true, true, 0], [true, false, 0], [false, true, 1], [false, false, 1]]
const SEQ_MOUSE_FRAMES_LATER := [[true, true, 0], [true, false, 0], [false, true, 2], [false, false, 2]]
const SEQ_MOUSE_BEFORE_TOUCH := [[false, true, 0], [true, true, 1], [false, false, 1], [true, false, 1]]

const SEQUENCES := {
	"same-frame": SEQ_SAME_FRAME,
	"mouse-next-frame": SEQ_MOUSE_NEXT_FRAME,
	"mouse-after-release": SEQ_MOUSE_AFTER_RELEASE,
	"mouse-frames-later": SEQ_MOUSE_FRAMES_LATER,
	"mouse-before-touch": SEQ_MOUSE_BEFORE_TOUCH,
}

const BUTTONS := [
	["attack", "_on_atk_gui_input", "attack_pressed"],
	["earthquake", "_on_skill_gui_input", "skill_pressed"],
	["dash", "_on_dash_gui_input", "dash_pressed"],
	["berserk", "_on_berserk_gui_input", "berserk_pressed"],
]

# A spied PotionsPanel so its activation can be counted at the call site. PotionsPanel
# opens a popup directly instead of emitting a signal, and the popup's open guard would
# hide a duplicate.
const POTIONS_SPY := """
extends "res://scenes/run/PotionsPanel.gd"
var press_count: int = 0

func _on_potions_pressed() -> void:
	press_count += 1
"""

var _fails: int = 0


func _initialize() -> void:
	_run()


func _fail(msg: String) -> void:
	_fails += 1
	print("CHECK FAIL: " + msg)


func _touch(pressed: bool, index: int = 0) -> InputEventScreenTouch:
	var st := InputEventScreenTouch.new()
	st.index = index
	st.pressed = pressed
	st.position = Vector2(100, 100)
	return st


func _mouse(pressed: bool) -> InputEventMouseButton:
	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_LEFT
	mb.pressed = pressed
	mb.position = Vector2(100, 100)
	return mb


func _event_for(spec: Array) -> InputEvent:
	if spec[0]:
		return _touch(spec[1])
	return _mouse(spec[1])


# Replays one physical tap, honouring the frame gaps the sequence asks for.
func _feed(target: Object, handler: String, seq: Array) -> void:
	for spec: Array in seq:
		for i in int(spec[2]):
			await process_frame
		target.call(handler, _event_for(spec))


func _make_hud() -> CanvasLayer:
	var hud := CanvasLayer.new()
	hud.set_script(load("res://scenes/run/RunHUD.gd"))
	root.add_child(hud)
	# A parse error in the HUD leaves it without the handler, and calling a missing
	# method would otherwise let these checks pass for the wrong reason.
	for entry: Array in BUTTONS:
		if not hud.has_method(entry[1]):
			_fail("RunHUD is missing %s - did the script fail to load?" % entry[1])
	return hud


func _make_potions_spy() -> Control:
	var script := GDScript.new()
	script.source_code = POTIONS_SPY
	script.reload()
	var panel := Control.new()
	panel.set_script(script)
	root.add_child(panel)
	return panel


func _make_king() -> Node3D:
	var kc: Node3D = load("res://scenes/run/KingController.tscn").instantiate()
	kc.position = Vector3.ZERO
	kc.set_play_field(8)
	kc.setup_king({
		"hp": 9999.0,
		"attack": 20.0,
		"defense": 20.0,
		"mana_max": 200.0,
	})
	root.add_child(kc)
	return kc


func _run() -> void:
	await process_frame
	await _check_mouse_click_depends_on_emulation()
	await _check_buttons_emit_once_per_tap()
	await _check_potions_pressed_once_per_tap()
	await _check_separate_taps_all_count()
	await _check_berserk_tap_deactivates()
	await _check_berserk_activates_from_off()
	_finish()


# The tap buttons ignore InputEventMouseButton, so a desktop mouse click only works
# because emulate_touch_from_mouse turns it into a touch. That setting is the whole
# reason ignoring mouse events is safe, so pin it here: without it, mouse clicks would
# stop working on all five buttons and nothing else in the suite would notice.
func _check_mouse_click_depends_on_emulation() -> void:
	if not bool(ProjectSettings.get_setting("input_devices/pointing/emulate_touch_from_mouse", false)):
		_fail("emulate_touch_from_mouse is off, but the tap buttons rely on it to turn a mouse click into a touch")
	var hud := _make_hud()
	await process_frame
	var count := [0]
	hud.connect("attack_pressed", func() -> void: count[0] += 1)
	# A bare mouse click carries no touch, so it must be ignored rather than acted on
	# twice; emulated_touch_from_mouse is what supplies the touch in the real game.
	for pressed: bool in [true, false]:
		hud.call("_on_atk_gui_input", _mouse(pressed))
	await process_frame
	if count[0] != 0:
		_fail("a bare mouse click emitted %d times; only the touch source may be acted on" % count[0])
	hud.queue_free()
	await process_frame


func _check_buttons_emit_once_per_tap() -> void:
	for entry: Array in BUTTONS:
		for seq_name: String in SEQUENCES:
			await process_frame
			var hud := _make_hud()
			await process_frame
			var count := [0]
			hud.connect(entry[2], func() -> void: count[0] += 1)
			await _feed(hud, entry[1], SEQUENCES[seq_name])
			await process_frame
			if count[0] != 1:
				_fail("%s [%s]: one tap emitted %d times, expected 1" % [entry[0], seq_name, count[0]])
			hud.queue_free()
			await process_frame


func _check_potions_pressed_once_per_tap() -> void:
	for seq_name: String in SEQUENCES:
		await process_frame
		var panel := _make_potions_spy()
		await process_frame
		await _feed(panel, "_on_potions_gui_input", SEQUENCES[seq_name])
		await process_frame
		var count: int = panel.get("press_count")
		if count != 1:
			_fail("potions [%s]: one tap activated %d times, expected 1" % [seq_name, count])
		panel.queue_free()
		await process_frame


# A release must clear the state, so later taps still register, and nothing may be
# swallowed across frame boundaries.
func _check_separate_taps_all_count() -> void:
	for entry: Array in BUTTONS:
		await process_frame
		var hud := _make_hud()
		await process_frame
		var count := [0]
		hud.connect(entry[2], func() -> void: count[0] += 1)
		for tap in 3:
			await process_frame
			await _feed(hud, entry[1], SEQ_SAME_FRAME)
		if count[0] != 3:
			_fail("%s: three separate taps emitted %d times, expected 3" % [entry[0], count[0]])
		hud.queue_free()
		await process_frame

	await process_frame
	var panel := _make_potions_spy()
	await process_frame
	for tap in 3:
		await process_frame
		await _feed(panel, "_on_potions_gui_input", SEQ_SAME_FRAME)
	var potions_count: int = panel.get("press_count")
	if potions_count != 3:
		_fail("potions: three separate taps activated %d times, expected 3" % potions_count)
	panel.queue_free()
	await process_frame


# The reported bug: a tap while Berserk is active must leave it off, not turn it off
# and immediately back on again.
func _check_berserk_tap_deactivates() -> void:
	for seq_name: String in SEQUENCES:
		await process_frame
		var king := _make_king()
		var hud := _make_hud()
		await process_frame
		hud.set_berserk_receiver(king, "request_berserk")
		king.set_berserk(true)
		await process_frame
		if not king.berserk_active:
			_fail("berserk [%s]: precondition, berserk was not active" % seq_name)
		await _feed(hud, "_on_berserk_gui_input", SEQUENCES[seq_name])
		await process_frame
		if king.berserk_active:
			_fail("berserk [%s]: tap while active restarted it instead of deactivating" % seq_name)
		hud.queue_free()
		king.queue_free()
		await process_frame


# The other half of the reported bug: a tap while Berserk is off must turn it on and
# leave it on, even when the emulated partner lands a frame or more later.
func _check_berserk_activates_from_off() -> void:
	for seq_name: String in SEQUENCES:
		await process_frame
		var king := _make_king()
		var hud := _make_hud()
		await process_frame
		hud.set_berserk_receiver(king, "request_berserk")
		await process_frame
		await _feed(hud, "_on_berserk_gui_input", SEQUENCES[seq_name])
		await process_frame
		if not king.berserk_active:
			_fail("berserk [%s]: tap while off failed to activate (activated then cancelled?)" % seq_name)
		hud.queue_free()
		king.queue_free()
		await process_frame


func _finish() -> void:
	if _fails == 0:
		print("VERIFY_PASS: hud input tap")
		quit(0)
	else:
		print("VERIFY_FAIL: %d checks failed" % _fails)
		quit(1)
