extends OrbitalWeapon

func _ready() -> void:
	weapon_id = "frost_shard"
	super._ready()

func _fire(target: Node) -> void:
	if not is_instance_valid(target):
		return
	_show_ice_spike(global_position, target.global_position)
	target.take_damage(weapon_damage, global_position)
	if target.has_method("apply_status"):
		target.apply_status("slowed", 2.0)
