# cc-env-setup | Install Claude Code (latest or specific version)
# Latest works with the sanitizing proxy; 2.1.153 is a fallback option.

param(
    [string]$Version = "latest"
)

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "===== Claude Code Install =====" -ForegroundColor Cyan
Write-Host "Target: $Version" -ForegroundColor Yellow
Write-Host ""

$current = ""
$claude = Get-Command claude -ErrorAction SilentlyContinue
if ($null -ne $claude) { $current = (claude --version 2>&1).Trim() }
Write-Host "Current version: $current"

if ($Version -ne "latest" -and $current -eq $Version) {
    Write-Host "[OK] Already at target version, nothing to do" -ForegroundColor Green
    exit 0
}

Write-Host ""
Write-Host "Installing Claude Code ($Version) ..." -ForegroundColor Yellow

$pkg = "@anthropic-ai/claude-code"
if ($Version -eq "latest") { $pkg = "$pkg@latest" } else { $pkg = "$pkg@$Version" }

try {
    npm install -g $pkg 2>&1 | Out-Host
} catch {
    Write-Host "[X] Install failed. Try running PowerShell as Administrator." -ForegroundColor Red
    exit 1
}

Write-Host ""
$newVersion = (claude --version 2>&1).Trim()
Write-Host "Installed version: $newVersion"

if ($Version -eq "latest" -or $newVersion -eq $Version) {
    Write-Host "[OK] Install succeeded!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Note: BOTH latest and older versions work with this tool." -ForegroundColor Cyan
    Write-Host "      - Latest (2.1.283+): sanitizing proxy handles it automatically." -ForegroundColor Cyan
    Write-Host "      - Fallback old version: run this script with -Version 2.1.153" -ForegroundColor Cyan
} else {
    Write-Host "[WARN] Version may not have taken effect, reopen terminal to verify" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "===== Done =====" -ForegroundColor Cyan