extends EnemyBase

# Tank — slow, very durable, high damage

func _ready() -> void:
	enemy_type       = "tank"
	max_health       = 130
	move_speed       = 26.0
	damage           = 28
	xp_value         = 30
	contact_cooldown = 1.6
	knockback_resistance = 0.75  # Heavy — takes only 25% knockback
	super._ready()
