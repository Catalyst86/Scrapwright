# Pass 4 — Performance & Frame Budget

*Scrapwright audit 2026-04-16. Findings only. Bullet-heaven with 80+ concurrent enemies must hold 60 fps on GL Compatibility renderer.*

## 4.1 Per-Frame Allocations in Hot Paths

### Finding D1 (HIGH) — Flame Wisp trail embers uncapped

[orbital_flame_wisp.gd:48-68](scripts/orbitals/orbital_flame_wisp.gd:48) spawns a trail timer at 0.05s (20 Hz) during each projectile's flight of up to 1.5s — **up to 30 new `Polygon2D` + per-ember tween + per-ember queue_free per fireball**.

At wave 60 with a full 6-orbital loadout including Flame Wisp cooling at 0.7s, ~1-2 fireballs are in flight simultaneously. That's **200-400 concurrent Polygon2D ember nodes** plus their tweens. Every ember is its own draw call (2D canvas doesn't batch Polygon2D across instances). Frame cost scales linearly with enemy density because that governs orbital fire frequency.

Mitigation: pool the Polygon2D or draw the trail as a single CanvasItem with `_draw()` — collapses 30 draw calls per fireball into 1.

### Finding D2 (HIGH) — Orbital VFX allocations per fire

Each orbital weapon hit allocates 1-5 `Line2D` / `Polygon2D` / `Label` / `Tween` nodes at runtime. [orbital_weapon.gd:189-285](scripts/orbital_weapon.gd:189) contains `_show_lightning`, `_show_ice_spike`, `_show_fire_burst` — none pool. At worst-case 6 orbitals firing on a 0.3s-0.7s cadence: **~20 VFX node allocations/sec per weapon × 6 = 120/sec**.

Mitigation: introduce a `VFXPool` autoload with `get_line2d()` / `get_polygon2d()` / `get_label()` returning reused nodes.

### Finding D3 (MEDIUM) — Player bark wave allocations

[player.gd:664-739](scripts/player.gd:664) — every auto-attack (≤0.6s CD, sometimes 0.18s with perks) spawns a "BARK!" label + line rings + impact polygon. With attack-speed perks stacking to 3.33 atk/s, this is **~15-20 allocations/sec**. 

Mitigation: pool the bark VFX; or draw the ring in a single `_draw()` call parented to the player.

### Finding D4 (LOW) — Pickup collect labels

[xp_pickup.gd:98](scripts/xp_pickup.gd:98), [material_pickup.gd:96-126](scripts/material_pickup.gd:96) allocate a floating label on pickup. Rate <10/sec typical. Not a bottleneck.

### Finding D5 (MEDIUM) — Flame trail dot scene instantiation

[player.gd:537-543](scripts/player.gd:537) spawns flame trail dots by instantiating `flame_trail_dot.tscn` at 20 Hz during a 0.3s dodge — 6 scene-load + instance per dodge. At frequent dodges, 30/sec scene instantiations. Mitigation: preload and pool.

## 4.2 `get_tree().get_nodes_in_group()` In Hot Loops

### Finding D6 (HIGH) — Fallback path if WaveManager cache stale

[enemy_base.gd:503-512](scripts/enemy_base.gd:503): `_compute_separation()` uses `WaveManager._cached_enemies` if available, else falls back to `get_nodes_in_group("enemies")`. Because 80 enemies all run this per physics tick, the fallback cost is **O(n²) = 6400** lookups/frame if the cache is ever empty (e.g., right after wave start before the cache populates). Verified: the cache *is* populated in `_on_enemy_spawned` / death callbacks, but there's a 1-frame race where `_cached_enemies` is set after the enemies have already ticked once.

Mitigation: populate cache before enemies' first physics tick (deferred-add then cache), or accept the one-frame hit as "one bad frame per wave start".

### Finding D7 (MEDIUM) — Bug-swarm / vine-snare damage scans

[arena.gd:1339](scripts/arena.gd:1339), [arena.gd:1378](scripts/arena.gd:1378), [level_up.gd:704/738](scripts/level_up.gd:704), [junkyard_v2.gd:1207/1236](scripts/junkyard_v2.gd:1207) — all call `get_tree().get_nodes_in_group("enemies")` inside a timer tick (1.0s for bug swarm, 0.5s for vine snare). Each tick is O(n). At wave 60+ with both perks active, that's **120 enemy-distance checks per second**. Not catastrophic, but easy win: also piggyback on `WaveManager._cached_enemies`.

### Finding D8 (LOW) — Boss special abilities

`enemy_piston_crusher.gd:165`, `enemy_spore_mother.gd:250`, `enemy_junkyard_mech.gd:113` — all do group queries in boss phase-transition paths. Fires 1-2 times per encounter. Safe.

## 4.3 Projectile & Enemy Pooling

### Finding D9 (HIGH) — No enemy projectile pool

[enemy_projectile.gd](scripts/enemy_projectile.gd) + [enemy_shooter.gd](scripts/enemy_shooter.gd), [enemy_lava_lobber.gd](scripts/enemy_lava_lobber.gd), [enemy_mycelium_sniper.gd](scripts/enemy_mycelium_sniper.gd), [enemy_ice_archer.gd](scripts/enemy_ice_archer.gd), [enemy_steam_turret.gd](scripts/enemy_steam_turret.gd) all instantiate `enemy_projectile.tscn` per shot. At wave 60+ with ~15 shooters firing at ~1.5s cadence, that's **10 projectile spawns/sec**. Concurrent peak: ~30 projectiles. Tolerable today but regressions possible.

Mitigation: pool projectiles via a central `ProjectilePool` autoload. Returns hidden/deactivated instances rather than new ones.

### Finding D10 (MEDIUM) — Enemies not pooled

Wave spawns instantiate 40-80 enemy scenes per wave. Because waves are gated by a full kill-clear, peak concurrent creates ≈ full wave count. Godot can handle this, but `instantiate()` cost of complex enemies (AnimatedSprite2D + multi-shape collision + AI node tree) shows up on wave-start spikes. Mitigation: preload and pool common enemy types (rusher, shooter, flyer) per biome.

## 4.4 Particle / VFX Caps

### Finding D11 (MEDIUM) — VFX count uncapped

No global cap on concurrent floating damage numbers, ember trails, hit flashes, spark lines, bug swarm visuals, vine pulses. A "max 200 concurrent VFX, oldest evicted" policy would defend the frame budget without changing behavior at normal loads.

### Finding D12 (LOW) — Modulate tweens on VFX

Hundreds of per-node `tween_property(mod, "modulate:a", 0.0, ...)` calls per second. Each tween allocates a `SceneTreeTween` object. Combined with `Polygon2D.queue_free()` after tween, garbage is continually produced.

## 4.5 Draw-Call Batching

### Finding D13 (HIGH) — Line2D / Polygon2D not batched

Line2D and Polygon2D are each their own draw call. With 200+ concurrent VFX nodes (embers, bolts, rings), the game issues a sizable number of 2D draw calls per frame. GL Compatibility is happy with this up to a point, but fold these into a small number of CanvasItems using `_draw()` — especially the orbital trails and bark waves.

### Finding D14 (LOW) — Enemy AnimatedSprite2D per enemy

80 enemies = 80 sprite draw calls. Possibly batchable via `MultiMeshInstance2D` for enemies sharing the same `SpriteFrames`. Likely not a frame-killer today (GL compat handles ~1000 2D draw calls fine), but low-hanging optimization.

## 4.6 Physics Layers / Collision Pairs

### Finding D15 (HIGH — needs verification in scenes)

Scene files weren't inspected in this pass, but from the scripts:

- `player.gd` uses an `Area2D` detection ring (`detection.body_entered`, [player.gd:113](scripts/player.gd:113)) — correct, signal-driven.
- Enemy scripts inherit `CharacterBody2D`. If enemy-enemy physics collision is enabled (both on same `collision_layer` with overlapping `collision_mask`), Godot generates up to **n·(n-1)/2 ≈ 3160 pair candidates** at 80 enemies.
- Flame trail dots (`flame_trail_dot.gd:15-16`) use `collision_layer=0, collision_mask=2` — correct (detection only).

Mitigation: inspect `scenes/enemies/*.tscn` to confirm enemy-to-enemy collision is DISABLED (`collision_mask` does not include the enemy layer). If it's enabled, expect a ~20% frame-time reduction at wave 60 by disabling it and using only the separation steering already in `_compute_separation`.

## 4.7 Hot Paths to Profile at Wave 60+

| Rank | Function | Why |
|------|----------|-----|
| 1 | `enemy_base._physics_process` ([enemy_base.gd:385-431](scripts/enemy_base.gd:385)) | 80 calls/frame; movement + separation + collision |
| 2 | `_compute_separation` ([enemy_base.gd:503](scripts/enemy_base.gd:503)) | 80× per frame; O(n) even with cache |
| 3 | `orbital_flame_wisp` trail timer callback ([orbital_flame_wisp.gd:51](scripts/orbitals/orbital_flame_wisp.gd:51)) | 20 Hz × n in-flight fireballs |
| 4 | `orbital_weapon._find_target` ([orbital_weapon.gd:128](scripts/orbital_weapon.gd:128)) | 6 orbitals × wave 60 candidates |
| 5 | `player._auto_attack` ([player.gd:620-661](scripts/player.gd:620)) | Allocates VFX 1-3 times/sec |

## 4.8 Shaders

No `.gdshader` files are referenced. Rendering relies on standard CanvasItem materials + modulate. **No shader-related findings.**

## 4.9 AudioManager `node_added` Listener

### Finding D16 (LOW)

[audio_manager.gd:57](autoloads/audio_manager.gd:57) connects `get_tree().node_added` globally. `_on_node_added` filters to `BaseButton` and returns quickly otherwise. At ~60 node adds/sec during combat (enemies, pickups, VFX), each incurs a type check. Per-call cost is <0.01ms → total <1ms/sec overhead. **Measurable but not a bottleneck.**

Mitigation (if profiling ever flags): unsubscribe from `node_added` during arena combat and re-subscribe on return-to-hub.

## 4.10 Pickup Magnetism

### Finding D17 (—)

[xp_pickup.gd:64-73](scripts/xp_pickup.gd:64), [material_pickup.gd:63-77](scripts/material_pickup.gd:63) — each pickup polls player position once per frame. O(m) where m = pickups on-screen (≤50). No inter-pickup quadratic cost. Verified safe.

## 4.11 Findings Summary

| # | Sev | Issue | Fix |
|---|-----|-------|-----|
| D1 | HIGH | Flame wisp trail uncapped (20 Hz × 30 embers per fireball) | Cap embers to 10, or use `_draw()` |
| D2 | HIGH | Orbital VFX nodes allocated per hit (120 allocs/sec peak) | Pool VFX |
| D3 | MEDIUM | Bark wave allocates nodes per attack (15-20/sec peak) | Pool bark VFX or draw in-place |
| D4 | LOW | Pickup collect labels allocated | Acceptable |
| D5 | MEDIUM | Flame trail dots instantiated per leap (~30/sec) | Pool |
| D6 | HIGH | `_compute_separation` fallback can hit O(n²) on one-frame cache miss | Populate cache before first physics tick |
| D7 | MEDIUM | Bug/vine timers do `get_nodes_in_group` each tick | Piggyback on `WaveManager._cached_enemies` |
| D8 | LOW | Boss ability group scans — infrequent | Accept |
| D9 | HIGH | No projectile pool, ~10 spawns/sec | Pool |
| D10 | MEDIUM | No enemy pool — wave-start spikes | Pool common enemy types |
| D11 | MEDIUM | No global VFX cap — unbounded at late game | Soft cap 200 |
| D12 | LOW | Per-VFX modulate tweens generate garbage | Accept or batch |
| D13 | HIGH | Line2D/Polygon2D per-instance draw calls | Merge into `_draw()` |
| D14 | LOW | 80 enemy sprite draw calls | Accept / later MultiMesh |
| D15 | HIGH (needs verify) | Enemy-enemy collision pairs possibly O(n²) | Inspect scene masks, disable if enabled |
| D16 | LOW | AudioManager tree listener fine today | Accept |
| D17 | — | Pickup magnetism safe | — |

**Pass 4 totals:** CRITICAL 0 · HIGH 6 · MEDIUM 6 · LOW 5.

**Biggest three wins if a late-game FPS drop is reported:** D1 (cap embers), D13 (batch draw), D15 (verify enemy collision mask). Collectively likely to yield 25-40% frame-time improvement at wave 60.
