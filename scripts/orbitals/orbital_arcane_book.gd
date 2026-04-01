extends OrbitalWeapon

func _ready() -> void:
	weapon_id = "arcane_book"
	super._ready()

func _fire(target: Node) -> void:
	if not is_instance_valid(target):
		return
	var arena = _get_arena()
	if not arena:
		return
	# Glowing magic missile
	var missile = Node2D.new()
	missile.position = global_position
	missile.z_index = 10
	arena.add_child(missile)
	# Outer glow
	var glow = Polygon2D.new()
	var glow_pts: PackedVector2Array = []
	for i in 8:
		var angle = TAU * i / 8.0
		glow_pts.append(Vector2(cos(angle), sin(angle)) * 4.0)
	glow.polygon = glow_pts
	glow.color = Color(0.6, 0.3, 1.0, 0.5)
	missile.add_child(glow)
	# Inner core
	var core = Polygon2D.new()
	var core_pts: PackedVector2Array = []
	for i in 8:
		var angle = TAU * i / 8.0
		core_pts.append(Vector2(cos(angle), sin(angle)) * 2.0)
	core.polygon = core_pts
	core.color = Color(0.85, 0.7, 1.0, 0.95)
	missile.add_child(core)

	# Missile trail — spawn particles behind it
	var trail_timer = Timer.new()
	trail_timer.wait_time = 0.05
	trail_timer.autostart = true
	missile.add_child(trail_timer)
	trail_timer.timeout.connect(func():
		if not is_instance_valid(missile) or not is_instance_valid(arena): return
		var trail = Polygon2D.new()
		var tpts: PackedVector2Array = []
		for ti in 6:
			var ta = TAU * ti / 6.0
			tpts.append(Vector2(cos(ta), sin(ta)) * 1.5)
		trail.polygon = tpts
		trail.color = Color(0.8, 0.5, 1.0, 0.6)
		trail.position = missile.position + Vector2(randf_range(-2, 2), randf_range(-2, 2))
		trail.z_index = 9
		arena.add_child(trail)
		var ttw = trail.create_tween()
		ttw.tween_property(trail, "modulate:a", 0.0, 0.2)
		ttw.parallel().tween_property(trail, "scale", Vector2(0.2, 0.2), 0.2)
		ttw.tween_callback(trail.queue_free)
	)

	var dest = target.global_position
	var target_ref = weakref(target)
	var tw = missile.create_tween()
	tw.tween_property(missile, "position", dest, 0.5).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		var t = target_ref.get_ref()
		if t and is_instance_valid(t) and not t.get("is_dead"):
			t.take_damage(weapon_damage, missile.position)
		# Arcane burst — purple sparkles
		for i in range(6):
			var spark = Polygon2D.new()
			var spts: PackedVector2Array = []
			for si in 5:
				var sa = TAU * si / 5.0
				spts.append(Vector2(cos(sa), sin(sa)) * 1.5)
			spark.polygon = spts
			spark.color = Color(randf_range(0.6, 0.9), randf_range(0.3, 0.5), 1.0, 0.8)
			spark.position = missile.position + Vector2(randf_range(-4, 4), randf_range(-4, 4))
			spark.z_index = 11
			arena.add_child(spark)
			var stw = spark.create_tween()
			stw.tween_property(spark, "position", spark.position + Vector2(randf_range(-12, 12), randf_range(-12, 12)), 0.3)
			stw.parallel().tween_property(spark, "modulate:a", 0.0, 0.3)
			stw.tween_callback(spark.queue_free)
		missile.queue_free()
	)
