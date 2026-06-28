#!/bin/bash
# Watches the app source and rebuilds on every change — which also refreshes the
# landing-page download (build_app.sh syncs landing/assets/Upright.zip).
#
# Usage:  ./scripts/watch.sh [debug|release]
#
# Uses fswatch if installed (brew install fswatch); otherwise falls back to a
# lightweight polling loop so it works out of the box.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
CONFIG="${1:-debug}"
WATCH_DIR="$ROOT/Sources"

build() {
  echo "==> change detected — rebuilding ($CONFIG) + syncing landing zip"
  ./scripts/build_app.sh "$CONFIG" || echo "!! build failed, will retry on next change"
}

echo "==> watching $WATCH_DIR for changes (Ctrl-C to stop)"
build  # initial build so things start in sync

if command -v fswatch >/dev/null 2>&1; then
  # Coalesce bursts of saves (0.8s) so a multi-file change triggers one build.
  fswatch -o -l 0.8 "$WATCH_DIR" | while read -r _; do build; done
else
  echo "   (fswatch not found — using polling. For instant rebuilds: brew install fswatch)"
  LAST=""
  while true; do
    SIG="$(find "$WATCH_DIR" -name '*.swift' -type f -exec stat -f '%m %N' {} + | sort)"
    if [ "$SIG" != "$LAST" ]; then
      [ -n "$LAST" ] && build
      LAST="$SIG"
    fi
    sleep 2
  done
fi
