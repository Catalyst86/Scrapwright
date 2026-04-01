extends EnemyBase

# Fungal Titan — Stage 2 Boss
# Poison trail, spore burst projectiles, passive heal.

var poison_trail_timer: float = 0.0
var spore_burst_timer: float = 0.0
var heal_timer: float = 0.0

const POISON_TRAIL_INTERVAL = 1.5
const POISON_TRAIL_DURATION = 5.0
const POISON_DPS = 3

const SPORE_BURST_INTERVAL = 6.0
const SPORE_COUNT = 6
const SPORE_SPEED = 70.0

const HEAL_INTERVAL = 10.0
const HEAL_AMOUNT = 20
var _proj_scene: PackedScene = null

func _ready() -> void:
	enemy_type       = "fungal_titan"
	max_health       = 650
	move_speed       = 25.0
	damage           = 20
	xp_value         = 120
	contact_cooldown = 1.5
	_proj_scene = load("res://scenes/enemy_projectile.tscn")
	super._ready()
	if health_bar:
		health_bar.visible = true

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	poison_trail_timer += delta
	spore_burst_timer += delta
	heal_timer += delta

	if poison_trail_timer >= POISON_TRAIL_INTERVAL:
		poison_trail_timer = 0.0
		_drop_poison()

	if spore_burst_timer >= SPORE_BURST_INTERVAL:
		spore_burst_timer = 0.0
		_spore_burst()

	if heal_timer >= HEAL_INTERVAL:
		heal_timer = 0.0
		_heal()

	super._physics_process(delta)

func _drop_poison() -> void:
	var parent = get_parent()
	if not parent:
		return
	var pool = Area2D.new()
	pool.collision_layer = 0
	pool.collision_mask = 1  # detect player
	pool.monitoring = true
	pool.global_position = global_position

	var shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = 14.0
	shape.shape = circle
	pool.add_child(shape)

	# Visual — bubbling acid puddle with layered circles
	var vis = Node2D.new()
	vis.z_index = -1
	# Outer glow ring (dark green border)
	var glow_ring = _make_circle_poly(18, 16)
	glow_ring.color = Color(0.08, 0.35, 0.1, 0.25)
	glow_ring.z_index = -1
	vis.add_child(glow_ring)
	# Main puddle — dark green circle with irregular edge
	var puddle_main = _make_circle_poly(14, 14, 2.0)
	puddle_main.color = Color(0.12, 0.5, 0.18, 0.55)
	vis.add_child(puddle_main)
	# Lighter green inner circle
	var inner_pool = _make_circle_poly(9, 12, 1.5)
	inner_pool.color = Color(0.25, 0.7, 0.25, 0.45)
	vis.add_child(inner_pool)
	# Bright acidic center
	var acid_core = _make_circle_poly(5, 10)
	acid_core.color = Color(0.4, 0.9, 0.3, 0.35)
	vis.add_child(acid_core)
	# Bubble dots — tiny bright circles that pop up
	for i in 5:
		var bubble = _make_circle_poly(randf_range(1.0, 2.2), 6)
		bubble.color = Color(0.4, 0.9, 0.35, randf_range(0.4, 0.7))
		bubble.position = Vector2(randf_range(-9, 9), randf_range(-9, 9))
		vis.add_child(bubble)
		# Animate each bubble bobbing up then fading
		var btw = pool.create_tween().set_loops()
		btw.tween_property(bubble, "position:y", bubble.position.y - 3.0, randf_range(0.4, 0.8)).set_delay(randf_range(0.0, 1.0))
		btw.tween_property(bubble, "position:y", bubble.position.y, 0.3)
	pool.add_child(vis)
	# Pulsing glow on the whole puddle
	var pulse = pool.create_tween().set_loops()
	pulse.tween_property(vis, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.8).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(vis, "modulate", Color(0.85, 1.0, 0.85, 0.8), 0.8).set_trans(Tween.TRANS_SINE)

	parent.add_child(pool)

	# Damage tick logic
	var tick_count = int(POISON_TRAIL_DURATION / 0.5)
	_run_poison_ticks(pool, tick_count)

func _make_circle_poly(radius: float, segments: int = 12, jitter: float = 0.0) -> Polygon2D:
	var poly = Polygon2D.new()
	var pts: PackedVector2Array = []
	for i in segments:
		var angle = TAU * i / float(segments)
		var r = radius + randf_range(-jitter, jitter)
		pts.append(Vector2(cos(angle), sin(angle)) * r)
	poly.polygon = pts
	return poly

func _run_poison_ticks(pool: Area2D, ticks_left: int) -> void:
	if ticks_left <= 0 or not is_instance_valid(pool):
		if is_instance_valid(pool):
			pool.queue_free()
		return
	if not is_instance_valid(self) or not is_inside_tree():
		if is_instance_valid(pool): pool.queue_free()
		return
	await get_tree().create_timer(0.5).timeout
	if not is_inside_tree() or not is_instance_valid(pool):
		return
	var bodies = pool.get_overlapping_bodies()
	for body in bodies:
		if body.is_in_group("player") and body.has_method("take_damage"):
			body.take_damage(POISON_DPS)
	# Fade visual over time
	var vis = pool.get_child(1) if pool.get_child_count() > 1 else null
	if vis:
		vis.modulate.a = float(ticks_left) / (POISON_TRAIL_DURATION / 0.5)
	_run_poison_ticks(pool, ticks_left - 1)

func _spore_burst() -> void:
	if not player_ref or not is_instance_valid(player_ref):
		return
	var proj_scene = _proj_scene
	if not proj_scene:
		return
	var parent = get_parent()
	if not parent:
		return
	_play_attack_anim_then(_do_spore_burst)

func _do_spore_burst() -> void:
	if is_dead: return
	var proj_scene = _proj_scene
	if not proj_scene: return
	var parent = get_parent()
	if not parent: return

	# Visual feedback
	if sprite:
		sprite.modulate = Color(0.4, 1.5, 0.6)
		var tw = create_tween()
		tw.tween_property(sprite, "modulate", Color.WHITE, 0.3)
	if _dot:
		_dot.modulate = Color(0.4, 1.5, 0.6)
		var tw2 = create_tween()
		tw2.tween_property(_dot, "modulate", Color.WHITE, 0.3)

	for i in SPORE_COUNT:
		var angle = (TAU / SPORE_COUNT) * i
		var dir = Vector2(cos(angle), sin(angle))
		var proj = proj_scene.instantiate()
		proj.global_position = global_position + dir * 12.0
		proj.projectile_type = "spore"
		proj.setup(dir * SPORE_SPEED, damage)
		parent.add_child(proj)

func _heal() -> void:
	if health >= max_health:
		return
	health = mini(health + HEAL_AMOUNT, max_health)
	if health_bar:
		health_bar.value = health
	# Green flash
	if sprite:
		sprite.modulate = Color(0.5, 1.8, 0.5)
		var tw = create_tween()
		tw.tween_property(sprite, "modulate", Color.WHITE, 0.25)
	if _dot:
		_dot.modulate = Color(0.5, 1.8, 0.5)
		var tw2 = create_tween()
		tw2.tween_property(_dot, "modulate", Color.WHITE, 0.25)
	# Heal number
	var lbl = Label.new()
	lbl.text = "+" + str(HEAL_AMOUNT)
	lbl.z_index = 20
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4))
	lbl.position = global_position + Vector2(-8, -20)
	var parent = get_parent()
	if parent:
		parent.add_child(lbl)
		var tw3 = lbl.create_tween()
		tw3.set_parallel(true)
		tw3.tween_property(lbl, "position:y", lbl.position.y - 18.0, 0.5).set_ease(Tween.EASE_OUT)
		tw3.tween_property(lbl, "modulate:a", 0.0, 0.5).set_delay(0.25)
		tw3.set_parallel(false)
		tw3.tween_callback(lbl.queue_free)
