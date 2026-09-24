extends Node
## C7: which gamepad inputs map to which actions (all actions, not just the first match).
func _ready() -> void:
	var probes := {
		"LeftStick-left": _axis(JOY_AXIS_LEFT_X, -1.0), "LeftStick-down": _axis(JOY_AXIS_LEFT_Y, 1.0),
		"DPad-left": _btn(JOY_BUTTON_DPAD_LEFT), "DPad-up": _btn(JOY_BUTTON_DPAD_UP),
		"A": _btn(JOY_BUTTON_A), "B": _btn(JOY_BUTTON_B), "X": _btn(JOY_BUTTON_X), "Y": _btn(JOY_BUTTON_Y),
		"LB": _btn(JOY_BUTTON_LEFT_SHOULDER), "RB": _btn(JOY_BUTTON_RIGHT_SHOULDER), "Start": _btn(JOY_BUTTON_START),
		"Back": _btn(JOY_BUTTON_BACK), "Guide": _btn(JOY_BUTTON_GUIDE),
	}
	for name in probes:
		var hits := []
		for act in InputMap.get_actions():
			if act.begins_with("ui_") or act in ["dodge", "bark", "salvage", "sneak", "collect"]:
				if probes[name].is_action_pressed(act, false, true):
					hits.append(act)
		print("PAD: %-15s -> %s" % [name, hits])
	get_tree().quit()

func _btn(b: JoyButton) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new(); e.button_index = b; e.pressed = true; return e

func _axis(a: JoyAxis, v: float) -> InputEventJoypadMotion:
	var e := InputEventJoypadMotion.new(); e.axis = a; e.axis_value = v; return e
