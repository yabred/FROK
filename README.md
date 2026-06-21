# FROK

Instant sound effects for macOS. FROK lives in your menu bar, keeps sounds ready in memory, and plays them with zero delay — from hotkeys, the settings window, or the command line.

## What you can do

- Play sound effects instantly from the menu bar
- Assign global hotkeys with one-shot or hold-to-play modes
- Trigger sounds from Terminal or scripts with `frok`
- Play multiple sounds at once; stop all with `frok stop`
- Set per-sound volume from 0% to 150%
- Launch FROK automatically at login

## Requirements

- macOS 14.0+
- **Accessibility** permission — required for global hotkeys (not needed for UI preview or the command line)

## Install

### Homebrew (recommended)

```bash
brew tap yabred/tap
brew install --cask frok
```

This installs `FROK.app` to `/Applications` and adds the `frok` CLI to your PATH.

> **Note:** Current releases are not notarized. On first launch, macOS may block the app. Open **System Settings → Privacy & Security → Open Anyway**, or run:
>
> ```bash
> xattr -cr /Applications/FROK.app
> ```

### Build from source

1. Open `FROK.xcodeproj` in Xcode 15+.
2. Select the **FROK** scheme, then build and run (⌘R).
3. A menu bar icon appears — click it to open settings.

To use `frok` from anywhere in Terminal when running from Xcode:

```bash
ln -sf /path/to/FROK.app/Contents/Resources/bin/frok /usr/local/bin/frok
```

## Quick start

1. Launch FROK — the icon appears in the menu bar (no Dock icon).
2. Click the icon → **Add new sound** → pick audio files (MP3, WAV, AIFF, and more).
3. Set an **alias** for each sound — this is the name you use with `frok`.
4. Click the hotkey field and press a key combo with ⌘, ⌥, ⌃, or ⇧.
5. If prompted, grant **Accessibility** in System Settings — hotkeys won't work without it.

## Using the app

Each sound appears as a row in the settings window:

| Control | What it does |
|---------|--------------|
| Play / Stop | Preview the sound |
| Alias | Name used by `frok` (e.g. `frok applause`) |
| Hotkey | Global shortcut; press Esc to cancel recording, ✕ to clear |
| **S / H** | **S** = one-shot (plays the full clip); **H** = hold (plays while the key is held, stops on release). New sounds 3 seconds or shorter default to S |
| Volume | 0–150% per sound |
| Trash | Remove the sound |

In the footer:

- **Launch at login** — start FROK automatically when you sign in
- **Loaded sounds** — how much memory your sounds use
- **Log** — recent triggers from hotkeys, the UI, and the command line
- **Exit** — quit FROK

Sounds are saved between restarts. A red ✕ next to a sound means the file failed to load — try adding it again.

## Global hotkeys

- Every hotkey must include at least one modifier: ⌘, ⌥, ⌃, or ⇧.
- When a hotkey fires, the keystroke is consumed and won't reach other apps.
- If hotkeys don't work, open **System Settings → Privacy & Security → Accessibility** and enable FROK, then restart the app.

## Command line

FROK must be running for the CLI to work.

```bash
frok applause              # play by alias
frok "record scratch"      # multi-word alias
frok stop                  # stop all playing sounds
```

Aliases are case-sensitive. You can call `frok` from shell scripts, Shortcuts, OBS, or any tool that runs shell commands.

## Troubleshooting

| Problem | What to try |
|---------|-------------|
| Hotkeys don't work | Grant Accessibility permission and restart FROK |
| `frok`: "FROK is not running" | Launch FROK first |
| Red ✕ on a sound | File missing or unsupported — remove and re-add it |
| Sound doesn't play | Check the alias spelling (case-sensitive) |

Open **Log** in the settings footer to see what triggered each sound.

## Roadmap

- Mute all sounds
- Trim and duration controls
- Softer start/stop to reduce clicks
- Play on any key press

## License

MIT — see [LICENSE](LICENSE).
