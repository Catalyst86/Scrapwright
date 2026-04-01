extends Area2D

# ============================================================
# KeyPickup — Dropped by enemies, collected by player
# ============================================================

@export var key_tier: String = "bronze"

var collected: bool = false
var scatter_vel: Vector2 = Vector2.ZERO
var player_ref: Node = null
var life: float = 20.0
var _bob_time: float = 0.0

const TIER_COLORS = {
	"bronze": Color(0.65, 0.45, 0.2),
	"silver": Color(0.75, 0.75, 0.8),
	"gold":   Color(1.0, 0.85, 0.15),
	"secret": Color(0.6, 0.2, 0.85),
}

const MAGNET_RANGE = 60.0

var _sprite: Sprite2D = null
var _fallback: Polygon2D = null

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	set_deferred("monitoring", true)
	set_deferred("monitorable", false)

	# Random scatter on spawn
	var angle = randf() * TAU
	scatter_vel = Vector2(cos(angle), sin(angle)) * randf_range(18, 40)

	_bob_time = randf() * TAU  # randomize starting phase

	# Try to load sprite
	_sprite = get_node_or_null("Sprite2D")
	var tex_path = "res://assets/sprites/items/key_%s.png" % key_tier
	if ResourceLoader.exists(tex_path) and _sprite:
		_sprite.texture = load(tex_path)
	else:
		# Fallback: colored diamond
		if _sprite:
			_sprite.visible = false
		_fallback = Polygon2D.new()
		var color = TIER_COLORS.get(key_tier, Color.WHITE)
		_fallback.color = color
		_fallback.polygon = PackedVector2Array([
			Vector2(0, -5), Vector2(4, 0), Vector2(0, 5), Vector2(-4, 0)
		])
		add_child(_fallback)

	player_ref = get_tree().get_first_node_in_group("player")

func _process(delta: float) -> void:
	if collected:
		return

	# Scatter decelerate
	if scatter_vel.length() > 0.5:
		scatter_vel = scatter_vel.move_toward(Vector2.ZERO, 90.0 * delta)
		global_position += scatter_vel * delta

	# Bobbing animation
	_bob_time += delta * 4.0
	var bob_offset = sin(_bob_time) * 2.5
	if _sprite and _sprite.visible:
		_sprite.offset.y = bob_offset
	if _fallback:
		_fallback.offset.y = bob_offset

	# Magnet: float toward player when within range
	if player_ref and is_instance_valid(player_ref):
		var dist = global_position.distance_to(player_ref.global_position)
		if dist < MAGNET_RANGE:
			var dir = (player_ref.global_position - global_position).normalized()
			global_position += dir * 140.0 * delta

	# Lifetime
	life -= delta
	if life < 4.0:
		modulate.a = life / 4.0
	if life <= 0:
		queue_free()

func _on_body_entered(body: Node) -> void:
	if collected:
		return
	if body.is_in_group("player"):
		_collect()

func _collect() -> void:
	collected = true
	GameState.add_key(key_tier)

	# Float text
	var color = TIER_COLORS.get(key_tier, Color.WHITE)
	var popup = Label.new()
	popup.text = "+1 %s key" % key_tier
	popup.add_theme_font_size_override("font_size", 7)
	popup.modulate = color
	popup.global_position = global_position + Vector2(-18, -12)
	var pickup_parent = get_parent()
	if not pickup_parent: return
	pickup_parent.add_child(popup)
	var tw = get_tree().create_tween()
	tw.tween_property(popup, "position:y", popup.position.y - 16, 0.55)
	tw.parallel().tween_property(popup, "modulate:a", 0.0, 0.55)
	tw.tween_callback(popup.queue_free)
	queue_free()
