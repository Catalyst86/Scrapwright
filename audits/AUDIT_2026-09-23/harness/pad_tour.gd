extends Node
## PadTour — plays the core loop using ONLY synthesized gamepad events for every
## menu / popup interaction, and checks where focus lands at each step:
##   intro skip -> create profile -> NEW GAME -> tutorial (move + dodge steps)
##   -> hub (wheel routes, upgrade purchase, wardrobe, list tab, pause)
##   -> arena (stick + D-pad movement, level-up pick, pause, chest phase)
##   -> death -> game over -> hub -> Junkyard (pause, death, game-over panel) -> hub
## Harness assists that are NOT UI: the player is invincible until the scripted
## death, enemies are killed a second after they appear, one level-up is granted
## with XP, the hub is stocked with materials, and the tutorial is finished via
## its own _finish_tutorial() after the pad clears its first two steps.
## Inert unless run with `-- --pad_tour`. Harness only: NOT part of the game.
## WARNING: deletes save profiles 1-4 in the active user dir; see harness/README.md.

class ErrLogger extends Logger:
	var mutex := Mutex.new()
	var entries: Array = []

	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, script_backtraces: Array[ScriptBacktrace]) -> void:
		var bt := ""
		for b in script_backtraces:
			if b != null and not b.is_empty():
				bt = "%s:%d %s()" % [b.get_frame_file(0), b.get_frame_line(0), b.get_frame_function(0)]
				break
		mutex.lock()
		entries.append({"type": error_type, "func": function, "file": file, "line": line,
			"code": code, "why": rationale, "bt": bt})
		mutex.unlock()

	func _log_message(_message: String, _error: bool) -> void:
		pass

	func drain() -> Array:
		mutex.lock()
		var out := entries.duplicate()
		entries.clear()
		mutex.unlock()
		return out

const FPS := 60
const A := JOY_BUTTON_A
const B := JOY_BUTTON_B
const START := JOY_BUTTON_START
const UP := JOY_BUTTON_DPAD_UP
const DOWN := JOY_BUTTON_DPAD_DOWN
const LEFT := JOY_BUTTON_DPAD_LEFT
const RIGHT := JOY_BUTTON_DPAD_RIGHT

var _on := false
var _passes := 0
var _fails: Array = []
var _errors: Array = []
var _invincible := true
var _assist := false
var _stocked := false
var _seen: Dictionary = {}
var _frame := 0
var logger: ErrLogger


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not OS.get_cmdline_user_args().has("--pad_tour"):
		return
	# SAFETY: the tour starts from empty profile slots (it deletes 1-4) and presses
	# NEW GAME. Refuse to touch real save data.
	if not ProjectSettings.get_setting("application/config/use_custom_user_dir", false) \
			and not "--allow-real-userdata" in OS.get_cmdline_user_args():
		push_error("PadTour: refusing to run - it deletes save profiles. Use the override.cfg from harness/README.md (separate user dir), or pass --allow-real-userdata.")
		get_tree().quit(2)
		return
	for slot in range(1, 5):
		SaveManager.delete_profile(slot)
	_on = true
	logger = ErrLogger.new()
	OS.add_logger(logger)
	GameState.health_changed.connect(_on_health_changed)
	get_tree().node_added.connect(_on_node_added)
	print("PAD: tour starting")
	_tour.call_deferred()


func _process(_delta: float) -> void:
	if not _on:
		return
	_frame += 1
	_errors.append_array(logger.drain())
	if _assist and not get_tree().paused:
		for e in get_tree().get_nodes_in_group("enemies"):
			if not is_instance_valid(e) or e.get("is_dead") == true:
				continue
			var id := e.get_instance_id()
			if not _seen.has(id):
				_seen[id] = _frame
			elif _frame - _seen[id] > FPS:
				e.take_damage(99999999)


func _on_health_changed(cur, mx) -> void:
	# Synchronous inside take_damage, before its lethal check (like AuditBot)
	if _invincible and cur < mx * 0.5:
		GameState.player_health = mx


func _on_node_added(n: Node) -> void:
	if not _stocked and n.scene_file_path == "res://scenes/base_hub.tscn":
		_stocked = true
		for m in GameState.materials:
			GameState.materials[m] = 500


# ───────────────────────────────────────────────────────── helpers

func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _press(button: int, hold := 3) -> void:
	var down := InputEventJoypadButton.new()
	down.device = 0
	down.button_index = button
	down.pressed = true
	down.pressure = 1.0
	Input.parse_input_event(down)
	await _frames(hold)
	var up := InputEventJoypadButton.new()
	up.device = 0
	up.button_index = button
	up.pressed = false
	Input.parse_input_event(up)
	await _frames(4)


func _stick(axis: int, value: float) -> void:
	var ev := InputEventJoypadMotion.new()
	ev.device = 0
	ev.axis = axis
	ev.axis_value = value
	Input.parse_input_event(ev)


func _until(cond: Callable, seconds: float) -> bool:
	for i in int(seconds * FPS):
		if cond.call():
			return true
		await get_tree().process_frame
	return cond.call()


func _check(ok: bool, what: String, detail := "") -> bool:
	if ok:
		_passes += 1
		print("PAD PASS: ", what, ("   (" + detail + ")") if detail != "" else "")
	else:
		_fails.append(what + ("   [" + detail + "]" if detail != "" else ""))
		print("PAD FAIL: ", what, "   [", detail, "]")
	return ok


func _focus() -> Control:
	return get_viewport().gui_get_focus_owner()


func _desc(c) -> String:
	if c == null or not is_instance_valid(c):
		return "<no focus>"
	if c is Button and c.text != "":
		return "%s('%s')" % [c.get_class(), c.text]
	return "%s<%s>" % [c.name, c.get_class()]


func _scene() -> String:
	var cs := get_tree().current_scene
	return cs.scene_file_path.get_file() if cs else ""


func _is(c, want: String) -> bool:
	return c != null and is_instance_valid(c) and (c.name == want or (c is Button and c.text == want))


## Press a D-pad direction and check which control has focus afterwards.
func _nav(button: int, want: String, where: String) -> bool:
	await _press(button)
	var f := _focus()
	var dir: String = {UP: "up", DOWN: "down", LEFT: "left", RIGHT: "right"}.get(button, str(button))
	return _check(_is(f, want), "%s: %s -> %s" % [where, dir, want], _desc(f))


# ───────────────────────────────────────────────────────── the tour

func _tour() -> void:
	await _intro_and_menu()
	await _tutorial()
	await _hub_tour()
	await _arena_tour()
	await _junkyard_tour()
	_finish()


func _intro_and_menu() -> void:
	var ok := await _until(func(): return _scene() == "intro_video.tscn", 5)
	_check(ok, "boots into the intro", _scene())
	await _frames(45)  # The intro ignores input for its first 0.5 s
	await _press(A)
	ok = await _until(func(): return _scene() == "main_menu.tscn", 3)
	_check(ok, "intro: pad A skips to the main menu", _scene())
	await _frames(45)

	var f := _focus()
	_check(f is Button and f.text == "CREATE", "main menu: first empty profile slot's CREATE has focus", _desc(f))
	await _press(A)
	await _frames(3)
	f = _focus()
	_check(f is LineEdit, "create-profile popup: the name field has focus", _desc(f))
	_check(f is LineEdit and f.text == "Player 1", "create-profile popup: name is prefilled", f.text if f is LineEdit else "")
	await _press(A)
	await _frames(3)
	ok = SaveManager.current_profile_slot == 1
	_check(ok, "create-profile popup: pad A on the name field creates the profile", "slot=%d" % SaveManager.current_profile_slot)
	if not ok:
		# Fall back to D-pad onto CREATE so the rest of the tour can still run
		await _press(DOWN)
		await _press(A)
		await _frames(3)
	ok = await _until(func():
		var g := _focus()
		return g is Button and g.text == "NEW GAME", 2)
	_check(ok, "game menu: NEW GAME has focus once the profile is picked", _desc(_focus()))
	await _nav(DOWN, "OPTIONS", "game menu")
	await _nav(UP, "NEW GAME", "game menu")
	await _press(A)
	ok = await _until(func(): return _scene() == "tutorial_arena.tscn", 3)
	_check(ok, "NEW GAME with pad A starts the tutorial", _scene())


func _tutorial() -> void:
	var tut := get_tree().current_scene
	var ok := await _until(func(): return tut.get("_current_step") == 0 and tut.get("_step_active") == true, 8)
	_check(ok, "tutorial: MOVEMENT step is active", "step=%s" % tut.get("_current_step"))
	# Move with the left stick, turning around every second to stay in the room
	var dir := 1.0
	for i in 8:
		_stick(JOY_AXIS_LEFT_X, dir)
		if await _until(func(): return tut.get("_current_step") != 0, 1.0):
			break
		dir = -dir
	_stick(JOY_AXIS_LEFT_X, 0.0)
	ok = await _until(func(): return tut.get("_current_step") == 1 and tut.get("_step_active") == true, 6)
	_check(ok, "tutorial: left stick completes MOVEMENT", "step=%s" % tut.get("_current_step"))
	for i in 6:
		await _press(A)
		if await _until(func(): return tut.get("_current_step") != 1, 1.8):
			break
	_check(tut.get("_current_step") != 1, "tutorial: pad A dodges (DODGE step completed)", "step=%s reps=%s" % [tut.get("_current_step"), tut.get("_rep_count")])
	print("PAD: (harness) finishing the tutorial via _finish_tutorial()")
	tut._finish_tutorial()
	ok = await _until(func(): return _scene() == "base_hub.tscn", 4)
	_check(ok, "tutorial -> hub", _scene())


func _hub_tour() -> void:
	await _frames(30)
	var hub := get_tree().current_scene
	var f := _focus()
	_check(_is(f, "LeftCardSlot"), "hub: focus starts on the upgrade wheel", _desc(f))

	# Every route out of / around the wheel
	var w := "hub"
	await _nav(RIGHT, "RightCardSlot", w)
	await _nav(DOWN, "BottomCard3", w)
	await _nav(DOWN, "EnterDungeonBtn", w)
	await _nav(LEFT, "WardrobeBtn", w)
	await _nav(LEFT, "JunkyardBtn", w)
	await _nav(UP, "AchievementsBtn", w)
	await _nav(RIGHT, "BottomCard1", w)
	await _nav(UP, "LeftCardSlot", w)
	await _nav(UP, "BottomCard2", w)
	await _nav(RIGHT, "RightCardSlot", w)
	await _nav(RIGHT, "CardCollectionBtn", w)
	await _nav(UP, "SAVE", w)
	await _nav(DOWN, "CardCollectionBtn", w)
	await _nav(DOWN, "ArchiveBtn", w)
	await _nav(LEFT, "BottomCard3", w)
	await _nav(LEFT, "BottomCard1", w)
	await _nav(LEFT, "AchievementsBtn", w)
	await _nav(UP, "DenUpgradesBtn", w)
	await _nav(RIGHT, "LeftCardSlot", w)

	# Upgrade detail panel: open, buy, stay inside, close
	await _press(A)
	await _frames(3)
	var panel: Control = hub.get("_detail_panel")
	f = _focus()
	_check(panel != null and is_instance_valid(panel), "detail panel: pad A on a category opens it")
	_check(f is Button and f.text == "UPGRADE" and panel.is_ancestor_of(f), "detail panel: focus starts on an affordable UPGRADE", _desc(f))
	var levels_before := _upgrade_levels()
	await _press(A)
	await _frames(3)
	var levels_after := _upgrade_levels()
	var bought := ""
	for k in levels_after:
		if levels_after[k] != levels_before.get(k, 0):
			bought = k
	_check(bought != "", "detail panel: pad A buys the upgrade", "bought=%s" % bought)
	panel = hub.get("_detail_panel")
	f = _focus()
	_check(f is Button and f.text == "UPGRADE" and panel.is_ancestor_of(f), "detail panel: focus stays on UPGRADE after the rebuild", _desc(f))
	await _press(A)
	await _frames(3)
	var levels_third := _upgrade_levels()
	_check(levels_third.get(bought, 0) == levels_after.get(bought, 0) + 1, "detail panel: a second press buys the SAME upgrade again", "%s %s -> %s" % [bought, levels_after.get(bought), levels_third.get(bought)])
	var escaped := ""
	for b in [DOWN, DOWN, DOWN, DOWN, DOWN, UP, UP, UP, UP, UP, UP, LEFT, RIGHT]:
		await _press(b)
		panel = hub.get("_detail_panel")
		f = _focus()
		if f == null or panel == null or not panel.is_ancestor_of(f):
			escaped = _desc(f)
			break
	_check(escaped == "", "detail panel: D-pad can't leave the panel", escaped)
	await _press(B)
	await _frames(3)
	panel = hub.get("_detail_panel")
	_check(panel == null, "detail panel: B closes it")
	f = _focus()
	_check(_is(f, "LeftCardSlot"), "detail panel: focus returns to its category", _desc(f))

	# Wardrobe popup
	await _nav(DOWN, "BottomCard1", w)
	await _nav(DOWN, "WardrobeBtn", w)
	await _press(A)
	await _frames(3)
	var overlay: Control = hub.get("_overlay_panel")
	f = _focus()
	_check(overlay != null and is_instance_valid(overlay), "wardrobe: pad A opens it")
	_check(f != null and overlay != null and overlay.is_ancestor_of(f), "wardrobe: focus starts inside the popup", _desc(f))
	escaped = ""
	for b in [RIGHT, RIGHT, DOWN, DOWN, DOWN, DOWN, LEFT, UP, UP, UP, UP, UP]:
		await _press(b)
		overlay = hub.get("_overlay_panel")
		f = _focus()
		if f == null or overlay == null or not overlay.is_ancestor_of(f):
			escaped = _desc(f)
			break
	_check(escaped == "", "wardrobe: D-pad can't leave the popup", escaped)
	# Equip something with A if a Stats / Look button has focus
	f = _focus()
	if f is Button and f.text in ["Stats", "Look"]:
		var before := [GameState.equipped_armor_stat, GameState.equipped_armor_visual]
		await _press(A)
		await _frames(3)
		overlay = hub.get("_overlay_panel")
		f = _focus()
		_check([GameState.equipped_armor_stat, GameState.equipped_armor_visual] != before, "wardrobe: pad A equips", "%s -> %s" % [before, [GameState.equipped_armor_stat, GameState.equipped_armor_visual]])
		_check(f != null and overlay != null and overlay.is_ancestor_of(f), "wardrobe: focus stays in the rebuilt popup", _desc(f))
	else:
		print("PAD: (no Stats/Look button focused in the wardrobe: ", _desc(f), ")")
	await _press(B)
	await _frames(12)
	overlay = hub.get("_overlay_panel")
	f = _focus()
	_check(overlay == null, "wardrobe: B closes it")
	_check(_is(f, "WardrobeBtn"), "wardrobe: focus returns to the WARDROBE button", _desc(f))

	# A list tab: scroll with the pad, back out with B
	await _nav(LEFT, "JunkyardBtn", w)
	await _nav(UP, "AchievementsBtn", w)
	await _press(A)
	await _frames(3)
	var scrolls: Dictionary = hub.get("_tab_scrolls")
	var list: ScrollContainer = scrolls.get("achievements")
	f = _focus()
	_check(list != null and f == list, "achievements tab: pad A moves focus into the list", _desc(f))
	var v0 := list.scroll_vertical if list else 0
	var hold := InputEventJoypadButton.new()
	hold.device = 0
	hold.button_index = DOWN
	hold.pressed = true
	Input.parse_input_event(hold)
	await _frames(30)
	var release := InputEventJoypadButton.new()
	release.device = 0
	release.button_index = DOWN
	release.pressed = false
	Input.parse_input_event(release)
	await _frames(3)
	_check(list != null and list.scroll_vertical > v0 + 50 and _focus() == list, "achievements tab: holding D-pad down scrolls the list", "scroll %d -> %d" % [v0, list.scroll_vertical if list else -1])
	_stick(JOY_AXIS_LEFT_Y, -1.0)
	await _frames(20)
	_stick(JOY_AXIS_LEFT_Y, 0.0)
	await _frames(3)
	_check(list != null and list.scroll_vertical < v0 + 300 and _focus() == list, "achievements tab: left stick up scrolls back", "scroll now %d" % [list.scroll_vertical if list else -1])
	await _press(B)
	await _frames(3)
	_check(_is(_focus(), "AchievementsBtn"), "achievements tab: B returns focus to the tab button", _desc(_focus()))
	await _nav(UP, "DenUpgradesBtn", w)
	await _press(A)
	await _frames(3)
	_check(_is(_focus(), "LeftCardSlot"), "den tab: pad A goes back to the wheel", _desc(_focus()))

	# Pause from the hub and back
	await _press(START)
	await _frames(3)
	var pm = hub.get("_pause_menu")
	_check(pm != null and pm.is_open and get_tree().paused, "hub: Start opens the pause menu")
	_check(_is(_focus(), "RESUME"), "hub pause: RESUME has focus", _desc(_focus()))
	_stick(JOY_AXIS_LEFT_Y, 1.0)
	await _frames(3)
	_stick(JOY_AXIS_LEFT_Y, 0.0)
	await _frames(3)
	_check(_is(_focus(), "SAVE GAME"), "hub pause: left stick down moves to SAVE GAME", _desc(_focus()))
	await _press(B)
	await _frames(3)
	_check(pm != null and not pm.is_open and not get_tree().paused, "hub pause: B resumes")
	_check(_is(_focus(), "LeftCardSlot"), "hub pause: focus handed back to the wheel", _desc(_focus()))
	await _press(START)
	await _press(START)
	await _frames(3)
	var layers := 0
	for c in hub.get_children():
		if c.get_script() == load("res://scripts/pause_menu.gd"):
			layers += 1
	_check(layers == 1, "hub pause: one reused menu instance (no leak per Esc)", "instances=%d" % layers)

	# Into the dungeon
	await _nav(DOWN, "BottomCard1", w)
	await _nav(RIGHT, "BottomCard3", w)
	await _nav(DOWN, "EnterDungeonBtn", w)
	await _press(A)
	var ok := await _until(func(): return _scene() == "arena.tscn", 3)
	_check(ok, "hub: pad A on ENTER DUNGEON starts the run", _scene())


func _upgrade_levels() -> Dictionary:
	var out := {}
	for k in GameState.permanent:
		out[k] = GameState.permanent[k]
	return out


func _player() -> Node2D:
	return get_tree().get_first_node_in_group("player") as Node2D


func _arena_tour() -> void:
	var arena := get_tree().current_scene
	await _frames(60)
	var p := _player()
	_check(p != null, "arena: player found")
	if p == null:
		return
	# Movement: left stick, then D-pad
	var x0 := p.global_position.x
	_stick(JOY_AXIS_LEFT_X, 1.0)
	await _frames(40)
	_stick(JOY_AXIS_LEFT_X, 0.0)
	await _frames(3)
	_check(p.global_position.x > x0 + 15.0, "arena: left stick moves the dog", "dx=%.1f" % (p.global_position.x - x0))
	var y0 := p.global_position.y
	var hold := InputEventJoypadButton.new()
	hold.device = 0
	hold.button_index = DOWN
	hold.pressed = true
	Input.parse_input_event(hold)
	await _frames(40)
	var rel := hold.duplicate()
	rel.pressed = false
	Input.parse_input_event(rel)
	await _frames(3)
	_check(p.global_position.y > y0 + 15.0, "arena: D-pad moves the dog", "dy=%.1f" % (p.global_position.y - y0))

	# Pause mid-combat
	await _press(START)
	await _frames(3)
	var pm = arena.get("_pause_menu")
	_check(pm != null and pm.is_open and get_tree().paused, "arena: Start pauses")
	_check(_is(_focus(), "RESUME"), "arena pause: RESUME has focus", _desc(_focus()))
	await _press(A)
	await _frames(3)
	_check(pm != null and not pm.is_open and not get_tree().paused, "arena pause: pad A on RESUME resumes")
	_check(_focus() == null, "arena: nothing keeps UI focus in combat", _desc(_focus()))
	var leapt := false
	var down_a := InputEventJoypadButton.new()
	down_a.device = 0
	down_a.button_index = A
	down_a.pressed = true
	Input.parse_input_event(down_a)
	for i in 10:
		await _frames(1)
		leapt = leapt or p.get("_is_leaping") == true
	var up_a := down_a.duplicate()
	up_a.pressed = false
	Input.parse_input_event(up_a)
	await _frames(3)
	_check(leapt, "arena: pad A dodges in combat")

	# Level-up (granted with XP), picked with the pad
	_assist = true
	var lu: Control = arena.get("level_up_screen")
	GameState.gain_xp(GameState.xp_to_next_level)
	var ok := await _until(func(): return lu.visible, 3)
	_check(ok, "arena: level-up screen appears")
	var btns: Array = lu.get("_select_buttons")
	ok = await _until(func(): return not btns.is_empty() and not btns[0].disabled and _focus() in btns, 2)
	_check(ok, "level-up: the first SELECT has focus once armed", _desc(_focus()))
	if btns.size() > 1:
		await _press(RIGHT)
		_check(_focus() in btns and _focus() != btns[0], "level-up: D-pad right moves to another card", _desc(_focus()))
	var sig := str(GameState.active_perks) + str(GameState.orbital_weapons)
	await _press(A)
	ok = await _until(func(): return not lu.visible and not get_tree().paused, 3)
	_check(ok, "level-up: pad A picks a card and the game resumes")
	_check(str(GameState.active_perks) + str(GameState.orbital_weapons) != sig, "level-up: the perk was applied")

	# Chest phase: follow focus and press A until the next wave starts. One key,
	# so a chest can actually be opened from the pad.
	GameState.add_key("bronze")
	ok = await _until(func(): return arena.get("arena_phase") == 2, 40)
	_check(ok, "arena: wave 1 cleared -> chest phase", "phase=%s wave=%d" % [arena.get("arena_phase"), WaveManager.current_wave])
	var wave_before := GameState.current_wave
	var pressed: Array = []
	for i in 12:
		await _frames(30)
		if arena.get("arena_phase") != 2:
			break
		var f := _focus()
		if f is BaseButton and not f.disabled and f.is_visible_in_tree():
			pressed.append(_desc(f))
			await _press(A)
		else:
			pressed.append("(nothing focusable: %s)" % _desc(f))
	ok = await _until(func(): return arena.get("arena_phase") != 2, 3)
	_check(ok, "chest phase: finished using only pad A on focused buttons", "pressed %s" % [pressed])
	_check(GameState.get_key_count("bronze") == 0, "chest phase: the key was used on a chest", "bronze keys left=%d" % GameState.get_key_count("bronze"))
	ok = await _until(func(): return WaveManager.wave_active, 6)
	_check(ok, "chest phase: the next wave starts", "wave %d -> %d" % [wave_before, WaveManager.current_wave])
	await _frames(30)
	_check(_focus() == null, "next wave: no chest button keeps focus (pad A dodges again)", _desc(_focus()))

	# Death -> game over -> hub (through the player's own damage path)
	_assist = false
	_invincible = false
	for i in 6:
		if _scene() != "arena.tscn" or p.get("is_dead") == true:
			break
		p.take_damage(99999)
		await _frames(20)
	ok = await _until(func(): return _scene() == "game_over.tscn", 10)
	_check(ok, "arena: death leads to Game Over", _scene())
	await _frames(20)
	var f := _focus()
	_check(f is Button and f.text in ["RETRY", "RETURN TO HUB"], "game over: a button has focus", _desc(f))
	if f is Button and f.text == "RETRY":
		await _nav(DOWN, "RETURN TO HUB", "game over")
	await _press(A)
	ok = await _until(func(): return _scene() == "base_hub.tscn", 4)
	_check(ok, "game over: pad A on RETURN TO HUB", _scene())
	_invincible = true
	_assist = false


func _junkyard_tour() -> void:
	await _frames(40)
	var f := _focus()
	_check(_is(f, "LeftCardSlot"), "hub (2nd visit): focus on the wheel", _desc(f))
	await _nav(DOWN, "BottomCard1", "hub")
	await _nav(DOWN, "WardrobeBtn", "hub")
	await _nav(LEFT, "JunkyardBtn", "hub")
	await _press(A)
	var ok := await _until(func(): return _scene() == "junkyard.tscn", 3)
	_check(ok, "hub: pad A on JUNKYARD enters it", _scene())
	await _frames(60)
	var jy := get_tree().current_scene
	await _press(START)
	await _frames(3)
	var pm = jy.get("_pause_menu")
	_check(pm != null and pm.is_open and get_tree().paused, "junkyard: Start pauses")
	_check(_is(_focus(), "RESUME"), "junkyard pause: RESUME has focus", _desc(_focus()))
	await _press(B)
	await _frames(3)
	_check(pm != null and not pm.is_open and not get_tree().paused, "junkyard pause: B resumes")
	_invincible = false
	var jp := _player()
	for i in 6:
		if jy.get("phase") == 2 or jp == null:  # JYPhase.GAME_OVER
			break
		jp.take_damage(99999)
		await _frames(20)
	_check(jy.get("phase") == 2, "junkyard: the dog died", "phase=%s" % jy.get("phase"))
	await _press(START)  # Pausing after death must not open the menu under the game-over panel
	await _frames(3)
	_check(pm != null and not pm.is_open, "junkyard: Start after death does not open the pause menu")
	ok = await _until(func():
		var g := _focus()
		return g is Button and g.text == "RETURN TO HUB", 6)
	_check(ok, "junkyard game over: RETURN TO HUB has focus", _desc(_focus()))
	await _press(A)
	ok = await _until(func(): return _scene() == "base_hub.tscn", 4)
	_check(ok, "junkyard game over: pad A returns to the hub", _scene())
	await _frames(40)
	_check(_is(_focus(), "LeftCardSlot"), "hub (3rd visit): focus on the wheel", _desc(_focus()))


func _finish() -> void:
	_errors.append_array(logger.drain())
	var real := _errors.filter(func(e): return e.type != 1)  # ERROR_TYPE_WARNING == 1
	print("\n==================== PAD TOUR SUMMARY ====================")
	print("checks passed: %d   failed: %d" % [_passes, _fails.size()])
	for s in _fails:
		print("  FAIL ", s)
	print("engine errors: %d (+%d warnings)" % [real.size(), _errors.size() - real.size()])
	var seen := {}
	for e in _errors:
		var where: String = e.bt if e.bt != "" else "%s:%d" % [e.file, e.line]
		var key := "%s | %s" % [where, (e.why if e.why != "" else e.code).left(160)]
		seen[key] = seen.get(key, 0) + 1
	for k in seen:
		print("  x%d %s" % [seen[k], k])
	print("PAD RESULT: ", "PASS" if _fails.is_empty() and real.is_empty() else "FAIL")
	get_tree().quit()
