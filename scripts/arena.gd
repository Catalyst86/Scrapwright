extends Node2D

# ============================================================
# Arena — Main combat scene
# ============================================================

const DEBUG_ENABLED := true  # Set to true during development only

enum ArenaPhase { PREP, COMBAT, CHEST_PHASE, TRANSITION }

@onready var player: CharacterBody2D       = $Player
@onready var enemies_container: Node2D     = $EnemiesContainer
@onready var props_container: Node2D       = $PropsContainer
@onready var pickups_container: Node2D     = $PickupsContainer
@onready var level_up_screen: Control      = $LevelUpLayer/LevelUp
@onready var hud: CanvasLayer              = $HUD

const ArenaBuilderScript   = preload("res://scripts/arena_builder.gd")
const ChestScene           = preload("res://scenes/chest.tscn")
const SecretDoorScene      = preload("res://scenes/secret_door.tscn")
const PauseMenuScript      = preload("res://scripts/pause_menu.gd")
const CardPopupScene       = preload("res://scenes/card_popup.tscn")

const ARENA_W = 1280
const ARENA_H = 720

var arena_phase: ArenaPhase = ArenaPhase.PREP
var last_player_level: int = -1  # Set from GameState in _ready()
var _zero_enemies_timer: float = 0.0  # Safety: force-complete wave if stuck at 0
var _last_known_health: int = -1

# Chest phase tracking
var _active_chests: Array = []

# Secret door tracking
var _secret_door: Area2D = null
const SECRET_DOOR_DURATION = 10.0

var _pause_menu: CanvasLayer = null
var _card_popup: CanvasLayer = null

func _ready() -> void:
	# Sync level tracker with actual player level to prevent false level-up popups
	last_player_level = GameState.player_level
	# Music is started per-wave in _start_combat() based on wave number
	var builder = Node2D.new()
	builder.set_script(ArenaBuilderScript)
	add_child(builder)
	# Pass current stage theme to builder
	var stage_theme = StageData.get_theme(GameState.current_wave + 1)
	builder.build(stage_theme)

	WaveManager.register_arena(enemies_container)
	WaveManager.wave_complete.connect(_on_wave_complete)
	WaveManager.all_waves_complete.connect(_on_all_waves_complete)
	GameState.health_changed.connect(_on_health_changed)
	GameState.materials_changed.connect(_update_hud)
	if player:
		player.died.connect(_on_player_died)

	# Make pickups_container findable for chest loot drops
	if pickups_container and not pickups_container.is_in_group("pickups_container"):
		pickups_container.add_to_group("pickups_container")

	# Camera follows player (arena is bigger than viewport)
	if player and not player.get_node_or_null("Camera2D"):
		var cam = Camera2D.new()
		cam.name = "Camera2D"
		cam.zoom = Vector2(2.0, 2.0)
		cam.limit_left = 0
		cam.limit_top = 0
		cam.limit_right = ARENA_W
		cam.limit_bottom = ARENA_H
		cam.position_smoothing_enabled = true
		cam.position_smoothing_speed = 8.0
		player.add_child(cam)

	_setup_spawn_points()
	_spawn_destructible_props()
	_start_combat()
	_update_hud()
	_restore_regen_perk()
	_restore_card_perks()
	# Pause menu
	_pause_menu = CanvasLayer.new()
	_pause_menu.set_script(PauseMenuScript)
	add_child(_pause_menu)
	# Card popup
	_card_popup = CardPopupScene.instantiate()
	add_child(_card_popup)

func _exit_tree() -> void:
	# Disconnect autoload signals to prevent leaks after scene change
	if WaveManager.wave_complete.is_connected(_on_wave_complete):
		WaveManager.wave_complete.disconnect(_on_wave_complete)
	if WaveManager.all_waves_complete.is_connected(_on_all_waves_complete):
		WaveManager.all_waves_complete.disconnect(_on_all_waves_complete)
	if GameState.health_changed.is_connected(_on_health_changed):
		GameState.health_changed.disconnect(_on_health_changed)
	if GameState.materials_changed.is_connected(_update_hud):
		GameState.materials_changed.disconnect(_update_hud)
	if GameState.keys_changed.is_connected(_refresh_chest_event_ui):
		GameState.keys_changed.disconnect(_refresh_chest_event_ui)

func _unhandled_input(event: InputEvent) -> void:
	if DEBUG_ENABLED:
		if event is InputEventKey and event.pressed and event.keycode == KEY_F1:
			_toggle_god_mode()
			get_viewport().set_input_as_handled()
			return
		if event is InputEventKey and event.pressed and event.keycode == KEY_F2:
			_show_wave_skip_dialog()
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed("ui_cancel"):
		# Don't open pause if level-up is showing (already paused)
		if level_up_screen and level_up_screen.visible:
			return
		if _pause_menu:
			if _pause_menu.is_open:
				_pause_menu.close()
			else:
				_pause_menu.open()
			get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	match arena_phase:
		ArenaPhase.COMBAT:
			_check_level_up()
			# Safety: if all enemies dead AND spawn queue empty but wave hasn't completed, force it after 3s
			if WaveManager.wave_active and WaveManager.enemies_alive <= 0 and WaveManager.spawn_queue.is_empty():
				_zero_enemies_timer += delta
				if _zero_enemies_timer > 3.0:
					_zero_enemies_timer = 0.0
					if WaveManager.wave_active:  # Double-check guard
						WaveManager.force_complete_wave()
			else:
				_zero_enemies_timer = 0.0
		ArenaPhase.CHEST_PHASE: _process_chest_phase(delta)
	_update_xp_bar()



func _check_level_up() -> void:
	# Only advance one level at a time so the player gets a perk choice per level
	if GameState.player_level > last_player_level:
		last_player_level += 1
		if level_up_screen:
			level_up_screen.show_level_up(last_player_level)

func _setup_spawn_points() -> void:
	WaveManager.clear_spawn_points()
	var m = 14
	for pos in [
		Vector2(m, ARENA_H / 2.0), Vector2(ARENA_W - m, ARENA_H / 2.0),
		Vector2(ARENA_W / 2.0, m), Vector2(ARENA_W / 2.0, ARENA_H - m),
		Vector2(m, m), Vector2(ARENA_W-m, m),
		Vector2(m, ARENA_H-m), Vector2(ARENA_W-m, ARENA_H-m),
	]:
		WaveManager.register_spawn_point(pos)

func _spawn_destructible_props() -> void:
	var prop_scene = load("res://scenes/destructible_prop.tscn")
	if not prop_scene:
		return
	var prop_list = [
		{"type":"crate",  "hp":2}, {"type":"crate",  "hp":2},
		{"type":"crate",  "hp":3}, {"type":"barrel", "hp":3},
		{"type":"barrel", "hp":2}, {"type":"rubble",  "hp":4},
		{"type":"rubble", "hp":3}, {"type":"corpse",  "hp":2},
	]
	for _i in min(GameState.current_wave, 6):
		prop_list.append({"type": ["crate","barrel","rubble"][randi()%3], "hp": randi_range(2,4)})

	var center = Vector2(ARENA_W / 2.0, ARENA_H / 2.0)
	for entry in prop_list:
		var pos  = _rand_prop_pos(center)
		var prop = prop_scene.instantiate()
		prop.setup(entry.type, entry.hp, null)
		prop.global_position = pos
		prop.card_dropped.connect(_on_card_dropped)
		props_container.add_child(prop)

func _rand_prop_pos(avoid: Vector2) -> Vector2:
	var player_pos = player.global_position if is_instance_valid(player) else avoid
	for _i in 20:
		var p = Vector2(randf_range(22, ARENA_W - 22), randf_range(22, ARENA_H - 22))
		if p.distance_to(avoid) > 55 and p.distance_to(player_pos) > 40:
			return p
	return Vector2(randf_range(22, ARENA_W - 22), randf_range(22, ARENA_H - 22))

# ─── Phase transitions ──────────────────────────────────────

func _start_combat() -> void:
	arena_phase = ArenaPhase.COMBAT
	if hud and hud.has_method("update_prep_timer"):
		hud.update_prep_timer(0, false)
	GameState.set_phase(GameState.Phase.ARENA_COMBAT)
	GameState.snapshot_wave_start()
	# Same combat music for all waves (including bosses)
	AudioManager.play_music("arena_combat")
	GameState.reset_dig_charges()
	WaveManager.start_wave(GameState.current_wave + 1)
	# Mutation: Feral Howl — stun all enemies for 2s on wave start
	if GameState.permanent.get("mutation_feral_howl", 0) > 0:
		call_deferred("_apply_feral_howl")
	_update_wave_label()
	# Use the actual wave being played for display
	var actual_wave = WaveManager.current_wave
	var stage_wave = ((actual_wave - 1) % 14) + 1
	# Show stage name on first wave of each stage
	if stage_wave == 1:
		var stage_name = StageData.get_stage_name(actual_wave)
		_show_banner(stage_name.to_upper(), Color(0.95, 0.82, 0.35), 2.0)
		if not is_inside_tree(): return
		await get_tree().create_timer(2.0).timeout
		if not is_inside_tree(): return
	_show_banner("WAVE %d!" % stage_wave, Color(0.95, 0.82, 0.35), 1.5)

	# Controls are now in the pause menu — no tutorial popup

func _on_wave_complete(wave_num: int) -> void:
	GameState.current_wave = wave_num
	SaveManager.save_game()
	_show_banner("WAVE CLEAR!", Color(0.4, 1.0, 0.4), 1.2)
	# Auto-collect all remaining XP orbs
	_vacuum_xp_orbs()
	# Achievement checks
	var ach = get_node_or_null("/root/Achievements")
	if ach:
		if wave_num >= 1:
			ach.check_and_unlock("baby_steps")
		if wave_num >= 21:
			ach.check_and_unlock("halfway_there")
		if wave_num >= 84:
			ach.check_and_unlock("the_end")
		# Untouchable: no damage taken this wave
		if ach.stats.get("damage_taken_this_wave", 0) == 0:
			ach.check_and_unlock("untouchable")
		# Reset wave damage tracker for next wave
		ach.stats["damage_taken_this_wave"] = 0
	if not is_inside_tree(): return
	await get_tree().create_timer(1.3).timeout
	if not is_inside_tree(): return

	if wave_num >= GameState.total_waves:
		return

	var stage_wave = StageData.get_stage_wave(wave_num)
	var is_boss = stage_wave == 14 or stage_wave == 7

	if is_boss:
		# Boss: 2 pairs of chests, one after the other
		_start_chest_phase(2, true)
		await _wait_for_chest_phase()
		if not is_inside_tree(): return
		_start_chest_phase(2, true)
		await _wait_for_chest_phase()
		if not is_inside_tree(): return
		if GameState.get_key_count("secret") > 0:
			await _spawn_secret_door()
		if not is_inside_tree(): return
		arena_phase = ArenaPhase.TRANSITION
		GameState.set_phase(GameState.Phase.BASE_HUB)
		SaveManager.save_game()
		_show_banner("RETURNING TO DEN...", Color(0.8, 0.7, 0.4), 1.5)
		if not is_inside_tree(): return
		await get_tree().create_timer(1.5).timeout
		if not is_inside_tree(): return
		get_tree().change_scene_to_file("res://scenes/base_hub.tscn")
	else:
		# Normal: 1 pair of chests
		_start_chest_phase(2, false)
		await _wait_for_chest_phase()
		if not is_inside_tree(): return
		_start_combat()

func _vacuum_xp_orbs() -> void:
	if not pickups_container:
		return
	var p = get_tree().get_first_node_in_group("player")
	if not p or not is_instance_valid(p):
		return
	for child in pickups_container.get_children():
		if child.has_method("_collect") and not child.get("collected"):
			# Tween the orb to the player then collect
			var orb = child
			orb.set_process(false)  # Stop lifetime countdown
			var tw = orb.create_tween()
			tw.tween_property(orb, "global_position", p.global_position, 0.4).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
			tw.tween_callback(func():
				if is_instance_valid(orb) and not orb.get("collected"):
					orb._collect()
			)

func _start_chest_phase(count: int, _is_boss: bool) -> void:
	arena_phase = ArenaPhase.CHEST_PHASE
	GameState.set_phase(GameState.Phase.CHEST_PHASE)
	_active_chests.clear()
	_chest_opened_count = 0
	_chest_total_count = count

	get_tree().paused = true
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_chest_event_ui(count)

func _wait_for_chest_phase() -> void:
	while arena_phase == ArenaPhase.CHEST_PHASE:
		if not is_inside_tree(): return
		await get_tree().process_frame

func _end_chest_phase() -> void:
	if arena_phase != ArenaPhase.CHEST_PHASE:
		return
	if _chest_event_ui:
		for child in _chest_event_ui.get_children():
			var tw2 = child.create_tween()
			tw2.tween_property(child, "modulate:a", 0.0, 0.3)
		if not is_inside_tree(): return
		await get_tree().create_timer(0.35).timeout
		if not is_inside_tree(): return
		_chest_event_ui.queue_free()
		_chest_event_ui = null
	if GameState.keys_changed.is_connected(_refresh_chest_event_ui):
		GameState.keys_changed.disconnect(_refresh_chest_event_ui)
	process_mode = Node.PROCESS_MODE_INHERIT
	get_tree().paused = false
	arena_phase = ArenaPhase.TRANSITION

# ═══════════════════════════════════════════════════════════════
# Chest Event UI — Full-screen overlay with big animated chests
# ═══════════════════════════════════════════════════════════════

const CHEST_SHEET_PATH = "res://assets/sprites/items/chest_open_sheet.png"
const CHEST_FRAME_W = 256
const CHEST_FRAME_H = 256
const CHEST_FRAME_COUNT = 9
const CHEST_IDLE_FRAMES = [0, 1, 2]
const CHEST_OPEN_FRAMES = [3, 4, 5, 6, 7, 8]

const TIER_COLORS = {
	"bronze": Color(0.72, 0.45, 0.20),
	"silver": Color(0.75, 0.75, 0.80),
	"gold":   Color(1.0, 0.84, 0.0),
	"secret": Color(0.6, 0.2, 0.9),
}

var _chest_event_ui: CanvasLayer = null
var _chest_sprites: Array = []       # TextureRect per chest
var _chest_key_panels: Array = []    # VBoxContainer per chest (key buttons)
var _chest_states: Array = []        # {opened: bool, chosen_tier: "", frame_idx: 0, anim_timer: 0}
var _chest_opened_count: int = 0
var _chest_total_count: int = 0
var _combine_panel: PanelContainer = null
var _chest_sheet: Texture2D = null

func _build_chest_event_ui(count: int) -> void:
	_chest_sprites.clear()
	_chest_key_panels.clear()
	_chest_states.clear()

	if ResourceLoader.exists(CHEST_SHEET_PATH):
		_chest_sheet = load(CHEST_SHEET_PATH)

	_chest_event_ui = CanvasLayer.new()
	_chest_event_ui.layer = 12
	_chest_event_ui.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_chest_event_ui)

	# Dark overlay
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.7)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	_chest_event_ui.add_child(overlay)

	# Main container — centers everything
	var root = VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_theme_constant_override("separation", 6)
	root.process_mode = Node.PROCESS_MODE_ALWAYS
	_chest_event_ui.add_child(root)

	# Title — RichTextLabel with outline for readability
	var title = RichTextLabel.new()
	title.bbcode_enabled = true
	title.text = "[center][outline_size=4][outline_color=black][color=#ffe666]TREASURE![/color][/outline_color][/outline_size][/center]"
	title.add_theme_font_size_override("normal_font_size", 28)
	title.fit_content = true
	title.scroll_active = false
	title.custom_minimum_size = Vector2(0, 34)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.process_mode = Node.PROCESS_MODE_ALWAYS
	title.modulate.a = 0.0  # Fades in after chests land
	root.add_child(title)

	# Chests row
	var chests_row = HBoxContainer.new()
	chests_row.alignment = BoxContainer.ALIGNMENT_CENTER
	chests_row.add_theme_constant_override("separation", 30)
	chests_row.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(chests_row)

	for i in count:
		var chest_col = VBoxContainer.new()
		chest_col.alignment = BoxContainer.ALIGNMENT_CENTER
		chest_col.add_theme_constant_override("separation", 4)
		chest_col.process_mode = Node.PROCESS_MODE_ALWAYS
		chests_row.add_child(chest_col)

		# Chest sprite — big and prominent
		var chest_tr = TextureRect.new()
		chest_tr.custom_minimum_size = Vector2(150, 150)
		chest_tr.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		chest_tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		chest_tr.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		if _chest_sheet:
			chest_tr.texture = _get_chest_frame_tex(0)
		chest_col.add_child(chest_tr)
		_chest_sprites.append(chest_tr)

		# Loot container — vertical list for clean stacking
		var loot_container = VBoxContainer.new()
		loot_container.add_theme_constant_override("separation", 1)
		loot_container.alignment = BoxContainer.ALIGNMENT_BEGIN
		loot_container.custom_minimum_size = Vector2(140, 10)
		loot_container.process_mode = Node.PROCESS_MODE_ALWAYS
		chest_col.add_child(loot_container)

		# Key selection panel below this chest
		var key_panel = VBoxContainer.new()
		key_panel.alignment = BoxContainer.ALIGNMENT_CENTER
		key_panel.add_theme_constant_override("separation", 2)
		key_panel.process_mode = Node.PROCESS_MODE_ALWAYS
		key_panel.modulate.a = 0.0  # Fades in after chests land
		chest_col.add_child(key_panel)
		_chest_key_panels.append(key_panel)

		_chest_states.append({
			"opened": false, "chosen_tier": "", "frame_idx": 0,
			"anim_timer": 0.0, "playing_open": false, "open_frame_idx": 0,
			"loot_container": loot_container, "column": chest_col,
			"bob_phase": i * PI,  # Offset so chests don't bob in sync
		})

		# Entry animation: chests scale from 0 with bounce
		chest_tr.scale = Vector2(0.0, 0.0)
		chest_tr.pivot_offset = Vector2(75, 75)
		var chest_delay = 0.15 + i * 0.1
		var tw_chest = chest_tr.create_tween()
		tw_chest.tween_property(chest_tr, "scale", Vector2(1.0, 1.0), 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK).set_delay(chest_delay)

	# Fade in title + buttons after chests land
	var buttons_delay = 0.15 + count * 0.1 + 0.4
	var tw_title = title.create_tween()
	tw_title.tween_property(title, "modulate:a", 1.0, 0.2).set_delay(buttons_delay)
	for kp in _chest_key_panels:
		var tw_kp = kp.create_tween()
		tw_kp.tween_property(kp, "modulate:a", 1.0, 0.2).set_delay(buttons_delay)

	# Combine panel at bottom — fades in with buttons
	_combine_panel = PanelContainer.new()
	_combine_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	_combine_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_combine_panel.modulate.a = 0.0
	root.add_child(_combine_panel)
	var tw_cp = _combine_panel.create_tween()
	tw_cp.tween_property(_combine_panel, "modulate:a", 1.0, 0.2).set_delay(buttons_delay)

	# Collect button — dismisses the overlay (hidden until all chests opened)
	var collect_btn = Button.new()
	collect_btn.name = "CollectBtn"
	collect_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	collect_btn.text = "Collect"
	collect_btn.add_theme_font_size_override("font_size", 12)
	collect_btn.custom_minimum_size = Vector2(100, 26)
	collect_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var collect_sb = StyleBoxFlat.new()
	collect_sb.bg_color = Color(0.25, 0.20, 0.15, 0.85)
	collect_sb.border_color = Color(0.8, 0.7, 0.4)
	collect_sb.set_border_width_all(1)
	collect_sb.set_corner_radius_all(5)
	collect_sb.set_content_margin_all(4)
	collect_btn.add_theme_stylebox_override("normal", collect_sb)
	var collect_hover = collect_sb.duplicate()
	collect_hover.bg_color = Color(0.35, 0.28, 0.18, 0.85)
	collect_hover.border_color = Color(1.0, 0.9, 0.5)
	collect_btn.add_theme_stylebox_override("hover", collect_hover)
	var collect_press = collect_sb.duplicate()
	collect_press.bg_color = Color(0.15, 0.12, 0.08, 0.85)
	collect_btn.add_theme_stylebox_override("pressed", collect_press)
	collect_btn.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	collect_btn.add_theme_color_override("font_hover_color", Color.WHITE)
	collect_btn.visible = false
	collect_btn.pressed.connect(_end_chest_phase)
	root.add_child(collect_btn)

	_refresh_chest_event_ui()
	if not GameState.keys_changed.is_connected(_refresh_chest_event_ui):
		GameState.keys_changed.connect(_refresh_chest_event_ui)

func _make_tier_btn_sb(tier_color: Color, state: String) -> StyleBoxFlat:
	var sb = StyleBoxFlat.new()
	match state:
		"normal":
			sb.bg_color = tier_color.darkened(0.55)
			sb.bg_color.a = 0.85
			sb.border_color = tier_color.lightened(0.15)
		"hover":
			sb.bg_color = tier_color.darkened(0.35)
			sb.bg_color.a = 0.85
			sb.border_color = tier_color.lightened(0.35)
		"pressed":
			sb.bg_color = tier_color.darkened(0.7)
			sb.bg_color.a = 0.85
			sb.border_color = tier_color
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(5)
	sb.set_content_margin_all(3)
	return sb

func _refresh_chest_event_ui() -> void:
	for i in _chest_key_panels.size():
		if i >= _chest_states.size():
			break
		var panel = _chest_key_panels[i]
		for child in panel.get_children():
			child.queue_free()

		if _chest_states[i].get("opened", false):
			continue

		# Prompt text
		var prompt = Label.new()
		prompt.text = "What key will you use?"
		prompt.add_theme_font_size_override("font_size", 9)
		prompt.add_theme_color_override("font_color", Color(0.8, 0.75, 0.55))
		prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		panel.add_child(prompt)

		var btn_row = HBoxContainer.new()
		btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
		btn_row.add_theme_constant_override("separation", 5)
		btn_row.process_mode = Node.PROCESS_MODE_ALWAYS
		panel.add_child(btn_row)

		var has_keys = false
		for tier in GameState.KEY_TIERS:
			var count = GameState.get_key_count(tier)
			if count <= 0:
				continue
			has_keys = true
			var tc = TIER_COLORS.get(tier, Color.WHITE)

			# Button with key icon + count
			var btn = Button.new()
			btn.process_mode = Node.PROCESS_MODE_ALWAYS
			btn.custom_minimum_size = Vector2(40, 40)
			btn.add_theme_stylebox_override("normal", _make_tier_btn_sb(tc, "normal"))
			btn.add_theme_stylebox_override("hover", _make_tier_btn_sb(tc, "hover"))
			btn.add_theme_stylebox_override("pressed", _make_tier_btn_sb(tc, "pressed"))

			var btn_content = VBoxContainer.new()
			btn_content.alignment = BoxContainer.ALIGNMENT_CENTER
			btn_content.add_theme_constant_override("separation", 0)
			btn_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
			btn.add_child(btn_content)

			# Key icon
			var key_path = "res://assets/sprites/items/key_%s.png" % tier
			if ResourceLoader.exists(key_path):
				var icon = TextureRect.new()
				icon.texture = load(key_path)
				icon.custom_minimum_size = Vector2(24, 24)
				icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
				icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
				icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
				btn_content.add_child(icon)
			else:
				# Fallback: colored diamond
				var icon_lbl = Label.new()
				icon_lbl.text = "◆"
				icon_lbl.add_theme_font_size_override("font_size", 14)
				icon_lbl.add_theme_color_override("font_color", tc)
				icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				icon_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
				btn_content.add_child(icon_lbl)

			# Count label
			var count_lbl = Label.new()
			count_lbl.text = "x%d" % count
			count_lbl.add_theme_font_size_override("font_size", 9)
			count_lbl.add_theme_color_override("font_color", tc)
			count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			count_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			btn_content.add_child(count_lbl)

			var chest_idx = i
			var captured_tier = tier
			btn.pressed.connect(func(): _on_chest_key_chosen(chest_idx, captured_tier))
			btn_row.add_child(btn)

		if not has_keys:
			prompt.text = "No keys!"
			prompt.add_theme_color_override("font_color", Color(1, 0.4, 0.3))

	# Rebuild combine panel
	if _combine_panel:
		for child in _combine_panel.get_children():
			child.queue_free()

		var sb = StyleBoxFlat.new()
		sb.bg_color = Color(0.08, 0.06, 0.04, 0.85)
		sb.border_color = Color(0.55, 0.45, 0.3, 0.6)
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(5)
		sb.set_content_margin_all(6)
		_combine_panel.add_theme_stylebox_override("panel", sb)

		var cvbox = HBoxContainer.new()
		cvbox.add_theme_constant_override("separation", 6)
		cvbox.alignment = BoxContainer.ALIGNMENT_CENTER
		cvbox.process_mode = Node.PROCESS_MODE_ALWAYS
		_combine_panel.add_child(cvbox)

		for tier in GameState.KEY_TIERS:
			var count = GameState.get_key_count(tier)
			if count <= 0 and not GameState.can_combine(tier):
				continue
			var tc = TIER_COLORS.get(tier, Color.WHITE)

			# Key icon
			var key_path = "res://assets/sprites/items/key_%s.png" % tier
			if ResourceLoader.exists(key_path):
				var icon = TextureRect.new()
				icon.texture = load(key_path)
				icon.custom_minimum_size = Vector2(16, 16)
				icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
				icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
				cvbox.add_child(icon)
			else:
				var pip = PanelContainer.new()
				var pip_sb = StyleBoxFlat.new()
				pip_sb.bg_color = tc
				pip_sb.set_corner_radius_all(3)
				pip.add_theme_stylebox_override("panel", pip_sb)
				pip.custom_minimum_size = Vector2(8, 8)
				pip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
				cvbox.add_child(pip)

			var lbl = Label.new()
			lbl.text = "%d" % count
			lbl.add_theme_font_size_override("font_size", 10)
			lbl.add_theme_color_override("font_color", tc)
			cvbox.add_child(lbl)

			if GameState.can_combine(tier):
				var btn = Button.new()
				btn.process_mode = Node.PROCESS_MODE_ALWAYS
				btn.text = "3>1"
				btn.add_theme_font_size_override("font_size", 9)
				btn.custom_minimum_size = Vector2(32, 18)
				btn.add_theme_stylebox_override("normal", _make_tier_btn_sb(tc, "normal"))
				btn.add_theme_stylebox_override("hover", _make_tier_btn_sb(tc, "hover"))
				btn.add_theme_stylebox_override("pressed", _make_tier_btn_sb(tc, "pressed"))
				btn.add_theme_color_override("font_color", Color.WHITE)
				var captured_tier = tier
				btn.pressed.connect(func(): GameState.combine_keys(captured_tier))
				cvbox.add_child(btn)

func _get_chest_frame_tex(idx: int) -> AtlasTexture:
	var atlas = AtlasTexture.new()
	atlas.atlas = _chest_sheet
	atlas.region = Rect2(idx * CHEST_FRAME_W, 0, CHEST_FRAME_W, CHEST_FRAME_H)
	return atlas

func _on_chest_key_chosen(chest_idx: int, tier: String) -> void:
	if chest_idx >= _chest_states.size():
		return
	if _chest_states[chest_idx].opened:
		return
	if not GameState.use_key(tier):
		return

	_chest_states[chest_idx].opened = true
	# Lucky Find — chance to upgrade chest tier
	var lucky_tier = tier
	if GameState.perk_chest_upgrade_chance > 0.0 and randf() < GameState.perk_chest_upgrade_chance:
		match tier:
			"bronze": lucky_tier = "silver"
			"silver": lucky_tier = "gold"
	_chest_states[chest_idx].chosen_tier = lucky_tier
	_chest_states[chest_idx].playing_open = true
	_chest_states[chest_idx].open_frame_idx = 0
	_chest_states[chest_idx].anim_timer = 0.0

	AudioManager.play("chest_open")

	# Lucky Find visual feedback
	if lucky_tier != tier:
		var lucky_lbl = Label.new()
		lucky_lbl.text = "LUCKY!"
		lucky_lbl.add_theme_font_size_override("font_size", 18)
		lucky_lbl.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0))
		lucky_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
		lucky_lbl.add_theme_constant_override("shadow_offset_x", 2)
		lucky_lbl.add_theme_constant_override("shadow_offset_y", 2)
		lucky_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lucky_lbl.set_anchors_preset(Control.PRESET_CENTER)
		lucky_lbl.offset_top = -60
		lucky_lbl.offset_bottom = -40
		lucky_lbl.offset_left = -50
		lucky_lbl.offset_right = 50
		lucky_lbl.process_mode = Node.PROCESS_MODE_ALWAYS
		var chest_panel = _chest_key_panels[chest_idx]
		chest_panel.add_child(lucky_lbl)
		var ltw = lucky_lbl.create_tween()
		ltw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		ltw.tween_property(lucky_lbl, "offset_top", -90, 1.0)
		ltw.parallel().tween_property(lucky_lbl, "modulate:a", 0.0, 1.0).set_delay(0.5)
		ltw.tween_callback(lucky_lbl.queue_free)

	# Clear key buttons for this chest
	var panel = _chest_key_panels[chest_idx]
	for child in panel.get_children():
		if child is Label and child.text == "LUCKY!":
			continue  # Don't clear the lucky label
		child.queue_free()
	var tier_lbl = Label.new()
	tier_lbl.text = "%s Key Used" % lucky_tier.capitalize()
	tier_lbl.add_theme_font_size_override("font_size", 10)
	tier_lbl.add_theme_color_override("font_color", TIER_COLORS.get(tier, Color.WHITE))
	tier_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(tier_lbl)

	# Refresh other chests' key buttons (counts changed)
	_refresh_chest_event_ui()

func _process_chest_phase(delta: float) -> void:
	if not _chest_event_ui:
		return

	for i in _chest_states.size():
		var state = _chest_states[i]

		# Bobbing — sine wave, offset per chest so they don't sync
		if i < _chest_sprites.size() and is_instance_valid(_chest_sprites[i]):
			state.bob_phase = state.get("bob_phase", 0.0) + delta * (TAU / 1.5)
			_chest_sprites[i].position.y = sin(state.bob_phase) * 3.0

		if not state.opened:
			# Idle spritesheet animation
			if _chest_sheet:
				state.anim_timer += delta
				if state.anim_timer >= 0.33:
					state.anim_timer = 0.0
					state.frame_idx = (state.frame_idx + 1) % CHEST_IDLE_FRAMES.size()
					if i < _chest_sprites.size():
						_chest_sprites[i].texture = _get_chest_frame_tex(CHEST_IDLE_FRAMES[state.frame_idx])
		elif state.playing_open:
			state.anim_timer += delta
			if state.anim_timer >= 0.1:
				state.anim_timer = 0.0
				state.open_frame_idx += 1
				if state.open_frame_idx < CHEST_OPEN_FRAMES.size():
					if i < _chest_sprites.size():
						_chest_sprites[i].texture = _get_chest_frame_tex(CHEST_OPEN_FRAMES[state.open_frame_idx])
				else:
					state.playing_open = false
					if i < _chest_sprites.size():
						_chest_sprites[i].texture = _get_chest_frame_tex(CHEST_OPEN_FRAMES[-1])
					_generate_chest_loot(i)
					_chest_opened_count += 1

	# Check if the player can still open any remaining chests
	var unopened_count = 0
	var still_animating = false
	for s in _chest_states:
		if not s.opened:
			unopened_count += 1
		if s.playing_open:
			still_animating = true

	var all_opened = unopened_count == 0 and not still_animating
	var can_open_more = unopened_count > 0 and GameState.has_any_key()
	var should_show_button = all_opened or (not can_open_more and not still_animating)

	if should_show_button:
		var collect_btn = null
		for child in _chest_event_ui.get_children():
			if child.has_method("find_child"):
				collect_btn = child.find_child("CollectBtn", true, false)
				if collect_btn:
					break
		if collect_btn and not collect_btn.visible:
			collect_btn.text = "Collect" if all_opened else "Skip"
			collect_btn.visible = true
			collect_btn.modulate.a = 0.0
			var tw = collect_btn.create_tween()
			var delay = 1.5 if all_opened else 0.3
			tw.tween_property(collect_btn, "modulate:a", 1.0, 0.3).set_delay(delay)

func _generate_chest_loot(chest_idx: int) -> void:
	var state = _chest_states[chest_idx]
	var tier = state.chosen_tier
	var loot_summary: Array = []

	const BASIC_MATS   = ["iron_scrap", "timber", "stone"]
	const MID_MATS     = ["iron_scrap", "timber", "stone", "fuel", "organic"]
	const ALL_MATS     = ["iron_scrap", "timber", "stone", "fuel", "organic", "blueprint"]
	# Legacy PERMANENT_UPGRADES removed — gold chests now give bonus materials + heal

	var xp_rewards = {"bronze": 15, "silver": 30, "gold": 60, "secret": 100}
	var xp_amount = xp_rewards.get(tier, 15)
	GameState.gain_xp(xp_amount)
	loot_summary.append({"text": "+%d XP" % xp_amount, "color": Color(0.35, 0.60, 0.90)})

	match tier:
		"bronze":
			loot_summary.append_array(_chest_drop_mats(BASIC_MATS, randi_range(2, 4)))
		"silver":
			loot_summary.append_array(_chest_drop_mats(MID_MATS, randi_range(3, 5)))
			if randf() < 0.15:
				GameState.player_max_health += 5
				GameState.player_health = min(GameState.player_health + 5, GameState.player_max_health)
				GameState.emit_signal("health_changed", GameState.player_health, GameState.player_max_health)
				loot_summary.append({"text": "+5 Max Health!", "color": Color(0.3, 1.0, 0.3)})
		"gold":
			loot_summary.append_array(_chest_drop_mats(ALL_MATS, randi_range(4, 6)))
			# Bonus: 25% chance for extra blueprint + heal
			if randf() < 0.25:
				GameState.add_material("blueprint", 1)
				loot_summary.append({"text": "+1 Blueprint!", "color": Color(0.3, 0.5, 0.95)})
			if randf() < 0.30:
				var heal_amt = 15
				GameState.heal(heal_amt)
				loot_summary.append({"text": "+%d HP!" % heal_amt, "color": Color(0.3, 1.0, 0.3)})
		"secret":
			loot_summary.append_array(_chest_drop_mats(ALL_MATS, randi_range(6, 10)))
			GameState.add_material("blueprint", 1)
			loot_summary.append({"text": "+1 Blueprint!", "color": Color(0.3, 0.5, 0.95)})

	# Orbital weapon drop
	var orbital_chances = {"bronze": 0.0, "silver": 0.05, "gold": 0.15, "secret": 0.30}
	var orbital_chance = orbital_chances.get(tier, 0.0)
	if orbital_chance > 0.0 and randf() < orbital_chance:
		var orb_entry = _try_chest_orbital_drop()
		if orb_entry:
			loot_summary.append(orb_entry)

	# Spring loot labels out from the chest
	_spring_chest_loot(chest_idx, loot_summary)

func _chest_drop_mats(pool: Array, count: int) -> Array:
	var dropped: Dictionary = {}
	for i in count:
		var mat_type = pool[randi() % pool.size()]
		dropped[mat_type] = dropped.get(mat_type, 0) + 1
		GameState.add_material(mat_type, 1)
	var entries: Array = []
	for mat in dropped:
		entries.append({"text": "+%d %s" % [dropped[mat], mat.replace("_", " ").capitalize()], "color": Color(0.9, 0.85, 0.6)})
	return entries

func _try_chest_orbital_drop() -> Variant:
	var p = get_tree().get_first_node_in_group("player")
	if not p or not p.has_method("add_orbital_weapon"):
		return null
	var owned = GameState.orbital_weapons
	var upgradeable: Array = []
	for entry in owned:
		if entry.level < OrbitalDB.MAX_LEVEL:
			upgradeable.append(entry.id)
	if not upgradeable.is_empty():
		var wid = upgradeable[randi() % upgradeable.size()]
		# Find new level before applying
		var new_lvl = 1
		for ow in owned:
			if ow.id == wid:
				new_lvl = mini(ow.level + 1, OrbitalDB.MAX_LEVEL)
		p.add_orbital_weapon(wid)
		var data = OrbitalDB.get_weapon_data(wid)
		return {"text": "%s Lv %d!" % [data.get("name", wid), new_lvl], "color": data.get("color", Color(0.6, 0.8, 1.0)), "is_orbital": true, "weapon_id": wid, "level": new_lvl, "is_new": false}
	if owned.size() < OrbitalDB.MAX_ORBITALS:
		var all_ids = OrbitalDB.get_weapon_ids()
		var owned_ids = []
		for entry in owned:
			owned_ids.append(entry.id)
		var available: Array = []
		for wid in all_ids:
			if wid not in owned_ids:
				available.append(wid)
		if not available.is_empty():
			var wid = available[randi() % available.size()]
			p.add_orbital_weapon(wid)
			var data = OrbitalDB.get_weapon_data(wid)
			return {"text": "NEW: %s!" % data.get("name", wid), "color": data.get("color", Color(0.6, 0.8, 1.0)), "is_orbital": true, "weapon_id": wid, "level": 1, "is_new": true}
	return null

func _spring_chest_loot(chest_idx: int, items: Array) -> void:
	var state = _chest_states[chest_idx]
	var loot_node = state.get("loot_container")
	if not loot_node or not is_instance_valid(loot_node):
		return

	for i in items.size():
		var item = items[i]

		if item.get("is_orbital", false):
			_spawn_orbital_card_reveal(loot_node, item, i)
			continue

		# Regular loot: centered label, stagger fade-in
		var lbl = Label.new()
		lbl.text = item.text
		lbl.add_theme_font_size_override("font_size", 10)
		lbl.add_theme_color_override("font_color", item.color)
		lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
		lbl.add_theme_constant_override("shadow_offset_x", 1)
		lbl.add_theme_constant_override("shadow_offset_y", 1)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.modulate.a = 0.0
		lbl.process_mode = Node.PROCESS_MODE_ALWAYS
		loot_node.add_child(lbl)

		var delay = i * 0.1
		var tw = lbl.create_tween()
		tw.tween_property(lbl, "modulate:a", 1.0, 0.15).set_delay(delay)
		lbl.scale = Vector2(0.5, 0.5)
		lbl.pivot_offset = Vector2(70, 6)
		tw.parallel().tween_property(lbl, "scale", Vector2(1.0, 1.0), 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK).set_delay(delay)

func _spawn_orbital_card_reveal(loot_node: Control, item: Dictionary, item_idx: int) -> void:
	var wid = item.get("weapon_id", "")
	var wlevel = item.get("level", 1)
	var is_new = item.get("is_new", false)
	var wcolor = item.get("color", Color(0.6, 0.8, 1.0))
	var data = OrbitalDB.get_weapon_data(wid)
	var wname = data.get("name", wid)
	var wdesc = OrbitalDB.get_level_desc(wid, wlevel)
	var is_milestone = OrbitalDB.is_visual_upgrade_level(wlevel)

	# Card container — sits in the VBox loot list
	var card = PanelContainer.new()
	card.process_mode = Node.PROCESS_MODE_ALWAYS
	card.custom_minimum_size = Vector2(100, 80)
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	var card_sb = StyleBoxFlat.new()
	card_sb.bg_color = Color(0.06, 0.04, 0.08, 0.95)
	card_sb.border_color = wcolor
	card_sb.set_border_width_all(2)
	card_sb.set_corner_radius_all(5)
	card_sb.set_content_margin_all(6)
	card.add_theme_stylebox_override("panel", card_sb)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(vbox)

	# Header: NEW or LEVEL UP
	var header = Label.new()
	header.text = "NEW ORBITAL!" if is_new else "LEVEL UP!"
	header.add_theme_font_size_override("font_size", 7)
	header.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3) if is_new else Color(0.5, 1.0, 0.5))
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(header)

	# Orbital icon — try to load sprite, else use colored diamond
	var icon_row = CenterContainer.new()
	icon_row.custom_minimum_size = Vector2(0, 28)
	vbox.add_child(icon_row)

	var sprite_path = "res://assets/sprites/orbitals/orbital_%s.png" % wid
	if ResourceLoader.exists(sprite_path):
		var icon = TextureRect.new()
		icon.texture = load(sprite_path)
		icon.custom_minimum_size = Vector2(24, 24)
		icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.modulate = wcolor
		icon_row.add_child(icon)
	else:
		var icon_lbl = Label.new()
		icon_lbl.text = "◆"
		icon_lbl.add_theme_font_size_override("font_size", 22)
		icon_lbl.add_theme_color_override("font_color", wcolor)
		icon_row.add_child(icon_lbl)

	# Weapon name + level
	var name_lbl = Label.new()
	name_lbl.text = "%s Lv%d" % [wname, wlevel]
	name_lbl.add_theme_font_size_override("font_size", 9)
	name_lbl.add_theme_color_override("font_color", wcolor)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(name_lbl)

	# Stats line
	var desc_lbl = Label.new()
	desc_lbl.text = wdesc
	desc_lbl.add_theme_font_size_override("font_size", 7)
	desc_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(desc_lbl)

	# Visual upgrade milestone badge
	if is_milestone:
		var badge = Label.new()
		badge.text = "VISUAL UPGRADE"
		badge.add_theme_font_size_override("font_size", 7)
		badge.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0))
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(badge)

	# Start hidden, scale up with bounce
	card.modulate.a = 0.0
	card.scale = Vector2(0.2, 0.2)
	card.pivot_offset = Vector2(50, 40)
	loot_node.add_child(card)

	var delay = item_idx * 0.1 + 0.15
	var tw = card.create_tween()
	# Fade in + scale bounce
	tw.tween_property(card, "modulate:a", 1.0, 0.15).set_delay(delay)
	tw.parallel().tween_property(card, "scale", Vector2(1.05, 1.05), 0.35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK).set_delay(delay)
	# Settle
	tw.tween_property(card, "scale", Vector2(1.0, 1.0), 0.1)
	# Glow pulse
	tw.tween_property(card, "modulate", Color(1.3, 1.3, 1.3, 1.0), 0.15)
	tw.tween_property(card, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.2)

func _on_all_waves_complete() -> void:
	arena_phase = ArenaPhase.TRANSITION
	GameState.permanent.runs_completed += 1
	GameState.end_run(true)  # keep_materials = true — player earned them!
	# Track run completion achievements
	var ach = get_node_or_null("/root/Achievements")
	if ach:
		ach.increment_stat("runs_completed")
	SaveManager.save_game()
	GameState.set_phase(GameState.Phase.RUN_COMPLETE)
	AudioManager.play("victory")
	AudioManager.play_music("victory_theme")
	_show_banner("RUN COMPLETE!", Color(1.0, 0.85, 0.2), 0)
	if not is_inside_tree(): return
	await get_tree().create_timer(2.5).timeout
	if not is_inside_tree(): return
	get_tree().change_scene_to_file("res://scenes/base_hub.tscn")

func _on_health_changed(current: int, max_hp: int) -> void:
	if hud and hud.has_method("update_health"):
		hud.update_health(current, max_hp)
	# Track damage for untouchable achievement
	if _last_known_health >= 0 and current < _last_known_health:
		var ach = get_node_or_null("/root/Achievements")
		if ach:
			ach.stats["damage_taken_this_wave"] = ach.stats.get("damage_taken_this_wave", 0) + 1
	_last_known_health = current

func _on_player_died() -> void:
	if arena_phase == ArenaPhase.TRANSITION:
		return
	arena_phase = ArenaPhase.TRANSITION
	GameState.set_phase(GameState.Phase.GAME_OVER)
	# death_sting sound disabled — needs replacement
	_show_banner("YOU DIED", Color(1, 0.15, 0.15), 0)
	# Save death stats BEFORE end_run wipes them
	GameState.last_death_wave = GameState.current_wave
	GameState.last_death_level = GameState.player_level
	# End run BEFORE saving so save file doesn't have run_in_progress=true with 0 HP
	GameState.end_run()
	SaveManager.save_game()
	if not is_inside_tree(): return
	await get_tree().create_timer(2.8).timeout
	if not is_inside_tree(): return
	get_tree().change_scene_to_file("res://scenes/game_over.tscn")

# ─── HUD helpers ────────────────────────────────────────────

func _show_banner(text: String, color: Color, auto_hide_sec: float) -> void:
	if hud and hud.has_method("show_banner"):
		hud.show_banner(text, color, auto_hide_sec)

func _update_wave_label() -> void:
	if hud and hud.has_method("update_wave"):
		# Show the wave currently being PLAYED, not the last completed wave
		hud.update_wave(WaveManager.current_wave, GameState.total_waves)

func _update_xp_bar() -> void:
	if hud and hud.has_method("update_xp"):
		hud.update_xp(GameState.player_xp, GameState.xp_to_next_level, GameState.player_level)

func _make_anim_sprite(sheet_path: String, frame_count: int, fps: float, node_name: String, scl: float, mod: Color, z: int) -> AnimatedSprite2D:
	var sheet = load(sheet_path) as Texture2D
	if not sheet: return null
	var spr = AnimatedSprite2D.new()
	spr.name = node_name
	var sf = SpriteFrames.new()
	sf.add_animation("default")
	sf.set_animation_speed("default", fps)
	sf.set_animation_loop("default", true)
	var fw = sheet.get_width() / float(frame_count)
	var fh = sheet.get_height()
	for i in frame_count:
		var atlas = AtlasTexture.new()
		atlas.atlas = sheet
		atlas.region = Rect2(i * fw, 0, fw, fh)
		sf.add_frame("default", atlas)
	spr.sprite_frames = sf
	spr.scale = Vector2(scl, scl)
	spr.modulate = mod
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.z_index = z
	spr.play("default")
	return spr

func _restore_card_perks() -> void:
	# Restore card deck perks (Bug Swarm / Vine Snare) if active
	if "bug_swarm" in GameState.active_perks and not has_node("BugSwarmTimer"):
		var p = player
		# Animated visual
		if p and not p.has_node("BugSwarmVFX"):
			var sheet_path = "res://assets/sprites/effects/bug_swarm_anim_sheet.png"
			if ResourceLoader.exists(sheet_path):
				var spr = _make_anim_sprite(sheet_path, 9, 10.0, "BugSwarmVFX", 0.6, Color(1, 1, 1, 0.7), 5)
				if spr: p.add_child(spr)
			else:
				# Fallback to static sprite with rotation
				var swarm_tex = load("res://assets/sprites/effects/bug_swarm.png") if ResourceLoader.exists("res://assets/sprites/effects/bug_swarm.png") else null
				if swarm_tex:
					var swarm_spr = Sprite2D.new()
					swarm_spr.name = "BugSwarmVFX"
					swarm_spr.texture = swarm_tex
					swarm_spr.scale = Vector2(0.6, 0.6)
					swarm_spr.modulate = Color(1, 1, 1, 0.7)
					swarm_spr.z_index = 5
					p.add_child(swarm_spr)
		# Damage
		var bug_timer = Timer.new()
		bug_timer.name = "BugSwarmTimer"
		bug_timer.wait_time = 1.0
		bug_timer.autostart = true
		bug_timer.process_mode = Node.PROCESS_MODE_INHERIT  # Respect pause
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
		# Animated visual
		if p2 and not p2.has_node("VineSnareVFX"):
			var sheet_path = "res://assets/sprites/effects/vine_snare_anim_sheet.png"
			if ResourceLoader.exists(sheet_path):
				var spr = _make_anim_sprite(sheet_path, 9, 8.0, "VineSnareVFX", 0.8, Color(0.6, 1.0, 0.5, 0.5), -1)
				if spr: p2.add_child(spr)
			else:
				var vine_tex = load("res://assets/sprites/effects/vine_snare.png") if ResourceLoader.exists("res://assets/sprites/effects/vine_snare.png") else null
				if vine_tex:
					var vine_spr = Sprite2D.new()
					vine_spr.name = "VineSnareVFX"
					vine_spr.texture = vine_tex
					vine_spr.scale = Vector2(0.8, 0.8)
					vine_spr.modulate = Color(0.6, 1.0, 0.5, 0.5)
					vine_spr.z_index = -1
					p2.add_child(vine_spr)
		# Slow
		var vine_timer = Timer.new()
		vine_timer.name = "VineSnareTimer"
		vine_timer.wait_time = 0.5
		vine_timer.autostart = true
		vine_timer.process_mode = Node.PROCESS_MODE_INHERIT  # Respect pause
		vine_timer.timeout.connect(func():
			if not p2 or not is_instance_valid(p2): return
			for enemy in get_tree().get_nodes_in_group("enemies"):
				if not is_instance_valid(enemy) or enemy.is_dead: continue
				if p2.global_position.distance_to(enemy.global_position) < 100.0:
					if "move_speed" in enemy and "_base_move_speed" in enemy:
						enemy.move_speed = enemy._base_move_speed * 0.6
				else:
					if "move_speed" in enemy and "_base_move_speed" in enemy:
						enemy.move_speed = enemy._base_move_speed
		)
		add_child(vine_timer)

func _restore_regen_perk() -> void:
	# Perk regen: +2 HP every 5 seconds (named to prevent duplication)
	if GameState.perk_regen_active:
		if not has_node("PerkRegenTimer"):
			var regen_t = Timer.new()
			regen_t.name = "PerkRegenTimer"
			regen_t.wait_time = 5.0
			regen_t.autostart = true
			regen_t.process_mode = Node.PROCESS_MODE_INHERIT  # Respect pause
			regen_t.timeout.connect(func(): GameState.heal(2))
			add_child(regen_t)
	# Health regen: new system (health_regen_level) with fallback to legacy (armory_level)
	var regen_lvl = GameState.permanent.get("health_regen_level", 0)
	if regen_lvl == 0:
		regen_lvl = clampi(GameState.permanent.get("armory_level", 0), 0, 10)
	if regen_lvl > 0:
		var udb = get_node_or_null("/root/UpgradeDB")
		var heal_pct = 1.0
		var interval = 8.0
		if udb and regen_lvl <= udb.REGEN_TIERS.size():
			var tier = udb.REGEN_TIERS[regen_lvl - 1]
			heal_pct = tier[0]
			interval = tier[1]
		else:
			heal_pct = 1.0 + (regen_lvl - 1) * 0.3
			interval = maxf(2.0, 8.0 - (regen_lvl - 1) * 0.6)
		var dh_timer = Timer.new()
		dh_timer.wait_time = interval
		dh_timer.autostart = true
		dh_timer.process_mode = Node.PROCESS_MODE_INHERIT  # Respect pause
		dh_timer.timeout.connect(func():
			# Heal as percentage of max HP — scales naturally with HP upgrades
			var heal_amt = maxi(1, int(GameState.player_max_health * heal_pct / 100.0))
			GameState.heal(heal_amt)
		)
		add_child(dh_timer)

func _spawn_secret_door() -> void:
	AudioManager.play("secret_door")
	_show_banner("A secret door has appeared...", Color(0.8, 0.3, 1.0), 2.5)
	if not is_inside_tree(): return
	await get_tree().create_timer(1.0).timeout
	if not is_inside_tree(): return

	var door = SecretDoorScene.instantiate()

	# Position near center of the arena so it's visible on the 480x270 viewport.
	# Offset slightly in a random direction so it doesn't overlap the player.
	var cx = ARENA_W / 2.0
	var cy = ARENA_H / 2.0
	var angle = randf() * TAU
	var offset_dist = randf_range(60, 120)
	door.position = Vector2(
		clampf(cx + cos(angle) * offset_dist, 60, ARENA_W - 60),
		clampf(cy + sin(angle) * offset_dist, 60, ARENA_H - 60)
	)

	door.z_index = 10  # Well above floor/walls/enemies
	add_child(door)
	_secret_door = door

	# If the door is used, the scene changes — no cleanup needed
	# Otherwise wait for the door to fade (it self-destructs after FADE_TIME)
	# We wait up to SECRET_DOOR_DURATION for the player to use it
	var elapsed = 0.0
	while elapsed < SECRET_DOOR_DURATION:
		if not is_inside_tree():
			return
		await get_tree().process_frame
		elapsed += get_process_delta_time()
		if not is_instance_valid(_secret_door):
			break
	# Clean up if still around
	if is_instance_valid(_secret_door) and is_inside_tree():
		var tw = create_tween()
		tw.tween_property(_secret_door, "modulate:a", 0.0, 1.0)
		tw.tween_callback(_secret_door.queue_free)
		await tw.finished
	_secret_door = null

func _on_card_dropped(card: Dictionary) -> void:
	if _card_popup and _card_popup.has_method("show_card"):
		_card_popup.show_card(card)

func _update_hud() -> void:
	_on_health_changed(GameState.player_health, GameState.player_max_health)
	_update_wave_label()

func _apply_feral_howl() -> void:
	# Stun all enemies for 2 seconds
	for enemy in enemies_container.get_children():
		if enemy.has_method("apply_stun"):
			enemy.apply_stun(2.0)
		elif enemy.get("_stunned") != null:
			enemy._stunned = true
			var timer = get_tree().create_timer(2.0)
			var e = enemy
			timer.timeout.connect(func():
				if is_instance_valid(e):
					e._stunned = false
			)
	_show_banner("AWOOOO!", Color(0.72, 0.35, 0.90), 1.0)

# ──── DEBUG: God mode (F1) — REMEMBER TO REMOVE BEFORE RELEASE! ────
var _god_mode: bool = false
var _god_mode_old_damage: int = 0

func _toggle_god_mode() -> void:
	_god_mode = !_god_mode
	if _god_mode:
		# Save original damage, set to 200, full heal
		_god_mode_old_damage = player.AUTO_ATTACK_DAMAGE
		player.AUTO_ATTACK_DAMAGE = 200
		GameState.player_health = GameState.player_max_health
		GameState.emit_signal("health_changed", GameState.player_health, GameState.player_max_health)
		_show_banner("GOD MODE ON", Color(1.0, 0.85, 0.0), 1.0)
	else:
		# Restore original damage
		player.AUTO_ATTACK_DAMAGE = _god_mode_old_damage
		_show_banner("GOD MODE OFF", Color(0.6, 0.6, 0.6), 1.0)
# ──── END DEBUG (God mode) ─────────────────────────────────────

# ──── DEBUG: Wave skip — REMEMBER TO REMOVE BEFORE RELEASE! ────
var _debug_skip_layer: CanvasLayer = null

const BOSS_NAMES = {
	7:  "Scrap Sentinel",   14: "Junkyard Mech",
	21: "Spore Mother",     28: "Fungal Titan",
	35: "Ember Drake",      42: "Molten Wyrm",
	49: "Frost Warden",     56: "Crystal Colossus",
	63: "Piston Crusher",   70: "The Architect",
	77: "The Devourer",     84: "Scrap King",
}

func _show_wave_skip_dialog() -> void:
	if _debug_skip_layer:
		_debug_skip_layer.queue_free()
		_debug_skip_layer = null
	get_tree().paused = true

	var layer = CanvasLayer.new()
	layer.layer = 200
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	_debug_skip_layer = layer

	var root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(root)

	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.7)
	root.add_child(bg)

	# Center panel
	var panel = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(340, 400)
	panel.position = Vector2(-170, -200)
	root.add_child(panel)

	var outer_vbox = VBoxContainer.new()
	outer_vbox.add_theme_constant_override("separation", 4)
	panel.add_child(outer_vbox)

	# Title
	var title = Label.new()
	title.text = "DEBUG — WAVE SELECT"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	outer_vbox.add_child(title)

	# Current wave indicator
	var current_label = Label.new()
	current_label.text = "Currently on wave %d" % WaveManager.current_wave
	current_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	current_label.add_theme_font_size_override("font_size", 11)
	current_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	outer_vbox.add_child(current_label)

	# Scrollable wave list
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 320)
	outer_vbox.add_child(scroll)

	var list_vbox = VBoxContainer.new()
	list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_vbox.add_theme_constant_override("separation", 2)
	scroll.add_child(list_vbox)

	var do_close = func():
		layer.queue_free()
		_debug_skip_layer = null
		get_tree().paused = false

	# Build wave list grouped by stage
	for wave in range(1, GameState.total_waves + 1):
		var stage_wave = StageData.get_stage_wave(wave)
		var stage_name = StageData.get_stage_name(wave)
		var is_mid_boss = stage_wave == 7
		var is_final_boss = stage_wave == 14
		var is_boss = is_mid_boss or is_final_boss
		var is_current = wave == WaveManager.current_wave

		# Stage header on wave 1 of each stage
		if stage_wave == 1:
			var stage_idx = StageData.get_stage_index(wave)
			var sep = HSeparator.new()
			if stage_idx > 0:
				list_vbox.add_child(sep)
			var header = Label.new()
			header.text = "── Stage %d: %s ──" % [stage_idx + 1, stage_name]
			header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			header.add_theme_font_size_override("font_size", 13)
			header.add_theme_color_override("font_color", Color(0.9, 0.75, 0.4))
			list_vbox.add_child(header)

		# Wave button
		var btn = Button.new()
		var label_text = "Wave %d  (stage %d)" % [wave, stage_wave]
		if is_mid_boss:
			label_text += "  ⚔ MID-BOSS: %s" % BOSS_NAMES.get(wave, "???")
		elif is_final_boss:
			label_text += "  👑 BOSS: %s" % BOSS_NAMES.get(wave, "???")
		if is_current:
			label_text += "  ◄ NOW"
		btn.text = label_text
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		# Color coding
		if is_current:
			btn.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
		elif is_final_boss:
			btn.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
		elif is_mid_boss:
			btn.add_theme_color_override("font_color", Color(1.0, 0.65, 0.2))

		var target_wave = wave
		btn.pressed.connect(func():
			do_close.call()
			_debug_skip_to_wave(target_wave)
		)
		list_vbox.add_child(btn)

	# Close button at bottom
	var close_btn = Button.new()
	close_btn.text = "Cancel (Esc)"
	close_btn.pressed.connect(do_close)
	outer_vbox.add_child(close_btn)

	add_child(layer)

	# Also allow Escape to close
	root.gui_input.connect(func(event):
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			do_close.call()
	)

func _debug_skip_to_wave(target: int) -> void:
	# Stop wave manager first so no new spawns or wave_complete signals fire
	WaveManager.wave_active = false
	WaveManager.spawn_queue.clear()
	WaveManager.enemies_alive = 0

	var old_stage = StageData.get_stage_index(GameState.current_wave + 1)
	var new_stage = StageData.get_stage_index(target)
	GameState.current_wave = target - 1

	if old_stage != new_stage:
		# Different stage — reload the entire arena scene to rebuild the map
		get_tree().reload_current_scene()
		return

	# Same stage — quick in-place skip
	# Remove all enemies without calling die() (avoids signal cascade)
	for enemy in enemies_container.get_children():
		enemy.queue_free()

	# Clear any leftover pickups/projectiles
	for pickup in pickups_container.get_children():
		pickup.queue_free()

	arena_phase = ArenaPhase.COMBAT

	# Wait a frame for queue_free to process
	await get_tree().process_frame
	if not is_inside_tree(): return

	_show_banner("SKIP -> WAVE %d" % target, Color(1.0, 0.8, 0.2), 1.0)
	await get_tree().create_timer(0.8).timeout
	if not is_inside_tree(): return
	_start_combat()
# ──── END DEBUG ────────────────────────────────────────────────
