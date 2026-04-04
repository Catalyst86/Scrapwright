extends Area2D

# ============================================================
# Chest — Universal chest with opening animation.
# Player chooses which key tier to spend. Loot springs out.
# Spritesheet: 9 frames (256x256 each) in a horizontal strip.
#   Frames 0-2: idle/closed, 3-5: opening, 6-8: fully open + magic burst
# ============================================================

signal chest_opened

const TIER_COLORS = {
	"bronze": Color(0.72, 0.45, 0.20),
	"silver": Color(0.75, 0.75, 0.80),
	"gold":   Color(1.0, 0.84, 0.0),
	"secret": Color(0.6, 0.2, 0.9),
}

const BASIC_MATS   = ["iron_scrap", "timber", "stone"]
const MID_MATS     = ["iron_scrap", "timber", "stone", "fuel", "organic"]
const ALL_MATS     = ["iron_scrap", "timber", "stone", "fuel", "organic", "blueprint"]

# Legacy PERMANENT_UPGRADES removed — gold chests now give bonus materials + heal

const ORBITAL_DROP_CHANCE = {
	"bronze": 0.0,
	"silver": 0.05,
	"gold": 0.15,
	"secret": 0.30,
}

const SHEET_PATH   = "res://assets/sprites/items/chest_open_sheet.png"
const FRAME_COUNT  = 9
const FRAME_W      = 256
const FRAME_H      = 256
const IDLE_FRAMES  = [0, 1, 2]           # Subtle idle loop
const OPEN_FRAMES  = [3, 4, 5, 6, 7, 8]  # Opening sequence

var opened: bool = false
var bob_time: float = 0.0
var bob_origin_y: float = 0.0
var _chosen_tier: String = ""
var _anim_sprite: Sprite2D = null
var _sheet_tex: Texture2D = null
var _current_frame: int = 0
var _anim_timer: float = 0.0
var _idle_fps: float = 3.0    # Slow idle bob
var _open_fps: float = 10.0   # Fast opening
var _playing_open: bool = false
var _fallback: ColorRect = null
var _deny_label: Label = null
var _deny_timer: float = 0.0
var _choice_ui: CanvasLayer = null
var _player_in_range: bool = false
var _has_sheet: bool = false

func _ready() -> void:
	collision_layer = 16
	collision_mask  = 1
	monitoring      = true
	monitorable     = false

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	bob_origin_y = position.y

	# Load spritesheet
	if ResourceLoader.exists(SHEET_PATH):
		_sheet_tex = load(SHEET_PATH)
		_has_sheet = true

	_anim_sprite = Sprite2D.new()
	# Big chest: ~100px on a 480x270 viewport = dramatic event feel
	_anim_sprite.scale = Vector2(0.4, 0.4)
	add_child(_anim_sprite)

	if _has_sheet:
		_set_frame(0)
	else:
		# Fallback: try static sprite
		var closed_path = "res://assets/sprites/items/chest_closed.png"
		if ResourceLoader.exists(closed_path):
			_anim_sprite.texture = load(closed_path)
		else:
			_anim_sprite.visible = false
			_fallback = ColorRect.new()
			_fallback.size = Vector2(16, 12)
			_fallback.position = Vector2(-8, -6)
			_fallback.color = Color(0.55, 0.35, 0.15)
			add_child(_fallback)
			var lid = ColorRect.new()
			lid.size = Vector2(16, 3)
			lid.position = Vector2(-8, -6)
			lid.color = Color(0.4, 0.25, 0.1)
			add_child(lid)

func _process(delta: float) -> void:
	if opened and not _playing_open:
		return

	# Bobbing (only when not opening)
	if not _playing_open and not opened:
		bob_time += delta * 2.5
		position.y = bob_origin_y + sin(bob_time) * 2.0

	# Spritesheet animation
	if _has_sheet:
		_anim_timer += delta
		if _playing_open:
			if _anim_timer >= 1.0 / _open_fps:
				_anim_timer = 0.0
				_advance_open_anim()
		elif not opened:
			if _anim_timer >= 1.0 / _idle_fps:
				_anim_timer = 0.0
				_current_frame = (_current_frame + 1) % IDLE_FRAMES.size()
				_set_frame(IDLE_FRAMES[_current_frame])

	# Deny label timer
	if _deny_label and _deny_timer > 0:
		_deny_timer -= delta
		if _deny_timer <= 0:
			_deny_label.queue_free()
			_deny_label = null

func _set_frame(idx: int) -> void:
	if not _sheet_tex:
		return
	var atlas = AtlasTexture.new()
	atlas.atlas = _sheet_tex
	atlas.region = Rect2(idx * FRAME_W, 0, FRAME_W, FRAME_H)
	_anim_sprite.texture = atlas

var _open_frame_idx: int = 0

func _play_open_anim() -> void:
	_playing_open = true
	_open_frame_idx = 0
	_anim_timer = 0.0
	_set_frame(OPEN_FRAMES[0])

func _advance_open_anim() -> void:
	_open_frame_idx += 1
	if _open_frame_idx < OPEN_FRAMES.size():
		_set_frame(OPEN_FRAMES[_open_frame_idx])
	else:
		# Animation done — hold last frame
		_playing_open = false
		_set_frame(OPEN_FRAMES[-1])
		# Now spawn loot
		call_deferred("_generate_loot")

func _on_body_entered(body: Node) -> void:
	if opened:
		return
	if not body.is_in_group("player"):
		return
	_player_in_range = true

	if not GameState.has_any_key():
		_show_deny()
		return

	_show_key_choice()

func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_player_in_range = false
		_close_key_choice()

# ═══════════════════════════════════════════════════════════════
# Key Choice UI — pauses game, shows available key tiers
# ═══════════════════════════════════════════════════════════════

func _show_key_choice() -> void:
	if _choice_ui:
		return

	get_tree().paused = true

	_choice_ui = CanvasLayer.new()
	_choice_ui.layer = 15
	_choice_ui.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_choice_ui)

	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.5)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_choice_ui.add_child(overlay)

	var panel = PanelContainer.new()
	panel.process_mode = Node.PROCESS_MODE_ALWAYS
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.06, 0.04, 0.95)
	sb.border_color = Color(0.8, 0.65, 0.3)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", sb)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	var title = Label.new()
	title.text = "CHOOSE A KEY"
	title.add_theme_font_size_override("font_size", 11)
	title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var sep = ColorRect.new()
	sep.color = Color(0.8, 0.65, 0.3, 0.5)
	sep.custom_minimum_size = Vector2(0, 1)
	vbox.add_child(sep)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(hbox)

	for tier in GameState.KEY_TIERS:
		var count = GameState.get_key_count(tier)
		if count <= 0:
			continue

		var btn = Button.new()
		btn.process_mode = Node.PROCESS_MODE_ALWAYS
		btn.text = "%s x%d" % [tier.capitalize(), count]
		btn.add_theme_font_size_override("font_size", 9)
		btn.custom_minimum_size = Vector2(60, 24)

		var btn_sb = StyleBoxFlat.new()
		btn_sb.bg_color = TIER_COLORS.get(tier, Color.WHITE).darkened(0.6)
		btn_sb.border_color = TIER_COLORS.get(tier, Color.WHITE)
		btn_sb.set_border_width_all(1)
		btn_sb.set_corner_radius_all(3)
		btn_sb.set_content_margin_all(4)
		btn.add_theme_stylebox_override("normal", btn_sb)

		var hover_sb = btn_sb.duplicate()
		hover_sb.bg_color = TIER_COLORS.get(tier, Color.WHITE).darkened(0.3)
		btn.add_theme_stylebox_override("hover", hover_sb)

		btn.add_theme_color_override("font_color", TIER_COLORS.get(tier, Color.WHITE))
		btn.add_theme_color_override("font_hover_color", Color.WHITE)

		var captured_tier = tier
		btn.pressed.connect(func(): _on_tier_chosen(captured_tier))
		hbox.add_child(btn)

	var cancel = Button.new()
	cancel.process_mode = Node.PROCESS_MODE_ALWAYS
	cancel.text = "Cancel"
	cancel.add_theme_font_size_override("font_size", 8)
	cancel.add_theme_color_override("font_color", Color(0.7, 0.6, 0.5))
	cancel.pressed.connect(_close_key_choice)
	vbox.add_child(cancel)
	cancel.alignment = HORIZONTAL_ALIGNMENT_CENTER

	_choice_ui.add_child(panel)

	await get_tree().process_frame
	if not is_inside_tree(): return
	var vp_size = get_viewport().get_visible_rect().size
	panel.position = Vector2(
		(vp_size.x - panel.size.x) / 2.0,
		(vp_size.y - panel.size.y) / 2.0
	)

	panel.scale = Vector2(0.5, 0.5)
	panel.pivot_offset = panel.size / 2.0
	var tw = panel.create_tween()
	tw.tween_property(panel, "scale", Vector2(1.0, 1.0), 0.15).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

func _close_key_choice() -> void:
	if _choice_ui:
		_choice_ui.queue_free()
		_choice_ui = null
		get_tree().paused = false

func _exit_tree() -> void:
	# Safety: if chest is freed while key choice UI is open, ensure unpause
	if get_tree():
		get_tree().paused = false

func _on_tier_chosen(tier: String) -> void:
	_close_key_choice()
	if opened:
		return
	if GameState.use_key(tier):
		_chosen_tier = tier
		_open_chest()

# ═══════════════════════════════════════════════════════════════
# Chest Opening — plays spritesheet animation, then spawns loot
# ═══════════════════════════════════════════════════════════════

func _open_chest() -> void:
	opened = true
	AudioManager.play("chest_open")

	if _has_sheet:
		_play_open_anim()
	else:
		# No spritesheet — instant open with static swap
		var open_path = "res://assets/sprites/items/chest_open.png"
		var open_tex = load(open_path) as Texture2D
		if open_tex and _anim_sprite:
			_anim_sprite.texture = open_tex
		elif _fallback:
			_fallback.color = _fallback.color.darkened(0.4)
		call_deferred("_generate_loot")

func _show_deny() -> void:
	AudioManager.play("chest_deny")
	if _deny_label:
		_deny_label.queue_free()

	_deny_label = Label.new()
	_deny_label.text = "No keys!"
	_deny_label.add_theme_font_size_override("font_size", 7)
	_deny_label.modulate = Color(1, 0.4, 0.3)
	_deny_label.position = Vector2(-20, -28)
	add_child(_deny_label)
	_deny_timer = 1.5

	var tw = create_tween()
	tw.tween_property(_deny_label, "position:y", _deny_label.position.y - 12, 1.5)
	tw.parallel().tween_property(_deny_label, "modulate:a", 0.0, 1.5)

# ═══════════════════════════════════════════════════════════════
# Loot Generation — items spring out of the chest
# ═══════════════════════════════════════════════════════════════

func _generate_loot() -> void:
	if not is_inside_tree(): return
	var loot_summary: Array = []

	var xp_rewards = {"bronze": 15, "silver": 30, "gold": 60, "secret": 100}
	var xp_amount = xp_rewards.get(_chosen_tier, 15)
	GameState.gain_xp(xp_amount)
	loot_summary.append({"text": "+%d XP" % xp_amount, "color": Color(0.35, 0.60, 0.90)})

	match _chosen_tier:
		"bronze":
			loot_summary.append_array(_drop_materials(BASIC_MATS, randi_range(2, 4)))
		"silver":
			loot_summary.append_array(_drop_materials(MID_MATS, randi_range(3, 5)))
			if randf() < 0.15:
				GameState.player_max_health += 5
				GameState.player_health = min(GameState.player_health + 5, GameState.player_max_health)
				GameState.emit_signal("health_changed", GameState.player_health, GameState.player_max_health)
				loot_summary.append({"text": "+5 Max Health!", "color": Color(0.3, 1.0, 0.3)})
		"gold":
			loot_summary.append_array(_drop_materials(ALL_MATS, randi_range(4, 6)))
			# Bonus: 25% chance for extra blueprint + heal
			if randf() < 0.25:
				GameState.add_material("blueprint", 1)
				loot_summary.append({"text": "+1 Blueprint!", "color": Color(0.3, 0.5, 0.95)})
			if randf() < 0.30:
				var heal_amt = 15
				GameState.heal(heal_amt)
				loot_summary.append({"text": "+%d HP!" % heal_amt, "color": Color(0.3, 1.0, 0.3)})
		"secret":
			loot_summary.append_array(_drop_materials(ALL_MATS, randi_range(6, 10)))
			GameState.add_material("blueprint", 1)
			loot_summary.append({"text": "+1 Blueprint!", "color": Color(0.3, 0.5, 0.95)})

	# Orbital weapon upgrade drop
	var orbital_chance = ORBITAL_DROP_CHANCE.get(_chosen_tier, 0.0)
	if orbital_chance > 0.0 and randf() < orbital_chance:
		var orbital_entry = _try_orbital_drop()
		if orbital_entry:
			loot_summary.append(orbital_entry)

	# Spring loot icons out of the chest
	_spring_loot_icons(loot_summary)

	# Fade out after loot display
	var tw = create_tween()
	tw.tween_interval(3.5)
	tw.tween_property(self, "modulate:a", 0.0, 0.5)
	tw.tween_callback(func():
		emit_signal("chest_opened")
		if is_inside_tree():
			queue_free()
	)

func _spring_loot_icons(items: Array) -> void:
	# Each loot entry springs upward from the chest in an arc
	var parent = get_parent()
	if not parent:
		return

	for i in items.size():
		var item = items[i]
		var lbl = Label.new()
		lbl.text = item.text
		lbl.add_theme_font_size_override("font_size", 8)
		lbl.add_theme_color_override("font_color", item.color)
		lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
		lbl.add_theme_constant_override("shadow_offset_x", 1)
		lbl.add_theme_constant_override("shadow_offset_y", 1)
		lbl.z_index = 15
		lbl.global_position = global_position + Vector2(-20, -5)
		lbl.modulate.a = 0.0
		parent.add_child(lbl)

		# Stagger each item's animation
		var delay = i * 0.15
		# Random horizontal spread
		var spread_x = randf_range(-35, 35)
		var target_y = -30.0 - i * 12.0

		var tw = lbl.create_tween()
		# Fade in
		tw.tween_property(lbl, "modulate:a", 1.0, 0.1).set_delay(delay)
		# Spring upward with horizontal spread
		tw.parallel().tween_property(lbl, "position",
			lbl.position + Vector2(spread_x, target_y), 0.4
		).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK).set_delay(delay)
		# Scale pop
		lbl.scale = Vector2(0.3, 0.3)
		lbl.pivot_offset = lbl.size / 2.0
		tw.parallel().tween_property(lbl, "scale",
			Vector2(1.0, 1.0), 0.3
		).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC).set_delay(delay)
		# Hold then fade out
		tw.tween_interval(2.0)
		tw.tween_property(lbl, "modulate:a", 0.0, 0.5)
		tw.parallel().tween_property(lbl, "position:y", lbl.position.y + target_y - 10, 0.5)
		tw.tween_callback(lbl.queue_free)

func _try_orbital_drop() -> Variant:
	var player = get_tree().get_first_node_in_group("player")
	if not player or not player.has_method("add_orbital_weapon"):
		return null

	var owned = GameState.orbital_weapons
	var upgradeable: Array = []
	for entry in owned:
		if entry.level < OrbitalDB.MAX_LEVEL:
			upgradeable.append(entry.id)

	if not upgradeable.is_empty():
		var wid = upgradeable[randi() % upgradeable.size()]
		player.add_orbital_weapon(wid)
		var data = OrbitalDB.get_weapon_data(wid)
		var wname = data.get("name", wid)
		return {"text": "%s Lv UP!" % wname, "color": data.get("color", Color(0.6, 0.8, 1.0))}

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
			player.add_orbital_weapon(wid)
			var data = OrbitalDB.get_weapon_data(wid)
			var wname = data.get("name", wid)
			return {"text": "NEW: %s!" % wname, "color": data.get("color", Color(0.6, 0.8, 1.0))}

	return null

func _drop_materials(pool: Array, count: int) -> Array:
	var dropped: Dictionary = {}
	var pickup_scene = load("res://scenes/material_pickup.tscn")
	for i in count:
		var mat_type = pool[randi() % pool.size()]
		dropped[mat_type] = dropped.get(mat_type, 0) + 1
		if pickup_scene:
			var pickup = pickup_scene.instantiate()
			pickup.material_type = mat_type
			pickup.amount = 1
			pickup.global_position = global_position
			var pickups = get_tree().get_first_node_in_group("pickups_container")
			if pickups:
				pickups.add_child(pickup)
			elif get_parent():
				get_parent().add_child(pickup)
		else:
			GameState.add_material(mat_type, 1)
	var entries: Array = []
	for mat in dropped:
		var mat_name = mat.replace("_", " ").capitalize()
		entries.append({"text": "+%d %s" % [dropped[mat], mat_name], "color": Color(0.9, 0.85, 0.6)})
	return entries
