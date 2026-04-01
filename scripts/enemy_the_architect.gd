extends EnemyBase

# The Architect — Stage 5 Final Boss
# 3 phases: Phase 1 spawns turrets, Phase 2 spawns enforcers, Phase 3 berserk rapid fire

var phase: int = 1
var spawn_timer: float = 0.0
var shoot_timer: float = 0.0

const SPAWN_INTERVAL_P1 = 10.0
const SPAWN_INTERVAL_P2 = 12.0
const TURRET_SPAWN_COUNT = 2
const ENFORCER_SPAWN_COUNT = 1

const SHOOT_INTERVAL_NORMAL = 1.8
const SHOOT_INTERVAL_BERSERK = 0.5
const PROJECTILE_SPEED = 80.0

const PREFERRED_DIST = 90.0
var _proj_scene: PackedScene = null

func _ready() -> void:
	enemy_type       = "the_architect"
	max_health       = 1000
	move_speed       = 25.0
	damage           = 20
	xp_value         = 400
	contact_cooldown = 1.5
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
		move_speed = _base_move_speed * 1.5
		_phase_change_visual(Color(1.0, 0.3, 0.3))
	elif hp_pct <= 0.66 and phase < 2:
		phase = 2
		_phase_change_visual(Color(1.0, 0.8, 0.3))

	spawn_timer += delta
	shoot_timer += delta

	# Spawn logic
	if phase == 1 and spawn_timer >= SPAWN_INTERVAL_P1:
		spawn_timer = 0.0
		_spawn_turrets()
	elif phase == 2 and spawn_timer >= SPAWN_INTERVAL_P2:
		spawn_timer = 0.0
		_spawn_enforcers()

	# Shooting — faster in phase 3
	var interval = SHOOT_INTERVAL_BERSERK if phase == 3 else SHOOT_INTERVAL_NORMAL
	if shoot_timer >= interval:
		shoot_timer = 0.0
		_shoot()

	super._physics_process(delta)

func _move_toward_player(delta: float) -> void:
	if not player_ref or not is_instance_valid(player_ref):
		player_ref = get_tree().get_first_node_in_group("player")
		return
	var dist = global_position.distance_to(player_ref.global_position)
	var dir  = (player_ref.global_position - global_position).normalized()
	if phase == 3:
		# Berserk: chase player
		velocity = velocity.move_toward(dir * move_speed, move_speed * 8.0 * delta)
	elif dist > PREFERRED_DIST + 20:
		velocity = velocity.move_toward(dir * move_speed, move_speed * 8.0 * delta)
	elif dist < PREFERRED_DIST - 20:
		velocity = velocity.move_toward(-dir * move_speed * 0.6, move_speed * 8.0 * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, move_speed * 8.0 * delta)
	_update_facing()

func _shoot() -> void:
	if not player_ref or not is_instance_valid(player_ref): return
	_play_attack_anim_then(_do_shoot)

func _do_shoot() -> void:
	if is_dead or not player_ref or not is_instance_valid(player_ref): return
	var proj_scene = _proj_scene
	if not proj_scene: return
	var dir = (player_ref.global_position - global_position).normalized()
	if phase == 3:
		# Berserk: fire 3 spread shots
		for i in 3:
			var spread = (i - 1) * 0.2
			var shot_dir = dir.rotated(spread)
			var proj = proj_scene.instantiate()
			proj.global_position = global_position + shot_dir * 12.0
			proj.projectile_type = "steam"
			proj.setup(shot_dir * PROJECTILE_SPEED * 1.3, damage)
			var parent = get_parent()
			if parent:
				parent.add_child(proj)
	else:
		var proj = proj_scene.instantiate()
		proj.global_position = global_position + dir * 12.0
		proj.projectile_type = "steam"
		proj.setup(dir * PROJECTILE_SPEED, damage)
		var parent = get_parent()
		if parent:
			parent.add_child(proj)

func _spawn_turrets() -> void:
	var turret_scene = load("res://scenes/enemies/enemy_steam_turret.tscn")
	if not turret_scene: return
	var parent = get_parent()
	if not parent: return
	for i in TURRET_SPAWN_COUNT:
		var minion = turret_scene.instantiate()
		var angle = TAU * i / TURRET_SPAWN_COUNT + randf_range(-0.3, 0.3)
		minion.global_position = global_position + Vector2(cos(angle), sin(angle)) * 40.0
		minion.died.connect(func(_xp: int = 0):
			if not WaveManager.wave_active: return
			WaveManager.enemies_alive = maxi(0, WaveManager.enemies_alive - 1)
			WaveManager.emit_signal("enemies_remaining_changed", WaveManager.get_wave_enemy_count())
		)
		parent.add_child(minion)
		WaveManager.enemies_alive += 1
		WaveManager.emit_signal("enemies_remaining_changed", WaveManager.get_wave_enemy_count())

func _spawn_enforcers() -> void:
	var enforcer_scene = load("res://scenes/enemies/enemy_brass_enforcer.tscn")
	if not enforcer_scene: return
	var parent = get_parent()
	if not parent: return
	for i in ENFORCER_SPAWN_COUNT:
		var minion = enforcer_scene.instantiate()
		var offset = Vector2(randf_range(-30, 30), randf_range(-30, 30))
		minion.global_position = global_position + offset
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
	var flash = ColorRect.new()
	flash.color = Color(color.r, color.g, color.b, 0.4)
	flash.size = Vector2(80, 80)
	flash.position = global_position - Vector2(40, 40)
	flash.z_index = 5
	var parent = get_parent()
	if parent:
		parent.add_child(flash)
		var tw2 = flash.create_tween()
		tw2.tween_property(flash, "modulate:a", 0.0, 0.5)
		tw2.tween_callback(flash.queue_free)
