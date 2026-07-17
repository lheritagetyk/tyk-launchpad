---
name: customize-portal-theme
description: Brand and deploy a Tyk Enterprise Developer Portal theme (logo, colors, copy) by scaffolding a new theme from the official default theme. Use when the user wants to customize, brand, or theme the developer portal.
---

# Customize the developer portal theme

Ground in `vendor/tyk-docs/portal/customization/themes.mdx` and `.../branding.mdx`.
Approach: **scaffold a new theme project from the official `portal-default-theme`** into a
directory the user chooses, then edit + deploy it. The toolkit ships no theme content of its
own — the scaffolded theme is the customer's own artifact.

## Key facts (from the docs)
- A theme = `theme.json` manifest + `assets/ layouts/ views/ partials/` (Go templates).
- The portal **forbids editing the `default` theme** — the new theme must be renamed.
- Brand knobs: logo at `assets/images/dev-portal-logo.svg`; colors via `--tdp-*` CSS
  variables in `assets/stylesheets/main.css`.
- Deploy via the Portal API: `POST /themes/upload` then `POST /themes/{id}/activate`
  (admin token). Per-file upload limit 5MB; total ≤ `PORTAL_MAX_UPLOAD_SIZE`.
- **Version-match:** themes are published per portal release; use the `portal-default-theme`
  ref matching the deployed portal version.

## Flow
1. **Sources** — `bash lib/ensure-sources.sh ensure`.
2. **Ask where to put it.** Get a directory from the user — this is their theme project, it
   lives wherever they want, not inside tyk-launchpad.
3. **Scaffold** from the official default theme:
   ```sh
   NAME=<theme-name> DEST=<their-dir> bash lib/new-theme.sh
   ```
   Creates `<their-dir>/<theme-name>` from `portal-default-theme`, renamed in `theme.json`.
   (If the portal is a released version, check out the matching `portal-default-theme` tag
   first: `git -C vendor/portal-default-theme tag`.)
4. **Brand it** — edit in the scaffolded dir:
   - `assets/stylesheets/main.css` → the `--tdp-*` variables (nav/body/text/link/button/border)
   - `assets/images/dev-portal-logo.svg` → their logo
   Show the user the changes; keep them in that directory.
5. **Deploy** — zips, validates the 5MB limit, uploads, activates:
   ```sh
   THEME_DIR=<their-dir>/<theme-name> PORTAL_URL=http://localhost:3001 \
     PORTAL_TOKEN=<admin-token> bash lib/upload-theme.sh          # DRY_RUN=1 to preview
   ```
   The admin token is available to portal admins — ask the user; never print/commit it.

## Guardrails (detect → documented fix)
- Upload rejected for size → a file exceeds 5MB or the total exceeds `PORTAL_MAX_UPLOAD_SIZE`
  (configurable — see the deploy/configuration doc). Trim assets.
- Won't save/activate as `default` → rename in `theme.json` (the scaffolder does this).
- Try-It (Stoplight) auth/CORS issues are an **API** concern, not the theme →
  `author-oas-apis` (CORS at `middleware.global.cors`).

## Not this skill
API products/plans/catalogue content → `build-products-plans`.
