extends Node

# SaveManager — Profile-based saves with per-profile save files

const SAVE_VERSION = 4
const PROFILES_PATH = "user://profiles.cfg"
const PROFILES_DIR = "user://profiles/"
const MAX_PROFILES = 4
const DEFAULT_PERM = {
	# Legacy
	"forge_level": 0, "workbench_level": 0,
	"garden_level": 0, "armory_level": 0, "scrapheap_level": 0,
	"salvage_tool_tier": 0, "max_health_bonus": 0, "runs_completed": 0,
	# New upgrade system
	"bite_damage_level": 0, "attack_speed_level": 0, "crit_chance_level": 0,
	"max_hp_level": 0, "health_regen_level": 0, "damage_reduction_level": 0,
	"dig_charges_level": 0, "salvage_speed_level": 0, "pickup_magnet_level": 0,
	"reroll_level": 0, "xp_gain_level": 0, "perk_choices_level": 0,
	"mutation_revival": 0, "mutation_feral_howl": 0, "mutation_junkyard_chimera": 0,
	"prestige_currency": 0,
}

var current_profile_slot: int = -1
var current_profile_name: String = ""

signal profile_changed(slot: int, profile_name: String)

func _ready() -> void:
	_ensure_profiles_dir()
	_migrate_legacy_save()

func get_save_path() -> String:
	if current_profile_slot < 1:
		return "user://scrapwright_save.cfg"
	return PROFILES_DIR + "profile_%d.cfg" % current_profile_slot

# ─── Profile Management ─────────────────────────────────────

func _ensure_profiles_dir() -> void:
	var global_dir = ProjectSettings.globalize_path(PROFILES_DIR)
	if not DirAccess.dir_exists_absolute(global_dir):
		DirAccess.make_dir_recursive_absolute(global_dir)

func _migrate_legacy_save() -> void:
	var legacy = "user://scrapwright_save.cfg"
	if not FileAccess.file_exists(legacy):
		return
	if FileAccess.file_exists(PROFILES_PATH):
		return  # Profiles already exist, don't overwrite
	_ensure_profiles_dir()
	var dest = PROFILES_DIR + "profile_1.cfg"
	var data = FileAccess.get_file_as_bytes(legacy)
	var f = FileAccess.open(dest, FileAccess.WRITE)
	if f:
		f.store_buffer(data)
		f.close()
	# Create master profiles entry with stats from the save
	var config = ConfigFile.new()
	var save_cfg = ConfigFile.new()
	var wave = 0
	var runs = 0
	var has_run = false
	if save_cfg.load(dest) == OK:
		wave = save_cfg.get_value("run", "current_wave", 0)
		runs = save_cfg.get_value("permanent", "runs_completed", 0)
		has_run = save_cfg.get_value("run", "in_progress", false)
	config.set_value("profiles", "slot_1_name", "Player 1")
	config.set_value("profiles", "slot_1_wave", wave)
	config.set_value("profiles", "slot_1_runs", runs)
	config.set_value("profiles", "slot_1_has_run", has_run)
	var save_err = config.save(PROFILES_PATH)
	if save_err != OK:
		push_error("SaveManager: Migration failed — could not write profiles (%d)" % save_err)
		return
	# Verify the new save is readable before deleting legacy
	var verify = ConfigFile.new()
	if verify.load(dest) != OK:
		push_error("SaveManager: Migration failed — new save unreadable, keeping legacy")
		return
	DirAccess.remove_absolute(ProjectSettings.globalize_path(legacy))

func get_all_profiles() -> Array:
	var profiles: Array = []
	var config = ConfigFile.new()
	if config.load(PROFILES_PATH) != OK:
		return profiles
	for i in range(1, MAX_PROFILES + 1):
		var key = "slot_%d" % i
		if config.has_section_key("profiles", key + "_name"):
			profiles.append({
				"slot": i,
				"name": config.get_value("profiles", key + "_name", ""),
				"wave": config.get_value("profiles", key + "_wave", 0),
				"runs": config.get_value("profiles", key + "_runs", 0),
				"has_run": config.get_value("profiles", key + "_has_run", false),
			})
	return profiles

func create_profile(slot: int, profile_name: String) -> bool:
	if slot < 1 or slot > MAX_PROFILES:
		return false
	profile_name = profile_name.strip_edges().left(12)
	if profile_name.is_empty():
		return false
	_ensure_profiles_dir()
	var config = ConfigFile.new()
	config.load(PROFILES_PATH)
	var key = "slot_%d" % slot
	config.set_value("profiles", key + "_name", profile_name)
	config.set_value("profiles", key + "_wave", 0)
	config.set_value("profiles", key + "_runs", 0)
	config.set_value("profiles", key + "_has_run", false)
	config.save(PROFILES_PATH)
	select_profile(slot)
	return true

func select_profile(slot: int) -> void:
	if slot < 1 or slot > MAX_PROFILES:
		return
	current_profile_slot = slot
	var config = ConfigFile.new()
	if config.load(PROFILES_PATH) == OK:
		current_profile_name = config.get_value("profiles", "slot_%d_name" % slot, "Profile %d" % slot)
	# Version check on profile save
	var save_path = get_save_path()
	if FileAccess.file_exists(save_path):
		var save_cfg = ConfigFile.new()
		if save_cfg.load(save_path) == OK:
			var ver = save_cfg.get_value("meta", "version", 0)
			if ver < SAVE_VERSION:
				_migrate_save(save_cfg, ver, save_path)
		else:
			# Corrupted file — back up then remove
			var backup = save_path + ".bak"
			if FileAccess.file_exists(save_path):
				var data = FileAccess.get_file_as_bytes(save_path)
				var bak = FileAccess.open(backup, FileAccess.WRITE)
				if bak:
					bak.store_buffer(data)
					bak.close()
			DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	load_game()
	var ach = get_node_or_null("/root/Achievements")
	if ach and ach.has_method("load_achievements"):
		ach.load_achievements()
	emit_signal("profile_changed", slot, current_profile_name)

func delete_profile(slot: int) -> void:
	if slot < 1 or slot > MAX_PROFILES:
		return
	var path = PROFILES_DIR + "profile_%d.cfg" % slot
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var config = ConfigFile.new()
	if config.load(PROFILES_PATH) == OK:
		var key = "slot_%d" % slot
		for suffix in ["_name", "_wave", "_runs", "_has_run"]:
			if config.has_section_key("profiles", key + suffix):
				config.erase_section_key("profiles", key + suffix)
		config.save(PROFILES_PATH)
	if current_profile_slot == slot:
		current_profile_slot = -1
		current_profile_name = ""
		_reset_game_state()

func update_profile_summary() -> void:
	if current_profile_slot < 1:
		return
	var config = ConfigFile.new()
	config.load(PROFILES_PATH)
	var key = "slot_%d" % current_profile_slot
	config.set_value("profiles", key + "_wave", GameState.current_wave)
	config.set_value("profiles", key + "_runs", GameState.permanent.get("runs_completed", 0))
	config.set_value("profiles", key + "_has_run", GameState.run_in_progress)
	config.save(PROFILES_PATH)

func _migrate_save(config: ConfigFile, from_version: int, path: String) -> void:
	# Migrate save data forward instead of deleting.
	# Each version bump should add a migration step here.
	# For now, just stamp the current version — the load() code uses
	# defaults for any missing keys, so older saves load gracefully.
	push_warning("SaveManager: migrating save from v%d to v%d" % [from_version, SAVE_VERSION])
	config.set_value("meta", "version", SAVE_VERSION)
	config.save(path)

func _reset_game_state() -> void:
	GameState.run_in_progress = false
	GameState.current_wave = 0
	GameState.permanent = DEFAULT_PERM.duplicate()
	GameState.materials = {
		"iron_scrap": 0, "timber": 0, "fuel": 0,
		"organic": 0, "stone": 0, "blueprint": 0,
	}
	GameState._materials_at_run_start = {}
	GameState.equipped_armor_stat = "leather_vest"
	GameState.equipped_armor_visual = "bandana_red"
	GameState.unlocked_armors = ["bandana_red", "leather_vest"]
	GameState.end_run()

# ─── Save / Load (per-profile) ──────────────────────────────

func save_game() -> void:
	if current_profile_slot < 1:
		push_warning("SaveManager: No profile selected, cannot save")
		return
	var path = get_save_path()
	var config = ConfigFile.new()
	config.load(path)  # Load existing file so achievements aren't overwritten
	config.set_value("meta", "version", SAVE_VERSION)

	# Permanent upgrades
	var p = GameState.permanent
	for key in p:
		config.set_value("permanent", key, p[key])

	# Materials are ALWAYS saved (even between runs, so stockpile persists)
	for mat in GameState.materials:
		config.set_value("materials", mat, GameState.materials[mat])

	# Run-in-progress data
	config.set_value("run", "in_progress", GameState.run_in_progress)
	if GameState.run_in_progress:
		config.set_value("run", "current_wave", GameState.current_wave)
		config.set_value("run", "player_health", GameState.player_health)
		config.set_value("run", "player_max_health", GameState.player_max_health)
		config.set_value("run", "player_xp", GameState.player_xp)
		config.set_value("run", "player_level", GameState.player_level)
		config.set_value("run", "xp_to_next_level", GameState.xp_to_next_level)
		# Save material snapshot for death restoration
		for mat in GameState._materials_at_run_start:
			config.set_value("materials_snapshot", mat, GameState._materials_at_run_start[mat])
		for tier in GameState.keys:
			config.set_value("keys", tier, GameState.keys[tier])
		config.set_value("run", "active_perks", GameState.active_perks)
		config.set_value("run", "orbital_weapons", GameState.orbital_weapons)
		config.set_value("run", "revival_used", GameState._revival_used)
		config.set_value("run", "chimera_buff", GameState.chimera_buff)
		config.set_value("perks", "speed_multiplier", GameState.perk_speed_multiplier)
		config.set_value("perks", "damage_bonus", GameState.perk_damage_bonus)
		config.set_value("perks", "attack_speed_multiplier", GameState.perk_attack_speed_multiplier)
		config.set_value("perks", "regen_active", GameState.perk_regen_active)
		config.set_value("perks", "xp_multiplier", GameState.perk_xp_multiplier)
		config.set_value("perks", "damage_reduction", GameState.perk_damage_reduction)
		config.set_value("perks", "crit_bonus", GameState.perk_crit_bonus)
		config.set_value("perks", "dodge_cooldown_mult", GameState.perk_dodge_cooldown_mult)
		config.set_value("perks", "magnet_bonus", GameState.perk_magnet_bonus)
		config.set_value("perks", "second_wind", GameState.perk_second_wind)
		config.set_value("perks", "second_wind_used", GameState.perk_second_wind_used)
		config.set_value("perks", "lifesteal", GameState.perk_lifesteal)
		config.set_value("perks", "bite_aoe_bonus", GameState.perk_bite_aoe_bonus)
		config.set_value("perks", "sneak_duration_bonus", GameState.perk_sneak_duration_bonus)
		config.set_value("perks", "sneak_cooldown_mult", GameState.perk_sneak_cooldown_mult)
		config.set_value("perks", "thorns_damage", GameState.perk_thorns_damage)
		config.set_value("perks", "chest_upgrade_chance", GameState.perk_chest_upgrade_chance)

	# Armor
	config.set_value("armor", "equipped_stat", GameState.equipped_armor_stat)
	config.set_value("armor", "equipped_visual", GameState.equipped_armor_visual)
	config.set_value("armor", "unlocked", GameState.unlocked_armors)


	# Card collection (persists across runs)
	var card_db = get_node_or_null("/root/CardDB")
	if card_db:
		config.set_value("cards", "collected", card_db.collected)

	var err = config.save(path)
	if err != OK:
		push_warning("SaveManager: save failed — " + str(err))
	else:
		update_profile_summary()

func load_game() -> void:
	# Reset ALL state to defaults so nothing bleeds across profiles
	GameState.permanent = DEFAULT_PERM.duplicate()
	GameState.run_in_progress = false
	GameState.materials = {
		"iron_scrap": 0, "timber": 0, "fuel": 0,
		"organic": 0, "stone": 0, "blueprint": 0,
	}
	GameState._materials_at_run_start = {}
	GameState.equipped_armor_stat = "leather_vest"
	GameState.equipped_armor_visual = "bandana_red"
	GameState.unlocked_armors = ["bandana_red", "leather_vest"]
	GameState.keys = {"bronze": 0, "silver": 0, "gold": 0, "secret": 0}
	GameState.active_perks = []
	GameState.orbital_weapons = []
	GameState.perk_speed_multiplier = 1.0
	GameState.perk_damage_bonus = 0
	GameState.perk_attack_speed_multiplier = 1.0
	GameState.perk_regen_active = false
	GameState.perk_xp_multiplier = 1.0
	# Reset card collection
	var _cdb = get_node_or_null("/root/CardDB")
	if _cdb:
		_cdb.collected = {}
	var path = get_save_path()
	var config = ConfigFile.new()
	var err = config.load(path)
	if err != OK:
		return

	var p = GameState.permanent
	for key in p:
		if config.has_section_key("permanent", key):
			p[key] = config.get_value("permanent", key)

	# Materials are ALWAYS loaded (stockpile persists between runs)
	for mat in GameState.materials:
		if config.has_section_key("materials", mat):
			GameState.materials[mat] = config.get_value("materials", mat)

	GameState.run_in_progress = config.get_value("run", "in_progress", false)
	if GameState.run_in_progress:
		GameState.current_wave = config.get_value("run", "current_wave", 0)
		GameState.player_health = config.get_value("run", "player_health", 100)
		GameState.player_max_health = config.get_value("run", "player_max_health", 100)
		GameState.player_xp = config.get_value("run", "player_xp", 0)
		GameState.player_level = config.get_value("run", "player_level", 1)
		GameState.xp_to_next_level = config.get_value("run", "xp_to_next_level", 100)
		# Restore material snapshot for death restoration
		GameState._materials_at_run_start = {}
		for mat in GameState.materials:
			if config.has_section_key("materials_snapshot", mat):
				GameState._materials_at_run_start[mat] = config.get_value("materials_snapshot", mat)
		if GameState._materials_at_run_start.is_empty():
			GameState._materials_at_run_start = GameState.materials.duplicate()
		for tier in GameState.keys:
			if config.has_section_key("keys", tier):
				GameState.keys[tier] = config.get_value("keys", tier)
		GameState.active_perks = config.get_value("run", "active_perks", [])
		GameState.orbital_weapons = config.get_value("run", "orbital_weapons", [])
		GameState._revival_used = config.get_value("run", "revival_used", false)
		GameState.chimera_buff = config.get_value("run", "chimera_buff", {})
		GameState.perk_speed_multiplier = config.get_value("perks", "speed_multiplier", 1.0)
		GameState.perk_damage_bonus = config.get_value("perks", "damage_bonus", 0)
		GameState.perk_attack_speed_multiplier = config.get_value("perks", "attack_speed_multiplier", 1.0)
		GameState.perk_regen_active = config.get_value("perks", "regen_active", false)
		GameState.perk_xp_multiplier = config.get_value("perks", "xp_multiplier", 1.0)
		GameState.perk_damage_reduction = config.get_value("perks", "damage_reduction", 0.0)
		GameState.perk_crit_bonus = config.get_value("perks", "crit_bonus", 0)
		GameState.perk_dodge_cooldown_mult = config.get_value("perks", "dodge_cooldown_mult", 1.0)
		GameState.perk_magnet_bonus = config.get_value("perks", "magnet_bonus", 0.0)
		GameState.perk_second_wind = config.get_value("perks", "second_wind", false)
		GameState.perk_second_wind_used = config.get_value("perks", "second_wind_used", false)
		GameState.perk_lifesteal = config.get_value("perks", "lifesteal", 0)
		GameState.perk_bite_aoe_bonus = config.get_value("perks", "bite_aoe_bonus", 0.0)
		GameState.perk_sneak_duration_bonus = config.get_value("perks", "sneak_duration_bonus", 0.0)
		GameState.perk_sneak_cooldown_mult = config.get_value("perks", "sneak_cooldown_mult", 1.0)
		GameState.perk_thorns_damage = config.get_value("perks", "thorns_damage", 0)
		GameState.perk_chest_upgrade_chance = config.get_value("perks", "chest_upgrade_chance", 0.0)

	GameState.equipped_armor_stat = config.get_value("armor", "equipped_stat", "leather_vest")
	GameState.equipped_armor_visual = config.get_value("armor", "equipped_visual", "bandana_red")
	GameState.unlocked_armors = config.get_value("armor", "unlocked", ["bandana_red", "leather_vest"])

	# Card collection
	var card_db = get_node_or_null("/root/CardDB")
	if card_db:
		var saved_cards = config.get_value("cards", "collected", {})
		card_db.collected = saved_cards

func reload_permanent() -> void:
	GameState.permanent = DEFAULT_PERM.duplicate()
	var config = ConfigFile.new()
	if config.load(get_save_path()) != OK:
		return
	var p = GameState.permanent
	for key in p:
		if config.has_section_key("permanent", key):
			p[key] = config.get_value("permanent", key)

func delete_save() -> void:
	var path = get_save_path()
	if FileAccess.file_exists(path):
		var globalized = ProjectSettings.globalize_path(path)
		DirAccess.remove_absolute(globalized)
	_reset_game_state()
	# Reset achievements in memory too
	var ach = get_node_or_null("/root/Achievements")
	if ach and ach.has_method("load_achievements"):
		ach.load_achievements()  # Will clear since file is gone

# ─── Junkyard High Scores ────────────────────────────────────

func save_junkyard_score(best_wave: int, best_scrap: int) -> void:
	if current_profile_slot < 1:
		return
	var path = get_save_path()
	var config = ConfigFile.new()
	config.load(path)
	config.set_value("junkyard", "best_wave", best_wave)
	config.set_value("junkyard", "best_scrap", best_scrap)
	config.save(path)

func load_junkyard_score() -> Dictionary:
	var config = ConfigFile.new()
	if config.load(get_save_path()) != OK:
		return {"best_wave": 0, "best_scrap": 0}
	return {
		"best_wave": config.get_value("junkyard", "best_wave", 0),
		"best_scrap": config.get_value("junkyard", "best_scrap", 0),
	}
