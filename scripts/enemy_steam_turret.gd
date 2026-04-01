extends EnemyBase

# Steam Turret — Stage 5 stationary, fires steam blasts in rotating pattern

var shoot_timer: float = 0.0
var rotation_angle: float = 0.0

const SHOOT_INTERVAL = 2.0
const PROJECTILE_COUNT = 3
const PROJECTILE_SPEED = 70.0
const ROTATION_PER_SHOT = 0.4  # radians rotation between volleys
var _proj_scene: PackedScene = null

func _ready() -> void:
	enemy_type       = "steam_turret"
	max_health       = 80
	move_speed       = 0.0
	damage           = 15
	xp_value         = 25
	contact_cooldown = 99.0
	_proj_scene = load("res://scenes/enemy_projectile.tscn")
	super._ready()

func _physics_process(delta: float) -> void:
	if is_dead: return
	shoot_timer += delta
	if shoot_timer >= SHOOT_INTERVAL:
		shoot_timer = 0.0
		_fire_steam_blast()
	super._physics_process(delta)

func _move_toward_player(_delta: float) -> void:
	# Stationary — do not move
	velocity = Vector2.ZERO

func _fire_steam_blast() -> void:
	_play_attack_anim_then(_do_fire_steam)

func _do_fire_steam() -> void:
	var proj_scene = _proj_scene
	if not proj_scene: return
	for i in PROJECTILE_COUNT:
		var angle = rotation_angle + (TAU * i / PROJECTILE_COUNT)
		var dir = Vector2(cos(angle), sin(angle))
		var proj = proj_scene.instantiate()
		proj.global_position = global_position + dir * 10.0
		proj.projectile_type = "steam"
		proj.setup(dir * PROJECTILE_SPEED, damage)
		var parent = get_parent()
		if parent:
			parent.add_child(proj)
	rotation_angle += ROTATION_PER_SHOT
