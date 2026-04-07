extends EnemyBase

# Mycelium Sniper — ranged, leads shots by predicting player movement

var shoot_timer: float = 0.0
const SHOOT_INTERVAL  = 2.0
const PREFERRED_DIST  = 100.0
const PROJECTILE_SPEED = 75.0
const LEAD_TIME        = 0.3
var _proj_scene: PackedScene = null

func _ready() -> void:
	enemy_type       = "mycelium_sniper"
	max_health       = 20
	move_speed       = 30.0
	damage           = 18
	xp_value         = 16
	contact_cooldown = 2.0
	_proj_scene = load("res://scenes/enemy_projectile.tscn")
	super._ready()

func _physics_process(delta: float) -> void:
	if is_dead: return
	shoot_timer += delta
	if shoot_timer >= SHOOT_INTERVAL:
		shoot_timer = 0.0
		_try_shoot()
	super._physics_process(delta)

func _move_toward_player(delta: float) -> void:
	if not player_ref or not is_instance_valid(player_ref):
		player_ref = get_tree().get_first_node_in_group("player")
		return
	var dist = global_position.distance_to(player_ref.global_position)
	var dir  = (player_ref.global_position - global_position).normalized()
	if dist > PREFERRED_DIST + 24:
		velocity = velocity.move_toward(dir * move_speed, move_speed * 8.0 * delta)
	elif dist < PREFERRED_DIST - 24:
		velocity = velocity.move_toward(-dir * move_speed * 0.7, move_speed * 8.0 * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, move_speed * 8.0 * delta)
	_update_facing()

func _try_shoot() -> void:
	if not player_ref or not is_instance_valid(player_ref): return
	var proj_scene = _proj_scene
	if not proj_scene: return
	_play_attack_anim_then(_do_shoot)

func _do_shoot() -> void:
	if is_dead or not player_ref or not is_instance_valid(player_ref): return
	var proj_scene = _proj_scene
	if not proj_scene: return

	# Predict player position based on their current velocity
	var predicted_pos = player_ref.global_position
	if player_ref is CharacterBody2D:
		predicted_pos += player_ref.velocity * LEAD_TIME

	var dir = (predicted_pos - global_position).normalized()
	var proj = proj_scene.instantiate()
	proj.source_enemy = self
	proj.global_position = global_position + dir * 14.0
	proj.projectile_type = "spore"
	proj.setup(dir * PROJECTILE_SPEED, damage)
	var parent = get_parent()
	if parent:
		parent.add_child(proj)
