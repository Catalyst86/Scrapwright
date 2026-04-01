# Scrapwright — Claude Code Instructions

## Project Overview
Top-down arena survivors/bullet-heaven roguelite built in Godot 4.6 (GDScript).
- Viewport: 960x540 (pixel art, camera zoom)
- Style: Steampunk junkyard/cave, pixel art with animated puppy protagonist
- Player is a scrappy dog who bites enemies, collects orbital weapons, and upgrades between runs

## Project Structure
```
C:\Users\danie\Desktop\Scrapwright Safe copy\
├── project.godot           ← Godot 4.6, GL Compatibility
├── autoloads/
│   ├── game_state.gd       ← Phase, materials, health, perks, permanent upgrades
│   ├── crafting_db.gd      ← Recipe definitions
│   ├── stage_data.gd       ← Stage/biome definitions (6 stages)
│   ├── orbital_db.gd       ← Orbital weapon definitions (13 types)
│   ├── wave_manager.gd     ← Wave spawning logic, 84 waves (6 stages × 14)
│   ├── save_manager.gd     ← ConfigFile persistence (profiles)
│   ├── achievements.gd     ← 16 achievements, 5 categories
│   ├── armor_db.gd         ← Armor/cosmetic definitions & unlock tracking
│   ├── card_db.gd          ← Card deck system & stat bonuses
│   ├── audio_manager.gd    ← Sound/music management
│   └── upgrade_db.gd       ← All permanent upgrade definitions (5 categories)
├── scenes/
│   ├── intro_video.tscn    ← CURRENT main scene (intro → main menu)
│   ├── main_menu.tscn
│   ├── base_hub.tscn       ← Between-run upgrade hub with dog bust
│   ├── arena.tscn          ← Main gameplay scene
│   ├── junkyard.tscn       ← Alternative junkyard mode
│   ├── level_up.tscn       ← Level-up perk selection popup
│   ├── game_over.tscn
│   ├── card_popup.tscn     ← Card reveal UI
│   ├── chest.tscn          ← Loot chests (spawn after waves)
│   ├── secret_door.tscn    ← Secret room entrance
│   ├── secret_room.tscn
│   ├── dig_hole.tscn       ← Player dig ability result
│   ├── material_pickup.tscn
│   ├── key_pickup.tscn
│   ├── destructible_prop.tscn
│   ├── enemy_projectile.tscn
│   ├── debug_boot.tscn
│   └── enemies/            ← 37 enemy scenes across 6 stages + bosses
├── scripts/
│   ├── arena.gd            ← Main gameplay, phase management
│   ├── arena_builder.gd    ← Generates floor/walls/nav at runtime
│   ├── base_hub.gd         ← Hub UI: sidebar tabs, radial upgrades, wardrobe, dog bust
│   ├── player.gd           ← Player movement, bite attack, dodge, sneak, dig
│   ├── enemy_base.gd       ← Base class (class_name EnemyBase extends CharacterBody2D)
│   ├── orbital_weapon.gd   ← Orbital weapon base (class_name OrbitalWeapon)
│   ├── orbital_*.gd        ← 12 specific orbital weapon scripts
│   ├── enemy_*.gd          ← 37 individual enemy scripts
│   ├── hud.gd, level_up.gd, game_over.gd, main_menu.gd
│   ├── chest.gd, secret_room.gd, secret_door.gd, dig_hole.gd
│   ├── material_pickup.gd, key_pickup.gd, destructible_prop.gd
│   ├── junkyard_v2.gd, junkyard_waves.gd, junkyard_state.gd
│   ├── card_popup.gd, pause_menu.gd, intro_video.gd
│   └── enemy_projectile.gd
└── assets/sprites/
    ├── player/         ← 8-direction animations per armor tier (bandana, leather_vest, etc.)
    ├── bust/           ← Animated dog bust for hub (idle, happy_panting, head_shake, etc.)
    ├── enemies/        ← Enemy sprites per type
    ├── orbitals/       ← Orbital weapon sprites (13 types)
    ├── armor_icons/    ← Puppy-wearing-armor icons for wardrobe (18 PNGs)
    ├── cards/          ← Card deck sprites
    ├── hub_icons/      ← Upgrade category icons + material icons
    ├── hub_ui/         ← Sidebar frame, tab buttons, bottom bar, wardrobe button
    ├── items/          ← Chest, key sprites
    ├── effects/        ← Visual effects
    ├── environment/    ← Arena tilework
    ├── junkyard_v2/    ← High-res junkyard props
    └── ui/             ← HUD icons (perk icons, level-up, etc.)
```

---

## Game Loop
```
Intro Video → Main Menu → Base Hub → Arena (wave combat → chests → next wave)
                                      ↕ (boss waves return to hub)
                                   Base Hub (upgrade, wardrobe, cards)
                                      ↓
                                   Next stage / Game Over / Run Complete
```

### Arena Phases
```gdscript
enum ArenaPhase { PREP, COMBAT, CHEST_PHASE, TRANSITION }
```
1. Wave spawns via WaveManager
2. Player fights (bite + orbitals) until all enemies dead
3. 3s safety timeout forces wave complete if 0 enemies remain
4. Wave clear → chests spawn (1 pair normal, 2 pairs on boss waves 7 & 14)
5. Boss waves: check for secret door (if player has secret key) → return to Base Hub
6. Normal waves: next wave starts immediately after chests

### 84 Waves Across 6 Stages
- **Stage 1 — Scrapyard** (waves 1–14): rusher, shooter, tank, flyer, exploder
- **Stage 2 — Fungal Grove** (waves 15–28): spore_walker, mycelium_sniper, fungal_brute
- **Stage 3 — Magma Core** (waves 29–42): magma_imp, lava_lobber, obsidian_golem
- **Stage 4 — Frozen Caverns** (waves 43–56): frost_sprite, ice_archer, glacial_hulk, crystal_bat
- **Stage 5 — Clockwork Factory** (waves 57–70): gear_drone, steam_turret, brass_enforcer, spark_bug
- **Stage 6 — The Abyss** (waves 71–84): shadow_crawler, void_weaver, abyssal_knight, phantom
- **Bosses** appear on waves 7 & 14 of each stage (junkyard_mech, fungal_titan, molten_wyrm, etc.)

---

## Player Combat System

### Primary Attack — Bite (Auto-Attack)
- Base damage: 8, range: 80px, cooldown: 0.6s
- Visual: bark shockwave + "BARK!"/"WOOF!" text
- Modified by: perk_damage_bonus, perk_attack_speed_multiplier, crit chance, sneak ambush (2x)

### Orbital Weapons (13 Types)
Orbit the player at 30px radius. Max 6 simultaneous, max level 20 each.
- spark_coil, flame_wisp, frost_shard, poison_orb, blade_fan, arcane_book
- thorn_vine, chain_link, shield_drone, magnet_core, holy_lantern, shadow_dagger

### Player Abilities
- **Dodge (Space):** Invulnerable leap, 0.3s duration, 1.5s cooldown
- **Sneak (E):** 50% speed, up to 3s, ambush bonus 2x damage
- **Dig (F):** 1.6s channel, creates dig hole, charges from Deep Digger upgrade
- **Salvage (Shift):** 1.0s channel on destructible props

---

## Base Hub — Upgrade System

The hub features an animated dog bust in the center with 5 upgrade categories arranged **radially** around it. Sidebar tabs on the left, bottom bar with JUNKYARD / ENTER DUNGEON / WARDROBE buttons.

### Left Sidebar Tabs
1. **DEN UPGRADES** — Radial upgrade category selector (default)
2. **CARD COLLECTION** — 4 decks × 10 cards (40 total). Completion bonuses: Scrap (+25 HP), Lost (+10 damage), Critter (Bug Swarm perk), Overgrowth (Vine Snare perk)
3. **ACHIEVEMENTS** — 16 achievements across 5 categories
4. **ARCHIVE** — Coming soon

### 5 Upgrade Categories (UpgradeDB)
Each category has 3 upgrades, positioned at an angle around the bust:

**Combat Paws** (210°, red-orange):
- bite_damage (Iron Maw): +1 damage/level, max 10
- attack_speed (Quick Snap): +5% speed/level, max 5
- crit_chance (Sharp Fangs): +3% crit/level, max 5

**Survival Den** (330°, green):
- max_hp (Thick Hide): +10 HP/level, max 10
- health_regen (Resting Howl): Regen during combat, max 10
- damage_reduction (Tough Coat): +2% reduction/level, max 5

**Scavenge Snout** (270° / top, blue):
- dig_charges (Deep Digger): +1 dig charge/level, max 10
- salvage_speed (Keen Nose): Faster salvaging & yields, max 5
- pickup_magnet (Fetch!): +15% pickup range/level, max 5

**Companion Legacy** (30°, gold):
- rerolls (Old Dog Tricks): +1 level-up reroll/level, max 5
- xp_gain (Street Smarts): +5% XP/level, max 10
- perk_choices (Sharp Instincts): 4 perk options instead of 3, max 1

**Mutation** (150°, purple — one-time unlocks):
- revival (Soulbound Stray): Revive at 30% HP once per run
- feral_howl (Feral Howl): Stun all enemies 2s on wave start
- junkyard_chimera (Junkyard Chimera): Random buff each run

### Wardrobe (bottom bar button)
- Popup with 3-column grid of armor cards
- Uses puppy icons from `assets/sprites/armor_icons/`
- Dual equip: "Stats" button (stat bonuses) and "Look" button (visual appearance)
- Stats applied via `GameState.apply_armor_stats()` at run start

---

## Key Systems Reference

### GameState (autoload)
```gdscript
# Signals
signal phase_changed(new_phase)
signal materials_changed
signal health_changed(current, max_hp)
signal keys_changed
signal abilities_changed

# Phase
GameState.current_phase              # Phase enum
GameState.Phase.BASE_HUB / ARENA_COMBAT / CHEST_PHASE / etc.

# Player stats
GameState.player_health / player_max_health
GameState.player_level / player_xp / xp_to_next_level
GameState.perk_speed_multiplier      # Base 1.0
GameState.perk_damage_bonus          # Base 0
GameState.perk_attack_speed_multiplier # Base 1.0 (lower = faster)
GameState.perk_regen_active          # bool
GameState.perk_xp_multiplier         # Base 1.0

# Materials & Keys
GameState.materials                  # {"iron_scrap": 0, "timber": 0, ...}
GameState.keys                       # {"bronze": 0, "silver": 0, "gold": 0, "secret": 0}
GameState.add_material(type, amt)
GameState.take_damage(amount)
GameState.heal(amount)

# Equipment
GameState.equipped_armor_stat        # Armor ID for stat bonuses
GameState.equipped_armor_visual      # Armor ID for appearance
GameState.unlocked_armors            # Array of unlocked armor IDs

# Permanent upgrades
GameState.permanent                  # {"bite_damage_level": 0, "max_hp_level": 0, ...}

# Run management
GameState.start_new_run()
GameState.apply_armor_stats()
GameState.reapply_permanent_bonuses()
```

### WaveManager (autoload)
```gdscript
WaveManager.start_wave(wave_num)
WaveManager.register_arena(enemies_container_node)
WaveManager.register_spawn_point(Vector2)
WaveManager.clear_spawn_points()
# Signals: wave_complete(wave_num), all_waves_complete, enemies_remaining_changed(count)
```

### Achievements (autoload)
```gdscript
Achievements.check_and_unlock(id)
Achievements.is_unlocked(id) -> bool
Achievements.increment_stat(stat_name, amount)
Achievements.reset_run_stats()
Achievements.ACHIEVEMENTS              # Dict of all 16 achievement definitions
Achievements.CATEGORIES                # ["Combat", "Progression", "Collection", "Base Building", "Misc"]
```

### Scene Flow
```
intro_video.tscn → main_menu.tscn → base_hub.tscn → arena.tscn
                                          ↑              ↓ (boss wave clear)
                                          └──────────────┘
                                                         ↓ (death)
                                                    game_over.tscn
```

---

## PixelLab API v2

- **Key**: `033683bf-7368-465f-81a8-6e01192d8a1b`
- **Base URL**: `https://api.pixellab.ai/v2`
- **Full reference**: See `memory/reference_pixellab_api.md`

### Key Endpoints
| Endpoint | What It Does | Sync? |
|----------|-------------|-------|
| `POST /create-character-with-4-directions` | Create character in 4 dirs, stored server-side | 200 |
| `POST /create-character-with-8-directions` | Create character in 8 dirs | 200 |
| `POST /characters/animations` | Animate existing character (template or custom) | 200 |
| `GET /characters/{id}/zip` | Download all frames as ZIP | 200 |
| `POST /generate-image-v2` | Best quality image gen, up to 792x688 | 202 |
| `POST /generate-with-style-v2` | Match existing art style (1-4 ref images) | 202 |
| `POST /create-image-pixflux` | Quick sync image gen (v1 compat), up to 400x400 | 200 |
| `POST /animate-with-text-v3` | Generate animation from first frame + action text, 4-16 frames | 200 |
| `POST /animate-with-text-v2` | Pro animation with size/direction control | 202 |
| `POST /transfer-outfit-v2` | Apply outfit/armor to animation frames | 202 |
| `POST /edit-animation-v2` | Edit existing animation frames with text | 202 |
| `POST /interpolation-v2` | Tween between two poses | 202 |
| `POST /generate-8-rotations-v2` | Generate 8 directional rotations | 202 |
| `POST /tilesets` | Generate full tileset with transitions | 202 |
| `POST /create-tiles-pro` | Pro tiles (hex/iso/square, 1-16 tiles) | 202 |
| `POST /map-objects` | Generate props with transparent bg | 200 |

### Character Template IDs
`mannequin`, `bear`, `cat`, `dog`, `horse`, `lion`

### Animation Template IDs
`breathing-idle`, `walking`, `running`, `crouched-walking`, `jump`, `landing`, `roll`,
`slash-down`, `slash-up`, `cross-punch`, `side-kick`, `flying-kick`, `upper-cut`,
`falling-back-death`, `fireball`, `spell-casting`, `swimming`, `backflip`, `crouching`, `drinking`

### 202 Async Pattern
```python
r = requests.post(f'{URL}/generate-image-v2', headers=H, json=body)
job_id = r.json()['data']['background_job_id']
# Poll:
result = requests.get(f'{URL}/background-jobs/{job_id}', headers=H)
# 200 = done, 423 = still processing
```

---

## Important GDScript 4.6 Gotchas

1. **Theme overrides in code**: Use `node.add_theme_font_size_override("font_size", 12)` NOT `node.theme_override_font_sizes = {"font_size": 12}`
2. **Inline shapes in .tscn**: DON'T write `shape = CircleShape2D(radius=8.0)` — must be a `[sub_resource]` block
3. **Enum iteration**: `"VALUE" in MyEnum` doesn't work — use `"VALUE" in MyEnum.keys()`
4. **class_name syntax**: `class_name EnemyBase extends CharacterBody2D` (one line, not two)
5. **Custom UIDs in .tscn**: Don't hand-write `uid="uid://something"` — Godot assigns these
6. **preload() vs load()**: preload() at class level is evaluated at parse time — if the file has any error, the whole project crashes on boot. Use load() at runtime when possible.
7. **NavigationRegion2D**: Call `bake_navigation_polygon()` after setting the polygon or enemies won't pathfind
8. **Timer.start()**: Timers don't autostart unless `autostart = true` — always call `.start()` explicitly
9. **await in _physics_process**: Don't use await in physics process functions — use timers instead
10. **Area2D collision**: Set `monitoring = true` for areas that detect things entering them
