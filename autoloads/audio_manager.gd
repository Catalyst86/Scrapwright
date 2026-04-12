extends Node

# Global audio manager for UI, event, and shared sound effects.
# Usage: AudioManager.play("button_click")

var _players: Dictionary = {}  # name -> AudioStreamPlayer
var music_enabled: bool = true
var sfx_enabled: bool = true
var music_volume: float = 0.5  # 0.0 = off, 1.0 = full
var sfx_volume: float = 0.7

const SFX_REGISTRY = {
	# UI sounds
	"button_click": ["res://assets/audio/sfx/ui/button_click.wav", -14.0],
	"button_hover": ["res://assets/audio/sfx/ui/A Short Quick Dull _bloop_ 32 Bit 2.wav", -18.0],
	"menu_transition": ["res://assets/audio/sfx/ui/menu_transition.wav", -12.0],
	"level_up": ["res://assets/audio/sfx/ui/level_up.wav", -10.0],
	"card_select": ["res://assets/audio/sfx/ui/card_select.wav", -12.0],
	"craft_success": ["res://assets/audio/sfx/ui/craft_success.wav", -10.0],
	"chest_open": ["res://assets/audio/sfx/ui/chest_open.wav", -20.0],
	"chest_deny": ["res://assets/audio/sfx/ui/chest_deny.wav", -20.0],
	"pause": ["res://assets/audio/sfx/ui/pause.wav", -12.0],
	"save": ["res://assets/audio/sfx/ui/save.wav", -12.0],
	# Event sounds
	"wave_start": ["res://assets/audio/sfx/events/wave_start.wav", -8.0],
	"wave_clear": ["res://assets/audio/sfx/events/wave_clear.wav", -8.0],
	"chest_phase": ["res://assets/audio/sfx/events/chest_phase.wav", -8.0],
	"victory": ["res://assets/audio/sfx/events/victory.wav", -6.0],
	"death_sting": ["res://assets/audio/sfx/events/death_sting.wav", -6.0],
	"secret_door": ["res://assets/audio/sfx/events/secret_door.wav", -8.0],
	# Trap sounds
	"trap_snap": ["res://assets/audio/sfx/traps/trap_snap.wav", -10.0],
	"trap_collapse": ["res://assets/audio/sfx/traps/trap_collapse.wav", -10.0],
	# Environment sounds
	"prop_hit": ["res://assets/audio/sfx/environment/prop_hit.wav", -14.0],
	"crate_break": ["res://assets/audio/sfx/environment/crate_break.wav", -10.0],
	"barrel_break": ["res://assets/audio/sfx/environment/barrel_break.wav", -10.0],
	"rubble_break": ["res://assets/audio/sfx/environment/rubble_break.wav", -10.0],
	"item_pickup": ["res://assets/audio/sfx/environment/item_pickup.wav", -14.0],
	# Orbital sounds
	"spark_coil": ["res://assets/audio/sfx/orbitals/spark_coil.wav", -24.0],
	"frost_shard": ["res://assets/audio/sfx/orbitals/frost_shard2.wav", -18.0],
	"poison_orb": ["res://assets/audio/sfx/orbitals/poison_orb.wav", -18.0],
	"chain_link": ["res://assets/audio/sfx/orbitals/chain_link.wav", -18.0],
	"blade_fan": ["res://assets/audio/sfx/orbitals/blade_fan.wav", -18.0],
	"shadow_dagger": ["res://assets/audio/sfx/orbitals/shadow_dagger.wav", -18.0],
	"flame_wisp": ["res://assets/audio/sfx/orbitals/flame_wisp.wav", -18.0],
	"holy_lantern": ["res://assets/audio/sfx/orbitals/holy_lantern.wav", -18.0],
	"thorn_vine": ["res://assets/audio/sfx/orbitals/thorn_vine.wav", -18.0],
	"magnet_core": ["res://assets/audio/sfx/orbitals/magnet_core.wav", -18.0],
	"shield_drone": ["res://assets/audio/sfx/orbitals/shield_drone.wav", -24.0],
	"arcane_book": ["res://assets/audio/sfx/orbitals/spark_coil.wav", -12.0],
}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().node_added.connect(_on_node_added)
	for sfx_name in SFX_REGISTRY:
		var entry: Array = SFX_REGISTRY[sfx_name]
		var path: String = entry[0]
		var vol: float = entry[1]
		if ResourceLoader.exists(path):
			var player = AudioStreamPlayer.new()
			player.stream = load(path)
			player.volume_db = vol
			if sfx_name in ["button_click", "button_hover", "menu_transition", "level_up", "card_select", "pause", "save"]:
				player.bus = "UI"
			else:
				player.bus = "SFX"
			add_child(player)
			_players[sfx_name] = player

func _on_node_added(node: Node) -> void:
	if node is BaseButton:
		if not node.pressed.is_connected(_on_button_pressed):
			node.pressed.connect(_on_button_pressed)
		if node.has_signal("mouse_entered") and not node.mouse_entered.is_connected(_on_button_hover):
			node.mouse_entered.connect(_on_button_hover)

func _on_button_pressed() -> void:
	play("button_click")

func _on_button_hover() -> void:
	play("button_hover")

# ═══════════════════════════════════════════════════════════════
# MUSIC SYSTEM
# ═══════════════════════════════════════════════════════════════

var _music_player: AudioStreamPlayer = null
var _current_music: String = ""
var _current_music_path: String = ""
var _last_played: Dictionary = {}  # category -> last path played
var _stage_first_played: Dictionary = {}  # stage_index -> bool (track if first song played)
var _shuffle_queues: Dictionary = {}  # category -> Array of shuffled paths remaining

const MUSIC_DIR = "res://assets/audio/Music/"
const MUSIC_VOLUME = -20.0

# --- Track pools ---

# Stage-specific "first entry" tracks — TODO: create these tracks
const STAGE_FIRST_TRACKS = {}

# General battle pool — randomized after the first song, or for stages without a "First" track
const BATTLE_POOL_FILES = [
	"Aluminum Thunder.ogg",
	"Aluminum Thunder 2.ogg",
	"Arcade Iron.ogg",
	"Arcade Iron 2.ogg",
	"metal_01.ogg",
	"metal_02.ogg",
	"metal_03.ogg",
	"metal_04.ogg",
	"metal_05.ogg",
	"metal_06.ogg",
	"metal_07.ogg",
	"metal_08.ogg",
	"Pixel Guillotine.ogg",
	"Pixel Guillotine 2.ogg",
	"Pixel Iron Heartbeat.ogg",
	"Pixel Iron Heartbeat (1).ogg",
]

const HUB_POOL_FILES = [
	"hub_song_1.ogg",
	"hub_song_2.ogg",
]

const MENU_TRACK = "main_menu_song.ogg"
const BOSS_TRACK = ""  # TODO: create boss_battle.ogg
const VICTORY_TRACK = "victory_theme.ogg"
const GAME_OVER_TRACK = "game_over.ogg"

# Build full paths and filter to only existing files
func _build_pool(files: Array) -> Array:
	var pool: Array = []
	for f in files:
		var path = MUSIC_DIR + f
		if ResourceLoader.exists(path):
			pool.append(path)
	return pool

func _pick_from_pool(pool: Array, category: String) -> String:
	if pool.is_empty():
		return ""
	# Shuffle-bag: play every track before repeating any
	if not _shuffle_queues.has(category) or _shuffle_queues[category].is_empty():
		var shuffled = pool.duplicate()
		# Fisher-Yates shuffle
		for i in range(shuffled.size() - 1, 0, -1):
			var j = randi() % (i + 1)
			var tmp = shuffled[i]
			shuffled[i] = shuffled[j]
			shuffled[j] = tmp
		# Avoid repeating the last song from the previous cycle
		var last = _last_played.get(category, "")
		if last != "" and shuffled.size() > 1 and shuffled[0] == last:
			# Swap first track with a random later position
			var swap_idx = (randi() % (shuffled.size() - 1)) + 1
			var tmp = shuffled[0]
			shuffled[0] = shuffled[swap_idx]
			shuffled[swap_idx] = tmp
		_shuffle_queues[category] = shuffled
	var pick = _shuffle_queues[category].pop_front()
	_last_played[category] = pick
	return pick

func _get_single_track(filename: String) -> String:
	var path = MUSIC_DIR + filename
	if ResourceLoader.exists(path):
		return path
	return ""

# --- Public API ---

func play_music(track_name: String, fade_in: float = 1.0) -> void:
	if track_name == _current_music and _music_player and _music_player.playing:
		return
	stop_music(0.5)
	_current_music = track_name
	if not music_enabled:
		return

	var path = _resolve_music_path(track_name)
	if path == "":
		return
	_current_music_path = path

	await get_tree().create_timer(0.5).timeout
	if _current_music != track_name:
		return

	var stream = load(path)
	if not stream:
		return
	if _music_player and is_instance_valid(_music_player):
		_music_player.stop()
		_music_player.queue_free()
		_music_player = null
	_music_player = AudioStreamPlayer.new()
	_music_player.stream = stream
	_music_player.volume_db = -40.0
	_music_player.bus = "Music"
	_music_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_music_player)
	_music_player.play()
	var tw = create_tween()
	tw.tween_property(_music_player, "volume_db", MUSIC_VOLUME, fade_in)
	_music_player.finished.connect(_on_music_finished.bind(track_name))

func _resolve_music_path(track_name: String) -> String:
	match track_name:
		"main_menu":
			var p = _get_single_track(MENU_TRACK)
			return p if p != "" else _get_single_track("main_menu.ogg")
		"base_hub":
			return _pick_from_pool(_build_pool(HUB_POOL_FILES), "hub")
		"arena_combat":
			return _pick_combat_track()
		"boss_battle":
			var p = _get_single_track(BOSS_TRACK)
			return p if p != "" else _pick_from_pool(_build_pool(BATTLE_POOL_FILES), "combat")
		"victory_theme":
			return _get_single_track(VICTORY_TRACK)
		"game_over":
			return _get_single_track(GAME_OVER_TRACK)
		_:
			# Fallback: try loading as-is from pool
			return _pick_from_pool(_build_pool(BATTLE_POOL_FILES), "combat")

func _pick_combat_track() -> String:
	# First time entering a stage — play the stage's intro track
	var sd = get_node_or_null("/root/StageData")
	if sd:
		# Try multiple wave references to find the current stage
		var wave = maxi(WaveManager.current_wave, maxi(GameState.current_wave, 1))
		var stage_idx = sd.get_stage_index(wave)
		pass  # Debug removed

		if not _stage_first_played.get(stage_idx, false):
			_stage_first_played[stage_idx] = true
			if stage_idx in STAGE_FIRST_TRACKS:
				var path = _get_single_track(STAGE_FIRST_TRACKS[stage_idx])
				pass
				if path != "":
					return path

	return _pick_from_pool(_build_pool(BATTLE_POOL_FILES), "combat")

func reset_stage_tracking() -> void:
	# Call this on new run to re-enable "First" tracks
	_stage_first_played.clear()

func stop_music(fade_out: float = 1.0) -> void:
	_current_music = ""
	if _music_player and is_instance_valid(_music_player):
		var old = _music_player
		_music_player = null
		var tw = old.create_tween()
		tw.tween_property(old, "volume_db", -40.0, fade_out)
		tw.tween_callback(old.queue_free)

func _on_music_finished(track_name: String) -> void:
	if _current_music == track_name:
		# Pick a different track from the same category
		var new_path = _resolve_music_path(track_name)
		if _music_player and is_instance_valid(_music_player):
			if new_path != "" and ResourceLoader.exists(new_path):
				_music_player.stream = load(new_path)
				_current_music_path = new_path
				_music_player.play()

# ═══════════════════════════════════════════════════════════════
# SFX
# ═══════════════════════════════════════════════════════════════

func set_music_volume(val: float) -> void:
	music_volume = val
	music_enabled = val > 0.0
	var bus_idx = AudioServer.get_bus_index("Music")
	if bus_idx >= 0:
		if val <= 0.0:
			AudioServer.set_bus_mute(bus_idx, true)
			stop_music(0.5)
		else:
			AudioServer.set_bus_mute(bus_idx, false)
			AudioServer.set_bus_volume_db(bus_idx, linear_to_db(val))
			if not _music_player or not is_instance_valid(_music_player) or not _music_player.playing:
				if _current_music != "":
					play_music(_current_music)

func set_sfx_volume(val: float) -> void:
	sfx_volume = val
	sfx_enabled = val > 0.0
	var bus_idx = AudioServer.get_bus_index("SFX")
	if bus_idx >= 0:
		if val <= 0.0:
			AudioServer.set_bus_mute(bus_idx, true)
		else:
			AudioServer.set_bus_mute(bus_idx, false)
			AudioServer.set_bus_volume_db(bus_idx, linear_to_db(val))
	var ui_idx = AudioServer.get_bus_index("UI")
	if ui_idx >= 0:
		if val <= 0.0:
			AudioServer.set_bus_mute(ui_idx, true)
		else:
			AudioServer.set_bus_mute(ui_idx, false)
			AudioServer.set_bus_volume_db(ui_idx, linear_to_db(val))

func has_sound(sfx_name: String) -> bool:
	return sfx_name in _players

func play(sfx_name: String, pitch_rand: float = 0.0) -> void:
	if not sfx_enabled:
		return
	if sfx_name in _players:
		var p: AudioStreamPlayer = _players[sfx_name]
		if pitch_rand > 0.0:
			p.pitch_scale = randf_range(1.0 - pitch_rand, 1.0 + pitch_rand)
		else:
			p.pitch_scale = 1.0
		p.play()
