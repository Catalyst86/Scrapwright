extends EnemyBase

# The Devourer — Stage 6 Boss
# Pulls player toward it, AoE darkness zone, spawns shadow crawlers

var pull_timer: float = 0.0
var darkness_timer: float = 0.0
var spawn_timer: float = 0.0

const PULL_INTERVAL = 3.0
const PULL_RANGE = 100.0
const PULL_STRENGTH = 60.0
const PULL_DURATION = 1.5

const DARKNESS_INTERVAL = 5.0
const DARKNESS_RADIUS = 50.0
const DARKNESS_DAMAGE = 8

const SPAWN_INTERVAL = 9.0
const SPAWN_COUNT = 2

var _pulling: bool = false
var _pull_time_left: float = 0.0

func _ready() -> void:
	enemy_type       = "the_devourer"
	max_health       = 800
	move_speed       = 28.0
	damage           = 25
	xp_value         = 300
	contact_cooldown = 1.2
	super._ready()
	if health_bar:
		health_bar.visible = true

func _physics_process(delta: float) -> void:
	if is_dead: return

	pull_timer += delta
	darkness_timer += delta
	spawn_timer += delta

	# Pull player toward self
	if pull_timer >= PULL_INTERVAL and not _pulling:
		pull_timer = 0.0
		_pulling = true
		_pull_time_left = PULL_DURATION

	if _pulling:
		_pull_time_left -= delta
		if _pull_time_left <= 0:
			_pulling = false
		elif player_ref and is_instance_valid(player_ref):
			var dist = global_position.distance_to(player_ref.global_position)
			if dist < PULL_RANGE and dist > 20.0:
				var pull_dir = (global_position - player_ref.global_position).normalized()
				if player_ref.has_method("apply_external_force"):
					player_ref.apply_external_force(pull_dir * PULL_STRENGTH)
				elif "velocity" in player_ref:
					player_ref.velocity += pull_dir * PULL_STRENGTH * delta

				# Visual — pull lines
				if randf() < 0.3:
					var line = Line2D.new()
					line.width = 1.0
					line.default_color = Color(0.3, 0.0, 0.4, 0.5)
					line.z_index = 5
					line.add_point(global_position)
					line.add_point(player_ref.global_position)
					var parent = get_parent()
					if parent:
						parent.add_child(line)
						var tw = line.create_tween()
						tw.tween_property(line, "modulate:a", 0.0, 0.2)
						tw.tween_callback(line.queue_free)

	if darkness_timer >= DARKNESS_INTERVAL:
		darkness_timer = 0.0
		_darkness_aoe()

	if spawn_timer >= SPAWN_INTERVAL:
		spawn_timer = 0.0
		_spawn_crawlers()

	super._physics_process(delta)

func _darkness_aoe() -> void:
	_play_attack_anim()
	# Visual — dark expanding circle
	var ring = ColorRect.new()
	ring.size = Vector2(4, 4)
	ring.position = global_position - Vector2(2, 2)
	ring.color = Color(0.15, 0.0, 0.2, 0.6)
	ring.z_index = -1
	var parent = get_parent()
	if parent:
		parent.add_child(ring)
		var tw = ring.create_tween()
		tw.set_parallel(true)
		tw.tween_property(ring, "size", Vector2(DARKNESS_RADIUS * 2, DARKNESS_RADIUS * 2), 0.4)
		tw.tween_property(ring, "position", global_position - Vector2(DARKNESS_RADIUS, DARKNESS_RADIUS), 0.4)
		tw.tween_property(ring, "modulate:a", 0.0, 0.5)
		tw.set_parallel(false)
		tw.tween_callback(ring.queue_free)

	# Damage player if in range
	if player_ref and is_instance_valid(player_ref):
		if global_position.distance_to(player_ref.global_position) < DARKNESS_RADIUS:
			if player_ref.has_method("take_damage"):
				player_ref.take_damage(DARKNESS_DAMAGE)

func _spawn_crawlers() -> void:
	var crawler_scene = load("res://scenes/enemies/enemy_shadow_crawler.tscn")
	if not crawler_scene: return
	var parent = get_parent()
	if not parent: return
	for i in SPAWN_COUNT:
		var minion = crawler_scene.instantiate()
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
