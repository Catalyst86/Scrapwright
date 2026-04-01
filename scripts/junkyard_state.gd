extends Node

# ============================================================
# JunkyardState - Isolates junkyard mode from main game state
# ============================================================

var junkyard_wave: int = 0
var junkyard_scrap: int = 0
var junkyard_kills: int = 0
var is_active: bool = false

var _snapshot: Dictionary = {}

func enter_junkyard() -> void:
	# Snapshot all run-related GameState fields
	_snapshot = {
		"run_in_progress": GameState.run_in_progress,
		"current_wave": GameState.current_wave,
		"player_health": GameState.player_health,
		"player_max_health": GameState.player_max_health,
		"player_xp": GameState.player_xp,
		"player_level": GameState.player_level,
		"xp_to_next_level": GameState.xp_to_next_level,
		"materials": GameState.materials.duplicate(),
		"_materials_at_run_start": GameState._materials_at_run_start.duplicate(),
		"keys": GameState.keys.duplicate(),
		"active_perks": GameState.active_perks.duplicate(),
		"orbital_weapons": GameState.orbital_weapons.duplicate(),
		"perk_speed_multiplier": GameState.perk_speed_multiplier,
		"perk_damage_bonus": GameState.perk_damage_bonus,
		"perk_attack_speed_multiplier": GameState.perk_attack_speed_multiplier,
		"perk_regen_active": GameState.perk_regen_active,
		"perk_xp_multiplier": GameState.perk_xp_multiplier,
		"current_phase": GameState.current_phase,
		"is_player_sneaking": GameState.is_player_sneaking,
		"dig_charges": GameState.dig_charges,
		"dig_charges_max": GameState.dig_charges_max,
	}

	# Reset junkyard counters
	junkyard_wave = 0
	junkyard_scrap = 0
	junkyard_kills = 0
	is_active = true

	# Apply permanent upgrades fresh (like start_new_run but isolated)
	GameState.run_in_progress = false
	GameState.current_wave = 0
	GameState.player_max_health = 100 + GameState.permanent.get("max_health_bonus", 0)
	GameState.player_health = GameState.player_max_health
	GameState.player_xp = 0
	GameState.player_level = 1
	GameState.xp_to_next_level = 100
	GameState.materials = {
		"iron_scrap": 0, "timber": 0, "fuel": 0,
		"organic": 0, "stone": 0, "blueprint": 0,
	}
	GameState._materials_at_run_start = {}
	GameState.keys = {"bronze": 0, "silver": 0, "gold": 0, "secret": 0}
	GameState.active_perks = []
	GameState.orbital_weapons = []
	GameState.perk_speed_multiplier = 1.0
	GameState.perk_damage_bonus = 0
	GameState.perk_attack_speed_multiplier = 1.0
	GameState.perk_regen_active = false
	GameState.perk_xp_multiplier = 1.0
	GameState.is_player_sneaking = false
	GameState.reset_dig_charges()
	GameState.apply_armor_stats()
	# Chew Toy bonus from forge
	GameState.perk_damage_bonus += GameState.permanent.get("forge_level", 0) * 3
	GameState.set_phase(GameState.Phase.ARENA_COMBAT)

func exit_junkyard() -> void:
	if not is_active:
		return
	is_active = false

	# Save high score before restoring
	var scores = SaveManager.load_junkyard_score()
	if junkyard_wave > scores.get("best_wave", 0) or junkyard_scrap > scores.get("best_scrap", 0):
		SaveManager.save_junkyard_score(
			maxi(junkyard_wave, scores.get("best_wave", 0)),
			maxi(junkyard_scrap, scores.get("best_scrap", 0))
		)

	# Merge junkyard materials INTO the pre-junkyard stockpile
	# (junkyard started from 0, so current materials = what was earned in junkyard)
	var junkyard_mats = GameState.materials.duplicate()
	var pre_junkyard_mats = _snapshot.get("materials", {}).duplicate()
	for mat in junkyard_mats:
		pre_junkyard_mats[mat] = pre_junkyard_mats.get(mat, 0) + junkyard_mats[mat]

	# Restore snapshotted GameState
	GameState.run_in_progress = _snapshot.get("run_in_progress", false)
	GameState.current_wave = _snapshot.get("current_wave", 0)
	GameState.player_health = _snapshot.get("player_health", 100)
	GameState.player_max_health = _snapshot.get("player_max_health", 100)
	GameState.player_xp = _snapshot.get("player_xp", 0)
	GameState.player_level = _snapshot.get("player_level", 1)
	GameState.xp_to_next_level = _snapshot.get("xp_to_next_level", 100)
	# Materials: pre-junkyard + junkyard earnings combined
	GameState.materials = pre_junkyard_mats
	GameState._materials_at_run_start = pre_junkyard_mats.duplicate()
	GameState.keys = _snapshot.get("keys", {}).duplicate()
	GameState.active_perks = _snapshot.get("active_perks", []).duplicate()
	GameState.orbital_weapons = _snapshot.get("orbital_weapons", []).duplicate()
	GameState.perk_speed_multiplier = _snapshot.get("perk_speed_multiplier", 1.0)
	GameState.perk_damage_bonus = _snapshot.get("perk_damage_bonus", 0)
	GameState.perk_attack_speed_multiplier = _snapshot.get("perk_attack_speed_multiplier", 1.0)
	GameState.perk_regen_active = _snapshot.get("perk_regen_active", false)
	GameState.perk_xp_multiplier = _snapshot.get("perk_xp_multiplier", 1.0)
	GameState.current_phase = _snapshot.get("current_phase", GameState.Phase.MAIN_MENU)
	GameState.is_player_sneaking = _snapshot.get("is_player_sneaking", false)
	GameState.dig_charges = _snapshot.get("dig_charges", 2)
	GameState.dig_charges_max = _snapshot.get("dig_charges_max", 2)
	_snapshot.clear()

func add_scrap(amount: int) -> void:
	junkyard_scrap += amount

func add_kill() -> void:
	junkyard_kills += 1
