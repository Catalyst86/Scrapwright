# Adversarial Research: Godot 4 Runtime Bugs and Edge Cases

## Key Findings Applied to This Project

### 1. Bugs That Pass Code Review But Crash at Runtime

- **Static variables persist across scene changes**: `OrbitalWeapon._shared_orbit_time` (static var) never resets between runs. Multiple instances incrementing the same static var causes acceleration.
- **await in _physics_process context**: `enemy_base.gd:_play_attack_anim()` uses await and is called from `_physics_process` → `_check_contact_damage`. While guarded, this is a known Godot anti-pattern.
- **DirAccess cannot browse .pck files**: `player.gd:203` uses `DirAccess.dir_exists_absolute()` on `res://` paths, which works in editor but fails on exported builds where assets are inside .pck.

### 2. Edge Cases Under Specific Conditions

- **Large delta values**: Window dragging on Windows freezes the game loop, causing delta spikes of 1+ seconds. Most code handles this via `move_toward()` clamping, but stuck detection timers in `enemy_base.gd` could false-positive.
- **Multiple pause sources**: Level-up, chest phase, pause menu, and junkyard all call `get_tree().paused = true/false`. Without a reference-counted pause system, unpausing from one source can unpause for all.
- **Process ordering**: Godot does not guarantee `_physics_process` order between sibling nodes. WaveManager's enemy cache refresh and enemy movement could see stale data for up to 3 frames.

### 3. Subtle GDScript Bugs

- **Multiplicative vs additive stacking**: `level_up.gd` applies speed_up as `*= 1.15` but `game_state.gd:reapply_permanent_bonuses` recalculates as `+= 0.15`. With multiple stacks, these diverge.
- **Array reference vs copy**: `GameState.materials` is a Dictionary. `_materials_at_run_start = materials.duplicate()` correctly deep-copies. `restore_wave_start` also duplicates. This is handled correctly throughout.
- **Signal emission order**: `GameState.take_damage()` emits `health_changed` synchronously. Player.take_damage() checks health_before, then calls GameState.take_damage() which resets health via `end_run()` in the `GAME_OVER` path. The pre-capture of `health_before` at `player.gd:788` correctly handles this race.

### 4. Export Bugs

- **Path case sensitivity**: All paths use lowercase with underscores. No mixed-case issues found.
- **DirAccess on res:// paths**: Confirmed issue in `player.gd:203`. ResourceLoader.exists() works on .pck, DirAccess does not.
- **Static vars not reset**: `OrbitalWeapon._shared_orbit_time` persists. Not a crash, but unexpected behavior.

### 5. Race Conditions and Timing

- **Scene transition during await**: All `await` chains have `is_inside_tree()` guards. This is correctly handled.
- **Freed node callbacks**: `tree_exiting` fires before removal, so callbacks can safely access the node. WaveManager correctly uses this pattern.
- **Double-die prevention**: All `_die()` functions check `is_dead` before proceeding. Correctly handled.

### 6. Memory Leaks

- **Lambda closures**: Boss minion spawners use lambdas in `tree_exiting.connect(func(): ...)`. These capture `WaveManager` by closure but WaveManager is an autoload, so no leak.
- **Signal connections**: `arena.gd` connects `GameState.keys_changed` and disconnects in `_end_chest_phase`. Pattern is correct but fragile.
- **Orphaned nodes**: Tween callbacks use `queue_free` which correctly removes nodes from the tree. Timer-created nodes (PerkRegenTimer, BugSwarmTimer) are parented to the arena and destroyed with it.

### 7. Player Behavior Bugs

- **Rapid input spam**: `_dodge_pressed_this_frame` and `_collect_pressed_this_frame` booleans reset every physics frame, preventing input accumulation.
- **Mashing interact during transitions**: `arena_phase == ArenaPhase.TRANSITION` guard prevents actions during scene changes.
- **Alt-F4 during save**: ConfigFile.save() is atomic on most platforms. Partial saves would fail validation on next load due to missing keys, which are handled with defaults.
