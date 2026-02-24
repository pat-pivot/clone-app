#!/usr/bin/env bash
# Clone App Orchestrator — Ralph-loop derivative
# Usage: ./clone.sh "<url>" "<name>" [--stack auto] [--tracking markdown] [--output ./clone] [--timeout 8]
# Resume: ./clone.sh --resume clone-workspace/<name>

set -euo pipefail

SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
CODEQ_API="https://clearhaven-os.vercel.app/api/queue"
GITHUB_REPO_ID="ebbeb4ae-41d2-4b40-ab1a-527bf307398f"
CLAUDE_ASSIGNEE="d4e5f6a7-b8c9-0123-defa-234567890123"

# --- Argument parsing ---
URL=""
NAME=""
STACK="auto"
TRACKING="markdown"
OUTPUT_DIR=""
TIMEOUT_HOURS=8
RESUME=""
QA_CYCLES=4

while [[ $# -gt 0 ]]; do
  case "$1" in
    --resume) RESUME="$2"; shift 2 ;;
    --stack) STACK="$2"; shift 2 ;;
    --tracking) TRACKING="$2"; shift 2 ;;
    --output) OUTPUT_DIR="$2"; shift 2 ;;
    --timeout) TIMEOUT_HOURS="$2"; shift 2 ;;
    --cycles) QA_CYCLES="$2"; shift 2 ;;
    *)
      if [[ -z "$URL" ]]; then URL="$1"
      elif [[ -z "$NAME" ]]; then NAME="$1"
      fi
      shift ;;
  esac
done

# --- Resume mode ---
if [[ -n "$RESUME" ]]; then
  WORKSPACE="$RESUME"
  NAME=$(basename "$WORKSPACE")
  CONFIG="$WORKSPACE/00-config.json"
  URL=$(python3 -c "import json; print(json.load(open('$CONFIG'))['target_url'])")
  TRACKING=$(python3 -c "import json; print(json.load(open('$CONFIG')).get('tracking','markdown'))")
  echo "Resuming clone: $NAME from $WORKSPACE"
else
  if [[ -z "$URL" || -z "$NAME" ]]; then
    echo "Usage: clone.sh <url> <name> [options]"
    echo "       clone.sh --resume clone-workspace/<name>"
    exit 1
  fi
  WORKSPACE="clone-workspace/$NAME"
  [[ -z "$OUTPUT_DIR" ]] && OUTPUT_DIR="./src/app/$NAME"
fi

# --- Safety limits ---
START_TIME=$(date +%s)
MAX_SECONDS=$((TIMEOUT_HOURS * 3600))

check_timeout() {
  local elapsed=$(( $(date +%s) - START_TIME ))
  if (( elapsed > MAX_SECONDS )); then
    echo "TIMEOUT: ${TIMEOUT_HOURS}h limit reached. Stopping."
    echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] TIMEOUT after ${TIMEOUT_HOURS}h" >> "$WORKSPACE/progress.md"
    codeq_comment "## TIMEOUT\n\nPipeline stopped after ${TIMEOUT_HOURS}h limit. Resume with:\n\`\`\`\nclone.sh --resume $WORKSPACE\n\`\`\`"
    exit 1
  fi
}

# --- Code Queue helpers (only active when tracking=codeq) ---
PARENT_ID=""
PARENT_IDENTIFIER=""

codeq_create_parent() {
  [[ "$TRACKING" != "codeq" ]] && return 0

  local response
  response=$(curl -s -X POST "$CODEQ_API/items" \
    -H "Content-Type: application/json" \
    -d "$(python3 -c "
import json
print(json.dumps({
  'title': '[CLONE] Clone $NAME from $URL',
  'description': '## Clone Pipeline — clone-app-pat-pro\n\n**Target**: $URL\n**Name**: $NAME\n**Stack**: $STACK\n**Started**: $TIMESTAMP\n\n## Stages\n1. Recon — Screenshots + sitemap\n2. Extraction — HTML/CSS/JS\n3. Design Spec — design-system.md\n4. Architecture — Component tree\n5. Build — Implementation\n6-7. QA-Fix Loop (${QA_CYCLES} cycles)\n9. Polish — Sub-pixel perfection\n\n## Enhanced Tooling\n- Chrome Pool CDP (Mac Mini)\n- Evidence-based grading\n- Anti-hallucination rules',
  'priority': 'medium',
  'status': 'in_progress',
  'github_repo_id': '$GITHUB_REPO_ID',
  'assignee_id': '$CLAUDE_ASSIGNEE'
}))
")" 2>/dev/null) || true

  if [[ -n "$response" ]]; then
    PARENT_ID=$(echo "$response" | python3 -c "import sys,json; print(json.load(sys.stdin).get('item',{}).get('id',''))" 2>/dev/null) || true
    PARENT_IDENTIFIER=$(echo "$response" | python3 -c "import sys,json; print(json.load(sys.stdin).get('item',{}).get('identifier',''))" 2>/dev/null) || true

    if [[ -n "$PARENT_ID" ]]; then
      # Save to config
      python3 -c "
import json
with open('$WORKSPACE/00-config.json','r+') as f:
  c = json.load(f)
  c['codeq_parent_id'] = '$PARENT_ID'
  c['codeq_identifier'] = '$PARENT_IDENTIFIER'
  f.seek(0); json.dump(c, f, indent=2); f.truncate()
"
      echo "Code Queue: Created $PARENT_IDENTIFIER"
    else
      echo "Code Queue: API returned unexpected response, continuing without tracking"
    fi
  else
    echo "Code Queue: API unreachable, continuing without tracking"
  fi
}

codeq_comment() {
  [[ "$TRACKING" != "codeq" || -z "$PARENT_ID" ]] && return 0
  local content="$1"
  curl -s -X POST "$CODEQ_API/items/$PARENT_ID/comments" \
    -H "Content-Type: application/json" \
    -d "$(python3 -c "import json,sys; print(json.dumps({'content': sys.argv[1]}))" "$content")" > /dev/null 2>&1 || true
}

codeq_create_bug() {
  [[ "$TRACKING" != "codeq" || -z "$PARENT_ID" ]] && return 0
  local cycle="$1"
  local bugs_file="$WORKSPACE/06-qa/cycle-$cycle/bugs.json"
  [[ ! -f "$bugs_file" ]] && return 0

  python3 -c "
import json, subprocess
try:
  bugs = json.load(open('$bugs_file'))
  f_bugs = [b for b in bugs if b.get('severity') == 'F']
  for bug in f_bugs:
    payload = json.dumps({
      'title': '[BUG] ' + bug.get('id','') + ': ' + bug.get('element','')[:60],
      'description': '**Severity**: ' + bug.get('severity','') + '\n**Element**: ' + bug.get('element','') + '\n**Viewport**: ' + bug.get('viewport','') + '\n**Expected**: ' + bug.get('expected','') + '\n**Actual**: ' + bug.get('actual','') + '\n**Fix Hint**: ' + bug.get('fix_hint',''),
      'parent_id': '$PARENT_ID',
      'priority': 'high',
      'status': 'todo'
    })
    subprocess.run(['curl', '-s', '-X', 'POST',
      '$CODEQ_API/items',
      '-H', 'Content-Type: application/json',
      '-d', payload], capture_output=True)
except Exception as e:
  print(f'Warning: Could not create bug issues: {e}')
" 2>/dev/null || true
}

codeq_complete() {
  [[ "$TRACKING" != "codeq" || -z "$PARENT_ID" ]] && return 0
  local elapsed=$(( $(date +%s) - START_TIME ))
  local elapsed_min=$((elapsed / 60))

  codeq_comment "## Clone Complete\n\n**Duration**: ${elapsed_min} minutes\n**Workspace**: $WORKSPACE\n**Output**: $OUTPUT_DIR\n\nSee progress.md for full stage-by-stage log."

  curl -s -X PATCH "$CODEQ_API/items/$PARENT_ID" \
    -H "Content-Type: application/json" \
    -d '{"status": "in_review"}' > /dev/null 2>&1 || true
}

# --- Enhanced prompt suffix for Pat's agents ---
get_enhanced_suffix() {
  if [[ "$TRACKING" == "codeq" ]]; then
    cat << ENHANCED

ENHANCED MODE (clone-app-pat-pro):
- Use agent-browser as primary tool (most token-efficient, ~50-150 tokens/op)
- Use claude-in-chrome javascript_tool for complex computed style queries (~75-100 tokens/op)
- DO NOT use Playwright MCP (token-inefficient — adds 100-200 tokens overhead per call)
- Every visual assertion must include evidence_method (e.g., "agent-browser eval getComputedStyle")
- Anti-hallucination: NEVER claim visual match without measured evidence
- Read the enhanced reference: cat "$SKILL_DIR/references/pat-enhanced.md"
ENHANCED
  fi
}

# --- Create workspace ---
if [[ ! -d "$WORKSPACE" ]]; then
  mkdir -p "$WORKSPACE"/{01-recon/screenshots/hover-states,02-extraction/raw-html,03-design-spec,04-architecture,05-build,06-qa,07-fix,08-polish/final-screenshots}

  # Write config
  cat > "$WORKSPACE/00-config.json" << CONF
{
  "target_url": "$URL",
  "clone_name": "$NAME",
  "output_dir": "$OUTPUT_DIR",
  "tech_stack": "$STACK",
  "tracking": "$TRACKING",
  "viewports": ["1920x1080", "768x1024", "375x667"],
  "pages": ["auto"],
  "qa_cycles": $QA_CYCLES,
  "created_at": "$TIMESTAMP"
}
CONF

  # Init progress log
  echo "# Clone Progress: $NAME" > "$WORKSPACE/progress.md"
  echo "Target: $URL" >> "$WORKSPACE/progress.md"
  echo "Started: $TIMESTAMP" >> "$WORKSPACE/progress.md"
  echo "Tracking: $TRACKING" >> "$WORKSPACE/progress.md"
  echo "" >> "$WORKSPACE/progress.md"

  # Init status
  cat > "$WORKSPACE/status.json" << STATUS
{"current_stage": "init", "completed_stages": [], "exit_ready": false}
STATUS

  echo "Created workspace: $WORKSPACE"

  # Create Code Queue parent issue (if codeq mode)
  codeq_create_parent
else
  # Resume: load existing Code Queue IDs
  if [[ "$TRACKING" == "codeq" ]]; then
    PARENT_ID=$(python3 -c "import json; print(json.load(open('$WORKSPACE/00-config.json')).get('codeq_parent_id',''))" 2>/dev/null) || true
    PARENT_IDENTIFIER=$(python3 -c "import json; print(json.load(open('$WORKSPACE/00-config.json')).get('codeq_identifier',''))" 2>/dev/null) || true
    [[ -n "$PARENT_IDENTIFIER" ]] && echo "Code Queue: Resuming $PARENT_IDENTIFIER"
  fi
fi

# --- Helper: get current stage ---
get_stage() {
  python3 -c "import json; print(json.load(open('$WORKSPACE/status.json'))['current_stage'])"
}

# --- Helper: run a stage agent ---
run_stage() {
  local stage_num="$1"
  local stage_name="$2"
  local prompt_template="$3"

  check_timeout
  echo ""
  echo "=== Stage $stage_num: $stage_name ==="
  echo ""

  # Substitute variables in prompt
  local prompt
  prompt=$(echo "$prompt_template" | \
    sed "s|{URL}|$URL|g" | \
    sed "s|{NAME}|$NAME|g" | \
    sed "s|{SKILL_DIR}|$SKILL_DIR|g" | \
    sed "s|{TIMESTAMP}|$(date -u +"%Y-%m-%dT%H:%M:%SZ")|g" | \
    sed "s|{QA_CYCLES}|$QA_CYCLES|g")

  # Append enhanced suffix for Pat's agents
  local suffix
  suffix=$(get_enhanced_suffix)
  if [[ -n "$suffix" ]]; then
    prompt="$prompt

$suffix"
  fi

  # Run agent with fresh context
  local result
  result=$(claude -p "$prompt" --allowedTools "Bash,Read,Write,Edit,Glob,Grep,mcp__claude-in-chrome__javascript_tool,mcp__claude-in-chrome__gif_creator,mcp__claude-in-chrome__navigate,mcp__claude-in-chrome__read_page,mcp__claude-in-chrome__computer,mcp__claude-in-chrome__tabs_context_mcp,mcp__claude-in-chrome__tabs_create_mcp,mcp__claude-in-chrome__resize_window" 2>&1) || true

  # Check completion signal
  if echo "$result" | grep -q '<promise>BLOCKED'; then
    local reason
    reason=$(echo "$result" | sed -n 's/.*BLOCKED: \(.*\)<\/promise>.*/\1/p')
    echo "BLOCKED: $reason"
    echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] Stage $stage_num BLOCKED: $reason" >> "$WORKSPACE/progress.md"
    codeq_comment "## Stage $stage_num: $stage_name BLOCKED\n\n$reason"
    exit 1
  fi

  # Log to Code Queue
  codeq_comment "## Stage $stage_num: $stage_name Complete\n\n**Time**: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"

  echo "Stage $stage_num complete."
}

# --- Read stage prompts ---
PROMPTS_FILE="$SKILL_DIR/references/stage-prompts.md"

# Extract prompt for a given stage header
get_prompt() {
  local header="$1"
  # Extract text between ```\n and \n``` after the header
  # Note: re.escape handles parentheses in headers like "Stage 6: QA (Cycle N)"
  python3 -c "
import re, sys
with open('$PROMPTS_FILE') as f:
    content = f.read()
# Find the section — escape header for regex safety
escaped = re.escape('$header')
pattern = r'## ' + escaped + r'\n\n\`\`\`\n(.*?)\n\`\`\`'
match = re.search(pattern, content, re.DOTALL)
if match:
    print(match.group(1))
else:
    print('ERROR: Prompt not found for $header', file=sys.stderr)
    sys.exit(1)
"
}

# --- Main pipeline ---
CURRENT=$(get_stage)

# Stage 1: Recon
if [[ "$CURRENT" == "init" || "$CURRENT" == "init_complete" ]]; then
  PROMPT=$(get_prompt "Stage 1: Recon")
  run_stage 1 "RECON" "$PROMPT"
  CURRENT=$(get_stage)
fi

# Stage 2: Extraction
if [[ "$CURRENT" == "recon_complete" ]]; then
  PROMPT=$(get_prompt "Stage 2: Extraction")
  run_stage 2 "EXTRACTION" "$PROMPT"
  CURRENT=$(get_stage)
fi

# Stage 3: Design Spec
if [[ "$CURRENT" == "extraction_complete" ]]; then
  PROMPT=$(get_prompt "Stage 3: Design Spec")
  run_stage 3 "DESIGN SPEC" "$PROMPT"
  CURRENT=$(get_stage)
fi

# Stage 4: Architecture
if [[ "$CURRENT" == "design_spec_complete" ]]; then
  PROMPT=$(get_prompt "Stage 4: Architecture")
  run_stage 4 "ARCHITECTURE" "$PROMPT"
  CURRENT=$(get_stage)
fi

# Stage 5: Build
if [[ "$CURRENT" == "architecture_complete" ]]; then
  PROMPT=$(get_prompt "Stage 5: Build")
  run_stage 5 "BUILD" "$PROMPT"
  CURRENT=$(get_stage)
fi

# Stages 6-7: QA-Fix Loop
for CYCLE in $(seq 1 $QA_CYCLES); do
  # QA
  if [[ "$CURRENT" == "build_complete" || "$CURRENT" == "fix_cycle_$((CYCLE-1))_complete" ]]; then
    QA_PROMPT=$(get_prompt "Stage 6: QA (Cycle N)" | sed "s|{CYCLE}|$CYCLE|g")
    mkdir -p "$WORKSPACE/06-qa/cycle-$CYCLE/screenshots"
    run_stage "6.$CYCLE" "QA CYCLE $CYCLE" "$QA_PROMPT"
    CURRENT=$(get_stage)

    # Create Code Queue sub-issues for F-grade bugs
    codeq_create_bug "$CYCLE"
  fi

  # Fix
  if [[ "$CURRENT" == "qa_cycle_${CYCLE}_complete" ]]; then
    FIX_PROMPT=$(get_prompt "Stage 7: Fix (Cycle N)" | sed "s|{CYCLE}|$CYCLE|g")
    run_stage "7.$CYCLE" "FIX CYCLE $CYCLE" "$FIX_PROMPT"
    CURRENT=$(get_stage)
  fi
done

# Stage 9: Polish
if [[ "$CURRENT" == "fix_cycle_${QA_CYCLES}_complete" ]]; then
  PROMPT=$(get_prompt "Stage 9: Polish")
  run_stage 9 "POLISH" "$PROMPT"
fi

# --- Done ---
echo ""
echo "=== CLONE COMPLETE ==="
echo "Workspace: $WORKSPACE"
echo "Output: $OUTPUT_DIR"
echo "Progress log: $WORKSPACE/progress.md"
[[ -n "$PARENT_IDENTIFIER" ]] && echo "Code Queue: $PARENT_IDENTIFIER"
echo ""

# Final Code Queue update
codeq_complete
