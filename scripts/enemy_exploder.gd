extends EnemyBase

# Exploder — charges player and detonates on proximity

const FUSE_RANGE    = 46.0
const EXPLODE_RANGE = 60.0
const EXPLODE_DMG   = 45

var fuse_lit: bool = false
var _sfx_fuse: AudioStreamPlayer2D = null
var _sfx_explosion: AudioStreamPlayer2D = null

func _ready() -> void:
	enemy_type       = "exploder"
	max_health       = 26
	move_speed       = 68.0
	damage           = 5
	xp_value         = 15
	contact_cooldown = 99.0   # no contact damage; explodes instead
	can_burrow_flank = false  # Exploders don't burrow
	super._ready()
	var fuse_path = "res://assets/audio/sfx/enemies/fuse_beep.wav"
	if ResourceLoader.exists(fuse_path):
		_sfx_fuse = AudioStreamPlayer2D.new()
		_sfx_fuse.stream = load(fuse_path)
		_sfx_fuse.volume_db = -10.0
		_sfx_fuse.max_distance = 400.0
		_sfx_fuse.bus = "SFX"
		add_child(_sfx_fuse)
	var explode_path = "res://assets/audio/sfx/enemies/explosion.wav"
	if ResourceLoader.exists(explode_path):
		_sfx_explosion = AudioStreamPlayer2D.new()
		_sfx_explosion.stream = load(explode_path)
		_sfx_explosion.volume_db = -6.0
		_sfx_explosion.max_distance = 500.0
		_sfx_explosion.bus = "SFX"
		add_child(_sfx_explosion)

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	if not fuse_lit and player_ref and is_instance_valid(player_ref):
		if global_position.distance_to(player_ref.global_position) < FUSE_RANGE:
			fuse_lit = true
			_light_fuse()
	super._physics_process(delta)

func _light_fuse() -> void:
	if _sfx_fuse:
		_sfx_fuse.play()
	# Flash red four times then explode
	for _i in 4:
		if is_dead or not is_inside_tree(): return
		if sprite and not is_dead: sprite.modulate = Color(2.2, 0.2, 0.2)
		await get_tree().create_timer(0.14).timeout
		if is_dead or not is_inside_tree(): return
		if sprite and not is_dead: sprite.modulate = Color.WHITE
		await get_tree().create_timer(0.14).timeout
		if is_dead or not is_inside_tree(): return
	if not is_dead and is_inside_tree():
		_explode()

func _explode() -> void:
	if _sfx_fuse and _sfx_fuse.playing:
		_sfx_fuse.stop()
	if _sfx_explosion:
		_sfx_explosion.play()
	# Damage player
	if player_ref and is_instance_valid(player_ref):
		if global_position.distance_to(player_ref.global_position) < EXPLODE_RANGE:
			if player_ref.has_method("take_damage"):
				player_ref.take_damage(EXPLODE_DMG, self)

	# Splash damage to nearby enemies
	var space = get_world_2d().direct_space_state
	var q = PhysicsShapeQueryParameters2D.new()
	var circle = CircleShape2D.new()
	circle.radius = EXPLODE_RANGE
	q.shape = circle
	q.transform = Transform2D(0, global_position)
	q.collision_mask = 2
	for hit in space.intersect_shape(q, 8):
		var body = hit.collider
		if body != self and body.is_in_group("enemies") and body.has_method("take_damage"):
			body.take_damage(EXPLODE_DMG / 2.0, global_position)

	# Visual flash
	var flash = ColorRect.new()
	flash.color = Color(1.0, 0.6, 0.1, 0.6)
	flash.size  = Vector2(EXPLODE_RANGE * 2, EXPLODE_RANGE * 2)
	flash.position = global_position - Vector2(EXPLODE_RANGE, EXPLODE_RANGE)
	var parent = get_parent()
	if not parent:
		flash.queue_free()
		health = 0
		_die()
		return
	parent.add_child(flash)
	var tw = flash.create_tween()
	tw.tween_property(flash, "modulate:a", 0.0, 0.3)
	tw.tween_callback(flash.queue_free)

	health = 0
	_die()
