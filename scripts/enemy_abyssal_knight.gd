extends EnemyBase

# Abyssal Knight — Stage 6 heavy tank, 40% damage reduction

const DAMAGE_REDUCTION = 0.4

func _ready() -> void:
	enemy_type       = "abyssal_knight"
	max_health       = 200
	move_speed       = 32.0
	damage           = 22
	xp_value         = 40
	contact_cooldown = 1.4
	knockback_resistance = 0.75  # Heavy — takes only 25% knockback
	super._ready()

func take_damage(amount: int, from_pos: Vector2 = Vector2.ZERO) -> void:
	if is_dead: return
	# 40% damage reduction
	var reduced = maxi(1, int(amount * (1.0 - DAMAGE_REDUCTION)))
	super.take_damage(reduced, from_pos)
