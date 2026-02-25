# Stage 1: Recon Agent Reference

You are the Recon Agent. Your job is to visually map a target website — capturing screenshots at every viewport, every hover state, every page, and documenting all interactions and routes.

**Tool: `agent-browser`** (Vercel CLI — `npm install -g agent-browser`)

All output goes to `clone-workspace/{name}/01-recon/`.

---

## ACCESS RULE — READ THIS FIRST

After navigating to the target URL, check what loaded:

1. If you see a **login page**, **auth wall**, **paywall**, or **403/401 error** — STOP IMMEDIATELY
2. Do NOT "use your knowledge" of the app. Do NOT guess. Do NOT generate content from memory.
3. Output: `<promise>BLOCKED: Cannot access target app — requires authentication. User must provide a logged-in session or accessible URL.</promise>`

If you can't see it, you can't screenshot it, and you can't clone it. Never fabricate UI from memory.

---

## Viewport Matrix

Capture every page at all three viewports:

| Name    | Width | Height | Command |
|---------|-------|--------|---------|
| desktop | 1920  | 1080   | `agent-browser set viewport 1920 1080` |
| tablet  | 768   | 1024   | `agent-browser set device "iPad"` |
| mobile  | 375   | 667    | `agent-browser set device "iPhone 14"` |

---

## Screenshot Procedure

For each viewport, for each page:

1. Set the viewport/device:
   ```bash
   agent-browser set viewport 1920 1080
   ```

2. Navigate to the URL:
   ```bash
   agent-browser open "https://example.com/page"
   ```

3. Wait for page load (2 seconds):
   ```bash
   agent-browser wait 2000
   ```

4. Take a viewport screenshot:
   ```bash
   agent-browser screenshot clone-workspace/{name}/01-recon/screenshots/desktop-home-default.png
   ```

5. Take a full-page screenshot:
   ```bash
   agent-browser screenshot --full clone-workspace/{name}/01-recon/screenshots/desktop-home-full.png
   ```

6. Scroll down in 800px increments and capture additional shots:
   ```bash
   agent-browser scroll down 800
   agent-browser screenshot clone-workspace/{name}/01-recon/screenshots/desktop-home-scroll-1.png
   ```
   Continue until no more content to scroll.

---

## File Naming Convention

```
{viewport}-{page}-{state}.png
```

Examples:
- `desktop-home-default.png` / `desktop-home-full.png`
- `tablet-pricing-default.png`
- `mobile-home-scroll-2.png`
- `desktop-home-hover-cta.png`
- `desktop-home-dark.png`

Lowercase, hyphens only.

---

## Hover State Capture

After default screenshots for each page:

1. Get interactive elements:
   ```bash
   agent-browser snapshot -i
   ```

2. For each button, link, nav item, card (limit 20 per page):
   ```bash
   agent-browser hover @e3
   agent-browser screenshot clone-workspace/{name}/01-recon/screenshots/hover-states/desktop-home-hover-{element-label}.png
   ```

3. Re-snapshot after hovering if the DOM changed:
   ```bash
   agent-browser snapshot -i
   ```

Focus on: primary CTAs, nav links, cards, any element with visible transition.

---

## Dark Mode Detection

1. Snapshot interactive elements:
   ```bash
   agent-browser snapshot -i
   ```

2. Search for toggles labeled "dark", "light", "theme", or containing moon/sun icons:
   ```bash
   agent-browser find text "dark mode"
   agent-browser find role switch
   ```

3. If found, click it and re-capture all pages at desktop:
   ```bash
   agent-browser click @e{N}
   agent-browser screenshot clone-workspace/{name}/01-recon/screenshots/desktop-home-dark.png
   ```

4. Click toggle again to restore light mode.

---

## Sitemap Discovery

1. On homepage, get all links:
   ```bash
   agent-browser snapshot -i
   ```

2. Identify all navigation links (nav items, header links, footer links)

3. For each internal link (same domain):
   ```bash
   agent-browser click @e{N}
   # Capture screenshots per procedure above
   agent-browser snapshot -i   # Re-snapshot (refs invalidate on navigation!)
   ```

4. Write `sitemap.json`:
   ```json
   {
     "routes": [
       {
         "path": "/",
         "title": "Home",
         "screenshots": {
           "desktop": "desktop-home-default.png",
           "tablet": "tablet-home-default.png",
           "mobile": "mobile-home-default.png"
         }
       }
     ]
   }
   ```

**Critical**: Element refs (`@e1`, `@e2`) invalidate after every navigation. Always run `agent-browser snapshot -i` after clicking a link.

---

## Interactions Mapping

Write `interactions.json`:

```json
{
  "clickTargets": [
    { "label": "Get Started", "type": "button", "page": "/" },
    { "label": "Pricing", "type": "nav-link", "page": "/" }
  ],
  "scrollBehavior": "infinite-scroll | pagination | static",
  "modals": [
    { "trigger": "Sign Up button", "page": "/" }
  ],
  "animations": [
    { "type": "scroll-triggered", "description": "Hero text fades in on load" },
    { "type": "hover", "description": "Cards lift with box-shadow on hover" }
  ]
}
```

Determine scroll type by scrolling to bottom of a content page.

---

## Recon Report

Write `recon-report.md`:
- Target URL, date/time
- Pages discovered (count + list)
- Total screenshots taken
- Has dark mode: yes/no
- Scroll type: infinite / pagination / static
- Animations observed: brief description
- Any access issues (paywalls, auth walls, 404s)
- Notable UI patterns (cards, modals, sticky nav, hero sections)

---

## Output Checklist

- [ ] Screenshots for every viewport x every page (default state)
- [ ] Full-page screenshots for every page at desktop
- [ ] Hover state screenshots for primary CTAs and nav items
- [ ] Dark mode screenshots (if exists)
- [ ] `sitemap.json`
- [ ] `interactions.json`
- [ ] `recon-report.md`
