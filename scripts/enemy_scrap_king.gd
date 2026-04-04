extends EnemyBase

# Scrap King — FINAL BOSS (Stage 6)
# 3 phases: Phase 1 melee+spawns, Phase 2 ranged barrage, Phase 3 enrage (all attacks, faster, stronger)

var phase: int = 1
var spawn_timer: float = 0.0
var attack_timer: float = 0.0
var barrage_timer: float = 0.0

const SPAWN_INTERVAL = 8.0
const SPAWN_COUNT_P1 = 2
const SPAWN_COUNT_P3 = 3

const MELEE_SLAM_INTERVAL = 3.0
const MELEE_SLAM_RANGE = 50.0
const MELEE_SLAM_DAMAGE = 25

const BARRAGE_INTERVAL = 2.0
const BARRAGE_COUNT = 6
const BARRAGE_SPEED = 85.0
const BARRAGE_DAMAGE = 15

const ENRAGE_SPEED_MULT = 1.6
const ENRAGE_DAMAGE_MULT = 1.4
var _proj_scene: PackedScene = null

func _ready() -> void:
	enemy_type       = "scrap_king"
	max_health       = 1500
	move_speed       = 30.0
	damage           = 35
	xp_value         = 500
	contact_cooldown = 1.0
	_proj_scene = load("res://scenes/enemy_projectile.tscn")
	super._ready()
	if health_bar:
		health_bar.visible = true

func _physics_process(delta: float) -> void:
	if is_dead: return

	# Phase transitions
	var hp_pct = float(health) / float(max_health)
	if hp_pct <= 0.33 and phase < 3:
		phase = 3
		move_speed = _base_move_speed * ENRAGE_SPEED_MULT
		damage = int(damage * ENRAGE_DAMAGE_MULT)
		_phase_change_visual(Color(1.0, 0.2, 0.2))
	elif hp_pct <= 0.66 and phase < 2:
		phase = 2
		_phase_change_visual(Color(0.8, 0.4, 0.1))

	spawn_timer += delta
	attack_timer += delta

	# Spawning
	if spawn_timer >= SPAWN_INTERVAL:
		spawn_timer = 0.0
		_spawn_minions()

	# Phase-specific attacks
	match phase:
		1:
			if attack_timer >= MELEE_SLAM_INTERVAL:
				attack_timer = 0.0
				_melee_slam()
		2:
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

func _melee_slam() -> void:
	if not player_ref or not is_instance_valid(player_ref): return
	_play_attack_anim()

	# Visual
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

func _ranged_barrage() -> void:
	var proj_scene = _proj_scene
	if not proj_scene: return
	if not player_ref or not is_instance_valid(player_ref): return
	_play_attack_anim_then(_do_barrage)

func _do_barrage() -> void:
	if is_dead or not player_ref or not is_instance_valid(player_ref): return
	var proj_scene = _proj_scene
	if not proj_scene: return

	var base_dir = (player_ref.global_position - global_position).normalized()
	for i in BARRAGE_COUNT:
		var spread = (float(i) - BARRAGE_COUNT * 0.5) * 0.15
		var dir = base_dir.rotated(spread)
		var proj = proj_scene.instantiate()
		proj.global_position = global_position + dir * 14.0
		proj.projectile_type = "bone"
		proj.setup(dir * BARRAGE_SPEED, BARRAGE_DAMAGE)
		var parent = get_parent()
		if parent:
			parent.add_child(proj)

func _spawn_minions() -> void:
	var count = SPAWN_COUNT_P3 if phase == 3 else SPAWN_COUNT_P1
	# Spawn shadow crawlers in later phases, rushers in phase 1
	var scene_path = "res://scenes/enemies/enemy_shadow_crawler.tscn" if phase >= 2 else "res://scenes/enemies/enemy_rusher.tscn"
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

func _phase_change_visual(color: Color) -> void:
	if sprite:
		var tw = create_tween()
		tw.tween_property(sprite, "modulate", color, 0.2)
		tw.tween_property(sprite, "modulate", Color.WHITE, 0.3)
	# Warning label
	var lbl = Label.new()
	lbl.text = "PHASE %d!" % phase
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
