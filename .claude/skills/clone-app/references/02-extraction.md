# Stage 2: Extraction Agent Reference

You are the Extraction Agent. Your job is to pull all source code, styles, and design tokens from the target site so the Build Agent has everything needed for a pixel-accurate clone.

**Tool: `agent-browser`** (Vercel CLI — `npm install -g agent-browser`)

Read `clone-workspace/{name}/01-recon/sitemap.json` first to know which routes to extract.

All output goes to `clone-workspace/{name}/02-extraction/`.

---

## Step 1: Raw HTML Extraction

For each route in `sitemap.json`:

1. Navigate to the page:
   ```bash
   agent-browser open "https://example.com{path}"
   agent-browser wait 2000
   ```

2. Extract the full rendered DOM:
   ```bash
   agent-browser eval "document.documentElement.outerHTML"
   ```

3. Save the output to `02-extraction/raw-html/{page-name}.html`
   - `/` → `home.html`, `/pricing` → `pricing.html`, `/about/team` → `about-team.html`

4. If a page fails to load (auth wall, timeout), note it in extraction-report.md and skip.

---

## Step 2: Computed Styles Extraction

On the homepage, extract computed styles from key elements:

```bash
agent-browser eval "JSON.stringify(Array.from(document.querySelectorAll('h1, h2, h3, p, a, button, nav, header, footer, main, [class*=\"card\"], [class*=\"container\"]')).slice(0, 50).map(el => ({tag: el.tagName, classes: el.className, text: el.textContent?.slice(0, 50), styles: {color: getComputedStyle(el).color, backgroundColor: getComputedStyle(el).backgroundColor, fontSize: getComputedStyle(el).fontSize, fontFamily: getComputedStyle(el).fontFamily, fontWeight: getComputedStyle(el).fontWeight, lineHeight: getComputedStyle(el).lineHeight, letterSpacing: getComputedStyle(el).letterSpacing, padding: getComputedStyle(el).padding, margin: getComputedStyle(el).margin, borderRadius: getComputedStyle(el).borderRadius, boxShadow: getComputedStyle(el).boxShadow, cursor: getComputedStyle(el).cursor, transition: getComputedStyle(el).transition, display: getComputedStyle(el).display, gap: getComputedStyle(el).gap, gridTemplateColumns: getComputedStyle(el).gridTemplateColumns}})))"
```

Save to `02-extraction/computed-styles.json`.

**Alternative (per-element)**: For specific elements, use the `get styles` command:
```bash
agent-browser snapshot -i
agent-browser get styles @e1
agent-browser get styles @e5
```

This returns the computed CSS for individual elements — useful for targeted extraction.

---

## Step 3: CSS Variables Extraction

Extract all CSS custom properties from `:root`:

```bash
agent-browser eval "JSON.stringify((() => { const vars = {}; for (const sheet of document.styleSheets) { try { for (const rule of sheet.cssRules) { if (rule.selectorText === ':root' || (rule.selectorText && rule.selectorText.includes(':root'))) { for (const prop of rule.style) { if (prop.startsWith('--')) vars[prop] = rule.style.getPropertyValue(prop).trim(); } } } } catch(e) {} } return vars; })())"
```

Save to `02-extraction/css-variables.json`.

If empty (Tailwind/utility-class site), note in extraction report — rely on computed styles instead.

---

## Step 4: Font-Face Extraction

Extract `@font-face` declarations:

```bash
agent-browser eval "JSON.stringify((() => { const fonts = []; for (const sheet of document.styleSheets) { try { for (const rule of sheet.cssRules) { if (rule.type === CSSRule.FONT_FACE_RULE) { fonts.push({family: rule.style.getPropertyValue('font-family'), src: rule.style.getPropertyValue('src'), weight: rule.style.getPropertyValue('font-weight'), style: rule.style.getPropertyValue('font-style')}); } } } catch(e) {} } return fonts; })())"
```

Also check for external font links:

```bash
agent-browser eval "JSON.stringify(Array.from(document.querySelectorAll('link[href*=\"fonts.googleapis\"], link[href*=\"use.typekit\"], link[href*=\"fonts.cdnfonts\"]')).map(el => el.href))"
```

Save both to `02-extraction/fonts.json` (combine under `{declarations: [...], externalUrls: [...]}`).

---

## Step 5: Animation Extraction

Extract `@keyframes` and transition rules:

```bash
agent-browser eval "JSON.stringify((() => { const anims = []; for (const sheet of document.styleSheets) { try { for (const rule of sheet.cssRules) { if (rule.type === CSSRule.KEYFRAMES_RULE) { anims.push({type: 'keyframes', name: rule.name, css: rule.cssText}); } if (rule.style && rule.style.transition && rule.style.transition !== 'none 0s ease 0s') { anims.push({type: 'transition', selector: rule.selectorText, transition: rule.style.transition}); } } } catch(e) {} } return anims; })())"
```

Save to `02-extraction/animations.json`.

---

## Step 6: Asset Inventory

Catalog all images and SVGs:

```bash
agent-browser eval "JSON.stringify({images: Array.from(document.querySelectorAll('img')).map(el => ({src: el.src, alt: el.alt, width: el.naturalWidth, height: el.naturalHeight})), svgs: Array.from(document.querySelectorAll('svg')).slice(0, 20).map(el => ({id: el.id, classes: el.className?.baseVal, viewBox: el.getAttribute('viewBox'), html: el.outerHTML.slice(0, 500)}))})"
```

Save to `02-extraction/assets.json`. Tells the Build Agent which images to stub with placeholders vs. recreate as SVG.

---

## Step 7: Full Stylesheet Dump (optional, large sites)

For thorough extraction, dump all CSS rules:

```bash
agent-browser eval "JSON.stringify((() => { const rules = []; for (const sheet of document.styleSheets) { try { for (const rule of sheet.cssRules) { rules.push(rule.cssText); } } catch(e) { rules.push('/* cross-origin: ' + sheet.href + ' */'); } } return rules; })())"
```

Save to `02-extraction/all-styles.json`. This is large but gives the Design Spec Agent complete CSS to work with.

---

## Output Files

```
02-extraction/
├── raw-html/              # One .html per route
├── computed-styles.json   # Up to 50 elements with full style map
├── css-variables.json     # CSS custom properties (may be empty)
├── fonts.json             # Font-face declarations + external URLs
├── animations.json        # @keyframes + transitions
├── assets.json            # Image and SVG inventory
├── all-styles.json        # Full CSS dump (optional)
└── extraction-report.md
```

---

## Extraction Report

Write `extraction-report.md` summarizing:
- Pages extracted (count + list)
- Pages skipped and reason
- Unique colors found (from computed styles)
- Font families found (list)
- CSS variable count
- Animation count (@keyframes)
- External font URLs
- Image count, SVG count
- Detected CSS framework (Tailwind, Bootstrap, custom, unknown — infer from class patterns)
- Any extraction errors or gaps

---

## Output Checklist

- [ ] `raw-html/` with one `.html` per route
- [ ] `computed-styles.json` (up to 50 elements)
- [ ] `css-variables.json` (may be empty for Tailwind sites)
- [ ] `fonts.json`
- [ ] `animations.json`
- [ ] `assets.json`
- [ ] `extraction-report.md`
