extends CharacterBody2D

# Tutorial walker — enemy that walks toward the player.
# Used in the dig-trap tutorial step. Has stun() for dig hole compatibility.

signal died(xp_reward)

@export var max_health: int = 40
@export var move_speed: float = 35.0

var health: int = 0
var is_dead: bool = false
var is_stunned: bool = false
var knockback: Vector2 = Vector2.ZERO

var _stun_timer: float = 0.0
var _dot: ColorRect = null
var _anim_time: float = 0.0
var _player_ref: Node = null

func _ready() -> void:
	health = max_health
	add_to_group("enemies")
	_player_ref = get_tree().get_first_node_in_group("player")
	_build_visual()

func _build_visual() -> void:
	# Outer ring (darker green)
	var ring = ColorRect.new()
	ring.color = Color(0.15, 0.4, 0.15)
	ring.size = Vector2(24, 24)
	ring.position = Vector2(-12, -12)
	ring.z_index = -1
	add_child(ring)
	# Inner body (green)
	_dot = ColorRect.new()
	_dot.color = Color(0.25, 0.7, 0.25)
	_dot.size = Vector2(20, 20)
	_dot.position = Vector2(-10, -10)
	add_child(_dot)

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	_anim_time += delta

	# Idle bob
	if _dot:
		_dot.scale = Vector2.ONE * (1.0 + sin(_anim_time * 4.0) * 0.08)

	if is_stunned:
		_stun_timer -= delta
		if _stun_timer <= 0:
			is_stunned = false
		return

	# Move toward player
	if _player_ref and is_instance_valid(_player_ref):
		var dir = (_player_ref.global_position - global_position).normalized()
		velocity = dir * move_speed
		move_and_slide()

func take_damage(amount: int, _source_pos = null) -> void:
	if is_dead:
		return
	health -= amount
	if _dot:
		_dot.color = Color.WHITE
		var tw = create_tween()
		tw.tween_property(_dot, "color", Color(0.25, 0.7, 0.25), 0.12)
	if health <= 0:
		_die()

func stun(duration: float) -> void:
	is_stunned = true
	_stun_timer = duration
	# Visual feedback: flash yellow
	if _dot:
		var tw = create_tween()
		tw.tween_property(_dot, "color", Color(1.0, 0.9, 0.3), 0.1)
		tw.tween_property(_dot, "color", Color(0.4, 0.4, 0.3), 0.2)

func _die() -> void:
	is_dead = true
	emit_signal("died", 0)
	var tw = create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.35).set_ease(Tween.EASE_IN)
	tw.tween_callback(queue_free)
