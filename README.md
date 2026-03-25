# Aura

Aura is a small macOS menu bar dictation app built in Swift. Hold a shortcut, speak, and it records audio, runs local transcription through `whisper.cpp`, then pastes the result into the focused app.

## Requirements

- macOS 13.3+
- Swift 6 command line tools or Xcode

The first build fetches the precompiled `whisper.cpp` XCFramework through SwiftPM.
The app stores its working model in:

- `~/Library/Caches/Aura/Models/ggml-medium.en.bin`

If no bundled or migrated model is available, the app downloads:

- `ggml-medium.en.bin`

## Run

```bash
swift run
```

## Build

```bash
./scripts/build-app.sh
```

If `ggml-medium.en.bin` already exists in `~/Library/Caches/Aura/Models` or `~/Library/Application Support/Aura`, the build script bundles it into the app automatically.

Output:

- `dist/Aura.app`
- `dist/Aura.zip`
