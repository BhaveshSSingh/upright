# Sharing Upright with friends

Upright is **ad-hoc signed** (no $99/yr Apple Developer ID), so macOS Gatekeeper
shows *“Apple could not verify Upright is free of malware”* on first open.
That dialog can only be removed completely by Apple notarization — but the
options below get past it with minimal (or zero) friction.

## Option 1 — Send the .pkg (easiest today)

Send `landing/assets/Upright.pkg`. Your friend:

1. Double-clicks the pkg → dialog appears → clicks **Done** (NOT “Move to Trash”).
2. **System Settings → Privacy & Security** → scroll down → **Open Anyway** → installs.
3. Done. The installer strips the quarantine flag, so **the app itself opens
   with no dialog, forever**. (The hoop is once, for the installer only.)

Why pkg over zip: with the zip, the *app* is quarantined and the friend hits the
dialog on the app itself; the pkg's postinstall runs
`xattr -dr com.apple.quarantine /Applications/Upright.app` so the app starts clean.

## Option 2 — Homebrew (zero dialogs, best long-term)

Homebrew's `--no-quarantine` flag skips Gatekeeper entirely. One-time setup:

1. Create two **public** GitHub repos: `<you>/upright` and `<you>/homebrew-tap`.
2. Run `./scripts/release.sh <your-github-username>` — it rebuilds, updates
   `homebrew-tap/Casks/upright.rb` (version, sha256, URLs), and prints the exact
   upload/push commands.
3. Upload `landing/assets/Upright.zip` as a release asset `v1.0` on `<you>/upright`,
   push the `homebrew-tap/` folder to `<you>/homebrew-tap`.

Friends then run:

```bash
brew install --cask --no-quarantine <you>/tap/upright
```

No dialogs, `brew upgrade` works for future versions.

## Option 3 — Terminal one-liner (for technical friends)

If they already downloaded the zip and got blocked:

```bash
xattr -dr com.apple.quarantine /Applications/Upright.app
```

Then the app opens normally.

## Why not a signed pkg / dmg?

The pkg-signing guides (e.g. sperixlabs) require a **Developer ID Installer**
certificate, which only comes with the paid Apple Developer Program. Same for
notarized dmg/zip. If you ever join the program (~$99/yr):
`codesign` with the Developer ID cert in `build_app.sh`, `productsign` the pkg,
`xcrun notarytool submit` + `xcrun stapler staple` — then every option above
works with zero dialogs and no flags.

## Rebuild rule

`./scripts/build_app.sh` (or `./scripts/watch.sh`) keeps
`landing/assets/Upright.zip` **and** `landing/assets/Upright.pkg` in sync with
the latest code automatically.
