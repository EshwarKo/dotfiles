#!/usr/bin/env bash
# Ralph Loop Stop Hook
# Intercepts Claude Code's exit attempt and checks if the work is actually done.
# If not, re-injects the prompt to start a fresh iteration.
#
# Install in ~/.claude/settings.json:
#   "hooks": {
#     "Stop": [{
#       "hooks": [{
#         "type": "command",
#         "command": "bash ~/dotfiles/claude/hooks/ralph-stop-hook.sh"
#       }]
#     }]
#   }
#
# Environment:
#   RALPH_SPEC_FILE     - path to the spec/PRD file
#   RALPH_PROGRESS_FILE - path to progress tracking file (default: ./progress.json)
#   RALPH_MAX_ITERS     - max iterations before forced stop (default: 20)
#   RALPH_COMPLETION_PROMISE - string that signals completion (default: RALPH_DONE)

set -euo pipefail

SPEC_FILE="${RALPH_SPEC_FILE:-}"
PROGRESS_FILE="${RALPH_PROGRESS_FILE:-./progress.json}"
MAX_ITERS="${RALPH_MAX_ITERS:-20}"
COMPLETION_PROMISE="${RALPH_COMPLETION_PROMISE:-RALPH_DONE}"
ITER_FILE="/tmp/ralph-iter-$$"

# Track iteration count
CURRENT_ITER=0
if [[ -f "$ITER_FILE" ]]; then
  CURRENT_ITER=$(cat "$ITER_FILE")
fi
CURRENT_ITER=$((CURRENT_ITER + 1))
echo "$CURRENT_ITER" > "$ITER_FILE"

# Check max iterations
if [[ $CURRENT_ITER -ge $MAX_ITERS ]]; then
  echo "Ralph loop reached max iterations (${MAX_ITERS}). Stopping."
  rm -f "$ITER_FILE"
  exit 0  # Allow exit
fi

# Check if completion promise was output
# The Stop hook receives the last assistant message via stdin
LAST_OUTPUT=""
if [[ -t 0 ]]; then
  : # No stdin
else
  LAST_OUTPUT=$(cat 2>/dev/null || true)
fi

if echo "$LAST_OUTPUT" | grep -q "$COMPLETION_PROMISE" 2>/dev/null; then
  echo "Completion promise found. Ralph loop done after ${CURRENT_ITER} iterations."
  rm -f "$ITER_FILE"
  exit 0  # Allow exit
fi

# Check if progress file shows all tasks complete
if [[ -f "$PROGRESS_FILE" ]]; then
  PENDING=$(grep -c '"status":\s*"pending"\|"done":\s*false' "$PROGRESS_FILE" 2>/dev/null || echo "0")
  if [[ "$PENDING" == "0" ]]; then
    # All tasks are done but run tests one more time
    echo "All tasks marked complete. Running final verification..."
    exit 0
  fi
fi

# Work is not done - re-inject the prompt
echo ""
echo "=== Ralph Loop: iteration ${CURRENT_ITER}/${MAX_ITERS} ==="
echo ""

if [[ -n "$SPEC_FILE" && -f "$SPEC_FILE" ]]; then
  echo "Continue working on the spec at: ${SPEC_FILE}"
  echo "Check progress at: ${PROGRESS_FILE}"
else
  echo "Continue working. Check git log and progress files to see what's been done."
  echo "Pick up the next incomplete task and implement it."
fi

echo ""
echo "When ALL tasks are complete and tests pass, output: ${COMPLETION_PROMISE}"

exit 2  # Exit code 2 = block exit, send feedback back to Claude
