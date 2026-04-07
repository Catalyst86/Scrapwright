extends OrbitalWeapon

func _ready() -> void:
	weapon_id = "holy_lantern"
	super._ready()

func _fire(_target: Node) -> void:
	var player = get_parent()
	if not player:
		return
	# Heal player — flat HP heal (3-10 based on level)
	var base_heal = OrbitalDB.get_heal_amount("holy_lantern", level)
	var heal_amount = maxi(1, int(base_heal))
	GameState.heal(heal_amount)

	# Holy burst — expanding golden ring with light rays
	_show_holy_burst(player.global_position, attack_range)

	# Damage all enemies in range
	for enemy in _cached_enemies:
		if not is_instance_valid(enemy):
			continue
		if player.global_position.distance_to(enemy.global_position) <= attack_range:
			enemy.take_damage(weapon_damage, player.global_position)
