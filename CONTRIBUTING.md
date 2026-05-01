# Contributing to Rover.app

Bug reports, feature ideas, and pull requests are all welcome. Open an [issue](https://github.com/youngjae99/rover-app/issues) to discuss, or send a PR directly.

## Local development

```bash
git clone https://github.com/youngjae99/rover-app.git
cd rover-app/RoverApp
./run.sh
```

Requires:

- macOS 14 or later.
- Swift 5.9 or later. Command Line Tools is enough; full Xcode is not required.

`run.sh` syncs the assets from `rover/Resources/` into the SwiftPM resource directory, runs `swift build`, assembles and ad-hoc codesigns `Rover.app`, and opens it. The ad-hoc signature is what keeps macOS TCC permissions stable across rebuilds (Accessibility, Screen Recording, Apple Events).

For a release build + DMG:

```bash
cd RoverApp
./package.sh
```

The script uses `hdiutil` directly; no `create-dmg` dependency.

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
    package.sh                        release build + hdiutil DMG
    Rover.icns                        app icon
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

## Adding a new agent backend

Conform to `AgentBackend` in `Sources/RoverApp/Agents/`. The protocol expects an event stream of `AgentEvent` cases — `tool(name:)`, `text(...)`, `done`, `error(...)` etc. — that `AnimationMapper` translates into a `RoverState`. CLI-style backends are good references; see `ClaudeCodeCLIBackend.swift` for stream-json parsing and `CodexCLIBackend.swift` for the Codex variant.

If your backend talks directly to a hosted API (rather than wrapping a local CLI), follow `AnthropicComputerUseBackend.swift`. API keys go through `Security/Keychain.swift`, never into `UserDefaults`.

## Adding a trigger

Conform to `Trigger` in `Sources/RoverApp/Triggers/`. Triggers post a `TriggerContext` into the `AppViewModel`. Toggle persistence lives in `Settings.swift`; surface a control in the corresponding tab of `SettingsView.swift`.

## Localization

`Sources/RoverApp/Localization.swift` (`AppStrings`) holds all user-facing strings. Add a new locale by extending the `AppStrings` enum cases and routing the new locale through the language picker in `SettingsView.swift`. Auto-detection lives in `main.swift`.

When you add UI text, add the EN string and the matching 한국어 string in the same PR — don't ship strings in only one language.

## Style

- Match existing SwiftUI / AppKit boundaries: AppKit for windows, dragging, menu bar; SwiftUI for the bubble and Settings.
- Follow the existing 4-space indent, no trailing whitespace.
- Keep comments to the WHY only; the WHAT is the code itself.

## Pull requests

- One conceptual change per PR. Easier to review, easier to revert.
- Smoke-test on macOS 14 and 15 if possible.
- For Computer Use changes, exercise both dry-run and live modes once.
- For new permissions, add the matching usage-description key to `Info.plist`.

Thanks for contributing.
