extends EnemyBase

# Scrap Sentinel — Stage 1 Mid-Boss (Wave 7)
# Phase 1: Blade spin AoE + scrap throws + periodic shield
# Phase 2: "SAW STORM" — moves to center, spawns cover, fires spiral saw blades
# Phase 3: Berserker — permanent shield (breaks after 5 hits), doubled attack speed

var blade_spin_timer: float = 0.0
var scrap_throw_timer: float = 0.0
var shield_timer: float = 0.0
var _is_shielded: bool = false
var _shield_hits: int = 0
var _saw_storm_timer: float = 0.0
var _saw_storm_active: bool = false
var _saw_storm_elapsed: float = 0.0
var _cover_nodes: Array = []

var BLADE_SPIN_INTERVAL: float = 3.5
const BLADE_SPIN_RANGE = 50.0
const BLADE_SPIN_DAMAGE = 12

var SCRAP_THROW_INTERVAL: float = 5.0
var SCRAP_COUNT: int = 4

const SHIELD_INTERVAL = 12.0
const SHIELD_DURATION = 3.0

const SAW_STORM_DURATION = 6.0
const SAW_STORM_INTERVAL = 15.0
const SAW_STORM_PROJECTILE_INTERVAL = 0.3

var _proj_scene: PackedScene = null

func _ready() -> void:
	enemy_type       = "scrap_sentinel"
	max_health       = 700
	move_speed       = 40.0
	damage           = 18
	xp_value         = 80
	contact_cooldown = 1.2
	_proj_scene = load("res://scenes/enemy_projectile.tscn")
	super._ready()
	if health_bar:
		health_bar.visible = true

func _physics_process(delta: float) -> void:
	if is_dead or _phase_transitioning: return

	# Saw storm mechanic (Phase 2+)
	if _saw_storm_active:
		_process_saw_storm(delta)
		return  # Don't do normal attacks during storm

	blade_spin_timer += delta
	scrap_throw_timer += delta

	if blade_spin_timer >= BLADE_SPIN_INTERVAL:
		blade_spin_timer = 0.0
		_blade_spin()

	if scrap_throw_timer >= SCRAP_THROW_INTERVAL:
		scrap_throw_timer = 0.0
		_throw_scrap()

	# Phase 1: Timed shield
	if _boss_phase == 1:
		shield_timer += delta
		if shield_timer >= SHIELD_INTERVAL:
			shield_timer = 0.0
			_activate_shield()

	# Phase 2+: Saw storm cooldown
	if _boss_phase >= 2:
		_saw_storm_timer += delta
		if _saw_storm_timer >= SAW_STORM_INTERVAL:
			_saw_storm_timer = 0.0
			_start_saw_storm()

	super._physics_process(delta)

func take_damage(amount: int, from_pos: Vector2 = Vector2.ZERO) -> void:
	if _is_shielded:
		_shield_hits += 1
		# Phase 3: Shield breaks after 5 hits
		if _boss_phase >= 3 and _shield_hits >= 5:
			_is_shielded = false
			_shield_hits = 0
			if sprite and not is_dead:
				sprite.modulate = Color.WHITE
			# Show break text
			var brk = Label.new()
			brk.text = "SHIELD BROKEN!"
			brk.add_theme_font_size_override("font_size", 8)
			brk.add_theme_color_override("font_color", Color(1.0, 0.5, 0.2))
			brk.position = global_position + Vector2(-24, -24)
			brk.z_index = 10
			var p = get_parent()
			if p:
				p.add_child(brk)
				var tw = brk.create_tween()
				tw.tween_property(brk, "modulate:a", 0.0, 0.6)
				tw.tween_callback(brk.queue_free)
			return
		# Normal block
		var spark = Label.new()
		spark.text = "BLOCKED"
		spark.add_theme_font_size_override("font_size", 7)
		spark.add_theme_color_override("font_color", Color(0.7, 0.8, 1.0))
		spark.position = global_position + Vector2(-16, -20)
		spark.z_index = 10
		var parent = get_parent()
		if parent:
			parent.add_child(spark)
			var tw = spark.create_tween()
			tw.tween_property(spark, "modulate:a", 0.0, 0.4)
			tw.tween_callback(spark.queue_free)
		return
	super.take_damage(amount, from_pos)

func _on_phase_change(new_phase: int) -> void:
	super._on_phase_change(new_phase)
	match new_phase:
		2:
			_show_boss_warning("TAKE COVER!")
			# Immediately trigger first saw storm
			_start_saw_storm()
		3:
			_show_boss_warning("BERSERKER MODE!")
			# Permanent shield that breaks after 5 hits
			_is_shielded = true
			_shield_hits = 0
			if sprite:
				sprite.modulate = Color(0.5, 0.7, 1.5)
			# Double attack speed
			BLADE_SPIN_INTERVAL = 1.75
			SCRAP_THROW_INTERVAL = 2.5
			SCRAP_COUNT = 6

func _start_saw_storm() -> void:
	if _saw_storm_active or is_dead: return
	_saw_storm_active = true
	_saw_storm_elapsed = 0.0

	_show_boss_warning("TAKE COVER!")

	# Spawn 3 scrap pile cover objects around the arena
	_cover_nodes.clear()
	var arena_center = _get_arena_center()
	var cover_positions = [
		arena_center + Vector2(-120, -80),
		arena_center + Vector2(120, -60),
		arena_center + Vector2(0, 100),
	]
	for pos in cover_positions:
		var obs = _spawn_cover_obstacle(pos, "scrap_pile", 15)
		if obs:
			_cover_nodes.append(obs)

	# Move sentinel toward center
	var tw = create_tween()
	tw.tween_property(self, "global_position", arena_center, 0.8).set_ease(Tween.EASE_IN_OUT)

func _process_saw_storm(delta: float) -> void:
	_saw_storm_elapsed += delta

	# Fire spiral saw blades every 0.3 seconds
	var fire_interval = SAW_STORM_PROJECTILE_INTERVAL
	var fire_count = int(_saw_storm_elapsed / fire_interval)
	var prev_count = int((_saw_storm_elapsed - delta) / fire_interval)

	if fire_count > prev_count:
		_fire_storm_projectiles(fire_count)

	# End storm after duration
	if _saw_storm_elapsed >= SAW_STORM_DURATION:
		_saw_storm_active = false
		# Destroy cover after storm ends
		for obs in _cover_nodes:
			if is_instance_valid(obs):
				obs.queue_free()
		_cover_nodes.clear()

func _fire_storm_projectiles(tick: int) -> void:
	if not _proj_scene: return
	var parent = get_parent()
	if not parent: return

	var num_blades = 8
	var base_angle = tick * 0.4  # Rotate spiral over time
	for i in num_blades:
		var angle = base_angle + TAU * i / num_blades
		var dir = Vector2.from_angle(angle)
		var proj = _proj_scene.instantiate()
		proj.projectile_type = "saw"
		parent.add_child(proj)
		proj.global_position = global_position + dir * 15.0
		proj.setup(dir * 100.0, 15)

func _get_arena_center() -> Vector2:
	# Approximate arena center
	if player_ref and is_instance_valid(player_ref):
		var cam = player_ref.get_node_or_null("Camera2D")
		if cam:
			return cam.get_screen_center_position()
	return Vector2(640, 360)

func _blade_spin() -> void:
	if not player_ref or not is_instance_valid(player_ref): return
	_play_attack_anim()
	if sprite:
		var tw = create_tween()
		tw.tween_property(sprite, "modulate", Color(1.5, 0.5, 0.5), 0.1)
		tw.tween_property(sprite, "modulate", Color.WHITE if not _is_shielded else Color(0.5, 0.7, 1.5), 0.2)

	var dist = global_position.distance_to(player_ref.global_position)
	if dist < BLADE_SPIN_RANGE:
		if player_ref.has_method("take_damage"):
			player_ref.take_damage(BLADE_SPIN_DAMAGE, self)

	for i in 6:
		var angle = TAU * i / 6.0
		var line = Line2D.new()
		line.width = 2.5
		line.default_color = Color(0.8, 0.6, 0.3, 0.8)
		line.z_index = 5
		var start = global_position + Vector2(cos(angle), sin(angle)) * 8.0
		var end_pt = global_position + Vector2(cos(angle), sin(angle)) * BLADE_SPIN_RANGE
		line.add_point(start)
		line.add_point(end_pt)
		var parent = get_parent()
		if parent:
			parent.add_child(line)
			var tw = line.create_tween()
			tw.tween_property(line, "modulate:a", 0.0, 0.3)
			tw.tween_callback(line.queue_free)

func _throw_scrap() -> void:
	if not player_ref or not is_instance_valid(player_ref): return
	var proj_scene = _proj_scene
	if not proj_scene: return
	_play_attack_anim_then(_do_throw_scrap)

func _do_throw_scrap() -> void:
	if is_dead or not player_ref or not is_instance_valid(player_ref): return
	var proj_scene = _proj_scene
	if not proj_scene: return
	var parent = get_parent()
	if not parent: return
	var spawn_pos = global_position
	var dir_to_player = (player_ref.global_position - spawn_pos).normalized()
	for i in SCRAP_COUNT:
		var spread_angle = (i - SCRAP_COUNT / 2.0) * 0.3
		var proj = proj_scene.instantiate()
		proj.projectile_type = "saw"
		parent.add_child(proj)
		proj.global_position = spawn_pos
		proj.setup(dir_to_player.rotated(spread_angle) * 120.0, 10)

func _activate_shield() -> void:
	_is_shielded = true
	_shield_hits = 0
	if sprite:
		sprite.modulate = Color(0.5, 0.7, 1.5)
	var tw = create_tween()
	tw.tween_interval(SHIELD_DURATION)
	tw.tween_callback(func():
		_is_shielded = false
		_shield_hits = 0
		if sprite and not is_dead:
			sprite.modulate = Color.WHITE
	)
