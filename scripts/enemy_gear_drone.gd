extends EnemyBase

# Gear Drone — Stage 5 fast swarm melee, very low HP

func _ready() -> void:
	enemy_type       = "gear_drone"
	max_health       = 25
	move_speed       = 90.0
	damage           = 6
	xp_value         = 8
	contact_cooldown = 0.7
	super._ready()
