# Scrapwright — Comprehensive Balance Audit

*Regenerated 2026-04-12 from full codebase analysis (post Apr 8 balance pass + Apr 12 QA fixes)*

---

## 1. COMBAT BALANCE

### Player Bite Attack

| Stat | Value | Source |
|------|-------|--------|
| Base Damage | 8 | player.gd |
| Base Cooldown | 0.6s | player.gd |
| Cooldown Floor | 0.18s (3.33 atk/s) | player.gd |
| Range | 80px | player.gd |
| Crit Multiplier | 1.5x | player.gd |
| Sneak Ambush | 2.0x (first hit) | player.gd |
| Bark Blast AoE | 50% splash in expanded range | player.gd |

**Damage Formula:**
1. Flat additive: `base(8) + bite_damage_level + perk_damage_bonus + armor_bonus + card_bonus + chimera_buff`
2. Multiplicative: `x sneak_ambush(2.0) x crit(1.5)`
3. No diminishing returns on flat damage stacking

**Dodge Flame Trail (NEW):** Spawns ~6 flame dots per dodge, each dealing 5 damage to enemies on contact. Total potential: ~30 bonus damage per dodge through a group.

**Mid-run realistic DPS:** ~36-54 (18 dmg x 2-3 atk/s)
**Optimized late-run spike:** 70-100 per hit with sneak + crit

### Orbital Weapons — DPS Comparison (Actual Calculated Values)

Scaling formula: `total = base + sum(increment * 0.88^(i-1))` for i in 1..level-1

| Weapon | Lv1 DPS | Lv10 DPS | Lv20 DPS | Cooldown Floor | Special |
|--------|---------|----------|----------|----------------|---------|
| **Arcane Tome** | 6.00 | 23.91 | **50.00** | 0.30s | Homing missile |
| **Spark Coil** | 7.00 | 23.91 | **46.67** | 0.30s | Lightning bolt |
| Blade Fan | 3.89* | 14.89* | 27.14* | 0.70s | AoE orbit (multi-hit) |
| Thorn Vine | 3.75* | 12.50* | 25.00* | 0.60s | Line pierce (multi-hit) |
| Chain Link | ~3.00t | ~17-19t | ~27-30t | 0.82s | Chains 2-3 targets (0.5x falloff) |
| Flame Wisp | 4.00 | 11.76 | 23.17 | 0.82s | Fire projectile |
| Shadow Dagger | 3.33 | 10.61 | 22.50 | 1.20s | Teleport burst |
| Poison Orb | 2.50 | 10.08 | 20.73 | 0.82s | 3s poison DoT |
| Frost Shard | 3.33 | 10.98 | 20.00 | 0.60s | 2s slow debuff |
| Shield Drone | 1.67 | 6.70 | 14.17 | 1.20s | +5% passive DR |
| Holy Lantern | ~1.33 | ~5.50 | ~10-12 | 1.20s | Heal + AoE damage |
| **Magnet Core** | **1.20** | **3.73** | **7.50** | 1.20s | Pull + crush |

*AoE weapons — actual DPS higher vs groups. tChain hits 2-3 targets with falloff.

**Optimal 6-weapon loadout (Lv20):** Arcane + Spark + Chain + Blade Fan + Flame + Shadow = ~197 DPS
**Worst 6-weapon loadout (Lv20):** Magnet + Shield + Holy + Frost + Poison + Thorn = ~97 DPS

#### Flags:
- OVERPOWERED: Arcane Tome (50 DPS) and Spark Coil (46.67 DPS) both hit 0.3s cooldown floor — 2x+ average
- UNDERPOWERED: Magnet Core (7.5 DPS at Lv20) — 16% of top weapon, trap pick past wave 30
- UNDERPOWERED: Shield Drone (14.17 DPS) and Holy Lantern (~10 DPS) — utility doesn't compensate for low damage

### Perk Diminishing Returns

Formula: `value_n = base x 0.7^pick_count`, hard floor per perk

| Pick # | hp_up (+25) | damage_up (+8) | speed_up (+15%) | thick_skin (+8%) |
|--------|-------------|----------------|-----------------|------------------|
| 1st | +25 HP | +8 dmg | +15% | +8% |
| 2nd | +17 HP | +5.6 dmg | +10.5% | +5.6% |
| 3rd | +12 HP | +3.9 dmg | +7.4% | +3.9% |
| 4th+ | +8 HP | +2 (floor) | +5% | +2% (floor) |

### Perk Tier List

| Tier | Perks | Why |
|------|-------|-----|
| **S** | damage_up (+8), hp_up (+25), attack_speed (-12%) | Universal scaling, huge base values |
| **A** | thick_skin (+8% DR), iron_jaws (+5% crit) | Strong survivability/damage multipliers |
| **B** | speed_up, quick_paws, bark_blast, shadow_step | Mobility/utility, not raw power |
| **C** | lucky_find, scavenger_nose, bloodlust | Situational, economy-focused |
| **D** | regen (1% HP/3s), second_wind (once per run) | Negligible healing impact |

---

## 2. ENEMY SCALING & PROGRESSION

### HP/Damage Scaling by Stage

| Stage | HP Multiplier | DMG Multiplier | Applied To |
|-------|--------------|----------------|------------|
| 1 (Scrapyard) | 1.0x | 1.0x | Native enemies |
| 2 (Fungal) | 1.4x | 1.3x | Non-native enemies |
| 3 (Molten) | 1.8x | 1.6x | Non-native enemies |
| 4 (Frozen) | 2.2x | 1.9x | Non-native enemies |
| 5 (Clockwork) | 2.6x | 2.2x | Non-native enemies |
| 6 (Abyss) | 3.0x | 2.5x | Non-native enemies |

### Wave Progression (84 Waves)

| Wave | Stage | Total Enemies | Boss | Notes |
|------|-------|---------------|------|-------|
| 1 | Scrapyard | 5 | — | Entry wave |
| 7 | Scrapyard | 41 | Scrap Sentinel | Mid-boss |
| 14 | Scrapyard | 54 | Junkyard Mech | Stage boss |
| 15 | Fungal | 9 | — | Reset (-83%) |
| 21 | Fungal | 46 | Spore Mother | Mid-boss |
| 28 | Fungal | 61 | Fungal Titan | Stage boss |
| 35 | Molten | 49 | Ember Drake | Mid-boss |
| 42 | Molten | 68 | Molten Wyrm | Stage boss |
| 49 | Frozen | 54 | Frost Warden | Mid-boss |
| 53 | Frozen | 40 | — | Flat spot (+0%) |
| 56 | Frozen | 73 | Crystal Colossus | Stage boss |
| 63 | Clockwork | 60 | Piston Crusher | Mid-boss |
| 70 | Clockwork | 79 | The Architect | Stage boss |
| 77 | Abyss | 68 | The Devourer | Mid-boss |
| 82 | Abyss | 59 | — | Flat spot (+5%) |
| 84 | Abyss | 87 | Scrap King | FINAL BOSS |

### Boss Stats

| Boss | Wave | HP | Damage | Ph3 Damage | TTK Est. |
|------|------|-----|--------|------------|----------|
| Scrap Sentinel | 7 | 700 | 18 | ~36 | 4-6s |
| Junkyard Mech | 14 | 1,000 | 25 | ~40 | 4-5s |
| Spore Mother | 21 | 900 | 15 | ~25 | 6-8s |
| Fungal Titan | 28 | 1,300 | 20 | ~32 | 8-10s |
| Ember Drake | 35 | 1,100 | 22 | ~35 | 7-9s |
| Molten Wyrm | 42 | 1,600 | 30 | ~48 | 10-12s |
| Frost Warden | 49 | 1,200 | 20 | ~32 | 8-10s |
| Crystal Colossus | 56 | 1,800 | 30 | ~48 | 11-13s |
| Piston Crusher | 63 | 1,400 | 25 | ~40 | 8-10s |
| The Architect | 70 | 2,000 | 20 | ~32 | 12-15s |
| The Devourer | 77 | 1,600 | 25 | ~40 | 9-11s |
| **Scrap King** | **84** | **2,200** | **35** | **49** | **15-18s** |

All bosses have 3 phases (transitions at ~66% and ~33% HP). Phase transitions now deferred to prevent overlap on burst damage.

---

## 3. ECONOMY & MATERIAL BALANCE

### Drop Sources

- **Enemies drop NO direct materials** — only XP orbs
- Materials come from: chests, destructible props (salvage), dig holes
- This is intentional — forces engagement with salvage mechanics

### Key Drop Rates

| Source | Bronze | Silver | Gold | Nothing |
|--------|--------|--------|------|---------|
| Normal enemy | 12% | 4% | 1.5% | 82.5% |
| Boss enemy | 15% | 8% | 4% | 73% |

### Chest Rewards

| Tier | XP | Materials | Bonus |
|------|-----|-----------|-------|
| Bronze | 15 | 2-4 basic | — |
| Silver | 30 | 3-5 mid | 15% heal, 5% blueprint |
| Gold | 60 | 4-6 all | 40% blueprint, 30% heal |
| Secret | 100 | 6-10 all | Guaranteed blueprint |

### XP Curve

Level 1-2: 100 XP. Scales at 1.4x per level.
By level 10: 1,376 XP needed. By level 15: ~5,370 XP.

---

## 4. PERMANENT UPGRADES (15 Total, 5 Categories)

### Total Cost to Max Everything

| Material | Approximate Total | Runs to Max (est.) |
|----------|------------------|--------------------|
| Iron Scrap | ~500 | 15-20 |
| Timber | ~400 | 15-20 |
| Stone | ~300 | 12-15 |
| Organic | ~300 | 12-15 |
| Fuel | ~100 | 10-15 |
| Blueprint | ~100 | 50-80 |

Blueprint remains the bottleneck resource but is less extreme than pre-Apr 8 (gold chest blueprint chance increased to 40%).

### Best Value Upgrades

1. **XP Gain (Street Smarts):** +5% per level, 10 levels = +50% total. Accelerates all progression.
2. **Bite Damage (Iron Maw):** +1 per level, 10 levels. Direct DPS increase.
3. **Max HP (Thick Hide):** +10 per level, 10 levels = +100 HP. Huge survivability.
4. **Rerolls (Old Dog Tricks):** 5 levels. Lets you fish for S-tier perks.

### Worst Value Upgrades

1. **Sharp Instincts:** 49 total materials for +1 perk choice. Only 1 level. Expensive for marginal gain.
2. **Dig Charges (Deep Digger):** 10 levels but dig holes are situational. Low combat impact.

---

## 5. DIFFICULTY CURVE FLAGS

| Issue | Severity | Details |
|-------|----------|---------|
| Waves 53 and 82 are flat spots | LOW | +0% and +5% enemy count — brief plateaus |
| Stage 1 enemies in Stage 6 get 3x HP | LOW | Can feel confusing when "basic" enemies are tanky |
| Crystal Colossus prison is a gear-check | MEDIUM | 400 HP of walls in 6s = 67 DPS needed to escape |
| Scrap King invuln phases lengthen fight | MEDIUM | Royal Decree shield + 3s stun window = ~70-80s total fight |

---

## 6. RECENT CHANGES (Apr 8-12)

### Apr 8 — Comprehensive Balance Pass
- Weapon DPS rebalanced (Shadow Dagger brought down from 122 to 22.5 DPS)
- Chest UI overhauled with key economy rebalance
- Audio overhaul (new music roster, shuffle-bag randomization)

### Apr 12 — QA Audit Fixes
- Piston Crusher HP: 1100 -> 1400 (was undertuned for wave 63)
- Boss phase transitions: deferred flag reset prevents phase 2+3 overlap
- Recursive boss tick loops converted to iterative (void_weaver, molten_wyrm, fungal_titan, spore_mother)
- Stun now pauses all boss lingering damage ticks
- Crystal Colossus prison walls cleaned up on boss death
- Flame trail dodge: ~30 bonus damage per dodge through enemy groups
- Improved dig hole visuals (layered Polygon2D with dirt particles)

---

## 7. TOP BALANCE RECOMMENDATIONS

| # | Severity | Issue | Suggested Fix |
|---|----------|-------|---------------|
| 1 | HIGH | Arcane Tome/Spark Coil 2-3x stronger than utility weapons | Increase cooldown floor from 0.3s to 0.5s |
| 2 | HIGH | Magnet Core is a trap pick (7.5 DPS at Lv20) | Increase damage to [6, 9, 15] |
| 3 | MEDIUM | Shield Drone/Holy Lantern too weak for a weapon slot | Buff damage or add scaling utility |
| 4 | MEDIUM | Regen perk is 0.33 HP/sec — effectively useless | Change to 2% HP/3s or 1.5% HP/2s |
| 5 | MEDIUM | Second Wind is unreliable (once per run, requires near-death) | Add visual/audio warning at 25% HP |
| 6 | LOW | Waves 53 and 82 are flat difficulty spots | Add 2-3 more enemies to smooth curve |
| 7 | LOW | Blueprint economy still gated (50-80 runs to max) | Consider blueprint vendor at hub |
