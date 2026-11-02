extends SceneTree

# Pins the iOS Unity Ads configuration and verifies the native reward callback
# is forwarded independently from the ad-completed callback.

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
	var ua = root.get_node_or_null("/root/UnityAds")
	_check("UnityAds autoload present", ua != null)
	if ua == null:
		quit(1)
		return
	_check("iOS game id remains configurable",
		ua.game_id() == ProjectSettings.get_setting("unity_ads/ios/game_id", ""))
	var placement: String = ProjectSettings.get_setting(
		"unity_ads/ios/placements/rewarded", "Rewarded_iOS")
	_check("iOS rewarded placement is configured", placement == "PF_Rewarded_iOS")
	_check("plugin absent headless is fine", not ua.is_available())

	var got := {"rewarded": false, "completed": false}
	ua.rewarded.connect(func(_id): got["rewarded"] = true)
	ua.ad_completed.connect(func(_id, _state): got["completed"] = true)
	ua._on_ad_completed("PF_Rewarded_iOS", "COMPLETED")
	_check("completion callback is forwarded", got["completed"])
	_check("completion is not mistaken for a reward", not got["rewarded"])
	ua._on_rewarded(placement)
	_check("native rewarded callback is forwarded", got["rewarded"])

	if failures > 0:
		push_error("unity ads config regression")
		quit(1)
	else:
		print("UNITY_ADS_CONFIG_PASS")
		quit(0)
