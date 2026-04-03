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

var _sprite: AnimatedSprite2D = null
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
	# Animated XP orb sprite — white orb with red star orbiting
	var sheet_tex = load("res://assets/sprites/ui/xp_orb_sheet.png")
	if not sheet_tex:
		return
	var frame_count = 9
	var frame_w = 32
	var sf = SpriteFrames.new()
	sf.remove_animation("default")
	sf.add_animation("spin")
	sf.set_animation_speed("spin", 10.0)
	sf.set_animation_loop("spin", true)
	for i in range(frame_count):
		var atlas = AtlasTexture.new()
		atlas.atlas = sheet_tex
		atlas.region = Rect2(i * frame_w, 0, frame_w, frame_w)
		sf.add_frame("spin", atlas)
	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = sf
	_sprite.scale = Vector2(0.5, 0.5)
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.play("spin")
	add_child(_sprite)

func _process(delta: float) -> void:
	if collected:
		return

	_time += delta

	# Scatter deceleration
	if scatter_vel.length() > 0.5:
		scatter_vel = scatter_vel.move_toward(Vector2.ZERO, 90.0 * delta)
		global_position += scatter_vel * delta

	# XP orbs always have a base attraction range — Fetch! upgrade extends it
	if _player_ref and is_instance_valid(_player_ref):
		var magnet_level = GameState.permanent.get("pickup_magnet_level", 0)
		var base_range = 20.0  # XP always attracts within 20px
		var magnet_range = base_range + magnet_level * 12.0  # Fetch adds +12px per level
		var dist = global_position.distance_to(_player_ref.global_position)
		if dist < magnet_range:
			var pull_speed = 150.0 + magnet_level * 20.0  # Fetch also makes pull faster
			var dir = (_player_ref.global_position - global_position).normalized()
			global_position += dir * pull_speed * delta

	# Lifetime countdown
	lifetime -= delta
	if lifetime <= 0:
		queue_free()
		return

	# Flashing when about to expire (last 3 seconds)
	if lifetime < 3.0 and _sprite:
		_flash_timer += delta
		var flash_rate = 1.0 / maxf(0.1, lifetime * 0.3)
		_sprite.visible = fmod(_flash_timer * flash_rate, 1.0) < 0.5

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
	# Hide the orb visual
	if _sprite: _sprite.visible = false
	# Animate popup floating up and fading
	var tw = create_tween()
	tw.tween_property(popup, "position:y", popup.position.y - 18.0, 0.5).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(popup, "modulate:a", 0.0, 0.5).set_delay(0.2)
	tw.tween_callback(queue_free)
