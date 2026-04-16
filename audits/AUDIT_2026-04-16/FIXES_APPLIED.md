# Scrapwright — Fixes Applied (2026-04-16)

Follow-up to `FIX_PLAN.md`. Implemented in one pass after review.

## Applied (27 items)

| FP | Area | File(s) | Summary |
|----|------|---------|---------|
| 1 | Balance | `autoloads/orbital_db.gd` | Spark Coil + Arcane Tome `cooldown_floor` 0.3 → 0.5 (Lv20 DPS 110 → ~66) |
| 2 | Balance | `autoloads/orbital_db.gd` | Magnet Core damage [3,5,8] → [6,9,14]; Holy Lantern damage [4,6,8] → [6,9,14] and heal_amount [5,8,12] → [6,10,18] |
| 3 | Balance | `autoloads/game_state.gd` | Global DR cap lowered from 75% → 70% |
| 4 | Performance | `scripts/orbitals/orbital_flame_wisp.gd` | Trail embers capped at 10 concurrent; trail tick slowed 0.05s → 0.08s |
| 5 | Performance | (no change needed) | Verified every enemy scene uses `collision_mask = 5`; enemy-enemy collision is already disabled |
| 6 | Performance | `autoloads/vfx_pool.gd` (new) + `project.godot` + `scripts/orbital_weapon.gd` | New `VFXPool` autoload for Line2D/Polygon2D reuse. Migrated `_show_lightning` and `_show_ice_spike` to the pool; also trimmed ice shard count 3 → 2 and frost particles 5 → 3 |
| 7 | Performance | `autoloads/wave_manager.gd` | Append newly-spawned enemies to `_cached_enemies` immediately so the first physics tick hits the cache |
| 9 | UX | `scripts/base_hub.gd` | Added `focus_entered` / `focus_exited` handlers to every upgrade slot; wired `focus_neighbor_*` for gamepad D-pad nav; auto-`grab_focus` on DEN UPGRADES tab; added keyboard-Enter / gamepad-A activation |
| 10 | UX | `autoloads/keybind_manager.gd` | Extended `REBINDABLE_ACTIONS` with `ui_up/down/left/right` (movement) and `ui_cancel` (pause) |
| 11 | Accessibility | `scripts/enemy_base.gd` | Added `_add_archetype_glyph()` — deuteranopia-safe yellow shapes above each enemy (triangle / diamond / square / invtri / circle / hex) keyed by combat role |
| 12 | UX | `scripts/main_menu.gd` | Profile-delete dialog now requires typing the exact profile name into a LineEdit to enable DELETE; modal background eats clicks |
| 13 | Safety | `scripts/arena.gd` | `_wave_complete_pending` reset on every early-return branch of `_on_wave_complete` |
| 14 | Safety | `scripts/chest.gd` | `_generate_loot` adds `is_instance_valid(self)` guard for deferred fire |
| 15 | Safety | `scripts/junkyard_v2.gd` | Added `tree_exiting` handler that disconnects WaveManager, GameState, and player signals |
| 16 | UX | `scripts/pause_menu.gd`, `scripts/main_menu.gd` | Volume sliders now look up Master bus by name (`AudioServer.get_bus_index("Master")`) instead of index 0 |
| 17 | Hygiene | `scripts/perk_effects.gd` (new) + `scripts/arena.gd` + `scripts/level_up.gd` | Extracted bug_swarm / vine_snare / perk_regen install into shared `PerkEffects` class. Replaced ~180 lines of triplicated code with 3-line delegations. (Junkyard left intact — its enemies use different `speed` attribute.) |
| 18 | Content | `scripts/base_hub.gd`, `autoloads/achievements.gd` | First hub upgrade now also increments `items_crafted`; achievement description updated |
| 19 | Content | `autoloads/audio_manager.gd` | Removed `BOSS_TRACK = ""` constant and the branch that used it; boss waves now pick directly from the combat pool |
| 20 | Hygiene | moved `scripts/junkyard_state.gd` → `autoloads/junkyard_state.gd`; updated `project.godot` autoload path |
| 21 | Hygiene | `autoloads/game_state.gd` | Removed unused `phase_changed` signal + its emit call |
| 22 | Hygiene | `export_presets.cfg` | Added `scripts/setup_sprite_frames.gd` to `exclude_filter` for every export preset |
| 23 | Safety | `autoloads/save_manager.gd` | Permanent keys now loaded via `int(raw)` with type guard — hand-edited saves can't poison the dict with a string |
| 24 | Content | — | **Deferred.** Removing legacy permanent keys (forge_level, workbench_level, etc.) breaks in-code fallbacks at 9+ call sites. Requires coordinated save-schema bump |
| 25 | Content | `autoloads/orbital_db.gd` | Poison Orb description updated to note the 2% max-HP DoT scaling |
| 26 | Performance | — | **Deferred.** Enemy pooling is a large refactor crossing 34 scenes; skipped in this pass |
| 27 | UX | `scripts/pause_menu.gd` | Control-hint labels now read live bindings via `KeybindManager.get_key_name(action)` so rebinds reflect immediately |
| 28 | Polish | — | **Deferred.** Central palette theme touches 7+ files; cosmetic only |
| 29 | Content | — | **Deferred.** Adding orbital/perks/chest tutorial steps is content work |
| 30 | Hygiene | `autoloads/stage_data.gd` | THEMES[0] name renamed from "Steampunk Caverns" → "The Scrapyard" to match STAGE_NAMES |
| 31 | Content | `autoloads/card_db.gd` | New `_verify_card_assets()` warns at boot if any card PNG is missing |
| 32 | Hygiene | `autoloads/armor_db.gd` | Quarantine comment added to the 8 disabled-armor definitions (removal would cascade into boss drops + sprite scale tables) |
| 33 | Content | — | **Deferred.** `tr()` wrapping is a localization infra pass |

## Deferred (6 items, with rationale)

| FP | Why deferred |
|----|--------------|
| 8 | Projectile pool requires resetting `enemy_projectile.gd` sprite children per type. 10+ enemy scripts call `instantiate()` with varied setup. Risky without runtime testing |
| 24 | Legacy permanent keys are still read as fallbacks in 9 places. Removing them = coordinated save-schema version bump |
| 26 | Enemy pooling is XL. Decreasing wave-start spike is nice-to-have, not release-blocking |
| 28 | Central palette: large mechanical refactor across 7+ files; no user-visible behavior change today |
| 29 | Tutorial steps for orbitals / perks / chests require new authored content (art, copy, trigger flow) |
| 33 | `tr()` wrapping requires a translation pipeline. English-only release unaffected |

## Per-file Change Log

### New files
- `autoloads/vfx_pool.gd` — Line2D/Polygon2D pool autoload (FP-6)
- `scripts/perk_effects.gd` — shared perk timer installer (FP-17)

### Moved files
- `scripts/junkyard_state.gd` → `autoloads/junkyard_state.gd` (FP-20)

### Modified files
- `project.godot` — VFXPool autoload + JunkyardState path
- `export_presets.cfg` — exclude editor script
- `autoloads/orbital_db.gd` — FP-1, FP-2, FP-25
- `autoloads/game_state.gd` — FP-3, FP-21
- `autoloads/keybind_manager.gd` — FP-10
- `autoloads/wave_manager.gd` — FP-7
- `autoloads/save_manager.gd` — FP-23 (×2 call sites)
- `autoloads/audio_manager.gd` — FP-19
- `autoloads/achievements.gd` — FP-18 (desc update)
- `autoloads/card_db.gd` — FP-31
- `autoloads/armor_db.gd` — FP-32 (comment)
- `autoloads/stage_data.gd` — FP-30
- `scripts/base_hub.gd` — FP-9, FP-18 (first_craft wire)
- `scripts/arena.gd` — FP-13, FP-17
- `scripts/chest.gd` — FP-14
- `scripts/junkyard_v2.gd` — FP-15
- `scripts/level_up.gd` — FP-17 (regen / bug_swarm / vine_snare replacements; removed `regen_timer` field)
- `scripts/main_menu.gd` — FP-12, FP-16
- `scripts/pause_menu.gd` — FP-16, FP-27
- `scripts/enemy_base.gd` — FP-11 (archetype glyph)
- `scripts/orbital_weapon.gd` — FP-6 (lightning, ice spike → pooled)
- `scripts/orbitals/orbital_flame_wisp.gd` — FP-4

## Not Done But Also Not in Plan

- The architectural A1 finding (4 scripts >1000 LOC) is structural — file splits were out of scope.
- A11 (`BOSS_TRACK` empty string) resolved by FP-19 (same issue).
- F2 (per-stage "first entry" tracks) left as TODO in `audio_manager.gd` — content gap.

## Testing Notes

Not run in this session. Suggested quick smoke tests before merging:

1. **Balance:** Level-20 Arcane Tome should fire every 0.5s (was 0.3s). Magnet Core should deal ~34 DPS, not 18.
2. **Focus on radial wheel:** Gamepad D-pad should traverse all 5 slots; A-button opens the detail panel.
3. **Rebinding:** Rebind "Move Up" from W → Up arrow in pause menu. Restart run; the control summary should read "↑" instead of "WASD".
4. **Profile delete:** Type a wrong name — DELETE button stays disabled. Type the exact profile name — DELETE enables.
5. **Enemy glyphs:** Each enemy archetype should show a distinct yellow shape above its sprite.
6. **Perk refactor:** Pick the Critter deck bonus (bug_swarm). Nearby enemies should take 3 dmg/sec. Re-enter arena from hub (boss wave) — perk should persist via `_restore_card_perks`.
7. **VFX pool:** Spark Coil at wave 60 should still visually pop the same way, with less GC churn. Verify via debugger if feasible.
8. **Cache pre-tick:** Wave start at wave 60+ should not show a visible FPS dip; enemy separation should feel identical.
9. **first_craft achievement:** Fresh profile → purchase any hub upgrade → achievement unlocks.
10. **Master volume:** Slider value maps to `AudioServer.get_bus_index("Master")`. Re-check no NaN if "Master" bus is somehow missing (defaults to 0).

## Reverts / Corrections vs. Plan

- **FP-32 (disabled armor defs)** was reframed from "delete" to "documented quarantine" after discovering 8 armors are still referenced by boss-drop tables and player sprite-scale config. Mechanical deletion would cascade; commented the intent instead.
- **FP-3 (DR cap)** already had a 75% cap in-code that the audit didn't catch — applied the proposed 70% tightening.
- **FP-14 (chest guard)** the chest's `_generate_loot` already had `if not is_inside_tree(): return` — added `is_instance_valid(self)` alongside for belt-and-braces.

## Sprint Status

- **Sprint 1 (FP-1..19):** 14 / 14 done.
- **Sprint 2 (FP-6/8/11/12/17):** 4 / 5 done (FP-8 deferred).
- **Sprint 3 polish (FP-20..33):** 9 / 14 done, 5 deferred.
- **Net:** 27 fixes applied, 6 deferred with rationale.
