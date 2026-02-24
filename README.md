# Clone App — Claude Code Skill

Multi-agent pipeline that produces pixel-perfect clones of web applications from just a URL.

## What It Does

Give it a URL. It clones the site through 9 siloed agents, each with fresh context:

```
URL → Recon → Extract → Design Spec → Architecture → Build
                                                       │
    ┌──────────────────────────────────────────────────┘
    ▼
  QA → Fix → QA → Fix → QA → Fix → QA → Fix → Polish
  └────── 4 mandatory cycles (fresh eyes each) ───────┘
```

## Prerequisites

- [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code)
- [agent-browser](https://github.com/AugmentHCI/agent-browser) (`npm install -g agent-browser`)
- Node.js 18+

## Quick Start

### 1. Install the skill

Copy the `.claude/skills/clone-app/` directory into your project:

```bash
mkdir -p .claude/skills
cp -r clone-app-repo/.claude/skills/clone-app .claude/skills/
```

### 2. Run it

```bash
# From your project root
.claude/skills/clone-app/scripts/clone.sh "https://example.com" "my-clone"

# Or with options
.claude/skills/clone-app/scripts/clone.sh "https://example.com" "my-clone" \
  --stack nextjs-tailwind \
  --output ./src/app/my-clone \
  --timeout 8

# Resume after interruption
.claude/skills/clone-app/scripts/clone.sh --resume clone-workspace/my-clone
```

### 3. Or invoke from Claude Code

```
/clone https://example.com --name my-clone
```

## How It Works

Each stage is a fresh `claude -p` invocation — no agent sees another's context. This prevents the "good enough" problem where agents rationalize away defects they introduced.

| Stage | Agent | What It Does |
|-------|-------|-------------|
| 1 | Recon | Screenshots at 3 viewports, sitemap discovery, hover states |
| 2 | Extraction | Raw HTML, computed styles, CSS variables, fonts, animations |
| 3 | Design Spec | Synthesizes exact design-system.md (hex codes, px values, font stacks) |
| 4 | Architecture | Component tree, file structure, routing, data model |
| 5 | Build | Implements the clone page-by-page |
| 6 | QA | Grades EVERY element A/B/C/F — fresh eyes, never saw the build |
| 7 | Fix | Fixes F-grade and C-grade bugs from QA report |
| 8 | Loop | Stages 6-7 repeat 4x total (mandatory) |
| 9 | Polish | Sub-pixel alignment, cursor states, transition timing, walkthrough |

## Anti-"Good Enough" Mechanisms

1. **Quantitative grading** — QA grades elements A/B/C/F, not pass/fail
2. **Fresh eyes** — QA agent never saw the build process
3. **Mandatory 4 cycles** — Even if cycle 1 looks clean, 3 more always run
4. **Polish agent** — Hunts the last 5%: cursors, easing, sub-pixel alignment

## File Structure

```
.claude/skills/clone-app/
├── SKILL.md                    # Skill overview (Claude reads this)
├── references/
│   ├── 01-recon.md             # Screenshot + sitemap methodology
│   ├── 02-extraction.md        # HTML/CSS/JS extraction commands
│   ├── 03-design-spec.md       # Design system template
│   ├── 04-architecture.md      # Component planning patterns
│   ├── 05-build.md             # Implementation patterns
│   ├── 06-qa.md                # QA grading rubric + Fix agent reference
│   ├── 07-polish.md            # Sub-pixel polish methodology
│   └── stage-prompts.md        # All 9 agent prompt templates
└── scripts/
    └── clone.sh                # Bash orchestrator
```

## License

MIT
