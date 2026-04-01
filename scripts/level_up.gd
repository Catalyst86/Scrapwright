extends Control

# ============================================================
# LevelUp — Perk cards with juicy animations
# Perks stored in GameState so they persist between scenes
# ============================================================

signal perk_chosen(perk_id)

const CLR_BG_DARK     = Color(0.08, 0.06, 0.04, 0.92)
const CLR_PANEL_BG    = Color(0.12, 0.09, 0.06, 0.95)
const CLR_BORDER      = Color(0.55, 0.42, 0.22, 1.0)
const CLR_GOLD_TEXT   = Color(0.95, 0.82, 0.35)
const CLR_SILVER_TEXT = Color(0.78, 0.78, 0.82)
const CLR_DIM_TEXT    = Color(0.45, 0.42, 0.38)
const CLR_GREEN       = Color(0.35, 0.82, 0.40)

const UI = "res://assets/sprites/ui/"

const PERK_ICONS = {
	"hp_up": "icon_perk_hp.png", "speed_up": "icon_perk_speed.png",
	"damage_up": "icon_perk_damage.png", "attack_speed": "icon_perk_damage.png",
	"regen": "icon_perk_hp.png", "xp_boost": "icon_levelup.png",
}
const PERK_ICON_FALLBACK = {
	"hp_up": "+", "speed_up": ">>", "damage_up": "!!", "attack_speed": "~~",
	"regen": "%%", "xp_boost": "&&",
}
const PERK_COLORS = {
	"hp_up": Color(0.9, 0.3, 0.3), "speed_up": Color(0.3, 0.8, 0.9),
	"damage_up": Color(1.0, 0.5, 0.2), "attack_speed": Color(0.9, 0.9, 0.3),
	"regen": Color(0.3, 0.9, 0.4), "xp_boost": Color(0.8, 0.6, 1.0),
}

const ALL_PERKS = [
	{"id":"hp_up",        "name":"+25 Max HP",       "desc":"Increase max health by 25"},
	{"id":"speed_up",     "name":"+15% Speed",        "desc":"Move faster through the arena"},
	{"id":"damage_up",    "name":"+5 Attack Dmg",     "desc":"Auto-attacks hit harder"},
	{"id":"attack_speed", "name":"Faster Attacks",    "desc":"-15% attack cooldown"},
	{"id":"regen",        "name":"Slow Regen",        "desc":"+2 HP every 5 seconds"},
	{"id":"xp_boost",     "name":"+25% XP",           "desc":"Gain more XP from kills"},
]

# Card deck completion perks (only available when full deck is collected)
const CARD_PERKS = [
	{"id":"bug_swarm",   "name":"Bug Swarm",   "desc":"Summon critters that bite nearby enemies for 3 dmg/sec", "deck":"Critter",    "icon":"res://assets/sprites/ui/icon_bug_swarm.png"},
	{"id":"vine_snare",  "name":"Vine Snare",  "desc":"Roots sprout around you, slowing nearby enemies by 40%", "deck":"Overgrowth", "icon":"res://assets/sprites/ui/icon_vine_snare.png"},
]

var regen_timer: Timer = null
var _choice_box: HBoxContainer
var _title_label: Label
var _time: float = 0.0
var _card_nodes: Array = []
var _rerolls_remaining: int = 0
var _reroll_btn: Button = null
var _reroll_container: Control = null  # Parent vbox for adding reroll btn

func _ready() -> void:
	_build_ui()
	hide()

func _load_tex(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path)
	return null

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS

	var dim = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.70)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	# Scale panel width to fit 3 or 4 perk cards
	var num_choices := _get_num_choices()
	var card_w := 140 if num_choices <= 3 else 130
	var gap := 12
	var panel_w := num_choices * card_w + (num_choices - 1) * gap + 60
	var panel_h := 260
	var hw := panel_w / 2.0
	var hh := panel_h / 2.0

	var panel = ColorRect.new()
	panel.color = CLR_PANEL_BG
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -hw; panel.offset_top = -hh
	panel.offset_right = hw; panel.offset_bottom = hh
	add_child(panel)
	_add_panel_borders(Vector2(-hw, -hh), Vector2(panel_w, panel_h))

	var lu_tex = _load_tex(UI + "icon_levelup.png")
	if lu_tex:
		var lu_icon = TextureRect.new()
		lu_icon.texture = lu_tex
		lu_icon.set_anchors_preset(Control.PRESET_CENTER)
		lu_icon.offset_left = -16; lu_icon.offset_top = -hh - 32
		lu_icon.offset_right = 16; lu_icon.offset_bottom = -hh
		lu_icon.expand_mode = 1; lu_icon.stretch_mode = 5
		add_child(lu_icon)

	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_CENTER)
	margin.offset_left = -hw + 10; margin.offset_top = -hh + 8
	margin.offset_right = hw - 10; margin.offset_bottom = hh - 8
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	_title_label = Label.new()
	_title_label.text = "LEVEL UP!"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 24)
	_title_label.add_theme_color_override("font_color", CLR_GOLD_TEXT)
	_title_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_title_label.add_theme_constant_override("shadow_offset_x", 2)
	_title_label.add_theme_constant_override("shadow_offset_y", 2)
	vbox.add_child(_title_label)

	var sub = Label.new()
	sub.text = "Choose a perk:"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 12)
	sub.add_theme_color_override("font_color", CLR_DIM_TEXT)
	vbox.add_child(sub)

	_choice_box = HBoxContainer.new()
	_choice_box.add_theme_constant_override("separation", 12)
	_choice_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_choice_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_choice_box)
	_reroll_container = vbox


func _process(_delta: float) -> void:
	_time += _delta
	if _title_label and visible:
		var glow = 0.85 + 0.15 * sin(_time * 4.0)
		_title_label.add_theme_color_override("font_color",
			CLR_GOLD_TEXT * Color(glow, glow, glow, 1.0))


func show_level_up(_level: int) -> void:
	AudioManager.play("level_up")
	_time = 0.0
	_card_nodes.clear()
	for child in _choice_box.get_children():
		child.queue_free()
	# Remove old reroll button if any
	if _reroll_btn and is_instance_valid(_reroll_btn):
		_reroll_btn.queue_free()
		_reroll_btn = null
	# Set rerolls from Companion Legacy upgrade
	_rerolls_remaining = GameState.permanent.get("reroll_level", 0)

	var choices = _build_choice_pool()

	for i in choices.size():
		var card = _make_perk_card(choices[i], i)
		_choice_box.add_child(card)
		_card_nodes.append(card)

	# Add reroll button if player has rerolls
	if _rerolls_remaining > 0 and _reroll_container:
		_reroll_btn = Button.new()
		_reroll_btn.text = "REROLL (%d)" % _rerolls_remaining
		_reroll_btn.add_theme_font_size_override("font_size", 12)
		_reroll_btn.add_theme_color_override("font_color", Color(0.95, 0.82, 0.35))
		_reroll_btn.custom_minimum_size = Vector2(120, 28)
		_reroll_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_reroll_btn.pressed.connect(_do_reroll.bind(_level))
		_reroll_container.add_child(_reroll_btn)

	show()
	get_tree().paused = true

	modulate = Color(1, 1, 1, 0)
	scale = Vector2(1, 1)
	var tw = create_tween()
	tw.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_property(self, "modulate:a", 1.0, 0.25)

	for i in _card_nodes.size():
		var card = _card_nodes[i]
		card.modulate.a = 0.0
		card.scale = Vector2(0.6, 0.6)
		card.pivot_offset = card.size / 2.0 if card.size.length() > 0 else Vector2(70, 85)
		var ctw = card.create_tween()
		ctw.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		ctw.tween_property(card, "scale", Vector2(1, 1), 0.3).set_delay(0.15 + i * 0.1)
		ctw.parallel().tween_property(card, "modulate:a", 1.0, 0.2).set_delay(0.15 + i * 0.1)


func _make_perk_card(perk: Dictionary, _index: int) -> PanelContainer:
	var perk_color = CLR_GOLD_TEXT
	if perk.get("is_orbital", false):
		var wdata = OrbitalDB.get_weapon_data(perk.weapon_id)
		perk_color = wdata.get("color", CLR_GOLD_TEXT)
	else:
		perk_color = PERK_COLORS.get(perk.id, CLR_GOLD_TEXT)
	var card = PanelContainer.new()
	card.set_meta("perk_name", perk.name)
	var cw := 130 if _get_num_choices() > 3 else 140
	card.custom_minimum_size = Vector2(cw, 180)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var sbf = StyleBoxFlat.new()
	sbf.bg_color = Color(0.10, 0.08, 0.06)
	sbf.border_color = CLR_BORDER
	sbf.set_border_width_all(2); sbf.set_corner_radius_all(4)
	sbf.set_content_margin_all(10)
	card.add_theme_stylebox_override("panel", sbf)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	card.add_child(vbox)

	var icon_tex: Texture2D = null
	if perk.get("is_orbital", false):
		icon_tex = _load_tex("res://assets/sprites/orbitals/orbital_%s.png" % perk.weapon_id)
	else:
		var icon_file = PERK_ICONS.get(perk.id, "")
		icon_tex = _load_tex(UI + icon_file) if icon_file != "" else null
	if icon_tex:
		var icon_tr = TextureRect.new()
		icon_tr.texture = icon_tex
		icon_tr.custom_minimum_size = Vector2(28, 28)
		icon_tr.size = Vector2(28, 28)
		icon_tr.expand_mode = 1; icon_tr.stretch_mode = 5
		icon_tr.modulate = perk_color
		icon_tr.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		vbox.add_child(icon_tr)
	else:
		var icon_lbl = Label.new()
		if perk.get("is_orbital", false):
			icon_lbl.text = "◆"
		else:
			icon_lbl.text = PERK_ICON_FALLBACK.get(perk.id, "?")
		icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		icon_lbl.add_theme_font_size_override("font_size", 28)
		icon_lbl.add_theme_color_override("font_color", perk_color)
		vbox.add_child(icon_lbl)

	var sep = ColorRect.new()
	sep.color = perk_color * Color(1, 1, 1, 0.5)
	sep.custom_minimum_size = Vector2(0, 2)
	vbox.add_child(sep)

	var name_lbl = Label.new()
	name_lbl.text = perk.name
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 14)
	name_lbl.add_theme_color_override("font_color", perk_color)
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(name_lbl)

	var desc_lbl = Label.new()
	desc_lbl.text = perk.desc
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.add_theme_font_size_override("font_size", 10)
	desc_lbl.add_theme_color_override("font_color", CLR_SILVER_TEXT)
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(desc_lbl)

	# Visual upgrade milestone indicator for orbitals
	if perk.get("is_milestone", false):
		var milestone_lbl = Label.new()
		milestone_lbl.text = "VISUAL UPGRADE"
		milestone_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		milestone_lbl.add_theme_font_size_override("font_size", 8)
		milestone_lbl.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0))
		vbox.add_child(milestone_lbl)

	var btn = Button.new()
	btn.text = "SELECT"
	btn.add_theme_font_size_override("font_size", 12)
	btn.custom_minimum_size = Vector2(0, 30)

	var btn_sb = StyleBoxFlat.new()
	btn_sb.bg_color = Color(0.14, 0.11, 0.08)
	btn_sb.border_color = CLR_GREEN
	btn_sb.set_border_width_all(2); btn_sb.set_corner_radius_all(3)
	btn_sb.set_content_margin_all(4)
	btn.add_theme_stylebox_override("normal", btn_sb)

	btn.add_theme_color_override("font_color", CLR_GREEN)
	btn.add_theme_color_override("font_hover_color", CLR_GREEN.lightened(0.3))
	btn.pressed.connect(_on_chosen.bind(perk))
	vbox.add_child(btn)

	card.mouse_entered.connect(func():
		var htw = card.create_tween()
		htw.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		htw.tween_property(card, "scale", Vector2(1.08, 1.08), 0.12)
	)
	card.mouse_exited.connect(func():
		var htw = card.create_tween()
		htw.tween_property(card, "scale", Vector2(1.0, 1.0), 0.12)
	)

	return card


func _do_reroll(level: int) -> void:
	if _rerolls_remaining <= 0:
		return
	_rerolls_remaining -= 1
	# Clear current cards
	_card_nodes.clear()
	for child in _choice_box.get_children():
		child.queue_free()
	# Build new choices
	var choices = _build_choice_pool()
	for i in choices.size():
		var card = _make_perk_card(choices[i], i)
		_choice_box.add_child(card)
		_card_nodes.append(card)
	# Update reroll button
	if _reroll_btn and is_instance_valid(_reroll_btn):
		if _rerolls_remaining > 0:
			_reroll_btn.text = "REROLL (%d)" % _rerolls_remaining
		else:
			_reroll_btn.text = "NO REROLLS"
			_reroll_btn.disabled = true
			_reroll_btn.add_theme_color_override("font_color", Color(0.5, 0.45, 0.4))


func _get_num_choices() -> int:
	var base = 3
	if GameState.permanent.get("perk_choices_level", 0) > 0:
		base = 4
	return base

func _build_choice_pool() -> Array:
	var num_choices = _get_num_choices()
	# Build stat perk pool
	var stat_pool: Array = []
	for p in ALL_PERKS:
		stat_pool.append(p.duplicate())
	# Add card deck perks if unlocked and not already chosen
	var card_db = get_node_or_null("/root/CardDB")
	if card_db:
		for cp in CARD_PERKS:
			if cp.id in GameState.active_perks:
				continue
			if card_db.is_deck_complete(cp.deck):
				stat_pool.append(cp.duplicate())
	stat_pool.shuffle()
	# Deprioritize already-picked perks
	stat_pool.sort_custom(func(a, b): return int(a.id in GameState.active_perks) < int(b.id in GameState.active_perks))

	# Build orbital weapon pool
	var weapon_pool: Array = []
	var owned_ids: Array = []
	for ow in GameState.orbital_weapons:
		owned_ids.append(ow.id)
	for wid in OrbitalDB.get_weapon_ids():
		var data = OrbitalDB.get_weapon_data(wid)
		# Check if already at max level
		var current_lvl = 0
		for ow in GameState.orbital_weapons:
			if ow.id == wid:
				current_lvl = ow.level
		if current_lvl >= OrbitalDB.MAX_LEVEL:
			continue
		var next_lvl = current_lvl + 1
		var is_milestone = OrbitalDB.is_visual_upgrade_level(next_lvl)
		var wp = {
			"id": "orbital_" + wid,
			"weapon_id": wid,
			"is_orbital": true,
			"is_milestone": is_milestone,
			"name": data.name + (" Lv%d" % next_lvl if current_lvl > 0 else ""),
			"desc": OrbitalDB.get_level_desc(wid, next_lvl),
		}
		weapon_pool.append(wp)
	weapon_pool.shuffle()

	# Ensure at least 1 weapon if player has <6 orbitals and weapons available
	var choices: Array = []
	var can_add_weapon = GameState.orbital_weapons.size() < OrbitalDB.MAX_ORBITALS or not weapon_pool.is_empty()
	if can_add_weapon and not weapon_pool.is_empty():
		choices.append(weapon_pool.pop_front())

	# Fill remaining slots from mixed pool
	var mixed: Array = stat_pool + weapon_pool
	mixed.shuffle()
	for item in mixed:
		if choices.size() >= num_choices:
			break
		# Avoid duplicates
		var dominated = false
		for c in choices:
			if c.id == item.id:
				dominated = true
				break
		if not dominated:
			choices.append(item)

	# If still not enough, pad with stat perks
	while choices.size() < num_choices and not stat_pool.is_empty():
		var p = stat_pool.pop_front()
		var dup = false
		for c in choices:
			if c.id == p.id:
				dup = true
				break
		if not dup:
			choices.append(p)

	return choices

func _on_chosen(perk: Dictionary) -> void:
	AudioManager.play("card_select")
	var chosen_idx = -1
	for i in _card_nodes.size():
		if _card_nodes[i].get_meta("perk_name", "") == perk.name:
			chosen_idx = i

	for i in _card_nodes.size():
		var card = _card_nodes[i]
		var tw = card.create_tween()
		if i == chosen_idx:
			tw.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
			tw.tween_property(card, "scale", Vector2(1.2, 1.2), 0.15)
			tw.tween_property(card, "scale", Vector2(1.0, 1.0), 0.1)
		else:
			tw.tween_property(card, "modulate:a", 0.2, 0.2)
			tw.tween_property(card, "scale", Vector2(0.8, 0.8), 0.2)

	var dismiss_tw = create_tween()
	dismiss_tw.tween_interval(0.4)
	dismiss_tw.tween_property(self, "modulate:a", 0.0, 0.2)
	dismiss_tw.tween_callback(func():
		get_tree().paused = false
		hide()
		if perk.get("is_orbital", false):
			_apply_orbital(perk.weapon_id)
		else:
			GameState.active_perks.append(perk.id)
			_apply(perk.id)
		SaveManager.save_game()
		perk_chosen.emit(perk.id)
	)

func _apply_orbital(wid: String) -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("add_orbital_weapon"):
		player.add_orbital_weapon(wid)

func _apply(id: String) -> void:
	var player = get_tree().get_first_node_in_group("player")
	match id:
		"hp_up":
			GameState.player_max_health += 25
			GameState.heal(25)
		"speed_up":
			GameState.perk_speed_multiplier *= 1.15
			if player and "SPEED" in player:
				player.SPEED = 90.0 * GameState.perk_speed_multiplier
		"damage_up":
			GameState.perk_damage_bonus += 5
			if player and "AUTO_ATTACK_DAMAGE" in player:
				player.AUTO_ATTACK_DAMAGE = 8 + GameState.perk_damage_bonus
		"attack_speed":
			GameState.perk_attack_speed_multiplier *= 0.85
			var t = player.get_node_or_null("AttackTimer") as Timer if player else null
			if t:
				t.wait_time = maxf(0.18, 0.6 * GameState.perk_attack_speed_multiplier)
		"regen":
			GameState.perk_regen_active = true
			# Create regen timer on the arena (not on LevelUp node) to avoid duplication
			if not is_instance_valid(regen_timer):
				var arena = get_tree().current_scene
				if arena:
					# Check if arena already has a perk regen timer
					var has_regen = false
					for child in arena.get_children():
						if child is Timer and child.name == "PerkRegenTimer":
							has_regen = true
							break
					if not has_regen:
						regen_timer = Timer.new()
						regen_timer.name = "PerkRegenTimer"
						regen_timer.wait_time = 5.0
						regen_timer.autostart = true
						regen_timer.timeout.connect(func(): GameState.heal(2))
						arena.add_child(regen_timer)
		"xp_boost":
			GameState.perk_xp_multiplier *= 1.25
		"bug_swarm":
			# Critter deck bonus: summon bugs that deal 3 damage/sec to nearby enemies
			var arena = get_tree().current_scene
			if arena and not arena.has_node("BugSwarmTimer"):
				# Visual: rotating bug swarm sprite on player
				var swarm_tex = load("res://assets/sprites/effects/bug_swarm.png") if ResourceLoader.exists("res://assets/sprites/effects/bug_swarm.png") else null
				if swarm_tex and player:
					var swarm_spr = Sprite2D.new()
					swarm_spr.name = "BugSwarmVFX"
					swarm_spr.texture = swarm_tex
					swarm_spr.scale = Vector2(0.6, 0.6)
					swarm_spr.modulate = Color(1, 1, 1, 0.7)
					swarm_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
					swarm_spr.z_index = 5
					player.add_child(swarm_spr)
					# Rotate the swarm continuously
					var rot_timer = Timer.new()
					rot_timer.name = "BugSwarmRotate"
					rot_timer.wait_time = 0.03
					rot_timer.autostart = true
					rot_timer.timeout.connect(func():
						if is_instance_valid(swarm_spr):
							swarm_spr.rotation += 0.06
					)
					player.add_child(rot_timer)
				# Damage timer
				var bug_timer = Timer.new()
				bug_timer.name = "BugSwarmTimer"
				bug_timer.wait_time = 1.0
				bug_timer.autostart = true
				bug_timer.timeout.connect(func():
					if not player or not is_instance_valid(player): return
					for enemy in get_tree().get_nodes_in_group("enemies"):
						if not is_instance_valid(enemy) or enemy.is_dead: continue
						if player.global_position.distance_to(enemy.global_position) < 80.0:
							if enemy.has_method("take_damage"):
								enemy.take_damage(3, player.global_position)
				)
				arena.add_child(bug_timer)
		"vine_snare":
			# Overgrowth deck bonus: slow nearby enemies by 40%
			var arena2 = get_tree().current_scene
			if arena2 and not arena2.has_node("VineSnareTimer"):
				# Visual: vine snare sprite on player feet
				var vine_tex = load("res://assets/sprites/effects/vine_snare.png") if ResourceLoader.exists("res://assets/sprites/effects/vine_snare.png") else null
				if vine_tex and player:
					var vine_spr = Sprite2D.new()
					vine_spr.name = "VineSnareVFX"
					vine_spr.texture = vine_tex
					vine_spr.scale = Vector2(0.8, 0.8)
					vine_spr.modulate = Color(0.6, 1.0, 0.5, 0.5)
					vine_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
					vine_spr.z_index = -1
					player.add_child(vine_spr)
					# Pulse the vines
					var pulse_tw = player.create_tween().set_loops()
					pulse_tw.tween_property(vine_spr, "scale", Vector2(0.9, 0.9), 0.8).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
					pulse_tw.tween_property(vine_spr, "scale", Vector2(0.7, 0.7), 0.8).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
				# Slow timer
				var vine_timer = Timer.new()
				vine_timer.name = "VineSnareTimer"
				vine_timer.wait_time = 0.5
				vine_timer.autostart = true
				vine_timer.timeout.connect(func():
					if not player or not is_instance_valid(player): return
					for enemy in get_tree().get_nodes_in_group("enemies"):
						if not is_instance_valid(enemy) or enemy.is_dead: continue
						if player.global_position.distance_to(enemy.global_position) < 100.0:
							if "move_speed" in enemy and "_base_move_speed" in enemy:
								enemy.move_speed = enemy._base_move_speed * 0.6
						else:
							if "move_speed" in enemy and "_base_move_speed" in enemy:
								enemy.move_speed = enemy._base_move_speed
				)
				arena2.add_child(vine_timer)


func _add_panel_borders(offset: Vector2, sz: Vector2) -> void:
	for data in [
		{"x": offset.x, "y": offset.y, "w": sz.x, "h": 3},
		{"x": offset.x, "y": offset.y + sz.y - 3, "w": sz.x, "h": 3},
		{"x": offset.x, "y": offset.y, "w": 3, "h": sz.y},
		{"x": offset.x + sz.x - 3, "y": offset.y, "w": 3, "h": sz.y},
	]:
		var r = ColorRect.new()
		r.color = CLR_BORDER
		r.set_anchors_preset(Control.PRESET_CENTER)
		r.offset_left = data.x; r.offset_top = data.y
		r.offset_right = data.x + data.w; r.offset_bottom = data.y + data.h
		add_child(r)
