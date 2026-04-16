# Scrapwright Comprehensive Audit — Summary

*Audit date: 2026-04-16. Six research passes + one synthesis + one fix-plan.*

## 7.1 Finding Counts

| Pass | CRIT | HIGH | MED | LOW | Total |
|------|------|------|-----|-----|-------|
| 1 — Architecture | 0 | 0 | 4 | 7 | 11 |
| 2 — Runtime safety | 0 | 0 | 6 | 10 | 16 |
| 3 — Balance | 0 | 3 | 6 | 5 | 14 |
| 4 — Performance | 0 | 6 | 6 | 5 | 17 |
| 5 — UX / accessibility | 0 | 3 | 10 | 14 | 27 |
| 6 — Content | 0 | 0 | 3 | 5 | 8 |
| **TOTAL** | **0** | **12** | **35** | **46** | **93** |

No CRITICAL findings: there are no shipping-blocker crashes, no save corruption paths, and all content (84 waves / 6 biomes / 12 bosses) is implemented.

## 7.2 Top 10 Blockers (severity × player-visibility)

| Rank | ID | Finding | Why it ranks |
|------|----|---------|--------------|
| 1 | C1/C2 | Arcane Tome / Spark Coil ~2.2× stronger than doc claimed — 110 DPS at Lv20, 424 DPS optimal loadout | Balance trivializes the late game for any player who rolls these weapons |
| 2 | E1 | Radial upgrade wheel is mouse-only — no `focus_entered` handlers | Full gamepad lockout from the core progression loop |
| 3 | D1 | Flame Wisp trail uncapped (20 Hz × 30 Polygon2D per fireball) | Frame-time risk at wave 60+ |
| 4 | D15 | Enemy-enemy collision mask status unknown — may be O(n²) | Confirmed fix potential ~20% frame improvement if enabled and disabled |
| 5 | C9 | Blueprint grind = 77+ runs | Progression pacing — late retention risk |
| 6 | E14 | Red-green enemy color reliance | 8% of male players can't distinguish Rusher vs Spore Walker |
| 7 | E5 | Movement + pause not rebindable | Accessibility + player expectation |
| 8 | C6 | No global DR cap — 60%+ possible | Late-game trivializes damage |
| 9 | D2/D13 | Orbital VFX per-hit allocations + individual draw calls | Contributes to wave-60 frame budget pressure |
| 10 | E27 | Profile delete confirm uses 3-s closure, not modal | Risk of accidental save loss |

## 7.3 Architectural Refactors vs. Point Fixes

### Architectural refactors (XL — worth planning across multiple sessions)

1. **VFX pooling system.** Introduce a `VFXPool` autoload or `_draw`-based batched renderer. Fixes D1, D2, D3, D5, D11, D12, D13 in one stroke. Refactor touches every orbital weapon and the player bark attack. **Effort: XL.**

2. **Hub + radial wheel gamepad rewrite.** Add a `FocusableSlot` helper, restructure `base_hub.gd` to emit focus signals and manage focus neighbors explicitly. Fixes E1, E2, E3, E4. **Effort: L.**

3. **Centralized palette / theme.** Pull all hardcoded `Color(...)` constants out of seven files into a `Palette` autoload or theme resource. Fixes E12, E13 and enables E14 outline-variant work. **Effort: L.**

### Point fixes

Everything else (roughly 80 findings) is file-local and can be fixed in one sitting each.

## 7.4 Recommended Fix Order (with effort estimates)

**Effort legend:** S = < 1 hr, M = 1-4 hrs, L = half day – 1 day, XL = multi-day project.

### Release-blocker adjacent

1. Cap orbital weapon 0.3s cooldown floor to 0.5s (S) — fixes C1/C2 most cleanly.
2. Rescale Magnet Core damage and Holy Lantern heal/damage (S) — fixes D-tier outliers.
3. Add focus handlers + focus_neighbor wiring to radial wheel (M) — fixes E1.
4. Add movement (`ui_up/down/left/right`) + pause to `REBINDABLE_ACTIONS` (S) — fixes E5.
5. Cap DR stacking at 70% globally in `player.gd` damage resolution (S) — fixes C6.
6. Upgrade profile-delete to a modal confirmation dialog (M) — fixes E27.

### Performance wins (run before a public build)

7. Inspect enemy scene files for `collision_layer`/`collision_mask`; disable enemy-enemy if enabled (S) — verifies D15.
8. Cap Flame Wisp trail emitter at 10 concurrent embers (S) — fixes D1.
9. Introduce a VFXPool autoload for lines/polygons (L) — fixes D2/D13.
10. Wire perk timers to `WaveManager._cached_enemies` (S) — fixes D7.

### Quality cleanup

11. Remove or wire `first_craft` achievement (S) — fixes F5.
12. Remove `BOSS_TRACK = ""` or commit a boss theme (S) — fixes F1.
13. Add `_wave_complete_pending = false` on final-wave early-return (S) — fixes B1/B2.
14. Add `is_instance_valid(self)` guard to `chest._generate_loot` (S) — fixes B8.
15. Add matching disconnects for `junkyard_v2` signal connects (S) — fixes B10.
16. Fix `AudioServer.set_bus_volume_db(0, ...)` to look up bus by name (S) — fixes E19.
17. Enemy-type silhouette / outline differentiation for colorblind (M) — fixes E14/E15.
18. Centralize palette to theme resource (L) — fixes E12.
19. Cleanup `DISABLED_ARMORS` definitions or commit to "retired but kept" (M) — fixes F6.
20. Extract bug-swarm / vine-snare / perk-regen triplicated logic into a `PerkEffects` helper (M) — fixes A6.

### Nice-to-have polish

21-40: HUD focus styles, tooltip parity on disabled Continue, save export, tutorial coverage for orbitals/perks/chests, per-stage "first entry" music, credits transition end-to-end test, legacy `permanent` keys removal, dev-only `@tool` script excluded from export.

## 7.5 Delta vs. `BALANCE_AUDIT.md`

### What regressed (or was never right)
- **S-tier DPS understated.** Arcane/Spark Coil were reported at 50 DPS Lv20 but actual is 110 DPS. Either the prior formula was wrong or a balance change slipped in without the doc being updated. `BALANCE_AUDIT.md:37` should be corrected.
- **Optimal loadout DPS understated.** 197 DPS claimed vs. 424 DPS actual. The "optimal vs. worst" spread is wider than documented (4.4× vs. 2×).

### What improved
- **Poison Orb DoT** is working correctly — duration refreshes, damage doesn't stack, scales with enemy max HP. The April 12 fix to iterative ticks stuck. Prior audit's "DOT bug" status should be flagged resolved.
- **Boss phase transitions** deferred-flag reset works. The April 12 fix is robust under burst damage.
- **Magnet Core** flag from prior audit (7.5 DPS at Lv20) stands — but new recompute puts it at 18.3 DPS, i.e., the prior audit's formula was understating DPS of the lower tier too. Still a trap pick either way.

### New findings the prior audit didn't cover
- Damage-reduction stacking has no global cap.
- `first_craft` achievement unreachable.
- 8 armors disabled but still defined in `_armors`.
- Movement not rebindable.
- Perk-timer code is triplicated across three files.
- Credits / victory path needs end-to-end verification.

## 7.6 Release Readiness

**Verdict: Ship-capable with 4-6 weeks of polish** on this list. Today's snapshot is playable, content-complete, and does not crash. The HIGH findings are balance outliers, accessibility gaps, and performance headroom — not correctness bugs.

Highest leverage fixes before a public release:
1. Cooldown floor bump on Arcane/Spark (one line).
2. Gamepad radial wheel (half day).
3. Rebindable movement (one line).
4. VFX ember cap (two lines).
5. Enemy collision mask verification (scene check only).

Five changes, under a day of work, would remove the top blockers.
