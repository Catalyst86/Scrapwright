extends EnemyBase

# The Devourer — Stage 6 Mid-Boss (Wave 77)
# Phase 1: Pull force toward self, darkness AoE, spawns shadow crawlers
# Phase 2 "VOID RIFT": Spawns portal at center with strong pull, massive contact damage
# Phase 3 "CONSUME": Doubled darkness damage, stronger pull, Void Rift repeats every 15s

var pull_timer: float = 0.0
var darkness_timer: float = 0.0
var spawn_timer: float = 0.0
var _pulling: bool = false
var _pull_time_left: float = 0.0

# Void Rift (Phase 2+)
var _void_rift_active: bool = false
var _void_rift_elapsed: float = 0.0
var _void_rift_cooldown: float = 0.0
var _void_portal_node: Node2D = null
var _void_rift_hit_player: bool = false

const PULL_INTERVAL = 3.0
const PULL_RANGE = 100.0
var PULL_STRENGTH: float = 60.0
const PULL_DURATION = 1.5

const DARKNESS_INTERVAL = 5.0
const DARKNESS_RADIUS = 50.0
var DARKNESS_DAMAGE: int = 8

const SPAWN_INTERVAL = 9.0
var SPAWN_COUNT: int = 2

const VOID_RIFT_DURATION = 6.0
const VOID_RIFT_PULL_STRENGTH = 120.0
const VOID_RIFT_CENTER_DAMAGE = 40
const VOID_RIFT_CENTER_RADIUS = 20.0
const VOID_RIFT_STUN = 1.5
const VOID_RIFT_COOLDOWN_P3 = 15.0

func _ready() -> void:
	enemy_type       = "the_devourer"
	max_health       = 1600
	move_speed       = 28.0
	damage           = 25
	xp_value         = 300
	contact_cooldown = 1.2
	super._ready()
	if health_bar:
		health_bar.visible = true

func _physics_process(delta: float) -> void:
	if is_dead or _phase_transitioning: return

	# --- Void Rift active ---
	if _void_rift_active:
		_process_void_rift(delta)

	# --- Phase 3: Void Rift cooldown ---
	if _boss_phase >= 3 and not _void_rift_active:
		_void_rift_cooldown += delta
		if _void_rift_cooldown >= VOID_RIFT_COOLDOWN_P3:
			_void_rift_cooldown = 0.0
			_start_void_rift()

	pull_timer += delta
	darkness_timer += delta
	spawn_timer += delta

	# Normal pull toward self
	if pull_timer >= PULL_INTERVAL and not _pulling and not _void_rift_active:
		pull_timer = 0.0
		_pulling = true
		_pull_time_left = PULL_DURATION

	if _pulling:
		_pull_time_left -= delta
		if _pull_time_left <= 0:
			_pulling = false
		elif player_ref and is_instance_valid(player_ref):
			var dist = global_position.distance_to(player_ref.global_position)
			if dist < PULL_RANGE and dist > 20.0:
				var pull_dir = (global_position - player_ref.global_position).normalized()
				if "velocity" in player_ref:
					player_ref.velocity += pull_dir * PULL_STRENGTH * delta

				# Visual — pull lines
				if randf() < 0.3:
					_draw_pull_line(global_position, player_ref.global_position, Color(0.3, 0.0, 0.4, 0.5))

	if darkness_timer >= DARKNESS_INTERVAL:
		darkness_timer = 0.0
		_darkness_aoe()

	if spawn_timer >= SPAWN_INTERVAL:
		spawn_timer = 0.0
		_spawn_crawlers(SPAWN_COUNT)

	super._physics_process(delta)

func _on_phase_change(new_phase: int) -> void:
	super._on_phase_change(new_phase)
	match new_phase:
		2:
			_show_boss_warning("RESIST THE VOID!")
			_start_void_rift()
		3:
			_show_boss_warning("CONSUME!")
			# Double darkness damage
			DARKNESS_DAMAGE = 16
			# Increase normal pull strength
			PULL_STRENGTH = 80.0
			# More crawlers per spawn
			SPAWN_COUNT = 3
			_void_rift_cooldown = 0.0

# ---- Darkness AoE ----
func _darkness_aoe() -> void:
	_play_attack_anim()
	# Visual — dark expanding circle
	var ring = ColorRect.new()
	ring.size = Vector2(4, 4)
	ring.position = global_position - Vector2(2, 2)
	ring.color = Color(0.15, 0.0, 0.2, 0.6)
	ring.z_index = -1
	var parent = get_parent()
	if parent:
		parent.add_child(ring)
		var tw = ring.create_tween()
		tw.set_parallel(true)
		tw.tween_property(ring, "size", Vector2(DARKNESS_RADIUS * 2, DARKNESS_RADIUS * 2), 0.4)
		tw.tween_property(ring, "position", global_position - Vector2(DARKNESS_RADIUS, DARKNESS_RADIUS), 0.4)
		tw.tween_property(ring, "modulate:a", 0.0, 0.5)
		tw.set_parallel(false)
		tw.tween_callback(ring.queue_free)

	# Damage player if in range
	if player_ref and is_instance_valid(player_ref):
		if global_position.distance_to(player_ref.global_position) < DARKNESS_RADIUS:
			if player_ref.has_method("take_damage"):
				player_ref.take_damage(DARKNESS_DAMAGE, self)

# ---- Spawn Crawlers ----
func _spawn_crawlers(count: int) -> void:
	var crawler_scene = load("res://scenes/enemies/enemy_shadow_crawler.tscn")
	if not crawler_scene: return
	var parent = get_parent()
	if not parent: return
	for i in count:
		var minion = crawler_scene.instantiate()
		var offset = Vector2(randf_range(-25, 25), randf_range(-25, 25))
		minion.global_position = global_position + offset
		minion.died.connect(func(_xp: int = 0):
			if not WaveManager.wave_active: return
			WaveManager.enemies_alive = maxi(0, WaveManager.enemies_alive - 1)
			WaveManager.emit_signal("enemies_remaining_changed", WaveManager.get_wave_enemy_count())
		)
		parent.add_child(minion)
		WaveManager.enemies_alive += 1
		WaveManager.emit_signal("enemies_remaining_changed", WaveManager.get_wave_enemy_count())

# ---- Void Rift ----
func _start_void_rift() -> void:
	if _void_rift_active or is_dead: return
	_void_rift_active = true
	_void_rift_elapsed = 0.0
	_void_rift_hit_player = false

	_show_boss_warning("RESIST THE VOID!")

	var parent = get_parent()
	if not parent: return
	var center = _get_arena_center()

	# Spawn void portal visual at arena center
	_void_portal_node = Node2D.new()
	_void_portal_node.global_position = center
	_void_portal_node.z_index = -1
	parent.add_child(_void_portal_node)

	# Animated void portal spritesheet
	var sheet_path = "res://assets/sprites/boss_fx/void_portal_v2_sheet.png"
	if ResourceLoader.exists(sheet_path):
		var tex = load(sheet_path)
		var anim_spr = AnimatedSprite2D.new()
		var sf = SpriteFrames.new()
		if not sf.has_animation("default"): sf.add_animation("default")
		sf.set_animation_speed("default", 8.0)
		sf.set_animation_loop("default", true)
		var frame_size = 64
		var frame_count = tex.get_width() / frame_size
		for i in frame_count:
			var atlas = AtlasTexture.new()
			atlas.atlas = tex
			atlas.region = Rect2(i * frame_size, 0, frame_size, frame_size)
			sf.add_frame("default", atlas)
		anim_spr.sprite_frames = sf
		anim_spr.play("default")
		anim_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		anim_spr.scale = Vector2(2.5, 2.5)
		_void_portal_node.add_child(anim_spr)
	else:
		# Fallback
		var circle = ColorRect.new()
		circle.size = Vector2(60, 60)
		circle.position = Vector2(-30, -30)
		circle.color = Color(0.2, 0.0, 0.3, 0.7)
		_void_portal_node.add_child(circle)

	# Spawn crawlers during rift
	var crawler_count = 3 if _boss_phase >= 3 else 2
	_spawn_crawlers(crawler_count)

	# Spawn entrance tween — portal scales up
	_void_portal_node.scale = Vector2(0.1, 0.1)
	var tw = _void_portal_node.create_tween()
	tw.tween_property(_void_portal_node, "scale", Vector2(1.0, 1.0), 0.5).set_ease(Tween.EASE_OUT)

func _process_void_rift(delta: float) -> void:
	_void_rift_elapsed += delta

	if not is_instance_valid(_void_portal_node):
		_void_rift_active = false
		return

	# Pulse portal gently (animated sprite handles the swirl)
	var pulse = 1.0 + 0.05 * sin(_void_rift_elapsed * 3.0)
	_void_portal_node.scale = Vector2(pulse, pulse)

	var center = _void_portal_node.global_position

	# Pull player toward center
	if player_ref and is_instance_valid(player_ref):
		var to_center = (center - player_ref.global_position)
		var dist = to_center.length()
		if dist > 5.0:
			var pull_dir = to_center.normalized()
			if "velocity" in player_ref:
				player_ref.velocity += pull_dir * VOID_RIFT_PULL_STRENGTH * delta

			# Pull lines
			if randf() < 0.4:
				_draw_pull_line(center, player_ref.global_position, Color(0.4, 0.0, 0.6, 0.6))

		# Check if player reached center — devastating damage + stun
		if dist < VOID_RIFT_CENTER_RADIUS and not _void_rift_hit_player:
			_void_rift_hit_player = true
			if player_ref.has_method("take_damage"):
				player_ref.take_damage(VOID_RIFT_CENTER_DAMAGE, self)
			if player_ref.has_method("stun"):
				player_ref.stun(VOID_RIFT_STUN)

			# Impact visual
			var flash = ColorRect.new()
			flash.size = Vector2(120, 120)
			flash.position = center - Vector2(60, 60)
			flash.color = Color(0.5, 0.0, 0.8, 0.6)
			flash.z_index = 5
			var parent = get_parent()
			if parent:
				parent.add_child(flash)
				var tw = flash.create_tween()
				tw.tween_property(flash, "modulate:a", 0.0, 0.5)
				tw.tween_callback(flash.queue_free)

	# End rift
	if _void_rift_elapsed >= VOID_RIFT_DURATION:
		_void_rift_active = false
		if is_instance_valid(_void_portal_node):
			var tw = _void_portal_node.create_tween()
			tw.tween_property(_void_portal_node, "scale", Vector2(0.01, 0.01), 0.4)
			tw.tween_property(_void_portal_node, "modulate:a", 0.0, 0.2)
			tw.tween_callback(_void_portal_node.queue_free)
		_void_portal_node = null

# ---- Helpers ----
func _draw_pull_line(from: Vector2, to: Vector2, color: Color) -> void:
	var line = Line2D.new()
	line.width = 1.0
	line.default_color = color
	line.z_index = 5
	line.add_point(from)
	line.add_point(to)
	var parent = get_parent()
	if parent:
		parent.add_child(line)
		var tw = line.create_tween()
		tw.tween_property(line, "modulate:a", 0.0, 0.2)
		tw.tween_callback(line.queue_free)

func _die() -> void:
	if is_instance_valid(_void_portal_node): _void_portal_node.queue_free()
	_void_portal_node = null
	super._die()

func _get_arena_center() -> Vector2:
	if player_ref and is_instance_valid(player_ref):
		var cam = player_ref.get_node_or_null("Camera2D")
		if cam: return cam.global_position
	return Vector2(480, 270)
