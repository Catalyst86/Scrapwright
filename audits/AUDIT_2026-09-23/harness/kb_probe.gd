extends Node
func _ready() -> void:
	var mode := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--kb="): mode = a.get_slice("=", 1)
	var esc := InputEventKey.new(); esc.keycode = KEY_ESCAPE; esc.physical_keycode = KEY_ESCAPE; esc.pressed = true
	var left := InputEventKey.new(); left.keycode = KEY_LEFT; left.physical_keycode = KEY_LEFT; left.pressed = true
	var a_key := InputEventKey.new(); a_key.keycode = KEY_A; a_key.physical_keycode = KEY_A; a_key.pressed = true
	print("KB[%s]: Esc->ui_cancel=%s  LeftArrow->ui_left=%s  A->ui_left=%s  ui_cancel events=%s" % [mode,
		InputMap.event_is_action(esc, "ui_cancel"), InputMap.event_is_action(left, "ui_left"), InputMap.event_is_action(a_key, "ui_left"),
		InputMap.action_get_events("ui_cancel").map(func(e): return "kc=%d phys=%d" % [e.keycode, e.physical_keycode])])
	if mode == "write":
		var j := InputEventKey.new(); j.physical_keycode = KEY_J
		KeybindManager.rebind_action("dodge", j)
		print("KB[write]: rebound Dodge -> J and saved keybinds.cfg")
	get_tree().quit()
