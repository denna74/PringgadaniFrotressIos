extends SceneTree

# Slice C: the barracks can actually field archers, not just infantry.

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

	await _test_default_is_infantry()
	await _test_select_archer()
	await _test_costs_differ()
	await _test_training_emits_selected_type()
	await _test_garrison_receives_archers()
	await _test_typed_queue_and_cap()
	await _test_death_allows_replacement()
	await _test_new_popup_counts_and_buttons()
	await _test_add_troop_keeps_overlay_open()

	if failures > 0:
		push_error("Barak archer training regression (%d failures)" % failures)
		quit(1)
		return
	print("BARAK_ARCHER_PASS")
	quit(0)


const BARAK_DATA := {
	"id": "barak", "name_en": "Barak", "troop_type": "infantry",
	"training_speed": 3, "base_cost_gold": 10, "max_level": 5, "type": "military",
	"grid_size": {"w": 3, "h": 3},
}


func _make_barak(garrison) -> Node3D:
	var holder := Node3D.new()
	root.add_child(holder)
	var barak = load("res://scenes/buildings/Barak.gd").new(BARAK_DATA.duplicate(), null)
	holder.add_child(barak)
	barak.setup(garrison)
	await process_frame
	return barak


func _test_default_is_infantry() -> void:
	var barak := await _make_barak(null)
	_check("a fresh barracks trains infantry", barak.get_troop_type() == "infantry")
	_check("infantry is the default selection", barak.building_data.get("troop_type") == "infantry")
	barak.queue_free()
	await process_frame


func _test_select_archer() -> void:
	var barak := await _make_barak(null)
	_check("barracks offers archers as a choice", barak.available_troop_types().has("archer"))
	_check("barracks offers infantry as a choice", barak.available_troop_types().has("infantry"))

	barak.set_troop_type("archer")
	_check("barracks switched to archer", barak.get_troop_type() == "archer")
	_check("selection is reflected in building_data", barak.building_data.get("troop_type") == "archer")

	barak.set_troop_type("dragon")
	_check("an unknown type is rejected", barak.get_troop_type() == "archer")

	barak.set_troop_type("infantry")
	barak.queue_free()
	await process_frame


func _test_costs_differ() -> void:
	var barak := await _make_barak(null)
	var inf_cost: int = barak.get_training_cost()
	barak.set_troop_type("archer")
	var arc_cost: int = barak.get_training_cost()
	_check("archers cost more than infantry (%d > %d)" % [arc_cost, inf_cost], arc_cost > inf_cost)
	_check("only infantry and archers are offered", barak.available_troop_types() == ["infantry", "archer"])
	barak.queue_free()
	await process_frame


func _test_training_emits_selected_type() -> void:
	var barak := await _make_barak(PlayerGarrison.new())
	var seen: Array = []
	barak.troop_trained.connect(func(t: String) -> void: seen.append(t))
	barak.set_troop_type("archer")
	barak.garrison.reserve_troop("archer", Barak.MAX_TROOPS_PER_TYPE)
	barak.garrison.add_troops("archer", 1)
	barak._training_queue.append("archer")
	barak._on_training_complete()
	_check("training emitted \"archer\" (got %s)" % [seen], seen == ["archer"])
	_check("the queue was consumed", barak._training_queue.is_empty())
	barak.queue_free()
	await process_frame


func _test_garrison_receives_archers() -> void:
	var garrison := PlayerGarrison.new()
	var barak := await _make_barak(garrison)
	barak.set_troop_type("archer")
	for i in 3:
		garrison.reserve_troop("archer", Barak.MAX_TROOPS_PER_TYPE)
		garrison.add_troops("archer", 1)
		barak._training_queue.append("archer")
		barak._on_training_complete()
	_check("garrison counted 3 archers (got %d)" % garrison.archers, garrison.archers == 3)
	_check("garrison total counts archers", garrison.get_total() == 3)
	_check("garrison reports archers via the singular key", garrison._get_count("archer") == 3)
	barak.queue_free()
	await process_frame


func _test_typed_queue_and_cap() -> void:
	var garrison := PlayerGarrison.new()
	var barak := await _make_barak(garrison)
	var seen: Array[String] = []
	barak.troop_trained.connect(func(t: String) -> void: seen.append(t))
	for troop_type in ["infantry", "archer"]:
		_check("reserve %s slot" % troop_type, garrison.reserve_troop(troop_type, 9))
		garrison.add_troops(troop_type, 1)
		barak._training_queue.append(troop_type)
	barak._on_training_complete()
	_check("count is updated before training finishes", garrison.infantry == 1)
	_check("first queued troop keeps its type", seen == ["infantry"])
	barak._on_training_complete()
	_check("second queued troop keeps its type", seen == ["infantry", "archer"])

	for i in 8:
		_check("reserve infantry slot %d" % i, garrison.reserve_troop("infantry", 9))
		garrison.add_troops("infantry", 1)
	_check("active plus queued infantry cannot exceed nine", not garrison.can_reserve_troop("infantry", 9))
	garrison.complete_troop_training("infantry")
	_check("queued troops already count toward on-duty total", garrison.infantry == 9)
	_check("remaining reservations are retained", garrison.get_reserved_count("infantry") == 7)
	barak.queue_free()
	await process_frame


func _test_death_allows_replacement() -> void:
	var rc = load("res://scenes/run/RunController.gd").new()
	var garrison := PlayerGarrison.new()
	rc.garrison = garrison
	garrison.add_troops("archer", 9)
	var soldier := Node3D.new()
	rc._soldier_units.append(soldier)
	rc._on_soldier_died(soldier, "archer")
	rc._on_soldier_died(soldier, "archer")
	_check("a dead soldier frees exactly one active slot", garrison.archers == 8)
	_check("a replacement can be queued after death", garrison.reserve_troop("archer", 9))
	rc.free()


func _test_new_popup_counts_and_buttons() -> void:
	var garrison := PlayerGarrison.new()
	var barak := await _make_barak(garrison)
	var translation_manager: Node = root.get_node("/root/TranslationManager")
	garrison.add_troops("infantry", 2)
	garrison.add_troops("archer", 1)
	barak.show_overlay()
	_check("popup uses a centered styled panel",
		barak._overlay is Panel
		and barak._overlay.get_node("OnDutyTitle").horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER
		and barak._overlay_dim.visible)
	_check("popup shows both live troop counts",
		barak._overlay.get_node("InfantryCount").text.contains(": 2")
		and barak._overlay.get_node("ArcherCount").text.contains(": 1"))
	_check("separate add buttons are present",
		not barak._overlay.get_node("AddInfantryBtn").text.is_empty()
		and not barak._overlay.get_node("AddArcherBtn").text.is_empty())
	_check("close button is present",
		barak._overlay.get_node("CloseBtn").text == translation_manager.t("close"))
	garrison.add_troops("infantry", 6)
	garrison.reserve_troop("infantry", 9)
	garrison.add_troops("infantry", 1)
	_check("add button disables at active plus queued cap", barak._overlay.get_node("AddInfantryBtn").disabled)
	garrison.remove_troops("infantry", 1)
	_check("add button enables after a troop is lost", not barak._overlay.get_node("AddInfantryBtn").disabled)
	barak.hide_overlay()
	_check("backdrop closes with popup", not barak._overlay_dim.visible)
	barak.queue_free()
	await process_frame


func _test_add_troop_keeps_overlay_open() -> void:
	var save_manager: Node = root.get_node("/root/SaveManager")
	var translation_manager: Node = root.get_node("/root/TranslationManager")
	var original_gold: int = save_manager.gold
	save_manager.gold = 100
	var garrison := PlayerGarrison.new()
	var barak := await _make_barak(garrison)
	barak.show_overlay()

	var add_button: Button = barak._overlay.get_node("AddInfantryBtn")
	add_button.pressed.emit()
	_check("training starts", barak._training_queue == ["infantry"])
	_check("training keeps barracks overlay open", barak._overlay.visible)
	_check("infantry count refreshes while popup stays open", garrison.infantry == 1)

	var close_button: Button = barak._overlay.get_node("CloseBtn")
	_check("popup action is labeled close",
		close_button.text == translation_manager.t("close"))
	close_button.pressed.emit()
	_check("close button still closes barracks overlay", not barak._overlay.visible)

	barak.queue_free()
	await process_frame
	save_manager.gold = original_gold
