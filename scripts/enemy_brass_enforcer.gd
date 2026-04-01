extends EnemyBase

# Brass Enforcer — Stage 5 medium tank with frontal shield (50% damage reduction from front)

func _ready() -> void:
	enemy_type       = "brass_enforcer"
	max_health       = 120
	move_speed       = 40.0
	damage           = 15
	xp_value         = 30
	contact_cooldown = 1.2
	super._ready()

func take_damage(amount: int, from_pos: Vector2 = Vector2.ZERO) -> void:
	if is_dead: return
	# Frontal shield: if damage comes from in front, reduce by 50%
	if from_pos != Vector2.ZERO and player_ref and is_instance_valid(player_ref):
		var facing_dir = Vector2.ZERO
		if nav_agent and player_ref:
			facing_dir = (player_ref.global_position - global_position).normalized()
		var hit_dir = (from_pos - global_position).normalized()
		var dot = facing_dir.dot(hit_dir)
		if dot > 0.0:
			# Hit from the front — shield absorbs half
			amount = maxi(1, amount / 2)
			if sprite:
				sprite.modulate = Color(1.0, 0.9, 0.5)
				var tw = create_tween()
				tw.tween_property(sprite, "modulate", Color.WHITE, 0.1)
	super.take_damage(amount, from_pos)
