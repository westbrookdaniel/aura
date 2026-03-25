# Sparkle Updates

This folder is intended to be published through GitHub Pages for Aura's Sparkle feed.

Recommended setup:

1. In GitHub, enable Pages for the `main` branch using the `/docs` folder.
2. Build a notarized release with `AURA_SPARKLE_PUBLIC_ED_KEY` set.
3. Run `./scripts/publish-appcast.sh --version <version>` to copy `dist/Aura-<version>.zip` here and regenerate `appcast.xml`.
4. Commit and push the updated files in `docs/`.

The default `SUFeedURL` in `./scripts/build-app.sh` points at:

`https://westbrookdaniel.github.io/aura/appcast.xml`

Override `AURA_SPARKLE_FEED_URL` if you want to host the appcast somewhere else.
