extends Node

# ============================================================
# UpgradeDB — All permanent upgrade definitions, costs, helpers
# ============================================================

# --- Category accent colors ---
const CAT_COLORS = {
	"combat_paws":     Color(0.95, 0.40, 0.25),  # red-orange
	"survival_den":    Color(0.35, 0.82, 0.40),  # green
	"scavenge_snout":  Color(0.40, 0.65, 0.95),  # blue
	"companion_legacy": Color(0.95, 0.82, 0.35), # gold
	"mutation":        Color(0.72, 0.35, 0.90),  # purple
}

# --- Categories ---
const CATEGORIES = {
	"combat_paws": {
		"name": "Combat Paws",
		"desc": "Strengthen your bite and sharpen your claws.",
		"icon": "res://assets/sprites/hub_icons/combat_paws_icon.png",
		"angle": 210.0,  # 10 o'clock
		"upgrades": ["bite_damage", "attack_speed", "crit_chance"],
	},
	"survival_den": {
		"name": "Survival Den",
		"desc": "Toughen up and learn to endure.",
		"icon": "res://assets/sprites/hub_icons/survival_den_icon.png",
		"angle": 330.0,  # 4 o'clock
		"upgrades": ["max_hp", "health_regen", "damage_reduction"],
	},
	"scavenge_snout": {
		"name": "Scavenge Snout",
		"desc": "Sniff out more loot and dig deeper.",
		"icon": "res://assets/sprites/hub_icons/scavenge_snout_icon.png",
		"angle": 270.0,  # 12 o'clock (top)
		"upgrades": ["dig_charges", "salvage_speed", "pickup_magnet"],
	},
	"companion_legacy": {
		"name": "Companion Legacy",
		"desc": "Wisdom from past runs makes every adventure better.",
		"icon": "res://assets/sprites/hub_icons/companion_legacy_icon.png",
		"angle": 30.0,  # 2 o'clock
		"upgrades": ["rerolls", "xp_gain", "perk_choices"],
	},
	"mutation": {
		"name": "Mutation",
		"desc": "Rare, powerful abilities unlocked once.",
		"icon": "res://assets/sprites/hub_icons/mutation_icon.png",
		"angle": 150.0,  # 8 o'clock
		"upgrades": ["revival", "feral_howl", "junkyard_chimera"],
	},
}

# --- Upgrade definitions ---
# key = permanent dict key, max_level = max (1 for mutations)
# costs = array of dicts, one per level
const UPGRADES = {
	# ── Combat Paws ──
	"bite_damage": {
		"name": "Iron Maw",
		"desc": "+1 bite damage per level",
		"flavor": "A well-chewed toy makes for stronger jaws.",
		"key": "bite_damage_level",
		"max_level": 10,
		"icon": "res://assets/sprites/hub_icons/bite_damage.png",
		"costs": [
			{"iron_scrap": 3, "timber": 2},
			{"iron_scrap": 5, "timber": 3},
			{"iron_scrap": 7, "stone": 3},
			{"iron_scrap": 10, "stone": 5},
			{"iron_scrap": 12, "stone": 6, "fuel": 2},
			{"iron_scrap": 15, "stone": 8, "fuel": 3},
			{"iron_scrap": 18, "stone": 10, "fuel": 4},
			{"iron_scrap": 20, "stone": 12, "blueprint": 1},
			{"iron_scrap": 24, "stone": 14, "blueprint": 2},
			{"iron_scrap": 28, "stone": 16, "blueprint": 3},
		],
	},
	"attack_speed": {
		"name": "Quick Snap",
		"desc": "+5% attack speed per level",
		"flavor": "Faster than a flea on a hot skillet.",
		"key": "attack_speed_level",
		"max_level": 5,
		"icon": "res://assets/sprites/hub_icons/attack_speed.png",
		"costs": [
			{"iron_scrap": 4, "fuel": 2},
			{"iron_scrap": 8, "fuel": 4},
			{"iron_scrap": 12, "fuel": 6, "stone": 3},
			{"iron_scrap": 16, "fuel": 8, "blueprint": 1},
			{"iron_scrap": 22, "fuel": 10, "blueprint": 2},
		],
	},
	"crit_chance": {
		"name": "Sharp Fangs",
		"desc": "+3% crit chance per level (1.5x damage)",
		"flavor": "Sometimes you bite just right.",
		"key": "crit_chance_level",
		"max_level": 5,
		"icon": "res://assets/sprites/hub_icons/crit_chance.png",
		"costs": [
			{"iron_scrap": 5, "stone": 3},
			{"iron_scrap": 10, "stone": 6},
			{"iron_scrap": 14, "stone": 8, "fuel": 3},
			{"iron_scrap": 18, "stone": 10, "blueprint": 1},
			{"iron_scrap": 24, "stone": 14, "blueprint": 2},
		],
	},

	# ── Survival Den ──
	"max_hp": {
		"name": "Thick Hide",
		"desc": "+10 max HP per level",
		"flavor": "Every scar is a lesson learned.",
		"key": "max_hp_level",
		"max_level": 10,
		"icon": "res://assets/sprites/hub_icons/max_hp.png",
		"costs": [
			{"timber": 3, "organic": 2},
			{"timber": 5, "organic": 3},
			{"timber": 7, "organic": 5},
			{"timber": 10, "organic": 6, "stone": 3},
			{"timber": 12, "organic": 8, "stone": 5},
			{"timber": 15, "organic": 10, "stone": 6},
			{"timber": 18, "organic": 12, "fuel": 3},
			{"timber": 20, "organic": 14, "blueprint": 1},
			{"timber": 24, "organic": 16, "blueprint": 2},
			{"timber": 28, "organic": 18, "blueprint": 3},
		],
	},
	"health_regen": {
		"name": "Resting Howl",
		"desc": "Regenerate health during combat",
		"flavor": "A good nap fixes everything.",
		"key": "health_regen_level",
		"max_level": 10,
		"icon": "res://assets/sprites/hub_icons/health_regen.png",
		"costs": [
			{"organic": 3, "timber": 2},
			{"organic": 5, "timber": 4},
			{"organic": 7, "timber": 5, "stone": 2},
			{"organic": 10, "timber": 7, "stone": 4},
			{"organic": 12, "timber": 8, "fuel": 3},
			{"organic": 15, "timber": 10, "fuel": 4},
			{"organic": 18, "timber": 12, "fuel": 5},
			{"organic": 20, "timber": 14, "blueprint": 1},
			{"organic": 24, "timber": 16, "blueprint": 2},
			{"organic": 28, "timber": 18, "blueprint": 3},
		],
	},
	"damage_reduction": {
		"name": "Tough Coat",
		"desc": "+2% damage reduction per level",
		"flavor": "That thick fur isn't just for show.",
		"key": "damage_reduction_level",
		"max_level": 5,
		"icon": "res://assets/sprites/hub_icons/damage_reduction.png",
		"costs": [
			{"stone": 5, "iron_scrap": 3},
			{"stone": 8, "iron_scrap": 6},
			{"stone": 12, "iron_scrap": 10, "timber": 5},
			{"stone": 16, "iron_scrap": 14, "blueprint": 1},
			{"stone": 22, "iron_scrap": 18, "blueprint": 2},
		],
	},

	# ── Scavenge Snout ──
	"dig_charges": {
		"name": "Deep Digger",
		"desc": "+1 dig charge per level",
		"flavor": "Dig dig dig! There's treasure down there!",
		"key": "dig_charges_level",
		"max_level": 10,
		"icon": "res://assets/sprites/hub_icons/dig_charges.png",
		"costs": [
			{"stone": 3, "iron_scrap": 2},
			{"stone": 5, "iron_scrap": 4},
			{"stone": 7, "iron_scrap": 5},
			{"stone": 10, "iron_scrap": 7, "timber": 3},
			{"stone": 12, "iron_scrap": 8, "timber": 5},
			{"stone": 15, "iron_scrap": 10, "fuel": 3},
			{"stone": 18, "iron_scrap": 12, "fuel": 4},
			{"stone": 20, "iron_scrap": 14, "blueprint": 1},
			{"stone": 24, "iron_scrap": 16, "blueprint": 2},
			{"stone": 28, "iron_scrap": 18, "blueprint": 3},
		],
	},
	"salvage_speed": {
		"name": "Keen Nose",
		"desc": "Faster salvaging and better yields",
		"flavor": "*sniff sniff* Found it!",
		"key": "salvage_speed_level",
		"max_level": 5,
		"icon": "res://assets/sprites/hub_icons/salvage_speed.png",
		"costs": [
			{"timber": 4, "iron_scrap": 3},
			{"timber": 8, "iron_scrap": 6},
			{"timber": 12, "iron_scrap": 10, "fuel": 3},
			{"timber": 16, "iron_scrap": 14, "blueprint": 1},
			{"timber": 22, "iron_scrap": 18, "blueprint": 2},
		],
	},
	"pickup_magnet": {
		"name": "Fetch!",
		"desc": "+15% pickup range per level",
		"flavor": "Good boy! Go get it!",
		"key": "pickup_magnet_level",
		"max_level": 5,
		"icon": "res://assets/sprites/hub_icons/pickup_magnet.png",
		"costs": [
			{"iron_scrap": 4, "organic": 2},
			{"iron_scrap": 8, "organic": 4},
			{"iron_scrap": 12, "organic": 6, "timber": 4},
			{"iron_scrap": 16, "organic": 8, "blueprint": 1},
			{"iron_scrap": 22, "organic": 12, "blueprint": 2},
		],
	},

	# ── Companion Legacy ──
	"rerolls": {
		"name": "Old Dog Tricks",
		"desc": "+1 level-up reroll per level",
		"flavor": "Experience is the best teacher.",
		"key": "reroll_level",
		"max_level": 5,
		"icon": "res://assets/sprites/hub_icons/rerolls.png",
		"costs": [
			{"timber": 5, "organic": 3},
			{"timber": 10, "organic": 6, "iron_scrap": 4},
			{"timber": 14, "organic": 8, "iron_scrap": 8},
			{"timber": 18, "organic": 12, "blueprint": 1},
			{"timber": 24, "organic": 16, "blueprint": 2},
		],
	},
	"xp_gain": {
		"name": "Street Smarts",
		"desc": "+5% XP gain per level",
		"flavor": "Every run teaches something new.",
		"key": "xp_gain_level",
		"max_level": 10,
		"icon": "res://assets/sprites/hub_icons/xp_gain.png",
		"costs": [
			{"organic": 3, "timber": 2},
			{"organic": 5, "timber": 3},
			{"organic": 7, "timber": 5},
			{"organic": 10, "timber": 6, "fuel": 2},
			{"organic": 12, "timber": 8, "fuel": 3},
			{"organic": 15, "timber": 10, "fuel": 4},
			{"organic": 18, "timber": 12, "iron_scrap": 5},
			{"organic": 20, "timber": 14, "blueprint": 1},
			{"organic": 24, "timber": 16, "blueprint": 2},
			{"organic": 28, "timber": 18, "blueprint": 3},
		],
	},
	"perk_choices": {
		"name": "Sharp Instincts",
		"desc": "See 4 perk options at level-up instead of 3",
		"flavor": "A wise dog sees more paths forward.",
		"key": "perk_choices_level",
		"max_level": 1,
		"icon": "res://assets/sprites/hub_icons/starting_throwables.png",
		"costs": [
			{"timber": 15, "organic": 12, "iron_scrap": 10, "blueprint": 2},
		],
	},

	# ── Mutation (one-time unlocks) ──
	"revival": {
		"name": "Soulbound Stray",
		"desc": "Revive once per run at 30% HP",
		"flavor": "Not even death can keep a good dog down.",
		"key": "mutation_revival",
		"max_level": 1,
		"icon": "res://assets/sprites/hub_icons/revival.png",
		"costs": [
			{"iron_scrap": 25, "organic": 20, "stone": 15, "blueprint": 3},
		],
	},
	"feral_howl": {
		"name": "Feral Howl",
		"desc": "Stun all enemies for 2s on wave start",
		"flavor": "AWOOOO! Everything freezes.",
		"key": "mutation_feral_howl",
		"max_level": 1,
		"icon": "res://assets/sprites/hub_icons/feral_howl.png",
		"costs": [
			{"iron_scrap": 20, "fuel": 15, "stone": 15, "blueprint": 3},
		],
	},
	"junkyard_chimera": {
		"name": "Junkyard Chimera",
		"desc": "Random powerful mutation each run",
		"flavor": "Something weird happened at the scrapyard...",
		"key": "mutation_junkyard_chimera",
		"max_level": 1,
		"icon": "res://assets/sprites/hub_icons/junkyard_chimera.png",
		"costs": [
			{"iron_scrap": 30, "timber": 20, "fuel": 15, "organic": 15, "blueprint": 4},
		],
	},
}

# ─── Regen tier table (health_regen_level 1-10) ────────────────
# Format: [heal_amount, interval_seconds]
const REGEN_TIERS = [
	[1, 8.0],   # Lv 1
	[1, 6.0],   # Lv 2
	[2, 5.0],   # Lv 3
	[2, 4.0],   # Lv 4
	[3, 4.0],   # Lv 5
	[3, 3.0],   # Lv 6
	[4, 3.0],   # Lv 7
	[4, 2.5],   # Lv 8
	[5, 2.5],   # Lv 9
	[5, 2.0],   # Lv 10
]

# ─── Chimera buff pool ─────────────────────────────────────────
const CHIMERA_BUFFS = [
	{"name": "Iron Stomach",  "effect": "damage",       "value": 20},
	{"name": "Turbo Paws",    "effect": "speed",        "value": 0.30},
	{"name": "Thick Skull",   "effect": "max_hp",       "value": 50},
	{"name": "Lucky Mutt",    "effect": "crit",         "value": 15},
	{"name": "Quick Twitch",  "effect": "attack_speed", "value": 0.20},
	{"name": "Scrap Magnet",  "effect": "xp",           "value": 0.50},
]

# ─── Helper functions ──────────────────────────────────────────

func get_upgrade_level(upgrade_id: String) -> int:
	if upgrade_id not in UPGRADES:
		push_warning("UpgradeDB: Unknown upgrade_id '%s'" % upgrade_id)
		return 0
	var key = UPGRADES[upgrade_id]["key"]
	return GameState.permanent.get(key, 0)

func get_max_level(upgrade_id: String) -> int:
	if upgrade_id not in UPGRADES:
		push_warning("UpgradeDB: Unknown upgrade_id '%s'" % upgrade_id)
		return 0
	return UPGRADES[upgrade_id]["max_level"]

func is_maxed(upgrade_id: String) -> bool:
	return get_upgrade_level(upgrade_id) >= get_max_level(upgrade_id)

func get_next_cost(upgrade_id: String) -> Dictionary:
	var level = get_upgrade_level(upgrade_id)
	var costs = UPGRADES[upgrade_id]["costs"]
	if level >= costs.size():
		return {}
	return costs[level]

func can_afford_upgrade(upgrade_id: String) -> bool:
	if is_maxed(upgrade_id):
		return false
	return GameState.can_afford(get_next_cost(upgrade_id))

func purchase_upgrade(upgrade_id: String) -> bool:
	if is_maxed(upgrade_id):
		return false
	var cost = get_next_cost(upgrade_id)
	if not GameState.spend_recipe(cost):
		return false
	var key = UPGRADES[upgrade_id]["key"]
	GameState.permanent[key] = GameState.permanent.get(key, 0) + 1
	SaveManager.save_game()
	return true

func get_category_progress(cat_id: String) -> int:
	var total = 0
	for upgrade_id in CATEGORIES[cat_id]["upgrades"]:
		total += get_upgrade_level(upgrade_id)
	return total

func get_category_max(cat_id: String) -> int:
	var total = 0
	for upgrade_id in CATEGORIES[cat_id]["upgrades"]:
		total += get_max_level(upgrade_id)
	return total

func can_afford_any_in_category(cat_id: String) -> bool:
	for upgrade_id in CATEGORIES[cat_id]["upgrades"]:
		if can_afford_upgrade(upgrade_id):
			return true
	return false

func is_category_maxed(cat_id: String) -> bool:
	return get_category_progress(cat_id) >= get_category_max(cat_id)

func get_effect_text(upgrade_id: String) -> String:
	var level = get_upgrade_level(upgrade_id)
	match upgrade_id:
		"bite_damage":
			return "+%d bite damage" % level if level > 0 else "No bonus yet"
		"attack_speed":
			return "+%d%% attack speed" % (level * 5) if level > 0 else "No bonus yet"
		"crit_chance":
			return "%d%% crit chance" % (level * 3) if level > 0 else "No bonus yet"
		"max_hp":
			return "+%d max HP" % (level * 10) if level > 0 else "No bonus yet"
		"health_regen":
			if level > 0:
				var tier = REGEN_TIERS[mini(level - 1, REGEN_TIERS.size() - 1)]
				return "%d HP every %.1fs" % [tier[0], tier[1]]
			return "No regen yet"
		"damage_reduction":
			return "%d%% damage reduction" % (level * 2) if level > 0 else "No bonus yet"
		"dig_charges":
			return "+%d dig charges" % level if level > 0 else "No bonus yet"
		"salvage_speed":
			var speeds = [1.0, 1.6, 2.4, 3.5, 5.0]
			return "%.1fx salvage speed" % speeds[clampi(level, 0, 4)] if level > 0 else "No bonus yet"
		"pickup_magnet":
			return "+%d%% pickup range" % (level * 15) if level > 0 else "No bonus yet"
		"rerolls":
			return "%d rerolls per level-up" % level if level > 0 else "No rerolls yet"
		"xp_gain":
			return "+%d%% XP gain" % (level * 5) if level > 0 else "No bonus yet"
		"perk_choices":
			return "4 perk choices at level-up" if level > 0 else "Not unlocked"
		"revival":
			return "Revive once per run" if level > 0 else "Not unlocked"
		"feral_howl":
			return "Stun on wave start" if level > 0 else "Not unlocked"
		"junkyard_chimera":
			return "Random buff each run" if level > 0 else "Not unlocked"
	return ""
