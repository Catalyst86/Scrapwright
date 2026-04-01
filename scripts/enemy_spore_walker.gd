extends EnemyBase

# Spore Walker — melee, spawns a slowing spore cloud on death

func _ready() -> void:
	enemy_type       = "spore_walker"
	max_health       = 35
	move_speed       = 52.0
	damage           = 12
	xp_value         = 11
	contact_cooldown = 1.0
	super._ready()

func _die() -> void:
	if is_dead: return
	_spawn_spore_cloud()
	super._die()

func _spawn_spore_cloud() -> void:
	var cloud = Area2D.new()
	cloud.name = "SporeCloud"
	cloud.global_position = global_position
	cloud.collision_layer = 0
	cloud.collision_mask  = 1  # detect player
	cloud.monitoring      = true

	var shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = 25.0
	shape.shape = circle
	cloud.add_child(shape)

	# Visual — toxic gas cloud with multiple overlapping semi-transparent circles
	var vis = Node2D.new()
	vis.z_index = -1
	# Large diffuse outer glow halo
	var outer_glow = _make_circle_poly(32, 20)
	outer_glow.color = Color(0.15, 0.5, 0.05, 0.12)
	vis.add_child(outer_glow)
	# Multiple overlapping cloud blobs at random offsets for organic shape
	for i in 5:
		var blob = _make_circle_poly(randf_range(12, 20), 14)
		var a = TAU * i / 5.0 + randf_range(-0.3, 0.3)
		blob.position = Vector2(cos(a), sin(a)) * randf_range(3, 10)
		blob.color = Color(0.2, randf_range(0.55, 0.75), 0.1, randf_range(0.2, 0.35))
		vis.add_child(blob)
	# Brighter inner cloud mass
	for i in 3:
		var inner = _make_circle_poly(randf_range(10, 15), 12)
		inner.position = Vector2(randf_range(-5, 5), randf_range(-5, 5))
		inner.color = Color(0.3, 0.85, 0.2, randf_range(0.25, 0.4))
		vis.add_child(inner)
	# Bright toxic core
	var core = _make_circle_poly(7, 10)
	core.color = Color(0.5, 1.0, 0.3, 0.35)
	vis.add_child(core)
	# Spore particles — small bright dots scattered throughout
	for i in 8:
		var dot = _make_circle_poly(randf_range(1.5, 3.0), 6)
		dot.color = Color(0.6, 1.0, 0.4, randf_range(0.4, 0.7))
		var angle = TAU * i / 8.0 + randf_range(-0.4, 0.4)
		dot.position = Vector2(cos(angle), sin(angle)) * randf_range(6, 22)
		vis.add_child(dot)
	cloud.add_child(vis)
	# Pulsing glow animation
	var pulse_tw = cloud.create_tween().set_loops()
	pulse_tw.tween_property(vis, "scale", Vector2(1.08, 1.08), 0.6).set_trans(Tween.TRANS_SINE)
	pulse_tw.tween_property(vis, "scale", Vector2(0.94, 0.94), 0.6).set_trans(Tween.TRANS_SINE)

	cloud.body_entered.connect(func(body: Node):
		if not is_instance_valid(body): return
		if body.is_in_group("player") and body.has_method("apply_status"):
			body.apply_status("slowed", 2.0)
	)

	var container = get_parent()
	if not container: return
	container.add_child(cloud)

	# Fade out over 3 seconds then remove
	var tw = cloud.create_tween()
	tw.tween_property(vis, "modulate:a", 0.0, 3.0)
	tw.tween_callback(cloud.queue_free)

func _make_circle_poly(radius: float, segments: int = 12) -> Polygon2D:
	var poly = Polygon2D.new()
	var pts: PackedVector2Array = []
	for i in segments:
		var angle = TAU * i / float(segments)
		pts.append(Vector2(cos(angle), sin(angle)) * radius)
	poly.polygon = pts
	return poly

