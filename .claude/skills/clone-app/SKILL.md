---
name: clone-app
description: Clones any web application pixel-for-pixel from a URL. Orchestrates 9 siloed agents (recon, extraction, design spec, architecture, build, QA, fix, polish) through a bash loop with fresh context per stage. Use when cloning a site, replicating a web app, or when given a URL to clone.
disable-model-invocation: true
argument-hint: <url> <name> [--stack auto] [--output ./src/app/clone] [--timeout 8]
allowed-tools: Bash
---

# Clone App Skill

Multi-agent pipeline that produces pixel-perfect clones of web applications. Each of the 9 stages runs as a separate `claude -p` agent with fresh context — no agent sees another's work.

**Prerequisite:** `npm install -g agent-browser`

## Quick Start

Run the orchestrator with a URL and clone name:

```bash
.claude/skills/clone-app/scripts/clone.sh $ARGUMENTS
```

Resume after interruption:

```bash
.claude/skills/clone-app/scripts/clone.sh --resume clone-workspace/<name>
```

## Pipeline

```
URL → Recon → Extract → Design Spec → Architecture → Build
                                                       │
   ┌───────────────────────────────────────────────────┘
   ▼
 QA → Fix → QA → Fix → QA → Fix → QA → Fix → Polish
 └────── 4 mandatory cycles (fresh context each) ──┘
```

## What the Orchestrator Does

1. Creates workspace at `clone-workspace/{name}/`
2. Spawns 9+ fresh `claude -p` agents sequentially
3. Each agent receives its stage prompt + full reference file content (injected by orchestrator)
4. Agents use `agent-browser` via Bash for all browser work (screenshots, DOM eval, computed styles)
5. Progress tracked in `progress.md` and `status.json`

## Stages

| # | Stage | Reference | What It Does |
|---|-------|-----------|-------------|
| 1 | Recon | [01-recon.md](references/01-recon.md) | Screenshots at 3 viewports, hover states, sitemap |
| 2 | Extraction | [02-extraction.md](references/02-extraction.md) | Raw HTML, computed styles, CSS vars, fonts, assets |
| 3 | Design Spec | [03-design-spec.md](references/03-design-spec.md) | design-system.md with exact hex, fonts, spacing |
| 4 | Architecture | [04-architecture.md](references/04-architecture.md) | Component tree, file structure, tech stack detection |
| 5 | Build | [05-build.md](references/05-build.md) | Implement clone page-by-page with visual checks |
| 6 | QA | [06-qa.md](references/06-qa.md) | Grade every element A/B/C/F |
| 7 | Fix | (inline in stage prompt) | Fix F-grade then C-grade bugs |
| 8 | Loop | — | Stages 6-7 repeat 4 times total |
| 9 | Polish | [07-polish.md](references/07-polish.md) | Sub-pixel alignment, cursor audit, transitions |

## Anti-"Good Enough" Mechanisms

1. **Quantitative grading**: QA grades elements A/B/C/F — exit requires 0 F-grades, <3 C-grades
2. **Fresh eyes**: QA agent never saw the build — cannot rationalize defects
3. **Mandatory 4 cycles**: Orchestrator enforces this regardless of early grades
4. **Polish agent**: Hunts for "not wrong but could be better" — cursors, easing, sub-pixel alignment

## Options

| Flag | Default | Description |
|------|---------|-------------|
| `--stack` | `auto` | Tech stack: `auto`, `nextjs-tailwind`, `vite-css` |
| `--output` | `./src/app/{name}` | Output directory for built code |
| `--timeout` | `8` | Max hours before pipeline stops |
| `--cycles` | `4` | Number of QA-Fix cycles |

## Workspace

All artifacts live in `clone-workspace/{name}/`. See [references/stage-prompts.md](references/stage-prompts.md) for the full stage prompt templates.
