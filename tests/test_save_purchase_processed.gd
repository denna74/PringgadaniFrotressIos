extends SceneTree

# Purchase tokens must be recorded so a restore/reconcile pass never delivers
# the same gold twice. The record lives in the save payload and round-trips.

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
	var sm = root.get_node("/root/SaveManager")
	sm.processed_purchases = {}

	_check("unknown token reports false", not sm.is_purchase_processed("tok_a"))
	sm.mark_purchase_processed("tok_a", "instant_gold_1")
	_check("marked token reports true", sm.is_purchase_processed("tok_a"))
	_check("sku recorded", sm.processed_purchases.get("tok_a", "") == "instant_gold_1")

	sm.save_game()
	var file := FileAccess.open(sm.save_path, FileAccess.READ)
	var data := JSON.parse_string(file.get_as_text()) as Dictionary
	file.close()
	_check("payload carries processed_purchases", data.has("processed_purchases"))
	var persisted: Dictionary = data.get("processed_purchases", {})
	_check("token persists in payload", persisted.get("tok_a", "") == "instant_gold_1")

	sm.processed_purchases = {}
	sm.load_game()
	_check("token survives load_game", sm.is_purchase_processed("tok_a"))

	sm.processed_purchases = {}
	sm.save_game()
	if failures > 0:
		push_error("purchase-processed regression")
		quit(1)
	else:
		print("SAVE_PURCHASE_PROCESSED_PASS")
		quit(0)
