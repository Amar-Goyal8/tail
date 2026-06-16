#!/bin/bash
# Build SwiftPM exe -> wrap in .app bundle -> ad-hoc sign -> launch.
# Bundle needed so macOS TCC can grant Screen Recording + Input Monitoring.
set -euo pipefail
cd "$(dirname "$0")/.."

CONFIG=${1:-release}
echo "==> swift build ($CONFIG)"
swift build -c "$CONFIG"

BIN=$(swift build -c "$CONFIG" --show-bin-path)/Tail
APP="build/Tail.app"
echo "==> bundling $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Tail"
cp Resources/Info.plist "$APP/Contents/Info.plist"
[ -f Resources/Tail.icns ] && cp Resources/Tail.icns "$APP/Contents/Resources/Tail.icns"

echo "==> ad-hoc sign"
codesign --force --deep --sign - "$APP"

echo "==> launch"
open "$APP"
echo "running. First run: grant Screen Recording (+ Input Monitoring for F9) in System Settings > Privacy, then relaunch."
