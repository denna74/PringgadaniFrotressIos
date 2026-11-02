extends Node

## SKU table for the Instant Gold shop, with rewards tuned for this game's economy.

enum SkuType { CONSUMABLE, NON_CONSUMABLE }

const SKUS := {
	"instant_gold_1": "com.pringgadanifortress.instant_gold_1",
	"instant_gold_2": "com.pringgadanifortress.instant_gold_2",
	"instant_gold_3": "com.pringgadanifortress.instant_gold_3",
}

const SKU_TYPES := {
	"com.pringgadanifortress.instant_gold_1": SkuType.CONSUMABLE,
	"com.pringgadanifortress.instant_gold_2": SkuType.CONSUMABLE,
	"com.pringgadanifortress.instant_gold_3": SkuType.CONSUMABLE,
}

const GOLD_REWARDS := {
	"com.pringgadanifortress.instant_gold_1": 30000,
	"com.pringgadanifortress.instant_gold_2": 80000,
	"com.pringgadanifortress.instant_gold_3": 120000,
}

static func get_sku(key: String) -> String:
	return SKUS.get(key, "")


static func get_gold_reward(sku: String) -> int:
	return GOLD_REWARDS.get(sku, 0)


static func get_type(sku: String) -> SkuType:
	return SKU_TYPES.get(sku, SkuType.CONSUMABLE)
