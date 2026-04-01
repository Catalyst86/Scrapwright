# SCRAPWRIGHT ADVERSARIAL AUDIT

**Auditor posture**: Hostile QA tester. Previous 3 audits rated A+. This audit assumes they missed things.
**Date**: 2026-03-31
**Codebase**: 81 .gd files, 52 .tscn files, ~13,000 lines of GDScript

---

## VERDICT

**The A+ does NOT hold up.** The previous audits missed several real bugs, including one that is trivially reproducible in normal gameplay (orbital weapon orbit acceleration), a perk stat desync that silently weakens the player after every hub visit, and an enemies_alive counter that can go negative. The codebase is impressively well-guarded against nulls and freed objects, but has blind spots around **shared state mutation**, **multiplicative vs additive math disagreements**, and **pause state race conditions**.

---

## NEW ISSUES FOUND

### RED (Will cause visible bugs or crashes under normal play)

#### R1. Orbital Weapon Orbit Speed Accelerates With Each New Weapon
- **File**: `scripts/orbital_weapon.gd:74`
- **Snippet**: `_shared_orbit_time += delta`
- **Explanation**: `_shared_orbit_time` is a `static var` (shared across all instances). Every `OrbitalWeapon` instance increments it in `_physics_process`. With 1 weapon, orbit is normal. With 3 weapons, `_shared_orbit_time` advances at 3x speed. With 6 weapons (max), orbits spin 6x faster than intended.
- **Impact**: Weapons become a blurry mess at high counts. Also affects `_bob_time` indirectly via visual perception.
- **Fix**: Only increment on the first instance, OR increment in a central location:
```gdscript
# In _physics_process, replace line 74 with:
if slot_index == 0:
    _shared_orbit_time += delta
```

#### R2. Perk Stat Desync: Multiplicative at Level-Up vs Additive at Reapply
- **File**: `scripts/level_up.gd:411,443` vs `autoloads/game_state.gd:347,355`
- **Snippet**:
  - Level-up: `GameState.perk_speed_multiplier *= 1.15` (line 411)
  - Reapply: `perk_speed_multiplier += 0.15` (line 347)
  - Level-up: `GameState.perk_xp_multiplier *= 1.25` (line 443)
  - Reapply: `perk_xp_multiplier += 0.25` (line 355)
- **Explanation**: When you pick "speed_up" twice during combat, the multiplier becomes `1.0 * 1.15 * 1.15 = 1.3225`. When you return to base hub and come back (triggering `reapply_permanent_bonuses`), it recalculates as `1.0 + 0.15 + 0.15 = 1.30`. Player silently loses ~1.7% speed. Same for XP: `1.5625x` becomes `1.5x`. The more perks stacked, the bigger the gap.
- **Impact**: Player gradually weakens after each hub visit. Not immediately obvious but compounds over a run.
- **Fix**: Use consistent math. Either both multiplicative or both additive. Recommend changing `reapply_permanent_bonuses` to match the level-up behavior:
```gdscript
# game_state.gd:347
"speed_up":
    perk_speed_multiplier *= 1.15
# game_state.gd:355
"xp_up":
    perk_xp_multiplier *= 1.25
```

#### R3. Minion enemies_alive Decrement Without Floor Guard
- **Files**: `scripts/enemy_fungal_brute.gd:31`, `enemy_frost_warden.gd:81`, `enemy_junkyard_mech.gd:110`, `enemy_piston_crusher.gd:139`, `enemy_spore_mother.gd:128`, `enemy_the_devourer.gd:123`, `enemy_scrap_king.gd:154`, `enemy_the_architect.gd:124,142`
- **Snippet**: `WaveManager.enemies_alive -= 1` (9 locations)
- **Explanation**: During scene teardown (e.g., player dies, transition to base hub), both the boss AND its minions can fire `tree_exiting`. The boss's `_die()` decrements via WaveManager's `_on_enemy_died` (which has `maxi(0, ...)` guard), but the minion lambdas do raw `enemies_alive -= 1`. If tree_exiting fires during teardown when `wave_active` is false, the `if not WaveManager.wave_active: return` guard catches it. But if wave IS still active during rapid kills, double-decrements can push `enemies_alive` to -1 or lower. This causes `enemies_remaining_changed` to emit negative counts.
- **Impact**: HUD could briefly show "-1 enemies" or similar. `_check_wave_complete` still fires (checks `<= 0`) so it won't softlock, but it's a display bug and a sign of accounting fragility.
- **Fix**: Add `maxi(0, ...)` guard to all 9 locations:
```gdscript
WaveManager.enemies_alive = maxi(0, WaveManager.enemies_alive - 1)
```

#### R4. Chest queue_free While Key Choice Is Open Permanently Pauses Game
- **File**: `scripts/chest.gd:182,283`
- **Explanation**: `_show_key_choice()` calls `get_tree().paused = true` at line 182. `_close_key_choice()` calls `get_tree().paused = false` at line 283. But if the chest node is `queue_free()`d while the key choice UI is open (e.g., scene change triggered by secret door, or player death during chest interaction), the unpause never executes. The game is permanently frozen.
- **Impact**: Hard softlock. Player must force-quit. This can happen if a secret door scene change fires while a chest overlay is active.
- **Fix**: Override `_exit_tree()` on the chest to ensure unpause:
```gdscript
func _exit_tree() -> void:
    if get_tree().paused:
        get_tree().paused = false
```

#### R5. Regen Timer Reference Check Uses Truthiness Instead of is_instance_valid
- **File**: `scripts/level_up.gd:426`
- **Snippet**: `if not regen_timer:`
- **Explanation**: `regen_timer` is assigned when the regen perk is picked. The timer is parented to the arena scene. When the arena is freed (scene change to base hub), the timer is freed with it — but `regen_timer` still holds a reference to the freed object. In GDScript 4, a freed object reference is still truthy (`if not regen_timer` = false). So the next time regen is checked, the guard fails, no new timer is created, and regen stops working for the rest of the run.
- **Impact**: Regen perk silently breaks after the first hub visit. Player heals during combat, returns to hub, goes back to arena — no more healing.
- **Fix**: Change to `if not is_instance_valid(regen_timer):` on line 426.

---

### YELLOW (Edge cases that can cause bugs under specific conditions)

#### Y1. Pause State Race Condition: Level-Up + Chest Phase
- **Files**: `scripts/level_up.gd:159,388`, `scripts/arena.gd:264,288`
- **Explanation**: `_check_level_up()` runs every frame during COMBAT phase. If the player gains enough XP to level up on the same frame that a wave completes, the level-up screen pauses the game (`get_tree().paused = true`), and then `_on_wave_complete` also tries to pause for chest phase. When the player picks a perk, level_up unpauses (`get_tree().paused = false`), but the chest phase expects the game to still be paused. The chest UI is set to `PROCESS_MODE_ALWAYS` so it remains interactive, but the actual game resumes underneath — enemies from the next wave could theoretically spawn while the chest overlay is shown.
- **Scenario**: Kill last enemy of a wave with an XP gain that triggers level-up. Level-up screen appears. Pick perk. Game unpauses. Chest phase begins but expects paused state.
- **Impact**: Momentary state confusion. The chest phase immediately re-pauses in `_start_chest_phase`, so the window is small. But during the frames between level_up unpausing and chest_phase re-pausing, input could be processed unexpectedly.
- **Fix**: Use a pause counter or ensure level_up doesn't unpause if another system has paused.

#### Y2. await in _die() Chains: Enemy Freed Mid-Await During Scene Change
- **File**: `scripts/enemy_base.gd:785-795`
- **Snippet**:
```gdscript
await get_tree().create_timer(die_duration).timeout
if not is_inside_tree(): return
await get_tree().create_timer(0.4).timeout
if not is_inside_tree(): return
# ...
await tw.finished
if not is_inside_tree(): return
queue_free()
```
- **Explanation**: The `is_inside_tree()` guards are excellent and prevent crashes. However, the timer-based signals still fire even after the node is removed from the tree (timers are parented to the SceneTree). If the scene changes during the die animation (player dies simultaneously, or wave completes), the `is_inside_tree()` check correctly prevents `queue_free()`, but the enemy remains as an orphaned reference in WaveManager's `enemies_alive` count. WaveManager's `_on_enemy_died` already handles this via `tree_exiting`, so the count is correct. But the dangling coroutine consumes memory until the timer expires.
- **Impact**: Minor memory pressure during rapid scene changes with many dying enemies. Not a crash, but not clean.

#### Y3. _play_attack_anim Uses await in _physics_process Context
- **File**: `scripts/enemy_base.gd:635-655`
- **Explanation**: `_play_attack_anim()` is called from `_check_contact_damage()` which is called from `_physics_process()`. The function uses `await get_tree().create_timer(dur).timeout`. While the `_attack_anim_playing` guard prevents re-entry, the coroutine context means the enemy is in a half-suspended state during the await. If the enemy is killed or freed during this await, the `is_instance_valid(self)` check at line 651 handles it. But if `dur` is 0 (from a division issue where `anim_speed` returns 0 or frames is 0), the timer fires immediately in the same frame, which is handled but wasteful.
- **Impact**: Mostly safe due to guards, but `await` in physics context is a Godot anti-pattern that can cause subtle timing issues.

#### Y4. Large Delta Spike Causes Excessive Knockback and Stuck-Detection False Positives
- **File**: `scripts/enemy_base.gd:358`
- **Snippet**: `knockback = knockback.move_toward(Vector2.ZERO, 420.0 * delta)`
- **Explanation**: If `delta` is ~1.0 (window drag, alt-tab, lag spike), knockback decays by 420 pixels in one frame, which is fine (overshoots to zero). But the stuck detection at line 338 checks `global_position.distance_to(_stuck_last_pos) < STUCK_MOVE_MIN` with `STUCK_THRESHOLD = 3.0`. A 1-second freeze means `_stuck_timer` jumps by 1.0 in one frame, so 3 consecutive freezes would false-positive into stuck detection and trigger `_force_unstuck()`.
- **Impact**: Unlikely but possible: enemies randomly burrow/teleport after alt-tab if the game was paused and resumed.

#### Y5. DirAccess.dir_exists_absolute Checks Globalized Paths — Fails on Export
- **File**: `scripts/player.gd:203`
- **Snippet**: `if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(PUPPY_BASE + _current_tier)):`
- **Explanation**: `ProjectSettings.globalize_path()` on a `res://` path works in the editor but returns a path inside the PCK archive on exported builds. `DirAccess.dir_exists_absolute()` cannot browse inside .pck files. This means the tier fallback logic will ALWAYS trigger on exported builds, falling back to "bandana" or "base" regardless of the actual equipped armor visual.
- **Impact**: On export, the player sprite tier selection always falls back. The sprite still loads (because `ResourceLoader.exists()` works with .pck), but the tier-based scale and folder selection may be wrong.
- **Fix**: Use `ResourceLoader.exists()` on a known file in the folder instead of `DirAccess.dir_exists_absolute()`.

#### Y6. Signal Connection Leak: keys_changed in Chest Phase
- **File**: `scripts/arena.gd:461,285`
- **Explanation**: `_build_chest_event_ui` connects `GameState.keys_changed.connect(_refresh_chest_event_ui)` at line 461. `_end_chest_phase` disconnects it at line 285-286. But `_on_wave_complete` calls `_start_chest_phase` twice for boss waves (lines 233-237). The first `_end_chest_phase` disconnects, then the second `_start_chest_phase` reconnects. This is correct for the normal flow. However, if `_end_chest_phase` is called when `arena_phase != ArenaPhase.CHEST_PHASE` (line 274 guard), the disconnect at line 285 still runs. If `keys_changed` was never connected (because `_build_chest_event_ui` wasn't called), the `is_connected` check at line 285 correctly prevents a crash. This is actually handled well, but the pattern is fragile.
- **Impact**: No crash, but if the flow ever changes, this signal management could leak.

#### Y7. Player._on_health_changed Is a No-Op
- **File**: `scripts/player.gd:907`
- **Snippet**: `func _on_health_changed(_c: int, _m: int) -> void: pass`
- **Explanation**: The player connects `GameState.health_changed` to `_on_health_changed` at line 92, but the handler is a no-op `pass`. The actual death handling happens in `take_damage()` → `_die()`. The signal fires from `GameState.take_damage()` which is called by `player.take_damage()`. This means the health_changed signal from GameState is connected to the player but does nothing. Not a bug per se, but it means the player won't react if health changes from a non-player source (e.g., GameState.take_damage called directly from a trap or status effect without going through player.take_damage).
- **Impact**: If any system calls `GameState.take_damage()` directly (instead of `player.take_damage()`), the player won't die, flash, or interrupt actions.

---

#### Y8. StageData.get_stage_wave() Returns 0 When wave_num Is 0 (Negative Modulo)
- **File**: `autoloads/stage_data.gd:336`
- **Snippet**: `return ((wave_num - 1) % WAVES_PER_STAGE) + 1`
- **Explanation**: If `wave_num = 0` is passed (which happens — `GameState.current_wave` starts at 0), then `(0 - 1) % 14 = -1` in GDScript 4 (C-style negative modulo). This returns `stage_wave = 0`. Downstream, `get_wave_def()` at line 355 does `wave_data[stage_wave - 1]` = `wave_data[-1]`, which in GDScript returns the LAST element of the array — silently serving wave 14's data as wave 0.
- **Impact**: The very first wave after `start_new_run()` could load the wrong wave definition if any code path calls `get_wave_def(0)`. In practice, `WaveManager.start_wave()` is called with `GameState.current_wave + 1`, so `wave_num >= 1` in normal flow. But it's a latent bug waiting to trigger.

#### Y9. WaveManager.spawn_interval Not Reset by start_wave()
- **File**: `autoloads/wave_manager.gd:108-127`
- **Explanation**: `start_wave()` doesn't reset `spawn_interval` (default 0.8). But `start_custom_wave()` at line 209 sets `spawn_interval = interval`. If junkyard mode calls `start_custom_wave()` with a different interval (e.g., 0.3), then the player returns to normal arena and `start_wave()` is called, it inherits the junkyard interval of 0.3 — spawning enemies twice as fast.
- **Impact**: Enemies spawn at wrong speed after playing junkyard mode then returning to normal arena. Only triggers if `start_custom_wave` was called before `start_wave` in the same session.
- **Fix**: Add `spawn_interval = 0.8` to `start_wave()`.

#### Y10. SaveManager Deletes Save on Version Mismatch Instead of Migrating
- **File**: `autoloads/save_manager.gd:122-125`
- **Snippet**:
```gdscript
var ver = save_cfg.get_value("meta", "version", 0)
if ver < SAVE_VERSION:
    DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
```
- **Explanation**: If `SAVE_VERSION` is bumped (currently 3), any existing save file with version < 3 is permanently deleted. No migration, no backup, no warning. A game update wipes all player progress.
- **Impact**: Data loss for players on game update. Acceptable during early dev, but a landmine for any public release.

#### Y11. Poison Orb Applies "burning" Instead of Poison Status (Copy-Paste Bug)
- **File**: `scripts/orbitals/orbital_poison_orb.gd:13`
- **Snippet**: `target.apply_status("burning", 3.0)`
- **Explanation**: The poison orb weapon shows a poison cloud visual but applies a "burning" status effect. This is a copy-paste bug from a fire-based weapon. Should be `"poisoned"` or `"slowed"`.
- **Impact**: Wrong gameplay effect. Player expects poison, gets fire.

#### Y12. Thorn Vine Division by Zero When Player on Target
- **File**: `scripts/orbitals/orbital_thorn_vine.gd:30`
- **Snippet**: `var t = clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)`
- **Explanation**: `_closest_point_on_segment(a, b, p)` divides by `ab.length_squared()`. If `a == b` (player position equals the line endpoint — possible if target is at distance 0), this divides by zero producing NaN/INF.
- **Impact**: Corrupted position calculations, potential visual artifacts.
- **Fix**: Guard with `if ab.length_squared() < 0.001: return a`

#### Y13. Arcane Book / Flame Wisp Arena Validity in Timer Callbacks
- **Files**: `scripts/orbitals/orbital_arcane_book.gd:53`, `scripts/orbitals/orbital_flame_wisp.gd:52`
- **Explanation**: Trail particle timers call `arena.add_child(trail)` inside timer callbacks without checking `is_instance_valid(arena)`. If the arena is freed during a missile's flight (scene change), this crashes.
- **Impact**: Potential crash during scene transitions if orbital missiles are in flight.

#### Y14. Intro Video Loads All 552 Frames Into Memory (~1GB+)
- **File**: `scripts/intro_video.gd:31-35`
- **Explanation**: The intro video system loads all 552 PNG frames into an array at once. At 960x540 RGBA, each frame is ~2MB uncompressed in VRAM. Total: ~1.1GB. Low-end systems will OOM or stutter severely.
- **Impact**: Memory exhaustion on systems with <2GB VRAM. Game may crash before the intro finishes.
- **Fix**: Stream frames on-demand instead of preloading all of them.

#### Y15. HUD Ability Labels Never Assigned — Display Permanently Broken
- **File**: `scripts/hud.gd:47-49`
- **Explanation**: `dodge_label`, `sneak_label`, `dig_label`, and `collect_label` are declared as vars but never assigned in `_build_hud()`. The update methods (`update_dodge_cooldown`, `update_sneak_state`, `update_dig_charges`) all check `if not dodge_label: return` and bail — so the ability indicators simply never display.
- **Impact**: Players never see dodge cooldown, sneak status, or dig charge counts on the HUD. Purely a missing feature, but the code suggests it was intended to work.

#### Y16. Gold Chest Permanent Upgrade Can Crash on Missing Key
- **File**: `scripts/arena.gd:764`
- **Snippet**: `GameState.permanent[upgrade] += 1`
- **Explanation**: `upgrade` is randomly selected from `PERMANENT_UPGRADES` array. If the selected key doesn't exist in `GameState.permanent` dictionary, this crashes. Currently all 5 keys in `PERMANENT_UPGRADES` are in `GameState.permanent`, so it's safe. But adding a new upgrade to the array without adding it to the dictionary would crash.
- **Impact**: Latent crash — safe today, fragile tomorrow.

---

### BLUE (Minor / Cosmetic / Code Quality)

#### B1. Print Statements Left in Production Code
- **Files**: `scripts/arena_builder.gd` (2 prints), `scripts/setup_sprite_frames.gd` (4 prints)
- **Impact**: Console noise. Minor performance cost on debug builds.

#### B2. Hardcoded Attack Timer Name Access
- **File**: `scripts/level_up.gd:421`
- **Snippet**: `var t = player.get_node("AttackTimer") as Timer`
- **Explanation**: Uses `get_node()` without null check. If the player node structure changes, this crashes. Should use `get_node_or_null()`.

#### B3. Static Variable Not Reset Between Runs
- **File**: `scripts/orbital_weapon.gd:21`
- **Snippet**: `static var _shared_orbit_time: float = 0.0`
- **Explanation**: Static vars persist across scene changes. Starting a new run doesn't reset `_shared_orbit_time`, so orbitals in a new run start at whatever angle the last run ended at. Not a gameplay bug, but not intentional either.

#### B4. Junkyard State Accessed via get_node("/root/JunkyardState")
- **File**: `scripts/junkyard_v2.gd:99`
- **Snippet**: `_jy = get_node("/root/JunkyardState")`
- **Explanation**: Hard path without null check. If JunkyardState isn't registered as an autoload, this crashes. Other places in the codebase use `get_node_or_null()` for this.

#### B5. Unused Variable in Shadow Dagger
- **File**: `scripts/orbitals/orbital_shadow_dagger.gd:10`
- **Snippet**: `var dark = Color(0.5, 0.2, 0.6)`
- **Explanation**: Variable declared but never used. The same color is hardcoded again at line 23.

#### B6. Heavy Per-Fire Node Allocation in Arcane Book / Flame Wisp
- **Files**: `scripts/orbitals/orbital_arcane_book.gd`, `scripts/orbitals/orbital_flame_wisp.gd`
- **Explanation**: Each fire creates ~19 nodes (missile + polygons + timer + trail particles + impact sparks). At high attack speed with multiple weapons, this creates significant GC pressure.

#### B7. Dead Signals in GameState Never Emitted
- **File**: `autoloads/game_state.gd:10,13`
- **Explanation**: `wave_changed` and `card_collected` signals are declared but never emitted anywhere in the codebase. Dead code.

#### B8. Achievement Description Says "42 waves" but Game Has 84
- **File**: `autoloads/achievements.gd:20`
- **Explanation**: "the_end" achievement description says "Complete all 42 waves" but `GameState.total_waves = 84`. Stale from when the game had fewer stages.

#### B9. AudioManager Hooks Into Every Node Added to Tree
- **File**: `autoloads/audio_manager.gd:57`
- **Snippet**: `get_tree().node_added.connect(_on_node_added)`
- **Explanation**: Fires for EVERY node creation in the entire game. The callback filters for `BaseButton`, but the signal overhead exists for all nodes — hundreds of enemies, particles, UI elements. Minor performance cost.

#### B10. Scene-Level Tweens on Freed Nodes in Pickups
- **Files**: `scripts/material_pickup.gd:98`, `scripts/key_pickup.gd:108`
- **Explanation**: Both use `get_tree().create_tween()` (scene-level) instead of `node.create_tween()` (node-level) for popup animations. If the parent scene changes while the tween is running, the tween tries to animate an orphaned node.

#### B11. Pause Menu Directly Modifies WaveManager.wave_active
- **File**: `scripts/pause_menu.gd:569`
- **Explanation**: The "Return to Den" option sets `WaveManager.wave_active = false` directly, bypassing `force_complete_wave()`. This could leave spawn_queue non-empty and enemies_alive in an inconsistent state.

#### B12. Bark Text Arrays Duplicated in Two Functions
- **File**: `scripts/player.gd:622,676`
- **Explanation**: `bark_words` and `bark_colors` arrays are identical in `_show_bark_wave()` and `_play_bark()`. Should be constants.

#### B13. Game Over Hardcodes 960px Viewport Width
- **File**: `scripts/game_over.gd:285`
- **Snippet**: `randf_range(0, 960)`
- **Explanation**: Ember particle spawning assumes 960px viewport width. The actual viewport is 480x270 with 2x camera zoom. Embers spawn off-screen.

#### B14. Inconsistent Player Slow API Across Enemy Scripts
- **Files**: `scripts/enemy_frost_sprite.gd` uses `apply_slow(0.3, 2.0)`, `scripts/enemy_glacial_hulk.gd` uses `apply_slow(0.3, 1.5)`, `scripts/enemy_spore_walker.gd` uses `apply_status("slowed", 2.0)`
- **Explanation**: Two different method signatures for the same effect. If the player only implements one, the other silently does nothing (guarded by `has_method`). The slow effect may not work for some enemies.

#### B15. Multiple Magic Numbers in Enemy Animation Speed
- **File**: `scripts/enemy_base.gd:462-599`
- **Explanation**: ~40 hardcoded animation speed/bob/squash values in a massive if/elif chain. Not a bug, but extremely fragile for maintenance. Any new enemy type that forgets to add its entry uses the default values, which may not match visually.

---

## SCENARIO TEST RESULTS

### Rapid State Changes

| Scenario | Result | Evidence |
|----------|--------|----------|
| Spam interact 30 times in 1 frame | **PASS** | `_is_collecting` and `_is_digging` booleans gate input; `_collect_pressed_this_frame` is reset each physics frame |
| Scene transition during another transition | **PASS** | `arena_phase = ArenaPhase.TRANSITION` guard at line 993-994 prevents double-transitions. `is_inside_tree()` checks everywhere |
| Pause/unpause toggled every frame | **MARGINAL** | See Y1 above. The pause_menu checks `is_open` state, level_up checks `visible`. But simultaneous pause sources can desync |
| Open menu during animation | **PASS** | Pause menu sets `process_mode = PROCESS_MODE_ALWAYS` and works independently |

### Timing Edge Cases

| Scenario | Result | Evidence |
|----------|--------|----------|
| First frame after scene load | **PASS** | `@onready` vars are set before `_ready`, `_physics_process` won't run until first frame after `_ready` |
| Signal fires during _ready() | **PASS** | Signals connected in `_ready()` fire on next frame, not during connection |
| await never resolves | **PASS** | All awaits use `get_tree().create_timer()` which always fires, or have `is_inside_tree()` escape hatches |
| Delta = 1+ seconds (lag spike) | **MARGINAL** | See Y4. Most code uses delta correctly but stuck detection could false-positive |

### Destruction Edge Cases

| Scenario | Result | Evidence |
|----------|--------|----------|
| queue_free during signal emission | **PASS** | Godot defers queue_free to end of frame; signals complete first |
| Parent freed with pending child callback | **PASS** | `is_inside_tree()` and `is_instance_valid()` guards everywhere |
| Player dies during transition | **PASS** | `arena_phase == ArenaPhase.TRANSITION` guard at line 993 prevents double-death |
| Target freed before code runs | **PASS** | `is_instance_valid()` checks on player_ref, current_target, enemies throughout |
| Double queue_free on same node | **PASS** | `is_dead` guards prevent double `_die()` calls everywhere |

### Data Integrity

| Scenario | Result | Evidence |
|----------|--------|----------|
| Corrupted/missing save keys | **PASS** | `config.get_value()` with defaults throughout `save_manager.gd`. Missing keys gracefully default |
| Dictionary accessed with missing key | **PASS** | `.get()` with defaults used consistently for dictionaries |
| Empty array when code assumes elements | **PASS** | `is_empty()` checks before array access throughout |
| Missing resource file | **PASS** | `ResourceLoader.exists()` checks before every `load()` |

### Platform Edge Cases

| Scenario | Result | Evidence |
|----------|--------|----------|
| Case-sensitive path on Linux | **PASS** | All resource paths use lowercase with underscores. Sprite paths use consistent conventions |
| Extreme aspect ratios | **PASS** | Camera2D with limits prevents seeing outside arena. Viewport is fixed 480x270 |
| 15 FPS vs 300 FPS | **MOSTLY PASS** | All movement uses delta. One exception: rotation in timer callbacks (B-level, see rotation += 0.06 in junkyard_v2.gd:1432 — timer-based so framerate-independent) |

### Input Edge Cases

| Scenario | Result | Evidence |
|----------|--------|----------|
| No input device | **PASS** | Input actions use keyboard; no gamepad-required paths |
| Undefined input actions | **PASS** | "dodge", "bark", "salvage" all defined in project.godot. Ctrl detected via raw keycode |
| Key held across scene change | **PASS** | `_dodge_pressed_this_frame` and `_collect_pressed_this_frame` reset every frame |

---

## POTENTIAL SOFTLOCKS

1. **Level-Up With No Valid Perks**: `_build_choice_pool()` has fallback padding (lines 354-363) that ensures at least 3 choices. If ALL_PERKS is somehow empty AND weapon_pool is empty, you'd get 0 choices and a blank level-up screen with no way to dismiss. **Probability**: Effectively zero — ALL_PERKS is hardcoded with 6 entries.

2. **Chest Phase With No Keys and No Skip Button**: The "Skip" button appears when `not can_open_more and not still_animating` (line 718). If you have no keys, the Skip button should appear after the animation delay. Confirmed it does appear. **Not a softlock**.

3. **_wait_for_chest_phase Infinite Loop**: The while loop at line 269 waits for `arena_phase != CHEST_PHASE`. If `_end_chest_phase` is never called, this loops forever. `_end_chest_phase` is connected to the Collect/Skip button. If the button fails to render (UI error), this would softlock. **Probability**: Very low — UI construction is straightforward.

4. **Pause Menu During Level-Up**: The `_unhandled_input` at line 91 checks `level_up_screen.visible` and returns if true. This prevents opening the pause menu during level-up. But if somehow the level-up screen becomes invisible while still paused, the pause menu could open and the quit-to-hub could trigger, leaving the game permanently paused. **Probability**: Extremely low.

5. **Chest queue_free While Paused (R4)**: If a chest node is freed while its key choice UI is open (via scene change, secret door, etc.), `get_tree().paused` is never set back to false. **This IS a realistic softlock.** See R4 above.

**Verdict**: One realistic softlock path found (R4 — chest freed while paused). All other flows are well-guarded.

---

## FRAGILE CODE MAP

Files and functions most likely to break when adding new features:

| File | Function | Fragility | Reason |
|------|----------|-----------|--------|
| `enemy_base.gd` | `_animate_sprite()` | **HIGH** | 130-line if/elif chain for every enemy type. Adding a new enemy without an entry here = wrong animation params |
| `game_state.gd` | `reapply_permanent_bonuses()` | **HIGH** | Must stay in sync with `level_up.gd:_apply()` — adding a new perk requires updating both |
| `orbital_weapon.gd` | `_physics_process()` | **HIGH** | Static var increment bug (R1) means any change to orbital count logic cascades |
| `arena.gd` | `_on_wave_complete()` | **MEDIUM** | Complex await chain with many `is_inside_tree()` guards. Adding new post-wave features requires careful interleaving |
| `wave_manager.gd` | `_on_enemy_died()` | **MEDIUM** | Minion spawners bypass this function and do their own `enemies_alive` accounting in 9 different files |
| `save_manager.gd` | `save_game()/load_game()` | **MEDIUM** | Adding any new persistent state requires changes in both save and load, plus `_reset_game_state()` |
| `level_up.gd` | `_apply()` | **MEDIUM** | Duplicates logic from `game_state.gd:reapply_permanent_bonuses` — see R2 |
| `base_hub.gd` | (entire file) | **MEDIUM** | 1800+ lines of imperative UI construction. Any layout change requires reading the whole file |

---

## GREP SWEEP RESULTS

| Pattern | Hits | Assessment |
|---------|------|------------|
| `get_node(` without null check | 2 | `level_up.gd:421` (B2) and `junkyard_v2.gd:99` (B4) — both risky |
| `queue_free` total | 110 | Heavily used but consistently guarded. No crash-worthy patterns found |
| `is_instance_valid` | 80+ | Excellent coverage. Nearly every freed-object access is guarded |
| `await` in gameplay code | 40 | All have `is_inside_tree()` escape hatches. Pattern is correct |
| `print(` left in code | 6 | Only in `arena_builder.gd` and `setup_sprite_frames.gd`. Acceptable for dev |
| `.connect(` without `is_connected` | 95 | Most are in `_ready()` so only fire once. `keys_changed` connection/disconnection in arena.gd is the riskiest (Y6) |
| Division operations | 100+ | All use `float()` casts or constant denominators. No zero-division risks found |
| Position changes without delta | 1 | `orbital_magnet_core.gd:19` — `enemy.global_position += dir * 25.0` — but this is timer-triggered, not per-frame. Acceptable |
| `enemies_alive -= 1` without guard | 9 | All in boss minion spawners (R3) |
| Framerate-dependent code | 2 | `rotation += 0.06` in timer callbacks (acceptable) |
| Input actions used | "dodge", "bark", "salvage", "ui_cancel", "ui_right/left/up/down" | All defined in project.godot |

---

## FINAL CONFIDENCE RATING

| Category | Score | Justification |
|----------|-------|---------------|
| **Stability** | 6/10 | Orbital orbit bug (R1) is visible in normal play. Perk desync (R2) silently degrades gameplay. Regen timer breaks after hub visit (R5). Chest can permanently freeze game (R4). |
| **Crash Resistance** | 9/10 | Exceptional `is_instance_valid` and `is_inside_tree` coverage. Null guards everywhere. The only crash risk is `get_node()` at `level_up.gd:421` and `junkyard_v2.gd:99`. |
| **Edge Case Coverage** | 8/10 | Scene transition guards, pause handling, and death state all well-covered. Delta handling is correct throughout. Stuck detection false-positive under lag is the only gap. |
| **Code Maintainability** | 5/10 | The 130-line if/elif chain in `_animate_sprite`, the perk logic duplication between two files, the 1800-line `base_hub.gd`, and 9 scattered minion accounting locations all make changes risky. Adding a new enemy, perk, or orbital requires touching many files with no compile-time safety net. |
| **Release Readiness** | 5/10 | R1 (orbit acceleration), R4 (chest freeze softlock), and R5 (regen breaks after hub) are showstoppers. R2 (perk desync) is subtle but real. Y5 (export path check) would break sprite tier selection on exported builds. Y14 (1GB intro video) would crash low-end systems. Fix all reds before shipping. |

---

## SUMMARY

The previous A+ audits were generous. The codebase IS impressively well-defended against nulls, crashes, and freed-object access — that part deserves high marks. But the audits missed:

- **1 visible gameplay bug** (orbital orbit acceleration) that any player with 2+ orbitals would notice
- **1 hard softlock** (chest freed while paused permanently freezes the game)
- **1 silent feature break** (regen timer never recreated after hub visit due to freed-object truthiness)
- **1 silent stat degradation** (perk math desync) that compounds over a run
- **1 export-breaking issue** (DirAccess on .pck paths) that would show up on any shipped build
- **1 memory bomb** (intro video loads 552 frames / ~1GB into memory at once)
- **9 unguarded counter decrements** that could show negative enemy counts
- **1 pause state race condition** with a narrow but real window
- **4 permanently broken HUD elements** (ability indicators declared but never wired up)

These are exactly the kinds of bugs that "pass code review but break at runtime" — which is why adversarial testing matters.

**Final tally: 5 red, 16 yellow, 15 blue issues found (36 total).**
