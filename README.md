# Listener

Listener is a native macOS menu bar dictation utility built in Swift. It stays out of the Dock, listens for a configurable press-and-hold shortcut, records audio while showing a bottom-center waveform pill, captures audio through SoX, runs local transcription through `whisper.cpp` with the fixed `ggml-medium.en.bin` model, and inserts the text into the currently focused field.

## Current implementation

- Native menu bar app using SwiftUI + AppKit
- Global shortcut monitor with `fn` and key combo support
- Non-activating floating overlay panel with live waveform
- SoX-based capture to 16 kHz mono WAV
- Local transcription via external `whisper-cli`
- Accessibility-first text insertion with clipboard/paste fallback
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

## Notes

- `fn` handling on macOS is quirky across hardware and OS versions; the app uses global flag/key monitoring, but some machines may work better with Right Command or another custom trigger.
- Listener uses a single Whisper path based on `ggml-medium.en.bin`; there are no alternate model or pipeline options in the UI.
