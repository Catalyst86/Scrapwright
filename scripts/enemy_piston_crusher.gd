extends EnemyBase

# Piston Crusher — Stage 5 Mid-Boss (Wave 63)
# Phase 1: Charge + ground pound + stun + spawns gear drones
# Phase 2 "ASSEMBLY LINE": Spawns steam turrets, push force on player, conveyor visuals
# Phase 3 "OVERCLOCK": All timers halved, assembly line repeats every 20s

var charge_timer: float = 0.0
var ground_pound_timer: float = 0.0
var spawn_timer: float = 0.0
var _is_charging: bool = false
var _charge_dir: Vector2 = Vector2.ZERO
var _charge_time: float = 0.0
var _charge_hit_player: bool = false

# Assembly Line (Phase 2+)
var _assembly_active: bool = false
var _assembly_timer: float = 0.0
var _assembly_elapsed: float = 0.0
var _assembly_arrows: Array = []

# Phase 3 repeat timer
var _assembly_cooldown: float = 0.0

var CHARGE_INTERVAL: float = 5.0
const CHARGE_SPEED = 160.0
const CHARGE_DURATION = 0.9
const CHARGE_DAMAGE = 25

var GROUND_POUND_INTERVAL: float = 4.0
const GROUND_POUND_RANGE = 55.0
const GROUND_POUND_DAMAGE = 18
const STUN_DURATION = 1.5

var SPAWN_INTERVAL: float = 8.0
const SPAWN_COUNT = 3

const ASSEMBLY_DURATION = 8.0
const ASSEMBLY_PUSH = Vector2(-30.0, 0.0)
const ASSEMBLY_COOLDOWN_P3 = 20.0

func _ready() -> void:
	enemy_type       = "piston_crusher"
	max_health       = 1400
	move_speed       = 35.0
	damage           = 25
	xp_value         = 250
	contact_cooldown = 1.5
	_is_boss = true
	super._ready()
	if health_bar:
		health_bar.visible = true

func _physics_process(delta: float) -> void:
	if is_dead or _phase_transitioning: return

	# --- Charging state ---
	if _is_charging:
		_charge_time -= delta
		velocity = _charge_dir * CHARGE_SPEED
		if _charge_time <= 0:
			_is_charging = false
			velocity = Vector2.ZERO
		if not _charge_hit_player and player_ref and is_instance_valid(player_ref):
			var dist = global_position.distance_to(player_ref.global_position)
			if dist < 20.0 and player_ref.has_method("take_damage"):
				player_ref.take_damage(CHARGE_DAMAGE, self)
				_charge_hit_player = true
		move_and_slide()
		_animate_sprite(delta)
		return

	# --- Assembly Line active ---
	if _assembly_active:
		_process_assembly(delta)

	# --- Phase 3 assembly cooldown ---
	if _boss_phase >= 3 and not _assembly_active:
		_assembly_cooldown += delta
		if _assembly_cooldown >= ASSEMBLY_COOLDOWN_P3:
			_assembly_cooldown = 0.0
			_start_assembly_line()

	charge_timer += delta
	ground_pound_timer += delta
	spawn_timer += delta

	if charge_timer >= CHARGE_INTERVAL:
		charge_timer = 0.0
		_start_charge()

	if ground_pound_timer >= GROUND_POUND_INTERVAL:
		ground_pound_timer = 0.0
		_ground_pound()

	if spawn_timer >= SPAWN_INTERVAL:
		spawn_timer = 0.0
		_spawn_drones()

	super._physics_process(delta)

func _on_phase_change(new_phase: int) -> void:
	super._on_phase_change(new_phase)
	match new_phase:
		2:
			_show_boss_warning("HOLD YOUR GROUND!")
			_start_assembly_line()
		3:
			_show_boss_warning("OVERCLOCK!")
			# Halve all timers
			CHARGE_INTERVAL = 2.5
			GROUND_POUND_INTERVAL = 2.0
			SPAWN_INTERVAL = 4.0
			_assembly_cooldown = 0.0

# ---- Charge ----
func _start_charge() -> void:
	if not player_ref or not is_instance_valid(player_ref): return
	_play_attack_anim()
	_is_charging = true
	_charge_hit_player = false
	_charge_dir = (player_ref.global_position - global_position).normalized()
	_charge_time = CHARGE_DURATION

	if sprite:
		var tw = create_tween()
		tw.tween_property(sprite, "modulate", Color(1.5, 1.0, 0.3), 0.1)
		tw.tween_property(sprite, "modulate", Color.WHITE, 0.2)

# ---- Ground Pound ----
func _ground_pound() -> void:
	if not player_ref or not is_instance_valid(player_ref): return
	_play_attack_anim()

	if sprite:
		sprite.modulate = Color(2.0, 2.0, 2.0)
		var tw = create_tween()
		tw.tween_property(sprite, "modulate", Color.WHITE, 0.3)

	# Shockwave visual
	var ring = ColorRect.new()
	ring.size = Vector2(4, 4)
	ring.position = global_position - Vector2(2, 2)
	ring.color = Color(0.8, 0.6, 0.3, 0.6)
	ring.z_index = -1
	var parent = get_parent()
	if parent:
		parent.add_child(ring)
		var tw2 = ring.create_tween()
		tw2.set_parallel(true)
		tw2.tween_property(ring, "size", Vector2(GROUND_POUND_RANGE * 2, GROUND_POUND_RANGE * 2), 0.4)
		tw2.tween_property(ring, "position", global_position - Vector2(GROUND_POUND_RANGE, GROUND_POUND_RANGE), 0.4)
		tw2.tween_property(ring, "modulate:a", 0.0, 0.4)
		tw2.set_parallel(false)
		tw2.tween_callback(ring.queue_free)

	var dist = global_position.distance_to(player_ref.global_position)
	if dist < GROUND_POUND_RANGE:
		if player_ref.has_method("take_damage"):
			player_ref.take_damage(GROUND_POUND_DAMAGE, self)
		if player_ref.has_method("stun"):
			player_ref.stun(STUN_DURATION)

	# Stun nearby enemies too
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if enemy == self or not is_instance_valid(enemy) or enemy.is_dead: continue
		var e_dist = global_position.distance_to(enemy.global_position)
		if e_dist < GROUND_POUND_RANGE * 1.5:
			enemy.stun(STUN_DURATION * 0.5)

# ---- Spawn Drones ----
func _spawn_drones() -> void:
	var drone_scene = load("res://scenes/enemies/enemy_gear_drone.tscn")
	if not drone_scene: return
	var parent = get_parent()
	if not parent: return
	for i in SPAWN_COUNT:
		var minion = drone_scene.instantiate()
		var offset = Vector2(randf_range(-25, 25), randf_range(-25, 25))
		minion.global_position = global_position + offset
		minion.died.connect(func(_xp: int = 0):
			if not WaveManager.wave_active: return
			WaveManager.enemies_alive = maxi(0, WaveManager.enemies_alive - 1)
		)
		parent.add_child(minion)
		WaveManager.enemies_alive += 1

# ---- Assembly Line ----
func _start_assembly_line() -> void:
	if _assembly_active or is_dead: return
	_assembly_active = true
	_assembly_elapsed = 0.0

	_show_boss_warning("HOLD YOUR GROUND!")

	# Spawn 2 steam turrets flanking the boss
	_spawn_steam_turrets()

	# Spawn 3 conveyor arrow visuals on the floor
	_spawn_conveyor_arrows()

func _process_assembly(delta: float) -> void:
	_assembly_elapsed += delta

	# Push player leftward each frame
	if player_ref and is_instance_valid(player_ref):
		if "velocity" in player_ref:
			player_ref.velocity += ASSEMBLY_PUSH * delta

		# Visual — conveyor pulse on arrows
		for arrow in _assembly_arrows:
			if is_instance_valid(arrow):
				arrow.modulate.a = 0.4 + 0.3 * sin(_assembly_elapsed * 4.0)

	if _assembly_elapsed >= ASSEMBLY_DURATION:
		_assembly_active = false
		# Clean up arrows
		for arrow in _assembly_arrows:
			if is_instance_valid(arrow):
				var tw = arrow.create_tween()
				tw.tween_property(arrow, "modulate:a", 0.0, 0.3)
				tw.tween_callback(arrow.queue_free)
		_assembly_arrows.clear()

func _spawn_steam_turrets() -> void:
	var turret_scene = load("res://scenes/enemies/enemy_steam_turret.tscn")
	if not turret_scene: return
	var parent = get_parent()
	if not parent: return
	for i in 2:
		var minion = turret_scene.instantiate()
		var angle = TAU * i / 2.0 + randf_range(-0.3, 0.3)
		minion.global_position = global_position + Vector2(cos(angle), sin(angle)) * 50.0
		minion.died.connect(func(_xp: int = 0):
			if not WaveManager.wave_active: return
			WaveManager.enemies_alive = maxi(0, WaveManager.enemies_alive - 1)
		)
		parent.add_child(minion)
		WaveManager.enemies_alive += 1

func _spawn_conveyor_arrows() -> void:
	var parent = get_parent()
	if not parent: return
	var center = _get_arena_center()
	for i in 3:
		var arrow = ColorRect.new()
		arrow.size = Vector2(30, 8)
		arrow.color = Color(0.9, 0.6, 0.1, 0.5)
		arrow.z_index = -1
		# Space arrows horizontally across the arena
		var x_offset = (i - 1) * 80.0
		arrow.position = center + Vector2(x_offset - 15, -4)
		parent.add_child(arrow)
		_assembly_arrows.append(arrow)

func _get_arena_center() -> Vector2:
	if player_ref and is_instance_valid(player_ref):
		var cam = player_ref.get_node_or_null("Camera2D")
		if cam: return cam.global_position
	return Vector2(480, 270)
