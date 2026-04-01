extends Area2D

# ============================================================
# MaterialPickup — Dropped by enemies, collected by player
# ============================================================

@export var material_type: String = "iron_scrap"
@export var amount: int = 1

var collected: bool    = false
var scatter_vel: Vector2 = Vector2.ZERO
var player_ref: Node   = null
var life: float        = 18.0

const MAT_COLORS = {
	"iron_scrap": Color(0.55, 0.7, 0.85),
	"timber":     Color(0.6, 0.4, 0.18),
	"fuel":       Color(0.95, 0.75, 0.1),
	"organic":    Color(0.25, 0.75, 0.2),
	"stone":      Color(0.55, 0.52, 0.50),
	"blueprint":  Color(0.3, 0.5, 0.95),
}

var _dot: ColorRect
var _lbl: Label

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	set_deferred("monitoring", true)
	set_deferred("monitorable", false)

	# Scatter
	var angle    = randf() * TAU
	scatter_vel  = Vector2(cos(angle), sin(angle)) * randf_range(18, 40)

	# Visual dot
	var color = MAT_COLORS.get(material_type, Color.WHITE)
	_dot = ColorRect.new()
	_dot.size     = Vector2(6, 6)
	_dot.position = Vector2(-3, -3)
	_dot.color    = color
	add_child(_dot)

	# Short label
	_lbl = Label.new()
	_lbl.text = material_type.replace("_scrap","").replace("_","").left(2).to_upper()
	_lbl.add_theme_font_size_override("font_size", 6)
	_lbl.modulate = color
	_lbl.position = Vector2(-4, -14)
	add_child(_lbl)

	player_ref = get_tree().get_first_node_in_group("player")

func _process(delta: float) -> void:
	if collected: return

	# Scatter decelerate
	if scatter_vel.length() > 0.5:
		scatter_vel   = scatter_vel.move_toward(Vector2.ZERO, 90.0 * delta)
		global_position += scatter_vel * delta

	# Magnet — base from bag_level or player meta, enhanced by pickup_magnet upgrade
	if player_ref and is_instance_valid(player_ref):
		var magnet_level = GameState.permanent.get("pickup_magnet_level", 0)
		var has_magnet = GameState.permanent.get("bag_level", 0) >= 5 or magnet_level > 0
		if not has_magnet and player_ref.has_meta("has_magnet"):
			has_magnet = true
		if has_magnet:
			var base_range = 80.0
			var magnet_range = base_range * (1.0 + magnet_level * 0.15)
			var dist = global_position.distance_to(player_ref.global_position)
			if dist < magnet_range:
				var dir = (player_ref.global_position - global_position).normalized()
				global_position += dir * 130.0 * delta

	# Lifetime
	life -= delta
	if life < 4.0:
		modulate.a = life / 4.0
	if life <= 0:
		queue_free()

func _on_body_entered(body: Node) -> void:
	if collected: return
	if body.is_in_group("player"):
		_collect()

func _collect() -> void:
	collected = true
	GameState.add_material(material_type, amount)

	# Float text
	var popup = Label.new()
	popup.text = "+%d %s" % [amount, material_type.replace("_", " ")]
	popup.add_theme_font_size_override("font_size", 7)
	popup.modulate = MAT_COLORS.get(material_type, Color.WHITE)
	popup.global_position = global_position + Vector2(-18, -12)
	var pickup_parent = get_parent()
	if not pickup_parent: return
	pickup_parent.add_child(popup)
	var tw = get_tree().create_tween()
	tw.tween_property(popup, "position:y", popup.position.y - 16, 0.55)
	tw.parallel().tween_property(popup, "modulate:a", 0.0, 0.55)
	tw.tween_callback(popup.queue_free)

	# Organic scrap has 75% chance to heal 5 HP
	if material_type == "organic" and randf() < 0.75:
		if GameState.player_health < GameState.player_max_health:
			GameState.heal(5)
			var food_popup = Label.new()
			food_popup.text = "Food! +5 HP"
			food_popup.add_theme_font_size_override("font_size", 8)
			food_popup.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
			food_popup.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
			food_popup.add_theme_constant_override("shadow_offset_x", 1)
			food_popup.add_theme_constant_override("shadow_offset_y", 1)
			food_popup.global_position = global_position + Vector2(-22, -24)
			pickup_parent.add_child(food_popup)
			var tw2 = get_tree().create_tween()
			tw2.tween_property(food_popup, "position:y", food_popup.position.y - 20, 0.7)
			tw2.parallel().tween_property(food_popup, "modulate:a", 0.0, 0.7)
			tw2.tween_callback(food_popup.queue_free)

	queue_free()
