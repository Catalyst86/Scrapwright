class_name EnemyBase extends CharacterBody2D

signal died(xp_reward)

@export var enemy_type: String      = "rusher"
@export var max_health: int         = 30
@export var move_speed: float       = 55.0
@export var damage: int             = 10
@export var xp_value: int           = 10
@export var contact_cooldown: float = 1.0

var health: int         = 0
var is_dead: bool       = false
var player_ref: Node    = null
var contact_timer: float = 0.0
var knockback: Vector2  = Vector2.ZERO
var is_stunned: bool    = false
var _stun_timer: float  = 0.0
var _base_move_speed: float = 0.0  # Stored after scaling, used for safe speed restoration
var _active_speed_debuffs: Dictionary = {}  # Track speed debuffs by id -> multiplier
var _is_burning := false
var _is_poisoned := false
var _poison_ticks_remaining := 0
var _burn_ticks_remaining := 0
var _has_directional_sprites: bool = false
var _current_facing: String = "south"  # "south", "east", "west"

# --- Boss Phase System ---
var _boss_phase: int = 1                      # Current phase (1, 2, or 3)
var _phase_transitioning: bool = false        # True during phase transition animation
var _phase_2_threshold: float = 0.66          # HP % to enter phase 2
var _phase_3_threshold: float = 0.33          # HP % to enter phase 3

# --- Audio ---
var _sfx_spawn: AudioStreamPlayer2D = null
var _sfx_melee: AudioStreamPlayer2D = null
var _sfx_death: AudioStreamPlayer2D = null
var _sfx_burrow: AudioStreamPlayer2D = null
var _sfx_grunt: AudioStreamPlayer2D = null
var _grunt_timer: float = 0.0

# --- Burrow-Flank System ---
var can_burrow_flank: bool = true         # Subclasses can disable (flyers, exploders)
var _is_burrowed: bool = false            # True while underground (invulnerable, non-collidable)
var _burrow_check_timer: float = 0.0      # Cooldown between cluster checks
var _burrow_cooldown: float = 0.0         # Per-enemy cooldown to prevent spam
const BURROW_CHECK_INTERVAL: float = 3.5  # Seconds between clustering checks
const BURROW_COOLDOWN: float = 8.0        # Min seconds between burrows for one enemy
const BURROW_CLUSTER_RADIUS: float = 80.0 # Pixels — how close enemies must be to count as clustered
const BURROW_CLUSTER_MIN: int = 4         # Min nearby enemies to trigger burrow consideration
const BURROW_CHANCE: float = 0.25         # 25% chance when cluster detected
const BURROW_EMERGE_DIST_MIN: float = 100.0  # Min distance from player on opposite side
const BURROW_EMERGE_DIST_MAX: float = 150.0  # Max distance from player on opposite side

# --- Stuck Detection ---
var _stuck_timer: float = 0.0
var _stuck_last_pos: Vector2 = Vector2.ZERO
const STUCK_THRESHOLD: float = 3.0    # Seconds before considered stuck
const STUCK_MOVE_MIN: float = 8.0     # Must move at least this many pixels to not be stuck
const BURROW_SINK_DURATION: float = 0.3   # Seconds to sink into ground
const BURROW_UNDERGROUND_TIME: float = 0.8  # Seconds spent underground
const BURROW_EMERGE_DURATION: float = 0.3 # Seconds to pop back up

# --- AI Steering (5-layer system) ---
var _approach_angle_offset: float = 0.0   # Random per-enemy, set at spawn
var _circle_angle: float = 0.0            # Current orbit angle around player
var _hit_retreat_timer: float = 0.0       # Countdown for retreat-after-hit
var _hit_retreat_dir: Vector2 = Vector2.ZERO
const SEPARATION_RADIUS: float = 55.0     # Wide separation — enemies can't stack
const SEPARATION_WEIGHT: float = 1.2      # Very strong separation force
const APPROACH_ANGLE_MAX: float = 1.4     # ~80 degrees — wide fan-out arc
const CIRCLE_SPEED: float = 1.5           # Radians/sec orbit speed at contact range
const CIRCLE_RANGE: float = 45.0          # Start circling from further out
const HIT_RETREAT_DURATION: float = 0.3   # Seconds of retreat after taking a hit
const HIT_RETREAT_SPEED_MULT: float = 0.7 # Retreat speed as fraction of move_speed

@onready var sprite: AnimatedSprite2D     = $AnimatedSprite2D
@onready var nav_agent: NavigationAgent2D = get_node_or_null("NavigationAgent2D")
@onready var health_bar: ProgressBar      = get_node_or_null("HealthBar")

const TYPE_COLORS = {
	"rusher":   Color(0.9, 0.2, 0.2),
	"shooter":  Color(0.9, 0.6, 0.1),
	"tank":     Color(0.4, 0.4, 0.9),
	"flyer":    Color(0.8, 0.2, 0.8),
	"exploder": Color(1.0, 0.5, 0.0),
	# Stage 2
	"spore_walker":     Color(0.3, 0.8, 0.4),
	"mycelium_sniper":  Color(0.2, 0.7, 0.6),
	"fungal_brute":     Color(0.4, 0.6, 0.3),
	# Stage 3
	"magma_imp":        Color(1.0, 0.4, 0.1),
	"lava_lobber":      Color(0.9, 0.3, 0.05),
	"obsidian_golem":   Color(0.3, 0.3, 0.35),
	# Bosses
	"junkyard_mech":    Color(0.5, 0.5, 0.55),
	"fungal_titan":     Color(0.2, 0.65, 0.3),
	"molten_wyrm":      Color(1.0, 0.35, 0.05),
	"scrap_sentinel":   Color(0.6, 0.5, 0.3),
	"spore_mother":     Color(0.5, 0.2, 0.6),
	"ember_drake":      Color(1.0, 0.5, 0.15),
	# Stage 4 — Frozen Caverns
	"frost_sprite":     Color(0.5, 0.8, 1.0),
	"ice_archer":       Color(0.3, 0.6, 0.9),
	"glacial_hulk":     Color(0.4, 0.5, 0.7),
	"crystal_bat":      Color(0.6, 0.85, 1.0),
	"frost_warden":     Color(0.2, 0.5, 0.8),
	"crystal_colossus": Color(0.35, 0.65, 0.95),
	# Stage 5 — Clockwork Factory
	"gear_drone":       Color(0.7, 0.6, 0.3),
	"steam_turret":     Color(0.6, 0.55, 0.4),
	"brass_enforcer":   Color(0.75, 0.55, 0.2),
	"spark_bug":        Color(0.9, 0.85, 0.2),
	"piston_crusher":   Color(0.5, 0.45, 0.35),
	"the_architect":    Color(0.8, 0.65, 0.15),
	# Stage 6 — The Abyss
	"shadow_crawler":   Color(0.3, 0.1, 0.4),
	"void_weaver":      Color(0.5, 0.15, 0.7),
	"abyssal_knight":   Color(0.2, 0.05, 0.3),
	"phantom":          Color(0.6, 0.3, 0.9),
	"the_devourer":     Color(0.4, 0.05, 0.5),
	"scrap_king":       Color(0.7, 0.2, 0.8),
}
const TYPE_SIZES = {
	# Stage 1 — Junkyard
	"rusher":   Vector2(38,38), "shooter": Vector2(38,38),
	"tank":     Vector2(52,52), "flyer":   Vector2(32,32), "exploder": Vector2(42,42),
	# Stage 2 — Fungal Depths
	"spore_walker":    Vector2(38,38), "mycelium_sniper": Vector2(38,38),
	"fungal_brute":    Vector2(52,52),
	# Stage 3 — Molten Core
	"magma_imp":       Vector2(32,32), "lava_lobber": Vector2(38,38),
	"obsidian_golem":  Vector2(56,56),
	# Bosses — big and imposing
	"junkyard_mech":   Vector2(160,160), "fungal_titan": Vector2(180,180),
	"scrap_sentinel":  Vector2(160,160), "spore_mother": Vector2(170,170),
	"ember_drake":     Vector2(170,170),
	"molten_wyrm":     Vector2(200,200),
	# Stage 4 — Frozen Caverns
	"frost_sprite":    Vector2(32,32), "ice_archer":      Vector2(42,42),
	"glacial_hulk":    Vector2(52,52), "crystal_bat":     Vector2(32,32),
	"frost_warden":    Vector2(160,160), "crystal_colossus": Vector2(200,200),
	# Stage 5 — Clockwork Factory
	"gear_drone":      Vector2(28,28), "steam_turret":    Vector2(42,42),
	"brass_enforcer":  Vector2(48,48), "spark_bug":       Vector2(28,28),
	"piston_crusher":  Vector2(170,170), "the_architect":  Vector2(200,200),
	# Stage 6 — The Abyss
	"shadow_crawler":  Vector2(38,38), "void_weaver":     Vector2(38,38),
	"abyssal_knight":  Vector2(52,52), "phantom":         Vector2(32,32),
	"the_devourer":    Vector2(180,180), "scrap_king":     Vector2(220,220),
}
# Key drop chances: [tier, cumulative_chance]
# Normal: bronze 30%, silver 10%, gold 4%, secret 0.5%, nothing 55.5%
# Secret keys only drop from stage-end bosses, not regular enemies
const KEY_DROP_NORMAL = [
	["bronze", 0.30],
	["silver", 0.40],
	["gold", 0.445],
	# above 0.445 = no drop
]
const KEY_DROP_BOSS = [
	["bronze", 0.25],
	["silver", 0.40],
	["gold", 0.49],
	# above 0.49 = no drop
]

var _dot: ColorRect = null
var _anim_time: float = 0.0
# Cached animation parameters (set once in _ready via _cache_anim_params)
var _anim_speed: float = 12.0
var _anim_bob_amount: float = 3.0
var _anim_squash_amount: float = 0.15

func _ready() -> void:
	_apply_stage_scaling()
	health = max_health
	add_to_group("enemies")
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value     = health
		health_bar.visible   = false
	player_ref = get_tree().get_first_node_in_group("player")
	# AI steering: randomize approach angle and orbit start position
	_approach_angle_offset = randf_range(-APPROACH_ANGLE_MAX, APPROACH_ANGLE_MAX)
	_circle_angle = randf() * TAU
	_load_sprites()
	_cache_anim_params()
	_setup_enemy_audio()

func _setup_enemy_audio() -> void:
	var sfx_base = "res://assets/audio/sfx/enemies/"
	var sfx_list = [
		["spawn.wav", "_sfx_spawn", -14.0],
		["melee_attack.wav", "_sfx_melee", -12.0],
		["enemy_death.wav", "_sfx_death", -12.0],
		["burrow.wav", "_sfx_burrow", -12.0],
	]
	for entry in sfx_list:
		var path: String = sfx_base + entry[0]
		if ResourceLoader.exists(path):
			var player = AudioStreamPlayer2D.new()
			player.stream = load(path)
			player.volume_db = entry[2]
			player.max_distance = 400.0
			player.bus = "SFX"
			add_child(player)
			set(entry[1], player)
	# Load monster-specific grunt
	var grunt_path: String = "res://assets/audio/sfx/monsters/" + enemy_type + ".wav"
	if ResourceLoader.exists(grunt_path):
		var gp = AudioStreamPlayer2D.new()
		gp.stream = load(grunt_path)
		gp.volume_db = -10.0
		gp.max_distance = 350.0
		gp.bus = "SFX"
		add_child(gp)
		_sfx_grunt = gp
		_grunt_timer = randf_range(5.0, 12.0)
	# Play spawn sound
	if _sfx_spawn:
		_sfx_spawn.pitch_scale = randf_range(0.85, 1.15)
		_sfx_spawn.play()

func _apply_stage_scaling() -> void:
	var stage_idx = GameState.get_current_stage()
	var sd = get_node_or_null("/root/StageData")
	if stage_idx > 0 and sd:
		var hp_scale = sd.get_enemy_hp_scale(enemy_type, stage_idx)
		var dmg_scale = sd.get_enemy_dmg_scale(enemy_type, stage_idx)
		if hp_scale > 1.0:
			max_health = int(max_health * hp_scale)
		if dmg_scale > 1.0:
			damage = int(damage * dmg_scale)

	# Per-wave scaling — quadratic curve: gentle early, steep late
	# Matches player's multiplicative power growth across 84 waves
	var wave = maxi(GameState.current_wave, 1)
	var t = float(wave - 1) / 83.0  # normalize to 0.0–1.0 over 84 waves
	var wave_hp_mult    = 1.0 + t * 1.5 + t * t * 3.0   # ~1.4x at wave 14, ~3.0x at wave 42, ~5.5x at wave 84
	var wave_dmg_mult   = 1.0 + t * 1.0 + t * t * 2.0   # ~1.2x at wave 14, ~2.0x at wave 42, ~4.0x at wave 84
	var wave_speed_mult = minf(1.8, 1.0 + t * 0.8)       # gradual speed increase, same 1.8x cap
	max_health = int(max_health * wave_hp_mult)
	damage = maxi(damage, ceili(damage * wave_dmg_mult))
	move_speed = move_speed * wave_speed_mult
	_base_move_speed = move_speed  # Store for safe slow/shock restoration
	# Contact damage gets faster in later waves (1.0s → 0.5s by wave 84)
	contact_cooldown = maxf(0.5, contact_cooldown - (wave - 1) * 0.006)

func _load_sprites() -> void:
	if not sprite: return
	var sf = sprite.sprite_frames
	if not sf: return

	var sheet_base = "res://assets/sprites/animations/enemy_" + enemy_type
	var static_tex = "res://assets/sprites/enemies/enemy_" + enemy_type + ".png"

	# --- Load south (default) animations ---
	var walk_sheet   = sheet_base + "_walk_sheet.png"
	var die_sheet    = sheet_base + "_die_sheet.png"
	var attack_sheet = sheet_base + "_attack_sheet.png"

	if ResourceLoader.exists(walk_sheet):
		var walk_frames = _detect_frame_count(walk_sheet)
		_load_hstrip(sf, "walk", walk_sheet, walk_frames, 8.0, true)
	elif ResourceLoader.exists(static_tex):
		_load_single(sf, "walk", static_tex, 8.0, true)

	if ResourceLoader.exists(die_sheet):
		var die_frames = _detect_frame_count(die_sheet)
		var die_speed = 4.0 if die_frames > 4 else 6.0
		_load_hstrip(sf, "die", die_sheet, die_frames, die_speed, false)
	elif ResourceLoader.exists(static_tex):
		_load_single(sf, "die", static_tex, 6.0, false)

	if ResourceLoader.exists(attack_sheet):
		var atk_frames = _detect_frame_count(attack_sheet)
		_load_hstrip(sf, "attack", attack_sheet, atk_frames, 10.0, false)

	# --- Load directional variants (east/west) if available ---
	var east_walk = sheet_base + "_walk_east_sheet.png"
	if ResourceLoader.exists(east_walk):
		_has_directional_sprites = true
		# Walk east/west
		_load_hstrip(sf, "walk_east", east_walk, _detect_frame_count(east_walk), 8.0, true)
		var west_walk = sheet_base + "_walk_west_sheet.png"
		if ResourceLoader.exists(west_walk):
			_load_hstrip(sf, "walk_west", west_walk, _detect_frame_count(west_walk), 8.0, true)
		# Attack east/west
		var east_atk = sheet_base + "_attack_east_sheet.png"
		if ResourceLoader.exists(east_atk):
			_load_hstrip(sf, "attack_east", east_atk, _detect_frame_count(east_atk), 10.0, false)
		var west_atk = sheet_base + "_attack_west_sheet.png"
		if ResourceLoader.exists(west_atk):
			_load_hstrip(sf, "attack_west", west_atk, _detect_frame_count(west_atk), 10.0, false)
		# Die east/west
		var east_die = sheet_base + "_die_east_sheet.png"
		if ResourceLoader.exists(east_die):
			var ef = _detect_frame_count(east_die)
			_load_hstrip(sf, "die_east", east_die, ef, 4.0 if ef > 4 else 6.0, false)
		var west_die = sheet_base + "_die_west_sheet.png"
		if ResourceLoader.exists(west_die):
			var wf = _detect_frame_count(west_die)
			_load_hstrip(sf, "die_west", west_die, wf, 4.0 if wf > 4 else 6.0, false)
		# Rename base anims as south aliases for clarity
		# (they already exist as "walk", "attack", "die" — used as south/fallback)

	# Pick an initial walk animation — prefer east if directional sprites exist
	var init_walk = "walk_east" if _has_directional_sprites and sf.has_animation("walk_east") else "walk"
	# Remove the auto-created "default" animation (empty, causes errors if played)
	if sf.has_animation("default") and sf.get_frame_count("default") == 0:
		sf.remove_animation("default")
	if _has_directional_sprites:
		_current_facing = "east"
	if sf.get_frame_count(init_walk) > 0:
		sprite.play(init_walk)
		# Scale sprite based on TYPE_SIZES — larger enemies get bigger sprites
		var target_size = TYPE_SIZES.get(enemy_type, Vector2(14, 14))
		var frame_tex = sf.get_frame_texture(init_walk, 0)
		if frame_tex:
			var tex_w = frame_tex.get_width()
			if tex_w > 0:
				var scale_factor = target_size.x / float(tex_w)
				sprite.scale = Vector2(scale_factor, scale_factor)
	else:
		_add_placeholder()

func _detect_frame_count(path: String) -> int:
	# Auto-detect frame count: assume square frames, so count = width / height
	var tex = load(path) as Texture2D
	if not tex: return 4
	var w = tex.get_width()
	var h = tex.get_height()
	if h <= 0: return 4
	var frames = roundi(float(w) / float(h))
	return clampi(frames, 1, 16)

func _load_hstrip(sf: SpriteFrames, anim: String, path: String, frames: int, speed: float, loop: bool) -> void:
	var sheet = load(path) as Texture2D
	if not sheet: return
	if not sf.has_animation(anim): sf.add_animation(anim)
	sf.set_animation_speed(anim, speed)
	sf.set_animation_loop(anim, loop)
	while sf.get_frame_count(anim) > 0: sf.remove_frame(anim, 0)
	var fw = sheet.get_width() / float(frames)
	var fh = sheet.get_height()
	for i in frames:
		var atlas = AtlasTexture.new()
		atlas.atlas  = sheet
		atlas.region = Rect2(i * fw, 0, fw, fh)
		sf.add_frame(anim, atlas)

func _load_single(sf: SpriteFrames, anim: String, path: String, speed: float, loop: bool) -> void:
	var tex = load(path) as Texture2D
	if not tex: return
	if not sf.has_animation(anim): sf.add_animation(anim)
	sf.set_animation_speed(anim, speed)
	sf.set_animation_loop(anim, loop)
	while sf.get_frame_count(anim) > 0: sf.remove_frame(anim, 0)
	sf.add_frame(anim, tex)

func _add_placeholder() -> void:
	var sz = TYPE_SIZES.get(enemy_type, Vector2(10,10))
	_dot = ColorRect.new()
	_dot.size     = sz
	_dot.position = -sz * 0.5
	_dot.color    = TYPE_COLORS.get(enemy_type, Color(0.9, 0.1, 0.1))
	_dot.z_index  = 1
	add_child(_dot)

func _physics_process(delta: float) -> void:
	if is_dead: return
	# Burrowed enemies skip all processing (handled by tween callbacks)
	if _is_burrowed: return
	contact_timer = maxf(0.0, contact_timer - delta)
	# Monster grunt — periodic ambient sounds
	if _sfx_grunt and not _is_burrowed:
		_grunt_timer -= delta
		if _grunt_timer <= 0.0:
			_sfx_grunt.pitch_scale = randf_range(0.88, 1.12)
			_sfx_grunt.play()
			_grunt_timer = randf_range(8.0, 18.0)
	# Burrow-flank cluster check
	if can_burrow_flank:
		_burrow_cooldown = maxf(0.0, _burrow_cooldown - delta)
		_burrow_check_timer += delta
		if _burrow_check_timer >= BURROW_CHECK_INTERVAL:
			_burrow_check_timer = 0.0
			_check_burrow_flank()
	# Stuck detection — ALL enemy types, including flyers and exploders
	if not _is_burrowed and not is_stunned:
		if global_position.distance_to(_stuck_last_pos) < STUCK_MOVE_MIN:
			_stuck_timer += delta
			if _stuck_timer >= STUCK_THRESHOLD:
				_stuck_timer = 0.0
				_force_unstuck()
		else:
			_stuck_timer = 0.0
			_stuck_last_pos = global_position
	# Stun system
	if is_stunned:
		_stun_timer -= delta
		if _stun_timer <= 0:
			is_stunned = false
			if sprite: sprite.modulate = Color.WHITE
		velocity = Vector2.ZERO
		move_and_slide()
		_animate_sprite(delta)
		return  # Skip movement and contact damage while stunned
	if knockback.length() > 2.0:
		velocity  = knockback
		knockback = knockback.move_toward(Vector2.ZERO, 420.0 * delta)
	else:
		_move_toward_player(delta)
	move_and_slide()
	_check_contact_damage()
	_animate_sprite(delta)

func _move_toward_player(delta: float) -> void:
	if not player_ref or not is_instance_valid(player_ref):
		player_ref = get_tree().get_first_node_in_group("player")
		if not player_ref:
			return
		# Fall through — player was re-fetched successfully, continue moving

	# Sneak detection: if player is sneaking and far enough, lose track
	if GameState.is_player_sneaking:
		var dist = global_position.distance_to(player_ref.global_position)
		if dist > 30.0:
			velocity = velocity.move_toward(Vector2.ZERO, move_speed * 8.0 * delta)
			return

	# --- Layer 4: Hit retreat override ---
	if _hit_retreat_timer > 0.0:
		_hit_retreat_timer -= delta
		velocity = velocity.move_toward(_hit_retreat_dir * move_speed * HIT_RETREAT_SPEED_MULT, move_speed * 10.0 * delta)
		_update_facing()
		return

	var to_player = player_ref.global_position - global_position
	var dist_to_player = to_player.length()
	var dir_to_player = to_player.normalized() if dist_to_player > 0.1 else Vector2.RIGHT

	# --- Layer 2: Approach angle variation ---
	# Always maintain at least 40% of the angle offset even at close range
	var seek_dir: Vector2
	var offset_fade = clampf(dist_to_player / (CIRCLE_RANGE * 3.0), 0.4, 1.0)
	seek_dir = dir_to_player.rotated(_approach_angle_offset * offset_fade)

	# --- Layer 1: Separation from nearby allies ---
	var separation_force = _compute_separation()

	# --- Layer 3: Circling behavior (when close to player) ---
	var circle_force = Vector2.ZERO
	var aggression = _get_wave_aggression()

	if dist_to_player < CIRCLE_RANGE:
		var circle_dir_sign = signf(_approach_angle_offset) if absf(_approach_angle_offset) > 0.01 else 1.0
		_circle_angle += CIRCLE_SPEED * delta * circle_dir_sign
		var orbit_pos = player_ref.global_position + Vector2(cos(_circle_angle), sin(_circle_angle)) * CIRCLE_RANGE
		circle_force = (orbit_pos - global_position).normalized()

	# --- Blend forces based on distance and aggression (Layer 5) ---
	var desired_dir: Vector2
	if dist_to_player < CIRCLE_RANGE:
		# Near player: blend between circling and direct attack
		desired_dir = circle_force.lerp(seek_dir, aggression)
	else:
		desired_dir = seek_dir

	# Add separation (always active)
	desired_dir = (desired_dir + separation_force * SEPARATION_WEIGHT).normalized()

	# Apply via nav agent (far) or direct (close)
	if nav_agent and dist_to_player > CIRCLE_RANGE * 2.0:
		nav_agent.target_position = player_ref.global_position + dir_to_player.rotated(_approach_angle_offset) * -10.0
		if not nav_agent.is_navigation_finished():
			var next = nav_agent.get_next_path_position()
			var nav_dir = (next - global_position).normalized()
			nav_dir = (nav_dir + separation_force * SEPARATION_WEIGHT).normalized()
			velocity = velocity.move_toward(nav_dir * move_speed, move_speed * 10.0 * delta)
		else:
			velocity = velocity.move_toward(Vector2.ZERO, move_speed * 8.0 * delta)
	else:
		velocity = velocity.move_toward(desired_dir * move_speed, move_speed * 10.0 * delta)

	_update_facing()

func _compute_separation() -> Vector2:
	var force = Vector2.ZERO
	var nearby_count = 0
	var sep_radius_sq = SEPARATION_RADIUS * SEPARATION_RADIUS
	# Use cached list from WaveManager if available to avoid O(n) group query per enemy
	var enemies: Array
	if WaveManager and WaveManager.get("_cached_enemies") is Array and not WaveManager._cached_enemies.is_empty():
		enemies = WaveManager._cached_enemies
	else:
		enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if enemy == self or not is_instance_valid(enemy):
			continue
		var diff = global_position - enemy.global_position
		var dist_sq = diff.length_squared()
		if dist_sq < sep_radius_sq and dist_sq > 0.1:
			var strength = 1.0 - (sqrt(dist_sq) / SEPARATION_RADIUS)
			force += diff.normalized() * strength
			nearby_count += 1
			if nearby_count >= 8:
				break  # Limit to nearest 8 to cap O(n^2)
	if nearby_count > 0:
		force /= nearby_count
	return force

func _get_wave_aggression() -> float:
	var wave = maxi(GameState.current_wave, 1)
	return clampf(0.15 + wave * 0.01, 0.15, 0.95)

func _cache_anim_params() -> void:
	# Cache per-type animation parameters once at spawn instead of branching every frame.
	# Defaults: anim_speed=12.0, bob_amount=3.0, squash_amount=0.15
	const ANIM_PARAMS := {
		# [anim_speed, bob_amount, squash_amount]
		"tank":              [8.0,  2.0, 0.10],
		"fungal_brute":      [8.0,  2.0, 0.10],
		"flyer":             [16.0, 5.0, 0.20],
		"magma_imp":         [16.0, 5.0, 0.20],
		"exploder":          [10.0, 3.0, 0.18],
		"obsidian_golem":    [6.0,  1.5, 0.08],
		"mycelium_sniper":   [10.0, 3.0, 0.15],
		"lava_lobber":       [10.0, 3.0, 0.15],
		"scrap_sentinel":    [4.5,  1.5, 0.04],
		"spore_mother":      [3.5,  1.2, 0.04],
		"ember_drake":       [4.0,  1.8, 0.04],
		"junkyard_mech":     [4.0,  1.5, 0.04],
		"fungal_titan":      [3.5,  1.2, 0.03],
		"molten_wyrm":       [3.5,  2.0, 0.03],
		# Stage 4
		"frost_sprite":      [16.0, 4.0, 0.18],
		"ice_archer":        [10.0, 3.0, 0.15],
		"glacial_hulk":      [6.0,  1.5, 0.08],
		"crystal_bat":       [16.0, 5.0, 0.20],
		"frost_warden":      [4.0,  1.5, 0.04],
		"crystal_colossus":  [3.5,  1.2, 0.03],
		# Stage 5
		"gear_drone":        [18.0, 3.0, 0.15],
		"steam_turret":      [4.0,  0.5, 0.05],
		"brass_enforcer":    [7.0,  2.0, 0.10],
		"spark_bug":         [16.0, 5.0, 0.20],
		"piston_crusher":    [4.0,  1.5, 0.04],
		"the_architect":     [3.5,  1.2, 0.03],
		# Stage 6
		"shadow_crawler":    [14.0, 3.5, 0.16],
		"void_weaver":       [10.0, 3.0, 0.15],
		"abyssal_knight":    [6.0,  1.8, 0.08],
		"phantom":           [12.0, 4.0, 0.18],
		"the_devourer":      [3.5,  1.5, 0.04],
		"scrap_king":        [3.0,  1.0, 0.03],
	}
	if enemy_type in ANIM_PARAMS:
		var p: Array = ANIM_PARAMS[enemy_type]
		_anim_speed = p[0]
		_anim_bob_amount = p[1]
		_anim_squash_amount = p[2]
	# else: defaults (12.0, 3.0, 0.15) already set at declaration

func _animate_sprite(delta: float) -> void:
	if not sprite or is_dead: return
	_anim_time += delta
	# Calculate base_scale from TYPE_SIZES and actual sprite frame size
	var target = TYPE_SIZES.get(enemy_type, Vector2(56, 56))
	var base_scale = 1.0
	if sprite.sprite_frames and sprite.sprite_frames.get_frame_count("walk") > 0:
		var ftex = sprite.sprite_frames.get_frame_texture("walk", 0)
		if ftex and ftex.get_width() > 0:
			base_scale = target.x / float(ftex.get_width())
	if velocity.length() > 5.0:
		var bob = sin(_anim_time * _anim_speed) * _anim_bob_amount
		sprite.offset.y = bob
		var squash = 1.0 + sin(_anim_time * _anim_speed) * _anim_squash_amount
		sprite.scale.x = base_scale / squash
		sprite.scale.y = base_scale * squash
		sprite.rotation = sin(_anim_time * _anim_speed * 0.5) * 0.05
	else:
		var breathe = sin(_anim_time * 3.5) * 0.04
		sprite.scale.x = base_scale + breathe
		sprite.scale.y = base_scale - breathe
		sprite.offset.y = sin(_anim_time * 2.5) * 1.2
		sprite.rotation = 0.0

func _update_facing() -> void:
	if not sprite or is_dead: return
	var sf = sprite.sprite_frames
	if not sf: return

	# Determine desired facing direction from velocity (actual movement, not player pos)
	var new_facing := _current_facing
	var move_dx := velocity.x

	if _has_directional_sprites:
		# Use velocity direction for facing — prevents jitter when near player
		if abs(move_dx) > 8.0:
			new_facing = "east" if move_dx > 0 else "west"
		# If stationary, face toward player
		elif player_ref and is_instance_valid(player_ref) and velocity.length() < 5.0:
			var dx_to_player = player_ref.global_position.x - global_position.x
			if abs(dx_to_player) > 10.0:
				new_facing = "east" if dx_to_player > 0 else "west"
		# Otherwise keep current facing (no snap)

		sprite.flip_h = false  # Never flip when we have directional sheets

		# Don't interrupt attack or die animations
		var cur: String = sprite.animation
		var is_action_anim = cur.begins_with("attack") or cur.begins_with("die")
		if not is_action_anim:
			var walk_anim = "walk_" + new_facing if new_facing != "south" else "walk"
			if sf.has_animation(walk_anim) and sf.get_frame_count(walk_anim) > 0:
				if sprite.animation != walk_anim:
					sprite.play(walk_anim)
			elif sf.has_animation("walk") and sprite.animation != "walk":
				sprite.play("walk")
		_current_facing = new_facing
	else:
		# Fallback: original flip_h behavior
		var dx_fallback := 0.0
		if player_ref and is_instance_valid(player_ref):
			dx_fallback = player_ref.global_position.x - global_position.x
		elif velocity.length() > 5.0:
			dx_fallback = velocity.x
		sprite.flip_h = dx_fallback > 0
		# Don't interrupt attack or die animations with walk
		var cur: StringName = sprite.animation if sf.has_animation(sprite.animation) else &""
		if cur != "attack" and cur != "die":
			if sf.get_frame_count("walk") > 0 and sprite.animation != "walk":
				sprite.play("walk")

func _check_contact_damage() -> void:
	if not player_ref or not is_instance_valid(player_ref): return
	var dist_sq = global_position.distance_squared_to(player_ref.global_position)
	# Scale contact range based on sprite size — bosses are 160px+, grunts are 38px
	var target_size = TYPE_SIZES.get(enemy_type, Vector2(14, 14))
	var contact_range = maxf(18.0, target_size.x * 0.25)  # 25% of sprite width
	var contact_range_sq = contact_range * contact_range
	var anim_range_sq = (contact_range * 3.0) * (contact_range * 3.0)
	# Play attack animation when approaching the player (visible wind-up before contact)
	if dist_sq < anim_range_sq and sprite and sprite.animation != "attack":
		_play_attack_anim()
	# Actual damage on close contact
	if contact_timer > 0: return
	if dist_sq < contact_range_sq:
		if player_ref.has_method("take_damage"):
			player_ref.take_damage(damage, self)
		if _sfx_melee:
			_sfx_melee.pitch_scale = randf_range(0.9, 1.1)
			_sfx_melee.play()
		contact_timer = contact_cooldown

var _attack_anim_playing: bool = false

func _get_directional_anim(base_name: String) -> String:
	# Resolve directional animation name, e.g. 'attack' -> 'attack_east' if available.
	if not _has_directional_sprites or not sprite or not sprite.sprite_frames:
		return base_name
	var dir_name = base_name + "_" + _current_facing
	if _current_facing != "south" and sprite.sprite_frames.has_animation(dir_name):
		return dir_name
	return base_name  # Fallback to south/default

func _get_directional_walk() -> String:
	# Resolve current walk animation name.
	return _get_directional_anim("walk")

func _play_attack_anim() -> void:
	if _attack_anim_playing: return
	if not sprite or not sprite.sprite_frames: return
	var atk_anim = _get_directional_anim("attack")
	if not sprite.sprite_frames.has_animation(atk_anim): return
	if sprite.sprite_frames.get_frame_count(atk_anim) <= 0: return
	_attack_anim_playing = true
	sprite.play(atk_anim)
	var frame_count = sprite.sprite_frames.get_frame_count(atk_anim)
	var anim_speed = sprite.sprite_frames.get_animation_speed(atk_anim)
	if anim_speed > 0:
		var dur = frame_count / anim_speed
		var timer := Timer.new()
		timer.wait_time = dur
		timer.one_shot = true
		add_child(timer)
		timer.timeout.connect(func():
			_attack_anim_playing = false
			if is_instance_valid(self) and not is_dead and sprite:
				sprite.play(_get_directional_walk())
			timer.queue_free()
		)
		timer.start()
	else:
		_attack_anim_playing = false

func _play_attack_anim_then(callback: Callable) -> void:
	# Play attack animation, fire the callback at the peak (40% through),
	# then finish the animation
	if not sprite or not sprite.sprite_frames: return
	var atk_anim = _get_directional_anim("attack")
	if not sprite.sprite_frames.has_animation(atk_anim) or sprite.sprite_frames.get_frame_count(atk_anim) <= 0:
		callback.call()
		return
	if _attack_anim_playing: return
	_attack_anim_playing = true
	sprite.play(atk_anim)
	var frame_count = sprite.sprite_frames.get_frame_count(atk_anim)
	var anim_speed = sprite.sprite_frames.get_animation_speed(atk_anim)
	if anim_speed > 0:
		var total_dur = frame_count / anim_speed
		# Fire callback at 40% (wind-up peak)
		var peak_timer := Timer.new()
		peak_timer.wait_time = total_dur * 0.4
		peak_timer.one_shot = true
		add_child(peak_timer)
		peak_timer.timeout.connect(func():
			peak_timer.queue_free()
			if not is_instance_valid(self) or is_dead:
				_attack_anim_playing = false
				return
			callback.call()
			# Wait for remaining animation
			var end_timer := Timer.new()
			end_timer.wait_time = total_dur * 0.6
			end_timer.one_shot = true
			add_child(end_timer)
			end_timer.timeout.connect(func():
				_attack_anim_playing = false
				if is_instance_valid(self) and not is_dead and sprite:
					sprite.play(_get_directional_walk())
				end_timer.queue_free()
			)
			end_timer.start()
		)
		peak_timer.start()
	else:
		callback.call()
		_attack_anim_playing = false

func stun(duration: float) -> void:
	if is_dead: return
	is_stunned = true
	_stun_timer = duration
	velocity = Vector2.ZERO
	if sprite: sprite.modulate = Color(0.5, 0.5, 1.0)  # Blue tint while stunned

func take_damage(amount: int, from_pos: Vector2 = Vector2.ZERO) -> void:
	if is_dead or _is_burrowed or _phase_transitioning: return
	if amount <= 0: return  # Prevent zero-damage spam and negative-healing exploit
	health -= amount
	if health_bar:
		health_bar.visible = true
		health_bar.value   = health
	if from_pos != Vector2.ZERO:
		knockback = (global_position - from_pos).normalized() * 140.0
		# Layer 4: Hit retreat — briefly steer away after taking damage
		_hit_retreat_timer = HIT_RETREAT_DURATION
		_hit_retreat_dir = (global_position - from_pos).normalized()
	elif velocity.length() > 1.0:
		_hit_retreat_timer = HIT_RETREAT_DURATION
		_hit_retreat_dir = -velocity.normalized()
	_show_damage_number(amount)
	# Boss phase transitions — use sequential ifs (not elif) so burst damage
	# that skips past both thresholds triggers both phases in order.
	if not _phase_transitioning:
		var hp_pct = float(health) / float(max_health)
		if _boss_phase < 2 and hp_pct <= _phase_2_threshold:
			_boss_phase = 2
			_phase_transitioning = true
			_on_phase_change(2)
			_phase_transitioning = false
		if _boss_phase < 3 and hp_pct <= _phase_3_threshold:
			_boss_phase = 3
			_phase_transitioning = true
			_on_phase_change(3)
			_phase_transitioning = false
	if health <= 0:
		# Skip damage flash on killing blow — go straight to death
		if sprite: sprite.modulate = Color.WHITE
		_die()
		return
	# Damage flash (only on non-lethal hits)
	if sprite:
		sprite.modulate = Color(1.6, 0.4, 0.4)
		var tw = create_tween()
		tw.tween_property(sprite, "modulate", Color.WHITE, 0.12)
	if _dot:
		_dot.modulate = Color(2.0, 0.5, 0.5)
		var tw2 = create_tween()
		tw2.tween_property(_dot, "modulate", Color.WHITE, 0.12)

func _show_damage_number(amount: int) -> void:
	var lbl = Label.new()
	lbl.text = str(amount)
	lbl.z_index = 20
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	lbl.add_theme_constant_override("shadow_offset_x", 1)
	lbl.add_theme_constant_override("shadow_offset_y", 1)
	lbl.position = global_position + Vector2(randf_range(-8, 8), -16)
	var parent = get_parent() if get_parent() else self
	parent.add_child(lbl)
	var tw3 = lbl.create_tween()
	tw3.set_parallel(true)
	tw3.tween_property(lbl, "position:y", lbl.position.y - 22.0, 0.5).set_ease(Tween.EASE_OUT)
	tw3.tween_property(lbl, "modulate:a", 0.0, 0.5).set_delay(0.25)
	tw3.set_parallel(false)
	tw3.tween_callback(lbl.queue_free)

# --- Boss Phase System (override in boss subclasses) ---
func _on_phase_change(new_phase: int) -> void:
	# Override in boss scripts to handle phase transitions
	# Flash white to signal phase change
	if sprite:
		var tw = create_tween()
		tw.tween_property(sprite, "modulate", Color(2.5, 2.5, 2.5), 0.15)
		tw.tween_property(sprite, "modulate", Color.WHITE, 0.3)

func _show_boss_warning(text: String) -> void:
	# Show a warning banner via the arena's HUD
	var arena = get_tree().current_scene
	if arena and arena.has_method("_show_banner"):
		arena._show_banner(text, Color(1.0, 0.3, 0.3), 2.0)

func _spawn_cover_obstacle(pos: Vector2, sprite_name: String, hp: int = 10, cover_scale: float = 2.0) -> Node2D:
	# Spawn a destructible cover obstacle at the given position
	var obstacle = StaticBody2D.new()
	obstacle.collision_layer = 1  # Wall layer — blocks movement
	obstacle.collision_mask = 0
	obstacle.global_position = pos
	obstacle.add_to_group("boss_obstacles")
	obstacle.add_to_group("wall")  # So projectiles collide with it

	var col = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(24.0 * cover_scale, 24.0 * cover_scale)
	col.shape = shape
	obstacle.add_child(col)

	var tex_path = "res://assets/sprites/boss_fx/%s.png" % sprite_name
	if ResourceLoader.exists(tex_path):
		var spr = Sprite2D.new()
		spr.texture = load(tex_path)
		spr.scale = Vector2(cover_scale, cover_scale)
		obstacle.add_child(spr)
	else:
		# Fallback colored rectangle
		var fallback = ColorRect.new()
		fallback.size = Vector2(24 * cover_scale, 24 * cover_scale)
		fallback.position = -fallback.size / 2.0
		fallback.color = Color(0.5, 0.4, 0.3, 0.8)
		obstacle.add_child(fallback)

	# Make it destructible — store HP as metadata
	obstacle.set_meta("hp", hp)
	obstacle.set_meta("max_hp", hp)

	var parent = get_parent()
	if parent:
		parent.add_child(obstacle)
	return obstacle

func _clear_boss_obstacles() -> void:
	for obs in get_tree().get_nodes_in_group("boss_obstacles"):
		if is_instance_valid(obs):
			obs.queue_free()

func _die() -> void:
	if is_dead: return
	_attack_anim_playing = false
	_phase_transitioning = false
	_clear_boss_obstacles()  # Clean up cover/obstacles from any boss phase
	is_dead = true
	set_physics_process(false)
	set_collision_layer_value(2, false)
	set_collision_mask_value(1, false)
	emit_signal("died", xp_value)
	# Bloodlust — heal player on kill (capped at 30% max HP per wave)
	if GameState.perk_lifesteal > 0:
		var cap = int(GameState.player_max_health * 0.3)
		if GameState._lifesteal_healed_this_wave < cap:
			var heal_amt = mini(GameState.perk_lifesteal, cap - GameState._lifesteal_healed_this_wave)
			GameState.heal(heal_amt)
			GameState._lifesteal_healed_this_wave += heal_amt
	# Drop XP orb instead of instant XP — player must collect it
	_drop_xp_orb()
	if _sfx_death:
		_sfx_death.pitch_scale = randf_range(0.85, 1.15)
		_sfx_death.play()
	_drop_key()
	# Track junkyard kills
	var js = get_node_or_null("/root/JunkyardState")
	if js and js.is_active:
		js.add_kill()
	# Track achievement stats
	var ach = get_node_or_null("/root/Achievements")
	if ach:
		ach.increment_stat("kills_this_run")
		ach.increment_stat("total_kills")
		# Boss slayer — only awarded when an actual boss enemy dies
		if enemy_type in ["junkyard_mech", "fungal_titan", "molten_wyrm", "scrap_sentinel", "spore_mother", "ember_drake", "frost_warden", "crystal_colossus", "piston_crusher", "the_architect", "the_devourer", "scrap_king"]:
			ach.check_and_unlock("boss_slayer")
	# Boss skin drop — bosses have a chance to drop an armor unlock
	_try_drop_skin()
	# Hide the colored square placeholder during death
	if _dot:
		_dot.visible = false
	var die_anim = _get_directional_anim("die")
	var die_duration := 0.5
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation(die_anim):
		var fc = sprite.sprite_frames.get_frame_count(die_anim)
		if fc > 0:
			# Reset ALL transforms so die animation plays cleanly
			sprite.offset.y = 0.0
			sprite.rotation = 0.0
			sprite.modulate = Color.WHITE
			# Reset scale to base (undo squash/stretch from _animate_sprite)
			var target_size = TYPE_SIZES.get(enemy_type, Vector2(14, 14))
			var die_tex = sprite.sprite_frames.get_frame_texture(die_anim, 0)
			if die_tex and die_tex.get_width() > 0:
				var base_s = target_size.x / float(die_tex.get_width())
				sprite.scale = Vector2(base_s, base_s)
			# Force non-looping and speed for ~1s playback
			sprite.sprite_frames.set_animation_loop(die_anim, false)
			var die_fps = maxf(float(fc) / 1.0, 6.0)
			sprite.sprite_frames.set_animation_speed(die_anim, die_fps)
			sprite.play(die_anim)
			die_duration = fc / die_fps
			# Freeze on last frame when done — explicitly lock frame index
			var last_frame = fc - 1
			sprite.animation_finished.connect(func():
				if sprite:
					sprite.pause()
					sprite.frame = last_frame
			, CONNECT_ONE_SHOT)
	await get_tree().create_timer(die_duration + 0.1).timeout
	if not is_inside_tree(): return
	# Safety: force-lock to last frame in case animation_finished didn't fire cleanly
	if sprite:
		sprite.pause()
		var final_fc = sprite.sprite_frames.get_frame_count(die_anim) if sprite.sprite_frames.has_animation(die_anim) else 0
		if final_fc > 0:
			sprite.frame = final_fc - 1
	# Hold the final death frame briefly, then fade out
	await get_tree().create_timer(0.4).timeout
	if not is_inside_tree(): return
	if sprite:
		var tw = create_tween()
		tw.tween_property(sprite, "modulate:a", 0.0, 0.5)
		await tw.finished
		if not is_inside_tree(): return
	queue_free()

func _drop_xp_orb() -> void:
	if xp_value <= 0:
		return
	var xp_scene = load("res://scenes/xp_pickup.tscn")
	if not xp_scene:
		# Fallback: grant XP directly if scene is missing
		GameState.gain_xp(xp_value)
		return
	var xp_orb = xp_scene.instantiate()
	xp_orb.xp_amount = xp_value
	xp_orb.global_position = global_position
	var container = get_tree().get_first_node_in_group("pickups_container")
	if container:
		container.call_deferred("add_child", xp_orb)
	else:
		# Fallback if no container found
		GameState.gain_xp(xp_value)

func _drop_key() -> void:
	# Boss enemies don't drop keys
	# Stage-end bosses (wave 14 of each stage) drop a guaranteed secret key
	var sd = get_node_or_null("/root/StageData")
	if enemy_type in ["junkyard_mech", "fungal_titan", "molten_wyrm", "scrap_sentinel", "spore_mother", "ember_drake", "frost_warden", "crystal_colossus", "piston_crusher", "the_architect", "the_devourer", "scrap_king"]:
		if sd and sd.has_method("get_stage_wave") and sd.get_stage_wave(GameState.current_wave) == 14:
			call_deferred("_deferred_spawn_key", "secret")
		return
	var is_boss = false
	if sd and sd.has_method("is_boss_wave"):
		is_boss = sd.is_boss_wave(GameState.current_wave)
	var drop_table = KEY_DROP_BOSS if is_boss else KEY_DROP_NORMAL
	var roll = randf()
	var tier = ""
	for entry in drop_table:
		if roll < entry[1]:
			tier = entry[0]
			break
	if tier == "":
		return  # No drop
	# Defer spawning to avoid physics flushing errors when killed by dig hole
	call_deferred("_deferred_spawn_key", tier)

func _deferred_spawn_key(tier: String) -> void:
	if not is_instance_valid(self) or not get_parent():
		GameState.add_key(tier)
		return
	var container = _get_pickup_container()
	var ps = load("res://scenes/key_pickup.tscn")
	if ps:
		var p = ps.instantiate()
		p.key_tier = tier
		p.global_position = global_position + Vector2(randf_range(-8, 8), randf_range(-8, 8))
		container.add_child(p)
	else:
		GameState.add_key(tier)

func _try_drop_skin() -> void:
	# Only bosses can drop skins
	var boss_types = [
		"junkyard_mech", "fungal_titan", "molten_wyrm",
		"scrap_sentinel", "spore_mother", "ember_drake",
		"frost_warden", "crystal_colossus", "piston_crusher",
		"the_architect", "the_devourer", "scrap_king",
	]
	if enemy_type not in boss_types:
		return

	# Boss-specific skin drops (guaranteed from certain bosses, chance from others)
	var armor_db = get_node_or_null("/root/ArmorDB")
	if not armor_db:
		return

	# Map boss types to the skins they can drop
	var boss_skin_table = {
		"scrap_sentinel": ["leather_vest"],
		"junkyard_mech": ["scrap_shield", "iron_mail"],
		"spore_mother": ["flower_crown"],
		"fungal_titan": ["fungal_hide"],
		"ember_drake": ["pirate_patch"],
		"molten_wyrm": ["obsidian_shell"],
		"frost_warden": ["crystal_vest"],
		"crystal_colossus": ["golden_collar"],
		"piston_crusher": ["steam_harness", "goggles"],
		"the_architect": ["void_cloak"],
		"the_devourer": ["phoenix_mantle"],
		"scrap_king": ["junkyard_crown"],
	}

	var possible_skins = boss_skin_table.get(enemy_type, [])
	if possible_skins.is_empty():
		return

	# 40% chance to drop a skin (60% for final bosses)
	var drop_chance = 0.6 if enemy_type in ["junkyard_mech", "fungal_titan", "molten_wyrm", "crystal_colossus", "the_architect", "scrap_king"] else 0.4
	if randf() > drop_chance:
		return

	# Pick a random skin from the pool, only if not already unlocked
	var locked_skins: Array = []
	for skin_id in possible_skins:
		if not armor_db.is_unlocked(skin_id):
			locked_skins.append(skin_id)

	if locked_skins.is_empty():
		return  # Already have all skins from this boss

	var skin_id = locked_skins[randi() % locked_skins.size()]
	armor_db.unlock_armor(skin_id)

	# Show unlock notification
	var skin_data = armor_db.get_armor(skin_id)
	var skin_name = skin_data.get("name", skin_id.replace("_", " ").capitalize())
	var popup = Label.new()
	popup.text = "NEW SKIN: %s!" % skin_name
	popup.add_theme_font_size_override("font_size", 12)
	popup.add_theme_color_override("font_color", Color(0.95, 0.82, 0.35))
	popup.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	popup.add_theme_constant_override("shadow_offset_x", 1)
	popup.add_theme_constant_override("shadow_offset_y", 1)
	popup.z_index = 20
	popup.global_position = global_position + Vector2(-40, -30)
	var container = _get_pickup_container()
	container.add_child(popup)
	var tw = popup.create_tween()
	tw.tween_property(popup, "position:y", popup.position.y - 30, 1.5)
	tw.parallel().tween_property(popup, "modulate:a", 0.0, 1.5).set_delay(0.5)
	tw.tween_callback(popup.queue_free)

func _get_pickup_container() -> Node:
	var parent = get_parent()
	if parent:
		var c = parent.get_node_or_null("PickupsContainer")
		if c: return c
	return get_tree().current_scene if get_tree() else self

# ==============================
# Burrow-Flank System
# ==============================

func _force_unstuck() -> void:
	if is_dead or _is_burrowed or not player_ref or not is_instance_valid(player_ref):
		return
	# Teleport to a random position near the player
	var emerge_dist = randf_range(BURROW_EMERGE_DIST_MIN, BURROW_EMERGE_DIST_MAX)
	var angle = randf() * TAU
	var emerge_dir = Vector2(cos(angle), sin(angle))
	var emerge_pos = player_ref.global_position + emerge_dir * emerge_dist
	emerge_pos = _clamp_to_arena(emerge_pos)
	if can_burrow_flank:
		# Full burrow animation for enemies that support it
		_start_burrow(emerge_pos)
	else:
		# Direct teleport with quick fade for flyers/exploders
		var tw = create_tween()
		tw.tween_property(self, "modulate:a", 0.0, 0.2)
		tw.tween_callback(func():
			global_position = emerge_pos
		)
		tw.tween_property(self, "modulate:a", 1.0, 0.2)

func _check_burrow_flank() -> void:
	if _burrow_cooldown > 0.0 or _is_burrowed or is_dead or is_stunned:
		return
	if not player_ref or not is_instance_valid(player_ref):
		return
	# Count nearby enemies within cluster radius
	var cluster_count := 0
	var cluster_radius_sq = BURROW_CLUSTER_RADIUS * BURROW_CLUSTER_RADIUS
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy == self or not is_instance_valid(enemy):
			continue
		if enemy.is_dead:
			continue
		if enemy.get("_is_burrowed") and enemy._is_burrowed:
			continue
		var dist_sq = global_position.distance_squared_to(enemy.global_position)
		if dist_sq < cluster_radius_sq:
			cluster_count += 1
	if cluster_count < BURROW_CLUSTER_MIN:
		return
	# Roll the dice
	if randf() > BURROW_CHANCE:
		return
	# Calculate emerge position
	var emerge_dist = randf_range(BURROW_EMERGE_DIST_MIN, BURROW_EMERGE_DIST_MAX)
	var emerge_dir: Vector2
	if randf() < 0.45 and player_ref.velocity.length() > 15.0:
		# 45% chance: emerge AHEAD of the player's movement direction
		emerge_dir = player_ref.velocity.normalized()
	else:
		# 55% chance: emerge on the opposite side (original behavior)
		emerge_dir = -(global_position - player_ref.global_position).normalized()
	# Add random angle offset (up to 35 degrees) so multiple burrowers don't stack
	var emerge_pos = player_ref.global_position + emerge_dir.rotated(randf_range(-0.6, 0.6)) * emerge_dist
	# Clamp to map bounds so enemies never teleport outside the arena
	emerge_pos = _clamp_to_arena(emerge_pos)
	_start_burrow(emerge_pos)

func _start_burrow(emerge_pos: Vector2) -> void:
	_is_burrowed = true
	_burrow_cooldown = BURROW_COOLDOWN
	velocity = Vector2.ZERO
	if _sfx_burrow:
		_sfx_burrow.pitch_scale = randf_range(0.9, 1.1)
		_sfx_burrow.play()
	# Disable collision while underground
	set_collision_layer_value(2, false)
	set_collision_mask_value(1, false)
	set_collision_mask_value(5, false)
	# --- Sink animation ---
	# Darken the sprite slightly as it sinks
	var sink_tween = create_tween()
	sink_tween.set_parallel(true)
	if sprite:
		sink_tween.tween_property(sprite, "scale:y", 0.0, BURROW_SINK_DURATION).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		sink_tween.tween_property(sprite, "modulate", Color(0.4, 0.35, 0.3), BURROW_SINK_DURATION)
		sink_tween.tween_property(sprite, "offset:y", 0.0, BURROW_SINK_DURATION)
	if _dot:
		sink_tween.tween_property(_dot, "scale:y", 0.0, BURROW_SINK_DURATION).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		sink_tween.tween_property(_dot, "modulate", Color(0.4, 0.35, 0.3), BURROW_SINK_DURATION)
	sink_tween.set_parallel(false)
	sink_tween.tween_callback(_spawn_burrow_dust.bind(global_position))
	sink_tween.tween_callback(_spawn_ground_cracks.bind(global_position, false))
	# Wait underground
	sink_tween.tween_interval(BURROW_UNDERGROUND_TIME * 0.5)
	# Spawn cracks at emerge position to telegraph arrival
	sink_tween.tween_callback(_spawn_ground_cracks.bind(emerge_pos, true))
	sink_tween.tween_interval(BURROW_UNDERGROUND_TIME * 0.5)
	# Teleport and emerge
	sink_tween.tween_callback(_do_emerge.bind(emerge_pos))

func _do_emerge(emerge_pos: Vector2) -> void:
	if is_dead or not is_inside_tree():
		_is_burrowed = false
		return
	# Teleport to new position
	global_position = emerge_pos
	if _sfx_burrow:
		_sfx_burrow.pitch_scale = randf_range(0.8, 1.0)
		_sfx_burrow.play()
	# Spawn dust at emerge location
	_spawn_burrow_dust(emerge_pos)
	# --- Emerge animation ---
	var emerge_tween = create_tween()
	emerge_tween.set_parallel(true)
	if sprite:
		sprite.scale.y = 0.0
		emerge_tween.tween_property(sprite, "scale:y", _get_sprite_base_scale(), BURROW_EMERGE_DURATION).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		emerge_tween.tween_property(sprite, "modulate", Color.WHITE, BURROW_EMERGE_DURATION)
	if _dot:
		_dot.scale.y = 0.0
		emerge_tween.tween_property(_dot, "scale:y", 1.0, BURROW_EMERGE_DURATION).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		emerge_tween.tween_property(_dot, "modulate", Color.WHITE, BURROW_EMERGE_DURATION)
	emerge_tween.set_parallel(false)
	emerge_tween.tween_callback(_finish_burrow)

func _clamp_to_arena(pos: Vector2) -> Vector2:
	# Find arena bounds from parent hierarchy
	var arena = get_parent()
	if arena:
		arena = arena.get_parent() if arena.name == "EnemiesContainer" else arena
	# Try to read arena constants, fall back to generous defaults
	var aw: float = 960.0
	var ah: float = 540.0
	if arena and "ARENA_W" in arena:
		aw = float(arena.ARENA_W)
		ah = float(arena.ARENA_H)
	elif arena:
		# Check script constants via get()
		var script = arena.get_script()
		if script:
			var temp = arena.get("ARENA_W")
			if temp: aw = float(temp)
			temp = arena.get("ARENA_H")
			if temp: ah = float(temp)
	# Also check for junkyard play margin
	var margin: float = 40.0
	if arena and arena.get("PLAY_MARGIN"):
		margin = float(arena.PLAY_MARGIN) + 20.0
	pos.x = clampf(pos.x, margin, aw - margin)
	pos.y = clampf(pos.y, margin, ah - margin)
	return pos

func _finish_burrow() -> void:
	_is_burrowed = false
	# Re-enable collision
	set_collision_layer_value(2, true)
	set_collision_mask_value(1, true)
	set_collision_mask_value(5, true)

func _get_sprite_base_scale() -> float:
	if not sprite or not sprite.sprite_frames:
		return 1.0
	var target = TYPE_SIZES.get(enemy_type, Vector2(56, 56))
	if sprite.sprite_frames.get_frame_count("walk") > 0:
		var ftex = sprite.sprite_frames.get_frame_texture("walk", 0)
		if ftex and ftex.get_width() > 0:
			return target.x / float(ftex.get_width())
	return 1.0

func _spawn_burrow_dust(pos: Vector2) -> void:
	# Spawn 5 small dust circles that expand and fade
	var container = get_parent() if get_parent() else self
	for i in 5:
		var dust = ColorRect.new()
		var size = randf_range(3.0, 6.0)
		dust.size = Vector2(size, size)
		dust.color = Color(0.55, 0.45, 0.3, 0.8)  # Earthy brown
		dust.z_index = 5
		# Random offset from center
		var angle = randf() * TAU
		var offset_dist = randf_range(2.0, 10.0)
		var offset = Vector2(cos(angle), sin(angle)) * offset_dist
		dust.global_position = pos + offset - Vector2(size * 0.5, size * 0.5)
		container.add_child(dust)
		# Animate: expand outward and fade
		var tw = dust.create_tween()
		tw.set_parallel(true)
		var end_pos = dust.global_position + offset.normalized() * randf_range(8.0, 18.0)
		tw.tween_property(dust, "global_position", end_pos, 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tw.tween_property(dust, "modulate:a", 0.0, 0.4).set_delay(0.1)
		tw.tween_property(dust, "size", dust.size * randf_range(1.5, 2.5), 0.4)
		tw.set_parallel(false)
		tw.tween_callback(dust.queue_free)

func _spawn_ground_cracks(pos: Vector2, is_emerge: bool) -> void:
	# Draw 4-6 thin lines radiating from center to simulate ground cracks
	var container = get_parent() if get_parent() else self
	var crack_count = randi_range(4, 6)
	var crack_color = Color(0.35, 0.28, 0.2, 0.9) if not is_emerge else Color(0.45, 0.35, 0.25, 0.9)
	for i in crack_count:
		var line = Line2D.new()
		line.width = 1.0
		line.default_color = crack_color
		line.z_index = 4
		var angle = (TAU / crack_count) * i + randf_range(-0.3, 0.3)
		var length = randf_range(6.0, 14.0)
		var dir = Vector2(cos(angle), sin(angle))
		# Crack starts near center and extends outward
		line.add_point(pos + dir * 1.5)
		# Add a slight bend midway for natural look
		var mid = pos + dir * (length * 0.5) + Vector2(randf_range(-1.5, 1.5), randf_range(-1.5, 1.5))
		line.add_point(mid)
		line.add_point(pos + dir * length)
		container.add_child(line)
		# Animate: appear quickly, linger, then fade
		line.modulate.a = 0.0
		var tw = line.create_tween()
		tw.tween_property(line, "modulate:a", 1.0, 0.08)
		tw.tween_interval(0.6 if is_emerge else 0.4)
		tw.tween_property(line, "modulate:a", 0.0, 0.3)
		tw.tween_callback(line.queue_free)

func apply_status(status: String, duration: float) -> void:
	match status:
		"burning": _apply_burning(duration)
		"shocked": _apply_shocked(duration)
		"slowed":  _apply_slowed(duration)
		"poisoned": _apply_poisoned(duration)

func _apply_burning(duration: float) -> void:
	var ticks := int(duration / 0.5)
	if _is_burning:
		# Already burning — just refresh remaining ticks, don't start a new loop
		_burn_ticks_remaining = ticks
		return
	_is_burning = true
	_burn_ticks_remaining = ticks
	while _burn_ticks_remaining > 0:
		if not is_inside_tree() or not is_instance_valid(self):
			_is_burning = false
			return
		await get_tree().create_timer(0.5).timeout
		if is_dead or not is_inside_tree() or not is_instance_valid(self):
			_is_burning = false
			return
		take_damage(5)
		_burn_ticks_remaining -= 1
	_is_burning = false

func _apply_poisoned(duration: float) -> void:
	var ticks := int(duration / 0.5)
	if _is_poisoned:
		_poison_ticks_remaining = ticks
		return
	_is_poisoned = true
	_poison_ticks_remaining = ticks
	while _poison_ticks_remaining > 0:
		if not is_inside_tree() or not is_instance_valid(self):
			_is_poisoned = false
			return
		await get_tree().create_timer(0.5).timeout
		if is_dead or not is_inside_tree() or not is_instance_valid(self):
			_is_poisoned = false
			return
		# Poison deals 2% of max HP per tick — scales naturally with enemy growth
		var poison_dmg = maxi(2, int(max_health * 0.02))
		take_damage(poison_dmg)
		_poison_ticks_remaining -= 1
		# Visual: greenish tint while poisoned
		if is_instance_valid(self):
			modulate = Color(0.6, 1.0, 0.5)
	_is_poisoned = false
	if is_instance_valid(self):
		modulate = Color.WHITE

func _recompute_speed() -> void:
	var mult := 1.0
	for debuff_id in _active_speed_debuffs:
		mult *= _active_speed_debuffs[debuff_id]
	move_speed = _base_move_speed * mult

func _apply_speed_debuff(debuff_id: String, multiplier: float, duration: float) -> void:
	var is_refresh := _active_speed_debuffs.has(debuff_id)
	_active_speed_debuffs[debuff_id] = multiplier
	_recompute_speed()
	if is_refresh:
		# Debuff already has an active timer that will handle expiry;
		# we can't cancel the old await, so let the newest duration win
		# by tagging with a generation counter.
		pass
	if not is_inside_tree(): return
	# Use a unique key per call so only the latest timer actually expires the debuff
	var gen_key := debuff_id + "_gen"
	var gen_val := randi()
	set_meta(gen_key, gen_val)
	await get_tree().create_timer(duration).timeout
	if not is_inside_tree() or not is_instance_valid(self): return
	# Only expire if this is still the latest application
	if get_meta(gen_key, -1) != gen_val: return
	_active_speed_debuffs.erase(debuff_id)
	if not is_dead:
		_recompute_speed()

func _apply_shocked(duration: float) -> void:
	_apply_speed_debuff("shocked", 0.5, duration)

func _apply_slowed(duration: float) -> void:
	_apply_speed_debuff("slowed", 0.6, duration)
