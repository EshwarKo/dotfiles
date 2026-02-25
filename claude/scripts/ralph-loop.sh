#!/usr/bin/env bash
# Ralph Loop Orchestrator
# Implements the Geoffrey Huntley "ralph loop" pattern for Claude Code:
#   One agent, one repo, one task per loop iteration.
#   Observe -> Plan -> Act -> Test -> Verify -> Loop
#
# Usage:
#   ralph-loop.sh <spec-file> [--workers N] [--worktree]
#
# The loop runs in tmux with a lead agent that:
#   1. Reads the spec
#   2. Breaks it into tasks
#   3. Asks the user to confirm/clarify design decisions
#   4. Assigns tasks to worker agents (each in their own tmux pane)
#   5. Dedicated test agents verify each completed task
#   6. Dashboard pane monitors everything

set -euo pipefail

# --- Config ---
SPEC_FILE="${1:?Usage: ralph-loop.sh <spec-file> [--workers N] [--worktree]}"
NUM_WORKERS=3
USE_WORKTREES=false
SESSION_NAME="ralph-$(date +%s)"
TEAM_DIR="${HOME}/.claude/ralph-teams/${SESSION_NAME}"
LOOP_STATE_FILE="${TEAM_DIR}/loop-state.json"

shift || true
while [[ $# -gt 0 ]]; do
  case "$1" in
    --workers) NUM_WORKERS="$2"; shift 2 ;;
    --worktree) USE_WORKTREES=true; shift ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# --- Validate ---
if [[ ! -f "$SPEC_FILE" ]]; then
  echo "Error: spec file not found: $SPEC_FILE"
  exit 1
fi

SPEC_FILE="$(realpath "$SPEC_FILE")"
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

# --- Setup ---
mkdir -p "$TEAM_DIR"

cat > "$LOOP_STATE_FILE" <<EOF
{
  "session": "${SESSION_NAME}",
  "spec": "${SPEC_FILE}",
  "repo": "${REPO_ROOT}",
  "workers": ${NUM_WORKERS},
  "use_worktrees": ${USE_WORKTREES},
  "started_at": "$(date -Iseconds)",
  "status": "initializing",
  "loop_count": 0,
  "tasks_total": 0,
  "tasks_completed": 0
}
EOF

echo "Ralph Loop Orchestrator"
echo "======================="
echo "Session:    ${SESSION_NAME}"
echo "Spec:       ${SPEC_FILE}"
echo "Repo:       ${REPO_ROOT}"
echo "Workers:    ${NUM_WORKERS}"
echo "Worktrees:  ${USE_WORKTREES}"
echo ""

# --- Create tmux session with layout ---
# Layout:
#   +-------------------+-------------------+
#   |                   |    worker-1       |
#   |      lead         +-------------------+
#   |                   |    worker-2       |
#   |                   +-------------------+
#   |                   |    worker-3       |
#   +-------------------+-------------------+
#   |           dashboard / test-agent      |
#   +---------------------------------------+

tmux new-session -d -s "$SESSION_NAME" -n "orchestrator" -x 200 -y 50

# Main lead pane (left)
# Split right for workers
tmux split-window -t "${SESSION_NAME}:0" -h -p 50

# Split the right side into worker panes
for ((i=1; i<NUM_WORKERS; i++)); do
  tmux split-window -t "${SESSION_NAME}:0.1" -v -p $(( 100 / (NUM_WORKERS - i + 1) ))
done

# Bottom pane for dashboard
tmux split-window -t "${SESSION_NAME}:0.0" -v -p 25

# --- Create git worktrees if requested ---
if [[ "$USE_WORKTREES" == "true" ]]; then
  echo "Creating git worktrees for workers..."
  for ((i=0; i<NUM_WORKERS; i++)); do
    WT_BRANCH="ralph/${SESSION_NAME}/worker-${i}"
    WT_DIR="${REPO_ROOT}/../ralph-wt-${SESSION_NAME}-w${i}"
    git worktree add "$WT_DIR" -b "$WT_BRANCH" HEAD 2>/dev/null || true
    echo "  Worker ${i}: ${WT_DIR} (branch: ${WT_BRANCH})"
  done
fi

# --- Build the lead agent prompt ---
LEAD_PROMPT=$(cat <<'PROMPT_EOF'
You are the LEAD AGENT in a Ralph Loop orchestration system.

## Your Role
You coordinate a team of worker agents to implement a product specification.
You are HUMAN-IN-THE-LOOP: ask the user for every design decision, architecture
choice, or ambiguous requirement before proceeding.

## The Ralph Loop Pattern
Each iteration:
1. OBSERVE: Read the current state of the codebase and spec
2. PLAN: Break work into tasks, identify what needs clarification
3. ELICIT: Ask the user to confirm/choose on any design decisions
4. ACT: Assign tasks to worker agents via the agent team
5. TEST: Have dedicated test agents verify completed work
6. VERIFY: Review results, update the plan, loop back

## Rules
- ALWAYS ask the user before making architectural decisions
- ALWAYS ask the user before choosing between implementation approaches
- Break the spec into small, independent tasks (5-6 per worker)
- Assign tasks so workers don't edit the same files
- After each loop iteration, summarize progress and ask user what to prioritize next
- Create a shared task list the team can see
- When a worker finishes a task, spawn a test/review subagent to verify it

## Start
1. Read the spec file provided
2. Present a high-level breakdown to the user
3. Ask for confirmation on architecture and tech choices
4. Create the agent team and begin the first loop iteration

Spec file location:
PROMPT_EOF
)

LEAD_PROMPT="${LEAD_PROMPT} ${SPEC_FILE}"

# --- Export ralph loop env vars so the stop hook knows we're in a loop ---
RALPH_ENV="RALPH_ACTIVE=1 RALPH_SESSION_ID='${SESSION_NAME}' RALPH_SPEC_FILE='${SPEC_FILE}' RALPH_PROGRESS_FILE='${REPO_ROOT}/progress.json'"

# --- Write prompt to temp file (avoids quoting issues in tmux send-keys) ---
PROMPT_FILE="${TEAM_DIR}/lead-prompt.txt"
echo "$LEAD_PROMPT" > "$PROMPT_FILE"

# --- Launch agents ---
# Lead agent (left pane)
tmux send-keys -t "${SESSION_NAME}:0.0" \
  "cd '${REPO_ROOT}' && ${RALPH_ENV} claude --teammate-mode tmux -p \"\$(cat '${PROMPT_FILE}')\"" Enter

# Dashboard (bottom-left pane)
DASHBOARD_SCRIPT="$(dirname "$(realpath "$0")")/claude-dashboard.sh"
if [[ -f "$DASHBOARD_SCRIPT" ]]; then
  tmux send-keys -t "${SESSION_NAME}:0.$((NUM_WORKERS + 1))" \
    "bash '${DASHBOARD_SCRIPT}'" Enter
else
  tmux send-keys -t "${SESSION_NAME}:0.$((NUM_WORKERS + 1))" \
    "watch -n 5 'echo \"Ralph Loop: ${SESSION_NAME}\"; echo \"State:\"; cat \"${LOOP_STATE_FILE}\" 2>/dev/null | python3 -m json.tool 2>/dev/null || cat \"${LOOP_STATE_FILE}\"'" Enter
fi

# Worker panes get labels (agents will be spawned by the lead via agent teams)
for ((i=0; i<NUM_WORKERS; i++)); do
  PANE_IDX=$((i + 1))
  if [[ "$USE_WORKTREES" == "true" ]]; then
    WT_DIR="${REPO_ROOT}/../ralph-wt-${SESSION_NAME}-w${i}"
    tmux send-keys -t "${SESSION_NAME}:0.${PANE_IDX}" \
      "cd '${WT_DIR}' && echo 'Worker ${i} ready in worktree: ${WT_DIR}' && echo 'Waiting for lead agent to spawn agent team...'" Enter
  else
    tmux send-keys -t "${SESSION_NAME}:0.${PANE_IDX}" \
      "cd '${REPO_ROOT}' && echo 'Worker ${i} ready' && echo 'Waiting for lead agent to spawn agent team...'" Enter
  fi
done

# --- Attach ---
echo ""
echo "Attaching to tmux session: ${SESSION_NAME}"
echo "  Ctrl-A d    = detach (keep running)"
echo "  Ctrl-A D    = open dashboard"
echo "  Shift+Down  = cycle between teammates"
echo ""

tmux select-pane -t "${SESSION_NAME}:0.0"
tmux attach -t "$SESSION_NAME"
