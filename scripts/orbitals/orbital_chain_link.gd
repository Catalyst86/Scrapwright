extends OrbitalWeapon

func _ready() -> void:
	weapon_id = "chain_link"
	super._ready()

func _fire(target: Node) -> void:
	if not is_instance_valid(target):
		return
	var chain_color = Color(0.5, 0.7, 1.0)
	# Hit primary target with lightning
	_show_lightning(global_position, target.global_position, chain_color, 2.5)
	target.take_damage(weapon_damage, global_position)

	# Chain to nearby enemies
	var chain_count = mini(6, OrbitalDB.get_chain_count("chain_link", level))  # Cap at 6 targets
	var hit_enemies: Array = [target]
	var last_pos = target.global_position

	var chain_dmg = weapon_damage
	for _i in range(chain_count):
		var best: Node = null
		var best_dist: float = 50.0
		for enemy in _cached_enemies:
			if not is_instance_valid(enemy):
				continue
			if enemy in hit_enemies:
				continue
			var d = last_pos.distance_to(enemy.global_position)
			if d < best_dist:
				best_dist = d
				best = enemy
		if best:
			_show_lightning(last_pos, best.global_position, chain_color, 1.5)
			best.take_damage(maxi(1, chain_dmg), last_pos)
			chain_dmg = maxi(1, int(chain_dmg * 0.7))
			hit_enemies.append(best)
			last_pos = best.global_position
		else:
			break
