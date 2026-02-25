#!/usr/bin/env bash
# TeammateIdle hook - runs when a teammate is about to go idle.
# Exit code 2 = send feedback to keep the teammate working.
# Exit code 0 = allow teammate to go idle.
#
# Install in ~/.claude/settings.json:
#   "hooks": {
#     "TeammateIdle": [{
#       "hooks": [{
#         "type": "command",
#         "command": "bash ~/dotfiles/claude/hooks/teammate-idle.sh"
#       }]
#     }]
#   }

# Check if there are still pending tasks in the team task list
TEAM_DIR="${HOME}/.claude/tasks"
PENDING=0

if [[ -d "$TEAM_DIR" ]]; then
  for task_file in "$TEAM_DIR"/*/*.json; do
    [[ -f "$task_file" ]] || continue
    if grep -q '"status":\s*"pending"' "$task_file" 2>/dev/null; then
      PENDING=$((PENDING + 1))
    fi
  done
fi

if [[ $PENDING -gt 0 ]]; then
  echo "There are ${PENDING} pending tasks. Pick up the next unassigned task from the task list."
  exit 2  # Keep working
fi

exit 0  # Allow idle
