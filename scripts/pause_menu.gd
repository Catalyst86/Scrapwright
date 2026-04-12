extends CanvasLayer

# ============================================================
# PauseMenu — In-game pause with save, options, quit
# ============================================================

const CLR_GOLD    = Color(0.95, 0.82, 0.35)
const CLR_DIM     = Color(0.55, 0.55, 0.55)
const CLR_BG      = Color(0.05, 0.04, 0.08, 0.92)
const CLR_BORDER  = Color(0.72, 0.58, 0.25)
const CLR_BTN     = Color(0.12, 0.10, 0.16)
const CLR_BTN_HOV = Color(0.18, 0.15, 0.22)

var _overlay: ColorRect
var _panel: PanelContainer
var _options_visible: bool = false
var _options_container: VBoxContainer
var _save_feedback: Label
var is_open: bool = false

func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

func open() -> void:
	if is_open: return
	is_open = true
	visible = true
	get_tree().paused = true
	AudioManager.play("pause")
	_build_menu()

func close() -> void:
	if not is_open: return
	is_open = false
	visible = false
	get_tree().paused = false
	# Clean up children
	for child in get_children():
		child.queue_free()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and is_open:
		close()
		get_viewport().set_input_as_handled()

func _build_menu() -> void:
	# Dark overlay
	_overlay = ColorRect.new()
	_overlay.color = Color(0, 0, 0, 0.7)
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_overlay)

	# Center panel
	_panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = CLR_BG
	style.border_color = CLR_BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(20)
	_panel.add_theme_stylebox_override("panel", style)
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.offset_left = -155
	_panel.offset_right = 155
	_panel.offset_top = -200
	_panel.offset_bottom = 200
	add_child(_panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	_panel.add_child(vbox)

	# Title
	var title = Label.new()
	title.text = "PAUSED"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", CLR_GOLD)
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	title.add_theme_constant_override("shadow_offset_x", 2)
	title.add_theme_constant_override("shadow_offset_y", 2)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	# Separator
	var sep = ColorRect.new()
	sep.color = CLR_BORDER.darkened(0.3)
	sep.custom_minimum_size = Vector2(0, 2)
	vbox.add_child(sep)

	# Spacer
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 4)
	vbox.add_child(spacer)

	# RESUME
	_add_button(vbox, "RESUME", func(): close())

	# SAVE GAME
	_add_button(vbox, "SAVE GAME", func(): _do_save())

	# Save feedback label (hidden initially)
	_save_feedback = Label.new()
	_save_feedback.text = ""
	_save_feedback.add_theme_font_size_override("font_size", 12)
	_save_feedback.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4))
	_save_feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_save_feedback.visible = false
	vbox.add_child(_save_feedback)

	# INVENTORY section (left side panel)
	_build_inventory(vbox)
	# CONTROLS section (right side panel)
	_build_controls_panel()

	# OPTIONS toggle
	_add_button(vbox, "OPTIONS", func(): _toggle_options())

	# Options container (hidden initially)
	_options_container = VBoxContainer.new()
	_options_container.add_theme_constant_override("separation", 6)
	_options_container.visible = false
	vbox.add_child(_options_container)
	_build_options()

	# Separator
	var sep2 = ColorRect.new()
	sep2.color = CLR_BORDER.darkened(0.5)
	sep2.custom_minimum_size = Vector2(0, 1)
	vbox.add_child(sep2)

	# RETURN TO HUB
	_add_button(vbox, "RETURN TO HUB", func(): _return_to_hub(), Color(0.5, 0.8, 0.5))

	# QUIT TO MENU
	_add_button(vbox, "QUIT TO MENU", func(): _quit_to_menu(), Color(0.9, 0.7, 0.3))

	# QUIT TO DESKTOP
	_add_button(vbox, "QUIT TO DESKTOP", func(): get_tree().quit(), Color(0.8, 0.3, 0.3))

func _build_inventory(_parent: VBoxContainer) -> void:
	# Build a separate side panel to the left of the main pause menu
	var side_panel = PanelContainer.new()
	var side_style = StyleBoxFlat.new()
	side_style.bg_color = Color(0.08, 0.07, 0.12, 0.95)
	side_style.border_color = CLR_BORDER.darkened(0.2)
	side_style.set_border_width_all(1)
	side_style.set_corner_radius_all(6)
	side_style.set_content_margin_all(10)
	side_panel.add_theme_stylebox_override("panel", side_style)
	side_panel.set_anchors_preset(Control.PRESET_CENTER)
	side_panel.offset_left = -340
	side_panel.offset_right = -170
	side_panel.offset_top = -160
	side_panel.offset_bottom = 160
	_overlay.add_child(side_panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	side_panel.add_child(vbox)

	# Title
	var title = Label.new()
	title.text = "INVENTORY"
	title.add_theme_font_size_override("font_size", 11)
	title.add_theme_color_override("font_color", CLR_GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	# Separator
	var sep = ColorRect.new()
	sep.color = CLR_BORDER.darkened(0.3)
	sep.custom_minimum_size = Vector2(0, 1)
	vbox.add_child(sep)

	# Run info
	var stage = GameState.get_current_stage() + 1
	var stage_wave = GameState.get_stage_wave()
	var info_lbl = Label.new()
	info_lbl.text = "Stage %d  Wave %d  Lv %d" % [stage, stage_wave, GameState.player_level]
	info_lbl.add_theme_font_size_override("font_size", 9)
	info_lbl.add_theme_color_override("font_color", CLR_DIM)
	info_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(info_lbl)

	# Spacer
	var sp1 = Control.new()
	sp1.custom_minimum_size = Vector2(0, 2)
	vbox.add_child(sp1)

	# Materials header
	var mat_title = Label.new()
	mat_title.text = "Materials"
	mat_title.add_theme_font_size_override("font_size", 10)
	mat_title.add_theme_color_override("font_color", Color(0.85, 0.75, 0.5))
	vbox.add_child(mat_title)

	# Materials list (vertical, clean)
	var mat_data = {
		"iron_scrap": ["Iron", Color(0.7, 0.7, 0.75)],
		"timber": ["Wood", Color(0.65, 0.45, 0.25)],
		"stone": ["Stone", Color(0.6, 0.6, 0.6)],
		"fuel": ["Fuel", Color(0.9, 0.4, 0.2)],
		"organic": ["Herb", Color(0.4, 0.8, 0.3)],
		"blueprint": ["Blueprint", Color(0.4, 0.6, 0.95)],
	}

	for mat_key in mat_data:
		var amount = GameState.materials.get(mat_key, 0)
		var data = mat_data[mat_key]
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		var name_lbl = Label.new()
		name_lbl.text = data[0]
		name_lbl.add_theme_font_size_override("font_size", 9)
		name_lbl.add_theme_color_override("font_color", data[1] if amount > 0 else CLR_DIM)
		name_lbl.custom_minimum_size.x = 70
		row.add_child(name_lbl)
		var amt_lbl = Label.new()
		amt_lbl.text = str(amount)
		amt_lbl.add_theme_font_size_override("font_size", 9)
		amt_lbl.add_theme_color_override("font_color", Color(1, 1, 1) if amount > 0 else CLR_DIM)
		row.add_child(amt_lbl)
		vbox.add_child(row)

	# Spacer
	var sp2 = Control.new()
	sp2.custom_minimum_size = Vector2(0, 4)
	vbox.add_child(sp2)

	# Keys header
	var key_title = Label.new()
	key_title.text = "Keys"
	key_title.add_theme_font_size_override("font_size", 10)
	key_title.add_theme_color_override("font_color", Color(0.85, 0.75, 0.5))
	vbox.add_child(key_title)

	var key_colors = {
		"bronze": ["Bronze", Color(0.72, 0.45, 0.20)],
		"silver": ["Silver", Color(0.75, 0.75, 0.80)],
		"gold": ["Gold", Color(1.0, 0.84, 0.0)],
		"secret": ["Secret", Color(0.6, 0.2, 0.9)],
	}
	for key_tier in key_colors:
		var count = GameState.get_key_count(key_tier)
		var data = key_colors[key_tier]
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		var name_lbl = Label.new()
		name_lbl.text = data[0]
		name_lbl.add_theme_font_size_override("font_size", 9)
		name_lbl.add_theme_color_override("font_color", data[1] if count > 0 else CLR_DIM)
		name_lbl.custom_minimum_size.x = 70
		row.add_child(name_lbl)
		var amt_lbl = Label.new()
		amt_lbl.text = str(count)
		amt_lbl.add_theme_font_size_override("font_size", 9)
		amt_lbl.add_theme_color_override("font_color", Color(1, 1, 1) if count > 0 else CLR_DIM)
		row.add_child(amt_lbl)
		vbox.add_child(row)

	# Spacer
	var sp3 = Control.new()
	sp3.custom_minimum_size = Vector2(0, 4)
	vbox.add_child(sp3)

	# Abilities
	var ability_title = Label.new()
	ability_title.text = "Abilities"
	ability_title.add_theme_font_size_override("font_size", 10)
	ability_title.add_theme_color_override("font_color", Color(0.85, 0.75, 0.5))
	vbox.add_child(ability_title)

	var dig_lbl = Label.new()
	dig_lbl.text = "Dig Traps  %d/%d" % [GameState.dig_charges, GameState.dig_charges_max]
	dig_lbl.add_theme_font_size_override("font_size", 9)
	dig_lbl.add_theme_color_override("font_color", Color(0.85, 0.65, 0.3))
	vbox.add_child(dig_lbl)

	var orb_title = Label.new()
	orb_title.text = "Orbitals  %d/%d" % [GameState.orbital_weapons.size(), OrbitalDB.MAX_ORBITALS]
	orb_title.add_theme_font_size_override("font_size", 9)
	orb_title.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
	vbox.add_child(orb_title)
	for ow in GameState.orbital_weapons:
		var wdata = OrbitalDB.get_weapon_data(ow.id)
		var wname = wdata.get("name", ow.id)
		var wcolor = wdata.get("color", Color(0.6, 0.8, 1.0))
		var ow_lbl = Label.new()
		ow_lbl.text = "  %s Lv%d" % [wname, ow.level]
		ow_lbl.add_theme_font_size_override("font_size", 8)
		ow_lbl.add_theme_color_override("font_color", wcolor)
		vbox.add_child(ow_lbl)

	# Perks
	if not GameState.active_perks.is_empty():
		var sp4 = Control.new()
		sp4.custom_minimum_size = Vector2(0, 4)
		vbox.add_child(sp4)

		var perk_title = Label.new()
		perk_title.text = "Perks"
		perk_title.add_theme_font_size_override("font_size", 10)
		perk_title.add_theme_color_override("font_color", Color(0.85, 0.75, 0.5))
		vbox.add_child(perk_title)

		var perk_counts = {}
		for p in GameState.active_perks:
			perk_counts[p] = perk_counts.get(p, 0) + 1
		for p in perk_counts:
			var perk_name = p.replace("_", " ").capitalize()
			var plbl = Label.new()
			if perk_counts[p] > 1:
				plbl.text = "%s x%d" % [perk_name, perk_counts[p]]
			else:
				plbl.text = perk_name
			plbl.add_theme_font_size_override("font_size", 9)
			plbl.add_theme_color_override("font_color", Color(0.8, 0.6, 1.0))
			vbox.add_child(plbl)

func _build_controls_panel() -> void:
	var side_panel = PanelContainer.new()
	var side_style = StyleBoxFlat.new()
	side_style.bg_color = Color(0.08, 0.07, 0.12, 0.95)
	side_style.border_color = CLR_BORDER.darkened(0.2)
	side_style.set_border_width_all(1)
	side_style.set_corner_radius_all(6)
	side_style.set_content_margin_all(10)
	side_panel.add_theme_stylebox_override("panel", side_style)
	side_panel.set_anchors_preset(Control.PRESET_CENTER)
	side_panel.offset_left = 170
	side_panel.offset_right = 340
	side_panel.offset_top = -160
	side_panel.offset_bottom = 160
	_overlay.add_child(side_panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	side_panel.add_child(vbox)

	# Title
	var title = Label.new()
	title.text = "CONTROLS"
	title.add_theme_font_size_override("font_size", 11)
	title.add_theme_color_override("font_color", CLR_GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var sep = ColorRect.new()
	sep.color = CLR_BORDER.darkened(0.3)
	sep.custom_minimum_size = Vector2(0, 1)
	vbox.add_child(sep)

	var controls = [
		["WASD", "Move", Color(0.8, 0.8, 0.8)],
		["SPACE", "Dodge", Color(0.6, 0.9, 1.0)],
		["CTRL", "Sneak", Color(0.7, 0.7, 0.7)],
		["F", "Dig Trap", Color(0.85, 0.65, 0.3)],
		["SHIFT", "Collect", Color(0.6, 0.85, 0.5)],
		["ESC", "Pause", Color(0.9, 0.9, 0.9)],
	]

	for entry in controls:
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)

		var key_lbl = Label.new()
		key_lbl.text = entry[0]
		key_lbl.add_theme_font_size_override("font_size", 9)
		key_lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 0.7))
		key_lbl.custom_minimum_size.x = 50
		row.add_child(key_lbl)

		var desc_lbl = Label.new()
		desc_lbl.text = entry[1]
		desc_lbl.add_theme_font_size_override("font_size", 9)
		desc_lbl.add_theme_color_override("font_color", entry[2])
		row.add_child(desc_lbl)

		vbox.add_child(row)

	# Spacer
	var sp = Control.new()
	sp.custom_minimum_size = Vector2(0, 6)
	vbox.add_child(sp)

	# Tips section
	var tips_title = Label.new()
	tips_title.text = "TIPS"
	tips_title.add_theme_font_size_override("font_size", 11)
	tips_title.add_theme_color_override("font_color", CLR_GOLD)
	tips_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(tips_title)

	var sep2 = ColorRect.new()
	sep2.color = CLR_BORDER.darkened(0.3)
	sep2.custom_minimum_size = Vector2(0, 1)
	vbox.add_child(sep2)

	var tips = [
		["Dodge gives brief invincibility", Color(0.6, 0.9, 1.0)],
		["Sneak then bite for 2x damage", Color(0.7, 0.7, 0.7)],
		["Dig traps stun enemies", Color(0.85, 0.65, 0.3)],
		["Collect scrap for cards", Color(0.6, 0.85, 0.5)],
		["Any key opens any chest — combine 3 keys to upgrade tier", Color(1.0, 0.84, 0.0)],
	]

	for tip in tips:
		var tip_lbl = Label.new()
		tip_lbl.text = tip[0]
		tip_lbl.add_theme_font_size_override("font_size", 8)
		tip_lbl.add_theme_color_override("font_color", tip[1].darkened(0.2))
		tip_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		tip_lbl.custom_minimum_size.x = 140
		vbox.add_child(tip_lbl)

func _add_button(parent: Control, text: String, callback: Callable, color: Color = Color.WHITE) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.add_theme_font_size_override("font_size", 14)
	btn.add_theme_color_override("font_color", color)
	btn.custom_minimum_size = Vector2(200, 32)

	# Style the button
	var normal = StyleBoxFlat.new()
	normal.bg_color = CLR_BTN
	normal.border_color = CLR_BORDER.darkened(0.2)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(4)
	normal.set_content_margin_all(6)
	btn.add_theme_stylebox_override("normal", normal)

	var hover = StyleBoxFlat.new()
	hover.bg_color = CLR_BTN_HOV
	hover.border_color = CLR_GOLD
	hover.set_border_width_all(1)
	hover.set_corner_radius_all(4)
	hover.set_content_margin_all(6)
	btn.add_theme_stylebox_override("hover", hover)

	var pressed = hover.duplicate()
	pressed.bg_color = CLR_BTN_HOV.lightened(0.1)
	btn.add_theme_stylebox_override("pressed", pressed)

	btn.pressed.connect(callback)
	parent.add_child(btn)
	return btn

func _build_options() -> void:
	# Volume
	var vol_row = HBoxContainer.new()
	vol_row.add_theme_constant_override("separation", 8)
	_options_container.add_child(vol_row)

	var vol_lbl = Label.new()
	vol_lbl.text = "Volume"
	vol_lbl.add_theme_font_size_override("font_size", 12)
	vol_lbl.add_theme_color_override("font_color", CLR_DIM)
	vol_lbl.custom_minimum_size.x = 70
	vol_row.add_child(vol_lbl)

	var vol_slider = HSlider.new()
	vol_slider.min_value = 0.0
	vol_slider.max_value = 1.0
	vol_slider.step = 0.05
	vol_slider.value = db_to_linear(AudioServer.get_bus_volume_db(0))
	vol_slider.custom_minimum_size = Vector2(120, 20)
	vol_slider.value_changed.connect(func(val):
		AudioServer.set_bus_volume_db(0, linear_to_db(val))
	)
	vol_row.add_child(vol_slider)

	# Fullscreen
	var fs_row = HBoxContainer.new()
	fs_row.add_theme_constant_override("separation", 8)
	_options_container.add_child(fs_row)

	var fs_lbl = Label.new()
	fs_lbl.text = "Fullscreen"
	fs_lbl.add_theme_font_size_override("font_size", 12)
	fs_lbl.add_theme_color_override("font_color", CLR_DIM)
	fs_lbl.custom_minimum_size.x = 70
	fs_row.add_child(fs_lbl)

	var fs_check = CheckButton.new()
	fs_check.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	fs_check.toggled.connect(func(on):
		if on:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	)
	fs_row.add_child(fs_check)

	# Music volume
	var music_row = HBoxContainer.new()
	music_row.add_theme_constant_override("separation", 8)
	_options_container.add_child(music_row)

	var music_lbl = Label.new()
	music_lbl.text = "Music"
	music_lbl.add_theme_font_size_override("font_size", 12)
	music_lbl.add_theme_color_override("font_color", CLR_DIM)
	music_lbl.custom_minimum_size.x = 70
	music_row.add_child(music_lbl)

	var music_slider = HSlider.new()
	music_slider.min_value = 0.0
	music_slider.max_value = 1.0
	music_slider.step = 0.05
	music_slider.value = AudioManager.music_volume
	music_slider.custom_minimum_size = Vector2(120, 20)
	music_slider.value_changed.connect(func(val):
		AudioManager.set_music_volume(val)
	)
	music_row.add_child(music_slider)

	# SFX volume
	var sfx_row = HBoxContainer.new()
	sfx_row.add_theme_constant_override("separation", 8)
	_options_container.add_child(sfx_row)

	var sfx_lbl = Label.new()
	sfx_lbl.text = "SFX"
	sfx_lbl.add_theme_font_size_override("font_size", 12)
	sfx_lbl.add_theme_color_override("font_color", CLR_DIM)
	sfx_lbl.custom_minimum_size.x = 70
	sfx_row.add_child(sfx_lbl)

	var sfx_slider = HSlider.new()
	sfx_slider.min_value = 0.0
	sfx_slider.max_value = 1.0
	sfx_slider.step = 0.05
	sfx_slider.value = AudioManager.sfx_volume
	sfx_slider.custom_minimum_size = Vector2(120, 20)
	sfx_slider.value_changed.connect(func(val):
		AudioManager.set_sfx_volume(val)
	)
	sfx_row.add_child(sfx_slider)

func _toggle_options() -> void:
	_options_visible = not _options_visible
	_options_container.visible = _options_visible

func _do_save() -> void:
	SaveManager.save_game()
	_save_feedback.text = "SAVED!"
	_save_feedback.visible = true
	_save_feedback.modulate = Color(1, 1, 1, 1)
	# Fade out after 1.5s
	var tw = create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_interval(1.5)
	tw.tween_property(_save_feedback, "modulate:a", 0.0, 0.5)
	tw.tween_callback(func():
		if is_instance_valid(_save_feedback):
			_save_feedback.visible = false
			_save_feedback.text = ""
	)

func _return_to_hub() -> void:
	get_tree().paused = false
	is_open = false
	# Stop the wave cleanly so spawn queue is cleared
	WaveManager.abort_wave()
	# Properly exit junkyard (merges materials) if active
	var jy = get_node_or_null("/root/JunkyardState")
	if jy and jy.is_active:
		jy.exit_junkyard()
	# Restore state to what it was at the START of this wave
	# (undo any XP, materials, perks, health changes gained mid-wave)
	GameState.restore_wave_start()
	# Revert current_wave so re-entering replays the same wave
	if WaveManager.current_wave > 0 and GameState.current_wave >= WaveManager.current_wave:
		GameState.current_wave = WaveManager.current_wave - 1
	SaveManager.save_game()
	GameState.set_phase(GameState.Phase.BASE_HUB)
	get_tree().call_deferred("change_scene_to_file", "res://scenes/base_hub.tscn")

func _quit_to_menu() -> void:
	get_tree().paused = false
	is_open = false
	# Preserve run progress — stop wave cleanly
	WaveManager.abort_wave()
	GameState.restore_wave_start()
	if WaveManager.current_wave > 0 and GameState.current_wave >= WaveManager.current_wave:
		GameState.current_wave = WaveManager.current_wave - 1
	SaveManager.save_game()
	get_tree().call_deferred("change_scene_to_file", "res://scenes/main_menu.tscn")
