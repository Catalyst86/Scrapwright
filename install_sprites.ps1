# Scrapwright — Sprite Installer
# Right-click this file -> Run with PowerShell
# Copies all sprites from the downloaded sprite_transfer folder into the project.
#
# HOW TO USE:
#   1. Download sprite_transfer.zip from Claude chat
#   2. Extract it anywhere (e.g. Desktop\sprite_transfer)
#   3. Edit $SRC below to match where you extracted it
#   4. Run this script

$SRC  = "$env:USERPROFILE\Desktop\sprite_transfer"
$PROJ = "$env:USERPROFILE\Desktop\roguelite\assets\sprites"

if (-not (Test-Path $SRC)) {
    Write-Host "ERROR: Source folder not found: $SRC" -ForegroundColor Red
    Write-Host "Edit the SRC variable in this script to point to your extracted sprite_transfer folder."
    pause
    exit
}

$copies = @(
    # Player sprites
    @{ s = "player\player_idle.png";          d = "player\player_idle.png" },
    @{ s = "player\player_walk_s.png";         d = "player\player_walk_s.png" },
    @{ s = "player\player_walk_n.png";         d = "player\player_walk_n.png" },
    @{ s = "player\player_walk_e.png";         d = "player\player_walk_e.png" },
    @{ s = "player\player_walk_w.png";         d = "player\player_walk_w.png" },
    @{ s = "player\player_throw.png";          d = "player\player_throw.png" },
    @{ s = "player\player_salvage.png";        d = "player\player_salvage.png" },
    @{ s = "player\player_hurt.png";           d = "player\player_hurt.png" },
    @{ s = "player\player_death.png";          d = "player\player_death.png" },
    @{ s = "player\walk_s_0.png";              d = "player\walk_s_0.png" },
    @{ s = "player\walk_s_1.png";              d = "player\walk_s_1.png" },
    @{ s = "player\walk_s_2.png";              d = "player\walk_s_2.png" },
    @{ s = "player\walk_s_3.png";              d = "player\walk_s_3.png" },
    @{ s = "player\walk_n_0.png";              d = "player\walk_n_0.png" },
    @{ s = "player\walk_n_1.png";              d = "player\walk_n_1.png" },
    @{ s = "player\walk_n_2.png";              d = "player\walk_n_2.png" },
    @{ s = "player\walk_n_3.png";              d = "player\walk_n_3.png" },
    @{ s = "player\walk_e_0.png";              d = "player\walk_e_0.png" },
    @{ s = "player\walk_e_1.png";              d = "player\walk_e_1.png" },
    @{ s = "player\walk_e_2.png";              d = "player\walk_e_2.png" },
    @{ s = "player\walk_e_3.png";              d = "player\walk_e_3.png" },
    @{ s = "player\walk_w_0.png";              d = "player\walk_w_0.png" },
    @{ s = "player\walk_w_1.png";              d = "player\walk_w_1.png" },
    @{ s = "player\walk_w_2.png";              d = "player\walk_w_2.png" },
    @{ s = "player\walk_w_3.png";              d = "player\walk_w_3.png" },
    @{ s = "player\throw_0.png";               d = "player\throw_0.png" },
    @{ s = "player\throw_1.png";               d = "player\throw_1.png" },
    @{ s = "player\throw_2.png";               d = "player\throw_2.png" },
    @{ s = "player\throw_3.png";               d = "player\throw_3.png" },
    # Enemies
    @{ s = "enemies\enemy_rusher.png";         d = "enemies\enemy_rusher.png" },
    @{ s = "enemies\enemy_shooter.png";        d = "enemies\enemy_shooter.png" },
    @{ s = "enemies\enemy_tank.png";           d = "enemies\enemy_tank.png" },
    @{ s = "enemies\enemy_flyer.png";          d = "enemies\enemy_flyer.png" },
    @{ s = "enemies\enemy_exploder.png";       d = "enemies\enemy_exploder.png" },
    # Items
    @{ s = "items\item_throwing_knife.png";    d = "items\item_throwing_knife.png" },
    @{ s = "items\item_molotov.png";           d = "items\item_molotov.png" },
    @{ s = "items\item_pipe_bomb.png";         d = "items\item_pipe_bomb.png" },
    @{ s = "items\item_boomerang.png";         d = "items\item_boomerang.png" },
    @{ s = "items\mat_iron_scrap.png";         d = "items\mat_iron_scrap.png" },
    @{ s = "items\mat_timber.png";             d = "items\mat_timber.png" },
    @{ s = "items\mat_fuel.png";               d = "items\mat_fuel.png" },
    @{ s = "items\mat_organic.png";            d = "items\mat_organic.png" },
    @{ s = "items\mat_stone.png";              d = "items\mat_stone.png" },
    @{ s = "items\mat_blueprint.png";          d = "items\mat_blueprint.png" },
    @{ s = "items\salvage_tool_pickaxe.png";   d = "items\salvage_tool_pickaxe.png" },
    # Traps
    @{ s = "traps\trap_spikes.png";            d = "traps\trap_spikes.png" },
    @{ s = "traps\trap_fire.png";              d = "traps\trap_fire.png" },
    @{ s = "traps\trap_electric.png";          d = "traps\trap_electric.png" },
    # Environment
    @{ s = "environment\destructible_crate.png";  d = "environment\destructible_crate.png" },
    @{ s = "environment\destructible_barrel.png"; d = "environment\destructible_barrel.png" },
    @{ s = "environment\destructible_rubble.png"; d = "environment\destructible_rubble.png" },
    @{ s = "environment\destructible_corpse.png"; d = "environment\destructible_corpse.png" },
    # UI
    @{ s = "ui\ui_heart.png";                  d = "ui\ui_heart.png" },
    @{ s = "ui\ui_bag.png";                    d = "ui\ui_bag.png" },
    # Base buildings
    @{ s = "base\base_workbench.png";          d = "base\base_workbench.png" },
    @{ s = "base\base_forge.png";              d = "base\base_forge.png" },
    @{ s = "base\base_garden.png";             d = "base\base_garden.png" },
    @{ s = "base\base_armory.png";             d = "base\base_armory.png" },
    @{ s = "base\base_scrapheap.png";          d = "base\base_scrapheap.png" },
    # Animation sheets
    @{ s = "animations\player_walk_s_sheet.png";      d = "animations\player_walk_s_sheet.png" },
    @{ s = "animations\player_walk_n_sheet.png";      d = "animations\player_walk_n_sheet.png" },
    @{ s = "animations\player_walk_e_sheet.png";      d = "animations\player_walk_e_sheet.png" },
    @{ s = "animations\player_walk_w_sheet.png";      d = "animations\player_walk_w_sheet.png" },
    @{ s = "animations\player_attack_sheet.png";      d = "animations\player_attack_sheet.png" },
    @{ s = "animations\player_hurt_sheet.png";        d = "animations\player_hurt_sheet.png" },
    @{ s = "animations\player_death_sheet.png";       d = "animations\player_death_sheet.png" },
    @{ s = "animations\enemy_rusher_walk_sheet.png";  d = "animations\enemy_rusher_walk_sheet.png" },
    @{ s = "animations\enemy_rusher_die_sheet.png";   d = "animations\enemy_rusher_die_sheet.png" },
    @{ s = "animations\enemy_shooter_walk_sheet.png"; d = "animations\enemy_shooter_walk_sheet.png" },
    @{ s = "animations\enemy_shooter_die_sheet.png";  d = "animations\enemy_shooter_die_sheet.png" },
    @{ s = "animations\enemy_tank_walk_sheet.png";    d = "animations\enemy_tank_walk_sheet.png" },
    @{ s = "animations\enemy_tank_die_sheet.png";     d = "animations\enemy_tank_die_sheet.png" }
)

$ok = 0; $missing = 0
foreach ($c in $copies) {
    $srcFile = Join-Path $SRC $c.s
    $dstFile = Join-Path $PROJ $c.d
    $dstDir  = Split-Path $dstFile -Parent
    if (-not (Test-Path $dstDir)) { New-Item -ItemType Directory -Path $dstDir -Force | Out-Null }
    if (Test-Path $srcFile) {
        Copy-Item $srcFile $dstFile -Force
        $ok++
    } else {
        Write-Host "MISSING: $($c.s)" -ForegroundColor Yellow
        $missing++
    }
}

Write-Host ""
Write-Host "Done: $ok sprites copied, $missing missing." -ForegroundColor Green
Write-Host "Reload the project in Godot (Project > Reload Current Project)"
pause
