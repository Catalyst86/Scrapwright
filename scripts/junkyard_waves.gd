extends RefCounted
class_name JunkyardWaves

# ============================================================
# JunkyardWaves - Procedural endless wave generator
# ============================================================

# Enemy pools by unlock tier
const TIER_1 = ["rusher", "shooter", "flyer"]
const TIER_2 = ["rusher", "shooter", "flyer", "tank", "exploder"]
const TIER_3 = ["rusher", "shooter", "tank", "exploder", "spore_walker", "mycelium_sniper", "fungal_brute"]
const TIER_4 = ["shooter", "tank", "exploder", "spore_walker", "fungal_brute", "magma_imp", "lava_lobber", "obsidian_golem"]
const TIER_5 = ["tank", "exploder", "fungal_brute", "magma_imp", "obsidian_golem", "frost_sprite", "ice_archer", "glacial_hulk", "crystal_bat"]
const TIER_6 = ["magma_imp", "obsidian_golem", "frost_sprite", "glacial_hulk", "crystal_bat", "gear_drone", "brass_enforcer", "spark_bug"]
const TIER_7 = ["obsidian_golem", "glacial_hulk", "gear_drone", "brass_enforcer", "spark_bug", "shadow_crawler", "void_weaver", "abyssal_knight", "phantom"]

const BOSS_CYCLE = [
	"scrap_sentinel", "junkyard_mech", "spore_mother", "fungal_titan",
	"ember_drake", "molten_wyrm", "frost_warden", "crystal_colossus",
	"piston_crusher", "the_architect", "the_devourer", "scrap_king",
]

static func get_wave(wave_num: int) -> Dictionary:
	var is_boss = wave_num > 0 and wave_num % 10 == 0

	# Pick enemy pool based on wave
	var pool: Array
	if wave_num <= 5:
		pool = TIER_1
	elif wave_num <= 14:
		pool = TIER_2
	elif wave_num <= 24:
		pool = TIER_3
	elif wave_num <= 34:
		pool = TIER_4
	elif wave_num <= 44:
		pool = TIER_5
	elif wave_num <= 54:
		pool = TIER_6
	else:
		pool = TIER_7

	# Enemy count scales with wave
	var base_count = 6
	var count = int(ceil(base_count * (1.0 + wave_num * 0.08)))
	count = mini(count, 60)  # cap at 60 enemies per wave

	# Build spawn queue
	var enemies: Array = []
	for i in count:
		enemies.append(pool[randi() % pool.size()])

	# Boss waves add a boss on top
	if is_boss:
		var boss_idx = ((wave_num / 10) - 1) % BOSS_CYCLE.size()
		enemies.append(BOSS_CYCLE[boss_idx])

	# Scaling
	var hp_scale = 1.0 + wave_num * 0.05
	var dmg_scale = 1.0 + wave_num * 0.03
	var interval = maxf(0.3, 0.8 - wave_num * 0.008)

	return {
		"enemies": enemies,
		"hp_scale": hp_scale,
		"dmg_scale": dmg_scale,
		"spawn_interval": interval,
		"is_boss": is_boss,
	}
