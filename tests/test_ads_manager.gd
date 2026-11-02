extends SceneTree

# Pins the one-ad rewarded flow: a single rewarded completion earns; skipped
# ads, failures, and timeouts abort; the init guard never re-initializes; only
# the configured rewarded placement can complete a flow.

# The stub (which extends the real AdsManager) is runtime-loaded, not
# preloaded: preload-time compilation runs before autoload globals exist,
# so any script referencing them must compile via load() instead.
# UnityAds is fetched from the tree for the same '-s' reason (run-pause ledger).
var StubAdsManager: GDScript
var _ua: Node
var failures := 0


func _initialize() -> void:
	_run()


func _check(name: String, cond: bool) -> void:
	if cond:
		print("OK  ", name)
	else:
		push_error("FAIL " + name)
		failures += 1


func _make_manager():
	var m = StubAdsManager.new()
	root.add_child(m)
	return m


func _make_label() -> Label:
	var label := Label.new()
	root.add_child(label)
	return label


func _run() -> void:
	await process_frame
	StubAdsManager = load("res://tests/stub_ads_manager.gd")
	_ua = root.get_node("/root/UnityAds")

	# StartResult + init guard
	var m = _make_manager()
	m._sdk_initialized = true
	var result: int = m.start_life_reward_flow(_make_label())
	_check("initialized SDK starts flow immediately",
		result == m.StartResult.SDK_READY and m.is_flow_active())
	m.queue_free()
	await process_frame

	m = _make_manager()
	result = m.start_life_reward_flow(null)
	_check("uninitialized SDK reports SDK_NOT_READY", result == m.StartResult.SDK_NOT_READY)
	_check("pending flow is armed", m._flow_pending)
	m.queue_free()
	await process_frame

	m = _make_manager()
	m._sdk_initialized = true
	m._ensure_sdk_initialized()
	_check("init guard skips initialize when ready", m.init_calls == 0)
	m._sdk_initialized = false
	m._ensure_sdk_initialized()
	_check("initialize called when not ready", m.init_calls == 1)
	m.queue_free()
	await process_frame

	# Load timeout aborts
	m = _make_manager()
	var got := {"failed": false}
	m.life_reward_failed.connect(func(): got["failed"] = true)
	m._kick_off_flow(_make_label())
	_check("flow active after kickoff", m.is_flow_active())
	await create_timer(0.7).timeout
	_check("load timeout emits life_reward_failed", got["failed"])
	_check("flow inactive after load timeout", not m.is_flow_active())
	m.queue_free()
	await process_frame

	# Show timeout aborts: loaded but never completes
	m = _make_manager()
	got = {"failed": false}
	m.life_reward_failed.connect(func(): got["failed"] = true)
	m._kick_off_flow(_make_label())
	_ua.ad_loaded.emit("PF_Rewarded_iOS")
	await create_timer(0.7).timeout
	_check("show timeout emits life_reward_failed", got["failed"])
	_check("flow inactive after show timeout", not m.is_flow_active())
	m.queue_free()
	await process_frame

	# Skipped ad aborts
	m = _make_manager()
	got = {"failed": false}
	m.life_reward_failed.connect(func(): got["failed"] = true)
	m._kick_off_flow(_make_label())
	_ua.ad_loaded.emit("PF_Rewarded_iOS")
	_ua.ad_completed.emit("PF_Rewarded_iOS", "SKIPPED")
	_check("skipped ad emits life_reward_failed", got["failed"])
	_check("flow inactive after skip", not m.is_flow_active())
	m.queue_free()
	await process_frame

	# Load failure aborts
	m = _make_manager()
	got = {"failed": false}
	m.life_reward_failed.connect(func(): got["failed"] = true)
	m._kick_off_flow(_make_label())
	_ua.ad_load_failed.emit("PF_Rewarded_iOS", "ERR", "load failed")
	_check("load failure aborts flow", got["failed"] and not m.is_flow_active())
	m.queue_free()
	await process_frame

	# No internet aborts
	m = _make_manager()
	m.force_no_internet = true
	got = {"failed": false}
	m.life_reward_failed.connect(func(): got["failed"] = true)
	m._kick_off_flow(_make_label())
	_check("no internet aborts flow", got["failed"] and not m.is_flow_active())
	m.queue_free()
	await process_frame

	# Pending flow fails on init failure
	m = _make_manager()
	got = {"failed": false}
	m.life_reward_failed.connect(func(): got["failed"] = true)
	result = m.start_life_reward_flow(null)
	_check("pending start returns SDK_NOT_READY", result == m.StartResult.SDK_NOT_READY)
	m._on_init_failed("TEST_ERROR", "init failed")
	_check("init failure fails pending flow", got["failed"] and not m.is_flow_active())
	m.queue_free()
	await process_frame

	# Pending flow auto-starts on init, then earns on the one ad
	m = _make_manager()
	var got_earned := {"earned": false}
	m.life_reward_earned.connect(func(): got_earned["earned"] = true)
	result = m.start_life_reward_flow(_make_label())
	_check("pending start before init", result == m.StartResult.SDK_NOT_READY)
	m._on_initialized()
	_check("flow kicked off after init", m.is_flow_active())
	_ua.rewarded.emit("PF_Rewarded_iOS")
	_check("rewarded after auto-start earns",
		got_earned["earned"] and not m.is_flow_active())
	m.queue_free()
	await process_frame

	# One rewarded completion earns
	m = _make_manager()
	got_earned = {"earned": false}
	m.life_reward_earned.connect(func(): got_earned["earned"] = true)
	m._kick_off_flow(_make_label())
	_ua.ad_loaded.emit("PF_Rewarded_iOS")
	_ua.ad_completed.emit("PF_Rewarded_iOS", "COMPLETED")
	_check("COMPLETED ad alone does not finish the flow",
		m.is_flow_active() and not got_earned["earned"])
	_ua.rewarded.emit("PF_Rewarded_iOS")
	_check("single rewarded completion earns", got_earned["earned"])
	_check("flow finished after reward", not m.is_flow_active())
	m.queue_free()
	await process_frame

	# Foreign placement cannot complete the flow
	m = _make_manager()
	got_earned = {"earned": false}
	m.life_reward_earned.connect(func(): got_earned["earned"] = true)
	m._kick_off_flow(_make_label())
	_ua.ad_loaded.emit("PF_Rewarded_iOS")
	_ua.ad_completed.emit("Some_Other_Placement", "COMPLETED")
	_check("foreign placement leaves flow running",
		m.is_flow_active() and not got_earned["earned"])
	_ua.ad_completed.emit("PF_Rewarded_iOS", "COMPLETED")
	_ua.rewarded.emit("PF_Rewarded_iOS")
	_check("our placement still completes after foreign noise",
		got_earned["earned"] and not m.is_flow_active())
	m.queue_free()
	await process_frame

	if failures > 0:
		push_error("ads manager regression")
		quit(1)
	else:
		print("ADS_MANAGER_PASS")
		quit(0)
