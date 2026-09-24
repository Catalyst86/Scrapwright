extends Node

# ============================================================
# KeybindManager — Runtime keybinding rebind + persistence
# Saves custom bindings to user://keybinds.cfg
#
# Each rebindable action has one "primary" keyboard key the player can change.
# Everything else in the action's project.godot defaults (alternate keys such as
# the arrow keys, and all gamepad events) is always kept, so rebinding Move Left
# can never break arrow-key menu navigation or controller input.
# Only actions the player actually changed are written to disk.
# ============================================================

const SAVE_PATH = "user://keybinds.cfg"
const SAVE_SECTION = "keybinds_v2"
# Pre-2026-09 format: "<action>_keycode" = physical_keycode for EVERY action.
# It stored 0 for keycode-only defaults (Esc, arrow keys), which erased them on
# the next launch. Read once for migration, then rewritten in SAVE_SECTION.
const LEGACY_SECTION = "keybinds"

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
# action -> InputEventKey chosen as that action's primary key (customised actions only)
var _custom_primary: Dictionary = {}

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
	if not (new_event is InputEventKey) or _key_code(new_event) == 0:
		return
	if _same_key(new_event, _default_primary(action)):
		_custom_primary.erase(action)  # Back to the default — nothing to persist
	else:
		_custom_primary[action] = new_event
	_apply_action(action)
	save_keybinds()


func reset_defaults() -> void:
	_custom_primary.clear()
	for action in REBINDABLE_ACTIONS:
		_apply_action(action)
	# Delete saved config
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


func save_keybinds() -> void:
	if _custom_primary.is_empty():
		if FileAccess.file_exists(SAVE_PATH):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
		return
	var config = ConfigFile.new()
	for action in _custom_primary:
		var ev: InputEventKey = _custom_primary[action]
		config.set_value(SAVE_SECTION, action, {
			"keycode": int(ev.keycode),
			"physical_keycode": int(ev.physical_keycode),
		})
	config.save(SAVE_PATH)


func load_keybinds() -> void:
	_custom_primary.clear()
	var config = ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return  # No custom bindings, use defaults
	var migrated := false
	for action in REBINDABLE_ACTIONS:
		var ev: InputEventKey = null
		if config.has_section_key(SAVE_SECTION, action):
			var data = config.get_value(SAVE_SECTION, action)
			if data is Dictionary:
				ev = InputEventKey.new()
				ev.keycode = int(data.get("keycode", 0))
				ev.physical_keycode = int(data.get("physical_keycode", 0))
		elif config.has_section_key(LEGACY_SECTION, action + "_keycode"):
			migrated = true
			var code := int(config.get_value(LEGACY_SECTION, action + "_keycode", 0))
			if code != 0:  # 0 = a keycode-only default the old format couldn't store
				ev = InputEventKey.new()
				ev.physical_keycode = code
		# Skip unusable keys and entries that merely repeat the default
		if ev == null or _key_code(ev) == 0 or _same_key(ev, _default_primary(action)):
			continue
		_custom_primary[action] = ev
		_apply_action(action)
	if migrated:
		save_keybinds()  # Rewrite in the current format (drops the legacy section)


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


# Rebuilds an action as: [primary key, default alternate keys..., default non-key events].
func _apply_action(action: String) -> void:
	var default_primary := _default_primary(action)
	var primary: InputEventKey = _custom_primary.get(action, default_primary)
	InputMap.action_erase_events(action)
	if primary:
		InputMap.action_add_event(action, primary)
	for ev in _defaults.get(action, []):
		if ev is InputEventKey and (ev == default_primary or _same_key(ev, primary)):
			continue  # The primary slot is already filled; don't add duplicates
		InputMap.action_add_event(action, ev)


# The first keyboard event in the action's project.godot defaults.
func _default_primary(action: String) -> InputEventKey:
	for ev in _defaults.get(action, []):
		if ev is InputEventKey:
			return ev
	return null


# The code an event matches on: physical key when set, otherwise the keycode.
static func _key_code(ev: InputEventKey) -> int:
	return int(ev.physical_keycode) if ev.physical_keycode != 0 else int(ev.keycode)


static func _same_key(a: InputEventKey, b: InputEventKey) -> bool:
	return a != null and b != null and _key_code(a) != 0 and _key_code(a) == _key_code(b)
