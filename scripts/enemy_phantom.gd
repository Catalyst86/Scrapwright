extends EnemyBase

# Phantom — Stage 6 invisible until within 50px of player, then appears and strikes

const REVEAL_RANGE = 50.0
const INVISIBLE_ALPHA = 0.1
var is_revealed: bool = false

func _ready() -> void:
	enemy_type       = "phantom"
	max_health       = 30
	move_speed       = 55.0
	damage           = 15
	xp_value         = 18
	contact_cooldown = 1.0
	super._ready()
	# Start invisible
	modulate.a = INVISIBLE_ALPHA

func _physics_process(delta: float) -> void:
	if is_dead: return

	# Check proximity to player for reveal/hide
	if player_ref and is_instance_valid(player_ref):
		var dist = global_position.distance_to(player_ref.global_position)
		if dist < REVEAL_RANGE and not is_revealed:
			is_revealed = true
			var tw = create_tween()
			tw.tween_property(self, "modulate:a", 1.0, 0.15)
		elif dist >= REVEAL_RANGE * 1.5 and is_revealed:
			is_revealed = false
			var tw = create_tween()
			tw.tween_property(self, "modulate:a", INVISIBLE_ALPHA, 0.3)

	super._physics_process(delta)
