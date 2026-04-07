extends OrbitalWeapon

func _ready() -> void:
	weapon_id = "magnet_core"
	super._ready()

func _fire(_target: Node) -> void:
	var player = get_parent()
	if not player:
		return
	for enemy in _cached_enemies:
		if not is_instance_valid(enemy):
			continue
		var dist = player.global_position.distance_to(enemy.global_position)
		if dist > attack_range or dist < 5.0:
			continue
		# Pull enemy 25px toward player + crush damage
		var dir = (player.global_position - enemy.global_position).normalized()
		enemy.global_position += dir * 25.0
		if weapon_damage > 0 and enemy.has_method("take_damage"):
			enemy.take_damage(weapon_damage, player.global_position)
		# Red/blue magnetic field lines
		_show_magnet_pull(player.global_position, enemy.global_position)
