# Scrapwright Comprehensive Debug Audit Report v2

**Date:** 2026-03-31
**Auditor:** Claude Code (Opus 4.6)
**Scope:** Full recursive audit of every .gd, .tscn, .tres, .cfg file
**Research:** Cross-referenced against Godot 4.x known pitfalls, GitHub issues, and community best practices

---

## Summary

| Severity | Count |
|----------|-------|
| CRITICAL | 12 |
| WARNING  | 16 |
| INFO     | 10 |
| **Total** | **38** |

---

## CRITICAL — Will crash or cause data loss

### C01: Unguarded `await` in `arena.gd:_start_combat()` line 196
**File:** `scripts/arena.gd:196`
**Issue:** `await get_tree().create_timer(2.0).timeout` has no `is_inside_tree()` guard before it. If the player quits to menu during the stage name banner, the coroutine resumes on a freed node.
**Fix:** Add `if not is_inside_tree(): return` before line 196.

### C02: Unguarded `await` in `arena.gd:_end_chest_phase()` line 278
**File:** `scripts/arena.gd:278`
**Issue:** `await get_tree().create_timer(0.35).timeout` inside `_end_chest_phase()` has no tree guard. Scene could change during the 0.35s fade delay.
**Fix:** Add `if not is_inside_tree(): return` before line 278.

### C03: Unguarded `await` in `arena.gd:_on_all_waves_complete()` line 971
**File:** `scripts/arena.gd:971`
**Issue:** `await get_tree().create_timer(2.5).timeout` followed immediately by `change_scene_to_file()`. No tree guard. If player force-quits during the "RUN COMPLETE!" banner, this crashes.
**Fix:** Add `if not is_inside_tree(): return` before line 971 and after line 971.

### C04: Unguarded `await` in `arena.gd:_spawn_secret_door()` line 1144
**File:** `scripts/arena.gd:1144`
**Issue:** `await get_tree().create_timer(1.0).timeout` without tree guard.
**Fix:** Add `if not is_inside_tree(): return` before line 1144 and after.

### C05: Unguarded `await` in `secret_room.gd` line 335
**File:** `scripts/secret_room.gd:335`
**Issue:** `await get_tree().create_timer(1.5).timeout` followed by scene change. No tree guard.
**Fix:** Add `if not is_inside_tree(): return` after line 335.

### C06: 39 instances of `get_parent().add_child()` without null check
**Files:** 23 enemy scripts + player.gd + arena_builder.gd
**Issue:** If `get_parent()` returns null (node freed during tween/timer callback), calling `.add_child()` on null crashes. Most common in visual effect creation (flash, lines, labels).
**Key offenders (highest call count):**
- `enemy_ember_drake.gd` — 3 unguarded calls (lines 86, 122, 168)
- `enemy_scrap_sentinel.gd` — 3 unguarded calls (lines 65, 99, 121)
- `enemy_scrap_king.gd` — 3 unguarded calls (lines 102, 135, 171)
- `enemy_the_architect.gd` — 3 unguarded calls (lines 101, 107, 156)
- `player.gd` — 5 unguarded calls (bark wave lines, death animation)
**Fix:** Add `var parent = get_parent()` + `if not parent: return` before each `add_child()` call.

### C07: Recursive async functions lack `is_instance_valid(self)` check
**Files:**
- `enemy_fungal_titan.gd:_run_poison_ticks()` line 127
- `enemy_molten_wyrm.gd:_run_lava_ticks()` line 163
- `enemy_void_weaver.gd:_run_zone_ticks()` line 91
- `enemy_spore_mother.gd:_run_cloud_ticks()` line 109
**Issue:** These recursive coroutines add `is_inside_tree()` guards before `await`, but the zone/pool itself is parented to the arena (not the enemy). After the enemy dies and is freed, the coroutine continues running with an invalid `self` reference. The `is_inside_tree()` guard catches the case where the enemy node is removed from the tree, but if the node has been fully freed (not just removed), `is_inside_tree()` itself would error.
**Fix:** Add `if not is_instance_valid(self): ... queue_free pool ... return` at the top of each recursive call.

### C08: `_play_attack_anim()` missing `is_inside_tree()` guard before await
**File:** `scripts/enemy_base.gd:647`
**Issue:** `await get_tree().create_timer(dur).timeout` — the `_play_attack_anim()` (non-callback version) only checks `is_instance_valid(self)` after the await, but calling `get_tree()` on a freed node crashes before the await even starts.
**Fix:** Add `if not is_inside_tree(): return` before line 647.

### C09: `_deferred_spawn_key()` accesses potentially freed parent
**File:** `scripts/enemy_base.gd:815-824`
**Issue:** `call_deferred("_deferred_spawn_key", tier)` fires after the current frame. The `_get_pickup_container()` helper calls `get_parent()` which may return null if the enemy is being freed during scene teardown.
**Fix:** Add `if not get_parent(): return` at the top of `_deferred_spawn_key()`.

### C10: Unguarded `await` in `secret_room.gd` line 291
**File:** `scripts/secret_room.gd:291`
**Issue:** `await get_tree().create_timer(3.0).timeout` — 3 full seconds with no tree guard. Uses `is_instance_valid(_banner_label)` after, but doesn't check `self`.
**Fix:** Add `if not is_inside_tree(): return` after line 291.

### C11: Scene change without active tween cleanup
**File:** `scripts/game_over.gd:343`, `scripts/pause_menu.gd:582,593`
**Issue:** `get_tree().change_scene_to_file()` called inside a tween callback without ensuring other active tweens are killed. Floating labels, particle effects, and bark wave tweens running in the arena can access freed nodes during scene transition.
**Fix:** Before scene change, set `get_tree().paused = true` or use `get_tree().call_deferred("change_scene_to_file", path)`.

### C12: `main_menu.gd` await in lambda without tree guard
**File:** `scripts/main_menu.gd:408`
**Issue:** `await get_tree().create_timer(3.0).timeout` inside a lambda connected to a button press. If the player navigates away during the 3s confirmation delay, the lambda resumes on freed nodes. The `is_instance_valid(delete_btn)` guard only protects the button, not the surrounding scene.
**Fix:** Add `if not is_inside_tree(): return` after line 408.

---

## WARNING — Will cause bugs or unexpected behavior

### W01: Per-frame group query in `wave_manager.gd`
**File:** `autoloads/wave_manager.gd:81`
**Issue:** `_cached_enemies = get_tree().get_nodes_in_group("enemies")` is called every single frame when `wave_active` is true. With 50+ enemies, this is O(n) allocation every frame.
**Fix:** Update the cache every 3-5 frames instead of every frame, or use a dirty flag.

### W02: `audio_manager.gd` race condition in `play_music()`
**File:** `autoloads/audio_manager.gd:162-191`
**Issue:** `play_music()` uses `await get_tree().create_timer(0.5).timeout` for crossfade. If called twice in quick succession (e.g., boss wave starts while stage transition music is still fading), the second call overwrites `_music_player` while the first await is still pending.
**Fix:** Kill any existing crossfade tween before starting a new one, or use a mutex flag.

### W03: `orbital_weapon.gd` time ignores pause state
**File:** `scripts/orbital_weapon.gd:95`
**Issue:** Uses `Time.get_ticks_msec()` for rotation angle. When game is paused (level-up screen, chest phase), time keeps advancing, causing orbital weapons to jump position when unpaused.
**Fix:** Use a class-level accumulator incremented in `_process(delta)` instead of wall clock time.

### W04: Missing `is_instance_valid()` on `get_node_or_null` results
**Files:**
- `scripts/destructible_prop.gd:178,185` — `get_node_or_null("/root/JunkyardState")` used with `if jy and jy.is_active` but no `is_instance_valid()`
- `scripts/game_over.gd:275,335` — Same pattern
- `scripts/pause_menu.gd:571` — Same pattern
**Issue:** In Godot 4, a freed node reference is not null — it's an invalid reference. Checking `if jy:` passes but accessing properties crashes. Autoloads are never freed so this is low-risk, but the pattern is unsafe for general use.
**Fix:** Use `if jy and is_instance_valid(jy):` for safety.

### W05: Recursive async functions don't check `is_dead`
**Files:**
- `enemy_fungal_titan.gd:_run_poison_ticks()`
- `enemy_molten_wyrm.gd:_run_lava_ticks()`
- `enemy_spore_mother.gd:_run_cloud_ticks()`
- `enemy_void_weaver.gd:_run_zone_ticks()`
**Issue:** These zone damage functions continue dealing damage even after the parent enemy dies. The zones are parented to the arena (not the enemy), so they persist correctly, but the `self` reference in the recursive call becomes invalid when the enemy is freed.
**Fix:** Store the damage amount and player group in local vars before the recursive loop, or pass them as parameters.

### W06: `_lava_lobber.gd` timer callback references `self`
**File:** `scripts/enemy_lava_lobber.gd:76-78`
**Issue:** `_delayed_puddle()` creates a Timer with `timer.timeout.connect(_spawn_fire_puddle.bind(pos))`. The `_spawn_fire_puddle` is an instance method — if the enemy is freed before the timer fires, it calls a method on a freed object.
**Fix:** Use a lambda that checks `is_instance_valid(self)` first, or parent the timer to the enemy (so it's freed together).

### W07: `chest.gd` deferred callback risk
**File:** `scripts/chest.gd:154`
**Issue:** `call_deferred("_generate_loot")` could fire after the chest is freed during rapid scene transitions.
**Fix:** Guard `_generate_loot()` with `if not is_inside_tree(): return` at its start.

### W08: Tween on potentially freed player
**File:** `scripts/level_up.gd:499-501`
**Issue:** `player.create_tween().set_loops()` for vine snare pulse — if player dies during level-up (shouldn't happen with pause, but edge case), the tween crashes.
**Fix:** Use `if is_instance_valid(player):` before creating tween.

### W09: `_play_attack_anim_then()` callback doesn't guard `get_parent()`
**File:** `scripts/enemy_base.gd:672`
**Issue:** `callback.call()` at line 672 fires the attack callback (e.g., `_do_shoot`, `_do_spore_burst`). Many of these callbacks call `get_parent().add_child(proj)` without guarding the parent.
**Fix:** Ensure all `_do_*` callbacks start with `var parent = get_parent(); if not parent: return`.

### W10: `intro_video.gd` unguarded await
**File:** `scripts/intro_video.gd:55`
**Issue:** `await get_tree().create_timer(0.5).timeout` without guard. Low risk since intro is stable, but violates the project pattern.
**Fix:** Add `if not is_inside_tree(): return` after.

### W11: HUD uninitialized control variables
**File:** `scripts/hud.gd:47-50`
**Issue:** `dodge_label`, `sneak_label`, `dig_label`, `collect_label` are declared but never assigned in `_build_hud()`. Any code referencing them gets null.
**Fix:** Either build these controls in `_build_hud()` or remove the variables.

### W12: `enemy_glacial_hulk.gd` lambda captures `self`
**File:** `scripts/enemy_glacial_hulk.gd:57-60`
**Issue:** `body_entered.connect()` lambda captures `self` implicitly. If glacial hulk dies while the freeze area persists, the lambda accesses a freed enemy.
**Fix:** Pass damage value as a bound parameter or check `is_instance_valid` in lambda.

### W13: Double `queue_free` risk in chest loot
**File:** `scripts/chest.gd:375-378`
**Issue:** Tween callback calls `queue_free()` after 3.5s delay. If scene changes during loot display, the scene tree frees the chest, and then the tween callback fires `queue_free()` again.
**Fix:** Guard with `if is_inside_tree():` before `queue_free()`.

### W14: `_get_pickup_container()` doesn't null-check `get_parent()`
**File:** `scripts/enemy_base.gd:~830`
**Issue:** Called from `_deferred_spawn_key()` and during loot drops. If enemy is being freed during the deferred call, `get_parent()` returns null.
**Fix:** Add null guard at start of function.

### W15: `enemy_spark_bug.gd` lightning effect without parent guard
**File:** `scripts/enemy_spark_bug.gd:61`
**Issue:** `get_parent().add_child(line)` in lightning visual without null check.
**Fix:** Add parent null check.

### W16: `enemy_crystal_colossus.gd` ground slam effect without parent guard
**File:** `scripts/enemy_crystal_colossus.gd:62`
**Issue:** `get_parent().add_child(ring)` in `_do_ground_slam()` without null check.
**Fix:** Add parent null check.

---

## INFO — Code smell, maintainability, or performance suggestion

### I01: Dead code in `audio_manager.gd`
**File:** `autoloads/audio_manager.gd:220,226`
**Issue:** `pass  # Debug removed` — leftover from print statement cleanup.
**Fix:** Remove the `pass` lines (they're unnecessary after a real statement).

### I02: Inconsistent tween creation style
**Files:** `scripts/material_pickup.gd:96`, `scripts/key_pickup.gd:106`
**Issue:** Uses `get_tree().create_tween()` instead of `create_tween()`. Both work, but inconsistent with the rest of the codebase.
**Fix:** Use `create_tween()` for consistency.

### I03: Fragile `"velocity" in player_ref` type check
**File:** `scripts/enemy_the_devourer.gd:59-60`
**Issue:** Uses `"velocity" in player_ref` to check if the player is a CharacterBody2D. Works but fragile — any node with a `velocity` property would pass.
**Fix:** Use `player_ref is CharacterBody2D` instead.

### I04: `setup_sprite_frames.gd` print statements (acceptable)
**File:** `scripts/setup_sprite_frames.gd:11,18,41,61`
**Issue:** Contains print() calls. This is a `@tool` editor-only script, so prints are expected.
**Status:** No fix needed.

### I05: Wave cache updated every frame
**File:** `autoloads/wave_manager.gd:81`
**Issue:** `_cached_enemies` array is re-allocated from group query every frame. Could use a dirty flag to only rebuild when enemies are added/removed.
**Fix:** Connect to `enemy_spawned` signal and `tree_exiting` to maintain the list incrementally.

### I06: `save_manager.gd` empty lines from print removal
**File:** `autoloads/save_manager.gd` multiple lines
**Issue:** Previous print statement removal left orphan empty lines. Cosmetic only.
**Fix:** Clean up extra blank lines.

### I07: Static typing missing in hot paths
**Files:** Most enemy scripts, player.gd
**Issue:** Variables in `_physics_process()` are untyped. Godot 4 GDScript runs 28-59% faster with static typing in tight loops (per community benchmarks).
**Fix:** Add type annotations to loop variables and function parameters in physics-heavy code.

### I08: No object pooling for projectiles
**Files:** All ranged enemies
**Issue:** Enemy projectiles are instantiated and freed hundreds of times per wave. Object pooling (hide/show + reposition) would reduce GC pressure.
**Fix:** Implement a simple projectile pool in WaveManager or a dedicated ProjectilePool autoload.

### I09: `save_manager.gd` dead code path
**File:** `autoloads/save_manager.gd:224`
**Issue:** `CraftingDB.get("recipes")` check — the `recipes` variable doesn't exist in crafting_db.gd as a property. This code path never executes.
**Fix:** Remove the dead branch.

### I10: `pass` statement from migration in `save_manager.gd`
**File:** `autoloads/save_manager.gd:66`
**Issue:** `pass  # Migrated legacy save to Profile 1` — leftover from print removal. The `pass` is needed syntactically if it's the only statement in a block, but should be verified.
**Fix:** Verify the enclosing block and remove if unnecessary.

---

## Files Audited

### Autoloads (11 files)
- game_state.gd, crafting_db.gd, stage_data.gd, orbital_db.gd, wave_manager.gd
- save_manager.gd, achievements.gd, armor_db.gd, card_db.gd, audio_manager.gd
- junkyard_state.gd (in scripts/)

### Enemy Scripts (37 files)
- enemy_base.gd + all 36 enemy type scripts

### Core Scripts (20+ files)
- arena.gd, arena_builder.gd, player.gd, hud.gd, level_up.gd, chest.gd
- destructible_prop.gd, material_pickup.gd, throwable.gd, trap.gd
- game_over.gd, main_menu.gd, base_hub.gd, pause_menu.gd, orbital_weapon.gd
- junkyard_v2.gd, junkyard_waves.gd, debug_boot.gd, secret_room.gd
- intro_video.gd, key_pickup.gd, dig_hole.gd, card_popup.gd, secret_door.gd

### Scene Files (57+ .tscn files)
- All enemy scenes, arena.tscn, player.tscn, base_hub.tscn, etc.

### Resource Files
- default_theme.tres, default_bus_layout.tres

### Config
- project.godot — all autoload paths verified, input actions checked

---

## Scene & Resource File Audit Results

All 52 .tscn files, 2 .tres files, project.godot, and export_presets.cfg were scanned.

**All clear:**
- All ext_resource script references point to existing .gd files
- All ext_resource scene references point to existing .tscn files
- All autoload paths in project.godot are valid
- All sub_resource blocks are well-formed
- Collision layers/masks are consistent
- Audio bus layout (Master + SFX/Music/UI) is properly configured
- Default theme file exists and is valid

**False positives resolved:**
- material_pickup.tscn, destructible_prop.tscn, dig_hole.tscn have no children in the .tscn file — this is intentional; their scripts build all visuals in `_ready()`
- 4 enemies lack NavigationAgent2D (crystal_bat, magma_imp, spark_bug, steam_turret) — intentional; flyers use direct movement, turret is stationary

**Minor scene issue:**
- `enemy_spore_mother.tscn` node name is "EnemysporeMother" (inconsistent capitalization) — cosmetic only, no functional impact

---

## Priority Fix Order

**Immediate (prevent crashes):**
1. Add `is_inside_tree()` guards to 6 unguarded `await` calls in arena.gd, secret_room.gd, main_menu.gd (C01-C05, C10, C12)
2. Add parent null checks to the ~39 `get_parent().add_child()` calls across 23 files (C06)
3. Add `is_instance_valid(self)` to recursive async zone functions (C07)
4. Guard `_play_attack_anim()` and `_deferred_spawn_key()` (C08, C09)
5. Use `call_deferred` for scene changes in game_over/pause_menu (C11)

**High (prevent silent bugs):**
6. Fix audio crossfade race condition (W02)
7. Fix lava_lobber timer callback (W06)
8. Guard all `_do_*` attack callbacks with parent checks (W09)

**Medium (code quality):**
9. Throttle wave cache refresh (W01/I05)
10. Fix orbital weapon pause desync (W03)
11. Add static types to hot paths (I07)
12. Implement projectile pooling (I08)
