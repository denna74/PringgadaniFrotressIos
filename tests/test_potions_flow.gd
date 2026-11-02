extends SceneTree


func _initialize() -> void:
	_run()


func _backup_save() -> Dictionary:
	var sm = root.get_node("/root/SaveManager")
	if not FileAccess.file_exists(sm.save_path):
		return {"exists": false}
	var f := FileAccess.open(sm.save_path, FileAccess.READ)
	var text: String = f.get_as_text()
	f.close()
	return {"exists": true, "data": text}


func _restore_save(backup: Dictionary) -> void:
	var sm = root.get_node("/root/SaveManager")
	if backup.get("exists", false):
		var f := FileAccess.open(sm.save_path, FileAccess.WRITE)
		f.store_string(backup["data"])
		f.close()
	else:
		DirAccess.remove_absolute(sm.save_path)
	sm.load_game()


func _run() -> void:
	await process_frame
	var sm = root.get_node("/root/SaveManager")
	var backup: Dictionary = _backup_save()
	DirAccess.remove_absolute(sm.save_path)
	sm.load_game()
	sm.inventory.clear()

	var pass_all := true

	var all: Array[Dictionary] = ConsumableDatabase.get_all()
	var prices := {
		"health_potion_small": 700, "health_potion_big": 850, "health_potion_super": 1000,
		"mana_potion_small": 400, "mana_potion_big": 600, "mana_potion_super": 800,
		"stamina_potion_small": 200, "stamina_potion_big": 400, "stamina_potion_super": 600,
	}
	if all.size() != prices.size():
		push_error("consumables size = %d, expected %d" % [all.size(), prices.size()])
		pass_all = false
	for item in all:
		var item_id: String = item.get("id", "")
		if not prices.has(item_id):
			push_error("unexpected consumable id '%s'" % item_id)
			pass_all = false
			continue
		if item.get("price", 0) != prices[item_id]:
			push_error("price for %s = %d, expected %d" % [item_id, item.get("price", 0), prices[item_id]])
			pass_all = false
		if item.get("icon", "") == "" or item.get("use_icon", "") == "":
			push_error("item %s missing icon or use_icon" % item_id)
			pass_all = false

	var panel: Control = null
	if load("res://scenes/run/PotionsPanel.gd") == null:
		push_error("PotionsPanel.gd not found")
		pass_all = false
		_restore_save(backup)
		quit(1)
		return

	sm.add_to_inventory("health_potion_small", 2)
	sm.add_to_inventory("mana_potion_small", 1)
	sm.add_to_inventory("stamina_potion_big", 1)

	var kc: Node3D = load("res://scenes/run/KingController.tscn").instantiate()
	root.add_child(kc)
	kc.setup_king({"hp": 300.0, "attack": 25.0, "mana_max": 200.0, "stamina_max": 100.0})
	await process_frame

	panel = load("res://scenes/run/PotionsPanel.gd").new()
	root.add_child(panel)
	panel.setup(kc)
	await process_frame

	var tm = root.get_node("/root/TranslationManager")
	var original_language: String = tm.current_language
	tm.set_language("en")
	panel._open_popup()
	if not panel.get("_popup_open"):
		push_error("popup did not open")
		pass_all = false
	var popup: Control = panel.get("_popup")
	var potion_title: Label = popup.get_node("PotionPanel/PopupTitle")
	var cancel_button: Button = popup.get_node("PotionPanel/CancelButton")
	var potion_cells: Dictionary = panel.get("_cells")
	var health_button: Button = potion_cells["health_potion_small"]["button"]
	if potion_title.text != tm.t("potions_title") or cancel_button.text != tm.t("cancel"):
		push_error("potion popup labels do not match the selected language")
		pass_all = false
	if health_button.tooltip_text != "Small Health Potion":
		push_error("English potion tooltip is not translated")
		pass_all = false
	panel._close_popup()
	tm.set_language("id")
	panel._open_popup()
	popup = panel.get("_popup")
	potion_title = popup.get_node("PotionPanel/PopupTitle")
	cancel_button = popup.get_node("PotionPanel/CancelButton")
	potion_cells = panel.get("_cells")
	health_button = potion_cells["health_potion_small"]["button"]
	if potion_title.text != tm.t("potions_title") or cancel_button.text != tm.t("cancel"):
		push_error("Indonesian potion popup labels are not translated")
		pass_all = false
	if health_button.tooltip_text != "Ramuan HP Kecil":
		push_error("Indonesian potion tooltip is not translated")
		pass_all = false
	panel._close_popup()
	tm.set_language(original_language)
	panel._open_popup()
	if not BuildingUIState.is_popup_open():
		push_error("BuildingUIState not incremented while popup open")
		pass_all = false
	var cells: Dictionary = panel.get("_cells")
	if cells.size() != 9:
		push_error("popup cells = %d, expected 9" % cells.size())
		pass_all = false

	kc.take_damage(100.0)
	var popup_before_use: Control = panel.get("_popup")
	var hp_before_potion: float = kc.king_hp
	var aura: Node3D = kc.get("_aura")
	panel._consume("health_potion_small")
	if panel.get("_popup_open") or kc.king_hp != hp_before_potion:
		push_error("health potion should close the popup before applying its effect")
		pass_all = false
	await process_frame
	if is_instance_valid(popup_before_use):
		push_error("potion popup should be freed before applying the effect")
		pass_all = false
	if kc.king_hp < 250.0:
		push_error("health potion restore: hp = %s expected at least 250" % kc.king_hp)
		pass_all = false
	if not aura.get("emitting"):
		push_error("health potion aura should start after the popup closes")
		pass_all = false
	if sm.get_inventory_count("health_potion_small") != 1:
		push_error("health potion stock should be 1 after consume")
		pass_all = false

	kc.spend_mana(30.0)
	panel._open_popup()
	popup_before_use = panel.get("_popup")
	var mana_before_potion: float = kc.mana
	panel._consume("mana_potion_small")
	if panel.get("_popup_open") or kc.mana != mana_before_potion:
		push_error("mana potion should close the popup before applying its effect")
		pass_all = false
	await process_frame
	if is_instance_valid(popup_before_use):
		push_error("mana potion popup should be freed before applying the effect")
		pass_all = false
	if not is_equal_approx(kc.mana, 195.0):
		push_error("mana potion restore: mana = %s expected 195" % kc.mana)
		pass_all = false

	kc.stamina = 50.0
	panel._open_popup()
	popup_before_use = panel.get("_popup")
	var stamina_before_potion: float = kc.stamina
	panel._consume("stamina_potion_big")
	if panel.get("_popup_open") or kc.stamina != stamina_before_potion:
		push_error("stamina potion should close the popup before applying its effect")
		pass_all = false
	await process_frame
	if is_instance_valid(popup_before_use):
		push_error("stamina potion popup should be freed before applying the effect")
		pass_all = false
	if not is_equal_approx(kc.stamina, kc.stamina_max):
		push_error("stamina potion should refill to max")
		pass_all = false

	panel._open_popup()
	cells = panel.get("_cells")
	for item_id in cells:
		var cell: Dictionary = cells[item_id] as Dictionary
		var count: int = sm.get_inventory_count(item_id)
		var btn: Button = cell["button"] as Button
		if count <= 0 and not btn.disabled:
			push_error("cell %s should be disabled at 0 stock" % item_id)
			pass_all = false
		if count <= 0 and btn.modulate.a > 0.4:
			push_error("cell %s should be transparent at 0 stock" % item_id)
			pass_all = false
		if count > 0 and btn.disabled:
			push_error("cell %s should be enabled with stock" % item_id)
			pass_all = false

	sm.load_game()
	if sm.get_inventory_count("health_potion_small") != 1:
		push_error("health potion stock not persisted to save")
		pass_all = false

	panel._close_popup()
	if BuildingUIState.is_popup_open():
		push_error("BuildingUIState not decremented after popup close")
		pass_all = false

	BuildingUIState.note_popup_opened()
	panel._open_popup()
	if panel.get("_popup_open"):
		push_error("popup opened while another popup is already open")
		pass_all = false
	BuildingUIState.note_popup_closed()

	kc.queue_free()
	_restore_save(backup)
	if not pass_all:
		quit(1)
		return
	print("POTIONS_PASS")
	quit(0)