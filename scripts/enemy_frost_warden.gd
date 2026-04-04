extends EnemyBase

# Frost Warden — Stage 4 Mid-Boss
# Ice shield (absorbs first 5 hits), spawns frost sprites every 8s, ice blast AoE every 5s
# Phase 1: Ice shield + ice blast + frost sprite spawns
# Phase 2 "BLIZZARD": Spawns ice wall cover, pushes player toward walls, rapid ice blasts. 10s duration.
# Phase 3 "PERMAFROST": Ice shield regenerates every 8s, blizzard repeats every 20s, ice blast slows player.

var ice_shield_hits: int = 5
var spawn_timer: float = 0.0
var ice_blast_timer: float = 0.0

# Phase 2/3
var _blizzard_timer: float = 0.0
var _blizzard_active: bool = false
var _blizzard_elapsed: float = 0.0
var _blizzard_blast_timer: float = 0.0
var _shield_regen_timer: float = 0.0
var _cover_nodes: Array = []

const SPAWN_INTERVAL = 8.0
const SPAWN_COUNT = 2
const ICE_BLAST_INTERVAL = 5.0  # Phase 1 normal rate
const ICE_BLAST_RANGE = 55.0
const ICE_BLAST_DAMAGE = 15

# Blizzard constants
const BLIZZARD_DURATION = 10.0
const BLIZZARD_REPEAT_INTERVAL = 20.0
const BLIZZARD_BLAST_INTERVAL = 1.0  # 3x faster than normal during blizzard
const BLIZZARD_PUSH_FORCE = 40.0
const BLIZZARD_WALL_DISTANCE = 120.0

# Permafrost constants (Phase 3)
const SHIELD_REGEN_INTERVAL = 8.0
const SHIELD_REGEN_HITS = 5
const ICE_SLOW_AMOUNT = 0.5  # 50% slow
const ICE_SLOW_DURATION = 2.0

func _ready() -> void:
	enemy_type       = "frost_warden"
	max_health       = 1200
	move_speed       = 30.0
	damage           = 20
	xp_value         = 200
	contact_cooldown = 1.5
	super._ready()
	if health_bar:
		health_bar.visible = true

func _physics_process(delta: float) -> void:
	if is_dead or _phase_transitioning: return

	# Blizzard push force on player
	if _blizzard_active and player_ref and is_instance_valid(player_ref):
		_process_blizzard(delta)

	# Blizzard repeat timer (Phase 2+)
	if _boss_phase >= 2 and not _blizzard_active:
		_blizzard_timer += delta
		if _blizzard_timer >= BLIZZARD_REPEAT_INTERVAL:
			_blizzard_timer = 0.0
			_start_blizzard()

	# Shield regeneration (Phase 3)
	if _boss_phase >= 3 and ice_shield_hits <= 0:
		_shield_regen_timer += delta
		if _shield_regen_timer >= SHIELD_REGEN_INTERVAL:
			_shield_regen_timer = 0.0
			_regenerate_shield()

	spawn_timer += delta
	ice_blast_timer += delta

	if spawn_timer >= SPAWN_INTERVAL:
		spawn_timer = 0.0
		_spawn_frost_sprites()

	# Normal ice blast (not during blizzard — blizzard has its own faster blast)
	if not _blizzard_active and ice_blast_timer >= ICE_BLAST_INTERVAL:
		ice_blast_timer = 0.0
		_ice_blast()

	super._physics_process(delta)

func take_damage(amount: int, from_pos: Vector2 = Vector2.ZERO) -> void:
	if ice_shield_hits > 0:
		ice_shield_hits -= 1
		# Show shield absorb visual
		if sprite:
			sprite.modulate = Color(0.5, 0.8, 1.5)
			var tw = create_tween()
			tw.tween_property(sprite, "modulate", Color.WHITE, 0.15)
		_show_damage_number(0)
		# Shield break visual when depleted
		if ice_shield_hits <= 0:
			_shield_break_visual()
		return
	super.take_damage(amount, from_pos)

func _shield_break_visual() -> void:
	var flash = ColorRect.new()
	flash.color = Color(0.5, 0.8, 1.0, 0.5)
	flash.size = Vector2(60, 60)
	flash.position = global_position - Vector2(30, 30)
	flash.z_index = 5
	var parent = get_parent()
	if parent:
		parent.add_child(flash)
		var tw = flash.create_tween()
		tw.tween_property(flash, "modulate:a", 0.0, 0.4)
		tw.tween_callback(flash.queue_free)

# --- Phase Transitions ---

func _on_phase_change(new_phase: int) -> void:
	super._on_phase_change(new_phase)
	match new_phase:
		2:
			_show_boss_warning("BRACE YOURSELF!")
			_start_blizzard()
		3:
			_show_boss_warning("PERMAFROST!")
			_regenerate_shield()
			_start_blizzard()

# --- Blizzard (Phase 2+) ---

func _start_blizzard() -> void:
	if _blizzard_active or is_dead: return
	_blizzard_active = true
	_blizzard_elapsed = 0.0
	_blizzard_blast_timer = 0.0

	_show_boss_warning("BRACE YOURSELF!")

	# Spawn 3 ice wall cover obstacles around the arena center
	_cover_nodes.clear()
	var center = _get_arena_center()
	var wall_angles = [0.0, TAU / 3.0, TAU * 2.0 / 3.0]
	for angle in wall_angles:
		var pos = center + Vector2(cos(angle), sin(angle)) * BLIZZARD_WALL_DISTANCE
		var obs = _spawn_cover_obstacle(pos, "ice_wall_small", 20, 2.0)
		if obs:
			_cover_nodes.append(obs)

	# Visual: tint the warden icy blue
	if sprite:
		sprite.modulate = Color(0.5, 0.7, 1.5)

func _process_blizzard(delta: float) -> void:
	_blizzard_elapsed += delta
	_blizzard_blast_timer += delta

	# Push player toward nearest wall
	if player_ref and is_instance_valid(player_ref):
		var nearest_wall: Node2D = null
		var nearest_dist: float = INF
		for wall in _cover_nodes:
			if not is_instance_valid(wall): continue
			var d = player_ref.global_position.distance_to(wall.global_position)
			if d < nearest_dist:
				nearest_dist = d
				nearest_wall = wall

		if nearest_wall and is_instance_valid(nearest_wall):
			var push_dir = (nearest_wall.global_position - player_ref.global_position).normalized()
			# Apply push as velocity offset on the player
			if player_ref.has_method("apply_external_force"):
				player_ref.apply_external_force(push_dir * BLIZZARD_PUSH_FORCE * delta)
			elif "velocity" in player_ref:
				player_ref.velocity += push_dir * BLIZZARD_PUSH_FORCE * delta

	# Rapid ice blasts during blizzard (every 1s instead of every 5s)
	if _blizzard_blast_timer >= BLIZZARD_BLAST_INTERVAL:
		_blizzard_blast_timer = 0.0
		_ice_blast()

	# End blizzard after duration
	if _blizzard_elapsed >= BLIZZARD_DURATION:
		_blizzard_active = false
		# Restore color
		if sprite and not is_dead:
			var tw = create_tween()
			tw.tween_property(sprite, "modulate", Color.WHITE, 0.3)
		# Destroy cover after blizzard ends
		for obs in _cover_nodes:
			if is_instance_valid(obs):
				obs.queue_free()
		_cover_nodes.clear()

	# Visual: spawn swirling snow particles
	if int(_blizzard_elapsed * 10) % 3 == 0:
		_spawn_snow_particle()

func _spawn_snow_particle() -> void:
	var parent = get_parent()
	if not parent: return
	var center = _get_arena_center()
	var particle = Polygon2D.new()
	var pts: PackedVector2Array = []
	for i in 4:
		var angle = TAU * i / 4.0
		pts.append(Vector2(cos(angle), sin(angle)) * randf_range(1.5, 3.0))
	particle.polygon = pts
	particle.color = Color(0.8, 0.9, 1.0, 0.6)
	particle.global_position = center + Vector2(randf_range(-150, 150), randf_range(-100, 100))
	particle.z_index = 5
	parent.add_child(particle)

	# Drift and fade
	var tw = particle.create_tween()
	tw.set_parallel(true)
	tw.tween_property(particle, "position", particle.position + Vector2(randf_range(-40, 40), randf_range(20, 50)), 1.0)
	tw.tween_property(particle, "modulate:a", 0.0, 1.0)
	tw.set_parallel(false)
	tw.tween_callback(particle.queue_free)

# --- Shield Regeneration (Phase 3) ---

func _regenerate_shield() -> void:
	ice_shield_hits = SHIELD_REGEN_HITS
	_shield_regen_timer = 0.0

	# Visual: flash blue to show shield is back
	if sprite:
		var tw = create_tween()
		tw.tween_property(sprite, "modulate", Color(0.3, 0.6, 2.0), 0.15)
		tw.tween_property(sprite, "modulate", Color.WHITE, 0.3)

	# Show shield regen text
	var lbl = Label.new()
	lbl.text = "SHIELD RESTORED!"
	lbl.add_theme_font_size_override("font_size", 7)
	lbl.add_theme_color_override("font_color", Color(0.4, 0.7, 1.0))
	lbl.position = global_position + Vector2(-28, -24)
	lbl.z_index = 10
	var parent = get_parent()
	if parent:
		parent.add_child(lbl)
		var tw2 = lbl.create_tween()
		tw2.tween_property(lbl, "modulate:a", 0.0, 0.8)
		tw2.tween_callback(lbl.queue_free)

# --- Original Attacks ---

func _spawn_frost_sprites() -> void:
	var sprite_scene = load("res://scenes/enemies/enemy_frost_sprite.tscn")
	if not sprite_scene: return
	var parent = get_parent()
	if not parent: return
	for i in SPAWN_COUNT:
		var minion = sprite_scene.instantiate()
		var offset = Vector2(randf_range(-20, 20), randf_range(-20, 20))
		minion.global_position = global_position + offset
		minion.died.connect(func(_xp: int = 0):
			if not WaveManager.wave_active: return
			WaveManager.enemies_alive = maxi(0, WaveManager.enemies_alive - 1)
			WaveManager.emit_signal("enemies_remaining_changed", WaveManager.get_wave_enemy_count())
		)
		parent.add_child(minion)
		WaveManager.enemies_alive += 1
		WaveManager.emit_signal("enemies_remaining_changed", WaveManager.get_wave_enemy_count())

func _ice_blast() -> void:
	if not player_ref or not is_instance_valid(player_ref): return
	_play_attack_anim()

	# Visual — expanding ice ring
	var ring = ColorRect.new()
	ring.size = Vector2(4, 4)
	ring.position = global_position - Vector2(2, 2)
	ring.color = Color(0.4, 0.7, 1.0, 0.6)
	ring.z_index = -1
	var parent = get_parent()
	if parent:
		parent.add_child(ring)
		var tw = ring.create_tween()
		tw.set_parallel(true)
		tw.tween_property(ring, "size", Vector2(ICE_BLAST_RANGE * 2, ICE_BLAST_RANGE * 2), 0.4)
		tw.tween_property(ring, "position", global_position - Vector2(ICE_BLAST_RANGE, ICE_BLAST_RANGE), 0.4)
		tw.tween_property(ring, "modulate:a", 0.0, 0.4)
		tw.set_parallel(false)
		tw.tween_callback(ring.queue_free)

	# Damage player if in range
	var dist = global_position.distance_to(player_ref.global_position)
	if dist < ICE_BLAST_RANGE:
		if player_ref.has_method("take_damage"):
			player_ref.take_damage(ICE_BLAST_DAMAGE, self)
		# Phase 3: All ice blasts apply slow
		if _boss_phase >= 3:
			if player_ref.has_method("apply_slow"):
				player_ref.apply_slow(ICE_SLOW_AMOUNT, ICE_SLOW_DURATION)

func _get_arena_center() -> Vector2:
	if player_ref and is_instance_valid(player_ref):
		var cam = player_ref.get_node_or_null("Camera2D")
		if cam: return cam.get_screen_center_position()
	return Vector2(640, 360)
