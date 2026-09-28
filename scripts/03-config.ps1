# cc-env-setup | Configure TokenRhythm Key / Model
# Config is saved to local .local-config.json (not pushed)

$ErrorActionPreference = "Continue"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$configPath = Join-Path $scriptDir "..\.local-config.json"

Write-Host ""
Write-Host "===== TokenRhythm Configuration =====" -ForegroundColor Cyan
Write-Host ""

$existingKey = ""
$existingModel = "deepseek-flash"
if (Test-Path $configPath) {
    try {
        $cfg = Get-Content $configPath -Raw | ConvertFrom-Json
        $existingKey = $cfg.apiKey
        if ($cfg.model) { $existingModel = $cfg.model }
        Write-Host "Existing config found. Will keep or overwrite." -ForegroundColor Yellow
    } catch {}
}

Write-Host "Enter TokenRhythm API Key:" -ForegroundColor Yellow
if ($existingKey) { Write-Host "  (current: $($existingKey.Substring(0,[Math]::Min(10,$existingKey.Length)))... press Enter to keep)" -ForegroundColor Gray }
$apiKey = Read-Host "API Key"
if ([string]::IsNullOrWhiteSpace($apiKey)) { $apiKey = $existingKey }
if ([string]::IsNullOrWhiteSpace($apiKey)) {
    Write-Host "[X] API Key cannot be empty" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Select model (supports Anthropic protocol):" -ForegroundColor Yellow
Write-Host "  1. deepseek-flash"
Write-Host "  2. glm-5.3-flashx"
Write-Host "  3. deepseek-v4-pro-0813"
Write-Host "  4. mimo-v2.6-pro"
$modelChoice = Read-Host "Select [1-4]"
switch ($modelChoice) {
    "1" { $model = "deepseek-flash" }
    "2" { $model = "glm-5.3-flashx" }
    "3" { $model = "deepseek-v4-pro-0813" }
    "4" { $model = "mimo-v2.6-pro" }
    default { $model = $existingModel; Write-Host "Using existing model: $model" }
}

$config = @{ apiKey = $apiKey; model = $model }
$config | ConvertTo-Json | Set-Content -Path $configPath -Encoding UTF8

Write-Host ""
Write-Host "[OK] Config saved to: $configPath" -ForegroundColor Green
Write-Host "     This file is excluded from git (.gitignore), will NOT be pushed." -ForegroundColor Yellow
Write-Host "     API Key: $($apiKey.Substring(0,[Math]::Min(10,$apiKey.Length)))..."
Write-Host "     Model:   $model"
Write-Host ""
Write-Host "===== Configuration complete =====" -ForegroundColor Cyan