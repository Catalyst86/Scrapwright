extends EnemyBase

# Junkyard Mech — Stage 1 Boss
# Phase 1: Ground pound every 4s, spawns 2 rusher minions every 8s.
# Phase 2 "WHIRLWIND": Teleports to center, spawns 4 scrap pile cover at 140px,
#   fires saw blade whirlwind (4 blades rotating 17deg/tick, every 0.3s) for 6s.
# Phase 3 "OVERDRIVE": Ground pound range +50% (90px), spawns 3 rushers,
#   ground pound also fires 4 saw blades outward. Whirlwind repeats every 20s.

var ground_pound_timer: float = 0.0
var minion_spawn_timer: float = 0.0

# Whirlwind state (Phase 2+)
var _whirlwind_active: bool = false
var _whirlwind_elapsed: float = 0.0
var _whirlwind_cooldown_timer: float = 0.0
var _cover_nodes: Array = []

const GROUND_POUND_INTERVAL = 4.0
var _ground_pound_range: float = 60.0
const GROUND_POUND_DAMAGE = 15
const SHOCKWAVE_PUSH = 200.0

const MINION_SPAWN_INTERVAL = 8.0
var _minion_count: int = 2

const WHIRLWIND_DURATION = 6.0
const WHIRLWIND_COOLDOWN = 20.0
const WHIRLWIND_FIRE_INTERVAL = 0.3

var _proj_scene: PackedScene = null

func _ready() -> void:
	enemy_type       = "junkyard_mech"
	max_health       = 1000
	move_speed       = 30.0
	damage           = 25
	xp_value         = 100
	contact_cooldown = 1.5
	_proj_scene = load("res://scenes/enemy_projectile.tscn")
	super._ready()
	if health_bar:
		health_bar.visible = true

func _physics_process(delta: float) -> void:
	if is_dead or _phase_transitioning: return

	# Whirlwind mechanic (Phase 2+)
	if _whirlwind_active:
		_process_whirlwind(delta)
		return  # Don't do normal attacks during whirlwind

	ground_pound_timer += delta
	minion_spawn_timer += delta

	if ground_pound_timer >= GROUND_POUND_INTERVAL:
		ground_pound_timer = 0.0
		_ground_pound()

	if minion_spawn_timer >= MINION_SPAWN_INTERVAL:
		minion_spawn_timer = 0.0
		_spawn_minions()

	# Whirlwind cooldown (Phase 2+)
	if _boss_phase >= 2:
		_whirlwind_cooldown_timer += delta
		if _whirlwind_cooldown_timer >= WHIRLWIND_COOLDOWN:
			_whirlwind_cooldown_timer = 0.0
			_start_whirlwind()

	super._physics_process(delta)

# --- Phase Transitions ---

func _on_phase_change(new_phase: int) -> void:
	super._on_phase_change(new_phase)
	match new_phase:
		2:
			_show_boss_warning("TAKE COVER!")
			# Immediately trigger first whirlwind
			_start_whirlwind()
		3:
			_show_boss_warning("OVERDRIVE!")
			# Increase ground pound range by 50%
			_ground_pound_range = 90.0
			# Spawn 3 minions instead of 2
			_minion_count = 3

# --- Ground Pound ---

func _ground_pound() -> void:
	if not player_ref or not is_instance_valid(player_ref): return
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
	if dist < _ground_pound_range:
		if player_ref.has_method("take_damage"):
			player_ref.take_damage(GROUND_POUND_DAMAGE, self)

	# Shockwave: push nearby enemies away
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if enemy == self: continue
		if not is_instance_valid(enemy) or enemy.is_dead: continue
		var e_dist = global_position.distance_to(enemy.global_position)
		if e_dist < _ground_pound_range * 1.5 and e_dist > 0:
			var push_dir = (enemy.global_position - global_position).normalized()
			enemy.knockback = push_dir * SHOCKWAVE_PUSH

	# Spawn shockwave ring visual
	_spawn_shockwave_visual()

	# Phase 3: Ground pound also fires 4 saw blades outward
	if _boss_phase >= 3:
		_fire_ground_pound_saws()

func _fire_ground_pound_saws() -> void:
	if not _proj_scene: return
	var parent = get_parent()
	if not parent: return
	for i in 4:
		var angle = TAU * i / 4.0
		var dir = Vector2.from_angle(angle)
		var proj = _proj_scene.instantiate()
		proj.projectile_type = "saw"
		parent.add_child(proj)
		proj.global_position = global_position + dir * 15.0
		proj.setup(dir * 100.0, 12)

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
	tw.tween_property(ring, "size", Vector2(_ground_pound_range * 2, _ground_pound_range * 2), 0.4)
	tw.tween_property(ring, "position", global_position - Vector2(_ground_pound_range, _ground_pound_range), 0.4)
	tw.tween_property(ring, "modulate:a", 0.0, 0.4)
	tw.set_parallel(false)
	tw.tween_callback(ring.queue_free)

# --- Minion Spawning ---

func _spawn_minions() -> void:
	var rusher_scene = load("res://scenes/enemies/enemy_rusher.tscn")
	if not rusher_scene: return
	var parent = get_parent()
	if not parent: return
	for i in _minion_count:
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

# --- Whirlwind (Phase 2+) ---

func _start_whirlwind() -> void:
	if _whirlwind_active or is_dead: return
	_whirlwind_active = true
	_whirlwind_elapsed = 0.0

	_show_boss_warning("TAKE COVER!")

	# Spawn 4 scrap pile cover objects at 140px from center
	_cover_nodes.clear()
	var arena_center = _get_arena_center()
	var cover_angles = [0.0, TAU * 0.25, TAU * 0.5, TAU * 0.75]
	for angle in cover_angles:
		var pos = arena_center + Vector2(cos(angle), sin(angle)) * 140.0
		var obs = _spawn_cover_obstacle(pos, "scrap_pile", 15, 2.5)
		if obs:
			_cover_nodes.append(obs)

	# Teleport to center
	var tw = create_tween()
	tw.tween_property(self, "global_position", arena_center, 0.5).set_ease(Tween.EASE_IN_OUT)

func _process_whirlwind(delta: float) -> void:
	_whirlwind_elapsed += delta

	# Fire spiral saw blades every 0.3 seconds
	var fire_count = int(_whirlwind_elapsed / WHIRLWIND_FIRE_INTERVAL)
	var prev_count = int((_whirlwind_elapsed - delta) / WHIRLWIND_FIRE_INTERVAL)

	if fire_count > prev_count:
		_fire_whirlwind_projectiles(fire_count)

	# End whirlwind after duration
	if _whirlwind_elapsed >= WHIRLWIND_DURATION:
		_whirlwind_active = false
		# Destroy cover after whirlwind ends
		for obs in _cover_nodes:
			if is_instance_valid(obs):
				obs.queue_free()
		_cover_nodes.clear()
		_clear_boss_obstacles()

func _fire_whirlwind_projectiles(tick: int) -> void:
	if not _proj_scene: return
	var parent = get_parent()
	if not parent: return

	# 4 blades per tick, rotating 17 degrees each tick for a spiral pattern
	var num_blades = 4
	var rotation_per_tick = deg_to_rad(17.0)
	var base_angle = tick * rotation_per_tick
	for i in num_blades:
		var angle = base_angle + TAU * i / num_blades
		var dir = Vector2.from_angle(angle)
		var proj = _proj_scene.instantiate()
		proj.projectile_type = "saw"
		parent.add_child(proj)
		proj.global_position = global_position + dir * 15.0
		proj.setup(dir * 90.0, 15)

# --- Arena Center ---

func _get_arena_center() -> Vector2:
	if player_ref and is_instance_valid(player_ref):
		var cam = player_ref.get_node_or_null("Camera2D")
		if cam: return cam.get_screen_center_position()
	return Vector2(640, 360)
