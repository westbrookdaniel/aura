# Aura

Aura is a small macOS menu bar dictation app built in Swift. Hold a shortcut, speak, and it records audio, runs local transcription through `whisper.cpp`, then pastes the result into the focused app.

## Requirements

- macOS 13.3+
- Swift 6 command line tools or Xcode

The first build fetches the precompiled `whisper.cpp` XCFramework through SwiftPM.
The app stores its working model in:

- `~/Library/Caches/Aura/Models/ggml-medium.en.bin`

On first launch, Aura checks for an existing cached model and, if needed, downloads during setup with visible progress:

- `ggml-medium.en.bin`

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
