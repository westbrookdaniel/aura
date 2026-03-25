# Sparkle Updates

This folder is intended to be published through GitHub Pages for Aura's Sparkle feed.

For the full release flow in one step, use:

`./scripts/release-tag.sh --version <version>`

That wrapper script:

1. builds the app archive for the requested version
2. republishes `docs/appcast.xml` and `docs/Aura-<version>.zip`
3. creates a release commit with the updated `docs/` artifacts
4. creates an annotated git tag named `v<version>`

The default `SUFeedURL` in `./scripts/build-app.sh` points at:

`https://westbrookdaniel.github.io/aura/appcast.xml`
