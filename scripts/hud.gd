extends CanvasLayer

# ============================================================
# HUD — Sprite-based steampunk UI (PixelLab-generated assets)
# ============================================================

# ─── Color palette ───────────────────────────────────────────
const CLR_HP_FULL     = Color(0.18, 0.75, 0.28)
const CLR_HP_MID      = Color(0.85, 0.72, 0.15)
const CLR_HP_LOW      = Color(0.88, 0.18, 0.18)
const CLR_XP          = Color(0.35, 0.60, 0.90)
const CLR_GOLD_TEXT   = Color(0.95, 0.82, 0.35)
const CLR_SILVER_TEXT = Color(0.78, 0.78, 0.82)
const CLR_DIM_TEXT    = Color(0.55, 0.55, 0.55)

# ─── Sprite paths ────────────────────────────────────────────
const UI = "res://assets/sprites/ui/"

# Stage banner images — keyed by stage name from StageData
const STAGE_BANNERS = {
	"The Junkyard": "res://assets/sprites/ui/The junkyard.jpg",
	"The Scrapyard": "res://assets/sprites/ui/The scrapyard image.jpg",
	"Fungal Depths": "res://assets/sprites/ui/Fungal Depths.jpg",
	"Molten Core": "res://assets/sprites/ui/Molten core.jpg",
	"Frozen Caverns": "res://assets/sprites/ui/Frozen Cavern.jpg",
	"Clockwork Factory": "res://assets/sprites/ui/Clockwork factory.jpg",
	"The Abyss": "res://assets/sprites/ui/The Abyss.jpg",
}

# ─── References (built in _ready) ───────────────────────────
var hp_bar_fill: ColorRect
var hp_bar_bg: NinePatchRect
var hp_label: Label
var hp_icon_tex: TextureRect
var xp_bar_fill: ColorRect
var xp_bar_bg: ColorRect
var level_label: Label
var wave_label: Label
var stage_name_label: Label
var stage_banner_tex: TextureRect = null
var wave_panel: NinePatchRect
var phase_banner: Label
var banner_shadow: Label
var prep_timer_label: Label
var material_float_container: Control

var _banner_tween: Tween = null
var _hp_current: int = 100
var _hp_max: int = 100

const HP_BAR_W = 200.0
const HP_BAR_H = 22.0
const XP_BAR_W = 200.0
const XP_BAR_H = 10.0

func _ready() -> void:
	layer = 5
	_build_hud()

# ─── Helpers ─────────────────────────────────────────────────

func _load_tex(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path)
	return null

func _make_9patch(tex_path: String, pos: Vector2, sz: Vector2, margin: int = 8) -> NinePatchRect:
	var np = NinePatchRect.new()
	var tex = _load_tex(tex_path)
	if tex:
		np.texture = tex
	np.position = pos
	np.size = sz
	np.patch_margin_left = margin
	np.patch_margin_right = margin
	np.patch_margin_top = margin
	np.patch_margin_bottom = margin
	np.axis_stretch_horizontal = NinePatchRect.AXIS_STRETCH_MODE_TILE
	np.axis_stretch_vertical = NinePatchRect.AXIS_STRETCH_MODE_TILE
	return np

func _make_icon(tex_path: String, sz: Vector2) -> TextureRect:
	var icon_rect = TextureRect.new()
	var tex = _load_tex(tex_path)
	if tex:
		icon_rect.texture = tex
	icon_rect.custom_minimum_size = sz
	icon_rect.size = sz
	icon_rect.expand_mode = 1  # EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = 4  # STRETCH_KEEP_ASPECT_CENTERED
	return icon_rect

# ─── Build entire HUD in code ───────────────────────────────

func _build_hud() -> void:
	# === TOP-LEFT: Health + XP cluster ===
	var hp_cluster = Control.new()
	hp_cluster.set_anchors_preset(Control.PRESET_TOP_LEFT)
	hp_cluster.position = Vector2(12, 8)
	add_child(hp_cluster)

	# Heart icon (sprite)
	hp_icon_tex = _make_icon(UI + "icon_heart.png", Vector2(22, 22))
	hp_icon_tex.position = Vector2(0, 0)
	hp_cluster.add_child(hp_icon_tex)

	# HP bar frame (NinePatch from generated sprite)
	hp_bar_bg = _make_9patch(UI + "bar_frame_hp.png", Vector2(24, 0), Vector2(HP_BAR_W + 4, HP_BAR_H + 4), 6)
	hp_cluster.add_child(hp_bar_bg)

	# HP bar fill
	hp_bar_fill = ColorRect.new()
	hp_bar_fill.color = CLR_HP_FULL
	hp_bar_fill.position = Vector2(28, 4)
	hp_bar_fill.size = Vector2(HP_BAR_W - 4, HP_BAR_H - 4)
	hp_cluster.add_child(hp_bar_fill)

	# HP text overlay
	hp_label = Label.new()
	hp_label.text = "100 / 100"
	hp_label.add_theme_font_size_override("font_size", 14)
	hp_label.add_theme_color_override("font_color", Color.WHITE)
	hp_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	hp_label.add_theme_constant_override("shadow_offset_x", 1)
	hp_label.add_theme_constant_override("shadow_offset_y", 1)
	hp_label.position = Vector2(28, 1)
	hp_label.size = Vector2(HP_BAR_W - 4, HP_BAR_H + 2)
	hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hp_cluster.add_child(hp_label)

	# XP bar background
	xp_bar_bg = ColorRect.new()
	xp_bar_bg.color = Color(0.0, 0.0, 0.0, 0.5)
	xp_bar_bg.position = Vector2(24, HP_BAR_H + 8)
	xp_bar_bg.size = Vector2(XP_BAR_W, XP_BAR_H)
	hp_cluster.add_child(xp_bar_bg)

	# XP bar fill
	xp_bar_fill = ColorRect.new()
	xp_bar_fill.color = CLR_XP
	xp_bar_fill.position = Vector2(25, HP_BAR_H + 9)
	xp_bar_fill.size = Vector2(0, XP_BAR_H - 2)
	hp_cluster.add_child(xp_bar_fill)

	# Level label
	level_label = Label.new()
	level_label.text = "Lv 1"
	level_label.add_theme_font_size_override("font_size", 12)
	level_label.add_theme_color_override("font_color", CLR_XP)
	level_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	level_label.add_theme_constant_override("shadow_offset_x", 1)
	level_label.add_theme_constant_override("shadow_offset_y", 1)
	level_label.position = Vector2(HP_BAR_W + 30, HP_BAR_H + 4)
	hp_cluster.add_child(level_label)

	# === TOP-RIGHT: Wave + Enemies cluster ===
	var wave_cluster = Control.new()
	wave_cluster.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	wave_cluster.position = Vector2(-222, 8)
	add_child(wave_cluster)

	# Wave panel (sprite-based NinePatch) — taller to fit 3 lines
	wave_panel = _make_9patch(UI + "panel_frame_small.png", Vector2(0, 0), Vector2(208, 68), 12)
	wave_cluster.add_child(wave_panel)

	# Gear decoration removed — banners have their own icons

	# Stage banner image (replaces text when image exists)
	stage_banner_tex = TextureRect.new()
	stage_banner_tex.position = Vector2(4, 1)
	stage_banner_tex.size = Vector2(200, 42)
	stage_banner_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	stage_banner_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stage_banner_tex.visible = false
	# Shader to make dark/black background pixels transparent
	var banner_shader = ShaderMaterial.new()
	var shader_code = Shader.new()
	shader_code.code = "shader_type canvas_item;
void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float brightness = max(tex.r, max(tex.g, tex.b));
	tex.a *= smoothstep(0.08, 0.25, brightness);
	COLOR = tex;
}"
	banner_shader.shader = shader_code
	stage_banner_tex.material = banner_shader
	wave_cluster.add_child(stage_banner_tex)

	# Stage name text fallback (shown when no banner image)
	stage_name_label = Label.new()
	stage_name_label.text = "The Scrapyard"
	stage_name_label.add_theme_font_size_override("font_size", 13)
	stage_name_label.add_theme_color_override("font_color", CLR_GOLD_TEXT)
	stage_name_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	stage_name_label.add_theme_constant_override("shadow_offset_x", 1)
	stage_name_label.add_theme_constant_override("shadow_offset_y", 1)
	stage_name_label.position = Vector2(12, 6)
	stage_name_label.size = Vector2(184, 18)
	stage_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wave_cluster.add_child(stage_name_label)

	# Wave number — bold, centered under banner
	wave_label = Label.new()
	wave_label.text = "WAVE 1"
	wave_label.uppercase = true
	wave_label.add_theme_font_size_override("font_size", 16)
	wave_label.add_theme_color_override("font_color", CLR_GOLD_TEXT)
	wave_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	wave_label.add_theme_constant_override("shadow_offset_x", 1)
	wave_label.add_theme_constant_override("shadow_offset_y", 1)
	wave_label.add_theme_constant_override("outline_size", 2)
	wave_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	wave_label.position = Vector2(0, 42)
	wave_label.size = Vector2(208, 24)
	wave_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wave_cluster.add_child(wave_label)

	# Controls moved to pause menu — no longer shown on HUD

	# === CENTER: Phase banner ===
	banner_shadow = Label.new()
	banner_shadow.text = ""
	banner_shadow.add_theme_font_size_override("font_size", 42)
	banner_shadow.add_theme_color_override("font_color", Color(0, 0, 0, 0.6))
	banner_shadow.set_anchors_preset(Control.PRESET_CENTER)
	banner_shadow.offset_left = -300; banner_shadow.offset_right = 300
	banner_shadow.offset_top = -28; banner_shadow.offset_bottom = 32
	banner_shadow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_shadow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	banner_shadow.visible = false
	add_child(banner_shadow)

	phase_banner = Label.new()
	phase_banner.text = ""
	phase_banner.add_theme_font_size_override("font_size", 42)
	phase_banner.add_theme_color_override("font_color", CLR_GOLD_TEXT)
	phase_banner.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	phase_banner.add_theme_constant_override("shadow_offset_x", 3)
	phase_banner.add_theme_constant_override("shadow_offset_y", 3)
	phase_banner.set_anchors_preset(Control.PRESET_CENTER)
	phase_banner.offset_left = -300; phase_banner.offset_right = 300
	phase_banner.offset_top = -30; phase_banner.offset_bottom = 30
	phase_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	phase_banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	phase_banner.visible = false
	add_child(phase_banner)

	# Prep timer
	prep_timer_label = Label.new()
	prep_timer_label.text = ""
	prep_timer_label.add_theme_font_size_override("font_size", 24)
	prep_timer_label.add_theme_color_override("font_color", CLR_GOLD_TEXT)
	prep_timer_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	prep_timer_label.add_theme_constant_override("shadow_offset_x", 2)
	prep_timer_label.add_theme_constant_override("shadow_offset_y", 2)
	prep_timer_label.set_anchors_preset(Control.PRESET_CENTER)
	prep_timer_label.offset_left = -100; prep_timer_label.offset_right = 100
	prep_timer_label.offset_top = 32; prep_timer_label.offset_bottom = 60
	prep_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prep_timer_label.visible = false
	add_child(prep_timer_label)

	# Floating text container
	material_float_container = Control.new()
	material_float_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	material_float_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(material_float_container)


# ─── Health bar update ───────────────────────────────────────

func update_health(current: int, max_hp: int) -> void:
	_hp_current = current
	_hp_max = max_hp
	var ratio = float(current) / float(max_hp) if max_hp > 0 else 0.0

	if hp_bar_fill:
		hp_bar_fill.size.x = (HP_BAR_W - 4) * ratio
		if ratio > 0.5:
			hp_bar_fill.color = CLR_HP_FULL
		elif ratio > 0.25:
			hp_bar_fill.color = CLR_HP_MID
		else:
			hp_bar_fill.color = CLR_HP_LOW
	if hp_label:
		hp_label.text = "%d / %d" % [current, max_hp]
	if hp_icon_tex:
		if ratio > 0.5:
			hp_icon_tex.modulate = Color(0.3, 1.0, 0.4)
		elif ratio > 0.25:
			hp_icon_tex.modulate = Color(1.0, 0.85, 0.2)
		else:
			hp_icon_tex.modulate = Color(1.0, 0.3, 0.3)

func update_xp(xp: int, xp_max: int, level: int) -> void:
	var ratio = float(xp) / float(xp_max) if xp_max > 0 else 0.0
	if xp_bar_fill:
		xp_bar_fill.size.x = (XP_BAR_W - 2) * ratio
	if level_label:
		level_label.text = "Lv %d" % level

func update_wave(current_wave: int, total_waves: int) -> void:
	var stage_name: String
	var display_wave: int

	if total_waves == 0:
		stage_name = "The Junkyard"
		display_wave = current_wave
	else:
		var stage_wave = ((current_wave - 1) % 14) + 1
		stage_name = StageData.get_stage_name(current_wave) if current_wave > 0 else "The Scrapyard"
		display_wave = stage_wave

	# Try to show banner image for this stage
	var banner_path = STAGE_BANNERS.get(stage_name, "")
	if banner_path != "" and ResourceLoader.exists(banner_path):
		var tex = load(banner_path) as Texture2D
		if tex and stage_banner_tex:
			stage_banner_tex.texture = tex
			stage_banner_tex.visible = true
			if stage_name_label:
				stage_name_label.visible = false
	else:
		# No banner — fall back to text
		if stage_banner_tex:
			stage_banner_tex.visible = false
		if stage_name_label:
			stage_name_label.visible = true
			stage_name_label.text = stage_name

	if wave_label:
		wave_label.text = "WAVE %d" % display_wave


# ─── Banner with scale animation ────────────────────────────

func show_banner(text: String, color: Color, auto_hide_sec: float) -> void:
	if not is_instance_valid(phase_banner):
		return
	phase_banner.text = text
	phase_banner.add_theme_color_override("font_color", color)
	phase_banner.visible = true
	phase_banner.scale = Vector2(0.3, 0.3)
	phase_banner.modulate = Color(color.r, color.g, color.b, 0.0)
	phase_banner.pivot_offset = phase_banner.size / 2.0

	if banner_shadow:
		banner_shadow.text = text
		banner_shadow.visible = true
		banner_shadow.scale = Vector2(0.3, 0.3)
		banner_shadow.modulate = Color(0, 0, 0, 0.0)
		banner_shadow.pivot_offset = banner_shadow.size / 2.0

	if _banner_tween and _banner_tween.is_valid():
		_banner_tween.kill()
	_banner_tween = create_tween()
	_banner_tween.set_ease(Tween.EASE_OUT)
	_banner_tween.set_trans(Tween.TRANS_BACK)
	_banner_tween.tween_property(phase_banner, "scale", Vector2(1.0, 1.0), 0.35)
	_banner_tween.parallel().tween_property(phase_banner, "modulate", Color(color.r, color.g, color.b, 1.0), 0.25)
	if banner_shadow:
		_banner_tween.parallel().tween_property(banner_shadow, "scale", Vector2(1.0, 1.0), 0.35)
		_banner_tween.parallel().tween_property(banner_shadow, "modulate", Color(0, 0, 0, 0.5), 0.25)

	if auto_hide_sec > 0:
		_banner_tween.tween_interval(maxf(0.0, auto_hide_sec - 0.4))
		_banner_tween.tween_property(phase_banner, "modulate:a", 0.0, 0.4)
		if banner_shadow:
			_banner_tween.parallel().tween_property(banner_shadow, "modulate:a", 0.0, 0.4)
		_banner_tween.tween_callback(func():
			if is_instance_valid(phase_banner): phase_banner.visible = false
			if is_instance_valid(banner_shadow): banner_shadow.visible = false
		)


# ─── Prep timer ─────────────────────────────────────────────

func update_prep_timer(seconds: int, visible_flag: bool) -> void:
	if prep_timer_label:
		prep_timer_label.text = "PREP: %ds" % seconds
		prep_timer_label.visible = visible_flag
