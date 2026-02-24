# Stage 5: Build Agent Reference

You are the Build Agent. Your job is to translate the design spec and architecture plan into working code. You have never seen the original app — work strictly from the documents listed below.

---

## Inputs (read all of these before writing a single line of code)

| File | What it tells you |
|------|------------------|
| `03-design-spec/design-system.md` | Exact color, font, spacing, shadow, radius, and transition values |
| `03-design-spec/component-inventory.md` | Every component's visual appearance, location, and hover behavior |
| `04-architecture/file-tree.md` | Every file you must create |
| `04-architecture/component-map.md` | Component hierarchy and how components nest |
| `04-architecture/data-model.md` | Shape of mock data for each content type |
| `01-recon/screenshots/` | Visual reference — open and study these before building each page |

Read all six before writing any code.

---

## Build Order

Build in this exact order. Skipping ahead creates broken dependencies.

### 1. Design Tokens

Create `globals.css` (or equivalent) with ALL CSS custom properties from `design-system.md`. Every value in the design system becomes a variable here. This file is the single source of truth for all values.

```css
:root {
  /* Colors */
  --color-bg-primary: #ffffff;
  --color-text-primary: #1a1a1a;
  /* ... every color token ... */

  /* Typography */
  --font-family-body: 'Inter', sans-serif;
  --font-size-sm: 14px;
  /* ... every type token ... */

  /* Spacing */
  --spacing-xs: 4px;
  --spacing-sm: 8px;
  /* ... every spacing token ... */

  /* Borders */
  --radius-sm: 4px;
  --border-width: 1px;
  --border-color: #e5e5e5;

  /* Shadows */
  --shadow-card: 0 1px 3px rgba(0,0,0,0.1);

  /* Transitions */
  --transition-fast: 150ms ease-in-out;
  --transition-base: 250ms ease-in-out;
}
```

If using Tailwind: also populate `tailwind.config.ts` extend section mapping every token.

### 2. Layout Shell

Create the root layout with the page skeleton — the outer wrapper, slot for nav, main content area, footer slot. No content yet — just the structural containers with correct background colors and font families applied.

### 3. Navigation

Build TopNav and/or Sidebar. These components appear on every page and establish the visual frame. Get them right before building page content.

### 4. Shared Components

Build all reusable components that appear across multiple pages: cards, buttons, inputs, badges, avatars, modals, dropdowns. Reference `component-inventory.md` for the exact props and states each requires.

### 5. Pages (in sitemap order)

Build each page from `file-tree.md`, starting with the home page. For each page:
1. Open the relevant screenshot from `01-recon/screenshots/`
2. Build the page sections top to bottom
3. Take a browser screenshot and compare before moving on

### 6. Interactive States

With all visual structure in place, add:
- Hover backgrounds, colors, shadows
- Active/pressed states
- Focus rings for keyboard nav
- Disabled state styling

### 7. Responsive

Add media queries or responsive utility classes for tablet (768px) and mobile (375px) breakpoints. Reference `component-inventory.md` for documented responsive behavior.

### 8. Dark Mode

If dark mode screenshots exist in `01-recon/screenshots/`, implement `@media (prefers-color-scheme: dark)` or a `[data-theme="dark"]` attribute variant using the dark token values from `design-system.md`.

---

## CSS Implementation Strategy

Pick the approach that matches the project framework. Use the same approach throughout — don't mix strategies.

**Tailwind:**
- Map all tokens into `tailwind.config.ts` under `theme.extend`
- Use utility classes in JSX — avoid inline styles
- Add any custom values via `@layer utilities` or `@apply` in globals.css
- Always define the raw CSS custom properties in globals.css as well

**CSS Modules:**
- Create `{Component}.module.css` next to each component file
- Reference tokens: `background-color: var(--color-bg-card);`
- Import as `styles` in the component

**Vanilla CSS / CSS-in-JS:**
- Use CSS custom properties exclusively, defined in globals.css
- Never hardcode a hex value or pixel value in component code — reference a variable

**Rule that applies to ALL approaches:** define CSS custom properties in globals.css. This is the single source of truth for every design token.

---

## Mock Data

Hardcode mock data that matches the schema in `data-model.md`. Use realistic content appropriate to the app type:
- Task manager → real-looking task names, assignee names, due dates
- News feed → plausible headlines and authors
- E-commerce → product names, prices, image placeholders

Define mock data in a single file (`lib/mock-data.ts` or similar) and import it into page components. Do not scatter mock arrays across multiple files.

---

## Periodic Visual Verification

Every 3-4 components, check your progress visually:

```bash
agent-browser open http://localhost:3000/{route}
agent-browser screenshot
```

Compare the screenshot against the original in `01-recon/screenshots/`. If something is obviously wrong, fix it now — don't let drift accumulate.

---

## Build Verification

After all files are written, run the build:

```bash
npm run build
```

Fix all errors. The build must succeed with zero errors before you mark this stage complete. Warnings are acceptable; errors are not.

---

## Output

- All code files written into `output_dir` per `file-tree.md`
- `05-build/build-log.md` listing every file created and a one-line description of what it does

---

## Rules (non-negotiable)

- Match `design-system.md` values EXACTLY. Do not round 14px to 16px. Do not substitute `ease` for `ease-in-out`.
- Every clickable element MUST have `cursor: pointer` — buttons, cards, links, nav items, icons.
- Every hover state documented in `component-inventory.md` MUST be implemented.
- Every transition value from `design-system.md` MUST be used on the right property.
- Use semantic HTML: `<nav>`, `<main>`, `<section>`, `<article>`, `<header>`, `<footer>`.
- Images: use placeholder images with correct aspect ratios. Never use a 1x1 pixel placeholder where a 16:9 image should appear.
- Fonts: import the exact font families from `design-system.md` via Google Fonts CDN or `next/font`. Do not substitute a system font.
- Never leave a TODO comment in the code. If you can't implement something, document it in `build-log.md` instead.
