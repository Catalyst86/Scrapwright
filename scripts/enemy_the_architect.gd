extends EnemyBase

# The Architect — Stage 5 Final Boss (Wave 70)
# Phase 1: Spawns turrets, normal projectile burst
# Phase 2: Spawns enforcer + "BLUEPRINT MODE" electric floor grid
# Phase 3: Berserk rapid fire + Blueprint Mode repeats every 18s with extra spawns

var spawn_timer: float = 0.0
var shoot_timer: float = 0.0

# Blueprint Mode (Phase 2+)
var _blueprint_active: bool = false
var _blueprint_elapsed: float = 0.0
var _blueprint_cooldown: float = 0.0
var _blueprint_tiles: Array = []     # All tile visuals (safe + electric)
var _electric_tiles: Array = []       # Just the electric ones (for damage check)
var _blueprint_damage_dealt: bool = false

const SPAWN_INTERVAL_P1 = 10.0
const SPAWN_INTERVAL_P2 = 12.0
const TURRET_SPAWN_COUNT = 2
const ENFORCER_SPAWN_COUNT = 1

const SHOOT_INTERVAL_NORMAL = 1.8
const SHOOT_INTERVAL_BERSERK = 0.5
const PROJECTILE_SPEED = 80.0

const PREFERRED_DIST = 90.0

const BLUEPRINT_DELAY = 2.0          # Seconds before electric tiles zap
const BLUEPRINT_DURATION = 4.0       # Total duration of blueprint phase
const BLUEPRINT_DAMAGE = 15
const BLUEPRINT_TILE_SIZE = 32.0
const BLUEPRINT_COOLDOWN_P3 = 18.0

var _proj_scene: PackedScene = null

func _ready() -> void:
	enemy_type       = "the_architect"
	max_health       = 2000
	move_speed       = 25.0
	damage           = 20
	xp_value         = 400
	contact_cooldown = 1.5
	_proj_scene = load("res://scenes/enemy_projectile.tscn")
	super._ready()
	if health_bar:
		health_bar.visible = true

func _physics_process(delta: float) -> void:
	if is_dead or _phase_transitioning: return

	# Phase transitions via EnemyBase boss phase system
	# (handled automatically in take_damage -> _on_phase_change)

	# Blueprint mode processing
	if _blueprint_active:
		_process_blueprint(delta)

	# Phase 3: Blueprint cooldown
	if _boss_phase >= 3 and not _blueprint_active:
		_blueprint_cooldown += delta
		if _blueprint_cooldown >= BLUEPRINT_COOLDOWN_P3:
			_blueprint_cooldown = 0.0
			_start_blueprint()

	spawn_timer += delta
	shoot_timer += delta

	# Spawn logic
	match _boss_phase:
		1:
			if spawn_timer >= SPAWN_INTERVAL_P1:
				spawn_timer = 0.0
				_spawn_turrets(TURRET_SPAWN_COUNT)
		2:
			if spawn_timer >= SPAWN_INTERVAL_P2:
				spawn_timer = 0.0
				_spawn_enforcers(ENFORCER_SPAWN_COUNT)
		3:
			if spawn_timer >= SPAWN_INTERVAL_P2 * 0.8:
				spawn_timer = 0.0
				# Phase 3 spawns both turrets and enforcers
				_spawn_turrets(TURRET_SPAWN_COUNT)
				_spawn_enforcers(ENFORCER_SPAWN_COUNT)

	# Shooting
	var interval = SHOOT_INTERVAL_BERSERK if _boss_phase == 3 else SHOOT_INTERVAL_NORMAL
	if shoot_timer >= interval:
		shoot_timer = 0.0
		_shoot()

	super._physics_process(delta)

func _on_phase_change(new_phase: int) -> void:
	super._on_phase_change(new_phase)
	match new_phase:
		2:
			_phase_change_visual(Color(1.0, 0.8, 0.3))
			# Spawn enforcer immediately
			_spawn_enforcers(ENFORCER_SPAWN_COUNT)
			# Start blueprint mode
			_start_blueprint()
		3:
			_phase_change_visual(Color(1.0, 0.3, 0.3))
			_show_boss_warning("BERSERK!")
			move_speed = _base_move_speed * 1.5
			_blueprint_cooldown = 0.0

func _move_toward_player(delta: float) -> void:
	if not player_ref or not is_instance_valid(player_ref):
		player_ref = get_tree().get_first_node_in_group("player")
		return
	var dist = global_position.distance_to(player_ref.global_position)
	var dir  = (player_ref.global_position - global_position).normalized()
	if _boss_phase == 3:
		velocity = velocity.move_toward(dir * move_speed, move_speed * 8.0 * delta)
	elif dist > PREFERRED_DIST + 20:
		velocity = velocity.move_toward(dir * move_speed, move_speed * 8.0 * delta)
	elif dist < PREFERRED_DIST - 20:
		velocity = velocity.move_toward(-dir * move_speed * 0.6, move_speed * 8.0 * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, move_speed * 8.0 * delta)
	_update_facing()

# ---- Shooting ----
func _shoot() -> void:
	if not player_ref or not is_instance_valid(player_ref): return
	_play_attack_anim_then(_do_shoot)

func _do_shoot() -> void:
	if is_dead or not player_ref or not is_instance_valid(player_ref): return
	if not _proj_scene: return
	var dir = (player_ref.global_position - global_position).normalized()
	var parent = get_parent()
	if not parent: return

	if _boss_phase == 3:
		# Berserk: fire 3 spread shots
		for i in 3:
			var spread = (i - 1) * 0.2
			var shot_dir = dir.rotated(spread)
			var proj = _proj_scene.instantiate()
			proj.source_enemy = self
			proj.projectile_type = "steam"
			parent.add_child(proj)
			proj.global_position = global_position + shot_dir * 12.0
			proj.setup(shot_dir * PROJECTILE_SPEED * 1.3, damage)
	elif _boss_phase == 2:
		# Phase 2: 2-shot spread
		for i in 2:
			var spread = (i - 0.5) * 0.15
			var shot_dir = dir.rotated(spread)
			var proj = _proj_scene.instantiate()
			proj.source_enemy = self
			proj.projectile_type = "steam"
			parent.add_child(proj)
			proj.global_position = global_position + shot_dir * 12.0
			proj.setup(shot_dir * PROJECTILE_SPEED * 1.1, damage)
	else:
		var proj = _proj_scene.instantiate()
		proj.source_enemy = self
		proj.projectile_type = "steam"
		parent.add_child(proj)
		proj.global_position = global_position + dir * 12.0
		proj.setup(dir * PROJECTILE_SPEED, damage)

# ---- Blueprint Mode ----
func _start_blueprint() -> void:
	if _blueprint_active or is_dead: return
	_blueprint_active = true
	_blueprint_elapsed = 0.0
	_blueprint_damage_dealt = false
	_blueprint_tiles.clear()
	_electric_tiles.clear()

	_show_boss_warning("WATCH THE FLOOR!")

	var parent = get_parent()
	if not parent: return
	var center = _get_arena_center()

	# Layout: 4x3 grid of tiles. 4 safe (green), 8 electric (red) in checkerboard
	var grid_cols = 4
	var grid_rows = 3
	var tile_size = BLUEPRINT_TILE_SIZE
	var grid_origin = center - Vector2(grid_cols * tile_size * 0.5, grid_rows * tile_size * 0.5)

	# Load floor tile sprites
	var danger_tex = load("res://assets/sprites/boss_fx/electric_floor_danger.png") if ResourceLoader.exists("res://assets/sprites/boss_fx/electric_floor_danger.png") else null
	var safe_tex = load("res://assets/sprites/boss_fx/electric_floor_safe.png") if ResourceLoader.exists("res://assets/sprites/boss_fx/electric_floor_safe.png") else null

	var tile_index = 0
	for row in grid_rows:
		for col in grid_cols:
			var is_electric = (row + col) % 2 == 0
			var tile_pos = grid_origin + Vector2(col * tile_size + tile_size * 0.5, row * tile_size + tile_size * 0.5)

			# Use sprite if available, fallback to ColorRect
			var tile_node: Node2D
			var tex = danger_tex if is_electric else safe_tex
			if tex:
				var spr = Sprite2D.new()
				spr.texture = tex
				spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				spr.scale = Vector2(tile_size / 32.0, tile_size / 32.0)
				spr.global_position = tile_pos
				spr.z_index = -1
				spr.modulate.a = 0.4 if is_electric else 0.6
				tile_node = spr
			else:
				var rect = ColorRect.new()
				rect.size = Vector2(tile_size, tile_size)
				rect.position = grid_origin + Vector2(col * tile_size, row * tile_size)
				rect.z_index = -1
				rect.color = Color(1.0, 0.2, 0.1, 0.3) if is_electric else Color(0.1, 0.9, 0.2, 0.3)
				tile_node = rect

			if is_electric:
				_electric_tiles.append(tile_node)
			_blueprint_tiles.append(tile_node)
			parent.add_child(tile_node)
			tile_index += 1

	# Phase 3: Also spawn turrets and enforcer during blueprint
	if _boss_phase >= 3:
		_spawn_turrets(TURRET_SPAWN_COUNT)
		_spawn_enforcers(ENFORCER_SPAWN_COUNT)

func _process_blueprint(delta: float) -> void:
	_blueprint_elapsed += delta

	# Pulse electric tiles brighter as delay approaches
	var pulse = clampf(_blueprint_elapsed / BLUEPRINT_DELAY, 0.0, 1.0)
	for tile in _electric_tiles:
		if is_instance_valid(tile):
			tile.modulate.a = 0.4 + pulse * 0.5
			if _blueprint_elapsed >= BLUEPRINT_DELAY * 0.8:
				# Flash warning
				tile.modulate = Color(1.5, 0.5, 0.5, 0.5 + 0.3 * sin(_blueprint_elapsed * 12.0))

	# At delay threshold, deal damage if player on electric tile
	if _blueprint_elapsed >= BLUEPRINT_DELAY and not _blueprint_damage_dealt:
		_blueprint_damage_dealt = true
		_zap_electric_tiles()

	# End blueprint
	if _blueprint_elapsed >= BLUEPRINT_DURATION:
		_blueprint_active = false
		for tile in _blueprint_tiles:
			if is_instance_valid(tile):
				var tw = tile.create_tween()
				tw.tween_property(tile, "modulate:a", 0.0, 0.3)
				tw.tween_callback(tile.queue_free)
		_blueprint_tiles.clear()
		_electric_tiles.clear()

func _zap_electric_tiles() -> void:
	if not player_ref or not is_instance_valid(player_ref): return

	# Visual: flash all electric tiles bright white
	for tile in _electric_tiles:
		if is_instance_valid(tile):
			tile.modulate = Color(2.0, 2.0, 1.0, 1.0)
			var tw = tile.create_tween()
			tw.tween_property(tile, "modulate", Color(1.0, 1.0, 1.0, 0.6), 0.4)

	# Check if player is standing on any electric tile
	var player_pos = player_ref.global_position
	var half_tile = BLUEPRINT_TILE_SIZE * 0.5
	for tile in _electric_tiles:
		if not is_instance_valid(tile): continue
		if tile.global_position.distance_to(player_pos) < half_tile:
			if player_ref.has_method("take_damage"):
				player_ref.take_damage(BLUEPRINT_DAMAGE, self)
			break  # Only damage once

# ---- Spawning ----
func _spawn_turrets(count: int) -> void:
	var turret_scene = load("res://scenes/enemies/enemy_steam_turret.tscn")
	if not turret_scene: return
	var parent = get_parent()
	if not parent: return
	for i in count:
		var minion = turret_scene.instantiate()
		var angle = TAU * i / count + randf_range(-0.3, 0.3)
		minion.global_position = global_position + Vector2(cos(angle), sin(angle)) * 40.0
		minion.died.connect(func(_xp: int = 0):
			if not WaveManager.wave_active: return
			WaveManager.enemies_alive = maxi(0, WaveManager.enemies_alive - 1)
			WaveManager.emit_signal("enemies_remaining_changed", WaveManager.get_wave_enemy_count())
		)
		parent.add_child(minion)
		WaveManager.enemies_alive += 1
		WaveManager.emit_signal("enemies_remaining_changed", WaveManager.get_wave_enemy_count())

func _spawn_enforcers(count: int) -> void:
	var enforcer_scene = load("res://scenes/enemies/enemy_brass_enforcer.tscn")
	if not enforcer_scene: return
	var parent = get_parent()
	if not parent: return
	for i in count:
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

func _get_arena_center() -> Vector2:
	if player_ref and is_instance_valid(player_ref):
		var cam = player_ref.get_node_or_null("Camera2D")
		if cam: return cam.global_position
	return Vector2(480, 270)
