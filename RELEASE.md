# Releasing FROK

Step-by-step guide for publishing a new version to GitHub Releases and Homebrew.

## Before you start

- **Version format:** semver tags like `v1.0.1`, `v1.1.0`, `v2.0.0`
- **Repositories:**
  - App: [yabred/FROK](https://github.com/yabred/FROK)
  - Homebrew tap: [yabred/homebrew](https://github.com/yabred/homebrew)

## 1. Bump the version in Xcode

1. Open `FROK.xcodeproj`.
2. Select the **FROK** target → **General**.
3. Set **Version** (`MARKETING_VERSION`) to the new release number, e.g. `1.0.1`.
4. Increment **Build** (`CURRENT_PROJECT_VERSION`) if you track build numbers separately.
5. Repeat for the **FROKCLI** target so app and CLI stay in sync.

The tag you push in step 3 must match **Version** exactly (`v1.0.1` → `1.0.1`).

## 2. Commit and push

```bash
git add FROK.xcodeproj/project.pbxproj
git commit -m "Bump version to 1.0.1"
git push origin main
```

Include any other changes for this release in the same commit or earlier commits on `main`.

## 3. Create and push a tag

The tag triggers [`.github/workflows/release.yml`](.github/workflows/release.yml).

```bash
git tag v1.0.1
git push origin v1.0.1
```

To replace a broken tag:

```bash
git tag -d v1.0.1
git push origin :refs/tags/v1.0.1
git tag v1.0.1
git push origin v1.0.1
```

## 4. Wait for GitHub Actions

1. Open **Actions** → **Release** in the FROK repo.
2. Confirm the workflow for your tag finished successfully.
3. Open **Releases** and verify the asset `FROK-1.0.1.zip` is attached.

The workflow runs on `macos-15`, builds an unsigned Release `.app`, zips it, and publishes it to GitHub Releases.

### Optional: build locally first

```bash
scripts/package-release.sh --version 1.0.1 --output-dir dist
```

This prints a local `sha256`. **Use the checksum from the GitHub Release asset**, not the local one — CI and your machine may produce different binaries.

## 5. Update the Homebrew cask

In [yabred/homebrew](https://github.com/yabred/homebrew), edit `Casks/frok.rb`:

1. Set `version` to the new number (without `v`).
2. Set `sha256` to the checksum of the **downloaded release zip**.

Get the checksum:

```bash
gh release download v1.0.1 --repo yabred/FROK --pattern 'FROK-1.0.1.zip' --clobber
shasum -a 256 FROK-1.0.1.zip
```

Update the cask:

```ruby
cask "frok" do
  version "1.0.1"
  sha256 "…"

  url "https://github.com/yabred/FROK/releases/download/v#{version}/FROK-#{version}.zip"
  # …
end
```

Commit and push:

```bash
cd /path/to/homebrew
git add Casks/frok.rb
git commit -m "Update FROK cask to 1.0.1"
git push origin main
```

## 6. Verify installation

```bash
brew update
brew reinstall --cask frok
```

Launch FROK from `/Applications`. The `frok` CLI should be on your PATH.

Current releases are **not notarized**. On first launch, macOS may block the app — see [README.md](README.md#homebrew-recommended).

## Checklist

- [ ] `MARKETING_VERSION` in Xcode matches the tag (e.g. `1.0.1` / `v1.0.1`)
- [ ] Changes merged on `main`
- [ ] Tag pushed; GitHub Actions **Release** workflow succeeded
- [ ] `FROK-{version}.zip` present on GitHub Releases
- [ ] `Casks/frok.rb` updated with new `version` and `sha256`
- [ ] `brew install --cask frok` works

## Later improvements

| Topic | What to add |
|-------|-------------|
| Code signing + notarization | Developer ID cert, `ExportOptions.plist`, notarytool in CI |
| Auto-update cask | GitHub Actions step with a PAT to commit sha256 to `yabred/homebrew` |
