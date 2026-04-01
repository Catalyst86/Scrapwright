@tool
extends EditorScript

# ============================================================
# Run once: Script menu > Run  (Ctrl+Shift+X)
# Creates player_frames.tres and enemy sprite frame resources.
# Requires sprites to be in assets/sprites/ already.
# ============================================================

func _run() -> void:
	print("=== Scrapwright: Building sprite frame resources ===")
	_build_player_frames()
	_build_enemy_frames("rusher")
	_build_enemy_frames("shooter")
	_build_enemy_frames("tank")
	_build_enemy_frames("flyer")
	_build_enemy_frames("exploder")
	print("=== Done! Reload scenes to see sprites. ===")

# ─── Player ────────────────────────────────────────────────

func _build_player_frames() -> void:
	var sf = SpriteFrames.new()
	sf.remove_animation("default")

	var p = "res://assets/sprites/player/"

	_add_single(sf, "idle",     p + "player_idle.png",    5.0,  true)
	_add_multi(sf,  "walk_s",   _seq(p, "walk_s_", 4),    8.0,  true)
	_add_multi(sf,  "walk_n",   _seq(p, "walk_n_", 4),    8.0,  true)
	_add_multi(sf,  "walk_e",   _seq(p, "walk_e_", 4),    8.0,  true)
	_add_multi(sf,  "walk_w",   _seq(p, "walk_w_", 4),    8.0,  true)
	_add_multi(sf,  "throw",    _seq(p, "throw_",  4),    10.0, false)
	_add_single(sf, "salvage",  p + "player_salvage.png", 6.0,  true)
	_add_single(sf, "hurt",     p + "player_hurt.png",    8.0,  false)
	_add_single(sf, "death",    p + "player_death.png",   5.0,  false)

	var path = "res://resources/player_frames.tres"
	_ensure_dir("res://resources")
	ResourceSaver.save(sf, path)
	print("Saved: " + path)

# ─── Enemies ───────────────────────────────────────────────

func _build_enemy_frames(enemy_type: String) -> void:
	var sf = SpriteFrames.new()
	sf.remove_animation("default")

	var base   = "res://assets/sprites/enemies/"
	var sheets = "res://assets/sprites/animations/"

	# Single idle frame from the static enemy sprite
	_add_single(sf, "idle", base + "enemy_%s.png" % enemy_type, 4.0, true)

	# Walk & die from horizontal spritesheets (4 frames each, 256×64)
	_add_hstrip(sf, "walk", sheets + "enemy_%s_walk_sheet.png" % enemy_type, 4, 8.0, true)
	_add_hstrip(sf, "die",  sheets + "enemy_%s_die_sheet.png"  % enemy_type, 4, 6.0, false)

	var path = "res://resources/enemy_%s_frames.tres" % enemy_type
	ResourceSaver.save(sf, path)
	print("Saved: " + path)

# ─── Helpers ───────────────────────────────────────────────

func _seq(base_path: String, prefix: String, count: int) -> Array:
	var arr = []
	for i in count:
		arr.append(base_path + prefix + str(i) + ".png")
	return arr

func _add_single(sf: SpriteFrames, anim: String, path: String, speed: float, loop: bool) -> void:
	if not ResourceLoader.exists(path):
		push_warning("Missing: " + path)
		_add_empty(sf, anim, speed, loop)
		return
	sf.add_animation(anim)
	sf.set_animation_speed(anim, speed)
	sf.set_animation_loop(anim, loop)
	var tex = load(path) as Texture2D
	if tex:
		sf.add_frame(anim, tex)
	else:
		push_warning("Could not load: " + path)

func _add_multi(sf: SpriteFrames, anim: String, paths: Array, speed: float, loop: bool) -> void:
	var loaded = []
	for p in paths:
		if ResourceLoader.exists(p):
			var tex = load(p) as Texture2D
			if tex: loaded.append(tex)
	if loaded.is_empty():
		_add_empty(sf, anim, speed, loop)
		return
	sf.add_animation(anim)
	sf.set_animation_speed(anim, speed)
	sf.set_animation_loop(anim, loop)
	for tex in loaded:
		sf.add_frame(anim, tex)

func _add_hstrip(sf: SpriteFrames, anim: String, sheet_path: String, frame_count: int, speed: float, loop: bool) -> void:
	if not ResourceLoader.exists(sheet_path):
		push_warning("Missing sheet: " + sheet_path)
		_add_empty(sf, anim, speed, loop)
		return
	var sheet = load(sheet_path) as Texture2D
	if not sheet:
		_add_empty(sf, anim, speed, loop)
		return
	sf.add_animation(anim)
	sf.set_animation_speed(anim, speed)
	sf.set_animation_loop(anim, loop)
	var fw = sheet.get_width() / frame_count
	var fh = sheet.get_height()
	for i in frame_count:
		var atlas = AtlasTexture.new()
		atlas.atlas  = sheet
		atlas.region = Rect2(i * fw, 0, fw, fh)
		sf.add_frame(anim, atlas)

func _add_empty(sf: SpriteFrames, anim: String, speed: float, loop: bool) -> void:
	if not sf.has_animation(anim):
		sf.add_animation(anim)
	sf.set_animation_speed(anim, speed)
	sf.set_animation_loop(anim, loop)

func _ensure_dir(path: String) -> void:
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(path)):
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path))
