extends EnemyBase

# Glacial Hulk — Stage 4 slow tank, leaves ice patches on ground

var ice_patch_timer: float = 0.0
const ICE_PATCH_INTERVAL = 2.5
const ICE_PATCH_RADIUS = 20.0
const ICE_PATCH_DURATION = 4.0
const ICE_PATCH_SLOW = 0.3  # 30% slow

func _ready() -> void:
	enemy_type       = "glacial_hulk"
	max_health       = 180
	move_speed       = 28.0
	damage           = 18
	xp_value         = 35
	contact_cooldown = 1.5
	knockback_resistance = 0.70  # Heavy — takes only 30% knockback
	super._ready()

func _physics_process(delta: float) -> void:
	if is_dead: return
	ice_patch_timer += delta
	if ice_patch_timer >= ICE_PATCH_INTERVAL and velocity.length() > 3.0:
		ice_patch_timer = 0.0
		_spawn_ice_patch()
	super._physics_process(delta)

func _spawn_ice_patch() -> void:
	_play_attack_anim()
	var patch = Area2D.new()
	patch.collision_layer = 0
	patch.collision_mask = 1
	patch.global_position = global_position
	patch.z_index = -1
	patch.monitoring = true

	var col = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = ICE_PATCH_RADIUS
	col.shape = shape
	patch.add_child(col)

	# Visual — blue circle
	var visual = Polygon2D.new()
	var pts: PackedVector2Array = []
	for i in 12:
		var angle = TAU * i / 12.0
		pts.append(Vector2(cos(angle), sin(angle)) * ICE_PATCH_RADIUS)
	visual.polygon = pts
	visual.color = Color(0.4, 0.7, 1.0, 0.35)
	patch.add_child(visual)

	if get_parent():
		get_parent().call_deferred("add_child", patch)

	# Slow players who enter
	patch.body_entered.connect(func(body):
		if body.is_in_group("player") and body.has_method("apply_slow"):
			body.apply_slow(ICE_PATCH_SLOW, 1.5)
	)

	# Fade and remove after duration
	var tw = patch.create_tween()
	tw.tween_interval(ICE_PATCH_DURATION - 0.5)
	tw.tween_property(patch, "modulate:a", 0.0, 0.5)
	tw.tween_callback(patch.queue_free)
