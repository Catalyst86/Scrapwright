# Audit harness (2026-09-23)

The autoplay bot and probe scripts behind every **[RT]** finding in `../REPORT.md`. They are **not part of the game**. This folder has a `.gdignore`, so Godot neither imports nor exports it.

## Safety first

The bot **deletes save profiles 1–4** in the active user-data folder when it starts. It refuses to run unless the project is using a *separate* user-data folder. The `override.cfg` below sets that up, so your real saves are never touched.

## Setup (no edits to `project.godot`)

1. Copy this folder's `*.gd` and `*.tscn` files into a new `_audit/` folder at the project root.
2. Create `override.cfg` at the project root. Godot reads it on top of `project.godot`.

   ```ini
   [application]

   config/use_custom_user_dir=true
   config/custom_user_dir_name="ScrapwrightAudit"

   [autoload]

   AuditBot="*res://_audit/audit_bot.gd"
   ```

   Saves then go to `%APPDATA%\ScrapwrightAudit\` on Windows or `~/.local/share/ScrapwrightAudit/` on Linux.
3. When you're done, delete `override.cfg` and `_audit/`. Don't commit them.

## Running a scenario

Use Godot **4.6.3-stable** or newer:

```bash
godot --headless --fixed-fps 60 --path . res://_audit/bot_boot.tscn -- --scenario=<name>
```

`--fixed-fps 60` makes each frame advance exactly 1/60 s of game time while running as fast as the CPU allows. Every run ends with a `BOT SUMMARY` that lists errors (with backtraces), softlocks and stat diffs. A JSON copy is written to `user://audit_bot/`.

| Scenario | Proves | Bug output | Fixed output |
|---|---|---|---|
| `full_run` (`--max_wave=84`, optional `--start_wave=N`) | Plays waves 1–84 through hub, chests and level-ups; logs per-wave telemetry | — | `errors: 0`, no `SOFTLOCK` lines |
| `levelup_race` | C6 | `RESULT softlock=true` | `softlock=false` |
| `double_click` | H1 | `RESULT double_grant=true` | `false` |
| `single_collect` / `double_collect` | H2 | double → `arena_phase=3 (TRANSITION)` | `1 (COMBAT)` for both |
| `hub_return` | H4, H5 | `dmg_bonus=0`, `popup shown=false` | `dmg_bonus=20`, popup shown |
| `hub_quit` | C2 | purchases revert on disk, `current_wave 7→6` | purchases kept, wave 7 |
| `profile_bleed` | C3 | profile 2 gains profile 1's upgrades and materials | profile 2 stays empty |
| `junkyard_save` | C4 | disk shows 0 materials, `run_in_progress=false` | disk keeps the real stockpile |
| `pause_damage` | H3 | `damage taken while paused: true` | `false` |
| `death_esc` / `clear_window_death` | C5 | `tree paused=true ; can_process=false` | `false ; true` |
| `death_cycle` | Retry/extra life, then a new run: no stat accumulation | `(no change)` = pass | — |
| `save_roundtrip` | Save → wipe → load mid-run | `0 GameState vars differ` = pass | — |
| `stress` (`--n=150`) | Frame cost with N late-game enemies | — | — |

## Probes (standalone scenes)

Run a probe with `-- --scenario=none` so the bot stays inert:

- `compile_all.tscn`: loads every script and instantiates every scene with autoloads active.
- `kb_probe.tscn`: C1. Run with `--kb=write`, then run again with `--kb=check`.
  - Bug: `Esc->ui_cancel=false` on the second run.
  - Fixed: `true`.
- `pad_probe.tscn`: C7. Lists which gamepad inputs map to any action.
  - Bug: only `A->dodge`.
  - Fixed: the stick, D-pad, A, B and Start all map to actions.
- `lambda_probe.tscn`: H7. Shows that GDScript lambdas capture an `int` by value.

## Caveats

- The bot keeps the player alive by restoring HP inside the `health_changed` signal. That happens before `GameState.take_damage` checks for death, so every damage path still runs.
- Headless runs use a dummy audio driver that advances in *wall-clock* time. Sound nodes may therefore linger longer than in a real session, which is not a leak.
- Headless frame times exclude rendering.
