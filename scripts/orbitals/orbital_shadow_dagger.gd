extends OrbitalWeapon

func _ready() -> void:
	weapon_id = "shadow_dagger"
	super._ready()

func _fire(target: Node) -> void:
	if not is_instance_valid(target):
		return
	var target_pos = target.global_position

	# Disappear
	visible = false

	# Dark slash X + purple wisps at target
	_show_shadow_strike(target_pos)
	target.take_damage(weapon_damage, target_pos)

	# Reappear after short delay via tween
	var tw = create_tween()
	tw.tween_interval(0.2)
	tw.tween_callback(_reappear)

func _reappear() -> void:
	if not is_instance_valid(self): return
	visible = true
	_show_impact(global_position, Color(0.5, 0.2, 0.6), 6.0)
