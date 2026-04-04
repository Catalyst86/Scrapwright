extends EnemyBase

# Spark Bug — Stage 5 flying, chains lightning to nearby allies (3 dmg/s within 40px)

var chain_timer: float = 0.0
const CHAIN_INTERVAL = 1.0
const CHAIN_RANGE = 40.0
const CHAIN_DAMAGE = 3

func _ready() -> void:
	enemy_type       = "spark_bug"
	max_health       = 18
	move_speed       = 70.0
	damage           = 5
	xp_value         = 10
	contact_cooldown = 0.9
	super._ready()

# Override: direct movement, no nav agent (flying)
func _move_toward_player(delta: float) -> void:
	if not player_ref or not is_instance_valid(player_ref):
		player_ref = get_tree().get_first_node_in_group("player")
		return
	var dir = (player_ref.global_position - global_position).normalized()
	velocity = velocity.move_toward(dir * move_speed, move_speed * 12.0 * delta)
	if sprite and velocity.length() > 5.0:
		sprite.flip_h = velocity.x < 0

func _physics_process(delta: float) -> void:
	if is_dead: return
	chain_timer += delta
	if chain_timer >= CHAIN_INTERVAL:
		chain_timer = 0.0
		_chain_lightning()
	super._physics_process(delta)

func _chain_lightning() -> void:
	if not player_ref or not is_instance_valid(player_ref): return
	# Check if player is within chain range
	var dist = global_position.distance_to(player_ref.global_position)
	if dist > CHAIN_RANGE: return
	_play_attack_anim()

	# Deal chain damage to player
	if player_ref.has_method("take_damage"):
		player_ref.take_damage(CHAIN_DAMAGE, self)

	# Visual — lightning line to player
	var line = Line2D.new()
	line.width = 1.5
	line.default_color = Color(0.6, 0.8, 1.0, 0.8)
	line.z_index = 5
	# Jagged lightning effect
	var start = global_position
	var end = player_ref.global_position
	line.add_point(start)
	var mid = (start + end) * 0.5 + Vector2(randf_range(-6, 6), randf_range(-6, 6))
	line.add_point(mid)
	line.add_point(end)
	var parent = get_parent()
	if parent:
		parent.add_child(line)
		var tw = line.create_tween()
		tw.tween_property(line, "modulate:a", 0.0, 0.2)
		tw.tween_callback(line.queue_free)
