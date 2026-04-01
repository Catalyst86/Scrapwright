# Scrapwright Audit — Structure Notes

## Project Scope
- **Total files**: 20,630 (includes .godot cache, assets, audio)
- **GDScript files**: ~80
- **Scene files (.tscn)**: ~57
- **Resource files (.tres)**: 2 (default_theme.tres, default_bus_layout.tres)
- **Config files**: Mostly .godot cache

## Autoload Chain (load order per project.godot)
1. GameState (game_state.gd) — central state, no dependencies
2. CraftingDB (crafting_db.gd) — destructible yields, no dependencies
3. StageData (stage_data.gd) — wave definitions, no dependencies
4. OrbitalDB (orbital_db.gd) — weapon definitions, no dependencies
5. WaveManager (wave_manager.gd) — depends on StageData, GameState
6. SaveManager (save_manager.gd) — depends on GameState, CraftingDB
7. Achievements (achievements.gd) — depends on GameState, SaveManager
8. ArmorDB (armor_db.gd) — depends on GameState, SaveManager
9. JunkyardState (junkyard_state.gd) — depends on GameState
10. CardDB (card_db.gd) — no dependencies
11. AudioManager (audio_manager.gd) — depends on WaveManager, GameState, StageData

## class_name Declarations
- `EnemyBase` — scripts/enemy_base.gd
- `OrbitalWeapon` — scripts/orbital_weapon.gd
- `JunkyardWaves` — scripts/junkyard_waves.gd

## Key Observations
- No `resources/` directory exists — SpriteLoader references nonexistent .tres files
- JunkyardState autoload points to `scripts/junkyard_state.gd` (not `autoloads/`)
- Main scene is `intro_video.tscn` (not debug_boot or main_menu)
- Viewport: 960x540 in project.godot, arena uses 1280x720, CLAUDE.md says 480x270
- Audio buses: Master, SFX, Music, UI — all properly defined
- Input actions: ui_left/right/up/down, salvage, bark, dodge, sneak, collect
- 42 print() statements across 6 files (debug output in production)
- 27 await create_timer calls across 12 files (potential scene-change crashes)

## Potential Case Sensitivity Issues
- `assets/Game icon.png` — space in filename (risky on Linux)
- All other paths appear clean
