# SCRAPWRIGHT — Setup & Dev Notes

## First-time setup (do this once)

### 1. Extract sprites
Download `sprite_transfer.zip` from Claude chat → extract so that:
```
roguelite/assets/sprites/player/      ← walk_s_0.png, walk_n_0.png, etc.
roguelite/assets/sprites/enemies/     ← enemy_rusher.png, etc.
roguelite/assets/sprites/items/       ← item_throwing_knife.png, etc.
roguelite/assets/sprites/traps/       ← trap_spikes.png, etc.
roguelite/assets/sprites/environment/ ← destructible_crate.png, etc.
roguelite/assets/sprites/ui/          ← ui_heart.png, ui_bag.png
roguelite/assets/sprites/base/        ← base_workbench.png, etc.
roguelite/assets/sprites/animations/  ← enemy_rusher_walk_sheet.png, etc.
```

### 2. Open in Godot 4.3+
Open Godot → Import → select `roguelite/project.godot`

### 3. Generate SpriteFrames resource
In Godot: Script menu → Run (or Ctrl+Shift+X) with `setup_sprite_frames.gd`  
This creates `resources/player_frames.tres` from the individual PNGs.

### 4. Wire player scene
Open `scenes/player.tscn` → click AnimatedSprite2D → in Inspector, set  
`SpriteFrames = res://resources/player_frames.tres`

### 5. Set up NavigationRegion2D (for enemy pathfinding)
Open `scenes/arena.tscn` → select NavigationRegion2D → draw a polygon  
covering the full arena floor (or add a RectangleShape covering 0,0 to 480,270)

### 6. Hit Play
Main scene is `scenes/main_menu.tscn` — should open, click Play → Base Hub → Start Run → Arena.

---

## Controls
| Key | Action |
|-----|--------|
| WASD / Arrows | Move |
| Left Click / Space | Throw active item |
| Q / Scroll Up | Next throwable |
| E / Scroll Down | Prev throwable |
| F | Interact (salvage mode) |
| Left Click (salvage) | Break nearby prop |

---

## Collision Layers
| Layer | Used for |
|-------|----------|
| 1 | Player + environment (walls/floor) |
| 2 | Enemies |
| 3 | Player + enemies (combined) |
| 4 | Enemy projectiles |
| 8 | Traps |

---

## Scene structure
```
main_menu.tscn      → base_hub.tscn → arena.tscn → (salvage) → base_hub.tscn
                                                   → (death)  → game_over.tscn
```

## What's working / what needs doing

### Done ✅
- GameState autoload (full run data, materials, health, phases)
- CraftingDB autoload (all recipes + trap + destructible yield data)
- WaveManager autoload (10 waves, spawning queue, difficulty scaling)
- SaveManager autoload (ConfigFile persistence)
- Player (movement, auto-attack, throw, salvage input)
- EnemyBase + all 5 enemy types (Rusher, Shooter, Tank, Flyer, Exploder)
- Throwable system (knife, molotov, pipe bomb, boomerang)
- Trap system (spikes, fire, electric + chain lightning)
- DestructibleProp (health, material drop, float text)
- SalvageWindow (90s timer, bag filling, material transfer)
- QuickCraft popup (post-wave recipe menu)
- Arena (full phase loop: prep → combat → quick craft → salvage → base)
- BaseHub (buildings, deep craft, passive gains, run start)
- HUD (health bar, XP bar, wave counter, throwable display)
- MainMenu + GameOver screens
- All scenes (.tscn files)
- Input map (WASD + mouse)
- 77 sprites generated and ready to import

### Needs doing next 🔨
- [ ] Wire SpriteFrames in player.tscn (run setup_sprite_frames.gd)
- [ ] Set up NavigationRegion2D polygon in arena.tscn
- [ ] Set up TileMapLayer with a floor tile in arena.tscn
- [ ] Wire enemy SpriteFrames (use animation sheets)
- [ ] Base Hub visual polish (building sprites visible)
- [ ] Trap placement UI during prep phase
- [ ] Level-up selection (pick a perk when XP bar fills)
- [ ] Sound effects (AudioStreamPlayer nodes)
- [ ] Particle effects on hit/death/explosion
- [ ] Tileset for arena floor/walls

---

## Architecture at a glance

```
Autoloads (always running):
  GameState   — phase, health, materials, throwables, permanent upgrades
  CraftingDB  — all recipe + yield data (pure data, no state)
  WaveManager — spawning logic, wave progression
  SaveManager — load on boot, save after each run/wave clear

Scenes:
  Arena
  ├── TileMapLayer          (floor tiles)
  ├── NavigationRegion2D    (enemy pathfinding mesh)
  ├── EnemiesContainer      (wave enemies added here)
  ├── TrapsContainer        (player-placed traps)
  ├── PropsContainer        (destructible props for salvage)
  ├── Player
  │   └── Camera2D (zoom 3x)
  ├── SalvageWindow (hidden until salvage phase)
  └── HUD (CanvasLayer)
```
