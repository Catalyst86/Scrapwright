extends Node
## C1 keybind persistence test. Each mode is a separate launch (real restart):
##   --kb=write        rebind Dodge->J, Move Up->I, Move Left->LeftArrow (duplicates its alternate)
##   --kb=check        expectations after `write` + restart
##   --kb=legacy       write a keybinds.cfg exactly as the pre-fix code did (Dodge->J)
##   --kb=check_legacy expectations after `legacy` + restart (migration)
##   --kb=reset        reset_defaults(), expect every default back and no file
## Prints "KB PASS"/"KB FAIL" lines; the final line is "KB RESULT ok=<bool>".

var _ok := true

func _ready() -> void:
	# SAFETY: this rewrites and deletes user://keybinds.cfg. Real key bindings live there.
	if not ProjectSettings.get_setting("application/config/use_custom_user_dir", false) \
			and not "--allow-real-userdata" in OS.get_cmdline_user_args():
		push_error("kb_probe: refusing to run - it overwrites keybinds.cfg. Use the override.cfg from harness/README.md (separate user dir), or pass --allow-real-userdata.")
		get_tree().quit(2)
		return
	var mode := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--kb="):
			mode = a.get_slice("=", 1)
	match mode:
		"write":
			KeybindManager.rebind_action("dodge", _phys(KEY_J))
			KeybindManager.rebind_action("ui_up", _phys(KEY_I))
			KeybindManager.rebind_action("ui_left", _phys(KEY_LEFT))
			print("KB[write]: file = ", FileAccess.get_file_as_string(KeybindManager.SAVE_PATH).replace("\n", " | "))
		"check":
			_expect("Esc -> ui_cancel", _key(KEY_ESCAPE), "ui_cancel", true)
			_expect("I -> ui_up (rebound)", _key(KEY_I), "ui_up", true)
			_expect("W -> ui_up (replaced)", _key(KEY_W), "ui_up", false)
			_expect("UpArrow -> ui_up (alternate kept)", _key(KEY_UP), "ui_up", true)
			_expect("LeftArrow -> ui_left", _key(KEY_LEFT), "ui_left", true)
			_expect("A -> ui_left (replaced)", _key(KEY_A), "ui_left", false)
			_expect("J -> dodge", _key(KEY_J), "dodge", true)
			_expect("Space -> dodge (replaced)", _key(KEY_SPACE), "dodge", false)
			_expect("Pad A -> dodge (gamepad kept)", _pad(JOY_BUTTON_A), "dodge", true)
			_expect("D -> ui_right (untouched)", _key(KEY_D), "ui_right", true)
			_count("ui_left has no duplicate keys", "ui_left", 1)
		"legacy":
			var c := ConfigFile.new()
			var old := {"ui_up": KEY_W, "ui_down": KEY_S, "ui_left": KEY_A, "ui_right": KEY_D,
				"dodge": KEY_J, "bark": KEY_E, "salvage": KEY_F, "sneak": KEY_CTRL,
				"collect": KEY_SHIFT, "ui_cancel": 0}
			for action in old:
				c.set_value("keybinds", action + "_keycode", int(old[action]))
			c.save(KeybindManager.SAVE_PATH)
			print("KB[legacy]: wrote pre-fix format file")
		"check_legacy":
			_expect("Esc -> ui_cancel", _key(KEY_ESCAPE), "ui_cancel", true)
			_expect("LeftArrow -> ui_left", _key(KEY_LEFT), "ui_left", true)
			_expect("UpArrow -> ui_up", _key(KEY_UP), "ui_up", true)
			_expect("A -> ui_left", _key(KEY_A), "ui_left", true)
			_expect("J -> dodge (migrated)", _key(KEY_J), "dodge", true)
			var c2 := ConfigFile.new()
			c2.load(KeybindManager.SAVE_PATH)
			_check("file migrated to v2 with only dodge",
				not c2.has_section("keybinds") and c2.get_section_keys("keybinds_v2") == PackedStringArray(["dodge"]))
		"reset":
			KeybindManager.reset_defaults()
			_expect("Space -> dodge", _key(KEY_SPACE), "dodge", true)
			_expect("W -> ui_up", _key(KEY_W), "ui_up", true)
			_expect("UpArrow -> ui_up", _key(KEY_UP), "ui_up", true)
			_expect("Esc -> ui_cancel", _key(KEY_ESCAPE), "ui_cancel", true)
			_check("no keybinds.cfg after reset", not FileAccess.file_exists(KeybindManager.SAVE_PATH))
	print("KB RESULT mode=%s ok=%s" % [mode, _ok])
	get_tree().quit()


func _phys(k: Key) -> InputEventKey:
	# Exactly what pause_menu's rebind listener builds
	var e := InputEventKey.new()
	e.physical_keycode = k
	return e


func _key(k: Key) -> InputEventKey:
	# What a real keyboard sends: both codes set
	var e := InputEventKey.new()
	e.keycode = k
	e.physical_keycode = k
	e.pressed = true
	return e


func _pad(b: JoyButton) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.button_index = b
	e.pressed = true
	return e


func _expect(label: String, ev: InputEvent, action: String, want: bool) -> void:
	_check("%s is %s" % [label, want], InputMap.event_is_action(ev, action) == want)


func _count(label: String, action: String, want_keys: int) -> void:
	var n := 0
	for e in InputMap.action_get_events(action):
		if e is InputEventKey:
			n += 1
	_check("%s (%d key events)" % [label, n], n == want_keys)


func _check(label: String, cond: bool) -> void:
	print("KB %s  %s" % ["PASS" if cond else "FAIL", label])
	if not cond:
		_ok = false
