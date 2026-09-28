Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$scriptPath = "E:\claude\claude-proxy\StartTokenRhythm.ps1"

$form = New-Object System.Windows.Forms.Form
$form.Text = "Claude Code Launcher"
$form.Size = New-Object System.Drawing.Size(500, 600)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false

# --- Title ---
$lblTitle = New-Object System.Windows.Forms.Label
$lblTitle.Text = "Claude Code (TokenRhythm) Launcher"
$lblTitle.Font = New-Object System.Drawing.Font("Arial", 14, [System.Drawing.FontStyle]::Bold)
$lblTitle.Location = New-Object System.Drawing.Point(20, 15)
$lblTitle.Size = New-Object System.Drawing.Size(440, 30)

# --- API Key ---
$lblKey = New-Object System.Windows.Forms.Label
$lblKey.Text = "API Key:"
$lblKey.Location = New-Object System.Drawing.Point(20, 60)
$lblKey.Size = New-Object System.Drawing.Size(90, 25)

$txtKey = New-Object System.Windows.Forms.TextBox
$txtKey.Location = New-Object System.Drawing.Point(120, 58)
$txtKey.Size = New-Object System.Drawing.Size(350, 25)

$localConfigPath = Join-Path $PSScriptRoot ".local-config.json"
$defaultKey = "sk_tr_YOUR_KEY_HERE"
if (Test-Path $localConfigPath) {
    try {
        $localCfg = Get-Content $localConfigPath -Raw | ConvertFrom-Json
        if ($localCfg.apiKey) { $defaultKey = $localCfg.apiKey }
    } catch {}
}
$txtKey.Text = $defaultKey

# --- Model ---
$lblModel = New-Object System.Windows.Forms.Label
$lblModel.Text = "Model:"
$lblModel.Location = New-Object System.Drawing.Point(20, 95)
$lblModel.Size = New-Object System.Drawing.Size(90, 25)

$cmbModel = New-Object System.Windows.Forms.ComboBox
$cmbModel.Location = New-Object System.Drawing.Point(120, 93)
$cmbModel.Size = New-Object System.Drawing.Size(350, 25)
$cmbModel.DropDownStyle = "DropDownList"
$cmbModel.Items.AddRange(@("deepseek-flash", "glm-5.3-flashx", "deepseek-v4-pro-0813", "mimo-v2.6-pro"))
$cmbModel.SelectedIndex = 0

# --- Working Directory ---
$lblWorkDir = New-Object System.Windows.Forms.Label
$lblWorkDir.Text = "Work Dir:"
$lblWorkDir.Location = New-Object System.Drawing.Point(20, 130)
$lblWorkDir.Size = New-Object System.Drawing.Size(90, 25)

$txtWorkDir = New-Object System.Windows.Forms.TextBox
$txtWorkDir.Location = New-Object System.Drawing.Point(120, 128)
$txtWorkDir.Size = New-Object System.Drawing.Size(265, 25)
$txtWorkDir.Text = (Get-Location).Path

$btnBrowse = New-Object System.Windows.Forms.Button
$btnBrowse.Text = "Browse..."
$btnBrowse.Location = New-Object System.Drawing.Point(395, 127)
$btnBrowse.Size = New-Object System.Drawing.Size(75, 25)

$btnBrowse.Add_Click({
    $folderDialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $folderDialog.Description = "Select working directory"
    $folderDialog.SelectedPath = $txtWorkDir.Text
    if ($folderDialog.ShowDialog() -eq "OK") {
        $txtWorkDir.Text = $folderDialog.SelectedPath
    }
})

# --- Info ---
$lblInfo = New-Object System.Windows.Forms.Label
$lblInfo.Text = "Starts local sanitizing proxy + Claude Code. Cleans up on exit."
$lblInfo.Location = New-Object System.Drawing.Point(20, 165)
$lblInfo.Size = New-Object System.Drawing.Size(440, 40)
$lblInfo.ForeColor = [System.Drawing.Color]::Gray

# --- Status ---
$lblStatus = New-Object System.Windows.Forms.Label
$lblStatus.Text = ""
$lblStatus.Location = New-Object System.Drawing.Point(20, 205)
$lblStatus.Size = New-Object System.Drawing.Size(440, 40)
$lblStatus.ForeColor = [System.Drawing.Color]::Green

# --- Start Button ---
$btnStart = New-Object System.Windows.Forms.Button
$btnStart.Text = "Start Claude Code"
$btnStart.Location = New-Object System.Drawing.Point(150, 250)
$btnStart.Size = New-Object System.Drawing.Size(180, 40)
$btnStart.BackColor = [System.Drawing.Color]::LightGreen

# --- Help ---
$lblHelp = New-Object System.Windows.Forms.Label
$lblHelp.Text = @"
How to use:
1. Fill in your API Key (editable)
2. Select model
3. Choose working directory (Browse)
4. Click Start

Claude Code opens in the selected directory.
Everything is cleaned up after Claude Code exits.

To switch Key: edit the API Key field above.
"@
$lblHelp.Location = New-Object System.Drawing.Point(20, 310)
$lblHelp.Size = New-Object System.Drawing.Size(440, 180)
$lblHelp.Font = New-Object System.Drawing.Font("Arial", 9)

$form.Controls.AddRange(@($lblTitle, $lblKey, $txtKey, $lblModel, $cmbModel, $lblWorkDir, $txtWorkDir, $btnBrowse, $lblInfo, $lblStatus, $btnStart, $lblHelp))

$btnStart.Add_Click({
    $key = $txtKey.Text.Trim()
    $model = $cmbModel.SelectedItem
    $workDir = $txtWorkDir.Text.Trim()

    if ([string]::IsNullOrWhiteSpace($key)) {
        $lblStatus.Text = "Error: API Key is empty"
        $lblStatus.ForeColor = [System.Drawing.Color]::Red
        return
    }

    if ([string]::IsNullOrWhiteSpace($workDir) -or -not (Test-Path $workDir)) {
        $lblStatus.Text = "Error: Working directory does not exist"
        $lblStatus.ForeColor = [System.Drawing.Color]::Red
        return
    }

    $lblStatus.Text = "Starting, please wait..."
    $lblStatus.ForeColor = [System.Drawing.Color]::Orange
    $form.Refresh()

    $args = "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`" -ApiKey `"$key`" -Model `"$model`" -WorkDir `"$workDir`""
    try {
        Start-Process powershell -ArgumentList $args
        $lblStatus.Text = "Claude Code started in: $workDir"
        $lblStatus.ForeColor = [System.Drawing.Color]::Green
    } catch {
        $lblStatus.Text = "Start failed: $($_.Exception.Message)"
        $lblStatus.ForeColor = [System.Drawing.Color]::Red
    }
})

[System.Windows.Forms.Application]::EnableVisualStyles()
[System.Windows.Forms.Application]::Run($form)