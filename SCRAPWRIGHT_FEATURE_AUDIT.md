# Scrapwright Feature Completeness Audit

**Date:** 2026-03-31
**Scope:** Every .gd script, .tscn scene, autoload, input action, signal, asset, and UI element

---

## Feature Completeness Score

| Category | Count |
|----------|-------|
| Total features found | 68 |
| Fully complete | 42 |
| Partial | 14 |
| Broken | 3 |
| Dead | 5 |
| Stubbed | 4 |
| **Overall completeness** | **62%** |

---

## Feature Inventory

### 1. Player Systems

| Feature | Status | Notes |
|---------|--------|-------|
| WASD Movement (8-dir) | COMPLETE | `_handle_movement()` reads ui_left/right/up/down, 8-dir facing, velocity-based |
| Dodge Leap (Space) | COMPLETE | Invincibility during leap, cooldown, cancels dig/collect/sneak |
| Sneak Mode (Ctrl) | COMPLETE | Ctrl hold, proportional cooldown, ambush 2x first-hit, enemies lose track |
| Dig Holes (F) | COMPLETE | Consumes dig charges, spawns DigHole trap, stuns/damages enemies |
| Collect Scrap (Shift) | COMPLETE | Channel on nearby destructible prop, calls prop.interact() |
| Manual Bark (E) | COMPLETE | Cosmetic floating text, no gameplay effect beyond flavor |
| Auto-Attack (bark) | COMPLETE | Timer-based, finds closest enemy in DetectionArea, damage + bark VFX |
| Crit System | COMPLETE | Sharp Fangs upgrade + Chimera buff, 1.5x multiplier, crit SFX |
| Player Death | COMPLETE | Death animation (spriteframes or fallback tween), transitions to game_over |
| Revival Mutation | COMPLETE | `mutation_revival` in permanent, 30% HP restore, one-use per run |
| Sprite Loading (8-dir) | COMPLETE | Loads from `player/{tier}/{anim}/{direction}/frame_###.png`, fallback to base tier |
| Armor Tiers (visual) | COMPLETE | Maps equipped_armor_visual to sprite folder tier |
| Hurt Flash | COMPLETE | Red modulate on hit, 0.15s timer reset |
| Fall Animation | COMPLETE | Used by secret_door to transition to secret_room |
| Footstep Audio | COMPLETE | AudioStreamPlayer2D, pitch variation, interval-based |
| God Mode (F1) | DEBUG | Works in arena — skips take_damage. Label "REMEMBER TO REMOVE" |
| Wave Skip (F2) | DEBUG | Shows dialog to skip to any wave. Label "REMEMBER TO REMOVE" |

### 2. Enemy Systems

| Feature | Status | Notes |
|---------|--------|-------|
| EnemyBase class | COMPLETE | 25 enemy types across 6 stages, all with unique AI |
| 5-Layer AI Steering | COMPLETE | Separation, approach angle, circling, hit retreat, stuck detection |
| Burrow-Flank System | COMPLETE | Cluster detection, sink/emerge animation, invuln underground |
| Stage Scaling | COMPLETE | HP/DMG/speed scaling per-wave + cross-stage scaling from StageData |
| Stun System | COMPLETE | `stun(duration)`, greys sprite, freezes movement |
| Status Effects | COMPLETE | `apply_status("slowed"/"poisoned")` in enemy_base, used by orbitals |
| Knockback | COMPLETE | Applied on hit, decays over time |
| Key Drops | COMPLETE | Tiered probability (bronze 30%, silver 10%, gold 4%), boss rates differ |
| Material Drops | COMPLETE | `_drop_materials()` spawns material_pickup scenes on death |
| XP Drops | COMPLETE | `GameState.gain_xp(xp_value)` on death |
| Enemy Death Anim | COMPLETE | Die spritesheet if available, fallback to shrink+fade |
| Contact Damage | COMPLETE | Timer-based cooldown, respects sneak mode |
| Boss Enemies | COMPLETE | Multi-phase (Scrap King), special attacks, health bar visible |
| Boss Spawning (minions) | COMPLETE | Junkyard Mech, Scrap King, Devourer, Spore Mother all spawn minions |
| Enemy Audio | COMPLETE | Spawn, melee, death, burrow, grunt SFX per enemy |

### 3. Wave & Combat Systems

| Feature | Status | Notes |
|---------|--------|-------|
| Wave Manager | COMPLETE | Queue-based spawning, 84 authored waves across 6 stages |
| Wave Completion | COMPLETE | Detects 0 enemies + empty queue, 3s safety timeout |
| Boss Waves | COMPLETE | Waves 7 and 14 per stage, special music, double chest rewards |
| Stage Transitions | COMPLETE | Every 14 waves changes arena theme via ArenaBuilder |
| Arena Builder | COMPLETE | Runtime floor/wall/nav generation, themed per stage |
| Spawn Points | COMPLETE | 8 points around arena perimeter |
| Destructible Props | COMPLETE | Crate/barrel/rubble/corpse, interact() for materials, card drops |
| Prep Phase | PARTIAL | `_start_prep_phase()` exists but immediately calls `_start_combat()` — prep is skipped |
| Stage Banners | COMPLETE | Shows stage name on first wave, "WAVE X" on each wave |
| All Waves Complete | COMPLETE | runs_completed++, transitions to base_hub with "RUN COMPLETE!" |

### 4. Chest & Key System

| Feature | Status | Notes |
|---------|--------|-------|
| Key Collection | COMPLETE | Enemies drop keys, magnet pickup, GameState tracking |
| Key Combining | COMPLETE | 3 bronze = 1 silver, 3 silver = 1 gold, UI in chest overlay |
| Chest Phase (Arena) | COMPLETE | Full-screen overlay with animated chests, key selection, loot display |
| Chest Loot Generation | COMPLETE | Tier-based rewards: materials, XP, max HP, permanent upgrades, orbitals |
| Chest Spritesheet Anim | COMPLETE | 9-frame idle/open animation from sheet |
| Standalone Chest (chest.gd) | PARTIAL | Full implementation but only used in secret_room, NOT in arena chest phase (arena has its own inline chest system) |
| Secret Door | COMPLETE | Spawns after boss waves if player has secret keys |
| Secret Room | COMPLETE | Separate scene with chests, returns to arena via fall animation |

### 5. Progression Systems

| Feature | Status | Notes |
|---------|--------|-------|
| XP & Leveling | COMPLETE | XP bar, 1.4x scaling per level, level-up triggers perk selection |
| Level-Up Perks | COMPLETE | 6 base perks + card deck bonuses, reroll system, orbital weapon choices |
| Permanent Upgrades (New) | COMPLETE | 16 upgrade types in UpgradeDB, purchased at base hub |
| Permanent Upgrades (Legacy) | DEAD | forge_level, workbench_level, etc. still in GameState but superseded by new system. Gold chest loot still upgrades these legacy keys. |
| Prestige Currency | COMPLETE | prestige_currency in permanent, earned system unclear |
| Mutations | COMPLETE | Revival, Feral Howl (wave-start stun), Junkyard Chimera (random buff) |
| Card Collection | COMPLETE | Cards drop from destructible props, CardDB tracks, deck bonuses (HP, damage, bug_swarm, vine_snare) |
| Achievements | PARTIAL | 16 achievements defined, check functions exist, toast UI works. But `check_building_achievements()` is never called, and `achievement_unlocked` signal is never connected. |
| Save/Load | COMPLETE | Profile-based (4 slots), materials, upgrades, armor, cards, junkyard scores |

### 6. Crafting System

| Feature | Status | Notes |
|---------|--------|-------|
| CraftingDB | STUBBED | File exists (53 lines) but `recipes` dict is empty. `unlock_recipe()` is a no-op `pass`. |
| Quick Craft | DEAD | Referenced in debug_boot.gd but `scenes/quick_craft.tscn` does NOT exist |
| Throwables | DEAD | Referenced in debug_boot.gd but `scenes/throwable.tscn` does NOT exist. No throwable system in code. |
| Traps | DEAD | Referenced in debug_boot.gd but `scenes/trap.tscn` does NOT exist. `trap_definitions` in CraftingDB is empty. DigHole is the only working "trap". |
| Salvage Window | STUBBED | Script exists (280 lines) but `start_salvage()`, `try_collect()`, `force_end()` are never called. `salvage_complete` signal is never connected. Scene exists but is never instanced. |

### 7. Orbital Weapon System

| Feature | Status | Notes |
|---------|--------|-------|
| OrbitalDB (12 weapons) | COMPLETE | Stats, scaling, descriptions for all 12 orbitals |
| OrbitalWeapon base class | COMPLETE | Orbit positioning, targeting, firing, visual effects |
| All 12 orbital scripts | COMPLETE | spark_coil, frost_shard, blade_fan, shield_drone, magnet_core, chain_link, holy_lantern, poison_orb, thorn_vine, arcane_book, flame_wisp, shadow_dagger |
| Orbital acquisition | COMPLETE | Via level-up perks and chest drops |
| Orbital leveling | COMPLETE | Level up on duplicate acquisition, visual upgrade milestones |
| Orbital persistence | COMPLETE | Saved in GameState.orbital_weapons, restored on scene change |

### 8. Armor System

| Feature | Status | Notes |
|---------|--------|-------|
| ArmorDB | COMPLETE | 10 armors defined with stats, rarity, unlock conditions |
| Armor Stat Application | COMPLETE | Applied in start_new_run() — HP, speed, damage, regen, XP |
| Armor Visual Mapping | COMPLETE | Maps armor ID to sprite tier folder |
| Armor Equip UI | COMPLETE | In base_hub.gd under wardrobe/collection tab |
| Armor Unlock | PARTIAL | `get_unlocked_armors()`, `get_armors_by_rarity()`, `get_rarity_color()` exist in ArmorDB but are never called |

### 9. Junkyard Mode

| Feature | Status | Notes |
|---------|--------|-------|
| JunkyardState (autoload) | COMPLETE | Snapshot/restore run state, scrap tracking, high scores |
| Junkyard Arena (junkyard_v2.gd) | COMPLETE | 2880x1620 arena with props, sinkholes, shader ground |
| Junkyard Waves | COMPLETE | Procedural endless waves, 7 tiers, boss every 10 waves |
| Junkyard Entry/Exit | COMPLETE | From base hub, preserves main run state |

### 10. UI Systems

| Feature | Status | Notes |
|---------|--------|-------|
| HUD | COMPLETE | Health bar, XP bar, wave counter, enemy count, ability indicators, stage banner |
| Main Menu | COMPLETE | Profile selection, continue/new run, junkyard, settings, credits |
| Base Hub | COMPLETE | Tab system: upgrades, cards, prestige, archive. Material/key display. |
| Game Over Screen | COMPLETE | Death stats, return to hub, floating ember particles |
| Pause Menu | COMPLETE | Resume, save, options, return to hub, quit. Inventory display. Controls reference. |
| Card Popup | COMPLETE | Shows collected card with animation |
| Level-Up Screen | COMPLETE | Perk card selection with animations, reroll |
| Intro Video | COMPLETE | Tween-based intro sequence, skip on input |
| Settings (Volume) | COMPLETE | Music/SFX sliders in pause menu and main menu |
| Fullscreen Toggle | COMPLETE | In pause menu options |

### 11. Audio System

| Feature | Status | Notes |
|---------|--------|-------|
| AudioManager (autoload) | COMPLETE | SFX registry, music system, bus controls |
| Music Tracks | COMPLETE | Stage-specific intros, battle/hub/menu pools, boss music |
| SFX Registry | COMPLETE | 30+ named sounds for UI, combat, environment, orbitals |
| Player Audio | COMPLETE | Footstep, bark, crit, dodge, dig, salvage, sneak, hurt |
| Enemy Audio | COMPLETE | Spawn, melee, death, burrow, per-type grunt |
| Button Auto-Sounds | COMPLETE | AudioManager detects button focus/press for UI sounds |

### 12. Scene Flow

| Feature | Status | Notes |
|---------|--------|-------|
| intro_video -> main_menu | COMPLETE | Auto-transition after animation or skip |
| main_menu -> base_hub | COMPLETE | New run or continue |
| base_hub -> arena | COMPLETE | "Enter the Arena" button |
| arena -> base_hub | COMPLETE | After boss waves (7, 14) |
| arena -> game_over | COMPLETE | On player death |
| game_over -> base_hub | COMPLETE | "Return to Den" button |
| arena -> arena (next wave) | COMPLETE | After chest phase |
| base_hub -> junkyard | COMPLETE | Junkyard mode entry |
| junkyard -> base_hub | COMPLETE | Return with materials |
| arena -> secret_room | COMPLETE | Via secret door after boss wave |
| secret_room -> arena | COMPLETE | Fall animation back |

---

## Disconnected Chains

### 1. Crafting System (FULLY DISCONNECTED)
- **Chain:** Player collects materials -> opens crafting UI -> selects recipe -> spends materials -> gets item
- **Break:** `CraftingDB.recipes` is empty. `scenes/quick_craft.tscn` does not exist. No recipe data, no crafting UI, no crafting flow. The entire "Scrapwright" core mechanic is absent.
- **Impact:** HIGH - The game's name is "Scrapwright" (craft + wright) and materials are collected but have no crafting use beyond base hub upgrades.

### 2. Throwable System (FULLY DISCONNECTED)
- **Chain:** Player crafts throwables -> equips them -> throws during combat
- **Break:** `scenes/throwable.tscn` does not exist. `GameState` has no throwable tracking. No throw input action. The throwable items in `assets/sprites/items/` (throwing_knife, molotov, pipe_bomb, boomerang) are orphaned.
- **Impact:** HIGH - Listed as a core mechanic in CLAUDE.md but entirely absent from code.

### 3. Trap Placement System (FULLY DISCONNECTED)
- **Chain:** Player crafts traps -> places during prep -> enemies walk into traps
- **Break:** `scenes/trap.tscn` does not exist. `CraftingDB.trap_definitions` is empty. The only trap is DigHole (puppy ability), not a crafted item. Trap sprites exist but are orphaned.
- **Impact:** MEDIUM - Prep phase skips directly to combat, no trap placement opportunity.

### 4. Salvage Window (DISCONNECTED)
- **Chain:** After wave clear -> salvage window opens -> player harvests props -> timer expires -> returns
- **Break:** `salvage_window.gd` exists with full logic but `start_salvage()` is never called. The signal `salvage_complete` has no connections. The scene is never instanced by arena or junkyard.
- **Impact:** MEDIUM - The between-wave salvage phase from CLAUDE.md doesn't exist. Scrap collection only happens during combat via Shift key.

### 5. Prep Phase (STUBBED)
- **Chain:** Wave ends -> 8s prep timer -> player places traps -> combat starts
- **Break:** `_start_prep_phase()` immediately calls `_start_combat()`. No prep timer, no trap UI.
- **Impact:** LOW - Would matter more if traps existed.

### 6. Legacy Permanent Upgrades vs Gold Chest Loot
- **Chain:** Gold chest -> random permanent upgrade -> applies on next run
- **Break:** Gold chests upgrade legacy keys (`forge_level`, `workbench_level`, etc.) which are partially superseded by the new upgrade system. `forge_level` fallback to `bite_damage_level` works, but `workbench_level`, `garden_level`, `armory_level`, `scrapheap_level` from chest loot have NO effect in the new system.
- **Impact:** MEDIUM - Player gets "Upgrade: Garden Level!" from gold chests but it does nothing.

### 7. Achievement Building Checks
- **Chain:** Player upgrades buildings -> achievement checks fire -> unlock
- **Break:** `check_building_achievements()` exists in achievements.gd but is never called from anywhere.
- **Impact:** LOW - Building-related achievements can never unlock.

### 8. `perk_chosen` Signal (DISCONNECTED)
- **Chain:** Player selects perk -> signal emitted -> external systems react
- **Break:** `perk_chosen` signal in level_up.gd is emitted but nothing connects to it. Perk application happens internally so this is cosmetic, but any system listening for perk events (analytics, achievements) gets nothing.

---

## Orphaned Assets

### Scenes That Don't Exist (Referenced in Code)
| Reference | Where | Status |
|-----------|-------|--------|
| `scenes/throwable.tscn` | debug_boot.gd:79 | PHANTOM - file does not exist |
| `scenes/quick_craft.tscn` | debug_boot.gd:82 | PHANTOM - file does not exist |
| `scenes/trap.tscn` | debug_boot.gd:85 | PHANTOM - file does not exist |

### Orphan PNG Files (Never Referenced)
| Folder | Count | Examples |
|--------|-------|---------|
| `assets/sprites/base/` | ~32 | base_hub_bg.png, computer_active.png, vault_*.png, toolbox_*.png, scrapwright_npc.png |
| `assets/sprites/environment/` | ~20 | debris_*.png, junk_border_pile_*.png, junk_car_*.png |
| `assets/sprites/hub_ui/` | ~10 | button_gray.png, category_node_frame.png, upgrade_card_frame.png |
| `assets/sprites/items/` | ~11 | item_throwing_knife.png, item_molotov.png, item_pipe_bomb.png, item_boomerang.png, mat_*.png (old versions), salvage_tool_pickaxe.png |
| `assets/sprites/traps/` | 3 | trap_spikes.png, trap_fire.png, trap_electric.png |
| `assets/sprites/ui/` | 2 | ui_heart.png, ui_bag.png (superseded by icon_heart.png, icon_bag.png) |
| `assets/sprites/junkyard_map/` | ~5 | Entire folder unused |

### Unused Input Actions (Defined in project.godot)
| Action | Key | Issue |
|--------|-----|-------|
| `sneak` | Left Shift | Player sneak uses raw `Input.is_key_pressed(KEY_CTRL)` instead of this action |
| `collect` | Tab | Player collect uses raw keycode check for KEY_SHIFT instead of this action |

---

## Dead Code

### Functions Never Called
| Function | File | Line |
|----------|------|------|
| `unlock_recipe()` | crafting_db.gd | 38 |
| `_build_border_layer_back()` | junkyard_v2.gd | 524 |
| `_build_border_layer_front()` | junkyard_v2.gd | 695 |
| `_build_border_layer_main()` | junkyard_v2.gd | 611 |
| `_cost_to_str()` | base_hub.gd | 1382 |
| `_show_bolt()` | orbital_weapon.gd | 501 |
| `check_building_achievements()` | achievements.gd | 130 |
| `force_end()` | salvage_window.gd | 277 |
| `get_armors_by_rarity()` | armor_db.gd | 142 |
| `get_occupied_slots()` | save_manager.gd | 93 |
| `get_progress()` | achievements.gd | 74 |
| `get_rarity_color()` | armor_db.gd | 150 |
| `get_total_count()` | achievements.gd | 92 |
| `get_total_keys()` | game_state.gd | 296 |
| `get_unlocked_armors()` | armor_db.gd | 124 |
| `get_unlocked_count()` | achievements.gd | 89 |
| `get_unlocked_perks()` | card_db.gd | 118 |
| `is_enemy_native_to_stage()` | stage_data.gd | 371 |
| `show_pickup_float()` | hud.gd | 395 |
| `spend_material()` | game_state.gd | 191 |
| `start_salvage()` | salvage_window.gd | 239 |
| `try_collect()` | salvage_window.gd | 258 |

### Signals Emitted But Never Connected
| Signal | File | Emitted At |
|--------|------|------------|
| `wave_started` | wave_manager.gd | Lines 128, 212 |
| `enemy_spawned` | wave_manager.gd | Line 169 |
| `profile_changed` | save_manager.gd | Line 146 |
| `achievement_unlocked` | achievements.gd | Line 67 |
| `card_collected` (GameState) | game_state.gd | Line 13 (emitted by destructible_prop) |
| `chest_opened` | chest.gd | Line 382 |
| `salvage_complete` | salvage_window.gd | Line 274 |
| `perk_chosen` | level_up.gd | Line 448 |
| `door_used` | secret_door.gd | Line 183 |
| `resumed` | pause_menu.gd | Line 44 |

### Empty Functions
| Function | File | Notes |
|----------|------|-------|
| `_ready()` | game_state.gd:171 | Just `pass` |
| `_ready()` | wave_manager.gd:78 | Just `pass` |
| `_process()` | hud.gd:65 | Just `pass` |
| `unlock_recipe()` | crafting_db.gd:38 | Comment says "no-op with empty recipes" |

### Duplicate Signal Declaration
`card_collected` is declared on both `GameState` (line 13) and `CardDB` (line 3). Both are emitted. The GameState one is emitted by destructible_prop.gd but never connected.

---

## Stub/TODO Inventory

| Feature | File | Current State | What's Missing |
|---------|------|---------------|----------------|
| Crafting Recipes | crafting_db.gd | `recipes = {}` | Entire recipe database, crafting UI, crafting logic |
| Trap Definitions | crafting_db.gd | `trap_definitions = {}` | Trap types, placement, trap scene |
| Salvage Window | salvage_window.gd | Full script, never called | Integration into arena flow (post-wave) |
| Prep Phase | arena.gd | `_start_prep_phase()` -> immediate `_start_combat()` | Timer, trap placement UI, prep-specific gameplay |

---

## Integration Gaps

### Systems That Should Talk But Don't

1. **Crafting <-> Materials**: Materials are collected extensively (enemies, props, chests) but the crafting system that would consume them is empty. Materials only serve the base hub upgrade system.

2. **Throwables <-> Combat**: CLAUDE.md describes throwable weapons as core combat, but no throwable system exists. The player only auto-attacks via barking.

3. **Traps <-> Prep Phase**: Both are stubbed. Traps don't exist, prep phase is skipped.

4. **Gold Chest Upgrades <-> New Upgrade System**: Gold chests award legacy upgrade keys (`workbench_level`, `garden_level`, `scrapheap_level`) that have NO effect in the current system. Only `forge_level` maps to `bite_damage_level` as a fallback.

5. **Achievement Building Checks <-> Base Hub**: Building/upgrade achievements exist but `check_building_achievements()` is never called when upgrades are purchased.

6. **Salvage Window <-> Arena Flow**: The salvage window has a complete implementation but is never integrated into the post-wave flow. The CLAUDE.md describes a 90s salvage phase that doesn't happen.

### Self-Contained Systems (By Design)
- **AudioManager**: Correct — called by everything, depends on nothing
- **StageData**: Correct — pure data, queried by wave_manager and arena
- **OrbitalDB**: Correct — pure data, queried by orbital_weapon.gd

### Input Action Mismatch
The `sneak` and `collect` input actions in project.godot are bypassed. Player.gd checks raw keycodes (`KEY_CTRL` for sneak, `KEY_SHIFT` for collect) instead of using the input map. This means:
- Remapping controls via Godot's input map won't work for sneak/collect
- The `sneak` action is bound to Left Shift but sneak actually uses Ctrl
- The `collect` action is bound to Tab but collect actually uses Shift

---

## Feature Integration Map

```
                    SaveManager
                        |
                   GameState ──────────────── Achievements
                   /   |   \                      |
                  /    |    \                (never calls check_building)
            Player  Arena  BaseHub
             |  \     |      |
         Orbitals \  Waves  UpgradeDB
             |     \  |      |
         OrbitalDB  HUD   ArmorDB
                    |
              LevelUp ── CardDB
                    |
              PauseMenu
                    |
              AudioManager (used by everything)

DISCONNECTED:
  CraftingDB ──X──> (empty recipes, no consumers)
  SalvageWindow ──X──> (never instanced)
  Throwable system ──X──> (doesn't exist)
  Trap system ──X──> (doesn't exist)

WEAKLY CONNECTED:
  Gold chest loot ~~> legacy permanent keys (partial effect)
  Input actions (sneak/collect) ~~> raw keycodes (bypassed)
```

---

## Recommended Priority List

### Top 10 Fixes by Player Impact

1. **Gold Chest Legacy Upgrades Do Nothing** (BROKEN)
   Gold chests award `workbench_level`, `garden_level`, `scrapheap_level` which have zero gameplay effect. Either remove these from the gold chest loot pool or map them to new-system equivalents.

2. **Input Action Mismatch** (BROKEN)
   `sneak` action = Left Shift in project.godot, but code uses `KEY_CTRL`. `collect` action = Tab, but code uses `KEY_SHIFT`. The pause menu "Controls" panel tells players wrong keys if it reads from actions.

3. **Remove Debug God Mode / Wave Skip** (BROKEN for release)
   F1 god mode and F2 wave skip are still active in arena.gd with "REMEMBER TO REMOVE" comments.

4. **Salvage Window Integration** (PARTIAL - High Value)
   The salvage window is fully coded but disconnected. Wiring it into the post-wave flow would add a complete gameplay phase with minimal new code.

5. **Wire `check_building_achievements()`** (PARTIAL)
   Add a call to `Achievements.check_building_achievements()` in base_hub.gd after any upgrade purchase. Currently building achievements can never unlock.

6. **Clean Up Orphaned Assets** (~80 PNGs)
   Remove unused sprites in `base/`, `environment/`, `hub_ui/`, `items/`, `traps/`, `ui/` to reduce project size and confusion.

7. **Fix Input Action Definitions**
   Either use the `sneak`/`collect` input actions in player.gd (recommended) or remove them from project.godot. Current state is misleading.

8. **Prep Phase Timer** (STUBBED)
   Even without trap placement, a brief 3-5s prep timer before each wave would let players reposition and read the arena.

9. **Remove Dead Signals** (10 signals)
   Clean up the 10 emitted-but-never-connected signals to prevent confusion during future development.

10. **Crafting System Decision** (STUBBED)
    The core "Scrapwright" mechanic (crafting) doesn't exist. Either implement basic recipes using the existing CraftingDB infrastructure or rename/rebrand if crafting is no longer planned.

---

## Debug Items to Remove Before Release

| Item | File | Line |
|------|------|------|
| God Mode toggle (F1) | arena.gd | 96 |
| God Mode check | player.gd | 791 |
| Wave Skip dialog (F2) | arena.gd | 101 |
| `_god_mode` variable | arena.gd | (used by player.gd check) |

---

## Summary

Scrapwright has a **strong combat core** — player movement, 35 enemy types, 12 orbital weapons, 84 authored waves, chest/key system, progression, and save/load are all fully wired. The **disconnected systems** are concentrated in the original CLAUDE.md design: throwables, crafting, traps, salvage window, and prep phase. The game has evolved from a "craftsman throws weapons" concept to a "puppy barks at enemies" survivors game, but the old infrastructure (CraftingDB, throwable references, trap sprites) remains as dead weight. The most impactful quick fixes are the gold chest loot bug, input action mismatch, and debug mode removal.
