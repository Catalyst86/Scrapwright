# Scrapwright -- Comprehensive Audit Report

**Date:** 2026-03-31
**Auditor:** Claude Code (Opus 4.6)
**Project:** Scrapwright (Godot 4.6, GDScript)
**Files Reviewed:** 60+ .gd scripts, 45+ .tscn scenes, 3000+ assets

---

## 1. Executive Summary

### Overall Grade: C+

Scrapwright is an ambitious survivors/bullet-heaven roguelite that has evolved significantly beyond its original spec. The core loop works, the enemy variety is impressive (35 types across 6 biomes), and the orbital weapon system is well-designed. However, the codebase has accumulated serious architectural debt, critical gameplay bugs, and significant documentation rot.

### Top 5 Critical Issues

1. **Ember Drake/Piston Crusher charge deals damage every frame** -- up to 960 damage in 0.8 seconds with no cooldown (enemy_ember_drake.gd:53, enemy_piston_crusher.gd:48)
2. **Double death authority** -- both player.gd and arena.gd independently detect and handle player death, executing different cleanup in different orders (arena.gd:1003, player.gd:809)
3. **Wave manager tree_exiting fires on scene teardown** -- enemy death tracking via `tree_exiting` can fire spuriously during scene transitions (wave_manager.gd:166)
4. **Attack animation permanently locks** -- `_attack_anim_playing` can get stuck true if enemy dies mid-await, blocking all future attacks (enemy_base.gd:650)
5. **Orbital weapons freeze if slot 0 is removed** -- static `_shared_orbit_time` only increments from slot_index==0 (orbital_weapon.gd:75)

### Top 5 Strengths

1. **Excellent enemy variety** -- 35 enemy types with distinct behaviors across 6 themed biomes
2. **Clean autoload architecture** -- well-separated concerns (GameState, WaveManager, StageData, etc.)
3. **Robust save system** -- profile-based saves with legacy migration and snapshot/restore for runs
4. **Good collision layer design** -- distinct layers for player, enemies, projectiles, and pickups
5. **Runtime sprite loading** -- graceful fallback to placeholders when assets are missing

### Estimated Effort to Production-Ready

- Critical bug fixes: 2-3 days
- Major issue cleanup: 1-2 weeks
- CLAUDE.md documentation sync: 1 day
- Asset optimization (wav->ogg, dedup): 1 day
- Architecture refactors (death authority, perk dedup): 1 week

---

## 2. Project Overview

### Architecture

```
                     project.godot
                          |
                    [12 Autoloads]
         _________________|_________________
        |        |        |        |        |
   GameState  WaveManager StageData AudioMgr  ... (8 more)
        |        |        |        |
        v        v        v        v
   [Scene Tree: intro_video -> main_menu -> base_hub <-> arena/junkyard]
        |                                    |
   [Player + Orbitals]              [35 Enemy Types]
        |                                    |
   [Chests + Keys + Cards]          [Destructibles + Pickups]
```

### Autoloads (12 registered)

| # | Name | Path | Purpose |
|---|------|------|---------|
| 1 | GameState | autoloads/game_state.gd | Phase, health, materials, perks, run state |
| 2 | CraftingDB | autoloads/crafting_db.gd | Destructible yield tables |
| 3 | StageData | autoloads/stage_data.gd | 6 biomes x 14 waves = 84 waves of data |
| 4 | OrbitalDB | autoloads/orbital_db.gd | 12 orbital weapon definitions |
| 5 | WaveManager | autoloads/wave_manager.gd | Wave spawning, enemy tracking |
| 6 | SaveManager | autoloads/save_manager.gd | Profile-based ConfigFile persistence |
| 7 | Achievements | autoloads/achievements.gd | 20 achievements with toast UI |
| 8 | ArmorDB | autoloads/armor_db.gd | 8 armor sets with stat bonuses |
| 9 | JunkyardState | scripts/junkyard_state.gd | Junkyard mode state (NOT in autoloads/ dir) |
| 10 | CardDB | autoloads/card_db.gd | 40 collectible cards across 4 decks |
| 11 | AudioManager | autoloads/audio_manager.gd | Music crossfade, SFX, auto-button sounds |
| 12 | UpgradeDB | autoloads/upgrade_db.gd | Permanent upgrade definitions and purchase |

### Display Settings (from project.godot)

| Setting | Value | CLAUDE.md Says | Status |
|---------|-------|----------------|--------|
| Viewport | 960x540 | 480x270 | MISMATCH |
| Main Scene | intro_video.tscn | debug_boot.tscn | MISMATCH |
| Stretch Mode | canvas_items | -- | OK |
| Texture Filter | Nearest (0) | -- | OK (pixel art) |
| Renderer | GL Compatibility | GL Compatibility | OK |
| 2D Gravity | 0 | -- | OK (top-down) |

### File Count Breakdown

| Category | Count |
|----------|-------|
| GDScript files (.gd) | 63 |
| Scene files (.tscn) | 45 |
| Resource files (.tres) | 2 |
| Sprite PNGs | ~3,000 |
| Audio files (wav+ogg) | ~65 |
| Font files | ~50 |
| Video files | 553 |

---

## 3. Critical Issues

### 3.1 CRITICAL -- Ember Drake/Piston Crusher Charge Deals Damage Every Frame

- **Severity:** CRITICAL
- **Files:** `scripts/enemy_ember_drake.gd:53`, `scripts/enemy_piston_crusher.gd:48-49`
- **Description:** During charging, `_physics_process` checks distance and calls `player_ref.take_damage(CHARGE_DAMAGE)` with NO cooldown or hit flag. At 60fps over a 0.8s charge, this deals `CHARGE_DAMAGE * 48 frames` of damage.
- **Impact:** Instant player death from a single charge attack. Ember Drake does 20 damage per frame = 960 total. Piston Crusher similarly devastating.
- **Fix:**
```gdscript
# Add flag at class level:
var _charge_hit_player := false

# In charge damage check:
if dist < 18.0 and not _charge_hit_player:
    player_ref.take_damage(CHARGE_DAMAGE)
    _charge_hit_player = true

# Reset in charge start:
_charge_hit_player = false
```

### 3.2 CRITICAL -- Double Death Authority Race Condition

- **Severity:** CRITICAL
- **Files:** `scripts/arena.gd:1003-1004`, `scripts/player.gd:809-814`
- **Description:** When health reaches 0, `GameState.take_damage()` emits `health_changed` synchronously. Arena's `_on_health_changed` detects `current <= 0` and calls `_on_player_died()` -> `GameState.end_run()`. Meanwhile, player.gd's `take_damage()` independently checks lethal damage and calls `_die()`. Both death paths execute with different cleanup in different orders.
- **Impact:** `end_run()` resets state BEFORE death animation plays. Game transitions to game_over.tscn after fixed 2.8s delay regardless of animation state. Potential double-cleanup of game state.
- **Fix:** Pick ONE death authority. Either arena detects death exclusively (remove lethal check from player.gd and have player emit a `died` signal), or player handles death exclusively and arena responds to a signal.

### 3.3 CRITICAL -- Wave Manager tree_exiting Fires During Scene Teardown

- **Severity:** CRITICAL
- **Files:** `scripts/wave_manager.gd:166`
- **Description:** Enemy death is tracked via `enemy.tree_exiting.connect(_on_enemy_died)`. `tree_exiting` fires when a node is removed from the tree for ANY reason, including scene changes. During arena-to-hub transitions, ALL enemies fire `tree_exiting`, each decrementing `enemies_alive` and potentially triggering `wave_complete` spuriously.
- **Impact:** False `wave_complete` signals during scene transitions. Can cause state corruption if handlers try to access freed nodes.
- **Fix:** Use a custom `died` signal on EnemyBase instead of `tree_exiting`. Or add a `_shutting_down` flag that `_exit_tree` sets to skip death processing.

### 3.4 CRITICAL -- Attack Animation Permanently Locks on Enemy Death Mid-Await

- **Severity:** CRITICAL
- **Files:** `scripts/enemy_base.gd:650-651`, `scripts/enemy_base.gd:673-687`
- **Description:** `_play_attack_anim()` and `_play_attack_anim_then()` use `await get_tree().create_timer().timeout`. If the enemy is freed during the await, `_attack_anim_playing` is never reset to false. While this affects the dying enemy (which is being freed anyway), the pattern is also used in ranged enemies where the callback that fires projectiles may never execute.
- **Impact:** Ranged enemies can silently stop attacking if their attack animation is interrupted by death, and the projectile callback is lost.
- **Fix:** Use Timer nodes with `timeout` signals instead of `await`. Ensure `_die()` resets `_attack_anim_playing = false`.

### 3.5 CRITICAL -- Orbital Weapons Freeze if Slot 0 Removed

- **Severity:** CRITICAL
- **File:** `scripts/orbital_weapon.gd:75`
- **Description:** The static `_shared_orbit_time` is only incremented by the orbital weapon with `slot_index == 0`. If that weapon is freed (removed from loadout, or scene change), no weapon increments the shared timer and ALL orbitals freeze in place.
- **Impact:** All orbital weapons stop orbiting, breaking the core combat mechanic.
- **Fix:** Use a different mechanism -- e.g., any active orbital can increment, or use an autoload timer:
```gdscript
# In _physics_process:
if slot_index == _get_lowest_active_slot():
    _shared_orbit_time += delta
```

---

## 4. Code Quality Findings

### 4.1 Autoloads

#### game_state.gd (523 lines)
- `OrbitalWeapon._shared_orbit_time = 0.0` at line 292 references a non-autoload class without null check
- `card_collected` signal defined here AND in CardDB -- duplicate signal name across autoloads
- Magic number 14 in stage calculation (line 464) should use `StageData.WAVES_PER_STAGE`
- Empty `_ready()` function (line 170)
- `randi() % buffs.size()` modulo bias (line 500)

#### wave_manager.gd (213 lines)
- `_cached_enemies` array populated every 3 frames but never read within the file (dead code)
- `spawn_queue.pop_front()` is O(n) per spawn -- should reverse and use `pop_back()`
- `enemies_remaining_changed` emits inconsistent values at wave start vs during combat

#### save_manager.gd (370 lines)
- Legacy save deleted after migration without verifying copy succeeded (line 72-73)
- `_revival_used` and `chimera_buff` not persisted -- revival resets on save/load
- `DEFAULT_PERM` is a const Dictionary but GDScript const dicts are mutable

#### audio_manager.gd (301 lines)
- `get_tree().node_added` connection auto-wires button sounds but never disconnects -- buttons created/freed rapidly get duplicate connections
- `play_music()` uses `await` with 0.5s delay; rapid calls can leak Timer nodes
- Dead `pass` statements from removed debug prints

#### stage_data.gd (389 lines)
- Missing stage 2 (Molten Core) entry in `STAGE_FIRST_TRACKS`
- `get_enemy_hp_scale()` silently returns 1.0 for enemies not in any stage's native list

#### upgrade_db.gd (423 lines)
- No bounds checking on `upgrade_id` in `get_upgrade_level()`, `get_max_level()`, `is_maxed()`, `get_next_cost()` -- invalid IDs crash
- `REGEN_TIERS[level - 1]` can overflow if level exceeds array size
- Salvage speed array duplicated between here and `GameState.get_salvage_tool_speed()`

### 4.2 Player & Arena

#### player.gd (941 lines)
- `_on_health_changed` connected but empty (line 926) -- dead signal handler
- `_update_ability_hud` does uncached `get_parent().get_node_or_null("HUD")` every physics frame
- `_has_prop_nearby()` iterates ALL props every frame when Shift is pressed -- no spatial partitioning
- `_show_bark_wave` creates 4+ new nodes per attack -- at 10+ attacks/sec this floods the scene tree
- Death SFX variable exists but is annotated unused (line 64)

#### arena.gd (1431 lines)
- Only disconnects 1 of 5 autoload signals in `_exit_tree` (line 89-92)
- `await get_tree().create_timer(2.0).timeout` in `_start_combat` with no guard against concurrent calls
- `GameState.permanent.runs_completed += 1` without checking key exists (line 978)
- Debug god mode (F1) and wave skip (F2) marked "REMEMBER TO REMOVE BEFORE RELEASE" (line 95-105)
- `_update_xp_bar()` runs every frame regardless of phase

#### hud.gd (436 lines)
- `enemies_label` declared but never constructed -- all `update_enemies()` calls are no-ops (line 343)
- `dodge_label`, `sneak_label`, `dig_label`, `collect_label` declared but never created -- 4 dead update functions
- Empty `_process` function wastes virtual call overhead (line 65)

### 4.3 Enemy System

#### enemy_base.gd (1165 lines) -- Base Class
- `_animate_sprite()` is a 120-line if/elif chain checking enemy_type strings (lines 462-600) -- should be data-driven
- `sprite.flip_h` direction is inverted vs flyer-type convention (line 607) -- some enemies face wrong direction
- Burning damage stacks without deduplication -- two molotovs = double burn (line 1136)
- Slow/shock stacking applies incorrect speed values -- last-applied wins, not combined (line 1142-1164)
- Burrow flanking available to all enemies including bosses with no size check

#### Common Patterns Across 35 Enemy Scripts
- `_make_circle_poly()` duplicated in 5 files -- should be in enemy_base.gd
- Boss spawner `tree_exiting` + `WaveManager.enemies_alive` pattern duplicated in 8 files
- Flyer movement override is copy-pasted across 4 files
- Ranged preferred-distance pattern duplicated across 4 files
- Fire trail dots (ember_drake, magma_imp) only damage on entry, not while standing in them

### 4.4 Orbital Weapons

#### orbital_weapon.gd (527 lines)
- Accesses `AudioManager._players` directly (private member) at line 97
- Static `_shared_orbit_time` persists across scene changes -- orbitals don't reset angle on new runs

#### Notable Orbital Issues
- `orbital_magnet_core.gd:19` -- enemies teleported toward player bypass collision, can be pulled into walls
- `orbital_thorn_vine.gd:14` -- vine damage line hardcoded at 70px, not scaled by attack_range
- `orbital_arcane_book.gd:63` -- missiles don't track targets, fly to snapshot position

### 4.5 Other Systems

#### chest.gd (488 lines)
- `get_tree().paused = true` for key choice UI -- if chest freed while UI open, game stays paused (line 179)
- `lbl.pivot_offset = lbl.size / 2.0` immediately after creation -- size is (0,0), scale animation scales from corner (line 419)

#### junkyard_v2.gd (1277 lines)
- `_jy.junkyard_wave += 1` with no null check -- `_jy` set via `get_node_or_null` (line 966)
- Vine snare perk multiplies enemy speed by 0.6 every 0.5s without tracking original -- compounding slowdown (line 1227)
- Force-completing stuck waves after 3s timeout may prematurely end slow-spawning waves (line 190)

#### level_up.gd (586 lines)
- Regen perk can be picked multiple times but creates at most one timer -- wasted perk slot on re-pick
- Attack speed perk uses hardcoded 0.6 instead of `AUTO_ATTACK_COOLDOWN` constant (line 474)
- Bug Swarm and Vine Snare implementation duplicated between here and arena.gd `_restore_card_perks()`

#### secret_room.gd (345 lines)
- Uses `preload("res://scenes/chest.tscn")` at class level -- violates CLAUDE.md gotcha #6 (line 12)

#### main_menu.gd (1003 lines)
- Master volume slider hardcoded to 1.0, doesn't read actual bus volume (line 367)
- Delete save 3-second confirm cooldown can race with rapid presses (line 401-414)

#### pause_menu.gd (598 lines)
- `_return_to_hub` directly manipulates WaveManager internals (`wave_active`, `spawn_queue`, `enemies_alive`) instead of using an abort method (line 565-584)
- Destroys and rebuilds entire UI every open/close cycle (line 42-43)

#### intro_video.gd (93 lines)
- Frame crossfade tween duration (0.3s) exceeds frame interval (0.1s) -- tweens overlap causing flicker (line 80)
- Synchronous `load()` for 552 frames every 100ms -- potential micro-stutters (line 62)

---

## 5. Feature Verification Results

### Player System

| Feature | Status | Notes |
|---------|--------|-------|
| Movement (WASD+arrows) | PASS | Diagonal normalized, speed scales with perks |
| Health/Damage | PARTIAL | Works but double death authority creates race condition |
| Invincibility frames | PASS | Hurt timer + flash working correctly |
| Dodge/Leap | PASS | Invulnerable during leap, cooldown tracked |
| Bark attack | PASS | AOE damage + visual wave effect |
| Dig mechanic | PASS | Charge-based with proper animation |
| Sneak mechanic | PASS | Speed reduction + enemy detection bypass |
| Death flow | FAIL | Two independent death paths (arena + player) race |
| Orbital weapons | PARTIAL | Core loop works but slot 0 removal freezes all |
| Costumes/Armor | PASS | 10 costumes with stat bonuses |

### Combat System

| Feature | Status | Notes |
|---------|--------|-------|
| Auto-attack | PASS | Timer-based, nearest enemy targeting |
| Orbital damage | PASS | 12 weapon types with distinct behaviors |
| Collision layers | PARTIAL | Player body collides with projectiles (layer 4 in mask) -- may cause physics pushing |
| Status effects | FAIL | Slow/shock stacking uses wrong speed values |
| Burning damage | FAIL | Stacks without deduplication |
| Charge attacks | FAIL | Ember Drake/Piston Crusher deal damage every frame |

### Enemy System

| Feature | Status | Notes |
|---------|--------|-------|
| 35 enemy types | PASS | All implemented with distinct behaviors |
| Spawning | PASS | Off-screen spawn points, wave-based |
| Pathfinding | PARTIAL | 4 enemies missing NavigationAgent2D (may be intentional for flyers/turrets) |
| Death + cleanup | PARTIAL | Works but tree_exiting can fire during scene teardown |
| Boss mechanics | PASS | Enrage phases, spawning minions, unique attacks |
| Sprite direction | FAIL | flip_h convention inconsistent between base class and flyer types |

### Loot/Treasure System

| Feature | Status | Notes |
|---------|--------|-------|
| Chest spawning | PASS | Bronze/Silver/Gold + Secret chests |
| Key system | PASS | 3 key tiers + secret keys |
| Card collection | PASS | 40 cards across 4 decks with stat bonuses |
| Material pickups | PASS | Magnet behavior, float text |
| Destructible props | PASS | Yield tables in CraftingDB |

### UI System

| Feature | Status | Notes |
|---------|--------|-------|
| HUD health bar | PASS | Updates reactively via signal |
| HUD enemy count | FAIL | enemies_label never constructed -- always null |
| HUD ability display | PARTIAL | Update function runs but references dead labels |
| Level-up screen | PASS | Perk selection with orbital weapon offers |
| Pause menu | PASS | Volume, controls info, return to hub |
| Game over screen | PASS | Stats display, material summary, return button |
| Main menu | PASS | Profile system, options, credits |

### Audio System

| Feature | Status | Notes |
|---------|--------|-------|
| Music per biome | PASS | Stage-based track selection with first-entry tracks |
| Music crossfade | PASS | Tween-based fade between tracks |
| SFX for events | PASS | Comprehensive coverage (player, enemies, UI, environment) |
| Auto button sounds | PARTIAL | Works but connections never cleaned up on button free |
| Volume control | PARTIAL | Pause menu reads actual value, main menu hardcodes 1.0 |

### Save/Load System

| Feature | Status | Notes |
|---------|--------|-------|
| Profile-based saves | PASS | 3 profile slots |
| Legacy migration | PARTIAL | Deletes original before verifying copy succeeded |
| Run snapshot/restore | PASS | Wave-start snapshots for death recovery |
| Persistent upgrades | PASS | Saved per-profile |
| Revival state | FAIL | `_revival_used` not persisted -- revival resets on save/load |

---

## 6. Scene & Asset Audit Results

### Scene Issues

| Scene | Status | Issue |
|-------|--------|-------|
| destructible_prop.tscn | FAIL | Missing CollisionShape2D -- cannot physically block |
| dig_hole.tscn | FAIL | Missing CollisionShape2D -- cannot detect player overlap |
| player.tscn | WARN | collision_mask=7 includes enemy projectiles (layer 4) -- causes physics pushing |
| player.tscn | WARN | SpriteFrames has empty "default" animation with no frames |
| player.tscn | INFO | Camera zoom=1x (CLAUDE.md says 3x) |
| enemy_spore_mother.tscn | WARN | Root node "EnemysporeMother" -- lowercase 's' |
| 4 enemy scenes | INFO | Missing NavigationAgent2D (crystal_bat, magma_imp, spark_bug, steam_turret) |
| All enemy scenes | INFO | SpriteFrames are inline and empty -- loaded at runtime by script |

### Asset Issues

| Category | Issue | Impact |
|----------|-------|--------|
| Music .wav files | ~26MB each vs ~1MB for .ogg | ~200MB+ wasted disk space |
| Duplicate music | "scrapyard first.wav" + scrapyard_first.wav identical | 26MB duplicate |
| Video frames | 552 PNGs in assets/video/frames/ | ~50MB+ redundant (source for intro.ogv) |
| Title card variants | 5 versions (jpg, png, original, full, menu) | ~3MB, likely only 1-2 used |
| Key sprites | Duplicated in ui/ and items/ | Minor redundancy |
| Level art JPGs | Spaces + mixed case in filenames | Naming inconsistency |
| Game icon | "Game icon.png" has space | Naming inconsistency |
| Font files | rpgmaker_instructions.txt, read_me.txt | Unnecessary files in export |
| traps/ directory | Does not exist | CLAUDE.md stale |
| items/ contents | No throwables/materials, has chests/keys/projectiles | CLAUDE.md stale |

### Import Settings

All sprite .import files are present and use default settings. Texture filtering is set to Nearest at the project level (correct for pixel art). No mipmaps enabled.

---

## 7. Architecture Recommendations

### 7.1 Unify Death Authority (Priority: Critical)

Create a single death detection path. Recommended: Player emits `died` signal, arena responds:

```gdscript
# player.gd
signal died

func take_damage(amount):
    if is_dead or _is_leaping: return
    GameState.take_damage(amount)
    if GameState.player_health <= 0:
        _die()
        died.emit()

# arena.gd -- remove _on_health_changed death check, connect to player.died instead
```

### 7.2 Replace tree_exiting with Custom Signal (Priority: Critical)

```gdscript
# enemy_base.gd
signal died(xp_reward)  # Already exists

# wave_manager.gd -- connect to died instead of tree_exiting
enemy.died.connect(_on_enemy_died)
```

### 7.3 Extract Shared Enemy Utilities (Priority: Medium)

Move to enemy_base.gd:
- `_make_circle_poly()` (currently in 5 files)
- Boss minion spawn/tracking pattern (currently in 8 files)
- Ranged preferred-distance movement (currently in 4 files)
- Flyer direct-chase movement (currently in 4 files)

### 7.4 Data-Drive Animation System (Priority: Medium)

Replace the 120-line `_animate_sprite()` if/elif chain with a dictionary:

```gdscript
const ANIM_PARAMS := {
    "rusher": {"bob_speed": 12.0, "bob_amount": 0.06, "squash_amount": 0.04},
    "shooter": {"bob_speed": 10.0, "bob_amount": 0.04, "squash_amount": 0.03},
    # ...
}
```

### 7.5 Fix Status Effect Stacking (Priority: High)

Track active debuffs as an array and compute combined speed:

```gdscript
var _active_debuffs: Array[Dictionary] = []

func _compute_speed() -> float:
    var mult := 1.0
    for debuff in _active_debuffs:
        mult *= debuff.speed_mult
    return _base_move_speed * mult
```

### 7.6 Add WaveManager.abort_wave() (Priority: Medium)

Instead of pause_menu.gd directly manipulating WaveManager internals:

```gdscript
# wave_manager.gd
func abort_wave():
    wave_active = false
    spawn_queue.clear()
    enemies_alive = 0
    _spawn_timer_acc = 0.0
```

### 7.7 Convert Music WAVs to OGG (Priority: Low)

The 10 .wav music files at ~26MB each total ~260MB. Converting to OGG Vorbis at reasonable quality would reduce this to ~10MB total with negligible quality loss.

### 7.8 Update CLAUDE.md (Priority: Medium)

The CLAUDE.md is severely out of date. Key discrepancies:
- Viewport is 960x540, not 480x270
- Main scene is intro_video.tscn, not debug_boot.tscn
- 12 autoloads, not 4
- 84 waves across 6 biomes, not 10 waves
- Player is a dog with costumes, not a craftsman with throwables
- Orbital weapons replaced throwable weapons
- Chest/key/card system replaced the old loot system
- traps/ directory doesn't exist
- items/ folder has completely different contents

---

## 8. Appendices

### Appendix A: Signal Map

#### Signals Defined

| Signal | Emitter | Connected To |
|--------|---------|-------------|
| `phase_changed(new_phase)` | GameState | (various, runtime) |
| `materials_changed` | GameState | arena._on_materials_changed, base_hub._refresh_top_bar |
| `health_changed(current, max_hp)` | GameState | arena._on_health_changed, player._on_health_changed (empty) |
| `keys_changed` | GameState | arena (conditional), base_hub._refresh_top_bar |
| `abilities_changed` | GameState | (runtime) |
| `card_collected(card_data)` | GameState | (unused, @warning_ignore) |
| `card_collected(card)` | CardDB | (runtime -- DUPLICATE NAME with GameState) |
| `wave_started(wave_num)` | WaveManager | (runtime) |
| `wave_complete(wave_num)` | WaveManager | arena._on_wave_complete |
| `all_waves_complete` | WaveManager | arena._on_all_waves_complete |
| `enemy_spawned(enemy)` | WaveManager | (runtime) |
| `enemies_remaining_changed(count)` | WaveManager | arena._on_enemies_remaining_changed |
| `profile_changed(slot, name)` | SaveManager | (runtime) |
| `achievement_unlocked` | Achievements | (runtime toast UI) |
| `perk_chosen(perk_id)` | LevelUp | arena (runtime) |
| `died(xp_reward)` | EnemyBase | (runtime) |
| `resumed` | PauseMenu | (runtime) |

#### Signals Connected but Empty/Dead

| Signal | Handler | Status |
|--------|---------|--------|
| `GameState.health_changed` | `player._on_health_changed` | Empty `pass` -- dead handler |

### Appendix B: Collision Layer Map

| Layer | Name | Used By |
|-------|------|---------|
| 1 | Walls/Static | Player body, wall collisions, props |
| 2 | Enemies | Enemy CharacterBody2D |
| 4 | Enemy Projectiles | enemy_projectile.tscn Area2D |
| 5 | Player+Enemies (mask) | Enemy detection mask |
| 16 | Pickups/Interactables | material_pickup, chest, key_pickup, secret_door |

**Issue:** Player's collision_mask=7 (layers 1+2+4) means enemy projectiles physically push the player via CharacterBody2D collision, not just Area2D damage detection.

### Appendix C: Complete File Inventory

#### Scripts (63 files)

| File | Lines | Status |
|------|-------|--------|
| autoloads/game_state.gd | 523 | ISSUES -- OrbitalWeapon ref, duplicate signal, magic numbers |
| autoloads/crafting_db.gd | 46 | CLEAN |
| autoloads/wave_manager.gd | 213 | ISSUES -- tree_exiting, O(n) pop_front, dead cache |
| autoloads/save_manager.gd | 370 | ISSUES -- unsafe migration, missing persistence |
| autoloads/stage_data.gd | 389 | MINOR -- missing stage 2 first track |
| autoloads/orbital_db.gd | 245 | MINOR -- inconsistent attack_range type |
| autoloads/achievements.gd | 233 | MINOR -- stale building achievement checks |
| autoloads/armor_db.gd | 157 | CLEAN |
| autoloads/card_db.gd | 117 | ISSUES -- duplicate signal name with GameState |
| autoloads/audio_manager.gd | 301 | ISSUES -- leaked connections, timer leak, dead code |
| autoloads/upgrade_db.gd | 423 | MINOR -- no bounds checks, duplicated data |
| scripts/player.gd | 941 | ISSUES -- empty handler, uncached lookups, node flooding |
| scripts/arena.gd | 1431 | CRITICAL -- double death, signal cleanup, debug keys |
| scripts/arena_builder.gd | 2257 | MINOR -- large but functional |
| scripts/hud.gd | 436 | ISSUES -- 5 dead labels/functions, empty _process |
| scripts/level_up.gd | 586 | ISSUES -- regen waste, hardcoded constant, perk dedup |
| scripts/game_over.gd | 346 | MINOR -- uncapped embers |
| scripts/main_menu.gd | 1003 | MINOR -- volume desync, confirm race |
| scripts/debug_boot.gd | 122 | MINOR -- enum type check may fail |
| scripts/base_hub.gd | 1454 | CLEAN -- good signal cleanup |
| scripts/intro_video.gd | 93 | MINOR -- tween overlap, sync load |
| scripts/pause_menu.gd | 598 | ISSUES -- direct WaveManager manipulation, rebuild-on-open |
| scripts/card_popup.gd | 159 | MINOR -- process runs when not showing |
| scripts/enemy_base.gd | 1165 | CRITICAL -- await lock, status stacking, flip_h, burn dedup |
| scripts/enemy_rusher.gd | 11 | CLEAN |
| scripts/enemy_shooter.gd | 75 | CLEAN |
| scripts/enemy_tank.gd | 13 | CLEAN |
| scripts/enemy_flyer.gd | 24 | CLEAN |
| scripts/enemy_exploder.gd | 104 | MINOR -- await in physics context |
| scripts/enemy_projectile.gd | 78 | CLEAN |
| scripts/enemy_brass_enforcer.gd | 31 | CLEAN |
| scripts/enemy_crystal_bat.gd | 23 | CLEAN |
| scripts/enemy_crystal_colossus.gd | 95 | CLEAN |
| scripts/enemy_ember_drake.gd | 178 | CRITICAL -- charge damage every frame, fire dots entry-only |
| scripts/enemy_frost_sprite.gd | 24 | CLEAN |
| scripts/enemy_frost_warden.gd | 116 | MINOR -- spawner tree_exiting pattern |
| scripts/enemy_fungal_brute.gd | 39 | CLEAN |
| scripts/enemy_fungal_titan.gd | 212 | CLEAN |
| scripts/enemy_gear_drone.gd | 13 | CLEAN |
| scripts/enemy_glacial_hulk.gd | 67 | CLEAN |
| scripts/enemy_ice_archer.gd | 60 | CLEAN |
| scripts/enemy_junkyard_mech.gd | 116 | MINOR -- tween outside null check |
| scripts/enemy_lava_lobber.gd | 163 | CLEAN |
| scripts/enemy_magma_imp.gd | 101 | MINOR -- fire dots entry-only |
| scripts/enemy_molten_wyrm.gd | 213 | CLEAN |
| scripts/enemy_mycelium_sniper.gd | 68 | CLEAN |
| scripts/enemy_obsidian_golem.gd | 83 | CLEAN |
| scripts/enemy_phantom.gd | 36 | CLEAN |
| scripts/enemy_piston_crusher.gd | 145 | CRITICAL -- charge damage every frame |
| scripts/enemy_scrap_king.gd | 180 | CLEAN |
| scripts/enemy_scrap_sentinel.gd | 138 | CLEAN |
| scripts/enemy_shadow_crawler.gd | 53 | MINOR -- tween overlap on teleport |
| scripts/enemy_spark_bug.gd | 66 | CLEAN |
| scripts/enemy_spore_mother.gd | 179 | CLEAN |
| scripts/enemy_spore_walker.gd | 94 | CLEAN |
| scripts/enemy_steam_turret.gd | 53 | CLEAN |
| scripts/enemy_the_architect.gd | 165 | CLEAN |
| scripts/enemy_the_devourer.gd | 129 | CLEAN |
| scripts/enemy_void_weaver.gd | 97 | MINOR -- zone damages on tick 0 |
| scripts/destructible_prop.gd | 227 | MINOR -- shake position drift |
| scripts/material_pickup.gd | 125 | MINOR -- float text position assumption |
| scripts/chest.gd | 488 | ISSUES -- pause stuck, pivot offset zero |
| scripts/dig_hole.gd | 86 | CLEAN |
| scripts/key_pickup.gd | 113 | CLEAN |
| scripts/secret_door.gd | 193 | MINOR -- no deny feedback |
| scripts/secret_room.gd | 345 | ISSUES -- preload at class level |
| scripts/junkyard_state.gd | 122 | MINOR -- tight coupling to GameState privates |
| scripts/junkyard_v2.gd | 1277 | ISSUES -- null crash, vine snare compounding |
| scripts/junkyard_waves.gd | 70 | CLEAN |
| scripts/orbital_weapon.gd | 527 | CRITICAL -- slot 0 freeze, private member access |
| scripts/orbitals/*.gd (12 files) | ~350 total | MINOR -- magnet pulls through walls, vine range mismatch |
| scripts/setup_sprite_frames.gd | 129 | CLEAN (tool script) |

#### Scenes (45 files)

| File | Status |
|------|--------|
| scenes/arena.tscn | CLEAN |
| scenes/base_hub.tscn | CLEAN |
| scenes/main_menu.tscn | CLEAN |
| scenes/game_over.tscn | CLEAN |
| scenes/level_up.tscn | CLEAN |
| scenes/debug_boot.tscn | CLEAN |
| scenes/intro_video.tscn | CLEAN |
| scenes/card_popup.tscn | CLEAN |
| scenes/player.tscn | WARN -- collision_mask includes projectiles, empty SpriteFrames |
| scenes/junkyard.tscn | CLEAN |
| scenes/destructible_prop.tscn | FAIL -- missing CollisionShape2D |
| scenes/dig_hole.tscn | FAIL -- missing CollisionShape2D |
| scenes/chest.tscn | CLEAN |
| scenes/key_pickup.tscn | CLEAN |
| scenes/secret_door.tscn | CLEAN |
| scenes/secret_room.tscn | CLEAN |
| scenes/material_pickup.tscn | CLEAN |
| scenes/enemy_projectile.tscn | CLEAN |
| scenes/enemies/*.tscn (35 files) | MINOR -- EnemysporeMother typo, inline empty SpriteFrames |

---

*End of Audit Report*
