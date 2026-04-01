extends Node2D

# ============================================================
# Junkyard V2 - Professional-quality pixel-art arena (2880x1620)
# Replaces junkyard.gd + junkyard_builder.gd with a single
# script that builds the level from tile/prop sprites and
# manages all gameplay logic (waves, enemies, HUD, etc.)
#
# Layer Stack (bottom to top):
#   -15  Outer darkness beyond walls
#   -10  Dirt ground (shader noise)
#    -9  Ground detail decals (oil stains, cracks)
#    -8  Grass/moss transition at wall edges
#    -7  Back junk wall layer (dark silhouettes)
#    -6  Main junk wall layer (readable props)
#    -5  Front junk overhang layer
#     0  Y-sorted entities (player, enemies, props w/ shadows)
#     5  Ambient particles (dust motes, smoke, sparks)
#    10  Lighting (CanvasModulate + PointLight2D)
#    20  Post-processing (vignette CanvasLayer)
# ============================================================

enum JYPhase { COMBAT, TRANSITION, GAME_OVER }

@onready var player: CharacterBody2D   = $Player
@onready var ysort_container: Node2D   = $YSortContainer
@onready var enemies_container: Node2D = $EnemiesContainer
@onready var pickups_container: Node2D = $PickupsContainer
@onready var level_up_screen: Control  = $LevelUpLayer/LevelUp
@onready var hud: CanvasLayer          = $HUD

const PauseMenuScript = preload("res://scripts/pause_menu.gd")

const ARENA_W = 2880
const ARENA_H = 1620

var phase: JYPhase = JYPhase.TRANSITION
var last_player_level: int = 1
var _zero_enemies_timer: float = 0.0
var _pause_menu: CanvasLayer = null
var _wave_pause_timer: float = 0.0
var _waiting_for_next_wave: bool = false
var _jy: Node  # JunkyardState autoload reference

# Play area bounds (border junk wall occupies the outer margin)
const PLAY_MARGIN = 500

# ── Prop assets ──────────────────────────────────────────────
const PROP_DIR = "res://assets/sprites/junkyard_v2/props/"
const BORDER_DIR = "res://assets/sprites/junkyard_v2/border/"

# Fixed prop placements (position = where the BASE/feet of the prop sits)
# col = collision rectangle size at the base
# Play area with PLAY_MARGIN=500 runs from ~(500,500) to ~(2380,1120), center ~(1440,810)
const MAPPED_PROPS = [
	{"pos": Vector2(1440, 660),  "sprite": "forklift.png",        "col": Vector2(80, 40),  "hp": 10, "type": "jy_forklift"},
	{"pos": Vector2(1180, 680),  "sprite": "pink_car.png",        "col": Vector2(100, 40), "hp": 8,  "type": "jy_pink_car"},
	{"pos": Vector2(1700, 680),  "sprite": "pink_car.png",        "col": Vector2(100, 40), "hp": 8,  "type": "jy_pink_car"},
	{"pos": Vector2(2050, 720),  "sprite": "pickup_truck.png",    "col": Vector2(100, 40), "hp": 8,  "type": "jy_pickup_truck"},
	{"pos": Vector2(1900, 850),  "sprite": "tire_pile.png",       "col": Vector2(64, 44),  "hp": 8,  "type": "jy_tire_pile"},
	{"pos": Vector2(750, 830),   "sprite": "appliance_stack.png", "col": Vector2(64, 50),  "hp": 10, "type": "jy_appliance_stack"},
	{"pos": Vector2(850, 950),   "sprite": "tire_pile.png",       "col": Vector2(50, 36),  "hp": 6,  "type": "jy_tire_pile"},
	{"pos": Vector2(1750, 1000), "sprite": "fire_barrel.png",     "col": Vector2(24, 20),  "hp": 3,  "type": "jy_fire_barrel"},
	{"pos": Vector2(2100, 800),  "sprite": "shopping_cart.png",   "col": Vector2(40, 24),  "hp": 2,  "type": "jy_shopping_cart"},
	{"pos": Vector2(900, 1050),  "sprite": "barrel_cluster.png",  "col": Vector2(56, 32),  "hp": 5,  "type": "jy_barrel_cluster"},
	{"pos": Vector2(650, 700),   "sprite": "crate.png",           "col": Vector2(36, 28),  "hp": 3,  "type": "jy_crate"},
	{"pos": Vector2(2000, 1020), "sprite": "crate.png",           "col": Vector2(36, 28),  "hp": 3,  "type": "jy_crate"},
	{"pos": Vector2(2200, 900),  "sprite": "barrel_cluster.png",  "col": Vector2(56, 32),  "hp": 5,  "type": "jy_barrel_cluster"},
]

# Ground-level props (rendered UNDER everything, z_index = -9)
const GROUND_PROPS = [
	{"pos": Vector2(1000, 760),  "sprite": "manhole.png"},
	{"pos": Vector2(1900, 950),  "sprite": "manhole.png"},
	{"pos": Vector2(1300, 1000), "sprite": "scrap_pile.png"},
	{"pos": Vector2(750, 650),   "sprite": "scrap_pile.png"},
	{"pos": Vector2(2100, 750),  "sprite": "scrap_pile.png"},
	{"pos": Vector2(1550, 600),  "sprite": "scrap_pile.png"},
]

# Sinkhole — Area2D that damages the player
const SINKHOLE_POS = Vector2(1440, 900)
const SINKHOLE_RADIUS = 38.0

# Small randomly-spawned filler props
const JUNKYARD_SMALL_PROPS = [
	{"type": "oil_drum",  "hp": [2, 4]},
	{"type": "crate",     "hp": [2, 3]},
	{"type": "barrel",    "hp": [2, 3]},
	{"type": "rubble",    "hp": [3, 4]},
]


# ─────────────────────────────────────────────────────────────
# READY
# ─────────────────────────────────────────────────────────────

func _ready() -> void:
	_jy = get_node_or_null("/root/JunkyardState")

	# Build the pixel-art level (professional layer stack)
	_build_outer_darkness()
	_build_floor()
	_build_ground_decals()
	_build_moss_transition()
	_build_border_walls()
	_build_ground_props()
	_spawn_mapped_props()
	_spawn_sinkhole()
	_spawn_fire_particles()
	_spawn_ambient_dust()
	_spawn_small_filler()
	call_deferred("_build_nav_region")
	_build_canvas_modulate()
	_build_vignette()

	# Reparent player INTO YSortContainer so Y-sorting works between player and props
	if player and ysort_container:
		var player_pos = player.global_position
		player.get_parent().remove_child(player)
		ysort_container.add_child(player)
		player.global_position = player_pos

	# Camera on player
	_setup_camera()

	# Wave manager
	WaveManager.register_arena(enemies_container)
	WaveManager.wave_complete.connect(_on_wave_complete)
	GameState.health_changed.connect(_on_health_changed)
	if player:
		player.died.connect(_on_player_died)

	# Pickups container group for chest/drop systems
	if pickups_container and not pickups_container.is_in_group("pickups_container"):
		pickups_container.add_to_group("pickups_container")

	_setup_spawn_points()
	_update_hud()
	AudioManager.play_music("arena_combat")

	# Pause menu
	_pause_menu = CanvasLayer.new()
	_pause_menu.set_script(PauseMenuScript)
	add_child(_pause_menu)

	# Card popup for scrap collection
	var card_popup_scene = load("res://scenes/card_popup.tscn")
	if card_popup_scene:
		var card_popup = card_popup_scene.instantiate()
		add_child(card_popup)
		# Connect card_dropped signal from all existing filler props
		_connect_card_signals(card_popup)

	# Restore perks
	_restore_regen_perk()
	_restore_card_perks()

	# Start first wave after a short delay
	_show_banner("THE JUNKYARD", Color(0.9, 0.6, 0.2), 2.0)
	_waiting_for_next_wave = true
	_wave_pause_timer = 2.5


# ─────────────────────────────────────────────────────────────
# INPUT / PROCESS
# ─────────────────────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if level_up_screen and level_up_screen.visible:
			return
		if _pause_menu:
			if _pause_menu.is_open:
				_pause_menu.close()
			else:
				_pause_menu.open()
			get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if _waiting_for_next_wave:
		_wave_pause_timer -= delta
		if _wave_pause_timer <= 0:
			_waiting_for_next_wave = false
			_start_next_wave()
		return

	if phase == JYPhase.COMBAT:
		_check_level_up()
		# Safety: force-complete stuck waves
		if WaveManager.get_wave_enemy_count() <= 0 and WaveManager.wave_active:
			_zero_enemies_timer += delta
			if _zero_enemies_timer > 3.0:
				_zero_enemies_timer = 0.0
				WaveManager.wave_active = false
				WaveManager.emit_signal("wave_complete", WaveManager.current_wave)
		else:
			_zero_enemies_timer = 0.0
	_update_xp_bar()


# ─────────────────────────────────────────────────────────────
# LEVEL BUILDING — Z=-15: Outer darkness beyond walls
# ─────────────────────────────────────────────────────────────

func _build_outer_darkness() -> void:
	var darkness = ColorRect.new()
	darkness.name = "OuterDarkness"
	darkness.color = Color(0.05, 0.04, 0.03)
	darkness.size = Vector2(ARENA_W + 400, ARENA_H + 400)
	darkness.position = Vector2(-200, -200)
	darkness.z_index = -15
	add_child(darkness)


# ─────────────────────────────────────────────────────────────
# LEVEL BUILDING — Z=-10: Dirt ground (noise shader)
# ─────────────────────────────────────────────────────────────

const GROUND_SHADER_CODE = """
shader_type canvas_item;

void fragment() {
	// Use UV scaled up to create world-space-like coordinates
	vec2 p = UV * vec2(90.0, 50.0);

	// Simple hash noise
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float n1 = fract(sin(dot(i, vec2(127.1, 311.7))) * 43758.5);
	float n2 = fract(sin(dot(i + vec2(1,0), vec2(127.1, 311.7))) * 43758.5);
	float n3 = fract(sin(dot(i + vec2(0,1), vec2(127.1, 311.7))) * 43758.5);
	float n4 = fract(sin(dot(i + vec2(1,1), vec2(127.1, 311.7))) * 43758.5);
	float noise_val = mix(mix(n1, n2, f.x), mix(n3, n4, f.x), f.y);

	// Second octave for detail
	vec2 p2 = UV * vec2(300.0, 170.0);
	vec2 i2 = floor(p2);
	vec2 f2 = fract(p2);
	f2 = f2 * f2 * (3.0 - 2.0 * f2);
	float m1 = fract(sin(dot(i2, vec2(269.5, 183.3))) * 43758.5);
	float m2 = fract(sin(dot(i2 + vec2(1,0), vec2(269.5, 183.3))) * 43758.5);
	float m3 = fract(sin(dot(i2 + vec2(0,1), vec2(269.5, 183.3))) * 43758.5);
	float m4 = fract(sin(dot(i2 + vec2(1,1), vec2(269.5, 183.3))) * 43758.5);
	float detail = mix(mix(m1, m2, f2.x), mix(m3, m4, f2.x), f2.y);

	// Dark sandy brown base colors
	vec3 sand = vec3(0.35, 0.28, 0.18);
	vec3 dirt = vec3(0.22, 0.17, 0.11);
	vec3 mud = vec3(0.12, 0.09, 0.06);

	// Blend based on noise
	vec3 col = mix(dirt, sand, noise_val);
	col = mix(col, mud, step(0.7, noise_val) * 0.6);

	// Subtle detail blending (no visible grain)
	col = mix(col, col * (0.95 + detail * 0.1), 0.3);

	// Hard cut: don't render ground in border zone at all
	vec2 world = UV * vec2(2880.0, 1620.0);
	float margin = 500.0;
	float dx = min(world.x - margin, 2880.0 - margin - world.x);
	float dy = min(world.y - margin, 1620.0 - margin - world.y);
	float dist_to_edge = min(dx, dy);

	// Fully transparent in border zone — dark fill handles it
	if (dist_to_edge < -10.0) {
		COLOR = vec4(0.0, 0.0, 0.0, 0.0);
	} else {
		// Quick fade at the exact border edge (20px transition)
		float alpha = smoothstep(-10.0, 10.0, dist_to_edge);
		COLOR = vec4(col, alpha);
	}
}
"""

func _build_floor() -> void:
	var ground = ColorRect.new()
	ground.name = "DirtGround"
	ground.size = Vector2(ARENA_W, ARENA_H)
	ground.z_index = -10

	var shader = Shader.new()
	shader.code = GROUND_SHADER_CODE
	var mat = ShaderMaterial.new()
	mat.shader = shader
	ground.material = mat

	add_child(ground)


# ─────────────────────────────────────────────────────────────
# LEVEL BUILDING — Z=-9: Ground detail decals (oil stains, cracks)
# ─────────────────────────────────────────────────────────────

func _build_ground_decals() -> void:
	var decal_container = Node2D.new()
	decal_container.name = "GroundDecals"
	decal_container.z_index = -9
	add_child(decal_container)

	# Procedural oil stain decals using draw primitives
	for _i in 18:
		var pos = Vector2(
			randf_range(PLAY_MARGIN + 50, ARENA_W - PLAY_MARGIN - 50),
			randf_range(PLAY_MARGIN + 50, ARENA_H - PLAY_MARGIN - 50)
		)
		var decal = _OilStainDecal.new()
		decal.position = pos
		decal.radius = randf_range(15.0, 45.0)
		decal.stain_color = Color(0.18, 0.15, 0.12, randf_range(0.15, 0.35))
		decal_container.add_child(decal)

	# Scratch/crack lines on the ground
	for _i in 12:
		var pos = Vector2(
			randf_range(PLAY_MARGIN + 30, ARENA_W - PLAY_MARGIN - 30),
			randf_range(PLAY_MARGIN + 30, ARENA_H - PLAY_MARGIN - 30)
		)
		var crack = _CrackDecal.new()
		crack.position = pos
		crack.crack_length = randf_range(20.0, 60.0)
		crack.crack_angle = randf_range(0, TAU)
		decal_container.add_child(crack)


# ─────────────────────────────────────────────────────────────
# LEVEL BUILDING — Z=-8: Grass/moss transition at wall edges
# ─────────────────────────────────────────────────────────────

func _build_moss_transition() -> void:
	var moss_container = Node2D.new()
	moss_container.name = "MossTransition"
	moss_container.z_index = -8
	add_child(moss_container)

	var edge_depth = 100.0
	var m = float(PLAY_MARGIN)

	# Soft moss-green strips along each border inner edge
	var moss_color = Color(0.22, 0.30, 0.18, 0.30)

	# Top edge
	var mt = ColorRect.new()
	mt.color = moss_color
	mt.size = Vector2(ARENA_W - 2 * m + edge_depth, edge_depth)
	mt.position = Vector2(m - edge_depth * 0.5, m - edge_depth * 0.3)
	moss_container.add_child(mt)

	# Bottom edge
	var mb = ColorRect.new()
	mb.color = moss_color
	mb.size = Vector2(ARENA_W - 2 * m + edge_depth, edge_depth)
	mb.position = Vector2(m - edge_depth * 0.5, ARENA_H - m - edge_depth * 0.7)
	moss_container.add_child(mb)

	# Left edge
	var ml = ColorRect.new()
	ml.color = moss_color
	ml.size = Vector2(edge_depth, ARENA_H - 2 * m + edge_depth)
	ml.position = Vector2(m - edge_depth * 0.3, m - edge_depth * 0.5)
	moss_container.add_child(ml)

	# Right edge
	var mr = ColorRect.new()
	mr.color = moss_color
	mr.size = Vector2(edge_depth, ARENA_H - 2 * m + edge_depth)
	mr.position = Vector2(ARENA_W - m - edge_depth * 0.7, m - edge_depth * 0.5)
	moss_container.add_child(mr)

	# Scattered small moss patches for organic feel
	for _i in 30:
		var side = randi() % 4
		var patch_pos: Vector2
		match side:
			0:  # Top
				patch_pos = Vector2(randf_range(m, ARENA_W - m), m + randf_range(-30, 60))
			1:  # Bottom
				patch_pos = Vector2(randf_range(m, ARENA_W - m), ARENA_H - m + randf_range(-60, 30))
			2:  # Left
				patch_pos = Vector2(m + randf_range(-30, 60), randf_range(m, ARENA_H - m))
			3:  # Right
				patch_pos = Vector2(ARENA_W - m + randf_range(-60, 30), randf_range(m, ARENA_H - m))
		var patch = ColorRect.new()
		patch.color = Color(0.20, 0.28, 0.16, randf_range(0.10, 0.25))
		var pw = randf_range(30, 80)
		var ph = randf_range(20, 50)
		patch.size = Vector2(pw, ph)
		patch.position = patch_pos - Vector2(pw * 0.5, ph * 0.5)
		moss_container.add_child(patch)


# ─────────────────────────────────────────────────────────────
# LEVEL BUILDING — Border walls (3-depth-layer junk walls)
# ─────────────────────────────────────────────────────────────

func _build_border_walls() -> void:
	# Dark fill behind border zone
	var fill = Node2D.new()
	fill.name = "BorderFill"
	fill.z_index = -9  # Between ground (-10) and scatter (-7)
	add_child(fill)
	var dark = Color(0.12, 0.10, 0.08)
	var bleed = 80  # Extend into play area to cover the green transition zone
	for rect_data in [
		[Vector2.ZERO, Vector2(ARENA_W, PLAY_MARGIN + bleed)],
		[Vector2(0, ARENA_H - PLAY_MARGIN - bleed), Vector2(ARENA_W, PLAY_MARGIN + bleed)],
		[Vector2.ZERO, Vector2(PLAY_MARGIN + bleed, ARENA_H)],
		[Vector2(ARENA_W - PLAY_MARGIN - bleed, 0), Vector2(PLAY_MARGIN + bleed, ARENA_H)],
	]:
		var cr = ColorRect.new()
		cr.color = dark
		cr.position = rect_data[0]
		cr.size = rect_data[1]
		fill.add_child(cr)

	# Scatter individual junk props densely in border zone
	var scatter_dir = "res://assets/sprites/junkyard_v2/border/scatter/"
	var scatter_textures: Array[Texture2D] = []
	var scatter_names = [
		"junk_car_door.png", "junk_tire_stack.png", "junk_pipe_bundle.png",
		"junk_fridge.png", "junk_oil_drum.png", "junk_metal_sheet.png",
		"junk_engine_block.png", "junk_wheel_rim.png", "junk_washing_machine.png",
		"junk_scrap_pile.png"
	]
	for sname in scatter_names:
		var path = scatter_dir + sname
		if ResourceLoader.exists(path):
			scatter_textures.append(load(path))

	# Only use small scatter sprites — no large border textures
	if scatter_textures.is_empty():
		return

	var scatter_container = Node2D.new()
	scatter_container.name = "BorderScatter"
	scatter_container.z_index = -7
	add_child(scatter_container)

	# Scatter props in border zone with heavy overlap
	var m = float(PLAY_MARGIN)
	var spacing = 22.0  # Dense packing
	var fade_dist = 60.0  # Pixels of fade at inner edge
	var rng = RandomNumberGenerator.new()
	rng.seed = 42  # Consistent layout per session

	# Define border zone rectangles — bleed further into play area for soft fade
	var zones = [
		Rect2(0, 0, ARENA_W, m + fade_dist),
		Rect2(0, ARENA_H - m - fade_dist, ARENA_W, m + fade_dist),
		Rect2(0, m, m + fade_dist, ARENA_H - 2 * m),
		Rect2(ARENA_W - m - fade_dist, m, m + fade_dist, ARENA_H - 2 * m),
	]

	for zone in zones:
		var x = zone.position.x
		while x < zone.position.x + zone.size.x:
			var y = zone.position.y
			while y < zone.position.y + zone.size.y:
				var tex = scatter_textures[rng.randi() % scatter_textures.size()]
				var spr = Sprite2D.new()
				spr.texture = tex
				spr.position = Vector2(
					x + rng.randf_range(-spacing * 0.5, spacing * 0.5),
					y + rng.randf_range(-spacing * 0.5, spacing * 0.5)
				)
				spr.flip_h = rng.randf() > 0.5
				spr.flip_v = rng.randf() > 0.5
				spr.rotation = rng.randf_range(-0.12, 0.12)
				var s = rng.randf_range(0.75, 1.1)  # Tighter scale, no blurry upscale
				spr.scale = Vector2(s, s)

				# Calculate distance from play area edge
				var dx = min(spr.position.x - m, float(ARENA_W) - m - spr.position.x)
				var dy = min(spr.position.y - m, float(ARENA_H) - m - spr.position.y)
				var edge_dist = min(dx, dy)  # Negative = in border, positive = in play area

				# Fade: sprites bleeding into play area become transparent
				var alpha = 1.0
				if edge_dist > 0:
					alpha = clamp(1.0 - edge_dist / fade_dist, 0.0, 1.0)
					# Also thin out — skip some sprites in the fade zone
					if rng.randf() > alpha * 0.7:
						y += spacing
						continue

				# Darken sprites further from play area
				var dist_to_center_x = abs(spr.position.x - ARENA_W * 0.5) / (ARENA_W * 0.5)
				var dist_to_center_y = abs(spr.position.y - ARENA_H * 0.5) / (ARENA_H * 0.5)
				var darkness = max(dist_to_center_x, dist_to_center_y)
				var mod_val = lerp(0.8, 0.3, clamp(darkness * 1.5 - 0.3, 0.0, 1.0))
				spr.modulate = Color(mod_val, mod_val * 0.88, mod_val * 0.78, alpha)

				scatter_container.add_child(spr)
				y += spacing
			x += spacing

	# Collision walls at the inner edge of the border zone
	var wt = 32.0
	var walls = [
		Rect2(0, 0, ARENA_W, m - wt),                  # Top
		Rect2(0, ARENA_H - m + wt, ARENA_W, m - wt),   # Bottom
		Rect2(0, 0, m - wt, ARENA_H),                  # Left
		Rect2(ARENA_W - m + wt, 0, m - wt, ARENA_H),  # Right
	]
	for r in walls:
		if r.size.x <= 0 or r.size.y <= 0:
			continue
		var sb = StaticBody2D.new()
		sb.collision_layer = 1
		sb.collision_mask = 0
		sb.add_to_group("wall")
		var col = CollisionShape2D.new()
		var shape = RectangleShape2D.new()
		shape.size = r.size
		col.shape = shape
		col.position = r.get_center()
		sb.add_child(col)
		add_child(sb)


# ─────────────────────────────────────────────────────────────
# LEVEL BUILDING — Ground-level props (z_index = -9, decals)
# ─────────────────────────────────────────────────────────────

func _build_ground_props() -> void:
	for entry in GROUND_PROPS:
		var path = PROP_DIR + entry.sprite
		if not ResourceLoader.exists(path):
			continue
		var spr = Sprite2D.new()
		spr.texture = load(path)
		spr.position = entry.pos
		spr.z_index = -9  # Ground decal level
		add_child(spr)


# ─────────────────────────────────────────────────────────────
# PROPS — Y-sorted collidable props with shadows
# ─────────────────────────────────────────────────────────────

func _spawn_mapped_props() -> void:
	# CRITICAL: Props go into ysort_container (y_sort_enabled=true).
	# The node's position.y is at the VISUAL BASE (feet) of the object.
	# The sprite is offset upward so the image extends above the sort point.
	for entry in MAPPED_PROPS:
		var sb = StaticBody2D.new()
		sb.collision_layer = 1
		sb.collision_mask = 0
		sb.add_to_group("junkyard_prop")

		var sprite_path = PROP_DIR + entry.sprite
		if ResourceLoader.exists(sprite_path):
			var spr = Sprite2D.new()
			spr.texture = load(sprite_path)
			var sprite_h = spr.texture.get_height()
			# Offset sprite upward so its bottom edge aligns with the node's origin
			spr.offset.y = -sprite_h * 0.5 + entry.col.y * 0.5

			# Ground shadow — subtle dark ellipse beneath the prop
			var shadow_node = Node2D.new()
			shadow_node.z_index = -1
			shadow_node.position = Vector2(2, 4)
			shadow_node.set_script(load("res://scripts/junkyard_shadow.gd") if ResourceLoader.exists("res://scripts/junkyard_shadow.gd") else null)
			if shadow_node.get_script() == null:
				# Inline shadow using a scaled-down copy with heavy blur-like effect
				var shadow = Sprite2D.new()
				shadow.texture = spr.texture
				shadow.modulate = Color(0, 0, 0, 0.15)
				shadow.offset = Vector2(spr.offset.x, spr.offset.y + sprite_h * 0.35)
				shadow.scale = Vector2(0.8, 0.3)  # Flatten into ground shadow
				shadow_node.add_child(shadow)
			sb.add_child(shadow_node)

			sb.add_child(spr)
		else:
			# Fallback colored rectangle
			var cr = ColorRect.new()
			cr.color = Color(0.4, 0.35, 0.3, 0.7)
			cr.size = entry.col
			cr.position = Vector2(-entry.col.x * 0.5, -entry.col.y)
			sb.add_child(cr)

		# Position at the base of the object
		sb.global_position = entry.pos

		# Collision shape centered slightly above base
		var col = CollisionShape2D.new()
		var shape = RectangleShape2D.new()
		shape.size = entry.col
		col.shape = shape
		col.position = Vector2(0, -entry.col.y * 0.3)
		sb.add_child(col)

		sb.set_meta("hp", entry.hp)
		sb.set_meta("max_hp", entry.hp)
		sb.set_meta("prop_type", entry.type)
		sb.add_to_group("destructible")

		ysort_container.add_child(sb)


# ─────────────────────────────────────────────────────────────
# SINKHOLE — Area2D that damages + teleports player
# ─────────────────────────────────────────────────────────────

func _spawn_sinkhole() -> void:
	# Visual: sinkhole sprite on the ground (below Y-sorted layer)
	var sinkhole_sprite_path = PROP_DIR + "sinkhole.png"
	if ResourceLoader.exists(sinkhole_sprite_path):
		var spr = Sprite2D.new()
		spr.texture = load(sinkhole_sprite_path)
		spr.position = SINKHOLE_POS
		spr.z_index = -9  # Ground decal level
		add_child(spr)

	# Damage area
	var area = Area2D.new()
	area.global_position = SINKHOLE_POS
	area.collision_layer = 0
	area.collision_mask = 1  # Detect player
	area.name = "Sinkhole"

	var col = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = SINKHOLE_RADIUS
	col.shape = shape
	area.add_child(col)

	area.monitoring = true
	area.body_entered.connect(func(body):
		if not body.is_in_group("player"): return
		area.set_deferred("monitoring", false)
		var raw_dir = body.global_position - SINKHOLE_POS
		var eject_dir: Vector2 = raw_dir.normalized() if raw_dir.length() > 0.1 else Vector2.UP
		var eject_pos = SINKHOLE_POS + eject_dir * (SINKHOLE_RADIUS + 120)
		body.start_fall_animation(func():
			GameState.take_damage(25)
			_show_banner("FELL IN SINKHOLE!", Color(1, 0.3, 0.2), 1.0)
			body.global_position = eject_pos
			get_tree().create_timer(2.0).timeout.connect(func():
				area.set_deferred("monitoring", true)
			)
		)
	)

	# Sinkhole area goes directly on root (not y-sorted)
	add_child(area)


# ─────────────────────────────────────────────────────────────
# FIRE BARREL — GPUParticles2D for flickering flames + PointLight2D
# ─────────────────────────────────────────────────────────────

func _spawn_fire_particles() -> void:
	# Find the fire barrel position from MAPPED_PROPS
	var fire_pos = Vector2(1750, 970)  # Slightly above the barrel base
	var particles = GPUParticles2D.new()
	particles.position = fire_pos
	particles.amount = 12
	particles.lifetime = 0.8
	particles.z_index = 5
	particles.name = "FireParticles"

	var mat = ParticleProcessMaterial.new()
	mat.direction = Vector3(0, -1, 0)
	mat.spread = 25.0
	mat.initial_velocity_min = 15.0
	mat.initial_velocity_max = 30.0
	mat.gravity = Vector3(0, -10, 0)
	mat.scale_min = 1.5
	mat.scale_max = 3.0
	mat.color = Color(1.0, 0.6, 0.1, 0.9)
	var gradient = Gradient.new()
	gradient.set_color(0, Color(1.0, 0.8, 0.2, 1.0))
	gradient.set_color(1, Color(0.8, 0.2, 0.0, 0.0))
	var gt = GradientTexture1D.new()
	gt.gradient = gradient
	mat.color_ramp = gt
	particles.process_material = mat

	add_child(particles)

	# PointLight2D for fire glow with flickering
	var light = PointLight2D.new()
	light.position = fire_pos
	light.color = Color(1.0, 0.7, 0.3)
	light.energy = 1.5
	light.texture = _create_gradient_light_texture()
	light.texture_scale = 3.0
	light.z_index = 10
	add_child(light)

	# Flickering tween for warm fire glow
	var tween = create_tween().set_loops()
	tween.tween_property(light, "energy", 1.2, 0.3)
	tween.tween_property(light, "energy", 1.8, 0.2)
	tween.tween_property(light, "energy", 1.5, 0.4)

	# Secondary ambient light at center of play area
	var center_light = PointLight2D.new()
	center_light.position = Vector2(ARENA_W / 2.0, ARENA_H / 2.0)
	center_light.color = Color(1.0, 0.9, 0.7)
	center_light.energy = 0.8
	center_light.texture = _create_gradient_light_texture()
	center_light.texture_scale = 8.0
	center_light.z_index = 10
	add_child(center_light)


func _create_gradient_light_texture() -> GradientTexture2D:
	var grad = Gradient.new()
	grad.set_color(0, Color.WHITE)
	grad.set_color(1, Color(1, 1, 1, 0))
	var grad_tex = GradientTexture2D.new()
	grad_tex.gradient = grad
	grad_tex.fill = GradientTexture2D.FILL_RADIAL
	grad_tex.fill_from = Vector2(0.5, 0.5)
	grad_tex.fill_to = Vector2(0.5, 0.0)
	grad_tex.width = 256
	grad_tex.height = 256
	return grad_tex


# ─────────────────────────────────────────────────────────────
# AMBIENT DUST PARTICLES (z_index = 5)
# ─────────────────────────────────────────────────────────────

func _spawn_ambient_dust() -> void:
	var dust = GPUParticles2D.new()
	dust.name = "AmbientDust"
	dust.amount = 40
	dust.lifetime = 8.0
	dust.z_index = 5

	var mat = ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(ARENA_W / 2.0, ARENA_H / 2.0, 0)
	mat.gravity = Vector3(0, -3, 0)  # Slight upward drift
	mat.initial_velocity_min = 3.0
	mat.initial_velocity_max = 8.0
	mat.scale_min = 1.0
	mat.scale_max = 2.0
	mat.color = Color(0.8, 0.7, 0.5, 0.15)  # Faint warm beige
	dust.process_material = mat
	dust.position = Vector2(ARENA_W / 2.0, ARENA_H / 2.0)
	add_child(dust)


# ─────────────────────────────────────────────────────────────
# SMALL FILLER PROPS
# ─────────────────────────────────────────────────────────────

const MAX_SCRAP_PROPS = 30

func _count_alive_props() -> int:
	var count = 0
	for child in ysort_container.get_children():
		if child.has_method("interact") and not child.get("is_broken"):
			count += 1
	return count

func _spawn_small_filler() -> void:
	var prop_scene = load("res://scenes/destructible_prop.tscn")
	if not prop_scene:
		return
	var center = Vector2(ARENA_W / 2.0, ARENA_H / 2.0)
	var alive = _count_alive_props()
	var to_spawn = mini(randi_range(15, 25), MAX_SCRAP_PROPS - alive)
	for _i in to_spawn:
		var entry = JUNKYARD_SMALL_PROPS[randi() % JUNKYARD_SMALL_PROPS.size()]
		var hp = randi_range(entry.hp[0], entry.hp[1])
		var pos = _rand_play_pos(center)
		var prop = prop_scene.instantiate()
		prop.setup(entry.type, hp, null)
		prop.global_position = pos
		if prop.has_signal("card_dropped"):
			var popup = get_node_or_null("CardPopup")
			if popup:
				prop.card_dropped.connect(func(card): popup.show_card(card))
		ysort_container.add_child(prop)

func _respawn_props_between_waves() -> void:
	var prop_scene = load("res://scenes/destructible_prop.tscn")
	if not prop_scene:
		return
	var center = Vector2(ARENA_W / 2.0, ARENA_H / 2.0)
	var alive = _count_alive_props()
	var to_spawn = mini(randi_range(8, 14), MAX_SCRAP_PROPS - alive)
	for _i in to_spawn:
		var entry = JUNKYARD_SMALL_PROPS[randi() % JUNKYARD_SMALL_PROPS.size()]
		var hp = randi_range(entry.hp[0], entry.hp[1])
		var pos = _rand_play_pos(center)
		var prop = prop_scene.instantiate()
		prop.setup(entry.type, hp, null)
		prop.global_position = pos
		if prop.has_signal("card_dropped"):
			var popup = get_node_or_null("CardPopup")
			if popup:
				prop.card_dropped.connect(func(card): popup.show_card(card))
		ysort_container.add_child(prop)

func _connect_card_signals(popup: Node) -> void:
	# Connect all existing destructible props to the card popup
	for child in ysort_container.get_children():
		if child.has_signal("card_dropped"):
			child.card_dropped.connect(func(card): popup.show_card(card))

func _rand_play_pos(avoid: Vector2) -> Vector2:
	var player_pos = player.global_position if is_instance_valid(player) else avoid
	for _attempt in 20:
		var p = Vector2(
			randf_range(PLAY_MARGIN, ARENA_W - PLAY_MARGIN),
			randf_range(PLAY_MARGIN, ARENA_H - PLAY_MARGIN)
		)
		if p.distance_to(player_pos) > 60 and p.distance_to(SINKHOLE_POS) > SINKHOLE_RADIUS + 30:
			return p
	return Vector2(randf_range(PLAY_MARGIN, ARENA_W - PLAY_MARGIN), randf_range(PLAY_MARGIN, ARENA_H - PLAY_MARGIN))


# ─────────────────────────────────────────────────────────────
# NAVIGATION — for enemy pathfinding
# ─────────────────────────────────────────────────────────────

func _build_nav_region() -> void:
	var nav = get_node_or_null("NavigationRegion2D")
	if not nav:
		nav = NavigationRegion2D.new()
		nav.name = "NavigationRegion2D"
		add_child(nav)

	var poly = NavigationPolygon.new()
	var margin = float(PLAY_MARGIN)

	# Main play area outline
	var outline = PackedVector2Array([
		Vector2(margin, margin),
		Vector2(ARENA_W - margin, margin),
		Vector2(ARENA_W - margin, ARENA_H - margin),
		Vector2(margin, ARENA_H - margin),
	])
	poly.add_outline(outline)

	# Carve out obstacles for major props so enemies path around them
	for entry in MAPPED_PROPS:
		var cx = entry.pos.x
		var cy = entry.pos.y - entry.col.y * 0.3
		var hw = entry.col.x * 0.6
		var hh = entry.col.y * 0.6
		var hole = PackedVector2Array([
			Vector2(cx - hw, cy - hh),
			Vector2(cx - hw, cy + hh),
			Vector2(cx + hw, cy + hh),
			Vector2(cx + hw, cy - hh),
		])
		poly.add_outline(hole)

	# Carve out sinkhole
	var steps = 8
	var sinkhole_outline = PackedVector2Array()
	for i in steps:
		var angle = TAU * i / steps
		# Winding must be opposite to the outer outline (clockwise = hole)
		sinkhole_outline.append(SINKHOLE_POS + Vector2(cos(angle), sin(angle)) * (SINKHOLE_RADIUS + 10))
	poly.add_outline(sinkhole_outline)

	poly.make_polygons_from_outlines()
	nav.navigation_polygon = poly
	nav.bake_navigation_polygon()


# ─────────────────────────────────────────────────────────────
# CANVAS MODULATE — warm dark ambient tint (z_index = 10)
# ─────────────────────────────────────────────────────────────

func _build_canvas_modulate() -> void:
	var canvas_mod = CanvasModulate.new()
	canvas_mod.name = "AmbientTint"
	canvas_mod.color = Color(0.85, 0.82, 0.78)
	add_child(canvas_mod)


# ─────────────────────────────────────────────────────────────
# VIGNETTE — post-processing via CanvasLayer (layer 100)
# ─────────────────────────────────────────────────────────────

const VIGNETTE_SHADER_CODE = """
shader_type canvas_item;
void fragment() {
	vec2 uv = SCREEN_UV;
	float dist = distance(uv, vec2(0.5));
	float vig = smoothstep(0.4, 0.85, dist);
	COLOR = vec4(0.0, 0.0, 0.0, vig * 0.5);
}
"""

func _build_vignette() -> void:
	var pp_layer = CanvasLayer.new()
	pp_layer.name = "PostProcessing"
	pp_layer.layer = 100
	add_child(pp_layer)

	var vignette = ColorRect.new()
	vignette.name = "Vignette"
	vignette.anchors_preset = Control.PRESET_FULL_RECT
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var vshader = Shader.new()
	vshader.code = VIGNETTE_SHADER_CODE
	var vmat = ShaderMaterial.new()
	vmat.shader = vshader
	vignette.material = vmat

	pp_layer.add_child(vignette)


# ─────────────────────────────────────────────────────────────
# CAMERA
# ─────────────────────────────────────────────────────────────

func _setup_camera() -> void:
	var cam = Camera2D.new()
	cam.name = "JunkyardCamera"
	cam.zoom = Vector2(2.0, 2.0)
	cam.limit_left = 0
	cam.limit_top = 0
	cam.limit_right = ARENA_W
	cam.limit_bottom = ARENA_H
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 5.0
	cam.enabled = true
	player.add_child(cam)


# ─────────────────────────────────────────────────────────────
# SPAWN POINTS
# ─────────────────────────────────────────────────────────────

func _setup_spawn_points() -> void:
	WaveManager.clear_spawn_points()
	var m = PLAY_MARGIN + 20
	var edge_points = [
		# Top edge
		Vector2(ARENA_W * 0.25, m), Vector2(ARENA_W * 0.5, m),
		Vector2(ARENA_W * 0.75, m),
		# Bottom edge
		Vector2(ARENA_W * 0.25, ARENA_H - m), Vector2(ARENA_W * 0.5, ARENA_H - m),
		Vector2(ARENA_W * 0.75, ARENA_H - m),
		# Left edge
		Vector2(m, ARENA_H * 0.3), Vector2(m, ARENA_H * 0.5),
		Vector2(m, ARENA_H * 0.7),
		# Right edge
		Vector2(ARENA_W - m, ARENA_H * 0.3), Vector2(ARENA_W - m, ARENA_H * 0.5),
		Vector2(ARENA_W - m, ARENA_H * 0.7),
	]
	for pos in edge_points:
		WaveManager.register_spawn_point(pos)


# ─────────────────────────────────────────────────────────────
# WAVE MANAGEMENT
# ─────────────────────────────────────────────────────────────

func _start_next_wave() -> void:
	_jy.junkyard_wave += 1
	var wave_num = _jy.junkyard_wave
	GameState.current_wave = wave_num
	GameState.set_phase(GameState.Phase.ARENA_COMBAT)
	GameState.reset_dig_charges()
	phase = JYPhase.COMBAT

	var wave_data = JunkyardWaves.get_wave(wave_num)

	if wave_data.is_boss:
		_show_banner("WAVE %d - BOSS!" % wave_num, Color(1.0, 0.3, 0.2), 2.0)
	else:
		_show_banner("WAVE %d" % wave_num, Color(0.9, 0.8, 0.4), 1.5)

	WaveManager.start_custom_wave(wave_num, wave_data.enemies, wave_data.spawn_interval)
	_update_hud()

func _on_wave_complete(wave_num: int) -> void:
	if phase == JYPhase.GAME_OVER:
		return
	phase = JYPhase.TRANSITION
	SaveManager.save_game()
	_show_banner("WAVE %d CLEAR!" % wave_num, Color(0.4, 1.0, 0.4), 1.5)
	_respawn_props_between_waves()
	_waiting_for_next_wave = true
	_wave_pause_timer = 2.5
	_update_hud()

func _check_level_up() -> void:
	if GameState.player_level > last_player_level:
		last_player_level = GameState.player_level
		if level_up_screen:
			level_up_screen.show_level_up(GameState.player_level)


# ─────────────────────────────────────────────────────────────
# HEALTH / DEATH
# ─────────────────────────────────────────────────────────────

func _on_health_changed(current: int, max_hp: int) -> void:
	if hud and hud.has_method("update_health"):
		hud.update_health(current, max_hp)

func _on_player_died() -> void:
	if phase == JYPhase.GAME_OVER:
		return
	phase = JYPhase.GAME_OVER
	WaveManager.wave_active = false
	_show_banner("YOU DIED", Color(1, 0.15, 0.15), 0)
	if not is_inside_tree(): return
	await get_tree().create_timer(2.0).timeout
	if not is_inside_tree(): return
	_show_junkyard_game_over()

func _show_junkyard_game_over() -> void:
	get_tree().paused = true

	var scores = SaveManager.load_junkyard_score()
	var best_wave = scores.get("best_wave", 0)
	var _best_scrap = scores.get("best_scrap", 0)
	var jy_wave = _jy.junkyard_wave
	var jy_scrap = _jy.junkyard_scrap
	var jy_kills = _jy.junkyard_kills
	var new_best = jy_wave > best_wave

	# Save score and restore GameState
	_jy.exit_junkyard()

	var layer = CanvasLayer.new()
	layer.layer = 50
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)

	var dim = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.8)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(dim)

	var panel = ColorRect.new()
	panel.color = Color(0.08, 0.06, 0.04, 0.95)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -160; panel.offset_top = -120
	panel.offset_right = 160; panel.offset_bottom = 120
	layer.add_child(panel)

	for d in [
		{"x": -160, "y": -120, "w": 320, "h": 2},
		{"x": -160, "y": 118, "w": 320, "h": 2},
		{"x": -160, "y": -120, "w": 2, "h": 240},
		{"x": 158, "y": -120, "w": 2, "h": 240},
	]:
		var r = ColorRect.new()
		r.color = Color(0.6, 0.35, 0.1)
		r.set_anchors_preset(Control.PRESET_CENTER)
		r.offset_left = d.x; r.offset_top = d.y
		r.offset_right = d.x + d.w; r.offset_bottom = d.y + d.h
		layer.add_child(r)

	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.offset_left = -140; vbox.offset_top = -105
	vbox.offset_right = 140; vbox.offset_bottom = 105
	vbox.add_theme_constant_override("separation", 6)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	layer.add_child(vbox)

	var title = Label.new()
	title.text = "JUNKYARD OVER"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.9, 0.6, 0.2))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	if new_best:
		var best_lbl = Label.new()
		best_lbl.text = "NEW BEST!"
		best_lbl.add_theme_font_size_override("font_size", 16)
		best_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
		best_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(best_lbl)

	var stats = [
		["Waves Survived", str(jy_wave)],
		["Scrap Collected", str(jy_scrap)],
		["Enemies Killed", str(jy_kills)],
		["Best Wave", str(maxi(jy_wave, best_wave))],
	]
	for s in stats:
		var hbox = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 8)
		vbox.add_child(hbox)
		var key_lbl = Label.new()
		key_lbl.text = s[0]
		key_lbl.add_theme_font_size_override("font_size", 12)
		key_lbl.add_theme_color_override("font_color", Color(0.7, 0.65, 0.55))
		key_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(key_lbl)
		var val_lbl = Label.new()
		val_lbl.text = s[1]
		val_lbl.add_theme_font_size_override("font_size", 12)
		val_lbl.add_theme_color_override("font_color", Color(0.95, 0.85, 0.4))
		val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		hbox.add_child(val_lbl)

	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	vbox.add_child(spacer)

	var btn = Button.new()
	btn.text = "RETURN TO HUB"
	btn.add_theme_font_size_override("font_size", 14)
	btn.custom_minimum_size = Vector2(180, 32)
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.15, 0.12, 0.08)
	btn_style.border_color = Color(0.6, 0.35, 0.1)
	btn_style.set_border_width_all(2)
	btn_style.set_corner_radius_all(4)
	btn_style.set_content_margin_all(6)
	btn.add_theme_stylebox_override("normal", btn_style)
	var btn_hover = btn_style.duplicate()
	btn_hover.bg_color = Color(0.25, 0.18, 0.1)
	btn.add_theme_stylebox_override("hover", btn_hover)
	btn.add_theme_color_override("font_color", Color(0.9, 0.7, 0.3))
	btn.pressed.connect(func():
		get_tree().paused = false
		var jy = get_node_or_null("/root/JunkyardState")
		if jy:
			jy.is_active = false
		SaveManager.save_game()
		GameState.set_phase(GameState.Phase.BASE_HUB)
		get_tree().change_scene_to_file("res://scenes/base_hub.tscn")
	)
	vbox.add_child(btn)


# ─────────────────────────────────────────────────────────────
# HUD HELPERS
# ─────────────────────────────────────────────────────────────

func _update_hud() -> void:
	if hud and hud.has_method("update_health"):
		hud.update_health(GameState.player_health, GameState.player_max_health)
	if hud and hud.has_method("update_wave"):
		hud.update_wave(_jy.junkyard_wave, 0)
	if hud and hud.has_method("update_materials"):
		hud.update_materials()

func _update_xp_bar() -> void:
	if hud and hud.has_method("update_xp"):
		hud.update_xp(GameState.player_xp, GameState.xp_to_next_level, GameState.player_level)

func _show_banner(text: String, color: Color, auto_hide_sec: float) -> void:
	if hud and hud.has_method("show_banner"):
		hud.show_banner(text, color, auto_hide_sec)

func _restore_card_perks() -> void:
	if "bug_swarm" in GameState.active_perks and not has_node("BugSwarmTimer"):
		var p = player
		var swarm_tex = load("res://assets/sprites/effects/bug_swarm.png") if ResourceLoader.exists("res://assets/sprites/effects/bug_swarm.png") else null
		if swarm_tex and p and not p.has_node("BugSwarmVFX"):
			var swarm_spr = Sprite2D.new()
			swarm_spr.name = "BugSwarmVFX"
			swarm_spr.texture = swarm_tex
			swarm_spr.scale = Vector2(0.6, 0.6)
			swarm_spr.modulate = Color(1, 1, 1, 0.7)
			swarm_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			swarm_spr.z_index = 5
			p.add_child(swarm_spr)
			var rot_timer = Timer.new()
			rot_timer.name = "BugSwarmRotate"
			rot_timer.wait_time = 0.03
			rot_timer.autostart = true
			rot_timer.timeout.connect(func():
				if is_instance_valid(swarm_spr): swarm_spr.rotation += 0.06
			)
			p.add_child(rot_timer)
		var bug_timer = Timer.new()
		bug_timer.name = "BugSwarmTimer"
		bug_timer.wait_time = 1.0
		bug_timer.autostart = true
		bug_timer.timeout.connect(func():
			if not p or not is_instance_valid(p): return
			for enemy in get_tree().get_nodes_in_group("enemies"):
				if not is_instance_valid(enemy) or enemy.is_dead: continue
				if p.global_position.distance_to(enemy.global_position) < 80.0:
					if enemy.has_method("take_damage"):
						enemy.take_damage(3, p.global_position)
		)
		add_child(bug_timer)

	if "vine_snare" in GameState.active_perks and not has_node("VineSnareTimer"):
		var p2 = player
		var vine_tex = load("res://assets/sprites/effects/vine_snare.png") if ResourceLoader.exists("res://assets/sprites/effects/vine_snare.png") else null
		if vine_tex and p2 and not p2.has_node("VineSnareVFX"):
			var vine_spr = Sprite2D.new()
			vine_spr.name = "VineSnareVFX"
			vine_spr.texture = vine_tex
			vine_spr.scale = Vector2(0.8, 0.8)
			vine_spr.modulate = Color(0.6, 1.0, 0.5, 0.5)
			vine_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			vine_spr.z_index = -1
			p2.add_child(vine_spr)
			var pulse_tw = p2.create_tween().set_loops()
			pulse_tw.tween_property(vine_spr, "scale", Vector2(0.9, 0.9), 0.8).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
			pulse_tw.tween_property(vine_spr, "scale", Vector2(0.7, 0.7), 0.8).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
		var vine_timer = Timer.new()
		vine_timer.name = "VineSnareTimer"
		vine_timer.wait_time = 0.5
		vine_timer.autostart = true
		vine_timer.timeout.connect(func():
			if not p2 or not is_instance_valid(p2): return
			for enemy in get_tree().get_nodes_in_group("enemies"):
				if not is_instance_valid(enemy) or enemy.is_dead: continue
				if p2.global_position.distance_to(enemy.global_position) < 100.0:
					if "speed" in enemy:
						if not enemy.has_meta("vine_original_speed"):
							enemy.set_meta("vine_original_speed", enemy.speed)
						enemy.speed = enemy.get_meta("vine_original_speed") * 0.6
				else:
					if "speed" in enemy and enemy.has_meta("vine_original_speed"):
						enemy.speed = enemy.get_meta("vine_original_speed")
						enemy.remove_meta("vine_original_speed")
		)
		add_child(vine_timer)

func _restore_regen_perk() -> void:
	if GameState.perk_regen_active:
		var timer = Timer.new()
		timer.wait_time = 10.0
		timer.autostart = true
		timer.timeout.connect(func():
			if not is_inside_tree(): return
			if GameState.player_health > 0:
				GameState.heal(2)
		)
		add_child(timer)


# ─────────────────────────────────────────────────────────────
# INNER CLASSES — Procedural ground decals
# ─────────────────────────────────────────────────────────────

class _OilStainDecal extends Node2D:
	var radius: float = 30.0
	var stain_color: Color = Color(0.18, 0.15, 0.12, 0.25)

	func _draw() -> void:
		# Irregular oil stain using overlapping ellipses
		for _i in 3:
			var offset = Vector2(randf_range(-radius * 0.3, radius * 0.3), randf_range(-radius * 0.3, radius * 0.3))
			var r = radius * randf_range(0.5, 1.0)
			draw_circle(offset, r, stain_color)


class _CrackDecal extends Node2D:
	var crack_length: float = 40.0
	var crack_angle: float = 0.0

	func _draw() -> void:
		var crack_color = Color(0.15, 0.12, 0.10, 0.3)
		var dir = Vector2(cos(crack_angle), sin(crack_angle))
		var start = -dir * crack_length * 0.5
		var end_pt = dir * crack_length * 0.5
		draw_line(start, end_pt, crack_color, 1.5)
		# Small branch
		var mid = start.lerp(end_pt, randf_range(0.3, 0.7))
		var branch_dir = dir.rotated(randf_range(0.5, 1.2) * sign(randf() - 0.5))
		draw_line(mid, mid + branch_dir * crack_length * 0.3, crack_color, 1.0)
