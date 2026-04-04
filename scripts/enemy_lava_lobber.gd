extends EnemyBase

# Lava Lobber — ranged, fires projectiles that leave fire puddles at target

var shoot_timer: float = 0.0
const SHOOT_INTERVAL   = 2.5
const PREFERRED_DIST   = 120.0
const PROJECTILE_SPEED = 85.0
var _proj_scene: PackedScene = null

func _ready() -> void:
	enemy_type       = "lava_lobber"
	max_health       = 25
	move_speed       = 28.0
	damage           = 22
	xp_value         = 18
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

	var target_pos = player_ref.global_position
	var dir = (target_pos - global_position).normalized()

	var proj = proj_scene.instantiate()
	proj.global_position = global_position + dir * 14.0
	proj.projectile_type = "lava"
	proj.setup(dir * PROJECTILE_SPEED, damage)
	var parent = get_parent()
	if parent:
		parent.add_child(proj)

	# Spawn fire puddle at target position after 0.8s delay
	_delayed_puddle(target_pos)

func _make_circle_poly(radius: float, segments: int = 12, jitter: float = 0.0) -> Polygon2D:
	var poly = Polygon2D.new()
	var pts: PackedVector2Array = []
	for i in segments:
		var angle = TAU * i / float(segments)
		var r = radius + randf_range(-jitter, jitter)
		pts.append(Vector2(cos(angle), sin(angle)) * r)
	poly.polygon = pts
	return poly

func _delayed_puddle(pos: Vector2) -> void:
	var timer = get_tree().create_timer(0.8)
	timer.timeout.connect(_spawn_fire_puddle.bind(pos))

func _spawn_fire_puddle(pos: Vector2) -> void:
	if not is_instance_valid(self): return
	var container = get_parent() if get_parent() else null
	if not container: return

	var puddle = Area2D.new()
	puddle.name = "FirePuddle"
	puddle.global_position = pos
	puddle.collision_layer = 0
	puddle.collision_mask  = 1  # detect player
	puddle.monitoring      = true

	var shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = 20.0
	shape.shape = circle
	puddle.add_child(shape)

	# Visual — animated fire puddle with overlapping flickering circles
	var vis = Node2D.new()
	vis.z_index = -1
	# Wide dim heat glow
	var heat_glow = _make_circle_poly(24, 16)
	heat_glow.color = Color(1.0, 0.2, 0.0, 0.12)
	vis.add_child(heat_glow)
	# Outer red ring
	var outer_ring = _make_circle_poly(20, 14, 2.0)
	outer_ring.color = Color(0.85, 0.15, 0.0, 0.35)
	vis.add_child(outer_ring)
	# Multiple overlapping flame blobs — orange/red at different offsets
	for i in 4:
		var flame = _make_circle_poly(randf_range(10, 16), 10, 2.5)
		var a = TAU * i / 4.0 + randf_range(-0.3, 0.3)
		flame.position = Vector2(cos(a), sin(a)) * randf_range(2, 6)
		flame.color = Color(1.0, randf_range(0.3, 0.55), 0.05, randf_range(0.35, 0.5))
		vis.add_child(flame)
		# Flicker each flame blob independently
		var ftw = puddle.create_tween().set_loops()
		ftw.tween_property(flame, "modulate:a", randf_range(0.5, 0.8), randf_range(0.15, 0.35))
		ftw.tween_property(flame, "modulate:a", 1.0, randf_range(0.15, 0.35))
	# Orange mid layer
	var mid_fire = _make_circle_poly(12, 12, 1.5)
	mid_fire.color = Color(1.0, 0.55, 0.1, 0.5)
	vis.add_child(mid_fire)
	# Yellow hot center
	var hot_core = _make_circle_poly(6, 10)
	hot_core.color = Color(1.0, 0.85, 0.3, 0.6)
	vis.add_child(hot_core)
	# White-hot innermost point
	var white_hot = _make_circle_poly(3, 8)
	white_hot.color = Color(1.0, 0.95, 0.7, 0.45)
	vis.add_child(white_hot)
	puddle.add_child(vis)
	# Overall flickering pulse
	var flicker = puddle.create_tween().set_loops()
	flicker.tween_property(vis, "scale", Vector2(1.06, 1.06), 0.2).set_trans(Tween.TRANS_SINE)
	flicker.tween_property(vis, "scale", Vector2(0.95, 0.95), 0.25).set_trans(Tween.TRANS_SINE)
	flicker.tween_property(vis, "scale", Vector2(1.03, 1.03), 0.15).set_trans(Tween.TRANS_SINE)

	container.add_child(puddle)

	# Damage ticker — 4 dmg every 0.5s for 3s (6 ticks)
	var tick_count := 0
	var tick_timer = Timer.new()
	tick_timer.wait_time = 0.5
	tick_timer.autostart = true
	puddle.add_child(tick_timer)
	tick_timer.timeout.connect(func():
		tick_count += 1
		if tick_count >= 6:
			puddle.queue_free()
			return
		var bodies = puddle.get_overlapping_bodies()
		for body in bodies:
			if body.is_in_group("player") and body.has_method("take_damage"):
				body.take_damage(4, self)
	)

	# Also fade out over 3 seconds
	var tw = puddle.create_tween()
	tw.tween_property(vis, "modulate:a", 0.0, 3.0)
