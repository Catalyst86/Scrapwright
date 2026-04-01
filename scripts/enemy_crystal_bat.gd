extends EnemyBase

# Crystal Bat — Stage 4 flying, ignores nav, dives at player

func _ready() -> void:
	enemy_type       = "crystal_bat"
	max_health       = 20
	move_speed       = 75.0
	damage           = 10
	xp_value         = 12
	contact_cooldown = 0.8
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
