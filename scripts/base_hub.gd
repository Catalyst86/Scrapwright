extends Control

# ============================================================
# BaseHub — Redesigned upgrade hub with tabbed sidebar,
# radial upgrade categories, and animated dog bust
# ============================================================

const NEW_BG = "res://scrapwright_intro/output/New Menu background.jpg"

# --- Colors (dark charcoal/slate theme, matching reference) ---
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

# --- Runtime state ---
var _tex_cache: Dictionary = {}
var _puppy_sprite: AnimatedSprite2D = null
var _bust_timer: float = 0.0
var _bust_next_anim_time: float = 6.0
var _bust_playing_oneshot: bool = false
var _overlay_panel: Control = null
var _confirm_building: String = ""

var _top_bar: HBoxContainer = null
var _key_container: HBoxContainer = null
var _mat_container: HBoxContainer = null

var _tab_containers: Dictionary = {}
var _tab_buttons: Dictionary = {}
var _current_tab: String = "den_upgrades"
var _detail_panel: Control = null
var _category_nodes: Dictionary = {}

var _content_area: Control = null
var _udb: Node = null  # UpgradeDB autoload reference

# ===================================================================
# LIFECYCLE
# ===================================================================

func _ready() -> void:
	_udb = get_node_or_null("/root/UpgradeDB")
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_background()
	_build_top_bar()
	_build_sidebar_tabs()
	_build_content_area()
	_build_den_upgrades_tab()
	_build_card_collection_tab()
	_build_achievements_tab()
	_build_archive_tab()
	_build_bottom_bar()
	_switch_tab("den_upgrades")
	GameState.materials_changed.connect(_refresh_top_bar)
	GameState.keys_changed.connect(_refresh_top_bar)

func _process(delta: float) -> void:
	# Puppy bust animation cycling
	if _puppy_sprite and is_instance_valid(_puppy_sprite) and not _bust_playing_oneshot:
		_bust_timer += delta
		if _bust_timer >= _bust_next_anim_time:
			_bust_playing_oneshot = true
			var anims = BUST_ONESHOT_ANIMS.duplicate()
			anims.shuffle()
			for anim in anims:
				if _puppy_sprite.sprite_frames.has_animation(anim):
					_puppy_sprite.play(anim)
					break
	# Gentle bob
	if _puppy_sprite and is_instance_valid(_puppy_sprite):
		_puppy_sprite.position.y = 220 + sin(Time.get_ticks_msec() * 0.001 * 1.5) * 1.5

func _exit_tree() -> void:
	if GameState.materials_changed.is_connected(_refresh_top_bar):
		GameState.materials_changed.disconnect(_refresh_top_bar)
	if GameState.keys_changed.is_connected(_refresh_top_bar):
		GameState.keys_changed.disconnect(_refresh_top_bar)

# ===================================================================
# BACKGROUND
# ===================================================================

func _build_background() -> void:
	var bg_tex: Texture2D = null
	if ResourceLoader.exists(NEW_BG):
		bg_tex = load(NEW_BG)
	if bg_tex:
		var bg = TextureRect.new()
		bg.texture = bg_tex
		bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		bg.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg.z_index = -10
		add_child(bg)
	else:
		var bg = ColorRect.new()
		bg.color = Color(0.08, 0.08, 0.10)
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		bg.z_index = -10
		add_child(bg)
	# Subtle darken for readability (minimal)
	var darken = ColorRect.new()
	darken.color = Color(0.0, 0.0, 0.0, 0.15)
	darken.set_anchors_preset(Control.PRESET_FULL_RECT)
	darken.z_index = -9
	darken.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(darken)

# ===================================================================
# TOP BAR (materials + keys + save)
# ===================================================================

func _build_top_bar() -> void:
	var bar_bg = ColorRect.new()
	bar_bg.color = Color(0.08, 0.08, 0.10, 0.80)
	bar_bg.position = Vector2.ZERO
	bar_bg.size = Vector2(960, 30)
	bar_bg.z_index = 50
	bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bar_bg)

	_top_bar = HBoxContainer.new()
	_top_bar.position = Vector2(8, 2)
	_top_bar.size = Vector2(944, 26)
	_top_bar.z_index = 51
	_top_bar.add_theme_constant_override("separation", 6)
	_top_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(_top_bar)

	# Key display
	_key_container = HBoxContainer.new()
	_key_container.add_theme_constant_override("separation", 3)
	_top_bar.add_child(_key_container)

	var sep1 = VSeparator.new()
	sep1.add_theme_constant_override("separation", 8)
	_top_bar.add_child(sep1)

	# Material display
	_mat_container = HBoxContainer.new()
	_mat_container.add_theme_constant_override("separation", 3)
	_mat_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_top_bar.add_child(_mat_container)

	# Save button
	var save_btn = Button.new()
	save_btn.text = "SAVE"
	save_btn.add_theme_font_size_override("font_size", 11)
	save_btn.add_theme_color_override("font_color", CLR_GREEN)
	_style_button_flat(save_btn)
	save_btn.pressed.connect(func():
		SaveManager.save_game()
		save_btn.text = "SAVED!"
		var tw = save_btn.create_tween()
		tw.tween_interval(1.0)
		tw.tween_callback(func(): save_btn.text = "SAVE")
	)
	_top_bar.add_child(save_btn)

	_refresh_top_bar()

func _refresh_top_bar() -> void:
	if not _key_container or not _mat_container:
		return

	# Keys
	for c in _key_container.get_children():
		c.queue_free()
	for tier in ["bronze", "silver", "gold", "secret"]:
		var count = GameState.keys.get(tier, 0)
		var kc = KEY_COLORS.get(tier, CLR_DIM)
		var icon = _load_tex("key_%s.png" % tier)

		var kh = HBoxContainer.new()
		kh.add_theme_constant_override("separation", 2)
		if icon:
			var tr = TextureRect.new()
			tr.texture = icon
			tr.custom_minimum_size = Vector2(16, 16)
			tr.size = Vector2(16, 16)
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			kh.add_child(tr)
		else:
			var dot = ColorRect.new()
			dot.color = kc
			dot.custom_minimum_size = Vector2(8, 8)
			kh.add_child(dot)
		var kl = Label.new()
		kl.text = str(count)
		kl.add_theme_font_size_override("font_size", 11)
		kl.add_theme_color_override("font_color", kc if count > 0 else CLR_DIM)
		kh.add_child(kl)
		_key_container.add_child(kh)

	# Materials
	for c in _mat_container.get_children():
		c.queue_free()
	for mat in ["iron_scrap", "timber", "fuel", "organic", "stone", "blueprint"]:
		var count = GameState.materials.get(mat, 0)
		var mc = MAT_COLORS.get(mat, CLR_DIM)
		var icon = _load_tex(MAT_ICONS.get(mat, ""))

		var mh = HBoxContainer.new()
		mh.add_theme_constant_override("separation", 2)
		if icon:
			var tr = TextureRect.new()
			tr.texture = icon
			tr.custom_minimum_size = Vector2(16, 16)
			tr.size = Vector2(16, 16)
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			mh.add_child(tr)
		else:
			var dot = ColorRect.new()
			dot.color = mc
			dot.custom_minimum_size = Vector2(8, 8)
			mh.add_child(dot)
		var abbrev = mat.replace("iron_scrap", "iron").replace("blueprint", "bluep").replace("organic", "organ")
		var ml = Label.new()
		ml.text = "%s %d" % [abbrev, count]
		ml.add_theme_font_size_override("font_size", 10)
		ml.add_theme_color_override("font_color", mc)
		mh.add_child(ml)
		_mat_container.add_child(mh)

# ===================================================================
# LEFT SIDEBAR TABS
# ===================================================================

const TAB_DEFS = [
	{"id": "den_upgrades", "label": "DEN\nUPGRADES", "color": Color(0.95, 0.82, 0.35)},
	{"id": "card_collection", "label": "CARD\nCOLLECTION", "color": Color(0.95, 0.55, 0.15)},
	{"id": "achievements", "label": "ACHIEVE-\nMENTS", "color": Color(0.72, 0.35, 0.90)},
	{"id": "archive", "label": "ARCHIVE", "color": Color(0.75, 0.75, 0.80)},
]

func _build_sidebar_tabs() -> void:
	# Sidebar background texture
	var sidebar_tex = _load_tex("res://assets/sprites/hub_ui/sidebar_frame.png")
	if sidebar_tex:
		var sidebar_bg = TextureRect.new()
		sidebar_bg.texture = sidebar_tex
		sidebar_bg.position = Vector2(0, 30)
		sidebar_bg.size = Vector2(130, 470)
		sidebar_bg.stretch_mode = TextureRect.STRETCH_SCALE
		sidebar_bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sidebar_bg.z_index = 39
		sidebar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(sidebar_bg)

	var sidebar = PanelContainer.new()
	sidebar.position = Vector2(0, 30)
	sidebar.size = Vector2(130, 470)
	sidebar.z_index = 40

	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)  # Transparent — texture provides the look
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 30  # Clear the hazard stripe
	sb.content_margin_bottom = 10
	sidebar.add_theme_stylebox_override("panel", sb)
	add_child(sidebar)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	vbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	sidebar.add_child(vbox)

	var btn_normal_tex = _load_tex("res://assets/sprites/hub_ui/tab_button_normal.png")
	var btn_active_tex = _load_tex("res://assets/sprites/hub_ui/tab_button_active.png")

	for tab_def in TAB_DEFS:
		var btn = Button.new()
		btn.text = tab_def.label
		btn.custom_minimum_size = Vector2(110, 80)
		btn.add_theme_font_size_override("font_size", 11)
		btn.clip_text = false
		var tab_id = tab_def.id
		btn.pressed.connect(func(): _switch_tab(tab_id))
		_style_tab_button(btn, btn_normal_tex)
		vbox.add_child(btn)
		_tab_buttons[tab_def.id] = btn

func _switch_tab(tab_id: String) -> void:
	_current_tab = tab_id
	# Close detail panel if open
	if _detail_panel and is_instance_valid(_detail_panel):
		_detail_panel.queue_free()
		_detail_panel = null
	# Show/hide tab content
	for tid in _tab_containers:
		if _tab_containers[tid] and is_instance_valid(_tab_containers[tid]):
			_tab_containers[tid].visible = (tid == tab_id)
	# Update button styles
	var btn_normal_tex = _load_tex("res://assets/sprites/hub_ui/tab_button_normal.png")
	var btn_active_tex = _load_tex("res://assets/sprites/hub_ui/tab_button_active.png")
	for tid in _tab_buttons:
		var btn: Button = _tab_buttons[tid]
		var tab_def = null
		for td in TAB_DEFS:
			if td.id == tid:
				tab_def = td
				break
		if tid == tab_id:
			btn.add_theme_color_override("font_color", tab_def.color if tab_def else CLR_GOLD)
			_style_tab_button(btn, btn_active_tex)
		else:
			btn.add_theme_color_override("font_color", CLR_DIM)
			_style_tab_button(btn, btn_normal_tex)

# ===================================================================
# CONTENT AREA (right of sidebar, below top bar, above bottom bar)
# ===================================================================

func _build_content_area() -> void:
	_content_area = Control.new()
	_content_area.position = Vector2(130, 30)
	_content_area.size = Vector2(830, 470)
	_content_area.z_index = 30
	add_child(_content_area)

# ===================================================================
# DEN UPGRADES TAB — Radial layout with dog bust in center
# ===================================================================

func _build_den_upgrades_tab() -> void:
	var tab = Control.new()
	tab.set_anchors_preset(Control.PRESET_FULL_RECT)
	_content_area.add_child(tab)
	_tab_containers["den_upgrades"] = tab

	# Dog bust in center of content area
	_build_puppy(tab)

	# Radial category nodes — shifted left to leave room for detail panel
	var center = Vector2(310, 220)
	var radius = 155.0

	for cat_id in _udb.CATEGORIES:
		var cat = _udb.CATEGORIES[cat_id]
		var angle_deg = cat.angle
		var angle_rad = deg_to_rad(angle_deg)
		var pos = center + Vector2(cos(angle_rad), sin(angle_rad)) * radius
		var node = _create_category_node(cat_id, pos)
		tab.add_child(node)
		_category_nodes[cat_id] = node

const CAT_ANIM_SHEETS = {
	"combat_paws": "res://assets/sprites/hub_icons/combat_paws_anim_sheet.png",
	"survival_den": "res://assets/sprites/hub_icons/survival_den_anim_sheet.png",
	"scavenge_snout": "res://assets/sprites/hub_icons/scavenge_snout_anim_sheet.png",
	"companion_legacy": "res://assets/sprites/hub_icons/companion_legacy_anim_sheet.png",
	"mutation": "res://assets/sprites/hub_icons/mutation_anim_sheet.png",
}

func _create_category_node(cat_id: String, pos: Vector2) -> PanelContainer:
	var cat = _udb.CATEGORIES[cat_id]
	var accent = _udb.CAT_COLORS.get(cat_id, CLR_GOLD)
	var progress = _udb.get_category_progress(cat_id)
	var max_progress = _udb.get_category_max(cat_id)
	var is_max = _udb.is_category_maxed(cat_id)
	var can_buy = _udb.can_afford_any_in_category(cat_id)

	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(78, 76)
	panel.position = pos - Vector2(39, 38)
	panel.pivot_offset = Vector2(39, 38)  # Scale from center

	# Style
	var sb_style = StyleBoxFlat.new()
	sb_style.bg_color = Color(0.08, 0.08, 0.10, 0.85)
	if is_max:
		sb_style.border_color = CLR_GREEN
	elif can_buy:
		sb_style.border_color = CLR_ORANGE
	else:
		sb_style.border_color = Color(0.30, 0.32, 0.35, 0.5)
	sb_style.set_border_width_all(2)
	sb_style.set_corner_radius_all(5)
	sb_style.set_content_margin_all(6)
	panel.add_theme_stylebox_override("panel", sb_style)

	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 2)
	panel.add_child(vbox)

	# Icon — use static TextureRect (small, centered in VBox)
	# Animation plays on hover via the panel scale tween
	var anim_sheet_path = CAT_ANIM_SHEETS.get(cat_id, "")
	var has_anim = ResourceLoader.exists(anim_sheet_path)
	var anim_sprite: AnimatedSprite2D = null
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
			anim_sprite.scale = Vector2(0.45, 0.45)  # 64*0.45 = ~29px, fits in panel
			anim_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			anim_sprite.play("idle")
			# Wrap in a container so VBox can center it
			var icon_wrap = Control.new()
			icon_wrap.custom_minimum_size = Vector2(30, 30)
			icon_wrap.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			anim_sprite.position = Vector2(-1, -1)  # Slight nudge for centering
			icon_wrap.add_child(anim_sprite)
			vbox.add_child(icon_wrap)

	if not anim_sprite and icon_tex:
		var icon = TextureRect.new()
		icon.texture = icon_tex
		icon.custom_minimum_size = Vector2(30, 30)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		vbox.add_child(icon)

	# Name
	var name_lbl = Label.new()
	name_lbl.text = cat.name
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 10)
	name_lbl.add_theme_color_override("font_color", accent)
	vbox.add_child(name_lbl)

	# Progress
	var prog_lbl = Label.new()
	if is_max:
		prog_lbl.text = "MAX"
		prog_lbl.add_theme_color_override("font_color", CLR_GREEN)
	else:
		prog_lbl.text = "%d / %d" % [progress, max_progress]
		prog_lbl.add_theme_color_override("font_color", CLR_DIM)
	prog_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prog_lbl.add_theme_font_size_override("font_size", 9)
	vbox.add_child(prog_lbl)

	# Hover: slight scale pop + play animation
	var p = panel
	var asp = anim_sprite
	panel.mouse_entered.connect(func():
		var tw = p.create_tween()
		tw.tween_property(p, "scale", Vector2(1.08, 1.08), 0.1).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		if asp and is_instance_valid(asp):
			asp.play("hover")
	)
	panel.mouse_exited.connect(func():
		var tw = p.create_tween()
		tw.tween_property(p, "scale", Vector2(1.0, 1.0), 0.08).set_ease(Tween.EASE_IN)
		if asp and is_instance_valid(asp):
			asp.play("idle")
	)

	# Click handler
	panel.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_show_detail_panel(cat_id)
	)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP

	return panel

func _refresh_category_nodes() -> void:
	for cat_id in _category_nodes:
		var old_node = _category_nodes[cat_id]
		if not is_instance_valid(old_node):
			continue
		var parent = old_node.get_parent()
		var pos = old_node.position + old_node.custom_minimum_size / 2.0
		old_node.queue_free()
		var new_node = _create_category_node(cat_id, pos)
		parent.add_child(new_node)
		_category_nodes[cat_id] = new_node

# ===================================================================
# DETAIL PANEL — Shows individual upgrades for a category
# ===================================================================

func _show_detail_panel(cat_id: String) -> void:
	# Remove existing detail panel
	if _detail_panel and is_instance_valid(_detail_panel):
		_detail_panel.queue_free()
		_detail_panel = null

	var cat = _udb.CATEGORIES[cat_id]
	var accent = _udb.CAT_COLORS.get(cat_id, CLR_GOLD)

	var panel = PanelContainer.new()
	panel.position = Vector2(570, 0)
	panel.size = Vector2(260, 470)
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.06, 0.08, 0.92)
	sb.border_color = accent * Color(1, 1, 1, 0.4)
	sb.border_width_left = 2
	sb.border_width_right = 1
	sb.border_width_top = 1
	sb.border_width_bottom = 1
	sb.set_corner_radius_all(3)
	sb.set_content_margin_all(14)
	panel.add_theme_stylebox_override("panel", sb)
	_content_area.add_child(panel)
	_detail_panel = panel

	var scroll = ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)

	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 8)
	scroll.add_child(vbox)

	# Header
	var header = Label.new()
	header.text = cat.name
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", 16)
	header.add_theme_color_override("font_color", accent)
	vbox.add_child(header)

	var desc_lbl = Label.new()
	desc_lbl.text = cat.desc
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.add_theme_font_size_override("font_size", 10)
	desc_lbl.add_theme_color_override("font_color", CLR_DIM)
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(desc_lbl)

	var sep = HSeparator.new()
	vbox.add_child(sep)

	# Individual upgrades
	for upgrade_id in cat.upgrades:
		var upgrade_card = _create_upgrade_card(upgrade_id, accent, cat_id)
		vbox.add_child(upgrade_card)

	# Close button
	var close_btn = Button.new()
	close_btn.text = "Close"
	close_btn.add_theme_font_size_override("font_size", 11)
	close_btn.add_theme_color_override("font_color", CLR_DIM)
	_style_button_flat(close_btn)
	close_btn.pressed.connect(func():
		if _detail_panel and is_instance_valid(_detail_panel):
			_detail_panel.queue_free()
			_detail_panel = null
	)
	vbox.add_child(close_btn)

	# Fade in
	panel.modulate.a = 0.0
	var tw = panel.create_tween()
	tw.tween_property(panel, "modulate:a", 1.0, 0.15)

func _create_upgrade_card(upgrade_id: String, accent: Color, cat_id: String) -> PanelContainer:
	var upg = _udb.UPGRADES[upgrade_id]
	var level = _udb.get_upgrade_level(upgrade_id)
	var max_lvl = _udb.get_max_level(upgrade_id)
	var is_max = _udb.is_maxed(upgrade_id)
	var can_buy = _udb.can_afford_upgrade(upgrade_id)

	var card = PanelContainer.new()
	var csb = StyleBoxFlat.new()
	csb.bg_color = Color(0.08, 0.08, 0.10, 0.85)
	csb.border_color = accent * Color(1, 1, 1, 0.25)
	csb.set_border_width_all(1)
	csb.set_corner_radius_all(3)
	csb.set_content_margin_all(8)
	card.add_theme_stylebox_override("panel", csb)

	var cv = VBoxContainer.new()
	cv.add_theme_constant_override("separation", 4)
	card.add_child(cv)

	# Name + level row
	var name_row = HBoxContainer.new()
	cv.add_child(name_row)

	var icon = _load_tex(upg.icon)
	if icon:
		var ir = TextureRect.new()
		ir.texture = icon
		ir.custom_minimum_size = Vector2(24, 24)
		ir.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ir.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		name_row.add_child(ir)

	var nlbl = Label.new()
	nlbl.text = upg.name
	nlbl.add_theme_font_size_override("font_size", 12)
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
	lvl_lbl.add_theme_font_size_override("font_size", 10)
	name_row.add_child(lvl_lbl)

	# Description
	var dlbl = Label.new()
	dlbl.text = upg.desc
	dlbl.add_theme_font_size_override("font_size", 10)
	dlbl.add_theme_color_override("font_color", CLR_SILVER)
	dlbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	cv.add_child(dlbl)

	# Current effect
	var effect_text = _udb.get_effect_text(upgrade_id)
	if effect_text != "":
		var elbl = Label.new()
		elbl.text = "Current: " + effect_text
		elbl.add_theme_font_size_override("font_size", 9)
		elbl.add_theme_color_override("font_color", CLR_GREEN if level > 0 else CLR_DIM)
		cv.add_child(elbl)

	# Flavor text
	var flbl = Label.new()
	flbl.text = upg.flavor
	flbl.add_theme_font_size_override("font_size", 9)
	flbl.add_theme_color_override("font_color", Color(0.5, 0.45, 0.35))
	flbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	cv.add_child(flbl)

	if not is_max:
		# Cost breakdown
		var cost = _udb.get_next_cost(upgrade_id)
		var cost_row = HBoxContainer.new()
		cost_row.add_theme_constant_override("separation", 6)
		cv.add_child(cost_row)

		var cost_label = Label.new()
		cost_label.text = "Cost: "
		cost_label.add_theme_font_size_override("font_size", 9)
		cost_label.add_theme_color_override("font_color", CLR_DIM)
		cost_row.add_child(cost_label)

		for mat in cost:
			var have = GameState.materials.get(mat, 0)
			var need = cost[mat]
			var ml = Label.new()
			var abbrev = mat.replace("iron_scrap", "iron").replace("blueprint", "bp")
			ml.text = "%d %s" % [need, abbrev]
			ml.add_theme_font_size_override("font_size", 9)
			ml.add_theme_color_override("font_color", CLR_GREEN if have >= need else CLR_RED)
			cost_row.add_child(ml)

		# Upgrade button
		var btn = Button.new()
		btn.text = "UPGRADE"
		btn.add_theme_font_size_override("font_size", 12)
		if can_buy:
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
				_show_detail_panel(cid)  # Rebuild to update
		)
		cv.add_child(btn)

	return card

# ===================================================================
# CARD COLLECTION TAB
# ===================================================================

func _build_card_collection_tab() -> void:
	var tab = Control.new()
	tab.set_anchors_preset(Control.PRESET_FULL_RECT)
	tab.visible = false
	_content_area.add_child(tab)
	_tab_containers["card_collection"] = tab

	var card_db = get_node_or_null("/root/CardDB")
	if not card_db:
		var lbl = Label.new()
		lbl.text = "Card system not available"
		lbl.add_theme_color_override("font_color", CLR_DIM)
		tab.add_child(lbl)
		return

	var scroll = ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tab.add_child(scroll)

	var main_vbox = VBoxContainer.new()
	main_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vbox.add_theme_constant_override("separation", 12)
	scroll.add_child(main_vbox)

	# Title + progress
	var progress = card_db.get_total_progress()
	var title = Label.new()
	title.text = "CARD COLLECTION  (%d / %d)" % [progress.owned, progress.total]
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", CLR_GOLD)
	main_vbox.add_child(title)

	# Group cards by deck name
	var deck_names = ["Scrap", "Lost", "Critter", "Overgrowth"]

	for deck_name in deck_names:
		var dp = card_db.get_deck_progress(deck_name)
		var is_complete = card_db.is_deck_complete(deck_name)

		# Get cards for this deck
		var deck_cards: Array = []
		var deck_color = CLR_SILVER
		for c in card_db.cards:
			if c.deck == deck_name:
				deck_cards.append(c)
				deck_color = c.get("deck_color", CLR_SILVER)

		# Deck header
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

		# Card grid for this deck
		var grid = GridContainer.new()
		grid.columns = 5
		grid.add_theme_constant_override("h_separation", 6)
		grid.add_theme_constant_override("v_separation", 6)
		main_vbox.add_child(grid)

		for card_def in deck_cards:
			var card_id = card_def.id
			var owned = card_db.collected.has(card_id)
			var card_panel = PanelContainer.new()
			card_panel.custom_minimum_size = Vector2(120, 50)

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

		var sep = HSeparator.new()
		main_vbox.add_child(sep)

# ===================================================================
# ACHIEVEMENTS TAB
# ===================================================================

func _build_achievements_tab() -> void:
	var tab = Control.new()
	tab.set_anchors_preset(Control.PRESET_FULL_RECT)
	tab.visible = false
	_content_area.add_child(tab)
	_tab_containers["achievements"] = tab

	var scroll = ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tab.add_child(scroll)

	var main_vbox = VBoxContainer.new()
	main_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vbox.add_theme_constant_override("separation", 12)
	scroll.add_child(main_vbox)

	# Title
	var title = Label.new()
	title.text = "ACHIEVEMENTS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(0.95, 0.82, 0.35))
	main_vbox.add_child(title)

	# Progress summary
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

	# Progress bar
	var bar_bg = ColorRect.new()
	bar_bg.custom_minimum_size = Vector2(0, 8)
	bar_bg.color = Color(0.15, 0.15, 0.18)
	main_vbox.add_child(bar_bg)
	if total > 0:
		var bar_fill = ColorRect.new()
		bar_fill.color = Color(0.95, 0.82, 0.35)
		bar_fill.custom_minimum_size = Vector2(0, 8)
		bar_fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		# We'll approximate fill via a container
		var bar_container = HBoxContainer.new()
		bar_container.custom_minimum_size = Vector2(0, 8)
		main_vbox.add_child(bar_container)
		var fill = ColorRect.new()
		fill.color = Color(0.95, 0.82, 0.35)
		fill.custom_minimum_size = Vector2(max(4, 700.0 * done / total), 8)
		fill.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		bar_container.add_child(fill)

	# Categories
	for cat in Achievements.CATEGORIES:
		var cat_ids: Array = []
		for id in Achievements.ACHIEVEMENTS:
			if Achievements.ACHIEVEMENTS[id].get("category", "") == cat:
				cat_ids.append(id)
		if cat_ids.is_empty():
			continue

		# Category header
		var cat_lbl = Label.new()
		cat_lbl.text = cat.to_upper()
		cat_lbl.add_theme_font_size_override("font_size", 14)
		cat_lbl.add_theme_color_override("font_color", CLR_GOLD)
		main_vbox.add_child(cat_lbl)

		# Achievement rows
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

	# Icon/status indicator
	var icon_rect = ColorRect.new()
	icon_rect.custom_minimum_size = Vector2(28, 28)
	icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if unlocked:
		icon_rect.color = ach.get("icon_color", CLR_GOLD)
	else:
		icon_rect.color = Color(0.2, 0.2, 0.22)
	hb.add_child(icon_rect)

	# Checkmark or lock symbol
	var check_lbl = Label.new()
	check_lbl.text = "OK" if unlocked else "?"
	check_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	check_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	check_lbl.add_theme_font_size_override("font_size", 10)
	check_lbl.add_theme_color_override("font_color", Color(0.0, 0.0, 0.0) if unlocked else CLR_DIM)
	check_lbl.position = Vector2(5, 5)
	icon_rect.add_child(check_lbl)

	# Text info
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

	# Progress for stat-based achievements
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
# ARCHIVE TAB (stub)
# ===================================================================

func _build_archive_tab() -> void:
	var tab = Control.new()
	tab.set_anchors_preset(Control.PRESET_FULL_RECT)
	tab.visible = false
	_content_area.add_child(tab)
	_tab_containers["archive"] = tab

	var lbl = Label.new()
	lbl.text = "ARCHIVE\n\nComing Soon..."
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.set_anchors_preset(Control.PRESET_CENTER)
	lbl.position = Vector2(-100, -30)
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", CLR_DIM)
	tab.add_child(lbl)

# ===================================================================
# BOTTOM BAR
# ===================================================================

func _build_bottom_bar() -> void:
	# Bottom bar texture background
	var bar_tex = _load_tex("res://assets/sprites/hub_ui/bottom_bar_frame.png")
	if bar_tex:
		var bar_bg = TextureRect.new()
		bar_bg.texture = bar_tex
		bar_bg.position = Vector2(0, 500)
		bar_bg.size = Vector2(960, 40)
		bar_bg.stretch_mode = TextureRect.STRETCH_SCALE
		bar_bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		bar_bg.z_index = 49
		bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(bar_bg)
	else:
		var bar = ColorRect.new()
		bar.color = Color(0.08, 0.08, 0.10, 0.80)
		bar.position = Vector2(0, 500)
		bar.size = Vector2(960, 40)
		bar.z_index = 49
		add_child(bar)

	# Commit to next run button with upgrade_button texture
	var run_btn = Button.new()
	run_btn.text = "ENTER DUNGEON"
	run_btn.position = Vector2(380, 504)
	run_btn.size = Vector2(200, 32)
	run_btn.z_index = 51
	run_btn.add_theme_font_size_override("font_size", 14)
	var run_tex = _load_tex("res://assets/sprites/hub_ui/wardrobe_button.png")
	if run_tex:
		_style_button_with_texture(run_btn, run_tex, CLR_ORANGE)
	else:
		_style_button_accent(run_btn, CLR_ORANGE)
	run_btn.pressed.connect(_start_run)
	add_child(run_btn)

	# Junkyard button
	var junk_btn = Button.new()
	junk_btn.text = "JUNKYARD"
	junk_btn.position = Vector2(140, 504)
	junk_btn.size = Vector2(120, 32)
	junk_btn.z_index = 51
	junk_btn.add_theme_font_size_override("font_size", 11)
	var junk_tex = _load_tex("res://assets/sprites/hub_ui/wardrobe_button.png")
	if junk_tex:
		_style_button_with_texture(junk_btn, junk_tex, Color(0.85, 0.65, 0.30))
	else:
		_style_button_accent(junk_btn, Color(0.75, 0.55, 0.25))
	junk_btn.pressed.connect(_enter_junkyard)
	add_child(junk_btn)

	# Wardrobe button
	var ward_btn = Button.new()
	ward_btn.text = "WARDROBE"
	ward_btn.position = Vector2(770, 504)
	ward_btn.size = Vector2(120, 32)
	ward_btn.z_index = 51
	ward_btn.add_theme_font_size_override("font_size", 11)
	var ward_tex = _load_tex("res://assets/sprites/hub_ui/wardrobe_button.png")
	if ward_tex:
		_style_button_with_texture(ward_btn, ward_tex, CLR_SILVER)
	else:
		_style_button_accent(ward_btn, CLR_SILVER)
	ward_btn.pressed.connect(_open_armor_popup)
	add_child(ward_btn)

# ===================================================================
# PUPPY BUST (animated character in center)
# ===================================================================

func _build_puppy(parent: Control) -> void:
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

	# Orbital frame behind the bust
	var orbital_tex = _load_tex("res://assets/sprites/hub_ui/bust_orbital_frame.png")
	if orbital_tex:
		var orbital = TextureRect.new()
		orbital.texture = orbital_tex
		orbital.custom_minimum_size = Vector2(200, 200)
		orbital.size = Vector2(200, 200)
		orbital.position = Vector2(310 - 100, 220 - 100)
		orbital.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		orbital.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		orbital.z_index = 11
		orbital.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(orbital)

	_puppy_sprite = AnimatedSprite2D.new()
	_puppy_sprite.sprite_frames = frames
	_puppy_sprite.position = Vector2(310, 220)  # Center of content area
	_puppy_sprite.scale = Vector2(1.5, 1.5)  # Nice and big, head pokes out the top
	_puppy_sprite.z_index = 12
	_puppy_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# Clip mask — head pokes out top, bottom/sides clipped at ring inner edge
	var clip_shader = Shader.new()
	clip_shader.code = "shader_type canvas_item;\nvoid fragment() {\n  vec2 uv = UV - vec2(0.5);\n  if (uv.y > -0.08) {\n    float r = 0.32 - max(uv.y, 0.0) * 0.3;\n    float d = length(uv);\n    COLOR.a *= 1.0 - smoothstep(r - 0.01, r, d);\n  }\n}\n"
	var mat = ShaderMaterial.new()
	mat.shader = clip_shader
	_puppy_sprite.material = mat
	parent.add_child(_puppy_sprite)

	_puppy_sprite.animation_finished.connect(_on_bust_animation_finished)
	_puppy_sprite.play("idle_breathing")
	_bust_next_anim_time = randf_range(4.0, 8.0)

	# Fade in
	_puppy_sprite.modulate.a = 0.0
	var tw = _puppy_sprite.create_tween()
	tw.tween_property(_puppy_sprite, "modulate:a", 1.0, 0.5).set_delay(0.3)

const BUST_ONESHOT_ANIMS: Array[String] = [
	"snap_fly", "head_shake", "head_tilt", "look_left",
	"look_right_to_center", "happy_panting", "sleepy",
	"idle_steady", "idle_sitting",
]

func _on_bust_animation_finished() -> void:
	if _bust_playing_oneshot:
		_bust_playing_oneshot = false
		_bust_timer = 0.0
		_bust_next_anim_time = randf_range(4.0, 8.0)
		if _puppy_sprite and is_instance_valid(_puppy_sprite):
			_puppy_sprite.play("idle_breathing")

# ===================================================================
# ARMOR POPUP (preserved from original)
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

	# Puppy preview sprite
	var preview_container = Control.new()
	preview_container.custom_minimum_size = Vector2(60, 80)
	hb.add_child(preview_container)

	if is_unlocked:
		# Use armor_icons pup images (cute puppy wearing the armor)
		var icon_path = "res://assets/sprites/armor_icons/%s.png" % armor.id
		if not ResourceLoader.exists(icon_path):
			# Fallback to player sprite idle frame
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

	# Info side
	var vb = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 3)
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(vb)

	var name_lbl = Label.new()
	name_lbl.text = armor.get("name", armor.id) if is_unlocked else "???"
	name_lbl.add_theme_font_size_override("font_size", 12)
	name_lbl.add_theme_color_override("font_color", rarity_color if is_unlocked else CLR_DIM)
	vb.add_child(name_lbl)

	# Rarity label
	var rar_lbl = Label.new()
	rar_lbl.text = armor.get("rarity", "common").to_upper()
	rar_lbl.add_theme_font_size_override("font_size", 8)
	rar_lbl.add_theme_color_override("font_color", rarity_color * Color(1, 1, 1, 0.6))
	vb.add_child(rar_lbl)

	if is_unlocked:
		# Stats summary
		if armor.get("stats", {}).size() > 0:
			var stats_text = armor_db.get_stats_summary(armor) if armor_db.has_method("get_stats_summary") else ""
			if stats_text != "":
				var stats_lbl = Label.new()
				stats_lbl.text = stats_text
				stats_lbl.add_theme_font_size_override("font_size", 9)
				stats_lbl.add_theme_color_override("font_color", CLR_SILVER)
				stats_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
				vb.add_child(stats_lbl)

		# Badges
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

		# Equip buttons
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

func _get_rarity_color(rarity: String) -> Color:
	match rarity:
		"common": return Color(0.6, 0.6, 0.6)
		"uncommon": return CLR_GREEN
		"rare": return Color(0.35, 0.55, 1.0)
		"legendary": return CLR_GOLD
	return CLR_DIM

# ===================================================================
# OVERLAY POPUP SYSTEM (preserved)
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
# START RUN (preserved)
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

	var door_center = Vector2(480, 270)

	var darkness = ColorRect.new()
	darkness.color = Color(0.0, 0.0, 0.0, 0.0)
	darkness.set_anchors_preset(Control.PRESET_FULL_RECT)
	darkness.z_index = 100
	darkness.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(darkness)

	var tw = create_tween()
	tw.tween_property(darkness, "color:a", 0.5, 0.3).set_ease(Tween.EASE_IN)
	tw.set_parallel(true)
	tw.tween_property(self, "scale", Vector2(3.0, 3.0), 0.6).set_ease(Tween.EASE_IN)
	tw.tween_property(self, "pivot_offset", door_center, 0.0)
	tw.tween_property(darkness, "color:a", 1.0, 0.6).set_ease(Tween.EASE_IN)
	tw.set_parallel(false)
	tw.tween_interval(0.15)
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
