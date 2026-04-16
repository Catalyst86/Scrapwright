# Pass 1 — Repository Hygiene & Architecture

*Scrapwright audit 2026-04-16. Findings only — no code changes.*

## 1.1 Directory Snapshot

**Scripts:** 77 `.gd` files in `scripts/` (incl. `scripts/orbitals/` subdir, 12 files).
**Scenes:** 58 `.tscn` files (incl. `scenes/enemies/` 34 files).
**Autoloads:** 13 registered in `project.godot:19-33`.

Largest scripts (LOC):

| File | LOC | Role |
|------|-----|------|
| `scripts/base_hub.gd` | 2014 | Hub UI (radial, wardrobe, sidebar, dog bust, popups) |
| `scripts/arena.gd` | 1670 | Run controller, phases, chest UI, perk timers |
| `scripts/enemy_base.gd` | 1406 | Enemy base class, boss phases, damage numbers, stun |
| `scripts/junkyard_v2.gd` | 1292 | Parallel arena for junkyard mode |
| `scripts/main_menu.gd` | 1013 | Menu + options + profile flow |
| `scripts/player.gd` | 1021 | Movement, bite, orbitals, dodge, sneak, dig |
| `scripts/pause_menu.gd` | 770 | Pause overlay + rebind submenu |
| `scripts/level_up.gd` | 762 | Perk selection + perk side-effect installation |
| `autoloads/game_state.gd` | 669 | All run/permanent state |

**Finding A1 (MEDIUM, maintainability):** Four scripts above 1,000 LOC; `base_hub.gd` at 2,014 LOC handles UI layout, wardrobe popups, card popups, upgrade radial, top bar, dog bust, tab switching, and input. Single-responsibility violated. Risk: every hub change has broad blast radius.

## 1.2 Autoloads & Responsibilities

All autoloads declared at [project.godot:19](project.godot:19):

| Autoload | File | Role |
|----------|------|------|
| GameState | `autoloads/game_state.gd` | Phase, run HP/XP, materials, keys, permanent bonuses, armor state |
| CraftingDB | `autoloads/crafting_db.gd` | Recipe definitions |
| StageData | `autoloads/stage_data.gd` | 6 biomes metadata |
| OrbitalDB | `autoloads/orbital_db.gd` | 12 orbital weapon definitions |
| WaveManager | `autoloads/wave_manager.gd` | 84-wave spawning |
| SaveManager | `autoloads/save_manager.gd` | ConfigFile profile persistence |
| Achievements | `autoloads/achievements.gd` | 16 achievements, stat tracking |
| ArmorDB | `autoloads/armor_db.gd` | Armor + stat bonuses |
| JunkyardState | `scripts/junkyard_state.gd` | Junkyard-mode state (lives in scripts/, not autoloads/) |
| CardDB | `autoloads/card_db.gd` | Card deck definitions |
| AudioManager | `autoloads/audio_manager.gd` | SFX/music bus |
| KeybindManager | `autoloads/keybind_manager.gd` | Action rebinding |
| UpgradeDB | `autoloads/upgrade_db.gd` | Permanent upgrade tiers |

**Finding A2 (LOW, hygiene):** `JunkyardState` autoload points to `scripts/junkyard_state.gd`, not the `autoloads/` directory — inconsistent with every other autoload ([project.godot:29](project.godot:29)). No runtime impact; organizational wart.

## 1.3 Signals — Emitters & Listeners

### Declared signals (11 total)

| Signal | Declared | Listeners |
|--------|----------|-----------|
| `wave_complete(wave_num)` | [wave_manager.gd:7](autoloads/wave_manager.gd:7) | [arena.gd:61](scripts/arena.gd:61), [junkyard_v2.gd:129](scripts/junkyard_v2.gd:129) |
| `all_waves_complete` | [wave_manager.gd:8](autoloads/wave_manager.gd:8) | [arena.gd:62](scripts/arena.gd:62) |
| `card_dropped(card_data)` | [destructible_prop.gd:7](scripts/destructible_prop.gd:7) | [arena.gd:188](scripts/arena.gd:188), [junkyard_v2.gd:781/801/808](scripts/junkyard_v2.gd:781) |
| `died(xp_reward)` (EnemyBase) | [enemy_base.gd:3](scripts/enemy_base.gd:3) | [wave_manager.gd:166](autoloads/wave_manager.gd:166), boss-minion hooks, tutorial_arena |
| `died` (player) | [player.gd:3](scripts/player.gd:3) | [arena.gd:66](scripts/arena.gd:66), [junkyard_v2.gd:132](scripts/junkyard_v2.gd:132) |
| `died(xp_reward)` (tutorial_dummy) | [tutorial_dummy.gd:5](scripts/tutorial_dummy.gd:5) | [tutorial_arena.gd:533/557/581](scripts/tutorial_arena.gd:533) |
| `died(xp_reward)` (tutorial_walker) | [tutorial_walker.gd:6](scripts/tutorial_walker.gd:6) | (same as above) |
| `phase_changed(new_phase)` | [game_state.gd:7](autoloads/game_state.gd:7) | **No listeners found** |
| `materials_changed` | [game_state.gd:8](autoloads/game_state.gd:8) | [arena.gd:64/533](scripts/arena.gd:64), [base_hub.gd:203](scripts/base_hub.gd:203) |
| `health_changed(current, max_hp)` | [game_state.gd:9](autoloads/game_state.gd:9) | [arena.gd:63](scripts/arena.gd:63), [junkyard_v2.gd:130](scripts/junkyard_v2.gd:130) |
| `keys_changed` | [game_state.gd:10](autoloads/game_state.gd:10) | [arena.gd:110/343/531](scripts/arena.gd:110), [base_hub.gd:204](scripts/base_hub.gd:204) |

### Signals documented but not declared

`CLAUDE.md:204` lists `signal abilities_changed` as a `GameState` signal, but **no such signal exists** in `autoloads/game_state.gd`. Either legacy documentation or the signal was removed.

**Finding A3 (LOW, dead signal):** `GameState.phase_changed(new_phase)` is emitted (see [game_state.gd](autoloads/game_state.gd) `_change_phase` / assignments) but has zero `.connect()` sites. Phase state is observed by polling `GameState.current_phase` instead. Either remove the signal or wire HUD/arena to it.

**Finding A4 (LOW, doc drift):** `CLAUDE.md:204` advertises `abilities_changed` — not in code. Update docs or restore the signal.

## 1.4 Connect Hygiene

Audited 135+ `.connect(…)` sites. Highlights:

- `arena.gd` disconnects its autoload connections in `_on_tree_exiting` / `_exit_tree`-ish paths (lines 102–110, 343). Good.
- `base_hub.gd` disconnects radial slot mouse/gui handlers explicitly (lines 914–918). Good.
- `tutorial_arena.gd` uses `CONNECT_ONE_SHOT` for `enemy.died` in tutorial stages (line 533, 620). Good.
- **Bug-swarm / Vine-snare / PerkRegen timers** are created dynamically by name-check (`has_node("BugSwarmTimer")`) and never disconnected, but they're children of `arena` so they die with the scene. Acceptable, but fragile — see Finding A6.

**Finding A5 (MEDIUM, reconnect risk):** [junkyard_v2.gd:129-130](scripts/junkyard_v2.gd:129) connects `WaveManager.wave_complete` and `GameState.health_changed` on `_ready()` but I found **no corresponding disconnect** in `_exit_tree` / cleanup. If the player returns from junkyard to hub and back without full scene reset, the signals may be double-connected. Verify the scene is fully freed on exit.

## 1.5 Duplicated Logic (Copy-Paste Hotspots)

**Finding A6 (MEDIUM, duplication):** Perk timer installation for `bug_swarm`, `vine_snare`, and perk-regen is duplicated across three files:

| Logic block | arena.gd | junkyard_v2.gd | level_up.gd |
|-------------|----------|----------------|-------------|
| BugSwarm VFX + damage timer | 1300–1345 | 1193–1220 | 697–727 |
| VineSnare VFX + slow timer | 1347–1387 | 1222–1250 | 729–762 |
| Regen timer | 1389–1399 (+ legacy) | — | 615–635 |

Three near-identical implementations diverge on details (VFX z_index, pulse tween, `_base_move_speed` restore). Any balance change (radius, damage, interval) must be applied three times — high regression risk.

**Finding A7 (LOW, duplication):** `_on_music_finished` pattern in `audio_manager.gd:210` plus similar one-shot `.finished.connect(queue_free)` in enemy_projectile.gd:120 — fine pattern, but the AudioManager does not track the bound `_on_music_finished` callable, so the implicit assumption is that the player is never rebound. OK for now.

**Finding A8 (MEDIUM, parallel arena code):** `scripts/junkyard_v2.gd` is ~1,300 LOC and re-implements much of the Arena loop (wave registration, card-drop hookup, player-died handling, post-wave flow). Any gameplay change touching wave flow must be mirrored in both files.

## 1.6 Circular Dependencies

No circular class-level dependencies detected (only three `class_name` declarations: `EnemyBase`, `JunkyardWaves`, `OrbitalWeapon`). Scene references are acyclic: `intro_video → main_menu → base_hub → arena/junkyard → {game_over, base_hub, credits}`.

## 1.7 Dead / Orphan Code

Scenes **never loaded** by any script (search of `preload`, `load`, `change_scene_to_file`, `instantiate`):

- **None confirmed dead** — every scene I tested has at least one reference. Notable near-misses:
  - `scenes/debug_boot.tscn` is referenced only in a comment at [debug_boot.gd:5](scripts/debug_boot.gd:5). Not set as main scene. **Finding A9 (LOW): debug boot scene exists but no entry path.**
  - `scenes/tutorial_dummy.tscn` / `scenes/tutorial_walker.tscn` referenced only inside `scripts/tutorial_arena.gd`.

Scripts with no references from other scripts or scenes (after grep):

- `scripts/setup_sprite_frames.gd` — `@tool` `EditorScript`. Intentional dev utility, not dead, but should be flagged as a dev artifact so it isn't shipped in release (see Finding A10).

**Finding A10 (LOW, release hygiene):** `scripts/setup_sprite_frames.gd` is an `@tool` `EditorScript`. It won't run at game start, but it will be packed into the release. Move to `addons/` or exclude from export.

## 1.8 TODO / FIXME / HACK / XXX

Only 2 comments of this class in the codebase:

| File:Line | Comment |
|-----------|---------|
| [audio_manager.gd:102](autoloads/audio_manager.gd:102) | `# Stage-specific "first entry" tracks — TODO: create these tracks` |
| [audio_manager.gd:131](autoloads/audio_manager.gd:131) | `const BOSS_TRACK = ""  # TODO: create boss_battle.ogg` |

**Finding A11 (LOW, content gap):** Boss-battle music is stubbed as an empty string. If any code path sends `BOSS_TRACK` to `AudioManager.play_music()`, the current boss music falls back silently — see Pass 6 content check.

## 1.9 Architecture Hotspots Summary

| # | Severity | Finding |
|---|----------|---------|
| A1 | MEDIUM | 4 scripts >1000 LOC; `base_hub.gd` particularly sprawling |
| A2 | LOW | `JunkyardState` autoload path inconsistent (`scripts/` vs `autoloads/`) |
| A3 | LOW | `GameState.phase_changed` has emitters but zero listeners |
| A4 | LOW | `CLAUDE.md` lists `abilities_changed` signal that doesn't exist |
| A5 | MEDIUM | `junkyard_v2` signal connects without matched disconnects — re-entry risk |
| A6 | MEDIUM | Bug-swarm / vine-snare / regen timer logic triplicated |
| A7 | LOW | Music `_on_music_finished` binds implicitly singleton-safe |
| A8 | MEDIUM | `junkyard_v2.gd` duplicates `arena.gd` wave/loot flow |
| A9 | LOW | `scenes/debug_boot.tscn` has no entry path |
| A10 | LOW | `setup_sprite_frames.gd` is a dev-only `EditorScript` shipped in release |
| A11 | LOW | `BOSS_TRACK` constant is `""` — boss music content gap |

**Pass 1 totals:** CRITICAL 0 · HIGH 0 · MEDIUM 4 · LOW 7.
