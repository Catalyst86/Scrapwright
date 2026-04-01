extends Node

# ============================================================
# StageData — Stage definitions, wave compositions, themes
# ============================================================

const WAVES_PER_STAGE = 14
const TOTAL_STAGES = 6

const STAGE_NAMES = ["The Scrapyard", "Fungal Depths", "Molten Core", "Frozen Caverns", "Clockwork Factory", "The Abyss"]

# Which enemies are native to each stage (don't get stat-scaled in their home stage)
const STAGE_NATIVE_ENEMIES = {
	0: ["rusher", "shooter", "tank", "flyer", "exploder", "junkyard_mech", "scrap_sentinel"],
	1: ["spore_walker", "mycelium_sniper", "fungal_brute", "fungal_titan", "spore_mother"],
	2: ["magma_imp", "lava_lobber", "obsidian_golem", "molten_wyrm", "ember_drake"],
	3: ["frost_sprite", "ice_archer", "glacial_hulk", "crystal_bat", "frost_warden", "crystal_colossus"],
	4: ["gear_drone", "steam_turret", "brass_enforcer", "spark_bug", "piston_crusher", "the_architect"],
	5: ["shadow_crawler", "void_weaver", "abyssal_knight", "phantom", "the_devourer", "scrap_king"],
}

# Stat scaling for non-native enemies appearing in later stages
const STAGE_HP_SCALE = [1.0, 1.4, 1.8, 2.2, 2.6, 3.0]
const STAGE_DMG_SCALE = [1.0, 1.3, 1.6, 1.9, 2.2, 2.5]

# ─── Wave Definitions ───────────────────────────────────────

# Stage 1: Steampunk Caverns (waves 1-14)
# Waves 1-6: normal, Wave 7: boss, Waves 8-13: normal (harder), Wave 14: final boss
const STAGE_1_WAVES = [
	# wave 1
	[{"type": "rusher", "count": 5}],
	# wave 2
	[{"type": "rusher", "count": 6}, {"type": "shooter", "count": 2}],
	# wave 3
	[{"type": "rusher", "count": 8}, {"type": "shooter", "count": 3}],
	# wave 4
	[{"type": "rusher", "count": 6}, {"type": "shooter", "count": 3}, {"type": "tank", "count": 1}],
	# wave 5
	[{"type": "rusher", "count": 10}, {"type": "shooter", "count": 4}, {"type": "tank", "count": 2}],
	# wave 6
	[{"type": "rusher", "count": 10}, {"type": "shooter", "count": 5}, {"type": "flyer", "count": 3}],
	# wave 7 — MID-BOSS WAVE (Scrap Sentinel)
	[{"type": "rusher", "count": 18}, {"type": "shooter", "count": 8}, {"type": "tank", "count": 4}, {"type": "flyer", "count": 5}, {"type": "exploder", "count": 5}, {"type": "scrap_sentinel", "count": 1}],
	# wave 8
	[{"type": "rusher", "count": 12}, {"type": "shooter", "count": 6}, {"type": "tank", "count": 2}, {"type": "flyer", "count": 3}],
	# wave 9
	[{"type": "exploder", "count": 4}, {"type": "rusher", "count": 10}, {"type": "shooter", "count": 5}],
	# wave 10
	[{"type": "rusher", "count": 14}, {"type": "shooter", "count": 7}, {"type": "tank", "count": 3}, {"type": "flyer", "count": 4}],
	# wave 11
	[{"type": "exploder", "count": 5}, {"type": "rusher", "count": 12}, {"type": "tank", "count": 3}, {"type": "shooter", "count": 6}],
	# wave 12
	[{"type": "rusher", "count": 14}, {"type": "shooter", "count": 8}, {"type": "flyer", "count": 5}, {"type": "exploder", "count": 4}],
	# wave 13
	[{"type": "rusher", "count": 16}, {"type": "shooter", "count": 8}, {"type": "tank", "count": 4}, {"type": "flyer", "count": 5}, {"type": "exploder", "count": 5}],
	# wave 14 — FINAL BOSS WAVE (Junkyard Mech)
	[{"type": "rusher", "count": 22}, {"type": "shooter", "count": 12}, {"type": "tank", "count": 5}, {"type": "flyer", "count": 8}, {"type": "exploder", "count": 6}, {"type": "junkyard_mech", "count": 1}],
]

# Stage 2: Fungal Depths (waves 15-28)
const STAGE_2_WAVES = [
	# wave 1 (global 15)
	[{"type": "spore_walker", "count": 6}, {"type": "rusher", "count": 3}],
	# wave 2 (global 16)
	[{"type": "spore_walker", "count": 8}, {"type": "mycelium_sniper", "count": 2}, {"type": "rusher", "count": 4}],
	# wave 3 (global 17)
	[{"type": "spore_walker", "count": 10}, {"type": "mycelium_sniper", "count": 4}, {"type": "shooter", "count": 3}],
	# wave 4 (global 18)
	[{"type": "spore_walker", "count": 8}, {"type": "mycelium_sniper", "count": 3}, {"type": "fungal_brute", "count": 1}, {"type": "tank", "count": 1}],
	# wave 5 (global 19)
	[{"type": "spore_walker", "count": 12}, {"type": "mycelium_sniper", "count": 5}, {"type": "fungal_brute", "count": 2}, {"type": "exploder", "count": 3}],
	# wave 6 (global 20)
	[{"type": "spore_walker", "count": 10}, {"type": "mycelium_sniper", "count": 6}, {"type": "flyer", "count": 5}, {"type": "shooter", "count": 4}],
	# wave 7 — MID-BOSS WAVE (Spore Mother)
	[{"type": "spore_walker", "count": 20}, {"type": "mycelium_sniper", "count": 10}, {"type": "fungal_brute", "count": 4}, {"type": "flyer", "count": 6}, {"type": "exploder", "count": 5}, {"type": "spore_mother", "count": 1}],
	# wave 8 (global 22)
	[{"type": "spore_walker", "count": 12}, {"type": "mycelium_sniper", "count": 6}, {"type": "fungal_brute", "count": 2}, {"type": "tank", "count": 2}],
	# wave 9 (global 23)
	[{"type": "spore_walker", "count": 14}, {"type": "mycelium_sniper", "count": 7}, {"type": "fungal_brute", "count": 2}, {"type": "exploder", "count": 4}],
	# wave 10 (global 24)
	[{"type": "spore_walker", "count": 14}, {"type": "mycelium_sniper", "count": 8}, {"type": "fungal_brute", "count": 3}, {"type": "flyer", "count": 5}],
	# wave 11 (global 25)
	[{"type": "spore_walker", "count": 16}, {"type": "mycelium_sniper", "count": 8}, {"type": "fungal_brute", "count": 3}, {"type": "tank", "count": 2}, {"type": "exploder", "count": 4}],
	# wave 12 (global 26)
	[{"type": "spore_walker", "count": 16}, {"type": "mycelium_sniper", "count": 9}, {"type": "fungal_brute", "count": 3}, {"type": "flyer", "count": 6}, {"type": "shooter", "count": 5}],
	# wave 13 (global 27)
	[{"type": "spore_walker", "count": 18}, {"type": "mycelium_sniper", "count": 10}, {"type": "fungal_brute", "count": 4}, {"type": "flyer", "count": 6}, {"type": "exploder", "count": 5}],
	# wave 14 — FINAL BOSS WAVE (Fungal Titan) (global 28)
	[{"type": "spore_walker", "count": 24}, {"type": "mycelium_sniper", "count": 14}, {"type": "fungal_brute", "count": 5}, {"type": "flyer", "count": 8}, {"type": "exploder", "count": 6}, {"type": "tank", "count": 3}, {"type": "fungal_titan", "count": 1}],
]

# Stage 3: Molten Core (waves 29-42)
const STAGE_3_WAVES = [
	# wave 1 (global 29)
	[{"type": "magma_imp", "count": 7}, {"type": "spore_walker", "count": 4}],
	# wave 2 (global 30)
	[{"type": "magma_imp", "count": 8}, {"type": "lava_lobber", "count": 3}, {"type": "mycelium_sniper", "count": 3}],
	# wave 3 (global 31)
	[{"type": "magma_imp", "count": 10}, {"type": "lava_lobber", "count": 4}, {"type": "rusher", "count": 5}],
	# wave 4 (global 32)
	[{"type": "magma_imp", "count": 8}, {"type": "lava_lobber", "count": 4}, {"type": "obsidian_golem", "count": 1}, {"type": "fungal_brute", "count": 1}],
	# wave 5 (global 33)
	[{"type": "magma_imp", "count": 14}, {"type": "lava_lobber", "count": 6}, {"type": "obsidian_golem", "count": 2}, {"type": "exploder", "count": 4}],
	# wave 6 (global 34)
	[{"type": "magma_imp", "count": 12}, {"type": "lava_lobber", "count": 5}, {"type": "flyer", "count": 6}, {"type": "mycelium_sniper", "count": 5}],
	# wave 7 — MID-BOSS WAVE (Ember Drake)
	[{"type": "magma_imp", "count": 18}, {"type": "lava_lobber", "count": 10}, {"type": "obsidian_golem", "count": 6}, {"type": "flyer", "count": 8}, {"type": "exploder", "count": 6}, {"type": "ember_drake", "count": 1}],
	# wave 8 (global 36)
	[{"type": "magma_imp", "count": 14}, {"type": "lava_lobber", "count": 7}, {"type": "obsidian_golem", "count": 2}, {"type": "fungal_brute", "count": 2}],
	# wave 9 (global 37)
	[{"type": "magma_imp", "count": 16}, {"type": "lava_lobber", "count": 8}, {"type": "obsidian_golem", "count": 3}, {"type": "exploder", "count": 5}],
	# wave 10 (global 38)
	[{"type": "magma_imp", "count": 16}, {"type": "lava_lobber", "count": 9}, {"type": "obsidian_golem", "count": 3}, {"type": "flyer", "count": 6}, {"type": "tank", "count": 3}],
	# wave 11 (global 39)
	[{"type": "magma_imp", "count": 18}, {"type": "lava_lobber", "count": 9}, {"type": "obsidian_golem", "count": 3}, {"type": "fungal_brute", "count": 3}, {"type": "exploder", "count": 5}],
	# wave 12 (global 40)
	[{"type": "magma_imp", "count": 18}, {"type": "lava_lobber", "count": 10}, {"type": "obsidian_golem", "count": 3}, {"type": "flyer", "count": 7}, {"type": "mycelium_sniper", "count": 6}],
	# wave 13 (global 41)
	[{"type": "magma_imp", "count": 20}, {"type": "lava_lobber", "count": 10}, {"type": "obsidian_golem", "count": 4}, {"type": "flyer", "count": 7}, {"type": "exploder", "count": 6}, {"type": "fungal_brute", "count": 3}],
	# wave 14 — FINAL BOSS WAVE (Molten Wyrm) (global 42)
	[{"type": "magma_imp", "count": 26}, {"type": "lava_lobber", "count": 14}, {"type": "obsidian_golem", "count": 5}, {"type": "flyer", "count": 10}, {"type": "exploder", "count": 8}, {"type": "fungal_brute", "count": 4}, {"type": "molten_wyrm", "count": 1}],
]

# Stage 4: Frozen Caverns (waves 43-56)
const STAGE_4_WAVES = [
	# wave 1 (global 43)
	[{"type": "frost_sprite", "count": 7}, {"type": "magma_imp", "count": 4}],
	# wave 2 (global 44)
	[{"type": "frost_sprite", "count": 9}, {"type": "ice_archer", "count": 3}, {"type": "lava_lobber", "count": 3}],
	# wave 3 (global 45)
	[{"type": "frost_sprite", "count": 12}, {"type": "ice_archer", "count": 5}, {"type": "rusher", "count": 5}],
	# wave 4 (global 46)
	[{"type": "frost_sprite", "count": 10}, {"type": "ice_archer", "count": 4}, {"type": "glacial_hulk", "count": 1}, {"type": "obsidian_golem", "count": 1}],
	# wave 5 (global 47)
	[{"type": "frost_sprite", "count": 14}, {"type": "ice_archer", "count": 6}, {"type": "glacial_hulk", "count": 2}, {"type": "crystal_bat", "count": 4}],
	# wave 6 (global 48)
	[{"type": "frost_sprite", "count": 12}, {"type": "ice_archer", "count": 7}, {"type": "crystal_bat", "count": 6}, {"type": "mycelium_sniper", "count": 5}],
	# wave 7 — MID-BOSS WAVE (Frost Warden) (global 49)
	[{"type": "frost_sprite", "count": 22}, {"type": "ice_archer", "count": 12}, {"type": "glacial_hulk", "count": 5}, {"type": "crystal_bat", "count": 8}, {"type": "exploder", "count": 6}, {"type": "frost_warden", "count": 1}],
	# wave 8 (global 50)
	[{"type": "frost_sprite", "count": 14}, {"type": "ice_archer", "count": 8}, {"type": "glacial_hulk", "count": 3}, {"type": "obsidian_golem", "count": 2}],
	# wave 9 (global 51)
	[{"type": "frost_sprite", "count": 16}, {"type": "ice_archer", "count": 9}, {"type": "glacial_hulk", "count": 3}, {"type": "crystal_bat", "count": 5}],
	# wave 10 (global 52)
	[{"type": "frost_sprite", "count": 18}, {"type": "ice_archer", "count": 10}, {"type": "glacial_hulk", "count": 3}, {"type": "crystal_bat", "count": 6}, {"type": "tank", "count": 3}],
	# wave 11 (global 53)
	[{"type": "frost_sprite", "count": 18}, {"type": "ice_archer", "count": 10}, {"type": "glacial_hulk", "count": 4}, {"type": "fungal_brute", "count": 3}, {"type": "exploder", "count": 5}],
	# wave 12 (global 54)
	[{"type": "frost_sprite", "count": 20}, {"type": "ice_archer", "count": 11}, {"type": "glacial_hulk", "count": 4}, {"type": "crystal_bat", "count": 7}, {"type": "lava_lobber", "count": 6}],
	# wave 13 (global 55)
	[{"type": "frost_sprite", "count": 22}, {"type": "ice_archer", "count": 12}, {"type": "glacial_hulk", "count": 5}, {"type": "crystal_bat", "count": 8}, {"type": "exploder", "count": 6}, {"type": "obsidian_golem", "count": 3}],
	# wave 14 — FINAL BOSS WAVE (Crystal Colossus) (global 56)
	[{"type": "frost_sprite", "count": 28}, {"type": "ice_archer", "count": 16}, {"type": "glacial_hulk", "count": 6}, {"type": "crystal_bat", "count": 10}, {"type": "exploder", "count": 8}, {"type": "fungal_brute", "count": 4}, {"type": "crystal_colossus", "count": 1}],
]

# Stage 5: Clockwork Factory (waves 57-70)
const STAGE_5_WAVES = [
	# wave 1 (global 57)
	[{"type": "gear_drone", "count": 8}, {"type": "frost_sprite", "count": 5}],
	# wave 2 (global 58)
	[{"type": "gear_drone", "count": 10}, {"type": "steam_turret", "count": 3}, {"type": "ice_archer", "count": 4}],
	# wave 3 (global 59)
	[{"type": "gear_drone", "count": 12}, {"type": "steam_turret", "count": 5}, {"type": "spark_bug", "count": 4}],
	# wave 4 (global 60)
	[{"type": "gear_drone", "count": 10}, {"type": "steam_turret", "count": 5}, {"type": "brass_enforcer", "count": 2}, {"type": "glacial_hulk", "count": 1}],
	# wave 5 (global 61)
	[{"type": "gear_drone", "count": 16}, {"type": "steam_turret", "count": 7}, {"type": "brass_enforcer", "count": 3}, {"type": "spark_bug", "count": 5}],
	# wave 6 (global 62)
	[{"type": "gear_drone", "count": 14}, {"type": "steam_turret", "count": 8}, {"type": "spark_bug", "count": 7}, {"type": "lava_lobber", "count": 5}],
	# wave 7 — MID-BOSS WAVE (Piston Crusher) (global 63)
	[{"type": "gear_drone", "count": 24}, {"type": "steam_turret", "count": 14}, {"type": "brass_enforcer", "count": 6}, {"type": "spark_bug", "count": 8}, {"type": "exploder", "count": 7}, {"type": "piston_crusher", "count": 1}],
	# wave 8 (global 64)
	[{"type": "gear_drone", "count": 16}, {"type": "steam_turret", "count": 9}, {"type": "brass_enforcer", "count": 3}, {"type": "glacial_hulk", "count": 3}],
	# wave 9 (global 65)
	[{"type": "gear_drone", "count": 18}, {"type": "steam_turret", "count": 10}, {"type": "brass_enforcer", "count": 4}, {"type": "spark_bug", "count": 6}],
	# wave 10 (global 66)
	[{"type": "gear_drone", "count": 20}, {"type": "steam_turret", "count": 11}, {"type": "brass_enforcer", "count": 4}, {"type": "spark_bug", "count": 7}, {"type": "obsidian_golem", "count": 3}],
	# wave 11 (global 67)
	[{"type": "gear_drone", "count": 20}, {"type": "steam_turret", "count": 11}, {"type": "brass_enforcer", "count": 4}, {"type": "crystal_bat", "count": 6}, {"type": "exploder", "count": 6}],
	# wave 12 (global 68)
	[{"type": "gear_drone", "count": 22}, {"type": "steam_turret", "count": 12}, {"type": "brass_enforcer", "count": 5}, {"type": "spark_bug", "count": 8}, {"type": "ice_archer", "count": 6}],
	# wave 13 (global 69)
	[{"type": "gear_drone", "count": 24}, {"type": "steam_turret", "count": 13}, {"type": "brass_enforcer", "count": 5}, {"type": "spark_bug", "count": 8}, {"type": "exploder", "count": 7}, {"type": "glacial_hulk", "count": 4}],
	# wave 14 — FINAL BOSS WAVE (The Architect) (global 70)
	[{"type": "gear_drone", "count": 30}, {"type": "steam_turret", "count": 16}, {"type": "brass_enforcer", "count": 6}, {"type": "spark_bug", "count": 12}, {"type": "exploder", "count": 9}, {"type": "obsidian_golem", "count": 5}, {"type": "the_architect", "count": 1}],
]

# Stage 6: The Abyss (waves 71-84)
const STAGE_6_WAVES = [
	# wave 1 (global 71)
	[{"type": "shadow_crawler", "count": 9}, {"type": "gear_drone", "count": 5}],
	# wave 2 (global 72)
	[{"type": "shadow_crawler", "count": 12}, {"type": "void_weaver", "count": 4}, {"type": "steam_turret", "count": 4}],
	# wave 3 (global 73)
	[{"type": "shadow_crawler", "count": 14}, {"type": "void_weaver", "count": 6}, {"type": "phantom", "count": 3}],
	# wave 4 (global 74)
	[{"type": "shadow_crawler", "count": 12}, {"type": "void_weaver", "count": 5}, {"type": "abyssal_knight", "count": 2}, {"type": "brass_enforcer", "count": 2}],
	# wave 5 (global 75)
	[{"type": "shadow_crawler", "count": 18}, {"type": "void_weaver", "count": 8}, {"type": "abyssal_knight", "count": 3}, {"type": "phantom", "count": 5}],
	# wave 6 (global 76)
	[{"type": "shadow_crawler", "count": 16}, {"type": "void_weaver", "count": 9}, {"type": "phantom", "count": 8}, {"type": "ice_archer", "count": 6}],
	# wave 7 — MID-BOSS WAVE (The Devourer) (global 77)
	[{"type": "shadow_crawler", "count": 26}, {"type": "void_weaver", "count": 16}, {"type": "abyssal_knight", "count": 7}, {"type": "phantom", "count": 10}, {"type": "exploder", "count": 8}, {"type": "the_devourer", "count": 1}],
	# wave 8 (global 78)
	[{"type": "shadow_crawler", "count": 18}, {"type": "void_weaver", "count": 10}, {"type": "abyssal_knight", "count": 4}, {"type": "brass_enforcer", "count": 3}],
	# wave 9 (global 79)
	[{"type": "shadow_crawler", "count": 20}, {"type": "void_weaver", "count": 12}, {"type": "abyssal_knight", "count": 4}, {"type": "phantom", "count": 7}],
	# wave 10 (global 80)
	[{"type": "shadow_crawler", "count": 22}, {"type": "void_weaver", "count": 13}, {"type": "abyssal_knight", "count": 5}, {"type": "phantom", "count": 8}, {"type": "glacial_hulk", "count": 4}],
	# wave 11 (global 81)
	[{"type": "shadow_crawler", "count": 24}, {"type": "void_weaver", "count": 13}, {"type": "abyssal_knight", "count": 5}, {"type": "spark_bug", "count": 7}, {"type": "exploder", "count": 7}],
	# wave 12 (global 82)
	[{"type": "shadow_crawler", "count": 24}, {"type": "void_weaver", "count": 14}, {"type": "abyssal_knight", "count": 5}, {"type": "phantom", "count": 9}, {"type": "steam_turret", "count": 7}],
	# wave 13 (global 83)
	[{"type": "shadow_crawler", "count": 26}, {"type": "void_weaver", "count": 15}, {"type": "abyssal_knight", "count": 6}, {"type": "phantom", "count": 10}, {"type": "exploder", "count": 8}, {"type": "brass_enforcer", "count": 5}],
	# wave 14 — FINAL BOSS WAVE (Scrap King) (global 84)
	[{"type": "shadow_crawler", "count": 32}, {"type": "void_weaver", "count": 18}, {"type": "abyssal_knight", "count": 7}, {"type": "phantom", "count": 14}, {"type": "exploder", "count": 10}, {"type": "glacial_hulk", "count": 5}, {"type": "scrap_king", "count": 1}],
]

const ALL_STAGE_WAVES = [STAGE_1_WAVES, STAGE_2_WAVES, STAGE_3_WAVES, STAGE_4_WAVES, STAGE_5_WAVES, STAGE_6_WAVES]

# ─── Arena Themes ───────────────────────────────────────────

const THEMES = [
	# Stage 1: Steampunk Caverns
	{
		"name": "Steampunk Caverns",
		"floor_base": Color(0.18, 0.14, 0.10),
		"floor_alt": Color(0.20, 0.16, 0.12),
		"wall_base": Color(0.12, 0.09, 0.06),
		"wall_highlight": Color(0.22, 0.17, 0.12),
		"outer_bg": Color(0.02, 0.015, 0.01),
		"mortar": Color(0.10, 0.07, 0.05),
		"puddle_color": Color(0.08, 0.10, 0.16, 0.5),
		"puddle_highlight": Color(0.15, 0.20, 0.30, 0.3),
		"torch_color": Color(1.0, 0.65, 0.15),
		"torch_glow": Color(1.0, 0.65, 0.15, 0.12),
		"moss_color": Color(0.15, 0.25, 0.10, 0.35),
		"detail_type": "steampunk",  # pipes, gears, bolts
		"particle_type": "dust_and_embers",
	},
	# Stage 2: Fungal Depths
	{
		"name": "Fungal Depths",
		"floor_base": Color(0.10, 0.14, 0.12),
		"floor_alt": Color(0.12, 0.17, 0.14),
		"wall_base": Color(0.06, 0.10, 0.08),
		"wall_highlight": Color(0.12, 0.20, 0.16),
		"outer_bg": Color(0.01, 0.02, 0.015),
		"mortar": Color(0.05, 0.08, 0.06),
		"puddle_color": Color(0.05, 0.22, 0.12, 0.5),
		"puddle_highlight": Color(0.10, 0.40, 0.20, 0.3),
		"torch_color": Color(0.3, 0.9, 0.5),
		"torch_glow": Color(0.3, 0.9, 0.5, 0.12),
		"moss_color": Color(0.1, 0.35, 0.25, 0.4),
		"detail_type": "fungal",  # mushroom caps, tendrils, glowing spots
		"particle_type": "spores_and_motes",
	},
	# Stage 3: Molten Core
	{
		"name": "Molten Core",
		"floor_base": Color(0.16, 0.08, 0.04),
		"floor_alt": Color(0.20, 0.10, 0.05),
		"wall_base": Color(0.12, 0.05, 0.02),
		"wall_highlight": Color(0.22, 0.10, 0.05),
		"outer_bg": Color(0.03, 0.01, 0.005),
		"mortar": Color(0.08, 0.04, 0.02),
		"puddle_color": Color(0.8, 0.3, 0.05, 0.45),
		"puddle_highlight": Color(1.0, 0.5, 0.1, 0.3),
		"torch_color": Color(1.0, 0.4, 0.1),
		"torch_glow": Color(1.0, 0.4, 0.1, 0.15),
		"moss_color": Color(0.5, 0.2, 0.05, 0.3),  # lava cracks instead of moss
		"detail_type": "molten",  # lava cracks, obsidian, heat shimmer
		"particle_type": "embers_and_ash",
	},
	# Stage 4: Frozen Caverns
	{
		"name": "Frozen Caverns",
		"floor_base": Color(0.15, 0.18, 0.25),
		"floor_alt": Color(0.18, 0.22, 0.30),
		"wall_base": Color(0.08, 0.12, 0.20),
		"wall_highlight": Color(0.20, 0.28, 0.40),
		"outer_bg": Color(0.01, 0.015, 0.03),
		"mortar": Color(0.06, 0.10, 0.16),
		"puddle_color": Color(0.3, 0.6, 0.9, 0.4),
		"puddle_highlight": Color(0.5, 0.8, 1.0, 0.3),
		"torch_color": Color(0.4, 0.7, 1.0),
		"torch_glow": Color(0.4, 0.7, 1.0, 0.12),
		"moss_color": Color(0.3, 0.5, 0.7, 0.3),  # frost crystals
		"detail_type": "frozen",  # ice shards, frost, icicles
		"particle_type": "snow_and_ice",
	},
	# Stage 5: Clockwork Factory (cold industrial steel, not warm)
	{
		"name": "Clockwork Factory",
		"floor_base": Color(0.16, 0.17, 0.20),
		"floor_alt": Color(0.20, 0.21, 0.25),
		"wall_base": Color(0.10, 0.11, 0.14),
		"wall_highlight": Color(0.25, 0.27, 0.32),
		"outer_bg": Color(0.015, 0.015, 0.02),
		"mortar": Color(0.08, 0.08, 0.10),
		"puddle_color": Color(0.2, 0.6, 0.3, 0.4),  # green coolant
		"puddle_highlight": Color(0.3, 0.8, 0.4, 0.3),
		"torch_color": Color(1.0, 0.9, 0.4),  # bright electric light
		"torch_glow": Color(1.0, 0.9, 0.4, 0.15),
		"moss_color": Color(0.4, 0.3, 0.15, 0.3),  # oil/rust patches
		"detail_type": "clockwork",  # gears, pipes, pistons
		"particle_type": "sparks_and_steam",
	},
	# Stage 6: The Abyss
	{
		"name": "The Abyss",
		"floor_base": Color(0.08, 0.05, 0.12),
		"floor_alt": Color(0.12, 0.07, 0.16),
		"wall_base": Color(0.05, 0.02, 0.08),
		"wall_highlight": Color(0.15, 0.08, 0.22),
		"outer_bg": Color(0.01, 0.005, 0.02),
		"mortar": Color(0.04, 0.02, 0.06),
		"puddle_color": Color(0.3, 0.1, 0.5, 0.5),
		"puddle_highlight": Color(0.5, 0.2, 0.8, 0.3),
		"torch_color": Color(0.6, 0.2, 0.9),
		"torch_glow": Color(0.6, 0.2, 0.9, 0.15),
		"moss_color": Color(0.3, 0.1, 0.4, 0.35),  # shadow tendrils
		"detail_type": "abyss",  # void rifts, dark tendrils, floating runes
		"particle_type": "void_motes",
	},
]

# ─── Helper Functions ───────────────────────────────────────

func get_stage_index(wave_num: int) -> int:
	@warning_ignore("integer_division")
	return clampi((wave_num - 1) / WAVES_PER_STAGE, 0, TOTAL_STAGES - 1)

func get_stage_wave(wave_num: int) -> int:
	if wave_num <= 0:
		return 1
	return ((wave_num - 1) % WAVES_PER_STAGE) + 1

func get_stage_name(wave_num: int) -> String:
	return STAGE_NAMES[get_stage_index(wave_num)]

func get_theme(wave_num: int) -> Dictionary:
	return THEMES[get_stage_index(wave_num)]

func is_boss_wave(wave_num: int) -> bool:
	var stage_wave = get_stage_wave(wave_num)
	return stage_wave == 7 or stage_wave == 14

func get_wave_def(wave_num: int) -> Array:
	var stage_idx = get_stage_index(wave_num)
	var stage_wave = get_stage_wave(wave_num)  # 1-14 within this stage
	var wave_data = ALL_STAGE_WAVES[stage_idx]
	var authored_count = wave_data.size()  # 14 hand-authored waves

	if stage_wave <= authored_count:
		return wave_data[stage_wave - 1]
	else:
		# Scale from the last authored wave
		var base_def = wave_data[authored_count - 1]
		return base_def  # scaling applied in wave_manager via scale_factor

func get_wave_scale_factor(wave_num: int) -> float:
	var stage_wave = get_stage_wave(wave_num)
	var authored_count = 14
	if stage_wave <= authored_count:
		return 1.0
	return 1.0 + (stage_wave - authored_count) * 0.2

func get_enemy_hp_scale(enemy_type: String, stage_idx: int) -> float:
	# Only scale enemies from earlier stages
	for s in range(stage_idx + 1):
		if enemy_type in STAGE_NATIVE_ENEMIES.get(s, []):
			if s == stage_idx:
				return 1.0  # Native to this stage, no scaling
			else:
				return STAGE_HP_SCALE[stage_idx]
	return 1.0

func get_enemy_dmg_scale(enemy_type: String, stage_idx: int) -> float:
	for s in range(stage_idx + 1):
		if enemy_type in STAGE_NATIVE_ENEMIES.get(s, []):
			if s == stage_idx:
				return 1.0
			else:
				return STAGE_DMG_SCALE[stage_idx]
	return 1.0
