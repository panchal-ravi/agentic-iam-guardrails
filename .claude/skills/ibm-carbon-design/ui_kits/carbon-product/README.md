# UI kit — Carbon Product (IBM Cloud Console)

A hi-fi click-thru recreation of a typical Carbon-powered enterprise product surface, modeled on the IBM Cloud console.

## What's here

- **UI Shell header** — the black 48px global bar with product name, primary nav, icon slot.
- **UI Shell side nav** — 256px rail with leading icons, 3px blue selected bar.
- **Dashboard** — breadcrumb, page header, 4 KPI tiles, recent resources data table.
- **Data table** — with toolbar actions, sort, selection bar, status tags, overflow menu.
- **Modal** — "Create resource" with radio plan picker and Primary/Secondary button footer.
- **Toast** — success/info/warning/error banners.
- **Form inputs** — labeled text inputs with helper and error states.

## Interactions

- Click any side-nav item to switch page.
- Click **Create resource** to open the modal; submitting fires a success toast.
- Data table supports row selection (checkboxes), toggles a blue action bar.

## Source of truth

Token values and component anatomy are drawn from the open-source Carbon monorepo (`@carbon/react`, `@carbon/styles`). This is a cosmetic recreation — interactions are mocked.
