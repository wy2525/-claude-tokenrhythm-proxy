# cc-env-setup | Configure provider (TokenRhythm / DeepSeek / Custom)
# Saves per-provider profiles to .local-config.json (not pushed)

$ErrorActionPreference = "Continue"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$configPath = Join-Path $scriptDir "..\.local-config.json"

Write-Host ""
Write-Host "===== Provider Configuration =====" -ForegroundColor Cyan
Write-Host ""

$presets = @{
    "1" = @{ key = "tokenrhythm"; baseUrl = "https://tokenrhythm.studio/v1";        models = "deepseek-flash / glm-5.3-flashx / deepseek-v4-pro-0813 / mimo-v2.6-pro" }
    "2" = @{ key = "deepseek";    baseUrl = "https://api.deepseek.com/anthropic";    models = "deepseek-chat / deepseek-reasoner" }
    "3" = @{ key = "custom";      baseUrl = "";                                      models = "type your own model name" }
}

Write-Host "Select provider:" -ForegroundColor Yellow
Write-Host "  1. TokenRhythm (base: https://tokenrhythm.studio/v1)"
Write-Host "  2. DeepSeek Official (base: https://api.deepseek.com/anthropic)"
Write-Host "  3. Custom (any Anthropic-compatible gateway)"
$pChoice = Read-Host "Select [1-3]"
if (-not $presets.ContainsKey($pChoice)) { $pChoice = "1" }
$provider = $presets[$pChoice]

# Base URL
$defaultBase = $provider.baseUrl
$baseUrl = Read-Host "BaseURL [default: $defaultBase]"
if ([string]::IsNullOrWhiteSpace($baseUrl)) { $baseUrl = $defaultBase }
if ([string]::IsNullOrWhiteSpace($baseUrl)) {
    Write-Host "[X] BaseURL cannot be empty for custom provider" -ForegroundColor Red
    exit 1
}

# API Key
$apiKey = Read-Host "API Key"
if ([string]::IsNullOrWhiteSpace($apiKey)) {
    Write-Host "[X] API Key cannot be empty" -ForegroundColor Red
    exit 1
}

# Model
Write-Host "Common models: $($provider.models)" -ForegroundColor Gray
$model = Read-Host "Model"
if ([string]::IsNullOrWhiteSpace($model)) {
    Write-Host "[X] Model cannot be empty" -ForegroundColor Red
    exit 1
}

# Load existing config or create new (multi-profile format)
$config = $null
if (Test-Path $configPath) {
    try {
        $raw = Get-Content $configPath -Raw | ConvertFrom-Json
        if ($raw.profiles) { $config = $raw }
        else {
            # migrate legacy
            $config = [pscustomobject]@{
                active = "tokenrhythm"
                profiles = [pscustomobject]@{
                    tokenrhythm = [pscustomobject]@{ baseUrl = "https://tokenrhythm.studio/v1"; apiKey = $raw.apiKey; model = $raw.model }
                }
            }
        }
    } catch {}
}
if ($null -eq $config) {
    $config = [pscustomobject]@{ active = $provider.key; profiles = [pscustomobject]@{} }
}

# Save profile
$p = [pscustomobject]@{ baseUrl = $baseUrl; apiKey = $apiKey; model = $model }
$pkey = $provider.key
if ($config.profiles.PSObject.Properties.Name -contains $pkey) {
    $config.profiles.$pkey = $p
} else {
    $config.profiles | Add-Member -NotePropertyName $pkey -NotePropertyValue $p -Force
}
$config | Add-Member -NotePropertyName "active" -NotePropertyValue $provider.key -Force
$config | ConvertTo-Json -Depth 6 | Set-Content -Path $configPath -Encoding UTF8

Write-Host ""
Write-Host "[OK] Config saved to: $configPath" -ForegroundColor Green
Write-Host "     Provider: $($provider.key)"
Write-Host "     BaseURL:  $baseUrl"
Write-Host "     Model:    $model"
Write-Host "     This file is excluded from git, will NOT be pushed." -ForegroundColor Yellow
Write-Host ""
Write-Host "===== Configuration complete =====" -ForegroundColor Cyan