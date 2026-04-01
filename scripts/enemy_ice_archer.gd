extends EnemyBase

# Ice Archer — Stage 4 ranged, fires ice projectiles, keeps distance

var shoot_timer: float = 0.0
const SHOOT_INTERVAL  = 2.0
const PREFERRED_DIST  = 100.0
var _proj_scene: PackedScene = null

func _ready() -> void:
	enemy_type       = "ice_archer"
	max_health       = 35
	move_speed       = 50.0
	damage           = 12
	xp_value         = 20
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
	var proj = proj_scene.instantiate()
	var dir  = (player_ref.global_position - global_position).normalized()
	proj.global_position = global_position + dir * 14.0
	proj.projectile_type = "ice"
	proj.setup(dir * 75.0, damage)
	var parent = get_parent()
	if parent:
		parent.add_child(proj)
