extends EnemyBase

# Scrap King — FINAL BOSS (Stage 6, Wave 84)
# Phase 1 (100-66%): Melee slam + spawn 2 minions + 2 stone pillar cover
# Phase 2 "ROYAL DECREE" (66-33%): Teleport to center, shield up, spiral saw barrage 8s, then stun 3s. Also fires barrage.
# Phase 3 "LAST STAND" (33-0%): Enraged. 8-projectile barrage. Royal Decree repeats every 20s with 6 spiral arms. Spawns 3 minions + new pillars.

var spawn_timer: float = 0.0
var attack_timer: float = 0.0
var barrage_timer: float = 0.0

# Royal Decree (Phase 2+)
var _decree_active: bool = false
var _decree_elapsed: float = 0.0
var _decree_cooldown: float = 0.0
var _decree_stunned: bool = false
var _decree_stun_timer: float = 0.0
var _is_shielded: bool = false

# Cover tracking
var _pillar_spawned_initial: bool = false

const SPAWN_INTERVAL = 8.0
const SPAWN_COUNT_P1 = 2
const SPAWN_COUNT_P3 = 3

const MELEE_SLAM_INTERVAL = 3.0
const MELEE_SLAM_RANGE = 50.0
const MELEE_SLAM_DAMAGE = 25

const BARRAGE_INTERVAL = 2.0
var BARRAGE_COUNT: int = 6
const BARRAGE_SPEED = 85.0
const BARRAGE_DAMAGE = 15

const ENRAGE_SPEED_MULT = 1.6
const ENRAGE_DAMAGE_MULT = 1.4

const DECREE_DURATION = 8.0
const DECREE_STUN_DURATION = 3.0
const DECREE_PROJECTILE_INTERVAL = 0.25
var DECREE_BLADE_COUNT: int = 6
const DECREE_ROTATION_PER_TICK = 12.0  # degrees
const DECREE_COOLDOWN_P3 = 20.0

var _proj_scene: PackedScene = null

func _ready() -> void:
	enemy_type       = "scrap_king"
	max_health       = 3000
	move_speed       = 30.0
	damage           = 35
	xp_value         = 500
	contact_cooldown = 1.0
	_proj_scene = load("res://scenes/enemy_projectile.tscn")
	super._ready()
	if health_bar:
		health_bar.visible = true

func _physics_process(delta: float) -> void:
	if is_dead or _phase_transitioning: return

	# --- Decree stun (after decree ends, king is stunned 3s) ---
	if _decree_stunned:
		_decree_stun_timer -= delta
		velocity = Vector2.ZERO
		if _decree_stun_timer <= 0:
			_decree_stunned = false
			if sprite and not is_dead:
				sprite.modulate = Color.WHITE
		move_and_slide()
		_animate_sprite(delta)
		return

	# --- Royal Decree active ---
	if _decree_active:
		_process_decree(delta)
		move_and_slide()
		_animate_sprite(delta)
		return

	# --- Phase 3: Decree cooldown ---
	if _boss_phase >= 3 and not _decree_active and not _decree_stunned:
		_decree_cooldown += delta
		if _decree_cooldown >= DECREE_COOLDOWN_P3:
			_decree_cooldown = 0.0
			_start_royal_decree()
			return

	spawn_timer += delta
	attack_timer += delta

	# Spawn initial pillars once in phase 1
	if not _pillar_spawned_initial and _boss_phase >= 1:
		_pillar_spawned_initial = true
		_spawn_stone_pillars()

	# Spawning
	if spawn_timer >= SPAWN_INTERVAL:
		spawn_timer = 0.0
		_spawn_minions()

	# Phase-specific attacks
	match _boss_phase:
		1:
			if attack_timer >= MELEE_SLAM_INTERVAL:
				attack_timer = 0.0
				_melee_slam()
		2:
			if attack_timer >= MELEE_SLAM_INTERVAL:
				attack_timer = 0.0
				_melee_slam()
			barrage_timer += delta
			if barrage_timer >= BARRAGE_INTERVAL:
				barrage_timer = 0.0
				_ranged_barrage()
		3:
			# Both attacks, faster
			if attack_timer >= MELEE_SLAM_INTERVAL * 0.6:
				attack_timer = 0.0
				_melee_slam()
			barrage_timer += delta
			if barrage_timer >= BARRAGE_INTERVAL * 0.7:
				barrage_timer = 0.0
				_ranged_barrage()

	super._physics_process(delta)

func take_damage(amount: int, from_pos: Vector2 = Vector2.ZERO) -> void:
	if _is_shielded:
		# Show blocked text
		var spark = Label.new()
		spark.text = "IMMUNE"
		spark.add_theme_font_size_override("font_size", 8)
		spark.add_theme_color_override("font_color", Color(0.8, 0.7, 1.0))
		spark.position = global_position + Vector2(-16, -22)
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
			_phase_change_visual(Color(0.8, 0.4, 0.1))
			# Start first Royal Decree immediately
			_start_royal_decree()
		3:
			_phase_change_visual(Color(1.0, 0.2, 0.2))
			_show_boss_warning("LAST STAND!")
			move_speed = _base_move_speed * ENRAGE_SPEED_MULT
			damage = int(damage * ENRAGE_DAMAGE_MULT)
			BARRAGE_COUNT = 8
			DECREE_BLADE_COUNT = 6  # 6 spiral arms in phase 3
			_decree_cooldown = 0.0

# ---- Melee Slam ----
func _melee_slam() -> void:
	if not player_ref or not is_instance_valid(player_ref): return
	_play_attack_anim()

	if sprite:
		sprite.modulate = Color(2.0, 1.5, 1.0)
		var tw = create_tween()
		tw.tween_property(sprite, "modulate", Color.WHITE, 0.3)

	# Shockwave visual
	var ring = ColorRect.new()
	ring.size = Vector2(4, 4)
	ring.position = global_position - Vector2(2, 2)
	ring.color = Color(0.7, 0.5, 0.2, 0.6)
	ring.z_index = -1
	var parent = get_parent()
	if parent:
		parent.add_child(ring)
		var tw2 = ring.create_tween()
		tw2.set_parallel(true)
		tw2.tween_property(ring, "size", Vector2(MELEE_SLAM_RANGE * 2, MELEE_SLAM_RANGE * 2), 0.4)
		tw2.tween_property(ring, "position", global_position - Vector2(MELEE_SLAM_RANGE, MELEE_SLAM_RANGE), 0.4)
		tw2.tween_property(ring, "modulate:a", 0.0, 0.4)
		tw2.set_parallel(false)
		tw2.tween_callback(ring.queue_free)

	var dist = global_position.distance_to(player_ref.global_position)
	if dist < MELEE_SLAM_RANGE:
		if player_ref.has_method("take_damage"):
			player_ref.take_damage(MELEE_SLAM_DAMAGE, self)

# ---- Ranged Barrage ----
func _ranged_barrage() -> void:
	if not _proj_scene: return
	if not player_ref or not is_instance_valid(player_ref): return
	_play_attack_anim_then(_do_barrage)

func _do_barrage() -> void:
	if is_dead or not player_ref or not is_instance_valid(player_ref): return
	if not _proj_scene: return

	var base_dir = (player_ref.global_position - global_position).normalized()
	var parent = get_parent()
	if not parent: return
	for i in BARRAGE_COUNT:
		var spread = (float(i) - BARRAGE_COUNT * 0.5) * 0.15
		var dir = base_dir.rotated(spread)
		var proj = _proj_scene.instantiate()
		proj.projectile_type = "bone"
		parent.add_child(proj)
		proj.global_position = global_position + dir * 14.0
		proj.setup(dir * BARRAGE_SPEED, BARRAGE_DAMAGE)

# ---- Royal Decree ----
func _start_royal_decree() -> void:
	if _decree_active or _decree_stunned or is_dead: return
	_decree_active = true
	_decree_elapsed = 0.0

	_show_boss_warning("BOW BEFORE THE KING!")

	# Phase 3: Spawn new stone pillars for cover before decree
	if _boss_phase >= 3:
		_clear_boss_obstacles()
		_spawn_stone_pillars()
		_spawn_minions()  # Extra minions during decree

	# Teleport to center
	var center = _get_arena_center()
	var tw = create_tween()
	tw.tween_property(self, "global_position", center, 0.4).set_ease(Tween.EASE_IN_OUT)

	# Raise shield
	_is_shielded = true
	if sprite:
		sprite.modulate = Color(0.6, 0.5, 1.5)

func _process_decree(delta: float) -> void:
	_decree_elapsed += delta
	velocity = Vector2.ZERO  # King stays at center during decree

	# Fire spiral saw blades
	var fire_interval = DECREE_PROJECTILE_INTERVAL
	var fire_count = int(_decree_elapsed / fire_interval)
	var prev_count = int((_decree_elapsed - delta) / fire_interval)

	if fire_count > prev_count:
		_fire_decree_blades(fire_count)

	# Pulsing visual on shield
	if sprite:
		var pulse = 0.8 + 0.2 * sin(_decree_elapsed * 6.0)
		sprite.modulate = Color(0.6 * pulse, 0.5 * pulse, 1.5)

	# End decree
	if _decree_elapsed >= DECREE_DURATION:
		_decree_active = false
		# Drop shield
		_is_shielded = false
		if sprite and not is_dead:
			sprite.modulate = Color(1.0, 1.0, 0.5)
		# Enter stun — vulnerable period
		_decree_stunned = true
		_decree_stun_timer = DECREE_STUN_DURATION

		# Stun visual — flash yellow
		var lbl = Label.new()
		lbl.text = "STUNNED!"
		lbl.add_theme_font_size_override("font_size", 10)
		lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 0.3))
		lbl.position = global_position + Vector2(-20, -28)
		lbl.z_index = 15
		var parent = get_parent()
		if parent:
			parent.add_child(lbl)
			var tw = lbl.create_tween()
			tw.tween_property(lbl, "position:y", lbl.position.y - 15, DECREE_STUN_DURATION)
			tw.parallel().tween_property(lbl, "modulate:a", 0.0, DECREE_STUN_DURATION)
			tw.tween_callback(lbl.queue_free)

func _fire_decree_blades(tick: int) -> void:
	if not _proj_scene: return
	var parent = get_parent()
	if not parent: return

	# Spiral pattern: DECREE_BLADE_COUNT blades rotating DECREE_ROTATION_PER_TICK degrees per tick
	var rotation_per_tick = deg_to_rad(DECREE_ROTATION_PER_TICK)
	var base_angle = tick * rotation_per_tick
	for i in DECREE_BLADE_COUNT:
		var angle = base_angle + TAU * i / DECREE_BLADE_COUNT
		var dir = Vector2.from_angle(angle)
		var proj = _proj_scene.instantiate()
		proj.projectile_type = "saw"
		parent.add_child(proj)
		proj.global_position = global_position + dir * 15.0
		proj.setup(dir * 95.0, 15)

# ---- Stone Pillars ----
func _spawn_stone_pillars() -> void:
	var center = _get_arena_center()
	var positions = [
		center + Vector2(-120, 0),
		center + Vector2(120, 0),
	]
	for pos in positions:
		_spawn_cover_obstacle(pos, "stone_pillar", 20, 2.0)

# ---- Spawn Minions ----
func _spawn_minions() -> void:
	var count = SPAWN_COUNT_P3 if _boss_phase == 3 else SPAWN_COUNT_P1
	var scene_path = "res://scenes/enemies/enemy_shadow_crawler.tscn" if _boss_phase >= 2 else "res://scenes/enemies/enemy_rusher.tscn"
	var minion_scene = load(scene_path)
	if not minion_scene: return
	var parent = get_parent()
	if not parent: return
	for i in count:
		var minion = minion_scene.instantiate()
		var angle = TAU * i / count
		minion.global_position = global_position + Vector2(cos(angle), sin(angle)) * 30.0
		minion.died.connect(func(_xp: int = 0):
			if not WaveManager.wave_active: return
			WaveManager.enemies_alive = maxi(0, WaveManager.enemies_alive - 1)
			WaveManager.emit_signal("enemies_remaining_changed", WaveManager.get_wave_enemy_count())
		)
		parent.add_child(minion)
		WaveManager.enemies_alive += 1
		WaveManager.emit_signal("enemies_remaining_changed", WaveManager.get_wave_enemy_count())

# ---- Helpers ----
func _phase_change_visual(color: Color) -> void:
	if sprite:
		var tw = create_tween()
		tw.tween_property(sprite, "modulate", color, 0.2)
		tw.tween_property(sprite, "modulate", Color.WHITE, 0.3)
	var lbl = Label.new()
	lbl.text = "PHASE %d!" % _boss_phase
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", color)
	lbl.position = global_position + Vector2(-18, -30)
	lbl.z_index = 15
	var parent = get_parent()
	if parent:
		parent.add_child(lbl)
		var tw2 = lbl.create_tween()
		tw2.tween_property(lbl, "position:y", lbl.position.y - 20, 0.8)
		tw2.parallel().tween_property(lbl, "modulate:a", 0.0, 0.8)
		tw2.tween_callback(lbl.queue_free)

func _get_arena_center() -> Vector2:
	if player_ref and is_instance_valid(player_ref):
		var cam = player_ref.get_node_or_null("Camera2D")
		if cam: return cam.get_screen_center_position()
	return Vector2(640, 360)
