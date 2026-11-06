extends SceneTree


var _fails: int = 0


func _initialize() -> void:
	_run()


func _fail(msg: String) -> void:
	_fails += 1
	print("CHECK FAIL: " + msg)


func _run() -> void:
	for entry: Array in [
		[1, "kalapracona_campaign"],
		[10, "kalapracona_campaign"],
		[11, "aswatama_campaign"],
		[30, "aswatama_campaign"],
		[31, "boma_campaign"],
		[60, "boma_campaign"],
		[61, "karna_campaign"],
		[90, "karna_campaign"],
		[91, "kalapracona_boma_campaign"],
		[130, "kalapracona_boma_campaign"],
		[131, "kalapracona_aswatama_campaign"],
		[170, "kalapracona_aswatama_campaign"],
		[171, "boma_aswatama_campaign"],
		[210, "boma_aswatama_campaign"],
		[211, "three_kings_campaign"],
		[250, "three_kings_campaign"],
		[251, "all_kings_campaign"],
		[9999, "all_kings_campaign"],
	]:
		_expect(int(entry[0]), str(entry[1]))

	var last_tier_index: int = -1
	var tier_order := [
		"kalapracona_campaign", "aswatama_campaign", "boma_campaign",
		"karna_campaign", "kalapracona_boma_campaign",
		"kalapracona_aswatama_campaign", "boma_aswatama_campaign",
		"three_kings_campaign", "all_kings_campaign",
	]
	var previous_boss: String = ProgressionData.final_boss_id(1)
	var previous_tier: String = ProgressionData.campaign_tier(1)
	for stage in range(1, 500):
		var tier: String = ProgressionData.campaign_tier(stage)
		var tier_index: int = tier_order.find(tier)
		if tier_index < last_tier_index:
			_fail("stage %d moves backward to campaign tier %s" % [stage, tier])
			break
		last_tier_index = maxi(last_tier_index, tier_index)

		if ProgressionData.final_boss_id(stage) != previous_boss and tier == previous_tier:
			_fail("stage %d changes final boss without changing campaign tier" % stage)
		previous_boss = ProgressionData.final_boss_id(stage)
		previous_tier = tier

		if ProgressionData.campaign_title(stage) in ["", "Unknown"]:
			_fail("stage %d has no campaign title" % stage)
			break

	if _fails == 0:
		print("VERIFY_PASS: campaign tiers follow boss rosters")
		quit(0)
	else:
		print("VERIFY_FAIL: %d checks failed" % _fails)
		quit(1)


func _expect(stage: int, tier: String) -> void:
	var got: String = ProgressionData.campaign_tier(stage)
	if got != tier:
		_fail("stage %d: expected %s, got %s" % [stage, tier, got])
