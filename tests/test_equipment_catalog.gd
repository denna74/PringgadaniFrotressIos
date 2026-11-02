extends SceneTree

var _fails: int = 0


func _initialize() -> void:
	_run()


func _check(name: String, ok: bool) -> void:
	if ok:
		print("OK  ", name)
	else:
		_fails += 1
		print("CHECK FAIL: " + name)


func _run() -> void:
	await process_frame

	var items: Array[Dictionary] = EquipmentDatabase.get_all()
	_check("25 accessories", items.size() == 25)

	var counts := {"head": 0, "hand": 0, "body": 0}
	var ids := {}
	var max_price := 0
	var top_count := 0
	for item in items:
		var item_type: String = item.get("type", "")
		counts[item_type] = counts.get(item_type, 0) + 1
		ids[item.get("id", "")] = true
		var price: int = item.get("price", 0)
		max_price = maxi(max_price, price)
		if price == 120000:
			top_count += 1
		_check("no unlock_stage on %s" % item.get("id", "?"), not item.has("unlock_stage"))
		_check("no description_en on %s" % item.get("id", "?"), not item.has("description_en"))
		_check("no description_id on %s" % item.get("id", "?"), not item.has("description_id"))
		var icon: String = item.get("icon", "")
		_check("icon exists for %s" % item.get("id", "?"), not icon.is_empty() and ResourceLoader.exists(icon))

	_check("9 head items", counts["head"] == 9)
	_check("9 hand items", counts["hand"] == 9)
	_check("7 body items", counts["body"] == 7)
	_check("ids are unique", ids.size() == 25)
	_check("most expensive item is 120000", max_price == 120000)
	_check("three top-tier items cost 120000", top_count == 3)

	var expected_prices := {
		"sumping_gajah_ngulun": 5000,
		"sumping_surengpati": 8000,
		"jamang_sungsang_bali": 13000,
		"makuta_rama": 20000,
		"kalung_banyu_rengga": 30000,
		"caping_basunanda": 45000,
		"pupuk_mas": 65000,
		"kuluk_kanigara": 90000,
		"garuda_mungkur": 120000,
		"cincin_setyaningampal": 6000,
		"cincin_mangkurawan": 10000,
		"cincin_palmukta": 16000,
		"gelang_candrakirana": 24000,
		"gelang_buntala": 36000,
		"kelatbau_candrakirana": 52000,
		"kelatbau_kiai_naga": 74000,
		"kelatbau_nagapasa": 98000,
		"kelatbau_wrekudara": 120000,
		"sabuk_cinde_puspita": 7000,
		"timang_purba": 12000,
		"timang_manikretna": 19000,
		"kawaca_kulit": 30000,
		"kawaca_wesi": 47000,
		"kawaca_ontorejo": 75000,
		"kawaca_antakusuma": 120000,
	}
	for id: String in expected_prices:
		var item: Dictionary = EquipmentDatabase.get_item(id)
		_check("price %s" % id, int(item.get("price", -1)) == expected_prices[id])

	_check("top head item", int(EquipmentDatabase.get_item("garuda_mungkur").get("price", 0)) == 120000)
	_check("top hand item", int(EquipmentDatabase.get_item("kelatbau_wrekudara").get("price", 0)) == 120000)
	_check("top body item", int(EquipmentDatabase.get_item("kawaca_antakusuma").get("price", 0)) == 120000)
	_check("old weapons removed", EquipmentDatabase.get_item("gada_besi").is_empty())

	if _fails == 0:
		print("EQUIPMENT_CATALOG_PASS")
		quit(0)
	else:
		print("EQUIPMENT_CATALOG_FAIL: %d" % _fails)
		quit(1)
