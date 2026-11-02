extends SceneTree

# The gold shop's SKU table is the contract with App Store Connect: three
# consumables with the agreed reward ladder, and a safe fallback.

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
	var cfg = load("res://autoload/IAPConfig.gd")
	_check("three skus", cfg.SKUS.size() == 3)
	_check("sku ids use the app bundle identifier",
		cfg.SKUS.get("instant_gold_1", "") == "com.pringgadanifortress.instant_gold_1"
		and cfg.SKUS.get("instant_gold_2", "") == "com.pringgadanifortress.instant_gold_2"
		and cfg.SKUS.get("instant_gold_3", "") == "com.pringgadanifortress.instant_gold_3")
	_check("get_sku resolves",
		cfg.get_sku("instant_gold_2") == "com.pringgadanifortress.instant_gold_2")
	_check("get_sku unknown empty", cfg.get_sku("nope") == "")
	_check("all consumable",
		cfg.get_type(cfg.get_sku("instant_gold_1")) == cfg.SkuType.CONSUMABLE
		and cfg.get_type(cfg.get_sku("instant_gold_2")) == cfg.SkuType.CONSUMABLE
		and cfg.get_type(cfg.get_sku("instant_gold_3")) == cfg.SkuType.CONSUMABLE)
	_check("reward tier 1 is 30000",
		cfg.get_gold_reward(cfg.get_sku("instant_gold_1")) == 30000)
	_check("reward tier 2 is 80000",
		cfg.get_gold_reward(cfg.get_sku("instant_gold_2")) == 80000)
	_check("reward tier 3 is 120000",
		cfg.get_gold_reward(cfg.get_sku("instant_gold_3")) == 120000)
	_check("unknown sku rewards 0", cfg.get_gold_reward("nope") == 0)
	if failures > 0:
		push_error("iap config regression")
		quit(1)
	else:
		print("IAP_CONFIG_PASS")
		quit(0)
