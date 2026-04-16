# Pass 3 — Balance Regression Check

*Scrapwright audit 2026-04-16. Extends and re-verifies `BALANCE_AUDIT.md`.*

## 3.1 Orbital DPS — Recomputed from Code

All figures below computed directly from [autoloads/orbital_db.gd](autoloads/orbital_db.gd) using the documented formula `total = base + Σ(increment × 0.88^(i-1))` for `i = 1..level-1`, with `cooldown_floor` enforced.

Sanity: for level=20, `Σ 0.88^i for i=0..18 ≈ 7.599`.

| Weapon | Lv1 dmg / cd | Lv20 dmg | Lv20 cd (floor) | **Lv20 DPS** |
|--------|--------------|----------|-----------------|--------------|
| Spark Coil | 7 / 1.0s | 7 + 3.5·7.599 ≈ **33** | **0.30s (floored)** | **110.0** |
| Arcane Tome | 6 / 1.0s | 6 + 3.5·7.599 ≈ **33** | **0.30s (floored)** | **110.0** |
| Blade Fan | 7 / 1.8s | 7 + 3.5·7.599 ≈ **34** | **0.70s (floored)** | **48.6** (multi-hit higher vs groups) |
| Flame Wisp | 8 / 2.0s | 8 + 4·7.599 ≈ **38** | **0.70s (floored)** | **54.3** |
| Frost Shard | 5 / 1.5s | 5 + 3·7.599 ≈ **28** | **0.60s (floored)** | **46.7** + slow utility |
| Thorn Vine | 6 / 1.6s | 6 + 3·7.599 ≈ **29** | **0.60s (floored)** | **48.3** (pierce) |
| Poison Orb | 5 / 2.0s | 5 + 3.5·7.599 ≈ **32** | **0.60s (floored)** | **53.3** (plus 2% HP/tick DoT) |
| Chain Link | 4 / 2.0s | 4 + 2·7.599 ≈ **19** | **0.70s (floored)** | **27.1** × chain factor |
| Shadow Dagger | 10 / 3.0s | 10 + 5·7.599 ≈ **48** | **1.00s (floored)** | **48.0** |
| Shield Drone | 5 / 3.0s | 5 + 3.5·7.599 ≈ **32** | **1.00s (floored)** | **32.0** + 5% DR |
| Holy Lantern | 4 / 3.0s | 4 + 2·7.599 ≈ **19** | **1.00s (floored)** | **19.0** + small heal |
| Magnet Core | 3 / 2.5s | 3 + 2.5·7.599 ≈ **22** | **1.20s (floored)** | **18.3** + pull |

### Finding C1 (HIGH — delta vs prior audit)

**Prior `BALANCE_AUDIT.md:35-48` lists Lv20 DPS for Arcane Tome at 50.00 and Spark Coil at 46.67.** Recomputed from current `orbital_db.gd` those are actually **~110 DPS each** (damage 33 / cooldown 0.3s). Either:
- the prior audit used an outdated formula (likely — it assumed damage growth without the 0.88 geometric increments), OR
- the balance pass on April 8 made the weapons even stronger than the audit reported.

Either way, S-tier is **more broken than the doc claims**. Recalibrating the rest of the tiers around this correction:

| Tier | Weapon | Lv20 DPS | Why |
|------|--------|----------|-----|
| **S** | Arcane Tome | 110 | Homing, floored at 0.3s, auto-hit |
| **S** | Spark Coil | 110 | Instant, floored at 0.3s, single target |
| **A** | Flame Wisp | 54 | Projectile, 0.5s flight but good range |
| **A** | Poison Orb | 53 + HP-scaling DoT | DoT scales naturally |
| **A** | Blade Fan | 49 base, 80-100 in groups | AoE orbit, best vs swarms |
| **A** | Thorn Vine | 48 | Line pierce, consistent |
| **A** | Shadow Dagger | 48 | Teleport burst, utility for repositioning |
| **B** | Frost Shard | 47 + slow | Slow is good on bosses |
| **B** | Shield Drone | 32 + 5% DR | DR is valuable with low HP builds |
| **C** | Chain Link | 27 × chain factor | Capped at 3 chains, damage falloff 0.5× |
| **D** | Holy Lantern | 19 + tiny heal | Heal at Lv20 ≈ 1.5% HP/2s |
| **D** | Magnet Core | 18 + pull | Pull is rarely useful once weapons out-range |

### Finding C2 (HIGH, stacking)

With the S-tier re-scored, the **best-case 6-weapon loadout** is now ≈ **110 + 110 + 54 + 53 + 49 + 48 = 424 DPS** (vs. the 197 DPS reported in `BALANCE_AUDIT.md:52`). Worst-case remains ≈ 97 DPS. The spread is **4.4x**, not 2x — deeper than the doc acknowledges.

## 3.2 Player Bite Re-Verification

From [player.gd](scripts/player.gd):
- Base damage: 8, cooldown 0.6s, range 80.
- `perk_damage_bonus + bite_damage_level + armor_bonus + card_bonus + chimera_buff` all stack flat-additive.
- Crit is additive across Iron Jaws perk, Sharp Fangs permanent, Chimera. Correct.
- Cooldown floor: 0.18s.

**Mid-run realistic DPS (conservative):** `(8 + 4 perk dmg + 2 card) / 0.5s CD = 28 DPS`. With occasional crits and sneak ambush, **30-38 DPS typical**. `BALANCE_AUDIT.md:28` cited 36-54 — still roughly correct, but upper bound only reached with full stacking.

**Finding C3 (LOW):** `BALANCE_AUDIT.md:28` mid-run DPS of 36-54 is optimistic; 28-38 is closer without sneak/crit luck.

## 3.3 Poison Orb DOT

Read [orbital_poison_orb.gd](scripts/orbitals/orbital_poison_orb.gd) and `enemy_base.gd` poison handling.

- `_fire()` applies `weapon_damage` immediately + `apply_status("poisoned", 3.0)`.
- Enemy `_apply_poisoned` (enemy_base.gd):
  - If already poisoned, **refreshes duration** but does NOT stack damage. Single-instance DoT.
  - 6 ticks of `max(2, 2% of max_health)` over 3s.
- The DoT scales with enemy max HP — naturally tracks stage multipliers.

**Finding C4 (MEDIUM, regression resolved):** The previously-flagged Poison Orb DOT bug **is not present in current code**. DoT applies correctly, refreshes don't stack. Update `BALANCE_AUDIT.md` to note it's fixed / not a bug in this snapshot.

**Finding C5 (MEDIUM, hidden strength):** Because the DoT scales with enemy max HP (% based), Poison Orb's effective DPS on late-stage enemies (2.2x-3x HP) is much higher than a flat-DoT would be. A wave-60 basic enemy (e.g., 3x HP = 90 HP) takes 2% × 90 = 1.8 per tick × 6 = 10.8 bonus damage per application. Across ~3 applications during a 10-second engagement, that's +30 DPS on top of the 53 base — pushing Poison Orb toward S-tier in the late game. Document this in-line.

## 3.4 Stat Stacking — Linear vs Multiplicative

| Stat | Sources | Stacking rule | Correct? |
|------|---------|---------------|----------|
| Flat damage | base + bite_damage_level + perk_damage_bonus + armor + card + chimera | Additive | ✓ |
| Crit chance | Iron Jaws perk (+5%) + Sharp Fangs (+3%/lvl, max 15%) + Chimera | Additive | ✓ |
| Attack-speed CD | perk (×0.88^n) × attack_speed_level (×0.95 per) × armor mult | Multiplicative | ✓ |
| HP | base + hp_up perk(s) × DR + max_hp_level + armor + card + chimera | Additive | ✓ |
| Move speed | base × perk_speed × armor × quick_paws | Multiplicative | ✓ |
| Damage reduction | thick_skin perk + damage_reduction_level + shield_drone(5%) + armor | Additive with 35% cap on thick_skin | Mixed — see C6 |
| Magnet range | scavenger_nose perk + pickup_magnet_level + armor | Additive | ✓ |

### Finding C6 (MEDIUM, DR stacking)

Damage reduction stacks additively across sources: `perk_damage_reduction + (damage_reduction_level × 2%) + shield_drone(5%) + armor_dr`. With Thick Skin perk stacked to 35%, damage_reduction_level 5 (10%), Shield Drone (5%), and a heavy armor (up to 10%), total DR can reach **60%** — a massive survivability jump. There is no global DR cap. At late game with defensive builds, damage becomes trivially absorbable.

## 3.5 Enemy Scaling Curve

Verified [stage_data.gd](autoloads/stage_data.gd) and [enemy_base.gd:253](scripts/enemy_base.gd:253) `wave_hp_mult = 1.0 + t·1.5 + t²·3.0` for `t = (wave-1)/83`.

- Wave 14 multiplier: **1.40x**
- Wave 42 multiplier: **3.00x**
- Wave 84 multiplier: **5.50x**

Cliffs: all cliffs >2x HP occur at boss waves (7, 14, 21, 28, 35, 42, 49, 56, 63, 70, 77, 84). All bosses are implemented in code.

### Finding C7 (LOW, flat spots)

Waves 53 (+0%) and 82 (+5%) confirmed flat per `BALANCE_AUDIT.md:202`. Still present in current wave tables. Downgrade from prior audit's LOW to LOW (unchanged).

### Finding C8 (LOW, stage reset)

Wave 15 HP is ~40% of wave 14 (intentional stage-1 → stage-2 mercy). Documented as intentional. No action.

## 3.6 Boss Fights

All 12 bosses present and HP matches `BALANCE_AUDIT.md:121-132`. Phase-transition deferral (Apr 12 fix) verified in [enemy_base.gd:780-794](scripts/enemy_base.gd:780) — the `_phase_transitioning` flag is gated behind `get_tree().process_frame.connect(..., CONNECT_ONE_SHOT)` so burst damage through both thresholds triggers phases sequentially.

**No boss encounters are placeholders.** Every boss script implements at least 2 custom abilities.

## 3.7 Drop Rates & Rewards

Verified by explore pass:
- Normal enemy keys: 12% bronze / 4% silver / 1.5% gold ✓
- Boss keys: 15% / 8% / 4% ✓
- Bronze / Silver / Gold / Secret chest contents match `BALANCE_AUDIT.md:154-160`.
- Gold chest blueprint chance is **40%** as documented.

### Finding C9 (HIGH — economy math):

Blueprints needed to max **all 15 permanent upgrades**: **77 blueprints total** (verified against `upgrade_db.gd` cost arrays).

Expected blueprint yield per run:
- 7-8 chests/run on average
- Assume roughly: 50% bronze (0 bp), 30% silver (0.05 avg), 15% gold (0.40 avg), 5% secret (1.0 guaranteed)
- Per-run yield ≈ 8 × (0.3·0.05 + 0.15·0.40 + 0.05·1.0) = 8 × 0.125 = **1.0 blueprint / run**

**Runs to max everything: ~77 runs.** `BALANCE_AUDIT.md:180` said 50-80. Close but the low end of the range is aspirational — assumes lucky_find perk pushing all chests up a tier, which itself requires a perk slot. A realistic "first playthrough to fully maxed" path is closer to **80-100 runs**.

### Finding C10 (LOW — dead roll):

Early runs return iron_scrap / timber / stone from bronze chests when those materials aren't yet gated. No dead rolls exist — all six materials feed permanent upgrades — but a player who ignores the material economy for 20 runs can accumulate 200+ iron_scrap while blueprint remains the bottleneck. Consider a material→blueprint conversion at the hub, or a soft cap with overflow.

## 3.8 XP Curve

Level ramp is `100 × 1.4^(level-1)`. By level 10 that's 1,376 XP to level; cumulative ≈ 6,957. `BALANCE_AUDIT.md:163-164` matches.

### Finding C11 (LOW):

By-wave level estimates assume ~6-8 XP per kill. At 40 kills/wave this is ≈ 260 XP/wave. Level 10 hit around wave 20 typically; level 15 around wave 50. Matches pace; no regression.

## 3.9 Perks

`BALANCE_AUDIT.md:64-79` perk tiers & diminishing returns (0.7x per pick) verified in code ([level_up.gd](scripts/level_up.gd)). Floors enforced. No regressions.

### Finding C12 (MEDIUM, perk coverage)

Confirmed that when all 6 orbital slots are filled, the level-up UI correctly suppresses "new weapon" cards and only offers upgrade cards. [level_up.gd](scripts/level_up.gd) pool-selection logic checks `GameState.orbital_weapons.size() >= OrbitalDB.MAX_ORBITALS`.

However: if fewer than 3 available perk options exist (e.g., all orbitals maxed + limited stat perks available), the UI can present duplicate cards or empty slots. Audit didn't find this crash, but it's worth running a stress test at wave 70+ with a full loadout to confirm.

## 3.10 Achievements Count

`CLAUDE.md:45` says "16 achievements". Code has **20**:
- Combat: 5 (first_blood, century, thousand_bones, untouchable, boss_slayer)
- Progression: 5 (baby_steps, halfway_there, the_end, repeat_offender, veteran)
- Collection: 5 (key_collector, golden_touch, secret_finder, hoarder, full_inventory)
- Base Building: 4 (home_improvement, master_builder, fully_upgraded, first_craft)
- Misc: 1 (puppy_power)

### Finding C13 (LOW, doc drift)

Docs say 16, code has 20. Trivial.

### Finding C14 (MEDIUM, dead achievement)

Correction on review: `master_builder` and `fully_upgraded` ARE properly wired via [achievements.gd:111-139](autoloads/achievements.gd:111) `check_building_achievements()`, which is called from [base_hub.gd:1154](scripts/base_hub.gd:1154). The function checks the **new** `permanent[*_level]` keys with correct caps. ✓

Still dead: **`first_craft`** requires `stats["items_crafted"] >= 1`. No code anywhere in the codebase calls `Achievements.increment_stat("items_crafted", ...)`. The `CraftingDB` autoload is present but no crafting UI or craft event fires. Achievement is unreachable. Either remove it or wire a craft event (e.g., on first permanent upgrade purchase, treat that as "crafting").

## 3.11 Pass 3 Findings Summary

| # | Severity | Finding |
|---|----------|---------|
| C1 | HIGH | Lv20 DPS for Arcane/Spark is ~110, not 50 — `BALANCE_AUDIT.md:37` is wrong or stale |
| C2 | HIGH | Optimal 6-weapon loadout is ~424 DPS, worst ~97. 4.4x spread |
| C3 | LOW | Bite mid-run DPS is 28-38, not 36-54 as doc claims |
| C4 | MEDIUM | Poison Orb DoT works correctly (previous bug resolved) |
| C5 | MEDIUM | Poison Orb's % HP DoT scales into S-tier late game |
| C6 | MEDIUM | DR stacking has no global cap — 60%+ possible with full defensive build |
| C7 | LOW | Flat wave spots at 53 & 82 still present |
| C8 | — | Stage reset at wave 15 intentional |
| C9 | HIGH | Blueprint grind: ~77-100 runs to max everything |
| C10 | LOW | No material→blueprint conversion; material overflow possible |
| C11 | — | XP curve pace matches doc |
| C12 | MEDIUM | Edge case: extremely late-game level-up UI may present duplicate perks |
| C13 | LOW | Docs drift: 16 achievements claimed, 20 in code |
| C14 | MEDIUM | 1 achievement (`first_craft`) is unreachable — no `items_crafted` increment path |

**Pass 3 totals:** CRITICAL 0 · HIGH 3 · MEDIUM 6 · LOW 5.

### Delta vs `BALANCE_AUDIT.md`

| Delta | Change |
|-------|--------|
| S-tier DPS underreported | Arcane / Spark actually **~2.2× stronger** than doc said |
| Optimal loadout underreported | **424 DPS** vs doc's 197 |
| Poison Orb "bug" | **Resolved** — doc should be updated |
| Magnet Core | Confirmed weakest (18 DPS) — doc was right |
| New: dead achievement | `first_craft` unreachable (no items_crafted increment) |
| New: DR stacking cap absent | Late-game defensive builds trivialize damage |
