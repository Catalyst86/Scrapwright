extends EnemyBase

# Fungal Brute — heavy tank, spawns 2 spore walkers at half health

var has_spawned_minions: bool = false

func _ready() -> void:
	enemy_type       = "fungal_brute"
	max_health       = 160
	move_speed       = 22.0
	damage           = 32
	xp_value         = 35
	contact_cooldown = 1.6
	knockback_resistance = 0.75  # Heavy — takes only 25% knockback
	super._ready()

func take_damage(amount: int, from_pos: Vector2 = Vector2.ZERO) -> void:
	super.take_damage(amount, from_pos)
	if not is_dead and not has_spawned_minions and health < max_health / 2:
		has_spawned_minions = true
		_spawn_minions()

func _spawn_minions() -> void:
	var scene = load("res://scenes/enemies/enemy_spore_walker.tscn")
	if not scene: return
	var offsets = [Vector2(-20, 0), Vector2(20, 0)]
	for offset in offsets:
		var minion = scene.instantiate()
		minion.global_position = global_position + offset
		minion.died.connect(func(_xp: int = 0):
			if not WaveManager.wave_active: return
			WaveManager.enemies_alive = maxi(0, WaveManager.enemies_alive - 1)
		)
		var parent = get_parent()
		if parent:
			parent.add_child(minion)
		WaveManager.enemies_alive += 1
