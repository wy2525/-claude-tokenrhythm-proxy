Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$startScript = Join-Path $scriptDir "scripts\04-start.ps1"
$checkScript = Join-Path $scriptDir "scripts\01-check-env.ps1"
$installScript = Join-Path $scriptDir "scripts\02-install-cc.ps1"
$configPath = Join-Path $scriptDir ".local-config.json"

# --- Provider presets ---
$script:presets = @{
    "TokenRhythm"      = @{ key = "tokenrhythm"; baseUrl = "https://tokenrhythm.studio/v1";        models = @("deepseek-flash", "glm-5.3-flashx", "deepseek-v4-pro-0813", "mimo-v2.6-pro") }
    "DeepSeek Official"= @{ key = "deepseek";      baseUrl = "https://api.deepseek.com/anthropic"; models = @("deepseek-chat", "deepseek-reasoner") }
    "Custom"           = @{ key = "custom";        baseUrl = "";                                   models = @() }
}
$script:presetOrder = @("TokenRhythm", "DeepSeek Official", "Custom")

# --- Config load (multi-profile, with legacy migration) ---
$script:config = $null
function Load-Config {
    if (Test-Path $configPath) {
        try {
            $raw = Get-Content $configPath -Raw | ConvertFrom-Json
            if ($raw.profiles) {
                $script:config = $raw
            } else {
                # Legacy single config -> migrate to tokenrhythm profile
                $script:config = [pscustomobject]@{
                    active = "tokenrhythm"
                    profiles = [pscustomobject]@{
                        tokenrhythm = [pscustomobject]@{ baseUrl = "https://tokenrhythm.studio/v1"; apiKey = $raw.apiKey; model = $raw.model }
                    }
                }
            }
        } catch {
            $script:config = $null
        }
    }
    if ($null -eq $script:config) {
        $script:config = [pscustomobject]@{ active = "tokenrhythm"; profiles = [pscustomobject]@{} }
    }
}
Load-Config

function Get-Profile {
    param([string]$ProfileKey)
    if ($script:config.profiles.PSObject.Properties.Name -contains $ProfileKey) {
        return $script:config.profiles.$ProfileKey
    }
    return $null
}

function Save-Profile {
    param([string]$ProfileKey, [string]$BaseUrl, [string]$ApiKey, [string]$Model)
    $p = [pscustomobject]@{ baseUrl = $BaseUrl; apiKey = $ApiKey; model = $Model }
    if ($script:config.profiles.PSObject.Properties.Name -contains $ProfileKey) {
        $script:config.profiles.$ProfileKey = $p
    } else {
        $script:config.profiles | Add-Member -NotePropertyName $ProfileKey -NotePropertyValue $p -Force
    }
    $script:config | Add-Member -NotePropertyName "active" -NotePropertyValue $ProfileKey -Force
    $script:config | ConvertTo-Json -Depth 6 | Set-Content -Path $configPath -Encoding UTF8
}

# --- Form ---
$form = New-Object System.Windows.Forms.Form
$form.Text = "Claude Code Gateway Setup"
$form.Size = New-Object System.Drawing.Size(560, 680)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false

$lblTitle = New-Object System.Windows.Forms.Label
$lblTitle.Text = "Claude Code Gateway - Any Provider"
$lblTitle.Font = New-Object System.Drawing.Font("Arial", 14, [System.Drawing.FontStyle]::Bold)
$lblTitle.Location = New-Object System.Drawing.Point(20, 15)
$lblTitle.Size = New-Object System.Drawing.Size(500, 30)

# --- Provider ---
$lblProvider = New-Object System.Windows.Forms.Label
$lblProvider.Text = "Provider:"
$lblProvider.Location = New-Object System.Drawing.Point(20, 58)
$lblProvider.Size = New-Object System.Drawing.Size(70, 25)

$cmbProvider = New-Object System.Windows.Forms.ComboBox
$cmbProvider.Location = New-Object System.Drawing.Point(95, 56)
$cmbProvider.Size = New-Object System.Drawing.Size(425, 25)
$cmbProvider.DropDownStyle = "DropDownList"
[void]$cmbProvider.Items.AddRange($script:presetOrder)
$cmbProvider.SelectedIndex = 0

# --- Base URL ---
$lblBaseUrl = New-Object System.Windows.Forms.Label
$lblBaseUrl.Text = "BaseURL:"
$lblBaseUrl.Location = New-Object System.Drawing.Point(20, 93)
$lblBaseUrl.Size = New-Object System.Drawing.Size(70, 25)

$txtBaseUrl = New-Object System.Windows.Forms.TextBox
$txtBaseUrl.Location = New-Object System.Drawing.Point(95, 91)
$txtBaseUrl.Size = New-Object System.Drawing.Size(425, 25)

# --- API Key ---
$lblKey = New-Object System.Windows.Forms.Label
$lblKey.Text = "API Key:"
$lblKey.Location = New-Object System.Drawing.Point(20, 128)
$lblKey.Size = New-Object System.Drawing.Size(70, 25)

$txtKey = New-Object System.Windows.Forms.TextBox
$txtKey.Location = New-Object System.Drawing.Point(95, 126)
$txtKey.Size = New-Object System.Drawing.Size(425, 25)

# --- Model (editable) ---
$lblModel = New-Object System.Windows.Forms.Label
$lblModel.Text = "Model:"
$lblModel.Location = New-Object System.Drawing.Point(20, 163)
$lblModel.Size = New-Object System.Drawing.Size(70, 25)

$cmbModel = New-Object System.Windows.Forms.ComboBox
$cmbModel.Location = New-Object System.Drawing.Point(95, 161)
$cmbModel.Size = New-Object System.Drawing.Size(425, 25)
$cmbModel.DropDownStyle = "DropDown"

# --- Provider switch: fill fields from preset + saved profile ---
$cmbProvider.Add_SelectedIndexChanged({
    $name = $cmbProvider.SelectedItem
    $preset = $script:presets[$name]
    $pkey = $preset.key

    $txtBaseUrl.Text = $preset.baseUrl

    $cmbModel.Items.Clear()
    if ($preset.models.Count -gt 0) {
        [void]$cmbModel.Items.AddRange($preset.models)
        $cmbModel.SelectedIndex = 0
    } else {
        $cmbModel.Text = ""
    }

    $p = Get-Profile -ProfileKey $pkey
    if ($p) {
        if ($p.baseUrl) { $txtBaseUrl.Text = $p.baseUrl }
        if ($p.apiKey) { $txtKey.Text = $p.apiKey }
        if ($p.model) {
            if (-not ($cmbModel.Items -contains $p.model)) { [void]$cmbModel.Items.Add($p.model) }
            $cmbModel.Text = $p.model
        }
    } else {
        $txtKey.Text = ""
    }
})

# --- Save Profile ---
$btnSave = New-Object System.Windows.Forms.Button
$btnSave.Text = "Save Config"
$btnSave.Location = New-Object System.Drawing.Point(95, 196)
$btnSave.Size = New-Object System.Drawing.Size(425, 30)
$btnSave.BackColor = [System.Drawing.Color]::LightYellow
$btnSave.Add_Click({
    $pkey = $script:presets[$cmbProvider.SelectedItem].key
    $key = $txtKey.Text.Trim()
    $baseUrl = $txtBaseUrl.Text.Trim()
    $model = $cmbModel.Text.Trim()
    if ([string]::IsNullOrWhiteSpace($key)) {
        [System.Windows.Forms.MessageBox]::Show("API Key cannot be empty!", "Error", "OK", "Warning") | Out-Null
        return
    }
    if ([string]::IsNullOrWhiteSpace($baseUrl)) {
        [System.Windows.Forms.MessageBox]::Show("BaseURL cannot be empty!", "Error", "OK", "Warning") | Out-Null
        return
    }
    if ([string]::IsNullOrWhiteSpace($model)) {
        [System.Windows.Forms.MessageBox]::Show("Model cannot be empty!", "Error", "OK", "Warning") | Out-Null
        return
    }
    try {
        Save-Profile -ProfileKey $pkey -BaseUrl $baseUrl -ApiKey $key -Model $model
        [System.Windows.Forms.MessageBox]::Show("Config saved!`nProvider: $($cmbProvider.SelectedItem)`nKey: $($key.Substring(0,[Math]::Min(10,$key.Length)))...`nModel: $model", "Success", "OK", "Information") | Out-Null
    } catch {
        [System.Windows.Forms.MessageBox]::Show("Save failed: $($_.Exception.Message)", "Error", "OK", "Error") | Out-Null
    }
})

# --- WorkDir ---
$lblWorkDir = New-Object System.Windows.Forms.Label
$lblWorkDir.Text = "Dir:"
$lblWorkDir.Location = New-Object System.Drawing.Point(20, 240)
$lblWorkDir.Size = New-Object System.Drawing.Size(70, 25)

$txtWorkDir = New-Object System.Windows.Forms.TextBox
$txtWorkDir.Location = New-Object System.Drawing.Point(95, 238)
$txtWorkDir.Size = New-Object System.Drawing.Size(370, 25)
$txtWorkDir.Text = (Get-Location).Path

$btnBrowse = New-Object System.Windows.Forms.Button
$btnBrowse.Text = "..."
$btnBrowse.Location = New-Object System.Drawing.Point(475, 237)
$btnBrowse.Size = New-Object System.Drawing.Size(45, 25)
$btnBrowse.Add_Click({
    $d = New-Object System.Windows.Forms.FolderBrowserDialog
    $d.Description = "Select working directory"
    $d.SelectedPath = $txtWorkDir.Text
    if ($d.ShowDialog() -eq "OK") { $txtWorkDir.Text = $d.SelectedPath }
})

# --- Action buttons ---
$btnCheck = New-Object System.Windows.Forms.Button
$btnCheck.Text = "Check Env"
$btnCheck.Location = New-Object System.Drawing.Point(95, 278)
$btnCheck.Size = New-Object System.Drawing.Size(135, 35)
$btnCheck.Add_Click({
    Start-Process powershell -ArgumentList "-NoExit -NoProfile -ExecutionPolicy Bypass -File `"$checkScript`""
})

$btnInstall = New-Object System.Windows.Forms.Button
$btnInstall.Text = "Install"
$btnInstall.Location = New-Object System.Drawing.Point(240, 278)
$btnInstall.Size = New-Object System.Drawing.Size(135, 35)
$btnInstall.Add_Click({
    Start-Process powershell -ArgumentList "-NoExit -NoProfile -ExecutionPolicy Bypass -File `"$installScript`""
})

$btnStart = New-Object System.Windows.Forms.Button
$btnStart.Text = "Start Claude Code"
$btnStart.Location = New-Object System.Drawing.Point(385, 278)
$btnStart.Size = New-Object System.Drawing.Size(135, 35)
$btnStart.BackColor = [System.Drawing.Color]::LightGreen
$btnStart.Font = New-Object System.Drawing.Font("Arial", 9, [System.Drawing.FontStyle]::Bold)
$btnStart.Add_Click({
    $pkey = $script:presets[$cmbProvider.SelectedItem].key
    $model = $cmbModel.Text.Trim()
    $baseUrl = $txtBaseUrl.Text.Trim()
    $key = $txtKey.Text.Trim()
    $workDir = $txtWorkDir.Text.Trim()

    if (-not (Test-Path $workDir)) {
        [System.Windows.Forms.MessageBox]::Show("Working directory does not exist: $workDir", "Error", "OK", "Error") | Out-Null
        return
    }
    if ([string]::IsNullOrWhiteSpace($key) -or [string]::IsNullOrWhiteSpace($baseUrl) -or [string]::IsNullOrWhiteSpace($model)) {
        [System.Windows.Forms.MessageBox]::Show("Please fill in BaseURL / API Key / Model, then click Save Config first.", "Error", "OK", "Warning") | Out-Null
        return
    }
    # Persist config before starting
    try { Save-Profile -ProfileKey $pkey -BaseUrl $baseUrl -ApiKey $key -Model $model } catch {}

    $launchArgs = "-NoProfile -ExecutionPolicy Bypass -File `"$startScript`" -Model `"$model`" -WorkDir `"$workDir`" -BaseUrl `"$baseUrl`" -ApiKey `"$key`""
    Start-Process powershell -ArgumentList $launchArgs
})

# --- Info ---
$lblInfo = New-Object System.Windows.Forms.Label
$lblInfo.Text = @"
Multi-Provider Setup

1. Pick a Provider (TokenRhythm / DeepSeek / Custom)
2. Fill in BaseURL, API Key, Model (editable)
3. Click [Save Config] - each provider keeps its own profile
4. Choose working directory
5. Click [Start Claude Code]

Presets:
- TokenRhythm: https://tokenrhythm.studio/v1
- DeepSeek:    https://api.deepseek.com/anthropic
- Custom:      any Anthropic-compatible gateway URL

Switch providers anytime - configs are saved per provider.
Key is stored in .local-config.json (excluded from git).
"@
$lblInfo.Location = New-Object System.Drawing.Point(20, 330)
$lblInfo.Size = New-Object System.Drawing.Size(500, 300)
$lblInfo.Font = New-Object System.Drawing.Font("Arial", 9)
$lblInfo.ForeColor = [System.Drawing.Color]::Gray

$form.Controls.AddRange(@($lblTitle, $lblProvider, $cmbProvider, $lblBaseUrl, $txtBaseUrl, $lblKey, $txtKey, $lblModel, $cmbModel, $btnSave, $lblWorkDir, $txtWorkDir, $btnBrowse, $btnCheck, $btnInstall, $btnStart, $lblInfo))

# --- Initial load: restore active profile ---
$activeKey = if ($script:config.active) { $script:config.active } else { "tokenrhythm" }
$activeIdx = 0
for ($i = 0; $i -lt $script:presetOrder.Count; $i++) {
    if ($script:presets[$script:presetOrder[$i]].key -eq $activeKey) { $activeIdx = $i; break }
}
$cmbProvider.SelectedIndex = $activeIdx

[System.Windows.Forms.Application]::EnableVisualStyles()
[System.Windows.Forms.Application]::Run($form)