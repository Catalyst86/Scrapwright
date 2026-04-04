extends Node

# ============================================================
# CraftingDB — Destructible prop material yields
# ============================================================

# Destructible material yields
var destructible_yields: Dictionary = {}

func _ready() -> void:
	_init_destructible_yields()

func _init_destructible_yields() -> void:
	# { prop_type: { material: [min, max] } }
	destructible_yields = {
		"crate": {"timber": [1, 2], "organic": [0, 1]},
		"barrel": {"iron_scrap": [0, 2]},
		"barrel_empty": {"iron_scrap": [1, 2]},
		"barrel_full": {"iron_scrap": [1, 2], "fuel": [1, 2]},
		"rubble": {"stone": [1, 3]},
		"corpse": {"organic": [1, 3]},
		"machinery": {"iron_scrap": [2, 4], "fuel": [0, 2]},
		"weapon_rack": {"iron_scrap": [1, 2], "timber": [1, 2]},
		# Junkyard props
		"car_intact": {"iron_scrap": [3, 6], "fuel": [1, 3]},
		"car_crushed": {"iron_scrap": [2, 4]},
		"scrap_pile": {"iron_scrap": [2, 5], "timber": [0, 1]},
		"wood_pile": {"timber": [3, 5]},
		"tire_stack": {"organic": [1, 2], "fuel": [0, 1]},
		"engine_block": {"iron_scrap": [4, 7]},
		"oil_drum": {"fuel": [2, 4]},
		"junk_heap": {"iron_scrap": [1, 3], "stone": [1, 2], "organic": [0, 1]},
	}

func get_material_yield(prop_type: String, tool_yield_mult: float) -> Dictionary:
	if not prop_type in destructible_yields:
		return {}
	var base = destructible_yields[prop_type]
	var result = {}
	for mat in base:
		var range_vals = base[mat]
		var raw = randi_range(range_vals[0], range_vals[1])
		var final_amount = int(ceil(raw * tool_yield_mult))
		if final_amount > 0:
			result[mat] = final_amount
	return result
