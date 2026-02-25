#!/usr/bin/env bash
# Claude Agent Dashboard
# Monitors active Claude Code tmux sessions, token usage, and git state.
# Usage: bash claude-dashboard.sh
#   Or bind to tmux: bind D new-window -n 'dashboard' 'bash ~/dotfiles/claude/scripts/claude-dashboard.sh'

set -euo pipefail

CLAUDE_DIR="${HOME}/.claude"
REFRESH_INTERVAL=5

# Colors
BOLD='\033[1m'
DIM='\033[2m'
GREEN='\033[32m'
YELLOW='\033[33m'
RED='\033[31m'
CYAN='\033[36m'
RESET='\033[0m'

bar() {
  local pct=$1 width=20
  local filled=$(( pct * width / 100 ))
  local empty=$(( width - filled ))
  local color="$GREEN"
  [[ $pct -gt 60 ]] && color="$YELLOW"
  [[ $pct -gt 80 ]] && color="$RED"
  printf "${color}"
  printf '%0.s█' $(seq 1 $filled 2>/dev/null) || true
  printf '%0.s░' $(seq 1 $empty 2>/dev/null) || true
  printf "${RESET} %d%%" "$pct"
}

get_session_info() {
  local session_name="$1"
  local pane_pid
  pane_pid=$(tmux list-panes -t "$session_name" -F '#{pane_pid}' 2>/dev/null | head -1)

  # Check if a claude process is running in this session
  local claude_running="no"
  if [[ -n "$pane_pid" ]]; then
    if pgrep -P "$pane_pid" -f "claude" >/dev/null 2>&1; then
      claude_running="yes"
    fi
  fi
  echo "$claude_running"
}

get_worktree_status() {
  local dir="$1"
  if [[ -d "$dir/.git" ]] || git -C "$dir" rev-parse --git-dir >/dev/null 2>&1; then
    local branch uncommitted
    branch=$(git -C "$dir" branch --show-current 2>/dev/null || echo "detached")
    uncommitted=$(git -C "$dir" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
    echo "${branch} (${uncommitted} uncommitted)"
  else
    echo "not a git repo"
  fi
}

render() {
  clear
  local now
  now=$(date '+%H:%M:%S')

  echo -e "${BOLD}${CYAN}╔══════════════════════════════════════════════════════════╗${RESET}"
  echo -e "${BOLD}${CYAN}║          CLAUDE AGENT DASHBOARD  ${DIM}${now}${BOLD}${CYAN}              ║${RESET}"
  echo -e "${BOLD}${CYAN}╠══════════════════════════════════════════════════════════╣${RESET}"

  # List tmux sessions
  echo -e "${BOLD}  Sessions:${RESET}"
  echo ""

  local sessions
  sessions=$(tmux list-sessions -F '#{session_name}|#{session_windows}|#{session_activity}' 2>/dev/null || true)

  if [[ -z "$sessions" ]]; then
    echo -e "  ${DIM}No tmux sessions found${RESET}"
  else
    printf "  ${BOLD}%-20s %-10s %-10s %-12s${RESET}\n" "Session" "Windows" "Claude?" "Last Active"
    printf "  %-20s %-10s %-10s %-12s\n" "-------" "-------" "-------" "-----------"

    while IFS='|' read -r name windows activity; do
      local claude_status
      claude_status=$(get_session_info "$name")
      local status_color="$DIM"
      [[ "$claude_status" == "yes" ]] && status_color="$GREEN"

      local age=""
      if [[ -n "$activity" ]]; then
        local now_epoch
        now_epoch=$(date +%s)
        local diff=$(( now_epoch - activity ))
        if [[ $diff -lt 60 ]]; then
          age="${diff}s ago"
        elif [[ $diff -lt 3600 ]]; then
          age="$(( diff / 60 ))m ago"
        else
          age="$(( diff / 3600 ))h ago"
        fi
      fi

      printf "  ${status_color}%-20s %-10s %-10s %-12s${RESET}\n" \
        "$name" "$windows" "$claude_status" "$age"
    done <<< "$sessions"
  fi

  echo ""
  echo -e "${BOLD}${CYAN}╠══════════════════════════════════════════════════════════╣${RESET}"

  # Git worktrees
  echo -e "${BOLD}  Git Worktrees:${RESET}"
  echo ""

  local worktrees
  worktrees=$(git worktree list 2>/dev/null || true)
  if [[ -z "$worktrees" ]]; then
    echo -e "  ${DIM}No worktrees (or not in a git repo)${RESET}"
  else
    while read -r wt_line; do
      local wt_dir
      wt_dir=$(echo "$wt_line" | awk '{print $1}')
      local wt_status
      wt_status=$(get_worktree_status "$wt_dir")
      echo -e "  ${DIM}${wt_dir}${RESET}"
      echo -e "    ${wt_status}"
    done <<< "$worktrees"
  fi

  echo ""
  echo -e "${BOLD}${CYAN}╠══════════════════════════════════════════════════════════╣${RESET}"

  # Recent conversations
  echo -e "${BOLD}  Recent Conversations (last 24h):${RESET}"
  echo ""

  local project_dirs
  project_dirs=$(find "$CLAUDE_DIR/projects/" -maxdepth 1 -type d 2>/dev/null | tail -5)
  local found=0
  for pdir in $project_dirs; do
    local recent
    recent=$(find "$pdir" -name "*.jsonl" -mtime 0 2>/dev/null | head -3)
    for conv in $recent; do
      found=1
      local conv_name
      conv_name=$(basename "$conv" .jsonl)
      local conv_size
      conv_size=$(wc -c < "$conv" 2>/dev/null | tr -d ' ')
      local conv_kb=$(( conv_size / 1024 ))
      echo -e "  ${DIM}${conv_name:0:40}${RESET}  ${conv_kb}KB"
    done
  done

  [[ $found -eq 0 ]] && echo -e "  ${DIM}No recent conversations found${RESET}"

  echo ""
  echo -e "${BOLD}${CYAN}╚══════════════════════════════════════════════════════════╝${RESET}"
  echo ""
  echo -e "  ${DIM}[q] quit  [r] refresh  Auto-refresh: ${REFRESH_INTERVAL}s${RESET}"
}

# Main loop
while true; do
  render
  read -t "$REFRESH_INTERVAL" -n 1 key 2>/dev/null || true
  case "${key:-}" in
    q|Q) echo ""; exit 0 ;;
    r|R) continue ;;
  esac
done
