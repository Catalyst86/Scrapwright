extends EnemyBase

# Magma Imp — fast direct melee, leaves damaging fire trail

var trail_timer: float = 0.0
const TRAIL_INTERVAL   = 0.3

func _ready() -> void:
	enemy_type       = "magma_imp"
	max_health       = 28
	move_speed       = 72.0
	damage           = 10
	xp_value         = 12
	contact_cooldown = 0.8
	super._ready()

func _physics_process(delta: float) -> void:
	if is_dead: return
	trail_timer += delta
	if trail_timer >= TRAIL_INTERVAL and velocity.length() > 5.0:
		trail_timer = 0.0
		_spawn_fire_dot()
	super._physics_process(delta)

# Direct movement like flyer — no nav agent
func _move_toward_player(delta: float) -> void:
	if not player_ref or not is_instance_valid(player_ref):
		player_ref = get_tree().get_first_node_in_group("player")
		return
	var dir = (player_ref.global_position - global_position).normalized()
	velocity = velocity.move_toward(dir * move_speed, move_speed * 12.0 * delta)
	if sprite and velocity.length() > 5.0:
		sprite.flip_h = velocity.x < 0

func _spawn_fire_dot() -> void:
	_play_attack_anim()
	var dot = Area2D.new()
	dot.name = "FireDot"
	dot.global_position = global_position
	dot.collision_layer = 0
	dot.collision_mask  = 1  # detect player
	dot.monitoring      = true

	var shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = 6.0
	shape.shape = circle
	dot.add_child(shape)

	# Visual — LARGE visible glowing ember with bright halo (12x12)
	var vis = Node2D.new()
	vis.z_index = -1
	# Outer glow halo — large semi-transparent ring so player can SEE it
	var outer_halo = _make_circle_poly(14, 12)
	outer_halo.color = Color(1.0, 0.25, 0.0, 0.18)
	vis.add_child(outer_halo)
	# Mid glow ring — warm orange
	var mid_halo = _make_circle_poly(10, 10)
	mid_halo.color = Color(1.0, 0.4, 0.05, 0.3)
	vis.add_child(mid_halo)
	# Hot ember body — bright orange, clearly visible
	var ember_body = _make_circle_poly(6, 10)
	ember_body.color = Color(1.0, 0.55, 0.1, 0.85)
	vis.add_child(ember_body)
	# Bright yellow-white center core
	var hot_center = _make_circle_poly(3.5, 8)
	hot_center.color = Color(1.0, 0.9, 0.4, 0.95)
	vis.add_child(hot_center)
	# White-hot pinpoint
	var white_core = _make_circle_poly(1.5, 6)
	white_core.color = Color(1.0, 1.0, 0.8, 0.9)
	vis.add_child(white_core)
	dot.add_child(vis)
	# Flickering pulse so it catches the eye
	var flicker = dot.create_tween().set_loops()
	flicker.tween_property(vis, "scale", Vector2(1.15, 1.15), 0.12).set_trans(Tween.TRANS_SINE)
	flicker.tween_property(vis, "scale", Vector2(0.9, 0.9), 0.18).set_trans(Tween.TRANS_SINE)

	dot.body_entered.connect(func(body: Node):
		if body.is_in_group("player") and body.has_method("take_damage"):
			body.take_damage(5, self)
	)

	var container = get_parent() if get_parent() else self
	container.add_child(dot)

	# Fade out over 2 seconds then remove
	var tw = dot.create_tween()
	tw.tween_property(vis, "modulate:a", 0.0, 2.0)
	tw.tween_callback(dot.queue_free)

func _make_circle_poly(radius: float, segments: int = 12) -> Polygon2D:
	var poly = Polygon2D.new()
	var pts: PackedVector2Array = []
	for i in segments:
		var angle = TAU * i / float(segments)
		pts.append(Vector2(cos(angle), sin(angle)) * radius)
	poly.polygon = pts
	return poly

