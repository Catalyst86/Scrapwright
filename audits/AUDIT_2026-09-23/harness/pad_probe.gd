extends Node
func _ready() -> void:
	var stick := InputEventJoypadMotion.new(); stick.axis = JOY_AXIS_LEFT_X; stick.axis_value = -1.0
	var dpad := InputEventJoypadButton.new(); dpad.button_index = JOY_BUTTON_DPAD_LEFT; dpad.pressed = true
	var start := InputEventJoypadButton.new(); start.button_index = JOY_BUTTON_START; start.pressed = true
	var b := InputEventJoypadButton.new(); b.button_index = JOY_BUTTON_B; b.pressed = true
	var a := InputEventJoypadButton.new(); a.button_index = JOY_BUTTON_A; a.pressed = true
	var hits := []
	for act in InputMap.get_actions():
		if act.begins_with("ui_") or act in ["dodge","bark","salvage","sneak","collect"]:
			for pair in [["LeftStick-left", stick], ["DPad-left", dpad], ["Start", start], ["B", b], ["A", a]]:
				if InputMap.event_is_action(pair[1], act):
					hits.append("%s->%s" % [pair[0], act])
	print("PAD: gamepad inputs that map to ANY action: ", hits)
	print("PAD: ui_left events=", InputMap.action_get_events("ui_left").map(func(e): return e.get_class()))
	print("PAD: ui_cancel events=", InputMap.action_get_events("ui_cancel").map(func(e): return e.get_class()))
	print("PAD: ui_accept events=", InputMap.action_get_events("ui_accept").map(func(e): return e.get_class()))
	get_tree().quit()
