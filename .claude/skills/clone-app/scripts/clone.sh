#!/usr/bin/env bash
# Clone App Orchestrator — Ralph-loop derivative
# Usage: ./clone.sh "<url>" "<name>" [--stack auto] [--output ./clone] [--timeout 8]
# Resume: ./clone.sh --resume clone-workspace/<name>

set -euo pipefail

SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# --- Argument parsing ---
URL=""
NAME=""
STACK="auto"
OUTPUT_DIR=""
TIMEOUT_HOURS=8
RESUME=""
QA_CYCLES=4

while [[ $# -gt 0 ]]; do
  case "$1" in
    --resume) RESUME="$2"; shift 2 ;;
    --stack) STACK="$2"; shift 2 ;;
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
    exit 1
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
  echo "" >> "$WORKSPACE/progress.md"

  # Init status
  cat > "$WORKSPACE/status.json" << STATUS
{"current_stage": "init", "completed_stages": [], "exit_ready": false}
STATUS

  echo "Created workspace: $WORKSPACE"
fi

# --- Helper: get current stage ---
get_stage() {
  python3 -c "import json; print(json.load(open('$WORKSPACE/status.json'))['current_stage'])"
}

# --- Reference file map: stage number → reference file ---
get_reference_file() {
  local stage="$1"
  case "$stage" in
    1)     echo "$SKILL_DIR/references/01-recon.md" ;;
    2)     echo "$SKILL_DIR/references/02-extraction.md" ;;
    3)     echo "$SKILL_DIR/references/03-design-spec.md" ;;
    4)     echo "$SKILL_DIR/references/04-architecture.md" ;;
    5)     echo "$SKILL_DIR/references/05-build.md" ;;
    6*)    echo "$SKILL_DIR/references/06-qa.md" ;;
    7*)    echo "" ;;
    9)     echo "$SKILL_DIR/references/07-polish.md" ;;
    *)     echo "" ;;
  esac
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

  # Inject reference file directly into the prompt
  local ref_file
  ref_file=$(get_reference_file "$stage_num")
  if [[ -n "$ref_file" && -f "$ref_file" ]]; then
    prompt="$prompt

=== DETAILED INSTRUCTIONS (follow every step) ===

$(cat "$ref_file")"
  fi

  # Run agent with fresh context
  local result
  result=$(claude -p "$prompt" \
    --allowedTools "Bash,Read,Write,Edit,Glob,Grep" \
    --disallowedTools "mcp__playwright__browser_navigate,mcp__playwright__browser_snapshot,mcp__playwright__browser_click,mcp__playwright__browser_type,mcp__playwright__browser_take_screenshot,mcp__playwright__browser_run_code,mcp__playwright__browser_evaluate,mcp__playwright__browser_close,mcp__playwright__browser_resize,mcp__playwright__browser_console_messages,mcp__playwright__browser_handle_dialog,mcp__playwright__browser_file_upload,mcp__playwright__browser_fill_form,mcp__playwright__browser_install,mcp__playwright__browser_press_key,mcp__playwright__browser_navigate_back,mcp__playwright__browser_network_requests,mcp__playwright__browser_select_option,mcp__playwright__browser_tabs,mcp__playwright__browser_wait_for,mcp__playwright__browser_hover,mcp__playwright__browser_drag" \
    2>&1) || true

  # Check completion signal
  if echo "$result" | grep -q '<promise>BLOCKED'; then
    local reason
    reason=$(echo "$result" | sed -n 's/.*BLOCKED: \(.*\)<\/promise>.*/\1/p')
    echo "BLOCKED: $reason"
    echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] Stage $stage_num BLOCKED: $reason" >> "$WORKSPACE/progress.md"
    exit 1
  fi

  echo "Stage $stage_num complete."
}

# --- Read stage prompts ---
PROMPTS_FILE="$SKILL_DIR/references/stage-prompts.md"

# Extract prompt for a given stage header
get_prompt() {
  local header="$1"
  python3 -c "
import re, sys
with open('$PROMPTS_FILE') as f:
    content = f.read()
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
echo ""
