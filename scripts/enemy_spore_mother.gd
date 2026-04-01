extends EnemyBase

# Spore Mother — Stage 2 Mid-Boss (Wave 21)
# Slow, spawns spore walkers, releases toxic clouds, heals nearby fungal enemies.

var toxic_cloud_timer: float = 0.0
var spawn_timer: float = 0.0
var heal_pulse_timer: float = 0.0

const TOXIC_CLOUD_INTERVAL = 4.0
const TOXIC_CLOUD_RADIUS = 45.0
const TOXIC_CLOUD_DAMAGE = 4

const SPAWN_INTERVAL = 7.0
const SPAWN_COUNT = 3

const HEAL_PULSE_INTERVAL = 10.0
const HEAL_AMOUNT = 15

func _ready() -> void:
	enemy_type       = "spore_mother"
	max_health       = 450
	move_speed       = 22.0
	damage           = 15
	xp_value         = 90
	contact_cooldown = 1.5
	super._ready()
	if health_bar:
		health_bar.visible = true

func _physics_process(delta: float) -> void:
	if is_dead: return
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

	super._physics_process(delta)

func _release_toxic_cloud() -> void:
	if not player_ref or not is_instance_valid(player_ref): return
	_play_attack_anim()

	# Create poison area
	var cloud = Area2D.new()
	cloud.collision_layer = 0
	cloud.collision_mask = 1  # Detect player
	cloud.global_position = global_position
	cloud.z_index = -1

	# Visual — animated green circle
	var visual = Node2D.new()
	visual.z_index = -1
	cloud.add_child(visual)

	# Collision
	var col = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = TOXIC_CLOUD_RADIUS
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
			var r = TOXIC_CLOUD_RADIUS * (0.5 + tick * 0.05)
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
				body.take_damage(TOXIC_CLOUD_DAMAGE)

	# Next tick
	if not is_inside_tree(): return
	await get_tree().create_timer(0.5).timeout
	_run_cloud_ticks(cloud, visual, tick + 1, max_ticks)

func _spawn_children() -> void:
	var spore_scene = load("res://scenes/enemies/enemy_spore_walker.tscn")
	if not spore_scene: return
	var parent = get_parent()
	if not parent: return
	for i in SPAWN_COUNT:
		var minion = spore_scene.instantiate()
		var angle = TAU * i / SPAWN_COUNT
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

func _heal_pulse() -> void:
	# Heal self
	health = mini(health, max_health)
	var heal = mini(HEAL_AMOUNT, max_health - health)
	health += heal
	if health_bar:
		health_bar.value = health

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
