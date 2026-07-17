---
name: customize-portal-theme
description: Brand and deploy a Tyk Enterprise Developer Portal theme (logo, colors, copy) starting from the official default theme. Use when the user wants to customize, brand, or theme the developer portal.
---

# Customize the developer portal theme

Ground in `vendor/tyk-docs/portal/customization/themes.mdx` and `.../branding.mdx`.
Approach: **overlay, not fork** — keep only the brand diff in `portal-theme/`; the full
theme comes from `vendor/portal-default-theme` at build time.

## Key facts (from the docs)
- A theme = `theme.json` manifest + `assets/ layouts/ views/ partials/` (Go templates).
- The portal **forbids editing the `default` theme** — you must upload a **renamed** theme.
- Brand knobs: logo at `assets/images/dev-portal-logo.svg`; colors via `--tdp-*` CSS
  variables in `assets/stylesheets/main.css`.
- Deploy via the Portal API: `POST /themes/upload` then `POST /themes/{id}/activate`
  (admin authorisation token). Per-file upload limit 5MB; total ≤ `PORTAL_MAX_UPLOAD_SIZE`.
- **Version-match:** the theme should match the portal release (themes are published per
  release tag). Detect the portal version and use the matching `portal-default-theme` ref.

## Flow
1. **Sources + version match** — `bash lib/ensure-sources.sh ensure`. Find the deployed
   portal version:
   ```sh
   kubectl get deploy -n tyk -o jsonpath='{range .items[*]}{.metadata.name}{" "}{.spec.template.spec.containers[0].image}{"\n"}{end}' | grep -i portal
   ```
   If it differs from the base theme, check out the matching tag:
   `git -C vendor/portal-default-theme checkout <tag>` (list: `git -C vendor/portal-default-theme tag`).
2. **Gather brand** — logo file, brand colors, theme name. The overlay ships as templates
   (`*.example`); seed the working files (`cp overlay.json.example overlay.json`,
   `cp brand.css.example brand.css` — `build-theme.sh` also does this on first run), then edit:
   - `portal-theme/overlay.json` → `name` (must ≠ `default`), version, author
   - `portal-theme/brand.css` → set the `--tdp-*` variables
   - drop the logo at `portal-theme/assets/images/dev-portal-logo.svg`
   These working files are gitignored (the customer's branding, not toolkit content).
3. **Build** — `bash lib/build-theme.sh` → `dist/<name>-theme.zip` (validates 5MB/file).
4. **Preview (safe)** — `THEME_ZIP=dist/<name>-theme.zip DRY_RUN=1 bash lib/upload-theme.sh`.
5. **Deploy** — needs the portal admin token and URL:
   ```sh
   PORTAL_URL=http://localhost:3001 PORTAL_TOKEN=<admin-token> \
     THEME_ZIP=dist/<name>-theme.zip bash lib/upload-theme.sh
   ```
   Uploads then activates. The admin token is available to portal admins — ask the user
   for it (or how they expose the portal); never print or commit it.

## Guardrails (detect → documented fix)
- Upload rejected for size → a file exceeds 5MB or the total exceeds
  `PORTAL_MAX_UPLOAD_SIZE` (configurable — see the deploy/configuration doc). Trim assets.
- Theme won't save/activate as `default` → it must be renamed (step 2). Confirm in docs.
- Try-It (Stoplight) auth/CORS issues are an **API** concern, not the theme →
  `author-oas-apis` (CORS at `middleware.global.cors`).

## Not this skill
API products/plans/catalog content → `build-products-plans`.
