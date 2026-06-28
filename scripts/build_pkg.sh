#!/bin/bash
# Builds a macOS .pkg installer for Upright from the already-built .app bundle.
#
#   ./scripts/build_pkg.sh
#
# Why a pkg: the installer's postinstall script strips the quarantine attribute,
# so the *installed app* launches with no Gatekeeper dialog. The pkg itself is
# unsigned (no Developer ID), so the friend still does ONE "Open Anyway" in
# System Settings → Privacy & Security — but only once, for the installer.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

APP="$ROOT/build/Upright.app"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist" 2>/dev/null || echo 1.0)"
PKG="$ROOT/build/Upright-$VERSION.pkg"
SCRIPTS_DIR="$ROOT/build/pkg_scripts"
PLIST="$ROOT/build/pkg_component.plist"

if [ ! -d "$APP" ]; then
  echo "!! $APP not found — run ./scripts/build_app.sh first"
  exit 1
fi

# postinstall: remove quarantine so the app opens without the Gatekeeper dialog.
mkdir -p "$SCRIPTS_DIR"
cat > "$SCRIPTS_DIR/postinstall" <<'EOS'
#!/bin/bash
xattr -dr com.apple.quarantine /Applications/Upright.app 2>/dev/null || true
exit 0
EOS
chmod +x "$SCRIPTS_DIR/postinstall"

# Component plist with relocation disabled, so it always lands in /Applications.
pkgbuild --analyze --root "$APP" "$PLIST" >/dev/null
/usr/libexec/PlistBuddy -c 'Set :0:BundleIsRelocatable false' "$PLIST" 2>/dev/null || true

echo "==> building $PKG"
pkgbuild \
  --component "$APP" \
  --install-location /Applications \
  --identifier com.bhavesh.Upright \
  --version "$VERSION" \
  --scripts "$SCRIPTS_DIR" \
  "$PKG"

# Keep the landing-page download in sync.
LANDING_ASSETS="$ROOT/landing/assets"
if [ -d "$LANDING_ASSETS" ]; then
  cp -f "$PKG" "$LANDING_ASSETS/Upright.pkg"
  echo "==> synced landing download: $LANDING_ASSETS/Upright.pkg"
fi

echo "==> done: $PKG"
