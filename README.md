# rover.app

<p align="center">
  <img src="docs/rover-hero.gif" width="240" alt="Rover talking" />
</p>

A homage to **Rover**, the yellow Labrador Retriever that lived inside Windows XP's Search Companion (2001). This project resurrects him as a floating macOS desktop pet, powered by Claude Code.

<p align="center">
  <img src="docs/rover-states.png" width="800" alt="Rover idle, speaking, reading, sleeping" />
</p>

<p align="center">
  <em>idle &nbsp;·&nbsp; speak &nbsp;·&nbsp; reading &nbsp;·&nbsp; sleep</em>
</p>

## Demo

The full app in action (Rover floating on your desktop, opening the bubble, streaming a Claude response):

<!-- Replace this placeholder with the actual recording. Capture with
     macOS Cmd+Shift+5 (Record Selected Portion), save as docs/demo.mp4
     or docs/demo.gif, then reference it below. -->

> Demo video coming soon. To capture your own, use Cmd+Shift+5 on macOS, choose Record Selected Portion, frame Rover plus the bubble, and save the file as `docs/demo.mp4`.

## What is this

In 2001, Microsoft put a friendly guide into Windows XP's search panel: a cartoon Labrador named Rover who watched while you typed, blinked, looked around, and went to sleep when you stopped. He was retired in Vista. This project brings him back, twenty five years later, as a floating macOS pet that drives modern coding agents.

The original sprite frames and sound effects are kept as they shipped. What changed is what he does. Click Rover, type a prompt, and he forwards it to one of three pluggable backends: the local Claude Code CLI, the local OpenAI Codex CLI, or Anthropic's Computer Use API (which lets him read your screen and operate the mouse and keyboard for you). His animations track the live event stream from whichever backend is active. When the agent reads files, Rover reads. When it runs a shell tool, Rover eats. When something errors, Rover looks ashamed. He sleeps after a minute of inactivity, and clicking him wakes him up.

This is a nostalgia project. It is not affiliated with Microsoft and has no commercial intent.

## Features

### Pet behavior

- Floating, borderless, transparent window. Drag him anywhere on screen.
- XP Luna style speech bubble. Click Rover to open the input field, press Enter to send.
- 24 animation states sourced from the original sprite sheet (idle, idle fidgets, sleep, speak, eat, reading, ashamed, lick, haf, exit).
- Original WAV sound effects (Haf, Lick, Whine, Snoring, Tap).
- Sleep after 60 seconds of inactivity. Click to wake.
- Bubble grows upward from a fixed bottom anchor, scrolls when content exceeds the visible area, and never crosses the top of the screen.

### Multiple backends

- **Claude Code CLI** (default). Wraps `claude -p --output-format stream-json --include-partial-messages`, parses NDJSON line by line, and maps tool use to Rover animations.
- **Codex CLI**. Same idea against the OpenAI Codex CLI.
- **Anthropic Computer Use** (beta). Talks to the Anthropic API directly using the `claude-opus-4-7` Computer Use loop. Roger captures screenshots, sends them to the model, and dispatches the resulting mouse/keyboard/scroll/key actions on your machine. API key is stored in macOS Keychain.

### Triggers

Rover does not have to wait for a click. Optional triggers, each toggleable in Settings:

- **Global hotkey** (⌘⇧Space). Summon the bubble from anywhere, even when another app is full-screen.
- **Active app change**. When you switch to a new app he plays a short animation and (optionally) shows a hint. No agent calls, zero cost.
- **Periodic screen observation**. On a configurable interval he sends a screenshot to Computer Use to check whether you need help. Each glance costs API credits, so the interval defaults to 10 minutes.
- **Scheduled tasks**. Per-day HH:MM entries with a fixed prompt that runs through the active backend.

### Safety

- **Dry-run mode** (Settings → Advanced). Mouse and keyboard tools log the action but do not execute it. Useful while learning what the agent will try.
- **Esc cancels the agent loop** at any time, mid-tool.
- All mouse, keyboard, and screenshot tool calls go through a single dispatcher that respects the dry-run flag and per-action delay.
- API keys live in macOS Keychain, never in plain config files.
- TCC permission prompter walks you through Accessibility, Screen Recording, and Apple Events on first run.

### Settings (six tabs)

- General: language (System / English / 한국어), menu bar toggle, sound toggle, working directory.
- Backend: pick the active backend, paste your Anthropic API key.
- Triggers: enable and tune each of the four triggers above.
- Model: pick Claude Opus 4.7, Sonnet 4.6, or Haiku 4.5 for CLI backends.
- System Prompt: persistent append-system-prompt with reset to default per language.
- Advanced: dry-run toggle, action delay, `--dangerously-skip-permissions` for the CLI backends, version and binary paths.

### Localization

- English and Korean.
- System language is auto detected. Manual override in Settings.

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
- One of the following backends, depending on which you want to use:
  - **Claude Code CLI**. Probed automatically at `/Applications/cmux.app/Contents/Resources/bin/claude`, `/opt/homebrew/bin/claude`, `/usr/local/bin/claude`, `~/.claude/local/claude`.
  - **Codex CLI**. Probed at the standard `codex` install paths.
  - **Anthropic Computer Use**. No CLI required, but you do need an Anthropic API key (paste it into Settings → Backend, stored in Keychain).

```bash
git clone https://github.com/youngjae99/rover-app.git
cd rover-app/RoverApp
./run.sh
```

`run.sh` syncs the assets from `rover/Resources/` into the SwiftPM resource directory, runs `swift build`, assembles and ad-hoc codesigns `Rover.app`, then opens it. The ad-hoc signature is what keeps macOS TCC permissions stable across rebuilds (Accessibility, Screen Recording, Apple Events).

### Permissions on first run

Computer Use, the global hotkey, and the active-app trigger each need different macOS permissions. Rover prompts you the first time each is needed:

- **Accessibility** (mouse and keyboard control, global hotkey).
- **Screen Recording** (periodic screen observation, Computer Use screenshots).
- **Apple Events** (active-app trigger uses AEs to read which app is in the foreground).

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
trigger        click             ⌘⇧Space hotkey
hotkey         active-app        scheduled task
periodic       change            etc.
        \      |       /
         v     v      v
       TriggerContext
              |
              v
       AppViewModel
              |
              v
       AgentCoordinator
              |
   +----------+-----------+--------------------+
   v                      v                    v
ClaudeCodeCLI         CodexCLI         AnthropicComputerUse
(stdin -> stream-json) (stdin -> JSON)  (HTTPS, computer-use loop)
        \                |               /
         v               v              v
              AgentEvent stream
                    |
        +-----------+-----------+
        v                       v
   SpeechBubbleView         AnimationMapper
   (text accumulates,       (event -> RoverState)
    autoscroll)                  |
                                  v
                          SpriteAnimator
                          (NSImage sequence,
                           8 to 14 fps)
                                  |
                                  v
                          RoverSpriteView
```

For the Computer Use backend, the loop additionally goes:

```
AnthropicAPIClient                       (HTTPS, beta header)
        |
        v
ComputerUseAction (screenshot / click / type / key / scroll / ...)
        |
        v
SafetyController (dry-run? action delay?)
        |
        v
ComputerUseDispatcher
        |
   +----+----+----+
   v    v    v    v
Screenshot Mouse Keyboard ActiveWindow
   Tool   Tool    Tool        Tool
```

## Repository layout

```
rover-app/
  rover/                              original Microsoft Rover assets
    Resources/                        PNG sprites, WAV sounds, EN and RU text
    Animation.cs                      reference Windows Forms implementation
  docs/                               README assets (hero gif, states strip)
  RoverApp/                           macOS Swift app
    Package.swift                     SwiftPM manifest
    Info.plist                        bundle metadata, TCC usage strings
    build.sh                          sync assets, swift build, ad-hoc codesign
    run.sh                            build then open
    package.sh                        release build, create-dmg
    Sources/RoverApp/
      main.swift                      NSApp entry, wires coordinator + triggers
      FloatingWindow.swift            borderless transparent NSWindow,
                                      intrinsic size tracking host view
      RoverPetView.swift              sprite, drag handling, right click menu
      RoverSpriteView.swift           frame sequence animator
      SpeechBubbleView.swift          XP Luna bubble, input, response
      AppViewModel.swift              UI state machine
      AnimationCatalog.swift          per state PNG sequence loading
      SoundPlayer.swift               AVAudioPlayer pool
      Settings.swift                  UserDefaults backed settings
      SettingsView.swift              six-tab settings UI
      SettingsWindowController.swift
      MenuBarController.swift         NSStatusItem (paw)
      Localization.swift              AppStrings (en, ko)
      Theme.swift                     XP color tokens, cursor helper

      Agents/                         pluggable backends
        AgentBackend.swift            protocol
        AgentEvent.swift              event enum + ComputerUseAction
        ClaudeCodeCLIBackend.swift    Claude Code CLI wrapper
        CodexCLIBackend.swift         Codex CLI wrapper
        AnthropicComputerUseBackend.swift  Anthropic Computer Use loop
        AnthropicAPIClient.swift      HTTPS client

      Coordinator/
        AgentCoordinator.swift        single dispatch surface
        AnimationMapper.swift         AgentEvent -> RoverState

      Triggers/                       optional autonomous hooks
        Trigger.swift                 protocol
        HotkeyTrigger.swift           ⌘⇧Space global hotkey
        ActiveAppTrigger.swift        active-app change
        PeriodicScreenTrigger.swift   periodic screen observation
        ScheduleTrigger.swift         scheduled HH:MM tasks

      ComputerUse/
        ComputerUseDispatcher.swift   single funnel for tool actions
        CoordinateScaler.swift
        ScreenInfo.swift
        Safety/
          SafetyController.swift      dry-run + action delay + Esc
        Tools/
          ScreenshotTool.swift
          MouseTool.swift             CGEvent based clicks, moves, scroll
          KeyboardTool.swift
          ActiveWindowTool.swift

      Security/
        Keychain.swift                Anthropic API key storage

      Permissions/
        PermissionPrompter.swift      TCC walkthrough on first use
```

## Keyboard and mouse

| Action                         | Effect                                          |
|--------------------------------|-------------------------------------------------|
| Click Rover                    | Open the input bubble                           |
| Drag Rover                     | Move the floating window                        |
| Right click Rover              | Context menu (Ask, Sound, Model, Settings, Quit)|
| Click the menu bar paw icon    | Open the input bubble from anywhere             |
| ⌘⇧Space                        | Global hotkey (Settings → Triggers to enable)   |
| Cmd+,                          | Settings window                                 |
| Esc                            | Dismiss the bubble, cancel the running agent    |
| Cmd+Q                          | Quit                                            |

## Limitations and TODO

- Conversation memory across prompts. Each prompt currently starts a fresh session for the CLI backends. Computer Use turns are stateful within a single run, but not across runs.
- Markdown rendering for responses. Plain text only at the moment.
- App icon (`.icns`). The bundle ships without one.
- Code signing and notarization for distribution. Local builds are ad-hoc signed (enough to keep TCC stable), but Gatekeeper still requires a right-click Open on first launch from a DMG.
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
