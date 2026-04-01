extends EnemyBase

# Scrap Sentinel — Stage 1 Mid-Boss (Wave 7)
# Medium speed, spinning blade AoE attack, throws scrap projectiles, shield mode.

var blade_spin_timer: float = 0.0
var scrap_throw_timer: float = 0.0
var shield_timer: float = 0.0
var _is_shielded: bool = false

const BLADE_SPIN_INTERVAL = 3.5
const BLADE_SPIN_RANGE = 50.0
const BLADE_SPIN_DAMAGE = 12

const SCRAP_THROW_INTERVAL = 5.0
const SCRAP_COUNT = 4

const SHIELD_INTERVAL = 12.0
const SHIELD_DURATION = 3.0
var _proj_scene: PackedScene = null

func _ready() -> void:
	enemy_type       = "scrap_sentinel"
	max_health       = 350
	move_speed       = 40.0
	damage           = 18
	xp_value         = 80
	contact_cooldown = 1.2
	_proj_scene = load("res://scenes/enemy_projectile.tscn")
	super._ready()
	if health_bar:
		health_bar.visible = true

func _physics_process(delta: float) -> void:
	if is_dead: return
	blade_spin_timer += delta
	scrap_throw_timer += delta
	shield_timer += delta

	if blade_spin_timer >= BLADE_SPIN_INTERVAL:
		blade_spin_timer = 0.0
		_blade_spin()

	if scrap_throw_timer >= SCRAP_THROW_INTERVAL:
		scrap_throw_timer = 0.0
		_throw_scrap()

	if shield_timer >= SHIELD_INTERVAL:
		shield_timer = 0.0
		_activate_shield()

	super._physics_process(delta)

func take_damage(amount: int, from_pos: Vector2 = Vector2.ZERO) -> void:
	if _is_shielded:
		# Shield absorbs damage, show spark
		var spark = Label.new()
		spark.text = "BLOCKED"
		spark.add_theme_font_size_override("font_size", 7)
		spark.add_theme_color_override("font_color", Color(0.7, 0.8, 1.0))
		spark.position = global_position + Vector2(-16, -20)
		spark.z_index = 10
		var parent = get_parent()
		if parent:
			parent.add_child(spark)
			var tw = spark.create_tween()
			tw.tween_property(spark, "modulate:a", 0.0, 0.4)
			tw.tween_callback(spark.queue_free)
		return
	super.take_damage(amount, from_pos)

func _blade_spin() -> void:
	if not player_ref or not is_instance_valid(player_ref): return
	_play_attack_anim()
	# Flash red
	if sprite:
		var tw = create_tween()
		tw.tween_property(sprite, "modulate", Color(1.5, 0.5, 0.5), 0.1)
		tw.tween_property(sprite, "modulate", Color.WHITE, 0.2)

	# Damage player if close
	var dist = global_position.distance_to(player_ref.global_position)
	if dist < BLADE_SPIN_RANGE:
		if player_ref.has_method("take_damage"):
			player_ref.take_damage(BLADE_SPIN_DAMAGE)

	# Spinning blade visual — expanding arc lines
	for i in 6:
		var angle = TAU * i / 6.0
		var line = Line2D.new()
		line.width = 2.5
		line.default_color = Color(0.8, 0.6, 0.3, 0.8)
		line.z_index = 5
		var start = global_position + Vector2(cos(angle), sin(angle)) * 8.0
		var end_pt = global_position + Vector2(cos(angle), sin(angle)) * BLADE_SPIN_RANGE
		line.add_point(start)
		line.add_point(end_pt)
		var parent = get_parent()
		if parent:
			parent.add_child(line)
			var tw = line.create_tween()
			tw.tween_property(line, "modulate:a", 0.0, 0.3)
			tw.tween_callback(line.queue_free)

func _throw_scrap() -> void:
	if not player_ref or not is_instance_valid(player_ref): return
	var proj_scene = _proj_scene
	if not proj_scene: return
	_play_attack_anim_then(_do_throw_scrap)

func _do_throw_scrap() -> void:
	if is_dead or not player_ref or not is_instance_valid(player_ref): return
	var proj_scene = _proj_scene
	if not proj_scene: return
	var dir_to_player = (player_ref.global_position - global_position).normalized()
	for i in SCRAP_COUNT:
		var spread = (i - SCRAP_COUNT / 2.0) * 0.3
		var proj = proj_scene.instantiate()
		proj.global_position = global_position
		proj.setup(dir_to_player.rotated(spread) * 90.0, 10)
		var parent = get_parent()
		if parent:
			parent.add_child(proj)

func _activate_shield() -> void:
	_is_shielded = true
	# Blue shield glow
	if sprite:
		sprite.modulate = Color(0.5, 0.7, 1.5)
	# Shield duration
	var tw = create_tween()
	tw.tween_interval(SHIELD_DURATION)
	tw.tween_callback(func():
		_is_shielded = false
		if sprite and not is_dead:
			sprite.modulate = Color.WHITE
	)
