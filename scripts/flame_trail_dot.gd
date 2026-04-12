extends Area2D

# ============================================================
# FlameTrailDot — Small flame left behind during player dodge
# Damages enemies that walk through it, then fades away
# ============================================================

const FLAME_DAMAGE: int       = 5
const FLAME_LIFETIME: float   = 0.4
const COLLISION_RADIUS: float = 7.0

var _damaged_bodies: Array = []

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2  # Detect enemies only
	monitoring = true
	monitorable = false
	z_index = 1

	_build_visual()
	_build_collision()
	body_entered.connect(_on_body_entered)

	# Fade out and self-destruct
	var tw = create_tween()
	tw.tween_property(self, "modulate:a", 0.0, FLAME_LIFETIME).set_ease(Tween.EASE_IN)
	tw.tween_callback(queue_free)

func _build_visual() -> void:
	# Layer 1: Outer glow (dim orange halo)
	var outer = _make_flame_circle(8.0, 8, Color(1.0, 0.35, 0.0, 0.25))
	add_child(outer)

	# Layer 2: Mid flame (warm orange)
	var mid = _make_flame_circle(5.0, 6, Color(1.0, 0.55, 0.1, 0.7))
	mid.z_index = 1
	add_child(mid)

	# Layer 3: Inner core (bright yellow-white)
	var core = _make_flame_circle(2.5, 6, Color(1.0, 0.9, 0.4, 0.9))
	core.z_index = 2
	add_child(core)

func _make_flame_circle(radius: float, segments: int, color: Color) -> Polygon2D:
	var poly = Polygon2D.new()
	var points: PackedVector2Array = PackedVector2Array()
	for i in range(segments):
		var angle = TAU * i / segments
		# Slight jitter for organic flame look
		var r = radius * randf_range(0.85, 1.15)
		points.append(Vector2(cos(angle) * r, sin(angle) * r))
	poly.polygon = points
	poly.color = color
	return poly

func _build_collision() -> void:
	var col = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = COLLISION_RADIUS
	col.shape = circle
	add_child(col)

func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("enemies"):
		return
	if body in _damaged_bodies:
		return
	_damaged_bodies.append(body)
	if body.has_method("take_damage"):
		body.take_damage(FLAME_DAMAGE, global_position)
