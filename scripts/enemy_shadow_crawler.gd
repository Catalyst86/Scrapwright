extends EnemyBase

# Shadow Crawler — Stage 6 teleports behind player every 4s, backstab deals 2x damage

var teleport_timer: float = 0.0
var backstab_ready: bool = false

const TELEPORT_INTERVAL = 4.0
const BACKSTAB_MULTIPLIER = 2

func _ready() -> void:
	enemy_type       = "shadow_crawler"
	max_health       = 40
	move_speed       = 60.0
	damage           = 12
	xp_value         = 20
	contact_cooldown = 1.0
	super._ready()

func _physics_process(delta: float) -> void:
	if is_dead: return
	teleport_timer += delta
	if teleport_timer >= TELEPORT_INTERVAL:
		teleport_timer = 0.0
		_teleport_behind_player()
	super._physics_process(delta)

func _teleport_behind_player() -> void:
	if not player_ref or not is_instance_valid(player_ref): return
	_play_attack_anim()

	# Calculate position behind the player (opposite of player's facing)
	var offset = (global_position - player_ref.global_position).normalized() * -25.0
	var target_pos = player_ref.global_position + offset

	# Vanish visual
	if sprite:
		var tw = create_tween()
		tw.tween_property(sprite, "modulate:a", 0.0, 0.1)
		tw.tween_callback(func(): global_position = target_pos; backstab_ready = true)
		tw.tween_property(sprite, "modulate:a", 1.0, 0.1)

func _check_contact_damage() -> void:
	if contact_timer > 0 or not player_ref or not is_instance_valid(player_ref): return
	if global_position.distance_to(player_ref.global_position) < 18.0:
		var actual_damage = damage
		if backstab_ready:
			actual_damage = damage * BACKSTAB_MULTIPLIER
			backstab_ready = false
		if player_ref.has_method("take_damage"):
			player_ref.take_damage(actual_damage)
		contact_timer = contact_cooldown
