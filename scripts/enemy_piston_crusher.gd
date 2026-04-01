extends EnemyBase

# Piston Crusher — Stage 5 Boss
# Charges across arena, ground pound stuns nearby, spawns gear drones

var charge_timer: float = 0.0
var ground_pound_timer: float = 0.0
var spawn_timer: float = 0.0
var _is_charging: bool = false
var _charge_dir: Vector2 = Vector2.ZERO
var _charge_time: float = 0.0
var _charge_hit_player: bool = false

const CHARGE_INTERVAL = 5.0
const CHARGE_SPEED = 160.0
const CHARGE_DURATION = 0.9
const CHARGE_DAMAGE = 25

const GROUND_POUND_INTERVAL = 4.0
const GROUND_POUND_RANGE = 55.0
const GROUND_POUND_DAMAGE = 18
const STUN_DURATION = 1.5

const SPAWN_INTERVAL = 8.0
const SPAWN_COUNT = 3

func _ready() -> void:
	enemy_type       = "piston_crusher"
	max_health       = 700
	move_speed       = 35.0
	damage           = 25
	xp_value         = 250
	contact_cooldown = 1.5
	super._ready()
	if health_bar:
		health_bar.visible = true

func _physics_process(delta: float) -> void:
	if is_dead: return

	if _is_charging:
		_charge_time -= delta
		velocity = _charge_dir * CHARGE_SPEED
		if _charge_time <= 0:
			_is_charging = false
			velocity = Vector2.ZERO
		if not _charge_hit_player and player_ref and is_instance_valid(player_ref):
			var dist = global_position.distance_to(player_ref.global_position)
			if dist < 20.0 and player_ref.has_method("take_damage"):
				player_ref.take_damage(CHARGE_DAMAGE)
				_charge_hit_player = true
		move_and_slide()
		_animate_sprite(delta)
		return

	charge_timer += delta
	ground_pound_timer += delta
	spawn_timer += delta

	if charge_timer >= CHARGE_INTERVAL:
		charge_timer = 0.0
		_start_charge()

	if ground_pound_timer >= GROUND_POUND_INTERVAL:
		ground_pound_timer = 0.0
		_ground_pound()

	if spawn_timer >= SPAWN_INTERVAL:
		spawn_timer = 0.0
		_spawn_drones()

	super._physics_process(delta)

func _start_charge() -> void:
	if not player_ref or not is_instance_valid(player_ref): return
	_play_attack_anim()
	_is_charging = true
	_charge_hit_player = false
	_charge_dir = (player_ref.global_position - global_position).normalized()
	_charge_time = CHARGE_DURATION

	# Warning flash
	if sprite:
		var tw = create_tween()
		tw.tween_property(sprite, "modulate", Color(1.5, 1.0, 0.3), 0.1)
		tw.tween_property(sprite, "modulate", Color.WHITE, 0.2)

func _ground_pound() -> void:
	if not player_ref or not is_instance_valid(player_ref): return
	_play_attack_anim()

	# Visual
	if sprite:
		sprite.modulate = Color(2.0, 2.0, 2.0)
		var tw = create_tween()
		tw.tween_property(sprite, "modulate", Color.WHITE, 0.3)

	# Shockwave visual
	var ring = ColorRect.new()
	ring.size = Vector2(4, 4)
	ring.position = global_position - Vector2(2, 2)
	ring.color = Color(0.8, 0.6, 0.3, 0.6)
	ring.z_index = -1
	var parent = get_parent()
	if parent:
		parent.add_child(ring)
		var tw2 = ring.create_tween()
		tw2.set_parallel(true)
		tw2.tween_property(ring, "size", Vector2(GROUND_POUND_RANGE * 2, GROUND_POUND_RANGE * 2), 0.4)
		tw2.tween_property(ring, "position", global_position - Vector2(GROUND_POUND_RANGE, GROUND_POUND_RANGE), 0.4)
		tw2.tween_property(ring, "modulate:a", 0.0, 0.4)
		tw2.set_parallel(false)
		tw2.tween_callback(ring.queue_free)

	# Damage and stun player
	var dist = global_position.distance_to(player_ref.global_position)
	if dist < GROUND_POUND_RANGE:
		if player_ref.has_method("take_damage"):
			player_ref.take_damage(GROUND_POUND_DAMAGE)
		if player_ref.has_method("stun"):
			player_ref.stun(STUN_DURATION)

	# Stun nearby enemies too
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if enemy == self or not is_instance_valid(enemy) or enemy.is_dead: continue
		var e_dist = global_position.distance_to(enemy.global_position)
		if e_dist < GROUND_POUND_RANGE * 1.5:
			enemy.stun(STUN_DURATION * 0.5)

func _spawn_drones() -> void:
	var drone_scene = load("res://scenes/enemies/enemy_gear_drone.tscn")
	if not drone_scene: return
	var parent = get_parent()
	if not parent: return
	for i in SPAWN_COUNT:
		var minion = drone_scene.instantiate()
		var offset = Vector2(randf_range(-25, 25), randf_range(-25, 25))
		minion.global_position = global_position + offset
		minion.died.connect(func(_xp: int = 0):
			if not WaveManager.wave_active: return
			WaveManager.enemies_alive = maxi(0, WaveManager.enemies_alive - 1)
			WaveManager.emit_signal("enemies_remaining_changed", WaveManager.get_wave_enemy_count())
		)
		parent.add_child(minion)
		WaveManager.enemies_alive += 1
		WaveManager.emit_signal("enemies_remaining_changed", WaveManager.get_wave_enemy_count())
