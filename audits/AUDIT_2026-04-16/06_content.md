# Pass 6 — Content Completeness

*Scrapwright audit 2026-04-16. Findings only. Scope check against 84-wave / 6-biome / 12-boss plan.*

## 6.1 Waves & Biomes

### Stage 1 (Scrapyard, waves 1–14)
- 14 waves present in `stage_data.gd` STAGE_1_WAVES. No empty waves.
- Native enemies present: rusher, shooter, tank, flyer, exploder. All have script + scene + `ENEMY_SCENES` registration.
- Bosses: scrap_sentinel (w7), junkyard_mech (w14) — both have `_on_phase_change` with 2+ abilities per phase.

### Stage 2 (Fungal Depths, waves 15–28)
- 14 waves; natives: spore_walker, mycelium_sniper, fungal_brute — complete.
- Bosses: spore_mother (w21), fungal_titan (w28) — implemented.

### Stage 3 (Molten Core, waves 29–42)
- 14 waves; natives: magma_imp, lava_lobber, obsidian_golem — complete.
- Bosses: ember_drake (w35), molten_wyrm (w42) — implemented with recursive ticks converted to iterative (per Apr 12 note).

### Stage 4 (Frozen Caverns, waves 43–56)
- 14 waves; natives: frost_sprite, ice_archer, glacial_hulk, crystal_bat — complete.
- Bosses: frost_warden (w49), crystal_colossus (w56) — prison cleanup on death confirmed (Apr 12 fix).

### Stage 5 (Clockwork Factory, waves 57–70)
- 14 waves; natives: gear_drone, steam_turret, brass_enforcer, spark_bug — complete.
- Bosses: piston_crusher (w63, HP corrected to 1400 in Apr 12 pass), the_architect (w70).

### Stage 6 (The Abyss, waves 71–84)
- 14 waves; natives: shadow_crawler, void_weaver, abyssal_knight, phantom — complete.
- Bosses: the_devourer (w77), scrap_king (w84) — final boss with Royal Decree shield / stun window.

**Total: 84 waves, 12 bosses — no placeholders, no missing encounters.**

## 6.2 Music

[audio_manager.gd](autoloads/audio_manager.gd) inventory:
- Hub: `hub_song_1.ogg`, `hub_song_2.ogg` (shuffle-bag pool) ✓
- Menu: `main_menu_song.ogg` ✓
- Arena combat: 16-track battle pool (aluminum_thunder, arcade_iron, metal_01-08, pixel_guillotine, pixel_iron_heartbeat, etc.) ✓
- Victory: `victory_theme.ogg` ✓
- Game over: `game_over.ogg` ✓

### Finding F1 (MEDIUM, content gap)

[audio_manager.gd:131](autoloads/audio_manager.gd:131) — `const BOSS_TRACK = ""`. Boss waves use the regular combat pool. A dedicated boss theme is authored content that never shipped. Decision needed: either record/license boss music or remove the constant.

### Finding F2 (LOW, content gap)

[audio_manager.gd:102](autoloads/audio_manager.gd:102) — per-stage "first entry" tracks are TODO'd and not present. Stage transitions currently use the same combat pool. Minor polish item.

## 6.3 Stage Names & Banners

[stage_data.gd](autoloads/stage_data.gd) STAGE_NAMES display names are all present and match `CLAUDE.md` and `BALANCE_AUDIT.md`.

### Finding F3 (LOW, theme/display drift)

A theme list in [stage_data.gd:228](autoloads/stage_data.gd:228) references "Steampunk Caverns" while the display name in STAGE_NAMES is "The Scrapyard". Not player-facing (the display name wins), but worth cleaning up.

## 6.4 Cards

Verified [card_db.gd](autoloads/card_db.gd):
- 4 decks (Scrap, Lost, Critter, Overgrowth) × 10 cards each = 40 cards ✓
- Each card has unique id, name, and a formatted icon path (`assets/sprites/cards/{deck}/{deck}_{item}.png`).
- Drop source: destructible prop `card_dropped` signal + level-up card perks for deck bonuses.
- Deck completion bonuses wired: Scrap → +25 HP, Lost → +10 dmg, Critter → bug_swarm perk, Overgrowth → vine_snare perk. Verified at [game_state.gd:404-406](autoloads/game_state.gd:404).

### Finding F4 (LOW, asset verification)

Sub-agent reported all 40 card PNGs exist in `assets/sprites/cards/`. Spot-checking the naming convention would be prudent — if a file is missing, the card icon renders as Godot's default magenta-checker. Add a unit test or one-time sanity check.

## 6.5 Chests

[chest.gd](scripts/chest.gd):
- BASIC_MATS: 3 materials (iron_scrap, timber, stone) ✓
- MID_MATS: 5 materials ✓
- ALL_MATS: 6 materials (inc. blueprint) ✓
- Orbital drop rates (bronze 0%, silver 5%, gold 15%, secret 30%) match doc.
- Heal and blueprint chances match `BALANCE_AUDIT.md:154-160`.

**No empty chest pools.**

## 6.6 Achievements Wiring — Re-verified

20 achievements defined in [achievements.gd:8-38](autoloads/achievements.gd:8). Wiring check:

| ID | Trigger | Status |
|----|---------|--------|
| first_blood | stat `total_kills` incremented in enemy death | ✓ |
| century | `kills_this_run` incremented | ✓ |
| thousand_bones | `total_kills` incremented | ✓ |
| untouchable | [arena.gd:246](scripts/arena.gd:246) | ✓ |
| boss_slayer | [enemy_base.gd:923](scripts/enemy_base.gd:923) | ✓ |
| baby_steps / halfway_there / the_end | [arena.gd:239-243](scripts/arena.gd:239) | ✓ |
| repeat_offender / veteran | `runs_completed` incremented on death/victory | ✓ |
| key_collector | `total_keys` incremented in key pickup | ✓ |
| golden_touch | [game_state.gd:292](autoloads/game_state.gd:292) on gold key collect | ✓ |
| secret_finder | [game_state.gd:294](autoloads/game_state.gd:294) on secret key collect | ✓ |
| hoarder | [achievements.gd:94-98](autoloads/achievements.gd:94) via `check_material_achievements()`, called from `game_state.gd:223` | ✓ |
| full_inventory | Same as above | ✓ |
| home_improvement | `buildings_upgraded` incremented in [base_hub.gd:1153](scripts/base_hub.gd:1153) | ✓ |
| master_builder / fully_upgraded | [achievements.gd:111-139](autoloads/achievements.gd:111) `check_building_achievements()` called from [base_hub.gd:1154](scripts/base_hub.gd:1154) — now tests new `*_level` keys | ✓ |
| **first_craft** | Requires `items_crafted >= 1` — **no code anywhere increments this stat** | **UNREACHABLE** |
| puppy_power | Player level ≥ 10 — check in `game_state.gd` | ✓ |

### Finding F5 (MEDIUM, dead achievement)

`first_craft` is unreachable. Either:
- Remove the achievement.
- Repurpose: fire on first material-spend in an upgrade (treat upgrade as "crafting").
- Implement a real crafting UI using `CraftingDB`.

## 6.7 Orbital Weapons

12 definitions in [orbital_db.gd](autoloads/orbital_db.gd); 12 scripts in [scripts/orbitals/](scripts/orbitals/). Perfect 1:1 mapping. Weapons acquired via level-up rolls; handled in [level_up.gd](scripts/level_up.gd).

**No orphan weapon scripts. No missing weapon implementations.**

## 6.8 Armor

[armor_db.gd](autoloads/armor_db.gd) — 18 armor definitions.

### Finding F6 (MEDIUM, config bloat)

Eight armors are in `DISABLED_ARMORS` list but still fully defined in `_armors` dict: `iron_mail`, `rusty_plate`, `crystal_vest`, `scrap_shield`, `fungal_hide`, `steam_harness`, `junkyard_crown`, `obsidian_shell`. `get_all_armors()` filters them out, but their definitions, icons, and unlock paths remain in code. If a future unlock path references them directly, they bypass the filter. Either delete the definitions or keep them with an explicit "hidden but not removed" pattern.

Armor icon coverage: `assets/sprites/armor_icons/` has 18 PNGs per the agent pass — 1:1 with defined armors. ✓

## 6.9 Localization

**No `tr()` or `TranslationServer` usage anywhere** in the codebase. Every user-facing string is hardcoded English:
- "WAVE CLEAR!", "YOU DIED", "BARK!", "WOOF!", "RETURNING TO DEN...", etc.
- Stage names, perk names, card names, chest tier names — all inline.

### Finding F7 (LOW, localization readiness)

For an English-only launch this is fine, but a later localization pass will require rewriting every `.text = "..."` assignment in scripts. Adding a thin `tr()` wrapper now would be cheap and not block release.

## 6.10 UI Screens

| Screen | Scene | Script | Status |
|--------|-------|--------|--------|
| Intro | `intro_video.tscn` | `intro_video.gd` | ✓ |
| Main menu | `main_menu.tscn` | `main_menu.gd` | ✓ |
| Base hub | `base_hub.tscn` | `base_hub.gd` | ✓ |
| Arena | `arena.tscn` | `arena.gd` | ✓ |
| Level-up | `level_up.tscn` | `level_up.gd` | ✓ |
| Game over | `game_over.tscn` | `game_over.gd` | ✓ |
| Credits | `credits.tscn` | `credits.gd` | ✓ |
| Chest | `chest.tscn` | `chest.gd` | ✓ |
| Secret room | `secret_room.tscn` | `secret_room.gd` | ✓ |
| Card popup | `card_popup.tscn` | `card_popup.gd` | ✓ |
| Pause menu | (overlay) | `pause_menu.gd` | ✓ |
| Tutorial arena | `tutorial_arena.tscn` | `tutorial_arena.gd` | ✓ |
| Junkyard (v2) | `junkyard.tscn` | `junkyard_v2.gd` | ✓ |

No missing UI screens. Settings UI lives inside `pause_menu.gd` and `main_menu.gd` (options popup) rather than a dedicated scene — by design.

### Finding F8 (LOW, credits path)

Confirmed: [arena.gd:1219-1221](scripts/arena.gd:1219) path switches to credits.tscn on wave-84 victory. Worth running end-to-end once to confirm the transition lands correctly with a 2.5s delay ahead of it.

## 6.11 Destructible Props

Card drops come from `destructible_prop.tscn`. [destructible_prop.gd](scripts/destructible_prop.gd) has 21 prop-type colors hardcoded ([Pass 5 Finding E12](audits/AUDIT_2026-04-16/05_ux.md)). Prop definitions (spawn weights, card drop chance per type) are present and non-empty.

## 6.12 Pass 6 Findings Summary

| # | Sev | Finding |
|---|-----|---------|
| F1 | MEDIUM | `BOSS_TRACK = ""` — no dedicated boss music track |
| F2 | LOW | Per-stage "first entry" tracks TODO'd |
| F3 | LOW | Stage-name drift ("Scrapyard" vs "Steampunk Caverns" in THEMES) |
| F4 | LOW | 40 card icons — add an at-boot sanity check |
| F5 | MEDIUM | `first_craft` achievement unreachable |
| F6 | MEDIUM | 8 disabled armors still fully defined (config bloat) |
| F7 | LOW | Hardcoded English UI strings — no `tr()` wrapping |
| F8 | LOW | Credits transition flow worth end-to-end test |

**Pass 6 totals:** CRITICAL 0 · HIGH 0 · MEDIUM 3 · LOW 5.

The game is **content-complete** relative to the 6-biome / 12-boss / 84-wave plan. Remaining gaps are polish (boss track, localization hooks, dead achievement).
