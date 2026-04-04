extends Node

# ============================================================
# GameState — Central run data, phase management
# ============================================================

signal phase_changed(new_phase)
signal materials_changed
signal health_changed(current, max_hp)
signal keys_changed
signal abilities_changed
enum Phase {
	MAIN_MENU,
	BASE_HUB,
	ARENA_PREP,
	ARENA_COMBAT,
	CHEST_PHASE,
	GAME_OVER,
	RUN_COMPLETE
}

# --- Current phase ---
var current_phase: Phase = Phase.MAIN_MENU

# --- Run data (resets each run) ---
var current_wave: int = 0
var total_waves: int = 84
var player_health: int = 100
var player_max_health: int = 100
var player_xp: int = 0
var player_level: int = 1
var xp_to_next_level: int = 100
var run_in_progress: bool = false

# --- Materials (persist in bag, spent at base) ---
var materials: Dictionary = {
	"iron_scrap": 0,
	"timber": 0,
	"fuel": 0,
	"organic": 0,
	"stone": 0,
	"blueprint": 0,
}

# --- Keys (accumulated during stages, used to open chests) ---
var keys: Dictionary = {
	"bronze": 0,
	"silver": 0,
	"gold": 0,
	"secret": 0,
}

# --- Permanent upgrades (persist between runs, saved) ---
var permanent: Dictionary = {
	# Legacy keys (kept for backward compat with old saves)
	"forge_level": 0,
	"workbench_level": 0,
	"garden_level": 0,
	"armory_level": 0,
	"scrapheap_level": 0,
	"salvage_tool_tier": 0,
	"max_health_bonus": 0,
	"runs_completed": 0,
	# New upgrade system
	"bite_damage_level": 0,
	"attack_speed_level": 0,
	"crit_chance_level": 0,
	"max_hp_level": 0,
	"health_regen_level": 0,
	"damage_reduction_level": 0,
	"dig_charges_level": 0,
	"salvage_speed_level": 0,
	"pickup_magnet_level": 0,
	"reroll_level": 0,
	"xp_gain_level": 0,
	"perk_choices_level": 0,
	"mutation_revival": 0,
	"mutation_feral_howl": 0,
	"mutation_junkyard_chimera": 0,
	"prestige_currency": 0,
}

# Revival tracking (reset each run)
var _revival_used: bool = false
# Chimera buff for this run (empty if none)
var chimera_buff: Dictionary = {}

# --- Active perks for this run (chosen via level-up) ---
var active_perks: Array = []

# --- Accumulated perk stat bonuses (so they survive scene changes) ---
var perk_speed_multiplier: float = 1.0
var perk_damage_bonus: int = 0
var perk_attack_speed_multiplier: float = 1.0
var perk_regen_active: bool = false
var perk_xp_multiplier: float = 1.0
var perk_damage_reduction: float = 0.0       # Thick Skin — % damage reduced (0.0–0.35)
var perk_crit_bonus: int = 0                  # Iron Jaws — extra crit % on bite
var perk_dodge_cooldown_mult: float = 1.0     # Quick Paws — dodge cooldown multiplier
var perk_magnet_bonus: float = 0.0            # Scavenger's Nose — pickup range bonus %
var perk_second_wind: bool = false             # Second Wind — heal at low HP (once per run)
var perk_second_wind_used: bool = false        # Whether Second Wind has triggered this run
var perk_lifesteal: int = 0                   # Bloodlust — HP healed per kill
var _lifesteal_healed_this_wave: int = 0      # Bloodlust — wave cap tracker
var perk_bite_aoe_bonus: float = 0.0          # Bark Blast — extra bite AoE radius %
var perk_sneak_duration_bonus: float = 0.0    # Shadow Step — extra sneak seconds
var perk_sneak_cooldown_mult: float = 1.0     # Shadow Step — sneak cooldown multiplier
var perk_thorns_damage: int = 0               # Thorns — damage reflected to attackers
var perk_chest_upgrade_chance: float = 0.0    # Lucky Find — chest tier upgrade chance

# --- Puppy ability state (read by enemies, HUD) ---
var is_player_sneaking: bool = false
var dig_charges: int = 2
var dig_charges_max: int = 2

# --- Death screen display (not wiped by end_run) ---
var last_death_wave: int = 0
var last_death_level: int = 1

# --- Orbital weapons for this run ---
var orbital_weapons: Array = []  # [{"id": "spark_coil", "level": 1}, ...]

# --- Materials snapshot (restored on death, so you only lose what you found this run) ---
var _materials_at_run_start: Dictionary = {}

# --- Wave-start snapshot (restored on quit-to-hub mid-wave) ---
var _wave_start_snapshot: Dictionary = {}

func snapshot_wave_start() -> void:
	_wave_start_snapshot = {
		"health": player_health,
		"max_health": player_max_health,
		"xp": player_xp,
		"level": player_level,
		"xp_to_next": xp_to_next_level,
		"materials": materials.duplicate(),
		"keys": keys.duplicate(),
		"perks": active_perks.duplicate(true),
		"orbitals": orbital_weapons.duplicate(true),
		"perk_speed": perk_speed_multiplier,
		"perk_damage": perk_damage_bonus,
		"perk_attack_speed": perk_attack_speed_multiplier,
		"perk_regen": perk_regen_active,
		"perk_xp": perk_xp_multiplier,
		"dig_charges": dig_charges,
		"permanent": permanent.duplicate(),
	}

func restore_wave_start() -> void:
	if _wave_start_snapshot.is_empty():
		return
	player_health = _wave_start_snapshot.health
	player_max_health = _wave_start_snapshot.max_health
	player_xp = _wave_start_snapshot.xp
	player_level = _wave_start_snapshot.level
	xp_to_next_level = _wave_start_snapshot.xp_to_next
	materials = _wave_start_snapshot.materials.duplicate()
	keys = _wave_start_snapshot.keys.duplicate()
	active_perks = _wave_start_snapshot.perks.duplicate(true)
	orbital_weapons = _wave_start_snapshot.orbitals.duplicate(true)
	perk_speed_multiplier = _wave_start_snapshot.perk_speed
	perk_damage_bonus = _wave_start_snapshot.perk_damage
	perk_attack_speed_multiplier = _wave_start_snapshot.perk_attack_speed
	perk_regen_active = _wave_start_snapshot.perk_regen
	perk_xp_multiplier = _wave_start_snapshot.perk_xp
	dig_charges = _wave_start_snapshot.dig_charges
	# Revert permanent upgrades too (prevents gold chest exploit)
	if _wave_start_snapshot.has("permanent"):
		for key in permanent:
			if key in _wave_start_snapshot.permanent:
				permanent[key] = _wave_start_snapshot.permanent[key]
	emit_signal("health_changed", player_health, player_max_health)
	emit_signal("materials_changed")

# --- Armor / Equipment ---
var equipped_armor_stat: String = "leather_vest"
var equipped_armor_visual: String = "bandana_red"
var unlocked_armors: Array = ["bandana_red", "leather_vest"]

func set_phase(new_phase: Phase) -> void:
	current_phase = new_phase
	emit_signal("phase_changed", new_phase)

func add_material(type: String, amount: int) -> void:
	if type in materials:
		materials[type] += amount
		emit_signal("materials_changed")
		# Track scrap in junkyard mode
		var js = get_node_or_null("/root/JunkyardState")
		if js and js.is_active:
			js.add_scrap(amount)
		# Check material-related achievements
		var ach = get_node_or_null("/root/Achievements")
		if ach:
			ach.check_material_achievements()

func can_afford(cost: Dictionary) -> bool:
	for mat in cost:
		if materials.get(mat, 0) < cost[mat]:
			return false
	return true

func spend_recipe(cost: Dictionary) -> bool:
	if not can_afford(cost):
		return false
	for mat in cost:
		materials[mat] -= cost[mat]
	emit_signal("materials_changed")
	return true

func take_damage(amount: int) -> void:
	# Apply damage reduction from Tough Coat upgrade
	var dr_pct = permanent.get("damage_reduction_level", 0) * 3  # 3% per level, max 15%
	# Shield Drone passive DR — 5% while equipped
	for ow in orbital_weapons:
		if ow.get("id", "") == "shield_drone":
			dr_pct += 5
			break
	var reduced = amount
	if dr_pct > 0:
		reduced = maxi(1, int(amount * (1.0 - dr_pct / 100.0)))
	player_health = max(0, player_health - reduced)
	emit_signal("health_changed", player_health, player_max_health)
	if player_health <= 0:
		# Revival mutation check
		if permanent.get("mutation_revival", 0) > 0 and not _revival_used:
			_revival_used = true
			player_health = maxi(1, int(player_max_health * 0.3))
			emit_signal("health_changed", player_health, player_max_health)
			return
		set_phase(Phase.GAME_OVER)

func heal(amount: int) -> void:
	player_health = min(player_max_health, player_health + amount)
	emit_signal("health_changed", player_health, player_max_health)

func gain_xp(amount: int) -> void:
	var boosted = int(amount * perk_xp_multiplier)
	player_xp += boosted
	while player_xp >= xp_to_next_level:
		player_xp -= xp_to_next_level
		player_level += 1
		xp_to_next_level = int(xp_to_next_level * 1.4)
		# Achievement: puppy power at level 10
		if player_level >= 10:
			var ach = get_node_or_null("/root/Achievements")
			if ach:
				ach.check_and_unlock("puppy_power")

func add_key(tier: String) -> void:
	if tier in keys:
		keys[tier] += 1
		emit_signal("keys_changed")
		# Achievement tracking
		var ach = get_node_or_null("/root/Achievements")
		if ach:
			ach.increment_stat("total_keys")
			if tier == "gold":
				ach.check_and_unlock("golden_touch")
			elif tier == "secret":
				ach.check_and_unlock("secret_finder")

func use_key(tier: String) -> bool:
	if keys.get(tier, 0) > 0:
		keys[tier] -= 1
		emit_signal("keys_changed")
		return true
	return false

func get_key_count(tier: String) -> int:
	return keys.get(tier, 0)

const KEY_TIERS = ["bronze", "silver", "gold", "secret"]

func get_next_tier(tier: String) -> String:
	var idx = KEY_TIERS.find(tier)
	if idx >= 0 and idx < KEY_TIERS.size() - 1:
		return KEY_TIERS[idx + 1]
	return ""

func can_combine(tier: String) -> bool:
	var next = get_next_tier(tier)
	return next != "" and keys.get(tier, 0) >= 3

func combine_keys(from_tier: String) -> bool:
	if not can_combine(from_tier):
		return false
	var next = get_next_tier(from_tier)
	keys[from_tier] -= 3
	keys[next] += 1
	emit_signal("keys_changed")
	return true

func has_any_key() -> bool:
	for tier in keys:
		if keys[tier] > 0:
			return true
	return false

func start_new_run() -> void:
	run_in_progress = true
	current_wave = 0
	AudioManager.reset_stage_tracking()
	OrbitalWeapon.reset_orbit()  # Reset orbit phase and active slots for new run
	# Apply new upgrade system HP, fallback to legacy max_health_bonus
	var hp_from_upgrades = permanent.get("max_hp_level", 0) * 10
	if hp_from_upgrades == 0:
		hp_from_upgrades = permanent.get("max_health_bonus", 0)
	player_max_health = 100 + hp_from_upgrades
	player_health = player_max_health
	player_xp = 0
	player_level = 1
	xp_to_next_level = 100
	# Snapshot materials so we can restore on death (only lose what you found this run)
	_materials_at_run_start = materials.duplicate()
	# Keys reset each run (earned during combat, not stockpiled)
	keys = {"bronze": 0, "silver": 0, "gold": 0, "secret": 0}
	is_player_sneaking = false
	reset_dig_charges()
	# Reset perks for fresh run
	active_perks.clear()
	perk_speed_multiplier = 1.0
	perk_damage_bonus = 0
	perk_attack_speed_multiplier = 1.0
	perk_regen_active = false
	perk_xp_multiplier = 1.0
	perk_damage_reduction = 0.0
	perk_crit_bonus = 0
	perk_dodge_cooldown_mult = 1.0
	perk_magnet_bonus = 0.0
	perk_second_wind = false
	perk_second_wind_used = false
	perk_lifesteal = 0
	perk_bite_aoe_bonus = 0.0
	perk_sneak_duration_bonus = 0.0
	perk_sneak_cooldown_mult = 1.0
	perk_thorns_damage = 0
	perk_chest_upgrade_chance = 0.0
	orbital_weapons.clear()
	_revival_used = false
	chimera_buff = {}
	# Reset per-run achievement stats
	var ach = get_node_or_null("/root/Achievements")
	if ach:
		ach.reset_run_stats()
	# Apply armor stat bonuses
	apply_armor_stats()
	# Card deck completion bonuses
	var card_db = get_node_or_null("/root/CardDB")
	if card_db:
		var card_bonuses = card_db.get_stat_bonuses()
		player_max_health += card_bonuses.max_hp
		player_health = player_max_health
		perk_damage_bonus += card_bonuses.damage
	# ── New upgrade system bonuses ──
	# Bite damage: +1 per level (fallback to legacy forge +3 per level)
	var bite_lvl = permanent.get("bite_damage_level", 0)
	if bite_lvl > 0:
		perk_damage_bonus += bite_lvl
	else:
		perk_damage_bonus += permanent.get("forge_level", 0) * 3
	# Attack speed: -5% cooldown per level
	var aspd_lvl = permanent.get("attack_speed_level", 0)
	if aspd_lvl > 0:
		perk_attack_speed_multiplier *= pow(0.95, aspd_lvl)
	# XP gain: +5% per level
	var xp_lvl = permanent.get("xp_gain_level", 0)
	if xp_lvl > 0:
		perk_xp_multiplier *= (1.0 + xp_lvl * 0.05)
	# Junkyard Chimera: random buff
	if permanent.get("mutation_junkyard_chimera", 0) > 0:
		_apply_chimera_buff()

func apply_armor_stats() -> void:
	var armor_db = get_node_or_null("/root/ArmorDB")
	if not armor_db:
		return
	var armor = armor_db.get_armor(equipped_armor_stat)
	if armor.is_empty():
		return
	var stats = armor.get("stats", {})
	if stats.has("max_health"):
		player_max_health += int(stats.max_health)
		player_health = player_max_health
	if stats.has("speed"):
		perk_speed_multiplier += stats.speed
	if stats.has("damage"):
		perk_damage_bonus += int(stats.damage)
	if stats.has("attack_speed"):
		perk_attack_speed_multiplier *= (1.0 - stats.attack_speed)
	if stats.has("regen"):
		perk_regen_active = true
	if stats.has("xp_gain"):
		perk_xp_multiplier += stats.xp_gain


func reapply_permanent_bonuses() -> void:
	# Called when returning to arena from base hub mid-run
	# Recalculate ALL perk stats from scratch to prevent stacking on each hub visit

	# 1. Reset all perk multipliers to base (1.0 / 0 / false)
	perk_speed_multiplier = 1.0
	perk_damage_bonus = 0
	perk_attack_speed_multiplier = 1.0
	perk_regen_active = false
	perk_xp_multiplier = 1.0
	perk_damage_reduction = 0.0
	perk_crit_bonus = 0
	perk_dodge_cooldown_mult = 1.0
	perk_magnet_bonus = 0.0
	perk_second_wind = false
	# NOTE: perk_second_wind_used is NOT reset here — it persists within the run
	perk_lifesteal = 0
	perk_bite_aoe_bonus = 0.0
	perk_sneak_duration_bonus = 0.0
	perk_sneak_cooldown_mult = 1.0
	perk_thorns_damage = 0
	perk_chest_upgrade_chance = 0.0
	var hp_bonus_r = permanent.get("max_hp_level", 0) * 10
	if hp_bonus_r == 0:
		hp_bonus_r = permanent.get("max_health_bonus", 0)
	player_max_health = 100 + hp_bonus_r

	# 2. Re-apply level-up perk bonuses from active_perks with diminishing returns
	# Diminishing formula: base * 0.7^pick_index (matching level_up.gd)
	const DIMINISH = 0.7
	const FLOORS = {"hp_up": 1.0, "speed_up": 3.0, "damage_up": 1.0, "attack_speed": 3.0, "xp_boost": 5.0, "thick_skin": 2.0, "iron_jaws": 1.0, "quick_paws": 3.0, "scavenger_nose": 5.0, "bloodlust": 1.0, "bark_blast": 5.0, "shadow_step": 0.3, "thorns": 1.0, "lucky_find": 3.0}
	var perk_counts := {}  # Track how many times each perk has been applied
	for perk_id in active_perks:
		var pick_idx = perk_counts.get(perk_id, 0)
		perk_counts[perk_id] = pick_idx + 1
		match perk_id:
			"damage_up":
				var val = int(maxf(5.0 * pow(DIMINISH, pick_idx), FLOORS.get("damage_up", 1.0)))
				perk_damage_bonus += val
			"speed_up":
				var pct = maxf(15.0 * pow(DIMINISH, pick_idx), FLOORS.get("speed_up", 3.0))
				perk_speed_multiplier *= (1.0 + pct / 100.0)
			"attack_speed":
				var pct = maxf(15.0 * pow(DIMINISH, pick_idx), FLOORS.get("attack_speed", 3.0))
				perk_attack_speed_multiplier *= (1.0 - pct / 100.0)
			"hp_up":
				var val = int(maxf(25.0 * pow(DIMINISH, pick_idx), FLOORS.get("hp_up", 1.0)))
				player_max_health += val
			"regen":
				perk_regen_active = true
			"xp_boost":
				var pct = maxf(25.0 * pow(DIMINISH, pick_idx), FLOORS.get("xp_boost", 5.0))
				perk_xp_multiplier *= (1.0 + pct / 100.0)
			"thick_skin":
				var pct_ts = maxf(8.0 * pow(DIMINISH, pick_idx), FLOORS.get("thick_skin", 2.0))
				perk_damage_reduction = minf(0.35, perk_damage_reduction + pct_ts / 100.0)
			"iron_jaws":
				var val_ij = int(maxf(5.0 * pow(DIMINISH, pick_idx), FLOORS.get("iron_jaws", 1.0)))
				perk_crit_bonus += val_ij
			"quick_paws":
				var pct_qp = maxf(20.0 * pow(DIMINISH, pick_idx), FLOORS.get("quick_paws", 3.0))
				perk_dodge_cooldown_mult *= (1.0 - pct_qp / 100.0)
			"scavenger_nose":
				var pct_sn = maxf(30.0 * pow(DIMINISH, pick_idx), FLOORS.get("scavenger_nose", 5.0))
				perk_magnet_bonus += pct_sn / 100.0
			"second_wind":
				perk_second_wind = true
			"bloodlust":
				var val_bl = int(maxf(2.0 * pow(DIMINISH, pick_idx), FLOORS.get("bloodlust", 1.0)))
				perk_lifesteal += val_bl
			"bark_blast":
				var pct_bb = maxf(35.0 * pow(DIMINISH, pick_idx), FLOORS.get("bark_blast", 5.0))
				perk_bite_aoe_bonus += pct_bb / 100.0
			"shadow_step":
				var dur_ss = maxf(1.0 * pow(DIMINISH, pick_idx), FLOORS.get("shadow_step", 0.3))
				perk_sneak_duration_bonus += dur_ss
				perk_sneak_cooldown_mult *= 0.8
			"thorns":
				var val_th = int(maxf(5.0 * pow(DIMINISH, pick_idx), FLOORS.get("thorns", 1.0)))
				perk_thorns_damage += val_th
			"lucky_find":
				var pct_lf = maxf(15.0 * pow(DIMINISH, pick_idx), FLOORS.get("lucky_find", 3.0))
				perk_chest_upgrade_chance += pct_lf / 100.0

	# 3. Apply permanent upgrade bonuses (new system with legacy fallback)
	var bite_lvl = permanent.get("bite_damage_level", 0)
	if bite_lvl > 0:
		perk_damage_bonus += bite_lvl
	else:
		perk_damage_bonus += permanent.get("forge_level", 0) * 3
	var aspd_lvl = permanent.get("attack_speed_level", 0)
	if aspd_lvl > 0:
		perk_attack_speed_multiplier *= pow(0.95, aspd_lvl)
	var xp_lvl = permanent.get("xp_gain_level", 0)
	if xp_lvl > 0:
		perk_xp_multiplier *= (1.0 + xp_lvl * 0.05)

	# 4. Apply card deck completion bonuses
	var card_db = get_node_or_null("/root/CardDB")
	if card_db and card_db.has_method("get_stat_bonuses"):
		var bonuses = card_db.get_stat_bonuses()
		player_max_health += bonuses.get("max_hp", 0)
		perk_damage_bonus += bonuses.get("damage", 0)

	# 5. Apply armor stats (on top of everything)
	apply_armor_stats()

	# 6. Clamp all stat multipliers to safe ranges
	perk_speed_multiplier = maxf(0.1, perk_speed_multiplier)
	perk_attack_speed_multiplier = maxf(0.1, perk_attack_speed_multiplier)
	perk_dodge_cooldown_mult = maxf(0.5, perk_dodge_cooldown_mult)
	player_health = mini(player_health, player_max_health)
	# Dog House regen is handled by arena.gd _restore_regen_perk() on scene load

func end_run(keep_materials: bool = false) -> void:
	run_in_progress = false
	# Reset run state
	current_wave = 0
	var hp_bonus_e = permanent.get("max_hp_level", 0) * 10
	if hp_bonus_e == 0:
		hp_bonus_e = permanent.get("max_health_bonus", 0)
	player_max_health = 100 + hp_bonus_e
	player_health = player_max_health
	player_xp = 0
	player_level = 1
	xp_to_next_level = 100
	# Restore materials to what you had BEFORE the run started
	# On death: lose what you found this run
	# On victory: keep everything (keep_materials = true)
	# In junkyard: always keep
	if not keep_materials:
		var jy = get_node_or_null("/root/JunkyardState")
		var in_junkyard = jy and jy.is_active
		if not in_junkyard and not _materials_at_run_start.is_empty():
			materials = _materials_at_run_start.duplicate()
	# Keys are always lost (earned and spent during the run)
	keys = {"bronze": 0, "silver": 0, "gold": 0, "secret": 0}
	is_player_sneaking = false
	active_perks.clear()
	perk_speed_multiplier = 1.0
	perk_damage_bonus = 0
	perk_attack_speed_multiplier = 1.0
	perk_regen_active = false
	perk_xp_multiplier = 1.0
	perk_damage_reduction = 0.0
	perk_crit_bonus = 0
	perk_dodge_cooldown_mult = 1.0
	perk_magnet_bonus = 0.0
	perk_second_wind = false
	perk_second_wind_used = false
	perk_lifesteal = 0
	perk_bite_aoe_bonus = 0.0
	perk_sneak_duration_bonus = 0.0
	perk_sneak_cooldown_mult = 1.0
	perk_thorns_damage = 0
	perk_chest_upgrade_chance = 0.0
	orbital_weapons.clear()

# --- Stage helpers ---
func get_current_stage() -> int:
	@warning_ignore("integer_division")
	return clampi((current_wave - 1) / StageData.WAVES_PER_STAGE, 0, StageData.TOTAL_STAGES - 1)

func get_stage_wave() -> int:
	return ((current_wave - 1) % 14) + 1

func has_save() -> bool:
	return FileAccess.file_exists(SaveManager.get_save_path())

func get_salvage_tool_speed() -> float:
	var speeds = [1.0, 1.6, 2.4, 3.5, 5.0]
	var lvl = permanent.get("salvage_speed_level", 0)
	if lvl == 0:
		lvl = permanent.get("salvage_tool_tier", 0)
	return speeds[clampi(lvl, 0, 4)]

func get_salvage_tool_yield() -> float:
	var yields = [0.5, 0.65, 0.78, 0.90, 1.0]
	var lvl = permanent.get("salvage_speed_level", 0)
	if lvl == 0:
		lvl = permanent.get("salvage_tool_tier", 0)
	return yields[clampi(lvl, 0, 4)]

func reset_dig_charges() -> void:
	var dig_lvl = permanent.get("dig_charges_level", 0)
	if dig_lvl == 0:
		dig_lvl = permanent.get("scrapheap_level", 0)
	dig_charges_max = 2 + dig_lvl
	dig_charges = dig_charges_max
	emit_signal("abilities_changed")

func _apply_chimera_buff() -> void:
	var udb = get_node_or_null("/root/UpgradeDB")
	if not udb:
		return
	var buffs = udb.CHIMERA_BUFFS
	var pick = buffs.pick_random()
	chimera_buff = pick
	match pick.effect:
		"damage":
			perk_damage_bonus += int(pick.value)
		"speed":
			perk_speed_multiplier += pick.value
		"max_hp":
			player_max_health += int(pick.value)
			player_health = player_max_health
		"crit":
			pass  # Applied in player.gd during attack
		"attack_speed":
			perk_attack_speed_multiplier *= (1.0 - pick.value)
		"xp":
			perk_xp_multiplier += pick.value

func use_dig_charge() -> bool:
	if dig_charges > 0:
		dig_charges -= 1
		emit_signal("abilities_changed")
		return true
	return false
