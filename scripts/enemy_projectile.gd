extends Area2D

# Enemy projectile — small arrow/bolt fired by shooter-type enemies

var vel: Vector2 = Vector2.ZERO
var dmg: int = 12
var lifetime: float = 3.0
var projectile_type: String = "bone"

var _poly: Polygon2D = null
var _sfx_hit: AudioStreamPlayer2D = null

const TYPE_COLORS = {
	"bone":  Color(1.0, 0.55, 0.1),
	"spore": Color(0.3, 0.85, 0.4),
	"lava":  Color(1.0, 0.35, 0.05),
	"ice":   Color(0.5, 0.85, 1.0),
	"steam": Color(0.85, 0.85, 0.9),
	"void":  Color(0.6, 0.2, 0.9),
}

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
		spr.scale = Vector2(0.35, 0.35)  # Scale down 32x32 sprites to ~11px
		add_child(spr)
	else:
		# Fallback: visible colored triangle (sized to match sprites)
		_poly = Polygon2D.new()
		_poly.color = TYPE_COLORS.get(projectile_type, Color(1.0, 0.55, 0.1))
		_poly.polygon = PackedVector2Array([Vector2(-10, -5), Vector2(10, 0), Vector2(-10, 5)])
		add_child(_poly)

func setup(velocity: Vector2, damage: int) -> void:
	vel      = velocity
	dmg      = damage
	rotation = velocity.angle()

func _physics_process(delta: float) -> void:
	position += vel * delta
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
		_play_hit_and_free()
	elif body.is_in_group("wall") or body is TileMapLayer:
		_play_hit_and_free()
