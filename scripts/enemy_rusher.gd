extends EnemyBase

func _ready() -> void:
	enemy_type       = "rusher"
	max_health       = 30
	move_speed       = 65.0
	damage           = 10
	xp_value         = 8
	contact_cooldown = 1.0
	super._ready()
