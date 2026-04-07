extends OrbitalWeapon

func _ready() -> void:
	weapon_id = "blade_fan"
	super._ready()

func _fire(_target: Node) -> void:
	var player = get_parent()
	if not player:
		return
	# Compute current angle from shared time
	var total = _get_orbital_count()
	var current_angle = _get_shared_time() * ORBIT_SPEED + (TAU / maxf(total, 1)) * slot_index

	# Metallic blade arc visual
	_show_blade_arc(player.global_position, current_angle, attack_range)

	# Damage all enemies in range of player
	for enemy in _cached_enemies:
		if not is_instance_valid(enemy):
			continue
		if player.global_position.distance_to(enemy.global_position) <= attack_range:
			enemy.take_damage(weapon_damage, player.global_position)
