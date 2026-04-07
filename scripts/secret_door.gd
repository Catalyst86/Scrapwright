extends Area2D

# ============================================================
# SecretDoor — Glowing portal that appears after boss waves
# Consumes a secret key and teleports player to bonus room
# ============================================================

signal door_used  # NOTE: Currently unconnected — arena monitors _secret_door ref directly

const DOOR_W = 36.0
const DOOR_H = 48.0
const FADE_TIME = 10.0

var _time: float = 0.0
var _fade_timer: float = FADE_TIME
var _used: bool = false
var _portal_rect: Node2D
var _glow_rect: Node2D
var _label: Label
var _sparkles: Array[Polygon2D] = []

func _ready() -> void:
	# Layer 16 so the door doesn't physically block anything,
	# mask 1 to detect the player (CharacterBody2D on layer 1).
	collision_layer = 16
	collision_mask = 1
	monitoring = true
	monitorable = false
	z_index = 10  # Well above floor/walls/enemies

	body_entered.connect(_on_body_entered)

	# Rebuild collision shape to match new size
	var col := $CollisionShape2D as CollisionShape2D
	if col:
		var shape = RectangleShape2D.new()
		shape.size = Vector2(DOOR_W + 10, DOOR_H + 10)  # Generous hitbox
		col.shape = shape

	_build_visuals()

func _process(delta: float) -> void:
	if _used:
		return

	_time += delta
	_fade_timer -= delta

	# Pulsing glow animation — oscillates between 0.4 and 1.0
	if _glow_rect:
		var pulse = 0.6 + 0.4 * sin(_time * 3.0)
		_glow_rect.modulate.a = pulse
		# Slowly rotate the glow
		_glow_rect.rotation = sin(_time * 0.8) * 0.12

	# Portal body swirl
	if _portal_rect:
		_portal_rect.rotation = sin(_time * 1.5) * 0.1

	# Sparkles orbit
	for i in _sparkles.size():
		var spark = _sparkles[i]
		if is_instance_valid(spark):
			var base_angle = TAU * i / _sparkles.size() + _time * 1.8
			var rx = DOOR_W / 2.0 + 4.0
			var ry = DOOR_H / 2.0 + 4.0
			spark.position = Vector2(cos(base_angle) * rx, sin(base_angle) * ry)
			spark.modulate.a = 0.6 + 0.4 * sin(_time * 5.0 + i)

	# Floating label bob
	if _label:
		_label.position.y = -DOOR_H / 2.0 - 16 + sin(_time * 2.5) * 3.0

	# Fade away after timeout
	if _fade_timer <= 2.0 and _fade_timer > 0:
		modulate.a = _fade_timer / 2.0
	elif _fade_timer <= 0:
		queue_free()

func _build_visuals() -> void:
	# --- Outer glow (big, bright, hard to miss) ---
	_glow_rect = Node2D.new()
	_glow_rect.z_index = 0
	var glow_poly = Polygon2D.new()
	var gpts: PackedVector2Array = []
	for i in 20:
		var angle = TAU * i / 20.0
		var rx = (DOOR_W + 28) / 2.0
		var ry = (DOOR_H + 28) / 2.0
		gpts.append(Vector2(cos(angle) * rx, sin(angle) * ry))
	glow_poly.polygon = gpts
	glow_poly.color = Color(0.8, 0.2, 1.0, 0.45)
	_glow_rect.add_child(glow_poly)

	# Second larger, fainter glow layer
	var glow2 = Polygon2D.new()
	var g2pts: PackedVector2Array = []
	for i in 20:
		var angle = TAU * i / 20.0
		var rx = (DOOR_W + 44) / 2.0
		var ry = (DOOR_H + 44) / 2.0
		g2pts.append(Vector2(cos(angle) * rx, sin(angle) * ry))
	glow2.polygon = g2pts
	glow2.color = Color(0.7, 0.1, 0.9, 0.2)
	_glow_rect.add_child(glow2)
	add_child(_glow_rect)

	# --- Portal body — oval shape, bright magenta/purple ---
	_portal_rect = Node2D.new()
	_portal_rect.z_index = 1
	var portal_poly = Polygon2D.new()
	var ppts: PackedVector2Array = []
	for i in 16:
		var angle = TAU * i / 16.0
		ppts.append(Vector2(cos(angle) * DOOR_W / 2.0, sin(angle) * DOOR_H / 2.0))
	portal_poly.polygon = ppts
	portal_poly.color = Color(0.6, 0.1, 0.9, 0.9)  # Brighter purple
	_portal_rect.add_child(portal_poly)
	add_child(_portal_rect)

	# Swirling inner rings — brighter colors
	for ring_i in 3:
		var ring = Polygon2D.new()
		var rpts: PackedVector2Array = []
		var r_scale = 0.75 - ring_i * 0.2
		for i in 14:
			var angle = TAU * i / 14.0
			rpts.append(Vector2(cos(angle) * DOOR_W / 2.0 * r_scale, sin(angle) * DOOR_H / 2.0 * r_scale))
		ring.polygon = rpts
		ring.color = Color(0.7 + ring_i * 0.1, 0.3 + ring_i * 0.15, 1.0, 0.4 + ring_i * 0.15)
		_portal_rect.add_child(ring)

	# Bright core center — white/pink
	var core = Polygon2D.new()
	var cpts: PackedVector2Array = []
	for i in 10:
		var angle = TAU * i / 10.0
		cpts.append(Vector2(cos(angle) * 6, sin(angle) * 8))
	core.polygon = cpts
	core.color = Color(1.0, 0.85, 1.0, 0.95)
	_portal_rect.add_child(core)

	# --- Orbiting sparkle particles ---
	_sparkles.clear()
	for i in 10:
		var spark = Polygon2D.new()
		var spts: PackedVector2Array = []
		for j in 4:
			var a = TAU * j / 4.0
			spts.append(Vector2(cos(a), sin(a)) * 2.5)
		spark.polygon = spts
		spark.color = Color(1.0, 0.7, 1.0, 0.85)
		spark.z_index = 2
		var base_angle = TAU * i / 10.0
		spark.position = Vector2(cos(base_angle) * DOOR_W / 2.0, sin(base_angle) * DOOR_H / 2.0)
		add_child(spark)
		_sparkles.append(spark)

	# --- "SECRET DOOR" floating label — larger, brighter ---
	_label = Label.new()
	_label.text = "SECRET DOOR"
	_label.add_theme_font_size_override("font_size", 10)
	_label.add_theme_color_override("font_color", Color(1.0, 0.7, 1.0))
	_label.add_theme_color_override("font_shadow_color", Color(0.3, 0.0, 0.4, 0.9))
	_label.add_theme_constant_override("shadow_offset_x", 1)
	_label.add_theme_constant_override("shadow_offset_y", 1)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.position = Vector2(-36, -DOOR_H / 2.0 - 16)
	_label.z_index = 3
	add_child(_label)

func _on_body_entered(body: Node) -> void:
	if _used:
		return
	if not body.is_in_group("player"):
		return

	if GameState.use_key("secret"):
		_use_door()

func _use_door() -> void:
	_used = true
	emit_signal("door_used")

	# Flash bright
	modulate = Color(2.0, 2.0, 2.0, 1.0)

	var tw = create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.6)
	tw.tween_callback(func():
		get_tree().change_scene_to_file("res://scenes/secret_room.tscn")
	)
