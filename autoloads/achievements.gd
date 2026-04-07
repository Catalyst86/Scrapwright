extends Node

# ============================================================
# Achievements — Tracks and unlocks achievements, persists via SaveManager
# ============================================================

signal achievement_unlocked(id)

const ACHIEVEMENTS = {
	# --- Combat ---
	"first_blood": {"name": "First Blood", "desc": "Kill your first enemy", "category": "Combat", "icon_color": Color(0.9, 0.2, 0.2), "stat": "total_kills", "target": 1},
	"century": {"name": "Century", "desc": "Kill 100 enemies in a single run", "category": "Combat", "icon_color": Color(0.9, 0.3, 0.1), "stat": "kills_this_run", "target": 100},
	"thousand_bones": {"name": "Thousand Bones", "desc": "Kill 1000 enemies total", "category": "Combat", "icon_color": Color(0.8, 0.2, 0.2), "stat": "total_kills", "target": 1000},
	"untouchable": {"name": "Untouchable", "desc": "Complete a wave without taking damage", "category": "Combat", "icon_color": Color(0.3, 0.8, 0.9), "stat": "", "target": 0},
	"boss_slayer": {"name": "Boss Slayer", "desc": "Defeat a boss enemy", "category": "Combat", "icon_color": Color(0.95, 0.5, 0.1), "stat": "", "target": 0},

	# --- Progression ---
	"baby_steps": {"name": "Baby Steps", "desc": "Complete wave 1", "category": "Progression", "icon_color": Color(0.4, 0.8, 0.4), "stat": "", "target": 0},
	"halfway_there": {"name": "Halfway There", "desc": "Reach wave 21", "category": "Progression", "icon_color": Color(0.5, 0.7, 0.9), "stat": "", "target": 0},
	"the_end": {"name": "The End", "desc": "Complete all 84 waves", "category": "Progression", "icon_color": Color(0.95, 0.82, 0.35), "stat": "", "target": 0},
	"repeat_offender": {"name": "Repeat Offender", "desc": "Complete 5 runs", "category": "Progression", "icon_color": Color(0.6, 0.5, 0.8), "stat": "runs_completed", "target": 5},
	"veteran": {"name": "Veteran", "desc": "Complete 10 runs", "category": "Progression", "icon_color": Color(0.8, 0.6, 0.9), "stat": "runs_completed", "target": 10},

	# --- Collection ---
	"key_collector": {"name": "Key Collector", "desc": "Collect 50 keys total", "category": "Collection", "icon_color": Color(0.8, 0.5, 0.2), "stat": "total_keys", "target": 50},
	"golden_touch": {"name": "Golden Touch", "desc": "Collect a gold key", "category": "Collection", "icon_color": Color(0.95, 0.82, 0.35), "stat": "", "target": 0},
	"secret_finder": {"name": "Secret Finder", "desc": "Collect a secret key", "category": "Collection", "icon_color": Color(0.85, 0.3, 0.85), "stat": "", "target": 0},
	"hoarder": {"name": "Hoarder", "desc": "Have 20+ of any material at once", "category": "Collection", "icon_color": Color(0.6, 0.6, 0.7), "stat": "", "target": 0},
	"full_inventory": {"name": "Full Inventory", "desc": "Have all 6 material types at 5+", "category": "Collection", "icon_color": Color(0.4, 0.7, 0.4), "stat": "", "target": 0},

	# --- Base Building ---
	"home_improvement": {"name": "Home Improvement", "desc": "Upgrade any building", "category": "Base Building", "icon_color": Color(0.9, 0.6, 0.2), "stat": "buildings_upgraded", "target": 1},
	"master_builder": {"name": "Master Builder", "desc": "Max out any building (level 3)", "category": "Base Building", "icon_color": Color(0.95, 0.75, 0.2), "stat": "", "target": 0},
	"fully_upgraded": {"name": "Fully Upgraded", "desc": "Max out ALL buildings", "category": "Base Building", "icon_color": Color(1.0, 0.85, 0.3), "stat": "", "target": 0},
	"first_craft": {"name": "First Craft", "desc": "Craft your first item", "category": "Base Building", "icon_color": Color(0.7, 0.5, 0.3), "stat": "items_crafted", "target": 1},

	# --- Misc ---
	"puppy_power": {"name": "Puppy Power", "desc": "Reach player level 10 in a single run", "category": "Misc", "icon_color": Color(0.9, 0.6, 0.8), "stat": "", "target": 0},
}

# Categories in display order
const CATEGORIES = ["Combat", "Progression", "Collection", "Base Building", "Misc"]

var unlocked: Dictionary = {}  # {"achievement_id": true}
var stats: Dictionary = {
	"total_kills": 0,
	"kills_this_run": 0,
	"total_keys": 0,
	"runs_completed": 0,
	"buildings_upgraded": 0,
	"items_crafted": 0,
	"damage_taken_this_wave": 0,
}

func _ready() -> void:
	# Load is handled by SaveManager after it initializes
	pass

# --- Core functions ---

func check_and_unlock(id: String) -> void:
	if id not in ACHIEVEMENTS:
		return
	if is_unlocked(id):
		return
	unlocked[id] = true
	emit_signal("achievement_unlocked", id)
	_show_toast(id)
	_save()

func is_unlocked(id: String) -> bool:
	return unlocked.get(id, false)

func increment_stat(stat_name: String, amount: int = 1) -> void:
	stats[stat_name] = stats.get(stat_name, 0) + amount
	_check_stat_achievements(stat_name)

func reset_run_stats() -> void:
	stats["kills_this_run"] = 0
	stats["damage_taken_this_wave"] = 0

# --- Stat-based auto-checks ---

func _check_stat_achievements(stat_name: String) -> void:
	for id in ACHIEVEMENTS:
		if is_unlocked(id):
			continue
		var ach = ACHIEVEMENTS[id]
		if ach.get("stat", "") == stat_name:
			var target = ach.get("target", 0)
			if target > 0 and stats.get(stat_name, 0) >= target:
				check_and_unlock(id)

# --- Material checks (called from game_state) ---

func check_material_achievements() -> void:
	# Hoarder: 20+ of any material
	for mat in GameState.materials:
		if GameState.materials[mat] >= 20:
			check_and_unlock("hoarder")
			break
	# Full inventory: all 6 at 5+
	var all_five = true
	for mat in GameState.materials:
		if GameState.materials[mat] < 5:
			all_five = false
			break
	if all_five:
		check_and_unlock("full_inventory")

# --- Building checks ---

func check_building_achievements() -> void:
	# Check upgrades using actual UpgradeDB keys and their max levels
	var upgrade_max = {
		"bite_damage": 10, "attack_speed": 5, "crit_chance": 5,
		"max_hp": 10, "health_regen": 10, "damage_reduction": 5,
		"dig_charges": 10, "salvage_speed": 5, "pickup_magnet": 5,
		"rerolls": 5, "xp_gain": 10, "perk_choices": 1,
		"revival": 1, "feral_howl": 1, "junkyard_chimera": 1,
	}
	# Map upgrade_id -> permanent dict key (matches UpgradeDB UPGRADES[id].key)
	var upgrade_keys = {
		"bite_damage": "bite_damage_level", "attack_speed": "attack_speed_level",
		"crit_chance": "crit_chance_level", "max_hp": "max_hp_level",
		"health_regen": "health_regen_level", "damage_reduction": "damage_reduction_level",
		"dig_charges": "dig_charges_level", "salvage_speed": "salvage_speed_level",
		"pickup_magnet": "pickup_magnet_level", "rerolls": "reroll_level",
		"xp_gain": "xp_gain_level", "perk_choices": "perk_choices_level",
		"revival": "mutation_revival", "feral_howl": "mutation_feral_howl",
		"junkyard_chimera": "mutation_junkyard_chimera",
	}
	var any_maxed = false
	var all_maxed = true
	for uid in upgrade_max:
		var key = upgrade_keys[uid]
		var level = GameState.permanent.get(key, 0)
		if level >= upgrade_max[uid]:
			any_maxed = true
		else:
			all_maxed = false
	if any_maxed:
		check_and_unlock("master_builder")
	if all_maxed:
		check_and_unlock("fully_upgraded")

# --- Save / Load via SaveManager's ConfigFile ---

func _save() -> void:
	var config = ConfigFile.new()
	var err = config.load(SaveManager.get_save_path())
	if err != OK:
		config = ConfigFile.new()

	# Save unlocked achievements
	for id in unlocked:
		config.set_value("achievements", id, true)

	# Save stats
	for key in stats:
		config.set_value("achievement_stats", key, stats[key])

	config.save(SaveManager.get_save_path())

func load_achievements() -> void:
	# Always reset in-memory state first so previous profile data doesn't carry over
	unlocked.clear()
	stats = {
		"total_kills": 0,
		"kills_this_run": 0,
		"total_keys": 0,
		"runs_completed": 0,
		"buildings_upgraded": 0,
		"items_crafted": 0,
		"damage_taken_this_wave": 0,
	}

	var config = ConfigFile.new()
	var err = config.load(SaveManager.get_save_path())
	if err != OK:
		return

	# Load unlocked
	if config.has_section("achievements"):
		for key in config.get_section_keys("achievements"):
			unlocked[key] = config.get_value("achievements", key, false)

	# Load stats
	if config.has_section("achievement_stats"):
		for key in config.get_section_keys("achievement_stats"):
			stats[key] = config.get_value("achievement_stats", key, 0)

# --- Toast notification ---

func _show_toast(id: String) -> void:
	var ach = ACHIEVEMENTS.get(id, {})
	var ach_name = ach.get("name", id)

	# We add the toast to the root viewport so it works in any scene
	var root = get_tree().root
	if not root:
		return

	# Background panel
	var toast_panel = PanelContainer.new()
	toast_panel.z_index = 100
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.06, 0.04, 0.92)
	sb.border_color = Color(0.95, 0.82, 0.35, 0.7)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	sb.set_content_margin_all(8)
	toast_panel.add_theme_stylebox_override("panel", sb)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	toast_panel.add_child(hbox)

	# Icon dot
	var dot = ColorRect.new()
	dot.custom_minimum_size = Vector2(14, 14)
	dot.color = ach.get("icon_color", Color(0.95, 0.82, 0.35))
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox.add_child(dot)

	# Text
	var lbl = Label.new()
	lbl.text = "Achievement Unlocked: %s!" % ach_name
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Color(0.95, 0.82, 0.35))
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	lbl.add_theme_constant_override("shadow_offset_x", 1)
	lbl.add_theme_constant_override("shadow_offset_y", 1)
	hbox.add_child(lbl)

	root.add_child.call_deferred(toast_panel)

	# Position at top center, start off-screen
	await root.get_tree().process_frame  # Wait for layout
	var vp_w = root.get_viewport().get_visible_rect().size.x
	var panel_w = toast_panel.size.x
	toast_panel.position = Vector2((vp_w - panel_w) / 2.0, -50)

	# Slide in
	var tw = toast_panel.create_tween()
	tw.tween_property(toast_panel, "position:y", 10.0, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	# Hold
	tw.tween_interval(3.0)
	# Slide out
	tw.tween_property(toast_panel, "position:y", -60.0, 0.3).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.tween_callback(toast_panel.queue_free)
