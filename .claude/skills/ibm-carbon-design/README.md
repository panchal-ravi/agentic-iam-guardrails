# IBM Carbon Design System

A design-system-in-a-project snapshot of **IBM's Carbon Design System** — IBM's open-source, cross-framework system that powers IBM's digital products, IBMid, IBM Cloud, watsonx, Instana, QRadar, and countless internal tools. Use this project to generate Carbon-branded interfaces, slides, marketing pages, and product prototypes without having to re-derive the tokens each time.

## Sources

All materials in this project are derived from public Carbon resources. We did **not** have a direct codebase or Figma attached — foundations were rebuilt from the canonical `llms.txt` index and from token/component specs published under the Apache-2.0-licensed Carbon packages on GitHub.

- **`llms.txt` index** — `https://carbondesignsystem.com/llms.txt`
- **Main monorepo** — `https://github.com/carbon-design-system/carbon`
  - Tokens: `packages/tokens`, `packages/themes`, `packages/type`, `packages/layout`, `packages/motion`
  - Components: `packages/react`, `packages/web-components`
  - Icons: `packages/icons` (SVG source), `packages/icons-react`
  - Pictograms: `packages/pictograms`
- **IBM Products monorepo** — `https://github.com/carbon-design-system/ibm-products` (advanced enterprise patterns)
- **Carbon AI Chat** — `https://github.com/carbon-design-system/carbon-ai-chat`
- **Storybook (live demos)** — `https://react.carbondesignsystem.com/`

If the reader has access to the Carbon repo locally, prefer it as the source of truth; files here follow it closely but are hand-curated rebuilds.

## What Carbon is

Carbon is the design language of IBM. It is intentionally **quiet, geometric, and engineered** — Carbon surfaces information, it does not decorate it. It is built on the **IBM Design Language**: the same language that governs IBM's brand, illustration, motion, and voice.

Key properties:

- **Sharp corners** everywhere. Cards, buttons, fields, tiles: all 0–4px radius. Softness is rare and reserved (AI pills, tooltips).
- **Rectangular, two-dimensional grid.** Content sits on a 2x-grid of 16-col layout. Gutters, tiles, and type align to the same scale.
- **IBM Plex** — the in-house super-family. Sans for UI and body; Mono for code, data, and eyebrow labels; Serif for editorial moments.
- **Four reference themes** (White, Gray 10, Gray 90, Gray 100) sharing a single semantic token set. Every Carbon product picks one and sticks to it.
- **IBM Blue 60 (`#0f62fe`)** is the single brand accent. Carbon discourages adding more.
- **Pictograms & illustrations** in a signature thin-line, 2px-stroke style — never 3D, never gradient-heavy.

## Project index

| File / folder | What it is |
|---|---|
| `README.md` | You are here. High-level guide to this project. |
| `SKILL.md` | Agent Skill entry point — load this when invoking the skill in Claude Code. |
| `colors_and_type.css` | All Carbon color, type, spacing, motion, and shape tokens as CSS vars. Import it first. |
| `fonts/` | Font license + notes (IBM Plex is fetched from Google Fonts for this kit). |
| `assets/` | Brand marks, icons, pictogram samples, sample imagery. |
| `preview/` | Small HTML cards shown in the Design System tab — palettes, type specimens, component states. |
| `ui_kits/carbon-product/` | Hi-fi product UI kit: UI Shell + dashboard + data table + modal. |
| `ui_kits/carbon-marketing/` | Hi-fi IBM.com-style marketing/landing kit. |
| `ui_kits/watsonx/` | Hi-fi watsonx console: Home, Projects, Prompt Lab. |
| `slides/` | IBM PowerPoint-guideline slide template, rebuilt as HTML. |

---

## CONTENT FUNDAMENTALS

Carbon voice is IBM's product-engineering voice: **direct, concrete, calm**. It is not chatty, not cute, not salesy. Imagine a senior systems engineer writing a calm cover email at 10am on a Tuesday.

### Rules

- **Sentence case everywhere.** Buttons, section titles, menu items, page titles. The only exceptions are product names ("watsonx", "IBM Cloud"), proper nouns, and acronyms.
- **Second person ("you"), active voice.** "You don't have permission to edit this file." Not "The user does not have permission."
- **Name the thing, then say what to do.** "Resource groups · Create a resource group to organize your resources." Not "Get started by creating something!"
- **Short. Verbs first.** "Create", "Delete", "Run", "Deploy", "Save changes". Never "Go ahead and create…".
- **No exclamation marks.** Ever. Carbon product copy does not shout. Marketing copy uses them sparingly (maybe one per page, for the hero).
- **No emoji** in product UI. Marketing may use them only in stylized social contexts. Inside Carbon, meaning is carried by Carbon icons and pictograms, not emoji.
- **Numerals, not words.** "3 items selected", not "three items selected".
- **Error messages state the problem and the fix.** "This email is already in use. Try signing in instead." Not "Oops! Something went wrong."
- **Empty states are instructional, not apologetic.** "No resources yet. Create your first resource group to get started."
- **Oxford comma on.** Serial commas throughout IBM editorial style.

### Capitalization

- **Page / screen titles:** Sentence case. *Resource groups*
- **Buttons:** Sentence case. *Create resource group*, *Save changes*
- **Labels & fields:** Sentence case. *Email address*, *API key*
- **Product names:** As-branded. *IBM watsonx.ai*, *IBM Cloud Pak for Data*
- **Acronyms:** All-caps. *IAM*, *SDK*, *GPU*

### Example copy

> **Page heading:** Identity and access
>
> **Subheading:** Manage users, service IDs, access groups, and the permissions assigned to them.
>
> **Empty state:** You haven't created any access groups yet. Access groups let you organize users and grant them permissions together.
>
> **Primary button:** Create access group
>
> **Inline error on email field:** Enter a valid email address.
>
> **Toast after save:** Access group saved.

### Marketing (IBM.com) voice

Slightly looser, but still restrained. Big claims are backed by specifics — IBM's marketing copy reads like a technical whitepaper with a good editor.

> **Hero:** Let's create a world that works better.
>
> **Sub:** From hybrid cloud and AI to quantum computing, we help organizations turn their hardest problems into working solutions.

---

## VISUAL FOUNDATIONS

### Color

- **Four reference themes** — **White**, **Gray 10**, **Gray 90**, **Gray 100**. Pick one per product and keep it. Never mix themes in the same view except via **Layer** reversal.
- **IBM Blue 60 (`#0f62fe`)** is *the* brand accent. Used for primary buttons, focus rings, links, selection states. Use it once per view, for the single most important action.
- **10-step color scales** for every hue. Semantic tokens (`--cds-button-primary`, `--cds-text-primary`, `--cds-layer-01`) reference these — always reach for the semantic token, never the raw hex.
- **Status colors** are fixed: Red 60 (danger), Green 50/60 (success), Yellow 30 (warning), Blue 70 (info). Do not invent new status colors.
- **Layer system** — instead of shadow stacks, Carbon builds depth from **flat layers of increasing lightness** (`layer-01`, `layer-02`, `layer-03`). A modal on a page shifts one layer up.

### Typography

- **IBM Plex Sans** for all UI and body.
- **IBM Plex Mono** for code, data cells, eyebrow labels above marketing heros, and legal / timestamp text.
- **IBM Plex Serif** for editorial features and long-form reading (rarely used in product).
- **Two type scales**: **Productive** (tight, compact — for dense UI) and **Expressive** (looser, larger — for marketing, empty states, hero moments). Never mix them inside a single component.
- Weights used: 300 (light — only in large display), 400 (regular), 600 (semibold — the "bold" in Carbon product).
- Line-height is tight: 1.25–1.5 on body; 1.2 on display. **No letter-spacing on body**; small positive tracking on LABEL and HELPER sizes.

### Spacing

- Everything aligns to the **4px base grid**, via tokens `spacing-01` (2px) through `spacing-13` (160px). Never use arbitrary pixel values.
- Typical vertical rhythm inside a card: `spacing-05` (16px). Between sections: `spacing-07` (32px) or `spacing-10` (64px).

### Layout & backgrounds

- **Full-bleed flat color** — no textures, no gradient backgrounds, no patterns. Carbon pages are fields of solid Layer color.
- **2x Grid** — columns double at breakpoints. Gutters are 32px desktop, 16px mobile.
- **Marketing pages** break out of the product grid with bigger hero units and occasional **thin-line pictograms**, but the color palette is the same gray-first + blue accent.
- **Hand-drawn illustrations: no.** Illustrations in Carbon are geometric, vector, on-grid. Any curve is an arc segment, not a free-form line.

### Motion

- **Purposeful and short.** Durations are in three tiers: `fast-01` (70ms, for taps), `moderate-01` (150ms, for hover/toggle), `slow-01` (400ms, for panel slides).
- **Easing tokens** — Carbon ships bespoke cubic-beziers per-role: `entrance-productive`, `exit-productive`, `standard`, and `entrance-expressive`. There is no generic `ease-in-out` anywhere.
- **No bounces, no elastic, no springs.** Never. Carbon motion is strictly decelerating or linear.
- Preferred transitions: fades, height/width reveals, panel slides from edge.

### Interaction states

- **Hover on interactive surface** = +1 layer of darkness (e.g. `--cds-background-hover`: subtle gray wash, ~12% black). Never opacity drops.
- **Active (pressed)** = +1 more layer of darkness. For primary buttons, active is `blue-80`.
- **Selected** = solid gray fill + left 3px blue bar (common in side nav / structured list).
- **Focus** = signature thick **2px inset blue outline**, color `--cds-focus` (`#0f62fe`), **no border-radius change**, **no offset**. On dark themes, outline is white.
- **Disabled** = 25% opacity on text and icon, 0% layer change. No strikethrough, no grayscale filter.

### Borders & shadows

- **Borders, not shadows.** Carbon almost never uses drop shadows in-product. Cards get a 1px `border-subtle` line instead.
- Shadows exist only on **overlay** surfaces (popovers, modals, overflow menus, toasts): a single soft `0 2px 6px rgba(0,0,0,0.2)`.
- No inner shadows. No "glass" or backdrop blur (marketing may occasionally use blur behind a solid panel).

### Transparency & blur

- Very rare. Overlays dim the background with solid `rgba(22,22,22,0.5)`. Product UI does not layer translucent panels.

### Shape & corners

- **Sharp** is the default. `border-radius: 0`.
- Small 2–4px radius on **AI-adjacent components** (AI Label pill, Chat bubble) — deliberate deviation that signals "this is a new, softer surface".
- **Capsule / pill radius** only on Tag + AI Label.

### Imagery

- **Cool and neutral.** Most IBM imagery is photographic with a **subtle cool cast** (blue in the shadows), never warm or amber.
- **Black & white** photography is common in editorial and people shots.
- **No grain filters, no vignettes.** Clean stock-photo fidelity.
- **Pictograms** are 2-color, thin-line, 2px stroke, built on a 32×32 grid. The library is 800+ strong (`@carbon/pictograms`).

### Cards / tiles

- A **Tile** in Carbon is: flat `layer-01` color, 1px `border-subtle-00` border, 0 radius, 16px padding, no shadow. A clickable Tile adds hover state (background darkens) and a small chevron icon bottom-right.

---

## ICONOGRAPHY

Carbon's icon system is exhaustive and opinionated. **Do not draw your own SVGs.** Use the official sets.

- **@carbon/icons** — the primary set. ~2,000 icons, 2-color, 1px stroke, designed on a 32×32 grid with sizes shipped at 16, 20, 24, and 32px. `https://github.com/carbon-design-system/carbon/tree/main/packages/icons`
- **@carbon/pictograms** — larger illustrative glyphs for marketing and empty states. 48×48 / 64×64 / 128×128. Line-art style, 2-color, no fills. `https://github.com/carbon-design-system/carbon/tree/main/packages/pictograms`
- **Usage sizes** — `16px` inside dense UI (buttons, menu items), `20px` in side nav, `24px` for prominent actions, `32px` for large tile anchors, `48px+` pictograms only in marketing / empty states.
- **Color** — icons inherit `currentColor`; use `--cds-icon-primary` (same as text) or `--cds-icon-secondary` (muted gray). On primary buttons, `--cds-icon-on-color` (white).
- **No emoji** anywhere in product UI. Marketing microsites may use them in social-proof modules only.
- **No unicode glyphs as icons.** Always a Carbon icon.
- **Logo** — IBM's 8-bar wordmark is the canonical brand mark. Available in `assets/ibm-logo.svg` (reference SVG — replace with a licensed copy from IBM for production use).

### In this project

- `assets/ibm-logo.svg` — IBM 8-bar mark (reference recreation).
- `assets/icons/*.svg` — a curated subset of ~40 common Carbon icons fetched from `@carbon/icons` at 32×32 source size. Naming matches the upstream package (`add`, `close`, `chevron--right`, `search`, `notification`, `user--avatar`, …).
- For anything not copied in, import from the CDN: `https://unpkg.com/@carbon/icons/svg/32/<name>.svg` (1:1 with the package source).

---

## Known substitutions / caveats

1. **Fonts.** Official IBM Plex is delivered from Google Fonts here instead of from IBM's CDN. The metrics are identical (Google Fonts is the canonical hosting for Plex), but if you need the web-font variants with the IBM-specific feature settings, grab the TTFs from `https://github.com/IBM/plex` and drop them in `fonts/`.
2. **No Figma / no codebase attached.** Foundations were rebuilt from public Carbon docs and the open-source Carbon GitHub. Tokens and components are accurate to the published spec but have not been diffed against a specific internal Carbon build.
3. **Icons** are linked by CDN (`@carbon/icons`) plus a small copied subset. If this project needs to run offline, copy more icons into `assets/icons/` or bundle `@carbon/icons` locally.
4. **Themes.** Four themes are defined (White, G10, G90, G100). The UI kit defaults to White; flip `data-carbon-theme` on the root to test the rest.
