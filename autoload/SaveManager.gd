extends Node


signal gold_changed(value: int)
signal stage_number_changed(value: int)
signal lives_changed(value: int)
signal lives_refill_tick(seconds_left: int)
signal skill_level_changed(id: String, level: int)
signal building_upgrade_level_changed(id: String, level: int)

const REAL_SAVE_PATH := "user://pringgadani.save"
const TEST_SAVE_PREFIX := "user://pringgadani_test_"

const STARTING_GOLD := 5000
const LIFE_REFILL_SECONDS := 3600
const DEFAULT_SKILL_LEVELS := {"dash": 1, "earthquake": 1, "berserk": 1}
const DEFAULT_BUILDING_UPGRADE_LEVELS := {
	"pendopo": 1,
	"menara": 1,
	"barak": 1,
	"tambang_emas": 1,
}
const EQUIPMENT_SLOTS := ["head", "body", "right_hand", "left_hand"]
const DEFAULT_EQUIPMENT := {
	"head": "",
	"body": "",
	"right_hand": "",
	"left_hand": "",
}

var _save_path: String = REAL_SAVE_PATH
var save_path: String:
	get:
		return _test_save_path() if _running_in_script_mode() else _save_path
	set(value):
		_save_path = value

var stage_number: int = 1
var gold: int = STARTING_GOLD
var heroes: Dictionary = {}
var stage_stars: Dictionary = {}
var pusaka_collected: Array = []
var achievements: Array = []
var bestiary_kills: Dictionary = {}
var total_runs_completed: int = 0
var total_victories: int = 0
var last_login: int = 0
var lives: int = 3
var max_lives: int = 3
var last_life_loss_time: int = 0
var pending_run_loss: bool = false
var skill_levels: Dictionary = DEFAULT_SKILL_LEVELS.duplicate()
var building_upgrade_levels: Dictionary = DEFAULT_BUILDING_UPGRADE_LEVELS.duplicate()
var _refill_timer: Timer = null
var equipment: Dictionary = DEFAULT_EQUIPMENT.duplicate()
var inventory: Array = []
## Purchase tokens already delivered, so a billing reconcile pass never
## grants the same purchase twice. Keyed by purchase token -> sku.
var processed_purchases: Dictionary = {}


func _ready() -> void:
	# Script-mode runs use a per-process save so tests cannot read, overwrite, or
	# interfere with another test's data or the player's real progress.
	if _running_in_script_mode():
		var test_path := _test_save_path()
		# Every test process starts from a clean slate, so results never depend on what a
		# previous test left behind -- and never on the player's real progress.
		if FileAccess.file_exists(test_path):
			DirAccess.remove_absolute(test_path)
	_setup_refill_timer()
	load_game()
	apply_pending_run_loss_if_any()
	if heroes.is_empty():
		heroes["gatotkaca"] = {"level": 1, "stars": 1, "xp": 0}
	_sync_refill_timer()


func _running_in_script_mode() -> bool:
	var args: PackedStringArray = OS.get_cmdline_args()
	return args.has("-s") or args.has("--script")


func _test_save_path() -> String:
	return "%s%d.save" % [TEST_SAVE_PREFIX, OS.get_process_id()]


func _exit_tree() -> void:
	if _running_in_script_mode() and FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(save_path)


func _setup_refill_timer() -> void:
	_refill_timer = Timer.new()
	_refill_timer.name = "LifeRefillTimer"
	_refill_timer.wait_time = 1.0
	_refill_timer.one_shot = false
	_refill_timer.autostart = false
	# The clock must keep running while a run screen is frozen (paused) so lives still
	# refill and countdown labels keep ticking.
	_refill_timer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_refill_timer)
	_refill_timer.timeout.connect(_on_refill_tick)


func save_game() -> void:
	var data: Dictionary = {
		"stage_number": stage_number,
		"gold": gold,
		"heroes": heroes,
		"stage_stars": stage_stars,
		"pusaka_collected": pusaka_collected,
		"achievements": achievements,
		"bestiary_kills": bestiary_kills,
		"total_runs_completed": total_runs_completed,
		"total_victories": total_victories,
		"last_login": Time.get_unix_time_from_system(),
		"lives": lives,
		"last_life_loss_time": last_life_loss_time,
		"pending_run_loss": pending_run_loss,
		"equipment": equipment,
		"inventory": inventory,
		"processed_purchases": processed_purchases,
		"skill_levels": skill_levels,
		"building_upgrade_levels": building_upgrade_levels,
	}
	var file: FileAccess = FileAccess.open(save_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))
		file.close()


func load_game() -> void:
	if not FileAccess.file_exists(save_path):
		last_login = Time.get_unix_time_from_system()
		gold = STARTING_GOLD
		return
	var file: FileAccess = FileAccess.open(save_path, FileAccess.READ)
	if file:
		var data: Dictionary = JSON.parse_string(file.get_as_text()) as Dictionary
		stage_number = max(1, data.get("stage_number", data.get("level_number", data.get("run_number", 1))))
		gold = data.get("gold", 0)
		heroes = data.get("heroes", {})
		stage_stars = data.get("stage_stars", {})
		pusaka_collected = data.get("pusaka_collected", [])
		achievements = data.get("achievements", [])
		bestiary_kills = data.get("bestiary_kills", {})
		total_runs_completed = data.get("total_runs_completed", 0)
		total_victories = data.get("total_victories", 0)
		last_login = data.get("last_login", Time.get_unix_time_from_system())
		lives = data.get("lives", 3)
		last_life_loss_time = data.get("last_life_loss_time", 0)
		pending_run_loss = data.get("pending_run_loss", false)
		var loaded_equip: Dictionary = data.get("equipment", {})
		equipment = DEFAULT_EQUIPMENT.duplicate()
		for slot: String in EQUIPMENT_SLOTS:
			equipment[slot] = String(loaded_equip.get(slot, ""))
		var loaded_inv: Array = data.get("inventory", [])
		if not loaded_inv.is_empty():
			inventory = loaded_inv
		sanitize_equipment()
		processed_purchases = data.get("processed_purchases", {})
		skill_levels = DEFAULT_SKILL_LEVELS.duplicate()
		var loaded_skills: Dictionary = data.get("skill_levels", {})
		for id in loaded_skills:
			if DEFAULT_SKILL_LEVELS.has(id):
				skill_levels[id] = clampi(int(loaded_skills[id]), 1, SkillData.MAX_LEVEL)
		building_upgrade_levels = DEFAULT_BUILDING_UPGRADE_LEVELS.duplicate()
		var loaded_building_levels: Dictionary = data.get("building_upgrade_levels", {})
		for id in loaded_building_levels:
			if DEFAULT_BUILDING_UPGRADE_LEVELS.has(id):
				building_upgrade_levels[id] = clampi(
					int(loaded_building_levels[id]), 1, BuildingUpgradeData.MAX_LEVEL
				)
		file.close()
		apply_elapsed_refills()


func add_gold(amount: int) -> void:
	gold += amount
	gold_changed.emit(gold)
	save_game()


func is_purchase_processed(token: String) -> bool:
	return processed_purchases.has(token)


func mark_purchase_processed(token: String, sku: String) -> void:
	processed_purchases[token] = sku


func spend_gold(amount: int) -> bool:
	if gold < amount:
		return false
	gold -= amount
	gold_changed.emit(gold)
	save_game()
	return true


func get_skill_level(id: String) -> int:
	return clampi(int(skill_levels.get(id, 1)), 1, SkillData.MAX_LEVEL)


func upgrade_skill(id: String) -> bool:
	if not DEFAULT_SKILL_LEVELS.has(id):
		return false
	var level: int = get_skill_level(id)
	if level >= SkillData.MAX_LEVEL:
		return false
	var cost: int = SkillData.upgrade_cost(id, level)
	if gold < cost:
		return false
	gold -= cost
	skill_levels[id] = level + 1
	gold_changed.emit(gold)
	skill_level_changed.emit(id, level + 1)
	save_game()
	return true


func get_building_upgrade_level(id: String) -> int:
	if not DEFAULT_BUILDING_UPGRADE_LEVELS.has(id):
		return 1
	return clampi(
		int(building_upgrade_levels.get(id, 1)), 1, BuildingUpgradeData.MAX_LEVEL
	)


func upgrade_building(id: String) -> bool:
	if not DEFAULT_BUILDING_UPGRADE_LEVELS.has(id):
		return false
	var level: int = get_building_upgrade_level(id)
	if level >= BuildingUpgradeData.MAX_LEVEL:
		return false
	var cost: int = BuildingUpgradeData.upgrade_cost(id, level)
	if gold < cost:
		return false
	gold -= cost
	building_upgrade_levels[id] = level + 1
	gold_changed.emit(gold)
	building_upgrade_level_changed.emit(id, level + 1)
	save_game()
	return true


func increment_stage() -> void:
	stage_number += 1
	stage_number_changed.emit(stage_number)
	save_game()


func complete_stage(stage: int) -> void:
	total_runs_completed += 1
	total_victories += 1
	save_game()


const MAX_STAGE_STARS: int = 3


## The best star rating this stage has ever earned, or 0 if it was never cleared.
func get_stage_stars(stage: int) -> int:
	return int(stage_stars.get(str(stage), 0))


## Files the rating for a stage, keeping the best one so far, and returns what the
## stage now holds. A stage cleared well is not taken back down by a later run that
## went badly, so replaying can only ever improve a node. Keys are strings because
## JSON object keys are, and the save only happens on an actual improvement.
func record_stage_stars(stage: int, stars: int) -> int:
	var clamped: int = clampi(stars, 0, MAX_STAGE_STARS)
	var key := str(stage)
	var best: int = int(stage_stars.get(key, 0))
	if clamped <= best:
		return best
	stage_stars[key] = clamped
	save_game()
	return clamped


func calculate_offline_earnings() -> int:
	var now: int = Time.get_unix_time_from_system()
	var hours_away: float = (now - last_login) / 3600.0
	last_login = now

	var multiplier: float = min(1.0, hours_away / 2.0)
	var earnings: int = floori(50.0 * multiplier * max(1, stage_number))
	return earnings


func add_king_xp(amount: int) -> Dictionary:
	var save_data: Dictionary = heroes.get("gatotkaca", {}) as Dictionary
	var level: int = save_data.get("level", 1)
	var stars: int = save_data.get("stars", 1)
	var xp: int = save_data.get("xp", 0)
	var xp_to_next: int = ProgressionData.xp_to_next(level)
	var xp_gained := maxi(amount, 0)
	var levels_gained := 0

	if level >= ProgressionData.MAX_KING_LEVEL:
		heroes["gatotkaca"] = {"level": level, "stars": stars, "xp": 0}
		save_game()
		return {
			"levels_gained": 0,
			"xp_gained": 0,
			"level": level,
			"xp": 0,
			"xp_to_next": 0,
			"max_level": true,
		}

	xp += xp_gained
	# xp_to_next() returns 0 at the cap, so guard the loop on the cap explicitly.
	while xp >= xp_to_next and level < ProgressionData.MAX_KING_LEVEL:
		xp -= xp_to_next
		level += 1
		levels_gained += 1
		xp_to_next = ProgressionData.xp_to_next(level)

	var at_max: bool = level >= ProgressionData.MAX_KING_LEVEL
	if at_max:
		xp = 0

	heroes["gatotkaca"] = {"level": level, "stars": stars, "xp": xp}
	save_game()
	return {
		"levels_gained": levels_gained,
		"xp_gained": xp_gained,
		"level": level,
		"xp": xp,
		"xp_to_next": xp_to_next,
		"max_level": at_max,
	}


func lose_life() -> void:
	if lives > 0:
		lives -= 1
		last_life_loss_time = Time.get_unix_time_from_system()
		lives_changed.emit(lives)
		save_game()
	_sync_refill_timer()


func set_pending_run_loss(value: bool) -> void:
	pending_run_loss = value


func apply_pending_run_loss_if_any() -> void:
	if not pending_run_loss:
		return
	pending_run_loss = false
	if lives > 0:
		lose_life()
	else:
		save_game()


func refill_life() -> void:
	if lives < max_lives:
		lives += 1
		lives_changed.emit(lives)
		save_game()
	_sync_refill_timer()


func get_lives_refill_seconds() -> int:
	if lives >= max_lives:
		return 0
	var time_since_loss: int = int(Time.get_unix_time_from_system()) - last_life_loss_time
	var remaining: int = LIFE_REFILL_SECONDS - (time_since_loss % LIFE_REFILL_SECONDS)
	return remaining


## Grants every life earned by the wall clock since the last loss, advancing the clock
## by exactly the whole hours spent so a second call never double-grants. Runs on load
## (offline catch-up) and once a second while a life is missing.
func apply_elapsed_refills() -> void:
	if lives < max_lives and last_life_loss_time != 0:
		var now := int(Time.get_unix_time_from_system())
		var elapsed := now - last_life_loss_time
		var lives_earned := int(elapsed / LIFE_REFILL_SECONDS)
		if lives_earned > 0:
			var new_lives := mini(lives + lives_earned, max_lives)
			var total_refilled := new_lives - lives
			lives = new_lives
			last_life_loss_time += total_refilled * LIFE_REFILL_SECONDS
			lives_changed.emit(lives)
			save_game()
	_sync_refill_timer()


func _on_refill_tick() -> void:
	apply_elapsed_refills()
	lives_refill_tick.emit(get_lives_refill_seconds())
	_sync_refill_timer()


func _sync_refill_timer() -> void:
	if _refill_timer == null:
		return
	if lives < max_lives:
		if _refill_timer.is_stopped():
			_refill_timer.start()
	elif not _refill_timer.is_stopped():
		_refill_timer.stop()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()


func equip_item(slot: String, item_id: String) -> bool:
	if not EQUIPMENT_SLOTS.has(slot):
		return false
	if not EquipmentDatabase.can_equip(item_id, slot):
		return false
	if get_inventory_count(item_id) <= 0:
		return false
	var item: Dictionary = EquipmentDatabase.get_item(item_id)
	if item.get("type", "") == "hand":
		for hand: String in ["right_hand", "left_hand"]:
			if hand != slot and equipment.get(hand, "") == item_id:
				equipment[hand] = ""
	equipment[slot] = item_id
	save_game()
	return true


func unequip_slot(slot: String) -> bool:
	if not EQUIPMENT_SLOTS.has(slot):
		return false
	equipment[slot] = ""
	save_game()
	return true


func get_equipped(slot: String) -> String:
	if not EQUIPMENT_SLOTS.has(slot):
		return ""
	return equipment.get(slot, "")


func sanitize_equipment() -> void:
	var sanitized: Dictionary = DEFAULT_EQUIPMENT.duplicate()
	var claimed_hands: Dictionary = {}
	for slot: String in EQUIPMENT_SLOTS:
		var item_id: String = String(equipment.get(slot, ""))
		if item_id.is_empty():
			continue
		if not EquipmentDatabase.can_equip(item_id, slot):
			continue
		if get_inventory_count(item_id) <= 0:
			continue
		var item: Dictionary = EquipmentDatabase.get_item(item_id)
		if item.get("type", "") == "hand":
			if claimed_hands.has(item_id):
				continue
			claimed_hands[item_id] = true
		sanitized[slot] = item_id
	equipment = sanitized


func add_to_inventory(item_id: String, quantity: int = 1) -> void:
	for entry in inventory:
		if entry["id"] == item_id:
			entry["quantity"] += quantity
			save_game()
			return
	inventory.append({"id": item_id, "quantity": quantity})
	save_game()


func remove_from_inventory(item_id: String, quantity: int = 1) -> bool:
	for i in range(inventory.size()):
		if inventory[i]["id"] == item_id:
			inventory[i]["quantity"] -= quantity
			if inventory[i]["quantity"] <= 0:
				inventory.remove_at(i)
			save_game()
			return true
	return false


func get_inventory_count(item_id: String) -> int:
	for entry in inventory:
		if entry["id"] == item_id:
			return entry["quantity"]
	return 0
