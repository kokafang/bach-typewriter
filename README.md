# Bach Typewriter Swift

Native macOS prototype of `Bach Typewriter`, built with AppKit.

## Current shape

- Transparent floating Bach pet window
- Bach spritesheet animation
- Global and local keyboard monitoring
- Sequential Goldberg note playback through `AVAudioEngine`
- Menu bar controls for show, pause/resume typing notes, play test note, instrument selection with stable sample playback plus GM options, accessibility settings, and quit

## Run

```bash
cd /Users/jiafenggao/Documents/Obsidian/jiafeng-vault-air/bach-typewriter-swift
./scripts/dev-run.sh
```

If global keyboard listening does not work at first launch, grant Accessibility permission in macOS Settings.

## Open in Xcode

You can open the package directory directly in Xcode once a full Xcode installation is available.
