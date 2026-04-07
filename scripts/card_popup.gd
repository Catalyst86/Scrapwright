extends CanvasLayer

# ============================================================
# CardPopup — Non-blocking card reveal overlay
# ============================================================

const DISPLAY_TIME = 2.5
const FADE_IN_TIME = 0.3
const FADE_OUT_TIME = 0.25

var _overlay: ColorRect
var _card_container: Control
var _dismiss_timer: float = 0.0
var _showing: bool = false
var _queue: Array[Dictionary] = []

func _ready() -> void:
	layer = 15
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()

func _build_ui() -> void:
	# Dark overlay
	_overlay = ColorRect.new()
	_overlay.color = Color(0, 0, 0, 0.5)
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.gui_input.connect(_on_overlay_click)
	_overlay.visible = false
	add_child(_overlay)

	# Card container (centered)
	_card_container = Control.new()
	_card_container.set_anchors_preset(Control.PRESET_CENTER)
	_card_container.visible = false
	add_child(_card_container)

func _process(delta: float) -> void:
	if not _showing:
		return
	_dismiss_timer -= delta
	if _dismiss_timer <= 0:
		_dismiss_card()

func _on_overlay_click(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_dismiss_card()

func show_card(card: Dictionary) -> void:
	if _showing:
		if _queue.size() < 3:
			_queue.append(card)
		return
	_reveal(card)

func _reveal(card: Dictionary) -> void:
	_showing = true
	_dismiss_timer = DISPLAY_TIME

	# Clear old card
	for child in _card_container.get_children():
		child.queue_free()

	# Build card visual
	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.06, 0.04, 0.95)
	style.border_color = card.get("deck_color", Color(0.65, 0.45, 0.20))
	style.set_border_width_all(3)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(140, 190)
	panel.position = Vector2(-70, -95)
	_card_container.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(vbox)

	# Deck label
	var deck_lbl = Label.new()
	deck_lbl.text = card.get("deck", "???")
	deck_lbl.add_theme_font_size_override("font_size", 10)
	deck_lbl.add_theme_color_override("font_color", card.get("deck_color", Color(0.7, 0.7, 0.7)))
	deck_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(deck_lbl)

	# Card art
	var tex_path = card.get("texture_path", "")
	if ResourceLoader.exists(tex_path):
		var tex = load(tex_path) as Texture2D
		if tex:
			var icon = TextureRect.new()
			icon.texture = tex
			icon.expand_mode = 1  # EXPAND_IGNORE_SIZE
			icon.stretch_mode = 5  # KEEP_ASPECT_CENTERED
			icon.custom_minimum_size = Vector2(80, 80)
			icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			vbox.add_child(icon)

	# Separator
	var sep = ColorRect.new()
	sep.color = card.get("deck_color", Color(0.65, 0.45, 0.20))
	sep.custom_minimum_size = Vector2(0, 2)
	vbox.add_child(sep)

	# Card name
	var name_lbl = Label.new()
	name_lbl.text = card.get("name", "Unknown")
	name_lbl.add_theme_font_size_override("font_size", 14)
	name_lbl.add_theme_color_override("font_color", Color(0.95, 0.82, 0.35))
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(name_lbl)

	# NEW badge
	var card_db = get_node_or_null("/root/CardDB")
	var is_new = card_db and card_db.collected.get(card.get("id", ""), 0) <= 1
	if is_new:
		var new_lbl = Label.new()
		new_lbl.text = "NEW!"
		new_lbl.add_theme_font_size_override("font_size", 12)
		new_lbl.add_theme_color_override("font_color", Color(0.2, 1.0, 0.4))
		new_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(new_lbl)

	# Animate in
	_overlay.visible = true
	_card_container.visible = true
	_overlay.modulate = Color(1, 1, 1, 0)
	panel.scale = Vector2(0.3, 0.3)
	panel.modulate = Color(1, 1, 1, 0)
	panel.pivot_offset = panel.custom_minimum_size * 0.5

	var tw = create_tween()
	tw.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_property(_overlay, "modulate:a", 1.0, FADE_IN_TIME)
	tw.parallel().tween_property(panel, "scale", Vector2(1.0, 1.0), FADE_IN_TIME)
	tw.parallel().tween_property(panel, "modulate:a", 1.0, FADE_IN_TIME * 0.6)

func _dismiss_card() -> void:
	if not _showing:
		return
	_showing = false

	var tw = create_tween()
	tw.tween_property(_overlay, "modulate:a", 0.0, FADE_OUT_TIME)
	tw.parallel().tween_property(_card_container, "modulate:a", 0.0, FADE_OUT_TIME)
	tw.tween_callback(func():
		_overlay.visible = false
		_card_container.visible = false
		_card_container.modulate.a = 1.0
		# Show next queued card
		if not _queue.is_empty():
			var next = _queue.pop_front()
			_reveal(next)
	)
