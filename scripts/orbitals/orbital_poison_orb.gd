extends OrbitalWeapon

func _ready() -> void:
	weapon_id = "poison_orb"
	super._ready()

func _fire(target: Node) -> void:
	if not is_instance_valid(target):
		return
	_show_poison_cloud(target.global_position, 14.0)
	target.take_damage(weapon_damage, global_position)
	if target.has_method("apply_status"):
		target.apply_status("poisoned", 3.0)
