# EYE-BREAK 👁️

A tiny, no-nonsense **20/20/20 eye-break reminder** for **macOS** and **Windows**.

Every 20 minutes it pops a big, top-of-screen window that counts down **20 seconds**
while you look 20 feet away. You can't dismiss it until the countdown finishes — so
the break actually happens.

No app store. No background daemon eating RAM. No account. Just your OS scheduler
(`launchd` on macOS, Task Scheduler on Windows), a compiled popup, and you.

[![License](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](LICENSE)
[![Platforms](https://img.shields.io/badge/platforms-macOS%20%7C%20Windows-lightgrey.svg)](#)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](https://github.com/hamzanachit/EYE-BREAK/pulls)

---

## Why

Staring at a screen for hours strains your eyes. The **20/20/20 rule**: every
**20** minutes, look at something **20** feet away for **20** seconds. This tool
makes that rule automatic.

## Features

- ⏱️ Fires every 20 minutes (configurable).
- 🖥️ **Big, unmissable popup** — 600×360 (macOS) / 560×380 (Windows), always on top.
- 🔒 **Enforced 20-second countdown** — the *Done* button stays disabled until the
  timer hits zero. No skipping.
- 🪶 Lightweight — no tray icon, no resident process. The popup runs, you dismiss it,
  it exits.
- 🔧 One-command install / uninstall. No admin rights.
- 🍎 macOS: compiled native AppKit window (`swiftc`), falls back to an AppleScript
  dialog if command-line tools are missing.
- 🪟 Windows: native WinForms window, topmost, close blocked during the countdown.

## Repository layout

```
EYE-BREAK/
├── EYE_BREAK.md        # detailed step-by-step guide (install / test / uninstall)
├── mac/
│   └── install.sh      # macOS installer → LaunchAgent + compiled popup
├── windows/
│   └── install.ps1     # Windows installer → Scheduled Task + WinForms popup
├── LICENSE             # Apache License 2.0
└── README.md
```

## Install

### macOS (11+)

Requires Xcode **Command Line Tools** for the nice countdown window
(`xcode-select --install`). Without them it still works via AppleScript fallback.

```sh
git clone https://github.com/hamzanachit/EYE-BREAK.git
cd EYE-BREAK/mac
chmod +x install.sh
./install.sh                 # every 20 minutes
MINUTES=30 ./install.sh      # custom interval
```

A popup appears immediately (proof), then every 20 minutes.
Test: `launchctl kickstart -k gui/$(id -u)/com.eyebreak.reminder`
Uninstall: `./install.sh uninstall`

### Windows (10/11, PowerShell 5.1+)

```powershell
git clone https://github.com/hamzanachit/EYE-BREAK.git
cd EYE-BREAK\windows
powershell -ExecutionPolicy Bypass -File .\install.ps1
# custom interval:
powershell -ExecutionPolicy Bypass -File .\install.ps1 -Minutes 30
```

Registers a per-user Scheduled Task (no admin needed) that runs in your session.
Test: `Start-ScheduledTask -TaskName EyeBreakReminder`
Uninstall: `.\install.ps1 -Uninstall`

## How it works

| | macOS | Windows |
|---|---|---|
| Scheduler | LaunchAgent `com.eyebreak.reminder` | Scheduled Task `EyeBreakReminder` |
| Trigger | `StartInterval` 1200 s (+ `RunAtLoad`) | `-Once` + repeat 20 min, indefinite |
| Popup | Compiled AppKit window (`.floating` level) | WinForms window (`TopMost`) |
| Install dir | `~/Library/Application Support/EyeBreak/` | `%LOCALAPPDATA%\EyeBreak\` |
| Countdown lock | Done disabled until 0; close hidden | Done disabled until 0; close cancelled |

Everything lives in your own user profile. Uninstall removes only what the
installer created.

## Change the interval

Re-run the installer with a new value — it replaces the schedule:

- macOS: `MINUTES=25 ./install.sh`
- Windows: `.\install.ps1 -Minutes 25`

## License

Licensed under the **Apache License 2.0** — see [LICENSE](LICENSE). Free to use,
modify, and distribute. Contributions welcome.

## Contributing

Issues and PRs are welcome. Keep it dependency-free and small — the whole point
is that this is a tiny utility.

## Disclaimer

This is a comfort/health reminder tool, **not medical advice**. If a doctor gave
you specific guidance, follow that. Built to make the 20/20/20 habit effortless.
