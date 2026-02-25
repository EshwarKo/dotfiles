#!/usr/bin/env bash
# Claude Code shell aliases and environment
# Source from ~/.bashrc or ~/.zshrc:
#   source ~/dotfiles/claude/claude-env.sh

# ── Core Aliases ──────────────────────────────────────────────────
alias c='claude'
alias ch='claude --chrome'
alias cr='claude -r'
alias cc='claude -c'
alias csk='claude --dangerously-skip-permissions'

# ── Agent Teams ───────────────────────────────────────────────────
# Enable experimental agent teams
export CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1

# Team launcher shortcuts
alias ct='bash ~/dotfiles/claude/scripts/claude-team.sh'
alias cta='bash ~/dotfiles/claude/scripts/claude-team.sh --test-agent --dashboard'

# Ralph loop: spec-driven autonomous agent pipeline
alias ralph='bash ~/dotfiles/claude/scripts/ralph-loop.sh'

# ── Fork Shortcut ─────────────────────────────────────────────────
# --fs expands to --fork-session (Tip 23)
claude() {
  local args=()
  for arg in "$@"; do
    if [[ "$arg" == "--fs" ]]; then
      args+=("--fork-session")
    else
      args+=("$arg")
    fi
  done
  command claude "${args[@]}"
}

# ── Tmux Session Helpers ─────────────────────────────────────────
# Quick Claude session in tmux
claude-session() {
  local name="${1:-claude-work}"
  tmux new-session -d -s "$name" 2>/dev/null || tmux attach -t "$name"
}

# Open Claude in a new tmux window
claude-window() {
  local name="${1:-agent}"
  tmux new-window -n "$name" 'claude'
}

# Spawn N concurrent Claude sessions in tmux panes
claude-multi() {
  local count="${1:-3}"
  local session="multi-$(date +%s)"
  tmux new-session -d -s "$session"
  for ((i=1; i<count; i++)); do
    tmux split-window -t "$session" -v
  done
  tmux select-layout -t "$session" tiled
  for ((i=0; i<count; i++)); do
    tmux send-keys -t "${session}:0.${i}" 'claude' Enter
  done
  tmux attach -t "$session"
}

# ── Git Worktree Helpers ─────────────────────────────────────────
# Create a worktree + Claude session for parallel branch work
claude-worktree() {
  local branch="${1:?Usage: claude-worktree <branch-name>}"
  local repo_root
  repo_root="$(git rev-parse --show-toplevel)"
  local wt_dir="${repo_root}/../wt-${branch}"
  git worktree add "$wt_dir" -b "$branch" HEAD 2>/dev/null || \
    git worktree add "$wt_dir" "$branch" 2>/dev/null
  tmux new-window -n "wt:${branch}" "cd '${wt_dir}' && claude"
}

# Clean up worktrees, tmux sessions, and temp files from claude tools
claude-clean() {
  echo "Cleaning up claude agent artifacts..."

  # Remove worktrees (matches wt-*, ralph-wt-*)
  local cleaned=0
  git worktree list 2>/dev/null | grep -E 'wt-|ralph-wt-' | awk '{print $1}' | while read -r wt; do
    echo "  Removing worktree: $wt"
    git worktree remove "$wt" --force 2>/dev/null || true
    cleaned=$((cleaned + 1))
  done
  git worktree prune 2>/dev/null

  # Kill tmux sessions matching team-* or ralph-*
  tmux list-sessions -F '#{session_name}' 2>/dev/null | grep -E '^(team-|ralph-|multi-)' | while read -r sess; do
    echo "  Killing tmux session: $sess"
    tmux kill-session -t "$sess" 2>/dev/null || true
  done

  # Clean temp files
  rm -f /tmp/ralph-iter-* /tmp/claude-team-prompt-*.txt 2>/dev/null

  echo "Done."
}

# Alias for backwards compat
claude-worktree-clean() { claude-clean; }

# ── Containerized Sessions ─────────────────────────────────────
# Sandbox launcher (Docker-based isolation with firewall)
alias csb='bash ~/dotfiles/claude/docker/claude-sandbox.sh'
alias csb-isolated='bash ~/dotfiles/claude/docker/claude-sandbox.sh --isolated'
alias csb-headless='bash ~/dotfiles/claude/docker/claude-sandbox.sh --headless'

# Docker compose shortcuts (from repo root)
alias csb-build='docker build -t claude-sandbox -f ~/dotfiles/claude/docker/Dockerfile ~/dotfiles'
alias csb-up='docker compose -f ~/dotfiles/claude/docker/docker-compose.yml run --rm claude-interactive'

# ── Utilities ────────────────────────────────────────────────────
alias rp='realpath'
export EDITOR="${EDITOR:-nvim}"

# Agent dashboard
alias cdash='bash ~/dotfiles/claude/scripts/claude-dashboard.sh'
