# Homebrew cask for Upright.
# Lives in a GitHub repo named `homebrew-tap` under your account, so friends can:
#   brew tap GITHUB_USER/tap
#   brew install --cask --no-quarantine upright
#
# `--no-quarantine` is the key: Homebrew skips the quarantine attribute, so the
# ad-hoc-signed app launches with NO Gatekeeper dialog at all.
#
# Run ./scripts/release.sh after each build to refresh `version`/`sha256` here.
cask "upright" do
  version "1.0"
  sha256 "afa2806aab6068d74ac1e1202aacb454dfdbb1c6cd4e0d58f3bbb7c06986df4d"

  url "https://github.com/GITHUB_USER/upright/releases/download/v#{version}/Upright.zip"
  name "Upright"
  desc "Menu-bar posture corrector — watches your eye level and nudges you to sit up straight"
  homepage "https://github.com/GITHUB_USER/upright"

  depends_on macos: ">= :ventura"

  app "Upright.app"

  caveats <<~EOS
    Upright is ad-hoc signed (no paid Apple Developer ID).
    Install with --no-quarantine to skip the Gatekeeper dialog:
      brew install --cask --no-quarantine upright
  EOS
end
