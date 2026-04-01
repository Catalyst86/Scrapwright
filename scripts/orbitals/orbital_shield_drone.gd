extends OrbitalWeapon

func _ready() -> void:
	weapon_id = "shield_drone"
	super._ready()

func _fire(target: Node) -> void:
	if not is_instance_valid(target):
		return
	var player = get_parent()
	if not player:
		return
	# Bump damage to nearest enemy
	target.take_damage(weapon_damage, player.global_position)

	# Hex shield flash
	_show_shield_flash(player.global_position, 18.0)
