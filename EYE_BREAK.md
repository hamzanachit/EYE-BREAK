# Eye Break — 20/20/20 desktop reminder (macOS + Windows)

Background reminder that pops a top-of-screen window every **20 minutes** telling
you to look 20 feet away for 20 seconds. Runs silently in the background
(macOS LaunchAgent / Windows Scheduled Task). Nothing to keep open.

```
eye-break/
  mac/install.sh        # macOS installer (LaunchAgent + AppleScript dialog)
  windows/install.ps1   # Windows installer (Scheduled Task + WinForms popup)
  EYE_BREAK.md          # this file
```

No app store, no admin rights, no background daemon process. macOS uses the
system scheduler (launchd); Windows uses Task Scheduler. Both start the popup on
a timer and exit.

---

## macOS — install

Requirements: macOS 11+, built-in `osascript` (no extra install).

```sh
cd eye-break/mac
chmod +x install.sh
./install.sh              # every 20 minutes (default)
```

Custom interval (minutes):

```sh
MINUTES=30 ./install.sh
```

First popup appears immediately (proves it works), then every 20 minutes.

### What it does

1. Writes the popup script to
   `~/Library/Application Support/EyeBreak/eyebreak.sh`
2. Writes a LaunchAgent to `~/Library/LaunchAgents/com.eyebreak.reminder.plist`
   with `StartInterval = 1200` (20 min) and `RunAtLoad = true`
3. Loads it into your GUI session via `launchctl bootstrap`

### Test now

```sh
launchctl kickstart -k gui/$(id -u)/com.eyebreak.reminder
```

### Status / logs

```sh
launchctl print gui/$(id -u)/com.eyebreak.reminder | head -20
```

### Uninstall

```sh
cd eye-break/mac
./install.sh uninstall
```

---

## Windows — install

Requirements: Windows 10/11, PowerShell 5.1+ (built in).

Open **PowerShell** and run (no admin needed for a per-user task):

```powershell
cd eye-break\windows
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

Custom interval (minutes):

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1 -Minutes 30
```

### What it does

1. Writes the popup script to `%LOCALAPPDATA%\EyeBreak\EyeBreak.ps1`
   (a top-most WinForms window with a **Done** button)
2. Registers a Scheduled Task `EyeBreakReminder` that runs that script
   **every 20 minutes, repeat indefinitely**, in your interactive session
   (`LogonType Interactive` so the window shows on your desktop)

### Test now

```powershell
Start-ScheduledTask -TaskName EyeBreakReminder
```

### Status

```powershell
Get-ScheduledTask -TaskName EyeBreakReminder | Get-ScheduledTaskInfo
```

### Uninstall

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1 -Uninstall
```

---

## Change the interval later

Just run the installer again with the new value. It replaces the old schedule:

- macOS: `MINUTES=25 ./install.sh`
- Windows: `.\install.ps1 -Minutes 25`

## Troubleshooting

- **macOS popup does not appear / is behind windows:** it is a standard
  AppleScript dialog shown by `osascript`. Confirm the agent loaded with
  `launchctl print gui/$(id -u)/com.eyebreak.reminder`. If it says "not found",
  reload with `launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.eyebreak.reminder.plist`.
- **Windows: nothing shows.** Task is registered as *interactive* — it only pops
  while you are logged in. Check `Get-ScheduledTaskInfo` "LastTaskResult"
  (`0` = success). If "Task is already running", ignore; new instances are
  ignored by design (`MultipleInstances IgnoreNew`).
- **Both:** the popup blocks until you click **Done** (or auto-dismisses after
  3 minutes on macOS). That is intended — it forces the break.

## Safety

Nothing is deleted. Everything lives in your own user profile
(`~/Library/...` on macOS, `%LOCALAPPDATA%` on Windows). Uninstall removes only
the files and task this installer created.
