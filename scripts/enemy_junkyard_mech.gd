extends EnemyBase

# Junkyard Mech — Stage 1 Boss
# Slow, tanky. Ground pound every 4s, spawns rusher minions every 8s.

var ground_pound_timer: float = 0.0
var minion_spawn_timer: float = 0.0

const GROUND_POUND_INTERVAL = 4.0
const GROUND_POUND_RANGE = 60.0
const GROUND_POUND_DAMAGE = 15
const SHOCKWAVE_PUSH = 200.0

const MINION_SPAWN_INTERVAL = 8.0
const MINION_COUNT = 2

func _ready() -> void:
	enemy_type       = "junkyard_mech"
	max_health       = 500
	move_speed       = 30.0
	damage           = 25
	xp_value         = 100
	contact_cooldown = 1.5
	super._ready()
	if health_bar:
		health_bar.visible = true

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	ground_pound_timer += delta
	minion_spawn_timer += delta

	if ground_pound_timer >= GROUND_POUND_INTERVAL:
		ground_pound_timer = 0.0
		_ground_pound()

	if minion_spawn_timer >= MINION_SPAWN_INTERVAL:
		minion_spawn_timer = 0.0
		_spawn_minions()

	super._physics_process(delta)

func _ground_pound() -> void:
	if not player_ref or not is_instance_valid(player_ref):
		return
	_play_attack_anim()
	# Visual feedback — flash white
	if sprite:
		sprite.modulate = Color(2.0, 2.0, 2.0)
		var tw = create_tween()
		tw.tween_property(sprite, "modulate", Color.WHITE, 0.3)
	if _dot:
		_dot.modulate = Color(2.0, 2.0, 2.0)
		var tw2 = create_tween()
		tw2.tween_property(_dot, "modulate", Color.WHITE, 0.3)

	# Damage player if in range
	var dist = global_position.distance_to(player_ref.global_position)
	if dist < GROUND_POUND_RANGE:
		if player_ref.has_method("take_damage"):
			player_ref.take_damage(GROUND_POUND_DAMAGE)

	# Shockwave: push nearby enemies away
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if enemy == self:
			continue
		if not is_instance_valid(enemy) or enemy.is_dead:
			continue
		var e_dist = global_position.distance_to(enemy.global_position)
		if e_dist < GROUND_POUND_RANGE * 1.5 and e_dist > 0:
			var push_dir = (enemy.global_position - global_position).normalized()
			enemy.knockback = push_dir * SHOCKWAVE_PUSH

	# Spawn shockwave ring visual
	_spawn_shockwave_visual()

func _spawn_shockwave_visual() -> void:
	# Expanding circle effect
	var ring = ColorRect.new()
	ring.size = Vector2(4, 4)
	ring.position = global_position - Vector2(2, 2)
	ring.color = Color(0.7, 0.7, 0.8, 0.6)
	ring.z_index = -1
	var parent = get_parent()
	if parent:
		parent.add_child(ring)
	var tw = ring.create_tween()
	tw.set_parallel(true)
	tw.tween_property(ring, "size", Vector2(GROUND_POUND_RANGE * 2, GROUND_POUND_RANGE * 2), 0.4)
	tw.tween_property(ring, "position", global_position - Vector2(GROUND_POUND_RANGE, GROUND_POUND_RANGE), 0.4)
	tw.tween_property(ring, "modulate:a", 0.0, 0.4)
	tw.set_parallel(false)
	tw.tween_callback(ring.queue_free)

func _spawn_minions() -> void:
	var rusher_scene = load("res://scenes/enemies/enemy_rusher.tscn")
	if not rusher_scene:
		return
	var parent = get_parent()
	if not parent:
		return
	for i in MINION_COUNT:
		var minion = rusher_scene.instantiate()
		var offset = Vector2(randf_range(-20, 20), randf_range(-20, 20))
		minion.global_position = global_position + offset
		minion.died.connect(func(_xp: int = 0):
			if not WaveManager.wave_active: return
			WaveManager.enemies_alive = maxi(0, WaveManager.enemies_alive - 1)
			WaveManager.emit_signal("enemies_remaining_changed", WaveManager.get_wave_enemy_count())
		)
		parent.add_child(minion)
		WaveManager.enemies_alive += 1
		WaveManager.emit_signal("enemies_remaining_changed", WaveManager.get_wave_enemy_count())
