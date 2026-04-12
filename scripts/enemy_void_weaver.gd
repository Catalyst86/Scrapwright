extends EnemyBase

# Void Weaver — Stage 6 creates dark damage zones (Area2D, 3 DPS for 5s) every 6s. Keeps distance.

var zone_timer: float = 0.0
const ZONE_INTERVAL = 6.0
const ZONE_RADIUS = 25.0
const ZONE_DPS = 3
const ZONE_DURATION = 5.0
const ZONE_TICK = 0.5

const PREFERRED_DIST = 90.0

func _ready() -> void:
	enemy_type       = "void_weaver"
	max_health       = 50
	move_speed       = 45.0
	damage           = 10
	xp_value         = 25
	contact_cooldown = 1.5
	super._ready()

func _physics_process(delta: float) -> void:
	if is_dead: return
	zone_timer += delta
	if zone_timer >= ZONE_INTERVAL:
		zone_timer = 0.0
		_create_dark_zone()
	super._physics_process(delta)

func _move_toward_player(delta: float) -> void:
	if not player_ref or not is_instance_valid(player_ref):
		player_ref = get_tree().get_first_node_in_group("player")
		return
	var dist = global_position.distance_to(player_ref.global_position)
	var dir  = (player_ref.global_position - global_position).normalized()
	if dist > PREFERRED_DIST + 20:
		velocity = velocity.move_toward(dir * move_speed, move_speed * 8.0 * delta)
	elif dist < PREFERRED_DIST - 20:
		velocity = velocity.move_toward(-dir * move_speed * 0.7, move_speed * 8.0 * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, move_speed * 8.0 * delta)
	_update_facing()

func _create_dark_zone() -> void:
	if not player_ref or not is_instance_valid(player_ref): return
	_play_attack_anim()

	# Place zone at player's current position
	var zone_pos = player_ref.global_position

	var zone = Area2D.new()
	zone.collision_layer = 0
	zone.collision_mask = 1
	zone.global_position = zone_pos
	zone.z_index = -1
	zone.monitoring = true

	var col = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = ZONE_RADIUS
	col.shape = shape
	zone.add_child(col)

	# Visual — dark purple circle
	var visual = Polygon2D.new()
	var pts: PackedVector2Array = []
	for i in 12:
		var angle = TAU * i / 12.0
		pts.append(Vector2(cos(angle), sin(angle)) * ZONE_RADIUS)
	visual.polygon = pts
	visual.color = Color(0.2, 0.05, 0.3, 0.4)
	zone.add_child(visual)

	if get_parent():
		get_parent().call_deferred("add_child", zone)

	# Run damage ticks
	_run_zone_ticks(zone, 0, int(ZONE_DURATION / ZONE_TICK))

func _run_zone_ticks(zone: Area2D, _tick: int, max_ticks: int) -> void:
	for tick in range(max_ticks):
		if not is_instance_valid(zone):
			return
		if not is_instance_valid(self) or not is_inside_tree():
			if is_instance_valid(zone): zone.queue_free()
			return
		if not is_stunned and is_instance_valid(zone):
			var bodies = zone.get_overlapping_bodies()
			for body in bodies:
				if body.is_in_group("player") and body.has_method("take_damage"):
					body.take_damage(ZONE_DPS, self)
		if not is_inside_tree(): return
		await get_tree().create_timer(ZONE_TICK).timeout
	if is_instance_valid(zone):
		zone.queue_free()
