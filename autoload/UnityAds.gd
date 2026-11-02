extends Node
## Autoload bridge to the GodotUnityAds iOS plugin (see ios/plugins/unity-ads).
## Mirrors the Android addons/unityads/unity_ads.gd interface so the game code
## behaves identically on both platforms.
## All config lives in Project Settings → Unity Ads — nothing is hardcoded.
## On editor/desktop (no iOS plugin) the singleton is absent → calls are no-ops.

signal initialized
signal init_failed(error: String, message: String)
signal ad_loaded(placement_id: String)
signal ad_load_failed(placement_id: String, error: String, message: String)
signal ad_completed(placement_id: String, state: String)
signal ad_show_failed(placement_id: String, error: String, message: String)
signal rewarded(placement_id: String)

## Default placement IDs. The iOS placement name defaults to "Rewarded_iOS";
## set the real placement in Project Settings → unity_ads → ios → placements.
const DEFAULT_REWARDED := "Rewarded_iOS"
const DEFAULT_INTERSTITIAL := "Interstitial_iOS"
const DEFAULT_BANNER := "Banner_iOS"

var _plugin: Object = null


func _ready() -> void:
	if Engine.has_singleton("GodotUnityAds"):
		_plugin = Engine.get_singleton("GodotUnityAds")
		_connect_plugin()
	else:
		push_warning("GodotUnityAds plugin not found — run on iOS with the plugin enabled.")

	if _get_bool("unity_ads/auto_initialize", true) and not game_id().is_empty():
		initialize()


func is_available() -> bool:
	return _plugin != null


func game_id() -> String:
	return _get_string("unity_ads/ios/game_id")


func initialize() -> void:
	if _plugin:
		_plugin.initialize(game_id(), _get_bool("unity_ads/test_mode", true))


func load_ad(placement_id: String) -> void:
	if _plugin:
		_plugin.load_ad(placement_id)


func show_ad(placement_id: String) -> void:
	if _plugin:
		_plugin.show_ad(placement_id)


func load_interstitial() -> void:
	load_ad(rewarded_placement())


func show_interstitial() -> void:
	show_ad(rewarded_placement())


func load_rewarded() -> void:
	load_ad(rewarded_placement())


func show_rewarded() -> void:
	show_ad(rewarded_placement())


## Not supported on iOS rewarded flow; kept for interface parity.
func load_banner(position: String = "bottom_center") -> void:
	if _plugin:
		_plugin.load_banner(rewarded_placement(), position)


func show_banner() -> void:
	if _plugin:
		_plugin.show_banner()


func hide_banner() -> void:
	if _plugin:
		_plugin.hide_banner()


func destroy_banner() -> void:
	if _plugin:
		_plugin.destroy_banner()


func _connect_plugin() -> void:
	_plugin.connect("initialized", func(): initialized.emit())
	_plugin.connect("init_failed", func(e, m): init_failed.emit(e, m))
	_plugin.connect("ad_loaded", func(p): ad_loaded.emit(p))
	_plugin.connect("ad_load_failed", func(p, e, m): ad_load_failed.emit(p, e, m))
	_plugin.connect("ad_completed", _on_ad_completed)
	_plugin.connect("ad_show_failed", func(p, e, m): ad_show_failed.emit(p, e, m))
	_plugin.connect("rewarded", _on_rewarded)


func rewarded_placement() -> String:
	return _get_string("unity_ads/ios/placements/rewarded", DEFAULT_REWARDED)


func _on_rewarded(placement_id: String) -> void:
	rewarded.emit(placement_id)


func _on_ad_completed(placement_id: String, state: String) -> void:
	ad_completed.emit(placement_id, state)


func _get_string(setting_name: String, default: String = "") -> String:
	return str(ProjectSettings.get_setting(setting_name, default))


func _get_bool(setting_name: String, default: bool = false) -> bool:
	return bool(ProjectSettings.get_setting(setting_name, default))
