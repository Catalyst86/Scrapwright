extends Node

# ============================================================
# ArmorDB — Armor set definitions & unlock tracking
# ============================================================

const RARITY_COLORS = {
	"common": Color(0.6, 0.6, 0.6),
	"uncommon": Color(0.35, 0.82, 0.40),
	"rare": Color(0.35, 0.55, 1.0),
	"legendary": Color(0.95, 0.82, 0.35),
}

var _armors: Array = []

func _ready() -> void:
	_define_armors()


func _define_armors() -> void:
	_armors = [
		# --- Cosmetic Only (no stats) ---
		{
			"id": "bandana_red",
			"name": "Red Bandana",
			"desc": "A trusty red bandana.",
			"category": "cosmetic",
			"stats": {},
			"rarity": "common",
			"color": Color(0.85, 0.20, 0.20),
			"unlock_method": "default",
		},
		{
			"id": "bandana_blue",
			"name": "Blue Bandana",
			"desc": "Cool and collected.",
			"category": "cosmetic",
			"stats": {},
			"rarity": "common",
			"color": Color(0.25, 0.45, 0.90),
			"unlock_method": "chest",
		},
		{
			"id": "flower_crown",
			"name": "Flower Crown",
			"desc": "Pretty petals for a pretty pup.",
			"category": "cosmetic",
			"stats": {},
			"rarity": "uncommon",
			"color": Color(0.95, 0.55, 0.75),
			"unlock_method": "craft",
		},
		{
			"id": "pirate_patch",
			"name": "Pirate Patch",
			"desc": "Yarr, matey!",
			"category": "cosmetic",
			"stats": {},
			"rarity": "uncommon",
			"color": Color(0.15, 0.15, 0.15),
			"unlock_method": "achievement",
			"unlock_hint": "Defeat a boss (boss_slayer)",
		},
		# --- Stat Boosting ---
		{
			"id": "leather_vest",
			"name": "Leather Vest",
			"desc": "+10 HP, +5% Speed",
			"category": "stat",
			"stats": {"max_health": 10, "speed": 0.05},
			"rarity": "common",
			"color": Color(0.50, 0.35, 0.15),
			"unlock_method": "default",
		},
		{
			"id": "golden_collar",
			"name": "Golden Collar",
			"desc": "+5 HP, +1 Damage, +5% Speed",
			"category": "stat",
			"stats": {"max_health": 5, "damage": 1, "speed": 0.05},
			"rarity": "legendary",
			"color": Color(0.95, 0.82, 0.35),
			"unlock_method": "achievement",
			"unlock_hint": "Complete the game (the_end)",
		},
		{
			"id": "void_cloak",
			"name": "Void Cloak",
			"desc": "+3 Damage, +10% XP Gain",
			"category": "stat",
			"stats": {"damage": 3, "xp_gain": 0.10},
			"rarity": "legendary",
			"color": Color(0.30, 0.10, 0.50),
			"unlock_method": "achievement",
			"unlock_hint": "Complete 10 runs (veteran)",
		},
		{
			"id": "phoenix_mantle",
			"name": "Phoenix Mantle",
			"desc": "+30 HP, Regen 2 HP/10s",
			"category": "stat",
			"stats": {"max_health": 30, "regen": 2},
			"rarity": "legendary",
			"color": Color(0.95, 0.40, 0.10),
			"unlock_method": "secret",
			"unlock_hint": "Found in a secret chest",
		},
		# --- Additional Cosmetics ---
		{
			"id": "party_hat",
			"name": "Party Hat",
			"desc": "It's always a celebration!",
			"category": "cosmetic",
			"stats": {},
			"rarity": "common",
			"color": Color(0.90, 0.35, 0.60),
			"unlock_method": "chest",
		},
		{
			"id": "goggles",
			"name": "Goggles",
			"desc": "For safety (and style).",
			"category": "cosmetic",
			"stats": {},
			"rarity": "uncommon",
			"color": Color(0.40, 0.70, 0.85),
			"unlock_method": "chest",
		},
		# --- Additional Stat Gear ---
		{
			"id": "rusty_plate",
			"name": "Rusty Plate",
			"desc": "+15 HP, -5% Speed",
			"category": "stat",
			"stats": {"max_health": 15, "speed": -0.05},
			"rarity": "common",
			"color": Color(0.55, 0.40, 0.30),
			"unlock_method": "chest",
		},
		{
			"id": "iron_mail",
			"name": "Iron Mail",
			"desc": "+20 HP, +1 Damage",
			"category": "stat",
			"stats": {"max_health": 20, "damage": 1},
			"rarity": "uncommon",
			"color": Color(0.60, 0.62, 0.68),
			"unlock_method": "craft",
		},
		{
			"id": "crystal_vest",
			"name": "Crystal Vest",
			"desc": "+10 HP, +10% Atk Speed",
			"category": "stat",
			"stats": {"max_health": 10, "attack_speed": 0.10},
			"rarity": "rare",
			"color": Color(0.50, 0.75, 0.95),
			"unlock_method": "achievement",
			"unlock_hint": "Collect 50 keys (key_collector)",
		},
		{
			"id": "scrap_shield",
			"name": "Scrap Shield",
			"desc": "+25 HP, +2 Damage",
			"category": "stat",
			"stats": {"max_health": 25, "damage": 2},
			"rarity": "rare",
			"color": Color(0.50, 0.50, 0.55),
			"unlock_method": "craft",
		},
		{
			"id": "fungal_hide",
			"name": "Fungal Hide",
			"desc": "+15 HP, Regen 1 HP/10s",
			"category": "stat",
			"stats": {"max_health": 15, "regen": 1},
			"rarity": "uncommon",
			"color": Color(0.40, 0.60, 0.35),
			"unlock_method": "chest",
		},
		{
			"id": "steam_harness",
			"name": "Steam Harness",
			"desc": "+10% Speed, +15% Atk Speed",
			"category": "stat",
			"stats": {"speed": 0.10, "attack_speed": 0.15},
			"rarity": "rare",
			"color": Color(0.70, 0.55, 0.30),
			"unlock_method": "achievement",
			"unlock_hint": "Kill 1000 enemies (thousand_bones)",
		},
		{
			"id": "junkyard_crown",
			"name": "Junkyard Crown",
			"desc": "+2 Damage, +10% XP, +5 HP",
			"category": "stat",
			"stats": {"damage": 2, "xp_gain": 0.10, "max_health": 5},
			"rarity": "legendary",
			"color": Color(0.75, 0.60, 0.25),
			"unlock_method": "achievement",
			"unlock_hint": "Complete 5 runs (repeat_offender)",
		},
		{
			"id": "obsidian_shell",
			"name": "Obsidian Shell",
			"desc": "+35 HP, +2 Damage, -10% Speed",
			"category": "stat",
			"stats": {"max_health": 35, "damage": 2, "speed": -0.10},
			"rarity": "legendary",
			"color": Color(0.20, 0.15, 0.25),
			"unlock_method": "secret",
			"unlock_hint": "Found in a secret chest",
		},
	]


# --- Public API ---

func get_all_armors() -> Array:
	return _armors.duplicate()


func get_armor(id: String) -> Dictionary:
	for armor in _armors:
		if armor.id == id:
			return armor
	return {}


func unlock_armor(id: String) -> void:
	if id not in GameState.unlocked_armors:
		GameState.unlocked_armors.append(id)
		SaveManager.save_game()


func is_unlocked(id: String) -> bool:
	return id in GameState.unlocked_armors


func get_stats_summary(armor: Dictionary) -> String:
	if armor.stats.is_empty():
		return "Cosmetic only"
	var parts: Array = []
	for stat_key in armor.stats:
		var val = armor.stats[stat_key]
		match stat_key:
			"max_health":
				parts.append("+%d HP" % val)
			"speed":
				if val > 0:
					parts.append("+%d%% Speed" % int(val * 100))
				else:
					parts.append("%d%% Speed" % int(val * 100))
			"damage":
				parts.append("+%d Damage" % val)
			"attack_speed":
				parts.append("+%d%% Atk Spd" % int(val * 100))
			"regen":
				parts.append("Regen %d HP/10s" % val)
			"xp_gain":
				parts.append("+%d%% XP" % int(val * 100))
	return ", ".join(parts)
