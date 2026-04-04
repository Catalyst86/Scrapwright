extends Area2D

# Enemy projectile — small arrow/bolt fired by shooter-type enemies

var vel: Vector2 = Vector2.ZERO
var dmg: int = 12
var lifetime: float = 3.0
var projectile_type: String = "bone"
var source_enemy: Node = null

var _poly: Polygon2D = null
var _sfx_hit: AudioStreamPlayer2D = null

const TYPE_COLORS = {
	"bone":  Color(1.0, 0.55, 0.1),
	"spore": Color(0.3, 0.85, 0.4),
	"lava":  Color(1.0, 0.35, 0.05),
	"ice":   Color(0.5, 0.85, 1.0),
	"steam": Color(0.85, 0.85, 0.9),
	"void":  Color(0.6, 0.2, 0.9),
	"saw":   Color(0.7, 0.7, 0.75),
}

var _spin_speed: float = 0.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	var hit_path = "res://assets/audio/sfx/enemies/projectile_hit.wav"
	if ResourceLoader.exists(hit_path):
		_sfx_hit = AudioStreamPlayer2D.new()
		_sfx_hit.stream = load(hit_path)
		_sfx_hit.volume_db = -12.0
		_sfx_hit.max_distance = 400.0
		_sfx_hit.bus = "SFX"
		add_child(_sfx_hit)

	# Try to load a sprite for this projectile type
	var tex_path = "res://assets/sprites/items/proj_%s.png" % projectile_type
	if ResourceLoader.exists(tex_path):
		var spr = Sprite2D.new()
		spr.texture = load(tex_path)
		# Ice projectiles are smaller to match the tiny ice archer
		if projectile_type == "ice":
			spr.scale = Vector2(0.5, 0.5)
		elif projectile_type == "saw":
			spr.scale = Vector2(1.25, 1.25)
			_spin_speed = 12.0
		else:
			spr.scale = Vector2(1.25, 1.25)
		add_child(spr)
	elif projectile_type == "saw":
		# Fallback: code-drawn saw blade
		_spin_speed = 12.0
		_build_saw_visual()
	else:
		# Fallback: visible colored triangle
		_poly = Polygon2D.new()
		_poly.color = TYPE_COLORS.get(projectile_type, Color(1.0, 0.55, 0.1))
		# Ice projectiles are smaller (ice archer is a small enemy)
		if projectile_type == "ice":
			_poly.polygon = PackedVector2Array([Vector2(-8, -4), Vector2(8, 0), Vector2(-8, 4)])
		else:
			_poly.polygon = PackedVector2Array([Vector2(-14, -7), Vector2(14, 0), Vector2(-14, 7)])
		add_child(_poly)

func _build_saw_visual() -> void:
	# Draw a gear/saw blade shape with 8 teeth
	var points := PackedVector2Array()
	var teeth := 8
	var outer_r := 14.0
	var inner_r := 8.0
	for i in teeth * 2:
		var angle = (i / float(teeth * 2)) * TAU
		var r = outer_r if i % 2 == 0 else inner_r
		points.append(Vector2(cos(angle) * r, sin(angle) * r))

	# Outer saw body
	_poly = Polygon2D.new()
	_poly.polygon = points
	_poly.color = Color(0.65, 0.65, 0.7)
	add_child(_poly)

	# Inner circle (axle hole)
	var center_points := PackedVector2Array()
	for i in 12:
		var angle = (i / 12.0) * TAU
		center_points.append(Vector2(cos(angle) * 3.0, sin(angle) * 3.0))
	var center = Polygon2D.new()
	center.polygon = center_points
	center.color = Color(0.3, 0.3, 0.35)
	add_child(center)

func setup(velocity: Vector2, damage: int) -> void:
	vel      = velocity
	dmg      = damage
	rotation = velocity.angle()

func _physics_process(delta: float) -> void:
	position += vel * delta
	if _spin_speed > 0.0:
		rotation += _spin_speed * delta
	lifetime -= delta
	if lifetime <= 0:
		queue_free()

func _play_hit_and_free() -> void:
	if _sfx_hit:
		_sfx_hit.pitch_scale = randf_range(0.9, 1.1)
		# Reparent audio so it survives queue_free
		var parent = get_parent()
		if parent:
			remove_child(_sfx_hit)
			parent.add_child(_sfx_hit)
			_sfx_hit.global_position = global_position
			_sfx_hit.play()
			_sfx_hit.finished.connect(_sfx_hit.queue_free)
	queue_free()

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		if body.has_method("take_damage"):
			body.take_damage(dmg)
		# Thorns — reflect damage back to the enemy that fired this projectile
		var thorns_dmg = GameState.perk_thorns_damage
		if thorns_dmg > 0 and source_enemy and is_instance_valid(source_enemy) and not source_enemy.get("is_dead"):
			if source_enemy.has_method("take_damage"):
				source_enemy.take_damage(thorns_dmg, global_position)
		_play_hit_and_free()
	elif body.is_in_group("wall") or body.is_in_group("boss_obstacles") or body is TileMapLayer:
		_play_hit_and_free()
