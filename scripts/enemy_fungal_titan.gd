extends EnemyBase

# Fungal Titan — Stage 2 Boss
# Phase 1: Poison trail (1.5s), spore burst (6s, 6 projectiles), self-heal (10s, 20 HP).
# Phase 2 "LASER SWEEP": Teleports to left arena edge, fires a bright green laser beam
#   (Line2D, width 8) that sweeps top to bottom over 3s. 40 damage on contact.
#   Banner: "DASH!" Teleports back after.
# Phase 3 "FUNGAL ERUPTION": Poison pools erupt at player's last 5 positions (delayed 1.5s
#   each). Self-heal increased to 30 HP. Laser sweep repeats every 18s.

var poison_trail_timer: float = 0.0
var spore_burst_timer: float = 0.0
var heal_timer: float = 0.0

const POISON_TRAIL_INTERVAL = 1.5
const POISON_TRAIL_DURATION = 5.0
const POISON_DPS = 3

const SPORE_BURST_INTERVAL = 6.0
const SPORE_COUNT = 6
const SPORE_SPEED = 70.0

const HEAL_INTERVAL = 10.0
var _heal_amount: int = 20

# Laser sweep state (Phase 2+)
var _laser_sweep_active: bool = false
var _laser_sweep_elapsed: float = 0.0
var _laser_sweep_cooldown_timer: float = 0.0
var _laser_line: Line2D = null
var _laser_area: Area2D = null
var _pre_laser_position: Vector2 = Vector2.ZERO

const LASER_SWEEP_DURATION = 3.0
const LASER_SWEEP_COOLDOWN = 18.0
const LASER_DAMAGE = 40
const LASER_WIDTH = 8.0
const LASER_LENGTH = 500.0

# Fungal eruption state (Phase 3)
var _eruption_active: bool = false
var _player_positions: Array = []
var _eruption_index: int = 0
var _eruption_delay_timer: float = 0.0

const ERUPTION_POSITIONS = 5
const ERUPTION_DELAY = 1.5
const ERUPTION_POOL_RADIUS = 20.0
const ERUPTION_POOL_DURATION = 4.0

var _proj_scene: PackedScene = null

func _ready() -> void:
	enemy_type       = "fungal_titan"
	max_health       = 1300
	move_speed       = 25.0
	damage           = 20
	xp_value         = 120
	contact_cooldown = 1.5
	_proj_scene = load("res://scenes/enemy_projectile.tscn")
	super._ready()
	if health_bar:
		health_bar.visible = true

func _physics_process(delta: float) -> void:
	if is_dead or _phase_transitioning: return

	# Laser sweep processing
	if _laser_sweep_active:
		_process_laser_sweep(delta)
		return  # Don't do normal attacks during laser

	# Fungal eruption processing
	if _eruption_active:
		_process_eruption(delta)

	poison_trail_timer += delta
	spore_burst_timer += delta
	heal_timer += delta

	if poison_trail_timer >= POISON_TRAIL_INTERVAL:
		poison_trail_timer = 0.0
		_drop_poison()

	if spore_burst_timer >= SPORE_BURST_INTERVAL:
		spore_burst_timer = 0.0
		_spore_burst()

	if heal_timer >= HEAL_INTERVAL:
		heal_timer = 0.0
		_heal()

	# Laser cooldown (Phase 2+)
	if _boss_phase >= 2 and not _laser_sweep_active:
		_laser_sweep_cooldown_timer += delta
		if _laser_sweep_cooldown_timer >= LASER_SWEEP_COOLDOWN:
			_laser_sweep_cooldown_timer = 0.0
			_start_laser_sweep()

	# Phase 3: Track player positions for eruption
	if _boss_phase >= 3 and not _eruption_active:
		if player_ref and is_instance_valid(player_ref):
			# Sample player position periodically (every ~0.5s based on frame accumulation)
			if _player_positions.size() < 20:
				_player_positions.append(player_ref.global_position)
			elif randf() < 0.1:
				# Replace a random older position to keep the list fresh
				_player_positions[randi() % _player_positions.size()] = player_ref.global_position

	super._physics_process(delta)

# --- Phase Transitions ---

func _on_phase_change(new_phase: int) -> void:
	super._on_phase_change(new_phase)
	match new_phase:
		2:
			_show_boss_warning("DASH!")
			# Immediately trigger first laser sweep
			_start_laser_sweep()
		3:
			_show_boss_warning("FUNGAL ERUPTION!")
			# Increase heal amount
			_heal_amount = 30

# --- Poison Trail ---

func _drop_poison() -> void:
	var parent = get_parent()
	if not parent: return

	var pool = Area2D.new()
	pool.collision_layer = 0
	pool.collision_mask = 1  # detect player
	pool.monitoring = true
	pool.global_position = global_position

	var shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = 14.0
	shape.shape = circle
	pool.add_child(shape)

	# Visual — bubbling acid puddle with layered circles
	var vis = Node2D.new()
	vis.z_index = -1
	var glow_ring = _make_circle_poly(18, 16)
	glow_ring.color = Color(0.08, 0.35, 0.1, 0.25)
	glow_ring.z_index = -1
	vis.add_child(glow_ring)
	var puddle_main = _make_circle_poly(14, 14, 2.0)
	puddle_main.color = Color(0.12, 0.5, 0.18, 0.55)
	vis.add_child(puddle_main)
	var inner_pool = _make_circle_poly(9, 12, 1.5)
	inner_pool.color = Color(0.25, 0.7, 0.25, 0.45)
	vis.add_child(inner_pool)
	var acid_core = _make_circle_poly(5, 10)
	acid_core.color = Color(0.4, 0.9, 0.3, 0.35)
	vis.add_child(acid_core)
	for i in 5:
		var bubble = _make_circle_poly(randf_range(1.0, 2.2), 6)
		bubble.color = Color(0.4, 0.9, 0.35, randf_range(0.4, 0.7))
		bubble.position = Vector2(randf_range(-9, 9), randf_range(-9, 9))
		vis.add_child(bubble)
		var btw = pool.create_tween().set_loops()
		btw.tween_property(bubble, "position:y", bubble.position.y - 3.0, randf_range(0.4, 0.8)).set_delay(randf_range(0.0, 1.0))
		btw.tween_property(bubble, "position:y", bubble.position.y, 0.3)
	pool.add_child(vis)
	var pulse = pool.create_tween().set_loops()
	pulse.tween_property(vis, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.8).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(vis, "modulate", Color(0.85, 1.0, 0.85, 0.8), 0.8).set_trans(Tween.TRANS_SINE)

	parent.add_child(pool)

	var tick_count = int(POISON_TRAIL_DURATION / 0.5)
	_run_poison_ticks(pool, tick_count)

func _make_circle_poly(radius: float, segments: int = 12, jitter: float = 0.0) -> Polygon2D:
	var poly = Polygon2D.new()
	var pts: PackedVector2Array = []
	for i in segments:
		var angle = TAU * i / float(segments)
		var r = radius + randf_range(-jitter, jitter)
		pts.append(Vector2(cos(angle), sin(angle)) * r)
	poly.polygon = pts
	return poly

func _run_poison_ticks(pool: Area2D, ticks_left: int) -> void:
	if ticks_left <= 0 or not is_instance_valid(pool):
		if is_instance_valid(pool):
			pool.queue_free()
		return
	if not is_instance_valid(self) or not is_inside_tree():
		if is_instance_valid(pool): pool.queue_free()
		return
	await get_tree().create_timer(0.5).timeout
	if not is_inside_tree() or not is_instance_valid(pool):
		return
	var bodies = pool.get_overlapping_bodies()
	for body in bodies:
		if body.is_in_group("player") and body.has_method("take_damage"):
			body.take_damage(POISON_DPS, self)
	var vis = pool.get_child(1) if pool.get_child_count() > 1 else null
	if vis:
		vis.modulate.a = float(ticks_left) / (POISON_TRAIL_DURATION / 0.5)
	_run_poison_ticks(pool, ticks_left - 1)

# --- Spore Burst ---

func _spore_burst() -> void:
	if not player_ref or not is_instance_valid(player_ref): return
	if not _proj_scene: return
	var parent = get_parent()
	if not parent: return
	_play_attack_anim_then(_do_spore_burst)

func _do_spore_burst() -> void:
	if is_dead: return
	if not _proj_scene: return
	var parent = get_parent()
	if not parent: return

	# Visual feedback
	if sprite:
		sprite.modulate = Color(0.4, 1.5, 0.6)
		var tw = create_tween()
		tw.tween_property(sprite, "modulate", Color.WHITE, 0.3)
	if _dot:
		_dot.modulate = Color(0.4, 1.5, 0.6)
		var tw2 = create_tween()
		tw2.tween_property(_dot, "modulate", Color.WHITE, 0.3)

	for i in SPORE_COUNT:
		var angle = (TAU / SPORE_COUNT) * i
		var dir = Vector2(cos(angle), sin(angle))
		var proj = _proj_scene.instantiate()
		proj.projectile_type = "spore"
		parent.add_child(proj)
		proj.global_position = global_position + dir * 12.0
		proj.setup(dir * SPORE_SPEED, damage)

	# Phase 3: Also trigger fungal eruption at player positions
	if _boss_phase >= 3 and not _eruption_active:
		_start_eruption()

# --- Self Heal ---

func _heal() -> void:
	if health >= max_health: return
	health = mini(health + _heal_amount, max_health)
	if health_bar:
		health_bar.value = health
	# Green flash
	if sprite:
		sprite.modulate = Color(0.5, 1.8, 0.5)
		var tw = create_tween()
		tw.tween_property(sprite, "modulate", Color.WHITE, 0.25)
	if _dot:
		_dot.modulate = Color(0.5, 1.8, 0.5)
		var tw2 = create_tween()
		tw2.tween_property(_dot, "modulate", Color.WHITE, 0.25)
	# Heal number
	var lbl = Label.new()
	lbl.text = "+" + str(_heal_amount)
	lbl.z_index = 20
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4))
	lbl.position = global_position + Vector2(-8, -20)
	var parent = get_parent()
	if parent:
		parent.add_child(lbl)
		var tw3 = lbl.create_tween()
		tw3.set_parallel(true)
		tw3.tween_property(lbl, "position:y", lbl.position.y - 18.0, 0.5).set_ease(Tween.EASE_OUT)
		tw3.tween_property(lbl, "modulate:a", 0.0, 0.5).set_delay(0.25)
		tw3.set_parallel(false)
		tw3.tween_callback(lbl.queue_free)

# --- Laser Sweep (Phase 2+) ---

func _start_laser_sweep() -> void:
	if _laser_sweep_active or is_dead: return
	_laser_sweep_active = true
	_laser_sweep_elapsed = 0.0

	_show_boss_warning("DASH!")

	# Remember current position to teleport back
	_pre_laser_position = global_position

	# Teleport to left edge of arena
	var arena_center = _get_arena_center()
	var left_edge = arena_center + Vector2(-220, 0)
	global_position = left_edge

	# Flash to indicate teleport
	if sprite:
		sprite.modulate = Color(0.3, 2.0, 0.3)
		var tw = create_tween()
		tw.tween_property(sprite, "modulate", Color.WHITE, 0.3)

	# Create the laser beam (Line2D pointing right from boss position)
	var parent = get_parent()
	if not parent: return

	_laser_line = Line2D.new()
	_laser_line.width = LASER_WIDTH
	_laser_line.default_color = Color(0.2, 1.0, 0.2, 0.9)
	_laser_line.z_index = 10
	# Laser points right from boss, top of arena initially
	var laser_start_y = arena_center.y - 200.0  # Start from top
	_laser_line.add_point(Vector2(0, 0))
	_laser_line.add_point(Vector2(LASER_LENGTH, 0))
	_laser_line.global_position = Vector2(left_edge.x, laser_start_y)
	parent.add_child(_laser_line)

	# Create damage area that follows the laser
	_laser_area = Area2D.new()
	_laser_area.collision_layer = 0
	_laser_area.collision_mask = 1  # player
	_laser_area.monitoring = true
	var col = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(LASER_LENGTH, LASER_WIDTH)
	col.shape = shape
	col.position = Vector2(LASER_LENGTH * 0.5, 0)
	_laser_area.add_child(col)
	_laser_area.global_position = Vector2(left_edge.x, laser_start_y)
	parent.add_child(_laser_area)

func _process_laser_sweep(delta: float) -> void:
	_laser_sweep_elapsed += delta

	var arena_center = _get_arena_center()
	var top_y = arena_center.y - 200.0
	var bottom_y = arena_center.y + 200.0
	var progress = clampf(_laser_sweep_elapsed / LASER_SWEEP_DURATION, 0.0, 1.0)
	var current_y = lerp(top_y, bottom_y, progress)

	# Update laser position
	if is_instance_valid(_laser_line):
		_laser_line.global_position.y = current_y
		# Pulsing glow effect
		var glow = 0.7 + sin(_laser_sweep_elapsed * 15.0) * 0.3
		_laser_line.default_color = Color(0.2, glow, 0.2, 0.9)

	if is_instance_valid(_laser_area):
		_laser_area.global_position.y = current_y
		# Check for player collision
		var bodies = _laser_area.get_overlapping_bodies()
		for body in bodies:
			if body.is_in_group("player") and body.has_method("take_damage"):
				body.take_damage(LASER_DAMAGE, self)

	# End laser sweep
	if _laser_sweep_elapsed >= LASER_SWEEP_DURATION:
		_laser_sweep_active = false

		# Clean up laser visuals
		if is_instance_valid(_laser_line):
			_laser_line.queue_free()
			_laser_line = null
		if is_instance_valid(_laser_area):
			_laser_area.queue_free()
			_laser_area = null

		# Teleport back to previous position
		global_position = _pre_laser_position
		if sprite:
			sprite.modulate = Color(0.3, 2.0, 0.3)
			var tw = create_tween()
			tw.tween_property(sprite, "modulate", Color.WHITE, 0.3)

# --- Fungal Eruption (Phase 3) ---

func _start_eruption() -> void:
	if _eruption_active or is_dead: return
	_eruption_active = true
	_eruption_index = 0
	_eruption_delay_timer = 0.0

	# Collect the last N player positions (or current if not enough)
	# Use the tracked positions, picking the most recent ones
	_player_positions.clear()
	if player_ref and is_instance_valid(player_ref):
		# Record 5 positions with slight offsets to spread them
		for i in ERUPTION_POSITIONS:
			var offset = Vector2(randf_range(-30, 30), randf_range(-30, 30))
			_player_positions.append(player_ref.global_position + offset)

func _process_eruption(delta: float) -> void:
	if _eruption_index >= _player_positions.size():
		_eruption_active = false
		return

	_eruption_delay_timer += delta
	if _eruption_delay_timer >= ERUPTION_DELAY:
		_eruption_delay_timer -= ERUPTION_DELAY
		_spawn_eruption_pool(_player_positions[_eruption_index])
		_eruption_index += 1

func _spawn_eruption_pool(pos: Vector2) -> void:
	var parent = get_parent()
	if not parent: return

	# Warning indicator before the pool appears
	var warning = Polygon2D.new()
	var warn_pts: PackedVector2Array = []
	for i in 12:
		var angle = TAU * i / 12.0
		warn_pts.append(Vector2(cos(angle), sin(angle)) * ERUPTION_POOL_RADIUS)
	warning.polygon = warn_pts
	warning.color = Color(1.0, 0.3, 0.3, 0.4)
	warning.position = pos
	warning.z_index = -1
	parent.add_child(warning)

	# Flash warning, then spawn actual pool
	var warn_tw = warning.create_tween()
	warn_tw.tween_property(warning, "modulate:a", 0.1, 0.3)
	warn_tw.tween_property(warning, "modulate:a", 1.0, 0.3)
	warn_tw.tween_property(warning, "modulate:a", 0.1, 0.3)
	warn_tw.tween_callback(warning.queue_free)

	# Delayed actual pool creation (after warning blinks)
	if not is_inside_tree(): return
	await get_tree().create_timer(0.9).timeout
	if is_dead or not is_inside_tree(): return

	# Create the poison pool
	var pool = Area2D.new()
	pool.collision_layer = 0
	pool.collision_mask = 1
	pool.monitoring = true
	pool.global_position = pos

	var shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = ERUPTION_POOL_RADIUS
	shape.shape = circle
	pool.add_child(shape)

	# Visual — green eruption pool
	var vis = Node2D.new()
	vis.z_index = -1
	var outer = _make_circle_poly(ERUPTION_POOL_RADIUS, 14, 3.0)
	outer.color = Color(0.15, 0.6, 0.2, 0.5)
	vis.add_child(outer)
	var inner = _make_circle_poly(ERUPTION_POOL_RADIUS * 0.6, 10, 2.0)
	inner.color = Color(0.3, 0.85, 0.3, 0.4)
	vis.add_child(inner)
	var core = _make_circle_poly(ERUPTION_POOL_RADIUS * 0.3, 8)
	core.color = Color(0.5, 1.0, 0.4, 0.35)
	vis.add_child(core)
	pool.add_child(vis)

	# Eruption burst visual — particles shooting up
	var burst = Label.new()
	burst.text = "ERUPTION!"
	burst.add_theme_font_size_override("font_size", 7)
	burst.add_theme_color_override("font_color", Color(0.4, 1.0, 0.3))
	burst.position = pos + Vector2(-20, -24)
	burst.z_index = 15
	parent.add_child(burst)
	var btw = burst.create_tween()
	btw.tween_property(burst, "position:y", burst.position.y - 20, 0.5)
	btw.parallel().tween_property(burst, "modulate:a", 0.0, 0.5)
	btw.tween_callback(burst.queue_free)

	parent.add_child(pool)

	# Run damage ticks for the pool
	var tick_count = int(ERUPTION_POOL_DURATION / 0.5)
	_run_eruption_ticks(pool, vis, tick_count)

func _run_eruption_ticks(pool: Area2D, vis: Node2D, ticks_left: int) -> void:
	if ticks_left <= 0 or not is_instance_valid(pool):
		if is_instance_valid(pool):
			pool.queue_free()
		return
	if not is_instance_valid(self) or not is_inside_tree():
		if is_instance_valid(pool): pool.queue_free()
		return
	await get_tree().create_timer(0.5).timeout
	if not is_inside_tree() or not is_instance_valid(pool):
		return
	var bodies = pool.get_overlapping_bodies()
	for body in bodies:
		if body.is_in_group("player") and body.has_method("take_damage"):
			body.take_damage(POISON_DPS, self)
	# Fade visual
	if is_instance_valid(vis):
		vis.modulate.a = float(ticks_left) / (ERUPTION_POOL_DURATION / 0.5)
	_run_eruption_ticks(pool, vis, ticks_left - 1)

# --- Arena Center ---

func _get_arena_center() -> Vector2:
	if player_ref and is_instance_valid(player_ref):
		var cam = player_ref.get_node_or_null("Camera2D")
		if cam: return cam.get_screen_center_position()
	return Vector2(640, 360)
