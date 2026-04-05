extends CharacterBody2D

signal died

var SPEED: float            = 90.0
var AUTO_ATTACK_DAMAGE: int = 8
var knockback: Vector2      = Vector2.ZERO
const AUTO_ATTACK_RANGE     = 80.0
const AUTO_ATTACK_COOLDOWN  = 0.6

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var attack_timer: Timer      = $AttackTimer
@onready var hurt_timer: Timer        = $HurtFlashTimer
@onready var detection: Area2D        = $DetectionArea

var is_dead: bool           = false
var facing_dir: Vector2     = Vector2.DOWN
var enemies_in_range: Array = []
var current_target: Node    = null
var salvage_cooldown: float = 0.0
var _dot: ColorRect         = null
var _anim_time: float       = 0.0
var _current_tier: String   = "base"

# --- Dodge Leap ---
var _is_leaping: bool       = false
var _leap_timer: float      = 0.0
var _leap_cooldown: float   = 0.0
const LEAP_DURATION         = 0.3
var LEAP_COOLDOWN: float    = 1.5  # Modified by Quick Paws perk
const LEAP_SPEED            = 280.0

# --- Sneak Mode ---
var _is_sneaking: bool      = false
var _sneak_ambush_ready: bool = false
var _sneak_duration: float  = 0.0
var _sneak_cooldown: float  = 0.0
var _sneak_time_used: float = 0.0
const SNEAK_SPEED_MULT      = 0.5
var SNEAK_MAX_DURATION: float = 3.0  # Modified by Shadow Step perk
const SNEAK_MAX_COOLDOWN    = 8.0
const SNEAK_MIN_COOLDOWN    = 3.0

# --- Dig Holes ---
var _is_digging: bool       = false
var _dig_timer: float       = 0.0
const DIG_DURATION          = 1.6

# --- Collect Scrap ---
var _is_collecting: bool    = false
var _collect_timer: float   = 0.0
const COLLECT_DURATION      = 1.0

# --- Fall Into Hole ---
var _is_falling: bool       = false
var _fall_callback: Callable = Callable()

# --- Audio ---
var _sfx_footstep: AudioStreamPlayer2D = null
var _sfx_bark_attack: AudioStreamPlayer2D = null
var _sfx_crit_hit: AudioStreamPlayer2D = null
var _sfx_dodge: AudioStreamPlayer2D = null
var _sfx_dig: AudioStreamPlayer2D = null
var _sfx_salvage: AudioStreamPlayer2D = null
var _sfx_sneak: AudioStreamPlayer2D = null
var _sfx_hurt: AudioStreamPlayer2D = null
@warning_ignore("unused_private_class_variable")
var _sfx_death: AudioStreamPlayer2D = null  # Assigned via set() in _setup_audio; play() currently disabled
var _footstep_timer: float = 0.0
const FOOTSTEP_INTERVAL = 0.3

# Base path for puppy sprites
const PUPPY_BASE = "res://assets/sprites/player/"

# 8 direction keys used in animation names
const DIR_KEYS = ["s", "se", "e", "ne", "n", "nw", "w", "sw"]

# Map short direction keys to folder names
const DIR_FOLDERS = {
	"s": "south", "se": "south-east", "e": "east", "ne": "north-east",
	"n": "north", "nw": "north-west", "w": "west", "sw": "south-west",
}

# Sprite sizes per tier (base/bandana=64 PixelLab, armor=128)
const TIER_SIZES = {"base": 64, "bandana": 64, "armor": 128,
	"blue_bandana": 48, "leather_vest": 48, "flower_crown": 48,
	"pirate_patch": 48, "golden_collar": 48, "void_cloak": 48, "phoenix_mantle": 48}

# Scale to get sprite to ~36px on screen
const TIER_SCALES = {"base": 0.56, "bandana": 0.56, "armor": 0.30,
	"blue_bandana": 0.75, "leather_vest": 0.75, "flower_crown": 0.75,
	"pirate_patch": 0.75, "golden_collar": 0.75, "void_cloak": 0.75, "phoenix_mantle": 0.75}

func _ready() -> void:
	add_to_group("player")

	attack_timer.wait_time = AUTO_ATTACK_COOLDOWN
	attack_timer.timeout.connect(_auto_attack)
	attack_timer.start()
	hurt_timer.wait_time = 0.15
	hurt_timer.one_shot  = true
	hurt_timer.timeout.connect(_stop_hurt_flash)
	detection.body_entered.connect(_on_enemy_entered)
	detection.body_exited.connect(_on_enemy_exited)

	_determine_tier()
	_load_sprites()
	_apply_saved_perks()
	_setup_audio()


func _exit_tree() -> void:
	# Note: Do NOT disconnect child node signals here — the player may be
	# reparented (e.g., junkyard Y-sort) which triggers _exit_tree/_enter_tree
	# without re-running _ready. Godot auto-cleans signals when nodes are freed.
	pass

func _apply_saved_perks() -> void:
	# Re-apply perk stat bonuses from GameState (survives scene changes)
	SPEED = maxf(10.0, 90.0 * GameState.perk_speed_multiplier)
	AUTO_ATTACK_DAMAGE = 8 + GameState.perk_damage_bonus
	attack_timer.wait_time = maxf(0.18, AUTO_ATTACK_COOLDOWN * maxf(0.1, GameState.perk_attack_speed_multiplier))
	LEAP_COOLDOWN = maxf(0.8, 1.5 * GameState.perk_dodge_cooldown_mult)
	SNEAK_MAX_DURATION = 3.0 + GameState.perk_sneak_duration_bonus
	_spawn_orbital_weapons()

func _setup_audio() -> void:
	var sfx_base = "res://assets/audio/sfx/player/"
	var sfx_list = [
		["footstep.wav", "_sfx_footstep", -24.0],
		["bark_attack.wav", "_sfx_bark_attack", -12.0],
		["crit_hit.wav", "_sfx_crit_hit", -10.0],
		["dodge.wav", "_sfx_dodge", -12.0],
		["dig.wav", "_sfx_dig", -14.0],
		["salvage.wav", "_sfx_salvage", -14.0],
		["sneak.wav", "_sfx_sneak", -14.0],
		["hurt.wav", "_sfx_hurt", -10.0],
		["death.wav", "_sfx_death", -8.0],
	]
	for entry in sfx_list:
		var path = sfx_base + entry[0]
		if ResourceLoader.exists(path):
			var player = AudioStreamPlayer2D.new()
			player.stream = load(path)
			player.volume_db = entry[2]
			player.max_distance = 500.0
			player.bus = "SFX"
			add_child(player)
			set(entry[1], player)

func _spawn_orbital_weapons() -> void:
	# Remove existing orbital children
	for child in get_children():
		if child is OrbitalWeapon:
			child.queue_free()
	# Spawn from saved state — each gets a slot_index for even spacing
	for i in GameState.orbital_weapons.size():
		var data = GameState.orbital_weapons[i]
		var orbital = _create_orbital(data.id, data.level)
		if orbital:
			orbital.slot_index = i
			add_child(orbital)

func _create_orbital(wid: String, lvl: int) -> OrbitalWeapon:
	var script_path = "res://scripts/orbitals/orbital_%s.gd" % wid
	if not ResourceLoader.exists(script_path):
		var base_orb = OrbitalWeapon.new()
		base_orb.weapon_id = wid
		base_orb.level = lvl
		return base_orb
	var scripted_orb = Node2D.new()
	scripted_orb.set_script(load(script_path))
	scripted_orb.level = lvl
	return scripted_orb

func add_orbital_weapon(wid: String) -> void:
	# Check if we already have this weapon — level it up
	for data in GameState.orbital_weapons:
		if data.id == wid:
			data.level = mini(data.level + 1, OrbitalDB.MAX_LEVEL)
			for child in get_children():
				if child is OrbitalWeapon and child.weapon_id == wid:
					child.level_up()
			return
	# New weapon
	if GameState.orbital_weapons.size() >= OrbitalDB.MAX_ORBITALS:
		return
	GameState.orbital_weapons.append({"id": wid, "level": 1})
	var orbital = _create_orbital(wid, 1)
	if orbital:
		orbital.slot_index = GameState.orbital_weapons.size() - 1
		add_child(orbital)


func _determine_tier() -> void:
	# Map equipped visual armor to sprite tier folder
	var visual = GameState.equipped_armor_visual
	var tier_map = {
		"bandana_red": "bandana",
		"bandana_blue": "blue_bandana",
		"leather_vest": "leather_vest",
		"flower_crown": "flower_crown",
		"pirate_patch": "pirate_patch",
		"golden_collar": "golden_collar",
		"void_cloak": "void_cloak",
		"phoenix_mantle": "phoenix_mantle",
		"rusty_plate": "leather_vest",
		"iron_plate": "armor",
		"steel_plate": "armor",
		"party_hat": "flower_crown",
		"goggles": "pirate_patch",
		"iron_mail": "armor",
		"crystal_vest": "armor",
		"scrap_shield": "armor",
		"fungal_hide": "leather_vest",
		"steam_harness": "leather_vest",
		"junkyard_crown": "golden_collar",
		"obsidian_shell": "armor",
	}
	_current_tier = tier_map.get(visual, "bandana")

	# Verify the tier folder exists by checking for a known file inside it.
	# DirAccess cannot browse .pck archives on export, so use ResourceLoader instead.
	var _test_path = PUPPY_BASE + "%s/idle/south/frame_000.png" % _current_tier
	if not ResourceLoader.exists(_test_path):
		var _bandana_test = PUPPY_BASE + "bandana/idle/south/frame_000.png"
		var _base_test = PUPPY_BASE + "base/idle/south/frame_000.png"
		if ResourceLoader.exists(_bandana_test):
			_current_tier = "bandana"
		elif ResourceLoader.exists(_base_test):
			_current_tier = "base"


func _load_sprites() -> void:
	if not sprite: return
	var sf = sprite.sprite_frames
	if not sf:
		sf = SpriteFrames.new()
		sprite.sprite_frames = sf

	var loaded_any = false
	var tier = _current_tier
	var scale_val = TIER_SCALES.get(tier, 0.42)

	# Load all available animation types for this tier
	for anim_type in ["idle", "run", "jump", "bark", "dig", "sneak", "death", "fall"]:
		for dk in DIR_KEYS:
			var anim_name = "%s_%s" % [anim_type, dk]
			var folder = DIR_FOLDERS[dk]
			var dir_path = PUPPY_BASE + "%s/%s/%s/" % [tier, anim_type, folder]

			# Try to load individual frames from folder
			var frame_count = _load_frames_from_dir(sf, anim_name, dir_path, anim_type)
			if frame_count > 0:
				loaded_any = true

	# If current tier has gaps, try to fill from base tier
	if tier != "base":
		for anim_type in ["idle", "run", "jump", "bark", "dig", "sneak", "death", "fall"]:
			for dk in DIR_KEYS:
				var anim_name = "%s_%s" % [anim_type, dk]
				if sf.has_animation(anim_name) and sf.get_frame_count(anim_name) > 0:
					continue  # Already loaded
				var folder = DIR_FOLDERS[dk]
				var dir_path = PUPPY_BASE + "base/%s/%s/" % [anim_type, folder]
				_load_frames_from_dir(sf, anim_name, dir_path, anim_type)

	if loaded_any:
		sprite.scale = Vector2(scale_val, scale_val)
		sprite.flip_h = false
		if sf.has_animation("idle_s") and sf.get_frame_count("idle_s") > 0:
			sprite.play("idle_s")
		# Remove the default animation if it exists and is empty
		if sf.has_animation("default") and sf.get_frame_count("default") == 0:
			sf.remove_animation("default")
	else:
		_add_dot_placeholder()


func _load_frames_from_dir(sf: SpriteFrames, anim_name: String, dir_path: String, anim_type: String) -> int:
	"""Load individual frame PNGs from a directory. Returns number of frames loaded."""
	# Collect frame paths
	var frame_paths: Array = []
	for i in range(20):  # max 20 frames
		var path = dir_path + "frame_%03d.png" % i
		if ResourceLoader.exists(path):
			frame_paths.append(path)
		else:
			break

	if frame_paths.is_empty():
		return 0

	if not sf.has_animation(anim_name):
		sf.add_animation(anim_name)

	# Set speed based on animation type
	var speed = 8.0
	match anim_type:
		"idle": speed = 6.0
		"run":  speed = 10.0
		"jump": speed = 8.0
		"bark": speed = 10.0
		"dig":   speed = 10.0
		"sneak": speed = 6.0
		"death": speed = 6.0
		"fall":  speed = 10.0

	sf.set_animation_speed(anim_name, speed)
	sf.set_animation_loop(anim_name, anim_type != "jump" and anim_type != "dig" and anim_type != "death" and anim_type != "fall")

	# Clear existing frames
	while sf.get_frame_count(anim_name) > 0:
		sf.remove_frame(anim_name, 0)

	# Add frames
	for path in frame_paths:
		var tex = load(path) as Texture2D
		if tex:
			sf.add_frame(anim_name, tex)

	return frame_paths.size()


func _add_dot_placeholder() -> void:
	if _dot: return
	_dot = ColorRect.new()
	_dot.size     = Vector2(10, 10)
	_dot.position = Vector2(-5, -5)
	_dot.color    = Color(0.3, 0.85, 0.4)
	_dot.z_index  = 1
	add_child(_dot)


func _get_dir_key(dir: Vector2) -> String:
	"""Convert a facing direction vector to one of 8 direction keys."""
	if dir.length() < 0.01:
		return "s"
	var angle = dir.angle()
	var deg = fmod(rad_to_deg(angle) + 360.0, 360.0)
	# 0° = East, 90° = South, 180° = West, 270° = North
	if deg < 22.5 or deg >= 337.5:
		return "e"
	elif deg < 67.5:
		return "se"
	elif deg < 112.5:
		return "s"
	elif deg < 157.5:
		return "sw"
	elif deg < 202.5:
		return "w"
	elif deg < 247.5:
		return "nw"
	elif deg < 292.5:
		return "n"
	else:
		return "ne"


func _input(event: InputEvent) -> void:
	# Use _input instead of _unhandled_input so Space (dodge) is captured
	# BEFORE any focused UI control can consume it as ui_accept.
	# This fixes dodge not working during chest phase when UI elements have focus.
	if event.is_action_pressed("dodge"):
		_dodge_pressed_this_frame = true
		get_viewport().set_input_as_handled()
	# Shift = collect scrap (capture raw keycode since Shift is a modifier key)
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SHIFT or event.physical_keycode == KEY_SHIFT:
			_collect_pressed_this_frame = true

var _dodge_pressed_this_frame: bool = false
var _collect_pressed_this_frame: bool = false

func _physics_process(delta: float) -> void:
	if is_dead: return
	salvage_cooldown = maxf(0.0, salvage_cooldown - delta)
	_leap_cooldown = maxf(0.0, _leap_cooldown - delta)
	_sneak_cooldown = maxf(0.0, _sneak_cooldown - delta)

	# Tick sneak duration — force-end if expired
	if _is_sneaking:
		_sneak_duration -= delta
		_sneak_time_used += delta
		if _sneak_duration <= 0:
			_end_sneak()

	# Tick dodge leap
	if _is_leaping:
		_leap_timer -= delta
		if _leap_timer <= 0:
			_is_leaping = false

	# Tick dig channel
	if _is_digging:
		_dig_timer -= delta
		velocity = Vector2.ZERO
		if _dig_timer <= 0:
			_is_digging = false
			_spawn_dig_hole()

	# Tick collect channel (same animation as dig, but salvages a prop)
	if _is_collecting:
		_collect_timer -= delta
		velocity = Vector2.ZERO
		if _collect_timer <= 0:
			_is_collecting = false
			_finish_collect()

	# Freeze movement while fall animation plays
	if _is_falling:
		velocity = Vector2.ZERO
		move_and_slide()
		_update_animation()
		return

	var phase = GameState.current_phase
	if phase == GameState.Phase.ARENA_COMBAT:
		if not _is_leaping and not _is_digging and not _is_collecting:
			_handle_sneak_input()
			_handle_dodge_input()
			# Only do normal movement if dodge didn't just start
			if not _is_leaping:
				_handle_movement()
			_handle_dig_input()
			_handle_collect_input()
		# Manual bark (works even while leaping)
		if Input.is_action_just_pressed("bark") and not _is_digging:
			_play_bark()
	elif phase == GameState.Phase.CHEST_PHASE:
		if _is_sneaking: _end_sneak()
		if not _is_leaping and not _is_collecting:
			_handle_dodge_input()
			if not _is_leaping:
				_handle_movement()
			_handle_collect_input()
		# Dodge works even when collecting (interrupt collect to dodge)
		if _dodge_pressed_this_frame and _is_collecting:
			_is_collecting = false
			_collect_timer = 0.0
			_handle_dodge_input()

	move_and_slide()
	_update_animation()
	_animate_sprite(delta)
	_dodge_pressed_this_frame = false
	_collect_pressed_this_frame = false


func _handle_movement() -> void:
	var dir = Vector2.ZERO
	if Input.is_action_pressed("ui_right"): dir.x += 1
	if Input.is_action_pressed("ui_left"):  dir.x -= 1
	if Input.is_action_pressed("ui_down"):  dir.y += 1
	if Input.is_action_pressed("ui_up"):    dir.y -= 1
	var speed_mult = SNEAK_SPEED_MULT if _is_sneaking else 1.0
	_process_slow(get_physics_process_delta_time())
	speed_mult *= _slow_mult  # Apply ice/debuff slows
	# Apply and decay knockback (from boss push effects)
	if knockback.length() > 2.0:
		velocity = knockback
		knockback = knockback.move_toward(Vector2.ZERO, 300.0 * get_physics_process_delta_time())
		return
	if dir != Vector2.ZERO:
		dir = dir.normalized()
		facing_dir = dir
		velocity = dir * SPEED * speed_mult
		# Footstep audio
		_footstep_timer -= get_physics_process_delta_time()
		if _footstep_timer <= 0 and _sfx_footstep:
			_sfx_footstep.pitch_scale = randf_range(0.9, 1.1)
			_sfx_footstep.play()
			_footstep_timer = FOOTSTEP_INTERVAL
	else:
		velocity = velocity.move_toward(Vector2.ZERO, SPEED * 6.0 * get_physics_process_delta_time())
		_footstep_timer = 0.0

func _handle_dodge_input() -> void:
	if _dodge_pressed_this_frame and _leap_cooldown <= 0 and not _is_leaping and not _is_digging:
		_is_leaping = true
		_leap_timer = LEAP_DURATION
		_leap_cooldown = LEAP_COOLDOWN
		var leap_dir = facing_dir.normalized() if facing_dir.length() > 0.01 else Vector2.DOWN
		velocity = leap_dir * LEAP_SPEED
		if _sfx_dodge:
			_sfx_dodge.pitch_scale = randf_range(0.75, 1.25)
			_sfx_dodge.play()
		# Exit sneak and cancel ambush when dodging
		if _is_sneaking: _end_sneak()
		_sneak_ambush_ready = false

func _handle_sneak_input() -> void:
	# Check Ctrl directly as a modifier key (more reliable than input action for modifiers)
	var wants_sneak = Input.is_key_pressed(KEY_CTRL)
	if wants_sneak and not _is_sneaking and _sneak_cooldown <= 0:
		# Start sneaking
		_is_sneaking = true
		_sneak_duration = SNEAK_MAX_DURATION
		_sneak_time_used = 0.0
		_sneak_ambush_ready = true
		GameState.is_player_sneaking = true
		if _sfx_sneak:
			_sfx_sneak.play()
	elif not wants_sneak and _is_sneaking:
		# Player released Ctrl early — end sneak
		_end_sneak()

func _end_sneak() -> void:
	_is_sneaking = false
	GameState.is_player_sneaking = false
	# Proportional cooldown: short sneak = short cooldown
	var ratio = clampf(_sneak_time_used / SNEAK_MAX_DURATION, 0.0, 1.0)
	_sneak_cooldown = maxf(SNEAK_MIN_COOLDOWN, SNEAK_MAX_COOLDOWN * ratio)

func _handle_dig_input() -> void:
	if Input.is_action_just_pressed("salvage") and not _is_digging and not _is_leaping:
		if GameState.dig_charges > 0:
			_is_digging = true
			_dig_timer = DIG_DURATION
			velocity = Vector2.ZERO
			if _sfx_dig:
				_sfx_dig.play()
			# Exit sneak when digging
			if _is_sneaking: _end_sneak()

func _spawn_dig_hole() -> void:
	# Only consume charge when the hole actually spawns (not on channel start)
	if not GameState.use_dig_charge():
		return
	var hole_scene = load("res://scenes/dig_hole.tscn")
	if not hole_scene: return
	var hole = hole_scene.instantiate()
	hole.global_position = global_position
	if get_parent():
		get_parent().add_child(hole)

const COLLECT_RANGE = 60.0

func _handle_collect_input() -> void:
	if _collect_pressed_this_frame and not _is_collecting and not _is_leaping:
		if _has_prop_nearby():
			_is_collecting = true
			_collect_timer = COLLECT_DURATION
			velocity = Vector2.ZERO
			if _sfx_salvage:
				_sfx_salvage.play()
			if _is_sneaking: _end_sneak()

func _find_props_container() -> Node:
	var parent = get_parent()
	if not parent: return null
	# In junkyard, the player is reparented INTO YSortContainer,
	# so parent IS the props container. Check if it has destructible children.
	if parent.name == "YSortContainer":
		return parent
	# Arena: PropsContainer is a sibling
	var props = parent.get_node_or_null("PropsContainer")
	if props: return props
	# Fallback: check grandparent for YSortContainer
	var grandparent = parent.get_parent()
	if grandparent:
		var ysort = grandparent.get_node_or_null("YSortContainer")
		if ysort: return ysort
	return null

func _has_prop_nearby() -> bool:
	var props = _find_props_container()
	if not props:
		return false
	var closest_dist = 9999.0
	for prop in props.get_children():
		if not prop.has_method("interact"): continue
		if prop.get("is_broken"): continue
		var d = global_position.distance_to(prop.global_position)
		if d < closest_dist:
			closest_dist = d
	return closest_dist < COLLECT_RANGE

func _finish_collect() -> void:
	_try_salvage_nearby_collect()

func _try_salvage_nearby_collect() -> void:
	var props = _find_props_container()
	if not props: return
	var closest: Node = null
	var best: float = COLLECT_RANGE
	for prop in props.get_children():
		if not prop.has_method("interact"): continue
		if prop.get("is_broken"): continue
		var d = global_position.distance_to(prop.global_position)
		if d < best:
			best = d
			closest = prop
	if closest:
		var spd = GameState.get_salvage_tool_speed()
		var yld = GameState.get_salvage_tool_yield()
		closest.interact(spd, yld)
		salvage_cooldown = 0.3 / spd


func _auto_attack() -> void:
	if is_dead or GameState.current_phase != GameState.Phase.ARENA_COMBAT: return
	if _is_digging or _is_collecting: return  # Can't attack while digging/collecting
	_find_closest_enemy()
	if current_target and is_instance_valid(current_target):
		# Ambush bonus: 2x damage on first attack with sneak charged
		var actual_damage = AUTO_ATTACK_DAMAGE
		if _sneak_ambush_ready:
			actual_damage *= 2
			_sneak_ambush_ready = false
			if _sfx_crit_hit:
				_sfx_crit_hit.pitch_scale = randf_range(0.9, 1.1)
				_sfx_crit_hit.play()
		# Crit chance from Sharp Fangs upgrade + Chimera buff + Iron Jaws perk
		var is_crit := false
		var crit_pct = GameState.permanent.get("crit_chance_level", 0) * 3
		crit_pct += GameState.perk_crit_bonus
		if GameState.chimera_buff.get("effect", "") == "crit":
			crit_pct += int(GameState.chimera_buff.get("value", 0))
		if crit_pct > 0 and randf() * 100.0 < crit_pct:
			actual_damage = int(actual_damage * 1.5)
			is_crit = true
			if _sfx_crit_hit:
				_sfx_crit_hit.pitch_scale = randf_range(1.1, 1.3)
				_sfx_crit_hit.play()
		if current_target.has_method("take_damage"):
			current_target.take_damage(actual_damage, global_position)
		# Bark Blast — AoE splash damage to nearby enemies
		if GameState.perk_bite_aoe_bonus > 0.0:
			var aoe_range = AUTO_ATTACK_RANGE * GameState.perk_bite_aoe_bonus
			var splash_dmg = int(maxf(1, actual_damage * 0.5))
			for enemy in get_tree().get_nodes_in_group("enemies"):
				if enemy == current_target: continue
				if not is_instance_valid(enemy) or enemy.is_dead: continue
				if current_target.global_position.distance_to(enemy.global_position) < aoe_range:
					if enemy.has_method("take_damage"):
						enemy.take_damage(splash_dmg, global_position)
		facing_dir = (current_target.global_position - global_position).normalized()
		if _sfx_bark_attack:
			_sfx_bark_attack.pitch_scale = randf_range(0.9, 1.1)
			_sfx_bark_attack.play()
		_show_bark_wave(current_target, is_crit)


func _show_bark_wave(target: Node, is_crit: bool = false) -> void:
	if not is_instance_valid(target): return
	var bark_parent = get_parent()
	if not bark_parent: return
	# Expanding ring from puppy toward target (bark shockwave)
	var dir = (target.global_position - global_position).normalized()
	var wave_pos = global_position + dir * 6.0

	# Arc of 3 small lines radiating outward (bark ripples)
	var line_color = Color(1.0, 0.3, 0.2, 0.9) if is_crit else Color(0.95, 0.85, 0.5, 0.8)
	var num_lines = 5 if is_crit else 3
	for i in num_lines:
		var spread = 0.35 if not is_crit else 0.25
		var offset_angle = (i - (num_lines - 1) / 2.0) * spread
		var wave_dir = dir.rotated(offset_angle)
		var line = Line2D.new()
		line.width = 3.0 if is_crit else 2.0
		line.default_color = line_color
		line.z_index = 10
		var start = wave_pos + wave_dir * (6.0 + i * 3.0)
		var end_pt = start + wave_dir * (12.0 if is_crit else 8.0)
		line.add_point(start)
		line.add_point(end_pt)
		bark_parent.add_child(line)
		var tw = line.create_tween()
		tw.tween_property(line, "position", line.position + wave_dir * (20.0 if is_crit else 14.0), 0.2)
		tw.parallel().tween_property(line, "modulate:a", 0.0, 0.2)
		tw.tween_callback(line.queue_free)

	# Floating "CRIT!" or "BARK!" text
	var bark_txt = Label.new()
	if is_crit:
		bark_txt.text = "CRIT!"
		bark_txt.add_theme_font_size_override("font_size", 14)
		bark_txt.add_theme_color_override("font_color", Color(1.0, 0.2, 0.15))
	else:
		var bark_words = ["BARK!", "WOOF!", "ARF!", "RUFF!", "YAP!", "BORK!"]
		var bark_colors = [
			Color(1.0, 0.85, 0.3), Color(0.95, 0.5, 0.2), Color(0.6, 0.9, 1.0),
			Color(1.0, 0.6, 0.7), Color(0.7, 1.0, 0.5), Color(1.0, 1.0, 0.5),
		]
		bark_txt.text = bark_words[randi() % bark_words.size()]
		bark_txt.add_theme_font_size_override("font_size", randi_range(7, 11))
		bark_txt.add_theme_color_override("font_color", bark_colors[randi() % bark_colors.size()])
	bark_txt.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	bark_txt.add_theme_constant_override("shadow_offset_x", 1)
	bark_txt.add_theme_constant_override("shadow_offset_y", 1)
	bark_txt.rotation = randf_range(-0.4, 0.4)
	bark_txt.position = wave_pos + Vector2(randf_range(-12, 12), randf_range(-14, -6))
	bark_txt.z_index = 11
	bark_parent.add_child(bark_txt)
	var tw_bark = bark_txt.create_tween()
	tw_bark.tween_property(bark_txt, "position:y", bark_txt.position.y - 18, 0.5).set_ease(Tween.EASE_OUT)
	tw_bark.parallel().tween_property(bark_txt, "modulate:a", 0.0, 0.5).set_delay(0.15)
	tw_bark.tween_callback(bark_txt.queue_free)

	# Impact flash on target (bigger and red for crits)
	var flash = Polygon2D.new()
	var pts: PackedVector2Array = []
	var star_points = 8 if is_crit else 6
	for i in star_points:
		var angle = TAU * i / float(star_points)
		var r_big = 7.0 if is_crit else 4.0
		var r_small = 3.5 if is_crit else 2.5
		var r = r_big if i % 2 == 0 else r_small
		pts.append(Vector2(cos(angle), sin(angle)) * r)
	flash.polygon = pts
	flash.color = Color(1.0, 0.2, 0.15, 0.9) if is_crit else Color(1.0, 0.95, 0.6, 0.8)
	flash.position = target.global_position
	flash.z_index = 10
	bark_parent.add_child(flash)
	var tw2 = flash.create_tween()
	var end_scale = Vector2(3.0, 3.0) if is_crit else Vector2(2.0, 2.0)
	tw2.tween_property(flash, "scale", end_scale, 0.15 if is_crit else 0.12)
	tw2.parallel().tween_property(flash, "modulate:a", 0.0, 0.18 if is_crit else 0.15)
	tw2.tween_callback(flash.queue_free)


func _find_closest_enemy() -> void:
	enemies_in_range = enemies_in_range.filter(func(e): return is_instance_valid(e))
	current_target = null
	var best = AUTO_ATTACK_RANGE
	for e in enemies_in_range:
		var d = global_position.distance_to(e.global_position)
		if d < best:
			best = d
			current_target = e


func _play_bark() -> void:
	# Cosmetic only — show bark text without interrupting movement animation
	var bark_p = get_parent()
	if not bark_p: return
	var bark_txt = Label.new()
	var bark_words = ["BARK!", "WOOF!", "ARF!", "RUFF!", "YAP!", "BORK!"]
	var bark_colors = [
		Color(1.0, 0.85, 0.3), Color(0.95, 0.5, 0.2), Color(0.6, 0.9, 1.0),
		Color(1.0, 0.6, 0.7), Color(0.7, 1.0, 0.5), Color(1.0, 1.0, 0.5),
	]
	bark_txt.text = bark_words[randi() % bark_words.size()]
	bark_txt.add_theme_font_size_override("font_size", randi_range(8, 12))
	bark_txt.add_theme_color_override("font_color", bark_colors[randi() % bark_colors.size()])
	bark_txt.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	bark_txt.add_theme_constant_override("shadow_offset_x", 1)
	bark_txt.add_theme_constant_override("shadow_offset_y", 1)
	bark_txt.rotation = randf_range(-0.4, 0.4)
	bark_txt.position = global_position + Vector2(randf_range(-12, 12), randf_range(-18, -8))
	bark_txt.z_index = 11
	bark_p.add_child(bark_txt)
	var tw = bark_txt.create_tween()
	tw.tween_property(bark_txt, "position:y", bark_txt.position.y - 18, 0.5).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(bark_txt, "modulate:a", 0.0, 0.5).set_delay(0.15)
	tw.tween_callback(bark_txt.queue_free)

func _update_animation() -> void:
	if not sprite or not sprite.sprite_frames: return
	if is_dead: return
	var sf = sprite.sprite_frames
	sprite.flip_h = false

	var dk = _get_dir_key(facing_dir)

	# Priority: fall > dig > leap > sneak > run > idle
	if _is_falling:
		_try_play(sf, "fall_s")
		return
	if _is_digging or _is_collecting:
		# Dig only has south animation — puppy faces down to dig
		if _try_play(sf, "dig_s"): return
		_try_play(sf, "dig_%s" % dk)
		return
	if _is_leaping:
		if _try_play(sf, "jump_%s" % dk): return
	if _is_sneaking:
		if _try_play(sf, "sneak_%s" % dk): return
	if velocity.length() > 10.0:
		if not _try_play(sf, "run_%s" % dk):
			_try_play(sf, "idle_%s" % dk)
	else:
		_try_play(sf, "idle_%s" % dk)

func _try_play(sf: SpriteFrames, anim: String) -> bool:
	if sf.has_animation(anim) and sf.get_frame_count(anim) > 0:
		if sprite.animation != anim:
			sprite.play(anim)
		return true
	return false

func start_fall_animation(on_complete: Callable) -> void:
	if _is_falling:
		return
	_is_falling = true
	_fall_callback = on_complete

	var has_anim = sprite and sprite.sprite_frames \
		and sprite.sprite_frames.has_animation("fall_s") \
		and sprite.sprite_frames.get_frame_count("fall_s") > 0

	if has_anim:
		var fps = maxf(sprite.sprite_frames.get_animation_speed("fall_s"), 1.0)
		var frames = sprite.sprite_frames.get_frame_count("fall_s")
		var duration = frames / fps
		sprite.play("fall_s")
		get_tree().create_timer(duration).timeout.connect(
			func(): if is_instance_valid(self): _on_fall_anim_finished()
		)
	else:
		# Frames not imported yet — tween scale to zero as fallback visual
		var tw = create_tween().set_ease(Tween.EASE_IN)
		var tween_target: Node2D = (sprite as Node2D) if sprite else (self as Node2D)
		tw.tween_property(tween_target, "scale", Vector2(0.05, 0.05), 1.5)
		tw.tween_callback(_on_fall_anim_finished)

func _on_fall_anim_finished() -> void:
	if not _is_falling: return  # Guard against double-fire
	_is_falling = false
	var base_scale = TIER_SCALES.get(_current_tier, 0.56)
	if sprite: sprite.scale = Vector2(base_scale, base_scale)
	if _fall_callback.is_valid():
		var cb = _fall_callback
		_fall_callback = Callable()
		cb.call()

func _animate_sprite(delta: float) -> void:
	if not sprite: return
	if _is_falling: return  # Don't reset scale while fall tween is running
	_anim_time += delta
	var scale_val = TIER_SCALES.get(_current_tier, 0.56)
	# Keep scale consistent — real frame animations handle the motion
	sprite.scale = Vector2(scale_val, scale_val)
	sprite.offset.y = 0.0
	sprite.rotation = 0.0


func take_damage(amount: int, from_enemy: Node = null) -> void:
	if is_dead: return
	if _is_leaping: return  # Invincible during dodge leap
	# Debug god mode — gated behind arena.DEBUG_ENABLED
	var arena = get_tree().current_scene
	if arena and arena.get("DEBUG_ENABLED") and arena.get("_god_mode"):
		return
	# Interrupt dig, collect and sneak if hit
	if _is_digging:
		_is_digging = false
		_dig_timer = 0.0
	if _is_collecting:
		_is_collecting = false
		_collect_timer = 0.0
	if _is_sneaking: _end_sneak()
	_sneak_ambush_ready = false
	# Thick Skin — damage reduction
	var reduced = amount
	if GameState.perk_damage_reduction > 0.0:
		reduced = int(maxf(1.0, amount * (1.0 - GameState.perk_damage_reduction)))
	GameState.take_damage(reduced)
	# Thorns — reflect damage back to attacker
	if GameState.perk_thorns_damage > 0 and from_enemy and is_instance_valid(from_enemy):
		if from_enemy.has_method("take_damage"):
			from_enemy.take_damage(GameState.perk_thorns_damage, global_position)
	# Second Wind — emergency heal at low HP
	if GameState.perk_second_wind and not GameState.perk_second_wind_used:
		if GameState.player_health > 0 and GameState.player_health < GameState.player_max_health * 0.2:
			GameState.perk_second_wind_used = true
			var heal_amount = int(GameState.player_max_health * 0.3)
			GameState.heal(heal_amount)
	var lethal = GameState.player_health <= 0
	if _sfx_hurt and not lethal:
		_sfx_hurt.pitch_scale = randf_range(0.9, 1.1)
		_sfx_hurt.play()
	_flash_hurt()
	if lethal:
		_die()
		died.emit()

var _slow_timer: float = 0.0
var _slow_mult: float = 1.0

func apply_slow(amount: float, duration: float) -> void:
	# amount = speed multiplier (0.5 = 50% speed), duration in seconds
	_slow_mult = amount
	_slow_timer = duration

func _process_slow(delta: float) -> void:
	if _slow_timer > 0:
		_slow_timer -= delta
		if _slow_timer <= 0:
			_slow_mult = 1.0

func _flash_hurt() -> void:
	if sprite: sprite.modulate = Color(1.0, 0.3, 0.3)
	if _dot:   _dot.color = Color(1.0, 0.3, 0.3)
	hurt_timer.start()

func _stop_hurt_flash() -> void:
	if sprite: sprite.modulate = Color.WHITE
	if _dot:   _dot.color = Color(0.3, 0.85, 0.4)

func _die() -> void:
	if is_dead: return  # Prevent double-die
	is_dead = true
	velocity = Vector2.ZERO
	set_physics_process(false)
	attack_timer.stop()
	hurt_timer.stop()  # Stop hurt flash from overriding
	# death sound disabled — needs replacement
	#if _sfx_death:
	#	_sfx_death.play()
	# Reset hurt flash immediately so death animation shows properly
	if sprite:
		sprite.modulate = Color.WHITE
	# Also try to use SpriteFrames death animation (simpler approach)
	var used_spriteframes = false
	if sprite and sprite.sprite_frames:
		var sf = sprite.sprite_frames
		var dk = _get_dir_key(facing_dir)
		for try_dk in [dk, "s", "se", "sw", "e", "w"]:
			var anim = "death_%s" % try_dk
			if sf.has_animation(anim) and sf.get_frame_count(anim) > 0:
				sprite.stop()
				sprite.play(anim)
				used_spriteframes = true
				# Fade after animation
				var dur = float(sf.get_frame_count(anim)) / maxf(sf.get_animation_speed(anim), 1.0)
				var tw = create_tween()
				tw.tween_interval(dur + 0.3)
				tw.tween_property(sprite, "modulate:a", 0.0, 0.8)
				break
	if not used_spriteframes:
		_play_death_animation()

var _death_frames: Array = []
var _death_sprite: Sprite2D = null
var _death_frame_idx: int = 0
var _death_frame_timer: float = 0.0
const DEATH_FPS = 10.0

func _play_death_animation() -> void:
	if not sprite:
		return

	# Try to load death frames directly from disk
	var dk = _get_dir_key(facing_dir)
	var try_dirs = [dk, "s", "se", "sw", "e", "w"]
	_death_frames.clear()

	for try_dk in try_dirs:
		var folder = DIR_FOLDERS.get(try_dk, "south")
		var base_path = PUPPY_BASE + "%s/death/%s/" % [_current_tier, folder]
		_death_frames.clear()
		for i in range(20):
			var frame_path = base_path + "frame_%03d.png" % i
			if ResourceLoader.exists(frame_path):
				var tex = load(frame_path) as Texture2D
				if tex:
					_death_frames.append(tex)
			else:
				break
		if not _death_frames.is_empty():
			break

	if not _death_frames.is_empty():
		# Hide the animated sprite, create a static Sprite2D for frame-by-frame control
		sprite.visible = false
		var scale_val = TIER_SCALES.get(_current_tier, 0.42)
		_death_sprite = Sprite2D.new()
		_death_sprite.texture = _death_frames[0]
		_death_sprite.scale = Vector2(scale_val, scale_val)
		_death_sprite.z_index = 5
		add_child(_death_sprite)
		_death_frame_idx = 0
		_death_frame_timer = 0.0
		# Use _process to advance frames (physics is disabled but process still runs)
		set_process(true)
	else:
		var tw = create_tween()
		tw.tween_property(sprite, "rotation", 1.5, 0.5)
		tw.parallel().tween_property(sprite, "scale:y", 0.1, 0.4).set_ease(Tween.EASE_IN)
		tw.tween_property(sprite, "modulate:a", 0.0, 0.6)

func _process(delta: float) -> void:
	# Only used for death animation playback
	if not is_dead or _death_frames.is_empty() or not is_instance_valid(_death_sprite):
		set_process(false)
		return
	_death_frame_timer += delta
	var frame_duration = 1.0 / DEATH_FPS
	if _death_frame_timer >= frame_duration:
		_death_frame_timer -= frame_duration
		_death_frame_idx += 1
		if _death_frame_idx < _death_frames.size():
			_death_sprite.texture = _death_frames[_death_frame_idx]
		elif _death_frame_idx == _death_frames.size():
			# Animation done — hold last frame then fade
			var tw = create_tween()
			tw.tween_interval(0.5)
			tw.tween_property(_death_sprite, "modulate:a", 0.0, 0.8)
			tw.tween_callback(func(): set_process(false))

func _on_enemy_entered(body: Node) -> void:
	if body.is_in_group("enemies") and body not in enemies_in_range:
		enemies_in_range.append(body)
func _on_enemy_exited(body: Node) -> void:
	enemies_in_range.erase(body)
