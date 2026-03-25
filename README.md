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
- `dist/Aura-<version>.zip`

## Automatic Updates

Aura ships with Sparkle integration in the packaged app:

- `Check for Updates...` is available from the menu bar menu
- Settings includes automatic check and automatic install toggles

Release setup:

- build signed releases with `AURA_SPARKLE_PUBLIC_ED_KEY` set
- by default, the Sparkle feed URL points at `https://westbrookdaniel.github.io/aura/appcast.xml`
- publish each archive into `docs/` and regenerate `appcast.xml` with `./scripts/publish-appcast.sh --version <version>`
- or run `./scripts/release-tag.sh --version <version>` to build, publish the Sparkle artifacts, commit the `docs/` release files, and create an annotated `v<version>` git tag

`docs/README.md` includes the GitHub Pages publishing flow.

## Sparkle Key Troubleshooting

`AURA_SPARKLE_PUBLIC_ED_KEY` is Sparkle's public EdDSA update-verification key.
Aura embeds this public key into the app's `Info.plist` as `SUPublicEDKey`, and Sparkle uses it to verify that downloaded updates were signed by your private key.

The split is:

- Apple code signing and notarization prove the app is trusted by macOS
- Sparkle's EdDSA keypair proves updates came from you

Generate the Sparkle keypair once:

```bash
./.build/artifacts/sparkle/Sparkle/bin/generate_keys
```

That command will:

- store the private key in your login Keychain
- print the public key you should use for `AURA_SPARKLE_PUBLIC_ED_KEY`

Build releases with the printed public key:

```bash
export AURA_SPARKLE_PUBLIC_ED_KEY='PASTE_PUBLIC_KEY_HERE'
./scripts/build-app.sh --version 0.1.0
```

Important:

- the public key is safe to embed in the app
- the private key must stay secret and should never be committed
- if `AURA_SPARKLE_PUBLIC_ED_KEY` is missing, Aura will build, but automatic updates will be unavailable in the packaged app
