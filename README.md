# Aura

Aura is a small macOS menu bar dictation app built in Swift. Hold a shortcut, speak, and it records audio, runs local transcription through `whisper.cpp`, then pastes the result into the focused app.

## Requirements

- macOS 13+
- Swift 6 command line tools or Xcode

These will be installed via homebrew when using the app:

- `whisper-cli`

The app also downloads:

- `ggml-medium.en.bin`

Default paths:

- `/opt/homebrew/bin/whisper-cli`
- `~/Library/Application Support/Aura/ggml-medium.en.bin`

## Run

```bash
swift run
```

## Build

```bash
./scripts/build-app.sh
```

Output:

- `dist/Aura.app`
- `dist/Aura.zip`
