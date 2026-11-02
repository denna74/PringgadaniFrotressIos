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
	var ok := true
	var sm = root.get_node("/root/SaveManager")
	var econ = root.get_node("/root/EconomyManager")
	var backup: Dictionary = _backup_save()

	DirAccess.remove_absolute(sm.save_path)
	sm.gold = -999
	sm.load_game()
	if sm.gold != 5000:
		push_error("fresh install gold = %d, expected 5000" % sm.gold)
		ok = false

	sm.gold = 1000
	var wallet: int = sm.gold
	econ.begin_run()
	if econ.get_gold() != wallet or sm.gold != wallet:
		push_error("begin_run changed the wallet")
		ok = false

	if not econ.spend(30):
		push_error("spend(30) failed")
		ok = false
	wallet -= 30
	if sm.gold != wallet:
		push_error("wallet after spend = %d, expected %d" % [sm.gold, wallet])
		ok = false
	sm.load_game()
	if sm.gold != wallet:
		push_error("spend did not persist (loaded %d, expected %d)" % [sm.gold, wallet])
		ok = false

	econ.add_pending(25)
	econ.add_pending(15)
	if econ.get_pending() != 40:
		push_error("pending = %d, expected 40" % econ.get_pending())
		ok = false
	if sm.gold != wallet:
		push_error("add_pending changed the wallet")
		ok = false

	wallet = sm.gold
	var mine: int = econ.get_pending()
	var reward := 140
	sm.add_gold(mine + reward)
	wallet += mine + reward
	if sm.gold != wallet:
		push_error("win commit total = %d, expected %d" % [sm.gold, wallet])
		ok = false
	econ.end_run()
	if econ.get_pending() != 0:
		push_error("end_run did not clear pending")
		ok = false
	if sm.gold != wallet:
		push_error("end_run changed the wallet")
		ok = false

	_restore_save(backup)
	if ok:
		print("GOLD_UNIFIED_PASS")
		quit(0)
	else:
		push_error("GoldUnified regression")
		quit(1)