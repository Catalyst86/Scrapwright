class_name OrbitalWeapon extends Node2D

# ============================================================
# OrbitalWeapon — Base class for floating orbital weapons
# All weapons share the same orbit speed and radius,
# evenly spaced around the player based on slot_index.
# ============================================================

var weapon_id: String = ""
var level: int = 1
var cooldown: float = 1.0
var current_cooldown: float = 0.0
var weapon_damage: int = 5
var attack_range: float = 80.0
var weapon_color: Color = Color.WHITE

# Orbit slot — assigned by player to keep weapons evenly spaced
var slot_index: int = 0

# Shared orbit time — pauses when game is paused (unlike Time.get_ticks_msec)
static var _shared_orbit_time: float = 0.0
static var _active_slots: Array = []

static func reset_orbit() -> void:
	_shared_orbit_time = 0.0
	_active_slots.clear()

var visual_tier: int = 0

var _sprite: Sprite2D = null
var _dot: Node2D = null
var _bob_time: float = 0.0

const ORBIT_SPEED = 2.0     # shared — all weapons orbit at the same rate
const ORBIT_RADIUS = 30.0   # shared — same distance from player

func _ready() -> void:
	z_index = 5
	if slot_index not in _active_slots:
		_active_slots.append(slot_index)
		_active_slots.sort()
	_load_weapon_data()
	_setup_visual()

func _exit_tree() -> void:
	_active_slots.erase(slot_index)

func _load_weapon_data() -> void:
	if weapon_id == "" or not OrbitalDB:
		return
	var data = OrbitalDB.get_weapon_data(weapon_id)
	if data.is_empty():
		return
	weapon_color = data.get("color", Color.WHITE)
	weapon_damage = OrbitalDB.get_damage(weapon_id, level)
	cooldown = OrbitalDB.get_cooldown(weapon_id, level)
	attack_range = OrbitalDB.get_attack_range(weapon_id, level)

func _setup_visual() -> void:
	visual_tier = OrbitalDB.get_visual_tier(level)
	# Try tier-specific sprite first, then base sprite, then fallback dot
	var tier_path = "res://assets/sprites/orbitals/orbital_%s_t%d.png" % [weapon_id, visual_tier]
	var base_path = "res://assets/sprites/orbitals/orbital_%s.png" % weapon_id
	var tex_path = tier_path if visual_tier > 0 and ResourceLoader.exists(tier_path) else base_path
	if ResourceLoader.exists(tex_path):
		_sprite = Sprite2D.new()
		_sprite.texture = load(tex_path)
		_sprite.scale = Vector2(0.5, 0.5)
		add_child(_sprite)
	else:
		_dot = Polygon2D.new()
		var pts: PackedVector2Array = []
		for i in 8:
			var angle = TAU * i / 8.0
			pts.append(Vector2(cos(angle), sin(angle)) * 5.0)
		_dot.polygon = pts
		_dot.color = weapon_color
		add_child(_dot)

func _physics_process(delta: float) -> void:
	if GameState.current_phase != GameState.Phase.ARENA_COMBAT:
		return

	# All weapons use the same global time so they rotate in lockstep
	# Only the lowest active slot increments to prevent Nx faster advancement
	if _active_slots.size() > 0 and slot_index == _active_slots[0]:
		_shared_orbit_time += delta
	var total_weapons = _get_orbital_count()
	var base_angle = _shared_orbit_time * ORBIT_SPEED
	var slot_offset = (TAU / maxf(total_weapons, 1)) * slot_index
	var angle = base_angle + slot_offset

	_bob_time += delta
	var bob = sin(_bob_time * 3.0) * 2.0
	position = Vector2(cos(angle) * ORBIT_RADIUS, sin(angle) * ORBIT_RADIUS + bob)

	if _sprite:
		_sprite.rotation = angle * 0.3
	elif _dot:
		_dot.rotation = angle * 0.5

	current_cooldown -= delta
	if current_cooldown <= 0:
		var target = _find_target()
		if target:
			_fire(target)
			current_cooldown = cooldown
			if AudioManager.has_sound(weapon_id):
				AudioManager.play(weapon_id, 0.2)

func _get_shared_time() -> float:
	return _shared_orbit_time

func _get_orbital_count() -> int:
	var player = get_parent()
	if not player:
		return 1
	var count = 0
	for child in player.get_children():
		if child is OrbitalWeapon:
			count += 1
	return maxi(count, 1)

func _find_target() -> Node:
	var player = get_parent()
	if not player or not is_instance_valid(player):
		return null
	var best_enemy: Node = null
	var best_dist: float = attack_range
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or enemy.get("is_dead"):
			continue
		var d = player.global_position.distance_to(enemy.global_position)
		if d < best_dist:
			best_dist = d
			best_enemy = enemy
	return best_enemy

func _fire(_target: Node) -> void:
	pass  # Override in subclasses

func level_up() -> void:
	level = mini(level + 1, OrbitalDB.MAX_LEVEL)
	_load_weapon_data()
	var old_vt = visual_tier
	visual_tier = OrbitalDB.get_visual_tier(level)
	if visual_tier > old_vt:
		_upgrade_visual(visual_tier)
	elif _sprite:
		_sprite.modulate = Color(2, 2, 2)
		var tw = _sprite.create_tween()
		tw.tween_property(_sprite, "modulate", Color.WHITE, 0.3)
	elif _dot:
		_dot.modulate = Color(2, 2, 2)
		var tw = _dot.create_tween()
		tw.tween_property(_dot, "modulate", Color.WHITE, 0.3)

func _upgrade_visual(tier: int) -> void:
	# Try loading tier-specific sprite
	var tier_path = "res://assets/sprites/orbitals/orbital_%s_t%d.png" % [weapon_id, tier]
	if ResourceLoader.exists(tier_path) and _sprite:
		_sprite.texture = load(tier_path)
	# Scale-burst animation for visual milestone
	var target = _sprite if _sprite else _dot
	if target:
		target.modulate = Color(2.5, 2.5, 2.5)
		var base_scale = target.scale
		target.scale = base_scale * 2.0
		var tw = target.create_tween()
		tw.tween_property(target, "scale", base_scale, 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BOUNCE)
		tw.parallel().tween_property(target, "modulate", Color.WHITE, 0.5)

# ═══════════════════════════════════════════════════════════════
# Visual FX — element-specific attack effects
# ═══════════════════════════════════════════════════════════════

func _show_lightning(from: Vector2, to: Vector2, color: Color, width: float = 2.0) -> void:
	var arena = _get_arena()
	if not arena: return
	var dist = from.distance_to(to)
	var segments = clampi(int(dist / 8.0), 3, 12)
	var direction = (to - from).normalized()
	var perp = Vector2(-direction.y, direction.x)

	# Main jagged bolt
	var bolt = Line2D.new()
	bolt.width = width
	bolt.default_color = color
	bolt.z_index = 10
	bolt.add_point(from)
	for i in range(1, segments):
		var t = float(i) / segments
		var jitter = perp * randf_range(-6.0, 6.0) * (1.0 - abs(t - 0.5) * 2.0)
		bolt.add_point(from.lerp(to, t) + jitter)
	bolt.add_point(to)
	arena.add_child(bolt)

	# Bright white core
	var core = Line2D.new()
	core.width = maxf(width * 0.4, 1.0)
	core.default_color = Color(1.0, 1.0, 1.0, 0.9)
	core.z_index = 11
	for i in bolt.get_point_count():
		core.add_point(bolt.get_point_position(i))
	arena.add_child(core)

	# Branch fork
	if segments > 4 and randf() < 0.6:
		var fork = Line2D.new()
		fork.width = maxf(width * 0.5, 1.0)
		fork.default_color = color * Color(1, 1, 1, 0.6)
		fork.z_index = 10
		var fi = clampi(int(segments * 0.6), 1, bolt.get_point_count() - 1)
		var fp = bolt.get_point_position(fi)
		fork.add_point(fp)
		fork.add_point(fp + perp * randf_range(-15, 15) + direction * randf_range(5, 15))
		arena.add_child(fork)
		var twf = fork.create_tween()
		twf.tween_property(fork, "modulate:a", 0.0, 0.15)
		twf.tween_callback(fork.queue_free)

	var tw1 = bolt.create_tween()
	tw1.tween_property(bolt, "modulate:a", 0.0, 0.15)
	tw1.tween_callback(bolt.queue_free)
	var tw2 = core.create_tween()
	tw2.tween_property(core, "modulate:a", 0.0, 0.1)
	tw2.tween_callback(core.queue_free)

func _show_ice_spike(from: Vector2, to: Vector2) -> void:
	var arena = _get_arena()
	if not arena: return
	var direction = (to - from).normalized()
	var perp = Vector2(-direction.y, direction.x)
	var dist = from.distance_to(to)
	var segs = clampi(int(dist / 10.0), 3, 10)

	# Sharp angular ice beam
	var beam = Line2D.new()
	beam.width = 3.0
	beam.default_color = Color(0.4, 0.8, 1.0)
	beam.z_index = 10
	beam.add_point(from)
	for i in range(1, segs):
		var t = float(i) / segs
		beam.add_point(from.lerp(to, t) + perp * (4.0 if i % 2 == 0 else -4.0))
	beam.add_point(to)
	arena.add_child(beam)

	# Crystal shards
	for i in range(3):
		var t = randf_range(0.2, 0.8)
		var sp = from.lerp(to, t)
		var shard = Line2D.new()
		shard.width = 2.0
		shard.default_color = Color(0.7, 0.95, 1.0, 0.8)
		shard.z_index = 11
		var sd = perp * (8.0 if randf() > 0.5 else -8.0)
		shard.add_point(sp - sd * 0.3)
		shard.add_point(sp + sd)
		arena.add_child(shard)
		var tws = shard.create_tween()
		tws.tween_property(shard, "modulate:a", 0.0, 0.3)
		tws.tween_callback(shard.queue_free)

	# Frost particles at impact
	for i in range(5):
		var p = _make_circle(1.5, Color(0.6, 0.9, 1.0, 0.7))
		p.position = to + Vector2(randf_range(-6, 6), randf_range(-6, 6))
		p.z_index = 11
		arena.add_child(p)
		var twp = p.create_tween()
		twp.tween_property(p, "position", to + Vector2(randf_range(-14, 14), randf_range(-14, 14)), 0.25)
		twp.parallel().tween_property(p, "modulate:a", 0.0, 0.3)
		twp.tween_callback(p.queue_free)

	var tw = beam.create_tween()
	tw.tween_property(beam, "modulate:a", 0.0, 0.25)
	tw.tween_callback(beam.queue_free)

func _show_poison_cloud(pos: Vector2, radius: float = 12.0) -> void:
	var arena = _get_arena()
	if not arena: return
	for i in range(8):
		var sz = randf_range(4, 8)
		var p = _make_circle(sz * 0.5, Color(randf_range(0.2, 0.4), randf_range(0.7, 0.9), randf_range(0.1, 0.3), randf_range(0.4, 0.7)))
		p.position = pos + Vector2(randf_range(-radius, radius), randf_range(-radius, radius))
		p.z_index = 10
		arena.add_child(p)
		var tw = p.create_tween()
		var drift = pos + Vector2(randf_range(-radius*1.5, radius*1.5), randf_range(-radius*2, -radius*0.5))
		tw.tween_property(p, "position", drift, randf_range(0.5, 1.0))
		tw.parallel().tween_property(p, "modulate:a", 0.0, randf_range(0.5, 1.0))
		tw.parallel().tween_property(p, "scale", Vector2(1.5, 1.5), randf_range(0.4, 0.8))
		tw.tween_callback(p.queue_free)

func _show_fire_burst(pos: Vector2, size: float = 10.0) -> void:
	var arena = _get_arena()
	if not arena: return
	for i in range(6):
		var sz = randf_range(3, 6)
		var p = Polygon2D.new()
		var pts: PackedVector2Array = []
		var segs = 6
		for j in segs:
			var angle = TAU * j / segs
			pts.append(Vector2(cos(angle), sin(angle)) * sz * 0.5)
		p.polygon = pts
		var warmth = randf()
		if warmth < 0.3:   p.color = Color(1.0, 0.3, 0.0, 0.9)
		elif warmth < 0.6: p.color = Color(1.0, 0.6, 0.1, 0.8)
		else:              p.color = Color(1.0, 0.9, 0.3, 0.7)
		p.position = pos + Vector2(randf_range(-size*0.5, size*0.5), randf_range(-size*0.5, size*0.5))
		p.z_index = 10
		arena.add_child(p)
		var tw = p.create_tween()
		tw.tween_property(p, "position", p.position + Vector2(randf_range(-8, 8), randf_range(-15, -5)), randf_range(0.2, 0.5))
		tw.parallel().tween_property(p, "modulate:a", 0.0, randf_range(0.2, 0.5))
		tw.parallel().tween_property(p, "scale", Vector2(0.3, 0.3), randf_range(0.2, 0.5))
		tw.tween_callback(p.queue_free)

func _show_vine_whip(from: Vector2, to: Vector2) -> void:
	var arena = _get_arena()
	if not arena: return
	var direction = (to - from).normalized()
	var perp = Vector2(-direction.y, direction.x)
	var dist = from.distance_to(to)
	var segs = clampi(int(dist / 6.0), 4, 16)

	var vine = Line2D.new()
	vine.width = 3.0
	vine.default_color = Color(0.3, 0.65, 0.15)
	vine.z_index = 10
	vine.add_point(from)
	for i in range(1, segs):
		var t = float(i) / segs
		vine.add_point(from.lerp(to, t) + perp * sin(t * TAU * 2.0) * 4.0)
	vine.add_point(to)
	arena.add_child(vine)

	# Thorns
	for i in range(0, segs, 2):
		var t = float(i) / segs
		var tp = from.lerp(to, t)
		var thorn = Line2D.new()
		thorn.width = 1.5
		thorn.default_color = Color(0.5, 0.3, 0.1, 0.8)
		thorn.z_index = 11
		var side = 1.0 if i % 4 == 0 else -1.0
		thorn.add_point(tp)
		thorn.add_point(tp + perp * side * 6.0 + direction * 2.0)
		arena.add_child(thorn)
		var twt = thorn.create_tween()
		twt.tween_property(thorn, "modulate:a", 0.0, 0.3)
		twt.tween_callback(thorn.queue_free)

	var tw = vine.create_tween()
	tw.tween_property(vine, "modulate:a", 0.0, 0.3)
	tw.tween_callback(vine.queue_free)

func _show_blade_arc(center: Vector2, start_angle: float, arc_range: float) -> void:
	var arena = _get_arena()
	if not arena: return

	var slash = Line2D.new()
	slash.width = 4.0
	slash.default_color = Color(0.85, 0.85, 0.9, 0.9)
	slash.z_index = 10
	for i in range(12):
		var a = start_angle + deg_to_rad(i * 30 - 165)
		slash.add_point(center + Vector2(cos(a), sin(a)) * arc_range)
	arena.add_child(slash)

	var core = Line2D.new()
	core.width = 1.5
	core.default_color = Color(1.0, 1.0, 1.0, 0.8)
	core.z_index = 11
	for i in range(12):
		var a = start_angle + deg_to_rad(i * 30 - 165)
		core.add_point(center + Vector2(cos(a), sin(a)) * arc_range)
	arena.add_child(core)

	# Speed lines
	for i in range(4):
		var a = start_angle + deg_to_rad(i * 80 - 120)
		var sl = Line2D.new()
		sl.width = 1.0
		sl.default_color = Color(0.7, 0.7, 0.8, 0.5)
		sl.z_index = 10
		sl.add_point(center + Vector2(cos(a), sin(a)) * (arc_range * 0.7))
		sl.add_point(center + Vector2(cos(a), sin(a)) * (arc_range * 1.3))
		arena.add_child(sl)
		var tws = sl.create_tween()
		tws.tween_property(sl, "modulate:a", 0.0, 0.15)
		tws.tween_callback(sl.queue_free)

	var tw1 = slash.create_tween()
	tw1.tween_property(slash, "modulate:a", 0.0, 0.2)
	tw1.tween_callback(slash.queue_free)
	var tw2 = core.create_tween()
	tw2.tween_property(core, "modulate:a", 0.0, 0.15)
	tw2.tween_callback(core.queue_free)

func _show_magnet_pull(from: Vector2, to: Vector2) -> void:
	var arena = _get_arena()
	if not arena: return
	var perp = Vector2(-(to - from).normalized().y, (to - from).normalized().x)
	for i in range(3):
		var line = Line2D.new()
		line.width = 1.5
		line.default_color = Color(0.9, 0.2, 0.2, 0.6) if i % 2 == 0 else Color(0.2, 0.4, 0.9, 0.6)
		line.z_index = 10
		var offset = perp * (i - 1) * 4.0
		var mid = (from + to) * 0.5 + offset + perp * randf_range(-3, 3)
		line.add_point(from + offset * 0.5)
		line.add_point(mid)
		line.add_point(to + offset * 0.3)
		arena.add_child(line)
		var tw = line.create_tween()
		tw.tween_property(line, "modulate:a", 0.0, 0.2)
		tw.tween_callback(line.queue_free)

func _show_holy_burst(center: Vector2, radius: float) -> void:
	var arena = _get_arena()
	if not arena: return
	var gold = Color(1.0, 0.9, 0.5)

	# Expanding ring
	var ring = Line2D.new()
	ring.width = 2.5
	ring.default_color = gold
	ring.z_index = 10
	for i in range(17):
		var a = deg_to_rad(i * 22.5)
		ring.add_point(center + Vector2(cos(a), sin(a)) * radius * 0.3)
	arena.add_child(ring)

	# Light rays
	for i in range(6):
		var a = deg_to_rad(i * 60 + randf_range(-10, 10))
		var ray = Line2D.new()
		ray.width = 1.5
		ray.default_color = Color(1.0, 1.0, 0.8, 0.6)
		ray.z_index = 11
		ray.add_point(center)
		ray.add_point(center + Vector2(cos(a), sin(a)) * radius * 1.2)
		arena.add_child(ray)
		var twr = ray.create_tween()
		twr.tween_property(ray, "modulate:a", 0.0, 0.3)
		twr.tween_callback(ray.queue_free)

	# Sparkles
	for i in range(5):
		var s = _make_circle(1.0, Color(1.0, 1.0, 0.7, 0.9))
		s.position = center + Vector2(randf_range(-radius, radius), randf_range(-radius, radius))
		s.z_index = 11
		arena.add_child(s)
		var tws = s.create_tween()
		tws.tween_property(s, "position", s.position + Vector2(0, randf_range(-12, -5)), 0.4)
		tws.parallel().tween_property(s, "modulate:a", 0.0, 0.4)
		tws.tween_callback(s.queue_free)

	var tw = ring.create_tween()
	tw.tween_property(ring, "scale", Vector2(3.0, 3.0), 0.3)
	tw.parallel().tween_property(ring, "modulate:a", 0.0, 0.35)
	tw.tween_callback(ring.queue_free)

func _show_shield_flash(center: Vector2, radius: float) -> void:
	var arena = _get_arena()
	if not arena: return
	# Hex shield
	var hex = Line2D.new()
	hex.width = 2.5
	hex.default_color = Color(0.5, 0.8, 1.0, 0.8)
	hex.z_index = 10
	for i in range(7):
		var a = deg_to_rad(i * 60)
		hex.add_point(center + Vector2(cos(a), sin(a)) * radius)
	arena.add_child(hex)
	var tw = hex.create_tween()
	tw.tween_property(hex, "scale", Vector2(1.3, 1.3), 0.2)
	tw.parallel().tween_property(hex, "modulate:a", 0.0, 0.25)
	tw.tween_callback(hex.queue_free)

func _show_shadow_strike(pos: Vector2) -> void:
	var arena = _get_arena()
	if not arena: return
	# X-shaped dark slash
	for ao in [0.0, 90.0]:
		var sl = Line2D.new()
		sl.width = 2.5
		sl.default_color = Color(0.4, 0.1, 0.5, 0.9)
		sl.z_index = 10
		var a = deg_to_rad(45 + ao)
		sl.add_point(pos + Vector2(cos(a), sin(a)) * 10.0)
		sl.add_point(pos - Vector2(cos(a), sin(a)) * 10.0)
		arena.add_child(sl)
		var tw = sl.create_tween()
		tw.tween_property(sl, "modulate:a", 0.0, 0.2)
		tw.tween_callback(sl.queue_free)
	# Purple wisps
	for i in range(4):
		var w = _make_circle(1.5, Color(0.6, 0.2, 0.8, 0.7))
		w.position = pos + Vector2(randf_range(-8, 8), randf_range(-8, 8))
		w.z_index = 11
		arena.add_child(w)
		var tw2 = w.create_tween()
		tw2.tween_property(w, "position", w.position + Vector2(randf_range(-10, 10), randf_range(-12, -3)), 0.3)
		tw2.parallel().tween_property(w, "modulate:a", 0.0, 0.3)
		tw2.tween_callback(w.queue_free)

func _show_impact(pos: Vector2, color: Color, size: float = 8.0) -> void:
	var flash = _make_circle(size * 0.5, color)
	flash.position = pos
	flash.z_index = 10
	var arena = _get_arena()
	if arena:
		arena.add_child(flash)
		var tw = flash.create_tween()
		tw.tween_property(flash, "scale", Vector2(2.0, 2.0), 0.15)
		tw.parallel().tween_property(flash, "modulate:a", 0.0, 0.2)
		tw.tween_callback(flash.queue_free)

func _get_arena() -> Node:
	var player = get_parent()
	if player and player.get_parent():
		return player.get_parent()
	return null

func _make_circle(radius: float, color: Color, segments: int = 8) -> Polygon2D:
	var poly = Polygon2D.new()
	var pts: PackedVector2Array = []
	for i in segments:
		var angle = TAU * i / segments
		pts.append(Vector2(cos(angle), sin(angle)) * radius)
	poly.polygon = pts
	poly.color = color
	return poly
