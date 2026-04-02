extends Control

# ============================================================
# BaseHub — Upgrade hub with tabbed sidebar, category cards,
# and animated dog bust. Layout defined in base_hub.tscn,
# dynamic content populated in code.
# ============================================================

# --- Colors ---
const CLR_GOLD      = Color(0.95, 0.82, 0.35)
const CLR_SILVER    = Color(0.85, 0.85, 0.88)
const CLR_DIM       = Color(0.50, 0.50, 0.52)
const CLR_GREEN     = Color(0.30, 0.85, 0.40)
const CLR_RED       = Color(0.90, 0.25, 0.25)
const CLR_ORANGE    = Color(0.95, 0.60, 0.15)
const CLR_PANEL_BG  = Color(0.10, 0.10, 0.12, 0.92)
const CLR_BORDER    = Color(0.35, 0.38, 0.42, 0.6)

const KEY_COLORS = {
	"bronze": Color(0.80, 0.50, 0.20),
	"silver": Color(0.75, 0.75, 0.80),
	"gold":   Color(0.95, 0.82, 0.35),
	"secret": Color(0.85, 0.30, 0.85),
}
const MAT_COLORS = {
	"iron_scrap": Color(0.6, 0.6, 0.7), "timber": Color(0.6, 0.4, 0.2),
	"fuel": Color(0.9, 0.4, 0.1), "organic": Color(0.3, 0.7, 0.3),
	"stone": Color(0.5, 0.5, 0.5), "blueprint": Color(0.4, 0.6, 0.9),
}
const MAT_ICONS = {
	"iron_scrap": "mat_icon_iron.png", "timber": "mat_icon_timber.png",
	"fuel": "mat_icon_fuel.png", "organic": "mat_icon_organic.png",
	"stone": "mat_icon_stone.png", "blueprint": "mat_icon_blueprint.png",
}

const TAB_DEFS = [
	{"id": "den_upgrades", "label": "DEN\nUPGRADES", "color": Color(0.95, 0.82, 0.35)},
	{"id": "card_collection", "label": "CARD\nCOLLECTION", "color": Color(0.95, 0.55, 0.15)},
	{"id": "achievements", "label": "ACHIEVE-\nMENTS", "color": Color(0.72, 0.35, 0.90)},
	{"id": "archive", "label": "INVENTORY", "color": Color(0.75, 0.75, 0.80)},
]

const CAT_ANIM_SHEETS = {
	"combat_paws": "res://assets/sprites/hub_icons/combat_paws_anim_sheet.png",
	"survival_den": "res://assets/sprites/hub_icons/survival_den_anim_sheet.png",
	"scavenge_snout": "res://assets/sprites/hub_icons/scavenge_snout_anim_sheet.png",
	"companion_legacy": "res://assets/sprites/hub_icons/companion_legacy_anim_sheet.png",
	"mutation": "res://assets/sprites/hub_icons/mutation_anim_sheet.png",
}

# Card slot → category mapping (matches scene tree order)
const CARD_SLOT_MAP = {
	"LeftCardSlot": "scavenge_snout",
	"RightCardSlot": "combat_paws",
	"BottomCard1": "mutation",
	"BottomCard2": "companion_legacy",
	"BottomCard3": "survival_den",
}

const BUST_ONESHOT_ANIMS: Array[String] = [
	"snap_fly", "head_shake", "head_tilt",
	"happy_panting", "sleepy",
	"idle_steady", "idle_sitting",
]

# --- Scene node refs (from .tscn) ---
@onready var _key_container: HBoxContainer = %KeyContainer
@onready var _mat_container: HBoxContainer = %MatContainer
@onready var _save_button: Button = %SaveButton
@onready var _content_area: Control = %ContentArea
@onready var _den_tab: Control = %DenUpgradesTab
@onready var _card_tab: Control = %CardCollectionTab
@onready var _ach_tab: Control = %AchievementsTab
@onready var _archive_tab: Control = %ArchiveTab
@onready var _puppy_sprite: AnimatedSprite2D = %PuppySprite
@onready var _glow_ring: ColorRect = %GlowRing
@onready var _orbital_frame: TextureRect = %OrbitalFrame

# Tab buttons
@onready var _den_btn: Button = %DenUpgradesBtn
@onready var _card_btn: Button = %CardCollectionBtn
@onready var _ach_btn: Button = %AchievementsBtn
@onready var _archive_btn: Button = %ArchiveBtn

# Bottom bar
@onready var _junkyard_btn: Button = %JunkyardBtn
@onready var _enter_dungeon_btn: Button = %EnterDungeonBtn
@onready var _wardrobe_btn: Button = %WardrobeBtn

# Card slots
@onready var _left_card: PanelContainer = %LeftCardSlot
@onready var _right_card: PanelContainer = %RightCardSlot
@onready var _bottom_card1: PanelContainer = %BottomCard1
@onready var _bottom_card2: PanelContainer = %BottomCard2
@onready var _bottom_card3: PanelContainer = %BottomCard3

# --- Runtime state ---
var _tex_cache: Dictionary = {}
var _bust_timer: float = 0.0
var _bust_next_anim_time: float = 6.0
var _puppy_base_y: float = 224.0
var _bust_playing_oneshot: bool = false
var _overlay_panel: Control = null
var _confirm_building: String = ""
var _current_tab: String = "den_upgrades"
var _detail_panel: Control = null
var _category_nodes: Dictionary = {}
var _tab_containers: Dictionary = {}
var _tab_buttons: Dictionary = {}
var _udb: Node = null

# ===================================================================
# LIFECYCLE
# ===================================================================

func _ready() -> void:
	_udb = get_node_or_null("/root/UpgradeDB")
	mouse_filter = Control.MOUSE_FILTER_STOP

	# Map tab containers and buttons
	_tab_containers = {
		"den_upgrades": _den_tab,
		"card_collection": _card_tab,
		"achievements": _ach_tab,
		"archive": _archive_tab,
	}
	_tab_buttons = {
		"den_upgrades": _den_btn,
		"card_collection": _card_btn,
		"achievements": _ach_btn,
		"archive": _archive_btn,
	}

	# Style tab buttons
	_setup_tab_buttons()

	# Add circular rings behind porthole
	_setup_circular_rings()

	# Setup puppy bust
	_setup_puppy()

	# Populate category cards
	_populate_all_cards()

	# Build dynamic tab content
	_build_card_collection_tab()
	_build_achievements_tab()
	_build_archive_tab()

	# Style bottom bar buttons
	_setup_bottom_bar()

	# Save button — create standalone in top-right since TopBar is hidden
	var save_btn = Button.new()
	save_btn.text = "SAVE"
	save_btn.z_index = 55
	save_btn.position = Vector2(900, 5)
	save_btn.size = Vector2(55, 28)
	save_btn.add_theme_font_size_override("font_size", 12)
	save_btn.add_theme_color_override("font_color", CLR_GREEN)
	save_btn.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	save_btn.add_theme_constant_override("outline_size", 2)
	_style_button_flat(save_btn)
	save_btn.pressed.connect(func():
		SaveManager.save_game()
		save_btn.text = "SAVED!"
		var tw = save_btn.create_tween()
		tw.tween_interval(1.0)
		tw.tween_callback(func(): save_btn.text = "SAVE")
	)
	add_child(save_btn)

	# Initial state
	_switch_tab("den_upgrades")

	# Connect signals
	GameState.materials_changed.connect(_refresh_top_bar)
	GameState.keys_changed.connect(_refresh_top_bar)

func _process(delta: float) -> void:
	if _puppy_sprite and is_instance_valid(_puppy_sprite) and not _bust_playing_oneshot:
		_bust_timer += delta
		if _bust_timer >= _bust_next_anim_time:
			_bust_playing_oneshot = true
			var anims = BUST_ONESHOT_ANIMS.duplicate()
			anims.shuffle()
			for anim in anims:
				if _puppy_sprite.sprite_frames and _puppy_sprite.sprite_frames.has_animation(anim):
					_puppy_sprite.play(anim)
					break
	# Gentle bob (base Y comes from scene position)
	if _puppy_sprite and is_instance_valid(_puppy_sprite):
		_puppy_sprite.position.y = _puppy_base_y + sin(Time.get_ticks_msec() * 0.001 * 1.5) * 1.2

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		# Close detail panel first, otherwise open pause menu
		if _detail_panel and is_instance_valid(_detail_panel):
			_close_detail_panel()
		elif _overlay_panel and is_instance_valid(_overlay_panel):
			_overlay_panel.queue_free()
			_overlay_panel = null
		else:
			var pause = load("res://scripts/pause_menu.gd").new()
			add_child(pause)
			pause.open()
		get_viewport().set_input_as_handled()

func _exit_tree() -> void:
	if GameState.materials_changed.is_connected(_refresh_top_bar):
		GameState.materials_changed.disconnect(_refresh_top_bar)
	if GameState.keys_changed.is_connected(_refresh_top_bar):
		GameState.keys_changed.disconnect(_refresh_top_bar)

# ===================================================================
# TAB BUTTONS (sidebar)
# ===================================================================

const TAB_RECT_TEXTURES = {
	"den_upgrades": "res://assets/sprites/hub_ui/steel_rect_1.jpg",
	"card_collection": "res://assets/sprites/hub_ui/steel_rect_2.jpg",
	"achievements": "res://assets/sprites/hub_ui/steel_rect_3.jpg",
	"archive": "res://assets/sprites/hub_ui/steel_rect_4.jpg",
}

func _setup_tab_buttons() -> void:
	for tid in _tab_buttons:
		var btn = _tab_buttons[tid]
		var tex_path = TAB_RECT_TEXTURES.get(tid, "")
		var tex = _load_tex(tex_path) if tex_path != "" else null
		_style_tab_button(btn, tex)
		var tab_id = tid
		btn.pressed.connect(func(): _switch_tab(tab_id))

func _switch_tab(tab_id: String) -> void:
	_current_tab = tab_id
	_close_detail_panel()
	for tid in _tab_containers:
		if _tab_containers[tid] and is_instance_valid(_tab_containers[tid]):
			_tab_containers[tid].visible = (tid == tab_id)
	# Bottom buttons always visible in new radial layout
	for tid in _tab_buttons:
		var btn: Button = _tab_buttons[tid]
		var tex_path = TAB_RECT_TEXTURES.get(tid, "")
		var tex = _load_tex(tex_path) if tex_path != "" else null
		var tab_def = null
		for td in TAB_DEFS:
			if td.id == tid:
				tab_def = td
				break
		if tid == tab_id:
			btn.add_theme_color_override("font_color", tab_def.color if tab_def else CLR_GOLD)
			btn.add_theme_color_override("font_hover_color", (tab_def.color if tab_def else CLR_GOLD).lightened(0.15))
			_style_tab_button(btn, tex)
			btn.modulate = Color(1.3, 1.3, 1.3)
		else:
			btn.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
			btn.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 0.85))
			_style_tab_button(btn, tex)
			btn.modulate = Color(0.8, 0.8, 0.8)

# ===================================================================
# CIRCULAR RINGS (radial wheel background)
# ===================================================================

func _setup_circular_rings() -> void:
	var rings_tex = _load_tex("res://assets/sprites/hub_ui/circular_rings.png")
	if not rings_tex:
		return
	var rings = TextureRect.new()
	rings.texture = rings_tex
	rings.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rings.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rings.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rings.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rings.z_index = 1
	# Center the rings on the porthole, sized to fill most of the screen
	var ring_w = 1100.0
	var ring_h = 640.0
	rings.position = Vector2(480.0 - ring_w / 2.0, 224.0 - ring_h / 2.0)
	rings.size = Vector2(ring_w, ring_h)
	_den_tab.add_child(rings)
	_den_tab.move_child(rings, 0)

# ===================================================================
# TOP BAR (materials + keys)
# ===================================================================

func _refresh_top_bar() -> void:
	if not _key_container or not _mat_container:
		return
	for c in _key_container.get_children():
		c.queue_free()
	for tier in ["bronze", "silver", "gold", "secret"]:
		var count = GameState.keys.get(tier, 0)
		var kc = KEY_COLORS.get(tier, CLR_DIM)
		var icon = _load_tex("key_%s.png" % tier)
		var kh = HBoxContainer.new()
		kh.add_theme_constant_override("separation", 4)
		if icon:
			var tr = TextureRect.new()
			tr.texture = icon
			tr.custom_minimum_size = Vector2(20, 20)
			tr.size = Vector2(20, 20)
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			kh.add_child(tr)
		else:
			var dot = ColorRect.new()
			dot.color = kc
			dot.custom_minimum_size = Vector2(12, 12)
			kh.add_child(dot)
		var kl = Label.new()
		kl.text = str(count)
		kl.add_theme_font_size_override("font_size", 13)
		kl.add_theme_color_override("font_color", kc if count > 0 else CLR_DIM)
		kl.add_theme_color_override("font_outline_color", Color(0, 0, 0))
		kl.add_theme_constant_override("outline_size", 2)
		kh.add_child(kl)
		_key_container.add_child(kh)

	for c in _mat_container.get_children():
		c.queue_free()
	for mat in ["iron_scrap", "timber", "fuel", "organic", "stone", "blueprint"]:
		var count = GameState.materials.get(mat, 0)
		var mc = MAT_COLORS.get(mat, CLR_DIM)
		var icon = _load_tex(MAT_ICONS.get(mat, ""))
		var mh = HBoxContainer.new()
		mh.add_theme_constant_override("separation", 4)
		if icon:
			var tr = TextureRect.new()
			tr.texture = icon
			tr.custom_minimum_size = Vector2(22, 22)
			tr.size = Vector2(22, 22)
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			mh.add_child(tr)
		else:
			var dot = ColorRect.new()
			dot.color = mc
			dot.custom_minimum_size = Vector2(12, 12)
			mh.add_child(dot)
		var ml = Label.new()
		ml.text = str(count)
		ml.add_theme_font_size_override("font_size", 12)
		ml.add_theme_color_override("font_color", mc)
		ml.add_theme_color_override("font_outline_color", Color(0, 0, 0))
		ml.add_theme_constant_override("outline_size", 2)
		mh.add_child(ml)
		_mat_container.add_child(mh)

# ===================================================================
# PUPPY BUST
# ===================================================================

func _setup_puppy() -> void:
	var bust_base := "res://assets/sprites/bust/animations/"
	var anim_defs := {
		"idle_breathing": {"fps": 8, "loop": true},
		"idle_steady": {"fps": 8, "loop": true},
		"idle_sitting": {"fps": 8, "loop": true},
		"snap_fly": {"fps": 10, "loop": false},
		"head_shake": {"fps": 10, "loop": false},
		"head_tilt": {"fps": 10, "loop": false},
		"look_left": {"fps": 10, "loop": false},
		"look_right_to_center": {"fps": 10, "loop": false},
		"happy_panting": {"fps": 10, "loop": false},
		"sleepy": {"fps": 8, "loop": false},
	}
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	var any_loaded := false
	for anim_name in anim_defs:
		var def: Dictionary = anim_defs[anim_name]
		var dir_path: String = bust_base + anim_name + "/south/"
		var frame_textures: Array[Texture2D] = []
		for i in range(100):
			var fpath: String = dir_path + "frame_%03d.png" % i
			if not ResourceLoader.exists(fpath):
				break
			var tex: Texture2D = load(fpath)
			if tex:
				frame_textures.append(tex)
		if frame_textures.is_empty():
			continue
		frames.add_animation(anim_name)
		frames.set_animation_speed(anim_name, def["fps"])
		frames.set_animation_loop(anim_name, def["loop"])
		for tex in frame_textures:
			frames.add_frame(anim_name, tex)
		any_loaded = true
	if not any_loaded:
		return
	_puppy_sprite.sprite_frames = frames
	_puppy_base_y = _puppy_sprite.position.y
	# Clip mask shader
	var clip_shader = Shader.new()
	clip_shader.code = "shader_type canvas_item;\nvoid fragment() {\n  vec2 uv = UV - vec2(0.5);\n  if (uv.y > -0.08) {\n    float r = 0.32 - max(uv.y, 0.0) * 0.3;\n    float d = length(uv);\n    COLOR.a *= 1.0 - smoothstep(r - 0.01, r, d);\n  }\n}\n"
	var mat = ShaderMaterial.new()
	mat.shader = clip_shader
	_puppy_sprite.material = mat
	_puppy_sprite.animation_finished.connect(_on_bust_animation_finished)
	_puppy_sprite.play("idle_breathing")
	_bust_next_anim_time = randf_range(4.0, 8.0)
	# Fade in
	_puppy_sprite.modulate.a = 0.0
	var tw = _puppy_sprite.create_tween()
	tw.tween_property(_puppy_sprite, "modulate:a", 1.0, 0.5).set_delay(0.3)

func _on_bust_animation_finished() -> void:
	if _bust_playing_oneshot:
		_bust_playing_oneshot = false
		_bust_timer = 0.0
		_bust_next_anim_time = randf_range(4.0, 8.0)
		if _puppy_sprite and is_instance_valid(_puppy_sprite):
			_puppy_sprite.play("idle_breathing")

# ===================================================================
# CATEGORY CARDS (Den Upgrades tab)
# ===================================================================

func _populate_all_cards() -> void:
	var slots = {
		"scavenge_snout": _left_card,
		"combat_paws": _right_card,
		"mutation": _bottom_card1,
		"companion_legacy": _bottom_card2,
		"survival_den": _bottom_card3,
	}
	for cat_id in slots:
		var slot: PanelContainer = slots[cat_id]
		_populate_card_slot(slot, cat_id)
		_category_nodes[cat_id] = slot

func _populate_card_slot(slot: PanelContainer, cat_id: String) -> void:
	# Clear existing content
	for c in slot.get_children():
		c.queue_free()

	var cat = _udb.CATEGORIES[cat_id]
	var accent = _udb.CAT_COLORS.get(cat_id, CLR_GOLD)
	var progress = _udb.get_category_progress(cat_id)
	var max_progress = _udb.get_category_max(cat_id)
	var is_max = _udb.is_category_maxed(cat_id)
	var can_buy = _udb.can_afford_any_in_category(cat_id)

	# Style the slot — transparent, content sits on the ring artwork
	var sb_style = StyleBoxFlat.new()
	sb_style.bg_color = Color(0, 0, 0, 0)
	sb_style.set_content_margin_all(2)
	slot.add_theme_stylebox_override("panel", sb_style)
	slot.mouse_filter = Control.MOUSE_FILTER_STOP
	slot.clip_contents = false

	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 1)
	slot.add_child(vbox)

	# Icon
	var anim_sprite: AnimatedSprite2D = null
	var anim_sheet_path = CAT_ANIM_SHEETS.get(cat_id, "")
	var has_anim = ResourceLoader.exists(anim_sheet_path)
	var icon_tex = _load_tex(cat.icon)

	if has_anim:
		var sheet_tex = load(anim_sheet_path) as Texture2D
		if sheet_tex:
			var sf = SpriteFrames.new()
			sf.remove_animation("default")
			sf.add_animation("idle")
			sf.set_animation_speed("idle", 1.0)
			sf.set_animation_loop("idle", false)
			sf.add_animation("hover")
			sf.set_animation_speed("hover", 6.0)
			sf.set_animation_loop("hover", true)
			var frame_w = sheet_tex.get_height()
			var frame_count = sheet_tex.get_width() / frame_w
			for i in int(frame_count):
				var atlas = AtlasTexture.new()
				atlas.atlas = sheet_tex
				atlas.region = Rect2(i * frame_w, 0, frame_w, frame_w)
				if i == 0:
					sf.add_frame("idle", atlas)
				sf.add_frame("hover", atlas)
			anim_sprite = AnimatedSprite2D.new()
			anim_sprite.sprite_frames = sf
			anim_sprite.centered = false
			anim_sprite.scale = Vector2(0.4, 0.4)
			anim_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			anim_sprite.play("idle")
			var icon_wrap = Control.new()
			icon_wrap.custom_minimum_size = Vector2(28, 28)
			icon_wrap.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			anim_sprite.position = Vector2(-1, -1)
			icon_wrap.add_child(anim_sprite)
			vbox.add_child(icon_wrap)

	if not anim_sprite and icon_tex:
		var icon = TextureRect.new()
		icon.texture = icon_tex
		icon.custom_minimum_size = Vector2(28, 28)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		vbox.add_child(icon)

	# Name
	var name_lbl = Label.new()
	name_lbl.text = cat.name
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	name_lbl.add_theme_font_size_override("font_size", 9)
	name_lbl.add_theme_color_override("font_color", accent)
	name_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	name_lbl.add_theme_constant_override("outline_size", 2)
	vbox.add_child(name_lbl)

	# Progress
	var prog_lbl = Label.new()
	if is_max:
		prog_lbl.text = "MAX"
		prog_lbl.add_theme_color_override("font_color", CLR_GREEN)
	else:
		prog_lbl.text = "%d/%d" % [progress, max_progress]
		prog_lbl.add_theme_color_override("font_color", CLR_SILVER)
	prog_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prog_lbl.add_theme_font_size_override("font_size", 9)
	prog_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	prog_lbl.add_theme_constant_override("outline_size", 2)
	vbox.add_child(prog_lbl)

	# Hover — scale from center, render on top
	var p = slot
	var asp = anim_sprite
	slot.pivot_offset = slot.size / 2.0
	slot.mouse_entered.connect(func():
		p.pivot_offset = p.size / 2.0
		p.z_index = 25
		var tw = p.create_tween()
		tw.tween_property(p, "scale", Vector2(1.08, 1.08), 0.1).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		if asp and is_instance_valid(asp):
			asp.play("hover")
	)
	slot.mouse_exited.connect(func():
		var tw = p.create_tween()
		tw.tween_property(p, "scale", Vector2(1.0, 1.0), 0.08).set_ease(Tween.EASE_IN)
		tw.finished.connect(func(): p.z_index = 20)
		if asp and is_instance_valid(asp):
			asp.play("idle")
	)
	# Click
	var cid = cat_id
	slot.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_show_detail_panel(cid)
	)

func _refresh_category_nodes() -> void:
	var slots = {
		"scavenge_snout": _left_card,
		"combat_paws": _right_card,
		"mutation": _bottom_card1,
		"companion_legacy": _bottom_card2,
		"survival_den": _bottom_card3,
	}
	for cat_id in slots:
		var slot = slots[cat_id]
		if not is_instance_valid(slot):
			continue
		# Disconnect old signals
		for conn in slot.mouse_entered.get_connections():
			slot.mouse_entered.disconnect(conn.callable)
		for conn in slot.mouse_exited.get_connections():
			slot.mouse_exited.disconnect(conn.callable)
		for conn in slot.gui_input.get_connections():
			slot.gui_input.disconnect(conn.callable)
		_populate_card_slot(slot, cat_id)
		_category_nodes[cat_id] = slot

# ===================================================================
# DETAIL PANEL
# ===================================================================

func _close_detail_panel() -> void:
	if _detail_panel and is_instance_valid(_detail_panel):
		_detail_panel.queue_free()
		_detail_panel = null
	_enter_dungeon_btn.visible = true
	_junkyard_btn.visible = true
	_wardrobe_btn.visible = true

func _show_detail_panel(cat_id: String) -> void:
	_close_detail_panel()

	var cat = _udb.CATEGORIES[cat_id]
	var accent = _udb.CAT_COLORS.get(cat_id, CLR_GOLD)

	# Full-screen overlay container
	var overlay = Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = 50
	add_child(overlay)
	_detail_panel = overlay
	_enter_dungeon_btn.visible = false
	_junkyard_btn.visible = false
	_wardrobe_btn.visible = false

	# Dim background — click to close
	var dim = ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.6)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_close_detail_panel()
	)
	overlay.add_child(dim)

	# Centered panel
	var panel_w = 340
	var panel_h = 440
	var panel = PanelContainer.new()
	panel.position = Vector2((960 - panel_w) / 2.0, (540 - panel_h) / 2.0)
	panel.size = Vector2(panel_w, panel_h)
	var menu_plate = _load_tex("res://assets/sprites/hub_ui/right_menu_plate.jpg")
	if menu_plate:
		var sb = StyleBoxTexture.new()
		sb.texture = menu_plate
		sb.texture_margin_left = 16
		sb.texture_margin_right = 16
		sb.texture_margin_top = 16
		sb.texture_margin_bottom = 16
		sb.set_content_margin_all(24)
		panel.add_theme_stylebox_override("panel", sb)
	else:
		var sb = StyleBoxFlat.new()
		sb.bg_color = Color(0.06, 0.06, 0.10, 0.95)
		sb.border_color = accent.lerp(Color.WHITE, 0.15)
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(6)
		sb.set_content_margin_all(20)
		panel.add_theme_stylebox_override("panel", sb)
	overlay.add_child(panel)

	var scroll = ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)

	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 8)
	scroll.add_child(vbox)

	var header = Label.new()
	header.text = cat.name
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", 18)
	header.add_theme_color_override("font_color", accent)
	header.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	header.add_theme_constant_override("outline_size", 2)
	vbox.add_child(header)

	var desc_lbl = Label.new()
	desc_lbl.text = cat.desc
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.add_theme_font_size_override("font_size", 10)
	desc_lbl.add_theme_color_override("font_color", Color.WHITE)
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(desc_lbl)

	var sep = HSeparator.new()
	vbox.add_child(sep)

	for upgrade_id in cat.upgrades:
		var upgrade_card = _create_upgrade_card(upgrade_id, accent, cat_id)
		vbox.add_child(upgrade_card)

	var close_btn = Button.new()
	close_btn.text = "✕  Close"
	close_btn.add_theme_font_size_override("font_size", 12)
	close_btn.add_theme_color_override("font_color", CLR_SILVER)
	_style_button_flat(close_btn)
	close_btn.pressed.connect(func():
		_close_detail_panel()
	)
	vbox.add_child(close_btn)

	overlay.modulate.a = 0.0
	var tw = overlay.create_tween()
	tw.tween_property(overlay, "modulate:a", 1.0, 0.15)
	# Scale-in effect on the panel
	panel.pivot_offset = Vector2(panel_w / 2.0, panel_h / 2.0)
	panel.scale = Vector2(0.9, 0.9)
	var tw2 = panel.create_tween()
	tw2.tween_property(panel, "scale", Vector2(1.0, 1.0), 0.15).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

func _create_upgrade_card(upgrade_id: String, accent: Color, cat_id: String) -> PanelContainer:
	var upg = _udb.UPGRADES[upgrade_id]
	var level = _udb.get_upgrade_level(upgrade_id)
	var max_lvl = _udb.get_max_level(upgrade_id)
	var is_max = _udb.is_maxed(upgrade_id)
	var can_buy = _udb.can_afford_upgrade(upgrade_id)

	var card = PanelContainer.new()
	var csb = StyleBoxFlat.new()
	csb.bg_color = Color(0.12, 0.12, 0.16, 0.90)
	if is_max:
		csb.border_color = CLR_GREEN.lerp(Color.WHITE, 0.2)
	elif can_buy:
		csb.border_color = accent.lerp(Color.WHITE, 0.2)
	else:
		csb.border_color = Color(0.35, 0.35, 0.40, 0.6)
	csb.set_border_width_all(2)
	csb.set_corner_radius_all(4)
	csb.set_content_margin_all(10)
	card.add_theme_stylebox_override("panel", csb)

	var cv = VBoxContainer.new()
	cv.add_theme_constant_override("separation", 4)
	card.add_child(cv)

	var name_row = HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 6)
	cv.add_child(name_row)

	var arrow = Label.new()
	arrow.text = ">"
	arrow.add_theme_color_override("font_color", CLR_GREEN if is_max else CLR_ORANGE)
	arrow.add_theme_font_size_override("font_size", 14)
	name_row.add_child(arrow)

	var icon = _load_tex(upg.icon)
	if icon:
		var ir = TextureRect.new()
		ir.texture = icon
		ir.custom_minimum_size = Vector2(28, 28)
		ir.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ir.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		name_row.add_child(ir)

	var nlbl = Label.new()
	nlbl.text = upg.name
	nlbl.add_theme_font_size_override("font_size", 13)
	nlbl.add_theme_color_override("font_color", accent)
	nlbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(nlbl)

	var lvl_lbl = Label.new()
	if is_max:
		lvl_lbl.text = "MAX"
		lvl_lbl.add_theme_color_override("font_color", CLR_GREEN)
	else:
		lvl_lbl.text = "Lv %d/%d" % [level, max_lvl]
		lvl_lbl.add_theme_color_override("font_color", CLR_SILVER)
	lvl_lbl.add_theme_font_size_override("font_size", 11)
	name_row.add_child(lvl_lbl)

	var dlbl = Label.new()
	dlbl.text = upg.desc
	dlbl.add_theme_font_size_override("font_size", 10)
	dlbl.add_theme_color_override("font_color", CLR_SILVER)
	dlbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	cv.add_child(dlbl)

	var effect_text = _udb.get_effect_text(upgrade_id)
	if effect_text != "":
		var elbl = Label.new()
		elbl.text = "Current: " + effect_text
		elbl.add_theme_font_size_override("font_size", 10)
		elbl.add_theme_color_override("font_color", CLR_GREEN if level > 0 else CLR_DIM)
		cv.add_child(elbl)

	if not is_max:
		var cost = _udb.get_next_cost(upgrade_id)
		var cost_lbl = RichTextLabel.new()
		cost_lbl.bbcode_enabled = true
		cost_lbl.fit_content = true
		cost_lbl.scroll_active = false
		cost_lbl.custom_minimum_size.x = 10
		cost_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cost_lbl.add_theme_font_size_override("normal_font_size", 10)
		var parts: Array[String] = []
		parts.append("[color=#aaaaaa]Cost:  [/color]")
		for mat_name in cost:
			var have = GameState.materials.get(mat_name, 0)
			var need = cost[mat_name]
			var abbrev = mat_name.replace("iron_scrap", "iron").replace("blueprint", "bp")
			var clr = "#66cc66" if have >= need else "#cc4444"
			parts.append("[color=%s]%d %s[/color]" % [clr, need, abbrev])
		cost_lbl.text = "  ".join(parts)
		cv.add_child(cost_lbl)

		var btn = Button.new()
		btn.text = "UPGRADE"
		btn.add_theme_font_size_override("font_size", 13)
		var upg_tex = _load_tex("res://assets/sprites/hub_ui/upgrade_button.png")
		if can_buy and upg_tex:
			_style_button_with_texture(btn, upg_tex, CLR_ORANGE)
		elif can_buy:
			_style_button_accent(btn, CLR_ORANGE)
		else:
			_style_button_flat(btn)
			btn.add_theme_color_override("font_color", CLR_DIM)
			btn.disabled = true
		var uid = upgrade_id
		var cid = cat_id
		btn.pressed.connect(func():
			if _udb.purchase_upgrade(uid):
				Achievements.check_building_achievements()
				_refresh_top_bar()
				_refresh_category_nodes()
				_show_detail_panel(cid)
		)
		cv.add_child(btn)

	return card

# ===================================================================
# CARD COLLECTION TAB
# ===================================================================

func _build_card_collection_tab() -> void:
	var card_db = get_node_or_null("/root/CardDB")
	if not card_db:
		var lbl = Label.new()
		lbl.text = "Card system not available"
		lbl.add_theme_color_override("font_color", CLR_DIM)
		_card_tab.add_child(lbl)
		return

	# Background panel for readability
	var bg = PanelContainer.new()
	bg.position = Vector2(200, 0)
	bg.size = Vector2(560, 420)
	var bg_sb = StyleBoxFlat.new()
	bg_sb.bg_color = Color(0.06, 0.06, 0.10, 0.92)
	bg_sb.set_corner_radius_all(6)
	bg_sb.set_content_margin_all(12)
	bg.add_theme_stylebox_override("panel", bg_sb)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card_tab.add_child(bg)

	var scroll = ScrollContainer.new()
	scroll.position = Vector2(210, 5)
	scroll.size = Vector2(540, 410)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_card_tab.add_child(scroll)

	var main_vbox = VBoxContainer.new()
	main_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vbox.add_theme_constant_override("separation", 12)
	scroll.add_child(main_vbox)

	var progress = card_db.get_total_progress()
	var title = Label.new()
	title.text = "CARD COLLECTION  (%d / %d)" % [progress.owned, progress.total]
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", CLR_GOLD)
	main_vbox.add_child(title)

	for deck_name in ["Scrap", "Lost", "Critter", "Overgrowth"]:
		var dp = card_db.get_deck_progress(deck_name)
		var is_complete = card_db.is_deck_complete(deck_name)
		var deck_cards: Array = []
		var deck_color = CLR_SILVER
		for c in card_db.cards:
			if c.deck == deck_name:
				deck_cards.append(c)
				deck_color = c.get("deck_color", CLR_SILVER)

		var deck_header = HBoxContainer.new()
		deck_header.add_theme_constant_override("separation", 8)
		main_vbox.add_child(deck_header)

		var deck_lbl = Label.new()
		deck_lbl.text = "%s  (%d/%d)" % [deck_name, dp.owned, dp.total]
		deck_lbl.add_theme_font_size_override("font_size", 13)
		deck_lbl.add_theme_color_override("font_color", CLR_GREEN if is_complete else deck_color)
		deck_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		deck_header.add_child(deck_lbl)

		if is_complete:
			var bonus_lbl = Label.new()
			bonus_lbl.text = "COMPLETE!"
			bonus_lbl.add_theme_font_size_override("font_size", 11)
			bonus_lbl.add_theme_color_override("font_color", CLR_GREEN)
			deck_header.add_child(bonus_lbl)

		var grid = GridContainer.new()
		grid.columns = 5
		grid.add_theme_constant_override("h_separation", 4)
		grid.add_theme_constant_override("v_separation", 4)
		main_vbox.add_child(grid)

		for card_def in deck_cards:
			var card_id = card_def.id
			var owned = card_db.collected.has(card_id)
			var card_panel = PanelContainer.new()
			card_panel.custom_minimum_size = Vector2(95, 40)
			var csb = StyleBoxFlat.new()
			csb.bg_color = Color(0.10, 0.10, 0.12, 0.85) if owned else Color(0.06, 0.06, 0.08, 0.7)
			csb.border_color = deck_color * Color(1, 1, 1, 0.5) if owned else Color(0.2, 0.2, 0.2, 0.3)
			csb.set_border_width_all(1)
			csb.set_corner_radius_all(3)
			csb.set_content_margin_all(4)
			card_panel.add_theme_stylebox_override("panel", csb)
			var cv = VBoxContainer.new()
			cv.add_theme_constant_override("separation", 1)
			card_panel.add_child(cv)
			var name_lbl = Label.new()
			name_lbl.text = card_def.name if owned else "???"
			name_lbl.add_theme_font_size_override("font_size", 10)
			name_lbl.add_theme_color_override("font_color", deck_color if owned else CLR_DIM)
			name_lbl.clip_text = true
			cv.add_child(name_lbl)
			grid.add_child(card_panel)

		var sep_line = HSeparator.new()
		main_vbox.add_child(sep_line)

# ===================================================================
# ACHIEVEMENTS TAB
# ===================================================================

func _build_achievements_tab() -> void:
	# Background panel for readability
	var bg = PanelContainer.new()
	bg.position = Vector2(200, 0)
	bg.size = Vector2(560, 420)
	var bg_sb = StyleBoxFlat.new()
	bg_sb.bg_color = Color(0.06, 0.06, 0.10, 0.92)
	bg_sb.set_corner_radius_all(6)
	bg_sb.set_content_margin_all(12)
	bg.add_theme_stylebox_override("panel", bg_sb)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ach_tab.add_child(bg)

	var scroll = ScrollContainer.new()
	scroll.position = Vector2(210, 5)
	scroll.size = Vector2(540, 410)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_ach_tab.add_child(scroll)

	var main_vbox = VBoxContainer.new()
	main_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vbox.add_theme_constant_override("separation", 12)
	scroll.add_child(main_vbox)

	var title = Label.new()
	title.text = "ACHIEVEMENTS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", CLR_GOLD)
	main_vbox.add_child(title)

	var total = Achievements.ACHIEVEMENTS.size()
	var done = 0
	for id in Achievements.ACHIEVEMENTS:
		if Achievements.is_unlocked(id):
			done += 1
	var progress_lbl = Label.new()
	progress_lbl.text = "%d / %d Unlocked" % [done, total]
	progress_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	progress_lbl.add_theme_font_size_override("font_size", 12)
	progress_lbl.add_theme_color_override("font_color", CLR_SILVER)
	main_vbox.add_child(progress_lbl)

	var bar_bg = ColorRect.new()
	bar_bg.custom_minimum_size = Vector2(0, 8)
	bar_bg.color = Color(0.15, 0.15, 0.18)
	main_vbox.add_child(bar_bg)
	if total > 0:
		var bar_container = HBoxContainer.new()
		bar_container.custom_minimum_size = Vector2(0, 8)
		main_vbox.add_child(bar_container)
		var fill = ColorRect.new()
		fill.color = CLR_GOLD
		fill.custom_minimum_size = Vector2(max(4, 700.0 * done / total), 8)
		fill.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		bar_container.add_child(fill)

	for cat in Achievements.CATEGORIES:
		var cat_ids: Array = []
		for id in Achievements.ACHIEVEMENTS:
			if Achievements.ACHIEVEMENTS[id].get("category", "") == cat:
				cat_ids.append(id)
		if cat_ids.is_empty():
			continue
		var cat_lbl = Label.new()
		cat_lbl.text = cat.to_upper()
		cat_lbl.add_theme_font_size_override("font_size", 14)
		cat_lbl.add_theme_color_override("font_color", CLR_GOLD)
		main_vbox.add_child(cat_lbl)
		for id in cat_ids:
			var ach = Achievements.ACHIEVEMENTS[id]
			var unlocked = Achievements.is_unlocked(id)
			var row = _create_achievement_row(id, ach, unlocked)
			main_vbox.add_child(row)

func _create_achievement_row(id: String, ach: Dictionary, unlocked: bool) -> PanelContainer:
	var row = PanelContainer.new()
	row.custom_minimum_size = Vector2(0, 44)
	var rsb = StyleBoxFlat.new()
	rsb.bg_color = Color(0.12, 0.12, 0.14, 0.8) if unlocked else Color(0.08, 0.08, 0.10, 0.6)
	rsb.border_color = ach.get("icon_color", CLR_DIM) * Color(1, 1, 1, 0.5) if unlocked else Color(0.2, 0.2, 0.2, 0.3)
	rsb.set_border_width_all(1)
	rsb.set_corner_radius_all(3)
	rsb.set_content_margin_all(6)
	row.add_theme_stylebox_override("panel", rsb)
	var hb = HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	row.add_child(hb)
	var icon_rect = ColorRect.new()
	icon_rect.custom_minimum_size = Vector2(28, 28)
	icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon_rect.color = ach.get("icon_color", CLR_GOLD) if unlocked else Color(0.2, 0.2, 0.22)
	hb.add_child(icon_rect)
	var check_lbl = Label.new()
	check_lbl.text = "OK" if unlocked else "?"
	check_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	check_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	check_lbl.add_theme_font_size_override("font_size", 10)
	check_lbl.add_theme_color_override("font_color", Color(0.0, 0.0, 0.0) if unlocked else CLR_DIM)
	check_lbl.position = Vector2(5, 5)
	icon_rect.add_child(check_lbl)
	var vb = VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 1)
	hb.add_child(vb)
	var name_lbl = Label.new()
	name_lbl.text = ach.get("name", id)
	name_lbl.add_theme_font_size_override("font_size", 12)
	name_lbl.add_theme_color_override("font_color", ach.get("icon_color", CLR_SILVER) if unlocked else CLR_DIM)
	vb.add_child(name_lbl)
	var desc_lbl = Label.new()
	desc_lbl.text = ach.get("desc", "")
	desc_lbl.add_theme_font_size_override("font_size", 9)
	desc_lbl.add_theme_color_override("font_color", CLR_SILVER if unlocked else Color(0.35, 0.35, 0.38))
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	vb.add_child(desc_lbl)
	var stat_name = ach.get("stat", "")
	var target = ach.get("target", 0)
	if stat_name != "" and target > 0 and not unlocked:
		var current = Achievements.stats.get(stat_name, 0)
		var prog_lbl = Label.new()
		prog_lbl.text = "%d / %d" % [mini(current, target), target]
		prog_lbl.add_theme_font_size_override("font_size", 10)
		prog_lbl.add_theme_color_override("font_color", CLR_ORANGE)
		prog_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hb.add_child(prog_lbl)
	return row

# ===================================================================
# ARCHIVE TAB
# ===================================================================

func _build_archive_tab() -> void:
	var bg = PanelContainer.new()
	bg.position = Vector2(200, 0)
	bg.size = Vector2(560, 420)
	var bg_sb = StyleBoxFlat.new()
	bg_sb.bg_color = Color(0.06, 0.06, 0.10, 0.92)
	bg_sb.set_corner_radius_all(6)
	bg_sb.set_content_margin_all(12)
	bg.add_theme_stylebox_override("panel", bg_sb)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_archive_tab.add_child(bg)

	# Inventory content — show materials and keys
	var scroll = ScrollContainer.new()
	scroll.position = Vector2(210, 5)
	scroll.size = Vector2(540, 410)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_archive_tab.add_child(scroll)

	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 12)
	scroll.add_child(vbox)

	var title = Label.new()
	title.text = "INVENTORY"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", CLR_GOLD)
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	title.add_theme_constant_override("outline_size", 2)
	vbox.add_child(title)

	# Materials section
	var mat_header = Label.new()
	mat_header.text = "— Materials —"
	mat_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mat_header.add_theme_font_size_override("font_size", 13)
	mat_header.add_theme_color_override("font_color", CLR_SILVER)
	vbox.add_child(mat_header)

	var mat_grid = GridContainer.new()
	mat_grid.columns = 3
	mat_grid.add_theme_constant_override("h_separation", 12)
	mat_grid.add_theme_constant_override("v_separation", 8)
	mat_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(mat_grid)

	var mat_names = {
		"iron_scrap": "Iron Scrap", "timber": "Timber", "fuel": "Fuel",
		"organic": "Organic", "stone": "Stone", "blueprint": "Blueprint",
	}
	for mat_id in ["iron_scrap", "timber", "fuel", "organic", "stone", "blueprint"]:
		var count = GameState.materials.get(mat_id, 0)
		var mc = MAT_COLORS.get(mat_id, CLR_DIM)
		var item_hbox = HBoxContainer.new()
		item_hbox.add_theme_constant_override("separation", 6)
		var icon = _load_tex(MAT_ICONS.get(mat_id, ""))
		if icon:
			var ir = TextureRect.new()
			ir.texture = icon
			ir.custom_minimum_size = Vector2(24, 24)
			ir.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			ir.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			ir.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			item_hbox.add_child(ir)
		var info_vbox = VBoxContainer.new()
		info_vbox.add_theme_constant_override("separation", 0)
		var name_lbl = Label.new()
		name_lbl.text = mat_names.get(mat_id, mat_id)
		name_lbl.add_theme_font_size_override("font_size", 11)
		name_lbl.add_theme_color_override("font_color", mc)
		name_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0))
		name_lbl.add_theme_constant_override("outline_size", 1)
		info_vbox.add_child(name_lbl)
		var count_lbl = Label.new()
		count_lbl.text = "x %d" % count
		count_lbl.add_theme_font_size_override("font_size", 13)
		count_lbl.add_theme_color_override("font_color", Color.WHITE if count > 0 else CLR_DIM)
		info_vbox.add_child(count_lbl)
		item_hbox.add_child(info_vbox)
		mat_grid.add_child(item_hbox)

	vbox.add_child(HSeparator.new())

	# Keys section
	var key_header = Label.new()
	key_header.text = "— Keys —"
	key_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	key_header.add_theme_font_size_override("font_size", 13)
	key_header.add_theme_color_override("font_color", CLR_SILVER)
	vbox.add_child(key_header)

	var key_grid = GridContainer.new()
	key_grid.columns = 4
	key_grid.add_theme_constant_override("h_separation", 16)
	key_grid.add_theme_constant_override("v_separation", 8)
	key_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(key_grid)

	for tier in ["bronze", "silver", "gold", "secret"]:
		var count = GameState.keys.get(tier, 0)
		var kc = KEY_COLORS.get(tier, CLR_DIM)
		var item_hbox = HBoxContainer.new()
		item_hbox.add_theme_constant_override("separation", 6)
		var icon = _load_tex("key_%s.png" % tier)
		if icon:
			var ir = TextureRect.new()
			ir.texture = icon
			ir.custom_minimum_size = Vector2(22, 22)
			ir.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			ir.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			ir.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			item_hbox.add_child(ir)
		var info_vbox = VBoxContainer.new()
		info_vbox.add_theme_constant_override("separation", 0)
		var name_lbl = Label.new()
		name_lbl.text = tier.capitalize()
		name_lbl.add_theme_font_size_override("font_size", 11)
		name_lbl.add_theme_color_override("font_color", kc)
		info_vbox.add_child(name_lbl)
		var count_lbl = Label.new()
		count_lbl.text = "x %d" % count
		count_lbl.add_theme_font_size_override("font_size", 13)
		count_lbl.add_theme_color_override("font_color", Color.WHITE if count > 0 else CLR_DIM)
		info_vbox.add_child(count_lbl)
		item_hbox.add_child(info_vbox)
		key_grid.add_child(item_hbox)

# ===================================================================
# BOTTOM BAR
# ===================================================================

func _setup_bottom_bar() -> void:
	# Enter Dungeon — use dedicated button asset
	var dungeon_tex = _load_tex("res://assets/sprites/hub_ui/enter_dungeon_btn.png")
	if dungeon_tex:
		_style_button_with_texture(_enter_dungeon_btn, dungeon_tex, Color.WHITE)
	else:
		_style_button_accent(_enter_dungeon_btn, CLR_ORANGE)
	_enter_dungeon_btn.add_theme_font_size_override("font_size", 16)

	# Junkyard — use dedicated button asset
	var junkyard_tex = _load_tex("res://assets/sprites/hub_ui/junkyard_btn.png")
	if junkyard_tex:
		_style_button_with_texture(_junkyard_btn, junkyard_tex, Color.WHITE)
	else:
		_style_button_accent(_junkyard_btn, Color(0.75, 0.55, 0.25))

	# Wardrobe — use steel rect or fallback
	var wardrobe_tex = _load_tex("res://assets/sprites/hub_ui/steel_rect_4.jpg")
	if wardrobe_tex:
		_style_button_with_texture(_wardrobe_btn, wardrobe_tex, CLR_SILVER)
	else:
		_style_button_accent(_wardrobe_btn, CLR_SILVER)
	_enter_dungeon_btn.pressed.connect(_start_run)
	_junkyard_btn.pressed.connect(_enter_junkyard)
	_wardrobe_btn.pressed.connect(_open_armor_popup)

# ===================================================================
# ARMOR POPUP
# ===================================================================

func _open_armor_popup() -> void:
	var result = _create_overlay("WARDROBE", 700, 440)
	if result.is_empty():
		return
	var content: VBoxContainer = result.content
	var armor_db = get_node_or_null("/root/ArmorDB")
	if not armor_db:
		var lbl = Label.new()
		lbl.text = "Armor system not available"
		lbl.add_theme_color_override("font_color", CLR_DIM)
		content.add_child(lbl)
		return
	var all_armor = armor_db.get_all_armors()
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)
	var grid = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)
	for armor in all_armor:
		var card = _create_armor_card(armor, armor_db)
		grid.add_child(card)

func _create_armor_card(armor: Dictionary, armor_db) -> PanelContainer:
	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(210, 160)
	var is_unlocked = armor_db.is_unlocked(armor.id)
	var is_stat_equipped = GameState.equipped_armor_stat == armor.id
	var is_look_equipped = GameState.equipped_armor_visual == armor.id
	var rarity_color = _get_rarity_color(armor.get("rarity", "common"))
	var csb = StyleBoxFlat.new()
	csb.bg_color = Color(0.10, 0.10, 0.12, 0.85)
	csb.border_color = rarity_color * Color(1, 1, 1, 0.4) if is_unlocked else Color(0.2, 0.2, 0.2, 0.4)
	csb.set_border_width_all(1)
	csb.set_corner_radius_all(3)
	csb.set_content_margin_all(6)
	card.add_theme_stylebox_override("panel", csb)
	var hb = HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	card.add_child(hb)
	var preview_container = Control.new()
	preview_container.custom_minimum_size = Vector2(60, 80)
	hb.add_child(preview_container)
	if is_unlocked:
		var icon_path = "res://assets/sprites/armor_icons/%s.png" % armor.id
		if not ResourceLoader.exists(icon_path):
			var armor_folder = armor.id.replace("bandana_red", "bandana").replace("bandana_blue", "blue_bandana")
			icon_path = "res://assets/sprites/player/%s/idle/south/frame_000.png" % armor_folder
		if not ResourceLoader.exists(icon_path):
			icon_path = "res://assets/sprites/player/base/idle/south/frame_000.png"
		if ResourceLoader.exists(icon_path):
			var ptex = load(icon_path)
			if ptex:
				var preview = TextureRect.new()
				preview.texture = ptex
				preview.custom_minimum_size = Vector2(56, 56)
				preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				preview.position = Vector2(2, 12)
				preview_container.add_child(preview)
	else:
		var lock_icon = Label.new()
		lock_icon.text = "?"
		lock_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lock_icon.add_theme_font_size_override("font_size", 28)
		lock_icon.add_theme_color_override("font_color", CLR_DIM)
		lock_icon.position = Vector2(15, 20)
		preview_container.add_child(lock_icon)
	var vb = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 3)
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(vb)
	var name_lbl = Label.new()
	name_lbl.text = armor.get("name", armor.id) if is_unlocked else "???"
	name_lbl.add_theme_font_size_override("font_size", 12)
	name_lbl.add_theme_color_override("font_color", rarity_color if is_unlocked else CLR_DIM)
	vb.add_child(name_lbl)
	var rar_lbl = Label.new()
	rar_lbl.text = armor.get("rarity", "common").to_upper()
	rar_lbl.add_theme_font_size_override("font_size", 8)
	rar_lbl.add_theme_color_override("font_color", rarity_color * Color(1, 1, 1, 0.6))
	vb.add_child(rar_lbl)
	if is_unlocked:
		if armor.get("stats", {}).size() > 0:
			var stats_text = armor_db.get_stats_summary(armor) if armor_db.has_method("get_stats_summary") else ""
			if stats_text != "":
				var stats_lbl = Label.new()
				stats_lbl.text = stats_text
				stats_lbl.add_theme_font_size_override("font_size", 9)
				stats_lbl.add_theme_color_override("font_color", CLR_SILVER)
				stats_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
				vb.add_child(stats_lbl)
		if is_stat_equipped:
			var badge = Label.new()
			badge.text = "[STATS EQUIPPED]"
			badge.add_theme_font_size_override("font_size", 9)
			badge.add_theme_color_override("font_color", CLR_ORANGE)
			vb.add_child(badge)
		if is_look_equipped:
			var badge = Label.new()
			badge.text = "[LOOK EQUIPPED]"
			badge.add_theme_font_size_override("font_size", 9)
			badge.add_theme_color_override("font_color", CLR_GREEN)
			vb.add_child(badge)
		var btn_row = HBoxContainer.new()
		btn_row.add_theme_constant_override("separation", 4)
		vb.add_child(btn_row)
		if not is_stat_equipped and armor.get("stats", {}).size() > 0:
			var eq_btn = Button.new()
			eq_btn.text = "Stats"
			eq_btn.add_theme_font_size_override("font_size", 9)
			_style_button_accent(eq_btn, CLR_ORANGE)
			var aid = armor.id
			eq_btn.pressed.connect(func():
				GameState.equipped_armor_stat = aid
				SaveManager.save_game()
				_close_overlay()
				_open_armor_popup()
			)
			btn_row.add_child(eq_btn)
		if not is_look_equipped:
			var lk_btn = Button.new()
			lk_btn.text = "Look"
			lk_btn.add_theme_font_size_override("font_size", 9)
			_style_button_accent(lk_btn, CLR_GREEN)
			var aid = armor.id
			lk_btn.pressed.connect(func():
				GameState.equipped_armor_visual = aid
				SaveManager.save_game()
				_close_overlay()
				_open_armor_popup()
			)
			btn_row.add_child(lk_btn)
	else:
		var lock_lbl = Label.new()
		lock_lbl.text = armor.get("unlock_method", "Locked")
		lock_lbl.add_theme_font_size_override("font_size", 9)
		lock_lbl.add_theme_color_override("font_color", CLR_DIM)
		lock_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		vb.add_child(lock_lbl)
	return card

# ===================================================================
# OVERLAY SYSTEM
# ===================================================================

func _create_overlay(title: String, panel_w: int = 640, panel_h: int = 420) -> Dictionary:
	if _overlay_panel and is_instance_valid(_overlay_panel):
		_overlay_panel.queue_free()
		_overlay_panel = null
	_confirm_building = ""
	var dim = ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(_on_dim_click)
	_overlay_panel = Control.new()
	_overlay_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay_panel.z_index = 80
	add_child(_overlay_panel)
	_overlay_panel.add_child(dim)
	var panel_x = (960 - panel_w) / 2.0
	var panel_y = (540 - panel_h) / 2.0
	var panel_bg = Panel.new()
	panel_bg.position = Vector2(panel_x, panel_y)
	panel_bg.size = Vector2(panel_w, panel_h)
	var sb = StyleBoxFlat.new()
	sb.bg_color = CLR_PANEL_BG
	sb.border_color = CLR_BORDER
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(5)
	sb.set_content_margin_all(12)
	panel_bg.add_theme_stylebox_override("panel", sb)
	_overlay_panel.add_child(panel_bg)
	var title_bar = ColorRect.new()
	title_bar.color = Color(0.12, 0.12, 0.14, 0.9)
	title_bar.position = Vector2(2, 2)
	title_bar.size = Vector2(panel_w - 4, 34)
	panel_bg.add_child(title_bar)
	var title_label = Label.new()
	title_label.text = title
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.position = Vector2(0, 6)
	title_label.size = Vector2(panel_w, 28)
	title_label.add_theme_font_size_override("font_size", 18)
	title_label.add_theme_color_override("font_color", CLR_GOLD)
	title_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	title_label.add_theme_constant_override("shadow_offset_x", 1)
	title_label.add_theme_constant_override("shadow_offset_y", 1)
	panel_bg.add_child(title_label)
	var close_btn = Button.new()
	close_btn.text = "X"
	close_btn.position = Vector2(panel_w - 42, 4)
	close_btn.size = Vector2(34, 28)
	close_btn.add_theme_font_size_override("font_size", 14)
	close_btn.add_theme_color_override("font_color", CLR_RED)
	close_btn.add_theme_color_override("font_hover_color", Color(1.0, 0.4, 0.4))
	_style_button_flat(close_btn)
	close_btn.pressed.connect(_close_overlay)
	panel_bg.add_child(close_btn)
	var content = VBoxContainer.new()
	content.position = Vector2(14, 44)
	content.size = Vector2(panel_w - 28, panel_h - 56)
	content.add_theme_constant_override("separation", 6)
	panel_bg.add_child(content)
	_overlay_panel.modulate.a = 0.0
	var tw = _overlay_panel.create_tween()
	tw.tween_property(_overlay_panel, "modulate:a", 1.0, 0.2)
	return {"overlay": _overlay_panel, "content": content, "panel": panel_bg}

func _on_dim_click(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_close_overlay()

func _close_overlay() -> void:
	if _overlay_panel and is_instance_valid(_overlay_panel):
		var tw = _overlay_panel.create_tween()
		tw.tween_property(_overlay_panel, "modulate:a", 0.0, 0.15)
		tw.tween_callback(_overlay_panel.queue_free)
		_overlay_panel = null

# ===================================================================
# SCENE TRANSITIONS
# ===================================================================

func _start_run() -> void:
	if not GameState.run_in_progress:
		SaveManager.reload_permanent()
		GameState.start_new_run()
		_apply_passive_gains()
		GameState._materials_at_run_start = GameState.materials.duplicate()
	else:
		GameState.reapply_permanent_bonuses()
		GameState._materials_at_run_start = GameState.materials.duplicate()
	SaveManager.save_game()
	GameState.set_phase(GameState.Phase.ARENA_PREP)
	_close_overlay()
	# Simple fade to black then load arena
	var darkness = ColorRect.new()
	darkness.color = Color(0.0, 0.0, 0.0, 0.0)
	darkness.set_anchors_preset(Control.PRESET_FULL_RECT)
	darkness.z_index = 100
	darkness.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(darkness)
	var tw = create_tween()
	tw.tween_property(darkness, "color:a", 1.0, 0.4).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		get_tree().change_scene_to_file("res://scenes/arena.tscn")
	)

func _enter_junkyard() -> void:
	var jy = get_node_or_null("/root/JunkyardState")
	if jy and jy.has_method("enter_junkyard"):
		jy.enter_junkyard()
		SaveManager.save_game()
		get_tree().change_scene_to_file("res://scenes/junkyard.tscn")

func _apply_passive_gains() -> void:
	var garden = GameState.permanent.get("garden_level", 0)
	var heap   = GameState.permanent.get("scrapheap_level", 0)
	if garden > 0: GameState.add_material("organic",    garden * 2)
	if heap   > 0: GameState.add_material("iron_scrap", heap   * 2)

# ===================================================================
# UTILITY HELPERS
# ===================================================================

func _load_tex(filename: String) -> Texture2D:
	if _tex_cache.has(filename):
		return _tex_cache[filename]
	var path = filename if filename.begins_with("res://") else "res://assets/sprites/ui/" + filename
	if ResourceLoader.exists(path):
		var tex = load(path)
		if tex:
			_tex_cache[filename] = tex
			return tex
	_tex_cache[filename] = null
	return null

func _get_rarity_color(rarity: String) -> Color:
	match rarity:
		"common": return Color(0.6, 0.6, 0.6)
		"uncommon": return CLR_GREEN
		"rare": return Color(0.35, 0.55, 1.0)
		"legendary": return CLR_GOLD
	return CLR_DIM

func _style_button_flat(btn: Button) -> void:
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.14, 0.14, 0.16, 0.7)
	sb.set_border_width_all(0)
	sb.set_corner_radius_all(2)
	sb.set_content_margin_all(4)
	btn.add_theme_stylebox_override("normal", sb)
	var sbh = sb.duplicate()
	sbh.bg_color = Color(0.20, 0.20, 0.24, 0.8)
	btn.add_theme_stylebox_override("hover", sbh)
	var sbp = sb.duplicate()
	sbp.bg_color = Color(0.25, 0.25, 0.30, 0.9)
	btn.add_theme_stylebox_override("pressed", sbp)

func _style_button_accent(btn: Button, accent: Color) -> void:
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.12, 0.14, 0.85)
	sb.border_color = accent * Color(1, 1, 1, 0.5)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(3)
	sb.set_content_margin_all(5)
	btn.add_theme_stylebox_override("normal", sb)
	var sbh = sb.duplicate()
	sbh.bg_color = Color(0.18, 0.18, 0.22, 0.9)
	sbh.border_color = accent * Color(1, 1, 1, 0.7)
	btn.add_theme_stylebox_override("hover", sbh)
	var sbp = sb.duplicate()
	sbp.bg_color = Color(0.22, 0.22, 0.28, 0.95)
	sbp.border_color = accent
	btn.add_theme_stylebox_override("pressed", sbp)
	btn.add_theme_color_override("font_color", accent)
	btn.add_theme_color_override("font_hover_color", accent.lightened(0.2))

func _style_tab_button(btn: Button, tex: Texture2D) -> void:
	if tex:
		var sbt = StyleBoxTexture.new()
		sbt.texture = tex
		sbt.texture_margin_left = 4
		sbt.texture_margin_right = 4
		sbt.texture_margin_top = 4
		sbt.texture_margin_bottom = 4
		sbt.set_content_margin_all(6)
		btn.add_theme_stylebox_override("normal", sbt)
		var sbh = sbt.duplicate()
		sbh.modulate_color = Color(1.2, 1.2, 1.2)
		btn.add_theme_stylebox_override("hover", sbh)
		var sbp = sbt.duplicate()
		sbp.modulate_color = Color(0.85, 0.85, 0.85)
		btn.add_theme_stylebox_override("pressed", sbp)
	else:
		_style_button_flat(btn)

func _style_button_with_texture(btn: Button, tex: Texture2D, font_color: Color) -> void:
	if tex:
		var sbt = StyleBoxTexture.new()
		sbt.texture = tex
		sbt.texture_margin_left = 6
		sbt.texture_margin_right = 6
		sbt.texture_margin_top = 4
		sbt.texture_margin_bottom = 4
		sbt.set_content_margin_all(6)
		btn.add_theme_stylebox_override("normal", sbt)
		var sbh = sbt.duplicate()
		sbh.modulate_color = Color(1.15, 1.15, 1.15)
		btn.add_theme_stylebox_override("hover", sbh)
		var sbp = sbt.duplicate()
		sbp.modulate_color = Color(0.8, 0.8, 0.8)
		btn.add_theme_stylebox_override("pressed", sbp)
		btn.add_theme_color_override("font_color", font_color)
		btn.add_theme_color_override("font_hover_color", font_color.lightened(0.2))
	else:
		_style_button_accent(btn, font_color)
