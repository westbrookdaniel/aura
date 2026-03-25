# Sparkle Updates

This folder is intended to be published through GitHub Pages for Aura's Sparkle feed.

Recommended setup:

1. In GitHub, enable Pages for the `main` branch using the `/docs` folder.
2. Build a notarized release with `AURA_SPARKLE_PUBLIC_ED_KEY` set.
3. Run `./scripts/publish-appcast.sh --version <version>` to copy `dist/Aura-<version>.zip` here and regenerate `appcast.xml`.
4. Commit and push the updated files in `docs/`.

For the full release flow in one step, use:

`./scripts/release-tag.sh --version <version>`

That wrapper script:

1. builds the app archive for the requested version
2. republishes `docs/appcast.xml` and `docs/Aura-<version>.zip`
3. creates a release commit with the updated `docs/` artifacts
4. creates an annotated git tag named `v<version>`

The default `SUFeedURL` in `./scripts/build-app.sh` points at:

`https://westbrookdaniel.github.io/aura/appcast.xml`

Override `AURA_SPARKLE_FEED_URL` if you want to host the appcast somewhere else.
