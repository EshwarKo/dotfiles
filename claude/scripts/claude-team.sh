#!/usr/bin/env bash
# Claude Agent Team Launcher
# Spins up a coordinated team of Claude Code agents in tmux split panes.
#
# Usage:
#   claude-team.sh [options]
#
# Options:
#   --name NAME       Team session name (default: team-<timestamp>)
#   --workers N       Number of worker agents (default: 3)
#   --lead-prompt P   Initial prompt for the lead agent
#   --spec FILE       Product spec file to work from
#   --worktree        Give each worker its own git worktree
#   --test-agent      Add a dedicated test/review agent
#   --dashboard       Add a dashboard pane
#
# Examples:
#   claude-team.sh --spec spec.md --workers 3 --test-agent --dashboard
#   claude-team.sh --name auth-refactor --workers 2 --worktree

set -euo pipefail

# --- Defaults ---
SESSION_NAME="team-$(date +%s)"
NUM_WORKERS=3
LEAD_PROMPT=""
SPEC_FILE=""
USE_WORKTREES=false
ADD_TEST_AGENT=false
ADD_DASHBOARD=false
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

# --- Parse args ---
while [[ $# -gt 0 ]]; do
  case "$1" in
    --name) SESSION_NAME="$2"; shift 2 ;;
    --workers) NUM_WORKERS="$2"; shift 2 ;;
    --lead-prompt) LEAD_PROMPT="$2"; shift 2 ;;
    --spec) SPEC_FILE="$(realpath "$2")"; shift 2 ;;
    --worktree) USE_WORKTREES=true; shift ;;
    --test-agent) ADD_TEST_AGENT=true; shift ;;
    --dashboard) ADD_DASHBOARD=true; shift ;;
    -h|--help)
      sed -n '2,/^$/p' "$0" | sed 's/^# \?//'
      exit 0 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

echo "Claude Agent Team"
echo "=================="
echo "Session:   ${SESSION_NAME}"
echo "Workers:   ${NUM_WORKERS}"
echo "Worktrees: ${USE_WORKTREES}"
echo "Test:      ${ADD_TEST_AGENT}"
echo "Dashboard: ${ADD_DASHBOARD}"
[[ -n "$SPEC_FILE" ]] && echo "Spec:      ${SPEC_FILE}"
echo ""

# --- Create tmux layout ---
tmux new-session -d -s "$SESSION_NAME" -n "team" -x 220 -y 55

# Split: left = lead, right = workers stacked vertically
tmux split-window -t "${SESSION_NAME}:0" -h -p 55

# Stack worker panes on the right
for ((i=1; i<NUM_WORKERS; i++)); do
  tmux split-window -t "${SESSION_NAME}:0.1" -v -p $(( 100 / (NUM_WORKERS - i + 1) ))
done

# Optional: test agent pane (bottom right)
if [[ "$ADD_TEST_AGENT" == "true" ]]; then
  tmux split-window -t "${SESSION_NAME}:0.$NUM_WORKERS" -v -p 30
fi

# Optional: dashboard pane (bottom left)
if [[ "$ADD_DASHBOARD" == "true" ]]; then
  tmux split-window -t "${SESSION_NAME}:0.0" -v -p 20
fi

# --- Git worktrees ---
if [[ "$USE_WORKTREES" == "true" ]]; then
  for ((i=0; i<NUM_WORKERS; i++)); do
    WT_BRANCH="${SESSION_NAME}/w${i}"
    WT_DIR="${REPO_ROOT}/../wt-${SESSION_NAME}-w${i}"
    git worktree add "$WT_DIR" -b "$WT_BRANCH" HEAD 2>/dev/null || true
  done
fi

# --- Build lead prompt ---
PROMPT="You are the lead of an agent team using Claude Code."
PROMPT="${PROMPT} Use agent teams (CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS is enabled)."
PROMPT="${PROMPT} Coordinate ${NUM_WORKERS} worker teammates in tmux split-pane mode."
PROMPT="${PROMPT} IMPORTANT: You are HUMAN-IN-THE-LOOP. For ANY design decision,"
PROMPT="${PROMPT} architecture choice, technology selection, or ambiguous requirement,"
PROMPT="${PROMPT} ALWAYS ask the user first using targeted questions."

if [[ -n "$SPEC_FILE" ]]; then
  PROMPT="${PROMPT} Read the product spec at: ${SPEC_FILE}."
  PROMPT="${PROMPT} Break it into tasks, ask the user to confirm the plan,"
  PROMPT="${PROMPT} then assign tasks to teammates so they don't edit the same files."
fi

if [[ "$ADD_TEST_AGENT" == "true" ]]; then
  PROMPT="${PROMPT} Spawn one teammate dedicated to testing: it should run unit tests,"
  PROMPT="${PROMPT} lint, and review code after each task is completed by other workers."
fi

if [[ -n "$LEAD_PROMPT" ]]; then
  PROMPT="${PROMPT} Additional instructions: ${LEAD_PROMPT}"
fi

# --- Write prompt to temp file (avoids quoting issues in tmux send-keys) ---
PROMPT_FILE="/tmp/claude-team-prompt-${SESSION_NAME}.txt"
echo "$PROMPT" > "$PROMPT_FILE"

# --- Launch lead ---
tmux send-keys -t "${SESSION_NAME}:0.0" \
  "cd '${REPO_ROOT}' && claude --teammate-mode tmux -p \"\$(cat '${PROMPT_FILE}')\"" Enter

# --- Label worker panes ---
for ((i=0; i<NUM_WORKERS; i++)); do
  PANE_IDX=$((i + 1))
  if [[ "$USE_WORKTREES" == "true" ]]; then
    WT_DIR="${REPO_ROOT}/../wt-${SESSION_NAME}-w${i}"
    tmux send-keys -t "${SESSION_NAME}:0.${PANE_IDX}" \
      "cd '${WT_DIR}' && echo '=== Worker ${i} (worktree) ===' && pwd" Enter
  else
    tmux send-keys -t "${SESSION_NAME}:0.${PANE_IDX}" \
      "cd '${REPO_ROOT}' && echo '=== Worker ${i} ==='" Enter
  fi
done

# --- Test agent pane ---
if [[ "$ADD_TEST_AGENT" == "true" ]]; then
  TEST_PANE=$((NUM_WORKERS + 1))
  tmux send-keys -t "${SESSION_NAME}:0.${TEST_PANE}" \
    "cd '${REPO_ROOT}' && echo '=== Test Agent === (will be spawned by lead)'" Enter
fi

# --- Dashboard ---
if [[ "$ADD_DASHBOARD" == "true" ]]; then
  DASH_SCRIPT="$(dirname "$(realpath "$0")")/claude-dashboard.sh"
  # Dashboard is the last pane on the left side
  DASH_OFFSET=1
  [[ "$ADD_TEST_AGENT" == "true" ]] && DASH_OFFSET=2
  DASH_PANE_IDX=$((NUM_WORKERS + DASH_OFFSET))
  if [[ -f "$DASH_SCRIPT" ]]; then
    tmux send-keys -t "${SESSION_NAME}:0.${DASH_PANE_IDX}" \
      "bash '${DASH_SCRIPT}'" Enter
  else
    tmux send-keys -t "${SESSION_NAME}:0.${DASH_PANE_IDX}" \
      "watch -n 5 'tmux list-panes -t ${SESSION_NAME} -F \"#{pane_index}: #{pane_current_command} (#{pane_width}x#{pane_height})\"'" Enter
  fi
fi

# --- Attach ---
echo "Attaching to: ${SESSION_NAME}"
echo "  Ctrl-A d       detach"
echo "  Shift+Down     cycle teammates"
echo "  Ctrl-A [0-9]   jump to pane"
echo ""
tmux select-pane -t "${SESSION_NAME}:0.0"
tmux attach -t "$SESSION_NAME"
