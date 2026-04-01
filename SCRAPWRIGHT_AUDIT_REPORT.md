# SCRAPWRIGHT — Comprehensive Debug Audit Report

## Executive Summary

| Metric | Value |
|--------|-------|
| GDScript files scanned | 80 |
| Scene files scanned (.tscn) | 57 |
| Resource files scanned (.tres) | 2 |
| Config files scanned (.cfg/.godot) | 2 (project.godot, default_bus_layout.tres) |
| Total issues found | **45** |
| **Overall Health Rating** | **C** |

The project is playable but has 13 crash-risk issues from unguarded awaits during scene transitions, two completely non-functional game systems (Vine Snare perk and card deck reapply), dev debug tools left in production code, dangling signal connections from dead enemies to persistent Area2D nodes, an O(n^2) performance hotspot in enemy AI, and 42+ print statements that should be removed before shipping.

### Top 5 Most Urgent Issues

1. **CRITICAL** — Vine Snare perk references wrong property names (`speed`/`base_speed` instead of `move_speed`/`_base_move_speed`) — completely broken
2. **CRITICAL** — 10+ `await create_timer` calls across enemy scripts and arena.gd without `is_inside_tree()` guards — crash on scene change
3. **CRITICAL** — Dev god mode (F1), wave jump (F2), wave skip (F3/F4) left in production player.gd
4. **CRITICAL** — Dangling signal connections: dead enemies' methods connected to persistent Area2D nodes (spore clouds, fire dots) — errors every frame after enemy dies
5. **WARNING** — O(n^2) enemy separation check runs every physics frame for every enemy — causes frame drops with 50+ enemies

---

## Issues by Severity

---

### CRITICAL — Will crash, corrupt data, or cause game-breaking bugs

---

#### C01: Vine Snare perk uses wrong property names (BROKEN FEATURE)
**File**: `scripts/arena.gd:1179-1183`

```gdscript
# BROKEN — enemy_base.gd uses move_speed / _base_move_speed, not speed / base_speed
if "speed" in enemy:
    enemy.speed = enemy.get("base_speed") if "base_speed" in enemy else enemy.speed * 0.6
else:
    if "speed" in enemy and "base_speed" in enemy:
        enemy.speed = enemy.base_speed
```

**What goes wrong**: The Vine Snare perk (earned by completing the Overgrowth card deck) checks for properties `speed` and `base_speed` on enemies. EnemyBase has `move_speed` and `_base_move_speed`. The `"speed" in enemy` check returns false, so the perk does absolutely nothing.

**Fix**:
```gdscript
if "move_speed" in enemy:
    enemy.move_speed = enemy._base_move_speed * 0.6
# ... and for restoration:
if "move_speed" in enemy:
    enemy.move_speed = enemy._base_move_speed
```

---

#### C02: Dev debug tools in production code
**File**: `scripts/player.gd:22-27, 345-398, 1022-1148`

```gdscript
# Line 22-27 — God mode variables
var god_mode: bool = false
var _god_label: Label = null
# ...

# Line 357-398 — F1 god mode, F2 wave jump, F3 skip wave, F4 prev wave
if event is InputEventKey and event.pressed and event.keycode == KEY_F1:
    god_mode = not god_mode
```

**What goes wrong**: Players can press F1 to become invincible with 99 keys and +100 damage. F2 opens a wave jump menu. F3 kills all enemies. F4 jumps back a wave. These are clearly marked "REMOVE BEFORE PUBLISHING" but are still present.

**Fix**: Remove all code blocks marked with `# DEV GOD MODE` and `# DEV WAVE JUMP` comments. Remove the associated variables and functions (`_dev_skip_wave`, `_dev_prev_wave`, `_show_wave_jump_ui`).

---

#### C03: Unguarded awaits crash on scene change
**File**: `scripts/enemy_base.gd:767-773`

```gdscript
func _die() -> void:
    # ... death setup ...
    await get_tree().create_timer(die_duration).timeout
    # Hold the final death frame briefly, then fade out
    await get_tree().create_timer(0.4).timeout  # NO is_inside_tree() CHECK
    if sprite:
        var tw = create_tween()
        tw.tween_property(sprite, "modulate:a", 0.0, 0.5)
        await tw.finished  # NO is_inside_tree() CHECK
    queue_free()
```

**What goes wrong**: If the player dies or the scene changes while an enemy death animation is playing, `get_tree()` returns null (node already removed from tree), causing a null access crash. This is especially likely during wave transitions.

**Fix**: Add `if not is_inside_tree(): return` guards after each await:
```gdscript
await get_tree().create_timer(die_duration).timeout
if not is_inside_tree(): return
await get_tree().create_timer(0.4).timeout
if not is_inside_tree(): return
```

---

#### C04: _play_attack_anim_then() can crash on freed enemy
**File**: `scripts/enemy_base.gd:644-669`

```gdscript
func _play_attack_anim_then(callback: Callable) -> void:
    # ...
    await get_tree().create_timer(total_dur * 0.4).timeout
    if is_instance_valid(self) and not is_dead:
        callback.call()
    await get_tree().create_timer(total_dur * 0.6).timeout
    if is_instance_valid(self) and not is_dead and sprite:
        sprite.play("walk")
```

**What goes wrong**: `is_instance_valid(self)` is checked, but `get_tree()` is called first on the second await — if the node was freed, `get_tree()` returns null and crashes before the check.

**Fix**:
```gdscript
if not is_inside_tree(): return
await get_tree().create_timer(total_dur * 0.6).timeout
if not is_instance_valid(self) or not is_inside_tree(): return
```

---

#### C05: Boss minion spawners don't guard against freed WaveManager reference
**Files**: `scripts/enemy_piston_crusher.gd:136`, `scripts/enemy_the_devourer.gd:119`, `scripts/enemy_the_architect.gd:116,130`, `scripts/enemy_spore_mother.gd:122`, `scripts/enemy_junkyard_mech.gd:108`, `scripts/enemy_fungal_brute.gd:29`, `scripts/enemy_frost_warden.gd:78`

```gdscript
minion.tree_exiting.connect(func():
    WaveManager.enemies_alive -= 1
    WaveManager.emit_signal("enemies_remaining_changed", WaveManager.get_wave_enemy_count())
)
```

**What goes wrong**: `tree_exiting` fires during scene teardown (when the entire scene tree is being freed). At that point, WaveManager autoload is still valid but `enemies_alive` could go negative, and the signal handler in the (now-freed) arena may crash.

**Fix**: Add guard:
```gdscript
minion.tree_exiting.connect(func():
    if not is_instance_valid(WaveManager) or not WaveManager.wave_active: return
    WaveManager.enemies_alive -= 1
    WaveManager.emit_signal("enemies_remaining_changed", WaveManager.get_wave_enemy_count())
)
```

---

#### C06: SpriteLoader references nonexistent resource files
**File**: `autoloads/sprite_loader.gd:10-17`

```gdscript
const PLAYER_FRAMES_PATH = "res://resources/player_frames.tres"
const ENEMY_FRAME_PATHS = {
    "EnemyRusher": "res://resources/enemy_rusher_frames.tres",
    # ...
}
```

**What goes wrong**: The `resources/` directory does not exist. These `.tres` files were never generated. The SpriteLoader silently fails (`ResourceLoader.exists()` returns false), so sprites fall back to placeholders. While not a crash, this means the SpriteLoader autoload is entirely non-functional dead code.

**Fix**: Either run `setup_sprite_frames.gd` to generate the resources, or remove SpriteLoader from autoloads since player.gd and enemy_base.gd already handle their own sprite loading.

---

#### C07: arena.gd force-completes stuck wave by externally mutating WaveManager
**File**: `scripts/arena.gd:115-117`

```gdscript
WaveManager.wave_active = false
WaveManager.emit_signal("wave_complete", WaveManager.current_wave)
```

**What goes wrong**: Arena directly sets `wave_active = false` and emits `wave_complete` signal on WaveManager, bypassing WaveManager's internal state management. This can cause the wave complete handler to fire twice if WaveManager's own `_check_wave_complete` also triggers.

**Fix**: Add a public method to WaveManager: `func force_complete_wave()` that handles this internally with proper deduplication.

---

#### C08: get_completion_bonuses() method doesn't exist in CardDB
**File**: `autoloads/game_state.gd:362-363`

```gdscript
if card_db and card_db.has_method("get_completion_bonuses"):
    var bonuses = card_db.get_completion_bonuses()
```

**What goes wrong**: CardDB defines `get_stat_bonuses()`, not `get_completion_bonuses()`. The `has_method()` check prevents a crash but silently skips applying card deck completion bonuses during `reapply_permanent_bonuses()`. Players who complete the Scrap or Lost decks get no bonus when returning from the hub.

**Fix**: Change to `card_db.has_method("get_stat_bonuses")` and `card_db.get_stat_bonuses()`.

---

#### C09: Unguarded awaits in enemy special abilities (5+ files)
**Files**: `enemy_exploder.gd:52-60`, `enemy_fungal_titan.gd:126`, `enemy_molten_wyrm.gd:163`, `enemy_spore_mother.gd:110`, `enemy_void_weaver.gd:92`

```gdscript
# enemy_exploder.gd — fuse countdown
for _i in 4:
    if is_dead: return
    await get_tree().create_timer(0.14).timeout  # NO is_inside_tree() CHECK
```

**What goes wrong**: Same pattern as C03/C04 — if the scene changes while these coroutines are running, `get_tree()` returns null. Exploders, Fungal Titans, Molten Wyrms, Spore Mothers, and Void Weavers all have this issue in their special ability loops.

**Fix**: Add `if not is_inside_tree(): return` before each `await` call.

---

#### C10: Dangling signal connections — dead enemy methods on persistent Area2Ds
**Files**: `enemy_spore_walker.gd:70`, `enemy_magma_imp.gd:99`

```gdscript
# enemy_spore_walker.gd
cloud.body_entered.connect(_on_spore_body_entered)
# cloud is parented to arena, but callback is on the spore_walker
```

**What goes wrong**: Spore clouds and fire dots are parented to the arena container and outlive the enemy that created them. When the enemy dies and is freed, the signal connection becomes a dangling reference. Godot prints errors every time a body enters these persistent areas.

**Fix**: Use lambdas instead of instance methods:
```gdscript
cloud.body_entered.connect(func(b):
    if is_instance_valid(b) and b.is_in_group("player") and b.has_method("apply_status"):
        b.apply_status("slowed", 2.0)
)
```

---

#### C11: Ember Drake fire dot tween created before node is in tree
**File**: `scripts/enemy_ember_drake.gd:170-174`

```gdscript
get_parent().call_deferred("add_child", dot)
var tw = dot.create_tween()  # dot isn't in tree yet!
```

**What goes wrong**: `call_deferred` means the dot won't be added until next frame, but `create_tween()` is called immediately. A tween on a node not in the tree produces a non-functional tween, so the fire dot never gets freed and leaks.

**Fix**: Use non-deferred `add_child()` or move tween creation into a deferred callback.

---

#### C12: Crystal Colossus / Steam Turret projectile spawn with no parent check
**Files**: `enemy_crystal_colossus.gd:89`, `enemy_steam_turret.gd:49`

```gdscript
get_parent().add_child(proj)
```

**What goes wrong**: If the enemy has no parent (freed during `_play_attack_anim_then` callback), this crashes with a null access.

**Fix**: Add `if not get_parent(): return` at the top of the shoot callback.

---

#### C13: base_hub.gd uses get_node() instead of get_node_or_null() — crashes if autoload missing
**File**: `scripts/base_hub.gd:991`

```gdscript
var jy = get_node("/root/JunkyardState")
```

**What goes wrong**: Every other JunkyardState reference in the codebase uses `get_node_or_null()`, but this one uses `get_node()`. If JunkyardState autoload is removed or misconfigured, clicking the Doggy Door crashes the game.

**Fix**: `var jy = get_node_or_null("/root/JunkyardState")` + null check.

---

#### C14: Steam Turret skips base class physics entirely
**File**: `scripts/enemy_steam_turret.gd:22-30`

```gdscript
func _physics_process(delta: float) -> void:
    if is_dead: return
    shoot_timer += delta
    # ... manual timer ticking, NO super call
```

**What goes wrong**: The turret overrides `_physics_process` without calling `super._physics_process(delta)`. This means it skips the stun system, burrow-flank checks, stuck detection, and grunt audio from EnemyBase. Most critically, **turrets cannot be stunned** — dig holes and other stun effects have no effect on them.

**Fix**: Call `super._physics_process(delta)` and override `_move_toward_player` to be a no-op.

---

### WARNING — Will cause noticeable bugs, unexpected behavior, or performance problems

---

#### W01: O(n^2) enemy separation every physics frame
**File**: `scripts/enemy_base.gd:433-448`

```gdscript
func _compute_separation() -> Vector2:
    for enemy in get_tree().get_nodes_in_group("enemies"):
        if enemy == self: continue
        var diff = global_position - enemy.global_position
        # ...
```

**What goes wrong**: Every enemy calls `get_nodes_in_group("enemies")` every frame and iterates all enemies. With 50 enemies, that's 2,500 iterations per frame. With 100 enemies (boss waves), that's 10,000. This will cause frame drops.

**Fix**: Use a spatial hash or limit separation to nearest N enemies. Or cache the group array once per frame in WaveManager and have enemies reference it:
```gdscript
# In WaveManager._process():
var _cached_enemies: Array = []
func _process(_d):
    if wave_active:
        _cached_enemies = get_tree().get_nodes_in_group("enemies")
```

---

#### W02: tree_exiting used for death counting
**File**: `autoloads/wave_manager.gd:146`

```gdscript
enemy.tree_exiting.connect(_on_enemy_died)
```

**What goes wrong**: `tree_exiting` fires for ANY reason a node leaves the tree — including scene changes, reparenting, etc. During scene teardown, ALL remaining enemies fire this signal simultaneously, potentially decrementing `enemies_alive` below 0. The `enemies_alive < 0` guard on line 154 catches this, but it's still incorrect semantics.

**Fix**: Connect to the enemy's custom `died` signal instead:
```gdscript
if enemy.has_signal("died"):
    enemy.died.connect(_on_enemy_died_proper)
enemy.tree_exiting.connect(_on_enemy_tree_exit)
```

---

#### W03: load() in spawn hot path
**File**: `autoloads/wave_manager.gd:139`

```gdscript
var scene = load(scene_path)
```

**What goes wrong**: `load()` is synchronous and hits disk every call (unless cached by ResourceLoader). During intense waves with rapid spawning, this can cause micro-stutters.

**Fix**: Cache loaded scenes:
```gdscript
var _scene_cache: Dictionary = {}

func _spawn_enemy(type: String) -> bool:
    if not type in _scene_cache:
        _scene_cache[type] = load(ENEMY_SCENES[type])
    var scene = _scene_cache[type]
```

---

#### W04: AudioManager connects to ALL buttons in entire tree
**File**: `autoloads/audio_manager.gd:57,73-77`

```gdscript
get_tree().node_added.connect(_on_node_added)

func _on_node_added(node: Node) -> void:
    if node is BaseButton:
        node.pressed.connect(_on_button_pressed)
```

**What goes wrong**: Every button that enters the tree gets a signal connection added. If buttons are freed, the connection is cleaned up by Godot. However, this runs for EVERY node added to the tree (not just buttons) — the type check runs constantly.

**Fix**: This is acceptable for a small game but could use `node is BaseButton` as early return, which it already does. Low priority.

---

#### W05: Spore Mother heal never updates health bar
**File**: `scripts/enemy_spore_mother.gd:134-137`

```gdscript
func _heal_pulse() -> void:
    health = mini(health, max_health)  # No-op
    var heal = mini(HEAL_AMOUNT, max_health - health)
    health += heal
    # Missing: health_bar.value = health
```

**What goes wrong**: After self-healing, the health bar is stale — it shows old damage even though the boss has healed. Players can't see the heal happening.

**Fix**: Add `if health_bar: health_bar.value = health` after the heal.

---

#### W06: Ranged enemies load() projectile scene every shot (10+ files)
**Files**: `enemy_shooter.gd`, `enemy_mycelium_sniper.gd`, `enemy_lava_lobber.gd`, `enemy_ice_archer.gd`, `enemy_crystal_colossus.gd`, `enemy_steam_turret.gd`, `enemy_the_architect.gd`, `enemy_scrap_king.gd`, `enemy_fungal_titan.gd`

```gdscript
var proj_scene = load("res://scenes/enemy_projectile.tscn")
```

**What goes wrong**: Called every shot cycle. With 20+ shooters each firing every 2s, this is unnecessary overhead. Godot caches loads but the hash lookup still adds up.

**Fix**: Cache as a class variable: `var _proj_scene = null` and load once in `_ready()`.

---

#### W07: enemy_projectile.gd uses _process instead of _physics_process
**File**: `scripts/enemy_projectile.gd:52`

```gdscript
func _process(delta: float) -> void:
    position += vel * delta
```

**What goes wrong**: Projectile movement is frame-rate dependent. At 30 FPS they move differently than at 60 FPS.

**Fix**: Change to `_physics_process`.

---

#### W08: Magma Imp fire dot trail creates massive node counts
**Files**: `enemy_magma_imp.gd`, `enemy_spore_walker.gd`, `enemy_lava_lobber.gd`

**What goes wrong**: Each fire dot creates 5+ Polygon2D child nodes for visual effects. Magma imps drop dots every 0.3s while moving. With 5 imps, that's ~33 dots/second, each with 5 children = 165 node creates/second, persisting for 2s. Peak node count from fire effects alone: ~660.

**Fix**: Use simpler single-Polygon2D visuals or pool the dots.

---

#### W09: Player _handle_salvage_input is dead code
**File**: `scripts/player.gd:627-651`

```gdscript
func _handle_salvage_input() -> void:
    if salvage_cooldown > 0: return
    if Input.is_action_just_pressed("salvage"):
        _try_salvage_nearby()
```

**What goes wrong**: `_handle_salvage_input()` is never called anywhere. The salvage/dig functionality is handled by `_handle_dig_input()` and `_handle_collect_input()` instead. This function and `_try_salvage_nearby()` are dead code.

**Fix**: Remove both functions.

---

#### W10: Viewport size mismatch between project.godot and code
**File**: `project.godot:35-36` vs `scripts/arena.gd:22-23`

```
# project.godot
window/size/viewport_width=960
window/size/viewport_height=540

# arena.gd
const ARENA_W = 1280
const ARENA_H = 720
```

**What goes wrong**: The viewport is 960x540 but the arena is 1280x720. The camera zoom of 2.0 means the player sees 640x360 of the arena at once. This works because the arena is meant to be larger than the viewport (scrolling), but the CLAUDE.md documentation says 480x270 which is wrong.

**Fix**: Update CLAUDE.md to reflect actual viewport size (960x540). No code change needed — the mismatch is intentional (arena > viewport for camera scrolling).

---

#### W11: Achievement "halfway_there" checks wave 42, should be wave 42
**File**: `scripts/arena.gd:280`

```gdscript
if wave_num >= 42:
    ach.check_and_unlock("halfway_there")
```

**What goes wrong**: The achievement says "Reach wave 21" but checks `wave_num >= 42`. With 84 total waves, wave 42 is exactly halfway. But the achievement description says "wave 21" — this is misleading. Either the description or the check is wrong.

**Fix**: Either change the description to "Reach wave 42" or change the check to `wave_num >= 21`.

---

#### W12: _on_health_changed damage tracking is inaccurate
**File**: `scripts/arena.gd:1047-1050`

```gdscript
if current < max_hp:
    var ach = get_node_or_null("/root/Achievements")
    if ach:
        ach.stats["damage_taken_this_wave"] = ach.stats.get("damage_taken_this_wave", 0) + 1
```

**What goes wrong**: This fires every time health_changed is emitted, including when health goes UP (healing). The condition `current < max_hp` is true even after healing — it only needs `current < max_hp` AND the change was negative. Also, it increments by 1 regardless of actual damage taken.

**Fix**:
```gdscript
# Track previous health to detect actual damage
if current < _last_known_health:
    ach.stats["damage_taken_this_wave"] += 1
_last_known_health = current
```

---

#### W13: CardDB.roll_card uses poor randomization
**File**: `autoloads/card_db.gd:74-78`

```gdscript
func roll_card() -> Dictionary:
    var card: Dictionary = {}
    for _attempt in 3:
        card = cards[randi() % cards.size()]
        if not collected.has(card.id):
            break
    return card
```

**What goes wrong**: Uses `randi() % cards.size()` which has modulo bias for non-power-of-2 sizes (40 cards). Also, if all 40 cards are collected, it still returns the last rolled card (a duplicate), but the loop variable `_attempt in 3` should be `_attempt in range(3)` — actually `for _attempt in 3` IS valid GDScript, iterating 0,1,2.

**Fix**: Use `cards.pick_random()` for better randomization:
```gdscript
card = cards.pick_random()
```

---

#### W14: DirAccess.dir_exists_absolute with relative path
**File**: `scripts/player.gd:211-216`

```gdscript
var tier_path = PUPPY_BASE.replace("res://", "") + _current_tier
if not DirAccess.dir_exists_absolute(tier_path):
```

**What goes wrong**: `PUPPY_BASE.replace("res://", "")` gives `assets/sprites/player/` which is a relative path passed to `dir_exists_absolute()`. In the editor, this resolves relative to the project root. But in an exported build, `res://` is packed into a PCK file and this relative path check will always fail.

**Fix**:
```gdscript
var tier_path = PUPPY_BASE + _current_tier
if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(tier_path)):
```

---

#### W15: Achievements toast can crash if viewport freed during await
**File**: `autoloads/achievements.gd:237`

```gdscript
await root.get_tree().process_frame
var vp_w = root.get_viewport().get_visible_rect().size.x
```

**What goes wrong**: If a scene change happens during the `await`, `root.get_viewport()` could return null or the toast_panel may no longer be valid.

**Fix**: Add null checks after the await.

---

#### W17: level_up.gd hard-coded child index navigation
**File**: `scripts/level_up.gd:367-370`

```gdscript
for i in _card_nodes.size():
    if _card_nodes[i].get_child(0).get_child(2).text == perk.name:
        chosen_idx = i
```

**What goes wrong**: Navigates the node tree by hard-coded child indices. If the card layout changes (e.g., milestone label added), this crashes with an out-of-range error or matches the wrong node.

**Fix**: Store perk id as metadata: `card.set_meta("perk_id", perk.id)` and match on that.

---

#### W18: chest.gd await in signal callback risks crash
**File**: `scripts/chest.gd:266`

```gdscript
await get_tree().process_frame
# then accesses get_viewport()
```

**What goes wrong**: Inside `_show_key_choice()` called from `body_entered` signal. After the await, the chest or viewport could be freed (scene change). Accessing `get_viewport()` after would crash.

**Fix**: Add `if not is_inside_tree(): return` after the await.

---

#### W19: hud.gd negative tween interval
**File**: `scripts/hud.gd:383`

```gdscript
_banner_tween.tween_interval(auto_hide_sec - 0.4)
```

**What goes wrong**: If `auto_hide_sec` is between 0.0 and 0.4, this creates a negative interval. The banner flashes and vanishes instantly.

**Fix**: `_banner_tween.tween_interval(maxf(auto_hide_sec - 0.4, 0.0))`

---

#### W20: destructible_prop.gd no fade delay when _vis is null
**File**: `scripts/destructible_prop.gd:194-196`

```gdscript
var tw = create_tween()
if _vis: tw.tween_property(_vis, "modulate:a", 0.0, 0.28)
tw.tween_callback(queue_free)
```

**What goes wrong**: If `_vis` is null, the tween has no property animation — just `queue_free`. The prop is freed immediately on the next frame, and all float text children (material drops, "Food!") are destroyed before the player can see them.

**Fix**: Add `tw.tween_interval(0.28)` when `_vis` is null.

---

#### W21: level_up.gd orbital weapon choice weighting
**File**: `scripts/level_up.gd:333`

```gdscript
var can_add_weapon = GameState.orbital_weapons.size() < OrbitalDB.MAX_ORBITALS or not weapon_pool.is_empty()
```

**What goes wrong**: The `or` condition makes this true whenever upgradeable weapons exist, even at max orbitals. This over-prioritizes orbital weapon choices in the level-up pool, potentially crowding out stat perks.

**Fix**: If weapon upgrades should appear at max orbitals, rename the variable. If not, change `or` to `and`.

---

#### W22: _apply_burning uses await loop — survives enemy death
**File**: `scripts/enemy_base.gd:1113-1118`

```gdscript
func _apply_burning(duration: float) -> void:
    for _i in int(duration / 0.5):
        if not is_inside_tree(): return
        await get_tree().create_timer(0.5).timeout
        if is_dead or not is_inside_tree(): return
        take_damage(5)
```

**What goes wrong**: The `take_damage(5)` call during burning ignores the `from_pos` parameter, so enemies won't get knockback from burn damage. More critically, if the enemy's `_die()` method calls `queue_free()` after a delay, this coroutine continues running in the background with a reference to a freed node.

**Fix**: The guards are mostly adequate but add `if not is_instance_valid(self): return` for safety.

---

### SUGGESTION — Code quality, maintainability, or minor performance improvements

---

#### S01: 42+ print() statements in production code
**Files**: player.gd (22), save_manager.gd (9), arena_builder.gd (2), arena.gd (1), intro_video.gd (1), setup_sprite_frames.gd (7)

**Fix**: Replace with conditional debug prints or remove entirely:
```gdscript
if OS.is_debug_build(): print("debug message")
```

---

#### S02: Massive file sizes need decomposition
- `player.gd` — 1,149 lines (movement, combat, sprites, audio, dig, sneak, collect, death, dev tools)
- `arena.gd` — 1,257 lines (combat, chest UI, loot generation, card perks, regen, secret doors)
- `enemy_base.gd` — 1,139 lines (AI, sprites, burrow, damage, keys, skins, VFX)
- `junkyard_v2.gd` — ~1,200+ lines

**Fix**: Extract into components: `PlayerCombat`, `PlayerSprites`, `ChestPhaseUI`, `EnemyAI`, etc.

---

#### S03: get_node_or_null("/root/...") instead of direct autoload reference
**Pattern across entire codebase**:
```gdscript
var ach = get_node_or_null("/root/Achievements")
var js = get_node_or_null("/root/JunkyardState")
```

**Fix**: Since these are autoloads, they're always available. Use direct references:
```gdscript
Achievements.check_and_unlock("boss_slayer")
```
The `get_node_or_null` pattern is only needed if the autoload might not exist, which isn't the case here.

---

#### S04: Duplicate bark VFX code
**File**: `scripts/player.gd:676-737` and `scripts/player.gd:751-772`

The `_show_bark_wave()` and `_play_bark()` functions contain nearly identical code for creating floating bark text.

**Fix**: Extract shared bark text creation into a helper function.

---

#### S05: Magic numbers throughout
Examples:
- `enemy_base.gd:617` — `dist < 18.0` for contact damage range
- `enemy_base.gd:613` — `dist < 80.0` for attack animation trigger
- `player.gd:559` — `COLLECT_RANGE = 60.0` (good! but others aren't constants)
- `arena.gd:29` — `_zero_enemies_timer > 3.0` (why 3?)

**Fix**: Define constants with descriptive names.

---

#### S06: emit_signal() vs .emit() inconsistency
The codebase mixes old-style `emit_signal("name", args)` with new-style `signal_name.emit(args)`:
- `game_state.gd` uses `emit_signal()` everywhere
- `card_db.gd:83` uses `card_collected.emit(card)`
- `level_up.gd:395` uses `perk_chosen.emit(perk.id)`

**Fix**: Standardize on `.emit()` (the Godot 4 way).

---

#### S07: SpriteLoader autoload is dead code
**File**: `autoloads/sprite_loader.gd`

The `resources/` directory doesn't exist, so `PLAYER_FRAMES_PATH` and all `ENEMY_FRAME_PATHS` point to nonexistent files. Meanwhile, `player.gd._load_sprites()` and `enemy_base.gd._load_sprites()` handle sprite loading independently.

**Fix**: Remove SpriteLoader from autoloads in project.godot, or delete the file entirely.

---

#### S08: CardDB get_stat_bonuses vs get_completion_bonuses naming mismatch
**Files**: `autoloads/card_db.gd:110` defines `get_stat_bonuses()` returning `{max_hp, damage}`
**But**: `autoloads/game_state.gd:363` calls `card_db.get_completion_bonuses()`

```gdscript
# game_state.gd:362-363
if card_db and card_db.has_method("get_completion_bonuses"):
    var bonuses = card_db.get_completion_bonuses()
```

**What goes wrong**: `get_completion_bonuses()` doesn't exist in CardDB. The method is `get_stat_bonuses()`. The `has_method()` check prevents a crash but means card deck bonuses are never applied during `reapply_permanent_bonuses()`.

**Fix**: Change to `card_db.get_stat_bonuses()` or add an alias method.

---

#### S09: CLAUDE.md is outdated
The CLAUDE.md references:
- Viewport 480x270 (actual: 960x540)
- `salvage_window.tscn` (may be outdated with new collect system)
- `throwable.tscn` (throwable system appears removed)
- `quick_craft.tscn` (not found in scenes)
- Phase enum includes ARENA_PREP but prep phase is skipped (`_start_prep_phase` just calls `_start_combat`)

---

---

## Dependency Map

### Autoload Chain
```
GameState ← (no deps)
CraftingDB ← (no deps)
StageData ← (no deps)
OrbitalDB ← (no deps)
WaveManager ← StageData, GameState
SaveManager ← GameState, CraftingDB, Achievements, CardDB
Achievements ← GameState, SaveManager
ArmorDB ← GameState, SaveManager
JunkyardState ← GameState
CardDB ← (no deps)
AudioManager ← WaveManager, GameState, StageData
```

### Key Signal Flows
```
GameState.health_changed → arena._on_health_changed → hud.update_health
GameState.health_changed → player._on_health_changed (no-op)
GameState.materials_changed → arena._update_hud
GameState.phase_changed → (multiple listeners)
GameState.keys_changed → arena._refresh_chest_event_ui

WaveManager.wave_complete → arena._on_wave_complete
WaveManager.all_waves_complete → arena._on_all_waves_complete
WaveManager.enemies_remaining_changed → arena._update_enemies_label

enemy.tree_exiting → WaveManager._on_enemy_died
enemy.died → GameState.gain_xp (via enemy_base._die)

Achievements.achievement_unlocked → (toast display)
CardDB.card_collected → (popup display)
```

### Scene Flow
```
intro_video.tscn → main_menu.tscn → base_hub.tscn → arena.tscn
                                                    ↓ wave complete
                                              chest_phase (overlay)
                                                    ↓ boss wave complete
                                              secret_door (optional)
                                                    ↓
                                              base_hub.tscn
                                                    ↓ next stage
                                              arena.tscn (repeat)
                    main_menu.tscn → junkyard.tscn (alternate mode)
```

---

## Performance Hotspots

### Top 10 Scripts Most Likely to Cause Frame Drops

1. **enemy_base.gd `_compute_separation()`** — O(n^2) every frame. 80 enemies = 6,400 iterations/frame.
2. **enemy_base.gd `_animate_sprite()`** — Large if/elif chain for 30+ enemy types, runs every frame per enemy.
3. **enemy_base.gd `_move_toward_player()`** — NavigationAgent2D pathfinding for distant enemies every frame.
4. **player.gd `_show_bark_wave()`** — Creates 3 Line2D + 1 Label + 1 Polygon2D per attack (every 0.6s).
5. **player.gd `_find_closest_enemy()`** — `filter()` allocates new array every attack timer tick.
6. **arena_builder.gd** — Generates entire arena floor/walls procedurally — one-time cost but heavy.
7. **wave_manager.gd `_spawn_enemy()`** — `load()` per spawn, synchronous disk I/O.
8. **audio_manager.gd `_on_node_added()`** — Runs for every node in tree, does type check.
9. **orbital_weapon.gd** — Each orbital checks for nearby enemies independently (potentially O(n) per orbital per frame).
10. **junkyard_v2.gd** — Massive procedural generation with many node instantiations.

---

## Dead Code Report

### Unused Functions
| File | Function | Reason |
|------|----------|--------|
| player.gd | `_handle_salvage_input()` | Never called — replaced by `_handle_collect_input()` |
| player.gd | `_try_salvage_nearby()` | Only called by unused `_handle_salvage_input()` |
| player.gd | `enable_salvage_mode()` | Empty function, never called |
| player.gd | `_on_health_changed()` | Connected but empty (pass) |
| player.gd | `_show_controls_tutorial()` | Defined but never called (comment says "Controls are now in pause menu") |
| game_state.gd | `_ready()` | Empty function |
| wave_manager.gd | `_ready()` | Empty function |
| crafting_db.gd | `unlock_recipe()` | No-op stub kept for compatibility |
| sprite_loader.gd | Entire file | Resources directory doesn't exist |
| arena.gd | `_start_prep_phase()` | Just calls `_start_combat()` — prep phase was removed |

### Unused Variables
| File | Variable | Reason |
|------|----------|--------|
| arena.gd | `prep_time: float = 8.0` | Prep phase is skipped |
| arena.gd | `prep_timer: float = 0.0` | Prep phase is skipped |
| arena.gd | `_chest_timer: float = 0.0` | Never written to or read |
| arena.gd | `CHEST_PHASE_TIMEOUT = 25.0` | Never used |
| arena.gd | `_combine_ui` | Assigned null, never used |
| game_state.gd | Phase.ARENA_PREP | Phase exists but is never set |

---

## Summary Statistics

### Issues by Severity
| Severity | Count |
|----------|-------|
| CRITICAL | 14 |
| WARNING | 22 |
| SUGGESTION | 9 |
| **Total** | **45** |

### Issues by Category
| Category | Count |
|----------|-------|
| Crash risk (null/freed/await) | 14 |
| Logic bug (wrong behavior) | 8 |
| Performance | 5 |
| Dead code | 4 |
| Dev tools in production | 1 |
| Signal/connection issues | 4 |
| Code quality | 6 |
| Documentation mismatch | 2 |
| UI bugs | 1 |

### Files with Most Issues (Top 15)
| File | Issue Count | Severities |
|------|-------------|------------|
| scripts/player.gd | 7 | 1 critical, 3 warning, 3 suggestion |
| scripts/arena.gd | 6 | 2 critical, 2 warning, 2 suggestion |
| scripts/enemy_base.gd | 5 | 2 critical, 2 warning, 1 suggestion |
| scripts/level_up.gd | 3 | 3 warning |
| autoloads/wave_manager.gd | 3 | 1 critical, 2 warning |
| autoloads/game_state.gd | 2 | 1 critical, 1 suggestion |
| scripts/chest.gd | 2 | 2 warning |
| scripts/base_hub.gd | 1 | 1 critical |
| scripts/hud.gd | 1 | 1 warning |
| scripts/destructible_prop.gd | 1 | 1 warning |
| Enemy special ability scripts (5 files) | 5 | 5 critical (unguarded awaits) |
| Ranged enemy scripts (10 files) | 10 | 10 warning (uncached load) |
| enemy_spore_walker/magma_imp | 2 | 2 critical (dangling signals) |
| enemy_steam_turret.gd | 2 | 1 critical, 1 warning |
| enemy_ember_drake.gd | 1 | 1 critical (tween before tree) |

---

*Report generated by comprehensive automated audit. All line numbers reference the codebase at time of audit.*
