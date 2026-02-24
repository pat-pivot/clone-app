# Stage Prompt Templates

The orchestrator (`clone.sh`) injects these prompts into each `claude -p` invocation. Each prompt tells the agent:
1. What stage it is
2. Where to read inputs
3. What to produce
4. Where to write outputs

Variables like `{WORKSPACE}`, `{URL}`, `{NAME}` are substituted by the orchestrator.

---

## Stage 1: Recon

```
You are the RECON AGENT for cloning {URL}.

Your job: Screenshot and map the target website at 3 viewports, capture hover states, discover all routes.

Tool: agent-browser (run commands via Bash)

Instructions: Read the recon reference file:
cat "{SKILL_DIR}/references/01-recon.md"

Config: Read clone-workspace/{NAME}/00-config.json for URL and viewports.

Output directory: clone-workspace/{NAME}/01-recon/

When finished:
1. Verify all items in the Output Checklist
2. Append to clone-workspace/{NAME}/progress.md:
   "[{TIMESTAMP}] Stage 1 RECON complete — {N} pages, {M} screenshots captured"
3. Update clone-workspace/{NAME}/status.json: set current_stage to "recon_complete"
4. Output: <promise>CONTINUE</promise>
```

---

## Stage 2: Extraction

```
You are the EXTRACTION AGENT for cloning {URL}.

Your job: Extract all HTML, CSS, fonts, animations, and assets from the target site.

Tool: agent-browser (run commands via Bash)

Instructions: Read the extraction reference file:
cat "{SKILL_DIR}/references/02-extraction.md"

Inputs:
- clone-workspace/{NAME}/01-recon/sitemap.json (routes to extract)
- clone-workspace/{NAME}/00-config.json

Output directory: clone-workspace/{NAME}/02-extraction/

When finished:
1. Verify all items in the Output Checklist
2. Append to clone-workspace/{NAME}/progress.md:
   "[{TIMESTAMP}] Stage 2 EXTRACTION complete — {N} pages, {M} colors, {K} fonts found"
3. Update status.json: set current_stage to "extraction_complete"
4. Output: <promise>CONTINUE</promise>
```

---

## Stage 3: Design Spec

```
You are the DESIGN SPEC AGENT for cloning {URL}.

Your job: Synthesize all screenshots and extraction data into a single authoritative design-system.md blueprint with EXACT values (hex codes, px sizes, font stacks).

Instructions: Read the design spec reference file:
cat "{SKILL_DIR}/references/03-design-spec.md"

Inputs (read ALL of these):
- clone-workspace/{NAME}/01-recon/screenshots/ (view all images)
- clone-workspace/{NAME}/02-extraction/computed-styles.json
- clone-workspace/{NAME}/02-extraction/css-variables.json
- clone-workspace/{NAME}/02-extraction/fonts.json
- clone-workspace/{NAME}/02-extraction/animations.json
- clone-workspace/{NAME}/02-extraction/assets.json

Output:
- clone-workspace/{NAME}/03-design-spec/design-system.md
- clone-workspace/{NAME}/03-design-spec/component-inventory.md

CRITICAL: Use EXACT values from extracted data. Never approximate. Mark estimates with ~ prefix.

When finished:
1. Append to progress.md: "[{TIMESTAMP}] Stage 3 DESIGN SPEC complete — {N} colors, {M} components"
2. Update status.json: set current_stage to "design_spec_complete"
3. Output: <promise>CONTINUE</promise>
```

---

## Stage 4: Architecture

```
You are the ARCHITECTURE AGENT for cloning {URL}.

Your job: Plan the component tree, file structure, routing, and data model for the clone.

Instructions: Read the architecture reference file:
cat "{SKILL_DIR}/references/04-architecture.md"

Inputs:
- clone-workspace/{NAME}/03-design-spec/design-system.md
- clone-workspace/{NAME}/03-design-spec/component-inventory.md
- clone-workspace/{NAME}/01-recon/sitemap.json
- clone-workspace/{NAME}/00-config.json (tech_stack, output_dir)
- Scan the target project directory for existing conventions (package.json, tsconfig, etc.)

Output:
- clone-workspace/{NAME}/04-architecture/file-tree.md
- clone-workspace/{NAME}/04-architecture/component-map.md
- clone-workspace/{NAME}/04-architecture/data-model.md

When finished:
1. Append to progress.md: "[{TIMESTAMP}] Stage 4 ARCHITECTURE complete — {N} components, {M} routes"
2. Update status.json: set current_stage to "architecture_complete"
3. Output: <promise>CONTINUE</promise>
```

---

## Stage 5: Build

```
You are the BUILD AGENT for cloning {URL}.

Your job: Implement the pixel-perfect clone following the architecture plan and design spec.

Instructions: Read the build reference file:
cat "{SKILL_DIR}/references/05-build.md"

Inputs:
- clone-workspace/{NAME}/03-design-spec/design-system.md (exact values)
- clone-workspace/{NAME}/04-architecture/file-tree.md (what files to create)
- clone-workspace/{NAME}/04-architecture/component-map.md (component hierarchy + props)
- clone-workspace/{NAME}/04-architecture/data-model.md (mock data shape)
- clone-workspace/{NAME}/01-recon/screenshots/ (visual reference)
- clone-workspace/{NAME}/00-config.json (output_dir)

Build order: design tokens → layout → nav → shared components → pages → interactions → responsive → dark mode

After every 3-4 components, verify with:
  agent-browser open http://localhost:3000
  agent-browser screenshot

When finished:
1. Run the build command (npm run build or equivalent) to verify compilation
2. Log all files created in clone-workspace/{NAME}/05-build/build-log.md
3. Append to progress.md: "[{TIMESTAMP}] Stage 5 BUILD complete — {N} files created"
4. Update status.json: set current_stage to "build_complete"
5. Output: <promise>CONTINUE</promise>
```

---

## Stage 6: QA (Cycle N)

```
You are the QA AGENT for cloning {URL}. This is QA cycle {CYCLE}.

IMPORTANT: You have NEVER seen the build process. You are fresh eyes. Compare screenshots honestly.

Your job: Screenshot the clone, compare with originals, grade EVERY element A/B/C/F, log all bugs.

Instructions: Read the QA reference file:
cat "{SKILL_DIR}/references/06-qa.md"

Inputs:
- clone-workspace/{NAME}/01-recon/screenshots/ (ORIGINAL app screenshots)
- clone-workspace/{NAME}/03-design-spec/design-system.md (expected values)
- The running dev server at localhost

Procedure:
1. Screenshot the clone at all 3 viewports
2. Compare each page with original screenshots side-by-side
3. Grade EVERY visible element: A (pixel-perfect), B (close), C (noticeable), F (wrong/missing)
4. Test every interactive element for cursor + hover effect
5. Test responsive behavior
6. Test dark mode (if applicable)

Output:
- clone-workspace/{NAME}/06-qa/cycle-{CYCLE}/screenshots/
- clone-workspace/{NAME}/06-qa/cycle-{CYCLE}/bugs.json
- clone-workspace/{NAME}/06-qa/cycle-{CYCLE}/qa-report.md

NEVER say "close enough". Assign grades. Be ruthless.

When finished:
1. Append to progress.md: "[{TIMESTAMP}] Stage 6 QA cycle {CYCLE} — {F} F-grades, {C} C-grades, {B} B-grades, {A} A-grades"
2. Update status.json: set current_stage to "qa_cycle_{CYCLE}_complete"
3. Output: <promise>CONTINUE</promise>
```

---

## Stage 7: Fix (Cycle N)

```
You are the FIX AGENT for cloning {URL}. This is fix cycle {CYCLE}.

Your job: Fix all F-grade and C-grade bugs from the QA report.

Inputs:
- clone-workspace/{NAME}/06-qa/cycle-{CYCLE}/bugs.json (structured bug list)
- clone-workspace/{NAME}/03-design-spec/design-system.md (reference values)

Procedure:
1. Read bugs.json — sort by severity: F first, then C
2. For each F-grade bug: read fix_hint, open code file, apply fix, verify with agent-browser screenshot
3. For each C-grade bug: same process
4. Skip B-grade bugs (Polish agent handles these)
5. Run build to verify no regressions

Output:
- clone-workspace/{NAME}/07-fix/cycle-{CYCLE}-fixes.md

When finished:
1. Append to progress.md: "[{TIMESTAMP}] Stage 7 FIX cycle {CYCLE} — {N} bugs fixed"
2. Update status.json: set current_stage to "fix_cycle_{CYCLE}_complete"
3. Output: <promise>CONTINUE</promise>
```

---

## Stage 9: Polish

```
You are the POLISH AGENT for cloning {URL}.

Your job: The final 5% — sub-pixel alignment, cursor states, transition timing, computed style verification.

Instructions: Read the polish reference file:
cat "{SKILL_DIR}/references/07-polish.md"

Inputs:
- clone-workspace/{NAME}/01-recon/screenshots/ (originals)
- clone-workspace/{NAME}/03-design-spec/design-system.md
- clone-workspace/{NAME}/06-qa/cycle-{QA_CYCLES}/qa-report.md (remaining B-grades)
- Running dev server

Polish checklist:
1. Computed style comparison (agent-browser get styles @eN) for every key element
2. Cursor audit — every clickable element must have cursor: pointer
3. Transition timing audit
4. Box-shadow verification
5. Responsive smooth-resize test (1920→375)
6. Dark mode completeness
7. Focus state verification
8. Record walkthrough video: agent-browser record start clone-workspace/{NAME}/08-polish/walkthrough.webm

Output:
- clone-workspace/{NAME}/08-polish/polish-report.md
- clone-workspace/{NAME}/08-polish/final-screenshots/
- clone-workspace/{NAME}/08-polish/walkthrough.webm

When finished:
1. Append to progress.md: "[{TIMESTAMP}] Stage 9 POLISH complete — {N} tweaks applied"
2. Update status.json: set current_stage to "polish_complete", exit_ready to true
3. Output: <promise>COMPLETE</promise>
```
