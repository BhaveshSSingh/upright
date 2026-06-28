#!/bin/bash
# Builds the SwiftPM executable and assembles it into a proper, ad-hoc-signed .app
# bundle so macOS will grant camera (TCC) permission.
#
#   ./scripts/build_app.sh [debug|release] [run]
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

CONFIG="${1:-debug}"
RUN="${2:-}"
APP="$ROOT/build/Upright.app"

echo "==> swift build ($CONFIG)"
swift build -c "$CONFIG"

BINDIR="$(swift build -c "$CONFIG" --show-bin-path)"

echo "==> assembling bundle: $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BINDIR/Upright" "$APP/Contents/MacOS/Upright"
cp "$ROOT/Info.plist" "$APP/Contents/Info.plist"
if [ -f "$ROOT/Resources/AppIcon.icns" ]; then
  cp "$ROOT/Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
fi

echo "==> codesigning (ad-hoc)"
codesign --force --deep --sign - "$APP"
codesign --verify --verbose "$APP" || true

echo "==> built: $APP"

# Rule: every build keeps the landing-page downloads in sync with the latest app.
LANDING_ASSETS="$ROOT/landing/assets"
if [ -d "$LANDING_ASSETS" ]; then
  LANDING_ZIP="$LANDING_ASSETS/Upright.zip"
  echo "==> syncing landing download: $LANDING_ZIP"
  rm -f "$LANDING_ZIP"
  ( cd "$ROOT/build" && ditto -c -k --sequesterRsrc --keepParent Upright.app "$LANDING_ZIP" )
fi

# Also refresh the .pkg installer (strips quarantine on install → no Gatekeeper
# dialog for the installed app).
"$ROOT/scripts/build_pkg.sh"

if [ "$RUN" = "run" ]; then
  echo "==> relaunching"
  pkill -f "Upright.app/Contents/MacOS/Upright" 2>/dev/null || true
  open "$APP"
fi
