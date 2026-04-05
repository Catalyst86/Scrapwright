extends EnemyBase

# Crystal Colossus — Stage 4 Final Boss
# Ground slam creates expanding ice ring, spawns ice shards in burst pattern every 6s
# Phase 1: Ground slam AoE + ice shard burst
# Phase 2 "CRYSTAL PRISON": Spawns 8 crystal walls in circle around player, must break out in 4s or take 50 damage
# Phase 3 "SHATTER": 12 projectiles instead of 8, crystal prison repeats every 20s, ground slam spawns pillar turrets

var ground_slam_timer: float = 0.0
var ice_shard_timer: float = 0.0

# Phase 2/3
var _prison_timer: float = 0.0
var _prison_active: bool = false

const GROUND_SLAM_INTERVAL = 5.0
const GROUND_SLAM_RANGE = 70.0
const GROUND_SLAM_DAMAGE = 20

const ICE_SHARD_INTERVAL = 6.0
const ICE_SHARD_COUNT = 8
const ICE_SHARD_COUNT_P3 = 12
const ICE_SHARD_SPEED = 90.0
const ICE_SHARD_DAMAGE = 12

# Crystal Prison constants
const PRISON_WALL_COUNT = 8
const PRISON_RADIUS = 50.0
const PRISON_WALL_HP = 50
const PRISON_ESCAPE_TIME = 6.0
const PRISON_FAIL_DAMAGE = 50
const PRISON_REPEAT_INTERVAL = 20.0

# Phase 3: Pillar turret constants
const PILLAR_COUNT = 4
const PILLAR_FIRE_DELAY = 1.0
const PILLAR_HP = 8

var _proj_scene: PackedScene = null

func _ready() -> void:
	enemy_type       = "crystal_colossus"
	max_health       = 1800
	move_speed       = 22.0
	damage           = 30
	xp_value         = 300
	contact_cooldown = 1.5
	_proj_scene = load("res://scenes/enemy_projectile.tscn")
	super._ready()
	if health_bar:
		health_bar.visible = true

func _physics_process(delta: float) -> void:
	if is_dead or _phase_transitioning: return

	# Crystal prison repeat timer (Phase 2+)
	if _boss_phase >= 2 and not _prison_active:
		_prison_timer += delta
		if _prison_timer >= PRISON_REPEAT_INTERVAL:
			_prison_timer = 0.0
			_start_crystal_prison()

	ground_slam_timer += delta
	ice_shard_timer += delta

	if ground_slam_timer >= GROUND_SLAM_INTERVAL:
		ground_slam_timer = 0.0
		_ground_slam()

	if ice_shard_timer >= ICE_SHARD_INTERVAL:
		ice_shard_timer = 0.0
		_ice_shard_burst()

	super._physics_process(delta)

# --- Phase Transitions ---

func _on_phase_change(new_phase: int) -> void:
	super._on_phase_change(new_phase)
	match new_phase:
		2:
			_show_boss_warning("BREAK FREE!")
			_start_crystal_prison()
		3:
			_show_boss_warning("SHATTER!")
			_start_crystal_prison()

# --- Crystal Prison (Phase 2+) ---

func _start_crystal_prison() -> void:
	if _prison_active or is_dead: return
	if not player_ref or not is_instance_valid(player_ref): return
	_prison_active = true

	_show_boss_warning("BREAK FREE!")

	var player_pos = player_ref.global_position
	var parent = get_parent()
	if not parent:
		_prison_active = false
		return

	# Spawn 8 breakable crystal wall obstacles in a circle around the player
	var prison_walls: Array = []
	for i in PRISON_WALL_COUNT:
		var angle = TAU * i / float(PRISON_WALL_COUNT)
		var pos = player_pos + Vector2(cos(angle), sin(angle)) * PRISON_RADIUS
		var wall = _spawn_breakable_wall(pos, parent)
		if wall:
			prison_walls.append(wall)

	# Start escape timer
	_run_prison_timer(prison_walls, player_pos)

func _run_prison_timer(prison_walls: Array, center_pos: Vector2) -> void:
	await get_tree().create_timer(PRISON_ESCAPE_TIME).timeout
	if is_dead or not is_inside_tree():
		_prison_active = false
		for wall in prison_walls:
			if is_instance_valid(wall):
				wall.queue_free()
		return

	# Check if any walls remain (player failed to break out)
	var remaining = 0
	for wall in prison_walls:
		if is_instance_valid(wall):
			remaining += 1

	if remaining > 0:
		# Player failed to escape — take big damage
		if player_ref and is_instance_valid(player_ref):
			if player_ref.has_method("take_damage"):
				player_ref.take_damage(PRISON_FAIL_DAMAGE, self)

			# Show fail text
			var lbl = Label.new()
			lbl.text = "CRUSHED!"
			lbl.add_theme_font_size_override("font_size", 10)
			lbl.add_theme_color_override("font_color", Color(0.3, 0.6, 1.0))
			lbl.position = player_ref.global_position + Vector2(-16, -28)
			lbl.z_index = 10
			var parent = get_parent()
			if parent:
				parent.add_child(lbl)
				var tw = lbl.create_tween()
				tw.tween_property(lbl, "modulate:a", 0.0, 0.8)
				tw.tween_callback(lbl.queue_free)

		# Shatter remaining walls with visual effect
		for wall in prison_walls:
			if is_instance_valid(wall):
				_shatter_wall_visual(wall.global_position)
				wall.queue_free()
	else:
		# Player escaped — show success text
		if player_ref and is_instance_valid(player_ref):
			var lbl = Label.new()
			lbl.text = "ESCAPED!"
			lbl.add_theme_font_size_override("font_size", 8)
			lbl.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4))
			lbl.position = player_ref.global_position + Vector2(-16, -24)
			lbl.z_index = 10
			var parent = get_parent()
			if parent:
				parent.add_child(lbl)
				var tw = lbl.create_tween()
				tw.tween_property(lbl, "modulate:a", 0.0, 0.8)
				tw.tween_callback(lbl.queue_free)

	_prison_active = false

func _spawn_breakable_wall(pos: Vector2, parent: Node) -> Node2D:
	# Create a wall the player can break with bite attacks
	var wall = CharacterBody2D.new()
	wall.collision_layer = 2  # Same as enemies so player bite can target them
	wall.collision_mask = 0
	wall.global_position = pos
	wall.add_to_group("enemies")  # So player auto-attack can find and hit them
	wall.add_to_group("boss_obstacles")
	wall.add_to_group("wall")  # So projectiles collide

	# Collision shape
	var col = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(28, 28)
	col.shape = shape
	wall.add_child(col)

	# Visual
	var tex_path = "res://assets/sprites/boss_fx/crystal_wall.png"
	if ResourceLoader.exists(tex_path):
		var spr = Sprite2D.new()
		spr.texture = load(tex_path)
		spr.scale = Vector2(1.5, 1.5)
		wall.add_child(spr)
	else:
		var fb = ColorRect.new()
		fb.size = Vector2(24, 24)
		fb.position = Vector2(-12, -12)
		fb.color = Color(0.4, 0.7, 1.0, 0.8)
		wall.add_child(fb)

	# Make it act like an enemy with HP so player bite damages it
	wall.set_meta("is_dead", false)
	wall.set_meta("health", PRISON_WALL_HP)
	wall.set_meta("max_health", PRISON_WALL_HP)

	# Add take_damage method via script
	var script = GDScript.new()
	script.source_code = """extends CharacterBody2D

var is_dead: bool = false
var health: int = %d

func take_damage(amount: int, _from_pos: Variant = null) -> void:
	if is_dead: return
	health -= amount
	# Flash on hit
	for child in get_children():
		if child is Sprite2D:
			child.modulate = Color(2.0, 1.5, 1.5)
			var tw = create_tween()
			tw.tween_property(child, "modulate", Color.WHITE, 0.1)
	if health <= 0:
		is_dead = true
		queue_free()
""" % PRISON_WALL_HP
	script.reload()
	wall.set_script(script)

	parent.add_child(wall)
	return wall

func _shatter_wall_visual(pos: Vector2) -> void:
	var parent = get_parent()
	if not parent: return

	# Crystal shard particles
	for i in 4:
		var shard = Polygon2D.new()
		var pts: PackedVector2Array = []
		pts.append(Vector2(0, -randf_range(3, 6)))
		pts.append(Vector2(randf_range(2, 4), randf_range(1, 3)))
		pts.append(Vector2(-randf_range(2, 4), randf_range(1, 3)))
		shard.polygon = pts
		shard.color = Color(0.4, 0.7, 1.0, 0.8)
		shard.global_position = pos
		shard.z_index = 6
		parent.add_child(shard)

		var dir = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized() * randf_range(20, 50)
		var tw = shard.create_tween()
		tw.set_parallel(true)
		tw.tween_property(shard, "position", shard.position + dir, 0.4)
		tw.tween_property(shard, "modulate:a", 0.0, 0.4)
		tw.tween_property(shard, "rotation", randf_range(-2, 2), 0.4)
		tw.set_parallel(false)
		tw.tween_callback(shard.queue_free)

# --- Phase 3: Ground Slam Pillar Turrets ---

func _spawn_slam_pillars(slam_pos: Vector2) -> void:
	if not _proj_scene: return
	var parent = get_parent()
	if not parent: return

	var offsets = [
		Vector2(30, 0), Vector2(-30, 0),
		Vector2(0, 30), Vector2(0, -30),
	]

	for offset in offsets:
		var pos = slam_pos + offset
		var pillar = _spawn_cover_obstacle(pos, "crystal_wall", PILLAR_HP, 1.0)
		if pillar:
			# After 1 second, the pillar fires a projectile toward the player
			_pillar_fire_delayed(pillar, pos)

func _pillar_fire_delayed(pillar: Node2D, pos: Vector2) -> void:
	await get_tree().create_timer(PILLAR_FIRE_DELAY).timeout
	if is_dead or not is_inside_tree(): return
	if not is_instance_valid(pillar): return
	if not player_ref or not is_instance_valid(player_ref): return
	if not _proj_scene: return

	var parent = get_parent()
	if not parent: return

	var dir = (player_ref.global_position - pos).normalized()
	var proj = _proj_scene.instantiate()
	proj.source_enemy = self
	proj.projectile_type = "ice"
	parent.add_child(proj)
	proj.global_position = pos
	proj.setup(dir * ICE_SHARD_SPEED, ICE_SHARD_DAMAGE)

	# Flash the pillar then destroy it
	if is_instance_valid(pillar):
		var tw = pillar.create_tween()
		tw.tween_property(pillar, "modulate", Color(2.0, 2.0, 2.5), 0.1)
		tw.tween_property(pillar, "modulate:a", 0.0, 0.3)
		tw.tween_callback(pillar.queue_free)

# --- Original Attacks ---

func _ground_slam() -> void:
	if not player_ref or not is_instance_valid(player_ref): return

	# Visual flash
	if sprite:
		sprite.modulate = Color(0.5, 0.8, 2.0)
		var tw = create_tween()
		tw.tween_property(sprite, "modulate", Color.WHITE, 0.3)

	# Expanding ice ring visual
	var ring = ColorRect.new()
	ring.size = Vector2(4, 4)
	ring.position = global_position - Vector2(2, 2)
	ring.color = Color(0.3, 0.6, 1.0, 0.5)
	ring.z_index = -1
	var parent = get_parent()
	if parent:
		parent.add_child(ring)
		var tw2 = ring.create_tween()
		tw2.set_parallel(true)
		tw2.tween_property(ring, "size", Vector2(GROUND_SLAM_RANGE * 2, GROUND_SLAM_RANGE * 2), 0.5)
		tw2.tween_property(ring, "position", global_position - Vector2(GROUND_SLAM_RANGE, GROUND_SLAM_RANGE), 0.5)
		tw2.tween_property(ring, "modulate:a", 0.0, 0.5)
		tw2.set_parallel(false)
		tw2.tween_callback(ring.queue_free)

	# Damage player if in range
	var dist = global_position.distance_to(player_ref.global_position)
	if dist < GROUND_SLAM_RANGE:
		if player_ref.has_method("take_damage"):
			player_ref.take_damage(GROUND_SLAM_DAMAGE, self)

	# Phase 3: Spawn crystal pillar turrets at slam location
	if _boss_phase >= 3:
		_spawn_slam_pillars(global_position)

func _ice_shard_burst() -> void:
	_play_attack_anim_then(_do_shard_burst)

func _do_shard_burst() -> void:
	if is_dead: return
	var proj_scene = _proj_scene
	if not proj_scene: return
	var parent = get_parent()
	if not parent: return

	# Phase 3: 12 projectiles instead of 8
	var count = ICE_SHARD_COUNT_P3 if _boss_phase >= 3 else ICE_SHARD_COUNT

	for i in count:
		var angle = TAU * i / count
		var dir = Vector2(cos(angle), sin(angle))
		var proj = proj_scene.instantiate()
		proj.source_enemy = self
		proj.global_position = global_position + dir * 12.0
		proj.projectile_type = "ice"
		proj.setup(dir * ICE_SHARD_SPEED, ICE_SHARD_DAMAGE)
		parent.add_child(proj)

func _die() -> void:
	_prison_active = false
	super._die()

func _get_arena_center() -> Vector2:
	if player_ref and is_instance_valid(player_ref):
		var cam = player_ref.get_node_or_null("Camera2D")
		if cam: return cam.global_position
	return Vector2(480, 270)
