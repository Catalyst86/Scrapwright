extends Control

# ============================================================
# LevelUp — Perk cards with juicy animations
# Perks stored in GameState so they persist between scenes
# ============================================================

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
	"thick_skin": "icon_shield.png", "iron_jaws": "icon_perk_damage.png",
	"quick_paws": "icon_perk_speed.png", "scavenger_nose": "icon_bag.png",
	"second_wind": "icon_heart.png", "bloodlust": "icon_skull.png",
	"bark_blast": "icon_perk_damage.png", "shadow_step": "icon_clock.png",
	"thorns": "icon_shield.png", "lucky_find": "icon_bag.png",
}
const PERK_ICON_FALLBACK = {
	"hp_up": "+", "speed_up": ">>", "damage_up": "!!", "attack_speed": "~~",
	"regen": "%%", "xp_boost": "&&",
	"thick_skin": "[]", "iron_jaws": "XX", "quick_paws": "<>", "scavenger_nose": "??",
	"second_wind": "<3", "bloodlust": "##", "bark_blast": "((", "shadow_step": "..",
	"thorns": "/\\", "lucky_find": "$$",
}
const PERK_COLORS = {
	"hp_up": Color(0.9, 0.3, 0.3), "speed_up": Color(0.3, 0.8, 0.9),
	"damage_up": Color(1.0, 0.5, 0.2), "attack_speed": Color(0.9, 0.9, 0.3),
	"regen": Color(0.3, 0.9, 0.4), "xp_boost": Color(0.8, 0.6, 1.0),
	"thick_skin": Color(0.5, 0.65, 0.85), "iron_jaws": Color(1.0, 0.35, 0.2),
	"quick_paws": Color(0.4, 0.75, 1.0), "scavenger_nose": Color(0.85, 0.65, 0.3),
	"second_wind": Color(0.3, 1.0, 0.5), "bloodlust": Color(0.9, 0.15, 0.2),
	"bark_blast": Color(1.0, 0.75, 0.2), "shadow_step": Color(0.55, 0.3, 0.85),
	"thorns": Color(0.4, 0.75, 0.3), "lucky_find": Color(1.0, 0.84, 0.0),
}

const ALL_PERKS = [
	{"id":"hp_up",          "name":"+25 Max HP",        "desc":"Increase max health by 25",                    "base_val": 25.0},
	{"id":"speed_up",       "name":"+15% Speed",        "desc":"Move faster through the arena",                "base_val": 15.0},
	{"id":"damage_up",      "name":"+8 Attack Dmg",     "desc":"Auto-attacks hit harder",                      "base_val": 8.0},
	{"id":"attack_speed",   "name":"Faster Attacks",    "desc":"-12% attack cooldown",                         "base_val": 12.0},
	{"id":"regen",          "name":"Slow Regen",        "desc":"Regenerate 1% max HP every 3 seconds",         "base_val": 0.0},
	{"id":"xp_boost",       "name":"+25% XP",           "desc":"Gain more XP from kills",                      "base_val": 25.0},
	{"id":"thick_skin",     "name":"+8% Armor",         "desc":"Reduce all damage taken by 8%",                "base_val": 8.0},
	{"id":"iron_jaws",      "name":"+5% Crit",          "desc":"Bite attacks have a higher chance to crit",    "base_val": 5.0},
	{"id":"quick_paws",     "name":"Quick Paws",        "desc":"-20% dodge cooldown",                          "base_val": 20.0},
	{"id":"scavenger_nose", "name":"Scavenger",         "desc":"+30% pickup magnet range",                     "base_val": 30.0},
	{"id":"second_wind",    "name":"Second Wind",       "desc":"Heal 30% HP when health drops below 20% (once per run)", "base_val": 0.0},
	{"id":"bloodlust",      "name":"Bloodlust",         "desc":"Heal 3 HP on each kill",                       "base_val": 3.0},
	{"id":"bark_blast",     "name":"Bark Blast",        "desc":"+35% bite AoE radius — hit nearby enemies too", "base_val": 35.0},
	{"id":"shadow_step",    "name":"Shadow Step",       "desc":"+1s sneak duration and -20% sneak cooldown",   "base_val": 1.0},
	{"id":"thorns",         "name":"Thorns",            "desc":"Enemies take 12 damage when they hit you",     "base_val": 12.0},
	{"id":"lucky_find",     "name":"Lucky Find",        "desc":"+15% chance for chests to upgrade tier",       "base_val": 15.0},
]

# Diminishing returns: each repeat gives 70% of previous bonus
const DIMINISH_FACTOR = 0.7
# Hard floors per perk type
const DIMINISH_FLOORS = {
	"hp_up": 1.0, "speed_up": 3.0, "damage_up": 2.0,
	"attack_speed": 3.0, "xp_boost": 5.0,
	"thick_skin": 2.0, "iron_jaws": 1.0, "quick_paws": 3.0,
	"scavenger_nose": 5.0, "bloodlust": 1.0, "bark_blast": 5.0,
	"shadow_step": 0.3, "thorns": 3.0, "lucky_find": 3.0,
}

func _get_perk_pick_count(perk_id: String) -> int:
	var count = 0
	for p in GameState.active_perks:
		if p == perk_id:
			count += 1
	return count

func _get_diminished_value(perk_id: String, base_val: float) -> float:
	var picks = _get_perk_pick_count(perk_id)
	var val = base_val * pow(DIMINISH_FACTOR, picks)
	var floor_val = DIMINISH_FLOORS.get(perk_id, 1.0)
	return maxf(val, floor_val)

func _get_diminished_perk(perk: Dictionary) -> Dictionary:
	var p = perk.duplicate()
	# One-time perks don't diminish
	if p.id in ["regen", "second_wind"]:
		return p
	var base = p.get("base_val", 0.0)
	var diminished = _get_diminished_value(p.id, base)
	var picks = _get_perk_pick_count(p.id)
	if picks > 0:
		match p.id:
			"hp_up":
				var val = int(diminished)
				p.name = "+%d Max HP" % val
				p.desc = "Increase max health by %d" % val
			"speed_up":
				var val = int(diminished)
				p.name = "+%d%% Speed" % val
				p.desc = "Move faster through the arena"
			"damage_up":
				var val = int(maxf(diminished, 1.0))
				p.name = "+%d Attack Dmg" % val
				p.desc = "Auto-attacks hit harder"
			"attack_speed":
				var val = int(diminished)
				p.name = "-%d%% Cooldown" % val
				p.desc = "Attack faster"
			"xp_boost":
				var val = int(diminished)
				p.name = "+%d%% XP" % val
				p.desc = "Gain more XP from kills"
			"thick_skin":
				var val = int(diminished)
				p.name = "+%d%% Armor" % val
				p.desc = "Reduce all damage taken by %d%%" % val
			"iron_jaws":
				var val = int(maxf(diminished, 1.0))
				p.name = "+%d%% Crit" % val
				p.desc = "Bite attacks have a higher chance to crit"
			"quick_paws":
				var val = int(diminished)
				p.name = "-%d%% Dodge CD" % val
				p.desc = "Dodge cooldown reduced by %d%%" % val
			"scavenger_nose":
				var val = int(diminished)
				p.name = "+%d%% Magnet" % val
				p.desc = "Pickup range increased by %d%%" % val
			"bloodlust":
				var val = int(maxf(diminished, 1.0))
				p.name = "Bloodlust +%d" % val
				p.desc = "Heal %d HP on each kill" % val
			"bark_blast":
				var val = int(diminished)
				p.name = "+%d%% Bite AoE" % val
				p.desc = "Bite hits enemies in a wider area"
			"shadow_step":
				p.name = "Shadow Step"
				p.desc = "+%.1fs sneak duration, shorter cooldown" % diminished
			"thorns":
				var val = int(maxf(diminished, 1.0))
				p.name = "Thorns +%d" % val
				p.desc = "Enemies take %d damage when they hit you" % val
			"lucky_find":
				var val = int(diminished)
				p.name = "+%d%% Luck" % val
				p.desc = "%d%% chance for chests to upgrade tier" % val
	return p

# Card deck completion perks (only available when full deck is collected)
const CARD_PERKS = [
	{"id":"bug_swarm",   "name":"Bug Swarm",   "desc":"Summon critters that bite nearby enemies for 3 dmg/sec", "deck":"Critter",    "icon":"res://assets/sprites/ui/icon_bug_swarm.png"},
	{"id":"vine_snare",  "name":"Vine Snare",  "desc":"Roots sprout around you, slowing nearby enemies by 40%", "deck":"Overgrowth", "icon":"res://assets/sprites/ui/icon_vine_snare.png"},
]

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
	# Build stat perk pool with diminishing returns applied to names/descriptions
	var stat_pool: Array = []
	for p in ALL_PERKS:
		# One-time perks — don't offer if already active
		if p.id == "regen" and GameState.perk_regen_active:
			continue
		if p.id == "second_wind" and GameState.perk_second_wind:
			continue
		stat_pool.append(_get_diminished_perk(p))
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
	var slots_full = GameState.orbital_weapons.size() >= OrbitalDB.MAX_ORBITALS
	for wid in OrbitalDB.get_weapon_ids():
		var data = OrbitalDB.get_weapon_data(wid)
		var current_lvl = 0
		for ow in GameState.orbital_weapons:
			if ow.id == wid:
				current_lvl = ow.level
		# Skip weapons at max level
		if current_lvl >= OrbitalDB.MAX_LEVEL:
			continue
		# Skip unowned weapons if all 6 slots are full
		if slots_full and current_lvl == 0:
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

	# Guarantee at least 1 weapon choice if available
	var choices: Array = []
	if not weapon_pool.is_empty():
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

	# CRITICAL: Unpause IMMEDIATELY — not inside the tween callback.
	# If a scene change happens during the 0.6s tween, the callback never fires
	# and the tree stays paused forever, freezing the next scene.
	get_tree().paused = false
	var dismiss_tw = create_tween()
	dismiss_tw.tween_interval(0.4)
	dismiss_tw.tween_property(self, "modulate:a", 0.0, 0.2)
	dismiss_tw.tween_callback(func():
		hide()
		if perk.get("is_orbital", false):
			_apply_orbital(perk.weapon_id)
		else:
			GameState.active_perks.append(perk.id)
			_apply(perk.id)
		SaveManager.save_game()
	)

func _apply_orbital(wid: String) -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("add_orbital_weapon"):
		player.add_orbital_weapon(wid)

func _apply(id: String) -> void:
	var player = get_tree().get_first_node_in_group("player")
	# Diminished value is calculated BEFORE this pick is added to active_perks
	# (active_perks.append happens in _on_chosen before _apply, so subtract 1)
	var picks_before = _get_perk_pick_count(id) - 1  # -1 because already appended
	match id:
		"hp_up":
			var base = 25.0
			var val = int(maxf(base * pow(DIMINISH_FACTOR, picks_before), DIMINISH_FLOORS.get("hp_up", 1.0)))
			GameState.player_max_health += val
			GameState.heal(val)
		"speed_up":
			var base = 15.0
			var pct = maxf(base * pow(DIMINISH_FACTOR, picks_before), DIMINISH_FLOORS.get("speed_up", 3.0))
			GameState.perk_speed_multiplier *= (1.0 + pct / 100.0)
			if player and "SPEED" in player:
				player.SPEED = maxf(10.0, 90.0 * GameState.perk_speed_multiplier)
		"damage_up":
			var base = 8.0
			var val = int(maxf(base * pow(DIMINISH_FACTOR, picks_before), DIMINISH_FLOORS.get("damage_up", 2.0)))
			GameState.perk_damage_bonus += val
			if player and "AUTO_ATTACK_DAMAGE" in player:
				player.AUTO_ATTACK_DAMAGE = 8 + GameState.perk_damage_bonus
		"attack_speed":
			var base = 12.0
			var pct = maxf(base * pow(DIMINISH_FACTOR, picks_before), DIMINISH_FLOORS.get("attack_speed", 3.0))
			GameState.perk_attack_speed_multiplier *= (1.0 - pct / 100.0)
			var t = player.get_node_or_null("AttackTimer") as Timer if player else null
			if t:
				t.wait_time = maxf(0.18, 0.6 * GameState.perk_attack_speed_multiplier)
		"regen":
			GameState.perk_regen_active = true
			# Audit FP-17: delegate install to shared helper so arena + level-up
			# share one perk-regen install path (3s, 1% HP).
			var regen_arena = get_tree().current_scene
			if regen_arena:
				PerkEffects.install_perk_regen(regen_arena)
		"xp_boost":
			var base_xp = 25.0
			var pct_xp = maxf(base_xp * pow(DIMINISH_FACTOR, picks_before), DIMINISH_FLOORS.get("xp_boost", 5.0))
			GameState.perk_xp_multiplier *= (1.0 + pct_xp / 100.0)
		"thick_skin":
			var pct_ts = maxf(8.0 * pow(DIMINISH_FACTOR, picks_before), DIMINISH_FLOORS.get("thick_skin", 2.0))
			GameState.perk_damage_reduction = minf(0.35, GameState.perk_damage_reduction + pct_ts / 100.0)
		"iron_jaws":
			var val_ij = int(maxf(5.0 * pow(DIMINISH_FACTOR, picks_before), DIMINISH_FLOORS.get("iron_jaws", 1.0)))
			GameState.perk_crit_bonus += val_ij
		"quick_paws":
			var pct_qp = maxf(20.0 * pow(DIMINISH_FACTOR, picks_before), DIMINISH_FLOORS.get("quick_paws", 3.0))
			GameState.perk_dodge_cooldown_mult *= (1.0 - pct_qp / 100.0)
			if player and "LEAP_COOLDOWN" in player:
				player.LEAP_COOLDOWN = maxf(0.8, 1.5 * GameState.perk_dodge_cooldown_mult)
		"scavenger_nose":
			var pct_sn = maxf(30.0 * pow(DIMINISH_FACTOR, picks_before), DIMINISH_FLOORS.get("scavenger_nose", 5.0))
			GameState.perk_magnet_bonus += pct_sn / 100.0
		"second_wind":
			GameState.perk_second_wind = true
		"bloodlust":
			var val_bl = int(maxf(3.0 * pow(DIMINISH_FACTOR, picks_before), DIMINISH_FLOORS.get("bloodlust", 1.0)))
			GameState.perk_lifesteal += val_bl
		"bark_blast":
			var pct_bb = maxf(35.0 * pow(DIMINISH_FACTOR, picks_before), DIMINISH_FLOORS.get("bark_blast", 5.0))
			GameState.perk_bite_aoe_bonus += pct_bb / 100.0
		"shadow_step":
			var dur_ss = maxf(1.0 * pow(DIMINISH_FACTOR, picks_before), DIMINISH_FLOORS.get("shadow_step", 0.3))
			GameState.perk_sneak_duration_bonus += dur_ss
			GameState.perk_sneak_cooldown_mult *= 0.8
			if player and "SNEAK_MAX_DURATION" in player:
				player.SNEAK_MAX_DURATION = 3.0 + GameState.perk_sneak_duration_bonus
		"thorns":
			var val_th = int(maxf(12.0 * pow(DIMINISH_FACTOR, picks_before), DIMINISH_FLOORS.get("thorns", 3.0)))
			GameState.perk_thorns_damage += val_th
		"lucky_find":
			var pct_lf = maxf(15.0 * pow(DIMINISH_FACTOR, picks_before), DIMINISH_FLOORS.get("lucky_find", 3.0))
			GameState.perk_chest_upgrade_chance += pct_lf / 100.0
		"bug_swarm":
			# Critter deck bonus (audit FP-17): shared installer
			var bs_arena = get_tree().current_scene
			if bs_arena:
				PerkEffects.install_bug_swarm(bs_arena, player)
		"vine_snare":
			# Overgrowth deck bonus (audit FP-17): shared installer
			var vs_arena = get_tree().current_scene
			if vs_arena:
				PerkEffects.install_vine_snare(vs_arena, player)

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
