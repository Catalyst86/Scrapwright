# Scrapwright — Comprehensive Balance Audit

*Generated 2026-04-07 from full codebase analysis*

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

**Damage Formula (order of operations):**
1. Flat additive: `base(8) + bite_damage_level + perk_damage_bonus + armor_bonus + card_bonus + chimera_buff`
2. Multiplicative: `× sneak_ambush(2.0) × crit(1.5)`
3. No diminishing returns on flat damage stacking

**Mid-run realistic DPS:** ~36–54 (18 dmg × 2–3 atk/s)
**Optimized late-run spike:** 70–100 per hit with sneak + crit

### Orbital Weapons — DPS Comparison

| Weapon | Lv1 Dmg | Lv20 Dmg | Lv1 DPS | Lv20 DPS | Special Effect |
|--------|---------|----------|---------|----------|----------------|
| **Shadow Dagger** | 12 | 61 | 4.0 | **122.0** | None (pure damage) |
| **Chain Link** | 4 | 19 | 3.0 | **~106** | Chains to 6 targets (0.7x falloff) |
| Flame Wisp | 8 | 38 | 4.0 | 76.0 | Projectile |
| Blade Fan | 7 | 34 | 3.9 | 68.0 | AoE all in range |
| Shield Drone | 5 | 32 | 1.7 | 64.0 | +5% passive DR |
| Spark Coil | 6 | 29 | 5.0 | 58.0 | Single target, fast |
| Thorn Vine | 6 | 29 | 3.8 | 58.0 | Line pierce |
| Frost Shard | 5 | 28 | 3.3 | 56.0 | 2s slow (0.6x speed) |
| Arcane Book | 5 | 24 | 5.0 | 48.0 | Homing |
| Magnet Core | 3 | 22 | 1.2 | 44.0 | 25px pull + AoE |
| Holy Lantern | 4 | 19 | 1.0 | 38.0 | Heals player, 4.0s CD |
| **Poison Orb** | 3 | 14 | 1.0 | **28.0** | 3s poison (2% maxHP/tick) |

**Scaling formula:** Diminishing factor 0.88x per level, cooldown floor 0.5s

#### ⚠️ CRITICAL: Shadow Dagger is 60% above next-best (122 vs 76 DPS)
#### ⚠️ HIGH: Poison Orb at 28 DPS is 63% below median weapon
#### ⚠️ MEDIUM: Holy Lantern's 4.0s base cooldown makes it uncompetitive early

### Perk Diminishing Returns

Formula: `value_n = base × 0.7^pick_count`, hard floor per perk

| Pick # | hp_up (+25) | damage_up (+5) | speed_up (+15%) |
|--------|-------------|----------------|-----------------|
| 1st | +25 HP | +5 dmg | +15% |
| 2nd | +17 HP | +3 dmg | +10% |
| 3rd | +12 HP | +2 dmg | +7% |
| 4th | +8 HP | +1 dmg (floor) | +5% |

---

## 2. ENEMY SCALING & PROGRESSION

### Wave Scaling Formula (enemy_base.gd)

`t = (wave - 1) / 83` (0.0 at wave 1, 1.0 at wave 84)

| Stat | Formula | Wave 1 | Wave 14 | Wave 42 | Wave 84 |
|------|---------|--------|---------|---------|---------|
| HP | 1.0 + 1.5t + 3.0t² | 1.0x | 1.41x | 3.0x | 5.5x |
| Damage | 1.0 + 1.0t + 2.0t² | 1.0x | 1.2x | 2.0x | 4.0x |
| Speed | 1.0 + 0.8t (cap 1.8x) | 1.0x | 1.13x | 1.4x | 1.8x |

### All Enemy Base Stats

**Stage 1 — The Scrapyard:**

| Enemy | HP | Dmg | Speed | Special |
|-------|-----|-----|-------|---------|
| Rusher | 30 | 10 | 65 | Basic melee |
| Shooter | 22 | 14 | 38 | Ranged, 85px/s projectiles |
| Tank | 130 | 28 | 26 | Slow, heavy |
| Flyer | 18 | 8 | 78 | Ignores pathing |
| Exploder | 26 | 5 (45 explode) | 68 | Suicide bomber |

**Stage 2 — Fungal Depths:**

| Enemy | HP | Dmg | Speed | Special |
|-------|-----|-----|-------|---------|
| Spore Walker | 35 | 12 | 52 | Slow cloud on death |
| Mycelium Sniper | 20 | 18 | 30 | Lead-prediction shots |
| Fungal Brute | 160 | 32 | 22 | Spawns 2 walkers at 50% HP |

**Stage 3 — Molten Core:**

| Enemy | HP | Dmg | Speed | Special |
|-------|-----|-----|-------|---------|
| Magma Imp | 28 | 10 | 72 | Fire trail every 0.3s |
| Lava Lobber | 25 | 22 | 28 | Fire puddles on projectile landing |
| **Obsidian Golem** | **200** | 40 | 18 | 3-hit armor shield |

**Stage 4 — Frozen Caverns:**

| Enemy | HP | Dmg | Speed | Special |
|-------|-----|-----|-------|---------|
| Frost Sprite | 25 | 8 | 85 | 30% slow for 2s on hit |
| Ice Archer | 35 | 12 | 50 | Ranged |
| Glacial Hulk | 180 | 18 | 28 | Ice patches (30% slow) |
| Crystal Bat | 20 | 10 | 75 | Flying |

**Stage 5 — Clockwork Factory:**

| Enemy | HP | Dmg | Speed | Special |
|-------|-----|-----|-------|---------|
| **Gear Drone** | **15** | 6 | 90 | Fast swarm, dies instantly |
| Steam Turret | 80 | 15 | 0 | Stationary, 3 projectiles/2s |
| Brass Enforcer | 120 | 15 | 40 | 50% front shield |
| Spark Bug | 18 | 5 | 70 | 3 DPS chain within 40px |

**Stage 6 — The Abyss:**

| Enemy | HP | Dmg | Speed | Special |
|-------|-----|-----|-------|---------|
| Shadow Crawler | 40 | 12 | 60 | Teleport + 2x backstab |
| Void Weaver | 50 | 10 | 45 | Dark zones (3 DPS, 5s) |
| Abyssal Knight | 200 | 22 | 32 | 40% DR always |
| Phantom | 30 | 15 | 55 | Invisible until 50px |

### Boss Stats & Estimated Fight Duration

Assuming ~50 DPS average player at respective stage:

| Boss | Stage | HP | Est. Scaled HP | Fight Duration |
|------|-------|-----|---------------|----------------|
| Scrap Sentinel | 1 mid | 700 | 987 | ~20s |
| Junkyard Mech | 1 final | 1,000 | 1,410 | ~28s |
| Spore Mother | 2 mid | 900 | 1,269 | ~25s |
| Fungal Titan | 2 final | 1,300 | 1,833 | ~37s |
| Ember Drake | 3 mid | 1,100 | 1,551 | ~31s |
| Molten Wyrm | 3 final | 1,600 | 2,256 | ~45s |
| Frost Warden | 4 mid | 1,200 | 1,692 | ~34s |
| Crystal Colossus | 4 final | 1,800 | 2,538 | ~51s |
| Piston Crusher | 5 mid | 1,400 | 1,974 | ~39s |
| The Architect | 5 final | 2,000 | 2,820 | ~56s |
| The Devourer | 6 mid | 1,600 | 2,256 | ~45s |
| **Scrap King** | **6 final** | **3,000** | **4,230** | **~85s** |

#### ⚠️ CRITICAL: Scrap King HP (3000) is 50% higher than The Architect (2000) — fight is 85s vs ~56s
#### ⚠️ HIGH: Piston Crusher at 1400 HP is the tankiest mid-boss — 40% more than Frost Warden
#### ⚠️ HIGH: Obsidian Golem (200 HP) is tankier than some mid-bosses scaled for its wave

### Difficulty Curve Issues

| Transition | Before | After | Issue |
|-----------|--------|-------|-------|
| Stage 4→5 | Frost Sprite (25 HP, 85 spd) | Gear Drone (15 HP, 90 spd) | **Difficulty DROPS** — Stage 5 starts easier |
| Stage 5→6 | Gear Drone (15 HP) | Shadow Crawler (40 HP + teleport) | **Sharp spike** |
| All bosses | 1000→1300→1600→1800→2000 | →**3000** | Final boss **50% jump** breaks pattern |

---

## 3. ECONOMY & MATERIAL BALANCE

### Total Materials to Max All Upgrades

| Material | Total Needed | Earned/Run | Runs to Max |
|----------|-------------|-----------|-------------|
| Iron Scrap | ~1,060 | 25–40 | 26–42 |
| Timber | ~718 | 20–35 | 20–36 |
| Stone | ~250 | 15–25 | 10–17 |
| Organic | ~286 | 15–25 | 11–19 |
| Fuel | ~110 | 5–10 | 11–22 |
| **Blueprint** | **~47** | **~0.2** | **~235 runs** |

#### ⚠️ CRITICAL: Blueprint economy is catastrophically broken — 235 runs to max vs 20–40 for other mats

### Material Sources

| Source | Iron | Timber | Stone | Fuel | Organic | Blueprint |
|--------|------|--------|-------|------|---------|-----------|
| Bronze chest (2-4 items) | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ |
| Silver chest (3-5 items) | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ |
| Gold chest (4-6 items) | ✅ | ✅ | ✅ | ✅ | ✅ | 25% bonus |
| Secret chest (6-10 items) | ✅ | ✅ | ✅ | ✅ | ✅ | Guaranteed |
| Salvage props | Heavy | Heavy | Medium | Medium | Light | ❌ |

---

## 4. LOOT SYSTEM

### Key Drop Rates (post-rebalance)

| | Bronze | Silver | Gold | No Drop |
|---|--------|--------|------|---------|
| Normal enemy | 12% | 4% | 1.5% | 82.5% |
| Boss enemy | 15% | 8% | 4% | 73% |

**Per stage (348 enemies):** ~42 bronze + 14 silver + 5 gold = ~61 keys for 32 chests
**Ratio:** 1.9:1 (slightly more keys than chests — forces tier choice)

### Key Conversion Costs

| Conversion | Keys | Materials |
|-----------|------|-----------|
| Bronze → Silver | 3 bronze | 2 iron_scrap + 1 stone |
| Silver → Gold | 3 silver | 3 iron_scrap + 2 timber + 1 fuel |
| Gold → Secret | 3 gold | 5 iron_scrap + 3 stone + 1 blueprint |

### Chest Rewards

| Tier | XP | Materials | Bonus |
|------|-----|-----------|-------|
| Bronze | 15 | 2–4 basic | — |
| Silver | 30 | 3–5 mid | 15% +5 max HP |
| Gold | 60 | 4–6 all | 25% +1 blueprint, 30% +15 HP |
| Secret | 100 | 6–10 all | Guaranteed +1 blueprint |

---

## 5. PLAYER POWER CURVE

### Expected Level & Perks at Milestones

| Wave | Level | Perk Picks | Orbitals | Est. Player DPS |
|------|-------|-----------|----------|----------------|
| 1 | 1 | 0 | 0 | ~13 (bite only) |
| 14 | 5–6 | 4–5 | 1–2 | ~40–60 |
| 28 | 8–9 | 7–8 | 2–3 | ~80–120 |
| 42 | 11–12 | 10–11 | 3–4 | ~140–200 |
| 56 | 13–14 | 12–13 | 4–5 | ~200–280 |
| 70 | 15–16 | 14–15 | 5–6 | ~280–380 |
| 84 | 17–19 | 16–18 | 6 (max) | ~350–500 |

### Perk Tier List

| Tier | Perks | Why |
|------|-------|-----|
| **S** | hp_up, damage_up, xp_boost | Universally strong, scale all game |
| **A** | bark_blast, quick_paws, speed_up | Essential for late-game survival |
| **B** | thick_skin, scavenger_nose, shadow_step, iron_jaws, lucky_find | Situational value |
| **C** | regen, bloodlust, second_wind, thorns, attack_speed | Weak or niche |

#### ⚠️ MEDIUM: Thorns (+5 reflect) is essentially useless — enemies deal 10–40 dmg
#### ⚠️ MEDIUM: Regen (1% HP / 5s) is negligible by mid-game (~2 HP/s at 200 HP)

---

## 6. BIOME BALANCE

| Stage | Relative Difficulty | Issue |
|-------|-------------------|-------|
| 1 — Scrapyard | Baseline | ✅ Well-tuned |
| 2 — Fungal Depths | +20% | ✅ Smooth transition, spore clouds add complexity |
| 3 — Molten Core | +40% | ⚠️ Obsidian Golem HP outlier (200 HP regular enemy) |
| 4 — Frozen Caverns | +30% | ✅ Slow mechanics are fair, Crystal Bat swarms engaging |
| 5 — Clockwork Factory | **+10%** | ⚠️ **Easier than Stage 4** — Gear Drone 15 HP is trivial |
| 6 — The Abyss | +80% | ⚠️ Sharp spike from Stage 5, teleporting enemies + DR tanks |

#### ⚠️ HIGH: Stage 5 is easier than Stage 4 — Gear Drones (15 HP) die instantly, reducing tension

---

## 7. PACING & TIME BALANCE

### Estimated Wave Durations

| Wave Type | Enemy Count | Duration | Issue |
|-----------|-------------|----------|-------|
| Early normal (1-6) | 5–18 | 15–30s | ✅ Quick, builds momentum |
| Mid normal (8-13) | 19–38 | 30–60s | ✅ Solid pacing |
| Mid-boss (7) | 40+ enemies + boss | 60–90s | ✅ Feels climactic |
| Final boss (14) | 50+ enemies + boss | 90–120s | ⚠️ Scrap King: 120–150s |

**Total run estimate (84 waves):** 60–90 minutes
**Genre standard:** 30–60 min for survivors/bullet-heaven

#### ⚠️ MEDIUM: Full 84-wave run may be too long (60-90 min). Consider run-end at wave 42 with NG+ loop.

---

## 8. MISCELLANEOUS

### Dead Code / Unused Values
- `forge_level` (legacy system) still referenced in game_state.gd alongside new `bite_damage_level` — dual path confusion
- `perk_chest_upgrade_chance` used in chest.gd but lucky_find perk may not always set it correctly with diminishing returns

### Magic Numbers
- `0.88` diminishing factor for orbital scaling — not a named constant
- `0.7` perk diminishing factor — hardcoded in multiple places, should be `const PERK_DIMINISH = 0.7`
- Boss phase thresholds `0.66` and `0.33` identical for all 12 bosses — should vary per boss

### Race Conditions
- `materials_changed` signal can fire during combat (salvaging props), triggering chest UI refresh when no chest UI exists — **FIXED** (guard added)

---

## TOP 10 MOST IMPACTFUL BALANCE ISSUES

| # | Severity | Issue | Fix |
|---|----------|-------|-----|
| 1 | **CRITICAL** | Blueprint economy: 235 runs to max | Increase gold chest blueprint to 40%, add 5% to silver, or add blueprint vendor |
| 2 | **CRITICAL** | Shadow Dagger 122 DPS at Lv20 — 60% above next weapon | Reduce Lv20 damage from 61→40 or increase cooldown to 1.0s |
| 3 | **CRITICAL** | Scrap King HP 3000 — 50% jump over The Architect (2000) | Reduce to 2200–2400 |
| 4 | **HIGH** | Stage 5 easier than Stage 4 (Gear Drone 15 HP is trivial) | Increase Gear Drone HP to 22–25 |
| 5 | **HIGH** | Obsidian Golem 200 HP — tankier than some mid-bosses | Reduce to 140 HP |
| 6 | **HIGH** | Poison Orb 28 DPS at Lv20 — 63% below median | Increase base damage [3,4,6]→[5,7,10] or reduce cooldown |
| 7 | **HIGH** | Piston Crusher 1400 HP — 40% more than other mid-bosses | Reduce to 1100 |
| 8 | **MEDIUM** | Thorns perk (+5 reflect) is useless | Increase to 10-15 or change to % reflection |
| 9 | **MEDIUM** | Regen perk (1% HP/5s) negligible late-game | Increase to 2% or reduce interval to 3s |
| 10 | **MEDIUM** | Perk meta is "always pick hp_up/damage_up first" | Increase damage_up base to 8, raise weak perk floors |
