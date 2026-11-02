extends SceneTree

# A key missing from either language file (or equal to its own key) shows the
# raw key in the shipped UI, so both tables must carry every new string.

var failures := 0

const REQUIRED_KEYS := [
	"instant_gold_label",
	"instant_life_label",
	"instant_gold_title",
	"instant_life_title",
	"instant_life_desc",
	"instant_life_watch",
	"no_lives_title",
	"no_lives_refill",
	"no_lives_refilled",
	"life_ad_loading",
	"life_ad_watch",
	"life_ad_failed",
	"life_ad_no_internet",
	"iap_purchasing",
	"iap_not_ready",
	"iap_unavailable",
	"iap_purchase_failed",
]


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
	var en := JSON.parse_string(
		FileAccess.get_file_as_string("res://resources/strings/strings_en.json")
	) as Dictionary
	var idn := JSON.parse_string(
		FileAccess.get_file_as_string("res://resources/strings/strings_id.json")
	) as Dictionary
	_check("both tables parse", en != null and idn != null)
	if en == null or idn == null:
		quit(1)
		return
	for key in REQUIRED_KEYS:
		_check("en has " + key, en.has(key) and str(en[key]) != key)
		_check("id has " + key, idn.has(key) and str(idn[key]) != key)
	_check("id differs from en for gold label",
		str(en["instant_gold_label"]) != str(idn["instant_gold_label"]))
	_check("id differs from en for life label",
		str(en["instant_life_label"]) != str(idn["instant_life_label"]))
	if failures > 0:
		push_error("instant strings regression")
		quit(1)
	else:
		print("INSTANT_STRINGS_PASS")
		quit(0)
