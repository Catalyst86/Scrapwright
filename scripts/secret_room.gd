extends Node2D

# ============================================================
# SecretRoom — Bonus treasure room entered via secret door
# ============================================================

const ROOM_W = 640
const ROOM_H = 360
const CHEST_COUNT = 2
const ROOM_TIMEOUT = 20.0

var ChestScene: PackedScene = null

@onready var player: CharacterBody2D = $Player
@onready var pickups_container: Node2D = $PickupsContainer

var _chests: Array = []
var _timer: float = ROOM_TIMEOUT
var _returning: bool = false
var _banner_label: Label
var _timer_label: Label

func _ready() -> void:
	ChestScene = load("res://scenes/chest.tscn")
	# Make pickups container findable for chest loot drops
	if pickups_container and not pickups_container.is_in_group("pickups_container"):
		pickups_container.add_to_group("pickups_container")

	_build_room()
	_spawn_chests()
	_show_banner()
	_create_timer_label()

	# Place player in center
	if player:
		player.global_position = Vector2(ROOM_W / 2.0, ROOM_H / 2.0 + 40)

func _process(delta: float) -> void:
	if _returning:
		return

	_timer -= delta

	# Update timer display
	if _timer_label:
		_timer_label.text = "%ds" % maxi(0, int(ceil(_timer)))

	# Clean up opened chests
	_chests = _chests.filter(func(c): return is_instance_valid(c) and not c.opened)

	if _chests.is_empty() or _timer <= 0:
		_start_return()

func _build_room() -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = 777

	# Camera on player so the room is centered
	if player and not player.get_node_or_null("Camera2D"):
		var cam = Camera2D.new()
		cam.name = "Camera2D"
		cam.zoom = Vector2(2.0, 2.0)
		cam.limit_left = 0
		cam.limit_top = 0
		cam.limit_right = ROOM_W
		cam.limit_bottom = ROOM_H
		player.add_child(cam)

	# Deep dark background — oversized to fill any viewport gap
	var bg = ColorRect.new()
	bg.size = Vector2(ROOM_W + 400, ROOM_H + 400)
	bg.position = Vector2(-200, -200)
	bg.color = Color(0.03, 0.02, 0.05)
	bg.z_index = -10
	add_child(bg)

	# Floor with a mystical stone pattern using draw node
	var floor_drawer = _SecretFloor.new()
	floor_drawer.room_w = ROOM_W
	floor_drawer.room_h = ROOM_H
	floor_drawer.z_index = -9
	add_child(floor_drawer)

	# Glowing center circle (concentric rings with purple/gold glow)
	var glow_center = Vector2(ROOM_W / 2.0, ROOM_H / 2.0)
	var glow_drawer = _GlowCircle.new()
	glow_drawer.center = glow_center
	glow_drawer.z_index = -8
	add_child(glow_drawer)

	# Floating sparkle particles
	for _i in 30:
		var sparkle = ColorRect.new()
		sparkle.size = Vector2(2, 2)
		sparkle.position = Vector2(rng.randf_range(20, ROOM_W - 20), rng.randf_range(20, ROOM_H - 20))
		sparkle.color = Color(0.8, 0.5, 1.0, rng.randf_range(0.2, 0.6))
		sparkle.z_index = -6
		add_child(sparkle)
		var tw = create_tween().set_loops()
		tw.tween_property(sparkle, "modulate:a", rng.randf_range(0.1, 0.3), rng.randf_range(1.0, 2.5))
		tw.tween_property(sparkle, "modulate:a", 1.0, rng.randf_range(1.0, 2.5))

	# Walls (ornate dark purple stone)
	var wall_color = Color(0.12, 0.08, 0.18)
	var walls = [
		Rect2(0, 0, ROOM_W, 16), Rect2(0, ROOM_H - 16, ROOM_W, 16),
		Rect2(0, 0, 16, ROOM_H), Rect2(ROOM_W - 16, 0, 16, ROOM_H),
	]
	for r in walls:
		var w = ColorRect.new()
		w.size = r.size
		w.position = r.position
		w.color = wall_color
		w.z_index = -7
		add_child(w)

	# Wall trim (gold accent line)
	var trim_col = Color(0.8, 0.6, 0.2, 0.5)
	var trims = [
		Rect2(16, 14, ROOM_W - 32, 2), Rect2(16, ROOM_H - 16, ROOM_W - 32, 2),
		Rect2(14, 16, 2, ROOM_H - 32), Rect2(ROOM_W - 16, 16, 2, ROOM_H - 32),
	]
	for r in trims:
		var t = ColorRect.new()
		t.size = r.size
		t.position = r.position
		t.color = trim_col
		t.z_index = -6
		add_child(t)

	# Corner gems (4 glowing orbs at corners) with pulsing animation
	var gem_col = Color(0.7, 0.3, 1.0, 0.7)
	for corner in [Vector2(24, 24), Vector2(ROOM_W - 24, 24), Vector2(24, ROOM_H - 24), Vector2(ROOM_W - 24, ROOM_H - 24)]:
		var gem_glow = ColorRect.new()
		gem_glow.size = Vector2(16, 16)
		gem_glow.position = corner - Vector2(8, 8)
		gem_glow.color = Color(gem_col.r, gem_col.g, gem_col.b, 0.2)
		gem_glow.z_index = -6
		add_child(gem_glow)
		var gem = ColorRect.new()
		gem.size = Vector2(4, 4)
		gem.position = corner - Vector2(2, 2)
		gem.color = gem_col
		gem.z_index = -5
		add_child(gem)
		# Pulse the gem glow
		var gtw = create_tween().set_loops()
		gtw.tween_property(gem_glow, "modulate:a", 0.3, rng.randf_range(0.8, 1.5))
		gtw.tween_property(gem_glow, "modulate:a", 1.0, rng.randf_range(0.8, 1.5))

	# Floating rising particles (magical dust drifting upward)
	for _i in 20:
		var dust = ColorRect.new()
		dust.size = Vector2(rng.randf_range(1, 3), rng.randf_range(1, 3))
		var start_x = rng.randf_range(30, ROOM_W - 30)
		var start_y = rng.randf_range(30, ROOM_H - 30)
		dust.position = Vector2(start_x, start_y)
		var dust_colors = [Color(0.9, 0.7, 1.0), Color(1.0, 0.85, 0.4), Color(0.6, 0.4, 1.0)]
		dust.color = dust_colors[rng.randi() % dust_colors.size()]
		dust.modulate.a = rng.randf_range(0.2, 0.5)
		dust.z_index = -4
		add_child(dust)
		# Float upward and fade, then reset
		var dtw = create_tween().set_loops()
		var drift_dur = rng.randf_range(3.0, 6.0)
		dtw.tween_property(dust, "position:y", start_y - rng.randf_range(40, 80), drift_dur)
		dtw.parallel().tween_property(dust, "modulate:a", 0.0, drift_dur)
		dtw.tween_callback(func():
			dust.position = Vector2(rng.randf_range(30, ROOM_W - 30), rng.randf_range(ROOM_H * 0.5, ROOM_H - 30))
			dust.modulate.a = rng.randf_range(0.2, 0.5)
		)

	# Static body walls for collision
	var body = StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	for wr in [
		Rect2(ROOM_W / 2.0, 8, ROOM_W, 16), Rect2(ROOM_W / 2.0, ROOM_H - 8, ROOM_W, 16),
		Rect2(8, ROOM_H / 2.0, 16, ROOM_H), Rect2(ROOM_W - 8, ROOM_H / 2.0, 16, ROOM_H),
	]:
		var shape = CollisionShape2D.new()
		var rect_shape = RectangleShape2D.new()
		rect_shape.size = wr.size
		shape.shape = rect_shape
		shape.position = wr.position
		body.add_child(shape)

# Inner class: draws mystical stone floor with runes
class _SecretFloor extends Node2D:
	var room_w: float = 640
	var room_h: float = 360
	func _draw() -> void:
		var rng = RandomNumberGenerator.new()
		rng.seed = 888
		# Dark stone floor
		draw_rect(Rect2(16, 16, room_w - 32, room_h - 32), Color(0.08, 0.05, 0.12))
		# Hex-like tiles with purple tint
		var tile_size = 40.0
		for x in range(0, int(room_w), int(tile_size)):
			for y in range(0, int(room_h), int(tile_size)):
				if x < 16 or x > room_w - 32 or y < 16 or y > room_h - 32:
					continue
				var offset_x = (int(y / tile_size) % 2) * int(tile_size / 2)
				var tx = float(x + offset_x)
				var ty = float(y)
				var brightness = rng.randf_range(-0.02, 0.02)
				var col = Color(0.10 + brightness, 0.06 + brightness, 0.14 + brightness)
				draw_rect(Rect2(tx + 1, ty + 1, tile_size - 2, tile_size - 2), col)
		# Rune circles on floor
		for _i in 6:
			var cx = rng.randf_range(60, room_w - 60)
			var cy = rng.randf_range(60, room_h - 60)
			var r = rng.randf_range(15, 25)
			draw_arc(Vector2(cx, cy), r, 0, TAU, 16, Color(0.5, 0.25, 0.8, 0.2), 1.5)
			draw_arc(Vector2(cx, cy), r * 0.6, 0, TAU, 12, Color(0.7, 0.4, 1.0, 0.15), 1.0)

# Inner class: animated center glow
class _GlowCircle extends Node2D:
	var center: Vector2 = Vector2.ZERO
	var _time: float = 0.0
	func _process(delta: float) -> void:
		_time += delta
		queue_redraw()
	func _draw() -> void:
		# Concentric glow rings (pulse with time)
		for i in range(8, 0, -1):
			var r = float(i) * 18.0
			var pulse = sin(_time * 1.5 + float(i) * 0.5) * 0.03
			var alpha = 0.04 * (9 - i) + pulse
			draw_circle(center, r, Color(0.5, 0.2, 0.8, alpha))
		# Inner bright core
		var core_alpha = 0.3 + sin(_time * 2.0) * 0.1
		draw_circle(center, 15, Color(0.8, 0.5, 1.0, core_alpha))
		draw_circle(center, 8, Color(1.0, 0.8, 0.5, core_alpha * 0.8))

func _spawn_chests() -> void:
	var center = Vector2(ROOM_W / 2.0, ROOM_H / 2.0)
	var radius = 50.0

	for i in CHEST_COUNT:
		var angle = (TAU / CHEST_COUNT) * i - PI / 2.0
		var pos = center + Vector2(cos(angle), sin(angle)) * radius

		var chest = ChestScene.instantiate()
		chest.position = pos
		chest.bob_origin_y = pos.y
		pickups_container.add_child(chest)
		_chests.append(chest)

		# Free chests — no key needed, always secret-tier loot
		if chest.has_signal("body_entered"):
			await get_tree().process_frame
		_make_chest_free(chest)

func _make_chest_free(chest: Area2D) -> void:
	var connections = chest.body_entered.get_connections()
	for conn in connections:
		chest.body_entered.disconnect(conn.callable)

	chest.body_entered.connect(func(body: Node):
		if chest.opened:
			return
		if not body.is_in_group("player"):
			return
		# Set secret tier for loot quality, then open without key
		chest._chosen_tier = "secret"
		chest._open_chest()
	)

func _show_banner() -> void:
	var layer = CanvasLayer.new()
	layer.layer = 10
	add_child(layer)

	_banner_label = Label.new()
	_banner_label.text = "SECRET ROOM!"
	_banner_label.add_theme_font_size_override("font_size", 20)
	_banner_label.modulate = Color(0.8, 0.3, 1.0)
	_banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_label.anchors_preset = Control.PRESET_CENTER_TOP
	_banner_label.position = Vector2(-80, 20)
	_banner_label.size = Vector2(160, 30)
	layer.add_child(_banner_label)

	# Pulse animation (bind to _banner_label so it auto-dies when banner is freed)
	var tw = _banner_label.create_tween().set_loops()
	tw.tween_property(_banner_label, "modulate:a", 0.5, 0.8)
	tw.tween_property(_banner_label, "modulate:a", 1.0, 0.8)

	# Fade banner after 3 seconds
	if not is_inside_tree(): return
	await get_tree().create_timer(3.0).timeout
	if not is_inside_tree(): return
	if is_instance_valid(_banner_label):
		tw.kill()  # Stop the looping pulse before freeing
		var fade_tw = create_tween()
		fade_tw.tween_property(_banner_label, "modulate:a", 0.0, 1.0)
		fade_tw.tween_callback(_banner_label.queue_free)

func _create_timer_label() -> void:
	var layer = CanvasLayer.new()
	layer.layer = 10
	add_child(layer)

	_timer_label = Label.new()
	_timer_label.text = "%ds" % ROOM_TIMEOUT
	_timer_label.add_theme_font_size_override("font_size", 10)
	_timer_label.modulate = Color(0.7, 0.7, 0.7)
	_timer_label.position = Vector2(10, 10)
	layer.add_child(_timer_label)

func _start_return() -> void:
	if _returning:
		return
	_returning = true

	# Remove remaining chests
	for chest in _chests:
		if is_instance_valid(chest) and not chest.opened:
			chest.queue_free()
	_chests.clear()

	# Show returning banner
	var layer = CanvasLayer.new()
	layer.layer = 10
	add_child(layer)

	var lbl = Label.new()
	lbl.text = "Returning..."
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.modulate = Color(0.7, 0.5, 1.0)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.anchors_preset = Control.PRESET_CENTER
	lbl.position = Vector2(-60, -10)
	lbl.size = Vector2(120, 30)
	layer.add_child(lbl)

	if not is_inside_tree(): return
	await get_tree().create_timer(1.5).timeout
	if not is_inside_tree(): return

	# Return to base hub (secret doors only appear after boss waves)
	GameState.set_phase(GameState.Phase.BASE_HUB)
	SaveManager.save_game()
	get_tree().change_scene_to_file("res://scenes/base_hub.tscn")
