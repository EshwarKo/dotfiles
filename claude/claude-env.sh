#!/usr/bin/env bash
# Claude Code shell aliases and environment
# Source this from ~/.bashrc or ~/.zshrc:
#   source ~/dotfiles/claude/claude-env.sh

# Core aliases (Tip 7)
alias c='claude'
alias ch='claude --chrome'
alias cr='claude -r'
alias cc='claude -c'
alias csk='claude --dangerously-skip-permissions'

# Fork shortcut: --fs expands to --fork-session (Tip 23)
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

# Quick tmux session for Claude work
claude-session() {
  local name="${1:-claude-work}"
  tmux new-session -d -s "$name" 2>/dev/null || tmux attach -t "$name"
}

# Launch Claude in a named tmux window
claude-window() {
  local name="${1:-agent}"
  tmux new-window -n "$name" 'claude'
}

# Absolute path helper (Tip 24)
alias rp='realpath'

# Editor for Ctrl+G prompt editing (Tip 38)
export EDITOR="${EDITOR:-nvim}"
