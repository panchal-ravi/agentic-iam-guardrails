# Fonts

**IBM Plex** is the brand typeface across Carbon. It's a three-member super-family:

- **IBM Plex Sans** — default UI/body
- **IBM Plex Mono** — code, data, timestamps, eyebrow labels
- **IBM Plex Serif** — editorial long-form

## This project

We load Plex via **Google Fonts** in `colors_and_type.css` — the same canonical source IBM uses. No TTFs live in this folder.

If you need self-hosted font files (e.g. for offline export, or to use the web-font variants with IBM's specific feature settings on), download from the official IBM repo:

- https://github.com/IBM/plex

Drop the `.ttf` / `.woff2` files into this folder and replace the `@import` at the top of `colors_and_type.css` with a local `@font-face` block.

## Substitution flag

⚠️ Google Fonts Plex is metrically identical to the GitHub release but is a slightly older build. For pixel-perfect parity with IBM's latest Plex (v6+ with the Arabic/Devanagari/Thai scripts), use the GitHub release.
