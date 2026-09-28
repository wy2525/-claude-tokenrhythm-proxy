Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$startScript = Join-Path $scriptDir "scripts\04-start.ps1"
$checkScript = Join-Path $scriptDir "scripts\01-check-env.ps1"
$installScript = Join-Path $scriptDir "scripts\02-install-cc.ps1"
$configScript = Join-Path $scriptDir "scripts\03-config.ps1"

$form = New-Object System.Windows.Forms.Form
$form.Text = "Claude Code Environment Setup"
$form.Size = New-Object System.Drawing.Size(520, 620)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false

$lblTitle = New-Object System.Windows.Forms.Label
$lblTitle.Text = "Claude Code + TokenRhythm Setup"
$lblTitle.Font = New-Object System.Drawing.Font("Arial", 14, [System.Drawing.FontStyle]::Bold)
$lblTitle.Location = New-Object System.Drawing.Point(20, 15)
$lblTitle.Size = New-Object System.Drawing.Size(460, 30)

$lblModel = New-Object System.Windows.Forms.Label
$lblModel.Text = "Model:"
$lblModel.Location = New-Object System.Drawing.Point(20, 65)
$lblModel.Size = New-Object System.Drawing.Size(60, 25)

$cmbModel = New-Object System.Windows.Forms.ComboBox
$cmbModel.Location = New-Object System.Drawing.Point(90, 63)
$cmbModel.Size = New-Object System.Drawing.Size(390, 25)
$cmbModel.DropDownStyle = "DropDownList"
$cmbModel.Items.AddRange(@("deepseek-flash", "glm-5.3-flashx", "deepseek-v4-pro-0813", "mimo-v2.6-pro"))
$cmbModel.SelectedIndex = 0

$lblWorkDir = New-Object System.Windows.Forms.Label
$lblWorkDir.Text = "Dir:"
$lblWorkDir.Location = New-Object System.Drawing.Point(20, 100)
$lblWorkDir.Size = New-Object System.Drawing.Size(60, 25)

$txtWorkDir = New-Object System.Windows.Forms.TextBox
$txtWorkDir.Location = New-Object System.Drawing.Point(90, 98)
$txtWorkDir.Size = New-Object System.Drawing.Size(305, 25)
$txtWorkDir.Text = (Get-Location).Path

$btnBrowse = New-Object System.Windows.Forms.Button
$btnBrowse.Text = "..."
$btnBrowse.Location = New-Object System.Drawing.Point(405, 97)
$btnBrowse.Size = New-Object System.Drawing.Size(40, 25)
$btnBrowse.Add_Click({
    $d = New-Object System.Windows.Forms.FolderBrowserDialog
    $d.Description = "Select working directory"
    $d.SelectedPath = $txtWorkDir.Text
    if ($d.ShowDialog() -eq "OK") { $txtWorkDir.Text = $d.SelectedPath }
})

$btnCheck = New-Object System.Windows.Forms.Button
$btnCheck.Text = "Check Env"
$btnCheck.Location = New-Object System.Drawing.Point(90, 140)
$btnCheck.Size = New-Object System.Drawing.Size(120, 35)
$btnCheck.Add_Click({
    Start-Process powershell -ArgumentList "-NoExit -NoProfile -ExecutionPolicy Bypass -File `"$checkScript`""
})

$btnInstall = New-Object System.Windows.Forms.Button
$btnInstall.Text = "Install"
$btnInstall.Location = New-Object System.Drawing.Point(220, 140)
$btnInstall.Size = New-Object System.Drawing.Size(120, 35)
$btnInstall.Add_Click({
    Start-Process powershell -ArgumentList "-NoExit -NoProfile -ExecutionPolicy Bypass -File `"$installScript`""
})

$btnConfig = New-Object System.Windows.Forms.Button
$btnConfig.Text = "Config Key"
$btnConfig.Location = New-Object System.Drawing.Point(350, 140)
$btnConfig.Size = New-Object System.Drawing.Size(120, 35)
$btnConfig.Add_Click({
    Start-Process powershell -ArgumentList "-NoExit -NoProfile -ExecutionPolicy Bypass -File `"$configScript`""
})

$btnStart = New-Object System.Windows.Forms.Button
$btnStart.Text = "Start Claude Code"
$btnStart.Location = New-Object System.Drawing.Point(140, 200)
$btnStart.Size = New-Object System.Drawing.Size(220, 45)
$btnStart.BackColor = [System.Drawing.Color]::LightGreen
$btnStart.Font = New-Object System.Drawing.Font("Arial", 11, [System.Drawing.FontStyle]::Bold)
$btnStart.Add_Click({
    $model = $cmbModel.SelectedItem
    $workDir = $txtWorkDir.Text.Trim()
    if (-not (Test-Path $workDir)) {
        [System.Windows.Forms.MessageBox]::Show("Working directory does not exist: $workDir", "Error", "OK", "Error")
        return
    }
    $args = "-NoProfile -ExecutionPolicy Bypass -File `"$startScript`" -Model `"$model`" -WorkDir `"$workDir`""
    Start-Process powershell -ArgumentList $args
})

$lblInfo = New-Object System.Windows.Forms.Label
$lblInfo.Text = @"
Environment Setup Tool

1. Check Env - verify Node/Git/Claude Code
2. Install - install compatible Claude Code (2.1.153)
3. Config Key - set TokenRhythm API Key and model
4. Start - start local proxy + Claude Code

Key is stored in .local-config.json (excluded from git).
"@
$lblInfo.Location = New-Object System.Drawing.Point(20, 270)
$lblInfo.Size = New-Object System.Drawing.Size(460, 260)
$lblInfo.Font = New-Object System.Drawing.Font("Arial", 9)
$lblInfo.ForeColor = [System.Drawing.Color]::Gray

$form.Controls.AddRange(@($lblTitle, $lblModel, $cmbModel, $lblWorkDir, $txtWorkDir, $btnBrowse, $btnCheck, $btnInstall, $btnConfig, $btnStart, $lblInfo))

[System.Windows.Forms.Application]::EnableVisualStyles()
[System.Windows.Forms.Application]::Run($form)