extends EnemyBase

# Ember Drake — Stage 3 Mid-Boss (Wave 35)
# Fast, fire-breathing lizard. Flame cone, charge attack, leaves fire trail.

var flame_breath_timer: float = 0.0
var charge_timer: float = 0.0
var fire_trail_timer: float = 0.0
var _is_charging: bool = false
var _charge_dir: Vector2 = Vector2.ZERO
var _charge_time: float = 0.0
var _charge_hit_player: bool = false

const FLAME_BREATH_INTERVAL = 3.0
const FLAME_BREATH_RANGE = 70.0
const FLAME_BREATH_ANGLE = 0.6  # radians, ~35 degree cone
const FLAME_BREATH_DAMAGE = 10

const CHARGE_INTERVAL = 6.0
const CHARGE_SPEED = 180.0
const CHARGE_DURATION = 0.8
const CHARGE_DAMAGE = 20

const FIRE_TRAIL_INTERVAL = 0.15

func _ready() -> void:
	enemy_type       = "ember_drake"
	max_health       = 550
	move_speed       = 45.0
	damage           = 22
	xp_value         = 100
	contact_cooldown = 1.0
	super._ready()
	if health_bar:
		health_bar.visible = true

func _physics_process(delta: float) -> void:
	if is_dead: return

	if _is_charging:
		_charge_time -= delta
		velocity = _charge_dir * CHARGE_SPEED
		fire_trail_timer += delta
		if fire_trail_timer >= FIRE_TRAIL_INTERVAL:
			fire_trail_timer = 0.0
			_spawn_fire_dot()
		if _charge_time <= 0:
			_is_charging = false
			velocity = Vector2.ZERO
		# Check if we hit the player during charge (once per charge)
		if not _charge_hit_player and player_ref and is_instance_valid(player_ref):
			var dist = global_position.distance_to(player_ref.global_position)
			if dist < 18.0 and player_ref.has_method("take_damage"):
				player_ref.take_damage(CHARGE_DAMAGE, self)
				_charge_hit_player = true
		move_and_slide()
		return

	flame_breath_timer += delta
	charge_timer += delta

	if flame_breath_timer >= FLAME_BREATH_INTERVAL:
		flame_breath_timer = 0.0
		_flame_breath()

	if charge_timer >= CHARGE_INTERVAL:
		charge_timer = 0.0
		_start_charge()

	super._physics_process(delta)

func _flame_breath() -> void:
	if not player_ref or not is_instance_valid(player_ref): return
	var dir_to_player = (player_ref.global_position - global_position).normalized()

	# Visual — flame cone lines
	for i in 8:
		var spread = randf_range(-FLAME_BREATH_ANGLE, FLAME_BREATH_ANGLE)
		var flame_dir = dir_to_player.rotated(spread)
		var length = randf_range(FLAME_BREATH_RANGE * 0.5, FLAME_BREATH_RANGE)
		var line = Line2D.new()
		line.width = randf_range(2.0, 4.0)
		line.default_color = Color(1.0, randf_range(0.3, 0.7), 0.1, 0.8)
		line.z_index = 5
		line.add_point(global_position + dir_to_player * 8.0)
		line.add_point(global_position + flame_dir * length)
		var parent = get_parent()
		if parent:
			parent.add_child(line)
			var tw = line.create_tween()
			tw.tween_property(line, "modulate:a", 0.0, 0.3)
			tw.tween_callback(line.queue_free)

	# Damage player if in cone
	var dist = global_position.distance_to(player_ref.global_position)
	if dist < FLAME_BREATH_RANGE:
		var angle_to_player = global_position.direction_to(player_ref.global_position).angle()
		var facing_angle = dir_to_player.angle()
		var angle_diff = abs(angle_difference(angle_to_player, facing_angle))
		if angle_diff < FLAME_BREATH_ANGLE:
			if player_ref.has_method("take_damage"):
				player_ref.take_damage(FLAME_BREATH_DAMAGE, self)

func _start_charge() -> void:
	if not player_ref or not is_instance_valid(player_ref): return
	_is_charging = true
	_charge_hit_player = false
	_charge_dir = (player_ref.global_position - global_position).normalized()
	_charge_time = CHARGE_DURATION
	fire_trail_timer = 0.0

	# Warning flash
	if sprite:
		var tw = create_tween()
		tw.tween_property(sprite, "modulate", Color(1.5, 0.8, 0.3), 0.1)
		tw.tween_property(sprite, "modulate", Color.WHITE, 0.2)

	# Warning text
	var warn = Label.new()
	warn.text = "CHARGE!"
	warn.add_theme_font_size_override("font_size", 8)
	warn.add_theme_color_override("font_color", Color(1.0, 0.5, 0.1))
	warn.position = global_position + Vector2(-14, -22)
	warn.z_index = 10
	var parent2 = get_parent()
	if parent2:
		parent2.add_child(warn)
		var tw2 = warn.create_tween()
		tw2.tween_property(warn, "modulate:a", 0.0, 0.5)
		tw2.tween_callback(warn.queue_free)

func _spawn_fire_dot() -> void:
	_play_attack_anim()
	var dot = Area2D.new()
	dot.collision_layer = 0
	dot.collision_mask = 1
	dot.global_position = global_position
	dot.z_index = -1

	# Visual — animated fire circle
	var visual = Polygon2D.new()
	var pts: PackedVector2Array = []
	for i in 8:
		var angle = TAU * i / 8.0
		var r = randf_range(4.0, 7.0)
		pts.append(Vector2(cos(angle), sin(angle)) * r)
	visual.polygon = pts
	visual.color = Color(1.0, 0.5, 0.1, 0.7)
	dot.add_child(visual)

	# Inner glow
	var inner = Polygon2D.new()
	var pts2: PackedVector2Array = []
	for i in 6:
		var angle = TAU * i / 6.0
		pts2.append(Vector2(cos(angle), sin(angle)) * 3.0)
	inner.polygon = pts2
	inner.color = Color(1.0, 0.9, 0.3, 0.6)
	dot.add_child(inner)

	var col = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 6.0
	col.shape = shape
	dot.add_child(col)

	dot.body_entered.connect(func(body):
		if body.is_in_group("player") and body.has_method("take_damage"):
			body.take_damage(5, self)
	)

	var parent = get_parent()
	if not parent: return
	parent.add_child(dot)

	# Fade and delete after 2.5s
	var tw = dot.create_tween()
	tw.tween_interval(2.0)
	tw.tween_property(dot, "modulate:a", 0.0, 0.5)
	tw.tween_callback(dot.queue_free)
