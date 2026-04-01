extends EnemyBase

# Obsidian Golem — extremely tough tank with armor that absorbs first 3 hits

var armor_hits: int = 3

func _ready() -> void:
	enemy_type       = "obsidian_golem"
	max_health       = 200
	move_speed       = 18.0
	damage           = 40
	xp_value         = 45
	contact_cooldown = 1.6
	super._ready()

func take_damage(amount: int, from_pos: Vector2 = Vector2.ZERO) -> void:
	if is_dead: return

	if armor_hits > 0:
		armor_hits -= 1
		# Show "ARMOR" text instead of damage number
		_show_armor_text()
		# Flash gray to indicate armor absorb
		_flash_color(Color(0.6, 0.6, 0.6))
		# Apply knockback even through armor
		if from_pos != Vector2.ZERO:
			knockback = (global_position - from_pos).normalized() * 140.0
		# When armor breaks, flash white brightly
		if armor_hits == 0:
			_flash_color(Color(3.0, 3.0, 3.0))
			_show_shatter_text()
		return

	super.take_damage(amount, from_pos)

func _flash_color(color: Color) -> void:
	if sprite:
		sprite.modulate = color
		var tw = create_tween()
		tw.tween_property(sprite, "modulate", Color.WHITE, 0.2)
	if _dot:
		_dot.modulate = color
		var tw2 = create_tween()
		tw2.tween_property(_dot, "modulate", Color.WHITE, 0.2)

func _show_armor_text() -> void:
	var lbl = Label.new()
	lbl.text = "ARMOR"
	lbl.z_index = 20
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	lbl.add_theme_constant_override("shadow_offset_x", 1)
	lbl.add_theme_constant_override("shadow_offset_y", 1)
	lbl.position = global_position + Vector2(randf_range(-8, 8), -16)
	var parent = get_parent() if get_parent() else self
	parent.add_child(lbl)
	var tw = lbl.create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "position:y", lbl.position.y - 22.0, 0.5).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.5).set_delay(0.25)
	tw.set_parallel(false)
	tw.tween_callback(lbl.queue_free)

func _show_shatter_text() -> void:
	var lbl = Label.new()
	lbl.text = "SHATTER!"
	lbl.z_index = 20
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 0.4))
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	lbl.add_theme_constant_override("shadow_offset_x", 1)
	lbl.add_theme_constant_override("shadow_offset_y", 1)
	lbl.position = global_position + Vector2(randf_range(-6, 6), -24)
	var parent = get_parent() if get_parent() else self
	parent.add_child(lbl)
	var tw = lbl.create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "position:y", lbl.position.y - 28.0, 0.7).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.7).set_delay(0.3)
	tw.set_parallel(false)
	tw.tween_callback(lbl.queue_free)
