extends OrbitalWeapon

func _ready() -> void:
	weapon_id = "spark_coil"
	super._ready()

func _fire(target: Node) -> void:
	if not is_instance_valid(target):
		return
	_show_lightning(global_position, target.global_position, Color(0.9, 0.8, 0.2), 2.5)
	target.take_damage(weapon_damage, global_position)
