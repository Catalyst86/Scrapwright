extends Node2D

# ============================================================
# TutorialArena — Interactive first-run tutorial (v2)
# 7 steps, each requiring real gameplay actions (3x repetition).
# Skippable at any point.
# ============================================================

const ROOM_W := 840
const ROOM_H := 600
const WALL_THICK := 16

# UI colours (match existing codebase palette)
const CLR_PANEL_BG  := Color(0.12, 0.09, 0.06, 0.95)
const CLR_BORDER    := Color(0.55, 0.42, 0.22)
const CLR_GOLD      := Color(0.95, 0.82, 0.35)
const CLR_SILVER    := Color(0.78, 0.78, 0.82)
const CLR_DIM       := Color(0.55, 0.55, 0.55)
const CLR_GREEN     := Color(0.3, 0.9, 0.4)
const CLR_FLOOR     := Color(0.10, 0.08, 0.06)
const CLR_WALL      := Color(0.22, 0.18, 0.14)
const CLR_SKIP_NORM := Color(0.18, 0.15, 0.12, 0.85)
const CLR_SKIP_HOV  := Color(0.25, 0.20, 0.15, 0.92)

# Material colours (matches material_pickup.gd)
const MAT_COLORS := {
	"iron_scrap": Color(0.55, 0.70, 0.85),
	"timber":     Color(0.60, 0.40, 0.18),
	"fuel":       Color(0.95, 0.75, 0.10),
	"organic":    Color(0.25, 0.75, 0.20),
	"stone":      Color(0.55, 0.52, 0.50),
	"blueprint":  Color(0.30, 0.50, 0.95),
}
const MAT_NAMES := {
	"iron_scrap": "Iron", "timber": "Wood", "fuel": "Fuel",
	"organic": "Herb", "stone": "Stone", "blueprint": "Blueprint",
}

# ─── Step enum ──────────────────────────────────────────────
enum Step {
	MOVEMENT,
	DODGE,
	BITE,
	SNEAK,
	DIG_TRAP,
	SALVAGE,
	COMPLETE,
}

const STEP_DATA = {
	Step.MOVEMENT: {
		"title": "MOVEMENT",
		"key_label": "[ W A S D ]",
		"desc": "Use WASD to move around the room.",
		"reps": 0,
	},
	Step.DODGE: {
		"title": "DODGE",
		"key_label": "[ SPACE ]",
		"desc": "An enemy is shooting at you! Press SPACE to dodge the projectiles!",
		"reps": 3,
	},
	Step.BITE: {
		"title": "BITE",
		"key_label": "[ AUTO ]",
		"desc": "Walk near each target dummy — your pup bites automatically!",
		"reps": 3,
	},
	Step.SNEAK: {
		"title": "SNEAK AMBUSH",
		"key_label": "[ CTRL ]",
		"desc": "Hold CTRL to sneak, then let your pup bite for 2x damage!",
		"reps": 3,
	},
	Step.DIG_TRAP: {
		"title": "DIG TRAP",
		"key_label": "[ F ]",
		"desc": "Press F to dig a trap hole, then lure the enemy into it!",
		"reps": 3,
	},
	Step.SALVAGE: {
		"title": "SALVAGE",
		"key_label": "[ SHIFT ]",
		"desc": "Press SHIFT near each crate to salvage materials!",
		"reps": 3,
	},
	Step.COMPLETE: {
		"title": "TUTORIAL COMPLETE!",
		"key_label": "",
		"desc": "You're ready, pup! Good luck out there!",
		"reps": 0,
	},
}

# ─── State ──────────────────────────────────────────────────
var _current_step: int = -1
var _step_active: bool = false
var _step_completed: bool = false
var _transitioning: bool = false

# Repetition tracking
var _rep_count: int = 0
var _rep_target: int = 0

# Movement
var _distance_moved: float = 0.0
var _last_player_pos: Vector2 = Vector2.ZERO

# Dodge
var _shooter_node: Node = null
var _prev_leaping: bool = false

# Sneak ambush
var _prev_ambush_ready: bool = false
var _ambush_dummy: Node = null  # Real enemy used for ambush practice

# Dig trap
var _active_walker: Node = null  # Real enemy that walks toward player

# Salvage sub-phase: 0 = breaking props, 1 = waiting for ESC, 2 = showing overlay
var _salvage_phase: int = 0
var _props_broken: int = 0
var _inventory_overlay: CanvasLayer = null
var _arrow_time: float = 0.0

# ─── Node refs ──────────────────────────────────────────────
var _player: CharacterBody2D = null
var _enemies_container: Node2D = null
var _props_container: Node2D = null
var _ui_layer: CanvasLayer = null
var _panel: PanelContainer = null
var _title_label: Label = null
var _key_label: Label = null
var _desc_label: Label = null
var _counter_label: Label = null
var _check_label: Label = null
var _step_label: Label = null
var _skip_btn: Button = null
var _fade_rect: ColorRect = null
var _room_center: Vector2 = Vector2.ZERO

# ════════════════════════════════════════════════════════════
# LIFECYCLE
# ════════════════════════════════════════════════════════════

func _ready() -> void:
	var vp = Vector2(
		ProjectSettings.get_setting("display/window/size/viewport_width", 960),
		ProjectSettings.get_setting("display/window/size/viewport_height", 540)
	)
	_room_center = vp / 2.0

	_build_room()
	_spawn_player()
	_build_ui()
	GameState.set_phase(GameState.Phase.ARENA_COMBAT)
	# Brief delay before first step
	var tw = create_tween()
	tw.tween_interval(0.4)
	tw.tween_callback(_advance_step)

# ════════════════════════════════════════════════════════════
# ROOM
# ════════════════════════════════════════════════════════════

func _build_room() -> void:
	var origin = _room_center - Vector2(ROOM_W, ROOM_H) / 2.0

	var floor_rect = ColorRect.new()
	floor_rect.color = CLR_FLOOR
	floor_rect.size = Vector2(ROOM_W, ROOM_H)
	floor_rect.position = origin
	floor_rect.z_index = -10
	add_child(floor_rect)

	# Grid lines
	for i in range(1, 14):
		var vline = ColorRect.new()
		vline.color = Color(0.14, 0.11, 0.08)
		vline.size = Vector2(1, ROOM_H)
		vline.position = origin + Vector2(i * (ROOM_W / 14.0), 0)
		vline.z_index = -9
		add_child(vline)
	for i in range(1, 10):
		var hline = ColorRect.new()
		hline.color = Color(0.14, 0.11, 0.08)
		hline.size = Vector2(ROOM_W, 1)
		hline.position = origin + Vector2(0, i * (ROOM_H / 10.0))
		hline.z_index = -9
		add_child(hline)

	# Walls
	_add_wall(origin + Vector2(0, -WALL_THICK), Vector2(ROOM_W, WALL_THICK))
	_add_wall(origin + Vector2(0, ROOM_H), Vector2(ROOM_W, WALL_THICK))
	_add_wall(origin + Vector2(-WALL_THICK, -WALL_THICK), Vector2(WALL_THICK, ROOM_H + WALL_THICK * 2))
	_add_wall(origin + Vector2(ROOM_W, -WALL_THICK), Vector2(WALL_THICK, ROOM_H + WALL_THICK * 2))

	_enemies_container = Node2D.new()
	_enemies_container.name = "Enemies"
	add_child(_enemies_container)

	_props_container = Node2D.new()
	_props_container.name = "PropsContainer"
	add_child(_props_container)

func _add_wall(pos: Vector2, sz: Vector2) -> void:
	var wall = StaticBody2D.new()
	wall.position = pos
	wall.collision_layer = 1
	wall.collision_mask = 0
	var shape = RectangleShape2D.new()
	shape.size = sz
	var col = CollisionShape2D.new()
	col.shape = shape
	col.position = sz / 2.0
	wall.add_child(col)
	var vis = ColorRect.new()
	vis.color = CLR_WALL
	vis.size = sz
	wall.add_child(vis)
	add_child(wall)

func _spawn_player() -> void:
	var player_scene = load("res://scenes/player.tscn")
	_player = player_scene.instantiate()
	_player.position = _room_center
	add_child(_player)
	_last_player_pos = _player.position

# ════════════════════════════════════════════════════════════
# UI
# ════════════════════════════════════════════════════════════

func _build_ui() -> void:
	_ui_layer = CanvasLayer.new()
	_ui_layer.layer = 25
	_ui_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_ui_layer)

	# Vignette
	var vignette = ColorRect.new()
	vignette.color = Color(0, 0, 0, 0.25)
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui_layer.add_child(vignette)

	# Instruction panel (upper-center)
	_panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = CLR_PANEL_BG
	style.border_color = CLR_BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(14)
	_panel.add_theme_stylebox_override("panel", style)
	_panel.custom_minimum_size = Vector2(380, 0)
	_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_panel.position.y = 12
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui_layer.add_child(_panel)

	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 5)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(vbox)

	_title_label = Label.new()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 20)
	_title_label.add_theme_color_override("font_color", CLR_GOLD)
	_title_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	_title_label.add_theme_constant_override("shadow_offset_x", 1)
	_title_label.add_theme_constant_override("shadow_offset_y", 1)
	vbox.add_child(_title_label)

	_key_label = Label.new()
	_key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_key_label.add_theme_font_size_override("font_size", 24)
	_key_label.add_theme_color_override("font_color", Color.WHITE)
	_key_label.add_theme_color_override("font_shadow_color", Color(0.3, 0.25, 0.1, 0.6))
	_key_label.add_theme_constant_override("shadow_offset_x", 1)
	_key_label.add_theme_constant_override("shadow_offset_y", 2)
	vbox.add_child(_key_label)

	var sep = ColorRect.new()
	sep.color = CLR_BORDER.darkened(0.3)
	sep.custom_minimum_size = Vector2(0, 1)
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(sep)

	_desc_label = Label.new()
	_desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_desc_label.add_theme_font_size_override("font_size", 12)
	_desc_label.add_theme_color_override("font_color", CLR_SILVER)
	_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_desc_label.custom_minimum_size = Vector2(340, 0)
	vbox.add_child(_desc_label)

	_counter_label = Label.new()
	_counter_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_counter_label.add_theme_font_size_override("font_size", 16)
	_counter_label.add_theme_color_override("font_color", CLR_GOLD)
	_counter_label.text = ""
	vbox.add_child(_counter_label)

	_check_label = Label.new()
	_check_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_check_label.add_theme_font_size_override("font_size", 14)
	_check_label.add_theme_color_override("font_color", CLR_GREEN)
	_check_label.text = ""
	vbox.add_child(_check_label)

	# Step counter (bottom-right)
	_step_label = Label.new()
	_step_label.add_theme_font_size_override("font_size", 11)
	_step_label.add_theme_color_override("font_color", CLR_DIM)
	_step_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_step_label.position = Vector2(-60, -18)
	_step_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui_layer.add_child(_step_label)

	# Skip button (top-right)
	_skip_btn = Button.new()
	_skip_btn.text = "Skip Tutorial"
	_skip_btn.add_theme_font_size_override("font_size", 11)
	_skip_btn.add_theme_color_override("font_color", CLR_DIM)
	_skip_btn.add_theme_color_override("font_hover_color", CLR_GOLD)
	var skip_normal = StyleBoxFlat.new()
	skip_normal.bg_color = CLR_SKIP_NORM
	skip_normal.border_color = CLR_BORDER.darkened(0.3)
	skip_normal.set_border_width_all(1)
	skip_normal.set_corner_radius_all(3)
	skip_normal.set_content_margin_all(6)
	_skip_btn.add_theme_stylebox_override("normal", skip_normal)
	var skip_hover = skip_normal.duplicate()
	skip_hover.bg_color = CLR_SKIP_HOV
	skip_hover.border_color = CLR_GOLD.darkened(0.3)
	_skip_btn.add_theme_stylebox_override("hover", skip_hover)
	_skip_btn.add_theme_stylebox_override("pressed", skip_hover)
	_skip_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_skip_btn.position = Vector2(-110, 10)
	_skip_btn.pressed.connect(_finish_tutorial)
	_ui_layer.add_child(_skip_btn)

	# Full-screen fade rect
	_fade_rect = ColorRect.new()
	_fade_rect.color = Color(0, 0, 0, 0)
	_fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_rect.z_index = 100
	_ui_layer.add_child(_fade_rect)

	_panel.modulate.a = 0.0

# ════════════════════════════════════════════════════════════
# STEP MANAGEMENT
# ════════════════════════════════════════════════════════════

func _advance_step() -> void:
	# Cleanup previous step
	_cleanup_step()

	_current_step += 1
	if _current_step >= Step.size():
		_finish_tutorial()
		return

	var data = STEP_DATA[_current_step]
	_step_completed = false
	_step_active = true
	_rep_count = 0
	_rep_target = data.reps
	_distance_moved = 0.0
	_prev_leaping = false
	_prev_ambush_ready = false
	_salvage_phase = 0
	_props_broken = 0
	if _player:
		_last_player_pos = _player.position

	# Setup entities for this step
	match _current_step:
		Step.DODGE:    _setup_dodge()
		Step.BITE:     _setup_bite()
		Step.SNEAK:    _setup_sneak()
		Step.DIG_TRAP: _setup_dig_trap()
		Step.SALVAGE:  _setup_salvage()

	# Update UI
	_title_label.text = data.title
	_key_label.text = data.key_label
	_key_label.visible = not data.key_label.is_empty()
	_desc_label.text = data.desc
	_check_label.text = ""
	_update_counter()
	_step_label.text = "%d / %d" % [_current_step + 1, Step.size()]

	# Animate panel in
	_panel.modulate.a = 0.0
	_panel.scale = Vector2(0.9, 0.9)
	_refresh_panel_pivot.call_deferred()
	var tw = create_tween()
	tw.set_parallel(true)
	tw.tween_property(_panel, "modulate:a", 1.0, 0.25).set_ease(Tween.EASE_OUT)
	tw.tween_property(_panel, "scale", Vector2.ONE, 0.25).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

func _update_counter() -> void:
	if _rep_target > 0:
		_counter_label.text = "%d / %d" % [_rep_count, _rep_target]
		_counter_label.visible = true
	else:
		_counter_label.text = ""
		_counter_label.visible = false

func _increment_rep() -> void:
	_rep_count += 1
	_update_counter()
	if _rep_count >= _rep_target:
		_complete_current_step()

func _complete_current_step() -> void:
	if _step_completed or _transitioning:
		return
	_step_completed = true
	_step_active = false
	_check_label.text = "Done!"

	_transitioning = true
	var tw = create_tween()
	tw.tween_interval(0.7)
	tw.tween_property(_panel, "modulate:a", 0.0, 0.15)
	tw.tween_interval(0.2)
	tw.tween_callback(func():
		_transitioning = false
		_advance_step()
	)

func _refresh_panel_pivot() -> void:
	if _panel:
		_panel.pivot_offset = _panel.size / 2.0

func _cleanup_step() -> void:
	# Remove shooter
	if _shooter_node and is_instance_valid(_shooter_node):
		_shooter_node.queue_free()
		_shooter_node = null
	# Remove active walker
	if _active_walker and is_instance_valid(_active_walker):
		_active_walker.queue_free()
		_active_walker = null
	# Remove ambush dummy
	if _ambush_dummy and is_instance_valid(_ambush_dummy):
		_ambush_dummy.queue_free()
		_ambush_dummy = null
	# Clear remaining enemies
	for child in _enemies_container.get_children():
		child.queue_free()
	# Clear remaining props
	for child in _props_container.get_children():
		child.queue_free()
	# Clear stray projectiles
	for child in get_children():
		if child.is_in_group("projectiles"):
			child.queue_free()
	# Remove inventory overlay
	_dismiss_inventory_overlay()

# ════════════════════════════════════════════════════════════
# STEP SETUPS
# ════════════════════════════════════════════════════════════

# Helper: configure a real enemy for tutorial use (low damage, no nav, no XP)
func _configure_enemy(enemy: Node, hp: int, dmg: int, spd: float) -> void:
	enemy.max_health = hp
	enemy.health = hp
	enemy.damage = dmg
	enemy.xp_value = 0
	enemy.move_speed = spd
	if enemy.health_bar:
		enemy.health_bar.max_value = hp
		enemy.health_bar.value = hp
	# Strip NavigationAgent2D to avoid pathfinding without a baked NavRegion
	var nav = enemy.get_node_or_null("NavigationAgent2D")
	if nav:
		nav.queue_free()
		enemy.nav_agent = null

func _random_room_pos(offset_from_player: float = 120.0) -> Vector2:
	var angle = randf() * TAU
	var offset = Vector2(cos(angle), sin(angle)) * offset_from_player
	var pos = _player.position + offset if _player else _room_center + offset
	var half = Vector2(ROOM_W, ROOM_H) / 2.0 - Vector2(40, 40)
	pos.x = clampf(pos.x, _room_center.x - half.x, _room_center.x + half.x)
	pos.y = clampf(pos.y, _room_center.y - half.y, _room_center.y + half.y)
	return pos

func _room_edge_pos() -> Vector2:
	var side = randi() % 4
	var half = Vector2(ROOM_W, ROOM_H) / 2.0 - Vector2(50, 50)
	match side:
		0: return _room_center + Vector2(randf_range(-half.x, half.x), -half.y)
		1: return _room_center + Vector2(randf_range(-half.x, half.x), half.y)
		2: return _room_center + Vector2(-half.x, randf_range(-half.y, half.y))
		_: return _room_center + Vector2(half.x, randf_range(-half.y, half.y))

# --- DODGE ---
func _setup_dodge() -> void:
	# Real shooter enemy — fires bone projectiles at the player
	var shooter_scene = load("res://scenes/enemies/enemy_shooter.tscn")
	if not shooter_scene:
		return
	_shooter_node = shooter_scene.instantiate()
	_shooter_node.position = _room_center + Vector2(200, -150)
	_enemies_container.add_child(_shooter_node)
	# Configure: stationary, unkillable, low damage
	_configure_enemy(_shooter_node, 9999, 3, 0.0)

# --- BITE ---
func _setup_bite() -> void:
	_spawn_bite_enemy()

func _spawn_bite_enemy() -> void:
	var rusher_scene = load("res://scenes/enemies/enemy_rusher.tscn")
	if not rusher_scene:
		return
	var enemy = rusher_scene.instantiate()
	enemy.position = _random_room_pos(randf_range(90, 160))
	_enemies_container.add_child(enemy)
	# Configure: low HP so bite kills quickly, very low damage, slow
	_configure_enemy(enemy, 12, 2, 25.0)
	enemy.died.connect(_on_bite_enemy_died, CONNECT_ONE_SHOT)

func _on_bite_enemy_died(_xp: int) -> void:
	_increment_rep()
	if _rep_count < _rep_target and _step_active:
		var tw = create_tween()
		tw.tween_interval(0.4)
		tw.tween_callback(_spawn_bite_enemy)

# --- SNEAK AMBUSH ---
func _setup_sneak() -> void:
	_spawn_ambush_enemy()

func _spawn_ambush_enemy() -> void:
	var rusher_scene = load("res://scenes/enemies/enemy_rusher.tscn")
	if not rusher_scene:
		return
	var enemy = rusher_scene.instantiate()
	enemy.position = _random_room_pos(130.0)
	_enemies_container.add_child(enemy)
	# High HP so it survives normal bites; only ambush (2x) kills efficiently
	_configure_enemy(enemy, 80, 2, 30.0)
	_ambush_dummy = enemy
	# If it dies before 3 ambush hits, respawn
	enemy.died.connect(func(_xp):
		if _step_active and _rep_count < _rep_target:
			var tw = create_tween()
			tw.tween_interval(0.5)
			tw.tween_callback(_spawn_ambush_enemy)
	, CONNECT_ONE_SHOT)

# --- DIG TRAP ---
func _setup_dig_trap() -> void:
	GameState.dig_charges = 3
	GameState.dig_charges_max = 3
	_spawn_trap_enemy()

func _spawn_trap_enemy() -> void:
	var rusher_scene = load("res://scenes/enemies/enemy_rusher.tscn")
	if not rusher_scene:
		return
	var enemy = rusher_scene.instantiate()
	enemy.position = _room_edge_pos()
	_enemies_container.add_child(enemy)
	# Slow approach so player can dig a hole in its path
	_configure_enemy(enemy, 50, 2, 30.0)
	_active_walker = enemy
	# If the enemy dies (bitten to death) without being trapped, spawn another
	enemy.died.connect(func(_xp):
		if _step_active and _rep_count < _rep_target:
			var tw = create_tween()
			tw.tween_interval(0.6)
			tw.tween_callback(_spawn_trap_enemy)
	, CONNECT_ONE_SHOT)

func _on_enemy_trapped(enemy: Node) -> void:
	_increment_rep()
	# Remove trapped enemy after stun wears off, then spawn next
	if enemy and is_instance_valid(enemy):
		var tw = create_tween()
		tw.tween_interval(2.0)
		tw.tween_callback(func():
			if enemy and is_instance_valid(enemy):
				enemy.queue_free()
		)
	if _rep_count < _rep_target and _step_active:
		GameState.dig_charges = maxi(1, GameState.dig_charges)
		var spawn_tw = create_tween()
		spawn_tw.tween_interval(2.5)
		spawn_tw.tween_callback(_spawn_trap_enemy)

# --- SALVAGE ---
func _setup_salvage() -> void:
	_props_broken = 0
	_salvage_phase = 0
	var prop_scene = load("res://scenes/destructible_prop.tscn")
	if not prop_scene:
		return
	# Spawn 3 props around the player
	var offsets = [Vector2(-80, -40), Vector2(80, -40), Vector2(0, 60)]
	for offset in offsets:
		var prop = prop_scene.instantiate()
		var pos = _player.position + offset if _player else _room_center + offset
		var half = Vector2(ROOM_W, ROOM_H) / 2.0 - Vector2(30, 30)
		pos.x = clampf(pos.x, _room_center.x - half.x, _room_center.x + half.x)
		pos.y = clampf(pos.y, _room_center.y - half.y, _room_center.y + half.y)
		prop.position = pos
		prop.tree_exiting.connect(_on_prop_broken, CONNECT_ONE_SHOT)
		_props_container.add_child(prop)

func _on_prop_broken() -> void:
	_props_broken += 1
	_rep_count = _props_broken
	_update_counter()
	if _props_broken >= 3 and _salvage_phase == 0:
		_salvage_phase = 1
		# Switch prompt to inventory
		_desc_label.text = "Materials collected! Press ESC to view your inventory!"
		_key_label.text = "[ ESC ]"
		_key_label.visible = true
		_counter_label.visible = false

func _show_inventory_overlay() -> void:
	_salvage_phase = 2
	_arrow_time = 0.0

	_inventory_overlay = CanvasLayer.new()
	_inventory_overlay.layer = 30
	_inventory_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_inventory_overlay)

	# Dark background
	var bg = ColorRect.new()
	bg.color = Color(0.02, 0.01, 0.04, 0.85)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	_inventory_overlay.add_child(bg)

	# Center panel
	var panel = PanelContainer.new()
	var pstyle = StyleBoxFlat.new()
	pstyle.bg_color = Color(0.08, 0.07, 0.12, 0.95)
	pstyle.border_color = CLR_BORDER
	pstyle.set_border_width_all(2)
	pstyle.set_corner_radius_all(8)
	pstyle.set_content_margin_all(20)
	panel.add_theme_stylebox_override("panel", pstyle)
	panel.custom_minimum_size = Vector2(280, 0)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_inventory_overlay.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	# Title
	var title = Label.new()
	title.text = "YOUR INVENTORY"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", CLR_GOLD)
	vbox.add_child(title)

	# Arrow pointing down at materials
	var arrow_lbl = Label.new()
	arrow_lbl.name = "Arrow"
	arrow_lbl.text = "▼  Materials  ▼"
	arrow_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	arrow_lbl.add_theme_font_size_override("font_size", 14)
	arrow_lbl.add_theme_color_override("font_color", CLR_GREEN)
	vbox.add_child(arrow_lbl)

	# Separator
	var sep = ColorRect.new()
	sep.color = CLR_BORDER.darkened(0.2)
	sep.custom_minimum_size = Vector2(0, 1)
	vbox.add_child(sep)

	# Materials list
	for mat_key in GameState.materials:
		var amt = GameState.materials[mat_key]
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var name_lbl = Label.new()
		name_lbl.text = MAT_NAMES.get(mat_key, mat_key)
		name_lbl.add_theme_font_size_override("font_size", 12)
		name_lbl.add_theme_color_override("font_color", MAT_COLORS.get(mat_key, CLR_SILVER))
		name_lbl.custom_minimum_size.x = 80
		row.add_child(name_lbl)
		var amt_lbl = Label.new()
		amt_lbl.text = str(amt)
		amt_lbl.add_theme_font_size_override("font_size", 12)
		amt_lbl.add_theme_color_override("font_color", CLR_GOLD if amt > 0 else CLR_DIM)
		amt_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		amt_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(amt_lbl)
		vbox.add_child(row)

	# Footer
	var footer = Label.new()
	footer.text = "\nPress ESC to continue"
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.add_theme_font_size_override("font_size", 11)
	footer.add_theme_color_override("font_color", CLR_DIM)
	vbox.add_child(footer)

func _dismiss_inventory_overlay() -> void:
	if _inventory_overlay and is_instance_valid(_inventory_overlay):
		_inventory_overlay.queue_free()
		_inventory_overlay = null

# ════════════════════════════════════════════════════════════
# FRAME-BY-FRAME CHECKS
# ════════════════════════════════════════════════════════════

func _physics_process(_delta: float) -> void:
	if not _step_active or _step_completed or _transitioning:
		return
	if _current_step < 0 or _current_step >= Step.size():
		return

	match _current_step:
		Step.MOVEMENT:
			_check_movement()
		Step.DODGE:
			_check_dodge()
		Step.SNEAK:
			_check_sneak_ambush()
		Step.DIG_TRAP:
			_check_dig_trap()

func _check_movement() -> void:
	if not _player:
		return
	var moved = _player.position.distance_to(_last_player_pos)
	_distance_moved += moved
	_last_player_pos = _player.position
	if _distance_moved >= 250.0:
		_complete_current_step()

func _check_dodge() -> void:
	if not _player:
		return
	var leaping_now: bool = _player._is_leaping
	if leaping_now and not _prev_leaping:
		_increment_rep()
	_prev_leaping = leaping_now

func _check_sneak_ambush() -> void:
	if not _player:
		return
	var ambush_now: bool = _player._sneak_ambush_ready
	if _prev_ambush_ready and not ambush_now:
		_increment_rep()
		if _rep_count < _rep_target and _step_active:
			if not _ambush_dummy or not is_instance_valid(_ambush_dummy) or _ambush_dummy.is_dead:
				var tw = create_tween()
				tw.tween_interval(0.5)
				tw.tween_callback(_spawn_ambush_enemy)
	_prev_ambush_ready = ambush_now

func _check_dig_trap() -> void:
	# Poll enemies for stun transitions caused by dig holes
	for enemy in _enemies_container.get_children():
		if not is_instance_valid(enemy) or not enemy.has_method("stun"):
			continue
		if enemy.is_stunned and not enemy.get_meta("tutorial_trapped", false):
			enemy.set_meta("tutorial_trapped", true)
			_on_enemy_trapped(enemy)

func _process(delta: float) -> void:
	# Animate inventory arrow bounce
	if _inventory_overlay and is_instance_valid(_inventory_overlay):
		_arrow_time += delta
		# Find the Arrow label and pulse it
		for child in _inventory_overlay.get_children():
			if child is PanelContainer:
				for sub in child.get_children():
					if sub is VBoxContainer:
						var arrow = sub.get_node_or_null("Arrow")
						if arrow and arrow is Label:
							arrow.modulate.a = 0.6 + 0.4 * sin(_arrow_time * 5.0)

# ════════════════════════════════════════════════════════════
# INPUT
# ════════════════════════════════════════════════════════════

func _unhandled_input(event: InputEvent) -> void:
	if _transitioning:
		return

	# Salvage step ESC handling
	if _current_step == Step.SALVAGE and _step_active and not _step_completed:
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			if _salvage_phase == 1:
				_show_inventory_overlay()
				get_viewport().set_input_as_handled()
				return
			elif _salvage_phase == 2:
				_dismiss_inventory_overlay()
				_complete_current_step()
				get_viewport().set_input_as_handled()
				return

	# Complete step — any key
	if _current_step == Step.COMPLETE and _step_active and not _step_completed:
		if event is InputEventKey and event.pressed:
			_complete_current_step()
		elif event is InputEventMouseButton and event.pressed:
			_complete_current_step()

# ════════════════════════════════════════════════════════════
# FINISH / SKIP
# ════════════════════════════════════════════════════════════

func _finish_tutorial() -> void:
	if _transitioning:
		return
	_transitioning = true
	_step_active = false
	_cleanup_step()

	GameState.tutorial_completed = true
	SaveManager.save_game()

	var tw = create_tween()
	tw.tween_property(_fade_rect, "color:a", 1.0, 0.4).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		GameState.set_phase(GameState.Phase.BASE_HUB)
		get_tree().change_scene_to_file("res://scenes/base_hub.tscn")
	)
