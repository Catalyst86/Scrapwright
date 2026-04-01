extends Area2D

# ============================================================
# DigHole — Trap hole dug by the puppy during combat
# Enemies that walk over it get stunned and take damage
# ============================================================

const STUN_DURATION = 3.0
const HOLE_DAMAGE = 15
const MAX_CATCHES = 4  # Stun up to 4 enemies before collapsing

var _catch_count: int = 0

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2  # Detect enemies only
	monitoring = true
	monitorable = false
	z_index = -1  # Below everything

	# Dark oval visual (the hole)
	var hole_bg = ColorRect.new()
	hole_bg.color = Color(0.06, 0.04, 0.03, 0.9)
	hole_bg.size = Vector2(22, 14)
	hole_bg.position = Vector2(-11, -7)
	add_child(hole_bg)

	# Dirt ring around the hole
	var dirt_ring = ColorRect.new()
	dirt_ring.color = Color(0.35, 0.25, 0.15, 0.7)
	dirt_ring.size = Vector2(26, 18)
	dirt_ring.position = Vector2(-13, -9)
	dirt_ring.z_index = -1
	add_child(dirt_ring)

	# Collision shape
	var col = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = 14.0
	col.shape = circle
	add_child(col)

	body_entered.connect(_on_body_entered)

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
