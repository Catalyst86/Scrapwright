extends EnemyBase

# Spore Mother — Stage 2 Mid-Boss (Wave 21)
# Phase 1: Toxic cloud (4s, 40px dmg), spawns 3 spore walkers (7s), heal pulse (10s, 15 HP).
# Phase 2 "SPORE BLOOM": Roots in place (velocity=0 for 8s), emits expanding poison
#   rings every 1.5s (3 active at once). Spawns 4 minions instead of 3.
#   Banner: "DODGE THE RINGS!"
# Phase 3 "MYCORRHIZAL NETWORK": Toxic cloud range doubled (80px). Heal pulse also
#   heals nearby minions. Spore Bloom repeats every 18s.

var toxic_cloud_timer: float = 0.0
var spawn_timer: float = 0.0
var heal_pulse_timer: float = 0.0

var _toxic_cloud_radius: float = 45.0

const TOXIC_CLOUD_INTERVAL = 4.0
const TOXIC_CLOUD_DAMAGE = 4

var _spawn_count: int = 3
const SPAWN_INTERVAL = 7.0

const HEAL_PULSE_INTERVAL = 10.0
const HEAL_AMOUNT = 15

# Spore Bloom state (Phase 2+)
var _spore_bloom_active: bool = false
var _spore_bloom_elapsed: float = 0.0
var _spore_bloom_cooldown_timer: float = 0.0
var _bloom_ring_timer: float = 0.0
var _active_rings: Array = []
var _rooted: bool = false
var _root_timer: float = 0.0

const SPORE_BLOOM_DURATION = 8.0
const SPORE_BLOOM_COOLDOWN = 18.0
const RING_INTERVAL = 1.5
const RING_MAX_RADIUS = 450.0
const RING_EXPAND_SPEED = 110.0  # px per second
const RING_DAMAGE = 10
const RING_WIDTH = 12.0
const MAX_ACTIVE_RINGS = 3

func _ready() -> void:
	enemy_type       = "spore_mother"
	max_health       = 900
	move_speed       = 22.0
	damage           = 15
	xp_value         = 90
	contact_cooldown = 1.5
	_is_boss = true
	super._ready()
	if health_bar:
		health_bar.visible = true

func _physics_process(delta: float) -> void:
	if is_dead or _phase_transitioning: return

	# Handle rooting during spore bloom
	if _rooted:
		_root_timer -= delta
		if _root_timer <= 0.0:
			_rooted = false
		else:
			velocity = Vector2.ZERO

	# Spore bloom active processing
	if _spore_bloom_active:
		_process_spore_bloom(delta)

	# Normal ability timers (run even during bloom for cloud/spawn/heal)
	toxic_cloud_timer += delta
	spawn_timer += delta
	heal_pulse_timer += delta

	if toxic_cloud_timer >= TOXIC_CLOUD_INTERVAL:
		toxic_cloud_timer = 0.0
		_release_toxic_cloud()

	if spawn_timer >= SPAWN_INTERVAL:
		spawn_timer = 0.0
		_spawn_children()

	if heal_pulse_timer >= HEAL_PULSE_INTERVAL:
		heal_pulse_timer = 0.0
		_heal_pulse()

	# Spore bloom cooldown (Phase 2+)
	if _boss_phase >= 2 and not _spore_bloom_active:
		_spore_bloom_cooldown_timer += delta
		if _spore_bloom_cooldown_timer >= SPORE_BLOOM_COOLDOWN:
			_spore_bloom_cooldown_timer = 0.0
			_start_spore_bloom()

	super._physics_process(delta)

# --- Phase Transitions ---

func _on_phase_change(new_phase: int) -> void:
	super._on_phase_change(new_phase)
	match new_phase:
		2:
			_show_boss_warning("DODGE THE RINGS!")
			_spawn_count = 4
			# Immediately trigger first spore bloom
			_start_spore_bloom()
		3:
			_show_boss_warning("MYCORRHIZAL NETWORK!")
			# Double toxic cloud range
			_toxic_cloud_radius = 80.0

# --- Toxic Cloud ---

func _release_toxic_cloud() -> void:
	if not player_ref or not is_instance_valid(player_ref): return
	_play_attack_anim()

	# Create poison area
	var cloud = Area2D.new()
	cloud.collision_layer = 0
	cloud.collision_mask = 1  # Detect player
	cloud.global_position = global_position
	cloud.z_index = -1
	cloud.monitoring = true

	# Visual
	var visual = Node2D.new()
	visual.z_index = -1
	cloud.add_child(visual)

	# Collision
	var col = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = _toxic_cloud_radius
	col.shape = shape
	cloud.add_child(col)

	var parent = get_parent()
	if not parent: return
	parent.call_deferred("add_child", cloud)

	# Run poison ticks
	_run_cloud_ticks(cloud, visual, 0, 10)

func _run_cloud_ticks(cloud: Area2D, visual: Node2D, tick: int, max_ticks: int) -> void:
	if tick >= max_ticks or not is_instance_valid(cloud):
		if is_instance_valid(cloud):
			cloud.queue_free()
		return
	if not is_instance_valid(self) or not is_inside_tree():
		if is_instance_valid(cloud): cloud.queue_free()
		return

	# Draw expanding/fading green circles
	if is_instance_valid(visual):
		var ring = Polygon2D.new()
		var pts: PackedVector2Array = []
		for i in 16:
			var angle = TAU * i / 16.0
			var r = _toxic_cloud_radius * (0.5 + tick * 0.05)
			pts.append(Vector2(cos(angle), sin(angle)) * r)
		ring.polygon = pts
		ring.color = Color(0.2, 0.7, 0.3, 0.25 - tick * 0.02)
		visual.add_child(ring)
		var tw_r = ring.create_tween()
		tw_r.tween_property(ring, "modulate:a", 0.0, 0.5)
		tw_r.tween_callback(ring.queue_free)

	# Damage player if in cloud
	if is_instance_valid(cloud):
		var bodies = cloud.get_overlapping_bodies()
		for body in bodies:
			if body.is_in_group("player") and body.has_method("take_damage"):
				body.take_damage(TOXIC_CLOUD_DAMAGE, self)

	# Next tick
	if not is_inside_tree(): return
	await get_tree().create_timer(0.5).timeout
	_run_cloud_ticks(cloud, visual, tick + 1, max_ticks)

# --- Spawn Children ---

func _spawn_children() -> void:
	var spore_scene = load("res://scenes/enemies/enemy_spore_walker.tscn")
	if not spore_scene: return
	var parent = get_parent()
	if not parent: return
	for i in _spawn_count:
		var minion = spore_scene.instantiate()
		var angle = TAU * i / _spawn_count
		minion.global_position = global_position + Vector2(cos(angle), sin(angle)) * 25.0
		minion.died.connect(func(_xp: int = 0):
			if not WaveManager.wave_active: return
			WaveManager.enemies_alive = maxi(0, WaveManager.enemies_alive - 1)
			WaveManager.emit_signal("enemies_remaining_changed", WaveManager.get_wave_enemy_count())
		)
		parent.add_child(minion)
		WaveManager.enemies_alive += 1
		WaveManager.emit_signal("enemies_remaining_changed", WaveManager.get_wave_enemy_count())

	# Spawn visual
	if sprite:
		var tw = create_tween()
		tw.tween_property(sprite, "modulate", Color(0.5, 1.5, 0.5), 0.15)
		tw.tween_property(sprite, "modulate", Color.WHITE, 0.3)

# --- Heal Pulse ---

func _heal_pulse() -> void:
	# Heal self
	health = mini(health, max_health)
	var heal = mini(HEAL_AMOUNT, max_health - health)
	health += heal
	if health_bar:
		health_bar.value = health

	# Phase 3: Also heal nearby minions
	if _boss_phase >= 3:
		_heal_nearby_minions()

	# Green pulse visual
	var pulse = Polygon2D.new()
	var pts: PackedVector2Array = []
	for i in 12:
		var angle = TAU * i / 12.0
		pts.append(Vector2(cos(angle), sin(angle)) * 30.0)
	pulse.polygon = pts
	pulse.color = Color(0.3, 1.0, 0.4, 0.4)
	pulse.position = global_position
	pulse.z_index = -1
	var parent = get_parent()
	if not parent: return
	parent.add_child(pulse)
	var tw = pulse.create_tween()
	tw.tween_property(pulse, "scale", Vector2(2.0, 2.0), 0.5)
	tw.parallel().tween_property(pulse, "modulate:a", 0.0, 0.5)
	tw.tween_callback(pulse.queue_free)

	# Show heal text
	var txt = Label.new()
	txt.text = "+%d" % heal
	txt.add_theme_font_size_override("font_size", 9)
	txt.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4))
	txt.position = global_position + Vector2(-8, -24)
	txt.z_index = 10
	parent.add_child(txt)
	var tw2 = txt.create_tween()
	tw2.tween_property(txt, "position:y", txt.position.y - 16, 0.6)
	tw2.parallel().tween_property(txt, "modulate:a", 0.0, 0.6)
	tw2.tween_callback(txt.queue_free)

func _heal_nearby_minions() -> void:
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if enemy == self: continue
		if not is_instance_valid(enemy) or enemy.is_dead: continue
		var dist = global_position.distance_to(enemy.global_position)
		if dist < 120.0:
			enemy.health = mini(enemy.health + HEAL_AMOUNT, enemy.max_health)
			if enemy.health_bar:
				enemy.health_bar.value = enemy.health
			# Green flash on healed minion
			if enemy.sprite:
				var tw = enemy.create_tween()
				tw.tween_property(enemy.sprite, "modulate", Color(0.5, 1.8, 0.5), 0.15)
				tw.tween_property(enemy.sprite, "modulate", Color.WHITE, 0.25)

# --- Spore Bloom (Phase 2+) ---

func _start_spore_bloom() -> void:
	if _spore_bloom_active or is_dead: return
	_spore_bloom_active = true
	_spore_bloom_elapsed = 0.0
	_bloom_ring_timer = 0.0

	_show_boss_warning("DODGE THE RINGS!")

	# Root in place for 8 seconds
	_rooted = true
	_root_timer = SPORE_BLOOM_DURATION

	# Visual: purple glow while rooted
	if sprite:
		sprite.modulate = Color(0.8, 0.4, 1.2)

func _process_spore_bloom(delta: float) -> void:
	_spore_bloom_elapsed += delta
	_bloom_ring_timer += delta

	# Emit expanding ring every 1.5s
	if _bloom_ring_timer >= RING_INTERVAL:
		_bloom_ring_timer -= RING_INTERVAL
		_spawn_poison_ring()

	# Update existing rings (expand them)
	_update_rings(delta)

	# End bloom after duration
	if _spore_bloom_elapsed >= SPORE_BLOOM_DURATION:
		_spore_bloom_active = false
		# Clear any remaining rings
		for ring_data in _active_rings:
			if is_instance_valid(ring_data["node"]):
				ring_data["node"].queue_free()
		_active_rings.clear()
		# Restore normal color
		if sprite:
			sprite.modulate = Color.WHITE

func _spawn_poison_ring() -> void:
	# Limit active rings
	if _active_rings.size() >= MAX_ACTIVE_RINGS:
		var oldest = _active_rings.pop_front()
		if is_instance_valid(oldest["node"]):
			oldest["node"].queue_free()

	var parent = get_parent()
	if not parent: return

	# Create ring using a Node2D container with Line2D for visual + Area2D for damage
	var ring_node = Node2D.new()
	ring_node.global_position = global_position
	ring_node.z_index = 5

	# Line2D ring visual
	var line = Line2D.new()
	line.width = RING_WIDTH
	line.default_color = Color(0.3, 0.9, 0.2, 0.7)
	line.closed = true
	# Start as a small ring
	var segments = 24
	for i in segments:
		var angle = TAU * i / float(segments)
		line.add_point(Vector2(cos(angle), sin(angle)) * 10.0)
	ring_node.add_child(line)

	# Damage area
	var area = Area2D.new()
	area.collision_layer = 0
	area.collision_mask = 1  # player
	area.monitoring = true
	var col = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 10.0
	col.shape = shape
	area.add_child(col)
	ring_node.add_child(area)

	parent.add_child(ring_node)

	_active_rings.append({
		"node": ring_node,
		"line": line,
		"area": area,
		"shape": shape,
		"col": col,
		"radius": 10.0,
		"origin": global_position
	})

func _update_rings(delta: float) -> void:
	var to_remove: Array = []

	for ring_data in _active_rings:
		if not is_instance_valid(ring_data["node"]):
			to_remove.append(ring_data)
			continue

		# Expand the ring
		ring_data["radius"] += RING_EXPAND_SPEED * delta

		# Update the Line2D visual to match the new radius
		var line: Line2D = ring_data["line"]
		var segments = line.get_point_count()
		for i in segments:
			var angle = TAU * i / float(segments)
			line.set_point_position(i, Vector2(cos(angle), sin(angle)) * ring_data["radius"])

		# Update the collision shape — use a thin ring by making the area a circle
		# and checking distance manually for ring-shaped damage
		# We'll use the area for overlap detection but check distance manually
		ring_data["shape"].radius = ring_data["radius"] + RING_WIDTH * 0.5

		# Check for player damage (ring-shaped: only damage if player is near ring edge)
		if player_ref and is_instance_valid(player_ref):
			var dist = ring_data["origin"].distance_to(player_ref.global_position)
			var inner = ring_data["radius"] - RING_WIDTH * 0.5
			var outer = ring_data["radius"] + RING_WIDTH * 0.5
			if dist >= inner and dist <= outer:
				if player_ref.has_method("take_damage"):
					player_ref.take_damage(RING_DAMAGE, self)

		# Fade as it expands
		var alpha = 1.0 - (ring_data["radius"] / RING_MAX_RADIUS)
		line.default_color = Color(0.3, 0.9, 0.2, clampf(alpha * 0.7, 0.0, 0.7))

		# Remove if too large
		if ring_data["radius"] >= RING_MAX_RADIUS:
			ring_data["node"].queue_free()
			to_remove.append(ring_data)

	for rd in to_remove:
		_active_rings.erase(rd)
