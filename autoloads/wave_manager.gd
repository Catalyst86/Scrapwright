extends Node

# ============================================================
# WaveManager — Spawning logic, wave progression (multi-stage)
# ============================================================

signal wave_complete(wave_num)
signal all_waves_complete

var current_wave: int = 0
var enemies_alive: int = 0
var wave_active: bool = false
var spawn_timer: float = 0.0
var spawn_queue: Array = []
var spawn_interval: float = 0.8

var arena_node: Node = null  # set by Arena scene

const ENEMY_SCENES = {
	# Stage 1
	"rusher": "res://scenes/enemies/enemy_rusher.tscn",
	"shooter": "res://scenes/enemies/enemy_shooter.tscn",
	"tank": "res://scenes/enemies/enemy_tank.tscn",
	"flyer": "res://scenes/enemies/enemy_flyer.tscn",
	"exploder": "res://scenes/enemies/enemy_exploder.tscn",
	# Stage 2
	"spore_walker": "res://scenes/enemies/enemy_spore_walker.tscn",
	"mycelium_sniper": "res://scenes/enemies/enemy_mycelium_sniper.tscn",
	"fungal_brute": "res://scenes/enemies/enemy_fungal_brute.tscn",
	# Stage 3
	"magma_imp": "res://scenes/enemies/enemy_magma_imp.tscn",
	"lava_lobber": "res://scenes/enemies/enemy_lava_lobber.tscn",
	"obsidian_golem": "res://scenes/enemies/enemy_obsidian_golem.tscn",
	# Bosses
	"junkyard_mech": "res://scenes/enemies/enemy_junkyard_mech.tscn",
	"fungal_titan": "res://scenes/enemies/enemy_fungal_titan.tscn",
	"molten_wyrm": "res://scenes/enemies/enemy_molten_wyrm.tscn",
	"scrap_sentinel": "res://scenes/enemies/enemy_scrap_sentinel.tscn",
	"spore_mother": "res://scenes/enemies/enemy_spore_mother.tscn",
	"ember_drake": "res://scenes/enemies/enemy_ember_drake.tscn",
	# Stage 4 — Frozen Caverns
	"frost_sprite": "res://scenes/enemies/enemy_frost_sprite.tscn",
	"ice_archer": "res://scenes/enemies/enemy_ice_archer.tscn",
	"glacial_hulk": "res://scenes/enemies/enemy_glacial_hulk.tscn",
	"crystal_bat": "res://scenes/enemies/enemy_crystal_bat.tscn",
	"frost_warden": "res://scenes/enemies/enemy_frost_warden.tscn",
	"crystal_colossus": "res://scenes/enemies/enemy_crystal_colossus.tscn",
	# Stage 5 — Clockwork Factory
	"gear_drone": "res://scenes/enemies/enemy_gear_drone.tscn",
	"steam_turret": "res://scenes/enemies/enemy_steam_turret.tscn",
	"brass_enforcer": "res://scenes/enemies/enemy_brass_enforcer.tscn",
	"spark_bug": "res://scenes/enemies/enemy_spark_bug.tscn",
	"piston_crusher": "res://scenes/enemies/enemy_piston_crusher.tscn",
	"the_architect": "res://scenes/enemies/enemy_the_architect.tscn",
	# Stage 6 — The Abyss
	"shadow_crawler": "res://scenes/enemies/enemy_shadow_crawler.tscn",
	"void_weaver": "res://scenes/enemies/enemy_void_weaver.tscn",
	"abyssal_knight": "res://scenes/enemies/enemy_abyssal_knight.tscn",
	"phantom": "res://scenes/enemies/enemy_phantom.tscn",
	"the_devourer": "res://scenes/enemies/enemy_the_devourer.tscn",
	"scrap_king": "res://scenes/enemies/enemy_scrap_king.tscn",
}

# Spawn points — arena scene registers these
var spawn_points: Array = []

# Cached enemy scenes to avoid repeated load() calls during spawning
var _scene_cache: Dictionary = {}

# Cached enemy list — refreshed every few frames to avoid O(n) per-enemy group queries
var _cached_enemies: Array = []
var _cache_frame_counter: int = 0
const CACHE_REFRESH_INTERVAL: int = 3

func _ready() -> void:
	pass

func _process(delta: float) -> void:
	if wave_active:
		_cache_frame_counter += 1
		if _cache_frame_counter >= CACHE_REFRESH_INTERVAL:
			_cache_frame_counter = 0
			_cached_enemies = get_tree().get_nodes_in_group("enemies")
	elif not _cached_enemies.is_empty():
		_cached_enemies.clear()
		_cache_frame_counter = 0
	if not wave_active:
		return
	if spawn_queue.is_empty():
		return
	spawn_timer -= delta
	if spawn_timer <= 0:
		spawn_timer = spawn_interval
		_spawn_next()

func register_arena(arena: Node) -> void:
	arena_node = arena

func register_spawn_point(pos: Vector2) -> void:
	spawn_points.append(pos)

func clear_spawn_points() -> void:
	spawn_points.clear()

func start_wave(wave_num: int) -> void:
	seed(Time.get_ticks_msec())  # Ensure varied spawn order each run
	current_wave = wave_num
	GameState._lifesteal_healed_this_wave = 0  # Reset bloodlust wave cap
	# Don't set GameState.current_wave here — only set it on wave COMPLETE
	# so quitting mid-wave doesn't advance the campaign
	wave_active = true
	spawn_queue.clear()
	enemies_alive = 0
	spawn_interval = 0.8  # Reset to default (start_custom_wave may have changed it)
	spawn_timer = 0.5  # short initial delay

	# Get wave definition from StageData
	var wave_def = StageData.get_wave_def(wave_num)
	var scale_factor = StageData.get_wave_scale_factor(wave_num)

	for group in wave_def:
		var count = int(ceil(group.count * scale_factor))
		for i in count:
			spawn_queue.append(group.type)
	spawn_queue.shuffle()
	spawn_queue.reverse()  # So we can pop_back() in O(1) instead of pop_front()




func _spawn_next() -> void:
	if spawn_queue.is_empty():
		return
	var enemy_type = spawn_queue[-1]
	var spawned = _spawn_enemy(enemy_type)
	spawn_queue.pop_back()
	if not spawned:
		# Enemy type couldn't spawn (missing scene) — skip it
		# Check if wave is complete after skipping
		_check_wave_complete()


func _spawn_enemy(type: String) -> bool:
	if not type in ENEMY_SCENES:
		return false
	if spawn_points.is_empty():
		return false
	if not is_instance_valid(arena_node):
		wave_active = false
		return false

	var scene_path = ENEMY_SCENES[type]
	if not ResourceLoader.exists(scene_path):
		return false

	var scene = _scene_cache.get(type)
	if not scene:
		scene = load(scene_path)
		if not scene:
			return false
		_scene_cache[type] = scene

	var enemy = scene.instantiate()
	var spawn_pos = spawn_points[randi() % spawn_points.size()]
	enemy.global_position = spawn_pos
	enemy.died.connect(_on_enemy_died)
	arena_node.add_child(enemy)
	enemies_alive += 1
	# Populate cache immediately so enemies see each other on their first physics
	# tick instead of after the next CACHE_REFRESH_INTERVAL (audit FP-7)
	_cached_enemies.append(enemy)

	return true

func _on_enemy_died(_xp_reward: int = 0) -> void:
	enemies_alive = maxi(0, enemies_alive - 1)
	if not is_instance_valid(arena_node):
		return

	_check_wave_complete()

func _check_wave_complete() -> void:
	if spawn_queue.is_empty() and enemies_alive <= 0 and wave_active:
		if not is_instance_valid(arena_node):
			wave_active = false
			return
		wave_active = false
		emit_signal("wave_complete", current_wave)
		if current_wave >= GameState.total_waves:
			emit_signal("all_waves_complete")

func force_complete_wave() -> void:
	if not wave_active:
		return
	wave_active = false
	spawn_queue.clear()
	enemies_alive = 0
	emit_signal("wave_complete", current_wave)
	if current_wave >= GameState.total_waves:
		emit_signal("all_waves_complete")

func abort_wave() -> void:
	wave_active = false
	spawn_queue.clear()
	enemies_alive = 0

func get_wave_enemy_count() -> int:
	return spawn_queue.size() + enemies_alive

func start_custom_wave(wave_num: int, enemy_queue: Array, interval: float) -> void:
	current_wave = wave_num
	wave_active = true
	spawn_queue = enemy_queue.duplicate()
	spawn_queue.shuffle()
	enemies_alive = 0
	spawn_interval = interval
	spawn_timer = 0.5
