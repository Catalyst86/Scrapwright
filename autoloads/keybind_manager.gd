extends Node

# ============================================================
# KeybindManager — Runtime keybinding rebind + persistence
# Saves custom bindings to user://keybinds.cfg
# ============================================================

const SAVE_PATH = "user://keybinds.cfg"

# Actions players can rebind (action_name -> display label)
const REBINDABLE_ACTIONS = {
	"ui_up": "Move Up",
	"ui_down": "Move Down",
	"ui_left": "Move Left",
	"ui_right": "Move Right",
	"dodge": "Dodge",
	"bark": "Bark",
	"salvage": "Dig / Salvage",
	"sneak": "Sneak",
	"collect": "Collect Scrap",
	"ui_cancel": "Pause / Back",
}

# Stores project.godot defaults so we can restore them
var _defaults: Dictionary = {}

func _ready() -> void:
	_cache_defaults()
	load_keybinds()


func _cache_defaults() -> void:
	for action in REBINDABLE_ACTIONS:
		var events = InputMap.action_get_events(action)
		_defaults[action] = events.duplicate()


func rebind_action(action: String, new_event: InputEvent) -> void:
	if action not in REBINDABLE_ACTIONS:
		return
	# Remove existing keyboard events (keep gamepad bindings)
	var events = InputMap.action_get_events(action)
	for ev in events:
		if ev is InputEventKey:
			InputMap.action_erase_event(action, ev)
	# Add the new keyboard binding
	InputMap.action_add_event(action, new_event)
	save_keybinds()


func reset_defaults() -> void:
	for action in REBINDABLE_ACTIONS:
		# Clear all events
		InputMap.action_erase_events(action)
		# Restore defaults
		if action in _defaults:
			for ev in _defaults[action]:
				InputMap.action_add_event(action, ev)
	# Delete saved config
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


func save_keybinds() -> void:
	var config = ConfigFile.new()
	for action in REBINDABLE_ACTIONS:
		var events = InputMap.action_get_events(action)
		for ev in events:
			if ev is InputEventKey:
				config.set_value("keybinds", action + "_keycode", ev.physical_keycode)
				break  # Only save the first keyboard binding
	config.save(SAVE_PATH)


func load_keybinds() -> void:
	var config = ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return  # No custom bindings, use defaults
	for action in REBINDABLE_ACTIONS:
		var key = action + "_keycode"
		if config.has_section_key("keybinds", key):
			var keycode = config.get_value("keybinds", key)
			# Build a new InputEventKey from the saved keycode
			var ev = InputEventKey.new()
			ev.physical_keycode = keycode
			# Remove existing keyboard events
			var events = InputMap.action_get_events(action)
			for old_ev in events:
				if old_ev is InputEventKey:
					InputMap.action_erase_event(action, old_ev)
			# Add saved binding
			InputMap.action_add_event(action, ev)


func get_key_name(action: String) -> String:
	var events = InputMap.action_get_events(action)
	for ev in events:
		if ev is InputEventKey:
			var kc = ev.physical_keycode
			if kc == 0:
				kc = ev.keycode
			if kc != 0:
				return OS.get_keycode_string(kc)
	return "???"


func get_action_label(action: String) -> String:
	return REBINDABLE_ACTIONS.get(action, action)
