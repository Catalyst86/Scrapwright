extends EnemyBase

# Frost Warden — Stage 4 Boss
# Ice shield (absorbs first 5 hits), spawns frost sprites every 8s, ice blast AoE every 5s

var ice_shield_hits: int = 5
var spawn_timer: float = 0.0
var ice_blast_timer: float = 0.0

const SPAWN_INTERVAL = 8.0
const SPAWN_COUNT = 2
const ICE_BLAST_INTERVAL = 5.0
const ICE_BLAST_RANGE = 55.0
const ICE_BLAST_DAMAGE = 15

func _ready() -> void:
	enemy_type       = "frost_warden"
	max_health       = 600
	move_speed       = 30.0
	damage           = 20
	xp_value         = 200
	contact_cooldown = 1.5
	super._ready()
	if health_bar:
		health_bar.visible = true

func _physics_process(delta: float) -> void:
	if is_dead: return
	spawn_timer += delta
	ice_blast_timer += delta

	if spawn_timer >= SPAWN_INTERVAL:
		spawn_timer = 0.0
		_spawn_frost_sprites()

	if ice_blast_timer >= ICE_BLAST_INTERVAL:
		ice_blast_timer = 0.0
		_ice_blast()

	super._physics_process(delta)

func take_damage(amount: int, from_pos: Vector2 = Vector2.ZERO) -> void:
	if ice_shield_hits > 0:
		ice_shield_hits -= 1
		# Show shield absorb visual
		if sprite:
			sprite.modulate = Color(0.5, 0.8, 1.5)
			var tw = create_tween()
			tw.tween_property(sprite, "modulate", Color.WHITE, 0.15)
		_show_damage_number(0)
		# Shield break visual when depleted
		if ice_shield_hits <= 0:
			_shield_break_visual()
		return
	super.take_damage(amount, from_pos)

func _shield_break_visual() -> void:
	var flash = ColorRect.new()
	flash.color = Color(0.5, 0.8, 1.0, 0.5)
	flash.size = Vector2(60, 60)
	flash.position = global_position - Vector2(30, 30)
	flash.z_index = 5
	var parent = get_parent()
	if parent:
		parent.add_child(flash)
		var tw = flash.create_tween()
		tw.tween_property(flash, "modulate:a", 0.0, 0.4)
		tw.tween_callback(flash.queue_free)

func _spawn_frost_sprites() -> void:
	var sprite_scene = load("res://scenes/enemies/enemy_frost_sprite.tscn")
	if not sprite_scene: return
	var parent = get_parent()
	if not parent: return
	for i in SPAWN_COUNT:
		var minion = sprite_scene.instantiate()
		var offset = Vector2(randf_range(-20, 20), randf_range(-20, 20))
		minion.global_position = global_position + offset
		minion.died.connect(func(_xp: int = 0):
			if not WaveManager.wave_active: return
			WaveManager.enemies_alive = maxi(0, WaveManager.enemies_alive - 1)
			WaveManager.emit_signal("enemies_remaining_changed", WaveManager.get_wave_enemy_count())
		)
		parent.add_child(minion)
		WaveManager.enemies_alive += 1
		WaveManager.emit_signal("enemies_remaining_changed", WaveManager.get_wave_enemy_count())

func _ice_blast() -> void:
	if not player_ref or not is_instance_valid(player_ref): return
	_play_attack_anim()

	# Visual — expanding ice ring
	var ring = ColorRect.new()
	ring.size = Vector2(4, 4)
	ring.position = global_position - Vector2(2, 2)
	ring.color = Color(0.4, 0.7, 1.0, 0.6)
	ring.z_index = -1
	var parent = get_parent()
	if parent:
		parent.add_child(ring)
		var tw = ring.create_tween()
		tw.set_parallel(true)
		tw.tween_property(ring, "size", Vector2(ICE_BLAST_RANGE * 2, ICE_BLAST_RANGE * 2), 0.4)
		tw.tween_property(ring, "position", global_position - Vector2(ICE_BLAST_RANGE, ICE_BLAST_RANGE), 0.4)
		tw.tween_property(ring, "modulate:a", 0.0, 0.4)
		tw.set_parallel(false)
		tw.tween_callback(ring.queue_free)

	# Damage player if in range
	var dist = global_position.distance_to(player_ref.global_position)
	if dist < ICE_BLAST_RANGE:
		if player_ref.has_method("take_damage"):
			player_ref.take_damage(ICE_BLAST_DAMAGE)
		if player_ref.has_method("apply_slow"):
			player_ref.apply_slow(0.4, 2.0)
