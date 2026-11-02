extends Node

# IAP manager using OpenIAP (StoreKit 2 on iOS).
# Registered as the `IAPManager` autoload in project.godot.
#
# Drives the `GodotIapPlugin` autoload (the GodotIapWrapper GDScript from
# addons/godot-iap), never the native `GodotIap` class directly — the native
# class only exposes camelCase native methods, while the friendly snake_case
# API lives on the wrapper.

const Types = preload("res://addons/godot-iap/types.gd")

signal purchase_successful(sku: String, token: String)
signal purchase_failed(sku: String)
signal billing_ready
signal purchases_restored

enum PurchaseResult { OK, NOT_INITIALIZED, NO_SKU, UNAVAILABLE, BUSY }

var _initialized: bool = false
var _products_ready: bool = false
var _product_details: Dictionary = {}
var _pending_restorations: Array[Dictionary] = []
var _purchases_by_token: Dictionary = {}
var _purchase_in_progress: bool = false
var last_products_status: String = ""
var _last_products_raw: Dictionary = {}
var _last_products_native_count: int = 0
var _last_products_error: String = ""

func _ready():
	await get_tree().process_frame
	var iap = _get_iap()
	if not iap:
		print("OpenIAP plugin not found")
		return
	iap.connected.connect(_on_connected)
	iap.disconnected.connect(_on_disconnected)
	iap.purchase_updated.connect(_on_purchase_updated)
	iap.purchase_error.connect(_on_purchase_error)
	iap.products_fetched.connect(_on_products_fetched_raw)
	var connected = await iap.init_connection()
	if connected and not _initialized:
		_on_connected()
	elif not connected:
		print("OpenIAP connection failed")

func _get_iap():
	return get_node_or_null("/root/GodotIapPlugin")

func is_available() -> bool:
	return (
		_get_iap() != null
		and ClassDB.class_exists("GodotIap")
		and ClassDB.can_instantiate("GodotIap")
	)

func is_initialized() -> bool:
	return _initialized

func is_products_ready() -> bool:
	return _products_ready

func get_product_details(sku: String) -> Dictionary:
	return _product_details.get(sku, {})

func get_formatted_price(sku: String) -> String:
	var details: Dictionary = _product_details.get(sku, {})
	return String(details.get("displayPrice", details.get("display_price", "")))

func get_pending_restorations() -> Array[Dictionary]:
	var result = _pending_restorations.duplicate()
	_pending_restorations.clear()
	return result

func _on_connected():
	if _initialized:
		return
	_initialized = true
	print("OpenIAP connected")
	_fetch_products()

func _on_disconnected():
	_initialized = false
	_products_ready = false
	print("OpenIAP disconnected")

func _on_products_fetched_raw(result: Dictionary) -> void:
	if not result.has("productsJson") and not result.has("products"):
		return
	_last_products_raw = result
	var products_json = String(result.get("productsJson", "[]"))
	var parsed = JSON.parse_string(products_json)
	_last_products_native_count = (parsed.size() if parsed is Array else 0)
	_last_products_error = String(result.get("error", ""))

func _fetch_products():
	var iap = _get_iap()
	if not iap:
		return
	var request = Types.ProductRequest.new()
	request.skus.assign(_get_all_skus())
	print("Fetching IAP products: ", request.skus)
	last_products_status = "Fetching: %s" % ", ".join(request.skus)
	var products = await iap.fetch_products(request)
	_on_products_loaded(products)

func _on_products_loaded(products: Array) -> void:
	_product_details.clear()
	for product in products:
		var details := _product_to_dict(product)
		var sku := String(details.get("id", details.get("productId", "")))
		if not sku.is_empty():
			_product_details[sku] = details
	if not _product_details.is_empty():
		_products_ready = true
		print("Product details loaded: ", _product_details.size(), " products")
		last_products_status = "Products: %s" % ", ".join(_get_all_skus())
		billing_ready.emit()
		_check_pending_restorations()
	else:
		print("Failed to load product details")
		if _last_products_native_count == 0 and _last_products_error.is_empty():
			last_products_status = "StoreKit returned no matching products"
		elif not _last_products_error.is_empty():
			last_products_status = "StoreKit error: %s" % _last_products_error

func _product_to_dict(product) -> Dictionary:
	if product is Dictionary:
		return product
	if product is Object and product.has_method("to_dict"):
		return product.to_dict()
	return {}

func _get_all_skus() -> Array:
	var skus := []
	for key in IAPConfig.SKUS:
		skus.append(IAPConfig.SKUS[key])
	return skus

func _check_pending_restorations():
	var iap = _get_iap()
	if not iap:
		return
	var result = await iap.get_available_purchases_result()
	if not result.get("success", false):
		return
	var purchases = result.get("purchases", [])
	if purchases.is_empty():
		print("No pending purchases to restore")
		return
	print("Found ", purchases.size(), " purchase(s) to reconcile")
	for purchase in purchases:
		var purchase_dict = _to_canonical_purchase_dict(purchase)
		if purchase_dict.is_empty():
			continue
		var product_id = purchase_dict.get("productId", "")
		if product_id.is_empty():
			continue
		if not _is_purchased(purchase_dict.get("purchaseState", "")):
			continue
		var token = purchase_dict.get("transactionId", "")
		if token.is_empty():
			continue
		if SaveManager.is_purchase_processed(token):
			print("Purchase already delivered, cleaning up: ", product_id, " token=", token)
			_acknowledge_purchase(purchase_dict, product_id)
		else:
			_purchases_by_token[token] = purchase_dict
			print("Pending delivery for: ", product_id, " token=", token)
			_pending_restorations.append({"sku": product_id, "token": token})
	if not _pending_restorations.is_empty():
		purchases_restored.emit()

func _to_canonical_purchase_dict(purchase) -> Dictionary:
	var purchase_dict: Dictionary
	if purchase is Dictionary:
		purchase_dict = purchase
	elif purchase is Object and purchase.has_method("to_dict"):
		purchase_dict = purchase.to_dict()
	else:
		return {}
	if String(purchase_dict.get("productId", "")) != "":
		return purchase_dict
	var mapped := purchase_dict.duplicate(true)
	if not mapped.has("productId") and mapped.has("product_id"):
		mapped["productId"] = mapped["product_id"]
	if not mapped.has("transactionId") and mapped.has("transaction_id"):
		mapped["transactionId"] = mapped["transaction_id"]
	if not mapped.has("purchaseState") and mapped.has("purchase_state"):
		mapped["purchaseState"] = mapped["purchase_state"]
	mapped.erase("product_id")
	mapped.erase("transaction_id")
	mapped.erase("purchase_state")
	if String(mapped.get("productId", "")) != "":
		return mapped
	return {}

func _is_purchased(state) -> bool:
	if state is int:
		return state == Types.PurchaseState.PURCHASED
	return String(state).strip_edges().to_lower() == "purchased"

func purchase(sku: String) -> int:
	var iap = _get_iap()
	if not is_available() or not iap:
		return PurchaseResult.UNAVAILABLE
	if not _initialized:
		return PurchaseResult.NOT_INITIALIZED
	if not _products_ready:
		return PurchaseResult.NOT_INITIALIZED
	if _purchase_in_progress:
		return PurchaseResult.BUSY
	if sku.is_empty():
		return PurchaseResult.NO_SKU
	var props = {
		"requestPurchase": {
			"apple": {"sku": sku}
		},
		"type": "in-app"
	}
	_purchase_in_progress = true
	var request_result = iap.request_purchase(props)
	if request_result is Dictionary and not request_result.get("success", true):
		_purchase_in_progress = false
		return PurchaseResult.UNAVAILABLE
	return PurchaseResult.OK

func finalize_purchase(token: String, sku: String):
	if token.is_empty() or sku.is_empty():
		return
	var purchase = _purchases_by_token.get(token, {})
	if purchase.is_empty():
		print("finalize_purchase: no stored purchase for token=", token, " sku=", sku)
		return
	_acknowledge_purchase(purchase, sku)
	_purchases_by_token.erase(token)

func _acknowledge_purchase(purchase: Dictionary, sku: String):
	var iap = _get_iap()
	if not iap:
		return
	var is_consumable: bool = IAPConfig.get_type(sku) == IAPConfig.SkuType.CONSUMABLE
	iap.finish_transaction_dict(purchase, is_consumable)

func _on_purchase_updated(purchase: Dictionary):
	_purchase_in_progress = false
	var product_id = purchase.get("productId", "")
	var token = purchase.get("transactionId", "")
	if product_id.is_empty() or token.is_empty():
		return
	print("Purchase updated: ", product_id, " token=", token)
	_purchases_by_token[token] = purchase
	purchase_successful.emit(product_id, token)

func _on_purchase_error(error: Dictionary):
	_purchase_in_progress = false
	print("Purchase failed: ", error.get("message", "unknown"))
	var sku = error.get("sku", error.get("productId", ""))
	purchase_failed.emit(sku)
