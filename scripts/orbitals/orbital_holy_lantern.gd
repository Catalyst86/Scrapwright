extends OrbitalWeapon

func _ready() -> void:
	weapon_id = "holy_lantern"
	super._ready()

func _fire(_target: Node) -> void:
	var player = get_parent()
	if not player:
		return
	# Heal player — scales with max HP (2-4% based on level)
	var base_heal_pct = OrbitalDB.get_heal_amount("holy_lantern", level)
	var heal_amount = maxi(2, int(GameState.player_max_health * base_heal_pct / 100.0))
	GameState.heal(heal_amount)

	# Holy burst — expanding golden ring with light rays
	_show_holy_burst(player.global_position, attack_range)

	# Damage all enemies in range
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or enemy.get("is_dead"):
			continue
		if player.global_position.distance_to(enemy.global_position) <= attack_range:
			enemy.take_damage(weapon_damage, player.global_position)
