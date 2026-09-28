Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$scriptPath = "E:\claude\claude-proxy\StartTokenRhythm.ps1"

# 记录调用 UI 时的当前目录（即用户期望的工作目录）
$launchDir = (Get-Location).Path

$form = New-Object System.Windows.Forms.Form
$form.Text = "Claude Code Launcher"
$form.Size = New-Object System.Drawing.Size(480, 500)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false

$lblTitle = New-Object System.Windows.Forms.Label
$lblTitle.Text = "Claude Code (TokenRhythm) Launcher"
$lblTitle.Font = New-Object System.Drawing.Font("Arial", 14, [System.Drawing.FontStyle]::Bold)
$lblTitle.Location = New-Object System.Drawing.Point(20, 20)
$lblTitle.Size = New-Object System.Drawing.Size(420, 30)

$lblKey = New-Object System.Windows.Forms.Label
$lblKey.Text = "API Key:"
$lblKey.Location = New-Object System.Drawing.Point(20, 70)
$lblKey.Size = New-Object System.Drawing.Size(100, 25)

$txtKey = New-Object System.Windows.Forms.TextBox
$txtKey.Location = New-Object System.Drawing.Point(130, 68)
$txtKey.Size = New-Object System.Drawing.Size(310, 25)
$txtKey.Text = "sk_tr_YOUR_KEY_HERE"

$lblModel = New-Object System.Windows.Forms.Label
$lblModel.Text = "Model:"
$lblModel.Location = New-Object System.Drawing.Point(20, 110)
$lblModel.Size = New-Object System.Drawing.Size(100, 25)

$cmbModel = New-Object System.Windows.Forms.ComboBox
$cmbModel.Location = New-Object System.Drawing.Point(130, 108)
$cmbModel.Size = New-Object System.Drawing.Size(310, 25)
$cmbModel.DropDownStyle = "DropDownList"
$cmbModel.Items.AddRange(@("deepseek-flash", "glm-5.3-flashx", "deepseek-v4-pro-0813", "mimo-v2.6-pro"))
$cmbModel.SelectedIndex = 0

$lblInfo = New-Object System.Windows.Forms.Label
$lblInfo.Text = "Starts local sanitizing proxy + Claude Code. Cleans up on exit."
$lblInfo.Location = New-Object System.Drawing.Point(20, 150)
$lblInfo.Size = New-Object System.Drawing.Size(420, 40)
$lblInfo.ForeColor = [System.Drawing.Color]::Gray

$lblStatus = New-Object System.Windows.Forms.Label
$lblStatus.Text = ""
$lblStatus.Location = New-Object System.Drawing.Point(20, 190)
$lblStatus.Size = New-Object System.Drawing.Size(420, 40)
$lblStatus.ForeColor = [System.Drawing.Color]::Green

$btnStart = New-Object System.Windows.Forms.Button
$btnStart.Text = "Start Claude Code"
$btnStart.Location = New-Object System.Drawing.Point(130, 240)
$btnStart.Size = New-Object System.Drawing.Size(180, 40)
$btnStart.BackColor = [System.Drawing.Color]::LightGreen

$lblHelp = New-Object System.Windows.Forms.Label
$lblHelp.Text = @"
How to use:
1. Fill in your API Key (editable)
2. Select model
3. Click Start

A Claude Code terminal window will open.
Everything is cleaned up after Claude Code exits.

To switch Key: edit the API Key field above.
"@
$lblHelp.Location = New-Object System.Drawing.Point(20, 300)
$lblHelp.Size = New-Object System.Drawing.Size(420, 160)
$lblHelp.Font = New-Object System.Drawing.Font("Arial", 9)

$form.Controls.AddRange(@($lblTitle, $lblKey, $txtKey, $lblModel, $cmbModel, $lblInfo, $lblStatus, $btnStart, $lblHelp))

$btnStart.Add_Click({
    $key = $txtKey.Text.Trim()
    $model = $cmbModel.SelectedItem

    if ([string]::IsNullOrWhiteSpace($key)) {
        $lblStatus.Text = "Error: API Key is empty"
        $lblStatus.ForeColor = [System.Drawing.Color]::Red
        return
    }

    $lblStatus.Text = "Starting, please wait..."
    $lblStatus.ForeColor = [System.Drawing.Color]::Orange
    $form.Refresh()

    $args = "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`" -ApiKey `"$key`" -Model `"$model`" -WorkDir `"$launchDir`""
    try {
        Start-Process powershell -ArgumentList $args
        $lblStatus.Text = "Claude Code started in: $launchDir"
        $lblStatus.ForeColor = [System.Drawing.Color]::Green
    } catch {
        $lblStatus.Text = "Start failed: $($_.Exception.Message)"
        $lblStatus.ForeColor = [System.Drawing.Color]::Red
    }
})

[System.Windows.Forms.Application]::EnableVisualStyles()
[System.Windows.Forms.Application]::Run($form)