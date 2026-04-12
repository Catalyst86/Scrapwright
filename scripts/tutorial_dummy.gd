extends CharacterBody2D

# Minimal training dummy for the tutorial — stands still, takes damage, dies.

signal died(xp_reward)

@export var max_health: int = 15

var health: int = 0
var is_dead: bool = false
var knockback: Vector2 = Vector2.ZERO
var is_stunned: bool = false

var _dot: ColorRect = null
var _anim_time: float = 0.0

func _ready() -> void:
	health = max_health
	add_to_group("enemies")
	_build_visual()

func _build_visual() -> void:
	_dot = ColorRect.new()
	_dot.color = Color(0.85, 0.25, 0.25)
	_dot.size = Vector2(24, 24)
	_dot.position = Vector2(-12, -12)
	add_child(_dot)
	# Outline ring
	var ring = ColorRect.new()
	ring.color = Color(0.5, 0.15, 0.15)
	ring.size = Vector2(28, 28)
	ring.position = Vector2(-14, -14)
	ring.z_index = -1
	add_child(ring)

func _process(delta: float) -> void:
	if is_dead:
		return
	_anim_time += delta
	if _dot:
		_dot.scale = Vector2.ONE * (1.0 + sin(_anim_time * 3.0) * 0.06)

func take_damage(amount: int, _source_pos = null) -> void:
	if is_dead:
		return
	health -= amount
	# Flash white
	if _dot:
		_dot.color = Color.WHITE
		var tw = create_tween()
		tw.tween_property(_dot, "color", Color(0.85, 0.25, 0.25), 0.12)
	if health <= 0:
		_die()

func stun(_duration: float) -> void:
	pass  # Already stationary — nothing to do

func _die() -> void:
	is_dead = true
	emit_signal("died", 0)
	# Fade out
	var tw = create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.35).set_ease(Tween.EASE_IN)
	tw.tween_callback(queue_free)
