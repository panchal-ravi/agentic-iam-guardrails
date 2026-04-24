---
name: ibm-carbon-design
description: Use this skill to generate well-branded interfaces and assets for IBM Carbon Design System, either for production or throwaway prototypes/mocks/etc. Contains essential design guidelines, colors, type, fonts, assets, and UI kit components for prototyping.
user-invocable: true
---

Read the `README.md` file within this skill, and explore the other available files.

The folder layout:

- `README.md` — full company/brand context, content fundamentals, visual foundations, iconography.
- `colors_and_type.css` — all tokens (color, type, spacing, motion, shape). Always `@import` this before writing any Carbon UI.
- `fonts/` — font notes; IBM Plex is fetched from Google Fonts by default.
- `assets/` — IBM wordmark + curated @carbon/icons SVG subset.
- `preview/` — small HTML spec cards (palette, type scales, component states). Good reference when designing.
- `ui_kits/carbon-product/` — hi-fi React recreation of a Carbon enterprise product (UI Shell + dashboard + data table + modal). Lift components and patterns from here.

If creating visual artifacts (slides, mocks, throwaway prototypes, etc.), copy assets out and create static HTML files for the user to view. If working on production code, you can copy assets and read the rules in `README.md` to become an expert in designing with IBM Carbon.

If the user invokes this skill without any other guidance, ask them what they want to build or design, ask clarifying questions about theme (White vs G90), audience (product vs marketing), and output format, then act as an expert designer who outputs HTML artifacts or production code depending on the need.

Key rules to internalize:

1. **One theme per view.** White, Gray 10, Gray 90, Gray 100. Never mix.
2. **IBM Blue 60 (`#0f62fe`) is the only brand accent.** Use it once per view.
3. **Sharp corners everywhere.** Radius only on AI pills and Tags.
4. **IBM Plex Sans** for UI, **Mono** for code/data/eyebrows, **Serif** for editorial only.
5. **Sentence case.** No exclamation marks. No emoji in product UI.
6. **4px base grid.** Use spacing tokens, not arbitrary px.
7. **Borders, not shadows.** Shadow only on overlay surfaces.
8. **Carbon icons** from `@carbon/icons`. Never hand-draw SVGs.
