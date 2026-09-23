# Scrapwright Audit — 2026-09-23

Five months after the April audit (`audits/AUDIT_2026-04-16/`). The April pass was a read-through; this one **ran the game**:

- Compiled every script and instantiated every scene in **Godot 4.6.3-stable** (headless).
- An autoplay bot (`harness/`) played the **full 84-wave run**: all 12 bosses, 12 hub visits, 94 chest screens. It also ran **15 targeted repro scenarios**: save/load, death/retry, hub return, keybinds, gamepad, pause, and more.
- Six parallel code reviews (core loop, combat, enemies, UI/input, systems, design). Every claim that made it into this report was re-checked against the code or the engine.

Evidence tags: **[RT]** reproduced at runtime in the engine · **[CODE]** confirmed by reading the code · **[ENG]** engine behaviour proven with a probe script.

---

## Verdict

**The combat core is solid.** The bot's 84-wave run produced **zero script errors**. A mid-run save → wipe → load round-trip matched on **every** `GameState` variable. Memory stayed flat (56 → 86 MB over 84 waves, ≤10 orphan nodes), and 150 simultaneous late-game enemies cost ~6 ms/frame of CPU (p95). The April crash-safety work held up.

**The problems are at the seams:** popups, pause, scene transitions, menus and persistence, which is exactly where players notice. **Seven bugs can freeze the game, corrupt a save, or lock players out** (§1). There is **one security issue to fix today** (§0).

After that, the biggest win isn't more content, it's **pacing** (§4):
- Runs take 90+ minutes, and death means restarting at wave 1.
- Level-ups dry up after stage 1.
- A paused chest screen interrupts every single wave.

### Summary

| ID | Issue | Sev | Evidence |
|---|---|---|---|
| S1 | PixelLab API key committed to a **public** repo | CRIT | [CODE] |
| C1 | Rebinding any key kills Esc + arrow keys after restart | CRIT | [RT] |
| C2 | Hub → Quit to Menu rolls the save back (purchases undone, boss replay) | CRIT | [RT] |
| C3 | …and writes one profile's progress into another profile | CRIT | [RT] |
| C4 | Entering the Junkyard writes an empty stockpile + no run to disk | CRIT | [RT] |
| C5 | Esc after dying (or dying right after wave clear) freezes Game Over | CRIT | [RT] |
| C6 | 2+ queued level-ups → invisible popup, game frozen | CRIT | [RT] |
| C7 | Controllers can't move/pause/confirm — but the store page promises gamepad support | CRIT | [RT] |
| H1 | Double-click a perk card = two perks | HIGH | [RT] |
| H2 | Double-click chest Collect = next wave broken, death ignored | HIGH | [RT] |
| H3 | You take damage while paused (37 timers ignore pause) | HIGH | [RT] |
| H4 | Hub return deletes the Chimera buff and chest max-HP; heal depends on armor | HIGH | [RT] |
| H5 | Perk picks lost/buried around wave clears and boss chests | HIGH | [RT] |
| H6 | Stage boss's "guaranteed" secret key usually doesn't drop | HIGH | [CODE] |
| H7 | Lava Lobber puddles never expire (invisible stacking damage) | HIGH | [ENG] |
| H8 | Boss "arena center" is the player's position | HIGH | [CODE] |
| H9 | Spore rings hit every frame; blizzard steals movement 10 s; prison unescapable | HIGH | [CODE] |
| H10 | Earlier-stage enemies one-shot you late (stacked multipliers) | HIGH | [CODE] |
| H11 | Settings never saved; NEW GAME wipes without confirmation | HIGH | [CODE] |
| H12 | April's colorblind fix (FP-11) was never applied | HIGH | [CODE] |

---

## 0 · Do today

**S1 — Rotate the PixelLab API key.**
- The GitHub repo `Catalyst86/Scrapwright` is **public** (`visibility: public`), although its description says "private dev".
- The live key is committed in:
  - `CLAUDE.md` (PixelLab section)
  - `tools/generate_armor_sprites.py`
  - `tools/__pycache__/generate_armor_sprites.cpython-311.pyc`
  - at least 4 commits of history
- Anyone can spend your PixelLab credits.
- Fix:
  1. Rotate the key first. Rotation is what actually closes the hole.
  2. Load it from an environment variable.
  3. Delete the `.pyc` and add `__pycache__/` to `.gitignore`.
  4. Consider making the repo private. Rewriting history is optional once the key is rotated.

**S2 — Stop tracking `.godot/`.**
- **10,930 files / 438 MB** of import cache are committed despite `.gitignore`; they were added before the rule existed. This is most of why the repo is 1.55 GiB after only 50 commits.
- This includes `.godot/export_credentials.cfg`. It's empty today, but the moment you enter code-signing or Apple notarization passwords in the export dialog, they will be committed.
- Fix: `git rm -r --cached .godot`, then commit.

---

## 1 · Critical — freezes, save corruption, lockouts

### C1 · Rebinding any key kills Esc and the arrow keys after a restart — [RT]
- **What:**
  - `KeybindManager.save_keybinds()` writes `physical_keycode` for *every* rebindable action.
  - The project's `ui_cancel` (Esc) is keycode-only (`physical_keycode = 0`). On the next launch, `load_keybinds()` erases Esc and adds a key-0 event, which matches nothing.
  - `ui_left/right/up/down` each have two keys (WASD + arrows). Only the first is saved, and reload erases both.
  - Reset Defaults lives in the pause menu, which needs Esc. The player **cannot undo this in-game**.
  - Regression introduced by April FP-10.
- **Proof:**
  - Launch 1: rebind Dodge → J.
  - Launch 2: `Esc → ui_cancel = false`, `LeftArrow → ui_left = false`, and `ui_cancel` holds `kc=0 phys=0`.
- **Fix:** `autoloads/keybind_manager.gd:64-92`.
  - Save and restore whichever of `keycode`/`physical_keycode` is non-zero.
  - Only persist actions that differ from their defaults.
  - Replace only the primary key and keep alternates.

### C2 · Hub → Quit to Menu rolls your save back — [RT]
- **What:**
  - Pressing Esc in the hub opens the *arena* pause menu (`base_hub.gd:248-258`).
  - Its QUIT TO MENU and RETURN TO HUB (`pause_menu.gd:591-618`) always call `GameState.restore_wave_start()`, rewind `current_wave`, and save.
  - This is the **only in-game route from the hub to the main menu**.
- **Proof:**
  1. Clear boss wave 7, go to the hub, and buy Iron Maw + Thick Hide (both saved to disk).
  2. Esc → Quit to Menu.
  3. On disk: `bite_damage_level 1→0`, `max_hp_level 1→0`, `current_wave 7→6`. The upgrades are gone and the boss must be replayed.
- **Fix:**
  - Restore only while `WaveManager.wave_active`.
  - Clear `_wave_start_snapshot` on wave complete, `end_run()` and `load_game()`.
  - Hide RETURN TO HUB when the menu is opened from the hub.

### C3 · …and it writes one profile's data into another — [RT]
- **What:**
  - `_wave_start_snapshot` is assigned in one place (`game_state.gd:133`) and **never cleared**.
  - That includes `SaveManager.load_game()`, whose own comment says it resets everything "so nothing bleeds across profiles".
- **Proof:**
  1. Play profile 1 (Iron Maw Lv5, 60 of each material).
  2. Create a fresh profile 2 and go to the hub.
  3. Esc → Quit to Menu.
  4. **Profile 2's save file now holds Iron Maw Lv5 and 60 of every material.**
- **Fix:** same as C2, and also clear the snapshot in `load_game()` / `select_profile()`.

### C4 · Entering the Junkyard erases your save — [RT]
- **What:**
  - `JunkyardState.enter_junkyard()` zeroes materials and sets `run_in_progress = false`.
  - `base_hub._enter_junkyard()` then saves immediately.
  - Your real stockpile and in-progress run exist **only in RAM** (`JunkyardState._snapshot`).
  - A crash, Alt-F4, or QUIT TO DESKTOP from the Junkyard loses both.
- **Proof:** mid-run with 60 of each material, click Junkyard. Disk immediately shows **0 materials, `run_in_progress=false`**, while the snapshot in RAM still holds the 60s.
- **Fix:**
  - While `JunkyardState.is_active`, `save_game()` must write the snapshot's values, not the sandbox's.
  - Call `exit_junkyard()` on every exit path.
  - Snapshot the full run state, not a subset (see §3).

### C5 · Esc after dying freezes the Game Over screen — [RT]
- **What:**
  - The death sequence waits 2.8 s on a `SceneTreeTimer` (`arena.gd:1270`), which by default ignores pause, then changes scene.
  - If the pause menu is open at that moment (players press Esc on death constantly), `game_over.tscn` loads with the tree **paused**. The menu that could unpause it was freed with the arena.
  - The same thing happens if you die within 1.3 s of WAVE CLEAR, because the chest phase pauses the tree. A last-enemy exploder is the classic trigger.
- **Proof:** both repros → `game_over loaded; tree paused=true; can_process=false` (buttons dead, fade-ins frozen).
- **Fix:**
  - `get_tree().paused = false` in `game_over._ready()` (and in `base_hub` and `credits`).
  - Disallow opening pause in `TRANSITION`.
  - In `_on_wave_complete`, return after each `await` if the player is dead.

### C6 · Two queued level-ups freeze the game — [RT]
- **What:**
  - `level_up._on_chosen()` (`level_up.gd:541-574`) unpauses immediately but only hides the popup and applies the perk 0.6 s later, via a tween.
  - On the next frame, `arena._check_level_up()` shows the next pending level and re-pauses.
  - Then the old tween calls `hide()` on the *new* popup.
  - Result: tree paused, nothing on screen, Esc dead (the arena doesn't process input while paused).
  - Triggers: a big XP burst (chest XP + wave-clear vacuum early on), or a level gained within 0.6 s of picking.
- **Proof:** queue 3 levels, pick a card → `tree_paused=true, levelup_visible=false, alpha=0`; Esc has no effect; one perk silently lost.
- **Fix:**
  - Apply the perk and hide the popup synchronously, or keep the dismiss tween and `kill()` it in `show_level_up()`.
  - Make `_check_level_up()` return while the popup is visible.

### C7 · Controllers don't work, but the itch page says they do — [RT]
- **What:**
  - `project.godot` overrides `ui_left/right/up/down/cancel` with **keyboard-only** events. A project override replaces Godot's built-in stick/D-pad events.
  - Movement reads `ui_*` (`player.gd:464-467`), so the stick and D-pad do nothing.
  - There is no pause button, and `ui_accept` has no pad button, so no menu can be confirmed.
  - Sneak and Collect use button indices **4/5**. Those were LB/RB in **Godot 3**; in **Godot 4** they are **Back/Guide**.
  - `tools/itch_page_description.txt` advertises "Gamepad support" (Left Stick, LB, RB).
  - This also makes April's gamepad radial-wheel fix (FP-9) unreachable.
- **Proof:** of stick, D-pad, A, B and Start, **the only one mapped to anything is A → dodge.**
- **Fix:**
  - Add `JOY_AXIS_LEFT_X/Y` and the D-pad to `ui_*`.
  - Map A to `ui_accept` and B to `ui_cancel`, and add a `pause` action on Start.
  - Use indices 9/10 for LB/RB.
  - `grab_focus()` in every popup (see §3 Input).

---

## 2 · High — wrong behaviour in normal play

### H1 · Double-click a perk card → two perks — [RT]
- SELECT buttons stay live during the 0.6 s dismiss, and `_on_chosen` has no guard.
- **Proof:** one level-up granted **Magnet Core and Lucky Find**.
- The same pattern exists on Game Over RETRY: a double-click burns two extra lives (`game_over.gd:379-389`).
- **Fix:** a `_choosing` flag, and disable every button on the first press.

### H2 · Double-click chest Collect → next wave broken, death ignored — [RT]
- `_end_chest_phase()` (`arena.gd:344`) awaits 0.35 s *after* its guard. A second click re-enters it and sets `arena_phase = TRANSITION` after the next wave has already started. For that whole wave:
  - there are no level-ups;
  - the 3 s safety net is off;
  - `_on_player_died` returns early. **The dog dies, there is no Game Over, and the run can't end.**
- **Proof:** single press → wave 2 in `COMBAT`; double press → `TRANSITION`; lethal hit → still in the arena with `is_dead=true`.
- **Fix:** disable the button, or set a closing flag, on the first press.

### H3 · You take damage while paused — [RT]
- All **37** `create_timer()` calls use the default `process_always = true`. The following keep running under the pause menu, level-up and chest screens:
  - exploder fuses (45)
  - the Crystal Colossus prison (50)
  - Molten Wyrm burrow strikes
  - Ember Drake meteors
  - burn and poison DoTs
- **Proof:** exploder fuse lit, then pause menu opened → **HP 105 → 60 while paused**.
- **Fix:** `create_timer(t, false)` (or child `Timer` nodes) for every gameplay timer.

### H4 · Returning from the hub deletes run bonuses — [RT]
- `reapply_permanent_bonuses()` rebuilds stats from scratch on every hub return (11× per run). It never re-applies:
  - **Junkyard Chimera**: 5 of 6 variants are lost; only crit survives, because `player.gd` reads it live.
  - silver-chest **+5 max HP**.
- It full-heals only if your *stat armor* has `max_health`: yes for Leather Vest, no for Void Cloak.
- **Proof:**
  - A natural run rolled Iron Stomach: `dmg_bonus 22 → 2` at the first hub return, while `chimera_buff` still reads "Iron Stomach".
  - Forced test: `max_hp 115 → 110` and `hp 20 → 110`.
- **Fix:**
  - Re-apply the existing `chimera_buff` without re-rolling.
  - Track chest HP as a run stat.
  - Move the heal out of `apply_armor_stats()` and make the rule explicit.

### H5 · Perk picks lost or buried around wave clears — [RT]
- **Boss waves:** chest XP levels you up during `CHEST_PHASE`, where no level check runs. The next arena's `_ready()` then resets `last_player_level` (`arena.gd:51`), so **that perk is never offered.**
- **Normal waves:** the XP vacuum's level-up popup gets covered by the chest screen, because the 1.3 s timer ignores pause. The popup then stays open into the next wave.
- **Proof:** a boss-chest level 2→3 was never offered after the hub (`popup shown=false`).
- **Fix:**
  - Keep a pending-level counter instead of resyncing.
  - Wait for the level-up to close before starting the chest phase and before leaving for the hub.

### H6 · The stage boss's "guaranteed" secret key usually doesn't drop — [CODE]
- During wave N, `GameState.current_wave` is still N−1; it only updates on wave complete (`arena.gd:230`).
- `_drop_key()` checks `get_stage_wave(current_wave) == 14` (`enemy_base.gd:998`). That only passes if the boss is the **last** enemy killed, because only then has the wave-complete handler already run inside the `died` emit.
- The same off-by-one causes three more problems:
  - the boss key table lands on the wave **after** each boss (8, 15, 22…);
  - stage scaling is shifted by one wave;
  - the final kill's XP orb and key spawn after the vacuum has already run.
- **Fix:** use `WaveManager.current_wave` in `enemy_base.gd`, and drop loot before emitting `died`.

### H7 · Lava Lobber puddles never expire — [ENG]
- The damage-tick counter is an `int` captured by a lambda (`enemy_lava_lobber.gd:145-152`). GDScript lambdas capture **by value**, so the counter resets on every call and never reaches 6.
- The puddle's visual fades after 3 s, but its hitbox keeps dealing 4 damage every 0.5 s. Puddles stack wherever you stood.
- **Proof:** in 4.6.3 an int counter in a lambda returns `[1,1,1,1,1,1,1,1]`, while an array box returns `[1..8]`. A leftover `FirePuddle` node was still alive in stage 4 of the autoplay run.
- **Fix:** `var tick_count := [0]` / `tick_count[0] += 1` (Flame Wisp already uses this pattern). Also free the puddle when the fade ends.

### H8 · Boss "arena center" is actually the player — [CODE]
- `_get_arena_center()` (defined in 11 bosses) returns the Camera2D's position, and the camera is a child of the Player (`player.tscn:47`). So:
  - The Devourer's void rift spawns **on you**: unavoidable 40 damage.
  - Titan, Sentinel, Mech, Drake and King "move to center", which means onto you, through walls.
  - Cover and pillars are placed around you, sometimes outside the arena.
- **Fix:** return `Vector2(ARENA_W, ARENA_H) / 2` (1280×720 arena), not the camera position or the 480×270 fallback.

### H9 · Boss mechanics that break their own rules — [CODE]
- **Spore Mother:** bloom rings damage **every physics frame** you're in the band, about 60–70 per ring instead of 10 (`enemy_spore_mother.gd:381-388`). Fix: a per-ring hit flag.
- **Frost Warden:** the blizzard overwrites `player.knockback` every frame. `player._handle_movement()` then ignores input, so you have **no movement for 10 s** (`enemy_frost_warden.gd:167-173`). Fix: a separate additive push.
- **Crystal Colossus:** the prison counts *any* surviving wall as a failure. Escaping means destroying all 8 walls (400 HP) in 6 s, so the 50 damage is effectively unavoidable (`enemy_crystal_colossus.gd:127-137`). Fix: fail only if the player is still inside the ring.
- **Boss ranged attacks** are silently skipped at close range:
  - The proximity "wind-up" (`_check_contact_damage`, within 3× contact range) sets `_attack_anim_playing`.
  - `_play_attack_anim_then()` then returns without calling the attack.
  - Affected: Architect, Colossus, King, Titan, Sentinel.

### H10 · Old enemies one-shot you late — [CODE]
- Earlier-stage enemies get the **stage** multiplier *and* the **wave** curve (`enemy_base.gd:239-259`). Examples:
  - Obsidian Golem at wave 70: **1,544 HP, ~279 per hit**. That wave's boss (the Architect) hits for 64.
  - Glacial Hulk at wave 84: 178 per hit.
- Late-game player max HP is about 250–340, and there are no post-hit invulnerability frames.
- **Fix:**
  - Scale relative to each enemy's home stage, or drop `STAGE_*_SCALE` now that the wave curve exists.
  - Add ~0.4 s of invulnerability after a hit.

### H11 · Settings never saved; NEW GAME wipes without asking — [CODE]
- Volume and fullscreen are applied but never persisted. The only `ConfigFile` users are saves, achievements and keybinds, so settings reset every launch.
- NEW GAME (`main_menu.gd:561-570`) asks for confirmation only if you've bought an upgrade. Otherwise it deletes cards, achievements, armor unlocks and any run in progress.
- Options → DELETE SAVE still uses the old double-click confirm (`main_menu.gd:403-418`). April's FP-12 only fixed *profile* delete.
- **Fix:**
  - Add a `user://settings.cfg`.
  - Confirm whenever `_has_save_progress()` is true.
  - Reuse the typed-name dialog for DELETE SAVE.

### H12 · The colorblind glyphs were never added — [CODE]
- `FIXES_APPLIED.md` says FP-11 added `_add_archetype_glyph()` to `enemy_base.gd`.
- The function exists nowhere (`grep glyph` → 0 hits), and the fix commit `716b296a` didn't touch that file.
- Rusher vs Spore Walker is still red-vs-green.

---

## 3 · Medium — "the text says X, the code does Y", and other paper cuts

**Perks and upgrades that don't do what they say** [CODE]
- **Shadow Step:** the "−20% sneak cooldown" is never read (`player.gd:524`).
- **Scavenger's Nose** doesn't affect XP orbs; `xp_pickup.gd:66-68` only reads Fetch!.
- **Fetch!:** gives XP orbs +12 px per level on a 20 px base, not the "+15%" it says. A 20 px base pull is also very small.
- **Keen Nose:**
  - Lv5 is identical to Lv4 (5-entry tables for levels 0–5, `game_state.gd:618-630`).
  - Lv1's 1.6× salvage speed is truncated to 1× by `int()` (`destructible_prop.gd:133`).
- **XP bonuses** mostly vanish to `int(amount × mult)` truncation on small orbs (8 × 1.05 = 8).
- **Phoenix Mantle:** says "Regen 2 HP/10s". The arena applies 1% max HP / 3 s (≈3× stronger); the Junkyard applies 2/10 s.
- **Shadow Dagger:** the "backstab crit" doesn't exist.
- **Magnet Core:** its pull is undone by its own knockback, for a net push of ~20 px outward.
- **Flame Wisp** never burns. A full `burning` status exists (`enemy_base.gd:1328`), but nothing applies it.
- **Bark (E)** is cosmetic only (`player.gd:754`), yet it's a bound, taught key.
- **Bad Dog** (the repurposed Feral Howl) doesn't say what it does before you buy it. CLAUDE.md still describes it as a stun.

**Wardrobe and collections** [CODE]
- `ArmorDB.unlock_armor()` has exactly **one** caller, the boss drop table (`enemy_base.gd:1030-1075`). So every wardrobe hint is wrong:
  - "Complete the game" (Golden Collar) actually drops from the Crystal Colossus.
  - "Complete 10 runs" (Void Cloak) actually drops from the Architect.
- **Blue Bandana and Party Hat are unobtainable.**
- Six bosses "drop" *disabled* skins, so you get "NEW SKIN!" pop-ups for items that never appear.
- Cards drop only in Junkyard mode (`destructible_prop.gd:181-187`). Nothing tells the player, and the arena's card hookup is dead code.
- Achievement stats (runs, kills, keys) are saved only when *some* achievement unlocks. Multi-session goals (Veteran, Thousand Bones) lose progress in any session where nothing unlocks.

**Run-state edge cases** [CODE]
- A mid-run Junkyard visit refunds Bad Dog lives and Second Wind, and a revival used inside the Junkyard stays consumed. `exit_junkyard()` restores none of these.
- QUIT TO DESKTOP mid-wave saves that wave's loot, and Continue replays the wave. That's a farm loop, and QUIT TO MENU behaves differently.
- The wave number is shown one behind in the pause menu and death screen ("Stage 1 Wave 0" during wave 1).
- Six hand-maintained copies of "the run state" have drifted apart:
  - snapshot/restore
  - save/load
  - junkyard enter/exit
  - `start_new_run`/`end_run`
  - `reapply_permanent_bonuses`
  - `JunkyardState`'s field list

  A single `RunState` dictionary with one serializer would remove C2–C4, H4 and the Junkyard refunds as a class.

**Enemies** [CODE]
- **Speed modifiers overwrite each other.** Vine Snare resets every enemy's `move_speed` every 0.5 s. That wipes Frost slows outside its radius and boss enrage (King ×1.6, Architect ×1.5), and any expiring slow also wipes enrage.
- **Hazard loops don't stop at death.** Spore Mother, Titan, Wyrm and Void Weaver hazards keep going after the boss dies. About half of Void Weaver deaths leave a permanent orphan zone.
- **Fungal Titan eruption** makes ~25 pools instead of 5, because it shares the phase-3 position array.
- **Molten Wyrm** keeps charging and firing while "burrowed", i.e. invisible and untargetable.
- **Frost Sprite / Glacial Hulk slows** are 70%, though commented as 30%: `apply_slow(0.3)` is a speed *multiplier*.
- **Shared `SpriteFrames`.** Every enemy of a type shares one `SpriteFrames` (a plain sub-resource). It is rebuilt on every spawn and mutated in `_die()`, so same-type sprites snap back to frame 0.
- **Minion `died` handlers** don't re-check wave completion, so the wave ends ~3 s late via the safety net.

**Input and UI** [CODE]
- **Rebind listener:** can't capture W/S/arrows/Tab/Enter/Space, because focus navigation consumes them first. There's no conflict detection.
- **Keyboard focus:** no popup grabs it (level-up, chest, pause, in-world chest), so a keyboard-only player can't pick a perk.
- **Intro click-to-skip** never fires: the root `Control` eats the click, and the pad is ignored. The ~59 s intro can only be skipped with the keyboard.
- **Window scaling:** the default is Maximized with fractional `canvas_items` scaling (~1.87× on a 1080p desktop), which gives uneven pixels and shimmer. Use `window/stretch/scale_mode="integer"` or offer it as an option.
- **Pause menu leak:** the hub instantiates a new PauseMenu layer on every Esc and never frees it.

---

## 4 · Design — what would most improve the *game*

Numbers come from the code plus the autoplay telemetry.

1. **Level-ups dry up after stage 1.**
   - XP-to-next grows ×1.4 per level. The bot reached **Lv6 by wave 14, then about one level per 14-wave stage** (Lv13 at wave 84). A moving player gets roughly 15 picks per run.
   - The Lv20 orbital tables are unreachable; the average orbital ends a run around Lv3.
   - → Use a linear or softer curve (e.g. `60 + 30×(level−1)`), and raise orb lifetime from 8 s to about 20 s.
2. **Runs are far too long for the genre, and death restarts at wave 1.**
   - 2,844 enemies at one spawn per 0.8 s = **38.7 minutes of spawning alone** (measured). Even the instant-kill bot needed 46 minutes; a human run is 90+ minutes.
   - Genre norm is 20–30 minutes (Vampire Survivors, Brotato, 20 Minutes Till Dawn).
   - → Stage checkpoints ("Start at Stage N" after beating its boss), a faster spawn cadence on big waves, and a real "STAGE CLEAR" moment on wave 14.
3. **94 paused chest screens per run.**
   - One after every wave; in stage 1 some modal pauses you about every 26 s.
   - → Auto-open normal-wave chests with a non-pausing loot toast, and keep the ceremony for boss waves.
4. **Game feel is flat.**
   - There's no screen shake, no hit-stop, no particles in the main arena, and no post-hit invulnerability.
   - → A juice pass:
     - camera shake on hurt and boss slams
     - 40–60 ms hit-stop on crits
     - pooled death pops through the existing `VFXPool`
     - 0.4 s i-frames, which also defuse H9 and H10
5. **Builds are shallow.**
   - These all buff only the bite: the damage, attack-speed and crit perks, Combat Paws, the Lost deck, and 3 of the 6 Chimera rolls.
   - Orbital builds can't be supported, and there are no evolutions or synergies.
   - → Make those global multipliers, and add 3–4 evolutions. The `burning` status is already written.
6. **Dying costs everything since the last hub visit.**
   - A first run that dies before wave 7 banks nothing.
   - The death screen lists your restored stockpile as "Materials Salvaged".
   - → Keep ~50% of run finds, and show kept vs lost.
7. **The threat curve is flat early and spiky late.**
   - Waves 1–6 barely threaten you.
   - From wave 6 to wave 7, total enemy HP jumps 4.8×.
   - Late waves have the one-shots from H10.
   - → Raise the early aggression floor, remove the stacked stage multipliers, and cap single hits at ~35% of max HP.
8. **Hidden systems.**
   - Dig charges, cooldowns, key counts and orbital levels aren't on the HUD.
   - Nothing explains where cards come from.
   - → Add a HUD strip and one-line hints.
9. **Too many verbs for a survivors-like.**
   - move, dodge, sneak, dig, salvage, bark, collect
   - plus 4 key tiers, key forging, 6 materials, 15 upgrades, the wardrobe, 40 cards and the Junkyard
   - Sneak's real effect is undocumented: it freezes every enemy more than 30 px away. Bark does nothing.
   - → Consolidate, e.g. make Bark the single active ability.
10. **Store page accuracy.** It claims "16 achievements" (there are 20), "11 armors" (10 are enabled, 8 obtainable), and "Gamepad support" (C7).

**Your roadmap** (`.claude/memory/future_features_roadmap.md`):
- **Keep:** the "+XXX this run" pop-up, starting loadouts, screen shake, short runs/checkpoints, a wave progress bar, WAV→OGG.
- **Reshape:** the Scrap meta-currency into "keep some materials on death" rather than a 7th currency; "8–10 archetypes" into 3–4 evolutions first.
- **Cut for now:** daily runs and leaderboards (the backend and anti-cheat work is a trap before launch), prestige tiers, and card-pool expansions (players can't find the current cards).

---

## 5 · Performance and build size

- **CPU is fine.**
  - With **150** simultaneous late-game enemies, script + physics runs at p95 ≈ 6 ms and max ≈ 22 ms per frame, against a 16.7 ms budget.
  - The 84-wave run showed no leaks.
  - Measured headless, so rendering is excluded; GL Compatibility has no trouble with ~2k sprites.
- **Spawn hitches:** each enemy spawn costs ~1.5 ms (150 in one frame = 218 ms), because its `SpriteFrames` is rebuilt every time. Cache it per type; boss summons will stop hitching.
- **Install size is the real problem:**
  - **Intro:** 552 PNG frames at 960×540 = **192 MB**, played at 10 fps with a synchronous `load()` per frame. → A 5–15 MB `.ogv` in a `VideoStreamPlayer`.
  - **Hub 3D buttons:** **eight GLBs of 16–25 MB each (~155 MB)**. → Decimate and compress the textures, or pre-render them to sprite sheets.
  - 33 MB of WAV remains (your roadmap already lists WAV→OGG).
- **Exports:** `export_filter="all_resources"` also ships `tools/previews/*.png`. Exclude `tools/*` and `audits/*`.

---

## 6 · Repo and release hygiene

- **Engine:** you're on **Godot 4.6-dev6**, a pre-release snapshot. The project compiles and runs cleanly on **4.6.3-stable**; switch before exporting.
- **`base_hub.tscn`:** has a stale UID for `hub_bg.jpg`, which logs a warning on every hub load. Re-save the scene.
- **Music imports:** 8 of the 16 battle tracks (`aluminum_thunder*`, `arcade_iron*`, `pixel_*`) have no committed `.import` files.
- **Docs drift:**
  - CLAUDE.md still describes Feral Howl as a stun.
  - BALANCE_AUDIT.md lists boss HP without the wave multiplier. The Scrap King has 11,902 HP at wave 84, not 2,200.
  - FIXES_APPLIED.md claims FP-11 (H12).

---

## 7 · April 2026 audit — status

- ✅ **Working:** FP-1, FP-2 (Magnet Core), FP-3, FP-4, FP-5, FP-6, FP-7, FP-12 (profile delete), FP-13, FP-15, FP-16, FP-17, FP-18, FP-20, FP-21, FP-23, FP-27.
- ⚠️ **Regressed or incomplete:**
  - **FP-10** broke keybind persistence (→ C1).
  - **FP-9** is unreachable by gamepad (→ C7).
  - **FP-12** didn't cover Options → Delete Save (→ H11).
  - **FP-2:** Holy Lantern heals more than the plan targeted.
  - **FP-32:** disabled armors are still dropped by bosses.
  - Commit 7e5e7fde's Lava Lobber fix doesn't stop the puddles (→ H7).
- ❌ **Never applied:** **FP-11** (→ H12).

---

## 8 · What's genuinely good — protect it

- **Stability.** 84 waves with zero errors, perfect save round-trips and no leaks, all verified in the real engine.
- **The flame-trail dodge.** Dodging is also an attack; it's your best verb.
- **Honest perk cards.** They show the real diminished values, always offer a weapon, and handle the 6-slot cap cleanly.
- **12 three-phase bosses** with warning banners and cover obstacles. That's rare for a solo project.
- **The hub stop every 7 waves.** It's a natural session break with a clean snapshot model; keep it when you shorten runs.
- **Charm.** The 8-direction pup, the animated hub bust, the bark words and "Bad Dog" land well.

---

## Appendix · Reproducing these results

`harness/` contains the autoplay bot and the probes used for every **[RT]** item; see `harness/README.md`. After fixing a bug, re-run its scenario and confirm the result flips.
