# Listener

Listener is a native macOS menu bar dictation utility built in Swift. It stays out of the Dock, listens for a configurable press-and-hold shortcut, records audio while showing a bottom-center waveform pill, captures audio through SoX, runs local transcription through `whisper.cpp` with the fixed `ggml-medium.en.bin` model, and inserts the text into the currently focused field.

## Current implementation

- Native menu bar app using SwiftUI + AppKit
- Global shortcut monitor with `fn` and key combo support
- Non-activating floating overlay panel with live waveform
- SoX-based capture to 16 kHz mono WAV
- Local transcription via external `whisper-cli`
- Clipboard-based text insertion with simulated paste
- Settings for shortcut, permissions, microphone selection, recorder setup, Whisper setup, and launch at login

## Requirements

- macOS 13+
- Swift 6 command line tools or Xcode
- SoX
- A working `whisper-cli` binary from `whisper.cpp`
- The `ggml-medium.en.bin` Whisper model

## Run

```bash
cd /Users/dan/dev/listener
swift run
```

By default the app expects:

- `sox` at `/opt/homebrew/bin/sox`
- `whisper-cli` at `/opt/homebrew/bin/whisper-cli`
- model file at `~/Library/Application Support/Listener/ggml-medium.en.bin`

## Permissions

The app needs:

- Microphone access for recording
- Accessibility access for focused field insertion
- Input Monitoring for the global press-and-hold shortcut

## Build a distributable app

This repo now includes a release bundling script that turns the SwiftPM executable into a macOS `.app` bundle:

```bash
cd /Users/dan/dev/listener
./scripts/build-app.sh
```

That produces:

- `dist/Listener.app`
- `dist/Listener.zip`

What the script does:

- builds the app in release mode
- creates a real macOS app bundle with `Info.plist`
- marks the app as a menu bar app with `LSUIElement`
- includes `NSMicrophoneUsageDescription` so microphone permission prompts work correctly
- optionally signs the app
- optionally submits it for notarization and staples the ticket

## Signing and notarization

The script now defaults to:

- bundle ID: `com.westbrookdaniel.listener`
- version: `0.1.0`
- Apple ID: `westy12dan@gmail.com`
- developer name: `Daniel Westbrook`
- notary profile: `listener-notary`

For a different version:

```bash
./scripts/build-app.sh --version 0.2.0
```

For distribution outside the App Store, sign with your Developer ID Application certificate:

```bash
./scripts/build-app.sh --team-id "TEAMID"
```

If you want notarization, there is still one one-time setup step to store your app-specific password in the keychain:

```bash
./scripts/setup-notary-profile.sh \
  --team-id "TEAMID" \
  --app-password "app-specific-password"
```

Then build and notarize:

```bash
./scripts/build-app.sh \
  --team-id "TEAMID" \
  --notarize
```

## Remaining release polish

The project is now buildable as a distributable app bundle, but these are still external release decisions rather than code gaps:

- provide your Apple Developer Team ID at build time
- notarize before sharing broadly to avoid Gatekeeper warnings
- add a custom `Packaging/AppIcon.icns` if you want a branded app icon instead of the default generic one

## Notes

- `fn` handling on macOS is quirky across hardware and OS versions; the app uses global flag/key monitoring, but some machines may work better with Right Command or another custom trigger.
- Listener uses a single Whisper path based on `ggml-medium.en.bin`; there are no alternate model or pipeline options in the UI.
