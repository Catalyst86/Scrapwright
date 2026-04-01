# Godot 4.x GDScript Code Audit Research Notes

Compiled for the Scrapwright project audit. Each section covers specific patterns, code smells, and gotchas to check for during the audit, with buggy code examples and fixes.

---

## 1. Most Common Godot 4.x GDScript Bugs and Crashes

### 1.1 Null / Nil Access ("Invalid get index on base: 'Nil'")

The single most common crash in GDScript projects. Happens when code accesses a property or method on a value that is `null`.

**Buggy pattern -- accessing a node that may not exist:**
```gdscript
@onready var target = get_tree().get_first_node_in_group("Player")

func _process(delta):
    var dir = global_position.direction_to(target.global_position)  # CRASH if target is null
```

**Fix -- null guard:**
```gdscript
func _process(delta):
    if target == null:
        return
    var dir = global_position.direction_to(target.global_position)
```

**Buggy pattern -- dictionary key assumed present:**
```gdscript
var data = some_dict["missing_key"]  # CRASH: invalid get index
```

**Fix -- use .get() with a default:**
```gdscript
var data = some_dict.get("missing_key", 0)
```

### 1.2 Freed Object Access (Use-After-Free)

Happens when a reference to a node outlives the node itself (e.g., enemy freed but still referenced by a projectile or signal callback).

**Buggy pattern:**
```gdscript
var cached_enemy: Node2D  # set somewhere

func _process(delta):
    var dist = global_position.distance_to(cached_enemy.global_position)
    # CRASH if cached_enemy was queue_free()'d
```

**Fix -- validity check:**
```gdscript
func _process(delta):
    if not is_instance_valid(cached_enemy):
        cached_enemy = null
        return
    var dist = global_position.distance_to(cached_enemy.global_position)
```

Note: `is_instance_valid()` is considered a "bandaid" by the community. Prefer architectures where references are cleaned up proactively (e.g., listen for `tree_exiting` signal on the target node).

**Better pattern -- clean up references when the target exits:**
```gdscript
func set_target(node: Node2D) -> void:
    if cached_enemy and cached_enemy.tree_exiting.is_connected(_on_target_freed):
        cached_enemy.tree_exiting.disconnect(_on_target_freed)
    cached_enemy = node
    if cached_enemy:
        cached_enemy.tree_exiting.connect(_on_target_freed)

func _on_target_freed() -> void:
    cached_enemy = null
```

### 1.3 Signal Connection Errors

**"Signal already connected" error:**
```gdscript
func _ready():
    some_signal.connect(_handler)
    # Called again on re-entering tree -- CRASH
```

**Fix -- guard connection:**
```gdscript
func _ready():
    if not some_signal.is_connected(_handler):
        some_signal.connect(_handler)
```

**One-shot signals not disconnecting before emission (known Godot bug):**
Connecting a signal with `CONNECT_ONE_SHOT` and then reconnecting in the callback can fail because the disconnect happens after the callback runs, not before.

**Fix -- manually disconnect:**
```gdscript
func _on_callback():
    if my_signal.is_connected(_on_callback):
        my_signal.disconnect(_on_callback)
    # Now safe to reconnect
    my_signal.connect(_on_callback, CONNECT_ONE_SHOT)
```

**Freed node still receiving signals:**
When a node is freed but a signal emitter still holds a reference to its callback, the signal emission can crash.

**Fix -- disconnect in `_exit_tree()`:**
```gdscript
func _exit_tree():
    if emitter_node and emitter_node.my_signal.is_connected(_my_handler):
        emitter_node.my_signal.disconnect(_my_handler)
```

### 1.4 Typing Errors and Unsafe Casts

**Buggy -- untyped code catches errors too late:**
```gdscript
var speed = "100"  # Accidentally a string
func _process(delta):
    position.x += speed * delta  # Runtime error, not caught at parse time
```

**Fix -- static typing:**
```gdscript
var speed: float = 100.0
func _process(delta: float) -> void:
    position.x += speed * delta  # Type mismatch caught by editor
```

### 1.5 queue_free() Timing Issues

`queue_free()` does not free the node immediately -- it marks it for deletion at the end of the frame. Code that runs after `queue_free()` within the same frame can still access the node.

**Buggy -- modifying scene tree in a signal callback:**
```gdscript
func _on_enemy_died():
    enemy.queue_free()
    get_tree().change_scene_to_file("res://win.tscn")
    # ERROR: "can't change scene during signal"
```

**Fix -- use call_deferred:**
```gdscript
func _on_enemy_died():
    enemy.queue_free()
    get_tree().change_scene_to_file.bind("res://win.tscn").call_deferred()
```

---

## 2. Scene Tree _ready() Order and Initialization Bugs

### 2.1 _ready() Execution Order

**Critical rule: Children are ready BEFORE their parent.**

The scene tree processes `_ready()` in reverse depth-first order:
1. Leaf children call `_ready()` first
2. Parent nodes call `_ready()` after ALL children are ready
3. Autoloads are ready before any scene nodes

**Buggy pattern -- child emits signal in _ready(), parent handler uses @onready var:**
```gdscript
# child.gd
func _ready():
    my_signal.emit()  # Fires BEFORE parent's _ready()

# parent.gd
@onready var label = $Label  # Not yet initialized when child's signal fires!

func _on_child_signal():
    label.text = "Hello"  # CRASH: label is null
```

**Fix -- defer the signal or connect after ready:**
```gdscript
# child.gd
func _ready():
    my_signal.emit.call_deferred()  # Waits until parent is also ready
```

### 2.2 @onready Initialization Timing

`@onready` variables are assigned just before `_ready()` runs, but AFTER `_enter_tree()`.

**Buggy -- accessing @onready in _enter_tree:**
```gdscript
@onready var sprite: Sprite2D = $Sprite2D

func _enter_tree():
    sprite.modulate = Color.RED  # CRASH: sprite is null, @onready hasn't run yet
```

**Fix -- move logic to _ready():**
```gdscript
func _ready():
    sprite.modulate = Color.RED  # Safe: @onready has been assigned
```

### 2.3 Autoload Timing

Autoloads are added to the scene tree before any other scenes. They call `_ready()` in the order they are listed in Project Settings.

**Buggy -- autoload B depends on autoload A, but A is listed after B:**
```gdscript
# autoload_b.gd
func _ready():
    AutoloadA.do_setup()  # CRASH if AutoloadA isn't ready yet
```

**Fix -- ensure correct autoload order in Project Settings, or use call_deferred:**
```gdscript
func _ready():
    AutoloadA.do_setup.call_deferred()
```

### 2.4 Deferred Calls During Initialization

**Buggy -- adding nodes during _ready() of another node:**
```gdscript
func _ready():
    var child = preload("res://child.tscn").instantiate()
    get_parent().add_child(child)  # May crash if parent is still processing tree
```

**Fix -- defer the add_child:**
```gdscript
func _ready():
    var child = preload("res://child.tscn").instantiate()
    get_parent().add_child.call_deferred(child)
```

### 2.5 Node Lifecycle Callback Order

Full order for reference:
1. `_init()` -- object constructed (no scene tree yet)
2. `_enter_tree()` -- added to scene tree (children may not be ready)
3. `@onready` vars assigned
4. `_ready()` -- all children are ready, node is fully initialized
5. `_process()` / `_physics_process()` -- frame callbacks begin
6. `_exit_tree()` -- removed from scene tree
7. `_notification(NOTIFICATION_PREDELETE)` -- about to be freed

---

## 3. GDScript Anti-Patterns and Pitfalls

### 3.1 Uncached get_node() / $ in Hot Paths

**Buggy -- tree traversal every frame:**
```gdscript
func _process(delta):
    $Sprite2D.rotation += delta  # Traverses tree 60x/sec
    $UI/HealthBar.value = health  # Another traversal
```

**Fix -- cache with @onready:**
```gdscript
@onready var sprite: Sprite2D = $Sprite2D
@onready var health_bar: ProgressBar = $UI/HealthBar

func _process(delta):
    sprite.rotation += delta
    health_bar.value = health
```

### 3.2 @onready + @export Conflict

Combining `@onready` with `@export` is flagged as an error (ONREADY_WITH_EXPORT). The `@export` value from the Inspector would be overwritten by the `@onready` assignment.

**Buggy:**
```gdscript
@export @onready var target: Node2D = $Target  # ERROR / unexpected behavior
```

**Fix -- use one or the other:**
```gdscript
@export var target: Node2D  # Set in Inspector
# OR
@onready var target: Node2D = $Target  # Set by code
```

### 3.3 Typed Array Coercion with $ (get_node)

`$NodeName` returns `Node`, not the specific type. Typed arrays reject the wrong type.

**Buggy:**
```gdscript
var enemies: Array[CharacterBody2D] = [$Enemy1, $Enemy2]
# ERROR: Cannot assign Node to Array[CharacterBody2D]
```

**Fix -- cast explicitly:**
```gdscript
var enemies: Array[CharacterBody2D] = [$Enemy1 as CharacterBody2D, $Enemy2 as CharacterBody2D]
```

### 3.4 Cyclic References

Godot does NOT handle cyclic references gracefully:
- Two scripts that `preload()` each other will crash the project on load
- Resources that reference each other via arrays crash the editor
- Export vars with PackedScene references can create hidden cycles

**Buggy -- mutual preload:**
```gdscript
# a.gd
const B = preload("res://b.gd")

# b.gd
const A = preload("res://a.gd")  # CYCLIC: project fails to load
```

**Fix -- use load() at runtime or use a dependency injection pattern:**
```gdscript
# b.gd
var A  # Assigned at runtime
func _ready():
    A = load("res://a.gd")
```

### 3.5 Misusing Enums

**Buggy -- checking if a string is in an enum:**
```gdscript
enum State { IDLE, MOVING, DEAD }

if "IDLE" in State:  # Does NOT work in GDScript 4
    pass
```

**Fix -- use .keys():**
```gdscript
if "IDLE" in State.keys():
    pass
```

### 3.6 Signals Wired in the Wrong Direction

Common mistake: connecting a parent signal to a child handler when the child should emit and the parent should listen.

**Anti-pattern -- parent reaches into child internals:**
```gdscript
# parent.gd
func _ready():
    $Child.some_internal_method()  # Tight coupling
```

**Better -- child emits, parent listens:**
```gdscript
# child.gd
signal action_completed
func do_action():
    action_completed.emit()

# parent.gd
func _ready():
    $Child.action_completed.connect(_on_child_action)
```

### 3.7 Theme Override Syntax

**Buggy (Godot 4.x):**
```gdscript
label.theme_override_font_sizes = {"font_size": 12}  # WRONG -- property doesn't exist
```

**Fix:**
```gdscript
label.add_theme_font_size_override("font_size", 12)
```

---

## 4. Performance Optimization Best Practices

### 4.1 _physics_process vs _process

- `_process(delta)` runs every rendered frame (variable rate)
- `_physics_process(delta)` runs at fixed physics tick rate (default 60/sec)

**Rule:** Movement/physics logic goes in `_physics_process`. Visual-only updates (animation, particles, UI) go in `_process`. Never mix them.

**Buggy -- physics in _process:**
```gdscript
func _process(delta):
    move_and_slide()  # Framerate-dependent physics! Jitter on fast/slow machines
```

**Fix:**
```gdscript
func _physics_process(delta):
    move_and_slide()
```

### 4.2 Per-Frame Allocations

Creating new objects every frame causes GC spikes.

**Buggy -- new array every frame:**
```gdscript
func _process(delta):
    var nearby = []  # Allocated every frame
    for enemy in get_tree().get_nodes_in_group("enemies"):
        if global_position.distance_to(enemy.global_position) < 100:
            nearby.append(enemy)
```

**Fix -- reuse the array:**
```gdscript
var nearby: Array = []

func _process(delta):
    nearby.clear()  # Reuse, don't reallocate
    for enemy in get_tree().get_nodes_in_group("enemies"):
        if global_position.distance_to(enemy.global_position) < 100:
            nearby.append(enemy)
```

### 4.3 String Concatenation in Loops

GDScript String concatenation has pathological O(n^2) performance due to copy-on-write semantics.

**Buggy:**
```gdscript
var log_text: String = ""
for i in range(1000):
    log_text += "Entry %d\n" % i  # Gets exponentially slower
```

**Fix -- use PackedStringArray:**
```gdscript
var parts: PackedStringArray = []
for i in range(1000):
    parts.append("Entry %d\n" % i)
var log_text = "\n".join(parts)
```

### 4.4 Object Pooling

Instantiating and freeing nodes every frame (e.g., bullets, particles) is expensive.

**Anti-pattern:**
```gdscript
func shoot():
    var bullet = bullet_scene.instantiate()
    add_child(bullet)  # Every shot creates a new node

# In bullet:
func _on_lifetime_expired():
    queue_free()  # Freed, then re-instantiated next shot
```

**Better -- pool:**
```gdscript
var bullet_pool: Array[Node2D] = []

func _ready():
    for i in 20:
        var b = bullet_scene.instantiate()
        b.visible = false
        b.set_process(false)
        add_child(b)
        bullet_pool.append(b)

func get_bullet() -> Node2D:
    for b in bullet_pool:
        if not b.visible:
            b.visible = true
            b.set_process(true)
            return b
    return null  # Pool exhausted
```

### 4.5 Disable Processing on Inactive Nodes

**Anti-pattern -- all enemies run _process even when off-screen:**
```gdscript
func _process(delta):
    # AI logic runs even if player is far away
    navigate_to_player()
```

**Fix -- toggle processing:**
```gdscript
set_process(false)  # Disable when not needed
set_process(true)   # Re-enable when visible/nearby
set_physics_process(false)  # Same for physics
```

### 4.6 Node Count

Every node in the tree has overhead. Deeply nested hierarchies slow down frame processing.

**Audit check:** Look for scenes with excessive nesting (>10 levels deep) or excessive node counts (>1000 active nodes). Flatten where possible.

### 4.7 Signal vs Polling

**Anti-pattern -- polling every frame:**
```gdscript
func _process(delta):
    if GameState.current_phase != _last_phase:
        _last_phase = GameState.current_phase
        _on_phase_changed()
```

**Better -- use a signal:**
```gdscript
func _ready():
    GameState.phase_changed.connect(_on_phase_changed)
```

### 4.8 get_nodes_in_group() in Hot Paths

`get_nodes_in_group()` creates a new array every call.

**Buggy:**
```gdscript
func _physics_process(delta):
    for e in get_tree().get_nodes_in_group("enemies"):  # New array every tick
        check_distance(e)
```

**Fix -- cache or use signals:**
```gdscript
var enemies: Array = []

func _ready():
    get_tree().node_added.connect(_on_node_added)
    get_tree().node_removed.connect(_on_node_removed)

func _on_node_added(node: Node):
    if node.is_in_group("enemies"):
        enemies.append(node)

func _on_node_removed(node: Node):
    enemies.erase(node)
```

---

## 5. Resource and Memory Leak Patterns

### 5.1 Orphaned Nodes

Instantiated nodes that are never added to the tree and never freed become orphans.

**Buggy:**
```gdscript
func spawn_enemy():
    var e = enemy_scene.instantiate()
    # Forgot add_child(e) -- orphan! Never freed.
    # Or: conditional add_child that sometimes doesn't run
    if some_condition:
        add_child(e)
    # If condition is false, e leaks
```

**Fix -- always free if not adding:**
```gdscript
func spawn_enemy():
    var e = enemy_scene.instantiate()
    if some_condition:
        add_child(e)
    else:
        e.queue_free()
```

**Audit check:** In the Godot debugger, Monitors > Orphan Nodes should read 0 during gameplay.

### 5.2 preload() vs load()

`preload()` is resolved at parse time. If the path is wrong or the resource has errors, the entire script fails to load.

**Risks of preload:**
- Cyclic preload chains crash the project
- Missing files crash at project open, not just at scene load
- All preloaded resources stay in memory for the lifetime of the script

**When to use load():**
- Resources loaded conditionally
- Resources that may not exist
- Breaking cyclic dependency chains

```gdscript
# Safe -- load() at runtime
var effect_scene = load("res://scenes/effect.tscn")

# Risky -- preload() at parse time
const EFFECT = preload("res://scenes/effect.tscn")  # Crash if file missing
```

### 5.3 Circular References Preventing GC

GDScript uses reference counting. Two RefCounted objects referencing each other will never reach refcount 0.

**Buggy:**
```gdscript
class_name ComponentA extends RefCounted
var partner: ComponentB  # Holds reference

class_name ComponentB extends RefCounted
var partner: ComponentA  # Holds reference -- CYCLE, neither is ever freed
```

**Fix -- use WeakRef or break the cycle manually:**
```gdscript
class_name ComponentB extends RefCounted
var partner_ref: WeakRef

func set_partner(a: ComponentA):
    partner_ref = weakref(a)

func get_partner() -> ComponentA:
    return partner_ref.get_ref() as ComponentA
```

### 5.4 PackedScene Instantiation Without Freeing

Every `instantiate()` call creates a new node. If scenes are instantiated in loops without being freed, memory grows unboundedly.

**Audit check:** Search for all `.instantiate()` calls and verify each has a corresponding `queue_free()` or `free()` path.

### 5.5 Autoload Singletons Accumulating Data

Autoloads persist across scene changes. If they store arrays/dictionaries that grow (e.g., tracking spawned enemies, collected items) without being cleared, memory leaks over time.

**Audit check:** Review all autoload scripts for growing collections. Ensure they are cleared during `start_new_run()` or equivalent reset functions.

---

## 6. .tscn and .tres File Common Errors

### 6.1 Broken Resource Paths

Moving files outside the Godot editor breaks paths in .tscn and .tres files.

**What to look for in .tscn files:**
```
[ext_resource type="Script" path="res://scripts/old_path/player.gd" ...]
```
If the file was moved, this path is stale.

**Audit check:** Grep all .tscn/.tres files for `ext_resource` paths and verify each path exists on disk.

### 6.2 UID Mismatches

Godot 4.4+ uses UIDs to track resources. Moving files outside the editor breaks the UID mapping.

**Symptoms:**
```
WARNING: res://scene.tscn:4 - ext_resource, invalid UID: uid://abc123 - using text path instead
```

**Fix:** Open each affected .tscn in the editor and re-save. Or use regex to strip broken UIDs and let Godot regenerate them.

**Audit check:** Grep for `uid://` in all .tscn/.tres files and check for warnings on project open.

### 6.3 Missing Scripts

If a .tscn references a script that has been deleted or renamed:
```
[ext_resource type="Script" path="res://scripts/deleted_script.gd" id="1"]
```
Godot shows confusing error messages ("Failed to load resource", "Invalid type", etc.).

**Audit check:** For every `type="Script"` in .tscn files, verify the script file exists.

### 6.4 Sub-Resource Shape Errors

Inline collision shapes must use `[sub_resource]` blocks, not inline constructors.

**Buggy .tscn:**
```
shape = CircleShape2D(radius=8.0)  # INVALID
```

**Correct .tscn:**
```
[sub_resource type="CircleShape2D" id="CircleShape2D_abc"]
radius = 8.0

[node name="Collision" type="CollisionShape2D"]
shape = SubResource("CircleShape2D_abc")
```

### 6.5 Hand-Written UIDs

Never manually write `uid="uid://..."` in .tscn files. Godot assigns these internally, and conflicts cause resource loading failures.

### 6.6 Merge Conflicts in .tscn

Text-based .tscn files are prone to git merge conflicts. A bad merge can produce invalid serialization (broken `[node]` blocks, duplicate IDs, etc.).

**Audit check:** After any merge, open every modified .tscn in the editor and verify it loads without errors.

---

## 7. Export and Shipping Bugs to Check Before Release

### 7.1 Case Sensitivity

**Critical:** Windows is case-insensitive, Linux/macOS/Android/Web are case-sensitive.

`preload("res://Scripts/Player.gd")` works on Windows but CRASHES on Linux if the actual path is `res://scripts/player.gd`.

**Audit check:** Grep all .gd and .tscn files for `res://` paths. Verify exact case matches against the filesystem. Enable the editor warning "Case mismatch" and treat it as an error.

### 7.2 Missing Autoloads in Export

When using "Export selected scenes and dependencies", autoload files may be missed.

**Audit check:** Verify all autoloads listed in project.godot are included in the export. Test the exported build to confirm autoloads initialize.

### 7.3 Input Map Gaps

Actions defined in the Input Map that reference keys or buttons not available on all platforms.

**Audit check:** Review project.godot `[input]` section. Ensure every action has both keyboard and gamepad bindings if targeting controllers. Ensure no actions are referenced in code but missing from the input map.

### 7.4 res:// vs user:// Path Confusion

`res://` is read-only in exported builds. Attempting to write to `res://` silently fails.

**Buggy:**
```gdscript
var file = FileAccess.open("res://save.dat", FileAccess.WRITE)  # FAILS in export
```

**Fix:**
```gdscript
var file = FileAccess.open("user://save.dat", FileAccess.WRITE)
```

### 7.5 Missing Imports

Files in the project folder that have not been imported (no .import file) will be missing in the exported build.

**Audit check:** Verify that every asset referenced in code or .tscn files has a corresponding .import file in the project.

### 7.6 Debug-Only Code Left In

```gdscript
func _ready():
    OS.window_title = "DEBUG BUILD"  # Left in release!
    print("Debug: spawning enemies")  # Print statements slow down release
```

**Audit check:** Search for `print(`, `OS.window_title`, `breakpoint`, and `assert(` calls. Either remove or guard with `if OS.is_debug_build()`.

### 7.7 Export Template Version Mismatch

The export template version must match the editor version exactly. A mismatch causes cryptic export failures.

### 7.8 .gdignore Blocking Required Assets

A `.gdignore` file in a directory prevents Godot from importing anything in that directory. If placed incorrectly, required assets will be silently excluded from the export.

---

## 8. GDScript Static Analysis Techniques

### 8.1 Built-In Warning System

Godot 4's GDScript editor has built-in warnings. Key warnings to enable/escalate to errors:

| Warning | What It Catches |
|---|---|
| `UNUSED_VARIABLE` | Variables declared but never read |
| `UNUSED_PARAMETER` | Function parameters never used |
| `UNUSED_SIGNAL` | Signals declared but never emitted |
| `SHADOWED_VARIABLE` | Local var shadows a member or parent var |
| `SHADOWED_VARIABLE_BASE_CLASS` | Local var shadows a base class member |
| `SHADOWED_GLOBAL_IDENTIFIER` | Local var shadows a global (e.g., `position`) |
| `UNREACHABLE_CODE` | Code after return/break/continue |
| `UNREACHABLE_PATTERN` | Match pattern that can never be reached |
| `RETURN_VALUE_DISCARDED` | Function return value ignored |
| `STANDALONE_EXPRESSION` | Expression with no side effect |
| `UNTYPED_DECLARATION` | Variables/params without type hints |
| `INFERRED_DECLARATION` | Type inferred but not explicit |
| `UNSAFE_PROPERTY_ACCESS` | Property access on Variant type |
| `UNSAFE_METHOD_ACCESS` | Method call on Variant type |
| `UNSAFE_CAST` | Cast that could fail at runtime |
| `UNSAFE_CALL_ARGUMENT` | Argument type doesn't match parameter type |
| `INCOMPATIBLE_TERNARY` | Ternary branches return different types |
| `STANDALONE_TERNARY` | Ternary expression used as statement with no effect |

**How to enable all as errors in project.godot:**
```ini
[debug]
gdscript/warnings/unused_variable=2
gdscript/warnings/shadowed_variable=2
gdscript/warnings/unreachable_code=2
gdscript/warnings/return_value_discarded=2
gdscript/warnings/untyped_declaration=2
; 0 = ignore, 1 = warn, 2 = error
```

### 8.2 Per-Line Warning Suppression

```gdscript
@warning_ignore("unused_variable")
var _temp = some_function()

@warning_ignore("return_value_discarded")
some_array.sort()
```

### 8.3 External Linting Tools

- **gdtoolkit (gdlint):** Python-based linter/formatter. Install via `pip install gdtoolkit`. Supports CI/CD integration.
- **Godot GDScript Linter (Asset Library #4612):** In-editor static analysis with clickable navigation to issues.

### 8.4 Manual Dead Code Detection Checklist

1. Search for functions that are never called (no `call(`, no signal connection, not referenced in .tscn)
2. Search for `match` branches that overlap or are unreachable
3. Search for variables assigned but never read
4. Search for signals declared with `signal` keyword but never `emit()`ed
5. Search for `if` branches with constant conditions (`if true:`, `if false:`)
6. Check for classes defined with `class_name` but never referenced outside their file

### 8.5 Type Safety Audit

Check for:
- Variables declared without type hints (`:` or `:=`)
- Function parameters without types
- Functions without return type annotations
- Use of `Variant` where a specific type is known
- Implicit conversions (int to float, etc.)

---

## 9. Shader and Material Common Mistakes

### 9.1 SCREEN_TEXTURE Removal (Godot 4.0+ Migration)

**Buggy -- Godot 3 syntax:**
```glsl
vec4 screen_color = texture(SCREEN_TEXTURE, SCREEN_UV);  // ERROR in Godot 4
```

**Fix -- Godot 4 syntax:**
```glsl
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

void fragment() {
    vec4 screen_color = texture(screen_texture, SCREEN_UV);
}
```

### 9.2 Uniform Type Mismatches

**Buggy -- setting a float uniform with an int from GDScript:**
```gdscript
material.set_shader_parameter("speed", 5)  # Int, but shader expects float
```

**Fix:**
```gdscript
material.set_shader_parameter("speed", 5.0)  # Explicit float
```

### 9.3 Global Uniforms Cannot Be Textures

Global shader uniforms only support scalar and vector types (float, int, vec2, vec3, vec4, Color). They do NOT support Texture2D.

**Audit check:** Verify no global uniform is expected to carry a texture.

### 9.4 Instance Uniform Type Conflicts

When a mesh uses multiple materials, instance uniform parameters must have the same name, index, AND type across all materials. Type mismatches cause the first material's value to "win" silently.

### 9.5 Missing Textures

If a shader uniform of type `sampler2D` has no texture assigned, it samples a default white texture. This can cause subtle visual bugs (e.g., a normal map defaulting to white instead of flat blue).

**Audit check:** Search for shader materials with unassigned texture uniforms.

### 9.6 Visual Shader Limitations

Visual Shaders may lack certain hints available in written shaders (e.g., scalar uniform hints). If advanced features are needed, prefer code-based shaders.

### 9.7 CanvasItem Shader Gotchas for 2D Games

For pixel art games with viewport scaling:
- Use `texture_filter = nearest` on materials/project settings, not in the shader
- `VERTEX` in canvas_item shaders is in local space, not screen space
- Modifying `COLOR` in a canvas_item shader affects the final output after texture sampling

---

## 10. Input Handling Bugs

### 10.1 is_action_pressed vs is_action_just_pressed

| Method | Behavior |
|---|---|
| `Input.is_action_pressed("jump")` | Returns `true` EVERY FRAME the key is held |
| `Input.is_action_just_pressed("jump")` | Returns `true` only on the FIRST frame |
| `Input.is_action_just_released("jump")` | Returns `true` only on the RELEASE frame |

**Buggy -- using pressed instead of just_pressed for one-shot actions:**
```gdscript
func _process(delta):
    if Input.is_action_pressed("interact"):
        open_door()  # Called 60x/sec while key held! Opens door repeatedly
```

**Fix:**
```gdscript
func _process(delta):
    if Input.is_action_just_pressed("interact"):
        open_door()  # Called exactly once per keypress
```

### 10.2 is_action_just_pressed Dropping Inputs at Low Framerates

Known Godot bug: `Input.is_action_just_pressed()` can miss inputs when running at low framerates because the press-and-release can happen between frames.

**Workaround -- use _unhandled_input() for critical one-shot inputs:**
```gdscript
func _unhandled_input(event: InputEvent):
    if event.is_action_pressed("jump"):
        jump()  # Never misses -- runs on event, not on frame
```

### 10.3 Input Event Propagation Order

Godot processes input in this order:
1. `_input()` -- all nodes, reverse tree order (children first)
2. `_gui_input()` -- Control nodes only
3. `_shortcut_input()` -- shortcut-specific handling
4. `_unhandled_key_input()` -- keyboard only, unhandled
5. `_unhandled_input()` -- all unhandled events

**Buggy -- using _input() for game actions that should be blocked by UI:**
```gdscript
# player.gd
func _input(event):
    if event.is_action_pressed("shoot"):
        shoot()  # Fires even when clicking a UI button!
```

**Fix -- use _unhandled_input() so UI consumes the event first:**
```gdscript
func _unhandled_input(event: InputEvent):
    if event.is_action_pressed("shoot"):
        shoot()  # Only fires if no UI handled it
```

### 10.4 Stopping Input Propagation

**Buggy -- input leaks through UI to game:**
```gdscript
# UI button handler
func _on_button_pressed():
    do_ui_thing()
    # Input continues propagating to game nodes!
```

**Fix -- mark input as handled in _gui_input or _input:**
```gdscript
func _gui_input(event: InputEvent):
    if event is InputEventMouseButton and event.pressed:
        accept_event()  # Stops propagation for Control nodes
```

Or from any `_input`/`_unhandled_input`:
```gdscript
func _input(event: InputEvent):
    if event.is_action_pressed("pause"):
        toggle_pause()
        get_viewport().set_input_as_handled()  # Stop propagation
```

### 10.5 InputEvent vs Input Singleton

**Important distinction:**
- `InputEvent` (in `_input()`, `_unhandled_input()`) is event-driven -- fires once per event
- `Input` singleton (in `_process()`) is polling-based -- checks current state every frame

`InputEvent` does NOT have `is_action_just_pressed()` -- that method only exists on the `Input` singleton.

**Buggy:**
```gdscript
func _unhandled_input(event):
    if event.is_action_just_pressed("jump"):  # ERROR: method doesn't exist on InputEvent
        jump()
```

**Fix:**
```gdscript
func _unhandled_input(event: InputEvent):
    if event.is_action_pressed("jump"):  # Correct: is_action_pressed exists on InputEvent
        jump()
```

### 10.6 Action Map Misconfigurations

**Common issues:**
- Actions referenced in code (`Input.is_action_pressed("attack")`) but not defined in Project Settings > Input Map
- Actions with no bindings (defined but empty)
- Dead zone set to 0 for analog sticks (causes phantom input)
- Duplicate bindings across different actions (ambiguous behavior)

**Audit check:** Extract all action names from code (`is_action_pressed`, `is_action_just_pressed`, `is_action_just_released`, `event.is_action`) and cross-reference with the `[input]` section of project.godot.

### 10.7 Mouse Input and Viewport Scaling

With a scaled viewport (common in pixel art games like 480x270 with 3x zoom), mouse coordinates must be handled carefully.

**Buggy -- using raw mouse position:**
```gdscript
func _input(event):
    if event is InputEventMouseButton:
        var click_pos = event.position  # Screen coordinates, not game world!
```

**Fix -- get world position:**
```gdscript
func _input(event):
    if event is InputEventMouseButton:
        var click_pos = get_global_mouse_position()  # Transformed to game world
```

### 10.8 UI Mouse Filter Settings

Control nodes have a `mouse_filter` property that determines how they handle mouse events:
- `MOUSE_FILTER_STOP` -- handles and consumes the event (default)
- `MOUSE_FILTER_PASS` -- handles but lets the event continue
- `MOUSE_FILTER_IGNORE` -- completely transparent to mouse

**Common bug:** A full-screen Control (like an HBox or Panel) with default `MOUSE_FILTER_STOP` blocks all mouse events from reaching the game world beneath it.

**Fix:** Set non-interactive UI containers to `MOUSE_FILTER_IGNORE`:
```gdscript
$HUD/InfoPanel.mouse_filter = Control.MOUSE_FILTER_IGNORE
```

---

## Audit Checklist Summary

Use this as a quick-reference during the code audit:

### Critical (Will Crash)
- [ ] Null access on unguarded node references
- [ ] Use-after-free on queue_free()'d nodes
- [ ] Cyclic preload() chains
- [ ] Scene tree modification in signal callbacks without call_deferred
- [ ] Missing scripts referenced in .tscn files
- [ ] Broken resource paths in .tscn/.tres files
- [ ] Hand-written UIDs in .tscn files

### High (Will Bug)
- [ ] @onready accessed before _ready() (e.g., in _enter_tree or child signal handlers)
- [ ] is_action_pressed used where is_action_just_pressed needed
- [ ] _input() used where _unhandled_input() needed (input leaks through UI)
- [ ] Case-sensitive path mismatches (works on Windows, crashes on Linux/Web)
- [ ] Writing to res:// instead of user:// for save data
- [ ] Signals not disconnected before freeing nodes
- [ ] @export + @onready on same variable
- [ ] Theme override syntax errors (wrong API for Godot 4)
- [ ] Enum membership checks without .keys()

### Medium (Performance)
- [ ] Uncached $Node lookups in _process/_physics_process
- [ ] Per-frame object allocations (arrays, strings, dictionaries)
- [ ] String concatenation in loops (use PackedStringArray)
- [ ] Missing object pooling for frequently spawned/freed nodes (bullets, pickups)
- [ ] Physics logic in _process instead of _physics_process
- [ ] Polling in _process where signals would suffice
- [ ] get_nodes_in_group() called every frame

### Low (Code Quality)
- [ ] Missing type annotations on variables, parameters, return types
- [ ] Unused variables, signals, and parameters
- [ ] Shadowed variable names
- [ ] Dead code / unreachable branches
- [ ] Debug print statements left in production code
- [ ] Return values silently discarded
- [ ] Orphan nodes (instantiated but never added to tree or freed)
- [ ] Growing collections in autoload singletons without cleanup
- [ ] Mouse filter settings blocking game input
- [ ] Missing input map entries for actions used in code
