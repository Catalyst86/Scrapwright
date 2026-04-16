# Scrapwright — Fix Plan (Draft)

*All CRITICAL and HIGH findings from passes 1-6 with proposed change, risk, and test cases. **Do not execute without review.***

## Legend

- **Effort:** S (< 1 hr) · M (1-4 hrs) · L (½-1 day) · XL (multi-day)
- **Risk:** L (isolated change) · M (touches multiple callsites) · H (gameplay balance or architecture)
- **Files** are indicative; assume an Edit-pass in each.

---

## HIGH — Balance

### FP-1 — Cooldown floor on Arcane Tome & Spark Coil (C1, C2)

- **File:** `autoloads/orbital_db.gd:24, 84`
- **Change:** Raise `cooldown_floor` from `0.3` → `0.5` for both `spark_coil` and `arcane_book`. Recomputes Lv20 DPS to ~66 (down from 110), which puts them at the top of A-tier rather than dominant S-tier.
- **Risk:** M — rebalances two of the most-played weapons. Expect forum feedback but the change closes the outlier.
- **Test cases:**
  1. Spawn a dummy enemy at wave 1 and wave 60; fire level-20 Arcane Tome 10 times; verify average attack interval ≈ 0.5s.
  2. Auto-test: `OrbitalDB.get_cooldown("arcane_book", 20) == 0.5`.
  3. Run a full wave 1 with Spark Coil Lv1 — ensure cooldown is still 1.0s (base value preserved).
  4. Manual playtest: do the weapons still feel powerful but not trivial at wave 40?

### FP-2 — Magnet Core & Holy Lantern buff (C1 D-tier)

- **File:** `autoloads/orbital_db.gd:133, 145, 149`
- **Change:** 
  - `magnet_core.damage`: `[3, 5, 8]` → `[6, 9, 14]` (brings Lv20 DPS from 18 to ~34)
  - `holy_lantern.damage`: `[4, 6, 8]` → `[6, 9, 14]` (similar)
  - `holy_lantern.heal_amount`: `[5, 8, 12]` → `[6, 10, 18]`
- **Risk:** L — these weapons are trap picks today; any buff is an improvement.
- **Test cases:**
  1. Verify new Lv20 DPS (Magnet Core ≈ 34, Holy Lantern damage ≈ 34, heal ≈ 22 HP/sec at cap).
  2. Playtest with 6-Magnet loadout at wave 30 — can the player survive?

### FP-3 — Global damage-reduction cap (C6)

- **File:** `scripts/player.gd` — in the damage resolution path (`take_damage` / equivalent)
- **Change:** After summing all DR sources, `dr_total = clampf(dr_total, 0.0, 0.70)`. Preserves 70% cap so stacked defensive builds can't reduce incoming damage to zero.
- **Risk:** M — changes actual game feel at the top end. Run through wave 50+ with full DR stack to confirm damage still happens.
- **Test cases:**
  1. Equip Thick Skin (35%) + damage_reduction_level 5 (10%) + Shield Drone (5%) + armor (15%) = 65% before cap (unchanged).
  2. Same as above + a hypothetical card giving +10% = 75% clamped to 70%.
  3. Verify player still takes damage from wave-60 boss attacks.

## HIGH — Performance

### FP-4 — Cap Flame Wisp trail embers (D1)

- **File:** `scripts/orbitals/orbital_flame_wisp.gd:48-68`
- **Change:** Track a `var _ember_count := 0` outside the trail timer callback; bail if count ≥ 10. On ember `queue_free`, decrement. Alternative: increase `trail_timer.wait_time` to `0.1` (halves count).
- **Risk:** L — visual quality drop is minor; frame stability win is major.
- **Test cases:**
  1. Fire Flame Wisp at max rate, measure concurrent Polygon2D nodes in scene tree (should cap at ~10 per fireball, regardless of flight time).
  2. Frame-time sample at wave 60 with flame wisp loadout — before/after.

### FP-5 — Enemy-enemy collision mask verification (D15)

- **File:** `scenes/enemies/*.tscn` (34 scene files)
- **Change:** Open each enemy scene, set `collision_layer = 2` (enemy layer), `collision_mask = 1` (player + walls only — NOT layer 2). Confirm separation steering in `_compute_separation` still handles crowding visually.
- **Risk:** M — could introduce enemy clumping if separation radius isn't tuned.
- **Test cases:**
  1. Run wave 1-5 with 30 rushers, confirm no stacking.
  2. Frame-time sample at wave 60: measure before/after.
  3. Confirm enemy projectiles still collide correctly with the player.

### FP-6 — Batch orbital VFX into `_draw()` (D2, D13)

- **File:** `scripts/orbital_weapon.gd` and each of the 12 orbital scripts
- **Change:** Introduce `VFXDrawer` autoload with `draw_line(from, to, color, width, lifetime)` / `draw_polygon(points, color, lifetime)`. Internally accumulates draw commands and renders via a single `_draw()` on a single CanvasItem per frame. Replace Line2D.new() / Polygon2D.new() in orbitals.
- **Risk:** H — significant refactor, touches 13 files. Write new visuals alongside old, feature-flag, then migrate.
- **Test cases:**
  1. Visual parity check on all 12 weapons at Lv1, Lv10, Lv20.
  2. Frame-time sample at wave 60 — target ≥20% reduction in draw calls.
  3. No regression in VFX color, timing, fade.

### FP-7 — Populate `WaveManager._cached_enemies` pre-tick (D6)

- **File:** `autoloads/wave_manager.gd`
- **Change:** In `_spawn_enemy`, after `arena_node.add_child(enemy)` and before control returns, add `_cached_enemies.append(enemy)`. Ensures the cache is populated before the enemy's first `_physics_process`.
- **Risk:** L — one-line addition, no behavior change other than faster separation.
- **Test cases:**
  1. Log `_cached_enemies.size()` in `_compute_separation` on first tick — should equal `enemies_alive`.
  2. Frame-time sample at wave start (worst case).

### FP-8 — Pool enemy projectiles (D9)

- **File:** new `autoloads/projectile_pool.gd` + modify `scripts/enemy_shooter.gd`, `enemy_lava_lobber.gd`, `enemy_mycelium_sniper.gd`, `enemy_ice_archer.gd`, `enemy_steam_turret.gd`
- **Change:** `ProjectilePool.get()` returns a pre-allocated `enemy_projectile` instance (or instantiates if pool empty). `ProjectilePool.release(p)` resets and hides it. Replace `.instantiate()` in all 5 shooter types.
- **Risk:** M — touches 5 enemies + projectile lifecycle. Risk: stale state carryover if reset is incomplete.
- **Test cases:**
  1. Peak concurrent projectile count at wave 60 — confirm pool stable.
  2. Collision behavior unchanged (player takes damage).
  3. Visual: projectile doesn't "blink" from previous direction when reused.

## HIGH — UX & Accessibility

### FP-9 — Gamepad focus on radial upgrade wheel (E1)

- **File:** `scripts/base_hub.gd:877-920`
- **Change:** For each slot `var s = ...`:
  1. `s.focus_mode = Control.FOCUS_ALL`
  2. `s.focus_entered.connect(func(): _on_slot_focus(s))` mirroring `mouse_entered`
  3. `s.focus_exited.connect(...)` mirroring `mouse_exited`
  4. Wire `s.focus_neighbor_left`, `_right`, `_top`, `_bottom` based on radial position
  5. On tab open, `s.grab_focus()` for the first slot
- **Risk:** M — existing mouse flow must continue to work. Use a `_on_slot_activated(slot)` that both handlers call.
- **Test cases:**
  1. Unplug mouse, navigate all 5 upgrade categories by gamepad alone.
  2. Confirm tab switch re-grabs focus.
  3. Mouse flow unchanged.

### FP-10 — Rebindable movement & pause (E5)

- **File:** `autoloads/keybind_manager.gd:11-17`
- **Change:** Extend `REBINDABLE_ACTIONS` to include:
  - `"ui_up": "Move Up"`
  - `"ui_down": "Move Down"`
  - `"ui_left": "Move Left"`
  - `"ui_right": "Move Right"`
  - `"ui_cancel": "Pause / Back"`
  - And audit the rebind UI in `pause_menu.gd:620-683` to ensure these render.
- **Risk:** L
- **Test cases:**
  1. Rebind "Move Up" from W → Up arrow, verify persistence.
  2. Rebind "Pause" from ESC → P, verify both main menu and arena respect it.
  3. "Reset to defaults" restores the full set.

### FP-11 — Color-blind enemy distinction (E14)

- **File:** `scripts/enemy_base.gd` + minor shader add
- **Change:** Add an outline / silhouette tell per enemy archetype so identification doesn't rely on hue.
  - Option A: set `sprite.material` to a 1-px outline shader with a per-type outline color that contrasts deuteranopically (e.g., bright yellow outlines on rushers).
  - Option B: add a small glyph node (2-frame Sprite2D) over the enemy's head with a distinct shape per type.
- **Risk:** M — visual change, needs art direction sign-off.
- **Test cases:**
  1. Pass screenshots through a deuteranopia simulator; verify rusher ≠ spore_walker.
  2. Toggle via accessibility option (on by default, off for pure stylistic mode).
  3. Sprite draw order unchanged; outlines don't clip with UI.

### FP-12 — Modal profile-delete confirmation (E27)

- **File:** `scripts/main_menu.gd:950-998`
- **Change:** Replace the 3-second closure-state "are you sure" with a proper `AcceptDialog` or custom `ConfirmationDialog` that:
  1. Blocks other input (modal).
  2. Requires typing the profile name into a LineEdit to enable "Delete".
  3. Has an explicit Cancel.
- **Risk:** L
- **Test cases:**
  1. Delete a profile — must type exact name to enable button.
  2. Cancel on the dialog restores menu; no state leaked.
  3. Can't trigger deletion via keyboard spam.

## MEDIUM (noteworthy but lower urgency)

### FP-13 — Fix `_wave_complete_pending` reset paths (B1, B2)

- **File:** `scripts/arena.gd:226-287`
- **Change:** Wrap the function body in `try`-equivalent: set flag true at top, and use a single `_finalize_wave_complete_reset()` called in every return path (or set the flag in a `defer`-ish pattern via `_notification(NOTIFICATION_EXIT_TREE)`). At minimum, reset the flag at line 254 before `return`.
- **Risk:** L
- **Test cases:**
  1. Quit the arena mid-wave-clear banner and re-enter; next wave complete should fire.
  2. Reach wave 84 — flag should still reset if credits transition is skipped.

### FP-14 — Chest `_generate_loot` self-validity guard (B8)

- **File:** `scripts/chest.gd:140-160`
- **Change:** First line of `_generate_loot`: `if not is_instance_valid(self) or not is_inside_tree(): return`.
- **Risk:** L
- **Test cases:**
  1. Open a chest, then die in the same frame — no "called on freed object" error.

### FP-15 — Matching disconnects in `junkyard_v2` (B10)

- **File:** `scripts/junkyard_v2.gd:129-132` + add `_exit_tree`
- **Change:** Add `func _exit_tree(): WaveManager.wave_complete.disconnect(_on_wave_complete)` etc., mirroring `arena.gd:102-110`.
- **Risk:** L
- **Test cases:**
  1. Enter junkyard → return → enter arena → return → enter junkyard. No duplicate signal fires.

### FP-16 — Audio bus index → name lookup (E19)

- **File:** `scripts/pause_menu.gd:486`, `scripts/main_menu.gd:371-388`
- **Change:** Replace `AudioServer.set_bus_volume_db(0, db)` with `AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), db)`. Same for Music / SFX.
- **Risk:** L — only risk is a typo in bus name. Guard with `if idx >= 0`.

### FP-17 — Extract perk-effect install helper (A6)

- **File:** new `scripts/perk_effects.gd` (or autoload); modify `arena.gd:1300-1399`, `junkyard_v2.gd:1193-1250`, `level_up.gd:615-762`
- **Change:** Consolidate the triplicated bug_swarm / vine_snare / perk_regen install code into one function `PerkEffects.install(effect_id, host_node)`. Each of the three sites becomes a 1-line call.
- **Risk:** M — subtle behavioral differences between the three (VFX z_index, pulse tween) must be preserved or reconciled.

### FP-18 — Remove or wire `first_craft` (F5, C14)

- **File:** `autoloads/achievements.gd:34`
- **Change (recommended):** repurpose — fire `increment_stat("items_crafted", 1)` inside `base_hub.gd`'s upgrade-purchase handler (so the first upgrade counts as "first craft"). Rename the achievement desc to "Spend your first materials".
- **Risk:** L
- **Test cases:**
  1. Fresh profile → first hub upgrade → achievement unlocks.

### FP-19 — Empty `BOSS_TRACK` constant (F1)

- **File:** `autoloads/audio_manager.gd:131`
- **Change:** Either delete the constant (and the TODO comment) or commit a boss theme asset (`boss_battle.ogg`) and point it here.
- **Risk:** L

## LOW (post-release polish backlog)

| # | ID | One-liner |
|---|----|-----------|
| FP-20 | A2 | Move `JunkyardState` script under `autoloads/` for naming consistency |
| FP-21 | A3/A4 | Remove dead `phase_changed` emissions or wire HUD to it; drop `abilities_changed` from CLAUDE.md |
| FP-22 | A10 | Exclude `setup_sprite_frames.gd` from export or move to `addons/` |
| FP-23 | B15 | Add type-safe casting in `SaveManager.load_game` per-field |
| FP-24 | B16 | Remove legacy `permanent` keys (forge_level, etc.) on next save-schema version bump |
| FP-25 | C5 | Document Poison Orb %HP DoT scaling in tooltip |
| FP-26 | D10 | Enemy pooling for common types |
| FP-27 | E6 | Dynamic rebinding of pause-menu control labels |
| FP-28 | E12 | Move all hardcoded palette colors to a central theme/autoload |
| FP-29 | E22 | Add tutorial steps for orbitals, perks, chests, keys, materials |
| FP-30 | F3 | Reconcile Scrapyard vs. Steampunk Caverns in `stage_data.gd` THEMES |
| FP-31 | F4 | One-time boot-check that all 40 card PNGs load |
| FP-32 | F6 | Delete or quarantine 8 disabled armor definitions |
| FP-33 | F7 | Introduce `tr()` wrapping pass for future localization |

---

## Rollout Order (suggested)

**Sprint 1 (days):** FP-1, FP-2, FP-3, FP-4, FP-5, FP-7, FP-9, FP-10, FP-13, FP-14, FP-15. These are all low-risk single-file fixes that collectively resolve every HIGH finding.

**Sprint 2 (week):** FP-6, FP-8, FP-11, FP-12, FP-17. Refactor work — VFX pool, projectile pool, accessibility, modal dialog, perk-effect helper.

**Sprint 3 (backlog):** FP-20 through FP-33. Polish backlog, release any time.

**Before shipping:** re-run the Pass 3 balance recompute (for DPS correctness in `BALANCE_AUDIT.md`) and Pass 4 (frame time at wave 60) once FP-1 through FP-7 have landed.

---

*Stop here. Awaiting review of the fix plan before writing any code.*
