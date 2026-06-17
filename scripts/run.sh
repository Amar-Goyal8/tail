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
[ -d Resources/fonts ] && cp -R Resources/fonts "$APP/Contents/Resources/fonts"

# Sign with the stable self-signed "Tail Self Signed" identity if present, so
# the code identity (and thus the TCC Screen Recording grant) survives rebuilds.
# Falls back to ad-hoc (-) which re-prompts for permission every build.
IDENTITY=$(security find-identity -p codesigning 2>/dev/null | grep "Tail Self Signed" | head -1 | awk '{print $2}')
SIGN_ID="${IDENTITY:--}"
echo "==> sign ($SIGN_ID)"
codesign --force --deep --sign "$SIGN_ID" "$APP"

echo "==> launch"
open "$APP"
echo "running. First run: grant Screen Recording (+ Input Monitoring for F9) in System Settings > Privacy, then relaunch."
