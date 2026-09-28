# cc-env-setup | Main script
# One-click configure Claude Code + TokenRhythm environment

$ErrorActionPreference = "Continue"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$scriptsDir = Join-Path $scriptDir "scripts"

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  cc-env-setup | Claude Code Setup Tool" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

function Run-Script {
    param([string]$Name)
    $path = Join-Path $scriptsDir $Name
    if (Test-Path $path) {
        & $path
    } else {
        Write-Host "[X] Script not found: $Name" -ForegroundColor Red
    }
}

$quit = $false
while (-not $quit) {
    Write-Host "Select an action:" -ForegroundColor Yellow
    Write-Host "  1. Check environment (Node/Git/Claude Code)"
    Write-Host "  2. Install / Downgrade Claude Code"
    Write-Host "  3. Configure TokenRhythm Key/Model"
    Write-Host "  4. Start Claude Code"
    Write-Host "  5. Full flow (check -> install -> config -> start)"
    Write-Host "  0. Exit"
    Write-Host ""
    $choice = Read-Host "Enter choice [0-5]"

    switch ($choice) {
        "1" { Run-Script "01-check-env.ps1" }
        "2" { Run-Script "02-install-cc.ps1" }
        "3" { Run-Script "03-config.ps1" }
        "4" { Run-Script "04-start.ps1" }
        "5" {
            Write-Host "--- Full flow starting ---" -ForegroundColor Cyan
            Run-Script "01-check-env.ps1"
            Write-Host ""
            Run-Script "02-install-cc.ps1"
            Write-Host ""
            Run-Script "03-config.ps1"
            Write-Host ""
            Run-Script "04-start.ps1"
        }
        "0" {
            Write-Host "Exiting" -ForegroundColor Green
            $quit = $true
        }
        default { Write-Host "[X] Invalid choice, try again" -ForegroundColor Red }
    }

    if (-not $quit) {
        Write-Host ""
        $cont = Read-Host "Press Enter to return to menu, or 'q' to quit"
        if ($cont -eq "q") { $quit = $true }
    }
}