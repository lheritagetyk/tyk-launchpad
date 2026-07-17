# portal-theme — your brand overlay (diff only)

This directory holds **only your changes** to the official Tyk portal theme. The full
theme comes from `vendor/portal-default-theme` at runtime; `lib/build-theme.sh` copies it
into a build dir, applies this overlay, and produces a deployable zip. Nothing Tyk-shipped
is copied into the tracked tree.

This directory ships **templates only** (`*.example`) — your real overlay
(`overlay.json`, `brand.css`, `assets/`) is gitignored so your branding never lands in the
shared toolkit. `build-theme.sh` seeds the working files from the templates on first run;
then edit them. To start manually: `cp overlay.json.example overlay.json` and
`cp brand.css.example brand.css`.

What you edit here:
- **`overlay.json`** (from `overlay.json.example`) — theme name/version/author stamped onto
  `theme.json`. The `name` MUST differ from `default` (the portal forbids editing the default theme).
- **`brand.css`** (from `brand.css.example`) — overrides of the documented `--tdp-*` CSS
  variables (see `vendor/tyk-docs/portal/customization/branding.mdx`). Appended after the
  theme's `main.css` so it wins.
- **`assets/<same/relative/path>`** — drop a file here to replace the theme's file at that
  path. e.g. `assets/images/dev-portal-logo.svg` replaces the portal logo.

Build + deploy is handled by the `customize-portal-theme` skill / `lib/build-theme.sh` +
`lib/upload-theme.sh`. Match the theme to your portal release (see the skill).
