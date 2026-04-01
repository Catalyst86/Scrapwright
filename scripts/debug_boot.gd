extends Control

# ============================================================
# DEBUG BOOT — Startup diagnostic. Main scene while debugging.
# project.godot: run/main_scene = "res://scenes/debug_boot.tscn"
# ============================================================

var _label: Label
var _scroll: ScrollContainer
var _lines: Array = []

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var bg = ColorRect.new()
	bg.color = Color(0.05, 0.05, 0.05)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 2)
	vbox.offset_left = 6; vbox.offset_right = -6
	vbox.offset_top  = 4; vbox.offset_bottom = -4
	add_child(vbox)

	var title = Label.new()
	title.text = "SCRAPWRIGHT  —  DEBUG BOOT"
	title.add_theme_font_size_override("font_size", 11)
	title.modulate = Color(1.0, 0.8, 0.2)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_scroll)

	_label = Label.new()
	_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label.add_theme_font_size_override("font_size", 8)
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_scroll.add_child(_label)

	var btn = Button.new()
	btn.text = "START GAME"
	btn.add_theme_font_size_override("font_size", 10)
	btn.pressed.connect(_go)
	vbox.add_child(btn)

	await get_tree().process_frame
	await get_tree().process_frame
	_run_checks()

func _run_checks() -> void:
	_h("AUTOLOADS")
	var gs  = _chk("GameState",  "/root/GameState")
	var cdb = _chk("CraftingDB", "/root/CraftingDB")
	_chk("WaveManager", "/root/WaveManager")
	_chk("SaveManager", "/root/SaveManager")

	if gs:
		_ok("  GS.materials  is Dict",  gs.get("materials")  is Dictionary)
		_ok("  GS.permanent  is Dict",  gs.get("permanent")  is Dictionary)
		var phase_val = gs.get("Phase")
		_ok("  GS.Phase enum exists",   phase_val != null)
		if phase_val is Dictionary:
			_ok("  GS.Phase has ARENA_COMBAT", "ARENA_COMBAT" in phase_val)

	_h("SCENES")
	for s in [
		"res://scenes/main_menu.tscn",
		"res://scenes/base_hub.tscn",
		"res://scenes/arena.tscn",
		"res://scenes/player.tscn",
		"res://scenes/level_up.tscn",
		"res://scenes/game_over.tscn",
		"res://scenes/material_pickup.tscn",
		"res://scenes/enemies/enemy_rusher.tscn",
		"res://scenes/enemies/enemy_shooter.tscn",
		"res://scenes/enemies/enemy_tank.tscn",
		"res://scenes/enemies/enemy_flyer.tscn",
		"res://scenes/enemies/enemy_exploder.tscn",
	]:
		_ok("  " + s.get_file(), ResourceLoader.exists(s))

	_h("SPRITES (optional)")
	for s in [
		"res://assets/sprites/player/player_idle.png",
		"res://assets/sprites/enemies/enemy_rusher.png",
	]:
		if ResourceLoader.exists(s):
			_log("  [HAVE] " + s.get_file(), Color(0.3, 1.0, 0.4))
		else:
			_log("  [MISS] " + s.get_file() + " (placeholders active)", Color(0.8, 0.8, 0.3))

	_h("DONE — all [FAIL] lines above need fixing before START GAME")
	await get_tree().process_frame
	if _scroll: _scroll.scroll_vertical = 999999

# ── helpers ─────────────────────────────────────────────────

func _chk(lbl: String, path: String) -> Node:
	var n = get_node_or_null(path)
	_log(("  [OK]   " if n else "  [FAIL] ") + lbl, Color(0.3,1,0.4) if n else Color(1,0.3,0.3))
	return n

func _ok(lbl: String, result: bool) -> void:
	_log(("  [OK]   " if result else "  [FAIL] ") + lbl, Color(0.3,1,0.4) if result else Color(1,0.3,0.3))

func _h(text: String) -> void:
	_log("── " + text + " ──", Color(1.0, 0.8, 0.2))

func _log(text: String, color: Color = Color.WHITE) -> void:
	_lines.append([text, color])
	if _label:
		var full := ""
		for l in _lines: full += l[0] + "\n"
		_label.text = full

func _go() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
