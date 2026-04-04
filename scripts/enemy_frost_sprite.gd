extends EnemyBase

# Frost Sprite — Stage 4 fast melee, applies slow on hit

func _ready() -> void:
	enemy_type       = "frost_sprite"
	max_health       = 25
	move_speed       = 85.0
	damage           = 8
	xp_value         = 15
	contact_cooldown = 0.8
	super._ready()

func _check_contact_damage() -> void:
	if contact_timer > 0 or not player_ref or not is_instance_valid(player_ref): return
	if global_position.distance_to(player_ref.global_position) < 18.0:
		_play_attack_anim()
		if player_ref.has_method("take_damage"):
			player_ref.take_damage(damage, self)
		# Apply slow to player (30% slow for 2 seconds)
		if player_ref.has_method("apply_slow"):
			player_ref.apply_slow(0.3, 2.0)
		contact_timer = contact_cooldown
