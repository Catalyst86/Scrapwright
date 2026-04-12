extends Control

# ============================================================
# Credits — Scrolling credits screen shown after victory
# ============================================================

const CLR_BG         = Color(0.04, 0.03, 0.06, 1.0)
const CLR_GOLD       = Color(0.95, 0.82, 0.35)
const CLR_SILVER     = Color(0.78, 0.78, 0.82)
const CLR_DIM        = Color(0.50, 0.48, 0.45)
const CLR_BORDER     = Color(0.55, 0.42, 0.22, 1.0)
const CLR_HEADING    = Color(0.85, 0.65, 0.25)

const SCROLL_SPEED   = 30.0  # pixels per second
const START_DELAY    = 1.0   # seconds before scroll begins

const UI = "res://assets/sprites/ui/"

const GODOT_LICENSE = """Copyright (c) 2014-present Godot Engine contributors.
Copyright (c) 2007-2014 Juan Linietsky, Ariel Manzur.

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
"Software"), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject
to the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE."""

var _scroll_container: ScrollContainer
var _content: VBoxContainer
var _scroll_active := false
var _auto_scroll := true
var _time: float = 0.0
var _particles: Array = []
var _particle_tex: Texture2D

func _ready() -> void:
	# Victory music continues from arena — don't restart it
	_build_ui()
	# Start scrolling after a short delay
	await get_tree().create_timer(START_DELAY).timeout
	if not is_inside_tree(): return
	_scroll_active = true

func _build_ui() -> void:
	# Dark background
	var bg = ColorRect.new()
	bg.color = CLR_BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Vignette overlay
	if ResourceLoader.exists(UI + "bg_vignette_dark.png"):
		var vig = TextureRect.new()
		vig.texture = load(UI + "bg_vignette_dark.png")
		vig.set_anchors_preset(Control.PRESET_FULL_RECT)
		vig.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		vig.stretch_mode = TextureRect.STRETCH_SCALE
		vig.modulate = Color(0.9, 0.8, 0.5, 0.15)
		add_child(vig)

	# Scroll container (full screen, no scrollbar)
	_scroll_container = ScrollContainer.new()
	_scroll_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	add_child(_scroll_container)

	# Content VBox
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 4)
	_scroll_container.add_child(_content)

	# Top spacer — start credits at the bottom of the screen
	var vp_h = get_viewport().get_visible_rect().size.y if get_viewport() else 540.0
	_add_spacer(vp_h)

	# === CREDITS CONTENT ===

	_add_title("SCRAPWRIGHT", 32, CLR_GOLD)
	_add_spacer(8)
	_add_line("Developed by", 14, CLR_DIM)
	_add_line("Northern Oak Games", 20, CLR_SILVER)
	_add_spacer(30)

	_add_heading("Lead Game Design & Graphics")
	_add_name("James Hope")
	_add_spacer(30)

	_add_heading("Game Testing")
	_add_name("David Belfry")
	_add_name("Kyle Hope")
	_add_name("Cullen Hope")
	_add_name("Danielle Hope")
	_add_spacer(30)

	_add_heading("Music & Sound Effects")
	_add_line("Generated with Suno AI", 14, CLR_SILVER)
	_add_spacer(30)

	_add_heading("Art & Assets")
	_add_line("Generated with Grok Imagine & Meshy", 14, CLR_SILVER)
	_add_spacer(30)

	_add_heading("Font")
	_add_line("\"Sweet Sunset\"", 14, CLR_SILVER)
	_add_spacer(30)

	_add_heading("Powered By")
	_add_line("Godot Engine 4.6", 16, CLR_SILVER)
	_add_line("https://godotengine.org", 11, CLR_DIM)
	_add_spacer(20)

	_add_heading("Godot Engine License")
	_add_line(GODOT_LICENSE, 9, CLR_DIM)
	_add_spacer(40)

	_add_line("Thank you for playing!", 18, CLR_GOLD)
	_add_spacer(30)

	# Return to Hub button
	var btn_container = CenterContainer.new()
	btn_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_child(btn_container)

	var return_btn = Button.new()
	return_btn.text = "RETURN TO HUB"
	return_btn.custom_minimum_size = Vector2(220, 44)
	return_btn.add_theme_font_size_override("font_size", 18)

	var btn_tex_path = UI + "button_normal.png"
	var btn_hover_path = UI + "button_hover.png"
	if ResourceLoader.exists(btn_tex_path):
		var sb = StyleBoxTexture.new()
		sb.texture = load(btn_tex_path)
		sb.texture_margin_left = 8; sb.texture_margin_right = 8
		sb.texture_margin_top = 4; sb.texture_margin_bottom = 4
		sb.content_margin_left = 12; sb.content_margin_right = 12
		sb.content_margin_top = 8; sb.content_margin_bottom = 8
		return_btn.add_theme_stylebox_override("normal", sb)
		if ResourceLoader.exists(btn_hover_path):
			var sb_h = StyleBoxTexture.new()
			sb_h.texture = load(btn_hover_path)
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
		sb_h.bg_color = Color(0.22, 0.18, 0.12); sb_h.border_color = CLR_GOLD
		return_btn.add_theme_stylebox_override("hover", sb_h)

	return_btn.add_theme_color_override("font_color", CLR_GOLD)
	return_btn.add_theme_color_override("font_hover_color", CLR_GOLD.lightened(0.2))
	return_btn.pressed.connect(_return_to_hub)
	return_btn.mouse_entered.connect(func():
		var tw = return_btn.create_tween()
		tw.tween_property(return_btn, "scale", Vector2(1.05, 1.05), 0.1).set_trans(Tween.TRANS_BACK)
	)
	return_btn.mouse_exited.connect(func():
		var tw = return_btn.create_tween()
		tw.tween_property(return_btn, "scale", Vector2(1.0, 1.0), 0.1)
	)
	btn_container.add_child(return_btn)

	# Bottom spacer
	_add_spacer(vp_h * 0.4)

	# Load particle texture
	if ResourceLoader.exists(UI + "particle_ember.png"):
		_particle_tex = load(UI + "particle_ember.png")

# --- Helpers ---

func _add_title(text: String, font_size: int, color: Color) -> void:
	var lbl = Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	lbl.add_theme_constant_override("shadow_offset_x", 2)
	lbl.add_theme_constant_override("shadow_offset_y", 2)
	_content.add_child(lbl)

func _add_heading(text: String) -> void:
	_add_spacer(4)
	var lbl = Label.new()
	lbl.text = "- %s -" % text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.add_theme_color_override("font_color", CLR_HEADING)
	_content.add_child(lbl)
	_add_spacer(6)

func _add_name(text: String) -> void:
	_add_line(text, 14, CLR_SILVER)

func _add_line(text: String, font_size: int, color: Color) -> void:
	var lbl = Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", color)
	_content.add_child(lbl)

func _add_spacer(height: float) -> void:
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, height)
	_content.add_child(spacer)

# --- Scrolling & effects ---

func _process(delta: float) -> void:
	_time += delta

	if _scroll_active and _auto_scroll:
		_scroll_container.scroll_vertical += int(SCROLL_SPEED * delta)
		# Stop auto-scroll when we've reached the end
		var max_scroll = _content.size.y - _scroll_container.size.y
		if _scroll_container.scroll_vertical >= max_scroll:
			_auto_scroll = false

	# Ambient gold particles
	if randf() < 0.12 and _particles.size() < 20:
		_spawn_particle()
	_update_particles(delta)

func _spawn_particle() -> void:
	var vp_size = get_viewport().get_visible_rect().size if get_viewport() else Vector2(960, 540)
	var pos = Vector2(randf_range(0, vp_size.x), vp_size.y + 5)
	if _particle_tex:
		var p = TextureRect.new()
		p.texture = _particle_tex
		var sz = randf_range(2, 5)
		p.size = Vector2(sz, sz)
		p.custom_minimum_size = Vector2(sz, sz)
		p.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		p.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		p.position = pos
		p.modulate = Color(1, 0.85, 0.4, randf_range(0.2, 0.5))
		add_child(p)
		_particles.append({"node": p, "vy": randf_range(-15, -35), "vx": randf_range(-5, 5), "life": randf_range(3.0, 6.0)})
	else:
		var p = ColorRect.new()
		p.color = Color(0.95, 0.8, 0.3, randf_range(0.2, 0.5))
		var sz = randf_range(1, 3)
		p.size = Vector2(sz, sz)
		p.position = pos
		add_child(p)
		_particles.append({"node": p, "vy": randf_range(-15, -35), "vx": randf_range(-5, 5), "life": randf_range(3.0, 6.0)})

func _update_particles(delta: float) -> void:
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
				p.node.modulate.a = p.life * 0.5
	to_remove.reverse()
	for i in to_remove:
		_particles.remove_at(i)

# --- Input ---

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		# Click skips to end of scroll
		_auto_scroll = false
		var max_scroll = _content.size.y - _scroll_container.size.y
		var tw = create_tween()
		tw.tween_property(_scroll_container, "scroll_vertical", int(max_scroll), 0.5).set_ease(Tween.EASE_OUT)
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_return_to_hub()

# --- Navigation ---

func _return_to_hub() -> void:
	GameState.set_phase(GameState.Phase.BASE_HUB)
	var tw = create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.3).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		get_tree().change_scene_to_file("res://scenes/base_hub.tscn")
	)
