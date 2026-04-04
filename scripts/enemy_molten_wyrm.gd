extends EnemyBase

# Molten Wyrm — Stage 3 Boss
# Charges at player, leaves lava pools, fires spread projectiles.

var charge_timer: float = 0.0
var lava_spread_timer: float = 0.0
var is_charging: bool = false
var charge_time_left: float = 0.0
var charge_dir: Vector2 = Vector2.ZERO
var base_speed: float = 35.0

const CHARGE_INTERVAL = 5.0
const CHARGE_DURATION = 1.5
const CHARGE_SPEED_MULT = 2.0
const LAVA_POOL_DURATION = 4.0
const LAVA_DPS = 5
const LAVA_DROP_INTERVAL = 0.25  # drop lava pools during charge

const LAVA_SPREAD_INTERVAL = 7.0
const LAVA_PROJ_COUNT = 3
const LAVA_PROJ_SPEED = 80.0
const LAVA_SPREAD_ANGLE = 0.4  # radians between each projectile

var lava_drop_cooldown: float = 0.0
var _proj_scene: PackedScene = null

func _ready() -> void:
	enemy_type       = "molten_wyrm"
	max_health       = 800
	move_speed       = 35.0
	damage           = 30
	xp_value         = 150
	contact_cooldown = 1.0
	base_speed       = move_speed
	_proj_scene = load("res://scenes/enemy_projectile.tscn")
	super._ready()
	if health_bar:
		health_bar.visible = true

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	charge_timer += delta
	lava_spread_timer += delta

	if is_charging:
		charge_time_left -= delta
		lava_drop_cooldown -= delta
		if lava_drop_cooldown <= 0:
			lava_drop_cooldown = LAVA_DROP_INTERVAL
			_drop_lava_pool()
		if charge_time_left <= 0:
			_end_charge()
	elif charge_timer >= CHARGE_INTERVAL:
		charge_timer = 0.0
		_start_charge()

	if lava_spread_timer >= LAVA_SPREAD_INTERVAL:
		lava_spread_timer = 0.0
		_lava_spread()

	super._physics_process(delta)

func _move_toward_player(delta: float) -> void:
	if is_charging:
		# Override movement during charge — go in charge direction
		velocity = charge_dir * base_speed * CHARGE_SPEED_MULT
		_update_facing()
		return
	# Normal movement
	super._move_toward_player(delta)

func _start_charge() -> void:
	if not player_ref or not is_instance_valid(player_ref):
		return
	is_charging = true
	charge_time_left = CHARGE_DURATION
	charge_dir = (player_ref.global_position - global_position).normalized()
	lava_drop_cooldown = 0.0
	# Visual: turn bright orange
	if sprite:
		sprite.modulate = Color(2.0, 0.8, 0.3)
	if _dot:
		_dot.modulate = Color(2.0, 0.8, 0.3)

func _end_charge() -> void:
	is_charging = false
	if sprite:
		var tw = create_tween()
		tw.tween_property(sprite, "modulate", Color.WHITE, 0.3)
	if _dot:
		var tw2 = create_tween()
		tw2.tween_property(_dot, "modulate", Color.WHITE, 0.3)

func _drop_lava_pool() -> void:
	var parent = get_parent()
	if not parent:
		return
	var pool = Area2D.new()
	pool.collision_layer = 0
	pool.collision_mask = 1
	pool.monitoring = true
	pool.global_position = global_position

	var shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = 12.0
	shape.shape = circle
	pool.add_child(shape)

	# Visual — molten lava pool with dark border, bright center, pulsing glow
	var vis = Node2D.new()
	vis.z_index = -1
	# Wide heat shimmer glow
	var heat_aura = _make_circle_poly(18, 16)
	heat_aura.color = Color(1.0, 0.15, 0.0, 0.1)
	vis.add_child(heat_aura)
	# Dark red border ring — gives the pool a defined edge
	var border_ring = _make_circle_poly(14, 14, 1.5)
	border_ring.color = Color(0.6, 0.1, 0.0, 0.55)
	vis.add_child(border_ring)
	# Main bright orange lava body
	var lava_body = _make_circle_poly(11, 12, 1.0)
	lava_body.color = Color(1.0, 0.45, 0.05, 0.65)
	vis.add_child(lava_body)
	# Yellow-orange hot layer
	var hot_layer = _make_circle_poly(7, 10)
	hot_layer.color = Color(1.0, 0.7, 0.15, 0.6)
	vis.add_child(hot_layer)
	# Yellow-white hot center — molten core
	var molten_core = _make_circle_poly(4, 8)
	molten_core.color = Color(1.0, 0.9, 0.4, 0.7)
	vis.add_child(molten_core)
	# White-hot innermost pinpoint
	var white_center = _make_circle_poly(2, 6)
	white_center.color = Color(1.0, 1.0, 0.8, 0.6)
	vis.add_child(white_center)
	pool.add_child(vis)
	# Pulsing glow effect — the pool throbs with heat
	var pulse = pool.create_tween().set_loops()
	pulse.tween_property(vis, "scale", Vector2(1.1, 1.1), 0.5).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(vis, "scale", Vector2(0.92, 0.92), 0.5).set_trans(Tween.TRANS_SINE)

	parent.add_child(pool)

	var tick_count = int(LAVA_POOL_DURATION / 0.5)
	_run_lava_ticks(pool, tick_count)

func _make_circle_poly(radius: float, segments: int = 12, jitter: float = 0.0) -> Polygon2D:
	var poly = Polygon2D.new()
	var pts: PackedVector2Array = []
	for i in segments:
		var angle = TAU * i / float(segments)
		var r = radius + randf_range(-jitter, jitter)
		pts.append(Vector2(cos(angle), sin(angle)) * r)
	poly.polygon = pts
	return poly

func _run_lava_ticks(pool: Area2D, ticks_left: int) -> void:
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
			body.take_damage(LAVA_DPS, self)
	var vis = pool.get_child(1) if pool.get_child_count() > 1 else null
	if vis:
		vis.modulate.a = float(ticks_left) / (LAVA_POOL_DURATION / 0.5)
	_run_lava_ticks(pool, ticks_left - 1)

func _lava_spread() -> void:
	if not player_ref or not is_instance_valid(player_ref):
		return
	var proj_scene = _proj_scene
	if not proj_scene:
		return
	var parent = get_parent()
	if not parent:
		return
	_play_attack_anim()

	# Visual feedback
	if sprite:
		sprite.modulate = Color(2.0, 0.5, 0.1)
		var tw = create_tween()
		tw.tween_property(sprite, "modulate", Color.WHITE, 0.25)
	if _dot:
		_dot.modulate = Color(2.0, 0.5, 0.1)
		var tw2 = create_tween()
		tw2.tween_property(_dot, "modulate", Color.WHITE, 0.25)

	var base_dir = (player_ref.global_position - global_position).normalized()
	var base_angle = base_dir.angle()

	for i in LAVA_PROJ_COUNT:
		var offset = (i - (LAVA_PROJ_COUNT - 1) / 2.0) * LAVA_SPREAD_ANGLE
		var angle = base_angle + offset
		var dir = Vector2(cos(angle), sin(angle))
		var proj = proj_scene.instantiate()
		proj.global_position = global_position + dir * 12.0
		proj.projectile_type = "lava"
		proj.setup(dir * LAVA_PROJ_SPEED, damage)
		parent.add_child(proj)
