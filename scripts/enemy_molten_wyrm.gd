extends EnemyBase

# Molten Wyrm — Stage 3 Boss
# Charges at player, leaves lava pools, fires spread projectiles.
# Phase 1: Charge + lava spread + lava pools
# Phase 2 "BURROW STRIKE": Goes invisible, erupts at player position 3x in sequence
# Phase 3 "ERUPTION": 4 lava geysers at cardinal offsets, burrow strikes repeat with 4 strikes

var charge_timer: float = 0.0
var lava_spread_timer: float = 0.0
var is_charging: bool = false
var charge_time_left: float = 0.0
var charge_dir: Vector2 = Vector2.ZERO
var base_speed: float = 35.0

# Phase 2/3
var _burrow_timer: float = 0.0
var _burrow_active: bool = false
var _geyser_nodes: Array = []

const CHARGE_INTERVAL = 5.0
const CHARGE_DURATION = 1.5
const CHARGE_SPEED_MULT = 2.0
const LAVA_POOL_DURATION = 4.0
const LAVA_DPS = 5
const LAVA_DROP_INTERVAL = 0.25  # drop lava pools during charge

const LAVA_SPREAD_INTERVAL = 7.0
const LAVA_PROJ_COUNT = 3
const LAVA_PROJ_SPEED = 80.0
const LAVA_SPREAD_ANGLE = 0.4  # radians between each projectile

# Burrow strike constants
const BURROW_STRIKE_DELAY = 2.0
const BURROW_STRIKE_DAMAGE = 30
const BURROW_STRIKE_RADIUS = 50.0
const BURROW_STRIKE_COUNT_P2 = 3
const BURROW_STRIKE_COUNT_P3 = 4
const BURROW_REPEAT_INTERVAL = 15.0

# Geyser constants (Phase 3)
const GEYSER_OFFSET = 100.0
const GEYSER_DPS = 8
const GEYSER_RADIUS = 20.0
const GEYSER_TICK = 0.5

var lava_drop_cooldown: float = 0.0
var _proj_scene: PackedScene = null
var _geyser_tick_timer: float = 0.0

func _ready() -> void:
	enemy_type       = "molten_wyrm"
	max_health       = 1600
	move_speed       = 35.0
	damage           = 30
	xp_value         = 150
	contact_cooldown = 1.0
	base_speed       = move_speed
	_proj_scene = load("res://scenes/enemy_projectile.tscn")
	super._ready()
	if health_bar:
		health_bar.visible = true

func _physics_process(delta: float) -> void:
	if is_dead or _phase_transitioning:
		return

	# Geyser tick (Phase 3)
	if _geyser_nodes.size() > 0:
		_geyser_tick_timer += delta
		if _geyser_tick_timer >= GEYSER_TICK:
			_geyser_tick_timer = 0.0
			_tick_geysers()

	# Burrow strike repeat timer (Phase 2+)
	if _boss_phase >= 2 and not _burrow_active:
		_burrow_timer += delta
		if _burrow_timer >= BURROW_REPEAT_INTERVAL:
			_burrow_timer = 0.0
			_start_burrow_sequence()

	charge_timer += delta
	lava_spread_timer += delta

	if is_charging:
		charge_time_left -= delta
		lava_drop_cooldown -= delta
		if lava_drop_cooldown <= 0:
			lava_drop_cooldown = LAVA_DROP_INTERVAL
			_drop_lava_pool()
		if charge_time_left <= 0:
			_end_charge()
	elif charge_timer >= CHARGE_INTERVAL:
		charge_timer = 0.0
		_start_charge()

	if lava_spread_timer >= LAVA_SPREAD_INTERVAL:
		lava_spread_timer = 0.0
		_lava_spread()

	super._physics_process(delta)

func _move_toward_player(delta: float) -> void:
	if is_charging:
		# Override movement during charge — go in charge direction
		velocity = charge_dir * base_speed * CHARGE_SPEED_MULT
		_update_facing()
		return
	# Normal movement
	super._move_toward_player(delta)

# --- Phase Transitions ---

func _on_phase_change(new_phase: int) -> void:
	super._on_phase_change(new_phase)
	match new_phase:
		2:
			_show_boss_warning("MOVE!")
			_start_burrow_sequence()
		3:
			_show_boss_warning("ERUPTION!")
			_spawn_lava_geysers()
			_start_burrow_sequence()

# --- Burrow Strike ---

func _start_burrow_sequence() -> void:
	if _burrow_active or is_dead: return
	_burrow_active = true
	var count = BURROW_STRIKE_COUNT_P3 if _boss_phase >= 3 else BURROW_STRIKE_COUNT_P2
	_do_burrow_strikes(count)

func _do_burrow_strikes(strikes_left: int) -> void:
	if strikes_left <= 0 or is_dead or not is_inside_tree():
		_burrow_active = false
		# Restore visibility
		if sprite: sprite.modulate.a = 1.0
		if _dot and is_instance_valid(_dot): _dot.modulate.a = 1.0
		set_collision_layer_value(2, true)
		set_collision_mask_value(1, true)
		return

	# Go invisible
	if sprite: sprite.modulate.a = 0.0
	if _dot and is_instance_valid(_dot): _dot.modulate.a = 0.0
	set_collision_layer_value(2, false)
	set_collision_mask_value(1, false)

	# Determine target position (player's current location)
	var target_pos = global_position
	if player_ref and is_instance_valid(player_ref):
		target_pos = player_ref.global_position

	# Spawn warning circle at target
	var parent = get_parent()
	if not parent:
		_burrow_active = false
		return

	var warning = _create_burrow_warning(target_pos, parent)

	# Wait for delay then erupt
	await get_tree().create_timer(BURROW_STRIKE_DELAY).timeout
	if is_dead or not is_inside_tree():
		_burrow_active = false
		return

	# Remove warning
	if is_instance_valid(warning):
		warning.queue_free()

	# Teleport to target and erupt
	global_position = target_pos

	# Spawn dust visual
	_spawn_burrow_dust(target_pos)

	# Spawn eruption impact
	_spawn_eruption_impact(target_pos, parent)

	# Damage player if in radius
	if player_ref and is_instance_valid(player_ref):
		var dist = target_pos.distance_to(player_ref.global_position)
		if dist < BURROW_STRIKE_RADIUS:
			if player_ref.has_method("take_damage"):
				player_ref.take_damage(BURROW_STRIKE_DAMAGE, self)

	# Brief visible flash to show where we emerged
	if sprite: sprite.modulate.a = 0.6
	if _dot and is_instance_valid(_dot): _dot.modulate.a = 0.6

	# Short pause between strikes
	await get_tree().create_timer(0.5).timeout
	if is_dead or not is_inside_tree():
		_burrow_active = false
		return

	_do_burrow_strikes(strikes_left - 1)

func _create_burrow_warning(pos: Vector2, parent: Node) -> Node2D:
	var warning = Node2D.new()
	warning.global_position = pos
	warning.z_index = -1

	# Use animated warning circle spritesheet
	var sheet_path = "res://assets/sprites/boss_fx/warning_circle_anim_sheet.png"
	if ResourceLoader.exists(sheet_path):
		var anim_spr = _make_anim_from_sheet(sheet_path, 48, 7, 6.0)
		anim_spr.scale = Vector2(1.5, 1.5)
		anim_spr.modulate = Color(1.0, 0.4, 0.0, 0.8)
		warning.add_child(anim_spr)
	else:
		var circle = _make_circle_poly(BURROW_STRIKE_RADIUS, 16)
		circle.color = Color(1.0, 0.4, 0.0, 0.35)
		warning.add_child(circle)

	parent.add_child(warning)

	var pulse = warning.create_tween().set_loops(4)
	pulse.tween_property(warning, "modulate:a", 1.0, 0.25)
	pulse.tween_property(warning, "modulate:a", 0.3, 0.25)

	return warning

func _spawn_burrow_dust(pos: Vector2) -> void:
	var dust = Node2D.new()
	dust.global_position = pos
	dust.z_index = 5

	# Use animated dust spritesheet
	var sheet_path = "res://assets/sprites/boss_fx/burrow_dust_anim_sheet.png"
	if ResourceLoader.exists(sheet_path):
		var anim_spr = _make_anim_from_sheet(sheet_path, 32, 5, 10.0)
		anim_spr.scale = Vector2(2.0, 2.0)
		dust.add_child(anim_spr)
	else:
		for i in 6:
			var puff = _make_circle_poly(randf_range(6, 14), 8)
			puff.color = Color(0.7, 0.5, 0.3, 0.6)
			puff.position = Vector2(randf_range(-15, 15), randf_range(-15, 15))
			dust.add_child(puff)

	var container = get_parent() if get_parent() else self
	container.add_child(dust)

	var tw = dust.create_tween()
	tw.tween_property(dust, "scale", Vector2(2.5, 2.5), 0.4)
	tw.tween_property(dust, "modulate:a", 0.0, 0.5)
	tw.tween_callback(dust.queue_free)

func _spawn_eruption_impact(pos: Vector2, parent: Node) -> void:
	var impact = Node2D.new()
	impact.global_position = pos
	impact.z_index = 4

	var flash = _make_circle_poly(BURROW_STRIKE_RADIUS * 0.8, 14)
	flash.color = Color(1.0, 0.5, 0.0, 0.7)
	impact.add_child(flash)

	var core = _make_circle_poly(BURROW_STRIKE_RADIUS * 0.4, 10)
	core.color = Color(1.0, 0.85, 0.3, 0.9)
	impact.add_child(core)

	parent.add_child(impact)

	var tw = impact.create_tween()
	tw.tween_property(impact, "scale", Vector2(1.4, 1.4), 0.2)
	tw.tween_property(impact, "modulate:a", 0.0, 0.4)
	tw.tween_callback(impact.queue_free)

# --- Lava Geysers (Phase 3) ---

func _spawn_lava_geysers() -> void:
	var center = _get_arena_center()
	var parent = get_parent()
	if not parent: return

	var offsets = [
		Vector2(GEYSER_OFFSET, 0),
		Vector2(-GEYSER_OFFSET, 0),
		Vector2(0, GEYSER_OFFSET),
		Vector2(0, -GEYSER_OFFSET),
	]

	for offset in offsets:
		var pos = center + offset
		var geyser = _create_geyser(pos)
		if geyser:
			parent.add_child(geyser)
			_geyser_nodes.append(geyser)

func _create_geyser(pos: Vector2) -> Area2D:
	var geyser = Area2D.new()
	geyser.collision_layer = 0
	geyser.collision_mask = 1
	geyser.monitoring = true
	geyser.global_position = pos
	geyser.add_to_group("boss_obstacles")

	var col = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = GEYSER_RADIUS
	col.shape = shape
	geyser.add_child(col)

	# Visual — use animated lava geyser spritesheet
	var sheet_path = "res://assets/sprites/boss_fx/lava_geyser_anim_sheet.png"
	if ResourceLoader.exists(sheet_path):
		var anim_spr = _make_anim_from_sheet(sheet_path, 32, 5, 8.0)
		anim_spr.scale = Vector2(2.0, 2.0)
		geyser.add_child(anim_spr)
	else:
		var base_vis = _make_circle_poly(GEYSER_RADIUS, 12)
		base_vis.color = Color(1.0, 0.3, 0.0, 0.5)
		geyser.add_child(base_vis)
		var core_vis = _make_circle_poly(GEYSER_RADIUS * 0.5, 8)
		core_vis.color = Color(1.0, 0.7, 0.2, 0.7)
		geyser.add_child(core_vis)

	geyser.z_index = -1

	# Pulsing glow
	var pulse = geyser.create_tween().set_loops()
	pulse.tween_property(geyser, "scale", Vector2(1.15, 1.15), 0.4).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(geyser, "scale", Vector2(0.9, 0.9), 0.4).set_trans(Tween.TRANS_SINE)

	return geyser

func _tick_geysers() -> void:
	if not player_ref or not is_instance_valid(player_ref): return
	for geyser in _geyser_nodes:
		if not is_instance_valid(geyser): continue
		var dist = geyser.global_position.distance_to(player_ref.global_position)
		if dist < GEYSER_RADIUS:
			if player_ref.has_method("take_damage"):
				var tick_dmg = ceili(GEYSER_DPS * GEYSER_TICK)
				player_ref.take_damage(tick_dmg, self)

# --- Original Attacks ---

func _start_charge() -> void:
	if not player_ref or not is_instance_valid(player_ref):
		return
	is_charging = true
	charge_time_left = CHARGE_DURATION
	charge_dir = (player_ref.global_position - global_position).normalized()
	lava_drop_cooldown = 0.0
	# Visual: turn bright orange
	if sprite:
		sprite.modulate = Color(2.0, 0.8, 0.3)
	if _dot:
		_dot.modulate = Color(2.0, 0.8, 0.3)

func _end_charge() -> void:
	is_charging = false
	if sprite:
		var tw = create_tween()
		tw.tween_property(sprite, "modulate", Color.WHITE, 0.3)
	if _dot:
		var tw2 = create_tween()
		tw2.tween_property(_dot, "modulate", Color.WHITE, 0.3)

func _drop_lava_pool() -> void:
	var parent = get_parent()
	if not parent:
		return
	var pool = Area2D.new()
	pool.collision_layer = 0
	pool.collision_mask = 1
	pool.monitoring = true
	pool.global_position = global_position

	var shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = 12.0
	shape.shape = circle
	pool.add_child(shape)

	# Visual — molten lava pool with dark border, bright center, pulsing glow
	var vis = Node2D.new()
	vis.z_index = -1
	# Wide heat shimmer glow
	var heat_aura = _make_circle_poly(18, 16)
	heat_aura.color = Color(1.0, 0.15, 0.0, 0.1)
	vis.add_child(heat_aura)
	# Dark red border ring
	var border_ring = _make_circle_poly(14, 14, 1.5)
	border_ring.color = Color(0.6, 0.1, 0.0, 0.55)
	vis.add_child(border_ring)
	# Main bright orange lava body
	var lava_body = _make_circle_poly(11, 12, 1.0)
	lava_body.color = Color(1.0, 0.45, 0.05, 0.65)
	vis.add_child(lava_body)
	# Yellow-orange hot layer
	var hot_layer = _make_circle_poly(7, 10)
	hot_layer.color = Color(1.0, 0.7, 0.15, 0.6)
	vis.add_child(hot_layer)
	# Yellow-white hot center
	var molten_core = _make_circle_poly(4, 8)
	molten_core.color = Color(1.0, 0.9, 0.4, 0.7)
	vis.add_child(molten_core)
	# White-hot innermost pinpoint
	var white_center = _make_circle_poly(2, 6)
	white_center.color = Color(1.0, 1.0, 0.8, 0.6)
	vis.add_child(white_center)
	pool.add_child(vis)
	# Pulsing glow effect
	var pulse = pool.create_tween().set_loops()
	pulse.tween_property(vis, "scale", Vector2(1.1, 1.1), 0.5).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(vis, "scale", Vector2(0.92, 0.92), 0.5).set_trans(Tween.TRANS_SINE)

	parent.add_child(pool)

	var tick_count = int(LAVA_POOL_DURATION / 0.5)
	_run_lava_ticks(pool, tick_count)

func _make_circle_poly(radius: float, segments: int = 12, jitter: float = 0.0) -> Polygon2D:
	var poly = Polygon2D.new()
	var pts: PackedVector2Array = []
	for i in segments:
		var angle = TAU * i / float(segments)
		var r = radius + randf_range(-jitter, jitter)
		pts.append(Vector2(cos(angle), sin(angle)) * r)
	poly.polygon = pts
	return poly

func _run_lava_ticks(pool: Area2D, ticks_left: int) -> void:
	if ticks_left <= 0 or not is_instance_valid(pool):
		if is_instance_valid(pool):
			pool.queue_free()
		return
	if not is_instance_valid(self) or not is_inside_tree():
		if is_instance_valid(pool): pool.queue_free()
		return
	await get_tree().create_timer(0.5).timeout
	if not is_inside_tree() or not is_instance_valid(pool):
		return
	var bodies = pool.get_overlapping_bodies()
	for body in bodies:
		if body.is_in_group("player") and body.has_method("take_damage"):
			body.take_damage(LAVA_DPS, self)
	var vis = pool.get_child(1) if pool.get_child_count() > 1 else null
	if vis:
		vis.modulate.a = float(ticks_left) / (LAVA_POOL_DURATION / 0.5)
	_run_lava_ticks(pool, ticks_left - 1)

func _lava_spread() -> void:
	if not player_ref or not is_instance_valid(player_ref):
		return
	var proj_scene = _proj_scene
	if not proj_scene:
		return
	var parent = get_parent()
	if not parent:
		return
	_play_attack_anim()

	# Visual feedback
	if sprite:
		sprite.modulate = Color(2.0, 0.5, 0.1)
		var tw = create_tween()
		tw.tween_property(sprite, "modulate", Color.WHITE, 0.25)
	if _dot:
		_dot.modulate = Color(2.0, 0.5, 0.1)
		var tw2 = create_tween()
		tw2.tween_property(_dot, "modulate", Color.WHITE, 0.25)

	var base_dir = (player_ref.global_position - global_position).normalized()
	var base_angle = base_dir.angle()

	for i in LAVA_PROJ_COUNT:
		var offset = (i - (LAVA_PROJ_COUNT - 1) / 2.0) * LAVA_SPREAD_ANGLE
		var angle = base_angle + offset
		var dir = Vector2(cos(angle), sin(angle))
		var proj = proj_scene.instantiate()
		proj.source_enemy = self
		proj.global_position = global_position + dir * 12.0
		proj.projectile_type = "lava"
		proj.setup(dir * LAVA_PROJ_SPEED, damage)
		parent.add_child(proj)

func _die() -> void:
	for g in _geyser_nodes:
		if is_instance_valid(g): g.queue_free()
	_geyser_nodes.clear()
	_burrow_active = false
	if sprite: sprite.modulate.a = 1.0
	if _dot and is_instance_valid(_dot): _dot.modulate.a = 1.0
	super._die()

func _get_arena_center() -> Vector2:
	if player_ref and is_instance_valid(player_ref):
		var cam = player_ref.get_node_or_null("Camera2D")
		if cam: return cam.global_position
	return Vector2(480, 270)

func _make_anim_from_sheet(sheet_path: String, frame_size: int, frame_count: int, fps: float) -> AnimatedSprite2D:
	var tex = load(sheet_path)
	var spr = AnimatedSprite2D.new()
	var frames = SpriteFrames.new()
	frames.add_animation("default")
	frames.set_animation_speed("default", fps)
	frames.set_animation_loop("default", true)
	for i in frame_count:
		var atlas = AtlasTexture.new()
		atlas.atlas = tex
		atlas.region = Rect2(i * frame_size, 0, frame_size, frame_size)
		frames.add_frame("default", atlas)
	spr.sprite_frames = frames
	spr.play("default")
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return spr
