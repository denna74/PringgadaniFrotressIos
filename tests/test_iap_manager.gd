extends SceneTree

# The native StoreKit plugin is unavailable in headless tests, but product
# mapping and purchase event handling must remain testable.

var failures := 0


func _initialize() -> void:
	_run()


func _check(name: String, condition: bool) -> void:
	if condition:
		print("OK  ", name)
	else:
		push_error("FAIL " + name)
		failures += 1


func _run() -> void:
	await process_frame
	var iap = root.get_node("/root/IAPManager")
	_check("autoload present", iap != null)
	_check("native StoreKit plugin unavailable headless", not iap.is_available())
	_check("purchase unavailable headless",
		iap.purchase("com.pringgadanifortress.instant_gold_1")
		== iap.PurchaseResult.UNAVAILABLE)

	var billing_ready := {"fired": false}
	iap.billing_ready.connect(func(): billing_ready["fired"] = true)
	iap._on_products_loaded([
		{"id": "com.pringgadanifortress.instant_gold_1", "displayPrice": "Rp 15.000"},
		{"id": "com.pringgadanifortress.instant_gold_2", "displayPrice": "Rp 45.000"},
	])
	_check("products ready after successful fetch", iap.is_products_ready())
	_check("billing_ready emitted", billing_ready["fired"])
	_check("localized StoreKit price exposed",
		iap.get_formatted_price("com.pringgadanifortress.instant_gold_1") == "Rp 15.000")
	_check("unknown sku price empty", iap.get_formatted_price("unknown") == "")

	var received := {}
	iap.purchase_successful.connect(
		func(sku, token): received["sku"] = sku; received["token"] = token)
	iap._on_purchase_updated({
		"productId": "com.pringgadanifortress.instant_gold_2",
		"transactionId": "storekit-transaction",
	})
	_check("purchase event carries product and transaction",
		received.get("sku", "") == "com.pringgadanifortress.instant_gold_2"
		and received.get("token", "") == "storekit-transaction")

	var failed := {"sku": ""}
	iap.purchase_failed.connect(func(sku): failed["sku"] = sku)
	iap._on_purchase_error({"sku": "com.pringgadanifortress.instant_gold_3"})
	_check("purchase error emits sku",
		failed["sku"] == "com.pringgadanifortress.instant_gold_3")
	_check("canonicalizes native purchase keys",
		iap._to_canonical_purchase_dict({
			"product_id": "com.pringgadanifortress.instant_gold_1",
			"transaction_id": "tx",
		}).get("transactionId", "") == "tx")

	if failures > 0:
		push_error("iap manager regression")
		quit(1)
	else:
		print("IAP_MANAGER_PASS")
		quit(0)
