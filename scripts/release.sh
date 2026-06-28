#!/bin/bash
# Prepares a release: rebuilds everything, refreshes the cask's version+sha256,
# and prints the exact commands to publish on GitHub.
#
#   ./scripts/release.sh [github-username]
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
GH_USER="${1:-GITHUB_USER}"

./scripts/build_app.sh release

ZIP="$ROOT/landing/assets/Upright.zip"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$ROOT/build/Upright.app/Contents/Info.plist")"
SHA="$(shasum -a 256 "$ZIP" | awk '{print $1}')"
CASK="$ROOT/homebrew-tap/Casks/upright.rb"

sed -i '' -e "s/^  version \".*\"/  version \"$VERSION\"/" \
          -e "s/^  sha256 \".*\"/  sha256 \"$SHA\"/" "$CASK"
if [ "$GH_USER" != "GITHUB_USER" ]; then
  sed -i '' "s/GITHUB_USER/$GH_USER/g" "$CASK"
fi

echo ""
echo "==> cask updated: version=$VERSION sha256=$SHA"
echo ""
cat <<EOS
Publish (one-time setup, then repeat the release steps per version):

  1. Create two PUBLIC GitHub repos: '$GH_USER/upright' and '$GH_USER/homebrew-tap'
  2. Release the zip (web UI: repo -> Releases -> 'v$VERSION' -> attach $ZIP)
     or with gh CLI:
       gh release create v$VERSION "$ZIP" --repo $GH_USER/upright --title "Upright $VERSION"
  3. Push the tap:
       cd homebrew-tap && git init && git add . && git commit -m "upright $VERSION"
       git remote add origin git@github.com:$GH_USER/homebrew-tap.git && git push -u origin main

Friends then install with ZERO Gatekeeper dialogs:
       brew install --cask --no-quarantine $GH_USER/tap/upright
EOS
