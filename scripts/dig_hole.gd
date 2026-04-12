extends Area2D

# ============================================================
# DigHole — Trap hole dug by the puppy during combat
# Enemies that walk over it get stunned and take damage
# ============================================================

const STUN_DURATION = 3.0
const HOLE_DAMAGE = 15
const MAX_CATCHES = 4  # Stun up to 4 enemies before collapsing

# Visual tuning
const HOLE_RX: float  = 11.0
const HOLE_RY: float  = 7.0
const RIM_RX: float   = 14.0
const RIM_RY: float   = 10.0
const SHADOW_RX: float = 12.5
const SHADOW_RY: float = 8.5
const DIRT_PARTICLE_COUNT: int = 10
const DIRT_SCATTER_RADIUS: float = 18.0

var _catch_count: int = 0

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2  # Detect enemies only
	monitoring = true
	monitorable = false
	z_index = -10  # Well below player and enemies
	z_as_relative = false

	_build_visual()
	_build_collision()
	body_entered.connect(_on_body_entered)

	# Spawn pop animation
	scale = Vector2(0.5, 0.5)
	var tw = create_tween()
	tw.tween_property(self, "scale", Vector2(1.0, 1.0), 0.15).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

func _build_visual() -> void:
	# --- Layer 1: Scattered dirt particles around the edge ---
	for i in range(DIRT_PARTICLE_COUNT):
		var angle = TAU * i / DIRT_PARTICLE_COUNT + randf_range(-0.3, 0.3)
		var dist = randf_range(DIRT_SCATTER_RADIUS * 0.6, DIRT_SCATTER_RADIUS)
		var pos = Vector2(cos(angle) * dist, sin(angle) * dist * 0.7)
		var particle = _make_dirt_particle()
		particle.position = pos
		particle.z_index = -2
		add_child(particle)

	# --- Layer 2: Outer dirt rim (irregular oval) ---
	var rim = _make_oval_poly(RIM_RX, RIM_RY, 12, 1.5)
	rim.color = Color(0.4, 0.3, 0.18, 0.8)
	rim.z_index = -1
	add_child(rim)

	# --- Layer 3: Shadow ring (depth illusion) ---
	var shadow = _make_oval_poly(SHADOW_RX, SHADOW_RY, 10, 1.0)
	shadow.color = Color(0.15, 0.1, 0.06, 0.7)
	add_child(shadow)

	# --- Layer 4: Dark hole center ---
	var center = _make_oval_poly(HOLE_RX, HOLE_RY, 10, 0.8)
	center.color = Color(0.04, 0.03, 0.02, 0.95)
	center.z_index = 1
	add_child(center)

	# --- Layer 5: Light edge highlights (top-left lip) ---
	for j in range(3):
		var ha = PI + randf_range(-0.5, 0.5)  # Top-left arc
		var hr = randf_range(RIM_RX * 0.7, RIM_RX * 0.95)
		var highlight = _make_oval_poly(1.5, 1.0, 5, 0.3)
		highlight.color = Color(0.55, 0.42, 0.28, 0.35)
		highlight.position = Vector2(cos(ha) * hr, sin(ha) * hr * 0.7)
		highlight.z_index = 2
		add_child(highlight)

func _make_oval_poly(rx: float, ry: float, segments: int = 10, jitter: float = 0.0) -> Polygon2D:
	var poly = Polygon2D.new()
	var points: PackedVector2Array = PackedVector2Array()
	for i in range(segments):
		var angle = TAU * i / segments
		var jx = randf_range(-jitter, jitter) if jitter > 0.0 else 0.0
		var jy = randf_range(-jitter, jitter) if jitter > 0.0 else 0.0
		points.append(Vector2(cos(angle) * rx + jx, sin(angle) * ry + jy))
	poly.polygon = points
	return poly

func _make_dirt_particle() -> Polygon2D:
	var poly = Polygon2D.new()
	var sides = randi_range(4, 6)
	var radius = randf_range(1.5, 3.5)
	var points: PackedVector2Array = PackedVector2Array()
	for i in range(sides):
		var angle = TAU * i / sides + randf_range(-0.3, 0.3)
		var r = radius * randf_range(0.6, 1.0)
		points.append(Vector2(cos(angle) * r, sin(angle) * r))
	poly.polygon = points
	# Random brown shade
	var brightness = randf_range(0.3, 0.55)
	poly.color = Color(brightness, brightness * 0.75, brightness * 0.45, randf_range(0.5, 0.8))
	return poly

func _build_collision() -> void:
	var col = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = 14.0
	col.shape = circle
	add_child(col)

func _on_body_entered(body: Node) -> void:
	if _catch_count >= MAX_CATCHES: return
	if not body.is_in_group("enemies"): return
	_catch_count += 1
	AudioManager.play("trap_snap", 0.1)

	# Defer damage/stun to avoid physics flushing errors
	call_deferred("_apply_trap_effect", body)

	# Show catch text
	var txt = Label.new()
	txt.text = "TRAPPED!"
	txt.add_theme_font_size_override("font_size", 8)
	txt.add_theme_color_override("font_color", Color(0.85, 0.65, 0.3))
	txt.position = global_position + Vector2(-16, -20)
	txt.z_index = 10
	var hole_parent = get_parent()
	if not hole_parent: return
	hole_parent.add_child(txt)
	var tw_t = txt.create_tween()
	tw_t.tween_property(txt, "position:y", txt.position.y - 14, 0.6)
	tw_t.parallel().tween_property(txt, "modulate:a", 0.0, 0.6)
	tw_t.tween_callback(txt.queue_free)

	if _catch_count >= MAX_CATCHES:
		call_deferred("_collapse")

func _apply_trap_effect(body: Node) -> void:
	if not is_instance_valid(body): return
	if body.has_method("take_damage"):
		body.take_damage(HOLE_DAMAGE, global_position)
	if body.has_method("stun"):
		body.stun(STUN_DURATION)

func _collapse() -> void:
	AudioManager.play("trap_collapse")
	set_deferred("monitoring", false)
	var tw = create_tween()
	tw.tween_property(self, "scale", Vector2(0.3, 0.3), 0.5).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(self, "modulate:a", 0.0, 0.5)
	tw.tween_callback(queue_free)
