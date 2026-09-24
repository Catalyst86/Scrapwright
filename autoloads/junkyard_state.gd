extends Node

# ============================================================
# JunkyardState - Isolates junkyard mode from main game state
# ============================================================

var junkyard_wave: int = 0
var junkyard_scrap: int = 0
var junkyard_kills: int = 0
var is_active: bool = false

var _snapshot: Dictionary = {}

# GameState fields that belong to the profile, not the run. The Junkyard may
# legitimately change them (e.g. a boss skin unlock), so they are never rolled
# back to the entry snapshot.
const PROFILE_FIELDS = [
	"permanent", "unlocked_armors", "equipped_armor_stat", "equipped_armor_visual",
	"tutorial_completed", "last_death_wave", "last_death_level", "_wave_start_snapshot",
]

func enter_junkyard() -> void:
	# Snapshot EVERY run field (not a hand-kept subset, which drifted and let
	# Junkyard visits refund extra lives / Second Wind or spend the revival).
	_snapshot = _capture_run_state()

	# Reset junkyard counters
	junkyard_wave = 0
	junkyard_scrap = 0
	junkyard_kills = 0
	is_active = true

	# Apply permanent upgrades fresh (like start_new_run but isolated)
	GameState.run_in_progress = false
	GameState.current_wave = 0
	# Base HP + new upgrade system (with legacy fallback)
	var hp_bonus = GameState.permanent.get("max_hp_level", 0) * 10
	if hp_bonus == 0:
		hp_bonus = GameState.permanent.get("max_health_bonus", 0)
	GameState.player_max_health = 100 + hp_bonus
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
	GameState.perk_damage_reduction = 0.0
	GameState.perk_crit_bonus = 0
	GameState.perk_dodge_cooldown_mult = 1.0
	GameState.perk_magnet_bonus = 0.0
	GameState.perk_second_wind = false
	GameState.perk_second_wind_used = false
	GameState.perk_lifesteal = 0
	GameState.perk_bite_aoe_bonus = 0.0
	GameState.perk_sneak_duration_bonus = 0.0
	GameState.perk_sneak_cooldown_mult = 1.0
	GameState.perk_thorns_damage = 0
	GameState.perk_chest_upgrade_chance = 0.0
	GameState.extra_lives = GameState.permanent.get("mutation_feral_howl", 0)
	GameState.is_player_sneaking = false
	GameState.reset_dig_charges()
	# Apply ALL permanent upgrade bonuses (new system with legacy fallback)
	var bite_lvl = GameState.permanent.get("bite_damage_level", 0)
	if bite_lvl > 0:
		GameState.perk_damage_bonus += bite_lvl
	else:
		GameState.perk_damage_bonus += GameState.permanent.get("forge_level", 0) * 3
	var aspd_lvl = GameState.permanent.get("attack_speed_level", 0)
	if aspd_lvl > 0:
		GameState.perk_attack_speed_multiplier *= pow(0.95, aspd_lvl)
	var xp_lvl = GameState.permanent.get("xp_gain_level", 0)
	if xp_lvl > 0:
		GameState.perk_xp_multiplier *= (1.0 + xp_lvl * 0.05)
	# Card deck bonuses
	var card_db = get_node_or_null("/root/CardDB")
	if card_db and card_db.has_method("get_stat_bonuses"):
		var bonuses = card_db.get_stat_bonuses()
		GameState.player_max_health += bonuses.get("max_hp", 0)
		GameState.perk_damage_bonus += bonuses.get("damage", 0)
	GameState.player_health = GameState.player_max_health
	# Armor stats
	GameState.apply_armor_stats()
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

	# Restore the main run, with Junkyard earnings merged into its stockpile
	_apply_state(_main_run_state())
	_snapshot.clear()


# Temporarily swaps GameState back to the main run (plus Junkyard earnings so
# far), calls `fn`, then restores the sandbox values. SaveManager uses this so
# the sandbox is never written to disk. No signals fire during the swap.
func run_with_main_state(fn: Callable) -> void:
	if not is_active or _snapshot.is_empty():
		fn.call()
		return
	var sandbox := _capture_run_state()
	_apply_state(_main_run_state())
	fn.call()
	_apply_state(sandbox)


# The entry snapshot with Junkyard earnings banked into the stockpile. The
# Junkyard started from 0 materials, so current materials = what was earned here.
func _main_run_state() -> Dictionary:
	var state := _snapshot.duplicate(true)
	var merged: Dictionary = state.get("materials", {}).duplicate()
	for mat in GameState.materials:
		merged[mat] = merged.get(mat, 0) + GameState.materials[mat]
	state["materials"] = merged
	# Banked: a later death in the main run shouldn't take Junkyard earnings away
	state["_materials_at_run_start"] = merged.duplicate()
	return state


func _capture_run_state() -> Dictionary:
	var state := {}
	for prop in GameState.get_property_list():
		if not (prop.usage & PROPERTY_USAGE_SCRIPT_VARIABLE) or prop.name in PROFILE_FIELDS:
			continue
		var value = GameState.get(prop.name)
		state[prop.name] = value.duplicate(true) if (value is Dictionary or value is Array) else value
	return state


func _apply_state(state: Dictionary) -> void:
	for key in state:
		var value = state[key]
		GameState.set(key, value.duplicate(true) if (value is Dictionary or value is Array) else value)

func add_scrap(amount: int) -> void:
	junkyard_scrap += amount

func add_kill() -> void:
	junkyard_kills += 1
