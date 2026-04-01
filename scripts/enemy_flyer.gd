extends EnemyBase

# Flyer — ignores navigation mesh, goes direct

func _ready() -> void:
	enemy_type       = "flyer"
	max_health       = 18
	move_speed       = 78.0
	damage           = 8
	xp_value         = 10
	contact_cooldown = 0.8
	can_burrow_flank = false  # Flyers don't burrow
	super._ready()

# Override: direct movement, no nav agent
func _move_toward_player(delta: float) -> void:
	if not player_ref or not is_instance_valid(player_ref):
		player_ref = get_tree().get_first_node_in_group("player")
		return
	var dir = (player_ref.global_position - global_position).normalized()
	velocity = velocity.move_toward(dir * move_speed, move_speed * 12.0 * delta)
	if sprite and velocity.length() > 5.0:
		sprite.flip_h = velocity.x < 0
