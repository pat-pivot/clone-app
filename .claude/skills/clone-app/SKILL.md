---
name: clone-app
description: Clone any web application pixel-for-pixel from a URL. Orchestrates 9 siloed agents (recon, extraction, design spec, architecture, build, QA, fix, polish) through a bash loop with fresh context per stage. Use when the user says "clone this app", "replicate this site", provides a URL to clone, or invokes /clone.
---

# Clone App Skill

Multi-agent pipeline that produces pixel-perfect clones of web applications. Each stage runs as a separate agent with fresh context to prevent the "good enough" problem.

## Invocation

```
/clone <url> --name <clone-name> [--stack auto|nextjs-tailwind|vite-css] [--tracking codeq|markdown] [--output ./src/app/clone]
```

Or run the orchestrator directly:

```bash
.claude/skills/clone-app/scripts/clone.sh "<url>" "<clone-name>" [options]
```

## Pipeline Overview

```
URL ─→ Recon ─→ Extract ─→ Design Spec ─→ Architecture ─→ Build
                                                            │
    ┌───────────────────────────────────────────────────────┘
    ▼
  QA ──→ Fix ──→ QA ──→ Fix ──→ QA ──→ Fix ──→ QA ──→ Fix ──→ Polish
  └─────── 4 mandatory cycles (fresh context each) ────────┘
```

9 stages, each a fresh `claude -p` invocation. No agent sees another's context.

## Config (00-config.json)

The orchestrator creates this at pipeline start:

```json
{
  "target_url": "https://example.com",
  "clone_name": "my-clone",
  "output_dir": "./src/app/clone",
  "tech_stack": "auto",
  "tracking": "markdown",
  "viewports": ["1920x1080", "768x1024", "375x667"],
  "pages": ["auto"],
  "qa_cycles": 4,
  "created_at": "2026-02-24T10:00:00Z"
}
```

- `tech_stack: "auto"` — Stage 4 detects from `package.json` and project structure
- `tracking: "codeq"` — logs to Code Queue; `"markdown"` — logs to workspace only
- `pages: ["auto"]` — discover all routes; or specify `["/", "/about", "/pricing"]`

## Workspace Structure

All artifacts live in `clone-workspace/{clone-name}/`. See [workspace layout below](#workspace-layout).

## Stage Summary

### Stage 1: Recon Agent
Screenshots at 3 viewports (desktop/tablet/mobile), full-page scrolls, hover states, dark mode. Maps sitemap via navigation. See [references/01-recon.md](references/01-recon.md).

### Stage 2: Extraction Agent
Raw HTML via `agent-browser eval`, computed styles via `agent-browser get styles` and `eval`. CSS variables, font-faces, keyframes, asset inventory. See [references/02-extraction.md](references/02-extraction.md).

### Stage 3: Design Spec Agent
Reads screenshots + extraction output. Synthesizes `design-system.md` with exact hex codes, font stacks, spacing values, shadows, border radii, animations, cursor states. The blueprint for building. See [references/03-design-spec.md](references/03-design-spec.md).

### Stage 4: Architecture Agent
Reads design spec + sitemap. Detects target project's tech stack. Plans component tree, routing, file structure, data model. See [references/04-architecture.md](references/04-architecture.md).

### Stage 5: Build Agent
Implements the clone page-by-page using the architecture plan and design spec. Periodic visual checks via agent-browser. Runs build to verify compilation. May use multiple Ralph-loop iterations. See [references/05-build.md](references/05-build.md).

### Stage 6: QA Agent (fresh eyes — never saw build)
Screenshots clone at matching viewports. Grades EVERY element A/B/C/F. Checks cursors, hovers, animations, responsive, dark mode. Outputs structured `bugs.json`. See [references/06-qa.md](references/06-qa.md).

### Stage 7: Fix Agent
Reads `bugs.json` sorted by severity (F first). Fixes each bug, verifies with screenshot. Marks each fixed.

### Stage 8: QA-Fix Loop
Stages 6-7 repeat 3 more times (4 total cycles). Mandatory — the orchestrator enforces this even if early cycles look clean.

### Stage 9: Polish Agent
Element-by-element computed style comparison. Verifies every cursor, transition, box-shadow. Responsive smooth-resize test. Dark mode verification. Records GIF walkthrough. See [references/07-polish.md](references/07-polish.md).

## Anti-"Good Enough" Mechanisms

1. **Quantitative grading**: QA grades elements A/B/C/F — exit requires 0 F-grades, <3 C-grades
2. **Fresh eyes**: QA agent never saw the build — cannot rationalize defects
3. **Mandatory 4 cycles**: Orchestrator enforces this regardless of early grades
4. **Polish agent**: Hunts for "not wrong but could be better" — cursors, easing, sub-pixel alignment

## Tool Selection

**Primary tool: `agent-browser`** (universal — `npm install -g agent-browser`)

Every team member can use this skill with just agent-browser installed. No MCP servers required.

| Stage | Primary | Key Commands |
|-------|---------|-------------|
| 1 Recon | agent-browser | `screenshot --full`, `set device`, `hover`, `snapshot -i` |
| 2 Extract | agent-browser | `eval "..."` for HTML/CSS/JS, `get styles @e1` |
| 3 Design | Read (images + files) | Pure analysis, no browser |
| 4 Arch | Read + Glob/Grep | File planning, tech stack detection |
| 5 Build | Write/Edit + agent-browser | Code writing + periodic `screenshot` checks |
| 6 QA | agent-browser | `screenshot`, `get styles @e1`, `hover` for interaction audit |
| 7 Fix | Write/Edit + agent-browser | Targeted fixes + `screenshot` verification |
| 9 Polish | agent-browser | `get styles`, `set viewport` resize test, `record` walkthrough |

## Workspace Layout

```
clone-workspace/{clone-name}/
├── 00-config.json
├── 01-recon/
│   ├── screenshots/          # desktop, tablet, mobile, scrolls, hover-states/
│   ├── sitemap.json          # {routes: [{path, title, screenshot}]}
│   ├── interactions.json     # {clickTargets, scrollBehavior, modals}
│   └── recon-report.md
├── 02-extraction/
│   ├── raw-html/             # One file per route
│   ├── computed-styles.json  # Key element styles
│   ├── css-variables.json    # CSS custom properties
│   ├── fonts.json            # @font-face + external URLs
│   ├── animations.json       # @keyframes + transitions
│   ├── assets.json           # Image and SVG inventory
│   └── extraction-report.md
├── 03-design-spec/
│   ├── design-system.md      # THE core blueprint
│   └── component-inventory.md
├── 04-architecture/
│   ├── file-tree.md
│   ├── component-map.md
│   └── data-model.md
├── 05-build/
│   └── build-log.md
├── 06-qa/
│   └── cycle-{N}/           # screenshots/, bugs.json, qa-report.md
├── 07-fix/
│   └── cycle-{N}-fixes.md
├── 08-polish/
│   ├── polish-report.md
│   └── final-screenshots/
├── progress.md               # Append-only log
└── status.json               # {current_stage, completed_stages}
```

## Tracking Modes

**Code Queue mode** (`tracking: "codeq"`):
- Creates `[CLONE] Clone {app_name}` parent issue at start
- Each stage appends timestamped comment to the issue
- QA bugs logged as sub-issues
- Uses Code Queue skill API (see `.claude/skills/code-queue/SKILL.md`)

**Markdown mode** (`tracking: "markdown"`):
- All progress in `clone-workspace/{name}/progress.md`
- Machine state in `status.json`
- No external API calls — fully self-contained

## Running the Orchestrator

```bash
# Full run
.claude/skills/clone-app/scripts/clone.sh "https://example.com" "my-clone"

# With options
.claude/skills/clone-app/scripts/clone.sh "https://example.com" "my-clone" \
  --stack nextjs-tailwind \
  --tracking codeq \
  --output ./src/app/my-clone \
  --timeout 8

# Resume after interruption
.claude/skills/clone-app/scripts/clone.sh --resume clone-workspace/my-clone
```

## Stage Prompt Templates

Each stage gets a tailored prompt injected by the orchestrator. See [references/stage-prompts.md](references/stage-prompts.md) for all 9 templates.
