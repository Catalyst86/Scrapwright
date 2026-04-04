extends EnemyBase

# Crystal Colossus — Stage 4 Final Boss
# Ground slam creates expanding ice ring, spawns ice shards in burst pattern every 6s

var ground_slam_timer: float = 0.0
var ice_shard_timer: float = 0.0

const GROUND_SLAM_INTERVAL = 5.0
const GROUND_SLAM_RANGE = 70.0
const GROUND_SLAM_DAMAGE = 20

const ICE_SHARD_INTERVAL = 6.0
const ICE_SHARD_COUNT = 8
const ICE_SHARD_SPEED = 90.0
const ICE_SHARD_DAMAGE = 12
var _proj_scene: PackedScene = null

func _ready() -> void:
	enemy_type       = "crystal_colossus"
	max_health       = 1800
	move_speed       = 22.0
	damage           = 30
	xp_value         = 300
	contact_cooldown = 1.5
	_proj_scene = load("res://scenes/enemy_projectile.tscn")
	super._ready()
	if health_bar:
		health_bar.visible = true

func _physics_process(delta: float) -> void:
	if is_dead: return
	ground_slam_timer += delta
	ice_shard_timer += delta

	if ground_slam_timer >= GROUND_SLAM_INTERVAL:
		ground_slam_timer = 0.0
		_ground_slam()

	if ice_shard_timer >= ICE_SHARD_INTERVAL:
		ice_shard_timer = 0.0
		_ice_shard_burst()

	super._physics_process(delta)

func _ground_slam() -> void:
	if not player_ref or not is_instance_valid(player_ref): return

	# Visual flash
	if sprite:
		sprite.modulate = Color(0.5, 0.8, 2.0)
		var tw = create_tween()
		tw.tween_property(sprite, "modulate", Color.WHITE, 0.3)

	# Expanding ice ring visual
	var ring = ColorRect.new()
	ring.size = Vector2(4, 4)
	ring.position = global_position - Vector2(2, 2)
	ring.color = Color(0.3, 0.6, 1.0, 0.5)
	ring.z_index = -1
	var parent = get_parent()
	if parent:
		parent.add_child(ring)
		var tw2 = ring.create_tween()
		tw2.set_parallel(true)
		tw2.tween_property(ring, "size", Vector2(GROUND_SLAM_RANGE * 2, GROUND_SLAM_RANGE * 2), 0.5)
		tw2.tween_property(ring, "position", global_position - Vector2(GROUND_SLAM_RANGE, GROUND_SLAM_RANGE), 0.5)
		tw2.tween_property(ring, "modulate:a", 0.0, 0.5)
		tw2.set_parallel(false)
		tw2.tween_callback(ring.queue_free)

	# Damage player if in range
	var dist = global_position.distance_to(player_ref.global_position)
	if dist < GROUND_SLAM_RANGE:
		if player_ref.has_method("take_damage"):
			player_ref.take_damage(GROUND_SLAM_DAMAGE, self)

func _ice_shard_burst() -> void:
	_play_attack_anim_then(_do_shard_burst)

func _do_shard_burst() -> void:
	if is_dead: return
	var proj_scene = _proj_scene
	if not proj_scene: return
	var parent = get_parent()
	if not parent: return
	for i in ICE_SHARD_COUNT:
		var angle = TAU * i / ICE_SHARD_COUNT
		var dir = Vector2(cos(angle), sin(angle))
		var proj = proj_scene.instantiate()
		proj.global_position = global_position + dir * 12.0
		proj.projectile_type = "ice"
		proj.setup(dir * ICE_SHARD_SPEED, ICE_SHARD_DAMAGE)
		parent.add_child(proj)
