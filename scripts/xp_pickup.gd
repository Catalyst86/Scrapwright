extends Area2D

# ============================================================
# XPPickup — Dropped by enemies on death. Player must collect
# before it expires. White glint core + red orbiting star.
# Flashes faster as expiration approaches.
# ============================================================

var xp_amount: int = 10
var collected: bool = false
var scatter_vel: Vector2 = Vector2.ZERO
var lifetime: float = 8.0
var _time: float = 0.0
var _flash_timer: float = 0.0

var _core: ColorRect = null
var _star: ColorRect = null
var _player_ref: Node2D = null

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	# Random scatter on spawn
	var angle = randf() * TAU
	scatter_vel = Vector2(cos(angle), sin(angle)) * randf_range(15.0, 35.0)
	# Build visuals
	_build_visual()
	# Find player
	_player_ref = get_tree().get_first_node_in_group("player")

func _build_visual() -> void:
	# White glint core (4x4)
	_core = ColorRect.new()
	_core.color = Color(1.0, 1.0, 1.0, 0.95)
	_core.size = Vector2(4, 4)
	_core.position = Vector2(-2, -2)
	_core.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_core)

	# Red orbiting star (3x3)
	_star = ColorRect.new()
	_star.color = Color(1.0, 0.2, 0.2, 0.9)
	_star.size = Vector2(3, 3)
	_star.position = Vector2(-1.5, -1.5)
	_star.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_star)

func _process(delta: float) -> void:
	if collected:
		return

	_time += delta

	# Scatter deceleration
	if scatter_vel.length() > 0.5:
		scatter_vel = scatter_vel.move_toward(Vector2.ZERO, 90.0 * delta)
		global_position += scatter_vel * delta

	# Magnet attraction (same logic as material_pickup.gd)
	if _player_ref and is_instance_valid(_player_ref):
		var magnet_level = GameState.permanent.get("pickup_magnet_level", 0)
		var has_magnet = GameState.permanent.get("bag_level", 0) >= 5 or magnet_level > 0
		if not has_magnet and _player_ref.has_meta("has_magnet"):
			has_magnet = true
		if has_magnet:
			var base_range = 80.0
			var magnet_range = base_range * (1.0 + magnet_level * 0.15)
			var dist = global_position.distance_to(_player_ref.global_position)
			if dist < magnet_range:
				var dir = (_player_ref.global_position - global_position).normalized()
				global_position += dir * 130.0 * delta

	# Orbiting red star
	if _star:
		var orbit_radius = 6.0
		var orbit_speed = 4.0
		_star.position = Vector2(
			cos(_time * orbit_speed) * orbit_radius - 1.5,
			sin(_time * orbit_speed) * orbit_radius - 1.5
		)

	# Gentle pulse on core
	if _core:
		var pulse = 0.7 + sin(_time * 5.0) * 0.3
		_core.color.a = pulse

	# Lifetime countdown
	lifetime -= delta
	if lifetime <= 0:
		queue_free()
		return

	# Flashing when about to expire (last 3 seconds)
	if lifetime < 3.0:
		_flash_timer += delta
		# Flash rate accelerates as expiration approaches
		var flash_rate = 1.0 / maxf(0.1, lifetime * 0.3)
		if fmod(_flash_timer * flash_rate, 1.0) < 0.5:
			if _core: _core.visible = true
			if _star: _star.visible = true
		else:
			if _core: _core.visible = false
			if _star: _star.visible = false

func _on_body_entered(body: Node2D) -> void:
	if collected:
		return
	if not body.is_in_group("player"):
		return
	_collect()

func _collect() -> void:
	collected = true
	GameState.gain_xp(xp_amount)
	# Floating "+XP" popup
	var popup = Label.new()
	popup.text = "+%d XP" % xp_amount
	popup.add_theme_font_size_override("font_size", 9)
	popup.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	popup.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	popup.add_theme_constant_override("outline_size", 2)
	popup.position = Vector2(-12, -14)
	popup.z_index = 50
	add_child(popup)
	# Hide the orb visuals
	if _core: _core.visible = false
	if _star: _star.visible = false
	# Animate popup floating up and fading
	var tw = create_tween()
	tw.tween_property(popup, "position:y", popup.position.y - 18.0, 0.5).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(popup, "modulate:a", 0.0, 0.5).set_delay(0.2)
	tw.tween_callback(queue_free)
