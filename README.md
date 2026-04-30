# rover.app

A homage to **Rover**, the yellow Labrador Retriever that lived inside Windows XP's Search Companion (2001). This project resurrects him as a floating macOS desktop pet, powered by Claude Code.

```
   ___                       _____
  / _ \  ___  __   __  ___  | || |__
 | (_) ||_ /  \ \ / / / -_) |__   _|
  \___//___|   \_/   \___|     |_|
        XP 2001                  2026
```

## What is this

In 2001, Microsoft put a friendly guide into Windows XP's search panel: a cartoon Labrador named Rover who watched while you typed, blinked, looked around, and went to sleep when you stopped. He was retired in Vista. This project brings him back, twenty five years later, as a floating macOS pet.

The original sprite frames and sound effects are kept exactly as they were. The difference is what he does: instead of running Windows search, he forwards your prompt to the local `claude` CLI and animates against the live token stream. When Claude is reading files, Rover reads. When Claude runs a Bash tool, Rover eats. When Claude errors out, Rover looks ashamed. He sleeps after a minute of inactivity and wakes when you click him.

This is a nostalgia project. It is not affiliated with Microsoft and has no commercial intent.

## Features

- Floating, borderless, transparent window. Drag him anywhere on screen.
- XP Luna style speech bubble. Click Rover to open the input field. Press Enter to send.
- 24 animation states and ~470 PNG frames sourced directly from the original assets.
- Original WAV sound effects (Haf, Lick, Whine, Snoring, Tap).
- Live `claude -p --output-format stream-json` parser. Tool use is mapped to animations:
  - `Read`, `Glob`, `Grep` to Reading
  - `Bash`, `Edit`, `Write` to Eat
  - `WebFetch`, `WebSearch` to Lick
  - tool errors to Ashamed
- Settings window with four tabs: General, Model, System Prompt, Advanced.
- Model picker for Claude Opus 4.7, Sonnet 4.6, Haiku 4.5.
- Persistent system prompt override (sent via `claude --append-system-prompt`).
- Localized in English and Korean. System language is auto detected with a manual override.
- Optional menu bar icon (paw symbol) for quick access from anywhere.
- Sleep after 60 seconds of inactivity. Click to wake.
- Speech bubble grows upward from a fixed bottom anchor and never crosses the top of the screen. Long responses scroll inside the bubble.

## Install

### From a DMG (recommended)

1. Download the latest `Rover.dmg` from the [Releases](https://github.com/youngjae99/rover-app/releases) page.
2. Open the DMG and drag `Rover.app` into `Applications`.
3. Launch from Launchpad.
4. Click Rover, or click the paw icon in the menu bar.

On first launch macOS Gatekeeper may complain. Right click `Rover.app` and choose Open to bypass it. (Code signing and notarization are on the TODO list below.)

### From source

Requirements:

- macOS 14 or later.
- Swift 5.9 or later. Command Line Tools is enough; full Xcode is not required.
- The `claude` CLI installed and reachable. The app probes a few common paths automatically (`/Applications/cmux.app/Contents/Resources/bin/claude`, `/opt/homebrew/bin/claude`, `/usr/local/bin/claude`, `~/.claude/local/claude`).

```bash
git clone https://github.com/youngjae99/rover-app.git
cd rover-app/RoverApp
./run.sh
```

`run.sh` syncs the assets from `rover/Resources/` into the SwiftPM resource directory, runs `swift build`, assembles `Rover.app`, and opens it.

## Building a DMG

To produce a distributable disk image locally:

```bash
brew install create-dmg
cd RoverApp
./package.sh
```

The output is `Rover.dmg` next to the `.app`. Drop it on a GitHub Release.

## How it works

```
user clicks Rover
        |
        v
SpeechBubbleView (input field)
        |
        | user types, presses Enter
        v
ClaudeRunner.send(prompt)
        |
        | stdin
        v
$ claude -p --output-format stream-json --include-partial-messages
         --model <opus|sonnet|haiku>
         --append-system-prompt "<custom>"
        |
        | NDJSON, one JSON object per line
        v
ClaudeRunner.handleLine -> ClaudeEvent
        |
        v
AppViewModel.handleEvent
        |
        +--> SpeechBubbleView (responseText accumulates, autoscroll)
        |
        +--> RoverState (Speak, Eat, Reading, Ashamed, ...)
                 |
                 v
            SpriteAnimator (NSImage sequence at 8 to 14 fps)
                 |
                 v
            RoverSpriteView
```

## Repository layout

```
rover-app/
  rover/                         original Microsoft Rover assets
    Resources/                   PNG sprites, WAV sounds, EN and RU text files
    Animation.cs                 reference Windows Forms implementation
    ...
  RoverApp/                      macOS Swift app
    Package.swift                SwiftPM manifest
    Info.plist                   bundle metadata
    build.sh                     sync assets, swift build, assemble .app
    run.sh                       build then open
    package.sh                   release build, create-dmg
    Sources/RoverApp/
      main.swift                       NSApp entry, window and menu setup
      FloatingWindow.swift             borderless transparent NSWindow,
                                       intrinsic size tracking host view
      RoverPetView.swift               sprite, drag handling, right click menu
      RoverSpriteView.swift            frame sequence animator
      SpeechBubbleView.swift           XP Luna bubble, input, response
      AppViewModel.swift               state machine, event to animation map
      ClaudeRunner.swift               claude CLI subprocess, NDJSON parser
      AnimationCatalog.swift           per state PNG sequence loading
      SoundPlayer.swift                AVAudioPlayer pool
      Settings.swift                   UserDefaults backed settings
      SettingsView.swift               settings window UI
      SettingsWindowController.swift
      MenuBarController.swift          NSStatusItem (paw)
      Localization.swift               AppStrings (en, ko)
      Theme.swift                      XP color tokens, cursor helper
```

## Keyboard and mouse

| Action                         | Effect                                          |
|--------------------------------|-------------------------------------------------|
| Click Rover                    | Open the input bubble                           |
| Drag Rover                     | Move the floating window                        |
| Right click Rover              | Context menu (Ask, Sound, Model, Settings, Quit)|
| Click the menu bar paw icon    | Open the input bubble from anywhere             |
| Cmd+,                          | Settings window                                 |
| Esc                            | Dismiss the bubble                              |
| Cmd+Q                          | Quit                                            |

## Limitations and TODO

- Conversation memory across prompts (`claude --continue` or `--resume`). Each prompt currently starts a fresh session.
- Markdown rendering for responses. Plain text only at the moment.
- Global system hotkey (for example Cmd+Space style). Today the menu bar icon is the closest equivalent.
- App icon (`.icns`). The bundle ships without one.
- Code signing and notarization. Without these, Gatekeeper requires a right click Open on first launch.
- Auto update.
- A UI to set the path to the `claude` CLI for installations that do not match the auto detected paths.

## Credits

- Rover character, sprite frames, and sound effects: copyright Microsoft Corporation, originally shipped with Windows XP Search Companion (2001).
- Claude Code: [Anthropic](https://anthropic.com).
- macOS revival: this repository.

The `rover/` directory contains the original assets together with a small C# Windows Forms reimplementation that this project used as a reference. Everything in `rover/` is included for archival and educational purposes only.

## License

- Original Microsoft Rover assets are property of Microsoft Corporation. They are included under fair use for nostalgia and educational purposes only. Do not redistribute commercially.
- The Swift code added by this repository is released under the MIT License.

> Rover left with Vista. We never quite said goodbye.
