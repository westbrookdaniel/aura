# Listener

Listener is a native macOS menu bar dictation utility built in Swift. It stays out of the Dock, listens for a configurable press-and-hold shortcut, records audio while showing a bottom-center waveform pill, runs local transcription through `whisper.cpp`, and inserts the text into the currently focused field.

## Current implementation

- Native menu bar app using SwiftUI + AppKit
- Global shortcut monitor with `fn` and key combo support
- Non-activating floating overlay panel with live waveform
- `AVAudioEngine` capture to 16 kHz mono WAV
- Local transcription via external `whisper-cli`
- Accessibility-first text insertion with clipboard/paste fallback
- Settings for shortcut, model selection, binary/model paths, idle timeout, fallback policy, and launch at login

## Requirements

- macOS 13+
- Swift 6 command line tools or Xcode
- A working `whisper-cli` binary from `whisper.cpp`
- A local Whisper model file such as `ggml-base.en.bin`

## Run

```bash
cd /Users/dan/dev/listener
swift run
```

By default the app expects:

- `whisper-cli` at `/opt/homebrew/bin/whisper-cli`
- model file at `~/Library/Application Support/Listener/ggml-base.en.bin`

You can change both paths in Settings.

## Permissions

The app needs:

- Microphone access for recording
- Accessibility access for focused field insertion
- Input Monitoring for the global press-and-hold shortcut

## Notes

- `fn` handling on macOS is quirky across hardware and OS versions; the app uses global flag/key monitoring, but some machines may work better with Right Command or another custom trigger.
- `whisper.cpp` is invoked as an external worker process in this version, which keeps the menu bar app’s idle memory footprint lower than embedding the model in-process.
