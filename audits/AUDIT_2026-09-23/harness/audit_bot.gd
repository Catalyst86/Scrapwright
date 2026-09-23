extends Node
## AuditBot — autoplay harness used for the 2026-09-23 audit. NOT part of the game.
## WARNING: deletes save profiles 1-4 in the active user dir; see harness/README.md.
## Drives menus/popups, keeps the player alive (synchronously, so all damage
## code still runs), kills enemies after a short life, and records per-wave
## telemetry plus every engine error tagged with the wave it happened in.
##
## Scenarios (pass after `--`):
##   --scenario=full_run      play from hub to credits (or --max_wave)
##   --scenario=levelup_race  queue 3 level-ups, click one card, inspect state
##   --scenario=double_click  one level-up, click two SELECT buttons 1 frame apart
##   --scenario=death_cycle   die on wave 3 (with 1 extra life), retry, die, new run; diff stats
##   --scenario=save_roundtrip save mid-run, wipe, load, diff every GameState var

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

const OUT_DIR := "user://audit_bot/"

var scenario := "full_run"
var _start_wave := 0
var _stress_n := 150
var max_wave := 84
var logger: ErrLogger
var t := 0.0
var invincible := true
var _done := false

# error aggregation
var errors: Dictionary = {}   # key -> {count, first_wave, first_t, sample}
var error_total := 0

# arena driving state
var enemy_seen: Dictionary = {}
var enemy_kill_at: Dictionary = {}
var _last_scene := ""
var _scene_entered_at := 0.0
var _hub_started := false
var _last_card_key := -1
var _seen_card_key := -1
var _card_seen_at := 0.0
var _in_chest := false
var _chest_seen_at := 0.0
var _paused_since := -1.0
var _wave_started_at := 0.0
var _max_proc_ms := 0.0
var _max_enemies := 0
var _last_wave_active := false

# telemetry
var wave_rows: Array = []
var softlocks: Array = []
var notes: Array = []
var levelups_chosen := 0
var chest_phases := 0
var hub_visits := 0
var _stats_before_hub: Dictionary = {}
var _levels_gained_total := 0
var _last_level_seen := 1

# scenario state
var _step := 0
var _step_t := 0.0
var _scratch: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--scenario="):
			scenario = a.get_slice("=", 1)
		elif a.begins_with("--n="):
			_stress_n = int(a.get_slice("=", 1))
		elif a.begins_with("--start_wave="):
			_start_wave = int(a.get_slice("=", 1))
		elif a.begins_with("--max_wave="):
			max_wave = int(a.get_slice("=", 1))
	if scenario == "none":
		_done = true
		return
	# SAFETY: the bot deletes save profiles 1-4. Refuse to touch real save data.
	if not ProjectSettings.get_setting("application/config/use_custom_user_dir", false) \
			and not "--allow-real-userdata" in OS.get_cmdline_user_args():
		push_error("AuditBot: refusing to run - it deletes save profiles. Use the override.cfg from harness/README.md (separate user dir), or pass --allow-real-userdata.")
		_done = true
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	logger = ErrLogger.new()
	OS.add_logger(logger)
	GameState.health_changed.connect(_on_health_changed)
	WaveManager.wave_complete.connect(_on_wave_complete_bot)
	get_tree().node_added.connect(_on_node_added)
	print("BOT: scenario=%s max_wave=%d" % [scenario, max_wave])
	call_deferred("_begin")


func _on_health_changed(cur, mx) -> void:
	# Runs synchronously inside GameState.take_damage's emit, BEFORE its lethal
	# check, so the player never dies but every damage path still executes.
	if invincible and cur < mx * 0.5:
		GameState.player_health = mx


func _begin() -> void:
	for s in range(1, 5):
		SaveManager.delete_profile(s)
	SaveManager.create_profile(1, "Bot")
	GameState.tutorial_completed = true
	var p: Dictionary = GameState.permanent
	match scenario:
		"full_run":
			# Mid-game meta progress so more systems are exercised.
			p["reroll_level"] = 2
			p["perk_choices_level"] = 1
			p["pickup_magnet_level"] = 2
			p["mutation_junkyard_chimera"] = 1
			p["health_regen_level"] = 2
			p["dig_charges_level"] = 1
			p["bite_damage_level"] = 2
			p["max_hp_level"] = 2
			p["xp_gain_level"] = 2
		"hub_return":
			p["mutation_junkyard_chimera"] = 1
		"hub_quit", "junkyard_save", "profile_bleed":
			for m in GameState.materials:
				GameState.materials[m] = 60
			if scenario == "profile_bleed":
				GameState.permanent["bite_damage_level"] = 5
		"death_cycle":
			p["mutation_feral_howl"] = 1   # "Bad Dog": 1 extra life
			p["max_hp_level"] = 3
			p["bite_damage_level"] = 3
	SaveManager.save_game()
	get_tree().change_scene_to_file("res://scenes/base_hub.tscn")


# ───────────────────────────────────────────────────────── main loop

func _process(delta: float) -> void:
	if _done:
		return
	t += delta
	var pt := Performance.get_monitor(Performance.TIME_PROCESS) + Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
	_max_proc_ms = maxf(_max_proc_ms, pt * 1000.0)
	_collect_errors()
	if GameState.player_level > _last_level_seen:
		_levels_gained_total += GameState.player_level - _last_level_seen
	_last_level_seen = GameState.player_level

	var cs := get_tree().current_scene
	if cs == null:
		return
	var path := cs.scene_file_path
	if path != _last_scene:
		print("BOT: t=%.1f scene -> %s  (GS.wave=%d lvl=%d paused=%s)" % [t, path.get_file(), GameState.current_wave, GameState.player_level, get_tree().paused])
		_last_scene = path
		_scene_entered_at = t
		_hub_started = false
		enemy_seen.clear()
		enemy_kill_at.clear()
		_step_t = t
	match path:
		"res://scenes/base_hub.tscn":
			_drive_hub(cs)
		"res://scenes/arena.tscn":
			match scenario:
				"levelup_race": _scenario_levelup_race(cs)
				"double_click": _scenario_double_click(cs)
				"death_cycle": _scenario_death_cycle(cs, delta)
				"save_roundtrip": _scenario_save_roundtrip(cs, delta)
				"double_collect", "single_collect": _scenario_collect(cs, delta)
				"hub_return": _scenario_hub_return(cs, delta)
				"pause_damage": _scenario_pause_damage(cs)
				"clear_window_death": _scenario_clear_window_death(cs, delta)
				"death_esc": _scenario_death_esc(cs, delta)
				"stress": _scenario_stress(cs, delta)
				"profile_bleed":
					if t - _scene_entered_at > 3.0 and not _scratch.has("quit1"):
						_scratch["quit1"] = true
						print("BOT[bleed]: profile 1 in arena (wave-start snapshot taken) | mem=%s" % [_mem()])
						arena_quit(cs)
				_: _drive_arena(cs, delta)
		"res://scenes/game_over.tscn":
			_drive_game_over(cs)
		"res://scenes/main_menu.tscn":
			if scenario == "profile_bleed" and t - _scene_entered_at > 1.0 and not _scratch.has("mm_%d" % int(_scene_entered_at)):
				_scratch["mm_%d" % int(_scene_entered_at)] = true
				if not _scratch.has("p2"):
					_scratch["p2"] = true
					SaveManager.create_profile(2, "Sibling")   # fresh profile: selects + loads it
					print("BOT[bleed]: created+selected fresh profile 2 | mem=%s" % [_mem()])
					print("BOT[bleed]:                                 | disk(p2)=%s" % [_disk()])
					GameState.set_phase(GameState.Phase.BASE_HUB)
					get_tree().change_scene_to_file("res://scenes/base_hub.tscn")   # what Continue/New Game does
				else:
					print("BOT[bleed]: back at main menu after hub QUIT TO MENU on profile 2 | mem=%s" % [_mem()])
					print("BOT[bleed]:                                                   | disk(p2)=%s" % [_disk()])
					_finish("profile_bleed done")
			if scenario == "hub_quit" and t - _scene_entered_at > 1.0:
				print("BOT[hub_quit]: at MAIN MENU after quit | mem=%s" % [_mem()])
				print("BOT[hub_quit]:                         | disk=%s" % [_disk()])
				_finish("hub_quit done")
		"res://scenes/credits.tscn":
			if t - _scene_entered_at > 2.0:
				_finish("CREDITS reached")
	if t > 60.0 * 200.0:
		_finish("TIMEOUT (game time)")


# ───────────────────────────────────────────────────────── hub

func _disk() -> Dictionary:
	var c := ConfigFile.new()
	c.load(SaveManager.get_save_path())
	var mats := {}
	if c.has_section("materials"):
		for k in c.get_section_keys("materials"):
			mats[k] = c.get_value("materials", k)
	return {"bite_damage_level": c.get_value("permanent", "bite_damage_level", "?"), "max_hp_level": c.get_value("permanent", "max_hp_level", "?"),
		"current_wave": c.get_value("run", "current_wave", "?"), "run_in_progress": c.get_value("run", "in_progress", "?"), "materials": mats}


func _mem() -> Dictionary:
	return {"bite_damage_level": GameState.permanent.get("bite_damage_level"), "max_hp_level": GameState.permanent.get("max_hp_level"),
		"current_wave": GameState.current_wave, "run_in_progress": GameState.run_in_progress, "materials": GameState.materials.duplicate()}


func _drive_hub(hub: Node) -> void:
	if _hub_started or t - _scene_entered_at < 1.0:
		return
	if scenario == "profile_bleed" and hub_visits == 1:
		_hub_started = true
		hub_visits += 1
		print("BOT[bleed]: profile 2 hub, pressing ESC -> QUIT TO MENU | mem=%s" % [_mem()])
		var pz = load("res://scripts/pause_menu.gd").new()
		hub.add_child(pz)
		pz.open()
		pz._quit_to_menu()
		return
	if scenario in ["hub_quit", "junkyard_save"] and hub_visits == 1:
		_hub_started = true
		hub_visits += 1
		print("BOT[%s]: hub after boss wave 7 | mem=%s" % [scenario, _mem()])
		print("BOT[%s]:                          | disk=%s" % [scenario, _disk()])
		if scenario == "hub_quit":
			var ok1 = UpgradeDB.purchase_upgrade("bite_damage")
			var ok2 = UpgradeDB.purchase_upgrade("max_hp")
			print("BOT[hub_quit]: bought bite_damage=%s max_hp=%s | mem=%s" % [ok1, ok2, _mem()])
			print("BOT[hub_quit]:                               | disk=%s" % [_disk()])
			var pause = load("res://scripts/pause_menu.gd").new()   # exactly what base_hub._unhandled_input does on ESC
			hub.add_child(pause)
			pause.open()
			print("BOT[hub_quit]: pressing QUIT TO MENU from the hub pause menu")
			pause._quit_to_menu()
		else:
			hub._enter_junkyard()
			print("BOT[junkyard_save]: right after ENTER JUNKYARD | mem=%s" % [_mem()])
			print("BOT[junkyard_save]:                            | disk=%s" % [_disk()])
			var snap: Dictionary = JunkyardState._snapshot
			print("BOT[junkyard_save]: real stockpile now lives only in RAM: JunkyardState._snapshot.materials=%s run_in_progress=%s" % [snap.get("materials"), snap.get("run_in_progress")])
			_finish("junkyard_save done")
		return
	_hub_started = true
	hub_visits += 1
	var before := _snap_stats()
	if scenario == "hub_return" and hub_visits == 2:
		_stats_before_hub = {}
		print("BOT[hub]: at hub entry (after boss chests): ", before)
	hub._start_run()
	var after := _snap_stats()
	if scenario == "death_cycle":
		if hub_visits == 1:
			_scratch["run1_start"] = after
		elif hub_visits >= 2:
			_diff_stats("run #1 start -> run #2 start (after death + new run)", _scratch["run1_start"], after)
			print("BOT[death]: run2 start: ", after)
			call_deferred("_finish", "death_cycle done")
	if scenario in ["hub_quit", "junkyard_save"] and hub_visits == 1:
		GameState.current_wave = 6
	if scenario == "stress" and hub_visits == 1:
		GameState.current_wave = 79
	if scenario == "full_run" and hub_visits == 1 and _start_wave > 0:
		GameState.current_wave = _start_wave - 1
	if scenario == "hub_return" and hub_visits == 1:
		# Replace whatever random chimera was rolled with Iron Stomach (+20 dmg), exactly as _apply_chimera_buff does.
		var cb: Dictionary = GameState.chimera_buff
		match cb.get("effect", ""):
			"damage": GameState.perk_damage_bonus -= int(cb.value)
			"speed": GameState.perk_speed_multiplier -= cb.value
			"max_hp":
				GameState.player_max_health -= int(cb.value)
				GameState.player_health = GameState.player_max_health
			"attack_speed": GameState.perk_attack_speed_multiplier /= (1.0 - cb.value)
			"xp": GameState.perk_xp_multiplier -= cb.value
		GameState.chimera_buff = UpgradeDB.CHIMERA_BUFFS[0]
		GameState.perk_damage_bonus += 20
		GameState.current_wave = 6   # next arena plays wave 7 (mid-boss)
		after = _snap_stats()
		print("BOT[hub]: forced chimera=Iron Stomach, jumping to wave 7: ", after)
	print("BOT: hub visit %d -> _start_run()  run_in_progress=%s" % [hub_visits, GameState.run_in_progress])
	if not _stats_before_hub.is_empty():
		_diff_stats("hub return (end of boss wave -> after hub _start_run) visit %d" % hub_visits, _stats_before_hub, after)
		_stats_before_hub = {}
	else:
		_diff_stats("hub _start_run (fresh run) visit %d" % hub_visits, before, after)


# ───────────────────────────────────────────────────────── arena (full run)

func _drive_arena(arena: Node, delta: float) -> void:
	var lu: Control = arena.get("level_up_screen")
	var pm = arena.get("_pause_menu")
	var cp = arena.get("_card_popup")
	var phase: int = arena.get("arena_phase")
	var paused := get_tree().paused

	if cp and cp.get("_showing") == true and cp.has_method("_dismiss_card"):
		cp._dismiss_card()

	if lu and lu.visible:
		_press_levelup_card(lu, -1)

	# CHEST_PHASE == 2
	if phase == 2:
		var ui_now = arena.get("_chest_event_ui")
		var ui_id: int = ui_now.get_instance_id() if ui_now != null and is_instance_valid(ui_now) else 0
		if not _in_chest or (ui_id != 0 and ui_id != _last_chest_ui_id):
			_in_chest = true
			if ui_id != 0:
				_last_chest_ui_id = ui_id
			chest_phases += 1
			_chest_seen_at = t
			_collect_presses = 0
		if t - _chest_seen_at > 0.8:
			var states: Array = arena.get("_chest_states")
			for i in states.size():
				if not states[i].opened:
					for tier in ["secret", "gold", "silver", "bronze"]:
						if GameState.get_key_count(tier) > 0:
							arena._on_chest_key_chosen(i, tier)
							break
					break
			var cb = arena.get("_collect_btn")
			if cb and is_instance_valid(cb) and cb.visible and cb.modulate.a > 0.95 and _collect_presses < _collect_press_limit:
				cb.emit_signal("pressed")
				_collect_presses += 1
				print("BOT: Collect pressed (%d/%d) on wave %d" % [_collect_presses, _collect_press_limit, WaveManager.current_wave])
	else:
		_in_chest = false

	# COMBAT == 1
	if phase == 1 and not paused:
		_kill_enemies_over_time(delta)

	if WaveManager.wave_active and not _last_wave_active:
		_wave_started_at = t
		_spawn_log.clear()
		_died_log.clear()
		_max_proc_ms = 0.0
		_max_enemies = 0
	_last_wave_active = WaveManager.wave_active
	if WaveManager.wave_active and t - _wave_started_at > 60.0:
		notes.append("STUCK wave %d: active %.0fs alive=%d queue=%d" % [WaveManager.current_wave, t - _wave_started_at, WaveManager.enemies_alive, WaveManager.spawn_queue.size()])
		print("BOT: ", notes[-1])
		_dump_stuck(arena, lu, pm)
		_wave_started_at = t
		if scenario == "stuck_probe":
			_finish("stuck probe captured")
			return
		# Recover so the run can continue: this is what the arena's 3 s safety net
		# would do if it didn't require enemies_alive <= 0.
		WaveManager.force_complete_wave()

	_watchdog(arena, lu, pm, cp)


func _dump_stuck(arena: Node, lu, pm) -> void:
	print("BOT:   paused=%s phase=%s lu.visible=%s pm.open=%s chest_ui=%s" % [get_tree().paused, arena.get("arena_phase"), lu.visible if lu else null, pm.get("is_open") if pm else null, arena.get("_chest_event_ui")])
	var grp := get_tree().get_nodes_in_group("enemies")
	print("BOT:   'enemies' group size=%d ; enemies_container children=%d" % [grp.size(), arena.get("enemies_container").get_child_count()])
	for e in arena.get("enemies_container").get_children():
		print("BOT:     child %s type=%s in_group=%s is_dead=%s hp=%s burrowed=%s phase_tr=%s pos=%s vis=%s queued_free=%s script=%s" % [
			e.name, e.get("enemy_type"), e.is_in_group("enemies"), e.get("is_dead"), e.get("health"),
			e.get("_is_burrowed"), e.get("_phase_transitioning"), e.global_position.round(), e.visible,
			e.is_queued_for_deletion(), e.get_script().resource_path.get_file() if e.get_script() else null])
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e) and e.get("is_dead") != true:
			var id := e.get_instance_id()
			var hp_before = e.get("health")
			var r := "seen=%s kill_at=%s now=%.1f can_process=%s proc_mode=%d phys=%s" % [enemy_seen.get(id), enemy_kill_at.get(id), t, e.can_process(), e.process_mode, e.is_physics_processing()]
			e.take_damage(99999999)
			print("BOT:     ALIVE %s %s | direct hit: hp %s -> %s is_dead=%s" % [e.get("enemy_type"), r, hp_before, e.get("health"), e.get("is_dead")])
	var counts := {}
	for id in _spawn_log:
		counts[_spawn_log[id]] = counts.get(_spawn_log[id], 0) + 1
	print("BOT:   spawned this wave by type: ", counts, "  died signals: ", _died_log)


var _collect_presses := 0
var _last_chest_ui_id := 0
var _collect_press_limit := 1
var _phase_checks: Array = []
var _spawn_log: Dictionary = {}
var _died_log: Dictionary = {}
var double_deaths: Array = []
var _died_per_instance: Dictionary = {}


func _on_node_added(n: Node) -> void:
	if not (n is CharacterBody2D) or not n.has_signal("died") or not n.scene_file_path.contains("/enemies/"):
		return
	var id := n.get_instance_id()
	var typ := n.scene_file_path.get_file().get_basename().trim_prefix("enemy_")
	_spawn_log[id] = typ
	n.died.connect(func(_xp = 0):
		_died_log[typ] = _died_log.get(typ, 0) + 1
		_died_per_instance[id] = _died_per_instance.get(id, 0) + 1
		if _died_per_instance[id] == 2:
			double_deaths.append({"type": typ, "wave": WaveManager.current_wave})
			print("BOT: DOUBLE DEATH signal from %s on wave %d" % [typ, WaveManager.current_wave])
	)


func _kill_enemies_over_time(delta: float) -> void:
	var n := 0
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or e.get("is_dead") == true:
			continue
		n += 1
		var id := e.get_instance_id()
		var is_boss: bool = e.get("_is_boss") == true
		if not enemy_seen.has(id):
			enemy_seen[id] = t
			enemy_kill_at[id] = t + (randf_range(9.0, 14.0) if is_boss else randf_range(1.5, 4.0))
		if is_boss and t > enemy_seen[id] + 2.0 and fmod(t - enemy_seen[id], 1.0) < delta:
			var mh = e.get("max_health")
			if mh:
				e.take_damage(maxi(1, int(mh * 0.11)))
		if t >= enemy_kill_at[id]:
			e.take_damage(99999999)
	_max_enemies = maxi(_max_enemies, n)


func _press_levelup_card(lu: Control, force_idx: int) -> bool:
	var cards: Array = lu.get("_card_nodes")
	if cards.is_empty() or not is_instance_valid(cards[0]):
		return false
	var key: int = cards[0].get_instance_id()
	if key == _last_card_key:
		return false
	if key != _seen_card_key:
		_seen_card_key = key
		_card_seen_at = t
		return false
	if t - _card_seen_at < 0.5:
		return false
	var idx := force_idx if force_idx >= 0 else randi() % cards.size()
	var btn := _find_select_button(cards[idx])
	if btn:
		btn.emit_signal("pressed")
		_last_card_key = key
		levelups_chosen += 1
		return true
	return false


func _find_select_button(n: Node) -> Button:
	if n is Button and (n as Button).text == "SELECT":
		return n
	for c in n.get_children():
		var b := _find_select_button(c)
		if b:
			return b
	return null


func _watchdog(arena: Node, lu, pm, cp) -> void:
	var chest_ui = arena.get("_chest_event_ui")
	var modal: bool = (lu != null and lu.visible) \
		or (pm != null and pm.get("is_open") == true) \
		or (chest_ui != null and is_instance_valid(chest_ui)) \
		or (cp != null and cp.get("_showing") == true)
	if get_tree().paused and not modal:
		if _paused_since < 0.0:
			_paused_since = t
		elif t - _paused_since > 3.0:
			var s := {"wave": WaveManager.current_wave, "t": t,
				"lvl": GameState.player_level, "arena_last_lvl": arena.get("last_player_level"),
				"lu_visible": lu.visible if lu else null, "lu_alpha": lu.modulate.a if lu else null,
				"phase": arena.get("arena_phase")}
			softlocks.append(s)
			print("BOT: SOFTLOCK (tree paused, no modal visible for 3s) ", s, " -> forcing unpause")
			get_tree().paused = false
			_paused_since = -1.0
	else:
		_paused_since = -1.0


func _on_wave_complete_bot(wave_num: int) -> void:
	var row := {
		"wave": wave_num, "t": snappedf(t, 0.1), "dur": snappedf(t - _wave_started_at, 0.1),
		"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"orphans": int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),
		"objects": int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		"mem_mb": snappedf(Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0, 0.1),
		"max_frame_ms": snappedf(_max_proc_ms, 0.01), "max_enemies": _max_enemies,
		"lvl": GameState.player_level, "orb": GameState.orbital_weapons.size(),
		"perks": GameState.active_perks.size(), "maxhp": GameState.player_max_health,
		"dmg": GameState.perk_damage_bonus, "errs": error_total,
		"pickups": _count_pickups(),
	}
	wave_rows.append(row)
	print("BOT: WAVE ", row)
	var stage_wave := StageData.get_stage_wave(wave_num)
	if stage_wave == 7 or stage_wave == 14:
		_stats_before_hub = _snap_stats()
	if wave_num >= max_wave and scenario == "full_run":
		call_deferred("_finish", "max_wave %d reached" % max_wave)


func _count_pickups() -> int:
	var pc = get_tree().get_first_node_in_group("pickups_container")
	return pc.get_child_count() if pc else -1


func _drive_game_over(go: Node) -> void:
	if scenario == "death_esc":
		if t - _scene_entered_at > 3.0 and not _scratch.has("go_report"):
			_scratch["go_report"] = true
			print("BOT[esc]: game_over loaded; tree paused=%s ; game_over can_process=%s ; root modulate.a=%.2f" % [get_tree().paused, go.can_process(), go.modulate.a])
			_finish("death_esc done")
		return
	if scenario == "clear_window_death":
		if t - _scene_entered_at > 4.0 and not _scratch.has("go_report"):
			_scratch["go_report"] = true
			var ret_btn = null
			print("BOT[clear]: game_over scene loaded %.1fs after death; tree paused=%s ; game_over can_process=%s ; chest UI still alive=%s" % [_scene_entered_at - float(_scratch.get("kill_t", 0.0)), get_tree().paused, go.can_process(), get_tree().root.find_child("CollectBtn", true, false) != null])
			_finish("clear_window_death done")
		return
	if scenario == "death_cycle":
		if t - _scene_entered_at > 1.5 and not _hub_started:
			_hub_started = true
			var deaths: int = _scratch.get("deaths", 0)
			print("BOT[death]: game over screen: deaths=%d extra_lives=%d run_in_progress=%s mats=%s" % [deaths, GameState.extra_lives, GameState.run_in_progress, GameState.materials])
			if deaths == 1 and go.has_method("_retry_run") and GameState.extra_lives > 0:
				print("BOT[death]: -> _retry_run()")
				go._retry_run()
			else:
				print("BOT[death]: -> _return_to_base()")
				go._return_to_base()
		return
	if t - _scene_entered_at > 2.0 and not _hub_started:
		_hub_started = true
		notes.append("GAME OVER reached at wave %d in scenario %s" % [GameState.last_death_wave, scenario])
		_finish("unexpected game over")


# ───────────────────────────────────────────────────────── scenarios

func _scenario_levelup_race(arena: Node) -> void:
	var lu: Control = arena.get("level_up_screen")
	var el := t - _step_t
	match _step:
		0:
			if el > 1.5:
				var need := 0
				var x: int = GameState.xp_to_next_level
				for i in 3:
					need += x
					x = int(x * 1.4)
				GameState.gain_xp(int(ceil(need / GameState.perk_xp_multiplier)) + 1)
				print("BOT[race]: granted XP for 3 levels -> player_level=%d arena.last=%d" % [GameState.player_level, arena.get("last_player_level")])
				_scratch["perks0"] = GameState.active_perks.size() + GameState.orbital_weapons.size()
				_step = 1; _step_t = t
		1:
			if lu.visible and el > 0.8:
				var btn := _find_select_button(lu.get("_card_nodes")[0])
				print("BOT[race]: popup #1 visible, clicking SELECT on card 0")
				btn.emit_signal("pressed")
				_step = 2; _step_t = t
		2:
			if el > 1.5:
				var r := {"tree_paused": get_tree().paused, "levelup_visible": lu.visible,
					"levelup_alpha": snappedf(lu.modulate.a, 0.01),
					"player_level": GameState.player_level, "arena_last_level": arena.get("last_player_level"),
					"perks_gained": GameState.active_perks.size() + GameState.orbital_weapons.size() - int(_scratch["perks0"]),
					"pause_menu_open": arena.get("_pause_menu").is_open}
				print("BOT[race]: 1.5s after first pick: ", r)
				var softlock: bool = r.tree_paused and not r.levelup_visible and not r.pause_menu_open
				print("BOT[race]: RESULT softlock=%s" % softlock)
				# Can the player escape with Esc? Send a real ui_cancel press through the input pipeline.
				var ev := InputEventAction.new()
				ev.action = "ui_cancel"
				ev.pressed = true
				Input.parse_input_event(ev)
				_step = 3; _step_t = t
		3:
			if el > 0.5:
				print("BOT[race]: after pressing Esc: paused=%s pause_menu_open=%s levelup_visible=%s" % [get_tree().paused, arena.get("_pause_menu").is_open, lu.visible])
				_finish("levelup_race done")


func _scenario_double_click(arena: Node) -> void:
	var lu: Control = arena.get("level_up_screen")
	var el := t - _step_t
	match _step:
		0:
			if el > 1.5:
				GameState.gain_xp(int(ceil(GameState.xp_to_next_level / GameState.perk_xp_multiplier)) + 1)
				_scratch["n0"] = GameState.active_perks.size() + GameState.orbital_weapons.size()
				_scratch["perks0"] = GameState.active_perks.duplicate()
				_step = 1; _step_t = t
		1:
			if lu.visible and el > 0.8:
				var cards: Array = lu.get("_card_nodes")
				_scratch["names"] = cards.map(func(c): return c.get_meta("perk_name", "?"))
				_find_select_button(cards[0]).emit_signal("pressed")
				_scratch["c1"] = cards[1]
				_step = 2; _step_t = t
		2:
			# one frame later (~16 ms), well inside the 0.6 s dismiss window
			var c1 = _scratch["c1"]
			var b1 := _find_select_button(c1) if is_instance_valid(c1) else null
			print("BOT[dbl]: second click: card1 valid=%s button found=%s visible=%s disabled=%s" % [is_instance_valid(c1), b1 != null, lu.visible, b1.disabled if b1 else null])
			if b1:
				b1.emit_signal("pressed")
			_step = 3; _step_t = t
		3:
			if el > 1.5:
				var n1 := GameState.active_perks.size() + GameState.orbital_weapons.size()
				print("BOT[dbl]: offered=%s" % [_scratch["names"]])
				print("BOT[dbl]: perks/orbitals before=%d after=%d  (1 level-up gained)  perks now=%s orbitals=%s" % [_scratch["n0"], n1, GameState.active_perks, GameState.orbital_weapons])
				print("BOT[dbl]: RESULT double_grant=%s" % (n1 - int(_scratch["n0"]) >= 2))
				_finish("double_click done")


func _scenario_death_cycle(arena: Node, delta: float) -> void:
	var deaths: int = _scratch.get("deaths", 0)
	if not _scratch.has("arena_seen_%d" % _scene_entered_at):
		_scratch["arena_seen_%d" % _scene_entered_at] = true
		if deaths == 1:
			invincible = true
			var now := _snap_stats()
			print("BOT[death]: arena reloaded after RETRY: ", now)
			_diff_stats("just before death #1 -> after retry", _scratch["before_death1"], now)
	_drive_arena(arena, delta)
	var ready_to_die := false
	if deaths == 0 and GameState.current_wave >= 2 and WaveManager.wave_active and t - _wave_started_at > 3.0:
		ready_to_die = true
	elif deaths == 1 and WaveManager.wave_active and t - _scene_entered_at > 6.0:
		ready_to_die = true
	if ready_to_die and not get_tree().paused and arena.get("arena_phase") == 1:
		_scratch["before_death%d" % (deaths + 1)] = _snap_stats()
		_scratch["deaths"] = deaths + 1
		invincible = false
		print("BOT[death]: killing player (death #%d) on wave %d, extra_lives=%d" % [deaths + 1, WaveManager.current_wave, GameState.extra_lives])
		arena.player.take_damage(999999)


func _scenario_collect(arena: Node, delta: float) -> void:
	_collect_press_limit = 2 if scenario == "double_collect" else 1
	_drive_arena(arena, delta)
	if WaveManager.current_wave == 2 and WaveManager.wave_active:
		if not _scratch.has("w2_start"):
			_scratch["w2_start"] = t
		elif t - _scratch["w2_start"] > 2.0 and not _scratch.has("reported"):
			_scratch["reported"] = true
			var ph: int = arena.get("arena_phase")
			print("BOT[collect]: %s -> 2s into wave 2: arena_phase=%d (%s)  wave_active=%s" % [scenario, ph, ["PREP","COMBAT","CHEST_PHASE","TRANSITION"][ph], WaveManager.wave_active])
			# Would the player's death be handled? _on_player_died returns early in TRANSITION.
			invincible = false
			arena.player.take_damage(999999)
			_scratch["died_at"] = t
	if _scratch.has("died_at") and t - _scratch["died_at"] > 4.0:
		var cs := get_tree().current_scene
		print("BOT[collect]: 4s after lethal damage: scene=%s player.is_dead=%s GS.phase=%s" % [cs.scene_file_path.get_file(), arena.player.get("is_dead") if is_instance_valid(arena.player) else "freed", GameState.current_phase])
		_finish("%s done" % scenario)


func _scenario_hub_return(arena: Node, delta: float) -> void:
	var lu: Control = arena.get("level_up_screen")
	if hub_visits == 1:
		# First arena visit: wave 7. At the first chest phase, set up the three probes.
		if arena.get("arena_phase") == 2 and not _scratch.has("armed"):
			_scratch["armed"] = true
			for i in 4:
				GameState.add_key("bronze")
			GameState.player_xp = GameState.xp_to_next_level - 5      # first chest XP will level us up
			GameState.player_max_health += 5                           # exactly what a silver chest bonus does
			GameState.player_health = 20                               # low HP going into the hub
			_scratch["lvl_before_chests"] = GameState.player_level
			print("BOT[hub]: armed at chest phase: lvl=%d xp=%d/%d maxhp=%d hp=%d dmg=%d" % [GameState.player_level, GameState.player_xp, GameState.xp_to_next_level, GameState.player_max_health, GameState.player_health, GameState.perk_damage_bonus])
		_drive_arena(arena, delta)
	else:
		# Second arena visit (after the hub). Did the chest level-up ever get a popup?
		if lu.visible and not _scratch.has("popup_seen"):
			_scratch["popup_seen"] = true
		if t - _scene_entered_at > 4.0 and not _scratch.has("reported"):
			_scratch["reported"] = true
			print("BOT[hub]: RESULT after hub: lvl=%d (was %d before boss chests), arena.last_player_level=%d, level-up popup shown=%s" % [GameState.player_level, _scratch.get("lvl_before_chests", -1), arena.get("last_player_level"), _scratch.has("popup_seen")])
			print("BOT[hub]: RESULT chimera=%s dmg_bonus=%d (Iron Stomach should keep +20) maxhp=%d hp=%d" % [GameState.chimera_buff.get("name", "?"), GameState.perk_damage_bonus, GameState.player_max_health, GameState.player_health])
			_finish("hub_return done")
		elif not _scratch.has("reported"):
			_drive_arena(arena, delta)


func _scenario_clear_window_death(arena: Node, delta: float) -> void:
	# Play wave 1 normally; 0.5 s after WAVE CLEAR (inside the 1.3 s window) the player dies.
	if not _scratch.has("killed"):
		if WaveManager.current_wave == 1 and not WaveManager.wave_active and _scratch.has("w1_active"):
			if not _scratch.has("clear_t"):
				_scratch["clear_t"] = t
			elif t - _scratch["clear_t"] > 0.5:
				_scratch["killed"] = true
				invincible = false
				print("BOT[clear]: wave 1 cleared %.2fs ago; killing player now (phase=%d)" % [t - _scratch["clear_t"], arena.get("arena_phase")])
				arena.player.take_damage(999999)
				_scratch["kill_t"] = t
		else:
			if WaveManager.wave_active:
				_scratch["w1_active"] = true
			_drive_arena(arena, delta)


func _scenario_death_esc(arena: Node, delta: float) -> void:
	var el := t - _step_t
	match _step:
		0:
			_drive_arena(arena, delta)
			if arena.get("arena_phase") == 1 and WaveManager.wave_active and el > 3.0 and not get_tree().paused:
				invincible = false
				arena.player.take_damage(999999)
				_scratch["kill_t"] = t
				print("BOT[esc]: player killed mid-wave")
				_step = 1; _step_t = t
		1:
			if el > 0.4:
				# A real Esc press routed through the input pipeline (arena._unhandled_input handles it)
				var ev := InputEventAction.new(); ev.action = "ui_cancel"; ev.pressed = true
				Input.parse_input_event(ev)
				_step = 2; _step_t = t
		2:
			if el > 0.1 and not _scratch.has("esc_logged"):
				_scratch["esc_logged"] = true
				print("BOT[esc]: after Esc on death banner: pause_menu open=%s tree paused=%s" % [arena.get("_pause_menu").is_open, get_tree().paused])


func _scenario_stress(arena: Node, delta: float) -> void:
	var el := t - _step_t
	match _step:
		0:
			if el > 2.0 and arena.get("arena_phase") == 1:
				WaveManager.spawn_queue.clear()
				var types := ["shadow_crawler", "phantom", "void_weaver", "abyssal_knight", "rusher", "exploder"]
				var n := int(_stress_n)
				var t0 := Time.get_ticks_usec()
				for i in n:
					var scn = load(WaveManager.ENEMY_SCENES[types[i % types.size()]])
					var e = scn.instantiate()
					e.global_position = arena.player.global_position + Vector2.from_angle(TAU * i / n) * randf_range(120, 300)
					e.died.connect(WaveManager._on_enemy_died)
					arena.get("enemies_container").add_child(e)
					WaveManager.enemies_alive += 1
				print("BOT[stress]: spawned %d enemies in one frame: %.1f ms" % [n, (Time.get_ticks_usec() - t0) / 1000.0])
				_scratch["samples"] = []
				_step = 1; _step_t = t
		1:
			var now_us := Time.get_ticks_usec()
			var pt := (now_us - int(_scratch.get("last_us", now_us))) / 1000.0
			_scratch["last_us"] = now_us
			if el > 1.0:
				_scratch["samples"].append(pt)
			if el > 11.0:
				var smp: Array = _scratch["samples"]
				smp.sort()
				print("BOT[stress]: %d live enemies, 10s window: frame(ms) p50=%.2f p95=%.2f max=%.2f | nodes=%d" % [get_tree().get_nodes_in_group("enemies").size(), smp[smp.size() / 2], smp[int(smp.size() * 0.95)], smp[-1], Performance.get_monitor(Performance.OBJECT_NODE_COUNT)])
				_finish("stress done")


func arena_quit(arena: Node) -> void:
	var pm = arena.get("_pause_menu")
	pm.open()
	pm._quit_to_menu()


func _scenario_pause_damage(arena: Node) -> void:
	var el := t - _step_t
	match _step:
		0:
			if el > 2.0 and arena.get("arena_phase") == 1:
				invincible = false
				GameState.player_health = GameState.player_max_health
				var ex = load("res://scenes/enemies/enemy_exploder.tscn").instantiate()
				arena.get("enemies_container").add_child(ex)
				ex.global_position = arena.player.global_position + Vector2(8, 0)
				ex.call_deferred("_light_fuse")
				_scratch["hp0"] = GameState.player_health
				_step = 1; _step_t = t
		1:
			if el > 0.05:
				arena.get("_pause_menu").open()
				_scratch["hp_at_pause"] = GameState.player_health
				print("BOT[pause]: fuse lit, PAUSE MENU OPEN (tree paused=%s), HP=%d" % [get_tree().paused, GameState.player_health])
				_step = 2; _step_t = t
		2:
			if el > 3.0:
				print("BOT[pause]: 3s later, still paused=%s pause_menu_open=%s  HP %d -> %d  (damage taken while paused: %s)" % [get_tree().paused, arena.get("_pause_menu").is_open, _scratch["hp_at_pause"], GameState.player_health, GameState.player_health < int(_scratch["hp_at_pause"])])
				_finish("pause_damage done")


func _scenario_save_roundtrip(arena: Node, delta: float) -> void:
	_drive_arena(arena, delta)
	if _step == 0 and GameState.current_wave >= 5 and arena.get("arena_phase") == 1 and WaveManager.wave_active and t - _wave_started_at > 2.0 and not get_tree().paused:
		_step = 1
		SaveManager.save_game()
		var before := _snap_all_gamestate()
		# Simulate a cold start: reset in-memory state, then load from disk.
		GameState.end_run()
		GameState.permanent = {}
		GameState.materials = {}
		GameState.active_perks = []
		GameState.orbital_weapons = []
		GameState.chimera_buff = {}
		SaveManager.load_game()
		var after := _snap_all_gamestate()
		var diffs: Array = []
		for k in before:
			if var_to_str(before[k]) != var_to_str(after.get(k)):
				diffs.append("%s: saved-state=%s  loaded=%s" % [k, _short(before[k]), _short(after.get(k))])
		print("BOT[save]: %d GameState vars differ after save->load round trip:" % diffs.size())
		for d in diffs:
			print("BOT[save]:   ", d)
		_finish("save_roundtrip done")


func _short(v) -> String:
	var s := var_to_str(v).replace("\n", " ")
	return s if s.length() < 140 else s.left(137) + "..."


# ───────────────────────────────────────────────────────── snapshots

func _snap_stats() -> Dictionary:
	return {
		"wave": GameState.current_wave, "hp": GameState.player_health, "max_hp": GameState.player_max_health,
		"lvl": GameState.player_level, "xp": GameState.player_xp,
		"dmg_bonus": GameState.perk_damage_bonus,
		"speed_mult": snappedf(GameState.perk_speed_multiplier, 0.0001),
		"atkspd_mult": snappedf(GameState.perk_attack_speed_multiplier, 0.0001),
		"xp_mult": snappedf(GameState.perk_xp_multiplier, 0.0001),
		"dr": snappedf(GameState.perk_damage_reduction, 0.0001),
		"crit": GameState.perk_crit_bonus, "lifesteal": GameState.perk_lifesteal,
		"thorns": GameState.perk_thorns_damage, "regen": GameState.perk_regen_active,
		"chimera": GameState.chimera_buff.duplicate(),
		"perks": GameState.active_perks.size(), "orbitals": GameState.orbital_weapons.size(),
		"keys": GameState.keys.duplicate(), "extra_lives": GameState.extra_lives,
		"second_wind_used": GameState.perk_second_wind_used,
	}


func _snap_all_gamestate() -> Dictionary:
	var out := {}
	for prop in GameState.get_property_list():
		if prop.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			var v = GameState.get(prop.name)
			if v is Dictionary or v is Array:
				v = v.duplicate(true)
			out[prop.name] = v
	return out


func _diff_stats(label: String, a: Dictionary, b: Dictionary) -> void:
	var d: Array = []
	for k in a:
		if var_to_str(a[k]) != var_to_str(b.get(k)):
			d.append("%s %s -> %s" % [k, _short(a[k]), _short(b.get(k))])
	var line := "STATDIFF [%s]: %s" % [label, ", ".join(d) if not d.is_empty() else "(no change)"]
	notes.append(line)
	print("BOT: ", line)


# ───────────────────────────────────────────────────────── errors + finish

func _collect_errors() -> void:
	for e in logger.drain():
		error_total += 1
		var where: String = e.bt if e.bt != "" else "%s:%d" % [e.file, e.line]
		var msg: String = e.why if e.why != "" else e.code
		var key := where + " | " + msg.left(160)
		if not errors.has(key):
			errors[key] = {"count": 0, "first_wave": WaveManager.current_wave, "first_t": snappedf(t, 0.1), "type": e.type}
		errors[key].count += 1


func _finish(reason: String) -> void:
	if _done:
		return
	_done = true
	_collect_errors()
	print("\n==================== BOT SUMMARY (%s) ====================" % scenario)
	print("reason: %s | game time %.0fs | waves logged %d | hub visits %d | level-ups chosen %d | levels gained %d | chest phases %d" % [reason, t, wave_rows.size(), hub_visits, levelups_chosen, _levels_gained_total, chest_phases])
	print("softlocks: %d | double deaths: %d %s" % [softlocks.size(), double_deaths.size(), double_deaths])
	for s in softlocks:
		print("  SOFTLOCK ", s)
	print("notes:")
	for n in notes:
		print("  ", n)
	print("errors: %d total, %d unique" % [error_total, errors.size()])
	var keys := errors.keys()
	keys.sort_custom(func(a, b): return errors[a].count > errors[b].count)
	for k in keys:
		var e = errors[k]
		print("  [%5d x] first@wave %d t=%.0f type=%d :: %s" % [e.count, e.first_wave, e.first_t, e.type, k])
	var f := FileAccess.open(OUT_DIR + scenario + "_waves.json", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"rows": wave_rows, "softlocks": softlocks, "notes": notes,
			"errors": errors, "levelups_chosen": levelups_chosen, "levels_gained": _levels_gained_total}, "  "))
		f.close()
	print("==================== END ====================")
	get_tree().quit()
