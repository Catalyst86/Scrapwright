# Godot 4 Bugs and Edge Cases Research

Compiled for: Scrapwright (2D pixel art arena survivors, GDScript, CharacterBody2D, NavigationAgent2D, Area2D, autoloads, scene transitions)

---

## 1. Bugs That Pass Code Review but Crash at Runtime

### 1a. Accessing freed nodes after queue_free()

`queue_free()` defers deletion to end-of-frame. Code that runs later in the same frame can still call methods on the node, but by the NEXT frame the reference is a freed instance.

```gdscript
# LOOKS FINE in code review:
func kill_enemy(enemy):
    enemy.queue_free()
    enemies.erase(enemy)
    update_enemy_count()  # OK this frame

# CRASHES next frame if anything still holds a ref:
func _physics_process(delta):
    for e in enemies:
        e.move_toward(player)  # "previously freed instance" if erase missed one
```

**Fix:** Always guard with `is_instance_valid()`, but know its limits (see section 6). Better: use `tree_exiting` signal to clean references proactively.

### 1b. is_instance_valid() can return true for WRONG objects

Godot reuses ObjectIDs. After freeing a node, `is_instance_valid(old_ref)` can return true because a newly created object occupies the same memory slot. This is a known engine issue (godotengine/godot#32383).

```gdscript
var cached_enemy = some_enemy
some_enemy.queue_free()
# ... later, after many instantiations ...
if is_instance_valid(cached_enemy):
    cached_enemy.take_damage(10)  # Might be calling on a DIFFERENT object
```

**Fix:** Null out references explicitly when freeing: `cached_enemy = null`.

### 1c. Freed Object boolean inconsistency

In Godot 4, `[Freed Object] == null` evaluates to `true`, but `if freed_obj:` still evaluates to `true`. This means simple truthiness checks do not catch freed objects.

```gdscript
# BROKEN pattern:
if target:           # True even if freed!
    target.attack()  # Crash

# CORRECT pattern:
if is_instance_valid(target):
    target.attack()
```

### 1d. preload() crashes the entire project on parse errors

`preload()` is evaluated at parse time. If the preloaded file has ANY error (even a typo in a dependent script), the entire project fails to boot with an opaque error.

```gdscript
# If enemy_rusher.tscn has a broken script attached:
const EnemyRusher = preload("res://scenes/enemies/enemy_rusher.tscn")  # PROJECT CRASH

# Safer:
var EnemyRusher = load("res://scenes/enemies/enemy_rusher.tscn")  # Fails gracefully, returns null
```

### 1e. NodePath hash collisions (fixed in 4.6.1)

NodePaths with different strings could hash to the same value, causing nodes to be confused at runtime. Patch 4.6.1 specifically addresses this.

---

## 2. Edge Cases That Only Trigger Under Specific Conditions

### 2a. Window resize freezes and permanent FPS drop

On Windows, dragging the window border for extended periods can freeze the game and permanently reduce FPS from 160+ down to 5-30 even after releasing. This is a known issue across Godot 4.0 through 4.6 (godotengine/godot#115568).

**Relevance to Scrapwright:** Your 480x270 viewport with 3x camera zoom is fine, but if players resize the window, FPS can tank and never recover until restart.

**Mitigation:**
```gdscript
# Lock window to fixed sizes or use exclusive fullscreen
DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_RESIZE_DISABLED, true)
# OR handle resize events:
func _notification(what):
    if what == NOTIFICATION_WM_SIZE_CHANGED:
        # Force re-render or reset viewport
        await get_tree().process_frame
```

### 2b. Alt-tab / unfocused window has no FPS cap

Exported projects have no FPS limit when unfocused or minimized. The game continues running at full speed, wasting CPU/GPU. There is no built-in setting for this (godotengine/godot-proposals#2001).

```gdscript
# Manual throttle when unfocused:
func _notification(what):
    if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
        Engine.max_fps = 10
    elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
        Engine.max_fps = 0  # Uncapped
```

### 2c. Low FPS causes physics desync with _process

If `_process()` handles input and `_physics_process()` handles movement, low FPS causes input to be processed multiple times per physics tick, or physics ticks to be skipped between visual frames.

```gdscript
# BAD: Mixing input in _process with movement in _physics_process
func _process(delta):
    if Input.is_action_just_pressed("throw"):
        throw_count += 1  # May fire multiple times at low FPS

# GOOD: Handle input in _physics_process or use _unhandled_input
func _unhandled_input(event):
    if event.is_action_pressed("throw"):
        throw_weapon()  # Fires exactly once per press
```

### 2d. move_and_slide() already applies delta internally

A very common bug: multiplying velocity by delta before calling `move_and_slide()` results in double-delta application, causing speed to vary with framerate.

```gdscript
# WRONG:
velocity = direction * speed * delta
move_and_slide()  # move_and_slide applies delta internally!

# CORRECT:
velocity = direction * speed
move_and_slide()

# You DO multiply delta for acceleration/deceleration:
velocity = velocity.move_toward(target_velocity, acceleration * delta)
move_and_slide()
```

---

## 3. Subtle GDScript Bugs That Look Correct

### 3a. Dictionary and Array are reference types (NOT copies)

```gdscript
var inv_a = {"iron": 5, "wood": 3}
var inv_b = inv_a          # Both point to SAME dictionary!
inv_b["iron"] = 0          # inv_a["iron"] is now 0 too!

# Fix:
var inv_b = inv_a.duplicate()       # Shallow copy
var inv_b = inv_a.duplicate(true)   # Deep copy (for nested dicts/arrays)
```

**Scrapwright relevance:** `GameState.materials` is a dictionary. If any code does `var mats = GameState.materials` and modifies `mats`, it modifies the global state. Always use `.duplicate()` for local copies.

### 3b. Modifying collections during iteration

```gdscript
# CRASHES or skips elements:
for enemy in enemies:
    if enemy.health <= 0:
        enemies.erase(enemy)  # Modifying array during iteration!

# Fix: Collect then remove
var dead = enemies.filter(func(e): return e.health <= 0)
for d in dead:
    enemies.erase(d)
    d.queue_free()
```

### 3c. Float precision: floor(-0.0) returns -1

```gdscript
# Surprise!
var x = -0.0
print(floor(x))  # Prints -1, not 0

# Vector comparison fails:
var a = Vector2(4.54, 0)
print(a.x < 4.54)  # Can print True due to float representation!

# Fix: Use is_equal_approx() or snapped()
if is_equal_approx(a.x, 4.54):
    pass

# For grid snapping:
var grid_pos = (position / cell_size).floor()  # Can give -1 at boundaries
var grid_pos = (position / cell_size + Vector2(0.001, 0.001)).floor()  # Safer
```

### 3d. Signal emission order is NOT guaranteed across nodes

If multiple nodes connect to the same signal, the order their callbacks execute is the order they connected, but this can change if nodes are freed and re-added. Never rely on callback ordering.

```gdscript
# DON'T rely on this executing in scene tree order:
WaveManager.wave_complete.connect(_on_wave_complete)  # HUD
WaveManager.wave_complete.connect(_on_wave_complete)  # Arena
# Which fires first? Depends on connection order, not tree order.
```

### 3e. ConfigFile loses float precision

```gdscript
# Saving:
config.set_value("stats", "multiplier", 1.414213562)
config.save("user://save.cfg")

# Loading back:
var val = config.get_value("stats", "multiplier")
# val might be 1.41421 (truncated!) - known issue godotengine/godot#82424
```

**Fix:** For precise floats, convert to string before saving, or multiply by a large integer and store as int.

### 3f. Enum string checking doesn't work as expected

```gdscript
enum Phase { PREP, COMBAT, SALVAGE }

# WRONG:
if "COMBAT" in Phase:  # Always false!

# CORRECT:
if "COMBAT" in Phase.keys():  # True
```

---

## 4. Export Bugs That Don't Appear in Editor

### 4a. Path case sensitivity changes on export

In the editor on Windows, `load("res://Assets/Sprites/player.png")` and `load("res://assets/sprites/player.png")` both work because Windows is case-insensitive. After export, paths become case-sensitive even on Windows (godotengine/godot#24107, #68230).

```gdscript
# Works in editor, FAILS in export:
var tex = load("res://Assets/Sprites/Player_Idle.png")

# Always use exact case matching your filesystem:
var tex = load("res://assets/sprites/player/player_idle.png")
```

**Scrapwright relevance:** All sprite loading in `player.gd` and `enemy_base.gd` must use exact-case paths matching the actual folder names.

### 4b. Missing .import files cause silent failures

The `.import/` directory contains Godot's processed versions of assets. If assets are added outside the editor (like via a Python script generating sprites), the `.import` files may not exist. The editor auto-generates them when it scans, but headless exports may not (godotengine/godot#69511).

**Fix:** After generating sprites, open the project in the Godot editor once before exporting to ensure all `.import` files are created.

### 4c. Resources referenced only by code are excluded from exports

If a scene or resource is never referenced in a `.tscn` file but only loaded via `load()` in code, the export may silently exclude it.

```gdscript
# This resource might be missing in export:
var scene = load("res://scenes/enemies/enemy_rusher.tscn")

# Fix: Add to export filters in project.godot:
# [export] resources_to_export = ["*.tscn", "*.tres", "*.png"]
# OR list specific paths in Export > Resources > Filters to export
```

### 4d. Debug vs Release behavior differences

- `assert()` statements are stripped in release builds. If your assert has side effects, they vanish:
  ```gdscript
  # BAD: side effect inside assert
  assert(initialize_system())  # In release, initialize_system() never runs!
  ```
- `print()` and `push_error()` still work in release but may have different performance characteristics
- `@tool` scripts behave differently in editor vs export

---

## 5. Race Conditions and Timing Bugs

### 5a. Scene change requires TWO process frames

`change_scene_to_file()` and `change_scene_to_packed()` change scene in a deferred way. The new scene is not available until after two `process_frame` signals (godotengine/godot#86286).

```gdscript
# BROKEN: Trying to access new scene immediately
get_tree().change_scene_to_file("res://scenes/arena.tscn")
var arena = get_tree().current_scene  # Still the OLD scene!

# CORRECT:
get_tree().change_scene_to_file("res://scenes/arena.tscn")
await get_tree().process_frame
await get_tree().process_frame
var arena = get_tree().current_scene  # NOW it's the new scene
```

### 5b. await + queue_free = ghost coroutine

If a node is queue_free'd while a coroutine is awaiting a timer, the coroutine can still run ONE more iteration (godotengine/godot#93608).

```gdscript
# In enemy_base.gd:
func flash_damage():
    modulate = Color.RED
    await get_tree().create_timer(0.1).timeout
    modulate = Color.WHITE  # Crashes if enemy was freed during the await!

# Fix: Guard after every await
func flash_damage():
    modulate = Color.RED
    await get_tree().create_timer(0.1).timeout
    if not is_instance_valid(self):
        return
    modulate = Color.WHITE
```

### 5c. Crash on scene exit when awaiting Timer

If a scene uses `await` on a Timer node and the scene is freed (via scene change or quit), the Timer is freed but the coroutine tries to resume, causing a crash (godotengine/godot#54572).

```gdscript
# DANGEROUS in any script that might be freed:
await get_tree().create_timer(2.0).timeout
do_something()  # Crash if scene changed during the 2 seconds

# SAFER:
var timer = get_tree().create_timer(2.0)
timer.timeout.connect(func():
    if is_instance_valid(self):
        do_something()
)
```

### 5d. @onready variables not ready when signals fire

If a parent node emits a signal in its `_ready()`, child nodes receiving that signal may not have their `@onready` variables initialized yet.

```gdscript
# Parent _ready fires BEFORE children are fully ready
# Child:
@onready var sprite = $Sprite2D

func _on_parent_signal():
    sprite.visible = false  # sprite is null! @onready not resolved yet
```

**Fix:** Use `await ready` or `call_deferred()` when emitting signals in `_ready()`.

### 5e. NavigationAgent2D first frame returns zero velocity

NavigationAgent2D needs one physics frame after setting `target_position` before it returns a valid path. On the first frame, `get_next_path_position()` returns the agent's current position.

```gdscript
# First frame bug:
func _physics_process(delta):
    nav_agent.target_position = player.global_position
    var next = nav_agent.get_next_path_position()
    var dir = global_position.direction_to(next)
    velocity = dir * speed  # First frame: dir is (0,0), enemy doesn't move

# Fix: Skip if no valid path yet
func _physics_process(delta):
    nav_agent.target_position = player.global_position
    if nav_agent.is_navigation_finished():
        return
    var next = nav_agent.get_next_path_position()
    # ...
```

---

## 6. Memory Leaks That Are Hard to Detect

### 6a. Orphaned nodes (not in tree, not freed)

Godot has no garbage collector. If you call `remove_child(node)` without `node.queue_free()`, the node stays in memory forever. Check the "Orphan Nodes" monitor in the debugger (should always be 0).

```gdscript
# LEAK:
var bullet = throwable_scene.instantiate()
add_child(bullet)
# ... later:
remove_child(bullet)  # Removed from tree but NOT freed!

# FIX:
bullet.queue_free()  # This both removes and frees
```

### 6b. await creates GDScriptFunctionState that can leak

Every `await` creates a GDScriptFunctionState object. If the awaited signal is never emitted (e.g., node freed before timer fires), the function state becomes an orphan (godotengine/godot#74449).

```gdscript
# LEAKS if this node is freed before 5 seconds:
await get_tree().create_timer(5.0).timeout

# Especially bad in enemy scripts that get queue_free'd mid-timer
```

**Scrapwright relevance:** Enemies using damage flash timers, death animations with awaits, or any coroutine-based effects will leak if the enemy is freed during the await.

### 6c. Signal connections prevent effective cleanup

Connecting a signal from an autoload (persistent) to a scene node (temporary) creates a reference. If the scene node is freed but the connection is not explicitly disconnected, Godot handles this gracefully for built-in signals, BUT lambdas connected to signals capture their closure scope:

```gdscript
# In arena.gd:
func _ready():
    WaveManager.wave_complete.connect(func(wave_num):
        $HUD.show_wave_text(wave_num)  # Lambda captures $HUD reference
    )
    # When arena scene is freed, the lambda still exists in WaveManager
    # and holds a reference to the freed $HUD node
```

**Fix:** Store the callable and disconnect explicitly:

```gdscript
var _wave_callback: Callable

func _ready():
    _wave_callback = _on_wave_complete
    WaveManager.wave_complete.connect(_wave_callback)

func _exit_tree():
    WaveManager.wave_complete.disconnect(_wave_callback)
```

### 6d. Autoload references to scene nodes

If an autoload (like GameState) stores a direct reference to a node in the current scene, that reference becomes invalid on scene change but the autoload still holds it.

```gdscript
# In GameState autoload:
var current_player: Node  # Set during arena, invalid after scene change

# Fix: Null it out on scene change
func _notification(what):
    if what == NOTIFICATION_WM_CLOSE_REQUEST:
        current_player = null
```

---

## 7. Bugs Triggered by Player Behavior

### 7a. Rapid input spam fires multiple throwables per frame

If `is_action_just_pressed()` is checked in `_process()`, at very high framerates it returns true only once. But at low framerates or with input buffering, rapid presses can stack.

```gdscript
# Needs a cooldown:
var throw_cooldown := 0.0

func _physics_process(delta):
    throw_cooldown -= delta
    if Input.is_action_just_pressed("throw") and throw_cooldown <= 0:
        throw_weapon()
        throw_cooldown = 0.2  # 200ms minimum between throws
```

### 7b. Pause/unpause on same key fires both in one frame

```gdscript
# BROKEN:
func _input(event):
    if event.is_action_pressed("pause"):
        get_tree().paused = !get_tree().paused
        # If the node's process_mode is ALWAYS, this toggles twice!

# FIX: Consume the event
func _unhandled_input(event):
    if event.is_action_pressed("pause"):
        get_tree().paused = !get_tree().paused
        get_viewport().set_input_as_handled()
```

Also: the pause menu node must have `process_mode = PROCESS_MODE_ALWAYS` or `PROCESS_MODE_WHEN_PAUSED` to receive input while paused.

### 7c. Mashing interact during scene transitions

If the player spams the interact key during a scene transition (e.g., entering base hub from arena), the interaction can fire on the OLD scene's nodes that are being freed.

```gdscript
# DANGEROUS:
func _on_salvage_complete():
    get_tree().change_scene_to_file("res://scenes/base_hub.tscn")

func _unhandled_input(event):
    if event.is_action_pressed("interact"):
        salvage_target.interact()  # salvage_target may be freed!

# FIX: Lock input during transitions
var transitioning := false

func _on_salvage_complete():
    transitioning = true
    get_tree().change_scene_to_file("res://scenes/base_hub.tscn")

func _unhandled_input(event):
    if transitioning:
        return
    if event.is_action_pressed("interact") and is_instance_valid(salvage_target):
        salvage_target.interact()
```

### 7d. Area2D overlap detection is 1-2 frames late

When an Area2D is instantiated (e.g., spawning a throwable), its `body_entered` and `area_entered` signals do not fire for 1-2 physics frames (godotengine/godot#38983). Fast-moving projectiles can pass through enemies entirely.

```gdscript
# If throwable moves too fast, it passes through enemy hitbox in one frame

# Mitigations:
# 1. Use raycasting for fast projectiles instead of Area2D overlap
# 2. Increase physics tick rate: Engine.physics_ticks_per_second = 120
# 3. Use ShapeCast2D for continuous collision detection
# 4. Clamp max velocity so projectile can't skip over targets
```

### 7e. NavigationAgent2D path jitter from rapid target changes

If the player moves erratically (WASD spam), enemies constantly recalculate paths, causing visible jittering and stuttering.

```gdscript
# Fix: Only recalculate path every N frames or when target moves significantly
var last_target_pos := Vector2.ZERO

func _physics_process(delta):
    var player_pos = player.global_position
    if player_pos.distance_to(last_target_pos) > 32:  # Only re-path if player moved far enough
        nav_agent.target_position = player_pos
        last_target_pos = player_pos
```

### 7f. Keyboard input ignored while paused (only mouse motion detected)

When `get_tree().paused = true`, `_input()` and `_unhandled_input()` only receive mouse motion events by default. Keyboard and mouse button events are dropped unless the receiving node has the correct `process_mode` (godotengine/godot#97054).

```gdscript
# Pause menu must have:
# process_mode = Node.PROCESS_MODE_ALWAYS
# AND be the one handling input (not a child with INHERIT mode)
```

---

## 8. NavigationAgent2D-Specific Pitfalls (Relevant to Enemy AI)

### 8a. Navigation mesh must be baked AFTER setting the polygon

```gdscript
# WRONG order:
nav_region.bake_navigation_polygon()
nav_region.navigation_polygon = my_polygon  # Bake used old/empty polygon!

# CORRECT:
nav_region.navigation_polygon = my_polygon
nav_region.bake_navigation_polygon()
# AND wait one frame before agents can use it
await get_tree().physics_frame
```

### 8b. Cell size mismatch causes merge errors

If the NavigationPolygon's `cell_size` doesn't match the NavigationServer's cell size, you get "Attempted to merge a navigation mesh polygon edge with another already-merged edge" errors and pathfinding breaks silently.

### 8c. velocity_computed signal returns (0,0) with avoidance

When using NavigationAgent2D with avoidance enabled, the `velocity_computed` signal can return Vector2.ZERO even when velocity is set correctly (godotengine/godot#88648). This completely stops enemy movement.

**Fix:** If avoidance isn't critical for your game, disable it. For a survivors game with many enemies, avoidance is usually too expensive anyway.

---

## Summary: Top 10 Most Likely to Hit Scrapwright

1. **Dictionary reference aliasing** in GameState.materials (section 3a)
2. **await + queue_free ghost coroutines** in enemy death effects (section 5b)
3. **Area2D overlap 1-2 frame delay** on throwable hits (section 7d)
4. **Input during scene transitions** causing freed-node access (section 7c)
5. **Path case sensitivity on export** for sprite loading (section 4a)
6. **Orphaned nodes from remove_child without queue_free** (section 6a)
7. **Signal connections from autoloads to scene nodes** leaking (section 6c)
8. **move_and_slide double-delta** speed bug (section 2d)
9. **NavigationAgent2D first-frame zero velocity** (section 5e)
10. **Modifying enemy array during iteration** when killing enemies (section 3b)

---

## Sources

- [Godot Issue #115568: Window resize FPS drop](https://github.com/godotengine/godot/issues/115568)
- [Godot Issue #24107: Path case sensitivity on export](https://github.com/godotengine/godot/issues/24107)
- [Godot Issue #68230: Case sensitive paths in exported GDScript](https://github.com/godotengine/godot/issues/68230)
- [Godot Issue #86286: change_scene needs two process frames](https://github.com/godotengine/godot/issues/86286)
- [Godot Issue #93608: queue_free with async coroutine timing](https://github.com/godotengine/godot/issues/93608)
- [Godot Issue #54572: Crash on scene exit with await Timer](https://github.com/godotengine/godot/issues/54572)
- [Godot Issue #74449: await GDScriptFunctionState leaks](https://github.com/godotengine/godot/issues/74449)
- [Godot Issue #38983: Area2D overlap one frame late](https://github.com/godotengine/godot/issues/38983)
- [Godot Issue #32383: Reference to freed object points to different one](https://github.com/godotengine/godot/issues/32383)
- [Godot Issue #82424: ConfigFile float precision loss](https://github.com/godotengine/godot/issues/82424)
- [Godot Issue #88648: NavigationAgent2D velocity_computed returns zero](https://github.com/godotengine/godot/issues/88648)
- [Godot Issue #97054: Input only detects mouse motion when paused](https://github.com/godotengine/godot/issues/97054)
- [Godot Issue #69511: Headless export import problems](https://github.com/godotengine/godot/issues/69511)
- [Godot Issue #86317: Exported game crashes on missing resources](https://github.com/godotengine/godot/issues/86317)
- [Godot Proposals #2001: FPS limit for unfocused windows](https://github.com/godotengine/godot-proposals/issues/2001)
- [Godot Docs: process vs physics_process](https://docs.godotengine.org/en/stable/tutorials/scripting/idle_and_physics_processing.html)
- [Godot Docs: Pausing games](https://docs.godotengine.org/en/stable/tutorials/scripting/pausing_games.html)
- [Godot Docs: Singletons/Autoload](https://docs.godotengine.org/en/stable/tutorials/scripting/singletons_autoload.html)
- [Godot Docs: Multiple resolutions](https://docs.godotengine.org/en/stable/tutorials/rendering/multiple_resolutions.html)
- [GDScript float issues discussion](https://godotforums.org/d/27697-gdscript-floats-are-weird-and-buggy)
- [Godot 4.6.1 crash fixes](https://www.linuxcompatible.org/story/fixes-crashes-and-keeps-your-projects-alive/)
