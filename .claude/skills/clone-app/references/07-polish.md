# Stage 9: Polish Agent Reference

You are the Polish Agent. You run after all 4 QA-Fix cycles are complete and the orchestrator has declared the clone PASS. Your job is to find the last 5% — things that aren't technically wrong but would make a designer notice the difference. You are not fixing bugs; you are achieving the threshold where a designer cannot tell which one is the clone.

---

## Inputs

| File | What it gives you |
|------|------------------|
| `01-recon/screenshots/` | Original app screenshots — ground truth |
| `03-design-spec/design-system.md` | Exact design token values |
| `06-qa/cycle-4/qa-report.md` | Latest QA report — shows remaining B-grade issues |
| Running dev server at `localhost:3000` | The clone in its current state |

Read all four before starting. The QA report tells you exactly which B-grade issues remain. Start with those, then run the full polish checklist below.

---

## Polish Checklist

Work through each item in order. Document every change you make.

### 1. Computed Style Comparison

For every key element on every page, compare computed CSS properties against `design-system.md` numerically — not visually. Open the page in the browser, inspect each element, and check:

```
agent-browser open http://localhost:3000/{route}
agent-browser get styles @e{N}   # get computed styles for element N
```

For each element, verify character-by-character:
- `font-family` — exact typeface match, including fallback stack
- `font-weight` — exact number (400, 500, 600, 700 — not approximate)
- `font-size` — exact pixel value
- `letter-spacing` — exact value (0, 0.025em, -0.01em, etc.)
- `line-height` — exact value (1.5, 1.4, 24px, etc.)
- `color` — exact hex, not "similar blue"
- `background-color` — exact hex

If any computed value does not match `design-system.md`, fix it.

### 2. Cursor Audit

Navigate through EVERY page. Hover over EVERY interactive element. This is the most commonly missed category — be exhaustive.

| Element Type | Expected Cursor | Must Also Have |
|-------------|----------------|----------------|
| Buttons (primary, secondary, ghost) | `cursor: pointer` | Visual hover state |
| Links (nav, body text, footer) | `cursor: pointer` | Color or underline change on hover |
| Clickable cards | `cursor: pointer` | Shadow or background change on hover |
| Icon buttons | `cursor: pointer` | Opacity or color change on hover |
| Form inputs | `cursor: text` | Focus border/ring |
| Textareas | `cursor: text` | Focus border/ring |
| Select dropdowns | `cursor: pointer` | — |
| Disabled buttons | `cursor: not-allowed` | Reduced opacity |
| Disabled inputs | `cursor: not-allowed` | Reduced opacity |
| Drag handles (if present) | `cursor: grab` | `cursor: grabbing` while dragging |
| Non-interactive text/images | `cursor: default` | — |

Fix every element that has the wrong cursor.

### 3. Transition Timing Audit

For each animated element, verify the exact transition values from `design-system.md`:

- Duration: `150ms` is not the same as `200ms` — check and match exactly
- Easing: `ease-in-out` is not the same as `ease` — check and match exactly
- Property: `background-color` is not the same as `all` — only the specific property should transition
- Do not use `transition: all` unless the original explicitly uses it — `all` causes unintended transitions

For each element, use browser devtools via agent-browser to confirm the computed transition value, then compare to `design-system.md`.

### 4. Box Shadow Verification

For every element with a shadow, compare the full shadow value character-by-character against `design-system.md`:

```
0 1px 3px rgba(0,0,0,0.1)          ← check offset-x, offset-y, blur, spread, color, opacity
0 4px 6px -1px rgba(0,0,0,0.1)     ← note the negative spread
inset 0 1px 0 rgba(255,255,255,0.1) ← check for inset shadows
```

Common mistakes: wrong blur radius, wrong opacity value, missing negative spread, missing inset shadow layered on top of outer shadow.

### 5. Responsive Smooth-Resize Test

Start the browser at 1920px width and slowly resize down to 375px. Check:

- No layout breaks at any intermediate width (e.g., 900px, 700px, 500px)
- No horizontal scroll bar appears at any width
- Text does not overflow its container at any width
- Grid columns collapse at the right breakpoints
- Navigation collapses to mobile menu at the right breakpoint
- Images do not break out of their containers

If you find a layout break at a non-standard width (between breakpoints), add a fix for it.

### 6. Dark Mode Completeness (if applicable)

If dark mode is present in the original, verify every token has a correct dark variant:

- Every background color token has a dark-mode counterpart
- Every text color token has a dark-mode counterpart
- No white text on white background
- No black text on black background
- Shadows are visible on dark backgrounds — may need lighter/more-spread values
- Images with transparent backgrounds work on both light and dark backgrounds
- Borders are still visible on dark backgrounds (may need lighter border color)

Toggle dark mode on and walk through every page checking these items.

### 7. Focus States

Tab through the entire application using the keyboard:

- Every button, link, input, and select must have a visible focus ring or outline
- The focus indicator must have sufficient contrast to be visible
- Focus order must be logical: left-to-right, top-to-bottom, nav before main content
- Skip links (if present in original) must work
- Modal/dialog focus trapping — if modals exist, tabbing must not escape to background content

### 8. Fix Remaining B-Grade Bugs

Return to `06-qa/cycle-4/qa-report.md`. Find all B-grade bugs that were deferred. Fix each one using the same procedure as the Fix Agent:
1. Read the bug description
2. Apply a minimal targeted fix
3. Verify with a screenshot

---

## Final Deliverables

### Polish Report

Write `08-polish/polish-report.md`:

```markdown
# Polish Report
Completed: {timestamp}

## B-Grade Bugs Fixed
- BUG-008: ContentCard border-radius corrected from 8px to 6px
- BUG-011: Footer link letter-spacing set to 0.025em per design-system.md

## Additional Issues Found and Fixed
- SidebarNavLink missing cursor: pointer (missed by QA)
- HeroSection h1 font-weight was 700, should be 800
- Primary button transition was `all 200ms` — corrected to `background-color 150ms ease-in-out`

## Computed Style Differences Resolved
| Element | Property | Was | Fixed To |
|---------|----------|-----|----------|
| Body text | letter-spacing | 0 | -0.01em |
| Card | box-shadow | 0 2px 4px rgba(0,0,0,0.1) | 0 1px 3px rgba(0,0,0,0.12) |

## Items Verified Clean (no changes needed)
- All cursor states verified
- Dark mode colors verified
- Responsive breakpoints verified
- Focus states verified

## Final Assessment
After polish, the clone matches the original at a level where a designer reviewing both
side-by-side would not reliably identify which is the clone.
```

### Final Screenshots

Take final screenshots at all three viewports (desktop 1440px, tablet 768px, mobile 375px) for every page. Save to `08-polish/final-screenshots/`:

```
08-polish/final-screenshots/desktop-home.png
08-polish/final-screenshots/desktop-settings.png
08-polish/final-screenshots/tablet-home.png
08-polish/final-screenshots/mobile-home.png
# etc.
```

### Animated Walkthrough

Create an animated walkthrough showing the final clone in action:

```bash
agent-browser record start clone-workspace/{name}/08-polish/walkthrough.webm
# navigate through key pages, hover over interactive elements
agent-browser record stop
```

The walkthrough should show:
1. Page load of the home page
2. Navigation between 2-3 key pages
3. Hovering over key interactive elements (cards, buttons, nav items)
4. One responsive resize if the tool supports it

Save to `08-polish/walkthrough.gif` or `08-polish/walkthrough.webm`.

---

## Rules

- This is the final pass. Every remaining imperfection matters — there is no stage after this.
- Compare computed styles numerically against `design-system.md`. Do not trust visual impression alone for font-weight, letter-spacing, or exact hex colors.
- Fix every B-grade bug from the last QA cycle. These are no longer "minor" — they are the known remaining issues.
- If you find a new issue during this pass, fix it AND document it in the polish report under "Additional Issues Found and Fixed."
- Do not introduce new complexity. Fix targeted properties; do not refactor components.
- The goal is: a designer reviewing both apps side-by-side cannot reliably identify which one is the clone.
