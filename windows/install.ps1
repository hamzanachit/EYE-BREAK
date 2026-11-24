# Eye Break - Windows installer
# Registers a Scheduled Task that shows a "look away" popup every N minutes.
#
#   .\install.ps1                 # every 20 minutes
#   .\install.ps1 -Minutes 30     # every 30 minutes
#   .\install.ps1 -Uninstall      # remove everything
#
#Requires -Version 5.1
param(
    [int]$Minutes = 20,
    [switch]$Uninstall
)

$ErrorActionPreference = "Stop"
$TaskName = "EyeBreakReminder"
$Dir      = Join-Path $env:LOCALAPPDATA "EyeBreak"
$Script   = Join-Path $Dir "EyeBreak.ps1"

if ($Uninstall) {
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
    if (Test-Path $Dir) { Remove-Item $Dir -Recurse -Force }
    Write-Host "Eye Break uninstalled."
    return
}

New-Item -ItemType Directory -Path $Dir -Force | Out-Null

# --- top-most popup window (written as a literal file) ---
$popup = @'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$form = New-Object System.Windows.Forms.Form
$form.Text            = "Eye Break - 20/20/20"
$form.Width           = 560
$form.Height          = 380
$form.StartPosition   = "CenterScreen"
$form.TopMost         = $true
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox     = $false
$form.MinimizeBox     = $false
$form.ControlBox      = $false
$form.BackColor       = [System.Drawing.Color]::FromArgb(20, 24, 34)
$form.ForeColor       = [System.Drawing.Color]::White

$title = New-Object System.Windows.Forms.Label
$title.Text      = "Eye Break"
$title.Font      = New-Object System.Drawing.Font("Segoe UI", 26, [System.Drawing.FontStyle]::Bold)
$title.ForeColor = [System.Drawing.Color]::White
$title.TextAlign = "MiddleCenter"
$title.Bounds    = New-Object System.Drawing.Rectangle(20, 20, 500, 52)
$form.Controls.Add($title)

$msg = New-Object System.Windows.Forms.Label
$msg.Text      = "Look 20 feet away.`nBlink slowly. Relax your shoulders."
$msg.Font      = New-Object System.Drawing.Font("Segoe UI", 15)
$msg.ForeColor = [System.Drawing.Color]::FromArgb(220, 225, 235)
$msg.TextAlign = "MiddleCenter"
$msg.Bounds    = New-Object System.Drawing.Rectangle(20, 82, 500, 70)
$form.Controls.Add($msg)

$count = New-Object System.Windows.Forms.Label
$count.Text      = "20"
$count.Font      = New-Object System.Drawing.Font("Consolas", 48, [System.Drawing.FontStyle]::Bold)
$count.ForeColor = [System.Drawing.Color]::FromArgb(100, 170, 255)
$count.TextAlign = "MiddleCenter"
$count.Bounds    = New-Object System.Drawing.Rectangle(20, 152, 500, 92)
$form.Controls.Add($count)

$btn = New-Object System.Windows.Forms.Button
$btn.Text      = "Wait 20s..."
$btn.Enabled   = $false
$btn.Font      = New-Object System.Drawing.Font("Segoe UI", 12)
$btn.Bounds    = New-Object System.Drawing.Rectangle(195, 282, 170, 44)
$btn.FlatStyle = "Flat"
$btn.BackColor = [System.Drawing.Color]::FromArgb(70, 120, 200)
$btn.ForeColor = [System.Drawing.Color]::White
$btn.Add_Click({ $form.Close() })
$form.Controls.Add($btn)

$remaining = 20

$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 1000
$timer.Add_Tick({
    $script:remaining--
    if ($script:remaining -le 0) {
        $timer.Stop()
        $count.Text       = "0"
        $btn.Text         = "Done"
        $btn.Enabled      = $true
        $form.ControlBox  = $true
        $form.MinimizeBox = $true
    } else {
        $count.Text = "$($script:remaining)"
    }
})

$form.Add_FormClosing({
    if ($script:remaining -gt 0) { $_.Cancel = $true }
})
$form.Add_Shown({ $timer.Start(); $form.Activate() })
[void]$form.ShowDialog()
'@

Set-Content -Path $Script -Value $popup -Encoding UTF8

# --- scheduled task: popup every N minutes, indefinitely, in this session ---
$action = New-ScheduledTaskAction -Execute "powershell.exe" `
    -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$Script`""

$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes($Minutes) `
    -RepetitionInterval (New-TimeSpan -Minutes $Minutes) `
    -RepetitionDuration (New-TimeSpan -Days 3650)

$principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" `
    -LogonType Interactive -RunLevel Limited

$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries -StartWhenAvailable -MultipleInstances IgnoreNew

Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger `
    -Principal $principal -Settings $settings `
    -Description "Reminds you to rest your eyes every $Minutes minutes." -Force | Out-Null

Write-Host "Eye Break installed on Windows. Popup every $Minutes min."
Write-Host "Test now:  Start-ScheduledTask -TaskName $TaskName"
