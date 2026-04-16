class_name PerkEffects

# ============================================================
# PerkEffects — shared installer for perk-driven in-arena timers
# Consolidates the bug_swarm / vine_snare / perk_regen installation
# that was previously triplicated across arena.gd, junkyard_v2.gd,
# and level_up.gd. (Audit FP-17 / A6)
# ============================================================

const BUG_SWARM_RADIUS := 80.0
const BUG_SWARM_TICK := 1.0
const BUG_SWARM_DAMAGE := 3

const VINE_SNARE_RADIUS := 100.0
const VINE_SNARE_TICK := 0.5
const VINE_SNARE_SLOW := 0.6  # enemy move_speed multiplier while in range

const PERK_REGEN_INTERVAL := 3.0
const PERK_REGEN_PCT := 0.01  # 1% max HP per tick


static func install_bug_swarm(arena: Node, player: Node) -> void:
	if not _valid(arena) or arena.has_node("BugSwarmTimer"):
		return
	# VFX — reuse an animated sprite sheet if available, otherwise a rotating static sprite.
	if _valid(player) and not player.has_node("BugSwarmVFX"):
		var sheet_path := "res://assets/sprites/effects/bug_swarm_anim_sheet.png"
		var static_path := "res://assets/sprites/effects/bug_swarm.png"
		var spr: Node = null
		if ResourceLoader.exists(sheet_path) and arena.has_method("_make_anim_sprite"):
			spr = arena.call("_make_anim_sprite", sheet_path, 9, 10.0, "BugSwarmVFX", 0.6, Color(1, 1, 1, 0.7), 5)
		elif ResourceLoader.exists(static_path):
			var tex = load(static_path)
			var s = Sprite2D.new()
			s.name = "BugSwarmVFX"
			s.texture = tex
			s.scale = Vector2(0.6, 0.6)
			s.modulate = Color(1, 1, 1, 0.7)
			s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			s.z_index = 5
			# Rotate continuously so it reads as a swarm.
			var rot = Timer.new()
			rot.name = "BugSwarmRotate"
			rot.wait_time = 0.03
			rot.autostart = true
			rot.process_mode = Node.PROCESS_MODE_INHERIT
			rot.timeout.connect(func():
				if is_instance_valid(s):
					s.rotation += 0.06
			)
			player.add_child(s)
			player.add_child(rot)
			spr = s
		if spr:
			# _make_anim_sprite paths already added the child; skip if it's already in tree.
			if spr is Node and not spr.is_inside_tree():
				player.add_child(spr)
	# Damage tick.
	var bug_timer := Timer.new()
	bug_timer.name = "BugSwarmTimer"
	bug_timer.wait_time = BUG_SWARM_TICK
	bug_timer.autostart = true
	bug_timer.process_mode = Node.PROCESS_MODE_INHERIT
	bug_timer.timeout.connect(func():
		if not _valid(player):
			return
		var enemies: Array = _enemies(arena)
		for enemy in enemies:
			if not is_instance_valid(enemy) or enemy.get("is_dead"):
				continue
			if player.global_position.distance_to(enemy.global_position) < BUG_SWARM_RADIUS:
				if enemy.has_method("take_damage"):
					enemy.take_damage(BUG_SWARM_DAMAGE, player.global_position)
	)
	arena.add_child(bug_timer)


static func install_vine_snare(arena: Node, player: Node) -> void:
	if not _valid(arena) or arena.has_node("VineSnareTimer"):
		return
	if _valid(player) and not player.has_node("VineSnareVFX"):
		var sheet_path := "res://assets/sprites/effects/vine_snare_anim_sheet.png"
		var static_path := "res://assets/sprites/effects/vine_snare.png"
		if ResourceLoader.exists(sheet_path) and arena.has_method("_make_anim_sprite"):
			var spr = arena.call("_make_anim_sprite", sheet_path, 9, 8.0, "VineSnareVFX", 0.8, Color(0.6, 1.0, 0.5, 0.5), -1)
			if spr and not spr.is_inside_tree():
				player.add_child(spr)
		elif ResourceLoader.exists(static_path):
			var tex = load(static_path)
			var s = Sprite2D.new()
			s.name = "VineSnareVFX"
			s.texture = tex
			s.scale = Vector2(0.8, 0.8)
			s.modulate = Color(0.6, 1.0, 0.5, 0.5)
			s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			s.z_index = -1
			player.add_child(s)
			var pulse = player.create_tween().set_loops()
			pulse.tween_property(s, "scale", Vector2(0.9, 0.9), 0.8).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
			pulse.tween_property(s, "scale", Vector2(0.7, 0.7), 0.8).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	var vine_timer := Timer.new()
	vine_timer.name = "VineSnareTimer"
	vine_timer.wait_time = VINE_SNARE_TICK
	vine_timer.autostart = true
	vine_timer.process_mode = Node.PROCESS_MODE_INHERIT
	vine_timer.timeout.connect(func():
		if not _valid(player):
			return
		var enemies: Array = _enemies(arena)
		for enemy in enemies:
			if not is_instance_valid(enemy) or enemy.get("is_dead"):
				continue
			if not ("move_speed" in enemy and "_base_move_speed" in enemy):
				continue
			if player.global_position.distance_to(enemy.global_position) < VINE_SNARE_RADIUS:
				enemy.move_speed = enemy._base_move_speed * VINE_SNARE_SLOW
			else:
				enemy.move_speed = enemy._base_move_speed
	)
	arena.add_child(vine_timer)


static func install_perk_regen(arena: Node) -> void:
	if not _valid(arena) or arena.has_node("PerkRegenTimer"):
		return
	var t := Timer.new()
	t.name = "PerkRegenTimer"
	t.wait_time = PERK_REGEN_INTERVAL
	t.autostart = true
	t.process_mode = Node.PROCESS_MODE_INHERIT
	t.timeout.connect(func():
		GameState.heal(maxi(1, int(GameState.player_max_health * PERK_REGEN_PCT)))
	)
	arena.add_child(t)


static func _valid(n: Node) -> bool:
	return n != null and is_instance_valid(n)


static func _enemies(arena: Node) -> Array:
	# Prefer the WaveManager cache to avoid O(n) group queries (audit D7).
	if WaveManager and WaveManager.get("_cached_enemies") is Array and not WaveManager._cached_enemies.is_empty():
		return WaveManager._cached_enemies
	if _valid(arena):
		return arena.get_tree().get_nodes_in_group("enemies")
	return []
