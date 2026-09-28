Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$startScript = Join-Path $scriptDir "scripts\04-start.ps1"
$checkScript = Join-Path $scriptDir "scripts\01-check-env.ps1"
$installScript = Join-Path $scriptDir "scripts\02-install-cc.ps1"
$configPath = Join-Path $scriptDir ".local-config.json"

$form = New-Object System.Windows.Forms.Form
$form.Text = "Claude Code Environment Setup"
$form.Size = New-Object System.Drawing.Size(540, 620)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false

$lblTitle = New-Object System.Windows.Forms.Label
$lblTitle.Text = "Claude Code + TokenRhythm Setup"
$lblTitle.Font = New-Object System.Drawing.Font("Arial", 14, [System.Drawing.FontStyle]::Bold)
$lblTitle.Location = New-Object System.Drawing.Point(20, 15)
$lblTitle.Size = New-Object System.Drawing.Size(480, 30)

# API Key
$lblKey = New-Object System.Windows.Forms.Label
$lblKey.Text = "API Key:"
$lblKey.Location = New-Object System.Drawing.Point(20, 60)
$lblKey.Size = New-Object System.Drawing.Size(60, 25)

$txtKey = New-Object System.Windows.Forms.TextBox
$txtKey.Location = New-Object System.Drawing.Point(90, 58)
$txtKey.Size = New-Object System.Drawing.Size(410, 25)

$cfgModel = "deepseek-flash"
if (Test-Path $configPath) {
    try {
        $cfg = Get-Content $configPath -Raw | ConvertFrom-Json
        if ($cfg.apiKey) { $txtKey.Text = $cfg.apiKey }
        if ($cfg.model) { $cfgModel = $cfg.model }
    } catch {}
}

# Model
$lblModel = New-Object System.Windows.Forms.Label
$lblModel.Text = "Model:"
$lblModel.Location = New-Object System.Drawing.Point(20, 95)
$lblModel.Size = New-Object System.Drawing.Size(60, 25)

$cmbModel = New-Object System.Windows.Forms.ComboBox
$cmbModel.Location = New-Object System.Drawing.Point(90, 93)
$cmbModel.Size = New-Object System.Drawing.Size(410, 25)
$cmbModel.DropDownStyle = "DropDownList"
$cmbModel.Items.AddRange(@("deepseek-flash", "glm-5.3-flashx", "deepseek-v4-pro-0813", "mimo-v2.6-pro"))
$cmbModel.SelectedIndex = 0
for ($i = 0; $i -lt $cmbModel.Items.Count; $i++) {
    if ($cmbModel.Items[$i] -eq $cfgModel) { $cmbModel.SelectedIndex = $i; break }
}

# Save Config
$btnSaveConfig = New-Object System.Windows.Forms.Button
$btnSaveConfig.Text = "Save Key"
$btnSaveConfig.Location = New-Object System.Drawing.Point(90, 128)
$btnSaveConfig.Size = New-Object System.Drawing.Size(410, 30)
$btnSaveConfig.BackColor = [System.Drawing.Color]::LightYellow
$btnSaveConfig.Add_Click({
    $key = $txtKey.Text.Trim()
    if ([string]::IsNullOrWhiteSpace($key)) {
        [System.Windows.Forms.MessageBox]::Show("API Key cannot be empty!", "Error", "OK", "Warning")
        return
    }
    $model = $cmbModel.SelectedItem
    $cfgToSave = @{ apiKey = $key; model = $model }
    try {
        $cfgToSave | ConvertTo-Json | Set-Content -Path $configPath -Encoding UTF8
        [System.Windows.Forms.MessageBox]::Show("Config saved successfully!`nKey: $($key.Substring(0,[Math]::Min(10,$key.Length)))...`nModel: $model", "Success", "OK", "Information")
    } catch {
        [System.Windows.Forms.MessageBox]::Show("Failed to save config: $($_.Exception.Message)", "Error", "OK", "Error")
    }
})

# WorkDir
$lblWorkDir = New-Object System.Windows.Forms.Label
$lblWorkDir.Text = "Dir:"
$lblWorkDir.Location = New-Object System.Drawing.Point(20, 168)
$lblWorkDir.Size = New-Object System.Drawing.Size(60, 25)

$txtWorkDir = New-Object System.Windows.Forms.TextBox
$txtWorkDir.Location = New-Object System.Drawing.Point(90, 166)
$txtWorkDir.Size = New-Object System.Drawing.Size(355, 25)
$txtWorkDir.Text = (Get-Location).Path

$btnBrowse = New-Object System.Windows.Forms.Button
$btnBrowse.Text = "..."
$btnBrowse.Location = New-Object System.Drawing.Point(455, 165)
$btnBrowse.Size = New-Object System.Drawing.Size(45, 25)
$btnBrowse.Add_Click({
    $d = New-Object System.Windows.Forms.FolderBrowserDialog
    $d.Description = "Select working directory"
    $d.SelectedPath = $txtWorkDir.Text
    if ($d.ShowDialog() -eq "OK") { $txtWorkDir.Text = $d.SelectedPath }
})

# Buttons
$btnCheck = New-Object System.Windows.Forms.Button
$btnCheck.Text = "Check Env"
$btnCheck.Location = New-Object System.Drawing.Point(90, 205)
$btnCheck.Size = New-Object System.Drawing.Size(130, 35)
$btnCheck.Add_Click({
    Start-Process powershell -ArgumentList "-NoExit -NoProfile -ExecutionPolicy Bypass -File `"$checkScript`""
})

$btnInstall = New-Object System.Windows.Forms.Button
$btnInstall.Text = "Install"
$btnInstall.Location = New-Object System.Drawing.Point(230, 205)
$btnInstall.Size = New-Object System.Drawing.Size(130, 35)
$btnInstall.Add_Click({
    Start-Process powershell -ArgumentList "-NoExit -NoProfile -ExecutionPolicy Bypass -File `"$installScript`""
})

$btnStart = New-Object System.Windows.Forms.Button
$btnStart.Text = "Start Claude Code"
$btnStart.Location = New-Object System.Drawing.Point(370, 205)
$btnStart.Size = New-Object System.Drawing.Size(130, 35)
$btnStart.BackColor = [System.Drawing.Color]::LightGreen
$btnStart.Font = New-Object System.Drawing.Font("Arial", 10, [System.Drawing.FontStyle]::Bold)
$btnStart.Add_Click({
    $model = $cmbModel.SelectedItem
    $workDir = $txtWorkDir.Text.Trim()
    $key = $txtKey.Text.Trim()
    if (-not (Test-Path $workDir)) {
        [System.Windows.Forms.MessageBox]::Show("Working directory does not exist: $workDir", "Error", "OK", "Error")
        return
    }
    if ($key -and (-not (Test-Path $configPath))) {
        $cfgToSave = @{ apiKey = $key; model = $model }
        $cfgToSave | ConvertTo-Json | Set-Content -Path $configPath -Encoding UTF8
    }
    $launchArgs = "-NoProfile -ExecutionPolicy Bypass -File `"$startScript`" -Model `"$model`" -WorkDir `"$workDir`""
    Start-Process powershell -ArgumentList $launchArgs
})

# Info
$lblInfo = New-Object System.Windows.Forms.Label
$lblInfo.Text = @"
How to use:
1. Enter your TokenRhythm API Key above
2. Select model
3. Click [Save Key] to save
4. Choose working directory
5. Click [Start Claude Code]

Key is stored in .local-config.json (excluded from git).
"@
$lblInfo.Location = New-Object System.Drawing.Point(20, 260)
$lblInfo.Size = New-Object System.Drawing.Size(480, 260)
$lblInfo.Font = New-Object System.Drawing.Font("Arial", 9)
$lblInfo.ForeColor = [System.Drawing.Color]::Gray

$form.Controls.AddRange(@($lblTitle, $lblKey, $txtKey, $lblModel, $cmbModel, $btnSaveConfig, $lblWorkDir, $txtWorkDir, $btnBrowse, $btnCheck, $btnInstall, $btnStart, $lblInfo))

[System.Windows.Forms.Application]::EnableVisualStyles()
[System.Windows.Forms.Application]::Run($form)