extends OrbitalWeapon

func _ready() -> void:
	weapon_id = "flame_wisp"
	super._ready()

func _fire(target: Node) -> void:
	if not is_instance_valid(target):
		return
	var arena = _get_arena()
	if not arena:
		return

	# Build a proper fireball visual
	var fireball = Node2D.new()
	fireball.position = global_position
	fireball.z_index = 10
	arena.add_child(fireball)

	# Core glow (bright yellow-white center)
	var core = Polygon2D.new()
	var core_pts: PackedVector2Array = []
	for i in 8:
		var angle = TAU * i / 8.0
		core_pts.append(Vector2(cos(angle), sin(angle)) * 3.0)
	core.polygon = core_pts
	core.color = Color(1.0, 0.95, 0.6, 0.95)
	fireball.add_child(core)

	# Outer flame (orange)
	var outer = Polygon2D.new()
	var outer_pts: PackedVector2Array = []
	for i in 8:
		var angle = TAU * i / 8.0
		var r = 5.0 if i % 2 == 0 else 3.5  # Spiky flame shape
		outer_pts.append(Vector2(cos(angle), sin(angle)) * r)
	outer.polygon = outer_pts
	outer.color = Color(1.0, 0.4, 0.05, 0.8)
	fireball.add_child(outer)
	outer.z_index = -1

	var dest = target.global_position
	var dist = global_position.distance_to(dest)
	var duration = clampf(dist / 120.0, 0.1, 1.5)
	var target_ref = weakref(target)

	# Spawn trailing embers during flight
	var trail_timer = Timer.new()
	trail_timer.wait_time = 0.05
	trail_timer.autostart = true
	trail_timer.timeout.connect(func():
		if not is_instance_valid(fireball) or not is_instance_valid(arena): return
		var ember = Polygon2D.new()
		var epts: PackedVector2Array = []
		for ei in 5:
			var ea = TAU * ei / 5.0
			epts.append(Vector2(cos(ea), sin(ea)) * 1.0)
		ember.polygon = epts
		ember.color = Color(1.0, randf_range(0.3, 0.7), 0.0, 0.8)
		ember.position = fireball.position + Vector2(randf_range(-2, 2), randf_range(-2, 2))
		ember.z_index = 9
		arena.add_child(ember)
		var tw2 = ember.create_tween()
		tw2.tween_property(ember, "modulate:a", 0.0, 0.25)
		tw2.parallel().tween_property(ember, "scale", Vector2(0.3, 0.3), 0.25)
		tw2.tween_callback(ember.queue_free)
	)
	fireball.add_child(trail_timer)

	# Animate rotation during flight
	var spin_tw = fireball.create_tween()
	spin_tw.tween_property(fireball, "rotation", TAU, duration).set_trans(Tween.TRANS_LINEAR)

	var tw = fireball.create_tween()
	tw.tween_property(fireball, "position", dest, duration)
	tw.tween_callback(func():
		trail_timer.stop()
		var t = target_ref.get_ref()
		if t and is_instance_valid(t) and not t.get("is_dead"):
			t.take_damage(weapon_damage, fireball.position)
		_show_fire_burst(fireball.position, 12.0)
		fireball.queue_free()
	)
