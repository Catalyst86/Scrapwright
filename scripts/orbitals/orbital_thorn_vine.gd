extends OrbitalWeapon

func _ready() -> void:
	weapon_id = "thorn_vine"
	super._ready()

func _fire(target: Node) -> void:
	if not is_instance_valid(target):
		return
	var player = get_parent()
	if not player:
		return
	var direction = (target.global_position - player.global_position).normalized()
	var line_end = player.global_position + direction * 70.0

	# Thorny vine whip visual
	_show_vine_whip(player.global_position, line_end)

	# Hit all enemies within 15px of the line
	for enemy in _cached_enemies:
		if not is_instance_valid(enemy):
			continue
		var ep = enemy.global_position
		var closest = _closest_point_on_segment(player.global_position, line_end, ep)
		if closest.distance_to(ep) <= 15.0:
			enemy.take_damage(weapon_damage, player.global_position)

func _closest_point_on_segment(a: Vector2, b: Vector2, p: Vector2) -> Vector2:
	var ab = b - a
	if ab.length_squared() < 0.001:
		return a
	var t = clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return a + ab * t
