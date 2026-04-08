extends Node

# ============================================================
# OrbitalDB — Orbital weapon definitions and stats per level
# ============================================================

const MAX_ORBITALS = 6
const MAX_LEVEL = 20
const VISUAL_UPGRADE_LEVELS = [5, 10, 15, 20]
const DIMINISHING_FACTOR = 0.88

# All orbital weapon definitions
# Stats arrays: [lv1, lv2, lv3] used as calibration points for the scaling formula
const WEAPONS = {
	"spark_coil": {
		"name": "Spark Coil",
		"desc": "Lightning bolt to nearest enemy",
		"orbit_radius": 26.0,
		"orbit_speed": 3.5,
		"attack_range": 90.0,
		"color": Color(0.9, 0.8, 0.2),
		"damage": [7, 10, 14],
		"cooldown": [1.0, 0.8, 0.6],
		"cooldown_floor": 0.3,
		"attack_type": "bolt",
	},
	"flame_wisp": {
		"name": "Flame Wisp",
		"desc": "Fireball projectile",
		"orbit_radius": 35.0,
		"orbit_speed": 2.0,
		"attack_range": 110.0,
		"color": Color(1.0, 0.5, 0.1),
		"damage": [8, 12, 16],
		"cooldown": [2.0, 1.6, 1.2],
		"cooldown_floor": 0.7,
		"attack_type": "projectile",
	},
	"frost_shard": {
		"name": "Frost Shard",
		"desc": "Ice spike + slows enemy 2s",
		"orbit_radius": 30.0,
		"orbit_speed": 2.8,
		"attack_range": 85.0,
		"color": Color(0.4, 0.8, 1.0),
		"damage": [5, 8, 11],
		"cooldown": [1.5, 1.2, 1.0],
		"cooldown_floor": 0.6,
		"attack_type": "bolt_slow",
	},
	"poison_orb": {
		"name": "Poison Orb",
		"desc": "Poison splash, DOT 3s",
		"orbit_radius": 28.0,
		"orbit_speed": 2.2,
		"attack_range": 75.0,
		"color": Color(0.3, 0.85, 0.2),
		"damage": [5, 8, 12],
		"cooldown": [2.0, 1.6, 1.2],
		"cooldown_floor": 0.6,
		"attack_type": "poison",
	},
	"blade_fan": {
		"name": "Blade Fan",
		"desc": "Slashes all enemies in orbit radius",
		"orbit_radius": 24.0,
		"orbit_speed": 4.0,
		"attack_range": 40.0,
		"color": Color(0.7, 0.7, 0.8),
		"damage": [7, 10, 14],
		"cooldown": [1.8, 1.4, 1.0],
		"cooldown_floor": 0.7,
		"attack_type": "aoe_orbit",
	},
	"arcane_book": {
		"name": "Arcane Tome",
		"desc": "Homing magic missile",
		"orbit_radius": 32.0,
		"orbit_speed": 1.5,
		"attack_range": 120.0,
		"color": Color(0.7, 0.4, 1.0),
		"damage": [6, 9, 13],
		"cooldown": [1.0, 0.8, 0.6],
		"cooldown_floor": 0.3,
		"attack_type": "homing",
	},
	"chain_link": {
		"name": "Chain Lightning",
		"desc": "Hits target + chains to nearby",
		"orbit_radius": 30.0,
		"orbit_speed": 2.5,
		"attack_range": 95.0,
		"color": Color(0.5, 0.7, 1.0),
		"damage": [4, 6, 8],
		"cooldown": [2.0, 1.6, 1.2],
		"cooldown_floor": 0.7,
		"attack_type": "chain",
		"chain_count": [2, 3, 3],
		"chain_falloff": 0.5,
	},
	"thorn_vine": {
		"name": "Thorn Vine",
		"desc": "Whip in a line, pierces enemies",
		"orbit_radius": 22.0,
		"orbit_speed": 3.2,
		"attack_range": 70.0,
		"color": Color(0.4, 0.7, 0.2),
		"damage": [6, 9, 12],
		"cooldown": [1.6, 1.3, 1.0],
		"cooldown_floor": 0.6,
		"attack_type": "line_pierce",
	},
	"shield_drone": {
		"name": "Shield Drone",
		"desc": "Bump damage + 5% passive DR while equipped",
		"orbit_radius": 38.0,
		"orbit_speed": 1.8,
		"attack_range": 30.0,
		"color": Color(0.6, 0.6, 0.7),
		"damage": [5, 8, 12],
		"cooldown": [3.0, 2.5, 2.0],
		"cooldown_floor": 1.0,
		"attack_type": "shield",
		"passive_dr": 5,
	},
	"magnet_core": {
		"name": "Magnet Core",
		"desc": "Pulls enemies in + crush damage",
		"orbit_radius": 24.0,
		"orbit_speed": 3.0,
		"attack_range": [60.0, 80.0, 100.0],
		"color": Color(0.8, 0.2, 0.2),
		"damage": [3, 5, 8],
		"cooldown": [2.5, 2.2, 2.0],
		"cooldown_floor": 1.2,
		"attack_type": "pull",
	},
	"holy_lantern": {
		"name": "Holy Lantern",
		"desc": "AOE burst heal + damage nearby",
		"orbit_radius": 36.0,
		"orbit_speed": 1.2,
		"attack_range": 65.0,
		"color": Color(1.0, 0.9, 0.5),
		"damage": [4, 6, 8],
		"cooldown": [3.0, 2.5, 2.0],
		"cooldown_floor": 1.0,
		"attack_type": "heal_burst",
		"heal_amount": [5, 8, 12],
	},
	"shadow_dagger": {
		"name": "Shadow Dagger",
		"desc": "Teleports to enemy, backstab crit",
		"orbit_radius": 28.0,
		"orbit_speed": 4.5,
		"attack_range": 100.0,
		"color": Color(0.5, 0.2, 0.6),
		"damage": [10, 15, 20],
		"cooldown": [3.0, 2.5, 2.0],
		"cooldown_floor": 1.0,
		"attack_type": "teleport_strike",
	},
}

func get_weapon_data(weapon_id: String) -> Dictionary:
	return WEAPONS.get(weapon_id, {})

func get_weapon_ids() -> Array:
	return WEAPONS.keys()

# --- Formula-based stat scaling with diminishing returns ---
# Uses lv1 and lv3 values as calibration points, then extends to lv20

func _scale_stat_up(base: float, increment: float, level: int) -> float:
	# For stats that increase (damage, range, chain count, heal)
	var total = base
	for i in range(1, level):
		total += increment * pow(DIMINISHING_FACTOR, i - 1)
	return total

func _scale_stat_down(base: float, decrement: float, level: int, floor_val: float) -> float:
	# For stats that decrease (cooldown)
	var total = base
	for i in range(1, level):
		total -= decrement * pow(DIMINISHING_FACTOR, i - 1)
	return maxf(total, floor_val)

func get_damage(weapon_id: String, level: int) -> int:
	var data = WEAPONS.get(weapon_id, {})
	var arr = data.get("damage", [0, 0, 0])
	var lv1 = float(arr[0])
	var lv3 = float(arr[2])
	var increment = (lv3 - lv1) / 2.0
	return int(round(_scale_stat_up(lv1, increment, level)))

func get_cooldown(weapon_id: String, level: int) -> float:
	var data = WEAPONS.get(weapon_id, {})
	var arr = data.get("cooldown", [1.0, 1.0, 1.0])
	var lv1 = arr[0]
	var lv3 = arr[2]
	var decrement = (lv1 - lv3) / 2.0
	var floor_val = data.get("cooldown_floor", 0.5)
	return _scale_stat_down(lv1, decrement, level, floor_val)

func get_attack_range(weapon_id: String, level: int) -> float:
	var data = WEAPONS.get(weapon_id, {})
	var r = data.get("attack_range", 80.0)
	if r is Array:
		var lv1 = r[0]
		var lv3 = r[2]
		var increment = (lv3 - lv1) / 2.0
		return _scale_stat_up(lv1, increment, level)
	return r

func get_chain_count(weapon_id: String, level: int) -> int:
	var data = WEAPONS.get(weapon_id, {})
	var arr = data.get("chain_count", [])
	if arr.is_empty():
		return 0
	var lv1 = float(arr[0])
	var lv3 = float(arr[2])
	var increment = (lv3 - lv1) / 2.0
	return int(round(_scale_stat_up(lv1, increment, level)))

func get_heal_amount(weapon_id: String, level: int) -> int:
	var data = WEAPONS.get(weapon_id, {})
	var arr = data.get("heal_amount", [])
	if arr.is_empty():
		return 0
	var lv1 = float(arr[0])
	var lv3 = float(arr[2])
	var increment = (lv3 - lv1) / 2.0
	return maxi(1, int(round(_scale_stat_up(lv1, increment, level))))

# --- Visual tier helpers ---

func get_visual_tier(level: int) -> int:
	var tier = 0
	for threshold in VISUAL_UPGRADE_LEVELS:
		if level >= threshold:
			tier += 1
	return tier

func is_visual_upgrade_level(level: int) -> bool:
	return level in VISUAL_UPGRADE_LEVELS

func get_level_desc(weapon_id: String, level: int) -> String:
	var data = WEAPONS.get(weapon_id, {})
	var dmg = get_damage(weapon_id, level)
	var cd = get_cooldown(weapon_id, level)
	var base_desc = data.get("desc", "")
	var tier_str = ""
	var vt = get_visual_tier(level)
	if vt > 0:
		tier_str = " T%d" % vt
	if dmg > 0:
		return "%s (Lv%d%s: %d dmg, %.1fs)" % [base_desc, level, tier_str, dmg, cd]
	else:
		return "%s (Lv%d%s: %.1fs cd)" % [base_desc, level, tier_str, cd]
