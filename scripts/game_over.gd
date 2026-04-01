extends Control

# ============================================================
# GameOver — Sprite-based dramatic death screen
# ============================================================

const CLR_BG          = Color(0.05, 0.02, 0.02, 1.0)
const CLR_BORDER      = Color(0.55, 0.42, 0.22, 1.0)
const CLR_RED         = Color(0.88, 0.20, 0.20)
const CLR_DARK_RED    = Color(0.45, 0.08, 0.08)
const CLR_GOLD_TEXT   = Color(0.95, 0.82, 0.35)
const CLR_SILVER_TEXT = Color(0.78, 0.78, 0.82)
const CLR_DIM_TEXT    = Color(0.45, 0.42, 0.38)

const UI = "res://assets/sprites/ui/"

var _time: float = 0.0
var _dead_label: Label
var _particles: Array = []
var _stats_nodes: Array = []
var _skull_icon: TextureRect
var _ember_tex: Texture2D

func _ready() -> void:
	AudioManager.play_music("game_over")
	_build_ui()

func _load_tex(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path)
	return null

func _build_ui() -> void:
	# Dark red background
	var bg = ColorRect.new()
	bg.color = CLR_BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Vignette overlay (sprite-based if available)
	var vig_tex = _load_tex(UI + "bg_vignette_dark.png")
	if vig_tex:
		var vig = TextureRect.new()
		vig.texture = vig_tex
		vig.set_anchors_preset(Control.PRESET_FULL_RECT)
		vig.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		vig.stretch_mode = TextureRect.STRETCH_SCALE
		vig.modulate = Color(1, 0.3, 0.3, 0.4)
		add_child(vig)

	# Red fog overlay — pulses
	var fog = ColorRect.new()
	fog.color = Color(0.3, 0.02, 0.02, 0.15)
	fog.set_anchors_preset(Control.PRESET_FULL_RECT)
	fog.name = "RedFog"
	add_child(fog)

	# Divider lines using sprite
	var div_tex = _load_tex(UI + "divider_horizontal.png")
	for y_off in [58, 100]:
		if div_tex:
			var div = TextureRect.new()
			div.texture = div_tex
			div.set_anchors_preset(Control.PRESET_CENTER_TOP)
			div.offset_left = -80; div.offset_top = y_off
			div.offset_right = 80; div.offset_bottom = y_off + 6
			div.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			div.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			div.modulate = Color(1, 0.4, 0.3, 0.7)
			add_child(div)
		else:
			var line = ColorRect.new()
			line.color = CLR_RED * Color(1,1,1,0.6)
			line.set_anchors_preset(Control.PRESET_CENTER_TOP)
			line.offset_left = -140; line.offset_top = y_off
			line.offset_right = 140; line.offset_bottom = y_off + 2
			add_child(line)

	# Skull icon (sprite-based)
	var skull_tex = _load_tex(UI + "icon_skull.png")
	if skull_tex:
		_skull_icon = TextureRect.new()
		_skull_icon.texture = skull_tex
		_skull_icon.set_anchors_preset(Control.PRESET_CENTER_TOP)
		_skull_icon.offset_left = -16; _skull_icon.offset_top = 28
		_skull_icon.offset_right = 16; _skull_icon.offset_bottom = 60
		_skull_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_skull_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_skull_icon.modulate = Color(1, 0.4, 0.4, 0.0)
		_skull_icon.pivot_offset = Vector2(16, 16)
		add_child(_skull_icon)
		var stw = create_tween()
		stw.tween_property(_skull_icon, "modulate:a", 1.0, 0.5).set_delay(0.2)
	else:
		var skull_lbl = Label.new()
		skull_lbl.text = "X"
		skull_lbl.set_anchors_preset(Control.PRESET_CENTER_TOP)
		skull_lbl.offset_left = -20; skull_lbl.offset_top = 30
		skull_lbl.offset_right = 20; skull_lbl.offset_bottom = 56
		skull_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		skull_lbl.add_theme_font_size_override("font_size", 24)
		skull_lbl.add_theme_color_override("font_color", CLR_RED)
		skull_lbl.modulate.a = 0.0
		add_child(skull_lbl)
		var stw = create_tween()
		stw.tween_property(skull_lbl, "modulate:a", 1.0, 0.5).set_delay(0.2)

	# "YOU DIED" title
	_dead_label = Label.new()
	_dead_label.text = "YOU DIED"
	_dead_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_dead_label.offset_left = -200; _dead_label.offset_top = 62
	_dead_label.offset_right = 200; _dead_label.offset_bottom = 98
	_dead_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dead_label.add_theme_font_size_override("font_size", 36)
	_dead_label.add_theme_color_override("font_color", CLR_RED)
	_dead_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_dead_label.add_theme_constant_override("shadow_offset_x", 2)
	_dead_label.add_theme_constant_override("shadow_offset_y", 2)
	_dead_label.pivot_offset = Vector2(200, 18)
	_dead_label.scale = Vector2(1.8, 1.8)
	_dead_label.modulate.a = 0.0
	add_child(_dead_label)

	var title_tw = create_tween()
	title_tw.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	title_tw.tween_property(_dead_label, "scale", Vector2(1, 1), 0.4).set_delay(0.1)
	title_tw.parallel().tween_property(_dead_label, "modulate:a", 1.0, 0.3).set_delay(0.1)

	# === Stats ===
	var stats_y = 110
	var delay = 0.6

	var wave_lbl = _make_stat_label("You reached wave %d" % GameState.last_death_wave, 20, CLR_SILVER_TEXT, stats_y, delay)
	_stats_nodes.append(wave_lbl)
	stats_y += 28; delay += 0.15

	var level_lbl = _make_stat_label("Level %d" % GameState.last_death_level, 16, CLR_DIM_TEXT, stats_y, delay)
	_stats_nodes.append(level_lbl)
	stats_y += 24; delay += 0.15

	# Materials
	var mat_parts: Array = []
	for mat in GameState.materials:
		var amt = GameState.materials[mat]
		if amt > 0:
			mat_parts.append("%s: %d" % [mat.replace("_", " "), amt])

	if mat_parts.size() > 0:
		var sep_tex = _load_tex(UI + "divider_horizontal.png")
		if sep_tex:
			var sep = TextureRect.new()
			sep.texture = sep_tex
			sep.set_anchors_preset(Control.PRESET_CENTER_TOP)
			sep.offset_left = -60; sep.offset_top = stats_y + 4
			sep.offset_right = 60; sep.offset_bottom = stats_y + 10
			sep.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; sep.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			sep.modulate = Color(1, 1, 1, 0.0)
			add_child(sep)
			var stw = create_tween()
			stw.tween_property(sep, "modulate:a", 0.6, 0.3).set_delay(delay)
		else:
			var sep = ColorRect.new()
			sep.color = CLR_BORDER * Color(1,1,1,0.4)
			sep.set_anchors_preset(Control.PRESET_CENTER_TOP)
			sep.offset_left = -100; sep.offset_top = stats_y + 4
			sep.offset_right = 100; sep.offset_bottom = stats_y + 5
			sep.modulate.a = 0.0
			add_child(sep)
			var stw = create_tween()
			stw.tween_property(sep, "modulate:a", 1.0, 0.3).set_delay(delay)
		stats_y += 14; delay += 0.15

		_make_stat_label("Materials Salvaged", 12, CLR_DIM_TEXT, stats_y, delay)
		stats_y += 18; delay += 0.1

		var mat_lbl = _make_stat_label("  |  ".join(mat_parts), 14, CLR_GOLD_TEXT, stats_y, delay)
		_stats_nodes.append(mat_lbl)
		stats_y += 28; delay += 0.15

	# Return button with sprite-based style
	stats_y += 8
	var return_btn = Button.new()
	return_btn.text = "RETURN TO HUB"
	return_btn.custom_minimum_size = Vector2(220, 44)
	return_btn.set_anchors_preset(Control.PRESET_CENTER_TOP)
	return_btn.offset_left = -110; return_btn.offset_top = stats_y
	return_btn.offset_right = 110; return_btn.offset_bottom = stats_y + 44
	return_btn.add_theme_font_size_override("font_size", 18)

	var btn_tex = _load_tex(UI + "button_normal.png")
	var btn_hover_tex = _load_tex(UI + "button_hover.png")
	if btn_tex:
		var sb = StyleBoxTexture.new()
		sb.texture = btn_tex
		sb.texture_margin_left = 8; sb.texture_margin_right = 8
		sb.texture_margin_top = 4; sb.texture_margin_bottom = 4
		sb.content_margin_left = 12; sb.content_margin_right = 12
		sb.content_margin_top = 8; sb.content_margin_bottom = 8
		return_btn.add_theme_stylebox_override("normal", sb)
		if btn_hover_tex:
			var sb_h = StyleBoxTexture.new()
			sb_h.texture = btn_hover_tex
			sb_h.texture_margin_left = 8; sb_h.texture_margin_right = 8
			sb_h.texture_margin_top = 4; sb_h.texture_margin_bottom = 4
			sb_h.content_margin_left = 12; sb_h.content_margin_right = 12
			sb_h.content_margin_top = 8; sb_h.content_margin_bottom = 8
			return_btn.add_theme_stylebox_override("hover", sb_h)
			return_btn.add_theme_stylebox_override("pressed", sb_h)
	else:
		var sb = StyleBoxFlat.new()
		sb.bg_color = Color(0.14, 0.11, 0.08)
		sb.border_color = CLR_BORDER
		sb.set_border_width_all(2); sb.set_corner_radius_all(2); sb.set_content_margin_all(10)
		return_btn.add_theme_stylebox_override("normal", sb)
		var sb_h = sb.duplicate()
		sb_h.bg_color = Color(0.22, 0.18, 0.12); sb_h.border_color = CLR_GOLD_TEXT
		return_btn.add_theme_stylebox_override("hover", sb_h)

	return_btn.add_theme_color_override("font_color", CLR_GOLD_TEXT)
	return_btn.add_theme_color_override("font_hover_color", CLR_GOLD_TEXT.lightened(0.2))
	return_btn.pressed.connect(_return_to_base)

	return_btn.modulate.a = 0.0
	add_child(return_btn)
	var btw = create_tween()
	btw.tween_property(return_btn, "modulate:a", 1.0, 0.4).set_delay(delay).set_ease(Tween.EASE_OUT)

	return_btn.mouse_entered.connect(func():
		var htw = return_btn.create_tween()
		htw.tween_property(return_btn, "scale", Vector2(1.05, 1.05), 0.1).set_trans(Tween.TRANS_BACK)
	)
	return_btn.mouse_exited.connect(func():
		var htw = return_btn.create_tween()
		htw.tween_property(return_btn, "scale", Vector2(1.0, 1.0), 0.1)
	)

	# Pre-load ember texture
	_ember_tex = _load_tex(UI + "particle_ember.png")


func _make_stat_label(text: String, font_size: int, color: Color, y: int, delay: float) -> Label:
	var lbl = Label.new()
	lbl.text = text
	lbl.set_anchors_preset(Control.PRESET_CENTER_TOP)
	lbl.offset_left = -220; lbl.offset_top = y
	lbl.offset_right = 220; lbl.offset_bottom = y + font_size + 8
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", color)
	lbl.modulate.a = 0.0
	add_child(lbl)

	lbl.offset_top += 10; lbl.offset_bottom += 10
	var tw = create_tween()
	tw.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(lbl, "modulate:a", 1.0, 0.35).set_delay(delay)
	tw.parallel().tween_property(lbl, "offset_top", y, 0.35).set_delay(delay)
	tw.parallel().tween_property(lbl, "offset_bottom", y + font_size + 8, 0.35).set_delay(delay)
	return lbl


func _process(delta: float) -> void:
	_time += delta

	if _dead_label:
		var pulse = 0.8 + 0.2 * sin(_time * 3.0)
		_dead_label.add_theme_color_override("font_color",
			CLR_RED * Color(pulse, pulse * 0.8, pulse * 0.8, 1.0))

	if _skull_icon:
		var s_pulse = 1.0 + 0.08 * sin(_time * 2.5)
		_skull_icon.scale = Vector2(s_pulse, s_pulse)

	var fog = get_node_or_null("RedFog")
	if fog:
		fog.color.a = 0.08 + 0.07 * sin(_time * 1.5)

	if randf() < 0.2:
		_spawn_ember()
	_update_embers(delta)


func _spawn_ember() -> void:
	var vp_w = get_viewport().get_visible_rect().size.x if get_viewport() else 480.0
	var pos = Vector2(randf_range(0, vp_w), -5)
	if _ember_tex:
		var ember_rect = TextureRect.new()
		ember_rect.texture = _ember_tex
		var sz = randf_range(4, 8)
		ember_rect.size = Vector2(sz, sz)
		ember_rect.custom_minimum_size = Vector2(sz, sz)
		ember_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; ember_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ember_rect.position = pos
		ember_rect.modulate = Color(1, 0.4, 0.2, randf_range(0.3, 0.7))
		add_child(ember_rect)
		_particles.append({
			"node": ember_rect, "vy": randf_range(15, 40),
			"vx": randf_range(-8, 8), "life": randf_range(2.0, 5.0),
		})
	else:
		var ember = ColorRect.new()
		var brightness = randf_range(0.3, 0.8)
		ember.color = Color(brightness, brightness * 0.15, brightness * 0.05, randf_range(0.3, 0.7))
		var sz = randf_range(1, 3)
		ember.size = Vector2(sz, sz)
		ember.position = pos
		add_child(ember)
		_particles.append({
			"node": ember, "vy": randf_range(15, 40),
			"vx": randf_range(-8, 8), "life": randf_range(2.0, 5.0),
		})


func _update_embers(delta: float) -> void:
	var to_remove: Array = []
	for i in _particles.size():
		var p = _particles[i]
		p.life -= delta
		if p.life <= 0 or not is_instance_valid(p.node):
			if is_instance_valid(p.node):
				p.node.queue_free()
			to_remove.append(i)
		else:
			p.node.position.y += p.vy * delta
			p.node.position.x += p.vx * delta
			if p.life < 1.0:
				p.node.modulate.a = p.life
	to_remove.reverse()
	for i in to_remove:
		_particles.remove_at(i)


func _return_to_base() -> void:
	# end_run() already called by arena.gd before loading this scene
	var jy = get_node_or_null("/root/JunkyardState")
	if jy and jy.is_active:
		jy.exit_junkyard()
	SaveManager.save_game()
	GameState.set_phase(GameState.Phase.BASE_HUB)
	var tw = create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.3).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		get_tree().change_scene_to_file("res://scenes/base_hub.tscn")
	)
