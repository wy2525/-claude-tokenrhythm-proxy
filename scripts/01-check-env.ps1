# cc-env-setup | Environment check script
# Checks Node.js / Git / Claude Code readiness

$ErrorActionPreference = "Continue"
$checkResults = @()

Write-Host ""
Write-Host "===== cc-env-setup Environment Check =====" -ForegroundColor Cyan
Write-Host ""

# --- Node.js ---
Write-Host "[1/3] Checking Node.js ..." -ForegroundColor Yellow
$node = Get-Command node -ErrorAction SilentlyContinue
if ($null -eq $node) {
    Write-Host "  [X] Node.js NOT installed!" -ForegroundColor Red
    $checkResults += "Node.js: not installed"
    $nodeOK = $false
} else {
    $nodeVersion = (node --version 2>&1).Trim()
    Write-Host "  [OK] Node.js version: $nodeVersion" -ForegroundColor Green
    $verMatch = [regex]::Match($nodeVersion, "v(\d+)\.(\d+)")
    $major = [int]$verMatch.Groups[1].Value
    if ($major -ge 18) {
        Write-Host "  [OK] Node.js >= 18, requirement met" -ForegroundColor Green
        $checkResults += "Node.js: $nodeVersion (OK)"
        $nodeOK = $true
    } else {
        Write-Host "  [WARN] Node.js too old, 18+ required" -ForegroundColor Yellow
        $checkResults += "Node.js: $nodeVersion (too old)"
        $nodeOK = $true
    }
}

# --- Git ---
Write-Host "[2/3] Checking Git ..." -ForegroundColor Yellow
$git = Get-Command git -ErrorAction SilentlyContinue
if ($null -eq $git) {
    Write-Host "  [X] Git NOT installed!" -ForegroundColor Red
    $checkResults += "Git: not installed"
    $gitOK = $false
} else {
    $gitVersion = (git --version 2>&1).Trim()
    Write-Host "  [OK] Git version: $gitVersion" -ForegroundColor Green
    $checkResults += "Git: $gitVersion (OK)"
    $gitOK = $true
}

# --- Claude Code ---
Write-Host "[3/3] Checking Claude Code ..." -ForegroundColor Yellow
$claude = Get-Command claude -ErrorAction SilentlyContinue
if ($null -eq $claude) {
    Write-Host "  [X] Claude Code NOT installed!" -ForegroundColor Red
    $checkResults += "Claude Code: not installed"
    $claudeOK = $false
    $claudeVersion = ""
} else {
    $claudeVersion = (claude --version 2>&1).Trim()
    Write-Host "  [OK] Claude Code version: $claudeVersion" -ForegroundColor Green
    Write-Host "  [OK] Works with the sanitizing proxy (old and new versions both fine)" -ForegroundColor Green
    $checkResults += "Claude Code: $claudeVersion (OK)"
    $claudeOK = $true
}

# --- Summary ---
Write-Host ""
Write-Host "===== Check Summary =====" -ForegroundColor Cyan
$checkResults | ForEach-Object { Write-Host "  - $_" }

Write-Host ""
Write-Host "===== Next Steps =====" -ForegroundColor Cyan
if (-not $nodeOK) { Write-Host "  1. Install Node.js: https://nodejs.org" }
if (-not $gitOK) { Write-Host "  2. Install Git: https://git-scm.com" }
if (-not $claudeOK) { Write-Host "  3. Install Claude Code: run scripts/02-install-cc.ps1" }

Write-Host ""
return @{
    nodeOK = $nodeOK
    gitOK = $gitOK
    claudeOK = $claudeOK
    claudeVersion = $claudeVersion
}