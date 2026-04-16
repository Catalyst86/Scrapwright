# Pass 2 — Runtime Safety & Crash Vectors

*Scrapwright audit 2026-04-16. Documentation only.*

## 2.1 Await / Timer Safety

Scanned all 37 `await get_tree().create_timer(...).timeout` call sites across 17 files.

### Good patterns (verified)

- `enemy_base.gd:957-973` — every `await` is followed by `if not is_inside_tree(): return`.
- `arena.gd:226-287` — same pattern, post-await `is_inside_tree()` guards.
- Boss scripts (`molten_wyrm`, `fungal_titan`, `crystal_colossus`, `spore_mother`, `void_weaver`, `ember_drake`) consistently guard awaits.

### Findings

**B1 (MEDIUM):** [arena.gd:253-254](scripts/arena.gd:253)
```gd
if wave_num >= GameState.total_waves:
    return
```
Early-returns the final-wave path without resetting `_wave_complete_pending`. Harmless in practice (run ends, scene is replaced) but creates a latent foot-gun if anyone later adds a re-arm path for post-wave-84 content (credits → return to hub → re-run arena same session).

**B2 (MEDIUM):** [arena.gd:226-287](scripts/arena.gd:226) — the `_on_wave_complete` state machine has 10 `return` statements across await branches. `_wave_complete_pending` is reset on 3 paths but not on 5 (lines 254, 263, 266, 269, 274, 276). Because the scene is freed on scene change, this is not an active crash, but the mix of "reset flag, then return" vs "just return" is inconsistent and will bite a future maintainer.

**B3 (MEDIUM):** [audio_manager.gd:190-210](autoloads/audio_manager.gd:190) — async music swap:
```gd
await get_tree().create_timer(0.5).timeout
if _current_music != track_name:
    return
...
_music_player = AudioStreamPlayer.new()
add_child(_music_player)
```
Autoloads are not freed, so `self` survives. But there is no `is_inside_tree()` check on `self` before `add_child`, and during shutdown `get_tree()` may be null. In normal play the `_current_music` guard catches stacked calls, but rapid scene transitions (menu ↔ hub ↔ arena in the same second) can leave tween callbacks targeting a freed AudioStreamPlayer. Downgraded from Explore's CRITICAL to MEDIUM.

**B4 (LOW):** [enemy_crystal_colossus.gd:119](scripts/enemy_crystal_colossus.gd:119), [enemy_void_weaver.gd:94](scripts/enemy_void_weaver.gd:94) — `await` followed by state access without `is_instance_valid(self)` — but these are bosses, mid-phase; they're cleared by the phase-transition flag `_phase_transitioning`. Low risk, document.

## 2.2 Null-Safety

**Coverage is generally good.** Every major touch-point (`get_tree().get_first_node_in_group("player")`, boss minion refs, orbital target cache) uses `is_instance_valid()`. Spot checks:

- [arena.gd:293](scripts/arena.gd:293) — `if not p or not is_instance_valid(p): return` ✓
- [dig_hole.gd:140](scripts/dig_hole.gd:140) — `if not is_instance_valid(body): return` ✓
- [orbital_weapon.gd:128-149](scripts/orbital_weapon.gd:128) — per-frame enemy cache refresh with validity checks ✓
- [enemy_base.gd:434,514,618](scripts/enemy_base.gd:434) — player_ref guarded ✓

### Findings

**B5 (LOW):** [game_state.gd:549-552](autoloads/game_state.gd:549) — `card_db.get_stat_bonuses()` result is not null-checked before `.get("max_hp", 0)`. Crashes if `get_stat_bonuses` ever returns `null`. Today it always returns a dict, but a refactor could regress.

**B6 (LOW):** [xp_pickup.gd:20](scripts/xp_pickup.gd:20), [material_pickup.gd:28](scripts/material_pickup.gd:28), [key_pickup.gd:28](scripts/key_pickup.gd:28), [chest.gd:62-63](scripts/chest.gd:62), [flame_trail_dot.gd:23](scripts/flame_trail_dot.gd:23), [dig_hole.gd:34](scripts/dig_hole.gd:34) — all connect `body_entered` with no "already connected" guard and no `_exit_tree` disconnect. These are child nodes of the arena; they free with the scene, so no accumulation. But if any of them is ever reparented (e.g. orb-to-chest magnet tween) the connection is now on the new parent's tree branch and could double-fire. Defensive `if not body_entered.is_connected(...)` would be cheap insurance.

## 2.3 `queue_free()` Then Use

93 `queue_free()` sites across 35 files. Spot-audited high-risk paths:

**B7 (LOW):** [audio_manager.gd:197-200](autoloads/audio_manager.gd:197)
```gd
if _music_player and is_instance_valid(_music_player):
    _music_player.stop()
    _music_player.queue_free()
    _music_player = null
```
Correct — frees and nulls. ✓

**B8 (MEDIUM):** [chest.gd:150,312](scripts/chest.gd:150) — `call_deferred("_generate_loot")` after a tween is queued. If the chest is freed (e.g. player dies while chest opens) before the deferred callback fires, Godot calls `_generate_loot` on a freed object. `_generate_loot()` itself has no early validity guard. Godot 4 will throw a "Attempt to call function on freed object" error, not crash, but it is still a stack-trace event. Add `if not is_instance_valid(self): return` inside `_generate_loot` as first line.

**B9 (LOW):** [enemy_projectile.gd:120](scripts/enemy_projectile.gd:120) — `_sfx_hit.finished.connect(_sfx_hit.queue_free)` — fine pattern, one-shot freed-after-play. ✓

## 2.4 Double-Connect / Missing Disconnect

### Verified clean

- `arena.gd` — `_on_tree_exiting`-style cleanup at [lines 102-110,343](scripts/arena.gd:102). ✓
- `base_hub.gd` — explicit slot disconnect on tab switch [lines 914-918](scripts/base_hub.gd:914). ✓
- `tutorial_arena.gd` — uses `CONNECT_ONE_SHOT`. ✓

### Findings

**B10 (MEDIUM):** [junkyard_v2.gd:129-132](scripts/junkyard_v2.gd:129)
```gd
WaveManager.wave_complete.connect(_on_wave_complete)
GameState.health_changed.connect(_on_health_changed)
if player:
    player.died.connect(_on_player_died)
```
No matching `_exit_tree` disconnects. Because the junkyard scene is typically changed via `change_scene_to_file`, nodes are freed and connections drop. But if the scene is ever re-instanced in-place (e.g. reset-without-reload), the next `_ready` re-connects and every signal fires twice. Add disconnect-on-exit like `arena.gd` does.

**B11 (MEDIUM):** [audio_manager.gd:57-78](autoloads/audio_manager.gd:57) — the AudioManager subscribes to `get_tree().node_added` and then to `pressed`/`mouse_entered` on every `Button` and `BaseButton` it sees. It guards with `is_connected(_on_button_pressed)` (line 75), so re-adding buttons is safe. But the tree subscription itself runs forever, evaluating every node ever created during the session. Over a 30-minute play session with many pickups, VFX, projectiles, etc., this is thousands of non-Button checks per second. See Pass 4 (performance) for the other side of this coin.

**B12 (LOW):** [secret_room.gd:263-265](scripts/secret_room.gd:263) — chest `body_entered` is disconnected and re-connected in a single expression:
```gd
chest.body_entered.disconnect(conn.callable)
...
chest.body_entered.connect(func(body: Node): ...)
```
Fine in the happy path, but the loop iterating connections mutates the list it's reading. Single connection today, but this will break silently if multiple callables are added.

## 2.5 Array / Dictionary Access

### Findings

**B13 (LOW):** [wave_manager.gd:131-136](autoloads/wave_manager.gd:131) — `spawn_queue[-1]` after `is_empty()`:
```gd
if spawn_queue.is_empty(): return
var enemy_type = spawn_queue[-1]
```
GDScript is single-threaded and the access is sequential with the `is_empty()` check, so the "race" the Explore agent flagged is impossible. This is **safe**; noted only to close the question.

**B14 (LOW):** Multiple `.get(key, default)` patterns checked — all use defaults. `GameState.materials.get(mat, 0)`, `GameState.keys.get(tier, 0)`, `config.get_value(..., default)` everywhere. Good.

## 2.6 Division by Zero

Every `/` operator in scaling, DPS, spawn math, and frame-count detection was spot-checked.

- [enemy_base.gd:253](scripts/enemy_base.gd:253) — `(wave - 1) / 83.0` — wave ≥ 1 always. ✓
- [enemy_base.gd:337,349](scripts/enemy_base.gd:337) — texture dim divisions guarded with explicit `<= 0` checks. ✓
- [player.gd:941](scripts/player.gd:941) — divisor clamped with `maxf(.., 1.0)`. ✓
- Cooldown floors (`0.18s`, `0.30s`, etc.) are hardcoded constants; no `/0` path.

**No division-by-zero findings.**

## 2.7 Save / Load Migration

Read [save_manager.gd:300-378](autoloads/save_manager.gd:300). Pattern is safe:
- Uses `config.has_section_key(section, key)` before loading into known keys — new keys added to `GameState.permanent` default to their in-code initialization.
- All `config.get_value(...)` calls include typed defaults.
- Armor list is filtered against `ArmorDB.DISABLED_ARMORS` so retired cosmetics don't crash the wardrobe.

### Finding

**B15 (LOW):** [save_manager.gd:316-319](autoloads/save_manager.gd:316)
```gd
var p = GameState.permanent
for key in p:
    if config.has_section_key("permanent", key):
        p[key] = config.get_value("permanent", key)
```
No type validation — if a save file is hand-edited or corrupted with a wrong type (say `"bite_damage_level": "oops"`), the int gets overwritten with a string and subsequent arithmetic (`base + bite_damage_level`) crashes. Very low likelihood, but a typed cast via `int(...)` would harden it.

**B16 (LOW):** Legacy keys (`forge_level`, `workbench_level`, `scrapheap_level`, `max_health_bonus`) remain in the permanent dict ([game_state.gd:54-62](autoloads/game_state.gd:54)) for backward-compat. They are written to disk every save; they're no longer read by any code path. Bloat, not breakage.

## 2.8 `_process` vs `_physics_process`

Scanned for `move_and_slide()` and `move_and_collide()` in `_process`. **None found.**

- Enemies use `_physics_process` for movement.
- Orbitals rotate in `_process` but do not move bodies — they use `is_on_wall`-style checks via Area2D signals.
- The navigation / physics layer is clean.

**No findings.**

## 2.9 Resource / Instance Leaks

### Findings

**B17 (LOW):** [arena.gd:1300-1387](scripts/arena.gd:1300) — Bug-swarm / Vine-snare VFX sprites are added as children of the player. If the perk is removed mid-run (not possible today) the VFX has no removal path. Low because it self-cleans on player death.

**B18 (LOW):** [arena.gd:1321-1330](scripts/arena.gd:1321) — the BugSwarm rotate timer runs forever at 0.03s while the perk is active, incrementing `swarm_spr.rotation`. No cleanup on player death (beyond scene free). Fine in practice.

**B19 (LOW):** [enemy_lava_lobber.gd:81](scripts/enemy_lava_lobber.gd:81) — `_spawn_fire_puddle.bind(pos)` timer — if lobber dies before the timer fires, the callback fires with a stale pos but the spawn creates a puddle at a freed-enemy's last known location. Functionally OK.

**B20 (MEDIUM):** Every dynamically-added `Timer` (bug_swarm, vine_snare, perk_regen, etc.) is named and re-checked via `has_node("...Timer")` before creation. Good. But none are freed if the perk is removed or re-picked with different parameters. Today perks are additive and never removed, so this is latent. Document it.

## 2.10 Findings Summary

| # | Sev | Finding (short) |
|---|-----|-----------------|
| B1 | MEDIUM | `_wave_complete_pending` not reset on final-wave early-return |
| B2 | MEDIUM | Inconsistent flag reset across 10 return branches in `_on_wave_complete` |
| B3 | MEDIUM | `audio_manager.play_music()` lacks `is_inside_tree()` after await |
| B4 | LOW | Several boss-phase `await`s trust `_phase_transitioning` only |
| B5 | LOW | `card_db.get_stat_bonuses()` result not null-checked |
| B6 | LOW | Pickup body_entered connects not guarded against double-connect |
| B7 | — | AudioManager queue_free pattern correct |
| B8 | MEDIUM | `chest._generate_loot` deferred call has no self-validity guard |
| B9 | — | enemy_projectile SFX one-shot free correct |
| B10 | MEDIUM | `junkyard_v2` connects autoload signals without disconnect |
| B11 | MEDIUM | AudioManager subscribes to every `node_added` forever |
| B12 | LOW | `secret_room` connection list mutated while iterated |
| B13 | — | `spawn_queue[-1]` safe (single-threaded) |
| B14 | — | Dict `.get()` usage safe throughout |
| B15 | LOW | Save load has no type validation per field |
| B16 | LOW | Legacy permanent keys bloat the save file |
| B17-B20 | LOW–MEDIUM | Perk-VFX and boss-puddle timers lack explicit teardown |

**Pass 2 totals:** CRITICAL 0 · HIGH 0 · MEDIUM 6 · LOW 10.

No immediate crash bugs found. Highest-priority cleanups: B3 (music race), B8 (chest deferred), B10 (junkyard signal leak), B11 (AudioManager tree listener).
