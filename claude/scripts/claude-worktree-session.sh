#!/usr/bin/env bash
# Create a git worktree and launch Claude Code in it via tmux.
# Usage: claude-worktree-session.sh <branch-name>

set -euo pipefail

BRANCH="${1:?Usage: claude-worktree-session.sh <branch-name>}"
REPO_ROOT="$(git rev-parse --show-toplevel)"
WT_DIR="${REPO_ROOT}/../wt-${BRANCH}"

# Create worktree if it doesn't exist
if [[ ! -d "$WT_DIR" ]]; then
  git worktree add "$WT_DIR" -b "$BRANCH" HEAD 2>/dev/null || \
    git worktree add "$WT_DIR" "$BRANCH" 2>/dev/null
  echo "Created worktree: ${WT_DIR} (branch: ${BRANCH})"
fi

# Launch Claude in a new tmux window pointed at the worktree
tmux new-window -n "wt:${BRANCH}" "cd '${WT_DIR}' && claude"
