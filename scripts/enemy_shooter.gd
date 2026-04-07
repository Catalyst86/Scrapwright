extends EnemyBase

# Shooter — ranged, keeps distance

var shoot_timer: float = 0.0
const SHOOT_INTERVAL  = 2.2
var _sfx_fire: AudioStreamPlayer2D = null
const PREFERRED_DIST  = 110.0
var _proj_scene: PackedScene = null

func _ready() -> void:
	enemy_type       = "shooter"
	max_health       = 22
	move_speed       = 38.0
	damage           = 14
	xp_value         = 12
	contact_cooldown = 2.0
	_proj_scene = load("res://scenes/enemy_projectile.tscn")
	super._ready()
	var fire_path = "res://assets/audio/sfx/enemies/projectile_fire.wav"
	if ResourceLoader.exists(fire_path):
		_sfx_fire = AudioStreamPlayer2D.new()
		_sfx_fire.stream = load(fire_path)
		_sfx_fire.volume_db = -12.0
		_sfx_fire.max_distance = 400.0
		_sfx_fire.bus = "SFX"
		add_child(_sfx_fire)

func _physics_process(delta: float) -> void:
	if is_dead:
		return
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
	if not player_ref or not is_instance_valid(player_ref):
		return
	var proj_scene = _proj_scene
	if not proj_scene:
		return
	_play_attack_anim_then(_do_shoot)

func _do_shoot() -> void:
	if is_dead or not player_ref or not is_instance_valid(player_ref): return
	if _sfx_fire:
		_sfx_fire.pitch_scale = randf_range(0.9, 1.1)
		_sfx_fire.play()
	var proj_scene = _proj_scene
	if not proj_scene: return
	var proj = proj_scene.instantiate()
	proj.source_enemy = self
	var dir  = (player_ref.global_position - global_position).normalized()
	proj.global_position = global_position + dir * 14.0
	proj.projectile_type = "bone"
	proj.setup(dir * 85.0, damage)
	var parent = get_parent()
	if parent:
		parent.add_child(proj)
