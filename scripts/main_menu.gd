extends Control

# ============================================================
# Main Menu — Title card background with ambient animations
# ============================================================

const CLR_BG           = Color(0.06, 0.05, 0.04, 1.0)
const CLR_BORDER       = Color(0.55, 0.42, 0.22, 1.0)
const CLR_GOLD_TEXT    = Color(0.95, 0.82, 0.35)
const CLR_SILVER_TEXT  = Color(0.78, 0.78, 0.82)
const CLR_DIM_TEXT     = Color(0.45, 0.42, 0.38)
const CLR_ORANGE       = Color(0.95, 0.55, 0.15)
const CLR_RED          = Color(0.85, 0.25, 0.25)
const CLR_GREEN        = Color(0.35, 0.82, 0.40)

var _time: float = 0.0
var _buttons: Array = []
var _continue_btn: Button
var _options_panel: Control
var _hover_labels: Dictionary = {}  # btn -> Label
var _profile_layer: Control
var _game_menu_layer: Control  # The btn_container + options

# Ambient effect nodes
var _wind_particles: Array = []
var _rat_sprite: ColorRect
var _rat_state: String = "hidden"  # hidden, scurrying, paused
var _rat_timer: float = 0.0
var _rat_next_event: float = 5.0
var _rat_start_x: float = 0.0
var _rat_end_x: float = 0.0
var _rat_y: float = 0.0
var _rat_scurry_speed: float = 0.0
var _rat_pause_timer: float = 0.0

func _ready() -> void:
	AudioManager.play_music("main_menu")
	_build_ui()
	modulate = Color(1, 1, 1, 0)
	var tw = create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.6).set_ease(Tween.EASE_OUT)

func _load_tex(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path)
	return null

func _build_ui() -> void:
	# Dark background
	var bg = ColorRect.new()
	bg.color = CLR_BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Title card background
	var title_tex = _load_tex("res://assets/sprites/ui/menu_background.jpg")
	if not title_tex:
		title_tex = _load_tex("res://assets/sprites/ui/title_card_menu.jpg")
	if not title_tex:
		title_tex = _load_tex("res://assets/sprites/ui/title_card_menu.png")
	if not title_tex:
		title_tex = _load_tex("res://assets/sprites/ui/title_card.jpg")
	if title_tex:
		var bg_img = TextureRect.new()
		bg_img.texture = title_tex
		bg_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		bg_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg_img.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(bg_img)

	# === AMBIENT EFFECTS ===
	_setup_wind_particles()
	_setup_rat()

	# === PROFILE SELECTION ===
	_profile_layer = Control.new()
	_profile_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_profile_layer)
	_build_profile_selection()

	# === GAME MENU (hidden until profile selected) ===
	_game_menu_layer = Control.new()
	_game_menu_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_game_menu_layer.visible = false
	_game_menu_layer.modulate.a = 0.0
	add_child(_game_menu_layer)

	# === BUTTONS (LEFT side, vertical stack — keeps puppy visible) ===
	var btn_container = VBoxContainer.new()
	btn_container.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	btn_container.offset_left = 20
	btn_container.offset_right = 140
	btn_container.offset_top = -60
	btn_container.offset_bottom = 60
	btn_container.add_theme_constant_override("separation", 8)
	btn_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_game_menu_layer.add_child(btn_container)

	var btn_idx = 0

	# Continue button — visible if player has any save progress (not just mid-run)
	_continue_btn = _make_menu_button("CONTINUE", CLR_ORANGE, btn_idx, "Return to the Den")
	_continue_btn.pressed.connect(_on_continue)
	btn_container.add_child(_continue_btn)
	btn_idx += 1
	_continue_btn.visible = _has_save_progress()

	# New Game
	var new_btn = _make_menu_button("NEW GAME", CLR_GOLD_TEXT, btn_idx, "Start a fresh adventure")
	new_btn.pressed.connect(_on_new_game)
	btn_container.add_child(new_btn)
	_buttons.append(new_btn)
	btn_idx += 1

	# Options
	var opts_btn = _make_menu_button("OPTIONS", CLR_SILVER_TEXT, btn_idx, "Settings and preferences")
	opts_btn.pressed.connect(_on_options)
	btn_container.add_child(opts_btn)
	_buttons.append(opts_btn)
	btn_idx += 1

	# Switch Profile
	btn_idx += 1
	var switch_btn = _make_menu_button("SWITCH PROFILE", CLR_DIM_TEXT, btn_idx, "Choose a different save")
	switch_btn.pressed.connect(_on_switch_profile)
	btn_container.add_child(switch_btn)
	_buttons.append(switch_btn)

	# Quit
	btn_idx += 1
	var quit_btn = _make_menu_button("QUIT", CLR_DIM_TEXT, btn_idx, "Exit the game")
	quit_btn.pressed.connect(_on_quit)
	btn_container.add_child(quit_btn)
	_buttons.append(quit_btn)

	# Version (top-right corner, out of the way)
	var version_lbl = Label.new()
	version_lbl.text = "v0.2 alpha"
	version_lbl.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	version_lbl.offset_left = -100; version_lbl.offset_top = 4
	version_lbl.offset_right = -8; version_lbl.offset_bottom = 20
	version_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	version_lbl.add_theme_font_size_override("font_size", 10)
	version_lbl.add_theme_color_override("font_color", Color(0.3, 0.28, 0.24))
	add_child(version_lbl)

	_build_options_panel()


# === WIND WISPS ===

func _setup_wind_particles() -> void:
	# Create a few small wind wisp lines that drift across occasionally
	for i in range(5):
		var wisp = ColorRect.new()
		wisp.color = Color(0.8, 0.75, 0.6, 0.0)  # start invisible
		wisp.size = Vector2(randi_range(15, 40), 1)
		wisp.position = Vector2(-50, randi_range(100, 250))
		add_child(wisp)
		_wind_particles.append({
			"node": wisp,
			"active": false,
			"speed": randf_range(60.0, 120.0),
			"next_trigger": randf_range(2.0, 8.0 + i * 3.0),
			"timer": 0.0,
			"y": randi_range(100, 250),
			"length": wisp.size.x,
			"wave_offset": randf() * TAU,
		})


func _update_wind(delta: float) -> void:
	var vp_w = get_viewport_rect().size.x

	for w in _wind_particles:
		w.timer += delta
		var node: ColorRect = w.node

		if not w.active:
			if w.timer >= w.next_trigger:
				# Trigger a new wisp
				w.active = true
				w.timer = 0.0
				w.y = randi_range(80, 240)
				node.position.x = -50
				node.position.y = w.y
				node.size.x = randi_range(15, 45)
		else:
			# Move wisp across screen
			node.position.x += w.speed * delta
			# Gentle sine wave drift vertically
			node.position.y = w.y + sin(_time * 2.0 + w.wave_offset) * 3.0

			# Fade in at start, fade out at end
			var progress = node.position.x / vp_w
			var alpha: float
			if progress < 0.1:
				alpha = progress / 0.1
			elif progress > 0.8:
				alpha = (1.0 - progress) / 0.2
			else:
				alpha = 1.0
			node.color.a = clampf(alpha * 0.15, 0.0, 0.15)

			# Reset when off screen
			if node.position.x > vp_w + 60:
				w.active = false
				w.timer = 0.0
				w.next_trigger = randf_range(4.0, 12.0)
				node.color.a = 0.0


# === RAT ===

func _setup_rat() -> void:
	_rat_sprite = ColorRect.new()
	_rat_sprite.color = Color(0.25, 0.2, 0.15, 0.0)
	_rat_sprite.size = Vector2(6, 3)
	_rat_sprite.position = Vector2(-20, 230)
	add_child(_rat_sprite)
	_rat_next_event = randf_range(6.0, 14.0)


func _update_rat(delta: float) -> void:
	var vp_w = get_viewport_rect().size.x

	match _rat_state:
		"hidden":
			_rat_timer += delta
			if _rat_timer >= _rat_next_event:
				# Start a scurry
				_rat_state = "scurrying"
				_rat_timer = 0.0
				# Pick direction: left-to-right or right-to-left
				if randi() % 2 == 0:
					_rat_start_x = -10.0
					_rat_end_x = vp_w * randf_range(0.15, 0.4)
				else:
					_rat_start_x = vp_w + 10.0
					_rat_end_x = vp_w * randf_range(0.6, 0.85)
				_rat_y = randf_range(215, 255)
				_rat_scurry_speed = randf_range(100.0, 180.0)
				_rat_sprite.position = Vector2(_rat_start_x, _rat_y)
				_rat_sprite.color.a = 0.7

		"scurrying":
			var dir = sign(_rat_end_x - _rat_start_x)
			_rat_sprite.position.x += dir * _rat_scurry_speed * delta
			# Jitter Y for scurrying feel
			_rat_sprite.position.y = _rat_y + sin(_time * 25.0) * 1.0

			# Reached destination?
			if (dir > 0 and _rat_sprite.position.x >= _rat_end_x) or \
			   (dir < 0 and _rat_sprite.position.x <= _rat_end_x):
				# Sometimes pause, sometimes just disappear
				if randf() < 0.4:
					_rat_state = "paused"
					_rat_pause_timer = randf_range(0.5, 1.5)
				else:
					# Scurry off screen
					_rat_state = "exiting"
					_rat_end_x = -20.0 if dir < 0 else vp_w + 20.0

		"paused":
			_rat_pause_timer -= delta
			# Subtle twitch
			_rat_sprite.position.y = _rat_y + sin(_time * 8.0) * 0.5
			if _rat_pause_timer <= 0:
				# Scurry off screen
				_rat_state = "exiting"
				var vp = get_viewport_rect().size.x
				if _rat_sprite.position.x < vp * 0.5:
					_rat_end_x = -20.0
				else:
					_rat_end_x = vp + 20.0
				_rat_scurry_speed = randf_range(120.0, 200.0)

		"exiting":
			var dir = sign(_rat_end_x - _rat_sprite.position.x)
			_rat_sprite.position.x += dir * _rat_scurry_speed * delta
			_rat_sprite.position.y = _rat_y + sin(_time * 25.0) * 1.0

			if _rat_sprite.position.x < -20 or _rat_sprite.position.x > get_viewport_rect().size.x + 20:
				_rat_state = "hidden"
				_rat_timer = 0.0
				_rat_next_event = randf_range(8.0, 18.0)
				_rat_sprite.color.a = 0.0


func _process(delta: float) -> void:
	_time += delta
	_update_wind(delta)
	_update_rat(delta)


# === OPTIONS PANEL ===

func _build_options_panel() -> void:
	_options_panel = Control.new()
	_options_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_options_panel.visible = false
	_options_panel.z_index = 10
	add_child(_options_panel)

	var dim = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.75)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_options_panel.add_child(dim)

	var panel = ColorRect.new()
	panel.color = Color(0.11, 0.08, 0.06, 0.95)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -200; panel.offset_top = -150
	panel.offset_right = 200; panel.offset_bottom = 150
	_options_panel.add_child(panel)

	for data in [
		{"x": -200, "y": -150, "w": 400, "h": 2},
		{"x": -200, "y": 148, "w": 400, "h": 2},
		{"x": -200, "y": -150, "w": 2, "h": 300},
		{"x": 198, "y": -150, "w": 2, "h": 300},
	]:
		var r = ColorRect.new()
		r.color = CLR_BORDER
		r.set_anchors_preset(Control.PRESET_CENTER)
		r.offset_left = data.x; r.offset_top = data.y
		r.offset_right = data.x + data.w; r.offset_bottom = data.y + data.h
		_options_panel.add_child(r)

	var opts_title = Label.new()
	opts_title.text = "OPTIONS"
	opts_title.set_anchors_preset(Control.PRESET_CENTER)
	opts_title.offset_left = -180; opts_title.offset_top = -140
	opts_title.offset_right = 180; opts_title.offset_bottom = -112
	opts_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	opts_title.add_theme_font_size_override("font_size", 22)
	opts_title.add_theme_color_override("font_color", CLR_GOLD_TEXT)
	_options_panel.add_child(opts_title)

	var sep = ColorRect.new()
	sep.color = CLR_BORDER * Color(1, 1, 1, 0.4)
	sep.set_anchors_preset(Control.PRESET_CENTER)
	sep.offset_left = -160; sep.offset_top = -108
	sep.offset_right = 160; sep.offset_bottom = -107
	_options_panel.add_child(sep)

	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.offset_left = -160; vbox.offset_top = -95
	vbox.offset_right = 160; vbox.offset_bottom = 100
	vbox.add_theme_constant_override("separation", 12)
	_options_panel.add_child(vbox)

	var vol_hbox = HBoxContainer.new()
	vol_hbox.add_theme_constant_override("separation", 8)
	vbox.add_child(vol_hbox)

	var vol_label = Label.new()
	vol_label.text = "Master Volume"
	vol_label.add_theme_font_size_override("font_size", 14)
	vol_label.add_theme_color_override("font_color", CLR_SILVER_TEXT)
	vol_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vol_hbox.add_child(vol_label)

	var vol_slider = HSlider.new()
	vol_slider.min_value = 0.0
	vol_slider.max_value = 1.0
	vol_slider.step = 0.05
	vol_slider.value = db_to_linear(AudioServer.get_bus_volume_db(0))
	vol_slider.custom_minimum_size = Vector2(120, 20)
	vol_slider.value_changed.connect(func(val):
		AudioServer.set_bus_volume_db(0, linear_to_db(val))
	)
	vol_hbox.add_child(vol_slider)

	var fs_hbox = HBoxContainer.new()
	fs_hbox.add_theme_constant_override("separation", 8)
	vbox.add_child(fs_hbox)

	var fs_label = Label.new()
	fs_label.text = "Fullscreen"
	fs_label.add_theme_font_size_override("font_size", 14)
	fs_label.add_theme_color_override("font_color", CLR_SILVER_TEXT)
	fs_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fs_hbox.add_child(fs_label)

	var fs_check = CheckButton.new()
	fs_check.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	fs_check.toggled.connect(func(on):
		if on:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	)
	fs_hbox.add_child(fs_check)

	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	vbox.add_child(spacer)

	var delete_btn = _make_options_button("DELETE SAVE", CLR_RED)
	var confirm_state = {"active": false}
	delete_btn.pressed.connect(func():
		if not confirm_state.active:
			confirm_state.active = true
			delete_btn.text = "ARE YOU SURE?"
			if not is_inside_tree(): return
			await get_tree().create_timer(3.0).timeout
			if not is_inside_tree(): return
			if is_instance_valid(delete_btn):
				confirm_state.active = false
				delete_btn.text = "DELETE SAVE"
		else:
			SaveManager.delete_save()
			get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
	)
	vbox.add_child(delete_btn)

	var back_btn = _make_options_button("BACK", CLR_GOLD_TEXT)
	back_btn.pressed.connect(_close_options)
	vbox.add_child(back_btn)


func _make_options_button(text: String, color: Color) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(0, 34)
	btn.add_theme_font_size_override("font_size", 14)

	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.14, 0.11, 0.08)
	sb.border_color = color * Color(1, 1, 1, 0.6)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(3)
	sb.set_content_margin_all(6)
	btn.add_theme_stylebox_override("normal", sb)

	var sbh = sb.duplicate()
	sbh.bg_color = Color(0.22, 0.18, 0.12)
	sbh.border_color = color
	btn.add_theme_stylebox_override("hover", sbh)

	btn.add_theme_color_override("font_color", color)
	btn.add_theme_color_override("font_hover_color", color.lightened(0.2))
	return btn


func _make_menu_button(text: String, accent: Color, idx: int, description: String = "") -> Button:
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(90, 24)
	btn.add_theme_font_size_override("font_size", 11)

	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.06, 0.04, 0.8)
	sb.border_color = accent * Color(1, 1, 1, 0.7)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(2)
	sb.set_content_margin_all(8)
	btn.add_theme_stylebox_override("normal", sb)

	var sb_hover = sb.duplicate()
	sb_hover.bg_color = Color(0.18, 0.14, 0.08, 0.9)
	sb_hover.border_color = accent
	btn.add_theme_stylebox_override("hover", sb_hover)

	var sb_pressed = sb.duplicate()
	sb_pressed.bg_color = Color(0.25, 0.2, 0.12, 0.9)
	btn.add_theme_stylebox_override("pressed", sb_pressed)

	btn.add_theme_color_override("font_color", accent)
	btn.add_theme_color_override("font_hover_color", accent.lightened(0.3))
	btn.add_theme_color_override("font_pressed_color", accent.lightened(0.5))

	btn.modulate.a = 0.0
	var tw = create_tween()
	tw.tween_property(btn, "modulate:a", 1.0, 0.4).set_delay(0.3 + idx * 0.12).set_ease(Tween.EASE_OUT)

	# --- Floating hover tooltip ---
	var hover_lbl: Label = null
	if description != "":
		hover_lbl = Label.new()
		hover_lbl.text = description
		hover_lbl.add_theme_font_size_override("font_size", 8)
		hover_lbl.add_theme_color_override("font_color", accent.lightened(0.15))
		hover_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
		hover_lbl.add_theme_constant_override("shadow_offset_x", 1)
		hover_lbl.add_theme_constant_override("shadow_offset_y", 1)
		hover_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		hover_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hover_lbl.modulate.a = 0.0
		hover_lbl.z_index = 5
		_hover_labels[btn] = hover_lbl

	btn.mouse_entered.connect(func():
		var htw = btn.create_tween()
		htw.tween_property(btn, "scale", Vector2(1.05, 1.05), 0.1).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		if hover_lbl and is_instance_valid(hover_lbl):
			_show_hover_label(btn, hover_lbl)
	)
	btn.mouse_exited.connect(func():
		var htw = btn.create_tween()
		htw.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.1).set_ease(Tween.EASE_OUT)
		if hover_lbl and is_instance_valid(hover_lbl):
			_hide_hover_label(hover_lbl)
	)
	btn.pressed.connect(func():
		var ptw = btn.create_tween()
		ptw.tween_property(btn, "scale", Vector2(0.92, 0.92), 0.05)
		ptw.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.1).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	)
	return btn


func _show_hover_label(btn: Button, lbl: Label) -> void:
	# Add to root so it's not clipped by VBoxContainer
	if lbl.get_parent() == null:
		add_child(lbl)
	# Position: to the right of the button, vertically centered
	var btn_rect = btn.get_global_rect()
	lbl.position = Vector2(btn_rect.position.x + btn_rect.size.x + 8, btn_rect.position.y + btn_rect.size.y * 0.5 - 6)
	# Animate: fade in + slight slide from left
	lbl.position.x -= 6
	var ftw = lbl.create_tween()
	ftw.set_parallel(true)
	ftw.tween_property(lbl, "modulate:a", 1.0, 0.15).set_ease(Tween.EASE_OUT)
	ftw.tween_property(lbl, "position:x", lbl.position.x + 6, 0.15).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)


func _hide_hover_label(lbl: Label) -> void:
	var ftw = lbl.create_tween()
	ftw.tween_property(lbl, "modulate:a", 0.0, 0.1).set_ease(Tween.EASE_IN)


func _has_save_progress() -> bool:
	# Show Continue if there's any save data: active run OR permanent upgrades/cards
	if GameState.run_in_progress:
		return true
	for key in GameState.permanent:
		if key != "runs_completed" and GameState.permanent.get(key, 0) > 0:
			return true
	if GameState.permanent.get("runs_completed", 0) > 0:
		return true
	var card_db = get_node_or_null("/root/CardDB")
	if card_db and not card_db.collected.is_empty():
		return true
	# Check if save file exists at all
	return GameState.has_save()

func _on_continue() -> void:
	var tw = create_tween()
	tw.tween_property(self, "modulate", Color(1, 1, 1, 0), 0.3).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		GameState.set_phase(GameState.Phase.BASE_HUB)
		get_tree().change_scene_to_file("res://scenes/base_hub.tscn")
	)

func _on_new_game() -> void:
	# Check if player has any permanent upgrades worth warning about
	var has_progress = false
	for key in GameState.permanent:
		if key != "runs_completed" and GameState.permanent.get(key, 0) > 0:
			has_progress = true
			break
	if has_progress:
		_show_new_game_confirm()
	else:
		_execute_new_game()

func _show_new_game_confirm() -> void:
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.7)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = 50
	add_child(overlay)

	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.08, 0.14, 0.95)
	style.border_color = Color(0.95, 0.4, 0.3)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", style)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -150
	panel.offset_right = 150
	panel.offset_top = -60
	panel.offset_bottom = 60
	panel.z_index = 51
	add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	var warn = Label.new()
	warn.text = "Start a new game?\nThis will erase ALL upgrades\nand progress!"
	warn.add_theme_font_size_override("font_size", 14)
	warn.add_theme_color_override("font_color", Color(1.0, 0.8, 0.3))
	warn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(warn)

	var btn_row = HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 20)
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btn_row)

	var yes_btn = Button.new()
	yes_btn.text = "YES, RESET"
	yes_btn.add_theme_font_size_override("font_size", 14)
	yes_btn.custom_minimum_size = Vector2(110, 30)
	btn_row.add_child(yes_btn)

	var no_btn = Button.new()
	no_btn.text = "CANCEL"
	no_btn.add_theme_font_size_override("font_size", 14)
	no_btn.custom_minimum_size = Vector2(110, 30)
	btn_row.add_child(no_btn)

	yes_btn.pressed.connect(func():
		overlay.queue_free()
		panel.queue_free()
		_execute_new_game()
	)
	no_btn.pressed.connect(func():
		overlay.queue_free()
		panel.queue_free()
	)

func _execute_new_game() -> void:
	SaveManager.delete_save()
	GameState.permanent = SaveManager.DEFAULT_PERM.duplicate()
	var card_db = get_node_or_null("/root/CardDB")
	if card_db:
		card_db.reset()
	GameState.start_new_run()
	SaveManager.save_game()
	# Route to tutorial on first ever launch, otherwise straight to hub
	var target_scene := "res://scenes/base_hub.tscn"
	if not GameState.tutorial_completed:
		target_scene = "res://scenes/tutorial_arena.tscn"
	var tw = create_tween()
	tw.tween_property(self, "modulate", Color(1, 1, 1, 0), 0.3).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		if target_scene == "res://scenes/tutorial_arena.tscn":
			# Tutorial handles its own phase management
			pass
		else:
			GameState.set_phase(GameState.Phase.BASE_HUB)
		get_tree().change_scene_to_file(target_scene)
	)

func _on_options() -> void:
	if _options_panel:
		_options_panel.visible = true
		_options_panel.modulate.a = 0.0
		var tw = create_tween()
		tw.tween_property(_options_panel, "modulate:a", 1.0, 0.2)

func _close_options() -> void:
	if _options_panel:
		var tw = create_tween()
		tw.tween_property(_options_panel, "modulate:a", 0.0, 0.15)
		tw.tween_callback(func(): _options_panel.visible = false)

func _on_quit() -> void:
	SaveManager.save_game()
	get_tree().quit()

func _on_switch_profile() -> void:
	_game_menu_layer.visible = false
	_profile_layer.visible = true
	_profile_layer.modulate.a = 1.0
	_refresh_profile_cards()

# ─── Profile Selection ──────────────────────────────────────

func _build_profile_selection() -> void:
	# Semi-transparent overlay
	var overlay = ColorRect.new()
	overlay.color = Color(0.03, 0.02, 0.05, 0.85)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_profile_layer.add_child(overlay)

	# Title
	var title = Label.new()
	title.text = "SELECT PROFILE"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", CLR_GOLD_TEXT)
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	title.add_theme_constant_override("shadow_offset_x", 2)
	title.add_theme_constant_override("shadow_offset_y", 2)
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.offset_top = 40
	title.offset_left = -200
	title.offset_right = 200
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_profile_layer.add_child(title)

	# Cards container
	var cards = HBoxContainer.new()
	cards.name = "ProfileCards"
	cards.add_theme_constant_override("separation", 16)
	cards.set_anchors_preset(Control.PRESET_CENTER)
	cards.offset_left = -340
	cards.offset_right = 340
	cards.offset_top = -50
	cards.offset_bottom = 100
	cards.alignment = BoxContainer.ALIGNMENT_CENTER
	_profile_layer.add_child(cards)

	_refresh_profile_cards()

func _refresh_profile_cards() -> void:
	var cards = _profile_layer.get_node_or_null("ProfileCards")
	if not cards: return
	# Clear existing cards
	for child in cards.get_children():
		child.queue_free()
	# Get profile data
	var profiles = SaveManager.get_all_profiles()
	var occupied_slots = {}
	for p in profiles:
		occupied_slots[p.slot] = p
	# Build 4 cards
	for slot in range(1, SaveManager.MAX_PROFILES + 1):
		if slot in occupied_slots:
			cards.add_child(_build_profile_card(slot, occupied_slots[slot]))
		else:
			cards.add_child(_build_empty_card(slot))

func _build_profile_card(slot: int, data: Dictionary) -> Control:
	var card = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.06, 0.12, 0.95)
	style.border_color = CLR_GOLD_TEXT.darkened(0.2)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(10)
	card.add_theme_stylebox_override("panel", style)
	card.custom_minimum_size = Vector2(150, 130)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	card.add_child(vbox)

	# Profile name
	var name_lbl = Label.new()
	name_lbl.text = data.name
	name_lbl.add_theme_font_size_override("font_size", 16)
	name_lbl.add_theme_color_override("font_color", CLR_GOLD_TEXT)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(name_lbl)

	# Separator
	var sep = ColorRect.new()
	sep.color = CLR_GOLD_TEXT.darkened(0.4)
	sep.custom_minimum_size = Vector2(0, 1)
	vbox.add_child(sep)

	# Stats
	var wave_lbl = Label.new()
	var wave_text = "Wave %d" % data.wave if data.wave > 0 else "Not started"
	wave_lbl.text = wave_text
	wave_lbl.add_theme_font_size_override("font_size", 11)
	wave_lbl.add_theme_color_override("font_color", CLR_SILVER_TEXT)
	wave_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(wave_lbl)

	var runs_lbl = Label.new()
	runs_lbl.text = "%d runs" % data.runs if data.runs > 0 else "New player"
	runs_lbl.add_theme_font_size_override("font_size", 10)
	runs_lbl.add_theme_color_override("font_color", CLR_DIM_TEXT)
	runs_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(runs_lbl)

	# Status
	if data.has_run:
		var status = Label.new()
		status.text = "Run in progress"
		status.add_theme_font_size_override("font_size", 9)
		status.add_theme_color_override("font_color", CLR_GREEN)
		status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(status)

	# Buttons row
	var btn_row = HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 6)
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btn_row)

	var play_btn = Button.new()
	play_btn.text = "PLAY"
	play_btn.add_theme_font_size_override("font_size", 12)
	play_btn.custom_minimum_size = Vector2(70, 24)
	var play_style = StyleBoxFlat.new()
	play_style.bg_color = Color(0.15, 0.35, 0.15)
	play_style.border_color = CLR_GREEN
	play_style.set_border_width_all(1)
	play_style.set_corner_radius_all(3)
	play_style.set_content_margin_all(4)
	play_btn.add_theme_stylebox_override("normal", play_style)
	play_btn.pressed.connect(func(): _on_profile_selected(slot))
	btn_row.add_child(play_btn)

	var del_btn = Button.new()
	del_btn.text = "X"
	del_btn.add_theme_font_size_override("font_size", 11)
	del_btn.custom_minimum_size = Vector2(24, 24)
	var del_style = StyleBoxFlat.new()
	del_style.bg_color = Color(0.3, 0.1, 0.1)
	del_style.border_color = CLR_RED.darkened(0.2)
	del_style.set_border_width_all(1)
	del_style.set_corner_radius_all(3)
	del_style.set_content_margin_all(2)
	del_btn.add_theme_stylebox_override("normal", del_style)
	del_btn.pressed.connect(func(): _confirm_delete_profile(slot, data.name))
	btn_row.add_child(del_btn)

	return card

func _build_empty_card(slot: int) -> Control:
	var card = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.04, 0.08, 0.7)
	style.border_color = CLR_DIM_TEXT.darkened(0.3)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(10)
	card.add_theme_stylebox_override("panel", style)
	card.custom_minimum_size = Vector2(150, 130)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(vbox)

	var plus_lbl = Label.new()
	plus_lbl.text = "+"
	plus_lbl.add_theme_font_size_override("font_size", 36)
	plus_lbl.add_theme_color_override("font_color", CLR_DIM_TEXT)
	plus_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(plus_lbl)

	var create_btn = Button.new()
	create_btn.text = "CREATE"
	create_btn.add_theme_font_size_override("font_size", 12)
	create_btn.custom_minimum_size = Vector2(100, 24)
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.12, 0.10, 0.16)
	btn_style.border_color = CLR_DIM_TEXT.darkened(0.2)
	btn_style.set_border_width_all(1)
	btn_style.set_corner_radius_all(3)
	btn_style.set_content_margin_all(4)
	create_btn.add_theme_stylebox_override("normal", btn_style)
	create_btn.pressed.connect(func(): _show_create_popup(slot))
	vbox.add_child(create_btn)

	return card

func _on_profile_selected(slot: int) -> void:
	SaveManager.select_profile(slot)
	# Update continue button visibility
	_continue_btn.visible = _has_save_progress()
	# Fade profile layer out, show game menu
	var tw = create_tween()
	tw.tween_property(_profile_layer, "modulate:a", 0.0, 0.25)
	tw.tween_callback(func():
		_profile_layer.visible = false
		_game_menu_layer.visible = true
	)
	var tw2 = create_tween()
	tw2.tween_property(_game_menu_layer, "modulate:a", 1.0, 0.3).set_delay(0.2)

func _show_create_popup(slot: int) -> void:
	var popup = Control.new()
	popup.set_anchors_preset(Control.PRESET_FULL_RECT)
	popup.z_index = 20
	_profile_layer.add_child(popup)

	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.6)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	popup.add_child(bg)

	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.06, 0.12, 0.95)
	style.border_color = CLR_GOLD_TEXT
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", style)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -120
	panel.offset_right = 120
	panel.offset_top = -60
	panel.offset_bottom = 60
	popup.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	var title = Label.new()
	title.text = "Enter Profile Name"
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", CLR_GOLD_TEXT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var input = LineEdit.new()
	input.max_length = 12
	input.placeholder_text = "Name (max 12)"
	input.add_theme_font_size_override("font_size", 14)
	input.custom_minimum_size = Vector2(200, 28)
	vbox.add_child(input)

	var btn_row = HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 12)
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btn_row)

	var ok_btn = Button.new()
	ok_btn.text = "CREATE"
	ok_btn.add_theme_font_size_override("font_size", 13)
	ok_btn.custom_minimum_size = Vector2(80, 26)
	ok_btn.pressed.connect(func():
		var pname = input.text.strip_edges()
		if pname.is_empty():
			input.placeholder_text = "Name required!"
			return
		SaveManager.create_profile(slot, pname)
		popup.queue_free()
		_on_profile_selected(slot)
	)
	btn_row.add_child(ok_btn)

	var cancel_btn = Button.new()
	cancel_btn.text = "CANCEL"
	cancel_btn.add_theme_font_size_override("font_size", 13)
	cancel_btn.custom_minimum_size = Vector2(80, 26)
	cancel_btn.pressed.connect(func(): popup.queue_free())
	btn_row.add_child(cancel_btn)

	# Focus the input
	input.call_deferred("grab_focus")

func _confirm_delete_profile(slot: int, profile_name: String) -> void:
	var popup = Control.new()
	popup.set_anchors_preset(Control.PRESET_FULL_RECT)
	popup.z_index = 20
	_profile_layer.add_child(popup)

	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.6)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	popup.add_child(bg)

	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.06, 0.06, 0.95)
	style.border_color = CLR_RED
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", style)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -130
	panel.offset_right = 130
	panel.offset_top = -50
	panel.offset_bottom = 50
	popup.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	var warn = Label.new()
	warn.text = "Delete '%s'?\nAll progress will be lost!" % profile_name
	warn.add_theme_font_size_override("font_size", 13)
	warn.add_theme_color_override("font_color", Color(1.0, 0.7, 0.3))
	warn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(warn)

	var btn_row = HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 16)
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btn_row)

	var yes_btn = Button.new()
	yes_btn.text = "DELETE"
	yes_btn.add_theme_font_size_override("font_size", 13)
	yes_btn.add_theme_color_override("font_color", CLR_RED)
	yes_btn.custom_minimum_size = Vector2(80, 26)
	yes_btn.pressed.connect(func():
		SaveManager.delete_profile(slot)
		popup.queue_free()
		_refresh_profile_cards()
	)
	btn_row.add_child(yes_btn)

	var no_btn = Button.new()
	no_btn.text = "CANCEL"
	no_btn.add_theme_font_size_override("font_size", 13)
	no_btn.custom_minimum_size = Vector2(80, 26)
	no_btn.pressed.connect(func(): popup.queue_free())
	btn_row.add_child(no_btn)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and _options_panel and _options_panel.visible:
		_close_options()
