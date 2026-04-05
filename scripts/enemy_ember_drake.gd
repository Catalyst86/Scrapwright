extends EnemyBase

# Ember Drake — Stage 3 Mid-Boss (Wave 35)
# Fast, fire-breathing lizard. Flame cone, charge attack, leaves fire trail.
# Phase 1: Flame breath cone + charge attack with fire DOT trail
# Phase 2 "METEOR RAIN": Moves to center, spawns warning circles, delayed AoE damage
# Phase 3 "INFERNO": Permanent fire aura, doubled charge speed, repeating meteor rain

var flame_breath_timer: float = 0.0
var charge_timer: float = 0.0
var fire_trail_timer: float = 0.0
var _is_charging: bool = false
var _charge_dir: Vector2 = Vector2.ZERO
var _charge_time: float = 0.0
var _charge_hit_player: bool = false

# Phase 2/3
var _meteor_timer: float = 0.0
var _meteor_active: bool = false
var _fire_aura: Area2D = null
var _fire_aura_tick_timer: float = 0.0

const FLAME_BREATH_INTERVAL = 3.0
const FLAME_BREATH_RANGE = 70.0
const FLAME_BREATH_ANGLE = 0.6  # radians, ~35 degree cone
const FLAME_BREATH_DAMAGE = 10

const CHARGE_INTERVAL = 6.0
const CHARGE_SPEED = 180.0
const CHARGE_DURATION = 0.8
const CHARGE_DAMAGE = 20

const FIRE_TRAIL_INTERVAL = 0.15

# Meteor rain constants
const METEOR_WARNING_DELAY = 1.5
const METEOR_DAMAGE = 20
const METEOR_RADIUS = 40.0
const METEOR_COUNT_P2 = 6
const METEOR_COUNT_P3 = 8
const METEOR_REPEAT_INTERVAL = 15.0

# Fire aura constants (Phase 3)
const FIRE_AURA_RADIUS = 60.0
const FIRE_AURA_DPS = 5
const FIRE_AURA_TICK = 0.5

func _ready() -> void:
	enemy_type       = "ember_drake"
	max_health       = 1100
	move_speed       = 45.0
	damage           = 22
	xp_value         = 100
	contact_cooldown = 1.0
	_is_boss = true
	super._ready()
	if health_bar:
		health_bar.visible = true

func _physics_process(delta: float) -> void:
	if is_dead or _phase_transitioning: return

	# Fire aura tick (Phase 3)
	if _fire_aura and is_instance_valid(_fire_aura):
		_fire_aura.global_position = global_position
		_fire_aura_tick_timer += delta
		if _fire_aura_tick_timer >= FIRE_AURA_TICK:
			_fire_aura_tick_timer = 0.0
			_tick_fire_aura()

	# Meteor rain repeat timer (Phase 2+)
	if _boss_phase >= 2 and not _meteor_active:
		_meteor_timer += delta
		var interval = METEOR_REPEAT_INTERVAL
		if _meteor_timer >= interval:
			_meteor_timer = 0.0
			_start_meteor_rain()

	if _is_charging:
		_charge_time -= delta
		var speed_mult = 2.0 if _boss_phase >= 3 else 1.0
		velocity = _charge_dir * CHARGE_SPEED * speed_mult
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

# --- Phase Transitions ---

func _on_phase_change(new_phase: int) -> void:
	super._on_phase_change(new_phase)
	match new_phase:
		2:
			_show_boss_warning("INCOMING!")
			_start_meteor_rain()
		3:
			_show_boss_warning("INFERNO!")
			_create_fire_aura()
			_start_meteor_rain()

# --- Meteor Rain ---

func _start_meteor_rain() -> void:
	if _meteor_active or is_dead: return
	_meteor_active = true

	var center = _get_arena_center()
	# Move drake toward center
	var tw = create_tween()
	tw.tween_property(self, "global_position", center, 0.6).set_ease(Tween.EASE_IN_OUT)

	var count = METEOR_COUNT_P3 if _boss_phase >= 3 else METEOR_COUNT_P2
	var parent = get_parent()
	if not parent:
		_meteor_active = false
		return

	# Spawn warning circles at random positions around the arena center
	var warnings: Array = []
	for i in count:
		var offset = Vector2(randf_range(-120, 120), randf_range(-90, 90))
		var pos = center + offset
		var warning = _create_warning_circle(pos, parent)
		warnings.append({"node": warning, "pos": pos})

	# After delay, deal damage at each warning position
	await get_tree().create_timer(METEOR_WARNING_DELAY).timeout
	if is_dead or not is_inside_tree():
		_meteor_active = false
		return

	for w in warnings:
		if not is_instance_valid(w["node"]): continue
		var pos: Vector2 = w["pos"]
		# Remove warning circle
		w["node"].queue_free()
		# Spawn impact visual
		_spawn_meteor_impact(pos, parent)
		# Damage player if in radius
		if player_ref and is_instance_valid(player_ref):
			var dist = pos.distance_to(player_ref.global_position)
			if dist < METEOR_RADIUS:
				if player_ref.has_method("take_damage"):
					player_ref.take_damage(METEOR_DAMAGE, self)

	_meteor_active = false

func _create_warning_circle(pos: Vector2, parent: Node) -> Node2D:
	var warning = Node2D.new()
	warning.global_position = pos
	warning.z_index = -1

	# Try to use warning_circle.png, fallback to procedural
	var tex_path = "res://assets/sprites/boss_fx/warning_circle.png"
	if ResourceLoader.exists(tex_path):
		var spr = Sprite2D.new()
		spr.texture = load(tex_path)
		spr.scale = Vector2(1.5, 1.5)
		spr.modulate = Color(1.0, 0.3, 0.1, 0.6)
		warning.add_child(spr)
	else:
		# Procedural warning circle
		var circle = _make_warning_poly(METEOR_RADIUS, 16)
		circle.color = Color(1.0, 0.3, 0.1, 0.35)
		warning.add_child(circle)
		# Inner ring
		var inner = _make_warning_poly(METEOR_RADIUS * 0.6, 12)
		inner.color = Color(1.0, 0.5, 0.1, 0.5)
		warning.add_child(inner)

	parent.add_child(warning)

	# Pulse animation
	var pulse = warning.create_tween().set_loops(3)
	pulse.tween_property(warning, "modulate:a", 1.0, 0.25)
	pulse.tween_property(warning, "modulate:a", 0.4, 0.25)

	return warning

func _make_warning_poly(radius: float, segments: int) -> Polygon2D:
	var poly = Polygon2D.new()
	var pts: PackedVector2Array = []
	for i in segments:
		var angle = TAU * i / float(segments)
		pts.append(Vector2(cos(angle), sin(angle)) * radius)
	poly.polygon = pts
	return poly

func _spawn_meteor_impact(pos: Vector2, parent: Node) -> void:
	# Orange-red flash at impact point
	var impact = Node2D.new()
	impact.global_position = pos
	impact.z_index = 5

	var flash = _make_warning_poly(METEOR_RADIUS * 0.8, 12)
	flash.color = Color(1.0, 0.4, 0.0, 0.8)
	impact.add_child(flash)

	var core = _make_warning_poly(METEOR_RADIUS * 0.4, 8)
	core.color = Color(1.0, 0.9, 0.3, 0.9)
	impact.add_child(core)

	parent.add_child(impact)

	var tw = impact.create_tween()
	tw.tween_property(impact, "scale", Vector2(1.3, 1.3), 0.15)
	tw.tween_property(impact, "modulate:a", 0.0, 0.35)
	tw.tween_callback(impact.queue_free)

# --- Fire Aura (Phase 3) ---

func _create_fire_aura() -> void:
	if _fire_aura and is_instance_valid(_fire_aura): return

	_fire_aura = Area2D.new()
	_fire_aura.collision_layer = 0
	_fire_aura.collision_mask = 1
	_fire_aura.monitoring = true
	_fire_aura.global_position = global_position

	var col = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = FIRE_AURA_RADIUS
	col.shape = shape
	_fire_aura.add_child(col)

	# Visual — pulsing orange ring
	var vis = _make_warning_poly(FIRE_AURA_RADIUS, 20)
	vis.color = Color(1.0, 0.3, 0.0, 0.2)
	_fire_aura.add_child(vis)

	var inner_vis = _make_warning_poly(FIRE_AURA_RADIUS * 0.7, 16)
	inner_vis.color = Color(1.0, 0.5, 0.1, 0.15)
	_fire_aura.add_child(inner_vis)

	_fire_aura.z_index = -1
	var parent = get_parent()
	if parent:
		parent.add_child(_fire_aura)

	# Pulse animation
	var pulse = _fire_aura.create_tween().set_loops()
	pulse.tween_property(_fire_aura, "scale", Vector2(1.1, 1.1), 0.6).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(_fire_aura, "scale", Vector2(0.95, 0.95), 0.6).set_trans(Tween.TRANS_SINE)

func _tick_fire_aura() -> void:
	if not _fire_aura or not is_instance_valid(_fire_aura): return
	if not player_ref or not is_instance_valid(player_ref): return
	var dist = global_position.distance_to(player_ref.global_position)
	if dist < FIRE_AURA_RADIUS:
		if player_ref.has_method("take_damage"):
			# DPS scaled to tick rate: 5 dps * 0.5s tick = ~2-3 per tick
			var tick_dmg = ceili(FIRE_AURA_DPS * FIRE_AURA_TICK)
			player_ref.take_damage(tick_dmg, self)

# --- Original Attacks ---

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

func _die() -> void:
	if is_instance_valid(_fire_aura): _fire_aura.queue_free()
	_fire_aura = null
	super._die()

func _get_arena_center() -> Vector2:
	if player_ref and is_instance_valid(player_ref):
		var cam = player_ref.get_node_or_null("Camera2D")
		if cam: return cam.global_position
	return Vector2(480, 270)
