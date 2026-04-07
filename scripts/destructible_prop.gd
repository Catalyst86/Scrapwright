extends StaticBody2D

# ============================================================
# DestructibleProp — Breakable salvage prop
# ============================================================

signal card_dropped(card_data: Dictionary)

@export var prop_type: String = "crate"
@export var base_health: int  = 3

var health: int = 0
var is_broken: bool = false
var salvage_ref: Node = null   # SalvageWindow reference

# Visual rects per type (colour, size)
const PROP_VISUALS = {
	"crate":   {"color": Color(0.55, 0.38, 0.18), "size": Vector2(18, 18)},
	"barrel":  {"color": Color(0.45, 0.45, 0.45), "size": Vector2(14, 20)},
	"rubble":  {"color": Color(0.42, 0.40, 0.38), "size": Vector2(22, 12)},
	"corpse":  {"color": Color(0.30, 0.22, 0.18), "size": Vector2(20, 10)},
	# Junkyard props - standard
	"car_intact":   {"color": Color(0.45, 0.35, 0.30), "size": Vector2(36, 20)},
	"car_crushed":  {"color": Color(0.40, 0.30, 0.25), "size": Vector2(34, 14)},
	"scrap_pile":   {"color": Color(0.50, 0.45, 0.40), "size": Vector2(28, 16)},
	"wood_pile":    {"color": Color(0.55, 0.40, 0.22), "size": Vector2(24, 18)},
	"tire_stack":   {"color": Color(0.15, 0.15, 0.15), "size": Vector2(18, 22)},
	"engine_block": {"color": Color(0.35, 0.35, 0.38), "size": Vector2(20, 16)},
	"oil_drum":     {"color": Color(0.20, 0.25, 0.20), "size": Vector2(14, 20)},
	"junk_heap":    {"color": Color(0.42, 0.38, 0.32), "size": Vector2(30, 18)},
	# Large junkyard props — scale so a car fills ~1/4 visible screen width
	"car_rusty_big":    {"color": Color(0.50, 0.30, 0.25), "size": Vector2(58, 38), "sprite_scale": 0.45},
	"car_crushed_big":  {"color": Color(0.45, 0.32, 0.28), "size": Vector2(54, 28), "sprite_scale": 0.45},
	"tire_pile_large":  {"color": Color(0.18, 0.18, 0.18), "size": Vector2(48, 48), "sprite_scale": 0.40},
	"tire_pile_medium": {"color": Color(0.16, 0.16, 0.16), "size": Vector2(32, 32), "sprite_scale": 0.38},
	"appliance_stack":  {"color": Color(0.55, 0.55, 0.55), "size": Vector2(34, 50), "sprite_scale": 0.40},
	"forklift":         {"color": Color(0.45, 0.40, 0.20), "size": Vector2(44, 44), "sprite_scale": 0.40},
	"junk_heap_large":  {"color": Color(0.48, 0.42, 0.35), "size": Vector2(56, 42), "sprite_scale": 0.38},
	"shopping_cart":    {"color": Color(0.50, 0.50, 0.52), "size": Vector2(22, 22), "sprite_scale": 0.35},
	"fire_barrel":      {"color": Color(0.50, 0.25, 0.10), "size": Vector2(16, 24), "sprite_scale": 0.38},
	"sinkhole":         {"color": Color(0.08, 0.06, 0.04), "size": Vector2(48, 48), "sprite_scale": 0.42},
}

# Map prop types to specific sprite filenames for large junkyard props
const SPRITE_OVERRIDES = {
	"car_rusty_big": "junk_car_rusty_1.png",
	"car_crushed_big": "junk_car_crushed_1.png",
	"tire_pile_large": "junk_tire_pile_large.png",
	"tire_pile_medium": "junk_tire_pile_medium.png",
	"appliance_stack": "junk_appliance_stack.png",
	"forklift": "junk_forklift.png",
	"junk_heap_large": "junk_heap_large_1.png",
	"shopping_cart": "junk_shopping_cart.png",
	"fire_barrel": "junk_fire_barrel.png",
	"sinkhole": "junk_sinkhole.png",
}

var _vis: Node2D  # Sprite2D or ColorRect fallback
var _hp_bar: ColorRect
var _hp_bg: ColorRect
var _shake_tween: Tween = null

const SPRITE_PATH = "res://assets/sprites/environment/"

func _ready() -> void:
	health = base_health
	collision_layer = 1
	collision_mask  = 0
	_build_visual()

func _build_visual() -> void:
	var vis_data = PROP_VISUALS.get(prop_type, {"color": Color(0.5, 0.4, 0.3), "size": Vector2(18, 18)})
	var sz = vis_data.size

	# Try loading actual sprite - check override name first, then default
	var sprite_file = SPRITE_OVERRIDES.get(prop_type, "destructible_" + prop_type + ".png")
	var tex_path = SPRITE_PATH + sprite_file
	if ResourceLoader.exists(tex_path):
		var tex = load(tex_path) as Texture2D
		if tex:
			var spr = Sprite2D.new()
			spr.texture = tex
			var s_scale = vis_data.get("sprite_scale", 0.55)
			spr.scale = Vector2(s_scale, s_scale)
			add_child(spr)
			_vis = spr
	if not _vis:
		var cr = ColorRect.new()
		cr.color    = vis_data.color
		cr.size     = sz
		cr.position = -sz * 0.5
		add_child(cr)
		_vis = cr

	# HP bar background
	_hp_bg = ColorRect.new()
	_hp_bg.color    = Color(0.2, 0.2, 0.2, 0.8)
	_hp_bg.size     = Vector2(sz.x, 3)
	_hp_bg.position = Vector2(-sz.x * 0.5, -sz.y * 0.5 - 5)
	_hp_bg.visible  = false
	add_child(_hp_bg)

	# HP bar fill
	_hp_bar = ColorRect.new()
	_hp_bar.color   = Color(0.2, 0.9, 0.2)
	_hp_bar.size    = Vector2(sz.x, 3)
	_hp_bar.position = _hp_bg.position
	_hp_bar.visible = false
	add_child(_hp_bar)

	# Collision
	var col = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = sz
	col.shape = rect
	add_child(col)

func setup(type: String, hp: int, salvage: Node) -> void:
	prop_type   = type
	base_health = hp
	health      = hp
	salvage_ref = salvage
	# Rebuild visual if already in tree
	if is_inside_tree():
		for child in get_children():
			child.queue_free()
		_build_visual()

func interact(tool_speed: float = 1.0, tool_yield: float = 1.0) -> void:
	if is_broken:
		return

	var dmg = maxi(1, int(tool_speed))
	health -= dmg

	# Show HP bar
	if _hp_bg: _hp_bg.visible = true
	if _hp_bar:
		_hp_bar.visible = true
		var ratio = clampf(float(health) / float(base_health), 0.0, 1.0)
		_hp_bar.size.x = _hp_bg.size.x * ratio

	# Shake
	AudioManager.play("prop_hit", 0.1)
	if _shake_tween and _shake_tween.is_valid():
		_shake_tween.kill()
	var origin = position
	_shake_tween = create_tween()
	_shake_tween.tween_property(self, "position", origin + Vector2(randf_range(-2, 2), randf_range(-2, 2)), 0.04)
	_shake_tween.tween_property(self, "position", origin, 0.04)

	if health <= 0:
		_break(tool_yield)

func _break(tool_yield: float) -> void:
	is_broken = true
	# Break sound based on prop type
	match prop_type:
		"crate", "junk_heap", "junk_heap_large":
			AudioManager.play("crate_break", 0.1)
		"barrel":
			AudioManager.play("barrel_break", 0.1)
		"rubble", "scrap_pile":
			AudioManager.play("rubble_break", 0.1)
		_:
			AudioManager.play("crate_break", 0.1)
	set_collision_layer_value(1, false)

	var drops = CraftingDB.get_material_yield(prop_type, tool_yield)
	for mat in drops:
		var amt = drops[mat]
		if amt > 0:
			GameState.add_material(mat, amt)
			_show_float_text("+%d %s" % [amt, mat.replace("_", " ")])

	# 75% chance to heal 5 HP from scavenging
	if randf() < 0.75 and GameState.player_health < GameState.player_max_health:
		GameState.heal(5)
		_show_food_text()

	# Card drop chance (junkyard only)
	var jy = get_node_or_null("/root/JunkyardState")
	var drop_chance = 0.0
	if jy and jy.is_active:
		drop_chance = 0.20
		if prop_type in ["corpse", "rubble", "scrap_pile", "junk_heap", "junk_heap_large"]:
			drop_chance = 0.33
	if drop_chance > 0 and randf() < drop_chance:
		var card_db = get_node_or_null("/root/CardDB")
		if card_db:
			var card = card_db.roll_card()
			if not card.is_empty():
				card_db.collect_card(card)
				card_dropped.emit(card)

	# Fade out
	var tw = create_tween()
	if _vis:
		tw.tween_property(_vis, "modulate:a", 0.0, 0.28)
	else:
		tw.tween_interval(0.28)
	tw.tween_callback(queue_free)

func _show_food_text() -> void:
	var lbl = Label.new()
	lbl.text = "Food!"
	lbl.add_theme_font_size_override("font_size", 9)
	lbl.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	lbl.add_theme_constant_override("shadow_offset_x", 1)
	lbl.add_theme_constant_override("shadow_offset_y", 1)
	lbl.position = Vector2(-14, -42)
	add_child(lbl)
	var tw = create_tween()
	tw.tween_property(lbl, "position:y", lbl.position.y - 18, 0.7)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, 0.7)
	tw.tween_callback(lbl.queue_free)

func _show_float_text(txt: String) -> void:
	var lbl = Label.new()
	lbl.text = txt
	lbl.add_theme_font_size_override("font_size", 8)
	lbl.modulate = Color(1.0, 0.9, 0.3)
	lbl.position = Vector2(-24, -28)
	add_child(lbl)
	var tw = create_tween()
	tw.tween_property(lbl, "position:y", lbl.position.y - 18, 0.55)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, 0.55)
	tw.tween_callback(lbl.queue_free)
