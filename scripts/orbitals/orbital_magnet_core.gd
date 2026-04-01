extends OrbitalWeapon

func _ready() -> void:
	weapon_id = "magnet_core"
	super._ready()

func _fire(_target: Node) -> void:
	var player = get_parent()
	if not player:
		return
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or enemy.get("is_dead"):
			continue
		var dist = player.global_position.distance_to(enemy.global_position)
		if dist > attack_range or dist < 5.0:
			continue
		# Pull enemy 25px toward player
		var dir = (player.global_position - enemy.global_position).normalized()
		enemy.global_position += dir * 25.0
		# Red/blue magnetic field lines
		_show_magnet_pull(player.global_position, enemy.global_position)
