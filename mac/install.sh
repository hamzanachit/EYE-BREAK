#!/bin/bash
#
# Eye Break — macOS installer
# Installs a LaunchAgent that shows a big "look away for 20s" countdown popup
# every N minutes.
# Usage:
#   ./install.sh              # every 20 minutes
#   MINUTES=30 ./install.sh   # every 30 minutes
#   ./install.sh uninstall    # remove everything
#
set -euo pipefail

LABEL="com.eyebreak.reminder"
SUPPORT="$HOME/Library/Application Support/EyeBreak"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
LAUNCHER="$SUPPORT/eyebreak.sh"
SWIFT_SRC="$SUPPORT/EyeBreak.swift"
BIN="$SUPPORT/EyeBreak"
MINUTES="${MINUTES:-20}"
UID_ME="$(id -u)"

if [ "${1:-}" = "uninstall" ]; then
    launchctl bootout "gui/$UID_ME/$LABEL" 2>/dev/null || launchctl unload "$PLIST" 2>/dev/null || true
    rm -f "$PLIST" "$LAUNCHER" "$BIN" "$SWIFT_SRC"
    rmdir "$SUPPORT" 2>/dev/null || true
    echo "Eye Break uninstalled."
    exit 0
fi

mkdir -p "$SUPPORT" "$HOME/Library/LaunchAgents"

# --- compiled AppKit popup with a real 20-second countdown (literal) ---
cat > "$SWIFT_SRC" <<'SWIFT_EOF'
import Cocoa

final class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    var countLabel: NSTextField!
    var doneButton: NSButton!
    var timer: Timer?
    var remaining = 20

    func applicationDidFinishLaunching(_ note: Notification) {
        let rect = NSRect(x: 0, y: 0, width: 600, height: 360)

        window = NSWindow(contentRect: rect,
                          styleMask: [.titled, .closable],
                          backing: .buffered, defer: false)
        window.title = "Eye Break — 20/20/20"
        window.level = .floating
        window.backgroundColor = NSColor(calibratedRed: 0.08, green: 0.09, blue: 0.13, alpha: 1)
        window.isReleasedWhenClosed = false
        window.center()

        let content = NSView(frame: rect)
        window.contentView = content

        let title = NSTextField(labelWithString: "Eye Break")
        title.font = NSFont.boldSystemFont(ofSize: 32)
        title.textColor = .white
        title.alignment = .center
        title.frame = NSRect(x: 20, y: 270, width: 560, height: 44)
        content.addSubview(title)

        let msg = NSTextField(labelWithString: "Look 20 feet away.\nBlink slowly. Relax your shoulders.")
        msg.font = NSFont.systemFont(ofSize: 18)
        msg.textColor = NSColor(calibratedWhite: 0.85, alpha: 1)
        msg.alignment = .center
        msg.frame = NSRect(x: 20, y: 170, width: 560, height: 95)
        content.addSubview(msg)

        countLabel = NSTextField(labelWithString: "\(remaining)")
        countLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 72, weight: .bold)
        countLabel.textColor = NSColor(calibratedRed: 0.4, green: 0.7, blue: 1, alpha: 1)
        countLabel.alignment = .center
        countLabel.frame = NSRect(x: 20, y: 78, width: 560, height: 92)
        content.addSubview(countLabel)

        doneButton = NSButton(title: "Wait 20s…", target: self, action: #selector(done))
        doneButton.bezelStyle = .rounded
        doneButton.font = NSFont.systemFont(ofSize: 15)
        doneButton.frame = NSRect(x: 225, y: 20, width: 150, height: 38)
        doneButton.isEnabled = false
        doneButton.keyEquivalent = "\r"
        content.addSubview(doneButton)

        // lock the window until the countdown ends
        window.standardWindowButton(.closeButton)?.isHidden = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true

        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)

        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.remaining -= 1
            if self.remaining <= 0 {
                self.remaining = 0
                self.timer?.invalidate()
                self.countLabel.stringValue = "0"
                self.doneButton.title = "Done"
                self.doneButton.isEnabled = true
                self.window.standardWindowButton(.closeButton)?.isHidden = false
            } else {
                self.countLabel.stringValue = "\(self.remaining)"
            }
        }
    }

    @objc func done() {
        timer?.invalidate()
        NSApp.terminate(nil)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ app: NSApplication) -> Bool {
        true
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
SWIFT_EOF

# --- compile (once; skipped if binary is newer than source) ---
if command -v swiftc >/dev/null 2>&1; then
    if [ ! -x "$BIN" ] || [ "$SWIFT_SRC" -nt "$BIN" ]; then
        echo "Compiling Eye Break popup…"
        if ! swiftc "$SWIFT_SRC" -o "$BIN" -framework Cocoa 2>/dev/null; then
            echo "WARN: swiftc failed; falling back to AppleScript dialog." >&2
            rm -f "$BIN"
        fi
    fi
else
    echo "WARN: swiftc not found (install Xcode Command Line Tools: xcode-select --install)."
    echo "      Falling back to AppleScript dialog (no countdown lock)." >&2
fi

# --- launcher: use compiled binary if present, else AppleScript fallback ---
cat > "$LAUNCHER" <<'LAUNCH_EOF'
#!/bin/bash
DIR="$(cd "$(dirname "$0")" && pwd)"
BIN="$DIR/EyeBreak"
if [ -x "$BIN" ]; then
    exec "$BIN"
fi
osascript <<'APPLESCRIPT'
display dialog "Time for an eye break.

Look 20 feet away for 20 seconds.
Blink slowly. Relax your shoulders." with title "Eye Break — 20/20/20" buttons {"Done"} default button "Done" with icon caution giving up after 20
APPLESCRIPT
LAUNCH_EOF
chmod +x "$LAUNCHER"

INTERVAL=$(( MINUTES * 60 ))

# --- LaunchAgent plist (values expanded) ---
cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$LABEL</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>$LAUNCHER</string>
    </array>
    <key>StartInterval</key>
    <integer>$INTERVAL</integer>
    <key>RunAtLoad</key>
    <true/>
</dict>
</plist>
EOF

# --- reload agent ---
launchctl bootout "gui/$UID_ME/$LABEL" 2>/dev/null || true
if ! launchctl bootstrap "gui/$UID_ME" "$PLIST" 2>/dev/null; then
    launchctl unload "$PLIST" 2>/dev/null || true
    launchctl load "$PLIST"
fi

echo "Eye Break installed on macOS. Big 20s countdown popup every $MINUTES min."
echo "Test now:  launchctl kickstart -k gui/$UID_ME/$LABEL"
