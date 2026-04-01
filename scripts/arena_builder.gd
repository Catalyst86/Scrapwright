extends Node2D

# ============================================================
# ArenaBuilder — Rich procedural cave arena with theme support.
# All visuals use _draw() with no shaders or external assets.
# Call build() immediately after add_child(builder).
# ============================================================

const AW = 1280
const AH = 720
const WT = 16   # wall thickness in pixels

var theme: Dictionary = {}

# Torch positions along walls (used by multiple layers)
const TORCH_POSITIONS: Array = [
	# Top wall torches
	{"pos": Vector2(160, 8), "wall": "top"},
	{"pos": Vector2(427, 8), "wall": "top"},
	{"pos": Vector2(640, 8), "wall": "top"},
	{"pos": Vector2(853, 8), "wall": "top"},
	{"pos": Vector2(1120, 8), "wall": "top"},
	# Bottom wall torches
	{"pos": Vector2(160, 712), "wall": "bottom"},
	{"pos": Vector2(427, 712), "wall": "bottom"},
	{"pos": Vector2(640, 712), "wall": "bottom"},
	{"pos": Vector2(853, 712), "wall": "bottom"},
	{"pos": Vector2(1120, 712), "wall": "bottom"},
	# Left wall torches
	{"pos": Vector2(8, 180), "wall": "left"},
	{"pos": Vector2(8, 360), "wall": "left"},
	{"pos": Vector2(8, 540), "wall": "left"},
	# Right wall torches
	{"pos": Vector2(1272, 180), "wall": "right"},
	{"pos": Vector2(1272, 360), "wall": "right"},
	{"pos": Vector2(1272, 540), "wall": "right"},
]

func build(stage_theme: Dictionary = {}) -> void:
	theme = stage_theme if not stage_theme.is_empty() else StageData.THEMES[0]
	_build_outer_bg()
	_build_floor()
	_build_floor_details()
	_build_puddles()
	_build_walls()
	_build_wall_decorations()
	_build_torch_glow()
	_build_vignette()
	_build_particles()
	call_deferred("_build_nav_region")

# ── Build steps ──────────────────────────────────────────────

func _build_outer_bg() -> void:
	var node = _OuterCaveBG.new()
	node.theme = theme
	node.z_index = -15
	get_parent().call_deferred("add_child", node)

func _build_floor() -> void:
	var node = _CaveFloor.new()
	node.theme = theme
	node.z_index = -10
	get_parent().call_deferred("add_child", node)

func _build_floor_details() -> void:
	var node = _FloorDetails.new()
	node.theme = theme
	node.z_index = -9
	get_parent().call_deferred("add_child", node)

func _build_puddles() -> void:
	var node = _Puddles.new()
	node.theme = theme
	node.z_index = -8
	get_parent().call_deferred("add_child", node)

func _build_walls() -> void:
	# Physics walls
	var wall_rects = [
		Rect2(0,       0,       AW, WT),
		Rect2(0,       AH - WT, AW, WT),
		Rect2(0,       0,       WT, AH),
		Rect2(AW - WT, 0,       WT, AH),
	]
	for r in wall_rects:
		var sb = StaticBody2D.new()
		sb.collision_layer = 1
		sb.collision_mask  = 0
		sb.add_to_group("wall")
		var col   = CollisionShape2D.new()
		var shape = RectangleShape2D.new()
		shape.size   = r.size
		col.shape    = shape
		col.position = r.get_center()
		sb.add_child(col)
		get_parent().call_deferred("add_child", sb)

	# Visual wall layer
	var vis = _WallVisuals.new()
	vis.theme = theme
	vis.z_index = -5
	get_parent().call_deferred("add_child", vis)

func _build_wall_decorations() -> void:
	var node = _WallDecorations.new()
	node.theme = theme
	node.z_index = -4
	get_parent().call_deferred("add_child", node)

func _build_torch_glow() -> void:
	var node = _TorchGlow.new()
	node.theme = theme
	node.z_index = -3
	get_parent().call_deferred("add_child", node)

func _build_vignette() -> void:
	var node = _Vignette.new()
	node.z_index = -2
	get_parent().call_deferred("add_child", node)

func _build_particles() -> void:
	var node = _AmbientParticles.new()
	node.theme = theme
	node.z_index = 5
	get_parent().call_deferred("add_child", node)

func _build_nav_region() -> void:
	var nav = get_parent().get_node_or_null("NavigationRegion2D")
	if not nav:
		nav      = NavigationRegion2D.new()
		nav.name = "NavigationRegion2D"
		get_parent().add_child(nav)

	var poly    = NavigationPolygon.new()
	var margin  = float(WT) + 6.0
	var outline = PackedVector2Array([
		Vector2(margin,      margin),
		Vector2(AW - margin, margin),
		Vector2(AW - margin, AH - margin),
		Vector2(margin,      AH - margin),
	])
	poly.add_outline(outline)
	# Use the modern baking API instead of deprecated make_polygons_from_outlines()
	var source_geo = NavigationMeshSourceGeometryData2D.new()
	NavigationServer2D.parse_source_geometry_data(poly, source_geo, nav)
	NavigationServer2D.bake_from_source_geometry_data(poly, source_geo)
	nav.navigation_polygon = poly


# ══════════════════════════════════════════════════════════════
# INNER CLASSES — each handles one visual layer via _draw()
# ══════════════════════════════════════════════════════════════


# ── 1. OUTER CAVE BACKGROUND ────────────────────────────────
# Deep cave darkness outside the arena with rocky texture

class _OuterCaveBG extends Node2D:
	var theme: Dictionary = {}

	func _ready() -> void:
		queue_redraw()

	func _draw() -> void:
		var outer_bg = theme.get("outer_bg", Color(0.02, 0.015, 0.01))
		var extent = 800.0
		# Very deep darkness
		draw_rect(Rect2(-extent, -extent, AW + extent * 2, AH + extent * 2), outer_bg)

		# Rough rocky texture in the outer dark area
		var rng = RandomNumberGenerator.new()
		rng.seed = 98765
		for _i in 300:
			var x = rng.randf_range(-extent, AW + extent)
			var y = rng.randf_range(-extent, AH + extent)
			# Skip anything inside arena
			if x > -10 and x < AW + 10 and y > -10 and y < AH + 10:
				continue
			var r = rng.randf_range(2, 12)
			var v = rng.randf_range(0.03, 0.07)
			draw_circle(Vector2(x, y), r, Color(v, v * 0.8, v * 0.6, 0.5))

		# Gradient fade from arena edges into darkness (multiple bands)
		var bands = 20
		var fade_depth = 120.0
		for i in bands:
			var t = float(i) / float(bands)
			var alpha = (1.0 - t) * 0.6
			var col = Color(outer_bg.r * 2.0, outer_bg.g * 2.0, outer_bg.b * 2.0, alpha)
			var thick = fade_depth / float(bands)
			# Top
			draw_rect(Rect2(-t * fade_depth, -t * fade_depth, AW + t * fade_depth * 2, thick), col)
			# Bottom
			draw_rect(Rect2(-t * fade_depth, AH + t * fade_depth - thick, AW + t * fade_depth * 2, thick), col)
			# Left
			draw_rect(Rect2(-t * fade_depth, 0, thick, AH), col)
			# Right
			draw_rect(Rect2(AW + t * fade_depth - thick, 0, thick, AH), col)

		# Stalactite silhouettes along top outer edge
		for _i in 30:
			var sx = rng.randf_range(0, AW)
			var sy = rng.randf_range(-80, -5)
			var sw = rng.randf_range(3, 10)
			var sh = rng.randf_range(15, 60)
			var points = PackedVector2Array([
				Vector2(sx - sw/2, sy),
				Vector2(sx + sw/2, sy),
				Vector2(sx + rng.randf_range(-2, 2), sy + sh),
			])
			draw_colored_polygon(points, Color(outer_bg.r + 0.01, outer_bg.g + 0.005, outer_bg.b + 0.005, 0.8))


# ── 2. CAVE FLOOR ───────────────────────────────────────────
# Multi-layer stone floor with color variation, worn paths, stains

class _CaveFloor extends Node2D:
	var theme: Dictionary = {}

	func _ready() -> void:
		queue_redraw()

	func _draw() -> void:
		var rng = RandomNumberGenerator.new()
		rng.seed = 42424

		var floor_base = theme.get("floor_base", Color(0.18, 0.14, 0.10))
		var floor_alt = theme.get("floor_alt", Color(0.20, 0.16, 0.12))
		var mortar_col = theme.get("mortar", Color(0.10, 0.07, 0.05))
		var detail_type = theme.get("detail_type", "steampunk")

		# Base floor color
		draw_rect(Rect2(0, 0, AW, AH), floor_base)

		match detail_type:
			"fungal":
				_draw_fungal_floor(rng, floor_base, floor_alt, mortar_col)
			"molten":
				_draw_molten_floor(rng, floor_base, floor_alt, mortar_col)
			"frozen":
				_draw_frozen_floor(rng, floor_base, floor_alt, mortar_col)
			"clockwork":
				_draw_clockwork_floor(rng, floor_base, floor_alt, mortar_col)
			"abyss":
				_draw_abyss_floor(rng, floor_base, floor_alt, mortar_col)
			_:
				_draw_steampunk_floor(rng, floor_base, floor_alt, mortar_col)

	func _draw_steampunk_floor(rng: RandomNumberGenerator, _floor_base: Color, floor_alt: Color, mortar_col: Color) -> void:
		# === Square stone slab grid (industrial, rigid) ===
		var slab_cols = 12
		var slab_rows = 7
		var base_sw: float = AW / float(slab_cols)
		var base_sh: float = AH / float(slab_rows)

		for cx in slab_cols:
			for cy in slab_rows:
				var sx = cx * base_sw + rng.randf_range(-2, 2)
				var sy = cy * base_sh + rng.randf_range(-2, 2)
				var sw = base_sw + rng.randf_range(-4, 4)
				var sh = base_sh + rng.randf_range(-4, 4)
				var hue_shift = rng.randf_range(-0.04, 0.04)
				var brightness = rng.randf_range(-0.03, 0.03)
				var col = Color(
					floor_alt.r + hue_shift + brightness,
					floor_alt.g + hue_shift * 0.7 + brightness,
					floor_alt.b + hue_shift * 0.4 + brightness)
				var inset = 1.5
				draw_rect(Rect2(sx + inset, sy + inset, sw - inset * 2, sh - inset * 2), col)
				var hi = Color(col.r + 0.04, col.g + 0.04, col.b + 0.03, 0.6)
				draw_line(Vector2(sx + inset, sy + inset), Vector2(sx + sw - inset, sy + inset), hi, 1.0)
				draw_line(Vector2(sx + inset, sy + inset), Vector2(sx + inset, sy + sh - inset), hi, 1.0)
				var sh_col = Color(col.r - 0.04, col.g - 0.04, col.b - 0.03, 0.6)
				draw_line(Vector2(sx + inset, sy + sh - inset), Vector2(sx + sw - inset, sy + sh - inset), sh_col, 1.0)
				draw_line(Vector2(sx + sw - inset, sy + inset), Vector2(sx + sw - inset, sy + sh - inset), sh_col, 1.0)
		var mortar = Color(mortar_col.r, mortar_col.g, mortar_col.b, 0.7)
		for cx in range(1, slab_cols):
			var lx = cx * base_sw + rng.randf_range(-1, 1)
			draw_line(Vector2(lx, WT), Vector2(lx, AH - WT), mortar, 2.0)
		for cy in range(1, slab_rows):
			var ly = cy * base_sh + rng.randf_range(-1, 1)
			draw_line(Vector2(WT, ly), Vector2(AW - WT, ly), mortar, 2.0)
		_draw_worn_paths(rng, floor_alt)

	func _draw_fungal_floor(rng: RandomNumberGenerator, _floor_base: Color, floor_alt: Color, mortar_col: Color) -> void:
		# === Organic hex-like cells with mycelium network (no rigid grid) ===

		# Scatter irregular organic cell centers (Voronoi-like)
		var cell_centers: Array = []
		var cell_colors: Array = []
		for _i in 65:
			var cx = rng.randf_range(10, AW - 10)
			var cy = rng.randf_range(10, AH - 10)
			cell_centers.append(Vector2(cx, cy))
			var hue = rng.randf_range(-0.03, 0.03)
			var bri = rng.randf_range(-0.02, 0.02)
			cell_colors.append(Color(
				floor_alt.r + hue + bri,
				floor_alt.g + hue * 0.5 + bri + rng.randf_range(0, 0.02),
				floor_alt.b + hue * 0.3 + bri))

		# Draw organic circular cells (overlapping for natural look)
		for i in cell_centers.size():
			var center = cell_centers[i]
			var col = cell_colors[i]
			var radius = rng.randf_range(35, 65)
			# Outer ring (darker border — like cell membrane)
			draw_circle(center, radius + 3, Color(mortar_col.r, mortar_col.g + 0.02, mortar_col.b, 0.5))
			# Cell body
			draw_circle(center, radius, col)
			# Inner highlight (bioluminescent center glow)
			var glow = Color(col.r + 0.03, col.g + 0.06, col.b + 0.02, 0.4)
			draw_circle(center, radius * 0.5, glow)

		# === Mycelium network lines (branching white threads between cells) ===
		var myc_col = Color(floor_alt.r + 0.08, floor_alt.g + 0.12, floor_alt.b + 0.05, 0.25)
		for i in cell_centers.size():
			# Connect to 2-3 nearest neighbors
			var from = cell_centers[i]
			var connections = 0
			for j in cell_centers.size():
				if i == j: continue
				var to = cell_centers[j]
				var dist = from.distance_to(to)
				if dist < 120 and connections < 3:
					# Wavy line (3 segments with slight offset)
					var mid1 = from.lerp(to, 0.33) + Vector2(rng.randf_range(-8, 8), rng.randf_range(-8, 8))
					var mid2 = from.lerp(to, 0.66) + Vector2(rng.randf_range(-8, 8), rng.randf_range(-8, 8))
					draw_line(from, mid1, myc_col, 1.5)
					draw_line(mid1, mid2, myc_col, 1.5)
					draw_line(mid2, to, myc_col, 1.5)
					connections += 1
					# Small nodes at branch points
					draw_circle(mid1, 2.5, Color(myc_col.r, myc_col.g, myc_col.b, 0.35))

		# === Bioluminescent pools (replace worn paths) ===
		var glow_col = Color(0.1, 0.4, 0.25, 0.15)
		for _i in 20:
			var px = rng.randf_range(40, AW - 40)
			var py = rng.randf_range(40, AH - 40)
			var pr = rng.randf_range(15, 40)
			draw_circle(Vector2(px, py), pr, glow_col)
			draw_circle(Vector2(px, py), pr * 0.5, Color(glow_col.r, glow_col.g + 0.1, glow_col.b, 0.1))

	func _draw_molten_floor(rng: RandomNumberGenerator, _floor_base: Color, floor_alt: Color, _mortar_col: Color) -> void:
		# === Cracked tectonic plates with lava veins (no regular grid) ===

		# Irregular polygonal plates (larger, fewer, cracked)
		var plate_centers: Array = []
		for _i in 30:
			plate_centers.append(Vector2(
				rng.randf_range(20, AW - 20),
				rng.randf_range(20, AH - 20)))

		# Draw each plate as a large rough circle with heat variation
		for i in plate_centers.size():
			var center = plate_centers[i]
			var radius = rng.randf_range(45, 80)
			var hue = rng.randf_range(-0.03, 0.03)
			var col = Color(
				floor_alt.r + hue + rng.randf_range(-0.02, 0.02),
				floor_alt.g + hue * 0.5,
				floor_alt.b + hue * 0.3)
			# Draw rough polygon (8-12 sided)
			var sides = rng.randi_range(7, 11)
			var points = PackedVector2Array()
			for s in sides:
				var angle = TAU * s / float(sides) + rng.randf_range(-0.15, 0.15)
				var r = radius + rng.randf_range(-12, 12)
				points.append(center + Vector2(cos(angle), sin(angle)) * r)
			draw_colored_polygon(points, col)
			# Subtle heat glow at center
			draw_circle(center, radius * 0.3, Color(col.r + 0.04, col.g + 0.02, col.b, 0.3))

		# === Lava veins between plates (bright orange cracks) ===
		var lava_col = Color(0.9, 0.35, 0.05, 0.6)
		var lava_glow = Color(1.0, 0.5, 0.1, 0.2)
		for i in plate_centers.size():
			var from = plate_centers[i]
			for j in range(i + 1, plate_centers.size()):
				var to = plate_centers[j]
				if from.distance_to(to) < 130:
					# Glow halo first (wider, softer)
					var mid = from.lerp(to, 0.5) + Vector2(rng.randf_range(-10, 10), rng.randf_range(-10, 10))
					draw_line(from, mid, lava_glow, 6.0)
					draw_line(mid, to, lava_glow, 6.0)
					# Bright crack on top
					draw_line(from, mid, lava_col, 2.0)
					draw_line(mid, to, lava_col, 2.0)
					# Bright core
					draw_line(from, mid, Color(1.0, 0.7, 0.2, 0.4), 1.0)

		# === Scattered ember dots and heat shimmer ===
		for _i in 40:
			var px = rng.randf_range(30, AW - 30)
			var py = rng.randf_range(30, AH - 30)
			var ember_r = rng.randf_range(1.5, 4.0)
			draw_circle(Vector2(px, py), ember_r, Color(1.0, 0.5 + rng.randf_range(0, 0.3), 0.1, 0.3))

	func _draw_worn_paths(rng: RandomNumberGenerator, floor_alt: Color) -> void:
		var worn_col = Color(floor_alt.r + 0.02, floor_alt.g + 0.02, floor_alt.b + 0.03)
		var center_y = AH / 2.0
		for _i in 80:
			var px = rng.randf_range(WT + 20, AW - WT - 20)
			var py = center_y + rng.randf_range(-40, 40)
			var pr = rng.randf_range(8, 25)
			draw_circle(Vector2(px, py), pr, Color(worn_col.r, worn_col.g, worn_col.b, 0.12))
		var center_x = AW / 2.0
		for _i in 40:
			var px = center_x + rng.randf_range(-30, 30)
			var py = rng.randf_range(WT + 20, AH - WT - 20)
			var pr = rng.randf_range(6, 18)
			draw_circle(Vector2(px, py), pr, Color(worn_col.r, worn_col.g, worn_col.b, 0.10))

	func _draw_frozen_floor(rng: RandomNumberGenerator, _floor_base: Color, floor_alt: Color, _mortar_col: Color) -> void:
		# === Hexagonal ice crystal pattern — interlocking hexagons with frost borders ===
		var hex_size = 38.0  # radius of each hexagon
		var hex_h = hex_size * 2.0
		var hex_w = sqrt(3.0) * hex_size
		var frost_border = Color(0.55, 0.70, 0.85, 0.5)
		var ice_crack_col = Color(0.40, 0.55, 0.70, 0.35)

		var col_count = int(AW / hex_w) + 2
		var row_count = int(AH / (hex_h * 0.75)) + 2

		for row in row_count:
			for col in col_count:
				var cx = col * hex_w + (hex_w * 0.5 if row % 2 == 1 else 0.0) - hex_w * 0.5
				var cy = row * hex_h * 0.75 - hex_size * 0.5
				if cx < -hex_size or cx > AW + hex_size or cy < -hex_size or cy > AH + hex_size:
					continue

				# Build hex polygon
				var pts = PackedVector2Array()
				for i in 6:
					var angle = TAU * i / 6.0 - PI / 6.0
					pts.append(Vector2(cx + cos(angle) * hex_size, cy + sin(angle) * hex_size))

				# Fill with subtle color variation (icy blue tones)
				var hue_shift = rng.randf_range(-0.03, 0.03)
				var bri = rng.randf_range(-0.02, 0.02)
				var col_fill = Color(
					floor_alt.r + hue_shift + bri,
					floor_alt.g + hue_shift * 0.5 + bri + rng.randf_range(0.0, 0.02),
					floor_alt.b + hue_shift * 0.3 + bri + rng.randf_range(0.0, 0.03))
				draw_colored_polygon(pts, col_fill)

				# Draw frost-white hex border
				for i in 6:
					var p1 = pts[i]
					var p2 = pts[(i + 1) % 6]
					draw_line(p1, p2, frost_border, 1.5)

				# Occasional ice crack lines inside hex
				if rng.randf() < 0.35:
					var crack_start = Vector2(cx, cy)
					var crack_angle = rng.randf_range(0, TAU)
					var crack_len = rng.randf_range(8, hex_size * 0.7)
					var crack_end = crack_start + Vector2(cos(crack_angle), sin(crack_angle)) * crack_len
					draw_line(crack_start, crack_end, ice_crack_col, 1.0)
					# Fork
					if rng.randf() < 0.5:
						var fork_angle = crack_angle + rng.randf_range(-0.8, 0.8)
						var fork_len = rng.randf_range(4, 10)
						var fork_end = crack_end + Vector2(cos(fork_angle), sin(fork_angle)) * fork_len
						draw_line(crack_end, fork_end, ice_crack_col, 1.0)

		# Specular highlight streaks across the ice
		for _i in 15:
			var sx = rng.randf_range(WT + 20, AW - WT - 20)
			var sy = rng.randf_range(WT + 20, AH - WT - 20)
			var sl = rng.randf_range(20, 60)
			var sa = rng.randf_range(-0.3, 0.3)
			draw_line(Vector2(sx, sy), Vector2(sx + cos(sa) * sl, sy + sin(sa) * sl),
					  Color(0.7, 0.85, 1.0, 0.08), 2.0)

	func _draw_clockwork_floor(rng: RandomNumberGenerator, _floor_base: Color, floor_alt: Color, mortar_col: Color) -> void:
		# === Metal plate pattern — rectangular plates with bolts and seam lines ===
		var plate_cols = 8
		var plate_rows = 5
		var base_pw: float = AW / float(plate_cols)
		var base_ph: float = AH / float(plate_rows)
		var seam_col = Color(mortar_col.r * 0.6, mortar_col.g * 0.6, mortar_col.b * 0.5, 0.8)
		var bolt_dark = Color(0.06, 0.05, 0.04)
		var bolt_light = Color(0.30, 0.28, 0.22)

		for cx in plate_cols:
			for cy in plate_rows:
				var px = cx * base_pw
				var py = cy * base_ph
				var pw = base_pw
				var ph = base_ph

				# Plate fill with metallic variation
				var metal_v = rng.randf_range(-0.03, 0.03)
				var col = Color(
					floor_alt.r + metal_v,
					floor_alt.g + metal_v * 0.9,
					floor_alt.b + metal_v * 0.8)
				var inset = 2.0
				draw_rect(Rect2(px + inset, py + inset, pw - inset * 2, ph - inset * 2), col)

				# Top highlight edge (metallic sheen)
				var hi = Color(col.r + 0.06, col.g + 0.06, col.b + 0.05, 0.5)
				draw_line(Vector2(px + inset, py + inset), Vector2(px + pw - inset, py + inset), hi, 1.0)
				draw_line(Vector2(px + inset, py + inset), Vector2(px + inset, py + ph - inset), hi, 1.0)
				# Bottom shadow edge
				var sh = Color(col.r - 0.05, col.g - 0.05, col.b - 0.04, 0.5)
				draw_line(Vector2(px + inset, py + ph - inset), Vector2(px + pw - inset, py + ph - inset), sh, 1.0)
				draw_line(Vector2(px + pw - inset, py + inset), Vector2(px + pw - inset, py + ph - inset), sh, 1.0)

				# Rivet/bolt pattern at 4 corners of each plate
				var bolt_margin = 6.0
				for bx in [px + bolt_margin, px + pw - bolt_margin]:
					for by in [py + bolt_margin, py + ph - bolt_margin]:
						draw_circle(Vector2(bx, by), 2.5, bolt_dark)
						draw_circle(Vector2(bx, by), 2.0, bolt_light)
						draw_circle(Vector2(bx - 0.5, by - 0.5), 1.0, Color(bolt_light.r + 0.1, bolt_light.g + 0.1, bolt_light.b + 0.08, 0.5))

				# Some plates have a grating pattern (cross-hatch lines)
				if rng.randf() < 0.2:
					var grate_col = Color(mortar_col.r, mortar_col.g, mortar_col.b, 0.3)
					for gx in range(int(px + 10), int(px + pw - 10), 6):
						draw_line(Vector2(gx, py + 10), Vector2(gx, py + ph - 10), grate_col, 1.0)
					for gy in range(int(py + 10), int(py + ph - 10), 6):
						draw_line(Vector2(px + 10, gy), Vector2(px + pw - 10, gy), grate_col, 1.0)

		# Seam lines between plates
		for cx in range(1, plate_cols):
			var lx = cx * base_pw
			draw_line(Vector2(lx, WT), Vector2(lx, AH - WT), seam_col, 2.5)
		for cy in range(1, plate_rows):
			var ly = cy * base_ph
			draw_line(Vector2(WT, ly), Vector2(AW - WT, ly), seam_col, 2.5)

		# Tread marks / worn paths on metal
		for _i in 12:
			var tx = rng.randf_range(WT + 30, AW - WT - 30)
			var ty = rng.randf_range(WT + 30, AH - WT - 30)
			var tl = rng.randf_range(30, 80)
			var ta = rng.randf_range(-0.2, 0.2)
			draw_line(Vector2(tx, ty), Vector2(tx + cos(ta) * tl, ty + sin(ta) * tl),
					  Color(floor_alt.r - 0.03, floor_alt.g - 0.03, floor_alt.b - 0.02, 0.15), 3.0)

	func _draw_abyss_floor(rng: RandomNumberGenerator, _floor_base: Color, floor_alt: Color, _mortar_col: Color) -> void:
		# === Cracked void stone — irregular polygons with glowing purple veins ===

		# Generate irregular stone plate centers
		var stone_centers: Array = []
		for _i in 45:
			stone_centers.append(Vector2(
				rng.randf_range(10, AW - 10),
				rng.randf_range(10, AH - 10)))

		# Draw each stone as a rough irregular polygon
		for i in stone_centers.size():
			var center = stone_centers[i]
			var radius = rng.randf_range(35, 70)
			var sides = rng.randi_range(5, 9)  # Irregular polygons
			var hue = rng.randf_range(-0.02, 0.02)
			var col = Color(
				floor_alt.r + hue,
				floor_alt.g + hue * 0.6,
				floor_alt.b + hue * 1.3)

			var points = PackedVector2Array()
			for s in sides:
				var angle = TAU * s / float(sides) + rng.randf_range(-0.25, 0.25)
				var r = radius + rng.randf_range(-18, 18)
				points.append(center + Vector2(cos(angle), sin(angle)) * r)
			draw_colored_polygon(points, col)

		# Void gaps — some tiles "missing" showing darkness below
		for _i in 8:
			var gx = rng.randf_range(WT + 40, AW - WT - 40)
			var gy = rng.randf_range(WT + 40, AH - WT - 40)
			var gap_sides = rng.randi_range(4, 7)
			var gap_r = rng.randf_range(10, 25)
			var gap_pts = PackedVector2Array()
			for s in gap_sides:
				var angle = TAU * s / float(gap_sides) + rng.randf_range(-0.3, 0.3)
				var r = gap_r + rng.randf_range(-5, 5)
				gap_pts.append(Vector2(gx + cos(angle) * r, gy + sin(angle) * r))
			# Deep void darkness
			draw_colored_polygon(gap_pts, Color(0.01, 0.005, 0.02))
			# Purple glow edge around gap
			for s in gap_pts.size():
				var p1 = gap_pts[s]
				var p2 = gap_pts[(s + 1) % gap_pts.size()]
				draw_line(p1, p2, Color(0.5, 0.1, 0.7, 0.5), 2.0)
			# Inner glow
			draw_circle(Vector2(gx, gy), gap_r * 0.4, Color(0.4, 0.05, 0.6, 0.15))

		# Glowing purple veins between stone plates
		var vein_col = Color(0.55, 0.10, 0.80, 0.5)
		var vein_glow = Color(0.65, 0.20, 0.90, 0.15)
		for i in stone_centers.size():
			var from = stone_centers[i]
			for j in range(i + 1, stone_centers.size()):
				var to = stone_centers[j]
				if from.distance_to(to) < 110:
					var mid = from.lerp(to, 0.5) + Vector2(rng.randf_range(-8, 8), rng.randf_range(-8, 8))
					# Glow halo
					draw_line(from, mid, vein_glow, 5.0)
					draw_line(mid, to, vein_glow, 5.0)
					# Bright vein
					draw_line(from, mid, vein_col, 1.5)
					draw_line(mid, to, vein_col, 1.5)
					# Bright core
					draw_line(from, mid, Color(0.8, 0.4, 1.0, 0.25), 1.0)

		# Faint purple ambient glow on floor
		for _i in 25:
			var px = rng.randf_range(30, AW - 30)
			var py = rng.randf_range(30, AH - 30)
			var pr = rng.randf_range(15, 40)
			draw_circle(Vector2(px, py), pr, Color(0.3, 0.05, 0.5, 0.06))


# ── 3. FLOOR DETAILS ────────────────────────────────────────
# Cracks, stains, moss, gear imprints, scratches, scattered debris

class _FloorDetails extends Node2D:
	var theme: Dictionary = {}

	func _ready() -> void:
		queue_redraw()

	func _draw() -> void:
		var rng = RandomNumberGenerator.new()
		rng.seed = 77771

		var floor_base = theme.get("floor_base", Color(0.18, 0.14, 0.10))
		var moss_color = theme.get("moss_color", Color(0.15, 0.25, 0.10, 0.35))
		var detail_type = theme.get("detail_type", "steampunk")

		# --- Cracks (branching) ---
		for _i in 18:
			var cx = rng.randf_range(WT + 10, AW - WT - 10)
			var cy = rng.randf_range(WT + 10, AH - WT - 10)
			var angle = rng.randf_range(0, TAU)
			var segments = rng.randi_range(2, 5)
			var crack_col = Color(floor_base.r * 0.44, floor_base.g * 0.43, floor_base.b * 0.40, 0.5)
			var pos = Vector2(cx, cy)
			for _s in segments:
				var seg_len = rng.randf_range(6, 22)
				angle += rng.randf_range(-0.6, 0.6)
				var next_pos = pos + Vector2(cos(angle), sin(angle)) * seg_len
				draw_line(pos, next_pos, crack_col, 1.0)
				# Subtle shadow beside crack
				draw_line(pos + Vector2(1, 1), next_pos + Vector2(1, 1),
						  Color(crack_col.r * 0.5, crack_col.g * 0.5, crack_col.b * 0.5, 0.3), 1.0)
				pos = next_pos
				# Branch chance
				if rng.randf() < 0.3:
					var ba = angle + rng.randf_range(-1.2, 1.2)
					var bl = rng.randf_range(4, 12)
					var branch_end = pos + Vector2(cos(ba), sin(ba)) * bl
					draw_line(pos, branch_end, crack_col, 1.0)

		# --- Dark oil/grease stains ---
		for _i in 12:
			var sx = rng.randf_range(WT + 15, AW - WT - 15)
			var sy = rng.randf_range(WT + 15, AH - WT - 15)
			# Draw multiple overlapping circles for organic shape
			for _j in rng.randi_range(3, 7):
				var ox = sx + rng.randf_range(-8, 8)
				var oy = sy + rng.randf_range(-8, 8)
				var or_val = rng.randf_range(4, 14)
				draw_circle(Vector2(ox, oy), or_val, Color(floor_base.r * 0.56, floor_base.g * 0.50, floor_base.b * 0.50, 0.18))

		# --- Moss / lichen patches (near walls) ---
		for _i in 20:
			var near_wall = rng.randi() % 4
			var mx: float = 0.0
			var my: float = 0.0
			match near_wall:
				0: # top
					mx = rng.randf_range(WT + 5, AW - WT - 5)
					my = rng.randf_range(WT + 2, WT + 40)
				1: # bottom
					mx = rng.randf_range(WT + 5, AW - WT - 5)
					my = rng.randf_range(AH - WT - 40, AH - WT - 2)
				2: # left
					mx = rng.randf_range(WT + 2, WT + 40)
					my = rng.randf_range(WT + 5, AH - WT - 5)
				3: # right
					mx = rng.randf_range(AW - WT - 40, AW - WT - 2)
					my = rng.randf_range(WT + 5, AH - WT - 5)
			for _j in rng.randi_range(2, 5):
				var px = mx + rng.randf_range(-6, 6)
				var py = my + rng.randf_range(-6, 6)
				var pr = rng.randf_range(2, 7)
				draw_circle(Vector2(px, py), pr, moss_color)

		# --- Theme-specific floor details ---
		match detail_type:
			"steampunk":
				_draw_steampunk_floor_details(rng)
			"fungal":
				_draw_fungal_floor_details(rng)
			"molten":
				_draw_molten_floor_details(rng)
			"frozen":
				_draw_frozen_floor_details(rng)
			"clockwork":
				_draw_clockwork_floor_details(rng)
			"abyss":
				_draw_abyss_floor_details(rng)

		# --- Small scattered debris dots ---
		for _i in 60:
			var dx = rng.randf_range(WT + 5, AW - WT - 5)
			var dy = rng.randf_range(WT + 5, AH - WT - 5)
			var dr = rng.randf_range(1, 3)
			var dv = rng.randf_range(0.12, 0.20)
			draw_circle(Vector2(dx, dy), dr, Color(dv, dv * 0.85, dv * 0.7, 0.3))

		# --- Scratch marks ---
		for _i in 15:
			var sx = rng.randf_range(WT + 10, AW - WT - 10)
			var sy = rng.randf_range(WT + 10, AH - WT - 10)
			var sa = rng.randf_range(-0.3, 0.3) # mostly horizontal
			var sl = rng.randf_range(12, 40)
			var end = Vector2(sx + cos(sa) * sl, sy + sin(sa) * sl)
			var floor_alt = theme.get("floor_alt", Color(0.20, 0.16, 0.12))
			draw_line(Vector2(sx, sy), end, Color(floor_alt.r + 0.04, floor_alt.g + 0.04, floor_alt.b + 0.04, 0.2), 1.0)

	func _draw_steampunk_floor_details(rng: RandomNumberGenerator) -> void:
		# Gear imprints on floor
		for _i in 6:
			var gx = rng.randf_range(WT + 40, AW - WT - 40)
			var gy = rng.randf_range(WT + 40, AH - WT - 40)
			_draw_gear_imprint(rng, Vector2(gx, gy))

	func _draw_fungal_floor_details(rng: RandomNumberGenerator) -> void:
		# Mushroom cap shapes (semicircles) on the floor
		for _i in 10:
			var mx = rng.randf_range(WT + 20, AW - WT - 20)
			var my = rng.randf_range(WT + 20, AH - WT - 20)
			var cap_r = rng.randf_range(5, 14)
			var cap_col = Color(0.15, 0.35, 0.20, 0.25)
			# Draw semicircle as a polygon
			var pts = PackedVector2Array()
			for a in 9:
				var angle = PI + float(a) / 8.0 * PI
				pts.append(Vector2(mx + cos(angle) * cap_r, my + sin(angle) * cap_r))
			if pts.size() >= 3:
				draw_colored_polygon(pts, cap_col)
			# Stem
			draw_line(Vector2(mx, my), Vector2(mx, my + cap_r * 0.6),
					  Color(0.12, 0.25, 0.15, 0.3), 2.0)

		# Glowing spots (bioluminescent)
		for _i in 15:
			var gx = rng.randf_range(WT + 10, AW - WT - 10)
			var gy = rng.randf_range(WT + 10, AH - WT - 10)
			var gr = rng.randf_range(2, 5)
			draw_circle(Vector2(gx, gy), gr + 3, Color(0.1, 0.5, 0.3, 0.08))
			draw_circle(Vector2(gx, gy), gr, Color(0.2, 0.8, 0.4, 0.2))

		# Vine / tendril lines
		for _i in 8:
			var vx = rng.randf_range(WT + 10, AW - WT - 10)
			var vy = rng.randf_range(WT + 10, AH - WT - 10)
			var angle = rng.randf_range(0, TAU)
			var pos = Vector2(vx, vy)
			var vine_col = Color(0.10, 0.30, 0.15, 0.3)
			for _s in rng.randi_range(3, 7):
				var seg_len = rng.randf_range(8, 18)
				angle += rng.randf_range(-0.8, 0.8)
				var next_pos = pos + Vector2(cos(angle), sin(angle)) * seg_len
				draw_line(pos, next_pos, vine_col, 1.5)
				pos = next_pos

	func _draw_molten_floor_details(rng: RandomNumberGenerator) -> void:
		# Lava crack lines (orange-red zigzag)
		for _i in 12:
			var cx = rng.randf_range(WT + 15, AW - WT - 15)
			var cy = rng.randf_range(WT + 15, AH - WT - 15)
			var angle = rng.randf_range(0, TAU)
			var pos = Vector2(cx, cy)
			var crack_col = Color(0.9, 0.3, 0.05, 0.4)
			var glow_col = Color(1.0, 0.5, 0.1, 0.15)
			for _s in rng.randi_range(3, 6):
				var seg_len = rng.randf_range(6, 16)
				angle += rng.randf_range(-1.0, 1.0)
				var next_pos = pos + Vector2(cos(angle), sin(angle)) * seg_len
				# Glow around crack
				draw_line(pos, next_pos, glow_col, 4.0)
				draw_line(pos, next_pos, crack_col, 1.5)
				pos = next_pos

		# Obsidian shard triangles
		for _i in 8:
			var sx = rng.randf_range(WT + 20, AW - WT - 20)
			var sy = rng.randf_range(WT + 20, AH - WT - 20)
			var shard_size = rng.randf_range(4, 12)
			var angle = rng.randf_range(0, TAU)
			var pts = PackedVector2Array([
				Vector2(sx, sy),
				Vector2(sx + cos(angle) * shard_size, sy + sin(angle) * shard_size),
				Vector2(sx + cos(angle + 0.8) * shard_size * 0.6, sy + sin(angle + 0.8) * shard_size * 0.6),
			])
			draw_colored_polygon(pts, Color(0.08, 0.05, 0.05, 0.4))
			# Shiny edge
			draw_line(pts[0], pts[1], Color(0.25, 0.20, 0.22, 0.3), 1.0)

		# Heat shimmer dots
		for _i in 20:
			var hx = rng.randf_range(WT + 10, AW - WT - 10)
			var hy = rng.randf_range(WT + 10, AH - WT - 10)
			var hr = rng.randf_range(1, 3)
			draw_circle(Vector2(hx, hy), hr, Color(1.0, 0.6, 0.2, 0.08))

	func _draw_gear_imprint(rng: RandomNumberGenerator, center: Vector2) -> void:
		var floor_base = theme.get("floor_base", Color(0.18, 0.14, 0.10))
		var radius = rng.randf_range(10, 22)
		var teeth = rng.randi_range(6, 12)
		var col = Color(floor_base.r * 0.78, floor_base.g * 0.79, floor_base.b * 0.73, 0.15)

		# Outer gear ring
		var points_outer = PackedVector2Array()
		for i in teeth * 2:
			var angle = float(i) / float(teeth * 2) * TAU
			var r = radius if i % 2 == 0 else radius - 4
			points_outer.append(center + Vector2(cos(angle), sin(angle)) * r)
		if points_outer.size() >= 3:
			draw_colored_polygon(points_outer, col)

		# Inner hole
		draw_circle(center, radius * 0.35, Color(floor_base.r, floor_base.g, floor_base.b, 0.8))
		# Axle mark
		draw_circle(center, 2, col)

	func _draw_frozen_floor_details(rng: RandomNumberGenerator) -> void:
		# Ice crystal formations — diamond/triangle shapes in light blue
		for _i in 12:
			var cx = rng.randf_range(WT + 25, AW - WT - 25)
			var cy = rng.randf_range(WT + 25, AH - WT - 25)
			var crystal_size = rng.randf_range(6, 18)
			var crystal_col = Color(0.45, 0.65, 0.85, 0.3)
			var crystal_glow = Color(0.55, 0.75, 0.95, 0.1)
			# Diamond shape
			var pts = PackedVector2Array([
				Vector2(cx, cy - crystal_size),
				Vector2(cx + crystal_size * 0.6, cy),
				Vector2(cx, cy + crystal_size),
				Vector2(cx - crystal_size * 0.6, cy),
			])
			draw_colored_polygon(pts, crystal_col)
			# Glow around crystal
			draw_circle(Vector2(cx, cy), crystal_size * 0.8, crystal_glow)
			# Highlight edge
			draw_line(pts[0], pts[1], Color(0.7, 0.85, 1.0, 0.4), 1.0)
			draw_line(pts[3], pts[0], Color(0.7, 0.85, 1.0, 0.4), 1.0)

		# Frost patterns — branching white lines from walls inward
		for _i in 16:
			var near_wall = rng.randi() % 4
			var fx: float = 0.0
			var fy: float = 0.0
			var angle: float = 0.0
			match near_wall:
				0:  # top
					fx = rng.randf_range(WT + 10, AW - WT - 10)
					fy = WT + rng.randf_range(2, 10)
					angle = PI / 2.0 + rng.randf_range(-0.5, 0.5)
				1:  # bottom
					fx = rng.randf_range(WT + 10, AW - WT - 10)
					fy = AH - WT - rng.randf_range(2, 10)
					angle = -PI / 2.0 + rng.randf_range(-0.5, 0.5)
				2:  # left
					fx = WT + rng.randf_range(2, 10)
					fy = rng.randf_range(WT + 10, AH - WT - 10)
					angle = 0.0 + rng.randf_range(-0.5, 0.5)
				3:  # right
					fx = AW - WT - rng.randf_range(2, 10)
					fy = rng.randf_range(WT + 10, AH - WT - 10)
					angle = PI + rng.randf_range(-0.5, 0.5)
			var pos = Vector2(fx, fy)
			var frost_col = Color(0.70, 0.82, 0.95, 0.25)
			for _s in rng.randi_range(3, 6):
				var seg_len = rng.randf_range(5, 15)
				angle += rng.randf_range(-0.4, 0.4)
				var next_pos = pos + Vector2(cos(angle), sin(angle)) * seg_len
				draw_line(pos, next_pos, frost_col, 1.0)
				# Branch
				if rng.randf() < 0.5:
					var ba = angle + rng.randf_range(-1.0, 1.0)
					var bl = rng.randf_range(3, 8)
					var bend = next_pos + Vector2(cos(ba), sin(ba)) * bl
					draw_line(next_pos, bend, Color(frost_col.r, frost_col.g, frost_col.b, 0.15), 1.0)
				pos = next_pos

		# Frozen puddles with surface shimmer
		for _i in 6:
			var px = rng.randf_range(WT + 30, AW - WT - 30)
			var py = rng.randf_range(WT + 30, AH - WT - 30)
			var pr = rng.randf_range(12, 28)
			# Frozen surface
			draw_circle(Vector2(px, py), pr, Color(0.30, 0.50, 0.70, 0.2))
			draw_circle(Vector2(px, py), pr * 0.7, Color(0.40, 0.60, 0.80, 0.12))
			# Shimmer highlight
			draw_circle(Vector2(px - pr * 0.25, py - pr * 0.25), pr * 0.2, Color(0.8, 0.9, 1.0, 0.2))

	func _draw_clockwork_floor_details(rng: RandomNumberGenerator) -> void:
		# Large gear shapes embedded in floor (bigger than steampunk)
		for _i in 8:
			var gx = rng.randf_range(WT + 50, AW - WT - 50)
			var gy = rng.randf_range(WT + 50, AH - WT - 50)
			var gear_r = rng.randf_range(18, 40)
			var teeth = rng.randi_range(8, 16)
			var gear_col = Color(0.16, 0.15, 0.13, 0.2)
			var gear_hi = Color(0.24, 0.22, 0.18, 0.15)
			# Gear teeth polygon
			var pts = PackedVector2Array()
			for t in teeth * 2:
				var angle = float(t) / float(teeth * 2) * TAU
				var r = gear_r if t % 2 == 0 else gear_r - 6
				pts.append(Vector2(gx + cos(angle) * r, gy + sin(angle) * r))
			if pts.size() >= 3:
				draw_colored_polygon(pts, gear_col)
			# Inner ring
			draw_circle(Vector2(gx, gy), gear_r * 0.5, Color(gear_col.r - 0.02, gear_col.g - 0.02, gear_col.b - 0.01, 0.15))
			# Axle
			draw_circle(Vector2(gx, gy), gear_r * 0.15, gear_hi)
			draw_circle(Vector2(gx, gy), gear_r * 0.08, gear_col)

		# Conveyor belt lines (parallel dashed lines)
		for _i in 3:
			var cy_start = rng.randf_range(WT + 30, AH - WT - 30)
			var cx_start = rng.randf_range(WT + 20, AW * 0.3)
			var cx_end = rng.randf_range(AW * 0.7, AW - WT - 20)
			var belt_col = Color(0.12, 0.11, 0.10, 0.2)
			var belt_w = rng.randf_range(14, 24)
			draw_line(Vector2(cx_start, cy_start - belt_w / 2), Vector2(cx_end, cy_start - belt_w / 2), belt_col, 2.0)
			draw_line(Vector2(cx_start, cy_start + belt_w / 2), Vector2(cx_end, cy_start + belt_w / 2), belt_col, 2.0)
			# Tread marks
			for tx in range(int(cx_start), int(cx_end), 12):
				draw_line(Vector2(tx, cy_start - belt_w / 2), Vector2(tx, cy_start + belt_w / 2),
						  Color(belt_col.r, belt_col.g, belt_col.b, 0.1), 1.0)

		# Oil stains (dark spots)
		for _i in 10:
			var ox = rng.randf_range(WT + 15, AW - WT - 15)
			var oy = rng.randf_range(WT + 15, AH - WT - 15)
			for _j in rng.randi_range(2, 5):
				var sx = ox + rng.randf_range(-6, 6)
				var sy = oy + rng.randf_range(-6, 6)
				var sr = rng.randf_range(3, 10)
				draw_circle(Vector2(sx, sy), sr, Color(0.04, 0.03, 0.02, 0.2))

		# Steam vents (white circles with glow)
		for _i in 5:
			var vx = rng.randf_range(WT + 30, AW - WT - 30)
			var vy = rng.randf_range(WT + 30, AH - WT - 30)
			var vr = rng.randf_range(4, 8)
			draw_circle(Vector2(vx, vy), vr + 4, Color(0.5, 0.5, 0.55, 0.06))
			draw_circle(Vector2(vx, vy), vr, Color(0.6, 0.6, 0.65, 0.15))
			draw_circle(Vector2(vx, vy), vr * 0.5, Color(0.8, 0.8, 0.85, 0.1))

	func _draw_abyss_floor_details(rng: RandomNumberGenerator) -> void:
		# Shadow tendrils — dark purple wavy lines
		for _i in 14:
			var tx = rng.randf_range(WT + 15, AW - WT - 15)
			var ty = rng.randf_range(WT + 15, AH - WT - 15)
			var angle = rng.randf_range(0, TAU)
			var pos = Vector2(tx, ty)
			var tendril_col = Color(0.15, 0.03, 0.25, 0.35)
			for _s in rng.randi_range(4, 8):
				var seg_len = rng.randf_range(8, 20)
				angle += rng.randf_range(-0.7, 0.7)
				var next_pos = pos + Vector2(cos(angle), sin(angle)) * seg_len
				draw_line(pos, next_pos, tendril_col, 2.0)
				# Thinner trailing line
				draw_line(pos, next_pos, Color(tendril_col.r, tendril_col.g, tendril_col.b, 0.15), 4.0)
				pos = next_pos

		# Void rifts — bright purple slashes
		for _i in 8:
			var rx = rng.randf_range(WT + 20, AW - WT - 20)
			var ry = rng.randf_range(WT + 20, AH - WT - 20)
			var ra = rng.randf_range(0, TAU)
			var rl = rng.randf_range(12, 35)
			var rift_end = Vector2(rx + cos(ra) * rl, ry + sin(ra) * rl)
			# Glow
			draw_line(Vector2(rx, ry), rift_end, Color(0.6, 0.15, 0.9, 0.12), 5.0)
			# Bright slash
			draw_line(Vector2(rx, ry), rift_end, Color(0.7, 0.25, 1.0, 0.5), 1.5)
			# Core
			draw_line(Vector2(rx, ry), rift_end, Color(0.9, 0.6, 1.0, 0.3), 1.0)

		# Ancient rune circles — geometric patterns in purple glow
		for _i in 4:
			var cx = rng.randf_range(WT + 50, AW - WT - 50)
			var cy = rng.randf_range(WT + 50, AH - WT - 50)
			var cr = rng.randf_range(15, 30)
			var rune_col = Color(0.5, 0.15, 0.75, 0.2)
			# Outer circle
			var circle_pts = 24
			for s in circle_pts:
				var a1 = TAU * s / float(circle_pts)
				var a2 = TAU * (s + 1) / float(circle_pts)
				draw_line(Vector2(cx + cos(a1) * cr, cy + sin(a1) * cr),
						  Vector2(cx + cos(a2) * cr, cy + sin(a2) * cr), rune_col, 1.0)
			# Inner geometric pattern (inscribed triangle or pentagon)
			var inner_sides = rng.randi_range(3, 5)
			var inner_r = cr * 0.6
			var inner_pts = PackedVector2Array()
			for s in inner_sides:
				var angle = TAU * s / float(inner_sides) + rng.randf_range(-0.1, 0.1)
				inner_pts.append(Vector2(cx + cos(angle) * inner_r, cy + sin(angle) * inner_r))
			for s in inner_pts.size():
				draw_line(inner_pts[s], inner_pts[(s + 1) % inner_pts.size()], rune_col, 1.0)
			# Center dot glow
			draw_circle(Vector2(cx, cy), 3, Color(0.6, 0.2, 0.9, 0.25))
			draw_circle(Vector2(cx, cy), 6, Color(0.5, 0.1, 0.8, 0.08))

		# Eye symbols scattered on floor
		for _i in 5:
			var ex = rng.randf_range(WT + 20, AW - WT - 20)
			var ey = rng.randf_range(WT + 20, AH - WT - 20)
			var eye_r = rng.randf_range(4, 8)
			var eye_col = Color(0.5, 0.1, 0.7, 0.25)
			# Eye outline (almond shape using 2 arcs)
			var eye_pts = PackedVector2Array()
			for s in 12:
				var angle = float(s) / 11.0 * PI
				eye_pts.append(Vector2(ex + cos(angle) * eye_r * 1.5, ey + sin(angle) * eye_r * 0.6))
			for s in 12:
				var angle = PI + float(s) / 11.0 * PI
				eye_pts.append(Vector2(ex + cos(angle) * eye_r * 1.5, ey + sin(angle) * eye_r * 0.6))
			if eye_pts.size() >= 3:
				draw_colored_polygon(eye_pts, Color(eye_col.r, eye_col.g, eye_col.b, 0.1))
			# Pupil
			draw_circle(Vector2(ex, ey), eye_r * 0.35, eye_col)
			draw_circle(Vector2(ex, ey), eye_r * 0.15, Color(0.8, 0.3, 1.0, 0.3))


# ── 4. PUDDLES ───────────────────────────────────────────────
# Small reflective puddles with subtle highlight

class _Puddles extends Node2D:
	var theme: Dictionary = {}

	func _ready() -> void:
		queue_redraw()

	func _draw() -> void:
		var rng = RandomNumberGenerator.new()
		rng.seed = 55123

		var puddle_color = theme.get("puddle_color", Color(0.08, 0.10, 0.16, 0.25))
		var puddle_highlight = theme.get("puddle_highlight", Color(0.3, 0.35, 0.4, 0.2))

		for _i in 8:
			var px = rng.randf_range(WT + 30, AW - WT - 30)
			var py = rng.randf_range(WT + 30, AH - WT - 30)
			var pw = rng.randf_range(12, 35)
			var ph = rng.randf_range(8, 20)

			# Puddle base
			for _j in rng.randi_range(3, 6):
				var ox = px + rng.randf_range(-pw * 0.3, pw * 0.3)
				var oy = py + rng.randf_range(-ph * 0.3, ph * 0.3)
				var orx = rng.randf_range(pw * 0.3, pw * 0.7)
				var ory = rng.randf_range(ph * 0.3, ph * 0.7)
				# Approximate ellipse with polygon
				var pts = PackedVector2Array()
				for a in 12:
					var angle = float(a) / 12.0 * TAU
					pts.append(Vector2(ox + cos(angle) * orx, oy + sin(angle) * ory))
				draw_colored_polygon(pts, puddle_color)

			# Specular highlight dot
			draw_circle(Vector2(px - pw * 0.2, py - ph * 0.2), 2, puddle_highlight)


# ── 5. WALL VISUALS ─────────────────────────────────────────
# Thick walls with brick pattern, gradient, inner shadow

class _WallVisuals extends Node2D:
	var theme: Dictionary = {}

	func _ready() -> void:
		queue_redraw()

	func _draw() -> void:
		var rng = RandomNumberGenerator.new()
		rng.seed = 33211

		# --- TOP WALL ---
		_draw_wall_segment(rng, Rect2(0, 0, AW, WT), "top")
		# --- BOTTOM WALL ---
		_draw_wall_segment(rng, Rect2(0, AH - WT, AW, WT), "bottom")
		# --- LEFT WALL ---
		_draw_wall_segment(rng, Rect2(0, 0, WT, AH), "left")
		# --- RIGHT WALL ---
		_draw_wall_segment(rng, Rect2(AW - WT, 0, WT, AH), "right")

		# --- Corner blocks (reinforced look) ---
		var wall_base = theme.get("wall_base", Color(0.12, 0.09, 0.06))
		var wall_highlight = theme.get("wall_highlight", Color(0.22, 0.17, 0.12))
		var corner_col = Color(wall_base.r - 0.02, wall_base.g - 0.02, wall_base.b - 0.01)
		var corner_hi  = Color(wall_highlight.r - 0.06, wall_highlight.g - 0.05, wall_highlight.b - 0.04)
		for c in [Vector2(0, 0), Vector2(AW - WT, 0),
				  Vector2(0, AH - WT), Vector2(AW - WT, AH - WT)]:
			draw_rect(Rect2(c.x, c.y, WT, WT), corner_col)
			# Rivet cluster
			for rx in [c.x + 4, c.x + WT - 4]:
				for ry in [c.y + 4, c.y + WT - 4]:
					draw_circle(Vector2(rx, ry), 2.5, Color(0.06, 0.04, 0.03))
					draw_circle(Vector2(rx, ry), 2.0, Color(wall_highlight.r + 0.08, wall_highlight.g + 0.07, wall_highlight.b + 0.04))
					draw_circle(Vector2(rx - 0.5, ry - 0.5), 1.0, corner_hi)

	func _draw_wall_segment(rng: RandomNumberGenerator, rect: Rect2, side: String) -> void:
		var wall_base = theme.get("wall_base", Color(0.12, 0.09, 0.06))
		var wall_highlight = theme.get("wall_highlight", Color(0.22, 0.17, 0.12))
		var base_col = wall_base
		var light_col = Color(wall_highlight.r - 0.04, wall_highlight.g - 0.03, wall_highlight.b - 0.02)
		var dark_col = Color(wall_base.r * 0.5, wall_base.g * 0.44, wall_base.b * 0.5)

		# Base wall fill
		draw_rect(rect, base_col)

		# Gradient: lighter toward arena interior
		var grad_steps = 6
		for i in grad_steps:
			var t = float(i) / float(grad_steps)
			var alpha = (1.0 - t) * 0.3
			var col = Color(light_col.r, light_col.g, light_col.b, alpha)
			match side:
				"top":
					draw_rect(Rect2(rect.position.x, rect.position.y + rect.size.y - (i + 1) * 2,
									rect.size.x, 2), col)
				"bottom":
					draw_rect(Rect2(rect.position.x, rect.position.y + i * 2,
									rect.size.x, 2), col)
				"left":
					draw_rect(Rect2(rect.position.x + rect.size.x - (i + 1) * 2, rect.position.y,
									2, rect.size.y), col)
				"right":
					draw_rect(Rect2(rect.position.x + i * 2, rect.position.y,
									2, rect.size.y), col)

		# Brick pattern
		_draw_brick_pattern(rng, rect, side)

		# Inner shadow line (edge facing arena)
		match side:
			"top":
				draw_line(Vector2(rect.position.x, rect.position.y + rect.size.y),
						  Vector2(rect.position.x + rect.size.x, rect.position.y + rect.size.y),
						  dark_col, 2.0)
			"bottom":
				draw_line(Vector2(rect.position.x, rect.position.y),
						  Vector2(rect.position.x + rect.size.x, rect.position.y),
						  dark_col, 2.0)
			"left":
				draw_line(Vector2(rect.position.x + rect.size.x, rect.position.y),
						  Vector2(rect.position.x + rect.size.x, rect.position.y + rect.size.y),
						  dark_col, 2.0)
			"right":
				draw_line(Vector2(rect.position.x, rect.position.y),
						  Vector2(rect.position.x, rect.position.y + rect.size.y),
						  dark_col, 2.0)

		# Outer highlight line
		var hi = Color(wall_highlight.r - 0.02, wall_highlight.g - 0.01, wall_highlight.b, 0.4)
		match side:
			"top":
				draw_line(Vector2(rect.position.x, rect.position.y + 1),
						  Vector2(rect.position.x + rect.size.x, rect.position.y + 1), hi, 1.0)
			"bottom":
				draw_line(Vector2(rect.position.x, rect.position.y + rect.size.y - 1),
						  Vector2(rect.position.x + rect.size.x, rect.position.y + rect.size.y - 1), hi, 1.0)
			"left":
				draw_line(Vector2(rect.position.x + 1, rect.position.y),
						  Vector2(rect.position.x + 1, rect.position.y + rect.size.y), hi, 1.0)
			"right":
				draw_line(Vector2(rect.position.x + rect.size.x - 1, rect.position.y),
						  Vector2(rect.position.x + rect.size.x - 1, rect.position.y + rect.size.y), hi, 1.0)

	func _draw_brick_pattern(rng: RandomNumberGenerator, rect: Rect2, side: String) -> void:
		var mortar_base = theme.get("mortar", Color(0.10, 0.07, 0.05))
		var wall_base = theme.get("wall_base", Color(0.12, 0.09, 0.06))
		var mortar_col = Color(mortar_base.r * 0.7, mortar_base.g * 0.71, mortar_base.b * 0.6, 0.6)
		if side == "top" or side == "bottom":
			# Horizontal bricks
			var bw = 20
			var bh = int(rect.size.y / 2.0)
			var row = 0
			var y = int(rect.position.y)
			while y < int(rect.position.y + rect.size.y):
				var h = mini(bh, int(rect.position.y + rect.size.y) - y)
				var offset = (bw / 2.0) if (row % 2 == 1) else 0.0
				var x = int(rect.position.x) + offset
				while x < int(rect.position.x + rect.size.x):
					# Per-brick color variation
					var v = rng.randf_range(-0.015, 0.015)
					var bc = Color(wall_base.r + v, wall_base.g + v * 0.8, wall_base.b + v * 0.5, 0.4)
					var bwidth = mini(bw, int(rect.position.x + rect.size.x) - x)
					if bwidth > 2 and h > 2:
						draw_rect(Rect2(x + 1, y + 1, bwidth - 1, h - 1), bc)
					# Mortar lines
					draw_line(Vector2(x, y), Vector2(x, y + h), mortar_col, 1.0)
					x += bw
				# Horizontal mortar
				if y > int(rect.position.y):
					draw_line(Vector2(rect.position.x, y),
							  Vector2(rect.position.x + rect.size.x, y), mortar_col, 1.0)
				y += bh
				row += 1
		else:
			# Vertical bricks
			var bh = 12
			var bw_val = int(rect.size.x / 2.0)
			var row = 0
			var y = int(rect.position.y)
			while y < int(rect.position.y + rect.size.y):
				var h = mini(bh, int(rect.position.y + rect.size.y) - y)
				var offset = (bw_val / 2.0) if (row % 2 == 1) else 0.0
				var x = int(rect.position.x) + offset
				while x < int(rect.position.x + rect.size.x):
					var v = rng.randf_range(-0.015, 0.015)
					var bc = Color(wall_base.r + v, wall_base.g + v * 0.8, wall_base.b + v * 0.5, 0.4)
					var w = mini(bw_val, int(rect.position.x + rect.size.x) - x)
					if w > 1 and h > 1:
						draw_rect(Rect2(x + 1, y + 1, w - 1, h - 1), bc)
					draw_line(Vector2(x, y), Vector2(x, y + h), mortar_col, 1.0)
					x += bw_val
				if y > int(rect.position.y):
					draw_line(Vector2(rect.position.x, y),
							  Vector2(rect.position.x + rect.size.x, y), mortar_col, 1.0)
				y += bh
				row += 1


# ── 6. WALL DECORATIONS ─────────────────────────────────────
# Theme-dependent: pipes/gears/bolts, mushrooms/tendrils, lava cracks/shards

class _WallDecorations extends Node2D:
	var theme: Dictionary = {}

	func _ready() -> void:
		queue_redraw()

	func _draw() -> void:
		var rng = RandomNumberGenerator.new()
		rng.seed = 44551

		var detail_type = theme.get("detail_type", "steampunk")

		match detail_type:
			"steampunk":
				_draw_steampunk_decorations(rng)
			"fungal":
				_draw_fungal_decorations(rng)
			"molten":
				_draw_molten_decorations(rng)
			"frozen":
				_draw_frozen_decorations(rng)
			"clockwork":
				_draw_clockwork_decorations(rng)
			"abyss":
				_draw_abyss_decorations(rng)

		# --- Torch brackets (always drawn regardless of theme) ---
		for torch_data in TORCH_POSITIONS:
			var tp: Vector2 = torch_data["pos"]
			var tw: String = torch_data["wall"]
			_draw_torch_bracket(tp, tw)

	func _draw_steampunk_decorations(rng: RandomNumberGenerator) -> void:
		# --- Horizontal pipes along top and bottom walls ---
		_draw_pipe(Vector2(WT + 20, 6), Vector2(AW / 3.0, 6), 3.0, rng)
		_draw_pipe(Vector2(AW * 0.6, 6), Vector2(AW - WT - 20, 6), 3.0, rng)
		_draw_pipe(Vector2(WT + 40, AH - 6), Vector2(AW / 2.5, AH - 6), 2.5, rng)
		_draw_pipe(Vector2(AW * 0.65, AH - 6), Vector2(AW - WT - 30, AH - 6), 2.5, rng)

		# --- Vertical pipes along left and right walls ---
		_draw_pipe(Vector2(6, WT + 30), Vector2(6, AH * 0.35), 3.0, rng)
		_draw_pipe(Vector2(6, AH * 0.6), Vector2(6, AH - WT - 20), 2.5, rng)
		_draw_pipe(Vector2(AW - 6, WT + 50), Vector2(AW - 6, AH * 0.4), 3.0, rng)
		_draw_pipe(Vector2(AW - 6, AH * 0.55), Vector2(AW - 6, AH - WT - 40), 2.5, rng)

		# --- Wall-mounted gears ---
		for _i in 8:
			var side = rng.randi() % 4
			var gx: float = 0.0
			var gy: float = 0.0
			match side:
				0: gx = rng.randf_range(WT + 5, AW - WT - 5); gy = rng.randf_range(2, WT - 2)
				1: gx = rng.randf_range(WT + 5, AW - WT - 5); gy = rng.randf_range(AH - WT + 2, AH - 2)
				2: gx = rng.randf_range(2, WT - 2); gy = rng.randf_range(WT + 5, AH - WT - 5)
				3: gx = rng.randf_range(AW - WT + 2, AW - 2); gy = rng.randf_range(WT + 5, AH - WT - 5)
			_draw_wall_gear(Vector2(gx, gy), rng.randf_range(4, 8), rng.randi_range(5, 8))

		# --- Scattered bolts along walls ---
		for _i in 30:
			var side = rng.randi() % 4
			var bx: float = 0.0
			var by: float = 0.0
			match side:
				0: bx = rng.randf_range(WT, AW - WT); by = rng.randf_range(3, WT - 3)
				1: bx = rng.randf_range(WT, AW - WT); by = rng.randf_range(AH - WT + 3, AH - 3)
				2: bx = rng.randf_range(3, WT - 3); by = rng.randf_range(WT, AH - WT)
				3: bx = rng.randf_range(AW - WT + 3, AW - 3); by = rng.randf_range(WT, AH - WT)
			_draw_bolt(Vector2(bx, by))

	func _draw_fungal_decorations(rng: RandomNumberGenerator) -> void:
		# --- Mushroom caps growing from walls ---
		for _i in 14:
			var side = rng.randi() % 4
			var mx: float = 0.0
			var my: float = 0.0
			var cap_dir: Vector2 = Vector2.ZERO
			match side:
				0:
					mx = rng.randf_range(WT + 10, AW - WT - 10)
					my = WT
					cap_dir = Vector2(0, 1)
				1:
					mx = rng.randf_range(WT + 10, AW - WT - 10)
					my = AH - WT
					cap_dir = Vector2(0, -1)
				2:
					mx = WT
					my = rng.randf_range(WT + 10, AH - WT - 10)
					cap_dir = Vector2(1, 0)
				3:
					mx = AW - WT
					my = rng.randf_range(WT + 10, AH - WT - 10)
					cap_dir = Vector2(-1, 0)

			var cap_r = rng.randf_range(4, 10)
			var cap_center = Vector2(mx, my) + cap_dir * cap_r * 0.5
			# Semicircle cap
			var pts = PackedVector2Array()
			var base_angle = atan2(cap_dir.y, cap_dir.x) - PI / 2.0
			for a in 9:
				var angle = base_angle + float(a) / 8.0 * PI
				pts.append(cap_center + Vector2(cos(angle), sin(angle)) * cap_r)
			if pts.size() >= 3:
				draw_colored_polygon(pts, Color(0.12, 0.30, 0.18, 0.5))
			# Stem
			draw_line(Vector2(mx, my), cap_center, Color(0.10, 0.22, 0.14, 0.4), 2.0)

		# --- Glowing spots on walls ---
		for _i in 20:
			var side = rng.randi() % 4
			var gx: float = 0.0
			var gy: float = 0.0
			match side:
				0: gx = rng.randf_range(WT + 5, AW - WT - 5); gy = rng.randf_range(2, WT - 1)
				1: gx = rng.randf_range(WT + 5, AW - WT - 5); gy = rng.randf_range(AH - WT + 1, AH - 2)
				2: gx = rng.randf_range(2, WT - 1); gy = rng.randf_range(WT + 5, AH - WT - 5)
				3: gx = rng.randf_range(AW - WT + 1, AW - 2); gy = rng.randf_range(WT + 5, AH - WT - 5)
			var gr = rng.randf_range(2, 5)
			draw_circle(Vector2(gx, gy), gr + 4, Color(0.1, 0.6, 0.3, 0.06))
			draw_circle(Vector2(gx, gy), gr, Color(0.2, 0.9, 0.4, 0.25))

		# --- Vine/tendril lines along walls ---
		for _i in 10:
			var side = rng.randi() % 4
			var vx: float = 0.0
			var vy: float = 0.0
			match side:
				0: vx = rng.randf_range(WT + 5, AW - WT - 5); vy = WT * 0.5
				1: vx = rng.randf_range(WT + 5, AW - WT - 5); vy = AH - WT * 0.5
				2: vx = WT * 0.5; vy = rng.randf_range(WT + 5, AH - WT - 5)
				3: vx = AW - WT * 0.5; vy = rng.randf_range(WT + 5, AH - WT - 5)
			var pos = Vector2(vx, vy)
			var angle = rng.randf_range(0, TAU)
			var vine_col = Color(0.08, 0.28, 0.12, 0.35)
			for _s in rng.randi_range(2, 5):
				var seg_len = rng.randf_range(5, 14)
				angle += rng.randf_range(-0.6, 0.6)
				var next_pos = pos + Vector2(cos(angle), sin(angle)) * seg_len
				draw_line(pos, next_pos, vine_col, 1.5)
				pos = next_pos

	func _draw_molten_decorations(rng: RandomNumberGenerator) -> void:
		# --- Lava crack lines on walls (orange-red zigzags) ---
		for _i in 16:
			var side = rng.randi() % 4
			var cx: float = 0.0
			var cy: float = 0.0
			match side:
				0: cx = rng.randf_range(WT + 5, AW - WT - 5); cy = rng.randf_range(2, WT - 2)
				1: cx = rng.randf_range(WT + 5, AW - WT - 5); cy = rng.randf_range(AH - WT + 2, AH - 2)
				2: cx = rng.randf_range(2, WT - 2); cy = rng.randf_range(WT + 5, AH - WT - 5)
				3: cx = rng.randf_range(AW - WT + 2, AW - 2); cy = rng.randf_range(WT + 5, AH - WT - 5)
			var pos = Vector2(cx, cy)
			var angle = rng.randf_range(0, TAU)
			for _s in rng.randi_range(2, 4):
				var seg_len = rng.randf_range(4, 10)
				angle += rng.randf_range(-1.2, 1.2)
				var next_pos = pos + Vector2(cos(angle), sin(angle)) * seg_len
				draw_line(pos, next_pos, Color(1.0, 0.5, 0.1, 0.12), 3.0)  # glow
				draw_line(pos, next_pos, Color(0.9, 0.3, 0.05, 0.5), 1.0)  # crack
				pos = next_pos

		# --- Obsidian shard triangles on walls ---
		for _i in 10:
			var side = rng.randi() % 4
			var sx: float = 0.0
			var sy: float = 0.0
			match side:
				0: sx = rng.randf_range(WT + 5, AW - WT - 5); sy = rng.randf_range(2, WT - 2)
				1: sx = rng.randf_range(WT + 5, AW - WT - 5); sy = rng.randf_range(AH - WT + 2, AH - 2)
				2: sx = rng.randf_range(2, WT - 2); sy = rng.randf_range(WT + 5, AH - WT - 5)
				3: sx = rng.randf_range(AW - WT + 2, AW - 2); sy = rng.randf_range(WT + 5, AH - WT - 5)
			var shard_size = rng.randf_range(3, 8)
			var angle = rng.randf_range(0, TAU)
			var pts = PackedVector2Array([
				Vector2(sx, sy),
				Vector2(sx + cos(angle) * shard_size, sy + sin(angle) * shard_size),
				Vector2(sx + cos(angle + 0.9) * shard_size * 0.5, sy + sin(angle + 0.9) * shard_size * 0.5),
			])
			draw_colored_polygon(pts, Color(0.06, 0.04, 0.04, 0.5))
			draw_line(pts[0], pts[1], Color(0.20, 0.15, 0.18, 0.3), 1.0)

		# --- Heat shimmer dots on walls ---
		for _i in 25:
			var side = rng.randi() % 4
			var hx: float = 0.0
			var hy: float = 0.0
			match side:
				0: hx = rng.randf_range(WT, AW - WT); hy = rng.randf_range(2, WT - 2)
				1: hx = rng.randf_range(WT, AW - WT); hy = rng.randf_range(AH - WT + 2, AH - 2)
				2: hx = rng.randf_range(2, WT - 2); hy = rng.randf_range(WT, AH - WT)
				3: hx = rng.randf_range(AW - WT + 2, AW - 2); hy = rng.randf_range(WT, AH - WT)
			draw_circle(Vector2(hx, hy), rng.randf_range(1, 3), Color(1.0, 0.5, 0.15, 0.1))

	func _draw_pipe(from: Vector2, to: Vector2, radius: float, rng: RandomNumberGenerator) -> void:
		var pipe_dark  = Color(0.15, 0.12, 0.08)
		var pipe_light = Color(0.28, 0.22, 0.16)
		var pipe_mid   = Color(0.20, 0.16, 0.12)

		# Pipe shadow
		draw_line(from + Vector2(0, 1), to + Vector2(0, 1), Color(0.05, 0.03, 0.02, 0.5), radius * 2 + 2)
		# Pipe body
		draw_line(from, to, pipe_mid, radius * 2)
		# Highlight stripe
		draw_line(from - Vector2(0, radius * 0.4), to - Vector2(0, radius * 0.4), pipe_light, 1.0)
		# Dark underside
		draw_line(from + Vector2(0, radius * 0.4), to + Vector2(0, radius * 0.4), pipe_dark, 1.0)

		# Joint rings
		var dist = from.distance_to(to)
		var joints = int(dist / 60)
		for j in joints:
			var t = float(j + 1) / float(joints + 1)
			var jp = from.lerp(to, t)
			draw_circle(jp, radius + 1, pipe_dark)
			draw_circle(jp, radius, pipe_light)

		# End caps
		for p in [from, to]:
			draw_circle(p, radius + 1, pipe_dark)
			draw_circle(p, radius, pipe_mid)

		# Occasional rust spot
		if rng.randf() < 0.4:
			var rust_t = rng.randf_range(0.2, 0.8)
			var rust_p = from.lerp(to, rust_t)
			draw_circle(rust_p, rng.randf_range(2, 4), Color(0.25, 0.12, 0.06, 0.3))

	func _draw_wall_gear(center: Vector2, radius: float, teeth: int) -> void:
		var col = Color(0.25, 0.20, 0.14, 0.6)
		var shadow = Color(0.06, 0.04, 0.03, 0.4)

		# Gear shadow
		draw_circle(center + Vector2(1, 1), radius + 1, shadow)

		# Gear teeth
		var points = PackedVector2Array()
		for i in teeth * 2:
			var angle = float(i) / float(teeth * 2) * TAU
			var r = radius if i % 2 == 0 else radius - 3
			points.append(center + Vector2(cos(angle), sin(angle)) * r)
		if points.size() >= 3:
			draw_colored_polygon(points, col)

		# Axle
		draw_circle(center, radius * 0.3, Color(0.10, 0.08, 0.06))
		draw_circle(center, 1.5, Color(0.30, 0.24, 0.16))

	func _draw_torch_bracket(pos: Vector2, wall: String) -> void:
		var torch_color = theme.get("torch_color", Color(1.0, 0.65, 0.15))
		var bracket_col = Color(0.30, 0.22, 0.14)
		var dark = Color(0.08, 0.06, 0.04)

		# Bracket arm extending into arena
		var arm_end = pos
		match wall:
			"top":    arm_end = pos + Vector2(0, 8)
			"bottom": arm_end = pos + Vector2(0, -8)
			"left":   arm_end = pos + Vector2(8, 0)
			"right":  arm_end = pos + Vector2(-8, 0)

		# Bracket
		draw_line(pos, arm_end, dark, 3.0)
		draw_line(pos, arm_end, bracket_col, 2.0)

		# Torch cup
		draw_circle(arm_end, 3, dark)
		draw_circle(arm_end, 2.5, bracket_col)

		# Flame
		var flame_col = Color(torch_color.r, torch_color.g, torch_color.b, 0.9)
		var flame_inner = Color(minf(torch_color.r, 1.0), minf(torch_color.g + 0.25, 1.0), minf(torch_color.b + 0.25, 1.0), 0.8)
		var flame_offset = Vector2(0, -3) if wall == "top" or wall == "bottom" else Vector2(0, -2)
		draw_circle(arm_end + flame_offset, 3.0, flame_col)
		draw_circle(arm_end + flame_offset + Vector2(0, -1), 1.5, flame_inner)

	func _draw_bolt(pos: Vector2) -> void:
		draw_circle(pos, 2.0, Color(0.06, 0.04, 0.03, 0.5))
		draw_circle(pos, 1.5, Color(0.28, 0.22, 0.15, 0.6))
		draw_circle(pos - Vector2(0.5, 0.5), 0.8, Color(0.35, 0.28, 0.20, 0.4))

	func _draw_frozen_decorations(rng: RandomNumberGenerator) -> void:
		# --- Icicle stalactites hanging from top wall (triangle shapes pointing down) ---
		for _i in 18:
			var ix = rng.randf_range(WT + 8, AW - WT - 8)
			var iy = WT  # hanging from top wall
			var iw = rng.randf_range(3, 7)
			var ih = rng.randf_range(10, 30)
			var ice_col = Color(0.50, 0.70, 0.90, 0.5)
			var ice_hi = Color(0.70, 0.85, 1.0, 0.4)
			var pts = PackedVector2Array([
				Vector2(ix - iw / 2, iy),
				Vector2(ix + iw / 2, iy),
				Vector2(ix + rng.randf_range(-1, 1), iy + ih),
			])
			draw_colored_polygon(pts, ice_col)
			# Highlight on left edge
			draw_line(pts[0], pts[2], ice_hi, 1.0)

		# Some icicles on bottom wall (pointing up) — fewer
		for _i in 8:
			var ix = rng.randf_range(WT + 15, AW - WT - 15)
			var iy = AH - WT
			var iw = rng.randf_range(2, 5)
			var ih = rng.randf_range(6, 18)
			var pts = PackedVector2Array([
				Vector2(ix - iw / 2, iy),
				Vector2(ix + iw / 2, iy),
				Vector2(ix + rng.randf_range(-1, 1), iy - ih),
			])
			draw_colored_polygon(pts, Color(0.45, 0.65, 0.85, 0.4))

		# --- Ice crystal clusters on walls ---
		for _i in 12:
			var side = rng.randi() % 4
			var cx: float = 0.0
			var cy: float = 0.0
			match side:
				0: cx = rng.randf_range(WT + 10, AW - WT - 10); cy = rng.randf_range(2, WT - 2)
				1: cx = rng.randf_range(WT + 10, AW - WT - 10); cy = rng.randf_range(AH - WT + 2, AH - 2)
				2: cx = rng.randf_range(2, WT - 2); cy = rng.randf_range(WT + 10, AH - WT - 10)
				3: cx = rng.randf_range(AW - WT + 2, AW - 2); cy = rng.randf_range(WT + 10, AH - WT - 10)
			# Small cluster of crystal shapes
			for _j in rng.randi_range(2, 4):
				var ox = cx + rng.randf_range(-4, 4)
				var oy = cy + rng.randf_range(-4, 4)
				var cr = rng.randf_range(2, 5)
				var crystal_col = Color(0.45, 0.65, 0.90, 0.45)
				# Small diamond
				var pts = PackedVector2Array([
					Vector2(ox, oy - cr),
					Vector2(ox + cr * 0.5, oy),
					Vector2(ox, oy + cr),
					Vector2(ox - cr * 0.5, oy),
				])
				draw_colored_polygon(pts, crystal_col)

		# --- Frozen pipe segments (iced-over pipes) ---
		var frost_line = Color(0.60, 0.75, 0.90, 0.3)
		# Horizontal frozen pipes on top wall
		_draw_pipe(Vector2(WT + 30, 7), Vector2(AW * 0.35, 7), 2.5, rng)
		_draw_pipe(Vector2(AW * 0.65, 7), Vector2(AW - WT - 25, 7), 2.5, rng)
		# Frost coating on pipes (draw over)
		draw_line(Vector2(WT + 30, 5), Vector2(AW * 0.35, 5), frost_line, 1.0)
		draw_line(Vector2(AW * 0.65, 5), Vector2(AW - WT - 25, 5), frost_line, 1.0)

		# --- Frost sparkle dots on walls ---
		for _i in 30:
			var side = rng.randi() % 4
			var sx: float = 0.0
			var sy: float = 0.0
			match side:
				0: sx = rng.randf_range(WT, AW - WT); sy = rng.randf_range(2, WT - 2)
				1: sx = rng.randf_range(WT, AW - WT); sy = rng.randf_range(AH - WT + 2, AH - 2)
				2: sx = rng.randf_range(2, WT - 2); sy = rng.randf_range(WT, AH - WT)
				3: sx = rng.randf_range(AW - WT + 2, AW - 2); sy = rng.randf_range(WT, AH - WT)
			draw_circle(Vector2(sx, sy), rng.randf_range(1, 2), Color(0.7, 0.85, 1.0, 0.3))

	func _draw_clockwork_decorations(rng: RandomNumberGenerator) -> void:
		# --- Massive interlocking gears on walls ---
		for _i in 10:
			var side = rng.randi() % 4
			var gx: float = 0.0
			var gy: float = 0.0
			match side:
				0: gx = rng.randf_range(WT + 10, AW - WT - 10); gy = rng.randf_range(2, WT - 2)
				1: gx = rng.randf_range(WT + 10, AW - WT - 10); gy = rng.randf_range(AH - WT + 2, AH - 2)
				2: gx = rng.randf_range(2, WT - 2); gy = rng.randf_range(WT + 10, AH - WT - 10)
				3: gx = rng.randf_range(AW - WT + 2, AW - 2); gy = rng.randf_range(WT + 10, AH - WT - 10)
			var gear_r = rng.randf_range(5, 10)
			var teeth = rng.randi_range(6, 10)
			_draw_wall_gear(Vector2(gx, gy), gear_r, teeth)

		# --- Pressure gauges (circles with needles) ---
		for _i in 6:
			var side = rng.randi() % 4
			var px: float = 0.0
			var py: float = 0.0
			match side:
				0: px = rng.randf_range(WT + 20, AW - WT - 20); py = rng.randf_range(3, WT - 3)
				1: px = rng.randf_range(WT + 20, AW - WT - 20); py = rng.randf_range(AH - WT + 3, AH - 3)
				2: px = rng.randf_range(3, WT - 3); py = rng.randf_range(WT + 20, AH - WT - 20)
				3: px = rng.randf_range(AW - WT + 3, AW - 3); py = rng.randf_range(WT + 20, AH - WT - 20)
			var gauge_r = rng.randf_range(3, 6)
			# Gauge body
			draw_circle(Vector2(px, py), gauge_r + 1, Color(0.06, 0.05, 0.04, 0.6))
			draw_circle(Vector2(px, py), gauge_r, Color(0.20, 0.18, 0.15, 0.5))
			# Glass face
			draw_circle(Vector2(px, py), gauge_r * 0.8, Color(0.30, 0.35, 0.32, 0.3))
			# Needle
			var needle_angle = rng.randf_range(0.3, 2.5)
			var needle_end = Vector2(px + cos(needle_angle) * gauge_r * 0.7,
									py + sin(needle_angle) * gauge_r * 0.7)
			draw_line(Vector2(px, py), needle_end, Color(0.8, 0.2, 0.1, 0.6), 1.0)

		# --- Steam pipes with joints and valves ---
		# Heavy pipes on all walls
		_draw_pipe(Vector2(WT + 15, 5), Vector2(AW * 0.4, 5), 3.5, rng)
		_draw_pipe(Vector2(AW * 0.55, 5), Vector2(AW - WT - 15, 5), 3.5, rng)
		_draw_pipe(Vector2(WT + 25, AH - 5), Vector2(AW * 0.5, AH - 5), 3.0, rng)
		_draw_pipe(Vector2(AW * 0.6, AH - 5), Vector2(AW - WT - 20, AH - 5), 3.0, rng)
		_draw_pipe(Vector2(5, WT + 20), Vector2(5, AH * 0.4), 3.5, rng)
		_draw_pipe(Vector2(5, AH * 0.55), Vector2(5, AH - WT - 15), 3.0, rng)
		_draw_pipe(Vector2(AW - 5, WT + 25), Vector2(AW - 5, AH * 0.45), 3.5, rng)
		_draw_pipe(Vector2(AW - 5, AH * 0.6), Vector2(AW - 5, AH - WT - 20), 3.0, rng)

		# --- Electrical conduits with spark points ---
		for _i in 8:
			var side = rng.randi() % 4
			var sx: float = 0.0
			var sy: float = 0.0
			match side:
				0: sx = rng.randf_range(WT + 30, AW - WT - 30); sy = rng.randf_range(2, WT - 1)
				1: sx = rng.randf_range(WT + 30, AW - WT - 30); sy = rng.randf_range(AH - WT + 1, AH - 2)
				2: sx = rng.randf_range(2, WT - 1); sy = rng.randf_range(WT + 30, AH - WT - 30)
				3: sx = rng.randf_range(AW - WT + 1, AW - 2); sy = rng.randf_range(WT + 30, AH - WT - 30)
			# Conduit box
			draw_rect(Rect2(sx - 3, sy - 2, 6, 4), Color(0.15, 0.14, 0.12, 0.5))
			# Spark point (bright yellow dot)
			draw_circle(Vector2(sx, sy), 1.5, Color(1.0, 0.9, 0.3, 0.6))
			draw_circle(Vector2(sx, sy), 3.0, Color(1.0, 0.9, 0.3, 0.1))

		# --- Scattered bolts (more than steampunk) ---
		for _i in 40:
			var side = rng.randi() % 4
			var bx: float = 0.0
			var by: float = 0.0
			match side:
				0: bx = rng.randf_range(WT, AW - WT); by = rng.randf_range(3, WT - 3)
				1: bx = rng.randf_range(WT, AW - WT); by = rng.randf_range(AH - WT + 3, AH - 3)
				2: bx = rng.randf_range(3, WT - 3); by = rng.randf_range(WT, AH - WT)
				3: bx = rng.randf_range(AW - WT + 3, AW - 3); by = rng.randf_range(WT, AH - WT)
			_draw_bolt(Vector2(bx, by))

	func _draw_abyss_decorations(rng: RandomNumberGenerator) -> void:
		# --- Shadow tentacles emerging from walls ---
		for _i in 12:
			var side = rng.randi() % 4
			var tx: float = 0.0
			var ty: float = 0.0
			var base_angle: float = 0.0
			match side:
				0:
					tx = rng.randf_range(WT + 15, AW - WT - 15)
					ty = WT
					base_angle = PI / 2.0
				1:
					tx = rng.randf_range(WT + 15, AW - WT - 15)
					ty = AH - WT
					base_angle = -PI / 2.0
				2:
					tx = WT
					ty = rng.randf_range(WT + 15, AH - WT - 15)
					base_angle = 0.0
				3:
					tx = AW - WT
					ty = rng.randf_range(WT + 15, AH - WT - 15)
					base_angle = PI
			var pos = Vector2(tx, ty)
			var angle = base_angle + rng.randf_range(-0.4, 0.4)
			var tentacle_col = Color(0.10, 0.02, 0.18, 0.45)
			var segments = rng.randi_range(4, 8)
			var thickness = rng.randf_range(2.5, 4.0)
			for _s in segments:
				var seg_len = rng.randf_range(5, 14)
				angle += rng.randf_range(-0.5, 0.5)
				var next_pos = pos + Vector2(cos(angle), sin(angle)) * seg_len
				thickness *= 0.85  # taper
				draw_line(pos, next_pos, tentacle_col, thickness)
				pos = next_pos
			# Tip glow
			draw_circle(pos, 2, Color(0.5, 0.1, 0.7, 0.2))

		# --- Void portals (purple circles with dark centers) ---
		for _i in 4:
			var side = rng.randi() % 4
			var px: float = 0.0
			var py: float = 0.0
			match side:
				0: px = rng.randf_range(WT + 30, AW - WT - 30); py = rng.randf_range(3, WT - 2)
				1: px = rng.randf_range(WT + 30, AW - WT - 30); py = rng.randf_range(AH - WT + 2, AH - 3)
				2: px = rng.randf_range(3, WT - 2); py = rng.randf_range(WT + 30, AH - WT - 30)
				3: px = rng.randf_range(AW - WT + 2, AW - 3); py = rng.randf_range(WT + 30, AH - WT - 30)
			var portal_r = rng.randf_range(4, 7)
			# Outer glow
			draw_circle(Vector2(px, py), portal_r + 3, Color(0.5, 0.1, 0.7, 0.1))
			# Purple ring
			var ring_pts = 16
			for s in ring_pts:
				var a1 = TAU * s / float(ring_pts)
				var a2 = TAU * (s + 1) / float(ring_pts)
				draw_line(Vector2(px + cos(a1) * portal_r, py + sin(a1) * portal_r),
						  Vector2(px + cos(a2) * portal_r, py + sin(a2) * portal_r),
						  Color(0.6, 0.15, 0.9, 0.5), 1.5)
			# Dark center
			draw_circle(Vector2(px, py), portal_r * 0.6, Color(0.02, 0.01, 0.03, 0.8))

		# --- Chains hanging from walls ---
		for _i in 8:
			var side = rng.randi() % 2  # top or sides only
			var cx: float = 0.0
			var cy: float = 0.0
			if side == 0:  # top wall
				cx = rng.randf_range(WT + 20, AW - WT - 20)
				cy = WT
			else:  # left or right
				var lr = rng.randi() % 2
				cx = WT if lr == 0 else AW - WT
				cy = rng.randf_range(WT + 20, AH - WT - 20)
			var chain_len = rng.randi_range(4, 8)
			var chain_col = Color(0.15, 0.08, 0.20, 0.4)
			var pos = Vector2(cx, cy)
			for _link in chain_len:
				var link_size = 3.0
				# Chain link (small oval)
				draw_circle(pos, link_size, chain_col)
				draw_circle(pos, link_size * 0.5, Color(chain_col.r + 0.05, chain_col.g + 0.03, chain_col.b + 0.05, 0.2))
				pos += Vector2(rng.randf_range(-1, 1), 5)  # hang down

		# --- Ancient symbols carved into stone (on walls) ---
		for _i in 16:
			var side = rng.randi() % 4
			var sx: float = 0.0
			var sy: float = 0.0
			match side:
				0: sx = rng.randf_range(WT + 10, AW - WT - 10); sy = rng.randf_range(3, WT - 3)
				1: sx = rng.randf_range(WT + 10, AW - WT - 10); sy = rng.randf_range(AH - WT + 3, AH - 3)
				2: sx = rng.randf_range(3, WT - 3); sy = rng.randf_range(WT + 10, AH - WT - 10)
				3: sx = rng.randf_range(AW - WT + 3, AW - 3); sy = rng.randf_range(WT + 10, AH - WT - 10)
			var symbol_size = rng.randf_range(2, 5)
			var sym_col = Color(0.45, 0.12, 0.65, 0.35)
			# Random simple symbol (cross, X, circle, or line)
			var sym_type = rng.randi() % 4
			match sym_type:
				0:  # cross
					draw_line(Vector2(sx - symbol_size, sy), Vector2(sx + symbol_size, sy), sym_col, 1.0)
					draw_line(Vector2(sx, sy - symbol_size), Vector2(sx, sy + symbol_size), sym_col, 1.0)
				1:  # X
					draw_line(Vector2(sx - symbol_size, sy - symbol_size), Vector2(sx + symbol_size, sy + symbol_size), sym_col, 1.0)
					draw_line(Vector2(sx + symbol_size, sy - symbol_size), Vector2(sx - symbol_size, sy + symbol_size), sym_col, 1.0)
				2:  # small circle
					var circ_pts = 8
					for s in circ_pts:
						var a1 = TAU * s / float(circ_pts)
						var a2 = TAU * (s + 1) / float(circ_pts)
						draw_line(Vector2(sx + cos(a1) * symbol_size, sy + sin(a1) * symbol_size),
								  Vector2(sx + cos(a2) * symbol_size, sy + sin(a2) * symbol_size), sym_col, 1.0)
				3:  # triangle
					var tri_pts = [
						Vector2(sx, sy - symbol_size),
						Vector2(sx - symbol_size, sy + symbol_size * 0.7),
						Vector2(sx + symbol_size, sy + symbol_size * 0.7),
					]
					draw_line(tri_pts[0], tri_pts[1], sym_col, 1.0)
					draw_line(tri_pts[1], tri_pts[2], sym_col, 1.0)
					draw_line(tri_pts[2], tri_pts[0], sym_col, 1.0)


# ── 7. TORCH GLOW ───────────────────────────────────────────
# Warm circular light spots around torch positions + ambient fill light

class _TorchGlow extends Node2D:
	var theme: Dictionary = {}

	func _ready() -> void:
		queue_redraw()

	func _draw() -> void:
		var torch_glow = theme.get("torch_glow", Color(1.0, 0.7, 0.3, 0.12))
		var glow_base = Color(torch_glow.r, torch_glow.g, torch_glow.b)

		# Per-torch glow circles (largest to smallest for smooth falloff)
		for torch_data in TORCH_POSITIONS:
			var tp: Vector2 = torch_data["pos"]
			var tw: String = torch_data["wall"]
			# Offset glow into the arena
			var glow_center = tp
			match tw:
				"top":    glow_center += Vector2(0, 30)
				"bottom": glow_center += Vector2(0, -30)
				"left":   glow_center += Vector2(30, 0)
				"right":  glow_center += Vector2(-30, 0)

			# Large outer glow
			draw_circle(glow_center, 80, Color(glow_base.r, glow_base.g, glow_base.b, 0.03))
			draw_circle(glow_center, 55, Color(glow_base.r, glow_base.g, glow_base.b, 0.04))
			draw_circle(glow_center, 35, Color(glow_base.r, glow_base.g, glow_base.b, 0.05))
			draw_circle(glow_center, 20, Color(glow_base.r, glow_base.g, glow_base.b + 0.05, 0.06))
			draw_circle(glow_center, 10, Color(glow_base.r, glow_base.g + 0.1, glow_base.b + 0.1, 0.08))

		# General ambient fill in center of arena
		var center = Vector2(AW / 2.0, AH / 2.0)
		draw_circle(center, 250, Color(glow_base.r, glow_base.g + 0.15, glow_base.b + 0.2, 0.015))
		draw_circle(center, 150, Color(glow_base.r, glow_base.g + 0.15, glow_base.b + 0.2, 0.02))


# ── 8. VIGNETTE ─────────────────────────────────────────────
# Darken edges of the arena for depth and focus

class _Vignette extends Node2D:
	func _ready() -> void:
		queue_redraw()

	func _draw() -> void:
		var depth = 80.0
		var bands = 30
		for i in bands:
			var t = float(i) / float(bands)
			var alpha = (1.0 - t) * 0.20
			var thick = depth / float(bands)
			var col = Color(0.0, 0.0, 0.0, alpha)
			# Top
			draw_rect(Rect2(WT, WT + i * thick, AW - WT * 2, thick), col)
			# Bottom
			draw_rect(Rect2(WT, AH - WT - (i + 1) * thick, AW - WT * 2, thick), col)
			# Left
			draw_rect(Rect2(WT + i * thick, WT, thick, AH - WT * 2), col)
			# Right
			draw_rect(Rect2(AW - WT - (i + 1) * thick, WT, thick, AH - WT * 2), col)


# ── 9. AMBIENT PARTICLES ────────────────────────────────────
# Theme-dependent: dust/embers, spores/motes, embers/ash

class _AmbientParticles extends Node2D:
	var theme: Dictionary = {}
	var _dust_motes: Array = []     # {pos, vel, size, alpha, color}
	var _embers: Array = []         # {pos, vel, life, max_life, size}
	var _steam_wisps: Array = []    # {pos, vel, life, max_life, size, alpha}
	var _time: float = 0.0

	func _ready() -> void:
		var rng = RandomNumberGenerator.new()
		rng.seed = 12345

		var particle_type = theme.get("particle_type", "dust_and_embers")

		match particle_type:
			"dust_and_embers":
				_init_dust_and_embers(rng)
			"spores_and_motes":
				_init_spores_and_motes(rng)
			"embers_and_ash":
				_init_embers_and_ash(rng)
			"snow_and_ice":
				_init_snow_and_ice(rng)
			"sparks_and_steam":
				_init_sparks_and_steam(rng)
			"void_motes":
				_init_void_motes(rng)

	func _init_dust_and_embers(rng: RandomNumberGenerator) -> void:
		# Create dust motes
		for _i in 40:
			_dust_motes.append({
				"pos": Vector2(rng.randf_range(WT + 5, AW - WT - 5),
							   rng.randf_range(WT + 5, AH - WT - 5)),
				"vel": Vector2(rng.randf_range(-3, 3), rng.randf_range(-2, 2)),
				"size": rng.randf_range(0.5, 2.0),
				"alpha": rng.randf_range(0.1, 0.3),
				"phase": rng.randf_range(0, TAU),
				"color": Color(0.8, 0.7, 0.5),
			})

		# Create embers near torches
		for torch_data in TORCH_POSITIONS:
			var tp: Vector2 = torch_data["pos"]
			for _j in 3:
				_embers.append({
					"origin": tp,
					"pos": tp + Vector2(rng.randf_range(-5, 5), rng.randf_range(-5, 5)),
					"vel": Vector2(rng.randf_range(-8, 8), rng.randf_range(-20, -5)),
					"life": rng.randf_range(0, 2.0),
					"max_life": rng.randf_range(1.5, 3.0),
					"size": rng.randf_range(0.5, 1.5),
					"type": "ember",
				})

		# Steam wisps
		var vent_spots = [
			Vector2(AW * 0.25, AH - WT - 5),
			Vector2(AW * 0.75, AH - WT - 5),
			Vector2(WT + 5, AH * 0.5),
		]
		for vp in vent_spots:
			for _j in 4:
				_steam_wisps.append({
					"origin": vp,
					"pos": vp,
					"vel": Vector2(rng.randf_range(-2, 2), rng.randf_range(-15, -5)),
					"life": rng.randf_range(0, 3.0),
					"max_life": rng.randf_range(2.0, 4.0),
					"size": rng.randf_range(3, 8),
					"alpha": rng.randf_range(0.05, 0.12),
				})

	func _init_spores_and_motes(rng: RandomNumberGenerator) -> void:
		# Green-tinted floating spores — slower, slight upward drift
		for _i in 55:
			_dust_motes.append({
				"pos": Vector2(rng.randf_range(WT + 5, AW - WT - 5),
							   rng.randf_range(WT + 5, AH - WT - 5)),
				"vel": Vector2(rng.randf_range(-1.5, 1.5), rng.randf_range(-2, -0.3)),
				"size": rng.randf_range(0.8, 2.5),
				"alpha": rng.randf_range(0.12, 0.35),
				"phase": rng.randf_range(0, TAU),
				"color": Color(0.3, 0.85, 0.4),
			})

		# Brighter glowing motes (fewer, larger)
		for _i in 12:
			_embers.append({
				"origin": Vector2(rng.randf_range(WT + 20, AW - WT - 20),
								  rng.randf_range(WT + 20, AH - WT - 20)),
				"pos": Vector2(rng.randf_range(WT + 20, AW - WT - 20),
							   rng.randf_range(WT + 20, AH - WT - 20)),
				"vel": Vector2(rng.randf_range(-2, 2), rng.randf_range(-3, -0.5)),
				"life": rng.randf_range(0, 3.0),
				"max_life": rng.randf_range(3.0, 5.0),
				"size": rng.randf_range(1.5, 3.0),
				"type": "spore_glow",
			})

	func _init_embers_and_ash(rng: RandomNumberGenerator) -> void:
		# More particles, orange-red, faster upward
		for _i in 20:
			_dust_motes.append({
				"pos": Vector2(rng.randf_range(WT + 5, AW - WT - 5),
							   rng.randf_range(WT + 5, AH - WT - 5)),
				"vel": Vector2(rng.randf_range(-2, 2), rng.randf_range(-1, 1)),
				"size": rng.randf_range(0.5, 1.5),
				"alpha": rng.randf_range(0.08, 0.2),
				"phase": rng.randf_range(0, TAU),
				"color": Color(0.5, 0.45, 0.4),  # gray ash
			})

		# Lots of embers rising fast
		for _i in 60:
			var origin = Vector2(rng.randf_range(WT + 10, AW - WT - 10),
								 rng.randf_range(AH * 0.4, AH - WT - 5))
			_embers.append({
				"origin": origin,
				"pos": origin + Vector2(rng.randf_range(-10, 10), rng.randf_range(-10, 10)),
				"vel": Vector2(rng.randf_range(-10, 10), rng.randf_range(-30, -8)),
				"life": rng.randf_range(0, 2.5),
				"max_life": rng.randf_range(1.5, 3.5),
				"size": rng.randf_range(0.5, 2.0),
				"type": "hot_ember",
			})

		# Some gray ash falling down
		for _i in 15:
			var origin = Vector2(rng.randf_range(WT + 10, AW - WT - 10),
								 rng.randf_range(WT + 5, AH * 0.3))
			_steam_wisps.append({
				"origin": origin,
				"pos": origin,
				"vel": Vector2(rng.randf_range(-1.5, 1.5), rng.randf_range(3, 10)),
				"life": rng.randf_range(0, 3.0),
				"max_life": rng.randf_range(3.0, 5.0),
				"size": rng.randf_range(1, 3),
				"alpha": rng.randf_range(0.06, 0.15),
			})

	func _init_snow_and_ice(rng: RandomNumberGenerator) -> void:
		# Snowflakes — white dots drifting down slowly
		for _i in 50:
			_dust_motes.append({
				"pos": Vector2(rng.randf_range(WT + 5, AW - WT - 5),
							   rng.randf_range(WT + 5, AH - WT - 5)),
				"vel": Vector2(rng.randf_range(-1.5, 1.5), rng.randf_range(3, 10)),
				"size": rng.randf_range(0.8, 2.5),
				"alpha": rng.randf_range(0.15, 0.4),
				"phase": rng.randf_range(0, TAU),
				"color": Color(0.85, 0.90, 1.0),
			})

		# Ice sparkles — bright blue-white dots that twinkle
		for _i in 20:
			_embers.append({
				"origin": Vector2(rng.randf_range(WT + 15, AW - WT - 15),
								  rng.randf_range(WT + 15, AH - WT - 15)),
				"pos": Vector2(rng.randf_range(WT + 15, AW - WT - 15),
							   rng.randf_range(WT + 15, AH - WT - 15)),
				"vel": Vector2(rng.randf_range(-0.5, 0.5), rng.randf_range(-0.5, 0.5)),
				"life": rng.randf_range(0, 3.0),
				"max_life": rng.randf_range(2.0, 4.5),
				"size": rng.randf_range(1.0, 2.5),
				"type": "ice_sparkle",
			})

	func _init_sparks_and_steam(rng: RandomNumberGenerator) -> void:
		# Electric sparks — bright yellow, fast, erratic
		for _i in 30:
			var origin = Vector2(rng.randf_range(WT + 10, AW - WT - 10),
								 rng.randf_range(WT + 10, AH - WT - 10))
			_embers.append({
				"origin": origin,
				"pos": origin + Vector2(rng.randf_range(-5, 5), rng.randf_range(-5, 5)),
				"vel": Vector2(rng.randf_range(-25, 25), rng.randf_range(-25, 25)),
				"life": rng.randf_range(0, 1.5),
				"max_life": rng.randf_range(0.5, 1.8),
				"size": rng.randf_range(0.5, 1.5),
				"type": "electric_spark",
			})

		# Steam clouds — white, rising slowly, fading
		for _i in 12:
			var origin = Vector2(rng.randf_range(WT + 20, AW - WT - 20),
								 rng.randf_range(AH * 0.4, AH - WT - 5))
			_steam_wisps.append({
				"origin": origin,
				"pos": origin,
				"vel": Vector2(rng.randf_range(-2, 2), rng.randf_range(-12, -4)),
				"life": rng.randf_range(0, 3.0),
				"max_life": rng.randf_range(2.5, 4.5),
				"size": rng.randf_range(4, 10),
				"alpha": rng.randf_range(0.06, 0.14),
			})

		# Small gear fragments falling
		for _i in 10:
			_dust_motes.append({
				"pos": Vector2(rng.randf_range(WT + 5, AW - WT - 5),
							   rng.randf_range(WT + 5, AH - WT - 5)),
				"vel": Vector2(rng.randf_range(-2, 2), rng.randf_range(2, 8)),
				"size": rng.randf_range(0.8, 2.0),
				"alpha": rng.randf_range(0.1, 0.25),
				"phase": rng.randf_range(0, TAU),
				"color": Color(0.5, 0.45, 0.35),
			})

	func _init_void_motes(rng: RandomNumberGenerator) -> void:
		# Shadow wisps — near-black, drifting horizontally
		for _i in 25:
			_dust_motes.append({
				"pos": Vector2(rng.randf_range(WT + 5, AW - WT - 5),
							   rng.randf_range(WT + 5, AH - WT - 5)),
				"vel": Vector2(rng.randf_range(-3, 3), rng.randf_range(-1, 1)),
				"size": rng.randf_range(1.0, 3.0),
				"alpha": rng.randf_range(0.12, 0.30),
				"phase": rng.randf_range(0, TAU),
				"color": Color(0.08, 0.02, 0.12),
			})

		# Floating void orbs — dark purple with bright purple core, slow orbit
		for _i in 15:
			var origin = Vector2(rng.randf_range(WT + 30, AW - WT - 30),
								 rng.randf_range(WT + 30, AH - WT - 30))
			_embers.append({
				"origin": origin,
				"pos": origin + Vector2(rng.randf_range(-10, 10), rng.randf_range(-10, 10)),
				"vel": Vector2(rng.randf_range(-2, 2), rng.randf_range(-2, 2)),
				"life": rng.randf_range(0, 4.0),
				"max_life": rng.randf_range(4.0, 7.0),
				"size": rng.randf_range(1.5, 3.5),
				"type": "void_orb",
			})

		# Occasional bright purple flash particles
		for _i in 6:
			var origin = Vector2(rng.randf_range(WT + 20, AW - WT - 20),
								 rng.randf_range(WT + 20, AH - WT - 20))
			_steam_wisps.append({
				"origin": origin,
				"pos": origin,
				"vel": Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1)),
				"life": rng.randf_range(0, 2.0),
				"max_life": rng.randf_range(1.0, 2.5),
				"size": rng.randf_range(2, 5),
				"alpha": rng.randf_range(0.2, 0.5),
			})

	func _process(delta: float) -> void:
		_time += delta
		var particle_type = theme.get("particle_type", "dust_and_embers")

		# Update dust motes (gentle floating)
		for mote in _dust_motes:
			mote["pos"] += mote["vel"] * delta
			# Gentle sine wave drift
			mote["pos"].x += sin(_time * 0.5 + mote["phase"]) * 0.3
			# Wrap around
			if mote["pos"].x < WT + 2: mote["pos"].x = AW - WT - 2
			if mote["pos"].x > AW - WT - 2: mote["pos"].x = WT + 2
			if mote["pos"].y < WT + 2: mote["pos"].y = AH - WT - 2
			if mote["pos"].y > AH - WT - 2: mote["pos"].y = WT + 2

		# Update embers / glowing particles (rise and die)
		for ember in _embers:
			ember["life"] += delta
			if ember["life"] >= ember["max_life"]:
				ember["life"] = 0.0
				ember["pos"] = ember["origin"] + Vector2(randf_range(-5, 5), randf_range(-3, 3))
				match particle_type:
					"spores_and_motes":
						ember["vel"] = Vector2(randf_range(-2, 2), randf_range(-3, -0.5))
					"embers_and_ash":
						ember["vel"] = Vector2(randf_range(-10, 10), randf_range(-30, -8))
					"snow_and_ice":
						ember["vel"] = Vector2(randf_range(-0.5, 0.5), randf_range(-0.5, 0.5))
					"sparks_and_steam":
						ember["vel"] = Vector2(randf_range(-25, 25), randf_range(-25, 25))
					"void_motes":
						ember["vel"] = Vector2(randf_range(-2, 2), randf_range(-2, 2))
					_:
						ember["vel"] = Vector2(randf_range(-8, 8), randf_range(-20, -5))
			ember["pos"] += ember["vel"] * delta
			var drift_strength = 5.0
			if particle_type == "sparks_and_steam":
				drift_strength = 15.0
			elif particle_type == "snow_and_ice" or particle_type == "void_motes":
				drift_strength = 1.5
			ember["vel"].x += randf_range(-drift_strength, drift_strength) * delta

		# Update steam wisps / falling ash
		for wisp in _steam_wisps:
			wisp["life"] += delta
			if wisp["life"] >= wisp["max_life"]:
				wisp["life"] = 0.0
				wisp["pos"] = wisp["origin"] + Vector2(randf_range(-3, 3), 0)
				match particle_type:
					"embers_and_ash":
						wisp["vel"] = Vector2(randf_range(-1.5, 1.5), randf_range(3, 10))
					"sparks_and_steam":
						wisp["vel"] = Vector2(randf_range(-2, 2), randf_range(-12, -4))
					"void_motes":
						wisp["vel"] = Vector2(randf_range(-1, 1), randf_range(-1, 1))
					_:
						wisp["vel"] = Vector2(randf_range(-2, 2), randf_range(-15, -5))
				match particle_type:
					"embers_and_ash":
						wisp["size"] = randf_range(1, 3)
					"void_motes":
						wisp["size"] = randf_range(2, 5)
					"sparks_and_steam":
						wisp["size"] = randf_range(4, 10)
					_:
						wisp["size"] = randf_range(3, 8)
			wisp["pos"] += wisp["vel"] * delta
			if particle_type == "sparks_and_steam" or (particle_type != "embers_and_ash" and particle_type != "void_motes"):
				wisp["size"] += delta * 2  # expand as it rises

		queue_redraw()

	func _draw() -> void:
		var particle_type = theme.get("particle_type", "dust_and_embers")

		# Draw dust motes / spores / ash
		for mote in _dust_motes:
			var pulse = sin(_time * 1.2 + mote["phase"]) * 0.5 + 0.5
			var a = mote["alpha"] * (0.5 + pulse * 0.5)
			var c: Color = mote.get("color", Color(0.8, 0.7, 0.5))
			draw_circle(mote["pos"], mote["size"], Color(c.r, c.g, c.b, a))

		# Draw embers / glowing motes
		for ember in _embers:
			var t = ember["life"] / ember["max_life"]
			var a = (1.0 - t) * 0.8  # fade out
			if a <= 0: continue
			var ember_type = ember.get("type", "ember")
			var col: Color
			match ember_type:
				"spore_glow":
					col = Color(0.2, 0.9, 0.4, a * 0.6)
				"hot_ember":
					col = Color(1.0, 0.35 + (1.0 - t) * 0.5, 0.05, a)
				"ice_sparkle":
					# Twinkle effect — sharp pulse
					var twinkle = sin(_time * 4.0 + ember["life"] * 8.0) * 0.5 + 0.5
					col = Color(0.6, 0.8, 1.0, a * 0.5 * twinkle)
				"electric_spark":
					col = Color(1.0, 0.9, 0.3, a)
				"void_orb":
					col = Color(0.35, 0.08, 0.55, a * 0.6)
				_:
					col = Color(1.0, 0.5 + (1.0 - t) * 0.4, 0.1, a)
			var sz = ember["size"] * (1.0 - t * 0.5)
			if ember_type == "spore_glow":
				# Draw glow halo for spores
				draw_circle(ember["pos"], sz + 2, Color(col.r, col.g, col.b, a * 0.15))
			elif ember_type == "ice_sparkle":
				# Bright core with soft halo
				draw_circle(ember["pos"], sz + 1.5, Color(0.5, 0.7, 1.0, a * 0.08))
			elif ember_type == "void_orb":
				# Dark purple outer with bright purple core
				draw_circle(ember["pos"], sz + 3, Color(0.2, 0.03, 0.35, a * 0.15))
				draw_circle(ember["pos"], sz * 0.4, Color(0.7, 0.3, 1.0, a * 0.5))
			draw_circle(ember["pos"], sz, col)

		# Draw steam wisps / falling ash
		for wisp in _steam_wisps:
			var t = wisp["life"] / wisp["max_life"]
			var a = wisp["alpha"] * (1.0 - t)  # fade out
			if a <= 0.005: continue
			var s: float = wisp["size"]
			if particle_type == "embers_and_ash":
				# Gray ash particles
				draw_circle(wisp["pos"], s, Color(0.4, 0.38, 0.35, a))
			elif particle_type == "void_motes":
				# Bright purple flash particles
				var flash = sin(_time * 3.0 + wisp["life"] * 5.0) * 0.5 + 0.5
				draw_circle(wisp["pos"], s, Color(0.6, 0.15, 0.9, a * flash))
				draw_circle(wisp["pos"], s * 0.4, Color(0.8, 0.4, 1.0, a * flash * 0.6))
			elif particle_type == "sparks_and_steam":
				# White steam clouds
				draw_circle(wisp["pos"], s, Color(0.7, 0.7, 0.75, a))
				draw_circle(wisp["pos"] + Vector2(s * 0.3, -s * 0.2), s * 0.6,
							Color(0.7, 0.7, 0.75, a * 0.5))
			else:
				draw_circle(wisp["pos"], s, Color(0.6, 0.6, 0.65, a))
				# Secondary smaller puff
				draw_circle(wisp["pos"] + Vector2(s * 0.3, -s * 0.2), s * 0.6,
							Color(0.6, 0.6, 0.65, a * 0.5))
